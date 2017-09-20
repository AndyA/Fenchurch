package Fenchurch::Syncotron::Despatcher;

our $VERSION = "1.00";

use Fenchurch::Moose;

use Carp qw( confess );

has _handlers => (
  traits  => ['Array'],
  isa     => 'ArrayRef[HashRef]',
  default => sub { [] },
  handles => {
    _add_handler  => 'push',
    _get_handlers => 'elements'
  }
);

=head1 NAME

Fenchurch::Syncotron::Despatcher - Event despatcher

=cut

=head2 C<on>

Register a handler for event type(s). 

  $desp->on('myapp.update', sub {
    my ($ev) = @_;
    ...
  });

The first argument may be

=over

=item A literal type

=item A type containing wildcards (e.g. myapp.completed.*)

=item A regex (e.g. qr{\.error\.})

=item An array of any of the above

=back

=cut

sub on {
  my ( $self, $type, $handler ) = @_;

  $type = [$type] unless ref $type && 'ARRAY' eq ref $type;

  $self->_add_handler(
    { m => [map { $self->_pattern_to_regexp($_) } @$type],
      h => $handler
    }
  );

  return $self;    # chaining
}

sub _pattern_to_regexp {
  my ( $self, $pattern ) = @_;

  return $pattern if ref $pattern && 'Regexp' eq ref $pattern;

  my $match = join '\.',
   map { $_ eq '**' ? '.+' : $_ eq '*' ? '[^.]+' : quotemeta $_ }
   split /\./, $pattern;

  return qr{^$match$};
}

=head2 C<despatch>

Despatch an event to registered handlers

=cut

sub despatch {
  my ( $self, $ev, @args ) = @_;

  my $type = $ev->{type} // confess "Missing type in event";
  my $matched = 0;

  for my $handler ( $self->_get_handlers ) {
    for my $match ( @{ $handler->{m} } ) {
      if ( $type =~ $match ) {
        $matched++;
        $handler->{h}( $ev, @args );
        last;
      }
    }
  }

  return $matched;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
