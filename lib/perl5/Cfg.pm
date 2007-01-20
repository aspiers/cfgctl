package Cfg;

=head1 NAME

Cfg -

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Tie::RefHash;

use Cfg::Utils qw(debug %opts %cfg);
use Cfg::Section;
use Cfg::Pkg::CVS;
use Cfg::Pkg::Baz;

use Sh qw(abs_path move_with_subpath safe_cat);

=head1 ROUTINES

=cut

my (@sections, %sections, $current_section, %aliases);
tie %sections, 'Tie::RefHash';

sub register (@) {
  foreach my $object (@_) {
    if ($object->isa('Cfg::Section')) {
      $current_section = $object;
      if (! $sections{$object}) {
        push @sections, $object;
      }
    }
    else {
      die "Tried to add a ", ref($object), " before any section!\n"
        unless $current_section;
      push @{ $sections{$current_section} }, $object;
    }
  }
}

sub alias ($@) {
  my ($alias, @expansions) = @_;
  $aliases{$alias} = [ @expansions ];
}

sub do_registration {
  eval {
    # Let the config file register any packages we want.
    require $cfg{MAP_FILE};
  };
  die "Compilation of $cfg{MAP_FILE} failed:\n$@\n" if $@;
}

sub list_pkgs {
  foreach my $section (@sections) {
    print $section->to_string, "\n";
    foreach my $entry (@{ $sections{$section} }) {
      if ($opts{sources})  {
        print $entry->src, "\n";
      }
      elsif ($opts{destinations}) {
        print $entry->dst, "\n";
      }
      else {
        die "BUG";
      }
    }
  }
}

sub expand_aliases {
  my @result = ();
  foreach my $elt (@_) {
    if (my $expansion = $aliases{$elt}) {
      push @result, @$expansion;
    }
    else {
      push @result, $elt;
    }
  }
  return @result;
}

sub process_pkgs {
  my %filter = map { $_ => 1 } expand_aliases(@ARGV);
  my %done;
  my $do_filter = @ARGV;

  foreach my $section (@sections) {
    print $section->to_string, "\n";
    foreach my $pkg (@{ $sections{$section} }) {
      my $dst = $pkg->dst;
      if ($do_filter and ! $filter{$dst}) {
        debug("#. skipping $dst - not on command-line pkg list\n");
        next;
      }

      process $pkg;
      $done{$dst}++;
    }
  }
  
  if ($do_filter) {
    warn "$_ not found in $cfg{MAP_FILE}; didn't process\n"
      foreach grep ! $done{$_}, keys %filter;
  }
}

=head1 BUGS

=head1 SEE ALSO

=cut

1;
