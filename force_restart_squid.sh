#!/bin/bash

is_squid_running() {

	running=`sudo pgrep -l squid | wc -l`
	if [ $running -gt 0 ]; then
		echo "Squid is running"
	else
		echo "Squid is not running"
	fi
}

sudo pgrep -l squid
echo "Killing squid"
sudo pkill squid
sudo pkill squid

is_squid_running

echo "Starting Squid"
sudo squid3 start

is_squid_running
