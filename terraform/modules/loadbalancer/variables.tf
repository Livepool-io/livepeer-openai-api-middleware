variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "instance_security_group_id" {
  description = "Instance security group ID"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "health_check_port" {
  description = "Health check port"
  type        = number
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
}

variable "route53_zone_id" {
  description = "The ID of the Route53 hosted zone"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate to use for the load balancer"
  type        = string
}