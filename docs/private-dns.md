# Private DNS

Terraform creates one Route 53 private hosted zone and associates it with the
application VPC. The default namespace is:

```text
aws.logicmatrix.tech
```

Override it when necessary:

```hcl
private_hosted_zone_name = "internal.example.com"
```

The zone is resolvable only by resources using the associated VPC DNS resolver,
including ECS tasks, EC2 instances, and clients whose DNS queries are forwarded
through an appropriate private-network resolver. It is not published to the
internet.

Cloudflare remains authoritative for public website domains. Do not change the
public domain's Cloudflare nameservers or create a public Route 53 hosted zone
for this configuration.

Terraform creates this private database record:

```text
postgres.aws.logicmatrix.tech -> AWS-generated RDS endpoint
```

The record is a CNAME with a 60-second TTL. Terraform exports the private name
as `database_address` and retains the AWS endpoint as `database_rds_address` for
troubleshooting.

Read the created zone metadata with:

```bash
terraform output -raw private_hosted_zone_id
terraform output -raw private_hosted_zone_name
terraform output -raw database_address
terraform output -raw database_rds_address
```
