package Fenchurch::Core::Types;

our $VERSION = "0.01";

use Fenchurch::Moose;
use Moose::Util::TypeConstraints;
use URI;

=head1 NAME

Fenchurch::Core::Types - Type coercions

=cut

subtype 'HashRefMayBeArrayRef', as 'HashRef[Str]';

coerce 'HashRefMayBeArrayRef', from 'ArrayRef[Str]', via {
  my $out  = {};
  my @list = @{ $_[0] };
  die "HashRefMayBeArrayRef requires an even number of list elements"
   if @list % 2;
  while (@list) {
    my ( $key, $value ) = splice @list, 0, 2;
    die "Value already seen for $key" if exists $out->{$key};
    $out->{$key} = $value;
  }
  return $out;
};

subtype 'Fenchurch::URI' => as class_type('URI');

coerce
 'Fenchurch::URI' => ( from 'Object' => via { $_ } ),
 ( from 'Str' => via { URI->new( $_, 'http' ) } );

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
