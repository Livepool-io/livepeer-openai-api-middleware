# Create the main Route53 zone
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# Create a record for the gateway subdomain
resource "aws_route53_record" "gateway" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "gateway.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_route53_record.regional_gateway[var.primary_region].name
    zone_id                = aws_route53_record.regional_gateway[var.primary_region].zone_id
    evaluate_target_health = true
  }
}

# Create regional records for the gateway
resource "aws_route53_record" "regional_gateway" {
  for_each = toset(var.regions)

  zone_id = aws_route53_zone.main.zone_id
  name    = "gateway-${each.key}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main[each.key].dns_name
    zone_id                = aws_lb.main[each.key].zone_id
    evaluate_target_health = true
  }
}

# Create a latency-based routing policy
resource "aws_route53_record" "gateway_latency" {
  for_each = toset(var.regions)

  zone_id = aws_route53_zone.main.zone_id
  name    = "gateway.${var.domain_name}"
  type    = "A"

  latency_routing_policy {
    region = each.key
  }

  alias {
    name                   = aws_lb.main[each.key].dns_name
    zone_id                = aws_lb.main[each.key].zone_id
    evaluate_target_health = true
  }

  set_identifier = each.key
}

# Create the certificate validation records
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in flatten([for cert in aws_acm_certificate.main : cert.domain_validation_options]) : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
      region = split("-", dvo.domain_name)[0]
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id

  provider = aws[each.value.region]
}