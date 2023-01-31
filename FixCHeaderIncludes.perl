#! /usr/bin/env perl
# -*- tab-width:8; indent-tabs-mode:nil; c-basic-offset:2; -*-
# vim: set sw=2 ts=8 et:
# 
# Copyright (c)
#   2017 FAU -- Joachim Falk <joachim.falk@fau.de>
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

use warnings;
use strict;

# fix the @INC path
BEGIN {
  use File::Spec;
  use File::Basename;
  use Cwd qw();
  
  @INC = grep { $_ ne '.' } @INC;
  unshift @INC, File::Spec->catfile(Cwd::abs_path(dirname($0)), "site_perl");
}

use Getopt::Long;
use IO::File;
use File::Find qw(find finddepth);
use File::Spec qw(abs2rel);

use vars qw($prog);

#
# Set global constants
#

# Get the program name
$prog = basename($0);

#
# Usage
#

sub Usage {
  my $error = (@_);

  print STDERR "\n".
  "usage: $prog [-h|-?|--help] --src-dir <src dir> --header-dir <header dir>\n\n";
  exit($error ? 1 : 0);
}

my $opt = {
  srcDir    => undef,
  headerDir => undef,
};

my $p = new Getopt::Long::Parser;
#$p->configure("pass_through", "gnu_getopt");
$p->configure("gnu_getopt");
my $rc = $p->getoptions(
  'help|h|?'          => \$opt->{'help'},
  'src-dir=s'         => \$opt->{'srcDir'},
  'header-dir=s'      => \$opt->{'headerDir'},
);

$rc = 0 unless defined $opt->{'srcDir'} && defined $opt->{'headerDir'};
if (!$rc || $opt->{'help'}) {
  &Usage(!$rc);
}

$opt->{srcDir}    =~ s{/*$}{};
$opt->{headerDir} =~ s{/*$}{};

my (@SOURCES, @HEADERS);

finddepth(sub {
    push @SOURCES, $1 if $File::Find::name =~ m{^\Q$opt->{srcDir}\E/(.*\.(?:c|cpp|re2cpp|cxx|cc|C|h|hpp|tcpp|hxx|hh)(?:\.in)?)$};
  }, $opt->{srcDir});
finddepth(sub {
    push @HEADERS, $1 if $File::Find::name =~ m{^\Q$opt->{headerDir}\E/(.*\.(?:h|hpp|tcpp|hxx|hh)(?:\.in)?)$};
  }, $opt->{headerDir});

my (%DUPLICATE_HEADER, %INTERNAL_HEADER, %EXTERNAL_HEADER);

foreach my $file (@HEADERS) {
  my $base = basename $file;
  unless (defined $EXTERNAL_HEADER{$base} ||
          defined $DUPLICATE_HEADER{$base}) {
    $EXTERNAL_HEADER{$base} = $file;
  } else {
    delete $EXTERNAL_HEADER{$base};
    $DUPLICATE_HEADER{$base} = [] unless defined $DUPLICATE_HEADER{$base};
    push @{$DUPLICATE_HEADER{$base}}, $file;
  }
}

foreach my $file (@SOURCES) {
  next unless $file =~ m/\.(?:h|hpp|tcpp|hxx|hh)(?:\.in)?$/;
  $file =~ s{\.in$}{};
  my $base = basename $file;
  unless (defined $EXTERNAL_HEADER{$base} ||
          defined $INTERNAL_HEADER{$base} ||
          defined $DUPLICATE_HEADER{$base}) {
    $INTERNAL_HEADER{$base} = $file;
  } else {
    delete $EXTERNAL_HEADER{$base};
    delete $INTERNAL_HEADER{$base};
    $DUPLICATE_HEADER{$base} = [] unless defined $DUPLICATE_HEADER{$base};
    push @{$DUPLICATE_HEADER{$base}}, $file;
  }
}

foreach my $file (@HEADERS) {
# print $file, "\n";
  my $fileDirectory = dirname $file;
  my $in  = IO::File->new(File::Spec->catfile($opt->{headerDir}, $file), "r") ||
    die "Can't open '<headers>/$file' for input: $!";
  my $out = IO::File->new(File::Spec->catfile($opt->{headerDir}, $file).".tmp", "w") ||
    die "Can't open '<headers>/$file.tmp' for output: $!";
  
  while (my $line = <$in>) {
    if ($line =~ m/^(\s*#\s*include\s*)(?:"([^"]*)"|<([^>]*)>)/) {
      my $include = $2||$3;
      my $base    = basename $include;
      if (defined $DUPLICATE_HEADER{$base}) {
        print "The header $include is ambiguous. Thus, i can't update the include statement!\n";
      } elsif (defined $EXTERNAL_HEADER{$base}) {
        $line = "$1\"".File::Spec->abs2rel($EXTERNAL_HEADER{$base}, $fileDirectory)."\"\n";
      }
    }
    $out->write($line);
  }
  
  undef $in;
  undef $out;

  system("mv", "-f",
      File::Spec->catfile($opt->{headerDir}, $file).".tmp",
      File::Spec->catfile($opt->{headerDir}, $file)) &&
    die "Can't move file '$file.tmp' to '$file' !";
}

foreach my $file (@SOURCES) {
# print $file, "\n";
  my $fileDirectory = dirname $file;
  my $in  = IO::File->new(File::Spec->catfile($opt->{srcDir}, $file), "r") ||
    die "Can't open '<sources>/$file' for input: $!";
  my $out = IO::File->new(File::Spec->catfile($opt->{srcDir}, $file).".tmp", "w") ||
    die "Can't open '<sources>/$file.tmp' for output: $!";
  
  while (my $line = <$in>) {
    if ($line =~ m/^(\s*#\s*include\s*)(?:"([^"]*)"|<([^>]*)>)/) {
      my $include = $2||$3;
      my $base    = basename $include;
      if (defined $DUPLICATE_HEADER{$base}) {
        print "The header $include is ambiguous. Thus, i can't update the include statement!\n";
      } elsif (defined $INTERNAL_HEADER{$base}) {
        $line = "$1\"".File::Spec->abs2rel($INTERNAL_HEADER{$base}, $fileDirectory)."\"\n";
      } elsif (defined $EXTERNAL_HEADER{$base}) {
        $line = "$1<$EXTERNAL_HEADER{$base}>\n";
      }
    }
    $out->write($line);
  }
  
  undef $in;
  undef $out;

  system("mv", "-f",
      File::Spec->catfile($opt->{srcDir}, $file).".tmp",
      File::Spec->catfile($opt->{srcDir}, $file)) &&
    die "Can't move file '$file.tmp' to '$file' !";
}

exit 0;
