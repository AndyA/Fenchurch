package Fenchurch::Objective;

our $VERSION = "0.01";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;
use Moose::Meta::Class;

use Class::MOP;
use Class::Load qw( load_class );
use Fenchurch::Objective::Instance;

=head1 NAME

Fenchurch::Objective - Wrap Fenchurch data as objects

=cut

has engine => (
  is       => 'ro',
  isa      => duck_type( ['db', 'schema'] ),
  required => 1,
  handles => ['db', 'schema'],
);

has _class_cache => (
  is      => 'ro',
  isa     => 'HashRef',
  default => sub { {} },
);

sub _spec_and_meta {
  my ( $self, $kind ) = @_;
  my $spec = $self->schema->spec_for($kind);
  my $meta = $self->db->meta_for( $spec->{table} );
  my %cols = %{ $meta->{columns} };
  # Don't generate attributes for foreign keys
  delete $cols{$_} for values %{ $spec->{child_of} // {} };
  return ( $spec, $meta, \%cols );
}

sub _make_class_for_kind {
  my ( $self, $kind ) = @_;

  my ( $spec, $meta, $cols ) = $self->_spec_and_meta($kind);

  my $class = Moose::Meta::Class->create_anon_class(
    superclasses => ["Fenchurch::Objective::Instance"] );

  while ( my ( $col, $info ) = each %$cols ) {
    $class->add_attribute( $col, is => 'rw', required => 1 );
  }

  while ( my ( $child, $info ) = each %{ $spec->{children} // {} } ) {
    $class->add_attribute( $child, is => 'rw', required => 1 );
  }

  $class->make_immutable;

  my $instance = $spec->{instance};
  return $class unless defined $instance;

  load_class($instance);

  my $ins_meta = Class::MOP::class_of($instance);

  $ins_meta->make_mutable;
  $ins_meta->superclasses( $class->name );
  $ins_meta->make_immutable;

  return $ins_meta;
}

sub _class_for_kind {
  my ( $self, $kind ) = @_;
  return $self->_class_cache->{$kind} //=
   $self->_make_class_for_kind($kind);
}

sub _make_objects {
  my ( $self, $kind, $objects ) = @_;

  my @obj   = ();
  my $class = $self->_class_for_kind($kind);
  my $spec  = $self->schema->spec_for($kind);

  for my $data (@$objects) {

    unless ( defined $data ) { push @obj, undef; next }

    my %d = %$data;    # Shallow clone
    my %a = ();        # Constructor args
    while ( my ( $child, $info ) = each %{ $spec->{children} // {} } ) {
      $a{$child} = $self->_make_objects( $info->{kind}, delete $d{$child} );
    }
    push @obj, $class->new_object( %a, %d );
  }
  return \@obj;
}

sub _get_data {
  my ( $self, $kind, $objects ) = @_;

  my ( $spec, $meta, $cols ) = $self->_spec_and_meta($kind);
  my @data = ();

  for my $obj (@$objects) {
    unless ( defined $obj && blessed $obj) { push @data, $obj; next }
    my $d = {};
    $d->{$_} = $obj->$_() for keys %$cols;
    while ( my ( $child, $info ) = each %{ $spec->{children} // {} } ) {
      $d->{$child} = $self->_get_data( $info->{kind}, $obj->$child() );
    }
    push @data, $d;
  }

  return \@data;
}

sub save {
  my ( $self, $kind, @docs ) = @_;
  return $self->engine->save( $kind,
    @{ $self->_get_data( $kind, \@docs ) } );
}

sub load {
  my ( $self, $kind, @args ) = @_;
  return $self->_make_objects( $kind,
    $self->engine->load( $kind, @args ) );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
