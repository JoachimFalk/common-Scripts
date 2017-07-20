#! /usr/bin/env perl

use warnings;
use strict;

# fix the @INC path
BEGIN {
  use File::Spec;
  use File::Basename qw(basename dirname);
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
  "usage: $prog [-h|-?|--help] [--guard-prefix|p <prefix>] --src-dir <src dir> --header-dir <header dir>\n\n";
  exit($error ? 1 : 0);
}

my $opt = {
  srcDir      => undef,
  headerDir   => undef,
  guardPrefix => undef,
};

my $p = new Getopt::Long::Parser;
#$p->configure("pass_through", "gnu_getopt");
$p->configure("gnu_getopt");
my $rc = $p->getoptions(
  'help|h|?'          => \$opt->{'help'},
  'src-dir=s'         => \$opt->{'srcDir'},
  'header-dir=s'      => \$opt->{'headerDir'},
  'guard-prefix|p=s'  => \$opt->{'guardPrefix'},
);

$rc = 0 unless defined $opt->{'srcDir'} && defined $opt->{'headerDir'};
if (!$rc || $opt->{'help'}) {
  &Usage(!$rc);
}

$opt->{srcDir}      =~ s{/*$}{};
$opt->{headerDir}   =~ s{/*$}{};
if (defined $opt->{guardPrefix}) {
  $opt->{guardPrefix} =~ s{[^a-zA-Z0-9]}{_}sg;
  $opt->{guardPrefix} = uc($opt->{guardPrefix});
}

sub fixIncludeGuard {
  my ($dir, $file) = @_;
  my $fileDirectory = dirname $file;
  my $in  = IO::File->new(File::Spec->catfile($dir, $file), "r") ||
    die "Can't open '$dir/$file' for input: $!";
  my $out = IO::File->new(File::Spec->catfile($dir, $file).".tmp", "w") ||
    die "Can't open '$dir/$file.tmp' for output: $!";
  
  my $state = 'EDITORLINE';
  
  my @commentStyle = (
    [qr{\Q/*}, undef,    qr{\Q*/}],
    [undef,    qr{\Q//}, undef   ],
  );
  
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
  my $nestDepth = 0;
  my $oldIncludeGuard = undef;
  my $newIncludeGuard = "_INCLUDED_".$file;
  $newIncludeGuard =~ s{[^a-zA-Z0-9]}{_}sg;
  $newIncludeGuard = uc ($newIncludeGuard);

  if (defined $opt->{guardPrefix} &&
      !($newIncludeGuard =~ m/^_INCLUDED_\Q$opt->{guardPrefix}\E_/)) {
    $newIncludeGuard =~ s/^_INCLUDED_/_INCLUDED_\Q$opt->{guardPrefix}\E_/;
  }

  while (my $line = <$in>) {
    if ($state eq 'EDITORLINE' && $line =~ $reEditorLine) {
      # Preserve editor line
      $out->write($line);
      $state = 'EDITORLINE'; # we may have several EDITOR LINES
      next;
    }
    if ($state eq 'EDITORLINE' && $line =~ $reCopyrightStart) {
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
        die "Can't determin comment style for '$line'!";
      }
      # Preserve copyrigh header
      $out->write($line);
      next;
    }
    if ($state eq 'COPYRIGHT') {
      if (defined $copyrightEnd->[0]) {
        # Preserve copyrigh header
        $out->write($line);
        $state = 'COPYRIGHTEND' if $line =~ m/$copyrightEnd->[2]\s*$/;
        next;
      } else {
        if ($line =~ m/^\s*$copyrightEnd->[1]/) {
          # Preserve copyrigh header
          $out->write($line);
          next;
        } else {
          $state = 'COPYRIGHTEND';
        }
      }
    }
    if ($line =~ m{^\s*$}) {
      # skip empty
      $out->write($line);
      next;
    }
    if ($state eq 'EDITORLINE' || $state eq 'COPYRIGHTEND') {
      $out->write("#ifndef $newIncludeGuard\n");
      $out->write("#define $newIncludeGuard\n");
      $state = 'STRIP'
    }

    if ($line =~ m/^\s*#\s*if/) {
      $nestDepth = $nestDepth+1;
      if ($nestDepth == 1) {
        unless ($state eq 'STRIP' &&
                $line =~ m/^\s*#\s*(?:ifndef\s+(\w+)|if\s+!\s*defined\s*\(\s*(\w+)\s*\))/) {
          $state = 'ERROR';
          last;
        } else {
          $oldIncludeGuard = $1 || $2;
#         print "oldIncludeGuard: $oldIncludeGuard\n";
          $state = 'WAITDEFINE';
          next;
        }
      }
    } elsif ($line =~ m/^\s*#\s*endif/) {
      $nestDepth = $nestDepth-1;
      die "WTF?!" if $nestDepth < 0;
      if ($nestDepth == 0) {
        if ($state eq 'WAITDONE') {
          $out->write("#endif /* $newIncludeGuard */\n");
          $state = 'DONE';
          next;
        } else {
          $state = 'ERROR';
          last;
        }
      }
    } elsif (defined $oldIncludeGuard &&
             $line =~ m/^\s*#\s*define\s+\Q$oldIncludeGuard\E\b/) {
#     print "match\n";
      if ($nestDepth == 1) {
        $state = 'WAITDONE';
        next;
      } else {
        $state = 'ERROR';
        last;
      }
    }

    if ($state eq 'DONE') {
      $state = 'ERROR';
      last;
    }

    # copy
    $out->write($line);
  }
  
  undef $in;
  undef $out;

  if ($state ne 'DONE') {
    print STDERR "The header $dir/$file does not seem to use traditional include guards!\n";
    unlink File::Spec->catfile($dir, $file).".tmp";
  } else {
    system("mv", "-f",
        File::Spec->catfile($dir, $file).".tmp",
        File::Spec->catfile($dir, $file)) &&
      die "Can't move file '$dir/$file.tmp' to '$dir/$file'!";
  }
}

my (@SOURCES, @HEADERS);

finddepth(sub {
    push @SOURCES, $1 if $File::Find::name =~ m{^\Q$opt->{srcDir}\E/(.*\.(?:c|cpp|re2cpp|cxx|cc|C|h|hpp|tcpp|hxx|hh))$};
  }, $opt->{srcDir});
finddepth(sub {
    push @HEADERS, $1 if $File::Find::name =~ m{^\Q$opt->{headerDir}\E/(.*\.(?:h|hpp|tcpp|hxx|hh)(?:\.in)?)$};
  }, $opt->{headerDir});

foreach my $file (@HEADERS) {
  fixIncludeGuard($opt->{headerDir}, $file);
}
foreach my $file (@SOURCES) {
  next unless $file =~ m/\.(?:h|hpp|tcpp|hxx|hh)(?:\.in)?$/;
  fixIncludeGuard($opt->{srcDir}, $file);
}

exit 0;
