package Cfg::Cfg;

=head1 NAME

Cfg::Cfg - global configuration variables

=head1 SYNOPSIS

synopsis

=head1 DESCRIPTION

description

=cut

use strict;
use warnings;

use FindBin qw($RealBin);
use Sh qw(abs_path);

use base 'Exporter';
our @EXPORT_OK = qw(%cfg);

our %cfg;

# Sensible default settings for the top-level container directories
# corresponding to each level described in the architecture document:

# (1) Where the all-important end-user symlinks go.
$cfg{TARGET_DIR} = $ENV{HOME};

# (2) Packages directory ("stow directory" in stow terminology).
#     stow requires all packages live immediately under this.
$cfg{PKGS_DIR} = "$ENV{HOME}/.cfg";

# We use a slightly hacked-up version of GNU stow which ignores CVS/
# directories and anything in ~/.cvsignore.
chomp($cfg{STOW} = `which stow 2>/dev/null`);

# This is where we configure which config packages we want installed locally.
$cfg{MAP_FILE} = abs_path("$RealBin/../etc/config.map");


sub check {
  -d $cfg{TARGET_DIR}
    or return "$cfg{TARGET_DIR} is not a valid directory; aborting.\n";
  -e $cfg{MAP_FILE}
    or return "$cfg{MAP_FILE} does not exist; did you copy from $cfg{MAP_FILE}.template?\n";
  -e $cfg{STOW}
    or return "$cfg{STOW} not found!  Aborting.\n";

  lstat($cfg{PKGS_DIR});
  if (-e _) {
    -d _ or return "$cfg{PKGS_DIR} must be a directory!  Aborting.\n";
  }
  else {
    mkdir $cfg{PKGS_DIR} or die "mkdir($cfg{PKGS_DIR}) failed: $!\n";
  }

  return undef; # no error
}

=head1 BUGS

=head1 SEE ALSO

=cut

1;
