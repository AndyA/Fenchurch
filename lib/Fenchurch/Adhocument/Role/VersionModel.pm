package Fenchurch::Adhocument::Role::VersionModel;

our $VERSION = "0.01";

use v5.10;

use Moose::Role;

=head1 NAME

Fenchurch::Adhocument::Role::VersionModel - Version table handling

=cut

requires 'db', '_version_engine', 'load';

sub _unpack_versions {
  my ( $self, $kind, $doc, $versions ) = @_;
  my @meta = ();
  my @docs = ();
  for my $ver (@$versions) {
    push @docs, delete $ver->{old_data};
    push @meta, $ver;
  }
  push @docs, $doc;
  unshift @meta, { sequence => 0, kind => $kind };
  my @out = ();
  push @out, { meta => shift @meta, doc => shift @docs, kind => $kind }
   while @docs;
  return \@out;
}

=head2 C<versions>

Load the version history for things.

=cut

sub versions {
  my ( $self, $kind, @ids ) = @_;

  # Load matching documents...
  my $docs = $self->db->stash_by( $self->load( $kind, @ids ),
    $self->pkey_for($kind) );

  # ...and version history
  my $vers
   = $self->db->stash_by(
    $self->_version_engine->load_by_key( 'version', 'object', @ids ),
    'object' );

  return [
    map {
      $self->_unpack_versions(
        $kind,
        ( $docs->{$_} // [] )->[0],
        $vers->{$_} // []
       )
    } @ids
  ];
}

=head2 C<load_versions>

Load versions by UUID.

=cut

sub load_versions {
  my ( $self, @ids ) = @_;
  return $self->_version_engine->load( version => @ids );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
