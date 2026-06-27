terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }

  cloud {
    organization = "oiasis-org"
    workspaces {
      name = "homelab-portainer"
    }
  }
}

provider "docker" {
  host = var.docker_host
}

resource "docker_image" "portainer" {
  name         = var.portainer_image
  keep_locally = true
}

resource "docker_container" "portainer" {
  name    = "portainer"
  image   = docker_image.portainer.image_id
  restart = "unless-stopped"

  ports {
    internal = 9000
    external = 9000
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  volumes {
    host_path      = var.data_dir
    container_path = "/data"
  }

  networks_advanced {
    name = "homelab-net"
  }

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.portainer.rule"
    value = "Host(`portainer.homelab.local`)"
  }
  labels {
    label = "traefik.http.services.portainer.loadbalancer.server.port"
    value = "9000"
  }
}
