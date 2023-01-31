#! /bin/sh
# -*- tab-width:8; indent-tabs-mode:nil; c-basic-offset:2; -*-
# vim: set sw=2 ts=8 et:
#
# Copyright (c)
#   2010 FAU -- Joachim Falk <joachim.falk@fau.de>
#   2012 FAU -- Joachim Falk <joachim.falk@fau.de>
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

COMMAND=$1; shift

SRCS=`find $@ \
        -type d \( -name "{arch}" -o -name "obj" -o -name "dust-bin" -o -name "dustbin" \) -prune -o \
        -type f \( -name "aclocal.m4" \) -prune -o \
        -type f \( -name "*.cpp" -o -name "*.tcpp" -o -name "*.hpp" -o -name "*.thpp" -o \
                   -name "*.cxx" -o -name "*.tcxx" -o -name "*.hxx" -o -name "*.thxx" -o -name "*.C" -o \
                   -name "*.c" -o -name "*.h" -o -name "*.re2cpp" -o \
                   -name "*.perl" -o -name "*.pm" -o \
                   -name "*.py" -o \
                   -name "*.m4" -o \
                   -name "*.sh" \
                \) -print`

eval ${COMMAND} ${SRCS}
