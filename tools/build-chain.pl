#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use lib qw( t/lib );

use TestSupport;

my $db = database;
make_data( $db, "test_chain_linear", name_factory(), 10000, 0.00,
  undef );
make_data( $db, "test_chain", name_factory(), 2000, 0.01, undef );

sub make_data {
  my ( $db, $table, $namer, $length, $branch_prob, $parent ) = @_;
  empty $table;
  return make_chain( $db, $table, $namer, $length, $branch_prob, $parent );
}

=for ref

CREATE TABLE `test_chain` (
  `uuid` varchar(36) NOT NULL,
  `parent` varchar(36) NULL,
  `when` datetime NOT NULL,
  `name` varchar(200) NOT NULL,
  PRIMARY KEY (`uuid`),
  KEY `test_chain_parent` (`parent`),
  KEY `test_chain_when` (`when`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

=cut

sub make_chain {
  my ( $db, $table, $namer, $length, $branch_prob, $parent ) = @_;

  for ( 1 .. $length ) {

    my $name = $namer->();
    my $uuid = make_uuid();

    say "$table: $uuid: $name";

    $db->do(
      join( " ",
        "INSERT INTO `$table` (`uuid`, `parent`, `name`, `when`, `rand`)",
        "VALUES (?, ?, ?, NOW(), RAND())" ),
      {},
      $uuid, $parent, $name
    );

    for ( 1 .. 5 ) {
      make_chain( $db, $table, name_factory($name),
        int( rand() * $length / 20 ),
        $branch_prob, $uuid )
       if rand() < $branch_prob;
    }

    $parent = $uuid;
  }

  return $parent;
}

sub name_factory {
  my @prefix = @_;
  my $next   = 0;
  sub { join ": ", @prefix, "Node", ++$next }
}
