locals {
  loadbalancer_dns_names = {
    "us-east-1"      = module.loadbalancer_us_east_1.lb_dns_name
    "us-west-2"      = module.loadbalancer_us_west_2.lb_dns_name
    "eu-central-1"   = module.loadbalancer_eu_central_1.lb_dns_name
    "ap-northeast-1" = module.loadbalancer_ap_northeast_1.lb_dns_name
  }

  loadbalancer_zone_ids = {
    "us-east-1"      = module.loadbalancer_us_east_1.lb_zone_id
    "us-west-2"      = module.loadbalancer_us_west_2.lb_zone_id
    "eu-central-1"   = module.loadbalancer_eu_central_1.lb_zone_id
    "ap-northeast-1" = module.loadbalancer_ap_northeast_1.lb_zone_id
  }
}


# Create Route53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# Regional Gateway Records
resource "aws_route53_record" "regional_gateway" {
  for_each = toset(var.regions)

  zone_id = aws_route53_zone.main.zone_id
  name    = "gateway-${each.key}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = local.loadbalancer_dns_names[each.key]
    zone_id                = local.loadbalancer_zone_ids[each.key]
    evaluate_target_health = true
  }
}

# Latency-Based Routing Record for the Gateway
resource "aws_route53_record" "gateway_latency" {
  for_each = toset(var.regions)

  zone_id        = aws_route53_zone.main.zone_id
  name           = "gateway.${var.domain_name}"
  type           = "A"
  set_identifier = each.key

  alias {
    name                   = local.loadbalancer_dns_names[each.key]
    zone_id                = local.loadbalancer_zone_ids[each.key]
    evaluate_target_health = true
  }
}
