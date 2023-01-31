#! /bin/sh
# -*- tab-width:8; indent-tabs-mode:nil; c-basic-offset:2; -*-
# vim: set sw=2 ts=8 et:
#
# Copyright (c)
#   2010 FAU -- Joachim Falk <joachim.falk@fau.de>
#   2010 FAU -- Martin Streubuehr <martin.streubuehr@fau.de>
#   2015 FAU -- Joachim Falk <joachim.falk@fau.de>
#   2015 Joachim Falk <joachim.falk@gmx.de>
#   2021 FAU -- Joachim Falk <joachim.falk@fau.de>
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA 02111-1307 USA.

if test -L "$0"; then
  SCRIPTS_DIR=`readlink -f "$0"`
  SCRIPTS_DIR=`dirname "$SCRIPTS_DIR"`
else
  SCRIPTS_DIR=`dirname "$0"`
  SCRIPTS_DIR=`cd "$SCRIPTS_DIR" && pwd -P`
fi

PATH=$SCRIPTS_DIR:$PATH
#echo $PATH

BASE=.

EXEC="$@"

while ! test -d .git -o -f .git; do
  cd ..
  if test x"`pwd`" = x"/"; then
    echo "Can't find git repository!"
    exit 255;
  fi
done

# git stuff

git_recurse() {
  local BASE=$1;
  ( cd "$BASE" && eval $EXEC )
  echo
  ( cd "$BASE" && git submodule ) | \
    while read subline; do
      case "$subline" in
        "+"*)
          # Is dirty
          STATUS="+"
          subline="${subline#?}"
          ;;
        *)
          # Is clean
          STATUS=" "
          ;;
      esac
      HASH="${subline%% *}"; subline="${subline#* }"
      DIR="${subline%% *}";  subline="${subline#* (}"
      SYM="${subline%)*}"
      if test -f "$BASE/$DIR/.git" -o -d "$BASE/$DIR/.git"; then
        echo "### ${STATUS}${HASH} $BASE/$DIR (${SYM})"
        git_recurse "$BASE/$DIR"
      fi
    done
}

# Do git stuff
( cd $BASE;
  if test x"`git status -s`" = x""; then
    # Is clean
    STATUS=" "
  else
    # Is dirty
    STATUS="+"
  fi
  # Get the hash
  HASH=`git show --pretty=oneline --shortstat HEAD | sed -ne '1,1{s/ .*//;p}'`
  # Get the symbolic name
  SYM=`git describe --all`
  echo "### ${STATUS}${HASH} $BASE (${SYM})"
)
git_recurse "$BASE"
