variable "regions" {
  description = "List of AWS regions to deploy resources in"
  type        = list(string)
  default     = ["us-east-1", "us-west-2", "eu-central-1", "ap-northeast-1"]
}

variable "primary_region" {
  description = "The primary AWS region"
  type        = string
}

variable "vpc_cidrs" {
  description = "CIDR blocks for VPCs in each region"
  type        = map(string)
}

variable "availability_zones" {
  description = "Availability zones for each region"
  type        = map(list(string))
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "amis" {
  description = "AMI IDs for Amazon Linux 2023 in each region"
  type        = map(string)
  default = {
    "us-east-1"      = "ami-0dfcb1ef8550277af"
    "us-west-2"      = "ami-0c65adc9a5c1b5d7c"
    "eu-central-1"   = "ami-0faab6bdbac9486fb"
    "ap-northeast-1" = "ami-0dfa284c9d7b2adad"
  }
}

variable "health_check_port" {
  description = "Port for the health check"
  type        = number
}

variable "health_check_path" {
  description = "Path for the health check endpoint"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "keystore_name" {
  description = "The filename for the keystore"
  type        = string
}

variable "keystore_pw" {
  description = "The password for the keystore"
  type        = string
  sensitive   = true
}

variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}