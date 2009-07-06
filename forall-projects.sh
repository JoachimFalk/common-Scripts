#! /bin/sh

cd `dirname $0`
BASE=.

EXEC="$@"

if test x"$1" = x"tla"; then
  EXEC="$EXEC | grep -v '^\*'"
fi

check_config() {
  BASE=$1;
  CONFIG=$2;
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
  BASE=$1;
  CONFIG=$2;
  if ! sed -e 's/[ 	]*#.*$//' -e '/^$/d' $BASE/$CONFIG | \
    grep -v '^[a-zA-Z0-9+./_-]\+[ 	]\+[^@]\+@[^@]\+--\([a-zA-Z0-9_]\|-[a-zA-Z0-9_]\)\+/\([a-zA-Z0-9_]\|-[a-zA-Z0-9_]\)\+--\([a-zA-Z0-9_]\|-[a-zA-Z0-9_]\)\+--\([a-zA-Z0-9_]\|-[a-zA-Z0-9_]\)\+' > /dev/null; then
    return 0;
  else
    return 1;
  fi
}

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
