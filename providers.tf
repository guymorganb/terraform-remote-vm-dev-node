// setting up the terraform configuration itself, for AWS
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      //version = "~> 5.0"
    }
  }
}
// setting up the configuration for terraform to work with AWS
provider "aws" {
  region                   = "us-east-2"
  shared_credentials_files = ["~/.aws/config"]
  profile                  = "vscodeCloudEnv"
}