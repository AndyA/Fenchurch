#!/bin/bash

function load {
  local db="$1"
  local file="$2"

  echo "Loading $db"
  echo "DROP DATABASE IF EXISTS $db; CREATE DATABASE $db;" | mysql -uroot
  mysql -uroot $db < $file
}

load test_adhocument_local  "sql/testdb.sql"
load test_adhocument_remote "sql/testdb.sql"
load fenchurch_wiki         "sql/fenchurch_wiki.sql"

# vim:ts=2:sw=2:sts=2:et:ft=sh

