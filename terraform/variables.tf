# variables.tf

variable "regions" {
  description = "AWS regions to deploy to"
  type        = list(string)
  default     = ["us-east-1", "us-west-2", "eu-central-1", "ap-northeast-1"]
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.large"
}

variable "amis" {
  description = "AMI IDs for Amazon Linux 2 in each region"
  type        = map(string)
  default = {
    "us-east-1"      = "ami-0cff7528ff583bf9a"
    "us-west-2"      = "ami-00f7e5c52c0f43726"
    "eu-central-1"   = "ami-0d1ddd83282187d18"
    "ap-northeast-1" = "ami-0b828c1c5ac3f13ee"
  }
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

variable "health_check_path" {
  description = "Path for the health check endpoint"
  type        = string
  default     = "/health"
}

variable "health_check_port" {
  description = "Port for the health check"
  type        = number
  default     = 8080
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "yourdomain.com"  # Replace with your actual domain
}