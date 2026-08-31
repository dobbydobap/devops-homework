# Networking Fundamentals

Commands run inside an `ubuntu:24.04` container with `iproute2`, `net-tools`, `iputils-ping`,
`dnsutils`, `traceroute`, `curl` and `netcat` installed. Each one has the output I got and what
I took away from it.

```bash
docker exec -it hw-linux bash
apt-get install -y iproute2 net-tools iputils-ping dnsutils traceroute curl netcat-openbsd
```

---

## hostname

```
$ hostname
devops-hw

$ hostname -I
172.17.0.2
```

The name the machine calls itself, and `-I` prints just its IP addresses. Quickest way to answer
"what box am I on and what is its address".

---

## ip addr

```
$ ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0@if50: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether ba:e4:f1:c8:d1:29 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
```

Lists every network interface with its IP and MAC address. `lo` is the loopback that never
leaves the machine, `eth0` is the real interface. `172.17.0.2/16` means the address is
172.17.0.2 and the first 16 bits are the network part, so the usable range is
172.17.0.0 - 172.17.255.255 with broadcast 172.17.255.255. `ba:e4:f1:c8:d1:29` is the MAC,
which is layer 2 and only matters on the local segment.

`ip addr` is the modern replacement for `ifconfig`.

---

## ip route

```
$ ip route
default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.2
```

The routing table. Anything inside 172.17.0.0/16 goes straight out `eth0` because it is on the
same network. Everything else goes to the default gateway 172.17.0.1. If a machine cannot reach
the internet but can ping its neighbours, a missing default route is the first thing I would check.

---

## ifconfig

```
$ ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.2  netmask 255.255.0.0  broadcast 172.17.255.255
        ether ba:e4:f1:c8:d1:29  txqueuelen 0  (Ethernet)
        RX packets 44434  bytes 61697325 (61.6 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 21130  bytes 1450592 (1.4 MB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        loop  txqueuelen 1000  (Local Loopback)
```

The older tool, from `net-tools`. Same information as `ip addr` but it also shows packet counters.
Note it prints the netmask as `255.255.0.0` where `ip addr` writes `/16` - two ways of saying the
same thing. Rising RX/TX error or dropped counters point at a physical or driver problem.

---

## ss -tuln

```
$ ss -tuln
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:Port
tcp   LISTEN 0      511          0.0.0.0:80        0.0.0.0:*
tcp   LISTEN 0      511             [::]:80           [::]:*
```

Which ports are open and listening. `-t` tcp, `-u` udp, `-l` listening only, `-n` numeric so it
prints `80` instead of `http`. `0.0.0.0:80` means it accepts connections on every interface -
if it said `127.0.0.1:80` it would only answer from inside the machine, which is the usual reason
a service works locally but not from outside.

`netstat -tulnp` gives the same thing plus the process name:

```
$ netstat -tulnp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      414/nginx: master p
tcp6       0      0 :::80                   :::*                    LISTEN      414/nginx: master p
```

---

## netstat -rn

```
$ netstat -rn
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         172.17.0.1      0.0.0.0         UG        0 0          0 eth0
172.17.0.0      0.0.0.0         255.255.0.0     U         0 0          0 eth0
```

The routing table again, in the old format. `0.0.0.0` as the destination is the default route,
and the `G` flag means it goes through a gateway.

---

## ping

```
$ ping -c 4 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=63 time=45.0 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=63 time=11.7 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=63 time=14.8 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=63 time=45.9 ms

--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3003ms
rtt min/avg/max/mdev = 11.690/29.347/45.875/16.132 ms
```

Sends ICMP echo requests to check reachability and round trip time. 0% packet loss is what you
want. `ttl=63` means the packet crossed one router on the way back (TTL starts at 64 and drops
by one per hop).

Pinging a name instead of an IP also tests DNS, so this is a nice single check for "is the
network working and is name resolution working":

```
$ ping -c 3 google.com
PING google.com (142.250.134.100) 56(84) bytes of data.
64 bytes from 142.250.134.100: icmp_seq=1 ttl=63 time=32.2 ms
64 bytes from 142.250.134.100: icmp_seq=2 ttl=63 time=37.8 ms
64 bytes from 142.250.134.100: icmp_seq=3 ttl=63 time=25.7 ms

--- google.com ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
```

If the IP pings but the name does not, the problem is DNS and not connectivity.

---

## nslookup and dig

```
$ nslookup github.com
Server:		192.168.65.7
Address:	192.168.65.7#53

Non-authoritative answer:
Name:	github.com
Address: 20.207.73.82
```

