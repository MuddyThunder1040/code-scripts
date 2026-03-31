terraform {
  required_providers {
    docker = {
        source = "kreuzwerker/docker"
        version = "~> 3.0"
    }
  }
}

provider "docker" {
  
}

rterraform {
  backend "s3" {
    bucket         = "terraform-backup-tank"
    key            = "Docker/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

resource "docker_image" "nginx" {
  name = "nginx:latest"
}

resource "docker_container" "nginx_container" {
  name  = "nginx"
  image = docker_image.nginx.name
  ports {
    internal = 80
    external = 8080
  }
  lifecycle {
    create_before_destroy = true
    prevent_destroy = false
  }
}