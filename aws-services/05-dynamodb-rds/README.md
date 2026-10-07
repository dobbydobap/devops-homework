# DynamoDB and RDS — Database Services

Two very different databases for different jobs. DynamoDB is AWS's serverless NoSQL key-value
store; RDS runs a traditional relational database for you.

---

## DynamoDB

### NoSQL

DynamoDB is a key-value and document database. There is no fixed schema (apart from the key), no
joins, and no SQL queries over arbitrary columns. In return you get single-digit-millisecond reads
and writes at any scale, with nothing to provision or patch — it's fully serverless.

You design the table around the queries you'll run, not around normalised entities.

### Tables

A table is a collection of items. You create it with only its **primary key** defined, and choose a
capacity mode:

- **On-demand** — pay per request, scales instantly, no planning (good default)
- **Provisioned** — set read/write capacity units (optionally with auto scaling), cheaper for
  steady load

```bash
aws dynamodb create-table --table-name Tasks \
  --attribute-definitions AttributeName=user_id,AttributeType=S AttributeName=created_at,AttributeType=S \
  --key-schema AttributeName=user_id,KeyType=HASH AttributeName=created_at,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
```

### Items

An item is one record, like a row — up to 400 KB. Different items in the same table can have
completely different attributes.

```json
{
  "user_id": "varshitha",
  "created_at": "2026-10-07T21:30:00Z",
  "title": "Provision VPC with Terraform",
  "status": "DONE",
  "tags": ["terraform", "aws"]
}
```

### Attributes

The fields of an item. Types include String, Number, Binary, Boolean, Null, List, Map and Set. Only
the key attributes are required; everything else is optional per item.

### Partition key

The required part of the primary key. DynamoDB hashes it to decide which internal partition stores
the item. A good partition key has **many distinct values with evenly spread traffic** (`user_id`,
`order_id`). A bad one (`status`, which has three values) creates a "hot partition" that throttles.

If the table has only a partition key, it must be unique per item.

### Sort key

The optional second part of the primary key. Items with the same partition key are stored together,
**sorted** by the sort key. This enables range queries within one partition:

```
partition key = user_id, sort key = created_at
→ "all of varshitha's tasks from October, newest first"
```

With a sort key, the *combination* of partition and sort key must be unique.

For other access patterns you add **Global Secondary Indexes** (a different partition/sort key) or
**Local Secondary Indexes** (same partition key, different sort key).

### Use cases

- user sessions, shopping carts, user profiles
- gaming leaderboards and player state
- IoT and time-series events at high write volume
- serverless backends with Lambda
- the **lock table for Terraform's S3 remote state**
- anything needing predictable low latency at huge scale with simple access patterns

---

## RDS — Relational Database Service

### Relational database

RDS runs a real SQL database for you — tables with fixed schemas, relationships, joins, foreign keys
and ACID transactions. AWS handles provisioning, patching, backups and failover; you still design
the schema and tune queries.

### Supported engines

| Engine | Notes |
|---|---|
| PostgreSQL | the one my TaskBoard app uses |
| MySQL | |
| MariaDB | |
| Oracle | bring your own licence, or licence included |
| SQL Server | |
| Db2 | IBM |
| **Aurora** (MySQL / PostgreSQL compatible) | AWS's own engine: storage auto-grows to 128 TB, 6 copies across 3 AZs, faster failover; Aurora Serverless v2 scales capacity automatically |

### DB instances

The database server, sized by an instance class like `db.t4g.micro` (free tier) or `db.r7g.large`,
with attached storage (gp3 or io2) that can auto-scale. You connect through an **endpoint** (a DNS
name), never an IP, because the IP changes on failover.

Unlike EC2, you get no OS or SSH access — only the database port.

### Security

- run in **private subnets**, with **Public access = No**
- a security group allowing the DB port (5432 for Postgres) only from the app servers' security group
- **encryption at rest** with KMS (must be chosen at creation time), and TLS in transit
- master password stored in **Secrets Manager** with automatic rotation, never in code
- **IAM database authentication** as an alternative to passwords
- a DB subnet group spanning at least two AZs

### Backups

- **Automated backups**: daily snapshot plus transaction logs, retained 1–35 days, enabling
  **point-in-time recovery** to any second within that window
- **Manual snapshots**: kept until you delete them, can be copied to other regions or accounts
- restoring always creates a **new** DB instance with a new endpoint — it never overwrites the
  existing one

### Multi-AZ

A **standby** copy in a second AZ, kept in sync with **synchronous** replication. If the primary
fails (or during maintenance), RDS fails over automatically in about 60–120 seconds and the endpoint
DNS switches to the standby.

It's for **high availability**, not performance: the classic standby serves no traffic. (The newer
Multi-AZ *DB cluster* option has two readable standbys.)

### Read replicas

**Asynchronous** copies used to scale **reads** — reporting, analytics and read-heavy pages go to the
replica endpoint while writes go to the primary.

- up to 15 replicas (Aurora), in the same or other regions
- slightly behind the primary (replication lag), so they're not for reads that must see the
  latest write
- can be promoted to a standalone database, e.g. for disaster recovery

| | Multi-AZ | Read replica |
|---|---|---|
| Purpose | availability / failover | read scaling |
| Replication | synchronous | asynchronous |
| Serves traffic | no (classic standby) | yes, reads |
| Failover | automatic | manual promotion |

### Use cases

- web application backends needing transactions and relational data (like TaskBoard on PostgreSQL)
- e-commerce orders, payments, inventory — anything needing ACID guarantees
- CRM, ERP and other line-of-business systems
- reporting with complex joins and aggregations
- lifting an existing on-premises MySQL/Postgres/SQL Server database into AWS

---

## Choosing between them

| | DynamoDB | RDS |
|---|---|---|
| Model | key-value / document | relational tables |
| Schema | flexible | fixed |
| Queries | by key and indexes | full SQL with joins |
| Scaling | automatic, effectively unlimited | vertical, plus read replicas |
| Management | serverless | instances you size and pay for while running |
| Best for | known access patterns at massive scale | complex queries, relationships, transactions |
