package Fenchurch::Wiki::Engine;

our $VERSION = "0.01";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;

has versions => (
  is       => 'ro',
  isa      => duck_type( ['load', 'load_by_key', 'save'] ),
  required => 1
);

with 'Fenchurch::Core::Role::UUIDFactory';

=head1 NAME

Fenchurch::Wiki::Engine - The Wiki engine

=cut

sub page_list {
  my $self = shift;
  my $ve   = $self->versions;
  return $ve->dbh->selectall_arrayref(
    $ve->db->quote_sql(
      "SELECT {slug}, {title}",
      "  FROM {wiki_page}",
      " ORDER BY {title}"
    ),
    { Slice => {} }
  );
}

sub _make_page {
  my ( $self, $slug ) = @_;

  return {
    uuid  => $self->_make_uuid,
    title => "Fenchurch Wiki Home",
    text  => "This is the home page.",
    slug  => $slug
   }
   if $slug eq 'home';

  return {
    uuid  => $self->_make_uuid,
    title => ucfirst $slug,
    text  => "This is a page about " . ucfirst($slug) . ".",
    slug  => $slug
  };
}

sub save {
  my ( $self, $page ) = @_;
  my $orig = $self->versions->load( page => $page->{uuid} );
  $self->versions->save( page => { %{ $orig->[0] }, %$page } );
}

sub delete {
  my ( $self, $uuid ) = @_;
  $self->versions->delete( page => $uuid );
}

sub page {
  my ( $self, $slug ) = @_;

  {
    my $page = $self->versions->load_by_key( 'page', slug => $slug );
    return $page->[0] if @$page;
  }

  {
    my $page = $self->_make_page($slug);
    $self->versions->save( page => $page );
    return $page;
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
