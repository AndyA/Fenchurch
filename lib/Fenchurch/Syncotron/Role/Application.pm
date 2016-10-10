package Fenchurch::Syncotron::Role::Application;

our $VERSION = "1.00";

use Moose::Role;
use Moose::Util::TypeConstraints;

has _despatcher => (
  is      => 'ro',
  isa     => duck_type( ['on', 'despatch'] ),
  lazy    => 1,
  builder => '_b_despatcher'
);

requires '_build_app', 'mq_out', 'emit';

=head1 NAME

Fenchurch::Syncotron::Role::Application - A message despatching application

=cut

sub _b_despatcher {
  my $self = shift;
  my $de   = Fenchurch::Syncotron::Despatcher->new;

  # Application logic
  $self->_build_app($de);

  return $de;
}

sub _despatch {
  my ( $self, $msg ) = @_;
  $self->emit( receive => $msg );
  $self->_despatcher->despatch($msg);
}

sub _send {
  my ( $self, $msg ) = @_;
  $self->emit( send => $msg );
  $self->mq_out->send($msg);
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
