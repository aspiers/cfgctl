package Cfg::Pkg::Relocatable;

=head1 NAME

Cfg::Pkg::Relocatable - mix-in for relocatable source control mechanisms

=head1 SYNOPSIS

  use base qw(Cfg::Pkg::Relocatable);

=head1 DESCRIPTION

Mix-in class for Cfg::Pkg::Base backend class hierarchy, providing
methods for relocating install of packages to arbitrary places in the
filesystem.

=head1 TREE RELOCATION

It's easiest to demonstrate this issue with an example: let's say we
want C<muse--main--1.0> checked out from the maintainer's upstream
repository to appear in its final usable location as a subtree at
C<~/lib/emacs/major-modes/muse>.

CVS allows you to locate modules at arbitrarily deep paths within a
single repository, so if the C<muse> code was in CVS repository of our
choosing, we could do something like

    $ cvs checkout lib/emacs/major-modes/muse

But it's not, and in contrast to CVS, most modern SCMs (svn excluded)
enforce a flat storage model, so that checkouts never have any
directory depth.  So if we use C<tla> or C<baz> to check out the
upstream C<muse> package, the required "extra depth"
(i.e. lib/emacs/major-modes) has to be ensured out of band with
respect to the SCM involved.

So first we check out to a predictable location indexed initially by
the particular SCM being used:

    ~/.baz/                                                   \
        arch@adamspiers.org--upstream-2006-d600/ <= $archive  | <= src()
          muse--main--1.0/                       <= $revision /
            a/
              file 

Then we need some way of relocating the branch's contents to a deeper
point within the dedicated stow package tree...

=head2 Strategy 1

Relocate using a separate tree C<~/.baz-relocations> which contains
extra relocation directories:

                 ~/.baz-relocations/
                   arch@adamspiers.org--upstream-2006-d600/  <= stow dir
  ~/.cfg/muse ->     muse--main--1.0/                        
                 /     lib/
                 |       emacs/
    $relocate => |         major-modes/
                 \           muse/       -> $src
                                              top-level-dir-upstream/
  Key:                                          upstream-file
    symlink -> target
    comment => thing being commented on

Pros:

  - makes it clear what's going on
  - consistent view of stow package tree, retrievable by both 
    baz archive/revision and C<$dst> key

Cons:

  - requires extra directory
  - requires extra layer of indirection

=head2 Strategy 2

Put extra relocation directions directly in C<~/.cfg> and use a
single symlink:

    ~/.cfg/muse/lib/emacs/major-modes/muse -> $src

Pros:

  - no extra layer of indirection, but unlikely to help performance anyway

Cons:

  - C<~/.cfg> contents are not purely symlinks

=head2 Solution

Strategy 1 wins - consistency is important.

=cut

use strict;
use warnings;

use Carp qw(carp cluck croak confess);
use File::Path;
use File::Spec;

use Cfg::Cfg qw(%cfg);
use Cfg::CLI qw(debug);
use Sh qw(ensure_correct_symlink);

=head1 METHODS

=head2 relocation()

Should be overridden to provide the path relative to
C<$Cfg::Cfg::cfg{TARGET_DIR}> (F<~>) which should be the root of the
hierarchy under which to install the package's source files,
e.g. F<lib/emacs/major-modes/org-mode>.

=cut

sub relocation {
  shift->_not_implemented(<<EOF);
ME should be overridden; see the pod for CLASS.
EOF
}

=head2 relocations_root()

The full path to the root of the relocations tree, e.g.
F<~/.git-relocations>.

=cut

sub relocations_root {
  shift->_not_implemented(<<EOF);
ME should be overridden; see the pod for CLASS.
EOF
}

=head2 relocation_path()

The full path to the directory containing the source of the relocation
symlink, e.g. F<~/.baz-relocations/dvc/lib/emacs/major-modes/dvc>

=cut

sub relocation_path {
  my $self = shift;
  
  return File::Spec->join(
    $self->src,
    $self->relocation
  );
}

# e.g. ~/.bzr/dvc
#   or ~/.bzr-relocations/dvc
sub src {
  my $self = shift;
  return $self->clone_to unless $self->relocation;
  return File::Spec->join(
    $self->relocations_root,
    $self->dst,
  );
}

sub ensure_relocation {
  my $self = shift;

  debug(1, "# Relocating ", $self->description, " to $cfg{TARGET_DIR}/",
           $self->relocation);

  my $rpath = $self->relocation_path;
  my ($container_dir, $symlink) = $self->_split_relocation_path;

  if (-d $container_dir) {
    debug(2, "#   relocation path $rpath already exists");
  }
  else {
    mkpath($container_dir);
    debug(2, "#   created $container_dir");
  }
  
  ensure_correct_symlink(
    symlink => $self->relocation_path,
    required_target => $self->clone_to, # FIXME shouldn't rely on private method
  );
}

# Returns something like
# ( "$ENV{HOME}/.GIT-relocations/cucumber-el/lib/emacs/major-modes",
#   "cucumber" )
sub _split_relocation_path {
  my $self = shift;
  my @dirs = File::Spec->splitdir($self->relocation_path);
  my $symlink = pop @dirs;
  my $container_dir = File::Spec->join(@dirs);
  return ($container_dir, $symlink);
}

sub remove_relocation {
  my $self = shift;

  my $desc  = $self->description;
  my $rpath = $self->relocation_path;

  if (-l $rpath) {
    debug(1, "# Removing relocation symlink for $desc: $rpath");
    unlink $rpath or die "unlink($rpath) failed: $!\n";
  }
  elsif (-e $rpath) {
    confess "ERROR: wanted to remove $rpath but it wasn't a relocation symlink";
  }
  else {
    debug(3, "# No relocation symlink to remove for $desc ($rpath)");
  }
}

=head1 BUGS

=head1 SEE ALSO

=cut

1;
