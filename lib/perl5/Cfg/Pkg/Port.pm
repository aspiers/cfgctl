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

use Cfg::Cfg qw(%cfg);
use Cfg::CLI qw(debug for_real);

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

  my $pkg = bless {
    port     => $port,
    dst      => $dst,
    relocate => $relocate, # e.g. local
  }, $class;

  unless (which('make')) {
    my $reason = "make not found";
    $pkg->disable($reason);
    return $pkg;
  }

  my $cmd = "$cfg{make} -f $cfg{PORTS_CONF} show-conf PORTNAME=$port";
  my $conf = `$cmd`;
  debug(2, "# Port $port");
  foreach my $type (qw{ports port status build install}) {
    my $var = "\U${type}\E_DIR";
    if ($conf =~ /^$var=(.+)/m) {
      debug(3, "#   ${type}_dir = $1");
      $pkg->{"${type}_dir"} = $1;
    }
    else {
      die "$var not found in output of \`$cmd\`:\n$conf";
    }
  }

  unless (-d $pkg->{port_dir}) {
    $pkg->disable("port dir not found for port $port");
  }

  return $pkg;
}

sub src_local {
  my $self = shift;
  return -f File::Spec->join($self->_status_dir, 'install');
}

sub update { shift->update_or_clone('update') }
sub clone  { shift->update_or_clone('clone')  }

sub update_or_clone {
  my $self = shift;
  my ($op) = @_;
  die unless $op eq 'update' or $op eq 'clone';

  my $class = ref($self);
  my $description = $self->description;
  debug(2, "#   Package $description in ${class}'s $op queue");
  chdir($self->_port_dir) or die "chdir($self->_port_dir) failed: $!\n";
  my $make_arg = $op eq 'clone' ? 'install' : 'force-all';
  if (for_real()) {
    system $cfg{make}, $make_arg;
  }
  else {
    debug(1, "#   Would run $cfg{make} $make_arg");
  }
}

sub relocations_root { shift->{ports_dir} . "-relocations" }

sub dst         { shift->{dst}        }
sub relocation  { shift->{relocate}   }
sub _status_dir { shift->{status_dir} }
sub port        { shift->{port}       }
sub _ports_dir  { shift->{ports_dir}  }
sub _port_dir   { shift->{port_dir}   }

sub description { shift->dst          }

sub params {
  my $self = shift;
  return map $self->$_, qw(port dst _port_dir relocation);
}

# where port installs to, e.g. ~/.ports/libtre/install
sub clone_to { # FIXME wrong method name
  my $self = shift;
  return $self->{install_dir};
}

sub batch      { 0 }
sub deprecated { 0 }

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
