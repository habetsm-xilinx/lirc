#!/usr/bin/perl
# From https://perlmaven.com/getting-started-with-net-server
use strict;
use warnings;

#use FindBin;
#use lib "$FindBin::Bin/../lib";
use MuxChatServer;
#use LogLevels;

my $username = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
my $groupname  = getgrgid($<);

my %opt = (
    port	=> 6667,
    ipv		=> 4,
    log_file	=> 'Log::Log4perl',
    log4perl_conf => 'server.conf',
    log_level	=> 3,
    #pid_file	=> ,
    user	=> $username,
    group	=> $groupname,
    #background
);

MuxChatServer->run(%opt);
