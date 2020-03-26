#!/bin/bash

U=$1
M="DENIED"

if [[ $1 =~ '-v' ]]; then
	U=$2
	# If -v is specified as the first arugment then look for all the connections.
	M="CONNECT"
fi
echo "$M $U"

sites=`sudo cat /var/log/squid3/access.log | grep "$M".*"$U" | awk '{print $7}' | sort -u | uniq`

for i in $sites;do
	# Get the most recent time for the match.
	time=`sudo tac /var/log/squid3/access.log |  grep -m1 "$M".*"$i".*"$U" | awk '{print $1}' | cut -d. -f1`
	# Convert the time from epoxh to Human readable format.
	echo `date -d @$time` $i
done
