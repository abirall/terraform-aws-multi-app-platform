# NetBird Database Routing Peer

Terraform provisions one private Ubuntu Server 26.04 LTS ARM64 EC2 instance
using a launch template. During planning, Terraform searches EC2 for the newest
matching AMI published by Canonical's verified AWS account `099720109477`. The
default instance type is `t4g.nano`. It has no public IP, no inbound
security-group rules, an encrypted GP3 root volume, and IMDSv2 is required. EC2
source/destination checking is disabled so the instance can forward NetBird
traffic to private VPC resources.

NetBird supplies encrypted workstation-to-VPC connectivity. AWS Systems Manager
Session Manager is installed and enabled as a recovery path. PostgreSQL accepts
port `5432` from the routing-peer security group; it is never exposed publicly.

## Traffic path

```text
Database administrator
  -> NetBird client
  -> encrypted NetBird peer connection
  -> private EC2 routing peer (t4g.nano)
  -> RDS private DNS name:5432
```

The instance is in the application private subnet and uses the NAT gateway for
NetBird coordination, package installation, and AWS API access. The RDS endpoint
remains in the isolated database subnets.

## 1. Create the NetBird setup key

In the NetBird dashboard:

1. Create a peer group such as `aws-database-routing-peers`.
2. Open **Setup Keys** and create a reusable key that automatically assigns the
   new peer to that group.
3. Restrict the key to the routing-peer group and choose an appropriate expiry.

The ASG needs a reusable key because every recovered EC2 instance registers as
a new NetBird peer. Remove stale peers from the NetBird dashboard after an ASG
replacement.

## 2. Configure Terraform

Add the reusable setup key to the protected, ignored `terraform.tfvars` file:

```hcl
netbird_routing_peer_setup_key = "<REUSABLE_NETBIRD_SETUP_KEY>"
```

You can instead set `TF_VAR_netbird_routing_peer_setup_key` in your deployment
environment. Terraform writes the value to an encrypted SSM SecureString using
the provider's write-only argument, so the value is not included in launch-template
user data or new Terraform state snapshots. Increment
`netbird_routing_peer_setup_key_version` whenever the key is rotated.
The version marker is also included in launch-template user data so incrementing
it triggers an ASG instance refresh that enrolls with the new key.

Keep `netbird_routing_peer_instance_type = "t4g.nano"` unless the routing
workload requires more CPU or memory.

## 3. Deploy and verify bootstrap

```bash
terraform plan
terraform apply
terraform output -raw netbird_routing_peer_instance_id
terraform output -raw netbird_routing_peer_ami_id
terraform output -raw netbird_routing_peer_ami_name
```

The launch-template cloud-config sets the hostname to
`<project>-<environment>-netbird-routing-peer`, installs NetBird, and runs
`netbird up --setup-key ... --allow-server-ssh` using the reusable key retrieved
from SSM Parameter Store.
NetBird uses the machine hostname as the peer name during registration.

NetBird SSH is enabled on the peer, but access also requires SSH Access to be
enabled in the NetBird dashboard and an access policy permitting the intended
administrator group. No public IP, AWS inbound rule, or port `22` rule is
created.

Cloud-config also creates 1 GiB of swap, enables Linux IPv4/IPv6 forwarding,
and runs a DNS forwarder on port `5353` of the NetBird `wt0` interface. Port 53
is reserved by NetBird's own DNS listener. The forwarder sends queries from
NetBird peers to the local AWS Route 53 VPC Resolver and is not exposed on the
instance's VPC interface or to the public internet.

Confirm that the peer is online in the NetBird dashboard. For AWS-side recovery
or bootstrap inspection, start an SSM session:

```bash
aws ssm start-session \
  --region us-east-1 \
  --target "$(terraform output -raw netbird_routing_peer_instance_id)"
```

On the instance, useful checks are:

```bash
sudo netbird status
sudo systemctl status netbird
sudo tail -n 200 /var/log/cloud-init-output.log
```

## 4. Publish the VPC network in NetBird

Read the VPC CIDR:

```bash
terraform output -raw netbird_routed_vpc_cidr
```

In the NetBird dashboard:

1. Create a Network such as `logicmatrix-prod-vpc`.
2. Add the `netbird_routed_vpc_cidr` output as an IP-range resource. The default
   is `10.0.0.0/16`.
3. Select `aws-database-routing-peers` as the routing-peer group.
4. Keep masquerading enabled. VPC destinations will see the EC2 peer's private
   IP, so no return route to the NetBird address range is required.
5. Create a Network access policy granting only approved NetBird groups access
   to the required VPC protocols and ports.

This advertises the full VPC route, but AWS security groups still decide whether
each destination accepts the connection. Add narrowly scoped ingress rules for
the routing peer where required; do not open every VPC resource globally.

Because AWS does not preserve security-group references through forwarded
middlebox traffic, the RDS rule allows port `5432` from the routing peer's exact
private `/32` address. Terraform updates that rule if the peer is replaced and
receives a different private IP.

## 5. Configure private DNS in NetBird

Find the routing peer's NetBird IP in **Peers** in the NetBird dashboard. Create
a NetBird nameserver configuration with:

- Nameserver: the routing peer's NetBird `100.x.x.x` address
- Type: UDP
- Port: `5353`
- Match domain: Terraform `netbird_private_dns_match_domain` output
- Distribution groups: only groups that need AWS private DNS

Also create an access policy allowing those groups to reach the routing peer on
UDP and TCP port `53`. The DNS forwarder queries AWS locally, allowing names such
as `postgres.aws.logicmatrix.tech` to resolve without a Route 53 Resolver inbound
endpoint.

Check the configured match domain with:

```bash
terraform output -raw netbird_private_dns_match_domain
```

## 6. Publish the private database resource in NetBird

After RDS exists, get its stable Route 53 private hostname:

```bash
terraform output -raw database_address
```

If you want a database-specific policy in addition to the full VPC Network,
create a separate Network for AWS database administration:

1. Add a domain resource whose domain is exactly the `database_address` output.
2. Select `aws-database-routing-peers` as the routing-peer group.
3. Enable routing-peer DNS resolution for the domain resource.
4. Keep masquerading enabled so RDS sees the connection as coming from the
   routing peer, which matches the AWS security-group rule.
5. Create an access policy granting only the administrator peer group access to
   this database resource on TCP port `5432`.

When a full-VPC IP-range resource and a domain resource overlap, keep their
access policies aligned. Otherwise the broader CIDR policy can make the database
reachable even when its domain-specific policy is more restrictive.

## 7. Connect from a workstation

Install the NetBird client, sign in to the same NetBird account, and make sure
the workstation belongs to the administrator group allowed by the route policy.
Then connect with the RDS hostname:

```bash
psql "host=$(terraform output -raw database_address) port=5432 dbname=$(terraform output -raw database_name) user=postgres sslmode=require"
```

NetBird provides network reachability, not database credentials. Retrieve the
PostgreSQL password from its approved secret store.

## Replacement and key rotation

Changing the launch template may replace or restart the routing peer. The
reusable setup key allows the ASG replacement to register automatically. After
a new peer is online:

1. Remove the stale peer from NetBird.
2. Rotate the setup key when required.
3. Increment `netbird_routing_peer_setup_key_version` when supplying its new value.

No SSH key or inbound port `22` is provisioned. Do not add public ingress merely
for troubleshooting; use SSM Session Manager.
