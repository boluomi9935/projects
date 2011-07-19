#!/usr/bin/perl -w
# cliIO.pl
# a simple client using IO:Socket
#----------------

use strict;
use IO::Socket;
$| = 1;

my $host = shift || 'localhost';
my $port = shift || 7890;
my $sock = new IO::Socket::INET( PeerAddr => $host, PeerPort => $port, Proto => 'tcp');
$sock or die "no socket :$!";

print $sock "123456\n";

# 	while (defined (my $buf = <$sock>))
# 	{
# 		print $buf;
# 	}

close $sock;
