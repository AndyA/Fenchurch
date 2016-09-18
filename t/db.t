#!perl

use strict;
use warnings;

use lib qw( t/lib );

use JSON;
use Test::Differences;
use Test::More;
use TestSupport;

use Fenchurch::Core::DB;

preflight;

{
  my $db = Fenchurch::Core::DB->new( dbh => database );
  my $meta_want = {
    columns => {
      _modified => {
        auto     => 0,
        primary  => 0,
        default  => undef,
        type     => "datetime",
        nullable => 0
      },
      _parent => {
        auto     => 0,
        nullable => 1,
        primary  => 0,
        default  => undef,
        type     => "varchar(36)"
      },
      episode => {
        auto     => 0,
        nullable => 1,
        default  => undef,
        primary  => 0,
        type     => "int(11)"
      },
      issue_key => {
        auto     => 0,
        primary  => 0,
        default  => undef,
        type     => "varchar(48)",
        nullable => 0
      },
      _uuid => {
        auto     => 0,
        type     => "varchar(36)",
        default  => undef,
        primary  => 1,
        nullable => 0
      },
      title => {
        auto     => 0,
        nullable => 0,
        type     => "varchar(256)",
        primary  => 0,
        default  => undef
      },
      synopsis => {
        auto     => 0,
        type     => "text",
        primary  => 0,
        default  => undef,
        nullable => 1
      },
      duration => {
        auto     => 0,
        default  => undef,
        primary  => 0,
        type     => "int(10) unsigned",
        nullable => 0
      },
      broadcast_date => {
        auto     => 0,
        nullable => 1,
        primary  => 0,
        default  => undef,
        type     => "date"
      },
      service_key => {
        auto     => 0,
        nullable => 1,
        type     => "varchar(48)",
        primary  => 0,
        default  => undef
      },
      text => {
        auto     => 0,
        nullable => 1,
        type     => "text",
        primary  => 0,
        default  => undef
      },
      _key => {
        auto     => 0,
        nullable => 0,
        primary  => 0,
        default  => undef,
        type     => "varchar(48)"
      },
      footnote => {
        auto     => 0,
        nullable => 1,
        type     => "text",
        default  => undef,
        primary  => 0
      },
      date => {
        auto     => 0,
        default  => undef,
        primary  => 0,
        type     => "date",
        nullable => 1
      },
      source => {
        auto     => 0,
        type     => "varchar(36)",
        default  => undef,
        primary  => 0,
        nullable => 0
      },
      service => {
        auto     => 0,
        nullable => 1,
        primary  => 0,
        default  => undef,
        type     => "varchar(36)"
      },
      day => {
        auto     => 0,
        nullable => 0,
        type     => "int(11)",
        primary  => 0,
        default  => undef
      },
      _created => {
        auto     => 0,
        type     => "datetime",
        default  => undef,
        primary  => 0,
        nullable => 0
      },
      episode_title => {
        auto     => 0,
        type     => "varchar(256)",
        default  => undef,
        primary  => 0,
        nullable => 1
      },
      _edit_id => {
        auto     => 0,
        nullable => 1,
        primary  => 0,
        default  => undef,
        type     => "int(10)"
      },
      when => {
        auto     => 0,
        primary  => 0,
        default  => undef,
        type     => "datetime",
        nullable => 0
      },
      page => {
        auto     => 0,
        type     => "int(11)",
        primary  => 0,
        default  => undef,
        nullable => 1
      },
      issue => {
        auto     => 0,
        nullable => 0,
        type     => "varchar(36)",
        default  => undef,
        primary  => 0
      },
      month => {
        auto     => 0,
        default  => undef,
        primary  => 0,
        type     => "int(11)",
        nullable => 0
      },
      year => {
        auto     => 0,
        primary  => 0,
        default  => undef,
        type     => "int(11)",
        nullable => 0
      },
      type => {
        auto     => 0,
        nullable => 1,
        default  => undef,
        primary  => 0,
        type     => "varchar(48)"
      },
      listing => {
        auto     => 0,
        nullable => 1,
        type     => "varchar(36)",
        primary  => 0,
        default  => undef
      }
    },
    pkey => ["_uuid"] };

  my @pkey_want = sort @{ $meta_want->{pkey} };
  my @cols_want = sort keys %{ $meta_want->{columns} };
  my @ncols_want
   = ( '_edit_id', 'day', 'duration', 'episode', 'month', 'page', 'year' );

  my $meta = $db->meta_for('test_programmes_v2');
  eq_or_diff $meta, $meta_want, "table meta matches";

  my @cols = $db->columns_for('test_programmes_v2');
  eq_or_diff [@cols], [@cols_want], "columns match";

  my @ncols = $db->numeric_columns_for('test_programmes_v2');
  eq_or_diff [@ncols], [@ncols_want], "numeric columns match";

  my @pkey = $db->pkey_for('test_programmes_v2');
  eq_or_diff [@pkey], [@pkey_want], "pkeys match";
}

done_testing;

# vim:ts=2:sw=2:et:ft=perl
