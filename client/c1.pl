#!/usr/bin/perl
# From: https://stackoverflow.com/questions/3835013/how-can-i-implement-a-simple-irc-client-in-perl

use strict;
use warnings;
use AnyEvent;
use AnyEvent::IRC::Client;
use Data::Dumper ();
use Getopt::Long;

my %opt = (
    channel => '#ircmsgtest',
    nick    => "ircmsg$$",
    port    => 6667,
    server  => '192.168.0.1',
    verbose => 1,
);

GetOptions(\%opt,'channel','nick', 'port', 'server', 'verbose|v');
my $message = shift() || "test message @{[ scalar localtime() ]}";
if ($opt{verbose}) {
    warn "message is: '$message'";
    warn Data::Dumper->Dump([\%opt], [qw(*opt)]);
}

my $c = AnyEvent->condvar;
my $con = AnyEvent::IRC::Client->new;

$con->reg_cb(
    connect => sub {
         my ($con) = @_;
         $con->send_msg (NICK => $opt{nick});
         $con->send_msg (USER => $opt{nick}, '*', '0', $opt{nick});
    },
    irc_001 => sub {
         my ($con) = @_;
         print "$_[1]->{prefix} says I'm in the IRC: $_[1]->{params}->[-1]!\n";
         $c->broadcast;
    },
    join => sub {
        my ($con, $nick, $channel, $is_myself) = @_;
	print "$nick Join $channel: $is_myself\n";
        #if ($is_myself && $channel eq $opt{channel}) {
	$con->send_chan($channel, PRIVMSG => $channel, $message);
	$c->send;
	$c->wait;
        #}
    }
);

$con->connect($opt{server}, $opt{port}, 10);
#$con->send_srv(JOIN => $opt{channel});
$con->send_msg(PRIVMSG => $opt{channel}, $message);
$c->wait;
$con->disconnect;
