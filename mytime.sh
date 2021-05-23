#!/bin/bash

ARGS=2
E_BADARGS=85

function usage_help() {
	echo "Usage: `basename $0` user-name minutes pause_after_minutes" >&2
	exit $E_BADARGS
}


function check_arguments() {
	if [[ $# -eq 0 ]]; then
		usage_help
		exit
	fi
	if [[ $# -eq 1 ]]; then
		echo "show"
		exit
	fi
	re='^[0-9]+$'
	if ! [[ $2 =~ $re ]] ; then
		   echo "error: $2 is not a number" >&2; exit 1
	fi
	
	if ! [[ $3 =~ $re ]] ; then
		   echo "error: $3 is not a number" >&2; exit 1
	fi
	echo "add"
}

TODAYS_FILE=`date +%Y_%m_%d.time`

command=$(check_arguments "$@")

if [[ $command  =~ "show" ]]; then
	cat "/home/$1/times/$TODAYS_FILE"
	exit 0
elif [[ $command =~ "add" ]]; then
	echo "$2 $3">  "/home/$1/times/$TODAYS_FILE"
else
	exit 0
fi


