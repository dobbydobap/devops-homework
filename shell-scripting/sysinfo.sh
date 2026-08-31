#!/bin/bash
# System information script
# Prints basic system details and saves the running processes to a file.

CURRENT_DATE=$(date)
HOST_NAME=$(hostname)
USER_NAME=$(whoami)

echo "==== System Information ===="
echo "Date      : $CURRENT_DATE"
echo "Hostname  : $HOST_NAME"
echo "Username  : $USER_NAME"

echo
echo "==== Disk Usage ===="
df -h

echo
echo "==== Running Processes ===="
ps aux | head -10

echo
read -p "Enter a directory name to store the report: " DIR_NAME

mkdir -p "$DIR_NAME"
echo "Directory '$DIR_NAME' created."

REPORT_FILE="$DIR_NAME/processes.txt"
touch "$REPORT_FILE"

ps aux > "$REPORT_FILE"
echo "Running processes saved in $REPORT_FILE"

echo
echo "First 5 lines of $REPORT_FILE:"
head -5 "$REPORT_FILE"
