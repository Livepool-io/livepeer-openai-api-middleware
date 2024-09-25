terraform {
    required_version = ">= 0.14.0"
  
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 3.0"
      }
    }
  
    # If you're using remote state, you can configure it here
    # backend "s3" {
    #   bucket = "my-terraform-state-bucket"
    #   key    = "path/to/my/key"
    #   region = "us-east-1"
    # }
  }