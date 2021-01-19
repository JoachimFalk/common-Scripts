#! /bin/sh

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
