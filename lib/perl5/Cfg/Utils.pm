package Cfg::Utils;

=head1 NAME

Cfg::Utils -

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Carp qw(carp cluck croak confess);
use File::Compare;

use base 'Exporter';
our @EXPORT_OK = qw(debug
                    ensure_correct_symlink preempt_conflict
                    for_real
                    %opts %cfg);

our (%opts, %cfg);

sub for_real { $opts{'dry-run'} ? 0 : 1 }

sub ensure_correct_symlink {
  my ($symlink, $required_target) = @_;

  if (! lstat $symlink) {
    symlink $required_target, $symlink
      or die "symlink($required_target, $symlink) failed: $!\n";
    return;
  }

  if (! -l $symlink) {
    die "$symlink already exists but is not a symlink; aborting!\n";
  }

  my ($a_dev, $a_ino) = stat($symlink) # stat automatically follows symlinks
    or die "stat($symlink) failed ($!); invalid symlink?\n";
  
  my ($r_dev, $r_ino) = stat($required_target)
    or confess "stat($required_target) failed: $!";
  if ($a_dev != $r_dev or $a_ino != $r_ino) {
    die "$symlink already exists and points to the wrong place; aborting!\n";
  }
}

sub preempt_conflict {
  my ($src, $symlink) = @_;

  debug("preempting conflict between $src and $symlink\n");

  # Shorter, human-readable versions of source file and symlink
  (my $human_src     = $src)     =~ s!^$ENV{HOME}/!~/!;
  (my $human_symlink = $symlink) =~ s!^$ENV{HOME}/!~/!;
  (my $sub_symlink   = $symlink) =~ s!^$cfg{TARGET_DIR}/!!
    or die "$symlink didn't start with $cfg{TARGET_DIR}\n";

  return if -d $symlink and -d $src;

  die "$human_symlink is a directory but $human_src isn't; aborting!\n"
    if -d $symlink and ! -d $src;

  if (! -d $symlink and ! -l $symlink and -d $src) {
    die "$human_src is a directory but $human_symlink isn't; aborting!\n";
  }

#   my $tempdir = TempDir->get;
#   die unless -d $tempdir;

  my ($src_dev,     $src_ino)     = stat($src) or die "stat($src) failed: $!";
  my ($symlink_dev, $symlink_ino) = stat($symlink);

  if (! $symlink_dev || ! $symlink_ino) {
    if (-l $symlink) {
      if ($opts{'remove-dangling'}) {
        debug("! Removing dangling symlink $symlink\n");
        if (for_real()) {
          unlink($symlink) or die "unlink($symlink) failed: $!\n";
        }
        return;
      }
      else {
        die "stat($symlink) failed ($!); invalid symlink?  Specify -r to remove dangling symlinks.\n";
      }
    }
    else {
      die "stat($symlink) failed ($!); can't preempt conflict!  Aborting.\n";
    }
  }

  if ($src_dev == $symlink_dev and $src_ino == $symlink_ino) {
    debug("$human_src and $human_symlink are the same file; must be false conflict (see 6.3 Conflicts section of manual)\n");
    return;
  }

  if (compare($src, $symlink) == 0) {
    # same file contents - remove target so that stow can put a
    # symlink there instead.
    debug("# $human_symlink == $src; remove to make way for symlink\n");
#     my $same_dir = File::Spec->join($tempdir, 'same');
#     die $same_dir unless -d $same_dir;
    if (for_real()) {
      unlink $symlink or die "unlink($symlink) to preempt conflict failed: $!\n";
      #move_with_subpath($cfg{TARGET_DIR}, $same_dir, $sub_symlink);
    }
  }
  else {
    # different file contents - move target to source so that stow
    # can put a symlink there instead whilst still preserving
    # local changes
#     my $modified_dir = File::Spec->join($tempdir, 'modified');
    print "M $human_symlink\n";
    if (for_real()) {
      my $host = $ENV{HOST} || $ENV{HOSTNAME} || die "edge case";
      my $suffix = "cfgsave.$host.$$." . time();
      rename $src, "$src.$suffix"
        or die "rename($src, $src.$suffix) failed: $!\n";
      debug("mv pristine $human_src => $human_src.$suffix\n");
      rename $symlink, $src
	or die "rename($symlink, $src) to preempt conflict failed: $!\n";
      debug("mv modified $human_symlink => $human_src\n");
      #move_with_subpath($cfg{TARGET_DIR}, $modified_dir, $sub_symlink);
    }
  }
}

sub debug {
  warn @_ if $opts{debug};
}

=head1 BUGS

=head1 SEE ALSO

=cut

1;
