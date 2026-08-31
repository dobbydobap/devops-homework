# Linux Fundamentals

Everything below was run in an `ubuntu:24.04` container (my host is Windows), except the
journalctl task which needed systemd - see task 3.

```bash
docker run -d --name hw-linux --hostname devops-hw ubuntu:24.04 sleep infinity
docker exec -it hw-linux bash
```

---

## Task 1: Soft link and hard link

A hard link is a second name pointing at the same inode, so it *is* the file. A soft link
(symlink) is a small separate file that just stores a path to the target.

Creating both:

```bash
ln -s original.txt softlink.txt   # soft link
ln original.txt hardlink.txt      # hard link
```

`ls -li` shows the inode number in the first column:

```
$ ls -li
total 8
1183107 -rw-r--r-- 2 root root 26 Aug 31 15:56 hardlink.txt
1183107 -rw-r--r-- 2 root root 26 Aug 31 15:56 original.txt
1183120 lrwxrwxrwx 1 root root 12 Aug 31 15:56 softlink.txt -> original.txt
```

Two things to notice: `original.txt` and `hardlink.txt` share inode `1183107`, and their link
count is `2`. The soft link has its own inode `1183120` and its size is 12 bytes, which is just
the length of the string "original.txt".

Both read the same content, and both see updates made to the original:

```
$ echo "line added later" >> original.txt

$ cat softlink.txt
this is the original file
line added later

$ cat hardlink.txt
this is the original file
line added later
```

The difference shows up when the original is deleted:

```
$ rm original.txt

$ ls -li
total 4
1183107 -rw-r--r-- 1 root root 43 Aug 31 15:56 hardlink.txt
1183120 lrwxrwxrwx 1 root root 12 Aug 31 15:56 softlink.txt -> original.txt

$ cat hardlink.txt
this is the original file
line added later

$ cat softlink.txt
cat: softlink.txt: No such file or directory
```

The hard link still works and the data is intact - the link count just dropped from 2 to 1.
The soft link is now dangling, because the path it stored no longer exists.

![soft and hard links](screenshots/links.png)

### Interview answer

| | Hard link | Soft link |
|---|---|---|
| Points to | the inode (the data itself) | a pathname |
| Own inode | no, shares the target's | yes |
| Survives deleting the original | yes | no, becomes broken |
| Works across filesystems | no | yes |
| Can link a directory | no (except `.` and `..`) | yes |
| Command | `ln target linkname` | `ln -s target linkname` |

Short version: deleting a file only removes one name for it. The data is freed when the link
count reaches zero, which is why a hard link keeps the file alive and a symlink does not.

---

## Task 2: adduser vs useradd

`useradd` is the low level binary. `adduser` on Debian/Ubuntu is a Perl script that calls
`useradd` for you with sensible defaults.

`useradd` on its own does the bare minimum:

```
$ useradd testuser1

$ grep testuser1 /etc/passwd
testuser1:x:1001:1001::/home/testuser1:/bin/sh

$ ls /home
ubuntu
```

The passwd entry mentions `/home/testuser1`, but the directory was never created, the shell is
`/bin/sh`, and no password was set.

`adduser` does the whole job:

```
$ adduser --disabled-password --gecos "" testuser2
info: Adding user `testuser2' ...
info: Selecting UID/GID from range 1000 to 59999 ...
info: Adding new group `testuser2' (1002) ...
info: Adding new user `testuser2' (1002) with group `testuser2 (1002)' ...
info: Creating home directory `/home/testuser2' ...
info: Copying files from `/etc/skel' ...
info: Adding new user `testuser2' to supplemental / extra groups `users' ...
info: Adding user `testuser2' to group `users' ...

$ grep testuser2 /etc/passwd
testuser2:x:1002:1002:,,,:/home/testuser2:/bin/bash

$ ls /home
testuser2
ubuntu

$ ls -a /home/testuser2
.
..
.bash_logout
.bashrc
.profile
```

The home directory exists, the dotfiles were copied from `/etc/skel`, and the shell is `/bin/bash`.

```
$ id testuser1
uid=1001(testuser1) gid=1001(testuser1) groups=1001(testuser1)

$ id testuser2
uid=1002(testuser2) gid=1002(testuser2) groups=1002(testuser2),100(users)
```

I used `--disabled-password --gecos ""` only because a container has no interactive terminal.
Run normally, `adduser testuser2` prompts for the password and the full name.

**Preferred on Ubuntu: `adduser`**, because it creates the home directory, copies `/etc/skel`,
sets a proper login shell and prompts for a password in one step. `useradd` is the portable one
that exists on every distro, and it is what you use in scripts where you want to control each
option yourself - note it needs `-m` to create the home directory at all.

![adduser vs useradd](screenshots/users.png)

---

## Task 3: journalctl

`journalctl` reads the logs collected by `systemd-journald`. Instead of every service writing
its own text file under `/var/log`, systemd collects everything - kernel messages, service
output, syslog - into one indexed binary journal that you query with filters.

A normal container has no systemd running, so `journalctl` would have no journal to read. I
started a systemd enabled container for this task:

```bash
docker run -d --name hw-systemd --privileged --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw --tmpfs /run --tmpfs /run/lock \
  jrei/systemd-ubuntu:24.04
```

```
$ systemctl is-system-running
running
```

Then I installed nginx so there was a real service to look at:

```
$ systemctl status nginx
* nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-08-31 15:58:53 UTC; 3s ago
       Docs: man:nginx(8)
   Main PID: 389 (nginx)
      Tasks: 5 (limit: 9518)
     Memory: 3.7M (peak: 4.4M)
        CPU: 24ms
