package Fenchurch::Adhocument::Role::VersionEngine;

our $VERSION = "0.01";

use v5.10;

use Moose::Role;

=head1 NAME

Fenchurch::Adhocument::Role::VersionEngine - Work with versions

=cut

requires 'db';

sub version_engine;

has table => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  default  => ':versions'
);

has version_engine => (
  is      => 'ro',
  isa     => 'Fenchurch::Adhocument',
  lazy    => 1,
  builder => '_b_version_engine'
);

sub version_schema {
  my ( $self, $table, %extra ) = @_;
  return {
    version => {
      table => $self->db->alias($table),
      pkey  => 'uuid',
      order => '+sequence',
      json  => ['old_data', 'new_data'],
      %extra
    } };
}

sub _b_version_engine {
  my $self = shift;
  return Fenchurch::Adhocument->new(
    db     => $self->db,
    schema => Fenchurch::Adhocument::Schema->new(
      schema => $self->version_schema( $self->table, append => 1 )
    ),
    numify => 1
  );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
