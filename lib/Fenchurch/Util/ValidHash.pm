package Fenchurch::Util::ValidHash;

our $VERSION = "1.00";

use Fenchurch::Moose;

use Carp qw( confess );

=head1 NAME

Fenchurch::Util::ValidHash - Validate a hash

=cut

has required => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );
has optional => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );

sub validate {
  my ( $self, $hash ) = @_;
  my %all = map { $_ => 1 } @{ $self->required }, @{ $self->optional };
  my @missing = grep { !exists $hash->{$_} } @{ $self->required };
  my @extra   = grep { !$all{$_} } keys %$hash;
  if ( @missing || @extra ) {
    my @msg = ();

    push @msg,
       "the following required key"
     . ( @missing == 1 ? " is" : "s are" )
     . " missing: "
     . join( ', ', map "'$_'", sort @missing )
     if @missing;

    push @msg,
       "the following unknown key"
     . ( @extra == 1 ? " was" : "s were" )
     . " found: "
     . join( ', ', map "'$_'", sort @extra )
     if @extra;

    confess ucfirst join ', and ', @msg;
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
