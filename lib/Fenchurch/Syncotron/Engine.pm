package Fenchurch::Syncotron::Engine;

use v5.10;

our $VERSION = "0.01";

use Moose;
use Moose::Util::TypeConstraints;

has versions => (
  is       => 'ro',
  isa      => duck_type( ['load', 'save'] ),
  required => 1,
  handles => ['db', 'dbh'],
);

=head1 NAME

Fenchurch::Syncotron::Engine - The guts of the sync engine

=cut

=head2 C<serial>

Get the current serial number

=cut

sub serial {
  my $self = shift;

  my ($serial)
   = $self->dbh->selectrow_array(
    $self->db->quote_sql("SELECT MAX({serial}) FROM {:versions}") );

  return $serial // 0;
}

=head2 C<leaves>

Return a page of the leaf nodes of the version tree.

=cut

sub leaves {
  my ( $self, $start, $size ) = @_;

  return @{
    $self->dbh->selectcol_arrayref(
      $self->db->quote_sql(
        "SELECT {tc1.uuid}",
        "FROM {:versions} AS {tc1}",
        "LEFT JOIN {:versions} AS {tc2} ON {tc2.parent} = {tc1.uuid}",
        "WHERE {tc2.parent} IS NULL",
        "ORDER BY {tc1.serial} ASC",
        "LIMIT ?, ?"
      ),
      {},
      $start, $size
    ) };
}

=head2 C<sample>

Return a random sample of nodes.

=cut

sub sample {
  my ( $self, $start, $size ) = @_;

  return @{
    $self->dbh->selectcol_arrayref(
      $self->db->quote_sql(
        "SELECT {tc1.uuid}",
        "FROM {:versions} AS {tc1}, {:versions} AS {tc2}",
        "WHERE {tc2.parent} = {tc1.uuid}",
        "ORDER BY {tc1.rand} ASC",
        "LIMIT ?, ?"
      ),
      {},
      $start, $size
    ) };
}

=head2 C<since>

Return the IDs of changes subsequent to a specific serial.

=cut

sub since {
  my ( $self, $index, $limit ) = @_;

  return @{
    $self->dbh->selectcol_arrayref(
      $self->db->quote_sql(
        "SELECT {uuid} FROM {:versions}",
        ( defined $index
          ? ("WHERE {serial} > ?")
          : ()
        ),
        "ORDER BY {serial} ASC",
        ( defined $limit ? ("LIMIT ?") : () )
      ),
      { Slice => {} },
      grep defined,
      $index, $limit
    ) };
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
