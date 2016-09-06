package Lintilla::Core::Util::ValidHash;

use Moose;

use Carp qw( croak );

=head1 NAME

Lintilla::Core::Util::ValidHash - Validate a hash

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

    croak ucfirst join ', and ', @msg;
  }
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
