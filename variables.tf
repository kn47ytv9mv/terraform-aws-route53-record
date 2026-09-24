variable "records" {
  default     = {}
  description = <<-EOT
    DNS records to create, keyed by a name you choose. The key identifies the
    record in state, so adding one does not disturb the others — and it must be
    a value you write in the configuration, not one read from another resource.
    Each entry needs zone_id, name, and type, plus either records (with optional
    ttl) or alias for an alias record.

    At most one of the following routing policies may be set per record — AWS
    rejects more than one, and each requires set_identifier: weighted_routing_policy,
    latency_routing_policy, failover_routing_policy, geolocation_routing_policy,
    geoproximity_routing_policy, cidr_routing_policy, or multivalue_answer_routing_policy.
    health_check_id pairs with failover_routing_policy (or any other policy) to route
    away from an unhealthy endpoint — see terraform-aws-route53-health-check.
  EOT
  type = map(object({
    zone_id = string
    name    = string
    type    = string
    ttl     = optional(number, 300)
    records = optional(list(string))
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = optional(bool, false)
    }))

    set_identifier                   = optional(string)
    health_check_id                  = optional(string)
    multivalue_answer_routing_policy = optional(bool)

    weighted_routing_policy = optional(object({
      weight = number
    }))

    latency_routing_policy = optional(object({
      region = string
    }))

    failover_routing_policy = optional(object({
      type = string
    }))

    geolocation_routing_policy = optional(object({
      continent   = optional(string)
      country     = optional(string)
      subdivision = optional(string)
    }))

    geoproximity_routing_policy = optional(object({
      aws_region       = optional(string)
      local_zone_group = optional(string)
      bias             = optional(number)
      coordinates = optional(object({
        latitude  = string
        longitude = string
      }))
    }))

    cidr_routing_policy = optional(object({
      collection_id = string
      location_name = string
    }))
  }))

  validation {
    condition = alltrue([
      for r in var.records : (
        length([
          for p in [
            r.weighted_routing_policy, r.latency_routing_policy, r.failover_routing_policy,
            r.geolocation_routing_policy, r.geoproximity_routing_policy, r.cidr_routing_policy,
          ] : p if p != null
        ]) + (r.multivalue_answer_routing_policy == true ? 1 : 0) <= 1
      )
    ])
    error_message = "Each record may set at most one of weighted_routing_policy, latency_routing_policy, failover_routing_policy, geolocation_routing_policy, geoproximity_routing_policy, cidr_routing_policy, or multivalue_answer_routing_policy."
  }

  validation {
    condition = alltrue([
      for r in var.records : (
        r.set_identifier != null || (
          r.weighted_routing_policy == null && r.latency_routing_policy == null &&
          r.failover_routing_policy == null && r.geolocation_routing_policy == null &&
          r.geoproximity_routing_policy == null && r.cidr_routing_policy == null &&
          r.multivalue_answer_routing_policy != true
        )
      )
    ])
    error_message = "set_identifier is required whenever a routing policy or multivalue_answer_routing_policy is set."
  }
}
