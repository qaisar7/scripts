#!/bin/bash

valid_connection() {
	HOST=192.168.1.1

	ping -c1 $HOST 1>/dev/null 2>/dev/null
	SUCCESS=$?

	if [ $SUCCESS -eq 0 ];then
		echo "$HOST has replied"
		return 0
	else
		echo "$HOST didn't reply"
		return 1
	fi
}

connect_wifi() {
	i=0
	while ! valid_connection  && [[ $i -lt 3 ]];do
		# Tries to connect
		nmcli connection up id QNet_2 1>/dev/null 2>/dev/null
		i=$((i+1))
	done
	if [[ $i -lt 3 ]];then
		return 0
	else
		return 1
	fi
}


if ! connect_wifi; then
	notify-send -t 1 --urgency=critical --icon=/usr/share/icons/gnome/256x256/status/appointment-soon.png "not able to connect to QNet_1 wifi";
	exit
fi

notify-send -t 1 --urgency=critical --icon=/usr/share/icons/gnome/256x256/status/appointment-soon.png "Hey Hey connected to QNet_1";

o=`pgrep -a squid3`

if [[ $o ]]; then
	echo "all good"
	notify-send -t 1 --urgency=critical --icon=/usr/share/icons/gnome/256x256/status/appointment-soon.png "all good" ;
	exit 0
fi

squid3 start

echo "Internet Started"
notify-send -t 1 --urgency=critical --icon=/usr/share/icons/gnome/256x256/status/appointment-soon.png "Internet started" ;
