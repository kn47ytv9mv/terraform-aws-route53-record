resource "aws_route53_record" "resource" {
  for_each = var.records

  name    = each.value.name
  type    = each.value.type
  zone_id = each.value.zone_id
  ttl     = each.value.alias == null ? each.value.ttl : null
  records = each.value.alias == null ? each.value.records : null

  set_identifier                   = each.value.set_identifier
  health_check_id                  = each.value.health_check_id
  multivalue_answer_routing_policy = each.value.multivalue_answer_routing_policy

  dynamic "alias" {
    for_each = each.value.alias[*]

    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }

  dynamic "weighted_routing_policy" {
    for_each = each.value.weighted_routing_policy[*]

    content {
      weight = weighted_routing_policy.value.weight
    }
  }

  dynamic "latency_routing_policy" {
    for_each = each.value.latency_routing_policy[*]

    content {
      region = latency_routing_policy.value.region
    }
  }

  dynamic "failover_routing_policy" {
    for_each = each.value.failover_routing_policy[*]

    content {
      type = failover_routing_policy.value.type
    }
  }

  dynamic "geolocation_routing_policy" {
    for_each = each.value.geolocation_routing_policy[*]

    content {
      continent   = geolocation_routing_policy.value.continent
      country     = geolocation_routing_policy.value.country
      subdivision = geolocation_routing_policy.value.subdivision
    }
  }

  dynamic "geoproximity_routing_policy" {
    for_each = each.value.geoproximity_routing_policy[*]

    content {
      aws_region       = geoproximity_routing_policy.value.aws_region
      local_zone_group = geoproximity_routing_policy.value.local_zone_group
      bias             = geoproximity_routing_policy.value.bias

      dynamic "coordinates" {
        for_each = geoproximity_routing_policy.value.coordinates[*]

        content {
          latitude  = coordinates.value.latitude
          longitude = coordinates.value.longitude
        }
      }
    }
  }

  dynamic "cidr_routing_policy" {
    for_each = each.value.cidr_routing_policy[*]

    content {
      collection_id = cidr_routing_policy.value.collection_id
      location_name = cidr_routing_policy.value.location_name
    }
  }
}

output "ids" {
  description = "Map of each record's key, as supplied in `records`, to its ID."
  value       = { for k, r in aws_route53_record.resource : k => r.id }
}

output "fqdns" {
  description = "Map of each record's key, as supplied in `records`, to its FQDN."
  value       = { for k, r in aws_route53_record.resource : k => r.fqdn }
}
