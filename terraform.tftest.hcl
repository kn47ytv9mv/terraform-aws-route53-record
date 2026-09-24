mock_provider "aws" {}

run "more_than_one_routing_policy_rejected" {
  command = plan

  variables {
    records = {
      app = {
        zone_id        = "Z1234567890ABC"
        name           = "app.example.com"
        type           = "A"
        set_identifier = "us-east-1"
        records        = ["10.0.0.1"]

        latency_routing_policy  = { region = "us-east-1" }
        weighted_routing_policy = { weight = 50 }
      }
    }
  }

  expect_failures = [var.records]
}

run "routing_policy_without_set_identifier_rejected" {
  command = plan

  variables {
    records = {
      app = {
        zone_id                = "Z1234567890ABC"
        name                   = "app.example.com"
        type                   = "A"
        records                = ["10.0.0.1"]
        latency_routing_policy = { region = "us-east-1" }
      }
    }
  }

  expect_failures = [var.records]
}

run "plain_record_sets_ttl_and_records_no_alias" {
  command = plan

  variables {
    records = {
      app = {
        zone_id = "Z1234567890ABC"
        name    = "app.example.com"
        type    = "CNAME"
        ttl     = 300
        records = ["target.example.net"]
      }
    }
  }

  assert {
    condition     = aws_route53_record.resource["app"].ttl == 300
    error_message = "A plain record should set ttl from the entry."
  }

  assert {
    condition     = length(aws_route53_record.resource["app"].alias) == 0
    error_message = "A plain record should have no alias block."
  }
}

run "alias_record_nulls_ttl_and_records" {
  command = plan

  variables {
    records = {
      app = {
        zone_id = "Z1234567890ABC"
        name    = "app.example.com"
        type    = "A"
        alias = {
          name    = "alb-1234567890.us-east-1.elb.amazonaws.com"
          zone_id = "Z35SXDOTRQ7X7K"
        }
      }
    }
  }

  assert {
    condition     = aws_route53_record.resource["app"].ttl == null
    error_message = "An alias record should null out ttl, since AWS rejects both alias and ttl on the same record."
  }

  assert {
    condition     = length(aws_route53_record.resource["app"].alias) == 1
    error_message = "An alias record should have exactly one alias block."
  }

  assert {
    condition     = aws_route53_record.resource["app"].alias[0].evaluate_target_health == false
    error_message = "evaluate_target_health should default to false when not set."
  }
}

run "each_key_becomes_its_own_record" {
  command = plan

  variables {
    records = {
      validation_a = {
        zone_id = "Z1"
        name    = "_a.example.com"
        type    = "CNAME"
        records = ["a.acm-validations.aws."]
      }
      validation_b = {
        zone_id = "Z1"
        name    = "_b.example.com"
        type    = "CNAME"
        records = ["b.acm-validations.aws."]
      }
    }
  }

  assert {
    condition     = length(aws_route53_record.resource) == 2
    error_message = "Two keys should create two distinct resource instances."
  }

  assert {
    condition     = length(output.ids) == 2 && length(output.fqdns) == 2
    error_message = "Both ids and fqdns outputs should carry one entry per record."
  }
}

run "an_unresolvable_zone_id_still_plans" {
  command = plan

  variables {
    records = {
      app = {
        zone_id = "Z1234567890ABC"
        name    = "app.example.com"
        type    = "A"
        alias = {
          name    = "alb-1234567890.us-east-1.elb.amazonaws.com"
          zone_id = "Z35SXDOTRQ7X7K"
        }
      }
    }
  }

  assert {
    condition     = length(aws_route53_record.resource) == 1
    error_message = "The record key must not depend on zone_id, so a zone created in the same apply can still be planned against."
  }
}

run "latency_routing_two_regions_get_distinct_keys" {
  command = plan

  variables {
    records = {
      us = {
        zone_id                = "Z1234567890ABC"
        name                   = "app.example.com"
        type                   = "A"
        set_identifier         = "us-east-1"
        records                = ["10.0.0.1"]
        latency_routing_policy = { region = "us-east-1" }
      }
      eu = {
        zone_id                = "Z1234567890ABC"
        name                   = "app.example.com"
        type                   = "A"
        set_identifier         = "eu-west-1"
        records                = ["10.1.0.1"]
        latency_routing_policy = { region = "eu-west-1" }
      }
    }
  }

  assert {
    condition     = length(aws_route53_record.resource) == 2
    error_message = "Two records sharing the same zone_id, name, and type but differing in set_identifier should create two distinct resource instances."
  }

  assert {
    condition     = aws_route53_record.resource["us"].latency_routing_policy[0].region == "us-east-1"
    error_message = "Each record should render its own routing policy."
  }
}

run "failover_routing_with_health_check" {
  command = plan

  variables {
    records = {
      primary = {
        zone_id                 = "Z1234567890ABC"
        name                    = "app.example.com"
        type                    = "A"
        set_identifier          = "primary"
        records                 = ["10.0.0.1"]
        health_check_id         = "abcd1234-ab12-cd34-ef56-abcdef123456"
        failover_routing_policy = { type = "PRIMARY" }
      }
    }
  }

  assert {
    condition     = aws_route53_record.resource["primary"].health_check_id == "abcd1234-ab12-cd34-ef56-abcdef123456"
    error_message = "health_check_id should pass through unchanged."
  }

  assert {
    condition     = aws_route53_record.resource["primary"].failover_routing_policy[0].type == "PRIMARY"
    error_message = "failover_routing_policy should render with the correct type."
  }
}

run "readme_registry_source_alias_record" {
  command = plan

  variables {
    records = {
      app = {
        zone_id = "Z1234567890ABC"
        name    = "app.example.com"
        type    = "A"

        alias = {
          name    = "alb-1234567890.us-east-1.elb.amazonaws.com"
          zone_id = "Z35SXDOTRQ7X7K"
        }
      }
    }
  }
}

run "readme_latency_routing_two_regions" {
  command = plan

  variables {
    records = {
      us_east_1 = {
        zone_id                = "Z1234567890ABC"
        name                   = "app.example.com"
        type                   = "A"
        set_identifier         = "us-east-1"
        records                = ["203.0.113.1"]
        health_check_id        = "abcd1234-ab12-cd34-ef56-abcdef123456"
        latency_routing_policy = { region = "us-east-1" }
      }
      eu_west_1 = {
        zone_id                = "Z1234567890ABC"
        name                   = "app.example.com"
        type                   = "A"
        set_identifier         = "eu-west-1"
        records                = ["203.0.113.2"]
        health_check_id        = "dcba4321-cd21-ab43-fe65-654321fedcba"
        latency_routing_policy = { region = "eu-west-1" }
      }
    }
  }

  assert {
    condition     = length(aws_route53_record.resource) == 2
    error_message = "The README's global-app example should create two records, one per region."
  }
}

run "readme_github_source_cname_record" {
  command = plan

  variables {
    records = {
      app = {
        zone_id = "Z1234567890ABC"
        name    = "app.example.com"
        type    = "CNAME"
        ttl     = 300
        records = ["target.example.net"]
      }
    }
  }
}
