package Fenchurch::Syncotron::Ping;

our $VERSION = "0.01";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;

use DateTime::Format::MySQL;
use Storable qw( dclone );
use Time::HiRes qw( time );

=head1 NAME

Fenchurch::Syncotron::Ping - Make, store and query pings

=cut

has engine => (
  is       => 'ro',
  isa      => duck_type( ['load', 'save'] ),
  required => 1,
  handles => ['db', 'dbh'],
);

has ttl => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
  default  => 10
);

with qw(
 Fenchurch::Core::Role::Logger
 Fenchurch::Core::Role::NodeName
);

sub put {
  my ( $self, @pings ) = @_;
  my @save = ();

  for my $ping ( map { dclone $_} @pings ) {
    next if $ping->{ttl} <= 0;
    $ping->{ttl}--;

    push @{ $ping->{path} },
     {node => $self->node_name,
      time => time,
     };

    push @save, $ping;
  }

  $self->engine->save( ping => @save );
}

sub get_all { @{ shift->engine->load( ping => '*' ) } }

sub get_for_remote {
  my ( $self, $remote_node ) = @_;

  my @out   = ();
  my @pings = $self->get_all;

  for my $ping (@pings) {
    next if $ping->{ttl} <= 0;
    next if $ping->{origin_node} eq $remote_node;

    my %seen = map { $_->{node} => 1 } @{ $ping->{path} };
    next if $seen{$remote_node};

    push @out, $ping;
  }

  return @out;
}

sub _ts { DateTime::Format::MySQL->format_datetime( DateTime->now ) }

sub make_ping {
  my ( $self, %ping ) = @_;

  return {
    origin_node => $self->node_name,
    ttl         => $self->ttl,
    when        => $self->_ts,
    path        => [],
    status      => {},
    %ping
  };
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl