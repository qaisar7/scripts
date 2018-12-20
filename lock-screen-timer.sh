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
#       Write time remaining to ~/.lock-screen-timer-remaining

MINUTES="$1" # Optional parameter 1 when invoked from terminal.
export DISPLAY=$(who | egrep fariya\\s+: | awk '{print $2}')
# if no parameters set default MINUTES to 30
if [ $# == 0 ]; then
    MINUTES=30
    SLEEP=60
fi


for i in "$@"; do
	if [ $i = "shut" ];then
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
done

DEFAULT="$MINUTES" # When looping, minutes count down to zero. Save deafult for subsequent timers.

# Check if lock screen timer already running
pID=$(pgrep -f "${0##*/}") # All PIDs matching lock-screen-timer name
PREVIOUS=$(echo "$pID" | grep -v ^"$$") # Strip out this running copy ($$$)
myPID=$(echo "$pID" | grep  ^"$$") # PID of this program
echo $PREVIOUS
if [ "$PREVIOUS" != "" ]; then
    #kill "$PREVIOUS"
    #rm ~/.lock-screen-timer-remaining
    if [ "$DISPLAY" != ""  ];then
    	zenity --info --title="Lock screen timer already running" --text="Already running!"
	exit 0
    else
	echo "Lock screen timer already running"
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
    if [ "$DISPLAY" != "" ]; then
    	MINUTES=$(zenity --entry --title="Lock screen timer" --text="Set number of minutes until lock" --entry-text="$DEFAULT")
        RESULT=$? # Zenity return code
        if [ $RESULT != 0 ]; then
            break ; # break out of timer lock screen loop and end this script.
        fi
    fi

    DEFAULT="$MINUTES" # Save deafult for subsequent timers.
    if [[ $MINUTES == 0 ]] || [[ $MINUTES == "" ]]; then
        break ; # zero minutes considered cancel.
    fi


    # Loop for X minutes, testing each minute for alert message.
    (( ++MINUTES )) 
    while (( --MINUTES > 0 )); do
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

    done

    rm ~/.lock-screen-timer-remaining # Remove work file others can see our progress with

    if [[ $WSL_running == true ]]; then  
        # Call lock screen for Windows 10
        rundll32.exe user32.dll,LockWorkStation
    else
        # Call screen saver lock for Ubuntu versions > 14.04.
	pgrep -u $USER | grep -v myPID | xargs kill -9
	if [ "$SHUT" = "TRUE" ]; then
		sudo shutdown now
	else
		dbus-send --type=method_call --dest=org.gnome.ScreenSaver /org/gnome/ScreenSaver org.gnome.ScreenSaver.Lock
	fi
	exit 0
    fi

done # End of while loop getting minutes to next lock screen

exit 0 # Closed dialog box or "Cancel" selected.