```

### Logs for a specific service

This is the one I would actually reach for day to day:

```
$ journalctl -u nginx
Aug 31 15:58:53 dbfc252bf234 systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Aug 31 15:58:53 dbfc252bf234 systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
Aug 31 15:59:08 dbfc252bf234 systemd[1]: Stopping nginx.service - A high performance web server and a reverse proxy server...
Aug 31 15:59:08 dbfc252bf234 systemd[1]: nginx.service: Deactivated successfully.
Aug 31 15:59:08 dbfc252bf234 systemd[1]: Stopped nginx.service - A high performance web server and a reverse proxy server.
Aug 31 15:59:09 dbfc252bf234 systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Aug 31 15:59:09 dbfc252bf234 systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
```

The full stop and start cycle is there from when I restarted the service.

### Other filters I practised

```
$ journalctl -n 10
Aug 31 15:58:52 dbfc252bf234 systemd[1]: Reloading...
Aug 31 15:58:52 dbfc252bf234 systemd[1]: Reloading finished in 51 ms.
Aug 31 15:58:53 dbfc252bf234 systemd[1]: Reached target network-online.target - Network is Online.
Aug 31 15:58:53 dbfc252bf234 systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Aug 31 15:58:53 dbfc252bf234 systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.

$ journalctl --disk-usage
Archived and active journals take up 8.0M in the file system.

$ journalctl --list-boots
IDX BOOT ID                          FIRST ENTRY                 LAST ENTRY
  0 92eb0cc63cdc41c398eeab3f050a7b5a Mon 2026-08-31 15:58:15 UTC Mon 2026-08-31 15:59:09 UTC
```

`journalctl -p err` picked up genuine errors coming from the WSL layer underneath Docker:

```
$ journalctl -p err
Aug 31 15:58:15 dbfc252bf234 unknown: WSL (108) ERROR: CheckConnection: getaddrinfo() failed: -5
Aug 31 15:58:15 dbfc252bf234 unknown: WSL (108) ERROR: CheckConnection: getaddrinfo() failed: -3
```

### The flags worth remembering

| Command | What it does |
|---|---|
| `journalctl -u <service>` | logs for one service |
| `journalctl -f` | follow live, like `tail -f` |
| `journalctl -n 50` | last 50 entries |
| `journalctl -b` | logs since the current boot |
| `journalctl --since "1 hour ago"` | time filtered |
| `journalctl -p err` | filter by priority |
| `journalctl --disk-usage` | how much space the journal uses |
| `journalctl --vacuum-time=7d` | delete journal data older than 7 days |

![journalctl](screenshots/journalctl.png)

---

## Task 4: Linux command cheat sheet

The cheat sheet commands, run one after another:

```
$ pwd
/root/practice

$ mkdir -p project/logs

$ touch project/notes.txt project/logs/app.log

$ ls -lR project
project:
total 4
drwxr-xr-x 2 root root 4096 Aug 31 15:59 logs
-rw-r--r-- 1 root root    0 Aug 31 15:59 notes.txt

project/logs:
total 0
-rw-r--r-- 1 root root 0 Aug 31 15:59 app.log

$ echo "server started" > project/logs/app.log
$ echo "connection error" >> project/logs/app.log

$ cat project/logs/app.log
server started
connection error

$ grep error project/logs/app.log
connection error

$ wc -l project/logs/app.log
2 project/logs/app.log

$ cp project/notes.txt project/notes-backup.txt
$ mv project/notes-backup.txt project/old-notes.txt

$ ls project
logs
notes.txt
old-notes.txt

$ find . -name "*.log"
./project/logs/app.log

$ chmod 750 project/notes.txt
$ ls -l project/notes.txt
-rwxr-x--- 1 root root 0 Aug 31 15:59 project/notes.txt

$ du -sh project
12K	project

$ uname -a
Linux devops-hw 6.18.33.1-microsoft-standard-WSL2 #1 SMP PREEMPT_DYNAMIC Fri Jun  5 01:12:21 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux

$ whoami
root

$ df -h /
Filesystem      Size  Used Avail Use% Mounted on
overlay        1007G   66G  891G   7% /

$ free -h
               total        used        free      shared  buff/cache   available
Mem:           7.8Gi       2.8Gi       1.1Gi        43Mi       4.0Gi       4.9Gi
Swap:          2.0Gi       707Mi       1.3Gi
```

Quick reference of what each one is for:

| Command | Purpose |
|---|---|
| `pwd` | print the directory you are in |
| `ls -l` / `ls -a` | list files in long format / including hidden |
| `cd` | change directory |
| `mkdir -p` | create a directory, `-p` makes parent directories too |
| `touch` | create an empty file, or update its timestamp |
| `cp` / `mv` / `rm` | copy, move or rename, delete |
| `cat` / `head` / `tail` | show a whole file, its first lines, its last lines |
| `grep` | search for text inside files |
| `find` | search for files by name, size or type |
| `chmod` / `chown` | change permissions / ownership |
| `ps aux` | list running processes |
| `df -h` | free disk space per filesystem |
| `du -sh` | size of a directory |
| `free -h` | memory usage |
| `uname -a` | kernel and system information |
| `wc -l` | count lines |

One thing that clicked while doing this: `chmod 750` is three digits for three sets of
permissions - owner 7 (rwx), group 5 (r-x), others 0 (---), which `ls -l` then shows back as
`-rwxr-x---`.

![cheat sheet practice](screenshots/cheatsheet.png)
