package Sh;

=head1 NAME

Sh - Utility routines for common shell operations

=cut

use strict;
use warnings;

use Carp qw(carp cluck croak confess);
use Cwd;
use Digest::MD5;
use File::Basename;
use File::Path;
use File::Spec;

use base qw(Exporter);
our @EXPORT_OK = qw(
  get_absolute_path abs_path abs_path_by_chdir abs_path_by_chasing
  cat safe_cat read_lines_from_file write_to_file append_to_file remove_from_file
  grep_quiet line_count
  md5hex_file md5b64_file
  move_with_subpath move_with_common_subpath
  glob_to_re
  safe_sys sys_or_warn sys_or_die
  ensure_correct_symlink
);

sub get_absolute_path {
  my ($file) = @_;

  # Strategy:
  # Use dirname/basename to split up $file into $dir and $file.
  # chdir to $dir.  If $file is a dir, chdir to that too.
  # Use getcwd() to determine where we are, and return result accordingly.

  my $dir = dirname($file);
  my $olddir = getcwd();
  chdir $dir or die "chdir($dir) failed: $!\n";
  $dir = getcwd();
  $file = basename($file);
  if (-d $file) {
    chdir $file or die "chdir($file) failed: $!\n";
    $dir = getcwd();
    return ($dir);
  }
  chdir $olddir or die "chdir($olddir) failed: $!\n";

  return ($dir, $file);
}

sub abs_path {
  &abs_path_by_chdir;
}

sub abs_path_by_chdir {
  return File::Spec->join(get_absolute_path(@_));
}

sub abs_path_by_chasing {
  my $path = shift;
  
  # The below was written during my "don't comment unobvious stuff"
  # phase, so I can't remember what the hell it does on top of
  # Cwd::abs_path().  Attempting to find out by just using
  # Cwd::abs_path() and seeing what breaks.
  return Cwd::abs_path($path);
  
  -d $path and return Cwd::abs_path($path);

  my ($vol, $dir, $file) = File::Spec->splitpath($path);
  # Don't know how to handle volumes.
  die "$0: splitpath returned vol '$vol'\n" if $vol;

  $dir = Cwd::abs_path($dir);

  # keep chasing links until we arrive at a non-link
  while (-l $path) {
    $path = File::Spec->rel2abs(readlink $path, $dir);
    $path = File::Spec->canonpath($path);
    1 while $path =~ s!/[^/]+/\.\./!/!g; # can't believe canonpath doesn't do this
    ($dir, $file) = $path =~ m!(.+)/(.+)!;
    $dir = Cwd::abs_path($dir);
  }

  return "$dir/$file";
}

sub cat {
  my ($file) = @_;
  my $text;
  open(FILE, "$file") or die "open($file) failed: $!\n";
  $text .= $_ while <FILE>;
  close(FILE);
  return $text;
}

sub safe_cat {
  my ($file) = @_;
  return '' unless -r $file;
  return cat($file);
}

sub read_lines_from_file {
  my ($file) = @_;
  open(FILE, "$file") or die "open($file) failed: $!\n";
  my @lines;
  while (<FILE>) {
    chomp;
    push @lines, $_;
  }
  close(FILE);
  return @lines;
}

sub write_to_file {
  my ($file, $text) = @_;
  open(FILE, ">$file") or die "open(>$file) failed: $!\n";
  print FILE $text;
  close(FILE);
}

sub append_to_file {
  my ($file, $text) = @_;
  open(FILE, ">>$file") or die "open(>>$file) failed: $!\n";
  print FILE $text;
  close(FILE);
}

sub remove_from_file {
  my ($file, $match) = @_;
  my $new = '';
  open(FILE, "+<$file") or die "open(+<$file) failed: $!\n";
  if (ref($match) eq 'Regexp') {
    while (<FILE>) {
      chomp;
      $new .= "$_\n" unless /$match/;
    }
  }
  else {
    while (<FILE>) {
      chomp;
      $new .= "$_\n" unless $_ eq $match;
    }
  }
  seek FILE, 0, 0;
  truncate FILE, 0;
  print FILE $new;
  close(FILE);
}

sub grep_quiet {
  my ($file, $line) = @_;
  
  return 0 unless -f $file;
  
  open(FILE, $file) or die "open($file) failed: $!\n";
  while (<FILE>) {
    chomp;
    if ($_ eq $line) {
      close(FILE);
      return 1;
    }
  }
  close(FILE);
  return 0;
}

sub line_count {
  my ($file) = @_;
  open(FILE, $file) or die "open(+<$file) failed: $!\n";
  my $count = 0;
  $count++ while <FILE>;
  close(FILE);
  return $count;
}

