# -*- tab-width:8; indent-tabs-mode:nil; c-basic-offset:2; -*-
# vim: set sw=2 ts=8 et:
#
# Copyright (c)
#   2010 FAU -- Joachim Falk <joachim.falk@fau.de>
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

function barf {
  echo "Internal error in tla-functions.sh" 1>&2
  exit -1
}

function tla_tag_top_project {
  local topdir="$1"
  local tagname="$2"
  local summary="$3"
  local TMPDIR=`mktemp -d`
  
  test x"$TMPDIR" != x"" -a -d "$TMPDIR" || barf
  
  "$topdir/forall-projects.sh" tla changes | tee "$TMPDIR/changes.log" || barf
  
  if grep '^[^#]' "$TMPDIR/changes.log" > /dev/null; then
    echo "There are local changes. Exiting..."
    exit 1
  fi
  
  cd "$topdir" && tla tag `tla tree-id` "$tagname" || barf
  tla get "$tagname" "$TMPDIR/top" || barf
  tla cat-config --snap "$topdir/config" > "$TMPDIR/top/config" || barf
  cd "$TMPDIR/top" && tla commit -s "* $summary" || barf
  rm -rf "$TMPDIR";
}
