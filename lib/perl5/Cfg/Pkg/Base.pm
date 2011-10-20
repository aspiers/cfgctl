package Cfg::Pkg::Base;

=head1 NAME

Cfg::Pkg::Base - abstract base class for cfgctl configuration packages

=head1 SYNOPSIS

Any mechanism for retrieving files via an SCM check-out or other
process should be implemented as a sub-class of this base class.

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Sh qw(ensure_correct_symlink);
use Cfg::CLI qw(debug for_real %opts);
use Cfg::Cfg qw(%cfg);
use Cfg::Pkg::Utils qw(preempt_conflict);
use Carp qw(carp cluck croak confess);

=head1 CONSTRUCTORS

See derived classes.

=cut

=head1 METHODS

=cut

sub multi {
  my $self = shift;
  my $class = ref($self) || $self;
  my $block = pop @_;
  my @common_args = @_;
  debug(3, "# ${class}::multi(" . join(", ", @common_args) . ", [$block])");
  my @new_pkgs;
  my @args = $class->pkg_arg_sets_from_block($block);
  for my $pkg_args (@args) {
    push @new_pkgs, $class->new(@common_args, @$pkg_args);
  }
  return @new_pkgs;
}

sub pkg_arg_sets_from_block {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($block) = @_;

  confess "no block passed" unless $block;
  my @lines = split /\n/, $block;
  my @args;
  for my $line (@lines) {
    debug(5, "     line [$line]");
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    next unless $line;
    next if $line =~ /^#/;
    push @args, [ split /\s+/, $line ];
  }
  return @args;
}

sub deprecate {
  my $self = shift;
  my $description = $self->description;
  my $dst = $self->dst;
  debug(1, "$description is deprecated; checking not installed ...");
  $self->ensure_install_symlink;
  system $cfg{STOW},
      '-c',            # Dummy run, checking for conflicts.  If we're
                       # not using the deprecated package, there won't
                       # be any.
      ($opts{debug} ? '-vvv' : ()),
      ($opts{thorough} ? () : '-p'),
      '-R',            # Remove any symlinks already there.
      '-t', $cfg{TARGET_DIR},
      '-d', $cfg{PKGS_DIR},
      $dst;
  my $exit = $? >> 8;
  warn "$cfg{STOW} -c failed; aborting!\n" if $exit != 0;
}

sub _not_implemented {
  my $self = shift;
  my ($error) = @_;

  my $class = ref($self) || $self;
  my $sub = (caller(1))[3];
  $sub =~ s/.+:://;
  my $me = "${class}::$sub";
  $error =~ s/CLASS/$class/g;
  $error =~ s/ME/$me/g;
  confess $error;
}

# Syntactic sugar, but some SCMs might not reuse code between update
# and clone operations, so we need to keep the interfaces separate.
sub enqueue_update       { shift->enqueue_op('update');    }
sub enqueue_clone        { shift->enqueue_op('clone');     }
sub enqueue_push         { shift->enqueue_op('push');      }
sub process_update_queue { shift->process_queue('update'); }
sub process_clone_queue  { shift->process_queue('clone');  }
sub process_push_queue   { shift->process_queue('push');   }

sub enqueue_op {
  not_yet_supported(@_);
}

sub process_queue {
  not_yet_supported(@_);
}

sub not_yet_supported {
  my $self = shift;
  my ($op) = @_;
  my $plural = "${op}s";
  $plural = 'clones' if $op eq 'clone';
  die <<EOF;
CLASS does not yet support $plural.

To add support, override CLASS::enqueue_$op and 
CLASS::process_${op}_queue.

Note that it will also be responsible for checking out any
non-existing sources, etc.
EOF
}

sub ensure_install_symlink {
  my $self = shift;
  ensure_correct_symlink(
    symlink => $self->install_symlink,
    required_target => $self->src,
  );
}

sub install_symlink {
  my $self = shift;
  return File::Spec->join($cfg{PKGS_DIR}, $self->dst);
}

sub src_local {
  my $self = shift;
  return -d $self->src;
}

=head2 deinstall()

Invoke stow to uninstall the package.

=cut

sub deinstall {
  my $self = shift;
  my $dst = $self->dst;
  $self->ensure_install_symlink;
  my @args = (
    (for_real() ? () : ( '-n' )),
    ($opts{debug} ? '-vvv' : ()),
    ($opts{thorough} ? () : '-p'),
    '-D',
    '-t', $cfg{TARGET_DIR},
    '-d', $cfg{PKGS_DIR},
    $dst
  );
  debug(3, "delete: $cfg{STOW} @args");
  system $cfg{STOW}, @args;
  my $exit = $? >> 8;
  warn "$cfg{STOW} -c failed; aborting!\n" if $exit != 0;
  my $is = $self->install_symlink;
  unlink($is) or die "unlink($is) failed: $!\n";
}

=head2 deinstall()

Invoke stow to install the package.

=cut

