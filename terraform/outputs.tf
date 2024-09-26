# outputs.tf
output "gateway_domain" {
  description = "The domain name for the gateway"
  value       = "gateway.${var.domain_name}"
}

output "load_balancer_dns_names" {
  value = {
    "us-east-1"      = module.loadbalancer_us_east_1.lb_dns_name,
    "us-west-2"      = module.loadbalancer_us_west_2.lb_dns_name,
    "eu-central-1"   = module.loadbalancer_eu_central_1.lb_dns_name,
    "ap-northeast-1" = module.loadbalancer_ap_northeast_1.lb_dns_name
  }
}

output "regional_gateway_domains" {
  value = {
    for region in var.regions :
    region => "gateway-${region}.${var.domain_name}"
  }
}

output "nameservers" {
  description = "The nameservers for the Route53 zone"
  value       = aws_route53_zone.main.name_servers
}