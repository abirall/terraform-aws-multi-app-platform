# Manual Cloudflare Setup for the Shared AWS ALB

This guide explains how to configure Cloudflare manually for the AWS
infrastructure in this repository. Terraform does not create or modify any
Cloudflare resources.

The intended request path is:

```text
Visitor
  -> Cloudflare edge HTTPS
  -> Cloudflare-to-origin HTTPS
  -> shared AWS Application Load Balancer
  -> host-header listener rule
  -> service-specific IP target group
  -> ECS task private IP
```

## Ownership boundary

Terraform manages:

- The AWS ACM certificate request and validation wait.
- The shared HTTPS ALB and its listener.
- One IP target group per entry in `service_routes`.
- Host-header rules that map domains to target groups.
- The existing `lgm-web` ECS service and its target-group registration.

Cloudflare is managed manually:

- Zone onboarding and authoritative nameservers.
- ACM validation CNAME records.
- Proxied application CNAME records pointing to the ALB.
- Edge certificate and SSL/TLS settings.
- Optional WAF, rate limiting, redirects, and caching rules.

Do not add Cloudflare credentials to this repository or `terraform.tfvars`.

## Prerequisites

Before deploying:

1. Add every apex domain, such as `logicmatrix.tech` and `mohsinrubel.com`, as a
   separate Cloudflare zone.
2. At each registrar, replace the authoritative nameservers with the two
   nameservers assigned by Cloudflare.
3. Wait until each Cloudflare zone reports **Active**.
4. Confirm that AWS credentials and the Terraform variables are available.
5. Decide which complete hostnames route to each ECS service.

Cloudflare's full-zone setup requires the registrar to delegate the domain to
Cloudflare's assigned nameservers. See [Cloudflare's full setup
guide](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/).

## 1. Define the service-to-domain routes

Set `service_routes` in the ignored `terraform.tfvars` file. Each map key is a
logical ECS service name and produces one dedicated ALB target group.

```hcl
service_routes = {
  logicmatrix = {
    domains = [
      "logicmatrix.tech",
      "www.logicmatrix.tech",
    ]
    target_group_port = 3000
    health_check_path = "/"
  }

  mohsinrubel = {
    domains = [
      "mohsinrubel.com",
      "www.mohsinrubel.com",
    ]
    target_group_port = 3000
    health_check_path = "/"
  }
}
```

Rules:

- Enter complete hostnames only—no `https://`, paths, or trailing slash.
- Add `www` explicitly if it should work in addition to the apex domain.
- Assign each hostname to exactly one service.
- Make the target-group port match the ECS container port for that service.
- Make the health-check path return HTTP `200` without authentication.
- Keep service keys lowercase and use only letters, digits, and hyphens.

The currently declared `lgm-web` ECS service uses the route selected by:

```hcl
lgm_service_route = "lgm-web"
```

If its route key is renamed, update `lgm_service_route` as well. Defining a route
creates the target group and listener rules; it does not create a new ECS service.
Each additional ECS service must register with its matching output:

```hcl
module.alb.target_group_arns["mohsinrubel"]
```

## 2. Request the multi-domain ACM certificate

ACM must generate its DNS challenges before those records can be entered into
Cloudflare. Run a targeted first apply:

```bash
terraform init
terraform apply -target=module.acm.aws_acm_certificate.wildcard
terraform output -json acm_domain_validation_records
```

The output contains one or more records shaped like this:

```json
{
  "logicmatrix.tech": {
    "name": "_token.logicmatrix.tech.",
    "type": "CNAME",
    "value": "_value.acm-validations.aws."
  }
}
```

ACM may reuse the same validation record for related certificate names. Create
each distinct record shown by the output.

## 3. Add ACM validation records to Cloudflare

For each validation record:

1. Open the correct Cloudflare zone.
2. Go to **DNS → Records**.
3. Select **Add record**.
4. Set **Type** to `CNAME`.
5. Copy the Terraform `name` into **Name**.
6. Copy the Terraform `value` into **Target**.
7. Set **Proxy status** to **DNS only** (gray cloud).
8. Set **TTL** to **Auto**.
9. Save the record.

Important details:

- Validation records prove ownership; they must never be proxied.
- Cloudflare may display the name without the zone suffix after saving. This is
  normal if the final fully qualified name is correct.
- Do not accidentally create a doubled name such as
  `_token.example.com.example.com`.
- Leave validation CNAMEs in place permanently. ACM needs them for automatic
  renewal while the certificate is in use.
