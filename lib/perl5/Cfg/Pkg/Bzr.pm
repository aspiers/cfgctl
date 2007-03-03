package Cfg::Pkg::Bzr;

=head1 NAME

Cfg::Pkg::Bzr - subclass for cfgctl configuration packages managed by tla/baz

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Carp qw(carp cluck croak confess);
use File::Path;
use File::Which;

use Cfg::Pkg::Disabled;
use Cfg::Utils qw(debug %opts);

use base qw(Cfg::Pkg::Relocatable Cfg::Pkg::Base);

my %queues;

my $BZR_CMD = 'bzr';

=head1 CONSTRUCTORS

=head2 new($co_root, $url, $dst, $relocate)

=cut

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($co_root, $dst, $url, $relocate) = @_;

  unless ($class->bzr_cmd_ok) {
    my $reason = "$BZR_CMD not found";
    debug(0, "# ! Disabling $dst - $reason");
    return Cfg::Pkg::Disabled->new(
      $dst, __PACKAGE__, $dst, $reason,
    );
  }

  $relocate =~ s/\$DST/$dst/g;

  return bless {
    co_root  => $co_root,  # e.g. ~/.bzr
    url      => $url,
    dst      => $dst,      # e.g. dvc (stow package name)
    relocate => $relocate, # e.g. lib/emacs/major-modes/dvc
  }, $class;
}

sub bzr_cmd_ok {
  my $class = shift;
  return which($BZR_CMD);
}

sub src_local {
  my $self = shift;
  return -d $self->_co_to;
}

sub enqueue_op {
  my $self = shift;
  my ($op) = @_;
  die unless $op eq 'update' or $op eq 'fetch';
  push @{ $queues{$op} }, $self;
}

sub process_queue {
  my $class = shift;
  my ($op) = @_;
  die unless $op eq 'update' or $op eq 'fetch';

  foreach my $pkg (@{ $queues{$op} }) {
    my $description = $pkg->description;
    debug(2, "#   Package $description in ${class}'s $op queue");
    my $url   = $pkg->url;
    my $co_to = $pkg->_co_to;

    my $root = $pkg->co_root;
    if (! -d $root) {
      mkdir $root or die "mkdir($root) failed: $!\n";
    }

    my @cmd;
    if ($op eq 'fetch') {
      @cmd = ( $BZR_CMD, 'get', $url, $co_to );
      debug(1, "$BZR_CMD get $url to $co_to ...");
    }
    elsif ($op eq 'update') {
      chdir($co_to) or die "chdir($co_to) failed: $!\n";
      if ($opts{'test'}) {
        @cmd = ( $BZR_CMD, 'missing', $url );
      }
      else {
        @cmd = ( $BZR_CMD, 'merge', $url );
      }
    }
    else {
      die "unknown op $op";
    }

    system @cmd;
    my $exit = $? >> 8;
    die "command @cmd failed; aborting!\n" if $exit != 0;
  }
}

sub co_root     { shift->{co_root}    }
sub url         { shift->{url}        }
sub dst         { shift->{dst}        }
sub relocation  { shift->{relocate}   }

sub description { shift->dst          }

# where to check out to, e.g. ~/.bzr/dvc
sub _co_to {
  my $self = shift;
  return File::Spec->join($self->co_root, $self->dst);
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

sub deprecated { 0 }

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
