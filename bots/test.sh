# This is a test bot for lirc. It only logs the input given.
Pgm=test

exec >> $Pgm.log 2>&1
echo $(date): $*
