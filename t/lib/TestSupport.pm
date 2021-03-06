package TestSupport;

use strict;
use warnings;

use feature 'state';

use DBI;
use Digest::SHA1 qw( sha1_hex );
use JSON ();
use Log::Log4perl;
use Path::Class;
use Storable qw( freeze );
use Test::More;

require Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
 database object_hash pickone preflight randint test_data
 test_data_file empty make_uuid valid_uuid insert
);

Log::Log4perl->init("log4perl.conf");

=head1 NAME

TestSupport - Common test stuff

=cut

BEGIN {
  if ( defined( my $seed = $ENV{FENCHURCH_ADHOCUMENT_SEED} ) ) {
    srand $seed;
    *CORE::GLOBAL::srand = sub(;$) { 1 };
  }
}

sub preflight() {
  unless ( defined $ENV{FENCHURCH_ADHOCUMENT_LOCAL_DSN} ) {
    plan skip_all => 'FENCHURCH_ADHOCUMENT_LOCAL_DSN not set';
    exit;
  }
}

sub database(@) {
  my $conn = uc( shift // 'local' );
  my $var = "FENCHURCH_ADHOCUMENT_${conn}_";

  die "${var}DSN not set" unless $ENV{"${var}DSN"};

  my $dbh = DBI->connect(
    $ENV{"${var}DSN"},
    $ENV{"${var}USER"} // 'root',
    $ENV{"${var}PASS"} // '',
    { mysql_enable_utf8   => 1,
      RaiseError          => 1,
      AutoInactiveDestroy => 1
    }
  );

  $dbh->do("SET character_set_client = utf8");
  $dbh->do("SET character_set_connection = utf8");
  $dbh->do("SET character_set_results = utf8");
  $dbh->do("SET character_set_server = utf8");
  $dbh->do("SET collation_connection = utf8_general_ci");
  $dbh->do("SET collation_server = utf8_general_ci");

  return $dbh;
}

sub test_data_file { file 't', 'data', @_ }

sub test_data {
  return JSON->new->decode( scalar test_data_file(@_)->slurp );
}

sub empty(@) {
  for my $conn ( 'local', 'remote' ) {
    my $dbh = database($conn);
    $dbh->do("TRUNCATE `$_`") for @_;
  }
}

sub insert {
  my ( $db, $table, $data ) = @_;
  return unless @$data;
  my @keys   = sort keys %{ $data->[0] };
  my $values = "(" . join( ", ", map "?", @keys ) . ")";
  my $sql    = join ' ',
   "INSERT INTO `$table` (", join( ", ", map "`$_`", @keys ), ")",
   "VALUES", join( ", ", ($values) x @$data );
  $db->do( $sql, {}, map { @{$_}{@keys} } @$data );
}

sub randint($) { int( rand() * $_[0] ) }

sub pickone(@) { @_[randint @_] }

sub object_hash {
  my $obj = shift;
  return [map { object_hash($_) } @$obj]
   if ref $obj && 'ARRAY' eq ref $obj;
  local $Storable::canonical = 1;
  my $rep = freeze [$obj];
  return sha1_hex($rep);
}

sub valid_uuid {
  for my $uuid (@_) {
    return unless $uuid =~ /^ ([0-9a-f]{8}) -?
                              ([0-9a-f]{4}) -?
                              ([0-9a-f]{4}) -?
                              ([0-9a-f]{4}) -?
                              ([0-9a-f]{12}) $/xi;
  }
  return 1;
}

sub format_uuid {
  my $uuid = shift;
  return join '-', $1, $2, $3, $4, $5
   if $uuid =~ /^ ([0-9a-f]{8}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{12}) $/xi;
  die "Bad UUID";
}

sub make_seq_uuid {
  state $next = 1;
  my $id = sprintf '%08x', $next++;
  return format_uuid( $id x 4 );
}

sub make_rand_uuid {
  return format_uuid( join '',
    map { sprintf '%04x', randint(65536) } 1 .. 8 );
}

sub make_uuid {
  return make_seq_uuid() if $ENV{FENCHURCH_ADHOCUMENT_SEQ_UUID};
  return make_rand_uuid();
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
