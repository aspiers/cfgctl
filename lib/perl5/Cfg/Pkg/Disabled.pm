package Cfg::Pkg::Disabled;

=head1 NAME

Cfg::Pkg::Disabled - disabled cfgctl configuration packages

=head1 SYNOPSIS

=head1 DESCRIPTION

Another package class may choose to register a package in this class,
e.g. if it is unable to retrieve the source.

=cut

use strict;
use warnings;

use Cfg::Utils qw(debug
                  ensure_correct_symlink preempt_conflict for_real
                  %cfg %opts);

use base 'Cfg::Pkg::Base';

=head1 CONSTRUCTORS

=cut

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($dst, $orig_class, $description, $reason) = @_;

  my $new = bless {
    dst         => $dst,
    orig_class  => $orig_class,
    description => $description,
    reason      => $reason,
  }, $class;

  return $new;
}

sub disabled { 1 }
sub dst { shift->{dst} }
sub reason { shift->{reason} }
sub src_local { 0 }
sub ensure_install_symlink { }

=head1 METHODS

=cut

sub enqueue_op {
  my $self = shift;
  my ($op) = @_;
  debug(1, sprintf "# ! Will not $op disabled %s (%s)",
                   $self->description, $self->reason);
}

sub process_queue { }

sub deinstall {
  my $self = shift;
  debug(0, "# ! Cannot deinstall disabled package ", $self->description);
}

sub install {
  my $self = shift;
  debug(0, "# ! Cannot install disabled package ", $self->description);
}

sub description { shift->{description} }

sub deprecated { 0 }

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::CVS>, L<cfgctl>

=cut

1;
