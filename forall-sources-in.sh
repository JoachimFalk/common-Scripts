#! /bin/sh

COMMAND=$1; shift

SRCS=`find $@ \
        -type d \( -name "{arch}" -o -name "obj" -o -name "dust-bin" -o -name "dustbin" \) -prune -o \
        -type f \( -name "*.cpp" -o -name "*.tcpp" -o -name "*.hpp" -o -name "*.thpp" -o \
                   -name "*.cxx" -o -name "*.tcxx" -o -name "*.hxx" -o -name "*.thxx" -o -name "*.C" -o \
                   -name "*.c" -o -name "*.h" -o \
                   -name "*.perl" -o -name "*.pm" -o \
                   -name "*.py" -o \
                   -name "*.m4" -o \
                   -name "*.sh" \
                \) -print`

eval ${COMMAND} ${SRCS}
