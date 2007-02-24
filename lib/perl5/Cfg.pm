package Cfg;

=head1 NAME

Cfg -

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Tie::RefHash;

use Cfg::PkgQueue;
use Cfg::Utils qw(debug %opts %cfg);
use Cfg::Section;
use Cfg::Pkg::CVS;
use Cfg::Pkg::Baz;

use Sh qw(abs_path move_with_subpath safe_cat);

=head1 ROUTINES

=cut

my (@sections, $current_section, %aliases);

sub register (@) {
  foreach my $object (@_) {
    if ($object->isa('Cfg::Section')) {
      my $section = $current_section = $object;
      push @sections, $section;
    }
    else {
      die "Tried to add a ", ref($object), " before any section!\n"
        unless $current_section;
      $current_section->add_pkg($object);
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

  foreach my $section (@sections) {
    alias($section->ident => map $_->dst, $section->pkgs);
  }
}

sub list_pkgs {
  foreach my $section (@sections) {
    print "#@ ", $section->to_string, "\n";
    foreach my $pkg ($section->pkgs) {
      if ($opts{sources})  {
        print $pkg->src, "\n";
      }
      elsif ($opts{destinations}) {
        print $pkg->dst, "\n";
      }
      else {
        die "BUG";
      }
    }
  }
}

sub expand_aliases {
  debug(2, "# Expanding aliases");
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

sub get_pkg_queue {
  debug(2, "# Getting package queue");

  my %filter = map { $_ => 1 } expand_aliases(@ARGV);
  my $do_filter = @ARGV;
  my %pkg_found;
  my $queue = Cfg::PkgQueue->new;

  foreach my $section (@sections) {
    my @section_queue;
    foreach my $pkg ($section->pkgs) {
      my $dst = $pkg->dst;
      die unless $dst;
      if ($do_filter and ! $filter{$dst}) {
        debug(3, "#. skipping $dst - not on command-line pkg list\n");
        next;
      }

      push @section_queue, $pkg;
      $pkg_found{$dst}++;
    }
    $queue->add_section_pkgs($section, @section_queue) if @section_queue;
  }

  # If ARGV specified a particular list of packages to process, check
  # that each one was valid - the user should be informed if they made
  # a typo, for instance.
  if ($do_filter) {
    foreach my $non_pkg (grep ! $pkg_found{$_}, keys %filter) {
      warn "$non_pkg not found in $cfg{MAP_FILE}; didn't process\n";
    }
  }

  return $queue;
}

# Enable SCM classes to batch updates/checkouts together if desired,
# for efficiency over high-latency links.

sub update {
  my $class = shift;
  my @pkgs = @_;
  $class->_batch_get(
    sub {
      my $pkg = shift;
      $pkg->src_local ? 'update' : 'fetch';
    },
    @pkgs
  );
}

sub ensure_src_local {
  my $class = shift;
  my @pkgs = @_;
  $class->_batch_get(
    sub {
      my $pkg = shift;
      if ($pkg->src_local) {
        my $src = $pkg->_src;
        my $wd = $pkg->_wd;
        debug(2, "# $src already checked out in $wd\n");
        return undef;
      }
      return 'fetch';
    },
    @pkgs
  );
}

sub _batch_get {
  my $class = shift;
  my $mode_block = shift;
  my @pkgs = @_;

  my %class_queues;
  foreach my $pkg (@pkgs) {
    my $mode = $mode_block->($pkg);
    next unless $mode;
    $class_queues{$mode}{ref($pkg)}++;
    my $method = "enqueue_$mode";
    $pkg->$method;
  }

  while (my ($mode, $class_queue) = each %class_queues) {
    my $method = "process_${mode}_queue";
    foreach my $class (keys %$class_queue) {
      $class->$method;
    }
  }
}

sub sections { @sections }

=head1 BUGS

=head1 SEE ALSO

=cut

1;
