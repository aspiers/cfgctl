package Cfg::Pkg::Arch;

=head1 NAME

Cfg::Pkg::Arch - subclass for cfgctl configuration packages managed by tla/baz

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Carp qw(carp cluck croak confess);
use File::Path;

use Cfg::Utils qw(debug);

use base qw(Cfg::Pkg::Relocatable Cfg::Pkg::Base);

sub ARCH_CMD {
  my $self = shift;
  my $sub = (caller(0))[3];
  $sub =~ s/.+:://;
  my $me = ref($self) . "::$sub";
  confess <<EOF;
$me should be overridden to return the arch executable e.g. tla or baz
EOF
}

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

sub ensure_src_local {
  my $self = shift;

  $self->maybe_check_out;
  $self->ensure_relocation if $self->relocation;
}

sub maybe_check_out {
  my $self = shift;

  my $archive      = $self->archive;
  my $revision     = $self->revision;
  my $archrev      = "$archive/$revision";
  my $archive_path = $self->archive_path;

  my $co_to = $self->_co_to;
  if (-d $co_to) {
    debug("# $archrev already checked out in $co_to\n");
    return;
  }

  if (! -d $archive_path) {
    mkpath($archive_path) or die "mkpath($archive_path) failed: $!\n";
  }
  
  print "Checking out $revision in $archive_path ...\n";
  my @cmd = ( $self->ARCH_CMD, 'get', '-A', $archive, $revision, $co_to );
  system @cmd;
  my $exit = $? >> 8;
  die "command @cmd failed; aborting!\n" if $exit != 0;
}

sub to_string {
  my $self = shift;
  return $self->{src};
  return sprintf "%s: %s -> %s", @$self{qw/co_root src dst/};
}

sub co_root     { shift->{co_root}    }
sub archive     { shift->{archive}    }
sub revision    { shift->{revision}   }
sub dst         { shift->{dst}        }
sub relocation  { shift->{relocate}   }

# e.g. mwolson@gnu.org--2006/muse--main--1.0
sub description {
  my $self = shift;
  return $self->archive . '/' . $self->revision;
}

# e.g. ~/.baz/mwolson@gnu.org--2006
sub archive_path {
  my $self = shift;
  return File::Spec->join($self->co_root, $self->archive);
}

# where to check out to, e.g. ~/.baz/mwolson@gnu.org--2006/muse--main--1.0
sub _co_to {
  my $self = shift;
  return File::Spec->join($self->archive_path, $self->revision);
}

sub src {
  my $self = shift;
  return $self->_co_to unless $self->relocation;
  return File::Spec->join(
    $self->relocations_root,
    $self->archive, $self->revision,
  );
}

# e.g. ~/.baz-relocations/mwolson@gnu.org--2006/muse--main--1.0/lib/emacs/major-modes (note dst 'muse' is missing off the end)
sub relocation_path {
  my $self = shift;
  
  return File::Spec->join(
    $self->src,
    $self->relocation
  );
}

sub deprecated { 0 }

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
