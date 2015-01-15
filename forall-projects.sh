#! /bin/sh

SCRIPTS_DIR=`readlink -f "$0"`
SCRIPTS_DIR=`dirname "$SCRIPTS_DIR"`

PATH=$SCRIPTS_DIR:$PATH
#echo $PATH

BASE=.

EXEC="$@"
MODE=""

if test x"$1" = x"tla"; then
  EXEC="$EXEC | grep -v '^\*'"
  MODE="tla"
elif test x"$1" = x"git"; then
  EXEC="$EXEC | grep -v '^# Not currently on any branch\.'"
  MODE="git"
fi
if test x"$MODE" = x""; then
  if test -d "$BASE/.git"; then
    MODE="git"
  else
    MODE="tla"
  fi
fi

# GNU arch (tla) stuff

check_config() {
  local BASE=$1;
  local CONFIG=$2;
  cat $BASE/$CONFIG | \
    sed -e 's/[ 	]*#.*$//' -e '/^$/d' | \
    while read dir arch; do \
      test -d $BASE/$dir && ( \
        CANONLOC=`echo "$BASE/$dir" | sed -e 's@/\(\.\?/\)*@/@g' -e 's@/*$@@'` && \
        cd $CANONLOC && echo "# $CANONLOC	`tla tree-id` from $BASE/$CONFIG"; \
        case `tla tree-id` in \
          ${arch}|${arch}--*) \
            ;; \
          *) \
            echo "Branch missmatch, please get new branch via:"; \
            echo " tla get $arch $dir !"; \
            ;; \
        esac; \
        eval $EXEC ); \
    done
}

test_config() {
  local BASE=$1;
  local CONFIG=$2;
  if ! sed -e 's/[ 	]*#.*$//' -e '/^$/d' $BASE/$CONFIG | \
    grep -v '^[a-zA-Z0-9+./_-]\+[ 	]\+[^@]\+@[^@]\+--\([a-zA-Z0-9_]\|-[a-zA-Z0-9_]\)\+/\([a-zA-Z0-9_]\|-[a-zA-Z0-9_]\)\+--\(\([a-zA-Z0-9_]\|-[a-zA-Z0-9_]\)\+--\)\?\([a-zA-Z0-9_]\|-[a-zA-Z0-9_]\)\+' > /dev/null; then
    return 0;
  else
    return 1;
  fi
}

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

if test x"$MODE" = x"git"; then
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
else
  # Do tla stuff
  test -d $BASE && ( cd $BASE; echo "# .	`tla tree-id`"; eval $EXEC );
  
  find $BASE -type d \( -name "{arch}" -o -name ".git" \) -prune -o \
    -type f \( -name "config-docu" -o -name "config" \) -print | \
    while read file; do \
      test -f $file && ( \
      dir=`dirname $file`; \
      config=`basename $file`; \
      if test_config $dir $config; then
        check_config $dir $config;
      else
        echo "Skipping non-arch config: $file"
      fi;)
    done
fi
