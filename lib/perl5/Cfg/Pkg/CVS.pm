package Cfg::Pkg::CVS;

=head1 NAME

Cfg::Pkg::CVS - subclass for cfgctl configuration packages managed by CVS

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Cfg::Utils qw(debug %opts);
use base 'Cfg::Pkg::Base';

use overload '""' => \&to_str;

my %queues;

=head1 CONSTRUCTORS

=cut

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($root, $wd, $src, $dst) = @_;
  return bless {
    root => $root, # e.g. 'adam@f5.mandolinarchive.com:/home/adam/.CVSROOT'
    wd   => $wd,   # e.g. "$ENV{HOME}/.cvs"            
    src  => $src,  # e.g. config/dev-tools/perl/mine   
    dst  => $dst,  # e.g. perl+mine
  }, $class;
}

sub multi {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($cvsroot, $wd, $block) = @_;
  my @new;
  die unless $block;
  for my $line (split /\n/, $block) {
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    next unless $line;
    next if $line =~ /^#/;
    my ($src, $dst) = split /\s+/, $line;
    push @new, $class->new($cvsroot, $wd, $src, $dst);
  }
  return @new;
}

=head1 METHODS

=cut

sub enqueue_op {
  my $self = shift;
  my ($op) = @_;
  die unless $op eq 'update' or $op eq 'fetch';
  $op = 'checkout' if $op eq 'fetch';
  push @{ $queues{$op}{$self->cvsroot} }, $self;
}

sub process_queue {
  my $self = shift;
  my ($op) = @_;
  die unless $op eq 'update' or $op eq 'fetch';
  $op = 'checkout' if $op eq 'fetch';

  debug(1, "# Processing CVS ${op}s...");

  foreach my $cvsroot (keys %{ $queues{$op} }) {
    my $pkgs = $queues{$op}{$cvsroot};

    my $wd = $pkgs->[0]->_wd;
    chdir($wd) or die "chdir($wd) failed: $!\n";

    my @modules = map $_->_src, @$pkgs;

    if ($opts{'test'} && $op eq 'checkout') {
      debug(1, "cvs -d $cvsroot $op @modules\n");
    }

    my @cmd = (
      'cvs',
      '-d', $cvsroot,
      $op eq 'update' ? '-q' : (),
      $opts{'test'} ? '-n' : (),
      $opts{'verbose'} > 3 ? '-t' : (),
      $op
    );
    debug(1, "@cmd @modules");
    open(XARGS, "|-", 'xargs', @cmd)
      or die "Couldn't open(| xargs @cmd): $!\n";
    print XARGS "$_\n" foreach @modules;
    close(XARGS) or die "close(| xargs @cmd) failed: $!\n";
    my $exit = $? >> 8;
    die "cvs $op failed; aborting!\n" if $exit != 0;
  }
}

sub src_local {
  my $self = shift;
  return -d $self->src;
}

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

sub src {
  my $self = shift;
  return File::Spec->join($self->_wd, $self->_src);
}

sub deprecated {
  my $self = shift;
  return $self->_src =~ /RETIRE/;
}

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
