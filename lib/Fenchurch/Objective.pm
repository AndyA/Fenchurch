package Fenchurch::Objective;

our $VERSION = "0.01";

use v5.10;

use Moose;
use Moose::Util::TypeConstraints;
use Moose::Meta::Class;

use Class::MOP;
use Class::MOP::Method;
use Class::Load qw( load_class );
use Fenchurch::Objective::Instance;

=head1 NAME

Fenchurch::Objective - Wrap Fenchurch data as objects

=cut

has engine => (
  is       => 'ro',
  isa      => duck_type( ['db', 'schema'] ),
  required => 1,
  handles  => ['db', 'schema', 'delete', 'exists'],
);

has ['_class_cache', '_meta_cache'] => (
  is      => 'ro',
  isa     => 'HashRef',
  default => sub { {} },
);

sub _make_spec_and_meta {
  my ( $self, $kind ) = @_;

  my $spec = $self->schema->spec_for($kind);
  my $meta = $self->db->meta_for( $spec->{table} );
  my %cols = %{ $meta->{columns} };
  # Don't generate attributes for foreign keys
  delete $cols{$_} for values %{ $spec->{child_of} // {} };
  return [$spec, $meta, \%cols];
}

sub _spec_and_meta {
  my ( $self, $kind ) = @_;
  return @{ $self->_meta_cache->{$kind} //=
     $self->_make_spec_and_meta($kind) };
}

sub _load_instance {
  my ( $self, $instance ) = @_;

  return unless defined $instance;

  load_class($instance);

  my $ins_meta = Class::MOP::class_of($instance);

  $ins_meta->make_mutable;
  return $ins_meta;
}

sub _make_class_for_kind {
  my ( $self, $kind ) = @_;

  my ( $spec, $meta, $cols ) = $self->_spec_and_meta($kind);

  my $ins_meta = $self->_load_instance( $spec->{instance} );

  my @super
   = defined $ins_meta
   ? $ins_meta->superclasses
   : ("Fenchurch::Objective::Instance");

  my $class
   = Moose::Meta::Class->create_anon_class( superclasses => [@super] );

  while ( my ( $col, $info ) = each %$cols ) {
    $class->add_attribute( $col, is => 'rw', required => 1 );
  }

  while ( my ( $child, $info ) = each %{ $spec->{children} // {} } ) {
    my $child_class = $self->_class_for_kind( $info->{kind} )->name;
    $class->add_attribute(
      $child,
      is       => 'rw',
      isa      => "ArrayRef[$child_class]",
      required => 1,
      default  => sub { [] },
    );
  }

  $class->add_method(
    "get_data",
    Class::MOP::Method->wrap(
      sub {
        my $self = shift;
        my $d    = {};
        $d->{$_} = $self->$_() for keys %$cols;
        while ( my ( $child, $info ) = each %{ $spec->{children} // {} } ) {
          $d->{$child} = [map { $_->get_data } @{ $self->$child() }];
        }
        return $d;
      },
      name                 => "get_data",
      package_name         => __PACKAGE__,
      associated_metaclass => $class
    )
  );

  $class->make_immutable;

  return $class unless defined $ins_meta;

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

  my @data = ();
  for my $obj (@$objects) {
    unless ( defined $obj && blessed $obj) { push @data, $obj; next }
    push @data, $obj->get_data;
  }

  return \@data;
}

sub save {
  my ( $self, $kind, @docs ) = @_;
  return $self->engine->save( $kind,
    @{ $self->_get_data( $kind, \@docs ) } );
}

{
  my @METHODS = qw(
   load
   deepen
   query
   load_by_key
  );

  my $meta = __PACKAGE__->meta;
  for my $method (@METHODS) {
    $meta->add_method(
      $method,
      Class::MOP::Method->wrap(
        sub {
          my ( $self, $kind, @args ) = @_;
          return $self->_make_objects( $kind,
            $self->engine->$method( $kind, @args ) );
        },
        name                 => $method,
        package_name         => __PACKAGE__,
        associated_metaclass => $meta
      )
    );
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
