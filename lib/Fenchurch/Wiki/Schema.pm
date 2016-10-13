package Fenchurch::Wiki::Schema;

our $VERSION = "0.01";

use v5.10;

use Moose;

use Fenchurch::Adhocument::Schema;
use Fenchurch::Core::DB;

=head1 NAME

Fenchurch::Wiki::Schema - The Wiki Schema

=cut

has dbh => ( is => 'ro', required => 1 );

has schema => (
  is      => 'ro',
  lazy    => 1,
  builder => '_b_schema'
);

has db => (
  is      => 'ro',
  lazy    => 1,
  builder => '_b_db'
);

sub _b_schema {
  my $self = shift;
  return Fenchurch::Adhocument::Schema->new(
    schema => {
      page => {
        table => 'wiki_page',
        pkey  => 'uuid'
      } }
  );
}

sub _b_db {
  my $self = shift;
  return Fenchurch::Core::DB->new(
    dbh    => $self->dbh,
    tables => {
      queue    => 'fenchurch_queue',
      versions => 'fenchurch_versions',
      state    => 'fenchurch_state',
      pending  => 'fenchurch_pending',
      known    => 'fenchurch_known',
    }
  );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
