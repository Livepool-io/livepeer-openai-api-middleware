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
resource "aws_acm_certificate" "main" {
  provider = aws.us-east-1
  domain_name               = "gateway.${var.domain_name}"
  subject_alternative_names = ["*.gateway.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Create a single latency-based routing record for all ALBs
resource "aws_route53_record" "alb_latency" {
  for_each = {
    "us-east-1"      = module.loadbalancer_us_east_1
    "us-west-2"      = module.loadbalancer_us_west_2
    "eu-central-1"   = module.loadbalancer_eu_central_1
    "ap-northeast-1" = module.loadbalancer_ap_northeast_1
  }
  
  zone_id        = aws_route53_zone.main.zone_id
  name           = "gateway.${var.domain_name}"
  type           = "A"
  set_identifier = each.key

  latency_routing_policy {
    region = each.key
  }

  alias {
    name                   = each.value.alb_dns_name
    zone_id                = each.value.alb_zone_id
    evaluate_target_health = true
  }
}

# Create Route53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name
}