sub install {
  my $self = shift;
  my $dst = $self->dst;

  $self->ensure_install_symlink;

  my $stow_args = qq{-t "$cfg{TARGET_DIR}" -d "$cfg{PKGS_DIR}" "$dst"};
  $stow_args = "-vvv $stow_args" if $opts{debug};
  $stow_args = "-p $stow_args"   if ! $opts{thorough};
  my $cmd       = "$cfg{STOW} -c -R $stow_args";
  (my $human_cmd = $cmd) =~ s!\b$ENV{HOME}/!~/!g;
  debug(3, "preempt: $cmd");
  open(STOW, "$cmd 2>&1 |") or die "open($human_cmd|) failed: $!\n";
  while (<STOW>) {
    if (/^CONFLICT: (.+) vs. (.+?)( \(.*?\))?$/) {
      my ($src, $symlink) = ($1, $2);
      preempt_conflict($src, $symlink);
      next;
    }

    debug(4, "! surplus stow -c output: $_");
    warn $_;
  }
  close(STOW) or die "close($human_cmd|) failed: $!\n";

  # Should have preempted all conflicts now; run for real.
  $cmd = "$cfg{STOW} -R $stow_args";
  ($human_cmd = $cmd) =~ s!(^|\s)$ENV{HOME}/!$1~/!g;
  debug(3, "post-preempt: $human_cmd");
  if (for_real()) {
    system $cmd;
    my $exit = $? >> 8;
    warn "$cfg{STOW} failed; aborting!\n" if $exit != 0;
  }

  my $post_hook = File::Spec->join($cfg{POST_DIR}, $dst);
  if (-x $post_hook) {
    if (for_real()) {
      debug(1, "# Running $post_hook ...");
      my $pkg_dir = File::Spec->join($cfg{PKGS_DIR}, $dst);
      chdir($pkg_dir) or die "chdir($pkg_dir) failed: $!\n";
      system $post_hook;
      my $exit = $? >> 8;
      warn "Warning: $post_hook failed\n" if $exit != 0;
    }
    else {
      debug(1, "# Would run $post_hook");
    }
  }
}

=head2 clone()

Clone the repository/sources from upstream.  Used if C<src_local()>
returns false.

=cut

sub clone {
  shift->_not_implemented(<<EOF);
ME should be overridden - CLASS backend not yet finished?
EOF
}

=head2 update()

Retrieve the latest upstream sources.  When implemented by a
distributed version control system, this requires first fetching them
from upstream, and then merging them with the local branch (i.e. "git
pull" or "hg fetch").

=cut

sub update {
  my $self = shift;
  my $class = ref $self;
  debug(3, "# Skipping unimplemented per-instance update for $class");
}

=head2 pull()

Pull the latest sources from upstream, but don't merge them locally
(i.e. this uses Mercurial's definition of "pull", which corresponds to
"fetch" in git).  Only implemented by distributed version control
systems.

=cut

sub pull {
  my $self = shift;
  my $class = ref $self;
  debug(3, "# Skipping unimplemented per-instance pull for $class");
}

=head2 push_upstream()

Push the latest sources upstream.  Only implemented by distributed
version control systems.

=cut

sub push_upstream {
  my $self = shift;
  my $class = ref $self;
  debug(3, "# Skipping unimplemented per-instance push_upstream for $class");
}

sub description {
  shift->_not_implemented(<<EOF);
ME should be overridden to return a human-readable description
of the package for use with debug lines like
  Installed: <description>
EOF
}

sub params {
  shift->_not_implemented(<<EOF);
ME should be overridden to return a list of the public parameters
to be output when generating a machine-readable package map.
EOF
}

sub dst {
  shift->_not_implemented(<<EOF);
ME should be overridden to return the unique package name as used by stow,
e.g. F<mutt> or F<emacs>.
It is the name of symlink which lives under the stow directory
(defined by C<$Cfg::Cfg::cfg{PKGS_DIR}>, typically F<~/.cfg>).
Each package on the local system must return a unique value.
EOF
}

sub src {
  shift->_not_implemented(<<EOF);
ME should be overridden to return the path to the package source,
which the symlink under C<$Cfg::Cfg::cfg{PKGS_DIR}> points to, e.g. 

   ~/.cvs/config/dev-tools/perl/mine

which is pointed to by

   ~/.cfg/perl+mine
EOF
}

sub batch    {
  shift->_not_implemented(<<EOF);
ME should be overridden to return true or false depending on whether
updates/clones should be batched or processed per package.
EOF
}

# Allow disabling per instance.  Switched from reblessing into
# Cfg::Pkg::Disabled because:
#  - no real benefit to implementing disabled checks all within
#    a disabled class vs within Cfg run logic
#  - can retain potentially useful class-specific package state
#  - treating the package's class as if it was a variable is ugly
sub disabled { shift->{disabled} || 0 }
sub disable {
  my ($self, $reason) = @_;
  my $dst = $self->dst;
  debug(0, "# ! Disabling $dst - $reason");
  shift->{disabled} = $reason;
}

sub deprecated  {
  shift->_not_implemented(<<EOF);
ME should be overridden to return true if the package is deprecated.
EOF
}

sub relocation { undef }

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::CVS>, L<cfgctl>

=cut

1;
