#
SERVER=${1:-mail}

Parser() {
    while read line;
    do
	set -- $line
	case $2 in
	\#*)	# Write to a specific file for the channel
		from=$1
		channel=${2#\#}
		shift 2
		echo "$from $*" >> $channel
		;;
	*)	#
		echo $line
		;;
	esac
    done
}

socat - TCP4:$SERVER:6667 | Parser
