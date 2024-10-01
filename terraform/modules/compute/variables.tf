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

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ami_id" {
  description = "AMI ID"
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

variable "keystore_name" {
  description = "Keystore name"
  type        = string
}

variable "keystore_pw" {
  description = "Keystore password"
  type        = string
}

variable "desired_capacity" {
  description = "Desired capacity for the Auto Scaling Group"
  type        = number
}

variable "max_size" {
  description = "Maximum size of the Auto Scaling Group"
  type        = number
}

variable "min_size" {
  description = "Minimum size of the Auto Scaling Group"
  type        = number
}
