package Cfg::Pkg::Base;

=head1 NAME

Cfg::Pkg::Base - base class for cfgctl configuration packages

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

=head1 CONSTRUCTORS

=cut

my @pkgs;

sub _register_pkg {
  my $class = shift;
  my ($pkg) = @_;
  push @pkgs, $pkg;
}

sub pkgs {
  return @pkgs;
}

=head1 METHODS

=cut

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::CVS>, L<cfgctl>

=cut

1;
