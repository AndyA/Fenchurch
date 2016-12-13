package UUIDSequence;

our $VERSION = "0.01";

use v5.10;

use Moose;

has _next => ( is => 'rw', isa => 'Num', default => 1 );

=head1 NAME

UUIDSequence - Sequential UUIDs for testing

=cut

sub _format_uuid {
  my ( $self, $uuid ) = @_;
  return join '-', $1, $2, $3, $4, $5
   if $uuid =~ /^ ([0-9a-f]{8}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{12}) $/xi;
  die "Bad UUID";
}

sub make_uuid {
  my $self = shift;
  my $next = $self->_next;
  my $id   = sprintf '%08x', $next;
  $self->_next( $next + 1 );
  return $self->_format_uuid( $id x 4 );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
