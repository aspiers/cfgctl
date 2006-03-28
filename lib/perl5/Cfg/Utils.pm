package Cfg::Utils;

=head1 NAME

Cfg::Utils -

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use base 'Exporter';
our @EXPORT_OK = qw(debug %opts %cfg);

our (%opts, %cfg);

sub debug {
  warn @_ if $opts{debug};
}

=head1 BUGS

=head1 SEE ALSO

=cut

1;
