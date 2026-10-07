# IAM — Identity and Access Management (Governance)

## What is IAM?

IAM decides **who** can do **what** to **which** AWS resources. Every API call to AWS — from the
console, the CLI, Terraform or an application — is checked against IAM before it runs. IAM is
global (not tied to a region) and free.

The root user (the email you signed up with) can do everything and can't be restricted, so it
should only be used for the few tasks that require it. Day-to-day work happens through IAM
identities.

## Users

A user is one identity for one person or one application, with long-term credentials: a console
password, and/or access keys (an access key ID plus secret) for the CLI and SDKs.

```bash
aws iam create-user --user-name varshitha
aws iam create-access-key --user-name varshitha
```

Long-lived access keys are the most common way AWS accounts get compromised (keys committed to
Git, pasted in chats). Prefer temporary credentials — `aws login`, IAM Identity Center, or roles.

## Groups

A group is a collection of users that share permissions. You attach policies to the group, not to
each user, so adding someone to `developers` gives them exactly what developers get.

Groups can't contain other groups, and a group is not an identity — you can't sign in as one.

## Roles

A role is an identity with permissions but **no long-term credentials**. Something *assumes* the
role and gets temporary credentials (valid for minutes to hours) from STS.

Who assumes roles:

- an **EC2 instance** (through an instance profile), so the app on it can read S3 without any keys
  stored on the server
- a **Lambda function** or an **EKS pod** (IRSA / Pod Identity)
- **another AWS account** (cross-account access)
- a **GitHub Actions** workflow via OIDC — the pipeline gets short-lived credentials and no AWS
  secret is stored in GitHub at all

A role has two policies: the **trust policy** (who may assume it) and the **permissions policy**
(what it can do once assumed).

## Policies

A policy is a JSON document listing permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::varshitha-devops-s18-10271/*"
    }
  ]
}
```

| Type | What it is |
|---|---|
| AWS managed | written by AWS, e.g. `AmazonS3ReadOnlyAccess` |
| Customer managed | written by you, reusable across identities |
| Inline | embedded in one user/group/role only |
| Resource-based | attached to the resource itself, e.g. an S3 bucket policy |

## Permissions — how a request is evaluated

1. Everything starts as **implicitly denied**.
2. An **Allow** in any applicable policy grants it…
3. …unless there is an **explicit Deny** anywhere, which always wins.

On top of identity policies there can be permission boundaries, Service Control Policies (in AWS
Organizations) and session policies — each one can only *narrow* access, never widen it.

## Least privilege

Give each identity only the permissions it needs, on only the resources it needs, and nothing
more. In practice:

- start from nothing and add, rather than starting from `AdministratorAccess` and removing
- scope `Resource` to specific ARNs instead of `"*"`
- use **IAM Access Analyzer** to generate a policy from what an identity actually used
- review and remove unused permissions and users regularly

## IAM best practices

- Lock the root user away: MFA on, no access keys, use it only for root-only tasks
- **MFA** for every human user
- Prefer **roles and temporary credentials** over long-lived access keys
- If keys are unavoidable, rotate them and never commit them (gitleaks in session 17 catches this)
- Use **groups** for human permissions, not per-user policies
- Use **IAM Identity Center** (SSO) for people across multiple accounts
- Turn on **CloudTrail** so every API call is logged and auditable

## Common use cases

| Need | IAM answer |
|---|---|
| A new team member needs console access | IAM user (or Identity Center user) added to a group |
| An app on EC2 must read from S3 | IAM role attached to the instance |
| A CI/CD pipeline deploys to AWS | role assumed through GitHub OIDC — no stored keys |
| Another AWS account needs read access | cross-account role with a trust policy |
| Make a bucket readable by one service | bucket policy (resource-based) |
| Running Terraform locally | `aws login` or SSO for temporary credentials |
