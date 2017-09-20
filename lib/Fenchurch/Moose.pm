package Fenchurch::Moose;

use 5.24.0;
use Moose                     ();
use MooseX::StrictConstructor ();
use Moose::Exporter;
use mro     ();
use feature ();

Moose::Exporter->setup_import_methods(
  with_meta => ['has'],
  also      => ['Moose'],
);

sub init_meta {
  my ( $class, @args ) = @_;
  my %params = @args;
  Moose->init_meta(@args);
  MooseX::StrictConstructor->import( { into => $params{for_class} } );
  warnings->unimport('experimental::signatures');
  feature->import(qw/signatures :5.24/);
  mro::set_mro( scalar caller(), 'c3' );
}

sub has {
  my ( $meta, $name, %options ) = @_;

  $options{is} //= 'ro';

  # "has [@attributes]" versus "has $attribute"
  foreach ( 'ARRAY' eq ref $name ? @$name : $name ) {
    $meta->add_attribute( $_, %options );
  }
}

1;
