package TempDir;

use File::Basename;
use File::Path;
use File::Spec;
use File::Temp qw/ tempfile tempdir /;

our $tempdir;
my $init = 0; # yuk
my @subdirs;

sub init {
  return if $init;
  @subdirs = (qw/same modified/);
  $init++;
}

sub get {
  shift->init();
  return $tempdir if $tempdir;
  my $me = basename($0);
  $tempdir = tempdir(".$me.XXXXXXXX", DIR => $TARGET_DIR);
  die "huh?" unless -d $tempdir;
  die unless @subdirs;
  foreach my $dir (@subdirs) {
    my $new = File::Spec->join($tempdir, $dir);
    mkdir($new) or die "mkdir($new) failed: $!\n";;
  }
  return $tempdir;
}

sub cleanup {
  return unless $tempdir and -d $tempdir;
  foreach my $dir (@subdirs) {
    my $doomed = File::Spec->join($tempdir, $dir);
    rmdir($doomed) or die "$doomed not empty?";
  }
  rmdir($tempdir) or die "rmdir($tempdir) failed: $!\n";
}

END {
  TempDir->cleanup();
}
