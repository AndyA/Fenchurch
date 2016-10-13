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

sub _make_home {
  my $self = shift;

  return {
    uuid  => $self->_make_uuid,
    title => "Fenchurch Wiki Home",
    text  => "This is the home page.",
    slug  => "home"
  };
}

sub save {
  my ( $self, $page ) = @_;
  use Dancer ':syntax';
  debug $page;
  my $orig = $self->versions->load( page => $page->{uuid} );
  $self->versions->save( page => { %{ $orig->[0] }, %$page } );
}

sub home {
  my $self = shift;

  {
    my $home = $self->versions->load_by_key( 'page', slug => 'home' );
    return $home->[0] if @$home;
  }

  {
    my $home = $self->_make_home;
    $self->versions->save( page => $home );
    return $home;
  }

}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
