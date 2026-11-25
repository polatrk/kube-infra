terraform {
  # on ajt le provider aws qui sera installé avec le tf init
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.73.0"
    }
  }

  required_version = ">= 1.17.2"
}