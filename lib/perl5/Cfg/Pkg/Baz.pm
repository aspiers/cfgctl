package Cfg::Pkg::Baz;

=head1 NAME

Cfg::Pkg::Baz - subclass for cfgctl configuration packages managed by tla/baz

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use File::Path;

use base 'Cfg::Pkg::Arch';

sub ARCH_CMD { 'baz' };

=head1 SEE ALSO

L<Cfg::Pkg::Arch>, L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
