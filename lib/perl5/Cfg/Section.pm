package Cfg::Section;

# Here's a perfect example of why Ruby is so much nicer than Perl.
#
#   class Cfg::Section
#     attr_reader :ident, :name
#     attr_writer :pkgs
#
#     def initialize(ident, name, pkgs)
#       @ident = ident
#       @name  = name
#       @pkgs  = []
#     end
#
#     def to_str
#       @name
#     end
#   end
#
# 12 lines versus 29 ...

=head1 NAME

Cfg::Section - section containing cfgctl configuration packages

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Carp qw(carp cluck croak confess);

=head1 CONSTRUCTORS

=cut

my (%all_sections, %all_pkgs);

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($ident, $name) = @_;

  if ($all_sections{$ident}) {
    die "Section '$ident' already registered once\n";
  }

  $all_sections{$ident}++;
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
  my $name = $pkg->dst;
  if ($all_pkgs{$name}) {
    die "Package '$name' already registered once\n";
  }
  $all_pkgs{$name}++;
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
