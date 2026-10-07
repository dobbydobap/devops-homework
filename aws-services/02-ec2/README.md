# EC2 — Elastic Compute Cloud (Compute)

## What is EC2?

EC2 gives you virtual servers ("instances") in AWS. You choose the operating system, CPU and
memory, storage and network, and you pay per second while it runs. It's IaaS: AWS runs the
hardware and the hypervisor, and you manage everything from the OS up — patching, software,
security settings.

## AMI — Amazon Machine Image

The template an instance boots from: an OS plus any pre-installed software and settings.

- AWS-provided AMIs: Amazon Linux 2023, Ubuntu, Windows Server, …
- Marketplace AMIs from vendors
- Your own AMIs, baked from a configured instance (or with Packer) so new servers start ready

AMI IDs are **per region**, so the same Ubuntu image has a different ID in `ap-south-1` and
`us-east-1`. In Terraform I look the AMI up with a `data "aws_ami"` block instead of hard-coding the
ID (see session 19).

## Instance types

The name encodes the family, generation and size: `t3.micro` = family **t**, generation **3**,
size **micro**.

| Family | Optimised for | Example |
|---|---|---|
| t | burstable general purpose — cheap, uses CPU credits | t3.micro, t4g.small |
| m | balanced general purpose | m7i.large |
| c | compute heavy | c7g.xlarge |
| r / x | memory heavy | r7i.2xlarge |
| g / p | GPU | g5.xlarge |
| i / d | fast local storage | i4i.large |

A `g` after the generation (`t4g`, `c7g`) means an ARM Graviton CPU, which is usually cheaper for
the same performance. `t3.micro` is in the free tier, which is why I used it in session 19.

## Key pairs

The SSH key used to log into a Linux instance. AWS keeps the public key and puts it in
`~/.ssh/authorized_keys` on the instance; you keep the private `.pem` file and AWS never has a copy.

```bash
ssh -i my-key.pem ec2-user@<public-ip>
```

Lose the private key and you can't SSH in. **SSM Session Manager** is the modern alternative: shell
access through the AWS API, with no key pair and no open port 22.

## Security Groups

A virtual firewall around each instance, made of allow rules only:

- **stateful** — if a request was allowed in, the reply is automatically allowed out
- **default**: all inbound blocked, all outbound allowed
- rules can reference **another security group** as the source, e.g. "the database accepts 5432
  only from the app servers' SG", instead of IP ranges

My session 19 SG allows 80 from anywhere and nothing else inbound — not even SSH.

## EBS — Elastic Block Store

Network-attached disks for instances. The root volume is EBS by default.

- persist independently of the instance (if `delete_on_termination` is off)
- live in **one Availability Zone** and attach to instances in that AZ
- types: `gp3` (general SSD, the default), `io2` (high IOPS for databases), `st1`/`sc1` (cheap HDD)
- **snapshots** back up a volume to S3 and can be copied to other regions

Instance store is the opposite: physically attached, very fast, and **wiped** when the instance stops.

## Public vs private IP

| | Private IP | Public IP | Elastic IP |
|---|---|---|---|
| Reachable from | inside the VPC | the internet | the internet |
| Assigned | always, from the subnet's range | if the subnet/instance asks for one | you allocate and attach it |
| On stop/start | kept | **changes** | kept |
| Cost | free | charged per hour | charged per hour |

An instance only gets a public IP if it's in a subnet with `map_public_ip_on_launch` (or you ask for
one), and it's only reachable if that subnet routes to an **Internet Gateway** — see the VPC notes.

## Instance lifecycle

```
pending --> running --> stopping --> stopped --> (start) --> pending
               |                        |
               +--> shutting-down --> terminated   (gone for good)
```

- **running**: billed for compute
- **stopped**: not billed for compute, but **EBS storage is still billed**; the public IP is released
- **terminated**: deleted; root volume deleted by default
- **reboot**: same host, keeps IPs, never leaves running
- **hibernate**: RAM saved to EBS, so the next start resumes where it left off

## Common use cases

- web and application servers (often in an Auto Scaling Group behind a load balancer)
- self-managed databases or software that needs OS-level control
- Kubernetes worker nodes (EKS managed node groups are EC2 instances)
- batch jobs and CI runners, often on cheap **Spot** instances
- bastion hosts, though SSM has largely replaced them

Pricing models: On-Demand (per second, no commitment), Savings Plans / Reserved (1–3 year
commitment, big discount), Spot (up to ~90% off, can be reclaimed with a 2-minute warning).
