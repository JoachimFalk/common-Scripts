#! /usr/bin/env perl

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
  "usage: $prog [-h|-?|--help] [-b|--boilerplate] <filename> files...\n\n";
  exit($error ? 1 : 0);
}

my $opt = {};

my $p = new Getopt::Long::Parser;
#$p->configure("pass_through", "gnu_getopt");
$p->configure("gnu_getopt");
my $rc = $p->getoptions(
  'help|h|?'          => \$opt->{'help'},
  'boilerplate|b=s'   => \$opt->{'boilerplate'},
);

if (!$rc || !$opt->{'boilerplate'} || $opt->{'help'}) {
  &Usage(!$rc || !$opt->{'boilerplate'});
}

my $bptxt;

{
  my $in  = IO::File->new($opt->{'boilerplate'}, "r") ||
    die "Can't open '$opt->{'boilerplate'}' for input: $!";

  $bptxt = join('', ("/*\n", (map { " * $_"; } <$in>), " */\n"));
}

foreach my $file (@ARGV) {
  print $file, "\n";
  
  my $in  = IO::File->new($file, "r") ||
    die "Can't open '$file' for input: $!";
  my $out = IO::File->new($file.".tmp", "w") ||
    die "Can't open '$file.tmp' for output: $!";

  my $state = 'VIMLINE';
  
  while (my $line = <$in>) {
    if ($state ne 'COPY' &&
        $line =~ m{^\s*$}) {
      # discard empty
      next;
    }
    if ($state eq 'VIMLINE' &&
        ($line =~ m{^\s*//\s*vim:} ||
         $line =~ m{^\s*/\*\s*vim:.*\*/\s*$})) {
      # Preserve vim line
      $out->write($line);
      $state = 'COPYRIGHTHEAD';
      next;
    }
    if (($state eq 'VIMLINE' || $state eq 'COPYRIGHTHEAD') &&
        $line =~ m{^\s*/\*}) {
      $state = 'COPYRIGHT';
    }
    if ($state eq 'COPYRIGHT' &&
        $line =~ m{\*/}) {
      $state = 'COPYRIGHTEND';
      next;
    }
    if ($state ne 'COPY' && $state ne 'COPYRIGHT') {
      $state = 'COPYRIGHTEND';
    }
    if ($state eq 'COPYRIGHTEND') {
      # insert boilerplate
      $out->write($bptxt);
      $out->write("\n");
      $state = 'COPY';
    }
    if ($state eq 'COPY') {
      # copy
      $out->write($line);
    }
  }

  undef $in;
  undef $out;
  
  system("mv", "-f", $file.".tmp", $file) &&
    die "Can't move file '$file.tmp' to '$file' !";
}
