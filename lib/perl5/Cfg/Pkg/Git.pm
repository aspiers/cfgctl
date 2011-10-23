package Cfg::Pkg::Git;

=head1 NAME

Cfg::Pkg::Git - subclass for cfgctl configuration packages managed by git

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

sub relocations_root { "$ENV{HOME}/.GIT-relocations" }

sub update {
  my $self = shift;

  $self->pull_if_upstream_exists();
}

sub pull_from_upstream {
  my $self = shift;
  my @pull_options = @_;

  my $clone_to = $self->clone_to;
  chdir($clone_to) or die "chdir($clone_to) failed: $!\n";

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
    die __PACKAGE__ . " backend doesn't support previews of incoming upstream changes
because git requires you to fetch them first.\n";
  }
}

sub push_upstream {
  my $self = shift;
  my @push_options = @_;

  my $clone_to = $self->clone_to;
  chdir($clone_to) or die "chdir($clone_to) failed: $!\n";

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

sub DVCS_CMD         { 'git'    }
sub DVCS_CLONE_CMD   { 'clone' }

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
