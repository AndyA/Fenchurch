package Fenchurch::Shadow;

our $VERSION = "0.01";

use Moose;

=head1 NAME

Fenchurch::Shadow - Work with shadow_* tables

=cut

with 'Fenchurch::Core::Role::DB';

has prefix => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  default  => 'shadow'
);

has _table_meta => (
  is      => 'ro',
  lazy    => 1,
  builder => '_b_table_meta'
);

sub _b_table_meta {
  my $self   = shift;
  my $prefix = $self->prefix;
  my $meta
   = $self->dbh->selectall_arrayref("SELECT * FROM ${prefix}_x_meta");
  for my $row (@$meta) {
    $row->{indentifying_keys} = [split /\s*,\s*/, $row->{indentifying_keys}];
  }
  return $meta;
}

sub _load_changes {
  my ( $self, $from, $to ) = @_;

  my $prefix = $self->prefix;

  my $index = $self->dbh->selectall_arrayref(
    join( " ",
      "SELECT *",
      "FROM `${prefix}_x_log`",
      "WHERE `id` BETWEEN ? AND ?",
      "ORDER BY `id`" ),
    { Slice => {} },
    $from, $to
  );

  return [] unless @$index;    # Empty?

  # Group by table name
  my $plan = $self->stash_by( $index, "table" );
  my $stash = {};

  # Load from the individual tables
  while ( my ( $table, $info ) = each %$plan ) {
    my @ids = map { $_->{sequence} } @$info;
    $stash->{$table} = $self->dbh->selectall_arrayref(
      join( " ",
        "SELECT *" . "FROM `$table`",
        "WHERE `sequence` IN(",
        join( ", ", map "?", @ids ),
        ") ORDER BY `sequence`" ),
      { Slice => {} },
      @ids
    );
  }

  my @changes = ();
  for my $row (@$index) {
    my $table    = $row->{table};
    my $sequence = $row->{sequence};
    my $event    = shift @{ $stash->{$table} // [] };
    die unless defined $event && $event->{sequence} == $sequence;
    $event->{table} = $table;
    $event->{id}    = $row->{id};
    # Put NEW_*, OLD_* fields in 'new', 'old' hashes.
    for my $key ( keys %$event ) {
      $event->{old}{$1} = delete $event->{$key} if $key =~ /^OLD_(.+)$/;
      $event->{new}{$1} = delete $event->{$key} if $key =~ /^NEW_(.+)$/;
    }
    push @changes, $event;
  }

  return \@changes;
}

sub _reverse_changes {
  my ( $self, $changes ) = @_;
  my @reverse = reverse @$changes;

  my %reverse_verb = (
    INSERT => 'DELETE',
    UPDATE => 'UPDATE',
    DELETE => 'INSERT'
  );

  for my $change (@reverse) {
    @{$change}['old', 'new'] = @{$change}['new', 'old'];
    $change->{verb} = $reverse_verb{ $change->{verb} };
  }

  return \@reverse;
}

1;
