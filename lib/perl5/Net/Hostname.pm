package Net::Hostname;

=head1 NAME

Net::Hostname - wrapper around crappy Net::Domain

=head1 SYNOPSIS

  use Net::Hostname qw(hostname);
  
  my $hostname = hostname();

=head1 DESCRIPTION

Net::Domain 2.19 has a stupid bug where it returns undef if the
hostname is missing from /etc/hosts.  This package works around it.

=cut

use strict;
use warnings;

use base 'Exporter';
our @EXPORT_OK = qw(hostname);

use Net::Domain;

sub hostname {
  return Net::Domain::hostname() 
  || eval {
    my $h = `hostname`;
    chomp $h;
    return $h;
  }
  || $ENV{HOSTNAME} 
  || $ENV{HOST};
}

=head1 SEE ALSO

L<Net::Domain>

=cut

1;
