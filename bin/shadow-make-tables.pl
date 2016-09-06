#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use Dancer ':script';
use Dancer::Plugin::Database;

my @tables = qw(
 genome_changelog
 genome_content_messages
 genome_contributors
 genome_coordinates
 genome_edit
 genome_editlog
 genome_infax
 genome_issues
 genome_listing_notes
 genome_listings_v2
 genome_media
 genome_media_collection
 genome_media_spreadsheet
 genome_overrides
 genome_programmes_v2
 genome_region_aliases
 genome_regions
 genome_related
 genome_related_meta
 genome_service_aliases
 genome_service_dates
 genome_services
 genome_tables
);

# Special cases
my %special = (
  genome_editlog => {
    before => [
      "-- Drop old editlog triggers - which are rolled into our triggers now. Ugly",
      "-- but MySQL doesn't like mulitiple triggers for the same thing.",
      "",
      "DROP TRIGGER IF EXISTS `genome_editlog_digest_edit_insert`;",
      "DROP TRIGGER IF EXISTS `genome_editlog_digest_edit_update`;",
      ""
    ],
    extra => {
      INSERT => ["CALL `genome_freshen_digest` (NEW.edit_id);"],
      UPDATE => ["CALL `genome_freshen_digest` (NEW.edit_id);"] } }
);

my @shadow = (
  "  `sequence` INT(10) unsigned NOT NULL AUTO_INCREMENT,",
  "  `when` DATETIME NOT NULL,",
  "  `verb` VARCHAR(20) NOT NULL,",
  "  `connection_id` INT(10) unsigned NOT NULL,",
  "  `session` VARCHAR(100),"
);

say <<EOT;
BEGIN;

-- Log table: every update is recorded here
DROP TABLE IF EXISTS `shadow_x_log`;
CREATE TABLE `shadow_x_log` (
  `id` INT(10) unsigned NOT NULL AUTO_INCREMENT,
  `table` VARCHAR(80) NOT NULL,
  `sequence` INT(10) unsigned NOT NULL,
  `when` DATETIME NOT NULL,
  `verb` VARCHAR(20) NOT NULL,
  `connection_id` INT(10) unsigned NOT NULL,
  `session` VARCHAR(100),
  PRIMARY KEY(`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

-- Metadata about tracked tables
DROP TABLE IF EXISTS `shadow_x_meta`;
CREATE TABLE `shadow_x_meta` (
  `table` VARCHAR(80) NOT NULL,
  `shadow` VARCHAR(80) NOT NULL,
  `indentifying_keys` VARCHAR(256) NOT NULL,
  PRIMARY KEY(`table`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- History checkpoints
DROP TABLE IF EXISTS `shadow_x_checkpoint`;
CREATE TABLE `shadow_x_checkpoint` (
  `name` VARCHAR(80) NOT NULL,
  `when` DATETIME NOT NULL,
  `log_id` INT(10) unsigned NOT NULL,
  PRIMARY KEY(`name`, `when`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

EOT

for my $tbl (@tables) {
  make_shadow( database, $tbl );
}

say "COMMIT;";

sub make_shadow {
  my ( $dbh, $tbl ) = @_;

  my $stbl    = "shadow_${tbl}";
  my $id_keys = find_identifying_keys( $dbh, $tbl );
  my @pk      = @{ $id_keys->{PRIMARY} // ( values %$id_keys )[0] };

  die "Can't find identifying keys for $tbl" unless @pk;

  my ( undef, $create )
   = $dbh->selectrow_array("SHOW CREATE TABLE `$tbl`");
  my @create = split /\n/, $create;
  my $head   = shift @create;
  my $tail   = pop @create;

  # Discard the indexes
  pop @create
   while @create && $create[-1] =~ /^\s*(?:PRIMARY|UNIQUE|KEY)\b/;

  my @fld = map { /^\s*`(.+?)`/ && $1 } @create;

  die unless @create;

  $create[-1] =~ s/,\s*$//;
  $create[-1] .= ",";

  # Remove NULL constraints, AUTO_INCREMENT
  s/\s+NOT\s+NULL\s+/ /g   for @create;
  s/\s+AUTO_INCREMENT\b//g for @create;

  my @old = prefix_names( "OLD_", @create );
  my @new = prefix_names( "NEW_", @create );

  my @idx = ("  PRIMARY KEY (`sequence`)");
  for my $kind ( 'OLD', 'NEW' ) {
    $idx[-1] .= ",";
    push @idx, "  KEY (" . join( ", ", map { "`${kind}_$_`" } @pk ) . ")";
  }

  my @top = ( "DROP TABLE IF EXISTS `$stbl`;", "CREATE TABLE `$stbl` (" );

  # CREATE
  say "-- Shadow $tbl into $stbl";
  say
   for @top, @shadow, @old, @new, @idx,
   ") ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;";
  say "";
  say "REPLACE INTO `shadow_x_meta`",
   "(`table`, `shadow`, `indentifying_keys`)";
  say "  VALUES (\"$tbl\", \"$stbl\", \"", join( ", ", @pk ), "\");";
  say "";

  my $dst_fld = join( ", ",
    ( map { "`$_`" } "when", "verb", "connection_id", "session", ),
    ( map { "`OLD_$_`" } @fld ),
    ( map { "`NEW_$_`" } @fld ) );

  my $spec = $special{$tbl} // {};

  say for @{ $spec->{before} // [] };

  for my $trig (qw( INSERT UPDATE DELETE )) {
    my $name = "${stbl}_" . lc $trig;
    my @svals
     = ( "NOW()", "\"$trig\"", "CONNECTION_ID()", '@genome_session' );
    my @ovals
     = $trig eq "INSERT" ? ( ("NULL") x @fld ) : ( map { "OLD.`$_`" } @fld );
    my @nvals
     = $trig eq "DELETE" ? ( ("NULL") x @fld ) : ( map { "NEW.`$_`" } @fld );
    my $vals = join ", ", @svals, @ovals, @nvals;
    my $svals = join ", ", @svals;

    say "DROP TRIGGER IF EXISTS `$name`;";
    say "DELIMITER //";
    say "CREATE TRIGGER `$name` AFTER $trig ON `$tbl`";
    say "FOR EACH ROW";
    say "  BEGIN";
    say "    INSERT INTO `$stbl`";
    say "      ($dst_fld)";
    say "      VALUES ($vals);";
    say "    INSERT INTO `shadow_x_log`";
    say "      (`table`, `sequence`, `when`, `verb`, `connection_id`, `session`)";
    say "      VALUES (\"$stbl\", LAST_INSERT_ID(), $svals);";
    say "    $_" for @{ $spec->{extra}{$trig} // [] };
    say "  END;";
    say "//";

    say "DELIMITER ;";
    say '';
  }

}

sub find_identifying_keys {
  my ( $dbh, $table ) = @_;

  my @indexes = @{
    $dbh->selectall_arrayref(
      "SHOW INDEXES FROM `$table`", { Slice => {} }
    ) };

  my $id_keys = {};
  for my $idx (@indexes) {
    next if $idx->{Non_unique};
    push @{ $id_keys->{ $idx->{Key_name} } }, $idx->{Column_name};
  }

  return $id_keys;
}

sub prefix_names {
  my ( $prefix, @fields ) = @_;
  s/^(\s*`)/$1$prefix/ for @fields;
  return @fields;
}
