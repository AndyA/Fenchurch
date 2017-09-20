package Fenchurch::Util::Compare;

our $VERSION = "1.00";

use Fenchurch::Module;

use Scalar::Util qw( looks_like_number );

use base qw( Exporter );

our @EXPORT_OK = qw( same );
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );

=head1 NAME

Fenchurch::Util::Compare - Deep comparison

=cut

sub same {
  my ( $a, $b ) = @_;

  return 1 unless defined $a || defined $b;
  return unless defined $a && defined $b;

  unless ( ref $a || ref $b ) {
    return $a == $b
     if looks_like_number($a)
     && looks_like_number($b);
    return $a eq $b;
  }

  return unless ref $a && ref $b;
  return unless ref $a eq ref $b;

  if ( "ARRAY" eq ref $a ) {
    my $len = $#$a;
    return unless $#$b == $len;
    for my $i ( 0 .. $len ) {
      return unless same( $a->[$i], $b->[$i] );
    }
    return 1;
  }

  if ( "HASH" eq ref $a ) {
    my @ka = sort keys %$a;
    my @kb = sort keys %$b;
    return unless same( \@ka, \@kb );
    for my $key (@ka) {
      return unless same( $a->{$key}, $b->{$key} );
    }
    return 1;
  }

  die "Can't compare ", ref $a;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
