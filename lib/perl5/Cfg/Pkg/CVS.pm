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

  my $wd = $self->_wd;
  my $src = $self->_src;
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

sub install {
  my $self = shift;
  $self->SUPER::install(@_);
  if ($self->_src =~ m!^(personal/sec)/!) {
    my @chmod = (
      'chmod', 'go-rwx', '-R',
      File::Spec->join($self->_wd, $1),
    );
    print "@chmod\n";
    system @chmod;
    my $exit = $? >> 8;
    warn "Warning: chmod failed\n" if $exit != 0;
  }
}

# Private
sub _wd         { shift->{wd } }
sub _src        { shift->{src} }

# Public
sub description { shift->{src} }
sub dst         { shift->{dst} }

sub cfg_symlink_target {
  my $self = shift;
  File::Spec->join($self->_wd, $self->_src),
}

sub deprecated {
  my $self = shift;
  return $self->src =~ /RETIRE/;
}

sub to_str2 {
  my $self = shift;
  return $self->{src};
  return sprintf "%s: %s -> %s", @$self{qw/wd src dst/};
}

sub to_str {
  my $self = shift;
  return $self->_wd . ":" . $self->dst;
}

=head1 BUGS

=head1 SEE ALSO

L<Cfg::Pkg::Base>, L<cfgctl>

=cut

1;
