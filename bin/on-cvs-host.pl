my $cvs_host  = `cat .my-cvs-host`;
die "no .my-cvs-host\n" unless $cvs_host;

(my $me = $0) =~ s!$ENV{HOME}/!!;
exec "ssh $cvs_host $me" if hostfqdn() !~ $cvs_host;

1;

