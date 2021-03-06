package Cfg::Pkg::Mercurial;

=head1 NAME

Cfg::Pkg::Mercurial - subclass for cfgctl configuration packages managed by hg

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Carp qw(carp cluck croak confess);
use File::Path;

use Cfg::CLI qw(debug for_real);
use Sh qw(sys_or_die);

use base qw(Cfg::Pkg::DVCS);

sub update {
  my $self = shift;

  $self->pull_from_upstream('-u');
}

sub pull_from_upstream {
  my $self = shift;
  my @pull_options = @_;

  my $co_to = $self->clone_to;
  chdir($co_to) or die "chdir($co_to) failed: $!\n";

  if (for_real()) {
    my @cmd = (
      $self->DVCS_CMD,
      'pull', @pull_options,
      $self->upstream,
    );
    debug(1, "@cmd");
    sys_or_die(\@cmd);
  }
  else {
    my @cmd = (
      $self->DVCS_CMD,
      'incoming',
      $self->upstream,
    );
    debug(1, "@cmd");
    sys_or_die(\@cmd);
  }
}

sub push_upstream {
  my $self = shift;
  my @push_options = @_;

  my $co_to = $self->clone_to;
  chdir($co_to) or die "chdir($co_to) failed: $!\n";

  if (for_real()) {
    my @cmd = (
      $self->DVCS_CMD,
      'push', @push_options,
      $self->upstream,
    );
    debug(1, "@cmd");
    sys_or_die(\@cmd);
  }
  else {
    my @cmd = (
      $self->DVCS_CMD,
      'outgoing',
      $self->upstream,
    );
    debug(1, "@cmd");
    sys_or_die(\@cmd);
  }
}

sub DVCS_CMD         { 'hg'    }
sub DVCS_CLONE_CMD   { 'clone' }

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
