package Fenchurch::Core::DB;

use Moose;

=head1 NAME

Fenchurch::Core::DB - Database handling

=cut

has dbh => ( is => 'ro', isa => 'DBI::db', required => 1 );

has _meta_cache => (
  is       => 'ro',
  isa      => 'HashRef',
  required => 1,
  default  => sub { {} }
);

sub quote_name {
  my ( $self, @name ) = @_;
  return join ".", map "`$_`", @name;
}

sub quote_sql {
  my $self = shift;
  ( my $sql = join " ", @_ )
   =~ s/\{(\w+(?:\.\w+)*)\}/$self->quote_name(split qr{[.]}, $1)/eg;
  return $sql;
}

sub _meta_for {
  my ( $self, $table ) = @_;
  my $rc
   = $self->dbh->selectall_arrayref(
    join( ' ', 'DESCRIBE', $self->quote_name($table) ),
    { Slice => {} } );

  my %columns = ();
  my @pkey    = ();

  for my $col (@$rc) {
    my $name = $col->{Field};
    my $pri = $col->{Key} eq 'PRI' ? 1 : 0;
    push @pkey, $name if $pri;
    $columns{$name} = {
      primary  => $pri,
      type     => $col->{Type},
      default  => $col->{Default},
      nullable => $col->{Null} eq 'YES' ? 1 : 0,
      auto     => $col->{Extra} eq 'auto_increment' ? 1 : 0
    };
  }

  return { columns => \%columns, pkey => \@pkey };
}

sub meta_for {
  my ( $self, $table ) = @_;
  my $mc = $self->_meta_cache;
  return ( $mc->{$table} //= $self->_meta_for($table) );
}

sub columns_for {
  my ( $self, $table ) = @_;
  my $meta = $self->meta_for($table);
  return sort keys %{ $meta->{columns} };
}

sub numeric_columns_for {
  my ( $self, $table ) = @_;
  my $meta = $self->meta_for($table);
  my $cols = $meta->{columns};
  return sort grep {
    $cols->{$_}{type} =~ /^ (?: decimal | double | float | int |
                              (?: big | medium | small | tiny ) int)/x
  } keys %$cols;
}

sub settable_columns_for {
  my ( $self, $table ) = @_;
  my $meta = $self->meta_for($table);
  my $cols = $meta->{columns};
  return sort grep { !$cols->{$_}{auto} } keys %$cols;
}

sub pkey_for {
  my ( $self, $table ) = @_;
  my $meta = $self->meta_for($table);
  return sort @{ $meta->{pkey} };
}

sub parse_order {
  my ( $self, $order ) = @_;
  my @term = ();
  for my $fld ( split /\s*,\s*/, $order ) {
    my ( $dir, $fname )
     = $fld =~ m{^([-+])(.+)} ? ( $1, $2 ) : ( '+', $fld );
    push @term, join ' ', $self->quote_name($fname),
     $dir eq '+' ? 'ASC' : 'DESC';
  }
  return join( ', ', @term );
}

sub _group_by {
  my ( $self, $del, $rows, @keys ) = @_;
  return $rows unless @keys;
  my $leaf = pop @keys;
  my $hash = {};
  for my $row (@$rows) {
    next unless defined $row;
    my $rr   = {%$row};    # clone
    my $slot = $hash;
    if ($del) {
      $slot = ( $slot->{ delete $rr->{$_} } ||= {} ) for @keys;
      push @{ $slot->{ delete $rr->{$leaf} } }, $rr;
    }
    else {
      $slot = ( $slot->{ $rr->{$_} } ||= {} ) for @keys;
      push @{ $slot->{ $rr->{$leaf} } }, $rr;
    }
  }
  return $hash;

}

sub group_by { return shift->_group_by( 1, @_ ) }
sub stash_by { return shift->_group_by( 0, @_ ) }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
