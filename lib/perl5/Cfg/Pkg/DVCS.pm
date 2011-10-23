package Cfg::Pkg::DVCS;

=head1 NAME

Cfg::Pkg::DVCS - base class for modern Distributed Version Control Systems

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Carp qw(carp cluck croak confess);
use File::Which;

use Cfg::CLI qw(debug for_real);
use Sh qw(sys_or_die);

use base qw(Cfg::Pkg::Relocatable Cfg::Pkg::Base);

my %queues;

sub DVCS_CMD { 
  my $self = shift;
  my $sub = (caller(0))[3];
  $sub =~ s/.+:://;
  my $class = ref($self);
  my $me = "${class}::$sub";
  die <<EOF;
$me should be overridden to return the command for the DVCS backend.
EOF
}

=head1 CONSTRUCTORS

=head2 new($clone_to, $dst, $upstream, $relocate)

=over 4

=item $clone_to

The local directory to which the upstream repository should be cloned,
e.g. F<~/.GIT/emacs>.

=item $dst

Package name, e.g. F<org-mode>.

=item $upstream (optional)

Path / URL to upstream sources.  This can be left unspecified if there
is no upstream and cfgctl is only being used to install the package
locally via stow, e.g. my personal config on adamspiers.org.

=item $relocate (optional)

The path relative to C<$Cfg::Cfg::cfg{TARGET_DIR}> (F<~>) which should
be the root of the hierarchy under which to install the package's
source files, e.g. F<lib/emacs/major-modes/org-mode>.  If unspecified,
uses C<$Cfg::Cfg::cfg{TARGET_DIR}>.

=back

=cut

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($clone_to, $dst, $upstream, $relocate) = @_;

  die "${class}->new() called without \$upstream" unless $upstream;

  $relocate =~ s/\$DST/$dst/g if $relocate;

  my $pkg = bless {
    clone_to => $clone_to, # e.g. ~/.bzr/dvc
    dst      => $dst,      # e.g. dvc (stow package name)
    upstream => $upstream, # e.g. http://bzr.xsteve.at/dvc/
    relocate => $relocate, # e.g. lib/emacs/major-modes/dvc
  }, $class;

  unless ($class->_cmd_ok) {
    my $reason = $class->DVCS_CMD . " not found";
    $pkg->disable($reason);
  }

  return $pkg;
}

sub _cmd_ok {
  my $class = shift;
  return which($class->DVCS_CMD);
}

sub src_local {
  my $self = shift;
  return -d $self->clone_to;
}

sub clone_if_upstream_exists {
  my $self = shift;

  unless ($self->upstream) {
    warn "Warning: ", $self->dst, " has no upstream to clone from\n";
    return;
  }

  $self->clone_from_upstream(@_);
}

sub clone_from_upstream {
  my $self = shift;

  my $class = ref($self) || $self;
  my $description = $self->description;
  debug(2, "#   Cloning $description");
  my @cmd = (
    $self->DVCS_CMD, $self->DVCS_CLONE_CMD,
    $self->upstream, $self->clone_to,
  );
  debug(1, "@cmd");
  sys_or_die(\@cmd) if for_real();
}

sub update {
  my $self = shift;

  $self->_not_implemented(<<EOF);
ME should be overridden to return a list of the public parameters
to be output when generating a machine-readable package map.
EOF
}

sub pull_if_upstream_exists {
  my $self = shift;

  unless ($self->upstream) {
    warn "Warning: ", $self->dst, " has no upstream to pull from\n";
    return;
  }

  $self->pull(@_);
}

sub push_if_upstream_exists {
  my $self = shift;

  unless ($self->upstream) {
    warn "Warning: ", $self->dst, " has no upstream to push to\n";
    return;
  }

  $self->push(@_);
}

sub clone_to    { shift->{clone_to}   }
sub dst         { shift->{dst}        }
sub upstream    { shift->{upstream}   }
sub relocation  { shift->{relocate}   }

sub description { shift->dst          }

sub params {
  my $self = shift;
  return map $self->$_, qw(dst clone_to upstream relocation);
}

sub batch      { 0 }
sub deprecated { 0 }

=head1 BUGS

=head1 SEE ALSO

=cut

1;
