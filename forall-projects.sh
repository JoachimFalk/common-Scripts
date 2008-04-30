#! /bin/sh

BASE=`dirname $0`;
BASE=`cd $BASE; pwd`;

EXEC=$@

test -d $BASE && ( cd $BASE; echo `basename $BASE`; $EXEC );

check_config() {
  BASE=$1;
  CONFIG=$2;
  cat $BASE/$CONFIG | \
    sed -e 's/[ 	]*#.*$//' -e '/^$/d' | \
    while read dir arch; do \
      test -d $BASE/$dir && ( \
        cd $BASE/$dir; echo " $dir"; \
        case `tla tree-id` in \
          ${arch}|${arch}--*) \
            ;; \
          *) \
            echo "Branch missmatch, please get new branch via:"; \
            echo " tla get $arch $dir !"; \
            ;; \
        esac; \
        $EXEC ); \
    done
}

test_config() {
  BASE=$1;
  CONFIG=$2;
  if ! sed -e 's/[ 	]*#.*$//' -e '/^$/d' $BASE/$CONFIG | \
    grep -v '^[a-zA-Z0-9./_-]\+[ 	]\+[^@]\+@[^@]\+--\([a-zA-Z0-9_]\|-[a-zA-Z0-9_]\)\+/\([a-zA-Z0-9_]\|-[a-zA-Z0-9_]\)\+--\([a-zA-Z0-9_]\|-[a-zA-Z0-9_]\)\+--\([a-zA-Z0-9_]\|-[a-zA-Z0-9_]\)\+' > /dev/null; then
    return 0;
  else
    return 1;
  fi
}

find $BASE -name config-docu -o -name config | \
    grep -v "{arch}" | \
  while read file; do \
    test -f $file && \
    echo "$file:" && ( \
    dir=`dirname $file`; \
    config=`basename $file`; \
    if test_config $dir $config; then
      check_config $dir $config;
    else
      echo "Skipping non-arch config: $file"
    fi;)
  done
