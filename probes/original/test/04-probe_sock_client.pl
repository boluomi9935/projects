#!/usr/bin/perl -w
use strict;
use IO::Socket;
my ($kidpid, $handle, $line);
# http://www.rocketaware.com/perl/perlipc/TCP_Servers_with_IO_Socket.htm

my $cmd = $ARGV[0];

die "USAGE: $0 [list|count|listcount|open|shutdown|statistics]" 
unless (($cmd) &&
	(
	($cmd =~ /^list$/i)			|| 
	($cmd =~ /^count$/i)		|| 
	($cmd =~ /^listcount$/i)	|| 
	($cmd =~ /^verbose$/i)		|| 
	($cmd =~ /^open$/i)			|| 
	($cmd =~ /^shutdown$/i)		|| 
	($cmd =~ /^statistics$/i)
	)
);
# $host = 'locadlhost';
# $port = 9000;

# create a tcp connection to the specified host and port
# $handle = IO::Socket::INET->new(Proto     => "tcp",
# 								PeerAddr  => $host,
# 								PeerPort  => $port,
# 								Reuse     => 1)
# 		or die "can't connect to port $port on $host: $!";

$handle = IO::Socket::UNIX->new(Peer      => '/tmp/server.sock',
								Type      => SOCK_STREAM,
								TimeOut   => 1)
		or die "can't connect to port : $!";


$handle->autoflush(1);              # so output gets there right away
# print STDERR "[Connected to $host:$port]\n";
$| = 1;


if ($cmd =~ /open/i)
{
	# split the program into two processes, identical twins
	die "can't fork: $!" unless defined($kidpid = fork());

	# the if{} block runs only in the parent process

	if ($kidpid) {
		# copy the socket to standard output
		while (defined ($line = <$handle>)) 
		{
			print STDOUT $line;
		}
		kill("TERM", $kidpid);                  # send SIGTERM to child
	}
	# the else{} block runs only in the child process
	else
	{
		# copy standard input to the socket
		while (defined ($line = <STDIN>))
		{
			print $handle $line;
	# 		$line =<$handle>;
	# 		print $line;
		}
	}
}
else
{
	print "SENDING " . uc($cmd) . ":\n";
	print $handle "$cmd\n";
	while (<$handle>)
	{
		print;
	}
}

1;