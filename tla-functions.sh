# This is not a shell script but should be source for shell function defs.

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
