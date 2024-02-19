terraform {
  backend "s3" {
    bucket         = "ever-smft-devnet"
    key            = "ever-smft-devnet.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "terraform-lockdb"
  }

  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "0.7.6"
    }
  }
}
