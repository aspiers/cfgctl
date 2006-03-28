package Cfg::Section;

=head1 NAME

Cfg::Section - section containing cfgctl configuration packages

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

=head1 CONSTRUCTORS

=cut

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($name) = @_;
  return bless {
    name => $name,
  }, $class;
}

=head1 METHODS

=cut

sub to_string {
  my $self = shift;
  return '#@ ' . $self->{name};
}


=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
