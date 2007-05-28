package Cfg::Pkg::Tla;

=head1 NAME

Cfg::Pkg::Tla - subclass for cfgctl configuration packages managed by tla/tla

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use File::Path;

use base 'Cfg::Pkg::Arch';

sub ARCH_CMD { 'tla' };

=head1 SEE ALSO

L<Cfg::Pkg::Arch>, L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
