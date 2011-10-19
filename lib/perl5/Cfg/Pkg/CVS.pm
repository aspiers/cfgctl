package Cfg::Pkg::CVS;

=head1 NAME

Cfg::Pkg::CVS - subclass for cfgctl configuration packages managed by CVS

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use File::Which;

use Cfg::CLI qw(debug %opts for_real);
use base 'Cfg::Pkg::Base';

use overload '""' => \&to_str;

my %queues;

=head1 CONSTRUCTORS

=cut

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($root, $wd, $src, $dst) = @_;
  debug(4, "#   ${class}->new(" . join(", ", @_) . ")");

  die "${class}->new() called without \$dst" unless $dst;

  my $pkg = bless {
    root => $root, # e.g. 'adam@f5.mandolinarchive.com:/home/adam/.CVSROOT'
    wd   => $wd,   # e.g. "$ENV{HOME}/.cvs"
    src  => $src,  # e.g. config/dev-tools/perl/mine
    dst  => $dst,  # e.g. perl+mine
  }, $class;

  my $cmd = $class->CMD;
  unless (which($cmd)) {
    my $reason = "$cmd not found";
    $pkg->disable($reason);
  }

  return $pkg;
}

sub CMD { 'cvs' }

=head1 METHODS

=cut

sub enqueue_op {
  my $self = shift;
  my ($op) = @_;
  die "batch operation '$op' not supported"
    unless $op eq 'update' or $op eq 'clone';
  $op = 'checkout' if $op eq 'clone';
  push @{ $queues{$op}{$self->cvsroot} }, $self;
}

sub process_queue {
  my $self = shift;
  my ($op) = @_;
  die "batch operation '$op' not supported"
    unless $op eq 'update' or $op eq 'clone';
  $op = 'checkout' if $op eq 'clone';

  debug(1, "#   Processing CVS ${op}s...");

  foreach my $cvsroot (keys %{ $queues{$op} }) {
    my $pkgs = $queues{$op}{$cvsroot};

    my $wd = $pkgs->[0]->_wd;
    chdir($wd) or die "chdir($wd) failed: $!\n";

    my @modules = map $_->_src, @$pkgs;

    my $cmd = $self->CMD;
    if (! for_real() && $op eq 'checkout') {
      debug(1, "$cmd -d $cvsroot $op @modules\n");
    }

    my @cmd = (
      $cmd,
      '-d', $cvsroot,
      $op eq 'update'      ? '-q' : (),
      for_real()           ?   () : '-n',
      $opts{'verbose'} > 3 ? '-t' : (),
      $op
    );
    debug(1, "@cmd @modules");
    open(XARGS, "|-", 'xargs', @cmd)
      or die "Couldn't open(| xargs @cmd): $!\n";
    print XARGS "$_\n" foreach @modules;
    close(XARGS) or die "close(| xargs @cmd) failed: $!\n";
    my $exit = $? >> 8;
    die "$cmd $op failed; aborting!\n" if $exit != 0;
  }
}

# This is a nop, since we batch checkout instead.
sub clone_if_upstream_exists { }

sub install {
  my $self = shift;
  $self->SUPER::install(@_);
  if ($self->_src =~ m!^(personal/sec)/!) {
    my @chmod = (
      'chmod', 'go-rwx', '-R',
      File::Spec->join($self->_wd, $1),
    );
    debug(1, "@chmod");
    system @chmod;
    my $exit = $? >> 8;
    warn "Warning: chmod failed\n" if $exit != 0;
  }
}

# Private
sub _wd         { shift->{wd } } # e.g. "$ENV{HOME}/.cvs"
sub _src        { shift->{src} } # e.g. config/dev-tools/perl/mine

# Public
sub cvsroot     { shift->{root} }
sub description { shift->{src}  } # human-readable
sub dst         { shift->{dst}  } # e.g. perl+mine

sub params {
  my $self = shift;
  return map $self->$_, qw(dst _src cvsroot _wd src);
}

sub src {
  my $self = shift;
  return File::Spec->join($self->_wd, $self->_src);
}

sub deprecated {
  my $self = shift;
  return $self->_src =~ /RETIRE/;
}

sub batch { 1 }

sub to_str2 {
  my $self = shift;
  return $self->{src};
  return sprintf "%s: %s -> %s", @$self{qw/wd src dst/};
}

sub to_str {
  my $self = shift;
  return $self->_wd . ":" . $self->dst;
}

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
