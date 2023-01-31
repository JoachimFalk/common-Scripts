#! /usr/bin/env perl
# -*- tab-width:8; indent-tabs-mode:nil; c-basic-offset:2; -*-
# vim: set sw=2 ts=8 et:
#
# Copyright (c)
#   2011 FAU -- Joachim Falk <joachim.falk@fau.de>
#   2012 Joachim Falk <joachim.falk@gmx.de>
#   2018 FAU -- Joachim Falk <joachim.falk@fau.de>
#   2020 FAU -- Joachim Falk <joachim.falk@fau.de>
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
use Date::Parse;

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
  my ($error) = @_;

  my $msg = "\n".
    "Usage: $prog [options]  <files to update> ...\n".
    "\n".
    "Available options:\n".
    "  --help|-h|-?                          Produce this help message\n".
    "  --copyright|-c [<filename>]           Insert the given copyright into the\n".
    "                                        files to update. Default: COPYRIGHT\n".
    "  --editorline|-e [<filename>]          Insert the given editor lines into the\n".
    "                                        files to update. Default: EDITORLINE\n".
    "\n";
  if ($error) {
    print STDERR $msg;
    exit 1;
  } else {
    print STDOUT $msg;
    exit 0;
  }
}

my $opt = {
  help       => undef,
  copyright  => undef,
  editorline => undef,
};

my $p = new Getopt::Long::Parser;
#$p->configure("pass_through", "gnu_getopt");
$p->configure("gnu_getopt");
my $rc = $p->getoptions(
  'help|h|?'          => \$opt->{'help'},
  'copyright|c:s'     => \$opt->{'copyright'},
  'editorline|e:s'    => \$opt->{'editorline'},
);

if (defined $opt->{copyright} && !$opt->{copyright}) {
  $opt->{copyright} = 'COPYRIGHT';
}
if (defined $opt->{'editorline'} && !$opt->{'editorline'}) {
  $opt->{'editorline'} = 'EDITORLINES';
}

if (!$rc || (!$opt->{'copyright'} && !$opt->{'editorline'}) || $opt->{'help'}) {
# print STDOUT (!$rc || !$opt->{'help'} ? 'error' : 'help'), "\n";
  &Usage(!$rc || !$opt->{'help'});
}

my @BPTXT;
if ($opt->{'copyright'}) {
  my $in  = IO::File->new($opt->{'copyright'}, "r") ||
    die "Can't open '$opt->{'copyright'}' for input: $!";
  @BPTXT = <$in>;
}

my @ELTXT;
if ($opt->{'editorline'}) {
  my $in  = IO::File->new($opt->{'editorline'}, "r") ||
    die "Can't open '$opt->{'editorline'}' for input: $!";
  @ELTXT = <$in>;
}

our %EMAILS = (
    'falk@cs.fau.de'            => 'Joachim Falk <joachim.falk@fau.de>',
    'joachim.falk@gmx.de'       => 'Joachim Falk <joachim.falk@gmx.de>',
    'liyuan.zhang@informatik.uni-erlangen.de' => 'Liyuan Zhang <liyuan.zhang@fau.de>',
    'streubuehr@cs.fau.de'      => 'Martin Streubuehr <martin.streubuehr@fau.de>',
    'sebastian.graf@cs.fau.de'  => 'Sebastian Graf <sebastian.graf@fau.de>',
    'schwarzer@codesign.informatik.uni-erlangen.de' => 'Tobias Schwarzer <tobias.schwarzer@fau.de>',
    'christian.zebelein@informatik.uni-erlangen.de' => 'Christian Zebelein <christian.zebelein@fau.de>',
    'rafael.rosales@informatik.uni-erlangen.de'     => 'Rafael Rosales <rafael.rosales@fau.de>',
  );


