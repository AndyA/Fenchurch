#!/bin/bash

in="proto"
out="public"

find "$in" -not -name '.*' -type f | while read src; do
  dst="$out/$( basename "$src" )"
  if [ "$src" -nt "$dst" ]; then
    echo "$src -> $dst"
    perl bin/fix-shebang.pl "$src" "$dst"
  fi
done

# vim:ts=2:sw=2:sts=2:et:ft=sh

