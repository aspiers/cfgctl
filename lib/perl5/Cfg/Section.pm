package Cfg::Section;
# Here's a perfect example of why Ruby is so much nicer than Perl.

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
  my ($ident, $name) = @_;
  return bless {
    ident => $ident,
    name  => $name,
    pkgs  => [],
  }, $class;
}

=head1 METHODS

=cut

sub add_pkg {
  my $self = shift;
  my ($pkg) = @_;
  push @{ $self->{pkgs} }, $pkg;
}

sub pkgs {
  my $self = shift;
  return @{ $self->{pkgs} };
}

sub name  { shift->{name}  }
sub ident { shift->{ident} }

sub to_string {
  my $self = shift;
  return $self->name;
}

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
