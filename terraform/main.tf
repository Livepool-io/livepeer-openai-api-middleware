terraform {
  required_version = ">= 0.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Networking Modules
module "networking_us_east_1" {
  source = "./modules/networking"
  providers = {
    aws.region = aws.us-east-1
  }
  region             = "us-east-1"
  vpc_cidr           = lookup(var.vpc_cidrs, "us-east-1", "10.0.0.0/16")
  availability_zones = lookup(var.availability_zones, "us-east-1", [])
}

module "networking_us_west_2" {
  source = "./modules/networking"
  providers = {
    aws.region = aws.us-west-2
  }
  region             = "us-west-2"
  vpc_cidr           = lookup(var.vpc_cidrs, "us-west-2", "10.0.0.0/16")
  availability_zones = lookup(var.availability_zones, "us-west-2", [])
}

module "networking_eu_central_1" {
  source = "./modules/networking"
  providers = {
    aws.region = aws.eu-central-1
  }
  region             = "eu-central-1"
  vpc_cidr           = lookup(var.vpc_cidrs, "eu-central-1", "10.0.0.0/16")
  availability_zones = lookup(var.availability_zones, "eu-central-1", [])
}

module "networking_ap_northeast_1" {
  source = "./modules/networking"
  providers = {
    aws.region = aws.ap-northeast-1
  }
  region             = "ap-northeast-1"
  vpc_cidr           = lookup(var.vpc_cidrs, "ap-northeast-1", "10.0.0.0/16")
  availability_zones = lookup(var.availability_zones, "ap-northeast-1", [])
}

# Compute Modules
module "compute_us_east_1" {
  source = "./modules/compute"
  providers = {
    aws.region = aws.us-east-1
  }
  region            = "us-east-1"
  vpc_id            = module.networking_us_east_1.vpc_id
  subnet_ids        = module.networking_us_east_1.subnet_ids
  instance_type     = var.instance_type
  ami_id            = var.amis["us-east-1"]
  health_check_port = var.health_check_port
  health_check_path = var.health_check_path
  desired_capacity  = var.asg_desired_capacity
  max_size          = var.asg_max_size
  min_size          = var.asg_min_size
  keystore_name     = var.keystore_name
  keystore_pw       = var.keystore_pw
}

module "compute_us_west_2" {
  source = "./modules/compute"
  providers = {
    aws.region = aws.us-west-2
  }
  region            = "us-west-2"
  vpc_id            = module.networking_us_west_2.vpc_id
  subnet_ids        = module.networking_us_west_2.subnet_ids
  instance_type     = var.instance_type
  ami_id            = var.amis["us-west-2"]
  health_check_port = var.health_check_port
  health_check_path = var.health_check_path
  desired_capacity  = var.asg_desired_capacity
  max_size          = var.asg_max_size
  min_size          = var.asg_min_size
  keystore_name     = var.keystore_name
  keystore_pw       = var.keystore_pw
}

module "compute_eu_central_1" {
  source = "./modules/compute"
  providers = {
    aws.region = aws.eu-central-1
  }
  region            = "eu-central-1"
  vpc_id            = module.networking_eu_central_1.vpc_id
  subnet_ids        = module.networking_eu_central_1.subnet_ids
  instance_type     = var.instance_type
  ami_id            = var.amis["eu-central-1"]
  health_check_port = var.health_check_port
  health_check_path = var.health_check_path
  desired_capacity  = var.asg_desired_capacity
  max_size          = var.asg_max_size
  min_size          = var.asg_min_size
  keystore_name     = var.keystore_name
  keystore_pw       = var.keystore_pw
}

module "compute_ap_northeast_1" {
  source = "./modules/compute"
  providers = {
    aws.region = aws.ap-northeast-1
  }
  region            = "ap-northeast-1"
  vpc_id            = module.networking_ap_northeast_1.vpc_id
  subnet_ids        = module.networking_ap_northeast_1.subnet_ids
  instance_type     = var.instance_type
  ami_id            = var.amis["ap-northeast-1"]
  health_check_port = var.health_check_port
  health_check_path = var.health_check_path
  desired_capacity  = var.asg_desired_capacity
  max_size          = var.asg_max_size
  min_size          = var.asg_min_size
  keystore_name     = var.keystore_name
  keystore_pw       = var.keystore_pw
}

# Load Balancer Modules
module "loadbalancer_us_east_1" {
  source = "./modules/loadbalancer"
  providers = {
    aws.region    = aws.us-east-1
    aws.us-east-1 = aws.us-east-1
  }
  region                     = "us-east-1"
  vpc_id                     = module.networking_us_east_1.vpc_id
  subnet_ids                 = module.networking_us_east_1.subnet_ids
  domain_name                = var.domain_name
  health_check_port          = var.health_check_port
  health_check_path          = var.health_check_path
  instance_security_group_id = module.compute_us_east_1.security_group_id
  route53_zone_id            = aws_route53_zone.main.zone_id
  certificate_arn = aws_acm_certificate_validation.main.certificate_arn
}

module "loadbalancer_us_west_2" {
  source = "./modules/loadbalancer"
  providers = {
    aws.region    = aws.us-west-2
    aws.us-east-1 = aws.us-east-1
  }
  region                     = "us-west-2"
  vpc_id                     = module.networking_us_west_2.vpc_id
  subnet_ids                 = module.networking_us_west_2.subnet_ids
  domain_name                = var.domain_name
  health_check_port          = var.health_check_port
  health_check_path          = var.health_check_path
  instance_security_group_id = module.compute_us_west_2.security_group_id
  route53_zone_id            = aws_route53_zone.main.zone_id
  certificate_arn = aws_acm_certificate_validation.main.certificate_arn
}

module "loadbalancer_eu_central_1" {
  source = "./modules/loadbalancer"
  providers = {
    aws.region    = aws.eu-central-1
    aws.us-east-1 = aws.us-east-1
  }
  region                     = "eu-central-1"
  vpc_id                     = module.networking_eu_central_1.vpc_id
  subnet_ids                 = module.networking_eu_central_1.subnet_ids
  domain_name                = var.domain_name
  health_check_port          = var.health_check_port
  health_check_path          = var.health_check_path
  instance_security_group_id = module.compute_eu_central_1.security_group_id
  route53_zone_id            = aws_route53_zone.main.zone_id
  certificate_arn = aws_acm_certificate_validation.main.certificate_arn
}

module "loadbalancer_ap_northeast_1" {
  source = "./modules/loadbalancer"
  providers = {
    aws.region    = aws.ap-northeast-1
    aws.us-east-1 = aws.us-east-1
  }
  region                     = "ap-northeast-1"
  vpc_id                     = module.networking_ap_northeast_1.vpc_id
  subnet_ids                 = module.networking_ap_northeast_1.subnet_ids
  domain_name                = var.domain_name
  health_check_port          = var.health_check_port
  health_check_path          = var.health_check_path
  instance_security_group_id = module.compute_ap_northeast_1.security_group_id
  route53_zone_id            = aws_route53_zone.main.zone_id
  certificate_arn = aws_acm_certificate_validation.main.certificate_arn
}