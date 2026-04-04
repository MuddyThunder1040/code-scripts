terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
    cloud {
    organization = "oiasis-org"

    workspaces {
      name = "homelab-tf"
    }
  }
}

provider "docker" {}

resource "docker_network" "cassandra_network" {
  name = var.cas_network
}

resource "docker_image" "cassandra_image" {
  name = "cassandra:latest"
}

resource "docker_volume" "cassandra_data" {
  name = "cassandra_data_seed"
}

resource "docker_container" "cassandra_seed_node" {
  name  = "cassandra-seed-node"
  image = docker_image.cassandra_image.image_id

  networks_advanced {
    name = docker_network.cassandra_network.name
  }

  cpu_shares = 512
  memory     = 2048
  memory_swap = 2048

  volumes {
    volume_name    = docker_volume.cassandra_data.name
    container_path = "/var/lib/cassandra"
  }

  env = [
    "CASSANDRA_CLUSTER_NAME=MyCassandraCluster",
    "CASSANDRA_SEEDS=cassandra-seed-node",
    "MAX_HEAP_SIZE=1G",
    "HEAP_NEWSIZE=256M"
  ]

  ports {
    internal = 9042
    external = 9042
  }

  ulimit {
    name = "nofile"
    soft = 100000
    hard = 100000
  }
}