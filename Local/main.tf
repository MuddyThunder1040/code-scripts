terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

terraform {
  backend "s3" {
    bucket         = "terraform-backup-tank"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "local" {
  
}

provider "null" {
}

resource "local_file" "terraform-created-file" {
  filename = "ipinfo.txt"
  file_permission = 777
  content = "${path.module}"
}

resource "null_resource" "example" {
  provisioner "local-exec" {
    command = "ifconfig > hello.txt"
  }
}