- If CNAME verification fails, ensure account-level flattening is not being
  applied to validation records. Cloudflare documents this in [CNAME domain
  verification troubleshooting](https://developers.cloudflare.com/dns/manage-dns-records/troubleshooting/cname-domain-verification/).

Verify each challenge from a terminal:

```bash
dig +short CNAME _token.example.com
```

The answer must resolve to the corresponding `acm-validations.aws` value.

AWS documents the validation and renewal behavior in [ACM DNS
validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)
and [ACM DNS renewal](https://docs.aws.amazon.com/acm/latest/userguide/dns-renewal-validation.html).

## 4. Complete the Terraform deployment

Once the validation CNAMEs resolve publicly, run:

```bash
terraform apply
```

Terraform waits for the certificate to become `ISSUED`, then creates or updates
the HTTPS listener. Retrieve the shared ALB hostname and routing outputs:

```bash
terraform output -raw alb_dns_name
terraform output -json target_group_arns
terraform output -json website_domains
```

Example ALB hostname:

```text
logicmatrix-alb-123456789.us-east-1.elb.amazonaws.com
```

Do not copy an ALB IP address into DNS. ALB addresses can change; always use the
DNS hostname.

## 5. Create the proxied application records

Create a CNAME for every domain listed under `service_routes`. All records point
to the same `alb_dns_name`; the ALB decides the service from the original Host
header.

Example for the `logicmatrix.tech` zone:

| Type | Name | Target | Proxy status | TTL |
|---|---|---|---|---|
| CNAME | `@` | Terraform `alb_dns_name` | Proxied | Auto |
| CNAME | `www` | Terraform `alb_dns_name` | Proxied | Auto |

Example for the `mohsinrubel.com` zone:

| Type | Name | Target | Proxy status | TTL |
|---|---|---|---|---|
| CNAME | `@` | Terraform `alb_dns_name` | Proxied | Auto |
| CNAME | `www` | Terraform `alb_dns_name` | Proxied | Auto |

For a hostname such as `app.example.com`, use `app` as the Cloudflare record
name. Cloudflare supports apex CNAMEs through [CNAME
flattening](https://developers.cloudflare.com/dns/cname-flattening/).

Application records must be **Proxied** (orange cloud). Proxied records send
HTTP/HTTPS traffic through Cloudflare; DNS-only records send clients directly to
the AWS origin. See [Cloudflare proxy
status](https://developers.cloudflare.com/dns/proxy-status/).

## 6. Enable end-to-end HTTPS

Repeat these settings for every Cloudflare zone.

### SSL/TLS encryption mode

1. Open **SSL/TLS → Overview**.
2. Select **Full (strict)**.

Full (strict) encrypts both connections:

```text
Visitor -- HTTPS --> Cloudflare -- HTTPS --> AWS ALB
```

Cloudflare verifies that the ALB presents an unexpired, publicly trusted ACM
certificate containing the requested hostname. Do not use **Flexible** mode.
Cloudflare's requirements are documented under [Full
(strict)](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/).

### Redirect visitors to HTTPS

1. Open **SSL/TLS → Edge Certificates**.
2. Enable **Always Use HTTPS**.

This performs the visitor-facing HTTP-to-HTTPS redirect at Cloudflare. Avoid
adding competing redirect logic unless the application has a specific need;
multiple redirect layers can create loops. See [Always Use
HTTPS](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/always-use-https/).

### Universal SSL

Leave Universal SSL enabled so Cloudflare can present an edge certificate to
visitors. Universal SSL is separate from the ACM certificate used by the ALB.

## 7. Verify routing and TLS

### Confirm Cloudflare proxying

```bash
dig +short logicmatrix.tech
dig +short mohsinrubel.com
```

Proxied records should return Cloudflare anycast addresses, not the ALB's current
addresses.

### Confirm visitor-facing HTTPS

```bash
curl -I https://logicmatrix.tech
curl -I https://mohsinrubel.com
```

Look for a successful application response and Cloudflare response headers such
as `server: cloudflare` and `cf-ray`.

### Confirm the ALB certificate directly

```bash
openssl s_client \
  -connect <alb-dns-name>:443 \
  -servername logicmatrix.tech \
  </dev/null
```

The certificate names must cover the supplied hostname.

### Confirm service separation

Verify that each domain returns content from its intended service. In AWS, check:

1. **EC2 → Target Groups**: each service target group has healthy task IPs.
2. **EC2 → Load Balancers → Listeners and rules**: each hostname forwards to the
   intended target group.
3. **ECS → Cluster → Service**: each service has the expected running tasks.

## 8. Adding a domain or service later

Use this sequence whenever certificate names change:

1. Add or edit the entry in `service_routes`.
2. If adding a service, implement its ECS task definition and ECS service and
   connect it to `module.alb.target_group_arns["<service-key>"]`.
3. Run the targeted ACM certificate apply.
4. Read `acm_domain_validation_records` again.
5. Add any new Cloudflare validation CNAMEs as DNS-only.
6. Wait for those records to resolve publicly.
7. Run the full `terraform apply`.
8. Add the new proxied application CNAME pointing to `alb_dns_name`.
9. Test HTTPS and confirm the intended target group is healthy.

Commands:

```bash
terraform apply -target=module.acm.aws_acm_certificate.wildcard
terraform output -json acm_domain_validation_records
terraform apply
```

The ACM resource uses `create_before_destroy`, so Terraform requests and
validates the replacement certificate before removing the old certificate.

## 9. Removing a domain or service

1. Remove the hostname or service from `service_routes`.
2. Run `terraform plan` and verify the listener rule and target-group changes.
3. Run `terraform apply`.
4. Remove the obsolete proxied application record from Cloudflare.
5. Remove an old ACM validation CNAME only when no active or renewable ACM
   certificate uses it.

Removing a target group affects live traffic. Confirm the corresponding ECS
service is no longer needed before applying the change.

## 10. Troubleshooting

### ACM remains `PENDING_VALIDATION`

Check that:

- The record is a CNAME in the authoritative Cloudflare zone.
- Proxy status is DNS only.
- The name was not duplicated with the zone suffix.
- The target matches the Terraform output exactly.
- CNAME flattening is not enabled for the validation record.
- CAA records do not prevent Amazon's certificate authority from issuing.
- Public DNS returns the record with `dig`.

ACM can take time to observe a correct record. AWS provides additional [DNS
validation troubleshooting](https://docs.aws.amazon.com/acm/latest/userguide/troubleshooting-DNS-validation.html).

### Cloudflare error 526

Cloudflare cannot validate the origin certificate in Full (strict) mode.

Check that:

- ACM shows the certificate as `ISSUED`.
- The ALB HTTPS listener uses the current ACM certificate.
- The requested hostname appears on the certificate.
- The certificate is not expired.

### Cloudflare error 525

The TLS handshake with the ALB failed. Check the HTTPS listener, certificate,
ALB security group, and TLS policy.

### Cloudflare errors 521 or 522

Cloudflare cannot reach the origin. Check that the ALB is internet-facing, its
public subnets have Internet Gateway routes, its security group permits HTTPS,
and the ALB is active.

### ALB returns 404

The request reached the ALB but did not match a host rule. Confirm that the exact
hostname exists in `service_routes`, apply Terraform, and inspect the listener
rules. The listener intentionally returns `404 Not Found` for unknown hosts.

### ALB or Cloudflare returns 502/503

The selected target group has no healthy targets or the application response is
invalid. Check:

- ECS desired and running task counts.
- Target health and health-check failure details.
- Container port versus `target_group_port`.
- Health-check path and expected HTTP `200` response.
- Task security-group ingress from the ALB security group.
- Application startup and CloudWatch logs.

### Redirect loop

Use Cloudflare Full (strict), not Flexible. Confirm the application respects
`X-Forwarded-Proto: https` and does not repeatedly redirect an already-secure
request.

### Wrong service responds

Check for duplicate or incorrect hostnames in `service_routes`, then inspect the
ALB listener rule for that Host header. A hostname must map to only one service.

## 11. Security and operations recommendations

- Keep application DNS records proxied and validation records DNS-only.
- Preserve ACM validation CNAMEs for automatic renewal.
- Review Cloudflare WAF managed rules and rate limits before production launch.
- Avoid caching authenticated HTML or API responses unless a carefully scoped
  Cache Rule makes it safe.
- Set alerts for Cloudflare origin errors, ALB 5xx responses, unhealthy target
  counts, and ACM renewal events.
- Treat the ALB hostname as public. Proxying DNS hides it from normal DNS lookups,
  but does not itself prevent direct origin access.

The current ALB security group permits public HTTPS. A recommended future AWS
hardening step is to manage Cloudflare's published origin IP ranges in Terraform
and allow port 443 only from those ranges. Cloudflare recommends allowlisting its
origin-facing addresses and blocking other sources; the ranges can change, so
this needs an update process. See [Cloudflare IP
addresses](https://developers.cloudflare.com/fundamentals/concepts/cloudflare-ip-addresses/)
and [Protect your origin
server](https://developers.cloudflare.com/fundamentals/security/protect-your-origin-server/).

Do not make ad hoc AWS console security-group changes. Add AWS-origin hardening
to Terraform so the desired state remains reviewable and reproducible.

## Final checklist

- [ ] Every apex domain is an active Cloudflare zone.
- [ ] `service_routes` contains every exact application hostname.
- [ ] Every ECS service uses its matching target-group ARN.
- [ ] ACM validation CNAMEs exist and are DNS-only.
- [ ] ACM certificate status is `ISSUED`.
- [ ] Terraform apply completed successfully.
- [ ] Every application CNAME points to `alb_dns_name` and is proxied.
- [ ] SSL/TLS mode is Full (strict) in every zone.
- [ ] Always Use HTTPS is enabled in every zone.
- [ ] Every ALB target group reports healthy task IPs.
- [ ] Every domain returns the intended service over HTTPS.
