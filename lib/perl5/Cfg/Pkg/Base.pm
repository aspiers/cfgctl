package Cfg::Pkg::Base;

=head1 NAME

Cfg::Pkg::Base - base class for cfgctl configuration packages

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Cfg::Utils qw(debug
                  ensure_correct_symlink preempt_conflict for_real
                  %cfg %opts);

=head1 CONSTRUCTORS

=cut

=head1 METHODS

=cut

sub process {
  my $self = shift;

  maybe_check_out $self;

  my $src = $self->src;
  my $dst = $self->dst;

  ensure_correct_symlink(
    File::Spec->join($cfg{PKG_DIR}, $dst),
    File::Spec->join($self->wd, $src),
  );

  if ($src =~ /RETIRE/) {
    print "#! deprecating: $src\n";
    $self->deprecate;
  }
  else {
    if ($opts{delete}) {
      $self->deinstall;
      print "# de-installed: $src\n";
    }
    else {
      $self->install;
      print "# installed: $src\n";
      if ($src =~ m!^(personal/sec)/!) {
        my @chmod = (
          'chmod', 'go-rwx', '-R',
          File::Spec->join($self->wd, $1),
        );
        print "@chmod\n";
        system @chmod;
        my $exit = $? >> 8;
        warn "Warning: chmod failed\n" if $exit != 0;
      }
    }
  }
}

sub deprecate {
  my $self = shift;
  my $src = $self->src;
  my $dst = $self->dst;
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

sub deinstall {
  my $self = shift;
  my $dst = $self->dst;
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

sub install {
  my $self = shift;
  my $src = $self->src;
  my $dst = $self->dst;
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

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::CVS>, L<cfgctl>

=cut

1;
