#!/bin/bash

# NAME: lock-screen-timer
# PATH: /home/qaisar/scripts/
# DESC: Lock screen in x minutes and pause in y minutes
# DATE: Created Nov 19, 2016. Last revision Sep 06, 2020.
# NOTE: The pause time is written to /var/log/pause_time and is used
#       for all users.
#       The login times are written to /var/log/mylabel.lgo.
# NOTE: Time defaults to 60 minutes.
#       If previous version is sleeping it is killed.
#       Write time remaining to ./times/YYYY_MM_DD.time

function isWeekend() {
	d=$(date +%a)
	case $d in
		"Sat")
			echo "Yes"
			;;
		"Sun")
			echo "Yes"
			;;
		*)
			echo "No"
			;;
	esac
}

function todaysFile () {
	command date +%Y_%m_%d.time
}

declare -a minutes
function readFromToday () {
	if [[ $AUTO ]];then
		d=$(ls $HOME/times/ | grep $(todaysFile))
		# Find todays file.
		if [[ $d ]]; then
			minutes[0]=$(cat "$HOME/times/$d" | cut -d " " -f 1)
			minutes[1]=$(cat "$HOME/times/$d" | cut -d " " -f 2)
		else
			# create todays file if it does not exist.
			touch $HOME/times/$(todaysFile)
			chmod 666 $HOME/times/$(todaysFile)
			echo "$1 $2"> $HOME/times/$(todaysFile)

			minutes[0]=$1
			minutes[1]=$2
		fi

		return
	fi
	echo "minutes: ${minutes[0]} pause_after:${minutes[1]}"
}

function writeToToday () {
	if [[ $AUTO ]];then
		echo "auto write"
		d=$(ls $HOME/times/ | grep $(todaysFile))
		echo "$1 $2" > "$HOME/times/$(todaysFile)"
		echo "wrote $1 $2 to todays file"
	fi
}

function logOutOrShutdown () {
	
    if [[ $WSL_running == true ]]; then  
        # Call lock screen for Windows 10
        rundll32.exe user32.dll,LockWorkStation
    else
        # Kill every process that belongs to this user except this program.
	if [ "$SHUT" = "TRUE" ]; then
		sudo shutdown now
	elif [ "$SHUT" = "NOPE" ]; then
		echo "simulated shut"
	else
		echo "Locking the SCREEN"
		pkill -KILL -u $THIS_USER
	fi
	exit 0
    fi
}

