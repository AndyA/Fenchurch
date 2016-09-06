package Fenchurch::Adhocument::Resolver;

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;

use Fenchurch::Adhocument::Versions;

has engine => (
  is       => 'ro',
  isa      => duck_type( ['save'] ),
  required => 1
);

sub resolve {
  my ( $self, $edit, $old ) = @_;

  my $ve = $self->engine;

  if ( defined $edit->{old_data} ) {
    $ve->save( $edit->{kind}, $edit->{old_data} );
  }
  else {
    $ve->delete( $edit->{kind}, $edit->{object} );
  }
}

1;
