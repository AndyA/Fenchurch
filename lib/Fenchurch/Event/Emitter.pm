package Fenchurch::Event::Emitter;

our $VERSION = "0.01";

use Moose;

use Carp qw( croak );

=head1 NAME

Fenchurch::Event::Emitter - Node style event emitter

=cut

has _listeners => (
  is       => 'ro',
  isa      => 'HashRef[ArrayRef]',
  required => 1,
  default  => sub { {} }
);

has _namespaces => (
  is       => 'ro',
  isa      => 'HashRef[HashRef]',
  required => 1,
  default  => sub { {} }
);

has do_default => (
  is      => 'rw',
  isa     => 'Bool',
  default => 1
);

# Class method: helper for delegation
sub interface {
  qw( add_listener emit interface off on once
   remove_all_listeners remove_listener
   do_default prevent_default );
}

sub _parse_event {
  my ( $self, $event ) = @_;
  my ( $ev, @ns ) = split /\./, $event;
  return ( $ev, { map { $_ => 1 } @ns } );
}

sub _parse_named_event {
  my $self = shift;
  my ( $ev, $ns ) = $self->_parse_event(@_);
  croak "An event must be named" if $ev eq '';
  return ( $ev, $ns );
}

sub _add_listener {
  my ( $self, $event, $listener, $once ) = @_;
  my ( $ev, $ns ) = $self->_parse_named_event($event);
  push @{ $self->_listeners->{$ev} },
   { cb => $listener, ev => $event, ns => $ns, once => $once };
  my $ns_set = $self->_namespaces;
  $ns_set->{$_}{$ev}++ for keys %$ns;
  $self->emit( 'new_listener', $event, $listener, $once );
  return $self;
}

sub add_listener {
  my ( $self, $event, $listener ) = @_;
  return $self->_add_listener( $event, $listener, 0 );
}

sub on { shift->add_listener(@_) }

sub once {
  my ( $self, $event, $listener ) = @_;
  return $self->_add_listener( $event, $listener, 1 );
}

sub _remove_like {
  my ( $self, $chain, $like ) = @_;
  my @new_chain = ();
  for my $li (@$chain) {
    if ( $like->($li) ) {
      $self->emit( 'remove_listener', $li->{ev}, $li->{cb}, $li->{once} );
      next;
    }
    push @new_chain, $li;
  }
  @$chain = @new_chain;
}

sub _expand_namespaces {
  my ( $self, $nss ) = @_;
  my $nsmap = $self->_namespaces;
  my %set   = ();
  for my $ns ( keys %$nss ) {
    $set{$_}++ for keys %{ $nsmap->{$ns} || {} };
  }
  return keys %set;
}

sub _make_matcher {
  my ( $self, $ns, $listener ) = @_;
  my @nsk = keys %$ns;

  if ( defined $listener && @nsk ) {
    return sub {
      my $li = shift;
      return 1 if $li->{cb} == $listener;
      for my $nsn (@nsk) {
        return 1 if $li->{ns}{$nsn};
      }
      return 0;
    };
  }

  if ( defined $listener ) {
    return sub {
      return shift->{cb} == $listener;
    };
  }

  if (@nsk) {
    return sub {
      my $li = shift;
      for my $nsn (@nsk) {
        return 1 if $li->{ns}{$nsn};
      }
      return 0;
    };
  }

  return sub { 1 };
}

sub _remove_from_chain {
  my ( $self, $ev, $like ) = @_;
  my $chain = $self->_listeners->{$ev};
  return unless defined $chain;
  $self->_remove_like( $chain, $like );
}

sub remove_listener {
  my ( $self, $event, $listener ) = @_;
  my ( $ev, $ns ) = $self->_parse_event($event);
  croak "Must name an event or namespace" unless $ev ne '' || keys %$ns;
  my $like = $self->_make_matcher( $ns, $listener );
  if ( $ev eq '' ) {
    for my $evx ( $self->_expand_namespaces($ns) ) {
      $self->_remove_from_chain( $evx, $like );
    }
    return $self;
  }

  $self->_remove_from_chain( $ev, $like );
  return $self;
}

sub remove_all_listeners {
  my $self = shift;
  unless (@_) {
    %{ $self->_listeners }  = ();
    %{ $self->_namespaces } = ();
    return $self;
  }
  return $self->remove_listener(@_);
}

sub off { shift->remove_all_listeners(@_) }

sub prevent_default { shift->do_default(0) }

sub _emit {
  my ( $self, $event, @args ) = @_;
  my $chain = $self->_listeners->{$event};
  return $self unless defined $chain;
  my $has_once = 0;
  for my $li (@$chain) {
    $li->{cb}(@args);
    $has_once++ if $li->{once};
  }
  $self->_remove_like( $chain, sub { shift->{once} } ) if $has_once;
}

sub emit {
  my ( $self, $event, @args ) = @_;
  croak "Can't use namespaces with emit" if $event =~ /\./;
  $self->do_default(1);
  $self->_emit( $event, @args );
  return $self;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
