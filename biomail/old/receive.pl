#!/usr/bin/perl

use warnings;
use strict;
use Mail::POP3Client;
use Email::Filter;
use IO::Socket::SSL;
#perl -MCPAN -e shell
#install Mail::POP3Client
#install Email::Filter

# http://conky.sourceforge.net/gmail.pl
# http://www.oreillynet.com/onlamp/blog/2004/11/my_own_gmail_notifier.html

my $provider = 2;
# 1 cbsknaw@gmail.com
# 2 knawcbsknaw@yahoo.com.br

my $deleteMail  = 1;
my $popVerbose  = 0;

my %job = &receive_mail($provider); #1 gmail 2 yahoo
&print_hash(\%job);

sub receive_mail
{
	my $email = $_[0];

	my $pop = Mail::POP3Client->new();
	my $dis_numb = "-1";
	my $ssl_prot = "tcp"; # ssl protocol 
	my $ssl_port = "995"; # ssl port number (995 is what Gmail uses) 
	
	my $pop_host_G = "pop.gmail.com"; # pop3 host 
	my $pop_user_G = 'cbsknaw@gmail.com';
	my $pop_pass_G = 'uppssalla';
	
	my $pop_host_Y = "pop.mail.yahoo.com"; # pop3 host 
	my $pop_user_Y = 'knawcbsknaw@yahoo.com.br';
	my $pop_pass_Y = 'uppssalla';
	
	my $pop_host;
	my $pop_user;
	my $pop_pass;

	my %out;

	if (! $email )
	{
		die "NOR YAHOO OR GMAIL CONFIGURATED\n";
	}	
	elsif ($email eq "1")
	{
		print "GMAIL SELECTED\n";
		$pop_host = $pop_host_G;
		$pop_user = $pop_user_G;
		$pop_pass = $pop_pass_G;
	}
	elsif ($email eq "2")
	{
		print "YAHOO SELECTED\n";
		$pop_host = $pop_host_Y;
		$pop_user = $pop_user_Y;
		$pop_pass = $pop_pass_Y;
	}
	else
	{
		die "NOR YAHOO OR GMAIL CONFIGURATED\n";
	}
	

	my $socket = IO::Socket::SSL->new( PeerAddr => $pop_host,
					   PeerPort => $ssl_port,
					   Proto    => $ssl_prot);
	
	
	$pop->User($pop_user);
	$pop->Pass($pop_pass);
	$pop->Socket($socket);
# 	$pop->Debug(1);
	
	$pop->Connect() >= 0 || die $pop->Message();
	
# 	print $pop->Message();
	
	my $msg_count = $pop->Count();
	# print $msg_count, "\n";
	# my $msg_list = $pop->List(); # size of the message
	# print $msg_list;
	# my $msg_capa = $pop->Capa(); # capabilities
	# print $msg_capa;
	# my $msg_array = $pop->ListArray(); #size of all messages
	# print $msg_array;
	
	# print $pop->Alive(), "\n";
	# print $pop->State(), "\n";
	# print $pop->POPStat(), "\n";
	# print "LAST: ", $pop->Last(), "\n"; # returns the number of the last message retrieved from the server
	
	my $plural = $msg_count == 1 ? [ 'is', '' ] : [ 'are', 's' ];
	
	# print $pop->Retrieve(0);
	
	print "$pop_user: There $$plural[0] $msg_count" . " message$$plural[1]\n";
	
	my $out = "";

	if ($dis_numb == -1) { $dis_numb = $msg_count; };

	my $list_total = $msg_count-($dis_numb-1);
	
	for (my $i = $msg_count, my $j = 0; $i >= $list_total; $i--, $j++)
	{
		my $bodyY = 0;
		my $text  = 0;
		my $boundary;
	
		foreach my $line ( $pop->HeadAndBody( $i ) )
	# 	foreach my $line ( $pop->Body( $i ) )
	# 	foreach my $line ( $pop->Retrieve( $j ) )
		{
	# 		/^(From|Subject):\s+/i and print $_, "\n"; 
	# 		$pop->Head( $i );
	# 		$pop->Body( $i );
	# 		$pop->HeadAndBody( $i );
			if ( $popVerbose ) { print $line."\n"; };
	
			if ($line =~ m/^From:/) 
			{
				my $from;
				if ($line =~ m/^From: (\S+\@\S+)/) 
				{
					$from = $1;
				}
				elsif ($line =~ m#^From: .*<(.*)>#) 
				{
					$from = $1;
				}

# 				(my $from) = ($line =~ m#^From: .*<(.*)>#); 
# 				$from = substr($from, 0, 30); 
				
				if ( $from )
				{
					$out .= "$j = $from\t"; 
					$out{$j}{"From"} = $from;
				}
				else
				{
					die "no from\n";
				}
			}
	
			if ($line =~ m/^Subject:/) 
			{
				(my $subj) = ($line =~ m#^Subject: (.*)#); 
# 				$subj = substr($subj, 0, 30); 
				$out .= "$subj\n"; 
				$out{$j}{"Subj"} = $subj;
			}
	
			if ($line =~ m/^\s+boundary=\"(\S+)\"/)
			{
				$boundary = $1;
			}

			if (($boundary) && (($line =~ m/$boundary/) || ($line =~ m/X\-Apparently\-To\:/)))
			{
				$bodyY = 0;
			}

			if ($bodyY && $text)
			{
				my $body = $line;
	# 			$body = substr($body, 0, 30); 
				$out    .= "$body\n"; 
				$out{$j}{"Body"} .= $body;
			}

			if ($line =~ m/^Content-Disposition: inline/)
			{
				$bodyY = 1;
			}

			if ($line =~ m/^Content-Type: (.*)\/(.*)\;/)
			{
				if (($1 eq "text") && ($2 eq "plain")) { $text = 1; } else { $text = 0; };
			}
		} # end foreach my line
		if ( $deleteMail ) { $pop->Delete($i); };
	}
# 	print $out;
	
	# print $pop->HeadAndBody(1);
	# print $pop->Body(1);
	# print $pop->Retrieve(4);
	
	# sleep 2;
	
	$pop->Close();
	return %out;
}

sub print_hash
{
	my %to_do = %{$_[0]};
	foreach my $key (sort keys %to_do)
	{
		print "$key";
		foreach my $subk (sort keys %{$to_do{$key}})
		{
			my $value = $to_do{$key}{$subk};
			print "\t$subk:\t$value\n";
		}
		print "\n";
	}

}