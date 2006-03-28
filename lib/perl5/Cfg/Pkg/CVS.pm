package Cfg::Pkg::CVS;

=head1 NAME

Cfg::Pkg::CVS - base class for cfgctl configuration packages

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Cfg::Utils qw(debug);
use base 'Cfg::Pkg::Base';

use overload '""' => \&to_str;

=head1 CONSTRUCTORS

=cut

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($wd, $src, $dst) = @_;
  return bless {
    wd => $wd,
    src => $src,
    dst => $dst,
  }, $class;
}

sub multi {
  my $self = shift;
  my $class = ref($self) || $self;
  my ($wd, $block) = @_;
  my @new;
  die unless $block;
  for my $line (split /\n/, $block) {
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    next unless $line;
    next if $line =~ /^#/;
    my ($src, $dst) = split /\s+/, $line;
    push @new, $class->new($wd, $src, $dst);
  }
  return @new;
}

=head1 METHODS

=cut

sub maybe_check_out {
  my $self = shift;

  my $wd = $self->wd;
  my $src = $self->src;
  if (-d File::Spec->join($wd, $src)) {
    debug("# $src already checked out in $wd\n");
    return;
  }

  chdir($wd) or die "chdir($wd) failed: $!\n";
  print "Checking out $src ...\n";
  system 'cvs', 'checkout', $src;
  my $exit = $? >> 8;
  die "cvs checkout $src failed; aborting!\n" if $exit != 0;
}

sub to_string {
  my $self = shift;
  return $self->{src};
  return sprintf "%s: %s -> %s", @$self{qw/wd src dst/};
}

sub wd  { shift->{wd } }
sub src { shift->{src} }
sub dst { shift->{dst} }

sub to_str {
  my $self = shift;
  return $self->wd . ":" . $self->dst;
}

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
