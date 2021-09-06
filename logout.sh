#!/bin/bash


echo " $(date) $1 logging out"

myPID=$(echo "$pID" | grep  ^"$$") # PID of this program
pgrep lock-screen | xargs kill -9
pgrep -u $1 | grep -v myPID | xargs kill -9
