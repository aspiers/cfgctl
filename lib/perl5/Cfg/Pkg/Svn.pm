package Cfg::Pkg::Svn;

=head1 NAME

Cfg::Pkg::Svn - subclass for cfgctl configuration packages managed by Subversion

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Carp qw(carp cluck croak confess);
use File::Path;

use Cfg::CLI qw(debug for_real);
use Sh qw(sys_or_die);

use base qw(Cfg::Pkg::Base);

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($root, $wd, $src, $dst) = @_;
  debug(4, "#   ${class}->new(" . join(", ", @_) . ")");

  die "${class}->new() called without \$dst" unless $dst;

  my $pkg = bless {
    root => $root, # e.g. 'http://yasnippet.googlecode.com/svn/trunk/'
    wd   => $wd,   # e.g. "$ENV{HOME}/.svn"
    src  => $src,  # e.g. config/dev-tools/emacs/yasnippet
    dst  => $dst,  # e.g. yasnippet-svn
  }, $class;

  my $cmd = $class->CMD;
  unless (which($cmd)) {
    my $reason = "$cmd not found";
    $pkg->disable($reason);
  }

  return $pkg;
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
    $self->CMD, $self->FETCH_CMD,
    $self->upstream, $self->_co_to,
  );
  debug(1, "@cmd");
  sys_or_die(\@cmd) if for_real();
}

sub update {
  my $self = shift;

  my $co_to = $self->_co_to;
  chdir($co_to) or die "chdir($co_to) failed: $!\n";

  if (for_real()) {
    my @cmd = ( $self->CMD, 'update', $self->upstream );
    debug(1, "@cmd");
    sys_or_die(\@cmd);
  }
  else {
    my @cmd = ( $self->CMD, 'log', '-r', 'BASE:HEAD', '-v' );
    debug(1, "@cmd");
    system @cmd; # svn missing exits non-zero for some reason.
  }
}


sub CMD         { 'svn'     }
sub FETCH_CMD   { 'clone'   }

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
