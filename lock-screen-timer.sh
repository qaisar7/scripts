#!/bin/bash

# NAME: lock-screen-timer
# PATH: $HOME/bin
# DESC: Lock screen in x minutes
# CALL: Place on Desktop or call from Terminal with "lock-screen-timer 99"
# DATE: Created Nov 19, 2016. Last revision May 30, 2018.
# UPDT: Updated to support WSL (Windows Subsystem for Linux)
#       Remove hotplugtv. Replace ogg with paplay.
#       Cohesion with multi-timer. New sysmonitor indicator style.

# NOTE: Time defaults to 30 minutes.
#       If previous version is sleeping it is killed.
#       Zenity is used to pop up entry box to get number of minutes.
#       If zenity is closed with X or Cancel, no screen lock timer is launched.
#       Pending lock warning displayed on-screen at set intervals.
#       Write time remaining to ./.lock-screen-timer-remaining

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

MINUTES="$1" # Optional parameter 1 when invoked from terminal.
export DISPLAY=$(who | egrep $THIS_USER\\s+: | awk '{print $2}')
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
done


# If its a weekend add another 60 minutes
if [[ $AUTO == "TRUE" ]]; then
	w=$(isWeekend)
	echo "its really true"
	if [[ $w == "Yes" ]]; then
		MINUTES=$(( MINUTES+60 ))
	fi
fi

DEFAULT="$MINUTES" # When looping, minutes count down to zero. Save deafult for subsequent timers.

# Check if lock screen timer already running
pID=$(pgrep -f "${0##*/}") # All PIDs matching lock-screen-timer name
PREVIOUS=$(echo "$pID" | grep -v ^"$$") # Strip out this running copy ($$$)
myPID=$(echo "$pID" | grep  ^"$$") # PID of this program
echo $PREVIOUS
if [[ "$PREVIOUS" != "" && $AUTO == "" ]]; then
    #kill "$PREVIOUS"
    #rm ~/.lock-screen-timer-remaining
    if [ "$DISPLAY" != ""  ];then
    	zenity --info --title="Lock screen timer already running" --text="Already running!"
	exit 0
    else
	echo "Lock screen timer already running myPID=$myPID"
	exit 0
    fi
fi

# Running under WSL (Windows Subsystem for Linux)?
if cat /proc/version | grep Microsoft; then
    WSL_running=true
else
    WSL_running=false
fi


while true ; do # loop until cancel

    # Get number of minutes until lock from user
    if [[ "$DISPLAY" != "" && "$AUTO" != "TRUE" ]]; then
    	MINUTES=$(zenity --entry --title="Lock screen timer" --text="Set number of minutes until lock" --entry-text="$DEFAULT")
        RESULT=$? # Zenity return code
        if [ $RESULT != 0 ]; then
            break ; # break out of timer lock screen loop and end this script.
        fi
    fi
    # If run in AUTO mode read minutes from todays file if exists
    # or create todays file and put minutes into it.
    MINUTES=$(readFromToday $MINUTES)
    DEFAULT="$MINUTES" # Save deafult for subsequent timers.

    # Loop for X minutes, testing each minute for alert message.
    #(( ++MINUTES )) 
    while (( $MINUTES > 0 )); do
        case $MINUTES in 1|2|3|5|10|15|30|45|60|120|480|960|1920)
            if [[ $WSL_running == true ]]; then  
                powershell.exe -c '(New-Object Media.SoundPlayer "C:\Windows\Media\notify.wav").PlaySync();'
            else
               paplay /usr/share/sounds/freedesktop/stereo/complete.oga ;
            fi
	    notify-send -t 1 --urgency=critical --icon=/usr/share/icons/gnome/256x256/status/appointment-soon.png "Locking screen in ""$MINUTES"" minute(s)." ;
           ;;
        esac;
        # Record number of minutes remaining to file other processes can read.
        echo "Lock screen in: $MINUTES Minutes" > ~/.lock-screen-timer-remaining

        sleep $SLEEP
        MINUTES=$(readFromToday $MINUTES)
	(( --MINUTES ))
	writeToToday $MINUTES
    done

    rm /home/fariya/.lock-screen-timer-remaining # Remove work file others can see our progress with

    writeToToday 0

    if [[ $WSL_running == true ]]; then  
        # Call lock screen for Windows 10
        rundll32.exe user32.dll,LockWorkStation
    else
        # Kill every process that belongs to this user except this program.
	pkill -KILL -u $THIS_USER
	if [ "$SHUT" = "TRUE" ]; then
		sudo shutdown now
	else
		dbus-send --type=method_call --dest=org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver.Lock
		echo "Locking the SCREEN"
	fi
	exit 0
    fi

done # End of while loop getting minutes to next lock screen

exit 0 # Closed dialog box or "Cancel" selected.
