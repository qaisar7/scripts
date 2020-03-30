#!/bin/bash

# NAME: lock-screen-timer
# PATH: $HOME/bin
# DESC: Lock screen in x minutes
# CALL: Place on Desktop or call from Terminal with "lock-screen-timer 99"
# DATE: Created Nov 19, 2016. Last revision Mar 29, 2020.
# UPDT: Updated to support WSL (Windows Subsystem for Linux)
#       Cohesion with multi-timer. New sysmonitor indicator style.

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

function readFromToday () {
	if [[ $AUTO ]];then
		d=$(ls $HOME/times/ | grep $(todaysFile))
		# Find todays file.
		if [[ $d ]]; then
			echo $(cat "$HOME/times/$d")
		else
			# create todays file if it does not exist.
			touch $HOME/times/$(todaysFile)
			chmod 666 $HOME/times/$(todaysFile)
			echo $1 > $HOME/times/$(todaysFile)

			# Write the minutes left into the file
			echo "$1"
		fi

		return
	fi
	echo $1
}

function writeToToday () {
	if [[ $AUTO ]];then
		echo "auto write"
		d=$(ls $HOME/times/ | grep $(todaysFile))
		echo $1 > "$HOME/times/$(todaysFile)"
		echo "wrote $1 to todays file"
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
	nt=$(( $t + 600 ))
	ct=$(date +%s)

	echo "reading pause time $t" $(date --date=@$t)
	echo "current time $t" $(date --date=@$ct)
	echo "next time $t" $(date --date=@$nt)

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
        pt_file="/var/log/pause_time"
        today=$(today_fn)
	time=$(date +%s)
	human_time=$(date --date=@$time)

	# Look for todays date in the pause time file.
	d=$(grep $t $pt_file)
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
	fi
	echo "$(date) $THIS_USER logs in " >> /var/log/mylabel.lgo
done


# If its a weekend add another 60 minutes
if [[ $AUTO == "TRUE" ]]; then
	w=$(isWeekend)
	if [[ $w == "Yes" ]]; then
		MINUTES=$(( MINUTES+60 ))
	fi
fi

DEFAULT="$MINUTES" # When looping, minutes count down to zero. Save deafult for subsequent timers.

# Check if lock screen timer already running
me=`basename "$0"`
pID=$(pgrep -f "$me") # All PIDs matching lock-screen-timer name
PREVIOUS=$(echo "$pID" | grep -v ^"$$") # Strip out this running copy ($$$)
myPID=$(echo "$pID" | grep  ^"$$") # PID of this program

for i in "$PREVIOUS" ;do
	if [[ $i != "" ]]; then
		echo "killing previous process $i"
		kill $i
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
    MINUTES=$(readFromToday $MINUTES)
    DEFAULT="$MINUTES" # Save deafult for subsequent timers.

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

			case $MINUTES in 30|60|90)
				# If the current minutes are not equal to the 
				# initially provided minutes as argments, then
				# initiate the pause time. This means that its already been 30 minutes.
				# This assumes that the maximum time provided is 120 minutes.
				if [ $ARG_MINUTES -ne $MINUTES ]; then
					writePauseTime
				fi
				;;
			esac
			;;
		32|62|92)
		    	paplay /usr/share/sounds/freedesktop/stereo/complete.oga ;
		    	notify-send -t 1 --urgency=critical --icon=/usr/share/icons/gnome/256x256/status/appointment-soon.png "10 minute pause time in 2 minute(s)." ;
			echo "Second case"
			;;
        esac;
        # Record number of minutes remaining to file other processes can read.
        echo "Lock screen in: $MINUTES Minutes" > ~/.lock-screen-timer-remaining

        sleep $SLEEP
        MINUTES=$(readFromToday $MINUTES)
	(( --MINUTES ))
	writeToToday $MINUTES
    done

    rm /home/$THIS_USER/.lock-screen-timer-remaining # Remove work file others can see our progress with

    writeToToday 0

    logOutOrShutdown


done # End of while loop getting minutes to next lock screen

exit 0 # Closed dialog box or "Cancel" selected.
