# /bin/bash

for i in {0..255} ; do
    printf "\x1b[48;5;%sm%3d\e[0m " "$i" "$i"
    if (( i == 15 )) || (( i > 15 )) && (( (i-15) % 6 == 0 )); then
        printf "\n";
    fi
done

# Test 256 color support along with bold and dim attributes.
# Copyright (C) 2014  Egmont Koblinger
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

format_number() {
  local c=$'\u254F'
  if [ $1 -lt 10 ]; then
    printf "$c %d" $1
  else
    printf "$c%02d" $(($1%100))
  fi
}

somecolors() {
  local from="$1"
  local to="$2"
  local prefix="$3"
  local line

  for line in \
      "[2m" \
      "" \
      "[1m" \
      "[1;2m"; do
    echo -ne "\e$line"
    i=$from
    while [ $i -le $to ]; do
      echo -ne "\e[$prefix${i}m"

      echo -n "  "
      [ "$line" ] && echo -n "\\033${line}"
      echo -n  "\\033[$prefix${i}m "

      #format_number $i
      i=$((i+1))
    done
    echo $'\e[0m\e[K'
  done
}

allcolors() {
  echo "-- 8 standard colors: SGR ${1}0..${1}7 --"
  somecolors 0 7 "$1"
  echo
  echo "-- 8 bright colors: SGR ${2}0..${2}7 --"
  somecolors 0 7 "$2"
  echo
  echo "-- 256 colors: SGR ${1}8;5;0..255 --"
  somecolors 0 15 "${1}8;5;"
  echo
  somecolors  16  51 "${1}8;5;"
  somecolors  52  87 "${1}8;5;"
  somecolors  88 123 "${1}8;5;"
  somecolors 124 159 "${1}8;5;"
  somecolors 160 195 "${1}8;5;"
  somecolors 196 231 "${1}8;5;"
  echo
  somecolors 232 255 "${1}8;5;"
}

allcolors 3 9
echo
allcolors 4 10

