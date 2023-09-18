package IrcCommand;

use strict;
use warnings;
use AnyEvent::IRC::Util qw/parse_irc_msg mk_msg/;
use Sys::Hostname;
#use LogLevels;
# From /usr/share/perl5/Net/Server/Log/Log/Log4perl.pm
my $DEBUG = 4;
my $INFO = 3;
my $WARN = 2;
my $ERROR = 1;

my %channels;
my %nicks;

sub set_nick {
    my ($nick, $value) = @_;
    return unless (length($nick) > 0);

    if (defined $value) {
	$nicks{$nick} = $value;
	print STDERR "DEBUG: Nicks $nick is now $value\n";
    } else {
	delete($nicks{$nick});
	print STDERR "DEBUG: Removed nick $nick\n";
    }
}

sub part_channel {
    my ($self, $channel) = @_;
    if (length($channel) == 0) {
	return;
    }

    print STDERR "DEBUG: Somebody left channel $channel\n";
    $self->{channel} = undef;
    $channels{$channel}--;
}

sub handle_irc_command {
    my ($self, $line) = @_;
    #print STDERR "H: $line\n";
    my $m = parse_irc_msg($line);

    if (not defined $m) {
	$self->log($DEBUG, "Not IRC: $line");
	return undef;
    }
    my $cmd = uc $m->{command};
    #if ($m->{prefix}) {
#	my ($nick, $user, $host) = split_prefix();
    #}
    if ($cmd eq 'QUIT') {
	$self->handle_quit_command;
	return "";
    } elsif ($cmd eq 'NICK') {
	my $nick = $m->{params}[0];
	my $oldnick = $self->{nick} || "";
	my $reply;

	if (not defined $nick) {
	    #set_nick($oldnick, undef);
	    $reply = mk_msg(undef, '431', "No nickname given");
	    return $reply;
	}

	my $newnick = $nick || "";
	$self->log($INFO, "NICK $newnick was $oldnick");
	if (not exists $nicks{$nick}) {
	    set_nick($oldnick, undef);
	    set_nick($nick, "$self->{peeraddr}:$self->{peerport}");
	    $self->{nick} = $nick;
	    $reply =  mk_msg("$self->{peeraddr}:$self->{peerport}", "NICK", $nick);
	} else {
	    $reply = mk_msg(undef, '433', "Nickname is already in use");
	}
	return $reply;
    } elsif ($cmd eq 'USER') {
	my $host = hostname;
	my $reply = mk_msg($host, '001', $self->{nick}, "Welcome!");
	$self->log($DEBUG, "$cmd Sending: $reply\n");
	return $reply;
    } elsif ($cmd eq 'JOIN') {
	my $channel = $m->{params}[0];
	my $oldchannel = $self->{channel} || "";
	my $reply;

	part_channel($self, $oldchannel);
	if (defined $channel) {
	    if ($channel == "0") {
		# JOIN 0 means PART.
		$reply = mk_msg($self->{nick}, "PART");
		return $reply;
	    }
	    if (not exists $channels{$channel}) {
		$channels{$channel} = 1;
	    } else {
		$channels{$channel}++;
	    }
	}
	$self->{channel} = $channel;
	#my $host = hostname;
	if (defined $channel) {
	    $reply = mk_msg($self->{nick}, "JOIN", "$channel");
	} else {
	    $reply = mk_msg($self->{nick}, "JOIN");
	}
	$self->log($DEBUG, "$cmd Sending: $reply");
	return $reply;
    } elsif ($cmd eq 'PART') {
	my $oldchannel = $self->{channel} || "";

	part_channel($self, $oldchannel);
	my $reply = mk_msg($self->{nick}, "PART");
	return $reply;
    } elsif ($cmd eq 'HISTORY') {
	open my $cmd,'lirc.log' or die $@;
	my $line;
	while (defined($line=<$cmd>)) {
	    my $i = rindex $line, 'INFO', 0;
	    if ($i == 0) {
		print $line;
	    }
	}
	close $cmd;

	my $reply = mk_msg($self->{nick}, "End of HISTORY");
	return $reply;
    }
    # TODO: get history or log, help
    #print STDERR "Unhandled command: $cmd\n";
    return undef;
}

1;
