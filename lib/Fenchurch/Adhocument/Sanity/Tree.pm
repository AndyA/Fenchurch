package Fenchurch::Adhocument::Sanity::Tree;

our $VERSION = "0.01";

use v5.10;

use Moose;

use Storable qw( dclone );

=head1 NAME

Fenchurch::Adhocument::Sanity::Tree - Walk the version tree looking for inconsitencies

=cut

has since => (
  is       => 'ro',
  isa      => 'Int',
  required => 1
);

has _by_uuid => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_b_by_uuid'
);

has _tree => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_b_tree'
);

has _by_object => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_b_by_object'
);

with qw(
 Fenchurch::Core::Role::DB
 Fenchurch::Core::Role::Group
 Fenchurch::Adhocument::Role::VersionEngine
 Fenchurch::Adhocument::Sanity::Role::Report
);

sub _b_by_uuid {
  my $self  = shift;
  my $table = $self->table;

  return $self->stash_by(
    $self->db->selectall_arrayref(
      [ "SELECT {uuid}, {parent}, {kind}, {object}, {sequence}",
        "  FROM {$table}",
        " WHERE {serial} >= ?"
      ],
      { Slice => {} },
      $self->since
    ),
    'uuid'
  );
}

sub _mark_tree {
  my ( $self, $node, @path ) = @_;
  $node->{path} = join "/", @path;
  while ( my ( $kuuid, $knode ) = each %{ $node->{children} // {} } ) {
    $self->_mark_tree( $knode, @path, $kuuid );
  }
}

sub _b_tree {
  my $self = shift;

  my $vers = dclone $self->_by_uuid;
  my $root = {};
  while ( my ( $uuid, $nodes ) = each %$vers ) {
    $self->report->log("Multiple nodes with UUID $uuid")
     unless @$nodes == 1;
    my $node   = $nodes->[0];
    my $parent = $node->{parent} // "ROOT";
    my $pn     = $vers->{$parent} // [$root->{children}{$parent} //= {}];
    $pn->[0]{children}{$uuid} = $node;
  }
  $self->_mark_tree($root);
  return $root;
}

sub _build_by_object {
  my ( $self, $node, $stash ) = @_;
  push @{ $stash->{ $node->{object} } }, $node if defined $node->{object};
  while ( my ( $kuuid, $knode ) = each %{ $node->{children} // {} } ) {
    $self->_build_by_object( $knode, $stash );
  }
}

sub _b_by_object {
  my $self = shift;

  my $stash = {};
  $self->_build_by_object( $self->_tree, $stash );
  my $out = {};
  while ( my ( $object, $versions ) = each %$stash ) {
    $out->{$object}
     = [sort { $a->{sequence} <=> $b->{sequence} } @$versions];
  }
  return $out;
}

sub check_structure {
  my $self = shift;

  my $by_object = $self->_by_object;
  for my $object ( sort keys %$by_object ) {
    my $versions = $by_object->{$object};
    my $path     = undef;
    for my $ver (@$versions) {
      $self->report->log("$ver->{uuid} is not a descendent of $path")
       if defined $path && $ver->{path} !~ /^\Q$path/;
      $path = $ver->{path};
    }
  }
}

sub check {
  my $self = shift;
  $self->check_structure;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
