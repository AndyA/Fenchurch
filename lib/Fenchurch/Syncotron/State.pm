package Fenchurch::Syncotron::State;

our $VERSION = "1.00";

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

=head1 NAME

Fenchurch::Syncotron::State - Sync state

=cut

has state => (
  is      => 'rw',
  isa     => enum( ['init', 'enumerate', 'recent', 'fault'] ),
  default => 'init'
);

has ['progress', 'serial'] => (
  is      => 'rw',
  isa     => 'Int',
  default => 0
);

has fault => (
  is  => 'rw',
  isa => duck_type( ['location', 'error'] )
);

with Storage( format => 'JSON' );

after state => sub {
  my $self = shift;
  $self->progress(0) if @_;
};

after fault => sub {
  my $self = shift;
  $self->state('fault') if @_;
};

sub advance {
  my ( $self, $amount ) = @_;
  $self->progress( $self->progress + $amount );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
