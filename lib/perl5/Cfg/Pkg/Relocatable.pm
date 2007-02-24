package Cfg::Pkg::Relocatable;

=head1 NAME

Cfg::Pkg::Relocatable - mix-in for relocatable source control mechanisms

=head1 SYNOPSIS

synopsis

=head1 DESCRIPTION

description

=head1 TREE RELOCATION

It's easiest to demonstrate this issue with an example: let's say we
want C<muse--main--1.0> checked out from the maintainer's upstream
repository to appear in its final usable location as a subtree at
C<~/lib/emacs/major-modes/muse>.

CVS allows you to locate modules at arbitrarily deep paths within a
single repository, so if the C<muse> code was in CVS repository of our
choosing, we could do something like

    $ cvs checkout lib/emacs/major-modes/muse

But it's not, and in contrast to CVS, most modern SCMs enforce a flat
storage model, so that checkouts never have any directory depth.  So
if we use C<tla> or C<baz> to check out the upstream C<muse> package,
the required "extra depth" (i.e. lib/emacs/major-modes) has to be
ensured out of band with respect to the SCM involved.

So first we check out to a predictable location indexed initially by
the particular SCM being used:

    ~/.baz/                                      <= $co_root  \
        arch@adamspiers.org--upstream-2006-d600/ <= $archive  | <= _src()
          muse--main--1.0/                       <= $revision /
            a/
              file 

Then we need some way of relocating the branch's contents to a deeper
point within the dedicated stow package tree...

=head2 Strategy 1

Relocate using a separate tree C<~/.baz-relocations>:

    ~/.baz-relocations/
        arch@adamspiers.org--upstream-2006-d600/  <-- stow dir
          muse--main--1.0/                        <-- symlink from ~/.cfg/muse
            lib/                                  \
              emacs/                              | 
                major-modes/                      | <= $relocate
                  muse/       <-- symlink to $src / 
                    a/
                      file

Pros:

  - makes it clear what's going on
  - consistent view of stow package tree, retrievable by both 
    baz archive/revision and C<$dst> key

Cons:

  - requires extra directory
  - requires extra layer of indirection

=head2 Strategy 2

Symlink:

    ~/.cfg/muse/lib/emacs/major-modes/muse -> $src

Pros:

  - no extra layer of indirection, but unlikely to help performance anyway

Cons:

  - C<~/.cfg> contents are not purely symlinks

=head2 Solution

Strategy 1 wins (just).

=cut

use strict;
use warnings;

use Carp qw(carp cluck croak confess);
use File::Path;
use File::Spec;

use Cfg::Utils qw(debug ensure_correct_symlink);

sub relocation       { shift->{relocation}               }
sub relocations_root { shift->{co_root} . "-relocations" }

sub relocation_path {
  my $self = shift;
  my $sub = (caller(0))[3];
  $sub =~ s/.+:://;
  my $me = ref($self) . "::$sub";
  confess <<EOF;
$me should be overridden to the full path to the
directory containing the source of the relocation symlink.
EOF
}

sub ensure_relocation {
  my $self = shift;

  my $relocation_prefix = $self->relocation_path;
  debug(1, "# Relocating ", $self->description, " to .../", $self->relocation, "\n");

  if (-d $relocation_prefix) {
    debug(2, "relocation_prefix $relocation_prefix already exists\n");
  }
  else {
    mkpath($relocation_prefix);
    debug(2, "created relocation_prefix $relocation_prefix\n");
  }
  
  ensure_correct_symlink(
    symlink => File::Spec->join($self->relocation_path, $self->dst),
    required_target => $self->_co_to,
  );
}

=head1 BUGS

=head1 SEE ALSO

=cut

1;
