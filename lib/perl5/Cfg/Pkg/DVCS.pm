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

=head2 new($co_root, $dst, $upstream, $relocate)

=over 4

=item $co_root

The local directory containing all repositories for this type of
backend, e.g. F<~/.git>.

=item $dst

Package name, e.g. F<org-mode>.

=item $upstream

Path / URL to upstream sources

=item $relocate (optional)

The path under which to install package source files.

=back

=cut

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($co_root, $dst, $upstream, $relocate) = @_;

  die "${class}->new() called without \$upstream" unless $upstream;

  $relocate =~ s/\$DST/$dst/g if $relocate;

  my $pkg = bless {
    co_root  => $co_root,  # e.g. ~/.bzr
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
  return -d $self->_co_to;
}

sub fetch {
  my $self = shift;

  my $root = $self->co_root;
  if (! -d $root) {
    mkdir $root or die "mkdir($root) failed: $!\n";
  }
  my $class = ref($self) || $self;
  my $description = $self->description;
  debug(2, "#   Fetching $description");
  my @cmd = (
    $self->DVCS_CMD, $self->DVCS_FETCH_CMD,
    $self->upstream, $self->_co_to,
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

sub co_root     { shift->{co_root}    }
sub upstream    { shift->{upstream}   }
sub dst         { shift->{dst}        }
sub relocation  { shift->{relocate}   }

sub description { shift->dst          }

sub params {
  my $self = shift;
  return map $self->$_, qw(dst co_root upstream relocation);
}

# where to check out to, e.g. ~/.bzr/dvc
sub _co_to {
  my $self = shift;
  my $quoted_upstream = $self->upstream;
  $quoted_upstream =~ tr,/,_,;
  return File::Spec->join($self->co_root, $quoted_upstream);
}

# e.g. ~/.bzr/dvc
#   or ~/.bzr-relocations/dvc
sub src {
  my $self = shift;
  return $self->_co_to unless $self->relocation;
  return File::Spec->join(
    $self->relocations_root,
    $self->dst,
  );
}

# e.g. ~/.baz-relocations/dvc/lib/emacs/major-modes/dvc
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

=cut

1;
