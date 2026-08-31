# Shell Scripting - System Information Script

[sysinfo.sh](sysinfo.sh) prints the date, hostname, username, disk usage and running processes,
asks where to save a report, then writes the full process list into a file.

It covers all the required pieces: variables, `read -p`, `mkdir`, `touch`, `echo`, `date`,
`hostname`, `whoami`, `df`, `ps`, and `>` output redirection.

## The script

```bash
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
```

## Running it

```bash
chmod +x sysinfo.sh
./sysinfo.sh
```

I ran this inside an `ubuntu:24.04` container and typed `sysreport` at the prompt:

```
==== System Information ====
Date      : Mon Aug 31 16:14:19 UTC 2026
Hostname  : devops-hw
Username  : root

==== Disk Usage ====
Filesystem      Size  Used Avail Use% Mounted on
overlay        1007G   66G  890G   7% /
tmpfs            64M     0   64M   0% /dev
shm              64M     0   64M   0% /dev/shm
/dev/sde       1007G   66G  890G   7% /etc/hosts
tmpfs           3.9G     0  3.9G   0% /proc/acpi
tmpfs           3.9G     0  3.9G   0% /proc/scsi
tmpfs           3.9G     0  3.9G   0% /sys/firmware

==== Running Processes ====
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0   2704  1452 ?        Ss   15:55   0:00 sleep infinity
root        3018 21.4  0.0   4332  3300 ?        Ss   16:14   0:00 /bin/bash ./run.sh
root        3024 12.5  0.0   2724  1760 ?        S    16:14   0:00 script -qec ./sysinfo.sh /dev/null
root        3025  0.0  0.0   2808  1928 pts/0    Ss+  16:14   0:00 sh -c ./sysinfo.sh
root        3026  0.0  0.0   4332  3464 pts/0    S+   16:14   0:00 /bin/bash ./sysinfo.sh
root        3031 50.0  0.0   7896  4156 pts/0    R+   16:14   0:00 ps aux
root        3032  0.0  0.0   2716  1580 pts/0    S+   16:14   0:00 head -10

Enter a directory name to store the report: sysreport
Directory 'sysreport' created.
Running processes saved in sysreport/processes.txt

First 5 lines of sysreport/processes.txt:
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0   2704  1452 ?        Ss   15:55   0:00 sleep infinity
root        3018 18.7  0.0   4332  3300 ?        Ss   16:14   0:00 /bin/bash ./run.sh
root        3024 10.0  0.0   2724  1760 ?        S    16:14   0:00 script -qec ./sysinfo.sh /dev/null
root        3025  0.0  0.0   2808  1928 pts/0    Ss+  16:14   0:00 sh -c ./sysinfo.sh
```

The `run.sh` and `script` lines in the process list are just how I fed the input in while
capturing the transcript - running `./sysinfo.sh` directly and typing the name gives the same
result.

![sysinfo script output](screenshots/sysinfo.png)

## The file it produced

```
$ ls sysreport
processes.txt

$ wc -l sysreport/processes.txt
7 sysreport/processes.txt
```

## Notes to self

- `$(date)` runs the command and stores the result, whereas `"date"` would just be the word.
- `read -p` prints the prompt and reads into a variable in one line.
- `>` overwrites the file, `>>` appends. The report uses `>` so a rerun replaces the old list
  instead of piling on top of it.
- Variables get quoted (`"$DIR_NAME"`) so a directory name with a space does not break the script.
- `mkdir -p` does not error out if the directory already exists, which makes reruns safe.
