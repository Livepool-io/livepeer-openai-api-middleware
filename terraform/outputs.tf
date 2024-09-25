# outputs.tf
output "gateway_domain" {
  description = "The domain name for the gateway"
  value       = "gateway.${var.domain_name}"
}

output "regional_gateway_domains" {
  description = "The regional domain names for the API"
  value       = { for region in var.regions : region => "gateway-${region}.${var.domain_name}" }
}

output "load_balancer_dns_names" {
  description = "The DNS names of the load balancers"
  value       = { for region in var.regions : region => aws_lb.main[region].dns_name }
}

output "nameservers" {
  description = "The nameservers for the Route53 zone"
  value       = aws_route53_zone.main.name_servers
}