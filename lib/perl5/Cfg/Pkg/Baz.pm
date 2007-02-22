package Cfg::Pkg::Baz;

=head1 NAME

Cfg::Pkg::Baz - base class for cfgctl configuration packages

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use File::Path;

use Cfg::Utils qw(debug);
use base 'Cfg::Pkg::Base';

my $BAZ_CMD = 'baz';

#use overload '""' => \&to_str;

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
    co_root  => $co_root,  # e.g. ~/.baz
    archive  => $archive,  # e.g. mwolson@gnu.org--2006
    revision => $revision, # e.g. muse--main--1.0
    dst      => $dst,      # e.g. muse (stow package name)
    relocate => $relocate, # e.g. lib/emacs/major-modes
  }, $class;
}

=head1 TREE RELOCATION

Unlike CVS, GNU arch enforces a flat storage model, so that checkouts
never have any directory depth.  Therefore any required depth has to
be ensured out of band.

Example: we want C<muse--main--1.0> to appear as a subtree at
C<~/lib/emacs/major-modes/muse>.

First we check out to a predictable location:

    ~/.baz/                                      <= $co_root  \
        arch@adamspiers.org--upstream-2006-d600/ <= $archive  | <= _src()
          muse--main--1.0/                       <= $revision /
            a/
              file 

Then we need some way of relocating the branch's contents to deeper
within the dedicated stow package tree...

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

sub maybe_check_out {
  my $self = shift;

  my $archive      = $self->archive;
  my $revision     = $self->revision;
  my $archrev      = "$archive/$revision";
  my $archive_path = $self->archive_path;

  if (! -d $archive_path) {
    mkpath($archive_path) or die "mkpath($archive_path) failed: $!\n";
  }

  my $src = $self->_src;
  if (-d $src) {
    debug("# $archrev already checked out in $archive_path\n");
    return;
  }

  print "Checking out $revision in $archive_path ...\n";
  my @cmd = ( $BAZ_CMD, 'get', '-A', $archive, $revision, $src );
  system @cmd;
  my $exit = $? >> 8;
  die "command @cmd failed; aborting!\n" if $exit != 0;
}

sub to_string {
  my $self = shift;
  return $self->{src};
  return sprintf "%s: %s -> %s", @$self{qw/co_root src dst/};
}

sub co_root    { shift->{co_root}    }
sub archive    { shift->{archive}    }
sub revision   { shift->{revision}   }
sub dst        { shift->{dst}        }
sub relocation { shift->{relocation} }

sub archive_path {
  my $self = shift;
  return File::Spec->join($self->co_root, $self->archive);
}

sub _src {
  my $self = shift;
  return File::Spec->join($self->archive_path, $self->revision);
}

sub deprecated { 0 }

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
