package Cfg;

=head1 NAME

Cfg -

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Tie::RefHash;

use Cfg::Utils qw(debug %opts %cfg);
use Cfg::Section;
use Cfg::Pkg::CVS;

use Sh qw(abs_path move_with_subpath cat);

=head1 ROUTINES

=cut

my (@sections, %sections, $current_section);
tie %sections, 'Tie::RefHash';

sub register (@) {
  foreach my $object (@_) {
    if ($object->isa('Cfg::Section')) {
      $current_section = $object;
      if (! $sections{$object}) {
        push @sections, $object;
      }
    }
    else {
      die "Tried to add a ", ref($object), " before any section!\n"
        unless $current_section;
      push @{ $sections{$current_section} }, $object;
    }
  }
}

sub for_real { $opts{'dry-run'} ? 0 : 1 }

sub do_registration {
  eval {
    # Let the config file register any packages we want.
    require $cfg{MAP_FILE};
  };
  die "Compilation of $cfg{MAP_FILE} failed:\n$@\n" if $@;
}

sub list_pkgs {
  foreach my $section (@sections) {
    print $section->to_string, "\n";
    foreach my $entry (@{ $sections{$section} }) {
      if ($opts{sources})  {
        print $entry->src, "\n";
      }
      elsif ($opts{destinations}) {
        print $entry->dst, "\n";
      }
      else {
        die "BUG";
      }
    }
  }
}

sub process_pkgs {
  my %filter = map { $_ => 1 } @ARGV;
  my %done;
  my $do_filter = @ARGV;

  foreach my $section (@sections) {
    print $section->to_string, "\n";
    foreach my $pkg (@{ $sections{$section} }) {
      my $dst = $pkg->dst;
      if ($do_filter and ! $filter{$dst}) {
        debug("#. skipping $dst - not on command-line pkg list\n");
        next;
      }

      process_pkg($pkg);
      $done{$dst}++;
    }
  }
  
  if ($do_filter) {
    warn "$_ not found in $cfg{MAP_FILE}; didn't process\n"
      foreach grep ! $done{$_}, keys %filter;
  }
}

sub cat_file {
  my ($file) = @_;
  return '' unless -r $file;
  return cat($file);
}

sub process_pkg {
  my ($pkg) = @_;

  maybe_check_out $pkg;

  my $src = $pkg->src;
  my $dst = $pkg->dst;

  ensure_correct_symlink(
    File::Spec->join($cfg{PKG_DIR}, $dst),
    File::Spec->join($pkg->wd, $src),
  );

  if ($src =~ /RETIRE/) {
    print "#! deprecating: $src\n";
    deprecate_pkg($src, $dst);
  }
  else {
    if ($opts{delete}) {
      delete_pkg($dst);
      print "# de-installed: $src\n";
    }
    else {
      install_pkg($src, $dst);
      print "# installed: $src\n";
      if ($src =~ m!^(personal/sec)/!) {
        my @chmod = (
          'chmod', 'go-rwx', '-R',
          File::Spec->join($pkg->wd, $1),
        );
        print "@chmod\n";
        system @chmod;
        my $exit = $? >> 8;
        warn "Warning: chmod failed\n" if $exit != 0;
      }
    }
  }
}

sub deprecate_pkg {
  my ($src, $dst) = @_;
  debug("$src is deprecated; checking not installed ...\n");
  system $cfg{STOW},
      '-c',            # Dummy run, checking for conflicts.  If we're
                       # not using the deprecated package, there won't
                       # be any.
      ($opts{debug} ? '-vvv' : ()),
      ($opts{thorough} ? () : '-p'),
      '-R',            # Remove any symlinks already there.
      '-t', $cfg{TARGET_DIR},
      '-d', $cfg{PKG_DIR},
      $dst;
  my $exit = $? >> 8;
  warn "$cfg{STOW} -c failed; aborting!\n" if $exit != 0;
}

sub delete_pkg {
  my ($dst) = @_;
  my @args = (
    (for_real() ? () : ( '-n' )),
    ($opts{debug} ? '-vvv' : ()),
    ($opts{thorough} ? () : '-p'),
    '-D',
    '-t', $cfg{TARGET_DIR},
    '-d', $cfg{PKG_DIR},
    $dst
  );
  debug("delete: $cfg{STOW} @args\n");
  system $cfg{STOW}, @args;
  my $exit = $? >> 8;
  warn "$cfg{STOW} -c failed; aborting!\n" if $exit != 0;
}

sub install_pkg {
  my ($src, $dst) = @_;
  my $stow_args = qq{-t "$cfg{TARGET_DIR}" -d "$cfg{PKG_DIR}" "$dst"};
  $stow_args = "-vvv $stow_args" if $opts{debug};
  $stow_args = "-p $stow_args"   if ! $opts{thorough};
  my $cmd       = "$cfg{STOW} -c -R $stow_args";
  (my $human_cmd = $cmd) =~ s!\b$ENV{HOME}/!~/!g;
  debug("preempt: $cmd\n");
  open(STOW, "$cmd 2>&1 |") or die "open($human_cmd|) failed: $!\n";
  while (<STOW>) {
    if (/^CONFLICT: (.+) vs. (.+?)( \(.*?\))?$/) {
      #print;
      my ($src, $symlink) = ($1, $2);
      preempt_conflict($src, $symlink);
      next;
    }

    #debug("! surplus stow -c output: $_");
    print "$_";
  }
  close(STOW) or die "close($human_cmd|) failed: $!\n";

  # Should have preempted all conflicts now; run for real.
  $cmd = "$cfg{STOW} -R $stow_args";
  ($human_cmd = $cmd) =~ s!(^|\s)$ENV{HOME}/!$1~/!g;
  debug("post-preempt: $human_cmd\n");
  if (for_real()) {
    system $cmd;
    my $exit = $? >> 8;
    warn "$cfg{STOW} failed; aborting!\n" if $exit != 0;
  }

  my $post_hook = File::Spec->join($cfg{TARGET_DIR}, '.cfg-post.d', $dst);
  if (-x $post_hook) {
    print "# Running $post_hook ...\n";
    my $pkg_dir = File::Spec->join($cfg{PKG_DIR}, $dst);
    chdir($pkg_dir) or die "chdir($pkg_dir) failed: $!\n";
    system $post_hook;
    my $exit = $? >> 8;
    warn "Warning: $post_hook failed\n" if $exit != 0;
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
  use Carp qw(carp cluck croak confess);
  
  my ($r_dev, $r_ino) = stat($required_target)
    or confess "stat($required_target) failed: $!";
  if ($a_dev != $r_dev or $a_ino != $r_ino) {
    die "$symlink already exists and points to the wrong place; aborting!\n";
  }
}

=head1 BUGS

=head1 SEE ALSO

=cut

1;
