# S3 — Simple Storage Service (Storage)

## What is S3?

Object storage: you store files ("objects") in containers ("buckets") and fetch them over HTTP. No
servers or disks to manage, it scales without limit, and it's designed for 99.999999999% (11 nines)
durability by keeping copies across multiple Availability Zones.

It is not a filesystem — no real folders, and you can't edit part of a file; you replace the whole
object. That's what makes it so durable and cheap.

The Terraform for my bucket is in [../../terraform-s3-demo/](../../terraform-s3-demo/).

## Buckets

- a bucket name is **globally unique across every AWS account**, which is why the course example's
  hard-coded `yatri1107` couldn't work for everyone and I used my own name
- a bucket lives in **one region**
- 3–63 characters: lowercase letters, numbers, dots and hyphens
- blocked from public access by default (Block Public Access is on)

## Objects

An object is the data plus metadata, addressed by a **key**:

```
s3://varshitha-devops-s18-10271/reports/2026/october.csv
     \______ bucket ________/  \__________ key _________/
```

The `reports/2026/` part only looks like folders — it's just part of the key string, and the
console displays `/` as folders for convenience. A single object can be up to 5 TB; anything over
100 MB should be sent with multipart upload.

## Storage classes

Trade retrieval speed for a lower storage price:

| Class | For | Retrieval |
|---|---|---|
| Standard | frequently accessed data | instant |
| Intelligent-Tiering | unknown or changing access patterns; moves objects automatically | instant |
| Standard-IA | infrequent access, still needs to be fast | instant, per-GB retrieval fee |
| One Zone-IA | re-creatable infrequent data, one AZ only | instant |
| Glacier Instant Retrieval | archives read about once a quarter | instant |
| Glacier Flexible Retrieval | archives | minutes to hours |
| Glacier Deep Archive | long-term compliance records | up to 12–48 hours, cheapest |

## Versioning

With versioning on, every overwrite or delete **keeps the old version**:

- an overwrite creates a new version ID
- a delete adds a *delete marker* instead of erasing the data, so it can be undone
- it protects against accidental deletes and ransomware-style overwrites
- once enabled it can only be *suspended*, never fully turned off

I enabled it on my bucket with `aws_s3_bucket_versioning`. Old versions are billed as storage, so
versioning is usually paired with a lifecycle rule.

## Lifecycle policies

Rules that move or delete objects automatically based on age:

```json
{
  "Rules": [{
    "ID": "archive-logs",
    "Filter": {"Prefix": "logs/"},
    "Status": "Enabled",
    "Transitions": [
      {"Days": 30, "StorageClass": "STANDARD_IA"},
      {"Days": 90, "StorageClass": "GLACIER"}
    ],
    "Expiration": {"Days": 365},
    "NoncurrentVersionExpiration": {"NoncurrentDays": 30}
  }]
}
```

Logs move to cheaper storage as they age, are deleted after a year, and old versions are cleaned up
after 30 days.

## Encryption

- **At rest**: since 2023 every new object is encrypted by default with **SSE-S3** (AES-256, keys
  managed by S3). I set it explicitly in my Terraform anyway.
- **SSE-KMS**: keys in AWS KMS — you control who can use the key, and every use is logged in
  CloudTrail.
- **DSSE-KMS**: two layers of KMS encryption, for strict compliance.
- **SSE-C / client-side**: you hold the keys yourself.
- **In transit**: HTTPS. A bucket policy can deny any request with `aws:SecureTransport = false`.

## Bucket policies

A resource-based IAM policy attached to the bucket — it decides who can access it, including other
accounts or services:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyInsecureTransport",
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": [
      "arn:aws:s3:::varshitha-devops-s18-10271",
      "arn:aws:s3:::varshitha-devops-s18-10271/*"
    ],
    "Condition": {"Bool": {"aws:SecureTransport": "false"}}
  }]
}
```

**Block Public Access** sits above bucket policies and ACLs and overrides them. I turned on all
four settings with `aws_s3_bucket_public_access_block`, so even a mistaken policy can't expose the
bucket.

## Common use cases

- static website hosting (often with CloudFront in front)
- backups and disaster recovery, with cross-region replication
- data lakes queried with Athena, Glue or Redshift Spectrum
- application file uploads (images, documents) via pre-signed URLs
- log storage (CloudTrail, ALB access logs)
- **Terraform remote state** — the state file in S3 with locking, so a team shares one state
- artifact storage for CI/CD pipelines