Resolves a name to an IP. "Non-authoritative" means the answer came from a cache rather than the
domain's own nameserver. `192.168.65.7#53` is the resolver being used - port 53 is DNS.

`dig` gives more detail, and `+short` gives just the answer:

```
$ dig +short github.com
20.207.73.82

$ dig google.com
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 48764
;; flags: qr rd ra; QUERY: 1, ANSWER: 6, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;google.com.			IN	A

;; ANSWER SECTION:
google.com.		197	IN	A	142.250.134.100
google.com.		197	IN	A	142.250.134.101
google.com.		197	IN	A	142.250.134.138
google.com.		197	IN	A	142.250.134.102
google.com.		197	IN	A	142.250.134.139
google.com.		197	IN	A	142.250.134.113

;; Query time: 0 msec
;; SERVER: 192.168.65.7#53(192.168.65.7) (UDP)
```

`status: NOERROR` means the lookup succeeded (`NXDOMAIN` would mean the name does not exist).
Google returns six A records for load balancing, and `197` is the TTL in seconds - how long the
answer can be cached before asking again.

---

## traceroute

```
$ traceroute -m 8 8.8.8.8
traceroute to 8.8.8.8 (8.8.8.8), 8 hops max, 60 byte packets
 1  172.17.0.1 (172.17.0.1)  0.504 ms  0.015 ms  0.003 ms
 2  * * *
 3  * * *
 4  * * *
```

Shows the path packets take, one router at a time, by sending packets with an increasing TTL.
Hop 1 is the Docker bridge gateway. The `* * *` after that is not a failure - those hops are not
replying to the probes, which is normal here because Docker Desktop runs behind a NAT inside a
WSL2 virtual machine. Ping to the same address still works, so the route is fine, the
intermediate routers just stay quiet.

---

## curl

```
$ curl -sI https://github.com
HTTP/2 200
date: Mon, 31 Aug 2026 16:00:49 GMT
content-type: text/html; charset=utf-8
content-language: en-US
etag: W/"3b8df9306721b36cd1111b2679e19c04"
cache-control: max-age=0, private, must-revalidate
strict-transport-security: max-age=31536000; includeSubdomains; preload
```

`-I` fetches only the response headers. This tests the whole chain at once: DNS, TCP connect,
TLS handshake and the HTTP response. `HTTP/2 200` means it all worked.

---

## nc (netcat)

```
$ nc -zv google.com 443
Connection to google.com (142.250.134.100) 443 port [tcp/*] succeeded!
```

Checks whether one specific TCP port is reachable. `-z` just scans without sending data, `-v` is
verbose. This is my go to for "is the firewall blocking this port" because it separates a port
problem from an application problem.

---

## arp

```
$ arp -n
Address                  HWtype  HWaddress           Flags Mask            Iface
172.17.0.1               ether   52:e0:cc:6b:f8:83   C                     eth0
```

The ARP table, mapping IP addresses to MAC addresses on the local network. ARP is how a machine
finds the hardware address for an IP before it can actually send the frame.

---

## /etc/resolv.conf

```
$ cat /etc/resolv.conf
# Generated by Docker Engine.
nameserver 192.168.65.7
```

The DNS servers the system uses. When name resolution breaks, this file is worth checking early -
that nameserver value is the same one `nslookup` reported.

---

## IP addressing notes from the session

Address classes:

| Class | First octet | Default mask | Network / host bits |
|---|---|---|---|
| A | 1 - 127 | 255.0.0.0 (/8) | 8 / 24 |
| B | 128 - 191 | 255.255.0.0 (/16) | 16 / 16 |
| C | 192 - 223 | 255.255.255.0 (/24) | 24 / 8 |
| D | 224 - 239 | multicast | - |

Private ranges, which are not routable on the internet:

- 10.0.0.0 - 10.255.255.255 (class A)
- 172.16.0.0 - 172.31.255.255 (class B)
- 192.168.0.0 - 192.168.255.255 (class C)

The container above got 172.17.0.2, which sits in the private class B range - Docker allocates
its bridge networks out of that block.

Host count for a given prefix is `2^(host bits) - 2`. The two subtracted are the network address
itself and the broadcast address. So a /24 has 2^8 - 2 = 254 usable addresses, and a /16 has
2^16 - 2 = 65534.

Worked from the session: `197.23.45.10` with mask `255.255.255.0` is class C, so 24 network bits
and 8 host bits, the network is 197.23.45.0 and the broadcast is 197.23.45.255.

![networking commands](screenshots/networking.png)
