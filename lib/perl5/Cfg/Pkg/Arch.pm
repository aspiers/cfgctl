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
use File::Spec;
use File::Which;

use Cfg::CLI qw(debug %opts for_real);
use Sh qw(sys_or_warn sys_or_die);

use base qw(Cfg::Pkg::Relocatable Cfg::Pkg::Base);

my %queues;

sub ARCH_CMD {
  my $self = shift;
  my $sub = (caller(0))[3];
  $sub =~ s/.+:://;
  my $me = ref($self) . "::$sub";
  confess <<EOF;
$me should be overridden to return the arch executable e.g. tla or baz
EOF
}

=head1 CONSTRUCTORS

=head2 new($co_root, $dst, $archive, $revision, $relocate)

C<$revision> could be C<CATEGORY--BRANCH--VERSION> or
C<CATEGORY--BRANCH--VERSION--REVISION>.

=cut

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($co_root, $dst, $archive, $revision, $relocate) = @_;

  if ($relocate) {
    $relocate =~ s/\$DST/$dst/g;
    $relocate =~ s/\$REV/$revision/g;
  }

  my $pkg = bless {
    co_root  => $co_root,  # e.g. ~/.baz
    archive  => $archive,  # e.g. mwolson@gnu.org--2006
    revision => $revision, # e.g. muse--main--1.0
    dst      => $dst,      # e.g. muse (stow package name)
    relocate => $relocate, # e.g. lib/emacs/major-modes/muse
  }, $class;

  unless ($class->arch_cmd_ok) {
    my $ARCH_CMD = $class->ARCH_CMD;
    my $reason = "$ARCH_CMD not found";
    debug(0, "# ! Disabling $dst - $reason");
    $pkg->disable($reason);
    return $pkg;
  }

  unless ($class->archive_valid($archive)) {
    my $ARCH_CMD = $class->ARCH_CMD;
    $pkg->disable("$ARCH_CMD archive $archive not found");
    return $pkg;
  }

  return $pkg;
}

sub arch_cmd_ok {
  my $class = shift;
  return which($class->ARCH_CMD);
}

sub archive_valid {
  my $class = shift;
  my ($archive) = @_;
  my $ARCH_CMD = $class->ARCH_CMD;
  chomp(my $check = `$ARCH_CMD archives $archive`);
  return index($check, $archive) >= 0;
}

sub src_local {
  my $self = shift;
  return -d $self->_co_to;
}

sub _ensure_archive_path_exists {
  my $self = shift;

  my $archive_path = $self->archive_path;
  if (for_real() && ! -d $archive_path) {
    mkpath($archive_path) or die "mkpath($archive_path) failed: $!\n";
  }
}

sub fetch {
  my $self = shift;
  my $ARCH_CMD = $self->ARCH_CMD;
  my @cmd = ( $ARCH_CMD, 'get', $self->archrev, $self->_co_to );
  my $revision = $self->revision;
  my $archive_path = $self->archive_path;
  debug(1, "$ARCH_CMD get $revision to $archive_path ...");
  sys_or_die(cmd => \@cmd) if for_real();
}

sub update {
  my $self = shift;

  my $co_to = $self->_co_to;
  chdir($co_to) or die "chdir($co_to) failed: $!\n";

  my @cmd = (
    $self->ARCH_CMD,
    for_real() ? 'merge' : 'missing',
    $self->archrev
  );

  if ($self->src_local) {
    sys_or_die(cmd => \@cmd);
  }
  elsif (! for_real()) {
    debug(2, "#   if src was local, would have done @cmd");
  }
}

sub co_root     { shift->{co_root}    }
sub archive     { shift->{archive}    }
sub revision    { shift->{revision}   }
sub dst         { shift->{dst}        }
sub relocation  { shift->{relocate}   }

sub archrev {
  my $self = shift;
  my $archive  = $self->archive;
  my $revision = $self->revision;
  return File::Spec->join($archive, $revision);
}

# e.g. mwolson@gnu.org--2006/muse--main--1.0
sub description {
  my $self = shift;
  return $self->archive . '/' . $self->revision;
#  return sprintf "%s: %s -> %s", @$self{qw/co_root src dst/};
}

sub params {
  my $self = shift;
  return map $self->$_, qw(dst archive revision co_root relocation);
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

# e.g. ~/.baz/mwolson@gnu.org--2006/muse--main--1.0
#   or ~/.baz-relocations/mwolson@gnu.org--2006/muse--main--1.0
sub src {
  my $self = shift;
  return $self->_co_to unless $self->relocation;
  return File::Spec->join(
    $self->relocations_root,
    $self->archive, $self->revision,
  );
}

# e.g. ~/.baz-relocations/mwolson@gnu.org--2006/muse--main--1.0/lib/emacs/major-modes/muse
sub relocation_path {
  my $self = shift;
  
  return File::Spec->join(
    $self->src,
    $self->relocation
  );
}

sub batch      { 0 }
sub deprecated { 0 }

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
