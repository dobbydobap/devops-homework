# VPC — Virtual Private Cloud (Networking)

## What is VPC?

A VPC is your own private, isolated network inside AWS. You choose its IP range, split it into
subnets, and decide what can reach the internet and what can reach what. Every EC2 instance, RDS
database or EKS node runs inside a VPC.

A VPC lives in one **region** and spans all of its **Availability Zones**. Each region comes with a
default VPC, but real workloads use their own. My Terraform for one is in
[../../terraform-cloud-infra/](../../terraform-cloud-infra/).

## CIDR

The VPC's IP range, written in CIDR notation, e.g. `10.20.0.0/16`:

- `/16` means the first 16 bits are the network part and the remaining 16 are for hosts
- 2^16 = **65,536** addresses
- use private ranges (RFC 1918): `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
- a VPC can be between `/16` and `/28`
- **don't overlap** with other VPCs or your office network if you'll ever connect them

| CIDR | Addresses |
|---|---|
| /16 | 65,536 |
| /20 | 4,096 |
| /24 | 256 |
| /28 | 16 |

## Subnets

A subnet is a slice of the VPC's CIDR, living in **exactly one Availability Zone**:

```
VPC 10.20.0.0/16
├── 10.20.1.0/24   public subnet,  ap-south-1a
├── 10.20.2.0/24   public subnet,  ap-south-1b
├── 10.20.11.0/24  private subnet, ap-south-1a
└── 10.20.12.0/24  private subnet, ap-south-1b
```

AWS reserves 5 addresses in every subnet (network, VPC router, DNS, future use, broadcast), so a
`/24` gives 251 usable IPs, not 256. For high availability, run things in at least two AZs.

## Route tables

Each subnet is associated with one route table, which decides where its traffic goes:

| Destination | Target | Meaning |
|---|---|---|
| 10.20.0.0/16 | local | traffic inside the VPC (always present, can't be removed) |
| 0.0.0.0/0 | igw-xxxx | everything else goes to the internet |

The most specific match wins, so VPC-internal traffic always stays local.

## Internet Gateway

The VPC's two-way door to the internet — horizontally scaled, highly available, and free. An
instance can be reached from the internet only if **all** of these are true:

1. the VPC has an Internet Gateway attached
2. the subnet's route table sends `0.0.0.0/0` to it
3. the instance has a public IP
4. the security group (and NACL) allow the traffic

Miss any one and it isn't reachable — that's usually the first checklist when "the EC2 instance
won't load in the browser".

## NAT Gateway

Lets instances in **private** subnets make outbound connections (OS updates, calling APIs) without
being reachable from the internet. It sits in a public subnet with an Elastic IP, and the private
route table sends `0.0.0.0/0` to it.

The catch is cost: about **$0.045–0.056 per hour plus a per-GB charge**, even when idle. That's why
my session 19 project uses only a public subnet — a NAT Gateway left running is the classic
surprise on a student's AWS bill. Cheaper alternatives: VPC endpoints for S3/DynamoDB, or a NAT
instance.

## Security Groups

A stateful firewall on each network interface — allow rules only, return traffic is allowed
automatically. Covered in detail in the [EC2 notes](../02-ec2/).

## Network ACLs

A stateless firewall at the **subnet** level:

| | Security Group | Network ACL |
|---|---|---|
| Applies to | instance / network interface | whole subnet |
| Rules | allow only | allow **and** deny |
| State | stateful (replies allowed automatically) | stateless (replies need their own rule) |
| Evaluation | all rules together | in number order, first match wins |
| Default | deny in, allow out | default NACL allows everything |

NACLs are useful for a blanket block, e.g. denying a known bad IP range for a whole subnet. Day to
day, most filtering is done with security groups.

## Public vs private subnet

There's no "public" checkbox — a subnet is public **because of its route table**:

| | Public subnet | Private subnet |
|---|---|---|
| Route `0.0.0.0/0` to | Internet Gateway | NAT Gateway (or nowhere) |
| Instances get public IPs | usually yes | no |
| Reachable from internet | yes, if the SG allows | no |
| Typical contents | load balancers, bastion, NAT gateway | app servers, databases, EKS nodes |

A standard production layout: an Application Load Balancer in public subnets, app servers in
private subnets, and the database in a further-isolated private subnet with no internet route at
all.

Other pieces worth knowing: VPC Peering and Transit Gateway (connect VPCs), VPC Endpoints (reach AWS
services without leaving the AWS network), and Flow Logs (record traffic for troubleshooting).
