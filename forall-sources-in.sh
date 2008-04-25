#! /bin/sh

COMMAND=$1; shift

SRCS=`find $@ \
        -type d \( -name "{arch}" -o -name "obj" -o -name "dust-bin" \) -prune -o \
        -type f \( -name "*.cpp" -o -name "*.hpp" -o -name "*.c" -o -name "*.h" \) -print`

${COMMAND} ${SRCS}
