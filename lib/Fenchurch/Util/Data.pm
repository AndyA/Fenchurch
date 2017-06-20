package Fenchurch::Util::Data;

our $VERSION = "1.00";

use v5.10;

use strict;
use warnings;

use base qw( Exporter );

our @EXPORT_OK = qw( flatten );
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );

=head1 NAME

Fenchurch::Core::Util::Data - Low level data mungging

=head2 C<< flatten >>

Return a list consisting of all the passed arguments. Any ARRAY refs in the
argument list will have been flattened into the returned list.

=cut

sub flatten(@) {
  my @out = ();
  for my $i (@_) {
    if ( ref $i ) {
      die "Not an array reference" unless 'ARRAY' eq ref $i;
      push @out, @$i;
      next;
    }
    push @out, $i;
  }
  return @out;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
