terraform {
  # on ajt le provider aws qui sera installé avec le tf init
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.73.0"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "1.5.2"
    }
  }

  required_version = ">= 1.17.2"
}