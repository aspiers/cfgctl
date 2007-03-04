package Cfg::Pkg::Port;

=head1 NAME

Cfg::Pkg::Port - subclass for *BSD-like port packages

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Carp qw(carp cluck croak confess);
use File::Path;
use File::Which;
use FindBin qw($RealBin $RealScript);

use Cfg::Pkg::Disabled;
use Cfg::Utils qw(debug %opts %cfg);

use base qw(Cfg::Pkg::Relocatable Cfg::Pkg::Base);

$cfg{make}       = 'make';
$cfg{PORTS_CONF} = "$RealBin/../etc/ports.conf";

my %queues;

=head1 CONSTRUCTORS

=head2 new($port, $dst, $relocate)

=cut

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($port, $dst, $relocate) = @_;
  $dst ||= $port;

  unless (-f $cfg{PORTS_CONF}) {
    my $reason = "$cfg{PORTS_CONF} not found";
    debug(0, "# ! Disabling $dst - $reason");
    return Cfg::Pkg::Disabled->new(
      $dst, __PACKAGE__, $dst, $reason,
    );
  }

  $relocate =~ s/\$PORT/$port/g if $relocate;

  my $new = bless {
    port     => $port,
    dst      => $dst,
    relocate => $relocate, # e.g. local
  }, $class;

  my $cmd = "$cfg{make} -f $cfg{PORTS_CONF} show-conf PORTNAME=$port";
  my $conf = `$cmd`;
  foreach my $type (qw{ports port status build install}) {
    my $var = "\U${type}\E_DIR";
    if ($conf =~ /^$var=(.+)/m) {
      $new->{"${type}_dir"} = $1;
    }
    else {
      die "$var not found in output of \`$cmd\`:\n$conf";
    }
  }

  unless (-d $new->{port_dir}) {
    my $reason = "port dir not found for port $port";
    debug(0, "# ! Disabling $dst - $reason");
    return Cfg::Pkg::Disabled->new(
      $dst, __PACKAGE__, $dst, $reason,
    );
  }

  return $new;
}

sub src_local {
  my $self = shift;
  return -f File::Spec->join($self->_status_dir, 'install');
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
    chdir($pkg->_port_dir) or die "chdir($pkg->_port_dir) failed: $!\n";
    system $cfg{make}, $op eq 'fetch'? 'install' : 'force-all';
  }
}

sub relocations_root { shift->{ports_dir} . "-relocations" }

sub dst         { shift->{dst}        }
sub relocation  { shift->{relocate}   }
sub _status_dir { shift->{status_dir} }
sub _ports_dir  { shift->{ports_dir}  }
sub _port_dir   { shift->{port_dir}   }

sub description { shift->dst          }

# where port installs to, e.g. ~/.ports/libtre/install
sub _co_to { # FIXME wrong method name
  my $self = shift;
  return $self->{install_dir};
}

# e.g. ~/.ports/libtre
#   or ~/.ports-relocations/libtre
sub src {
  my $self = shift;
  return $self->_co_to unless $self->relocation;
  return File::Spec->join(
    $self->relocations_root,
    $self->dst,
  );
}

# e.g. ~/.ports-relocations/libtre/local
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
