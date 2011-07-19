#!/usr/bin/perl -w
# biclient - bidirectional forking client
    use strict;
use IO::Socket;
my ($host, $port, $kidpid, $handle, $line);

$host = 'localhost';
$port = 7890;

# create a tcp connection to the specified host and port
$handle = IO::Socket::INET->new(Proto     => "tcp",
                                PeerAddr  => $host,
                                PeerPort  => $port)
       or die "can't connect to port $port on $host: $!";

$handle->autoflush(1);              # so output gets there right away
print STDERR "[Connected to $host:$port]\n";

# split the program into two processes, identical twins
die "can't fork: $!" unless defined($kidpid = fork());

if ($kidpid) {                      
    # parent copies the socket to standard output
    while (defined ($line = <$handle>)) {
        print STDOUT $line;
    }
    kill("TERM" => $kidpid);        # send SIGTERM to child
	}
	else 
	{
    # child copies standard input to the socket
    while (defined ($line = <STDIN>)) {
        print $handle $line;
    }
}
exit;