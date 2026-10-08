terraform {
  # backend "s3" {
  #   bucket = ""
  #   key    = ""
  #   region = "ap-southeast-1"
  #   use_lockfile = true
  # }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}
