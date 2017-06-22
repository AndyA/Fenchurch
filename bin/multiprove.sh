#!/bin/bash

find dbd_mysql -maxdepth 1 -mindepth 1 -type d | sort -u | while read dbd; do
  echo "Testing against $dbd";
  prove -I$dbd/blib/lib -I$dbd/blib/arch -Ilib -r t
done
  

# vim:ts=2:sw=2:sts=2:et:ft=sh

