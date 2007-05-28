package Cfg::Pkg::Utils;

=head1 NAME

Cfg::Pkg::Utils - name

=head1 SYNOPSIS

synopsis

=head1 DESCRIPTION

description

=cut

use strict;
use warnings;

use Cfg::Cfg qw(%cfg);
use Cfg::CLI qw(%opts);
use Sh qw(move_with_subpath);

use base 'Exporter';
our @EXPORT_OK = qw(preempt_conflict);

=head2 preempt_conflict($src, $dst)

The arguments are full paths to pairs of files which conflict.

If we know in advance via a dry run of stow that a real run would
result in conflicts (where files in the target tree already exist and
are not controlled by stow so cannot safely be removed), this routine
preempts the conflict in one of two ways:

=over 4

=item * Source and destination already have identical contents

In this case, the destination file can be unlinked.

=item * Source and destination have different contents

In this case, we move the destination file over the source so that
stow can put a symlink there instead whilst still preserving local
changes.  We take a backup of the original source file first, in case
we are offline and can't easily retrieve it from the source control
system.

=back

=cut

sub preempt_conflict {
  my ($src, $dst) = @_;

  debug(2, "# Preempting conflict between $src and $dst");

  # Shorter, human-readable versions of source and destination
  (my $human_src = $src) =~ s!^$ENV{HOME}/!~/!;
  (my $human_dst = $dst) =~ s!^$ENV{HOME}/!~/!;
  (my $sub_dst   = $dst) =~ s!^$cfg{TARGET_DIR}/!!
    or die "$dst didn't start with $cfg{TARGET_DIR}\n";

  return if -d $dst and -d $src;

  die "$human_dst is a directory but $human_src isn't; aborting!\n"
    if -d $dst and ! -d $src;

  if (! -d $dst and ! -l $dst and -d $src) {
    die "$human_src is a directory but $human_dst isn't; aborting!\n";
  }

#   my $tempdir = TempDir->get;
#   die unless -d $tempdir;

  my ($src_dev, $src_ino) = stat($src) or die "stat($src) failed: $!";
  my ($dst_dev, $dst_ino) = stat($dst);

  if (! $dst_dev || ! $dst_ino) {
    if (-l $dst) {
      if ($opts{'remove-dangling'}) {
        debug(2, "# !   Removing dangling symlink $dst");
        if (for_real()) {
          unlink($dst) or die "unlink($dst) failed: $!\n";
        }
        return;
      }
      else {
        die "stat($dst) failed ($!); invalid symlink?  Specify -r to remove dangling symlinks.\n";
      }
    }
    else {
      die "stat($dst) failed ($!); can't preempt conflict!  Aborting.\n";
    }
  }

  if ($src_dev == $dst_dev and $src_ino == $dst_ino) {
    debug(3, "#   $human_src and $human_dst are the same file; must be false conflict (see 6.3 Conflicts section of manual)");
    return;
  }

  if (compare($src, $dst) == 0) {
    # same file contents - remove target so that stow can put a
    # symlink there instead.
    debug(3, "#   $human_dst == $src; remove to make way for symlink");
#     my $same_dir = File::Spec->join($tempdir, 'same');
#     die $same_dir unless -d $same_dir;
    if (for_real()) {
      unlink $dst or die "unlink($dst) to preempt conflict failed: $!\n";
      #move_with_subpath($cfg{TARGET_DIR}, $same_dir, $sub_dst);
    }
  }
  else {
    # different file contents - move target to source so that stow
    # can put a symlink there instead whilst still preserving
    # local changes
#     my $modified_dir = File::Spec->join($tempdir, 'modified');
    debug(1, "M $human_dst");
    if (for_real()) {
      my $host = hostname() || die "Couldn't get hostname";
      my $suffix = "cfgsave.$host.$$." . time();
      rename $src, "$src.$suffix"
        or die "rename($src, $src.$suffix) failed: $!\n";
      debug(3, "#   mv pristine $human_src => $human_src.$suffix");
      rename $dst, $src
	or die "rename($dst, $src) to preempt conflict failed: $!\n";
      debug(3, "#   mv modified $human_dst => $human_src");
      #move_with_subpath($cfg{TARGET_DIR}, $modified_dir, $sub_dst);
    }
  }
}

=head1 BUGS

=head1 SEE ALSO

=cut

1;
