my $cvs_host  = `cat .my-cvs-host`;
die "no .my-cvs-host\n" unless $cvs_host;

(my $me = $0) =~ s!$ENV{HOME}/!!;
if (hostfqdn() !~ $cvs_host) {
  warn "ssh $cvs_host $me\n";
  exec "ssh $cvs_host $me";
}

1;

