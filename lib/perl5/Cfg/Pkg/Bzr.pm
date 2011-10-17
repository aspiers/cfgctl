package Cfg::Pkg::Bzr;

=head1 NAME

Cfg::Pkg::Bzr - subclass for cfgctl configuration packages managed by bzr

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

  my $co_to = $self->_co_to;
  chdir($co_to) or die "chdir($co_to) failed: $!\n";

  if (for_real()) {
    my @cmd = (
      $self->DVCS_CMD,
      'merge',
      $self->upstream,
    );
    debug(1, "@cmd");
    sys_or_die(\@cmd);
  }
  else {
    my @cmd = (
      $self->DVCS_CMD,
      'missing', '--short',
      $self->upstream,
    );
    debug(1, "@cmd");
    system @cmd; # bzr missing exits non-zero for some reason.
  }
}

# In bzr, bzr pull only works as a 2-way merge, i.e. if only one of
# the two sides has unique changes.  For 3-way, bzr merge is required.
# See <http://doc.bazaar-vcs.org/bzr.dev/tutorial.htm> for more.
sub pull {
  my $self = shift;
}


sub DVCS_CMD         { 'bzr'     }
sub DVCS_FETCH_CMD   { 'get'     }

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
