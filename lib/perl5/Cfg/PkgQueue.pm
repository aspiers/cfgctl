package Cfg::PkgQueue;
# Here's another perfect example of why Ruby is so much nicer than Perl.

=head1 NAME

Cfg::PkgQueue - 

=head1 SYNOPSIS

synopsis

=head1 DESCRIPTION

description

=cut

use strict;
use warnings;

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  return bless {
    entries => [],
  }, $class;
}

sub add_section_pkgs {
  my $self = shift;
  my ($section, @pkgs) = @_;
  push @{ $self->{entries} }, [ $section, [ @pkgs ] ];
}

sub pkgs {
  my $self = shift;
  return map @{ $_->[1] }, @{ $self->{entries} };
}

sub sections_and_pkgs {
  my $self = shift;
  return @{ $self->{entries} };
}

sub empty { scalar(shift->sections_and_pkgs) == 0 }

=head1 BUGS

=head1 SEE ALSO

=cut

1;
