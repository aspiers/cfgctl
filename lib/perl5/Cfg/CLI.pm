package Cfg::CLI;

=head1 NAME

Cfg::CLI -

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Carp qw(carp cluck croak confess);
use File::Compare;
use FindBin qw($RealScript);
use Getopt::Long;
use Net::Domain qw(hostname);

use base 'Exporter';
use Cfg::Cfg qw(%cfg);
our @EXPORT_OK = qw(debug for_real %opts);

our %opts = (
  verbose      => 1,
  install      => 0,
  freshen      => 0,
  update       => 0,
  erase        => 0,
  list         => 0,
  sources      => 0,
  destinations => 0,
);

sub for_real { $opts{'test'} ? 0 : 1 }

sub debug {
  my $level = shift;
  warn @_, "\n" if $opts{verbose} >= $level;
}

sub usage {
  warn @_, "\n" if @_;

  ### N.B.!  If you change the below, don't forget to update the
  ### SYNOPSIS too!
  my $usage = <<EOUSAGE;
$RealScript [options] [pkg [pkg...]]

By default, installs the listed config packages, or all if none are
specified.

Options [defaults in square brackets]:
  -i, --install              Ensure chosen package(s) are in the local
                             package store, then install.
  -U, --update               Ensure chosen packages are uptodate, then re-install.
                             (This involves pulling/merging for DVC backends.)
  -e, --erase                De-install the chosen packages.
  -p, --pull                 (DVC backends only) Pull latest changes but don't merge.

  -l, --list                 List all packages in tab-delimited format
  -s, --sources              Only list source packages
  -d, --destinations         Only list destination packages

  -t, --test                 Dry run, don't touch the disk
  -v, --verbose[=N]          Increase [specify] verbosity

  -P, --pkg-dir=DIR          Change source package directory [$cfg{PKGS_DIR}]
  -T, --target=TARGET-DIR    Change target directory [$cfg{TARGET_DIR}]
  -M, --map=MAP-FILE         Change config map file [$cfg{MAP_FILE}]
  -r, --remove-dangling      If conflicts with dangling symlinks
                             are found, delete them.
      --thorough             Don't prune subdirectories not in packages.
                             This may leave symlinks pointing to old
                             dirs which used to be in packages, but is
                             a lot slower.
EOUSAGE

  $usage =~ s!$ENV{HOME}!~!g;
  die $usage;
}

sub process_options {
  Getopt::Long::Configure('no_ignore_case', 'bundling');
  GetOptions(
    \%opts,
    'install|i', 'freshen|F', 'update|U', 'erase|e', 'pull|p',
    'list|l', 'sources|s', 'destinations|d',
    'test|t', 'verbose|v:+',
    'pkg-dir|P=s', 'target|T=s', 'map|M=s',
    'remove-dangling|r', 'thorough',
  )
    or usage();

  $cfg{PKGS_DIR}    = $opts{'pkg-dir'} if $opts{'pkg-dir'};
  $cfg{TARGET_DIR}  = $opts{'target' } if $opts{'target' };
  $cfg{MAP_FILE}    = $opts{'map'    } if $opts{'map'    };

  $cfg{POST_DIR} = "$cfg{PKGS_DIR}-post.d";
}

sub check_options {
  my $total = 0;
  $total += ($opts{$_} || 0)
    foreach qw(list sources destinations update pull erase);
  if ($total == 0) {
    $opts{install}++;
  }
  elsif ($total > 1) {
    usage("Only one of -i/-U/-e/-p/-l/-s/-d can be specified.\n");
  }
}

=head1 BUGS

=head1 SEE ALSO

=cut

1;