sub md5b64_file {
  my ($file) = @_;
  open(FILE, $file) or die "open($file) failed: $!\n";
  my $md5 = Digest::MD5->new->addfile(*FILE)->b64digest;
  close(FILE);
  return $md5;
}

sub md5hex_file {
  my ($file) = @_;
  open(FILE, $file) or die "open($file) failed: $!\n";
  my $md5 = Digest::MD5->new->addfile(*FILE)->hexdigest;
  close(FILE);
  return $md5;
}

=head2 move_with_subpath

e.g. moves foo/bar/src/1/2/3 to foo/bar/dst/1/2/3 even if
foo/bar/dst/1/2 didn't previously exist

=cut

sub move_with_subpath {
  my ($src_root, $dst_root, $subpath) = @_;

  my $src = File::Spec->join($src_root, $subpath);
  -e $src      or die "tried to move non-existent file $src!\n";
  -e $dst_root or die "tried to move $src to subdir of non-existent dir $dst_root!\n";
  my $dst = File::Spec->join($dst_root, $subpath);

  # Figure out directory which will contain $dst and ensure it exists.
  my @dirs = File::Spec->splitdir($subpath);
  my $file = pop @dirs;
  my $dir = File::Spec->join($dst_root, @dirs);
  unless (-d $dir) {
    mkpath $dir or die "mkdir($dir) failed: $!\n";
  }

  rename($src, $dst) or die "rename($src, $dst) failed: $!\n";
}

=head2 move_with_common_subpath

Same as C<move_with_subpath> but auto-figures out C<$subpath>.

=cut

sub move_with_common_subpath {
  my ($src, $dst) = @_;

  -e $src or die "tried to move non-existent file $src!\n";
  my @src = File::Spec->splitdir($src);
  my @dst = File::Spec->splitdir($dst);
  my ($suffix, $src_root, $dst_root) = _find_common_tail_elements(\@src, \@dst);
  
  # Figure out directory which will contain $dst and ensure it exists.
  my $file = pop @$suffix;
  my $dir = File::Spec->join(@$dst_root, @$suffix);
  unless (-d $dir) {
    mkpath $dir or die "mkdir($dir) failed: $!\n";
  }

  rename($src, $dst) or die "rename($src, $dst) failed: $!\n";
}

sub _find_common_tail_elements {
  my ($a, $b) = @_;
  my @a = @$a;
  my @b = @$b;
  my @common;
  while (@a and @b) {
    last if $a[-1] ne $b[-1];
    unshift @common, pop @a;
    pop @b;
  }
  return (\@common, \@a, \@b);
}

sub glob_to_re {
  local $_ = shift;
  s/([.+{}^\$])/\\$1/g;
  s/\*/.*/g;
  s/\?/./g;
  s/^/^/;
  s/$/\$/;
  return $_;
}

sub safe_sys {
  my %p = @_;
  my @cmd = ref($p{cmd}) eq 'ARRAY' ? @{ $p{cmd} } : ($p{cmd});
  confess "_safe_sys called without 'fail' coderef"
    unless ref($p{fail}) eq 'CODE';
  $p{msg} ||= "command @cmd failed; aborting.\n";
  system @cmd;
  my $exit = $? >> 8;
  $exit == 0 or $p{fail}->($p{msg});
}

sub sys_or_warn {
  my ($cmd, $msg) = @_;
  safe_sys(
    cmd  => $cmd,
    msg  => $msg,
    fail => sub { warn $_[0] },
  );
}

sub sys_or_die {
  my ($cmd, $msg) = @_;
  safe_sys(
    cmd  => $cmd,
    msg  => $msg,
    fail => sub { die $_[0] },
  );
}

sub ensure_correct_symlink {
  my %p = @_;
  confess "ensure_correct_symlink was not passed a symlink" unless $p{symlink};
  confess "ensure_correct_symlink was not passed a required_target" unless $p{required_target};
  
  if (! lstat $p{symlink}) {
    symlink $p{required_target}, $p{symlink}
      or die "symlink($p{required_target}, $p{symlink}) failed: $!\n";
    return;
  }

  if (! -l $p{symlink}) {
    die "$p{symlink} already exists but is not a symlink; aborting!\n";
  }

  my ($a_dev, $a_ino) = stat($p{symlink}) # stat automatically follows symlinks
    or die "stat($p{symlink}) failed ($!); invalid symlink?\n";
  
  my ($r_dev, $r_ino) = stat($p{required_target})
    or confess "stat($p{required_target}) failed: $!";
  if ($a_dev != $r_dev or $a_ino != $r_ino) {
    die "$p{symlink} already exists and points to the wrong place; aborting!\n";
  }
}

=head1 BUGS

C<grep_quiet> doesn't take regexps.

=cut

1;
