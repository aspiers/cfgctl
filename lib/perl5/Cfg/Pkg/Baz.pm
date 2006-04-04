package Cfg::Pkg::Baz;

=head1 NAME

Cfg::Pkg::Baz - base class for cfgctl configuration packages

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Cfg::Utils qw(debug);
use base 'Cfg::Pkg::Base';

use overload '""' => \&to_str;

=head1 CONSTRUCTORS

=head2 new($co_root, $archive, $revision, $dst, $relocate)

C<$revision> could be C<CATEGORY--BRANCH--VERSION> or
C<CATEGORY--BRANCH--VERSION--REVISION>.

=cut

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($co_root, $archive, $revision, $dst, $relocate) = @_;
  return bless {
    co_root  => $co_root,
    archive  => $archive,
    revision => $revision,
    dst      => $dst,
    relocate => $relocate,
  }, $class;
}

=head1 TREE RELOCATION

Unlike CVS, GNU arch enforces a flat storage model, so that checkouts
never have any directory depth.  Therefore any required depth has to
be ensured out of band.

Example: we want C<muse--main--1.0> to appear as a subtree at
C<~/lib/emacs/major-modes/muse>.

First we check out to a predictable location:

    ~/.baz/
        arch@adamspiers.org--upstream-2006-d600/
          muse--main--1.0/                       == $src
            a/
              file 

Then we need some way of relocating the branch's contents to deeper
within the dedicated stow package tree...

=head2 Strategy 1

Relocate using a separate tree C<~/.baz-relocations>:

    ~/.baz-relocations/
        arch@adamspiers.org--upstream-2006-d600/  <-- stow dir
          muse--main--1.0/                        <-- symlink from ~/.cfg/muse
            lib/                                }
              emacs/                            } relocation
                major-modes/                    } path
                  muse/                         } <-- symlink to $src
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

  - no extra layer of indirection, but unlikely to help performance

Cons:

  - C<~/.cfg> contents are not purely symlinks

=head2 Solution

Strategy 1 wins (just).

=cut

sub maybe_check_out {
  my $self = shift;

  my $wd = $self->wd;
  my $src = $self->src;
  if (-d File::Spec->join($wd, $src)) {
    debug("# $src already checked out in $wd\n");
    return;
  }

  chdir($wd) or die "chdir($wd) failed: $!\n";
  print "Checking out $src ...\n";
  system 'cvs', 'checkout', $src;
  my $exit = $? >> 8;
  die "cvs checkout $src failed; aborting!\n" if $exit != 0;
}

sub to_string {
  my $self = shift;
  return $self->{src};
  return sprintf "%s: %s -> %s", @$self{qw/wd src dst/};
}

sub wd  { shift->{wd } }
sub src { shift->{src} }
sub dst { shift->{dst} }

sub to_str {
  my $self = shift;
  return $self->wd . ":" . $self->dst;
}

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
