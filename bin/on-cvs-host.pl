my $cvs_host  = `cat .my-cvs-host`;
die "no .my-cvs-host\n" unless $cvs_host;

(my $me = $0) =~ s!$ENV{HOME}/!!;
if (hostfqdn() !~ $cvs_host) {
  my $cmd = "ssh $cvs_host $me";
  $cmd .= ' ' . join(' ', map { qq{"$_"} } @ARGV) if @ARGV;
#  warn "$cmd\n";
  exec $cmd;
}

1;

