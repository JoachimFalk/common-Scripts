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

my @BPTXT;

{
  my $in  = IO::File->new($opt->{'boilerplate'}, "r") ||
    die "Can't open '$opt->{'boilerplate'}' for input: $!";

  @BPTXT = <$in>;
}

foreach my $file (@ARGV) {
  print $file, "\n";
  
  my $in  = IO::File->new($file, "r") ||
    die "Can't open '$file' for input: $!";
  my $out = IO::File->new($file.".tmp", "w") ||
    die "Can't open '$file.tmp' for output: $!";
  
  my $state = 'SHEBANGLINE';
  
  my @commentStyle = ();
  
  if ($file =~ m/\.(?:c|cpp|cxx|cc|C|h|hpp|hxx|hh)$/) {
    push @commentStyle, [ qr{\Q/*}, undef,    qr{\Q*/},  "/*\n",  " * ", " */\n\n"];
    push @commentStyle, [ undef,    qr{\Q//}, undef,     "",      "// ", "\n"     ];
  } elsif ($file =~ m/\.(?:m4)$/) {
    push @commentStyle, [ undef, qr{dnl\s},  undef, "", "dnl ", "\n"];
  } elsif ($file =~ m/\.(?:sh|am|in|mk)$/) {
    push @commentStyle, [ undef, qr{#},      undef, "", "# ",   "\n"];
  } elsif ($file =~ m/\.(?:tex)$/) {
    push @commentStyle, [ undef, qr{%},      undef, "", "% ",   "\n"];
  } else {
    die "Unknown file type for file '$file' !";
  }
  
  my $reVimLine;
  
  foreach my $commentStyle (@commentStyle) {
    my $re =
      defined ($commentStyle->[0])
      ? qr{^\s*$commentStyle->[0]\s*vim:.*$commentStyle->[2]}
      : qr{^\s*$commentStyle->[1]\s*vim:};
    if (defined $reVimLine) {
      $reVimLine = qr{$reVimLine|$re};
    } else {
      $reVimLine = $re;
    }
  }
  
  my $reCopyrightStart;
  
  foreach my $commentStyle (@commentStyle) {
    my $re =
      defined ($commentStyle->[0])
      ? qr{^\s*$commentStyle->[0]}
      : qr{^\s*$commentStyle->[1]};
    if (defined $reCopyrightStart) {
      $reCopyrightStart = qr{$reCopyrightStart|$re};
    } else {
      $reCopyrightStart = $re;
    }
  }

  my $copyrightEnd;
  
  while (my $line = <$in>) {
    if ($state eq 'SHEBANGLINE' && $line =~ m/^#!.*/) {
      # Preserve shebang line
      $out->write($line);
      $state = 'VIMLINE';
      next;
    }
    if (($state eq 'SHEBANGLINE' || $state eq 'VIMLINE') &&
        $line =~ $reVimLine) {
      # Preserve vim line
      $out->write($line);
      $state = 'COPYRIGHTHEAD';
      next;
    }
    if (($state eq 'VIMLINE' || $state eq 'SHEBANGLINE' || $state eq 'COPYRIGHTHEAD') &&
        $line =~ $reCopyrightStart) {
      $state = 'COPYRIGHT';
      foreach my $commentStyle (@commentStyle) {
        if (defined($commentStyle->[0])
              ? $line =~ m/^\s*$commentStyle->[0]/
              : $line =~ m/^\s*$commentStyle->[1]/) {
          $copyrightEnd = $commentStyle;
          last;
        }
      }
      unless (defined $copyrightEnd) {
        die "Can't determin comment style for '$line' !";
      }
    }
    if ($state eq 'COPYRIGHT' &&
        (defined($copyrightEnd->[0])
          ? $line =~ m/$copyrightEnd->[2]\s*$/
          : !($line =~ m/^\s*$copyrightEnd->[1]/))) {
      $state = 'COPYRIGHTEND';
      next if defined($copyrightEnd->[0]);
    }
    if ($state ne 'COPY' && $line =~ m{^\s*$}) {
      # discard empty
      next;
    }
    if ($state ne 'COPY' && $state ne 'COPYRIGHT') {
      $state = 'COPYRIGHTEND';
    }
    if ($state eq 'COPYRIGHTEND') {
      # insert boilerplate
      my $bptxt = join('', (
          $commentStyle[0]->[3],
          (map { $commentStyle[0]->[4].$_; } @BPTXT),
          $commentStyle[0]->[5])
        );
      $out->write($bptxt);
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
