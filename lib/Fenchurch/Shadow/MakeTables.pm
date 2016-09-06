package Fenchurch::Shadow::MakeTables;

use Moose;

=head1 NAME

Fenchurch::Shadow::MakeTables - make shadow_ tables

=cut

with 'Fenchurch::Core::Role::DB';

has prefix => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  default  => 'shadow'
);

sub control_tables {
  my $self = shift;

  my $prefx = $self->prefix;

  return <<EOT;

-- Log table: every update is recorded here
DROP TABLE IF EXISTS `${prefix}_x_log`;
CREATE TABLE `${prefix}_x_log` (
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
DROP TABLE IF EXISTS `${prefix}_x_meta`;
CREATE TABLE `${prefix}_x_meta` (
  `table` VARCHAR(80) NOT NULL,
  `shadow` VARCHAR(80) NOT NULL,
  `indentifying_keys` VARCHAR(256) NOT NULL,
  PRIMARY KEY(`table`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- History checkpoints
DROP TABLE IF EXISTS `${prefix}_x_checkpoint`;
CREATE TABLE `${prefix}_x_checkpoint` (
  `name` VARCHAR(80) NOT NULL,
  `when` DATETIME NOT NULL,
  `log_id` INT(10) unsigned NOT NULL,
  PRIMARY KEY(`name`, `when`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

EOT
}

sub shadow_table {
  my ( $self, $table ) = @_;
}

1;
