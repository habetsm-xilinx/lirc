# From https://perlmaven.com/chat-server-using-net-server
package MuxChatServer;
use warnings;
use strict;

use base 'Net::Server::Multiplex';
use Sys::Hostname;
#use LogLevels;
use IrcCommand;
#use Log::Log4perl qw(:levels);

my $EOL   = "\015\012";
# From /usr/share/perl5/Net/Server/Log/Log/Log4perl.pm
our $DEBUG = 4;
my $INFO = 3;
my $WARN = 2;
my $ERROR = 1;

sub write_to_log_hook {
    my ($self, $level, $line) = @_;
    print STDERR "LOG $level: $line\n";
}

sub mux_connection {
    my ($self, $mux, $fh) = @_;
    my $host = hostname;

    $self->{peerport} = $self->{net_server}{server}{peerport};
    my $peer = "$self->{peeraddr}:$self->{peerport}";
    $self->log($INFO, "Client [$peer] just connected...");
    print "Welcome to server $host!$EOL";
    $self->broadcast($mux, "Please welcome $peer, who just joined us$EOL", $fh);
}

sub get_channel {
    my ($self, $line) = @_;
    my $channel =  $self->{channel} || "";

    if (substr($line, 0, 1) eq '#') {
	my @l = split(" ", $line);

	$channel = shift @l;
	$line = join(' ', @l);
    }
    return ($channel, $line);
}

sub handle_quit_command {
    my ($self) = @_;
    my $nick = $self->{nick} || "";
    my $channel =  $self->{channel} || "";

    IrcCommand::part_channel($self, $channel);
    IrcCommand::set_nick($nick, undef);
    close(STDOUT);
}

sub handle_bot_command {
    my ($self, $line) = @_;

    if (not substr($line, 0, 1) eq '@') {
	return;
    }

    my @text2 = split(" ", $line);
    my $bot = substr(shift @text2, 1);

    # Invoke a bot
    $bot .= ".sh";
    open my $in, '<', $bot or return;
    close $in;
    my $cmd = "./" . $bot . " " . join(' ', @text2);
    $self->log($DEBUG, "Invoking $cmd");
    system($cmd);
}

sub log_line {
    my ($self, $channel, $line) = @_;
    my $peer = $self->{nick} || "$self->{peeraddr}:$self->{peerport}";

    $self->log($INFO, "$peer($channel): $line");
    if (length($channel) == 0) {
	return;
    }

    # Append to the channel log
    if ($channel =~ "^#*") {
	$channel = substr($channel, 1);
    }
    $channel .= ".log";
    open(my $out, '>>', $channel) or die "Could not open file '$channel'";
    say $out "$peer: $line";
    close $out;
}

sub mux_input  {
    my ($self, $mux, $fh, $in_ref) = @_;
 
    while ($$in_ref =~ s/^(.*?)\r?\n//) {
        next unless $1;
        my $text = $1;
	my $reply = IrcCommand::handle_irc_command($self, $text);

	if (defined $reply) {
	    if (length($reply) gt 0) {
		#$self->log($DEBUG, "Sending: $reply");
		print "$reply$EOL";
	    }
	} else {
	    my $peer = $self->{nick} || "$self->{peeraddr}:$self->{peerport}";
	    my ($ch, $line) = $self->get_channel($text);

	    $self->log_line($ch, $line);
	    if ($line eq 'bye') {
		$self->handle_quit_command;
		return;
	    }
	    if ($ch ne "") {
		$ch .= " ";
	    }
	    $self->broadcast($mux, "$peer: $ch$text$EOL", $fh);
	    $self->handle_bot_command($line);
	}
    }
}

sub broadcast {
    my ($self, $mux, $msg, $my_fh) = @_;
 
    foreach my $fh ($mux->handles) {
        next if $fh eq $my_fh;
        print $fh $msg;
    }
}

sub mux_close {
    my ($self, $mux, $fh) = @_;
 
    if (exists $self->{peerport}) {
        my $peer = $self->{nick} || "$self->{peeraddr}:$self->{peerport}";
        $self->log($INFO, "Client [$peer] closed connection!");
        $self->broadcast($mux, "Unfortunately $peer left us$EOL", $fh);
	$self->handle_quit_command;
    }
}

1;
