#!/usr/bin/perl -w
use warnings;
use strict;

use Net::SMTP::SSL;
#perl -MCPAN -e shell
#install Net::SMTP::SSL
#install Authen::SASL
# http://robertmaldon.blogspot.com/2006/10/sending-email-through-google-smtp-from.html

my $smtpVerbose = 0;
my $provider = 2;
# 1 cbsknaw@gmail.com
# 2 knawcbsknaw@yahoo.com.br

for (my $i = 11; $i <= 20; $i++)
{
	&send_mail($provider,"cbsknaw\@gmail.com, knawcbsknaw\@yahoo.com.br", "test $i", "test $i body");
	# 	1 gmail 2 yahoo, to, subject, body
}

sub send_mail {
	my $server   = $_[0];
	my $to       = $_[1];
	my $subject  = $_[2];
	my $body     = $_[3];

	my $smtp_user_G = 'cbsknaw@gmail.com';
	my $smtp_pass_G = 'uppssalla';
	my $smtp_host_G = 'smtp.gmail.com';

	my $smtp_user_Y = 'knawcbsknaw@yahoo.com.br';
	my $smtp_pass_Y = 'uppssalla';
	my $smtp_host_Y = 'smtp.mail.yahoo.com.br';

	my $smtp_port   = 465;

	my $smtp_host;
	my $smtp_user;
	my $smtp_pass;
# 	my $cc;

	if (! $server )
	{
		die "NOR YAHOO OR GMAIL CONFIGURATED\n";
	}	
	elsif ($server eq "1")
	{
		print "GMAIL SELECTED\n";
		$smtp_host = $smtp_host_G;
		$smtp_user = $smtp_user_G;
		$smtp_pass = $smtp_pass_G;
# 		$cc        = $smtp_user_G;
	}
	elsif ($server eq "2")
	{
		print "YAHOO SELECTED\n";
		$smtp_host = $smtp_host_Y;
		$smtp_user = $smtp_user_Y;
		$smtp_pass = $smtp_pass_Y;
# 		$cc        = $smtp_user_Y;
	}
	else
	{
		die "NOR YAHOO OR GMAIL CONFIGURATED\n";
	}



	my $smtp;

	if (not $smtp = Net::SMTP::SSL->new($smtp_host, Port => $smtp_port,))
	{
		die "Could not connect to server\n";
	}

	if ( $smtpVerbose ) { $smtp->Debug(1); };

	$smtp->auth($smtp_user, $smtp_pass) || die "Authentication failed!\n";
	
	$smtp->mail($smtp_user . "\n");
	my @recepients = split(/,/, $to);
	push (@recepients, $smtp_user);
	foreach my $recp (@recepients) {
		$smtp->to($recp . "\n");
	}

	# Create arbitrary boundary text used to seperate
	# different parts of the message
	my ($bi, $bn, @bchrs);
	my $boundry = "";
	foreach $bn (48..57,65..90,97..122) {
	$bchrs[$bi++] = chr($bn);
	}
	foreach $bn (0..20) {
	$boundry .= $bchrs[rand($bi)];
	}


	$smtp->data();
	$smtp->datasend("From: "    . $smtp_user . "\n");
	$smtp->datasend("To: "      . $to        . "\n");
	$smtp->datasend("Subject: " . $subject   . "\n");
	$smtp->datasend("MIME-Version: 1.0\n");
	$smtp->datasend("Content-Type: multipart/alternative;\n");
	$smtp->datasend("        boundary=\"$boundry\"\n\n");
 	$smtp->datasend("\n--$boundry\n");
	$smtp->datasend("Content-Type: text/plain; charset=ISO-8859-1\n");
	$smtp->datasend("Content-Transfer-Encoding: 7bit\n");
	$smtp->datasend("Content-Disposition: inline\n");
	$smtp->datasend($body . "\n");
	$smtp->datasend("\n--$boundry"); # send boundary end message
	$smtp->datasend("\n");
	$smtp->dataend();
	$smtp->quit;
	print "DONE TO: $to SUBJ: $subject\n";
}

# Send away!
# &send_mail('johnny@mywork.com', 'Server just blew up', 'Some more detail');

# use Net::SMTP;
# 
# my $smtp = Net::SMTP->new("smtp.google.com",
#                       Timeout => 15,
#                       Debug => 1)|| print "ERROR creating SMTP obj: $! \n";
# 
# print "SMTP obj created.";
# print $smtp->domain,"\n";
# 
# # my $banner = $smtp->banner;
# # print $banner;
# 
# #                     Hello => 'smtp.google.com',
# 
# $smtp->mail('cbsknaw@gmail.com');
# $smtp->to("cbsknaw\@gmail.com");
# $smtp->data();
# $smtp->recipient("cbsknaw\@gmail.com", \ "user\@example2.com");
# # $smtp->to("user1@domain.com");
# # $smtp->cc("foo@example.com");
# # $smtp->bcc("bar@blah.net");
# 
# $smtp->datasend("From: cbsknaw\@gmail.com");
# $smtp->datasend("To: cbsknaw\@gmail.com");
# $smtp->datasend("Subject: This is a test");
# 
# $smtp->datasend("Disposition-Notification-To: cbsknaw\@gmail.com");
# 
# $smtp->datasend("Priority: Urgent\n");
# $smtp->datasend("Importance: high\n");
# 
# $smtp->datasend("\n");
# 
# 
# 
# $smtp->datasend("blahblah");
# 
# $smtp->dataend;
# $smtp->quit;
# 
# 
# 
# # email cbsknaw@gmailcom
# # user cbsknaw@gmail.com
# # passwd uppssalla
# # pop.gmail.com
# # 
# # smtp port 465
# # pop  port 995
