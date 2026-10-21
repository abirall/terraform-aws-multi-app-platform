# PostgreSQL RDS Deployment

Terraform provisions a private Amazon RDS for PostgreSQL instance using
`db.t4g.micro`.

## Network placement

The database tier uses two dedicated private subnets in different Availability
Zones. These subnets use a dedicated route table with only the VPC-local route:

```text
VPC
├── public subnets (2 AZs): ALB and NAT gateway
├── private application subnet: ECS instances and task ENIs
└── isolated database subnets (2 AZs): RDS subnet group
```

The database has no public IP and no Internet Gateway or NAT route. RDS requires
a DB subnet group covering at least two Availability Zones even when the database
instance itself is Single-AZ.

## Access control

The PostgreSQL security group accepts TCP port `5432` only from the security
groups attached to the existing `lgm-web` ECS task ENIs and the private NetBird
routing peer. It does not allow access from the internet, the ALB, or arbitrary
resources in the VPC.

When another ECS service needs database access, add another
`aws_vpc_security_group_ingress_rule` referencing that service's task security
group. Do not open PostgreSQL to `0.0.0.0/0`.

## Defaults

| Setting | Default |
|---|---|
| Engine | PostgreSQL 16 |
| Instance class | `db.t4g.micro` |
| Storage | 20 GiB encrypted GP3 |
| Storage autoscaling maximum | 100 GiB |
| Automated backup retention | 7 days |
| Public access | Disabled |
| Multi-AZ | Disabled |
| Deletion protection | Enabled |
| Final snapshot on deletion | Enabled |
| PostgreSQL/upgrade log export | Enabled |

Set `db_multi_az = true` when production availability requires an automatically
maintained synchronous standby. This increases cost.

## Required configuration

Set a strong master password through a protected variable source:

```hcl
db_name     = "lgm"
db_username = "postgres"
db_password = "<strong-secret>"
```

The password is sensitive in Terraform output, but it is still stored in
Terraform state because RDS receives it as a resource argument. Protect access to
the S3 state bucket and never commit `terraform.tfvars`.

## Deploy

Review the database changes before applying:

```bash
terraform plan
terraform apply
```

RDS creation can take several minutes. Read the connection metadata afterward.
The primary address is the stable Route 53 private name
`postgres.aws.logicmatrix.tech`:

```bash
terraform output -raw database_address
terraform output -raw database_port
terraform output -raw database_name
```

The underlying AWS-generated endpoint remains available when troubleshooting:

```bash
terraform output -raw database_rds_address
```

The application connection format is:

```text
postgresql://<username>:<password>@<database_address>:5432/<database_name>?sslmode=require
```

Pass the finished connection string to ECS through a secure secret store such as
AWS Systems Manager Parameter Store or AWS Secrets Manager. Do not place the
password directly in `container_environment`.

## Connecting for administration

The endpoint is private, so a workstation on the public internet cannot connect
directly. Use the Terraform-managed NetBird routing peer described in the
[NetBird routing-peer guide](netbird-routing-peer.md). SSM Session Manager remains
available as a recovery path and requires no inbound security-group rule.

## Destruction and snapshots

Deletion protection is enabled by default. Intentional deletion requires two
separate changes:

1. Set `db_deletion_protection = false` and apply.
2. Destroy the database in a later operation.

By default, RDS creates a final snapshot named
`<project>-<environment>-postgres-final`. If a snapshot with that name already
exists, choose a new identifier in code or remove/rename the old snapshot before
destroying. Set `db_skip_final_snapshot = true` only when data loss is explicitly
acceptable.
