# terraform-aws-route53-record

Terraform module for one or more Route 53 DNS records, plain or alias.
Requires an existing hosted zone — see
[`terraform-aws-route53-zone`](https://github.com/kn47ytv9mv/terraform-aws-route53-zone)
to create one.

## Cost

Individual records carry no charge; Route 53 bills per hosted zone, per
month, and per query against that zone. This module creates records
within an existing zone rather than the zone itself, so it adds no
marginal cost beyond the query volume those records receive.

## Design

`records` is a map keyed by a name you choose, not a list. The key
identifies the record in Terraform state, so adding a record leaves the
others untouched — the same reasoning as
[`terraform-aws-sns-topic`](https://github.com/kn47ytv9mv/terraform-aws-sns-topic)
and its subscriptions, where a list would renumber and recreate every
entry after an insertion.

**Write the keys literally; never derive them from another resource.**
Terraform needs every key at plan time. A key built from
`module.zone.id`, or from anything ACM computes, is unknown until after
apply, and the plan fails with *"the for_each map includes keys derived
from resource attributes that cannot be determined until apply"*. This
is why the key is yours to choose rather than composed from `zone_id`,
`name`, and `type`: those are routinely unknown, and a module that
created a zone and its records in one apply could not otherwise be
planned at all. Unknown values are fine inside each entry — only the
keys must be known.

## Usage

```hcl
module "dns" {
  source = "kn47ytv9mv/route53-record/aws"

  records = {
    app = {
      zone_id = var.route53_zone_id
      name    = "app.example.com"
      type    = "A"

      alias = {
        name    = module.alb.dns_name
        zone_id = module.alb.zone_id
      }
    }
  }
}
```

Or directly from this repository:

```hcl
module "dns" {
  source = "github.com/kn47ytv9mv/terraform-aws-route53-record"

  records = {
    app = {
      zone_id = var.route53_zone_id
      name    = "app.example.com"
      type    = "CNAME"
      ttl     = 300
      records = ["target.example.net"]
    }
  }
}
```

A global app, routing each user to their nearest healthy region:

```hcl
module "dns" {
  source = "kn47ytv9mv/route53-record/aws"

  records = {
    us_east_1 = {
      zone_id         = var.route53_zone_id
      name            = "app.example.com"
      type            = "A"
      set_identifier  = "us-east-1"
      records         = [module.eip_us_east_1.public_ip]
      health_check_id = module.health_check_us_east_1.id

      latency_routing_policy = {
        region = "us-east-1"
      }
    }

    eu_west_1 = {
      zone_id         = var.route53_zone_id
      name            = "app.example.com"
      type            = "A"
      set_identifier  = "eu-west-1"
      records         = [module.eip_eu_west_1.public_ip]
      health_check_id = module.health_check_eu_west_1.id

      latency_routing_policy = {
        region = "eu-west-1"
      }
    }
  }
}
```

Building DNS validation records for
[`terraform-aws-acm-certificate`](https://github.com/kn47ytv9mv/terraform-aws-acm-certificate)
— see that module's README for the full paired example:

```hcl
locals {
  domains = ["example.com"]

  validation = {
    for dvo in module.certificate.domain_validation_options :
    dvo.domain_name => dvo
  }
}

module "dns" {
  source = "kn47ytv9mv/route53-record/aws"

  records = {
    for domain in local.domains : domain => {
      zone_id = var.route53_zone_id
      name    = local.validation[domain].resource_record_name
      type    = local.validation[domain].resource_record_type
      records = [local.validation[domain].resource_record_value]
    }
  }
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| aws | ~> 6.61 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| records | DNS records to create, keyed by a name you choose. Each entry needs `zone_id`, `name`, and `type`, plus either `records` (with optional `ttl`) or `alias` for an alias record. At most one of `weighted_routing_policy`, `latency_routing_policy`, `failover_routing_policy`, `geolocation_routing_policy`, `geoproximity_routing_policy`, `cidr_routing_policy`, or `multivalue_answer_routing_policy` may be set, and each requires `set_identifier`. `health_check_id` pairs with any routing policy to route away from an unhealthy endpoint — see [`terraform-aws-route53-health-check`](https://github.com/kn47ytv9mv/terraform-aws-route53-health-check). | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| ids | Map of each record's key, as supplied in `records`, to its ID. |
| fqdns | Map of each record's key, as supplied in `records`, to its FQDN. |

## License

MIT — see [LICENSE.md](LICENSE.md).
