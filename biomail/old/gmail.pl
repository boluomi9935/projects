#!/usr/bin/perl -w
use warnings;
use strict;

use Mail::Webmail::Gmail;
use HTTP::Cookies;
use HTTP::Headers;
use HTTP::Request::Common;
use LWP::UserAgent;
use Crypt::SSLeay;
# perl -MCPAN -e shell
# install HTTP::Cookies
# install Crypt::SSLeay;

my $gmail = Mail::Webmail::Gmail->new( 
                username => 'cbsknaw',
		password => 'uppssalla',
            );

# my @labels = $gmail->get_labels();
# print @labels;

# my $messages = $gmail->get_messages( label => "myself" );

my $messages = $gmail->get_messages( label => 'work' );

1;