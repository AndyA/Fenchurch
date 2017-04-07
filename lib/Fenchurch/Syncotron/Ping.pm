package Fenchurch::Syncotron::Ping;

our $VERSION = "0.01";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;

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
  my ( $self, @ping ) = @_;
  $self->engine->save( ping => @ping );
}

sub get_all {
  my $self = shift;
  return @{ $self->engine->load( ping => '*' ) };
}

sub get_for_remote {
  my ( $self, $remote_node ) = @_;

  my @pings = $self->get_all;
  my @out   = ();

  for my $ping (@pings) {
    $ping->{ttl}--;
    next if $ping->{ttl} <= 0;
    next if $ping->{origin_node} eq $remote_node;

    my %seen = map { $_->{node} => 1 } @{ $ping->{path} };
    next if $seen{$remote_node};

    push @{ $ping->{path} },
     {node => $remote_node,
      time => time,
     };

    push @out, $ping;
  }

  return @out;
}

sub make_ping {
  my ( $self, %ping ) = @_;

  return {
    origin_node => $self->node_name,
    ttl         => $self->ttl,
    path        => [
      { node => $self->node_name,
        time => time,
      }
    ],
    status => {},
    %ping
  };
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