function isBefore9Am() {
	H=$(date +%H)
	if (( 10#$H < 9 )); then
		return 0;
	fi
	return 1; 
}


function readPauseTime () {
        pt_file="/var/log/pause_time"
        today=$(today_fn)
	d=$(grep $today $pt_file)
	
	echo $(echo $d | cut -d " " -f 2)
}

function today_fn () {
	command date +%Y_%m_%d
}

function isPauseTimeOn () {
  t=$(readPauseTime)
	# TESTONLY change below 1 t0 60 to go from seconds to minutes or viceversa.
	nt=$(( $t + $WAIT_FOR_MINUTES * 60 ))
	ct=$(date +%s)
	echo "reading pause time $t" $(date --date=@$t)
	echo "current time $ct" $(date --date=@$ct)
	echo "next time $nt" $(date --date=@$nt)

	if [[ $t ]];then
		if [[ "$ct" -le "$nt" ]]; then
			echo "ct is less than nt - should pause now"
	   		return 0;
		fi
		echo "ct is more than nt - not pause"
		return 1;
   	else
		echo "ct is more than nt - not pause"
	       	return 1;
	fi
}

function writePauseTime () {
	echo "writePauseTime()"
        pt_file="/var/log/pause_time"
        today=$(today_fn)
	time=$(date +%s)
	human_time=$(date --date=@$time)

	# Look for todays date in the pause time file.
	d=$(grep $today $pt_file)
	if [[ $d ]]; then
		# If found, replace the time.
		echo "writing new pause time $human_time"
		sudo sed -i "s/^$today.*/$today $time $human_time/g" $pt_file
	else
		#If not found, just add a new line.
		echo "first time writing pause time $human_time"
		sudo echo "$today $time $human_time" >> $pt_file
	fi
}

MINUTES="$1" # Optional parameter 1 when invoked from terminal.
PAUSE_AFTER_MINUTES=20
PAUSE_MINUTES=20
WAIT_FOR_MINUTES=10
ARG_MINUTES="$1"
DISPLAY=$(who | egrep $THIS_USER\\s+: | awk '{print $2}')
# if no parameters set default MINUTES to 30
if [ $# == 0 ]; then
    MINUTES=30
    SLEEP=60
fi


for i in "$@"; do
	if [ $i = "shut" ]; then
		echo "need to shut"
		SHUT="TRUE"
	fi
	if [ $i = "noshut" ]; then
		echo "simulate to shut"
		SHUT="NOPE"
	fi
	if [[ $i =~ ^minutes=[0-9]+ ]]; then
		IFS=’=’ read -ra MINS <<< "$i"
		MINUTES="${MINS[1]}"
		ARG_MINUTES="${MINS[1]}"
	fi
	if [[ $i =~ ^sleep=[0-9]+ ]]; then
		IFS=’=’ read -ra ARR <<< "$i"
		SLEEP="${ARR[1]}"
	fi
	if [[ $i =~ "auto" ]]; then
		echo "running in auto start mode"
		AUTO="TRUE"
	fi
	if [[ $i =~ ^user=[a-z]+ ]]; then
		IFS=’=’ read -ra ARR <<< "$i"
		THIS_USER="${ARR[1]}"
		echo "the user is $THIS_USER"
		HOME="/home/$THIS_USER"
		echo "the home directory is $HOME"
	fi
	echo "$(date) $THIS_USER logs in " >> /var/log/mylabel.lgo
done


# If its a weekend add another 60 minutes, otherwise set to 0 initially.
if [[ $AUTO == "TRUE" ]]; then
	# Uncomment the bellow to Ban weekdays.
	# MINUTES=0
	w=$(isWeekend)
	if [[ $w == "Yes" ]]; then
		# TESTONLY - in test comment below to avoid adding minutes for weekends.
		# Disable adding 60 minutes on weekends, instead just give 60 mins on weekends.
		#MINUTES=$(( MINUTES+60 ))
		MINUTES=60
		echo "we have $MINUTES"
	fi
	# Uncomment the bellow to Ban everything, even weekends.
	# MINUTES=0
fi

# Check if lock screen timer already running
me=`basename "$0"`
echo "*** I am $me"
pID=$(pgrep -l "$me") # All PIDs matching lock-screen-timer name
PREVIOUS=$(echo "$pID" | grep -v ^"$$") # Strip out this running copy ($$$)
myPID=$(echo "$pID" | grep  ^"$$") # PID of this program

for i in "$PREVIOUS" ;do
	if [[ $i != "" ]]; then
		echo "killing previous process $i"
		if [[ "$SHUT" = "TRUE" ]];then
			kill $i
		fi
	fi
done

# Running under WSL (Windows Subsystem for Linux)?
if cat /proc/version | grep Microsoft; then
    WSL_running=true
else
    WSL_running=false
fi


while true ; do # loop until cancel

    if isBefore9Am; then
      logOutOrShutdown
    fi

    # If run in AUTO mode read minutes from todays file if exists
    # or create todays file and put minutes into it.
    readFromToday $MINUTES $PAUSE_AFTER_MINUTES
    MINUTES=${minutes[0]}
    PAUSE_AFTER_MINUTES=${minutes[1]}

    if [ $PAUSE_AFTER_MINUTES -le 0 ]; then
	    echo "pause time less than or equal to 0"
	    PAUSE_AFTER_MINUTES=$PAUSE_MINUTES
	    writeToToday $MINUTES $PAUSE_AFTER_MINUTES
    fi

    # Loop for X minutes, testing each minute for alert message.
    #(( ++MINUTES )) 
    while (( $MINUTES > 0 )); do

       if isPauseTimeOn; then
          logOutOrShutdown
       fi

       case $MINUTES in 
		1|2|3|5|10|15|30|45|60|90|120|480|960|1920)
            		paplay /usr/share/sounds/freedesktop/stereo/complete.oga ;
	    		notify-send -t 1 --urgency=critical --icon=/usr/share/icons/gnome/256x256/status/appointment-soon.png "Locking screen in ""$MINUTES"" minute(s)." ;

			;;
		32|62|92)
		    	paplay /usr/share/sounds/freedesktop/stereo/complete.oga ;
		    	notify-send -t 1 --urgency=critical --icon=/usr/share/icons/gnome/256x256/status/appointment-soon.png "10 minute pause time in 2 minute(s)." ;
			echo "Second case"
			;;
        esac;
	
	if [ $PAUSE_AFTER_MINUTES -le 1 ]; then
		writePauseTime
	fi

        # Record number of minutes remaining to file other processes can read.
        #echo "Lock screen in: $MINUTES Minutes" > ~/.lock-screen-timer-remaining

        sleep $SLEEP
        readFromToday $MINUTES $PAUSE_AFTER_MINUTES
	MINUTES=${minutes[0]}
	PAUSE_AFTER_MINUTES=${minutes[1]}
	(( --MINUTES ))
	(( --PAUSE_AFTER_MINUTES ))
	writeToToday $MINUTES $PAUSE_AFTER_MINUTES
    done

    #rm /home/$THIS_USER/.lock-screen-timer-remaining # Remove work file others can see our progress with

    writeToToday 0 $PAUSE_AFTER_MINUTES

    logOutOrShutdown


done # End of while loop getting minutes to next lock screen

exit 0 # Closed dialog box or "Cancel" selected.