foreach my $file (@ARGV) {
  print $file, "\n";

  my @BPTXT_INSERTED;

  {
    my %COPYRIGHTYEARS;

    my $log = eval {
        open(my $fh, "-|", "git", "log", "--follow", $file); $fh
      } or
      die "Can't get git log for '$file': $!";
    my $author;

    foreach my $line (<$log>) {
      if ($line =~ m/^Author:\s*([^<>]*\s*(?:<(.*)>)?)$/) {
        my $email = $2;
        if (defined $EMAILS{$email}) {
          $author = $EMAILS{$email};
        } else {
          $author = $1;
        }
        if ($author =~ m/\@(?:cs\.)?fau\.de>/) {
          $author = "FAU -- $author"
        }
      } elsif ($line =~ m/^Date:\s*(.*)$/) {
        my ($ss,$mm,$hh,$day,$month,$year,$zone) = strptime($1);
        $COPYRIGHTYEARS{1900+$year}{$author} = 1;
      }
    }

    my @COPYRIGHTLINES;
    foreach my $year (sort keys %COPYRIGHTYEARS) {
      foreach my $author (sort keys %{$COPYRIGHTYEARS{$year}}) {
        push @COPYRIGHTLINES, "$year $author";
      }
    }
    foreach my $line (@BPTXT) {
      if ($line =~ m/\@COPYRIGHTLINES\@/) {
        push @BPTXT_INSERTED, map {
            my $rline = $line."";
            $rline =~ s/\@COPYRIGHTLINES\@/$_/;
            $rline;
          } @COPYRIGHTLINES;
      } else {
        push @BPTXT_INSERTED, $line;
      }
    }

  }

  my $in  = IO::File->new($file, "r") or
    die "Can't open '$file' for input: $!";
  my $out = IO::File->new($file.".tmp", "w") or
    die "Can't open '$file.tmp' for output: $!";
  
  my $state = 'SHEBANGLINE';
  
  my @commentStyle = ();
  
  if ($file =~ m/\.(?:c|cpp|re2cpp|cxx|cc|C|h|hpp|tcpp|hxx|hh)$/) {
    push @commentStyle, [ qr{\Q/*}, undef,    qr{\Q*/},  "/*\n",  " * ", " */\n"];
    push @commentStyle, [ undef,    qr{\Q//}, undef,     "",      "// ", ""     ];
  } elsif ($file =~ m/\.(?:java)$/) {
    push @commentStyle, [ qr{\Q/*}, undef,    qr{\Q*/},  "/*\n",  " * ", " */\n"];
    push @commentStyle, [ undef,    qr{\Q//}, undef,     "",      "// ", ""     ];
  } elsif ($file =~ m/\.(?:m4)$/) {
    push @commentStyle, [ undef, qr{dnl\s},  undef, "", "dnl ", ""];
  } elsif ($file =~ m/\.(?:sh|am|ac|in|mk|in\.frag|pl|pm|perl)$/) {
    push @commentStyle, [ undef, qr{#},      undef, "", "# ",   ""];
  } elsif ($file =~ m/\.(?:tex)$/) {
    push @commentStyle, [ undef, qr{%},      undef, "", "% ",   ""];
  } else {
    die "Unknown file type for file '$file' !";
  }
  
  my $reEditorLine;
  my $editorLinePattern = "(vim:|-\*-|!!!)";
  
  foreach my $commentStyle (@commentStyle) {
    my $re =
      defined ($commentStyle->[0])
      ? qr{^\s*$commentStyle->[0]\s*$editorLinePattern.*$commentStyle->[2]}
      : qr{^\s*$commentStyle->[1]\s*$editorLinePattern};
    if (defined $reEditorLine) {
      $reEditorLine = qr{$reEditorLine|$re};
    } else {
      $reEditorLine = $re;
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
    if ($state eq 'SHEBANGLINE') {
      if ($line =~ m/^#!.*/) {
        # Preserve shebang line
        $out->write($line);
        $state = 'EDITORLINE';
        next;
      } else {
        $state = 'EDITORLINE';
      }
    }
    if ($state eq 'EDITORLINE') {
      if ($line =~ $reEditorLine) {
        if (!$opt->{editorline}) {
          # Preserve editor line
          $out->write($line);
        }
        $state = 'EDITORLINE'; # we may have several EDITOR LINES
        next;
      } else {
        if ($opt->{editorline}) {
          my $commentStyle = $commentStyle[0];
          foreach my $cs (@commentStyle) {
            if ($cs->[3] eq '') {
              $commentStyle = $cs;
              last;
            }
          }
          # insert editor lines
          my $eltxt = join('', (
              $commentStyle->[3],
              (map { $commentStyle->[4].$_; } @ELTXT),
              $commentStyle->[5])
            );
          $out->write($eltxt);
        }
        if ($opt->{copyright}) {
          $state = 'COPYRIGHTSTART';
        } else {
          $state = 'COPY';
        }
      }
    }
    if ($state eq 'COPYRIGHTSTART' &&
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
      # insert copyright
      my $bptxt = join('', (
          $commentStyle[0]->[3],
          (map { $commentStyle[0]->[4].$_; } @BPTXT_INSERTED),
          $commentStyle[0]->[5])
        )."\n";
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
