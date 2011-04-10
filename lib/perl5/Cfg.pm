package Cfg;

=head1 NAME

Cfg - Manages Cfg::Pkg instances

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use strict;
use warnings;

use Tie::RefHash;

use Cfg::PkgQueue;
use Cfg::CLI qw(debug %opts);
use Cfg::Cfg qw(%cfg);
use Cfg::Section;
use Cfg::Pkg::CVS;
use Cfg::Pkg::Git;
use Cfg::Pkg::Svn;
use Cfg::Pkg::Mercurial;
use Cfg::Pkg::Port;
use Cfg::Pkg::Bzr;
use Cfg::Pkg::Baz;
use Sh qw(safe_cat); # required by config.map

=head1 ROUTINES

=cut

my (@sections, $current_section, %aliases);

sub register (@) {
  foreach my $object (@_) {
    next unless $object; # object constructor can fail and return undef
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
    debug(1, "#>>> ", $section->to_string); 
    foreach my $pkg ($section->pkgs) {
      next if $pkg->disabled;
      if ($opts{list}) {
        print join("\t", ref($pkg), map { $_ || '-' } $pkg->params), "\n";
      }
      elsif ($opts{sources})  {
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
      debug(3, "    $elt -> @$expansion");
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

  my $do_filter = @ARGV;
  my @pkgs = expand_aliases(grep ! m!^/.+/$!, @ARGV);
  my @regexps =             grep   m!^/.+/$!, @ARGV;
  debug(4, "#   Packages to include: @pkgs");
  debug(4, "#   Package regexps to use: @regexps");
  my %filter = map { $_ => 1 } @pkgs;
  my %pkg_found;
  my $queue = Cfg::PkgQueue->new;

  foreach my $section (@sections) {
    debug (3, "#   Processing section: ", $section->name);
    my @section_queue;
    foreach my $pkg ($section->pkgs) {
      my $dst = $pkg->dst;
      die unless $dst;
      if ($do_filter) {
        if (_include_pkg($dst, \%filter, \@regexps)) {
          debug(3, "#     Including $dst");
        }
        else {
          debug(4, "#     Skipping $dst - not on command-line pkg list");
          next;
        }
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

sub _include_pkg {
  my ($pkg, $filter, $regexps) = @_;
  if ($filter->{$pkg}) {
    debug(4, "#       $pkg listed on CLI");
    return 1;
  }
  foreach my $re (@$regexps) {
    die "re [$re]" unless $re =~ m!^/(.+)/$!;
    my $parsed_re = $1;
    if ($pkg =~ $parsed_re) {
      debug(4, "#       $pkg listed on CLI as regexp");
      return 1;
    }
  }
  return 0;
}


=head2 batch_update(@pkgs)

Updates each package, or fetches it if not previously local.

It's a class method in order to enable SCM classes to batch
updates/checkouts together if desired, for efficiency over
high-latency links.  First it groups the packages into per-class
queues, per-operation (i.e. update or fetch) queues, then each queue
is processed.

=cut

sub batch_update {
  my $class = shift;
  my @pkgs = @_;

  debug(2, "# Batch update");
  $class->_batch_get(
    sub {
      my $pkg = shift;
      $pkg->src_local ? 'update' : 'fetch';
    },
    @pkgs
  );
}

=head2 batch_fetch(@pkgs)

Fetches each package if not previously local.

It's a class method in order to enable SCM classes to batch
updates/checkouts together if desired, for efficiency over
high-latency links.  First it groups the packages into per-class
queues, per-operation (i.e. update or fetch) queues, then each queue
is processed.

=cut

sub batch_fetch {
  my $class = shift;
  my @pkgs = @_;
  debug(2, "# Batch fetch");
  $class->_batch_get(
    sub {
      my $pkg = shift;
      if ($pkg->src_local) {
        debug(2, "#   ", $pkg->description, " already present in ",
              $pkg->src);
        return undef; # nop
      }
      return 'fetch';
    },
    @pkgs
  );
}

=head2 batch_push(@pkgs)

Placeholder for any SCM which could push local changes upstream in
batch (i.e. many changes across multiple packages).  This currently
only makes sense for CVS and is not implemented yet.

=cut

sub batch_push {
  my $class = shift;
  my @pkgs = @_;
  debug(2, "# Batch push");
  $class->_batch_get(
    sub {
      my $pkg = shift;
      if ($pkg->src_local) {
        return 'push';
      }
      debug(2, "#   ", $pkg->description, " not present locally in ",
               $pkg->src, "; cannot push upstream");
      return undef; # nop
    },
    @pkgs
  );
}

# mode_calculator is a closure which returns 'fetch' if the package
# needs to be fetched, 'update' if it needs to be updated, and undef
# if nothing needs to be done.
sub _batch_get {
  my $class = shift;
  my $mode_calculator = shift;
  my @pkgs = @_;

  my %class_queues = $class->_batch_enqueue($mode_calculator, @pkgs);

  while (my ($mode, $class_queue) = each %class_queues) {
    my $method = "process_${mode}_queue";
    foreach my $class (keys %$class_queue) {
      debug(2, "#   Processing batch $mode queue for $class");
      $class->$method;
    }
  }
}

sub _batch_enqueue {
  my $class = shift;
  my $mode_calculator = shift;
  my %class_queues;
  foreach my $pkg (@_) {
    my $mode = $mode_calculator->($pkg);
    next unless $mode;
    my $pkg_class = ref $pkg;
    unless ($pkg_class->batch) {
      debug(3, "#   Skipping batch $mode for $pkg_class");
      next;
    }
    if ($pkg->disabled) {
      debug(3, "#   Not enqueueing disabled package $pkg for $pkg_class");
      next;
    }
    next if $mode eq 'fetch' and $pkg->deprecated;
    $class_queues{$mode}{$pkg_class}++;
    my $method = "enqueue_$mode";
    debug(2, "#   Enqueueing ", $pkg->description, " for $mode");
    $pkg->$method;
  }
  return %class_queues;
}

sub sections { @sections }

=head1 BUGS

=head1 SEE ALSO

=cut

1;
