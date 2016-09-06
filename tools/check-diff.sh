#!/bin/bash

same=diff/same
mkdir -p "$same"

find diff/ne -name '*.a.json' | sort | while read a_file; do
  b_file=${a_file/a.json/b.json}
  info=${a_file/a.json/info}
  if diff  "$a_file" "$b_file" > /dev/null; then
    mv "$a_file" "$b_file" "$info" "$same"
  fi
done

# vim:ts=2:sw=2:sts=2:et:ft=sh

