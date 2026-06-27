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
      name = "homelab-traefik"
    }
  }
}

provider "docker" {
  host = var.docker_host
}

resource "docker_image" "traefik" {
  name         = var.traefik_image
  keep_locally = true
}

resource "docker_container" "traefik" {
  name    = "traefik"
  image   = docker_image.traefik.image_id
  restart = "unless-stopped"

  ports {
    internal = 80
    external = 80
  }
  ports {
    internal = 443
    external = 443
  }
  ports {
    internal = 8080
    external = 8080
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }
  volumes {
    host_path      = "/data/services/traefik/dynamic"
    container_path = "/etc/traefik/dynamic"
    read_only      = true
  }
  volumes {
    host_path      = "/data/services/traefik/certs"
    container_path = "/certs"
    read_only      = true
  }

  command = [
    "--api.dashboard=true",
    "--api.insecure=true",
    "--providers.docker=true",
    "--providers.docker.exposedbydefault=false",
    "--providers.file.directory=/etc/traefik/dynamic",
    "--entrypoints.web.address=:80",
    "--entrypoints.websecure.address=:443",
    "--metrics.prometheus=true",
    "--entrypoints.metrics.address=:8082",
    "--metrics.prometheus.entrypoint=metrics",
  ]

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.dashboard.rule"
    value = "Host(`traefik.homelab.local`)"
  }
  labels {
    label = "traefik.http.routers.dashboard.service"
    value = "api@internal"
  }

  networks_advanced {
    name = "homelab-net"
  }
}
