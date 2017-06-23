package Fenchurch::Util;

use strict;
use warnings;

use base qw( Exporter );

our @EXPORT_OK = qw( tidy trim unique );
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );

=head1 NAME

Fenchurch::Util - Utility stuff

=cut

sub tidy {
  my $s = shift;
  s/^\s+//, s/\s+$//, s/\s+/ /g for $s;
  return $s;
}

sub trim {
  my $s = shift;
  s/^\s+//, s/\s+$// for $s;
  return $s;
}

sub unique(@) {
  my %seen = ();
  grep { !$seen{$_}++ } @_;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
