#!/bin/bash

sql="sql/testdb.sql"

for db in test_adhocument_local test_adhocument_remote; do
  echo "Loading $db"
  echo "DROP DATABASE IF EXISTS $db; CREATE DATABASE $db;" | mysql -uroot
  mysql -uroot $db < $sql
done

# vim:ts=2:sw=2:sts=2:et:ft=sh

