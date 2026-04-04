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


variable "cas_network" {
  default = "cassandra_network"
}


resource "docker_network" "cassandra_network" {
  name = var.cas_network
}


resource "docker_image" "cassandra_image" {
  name = "cassandra:latest"
}


# Seed node volume
resource "docker_volume" "cassandra_seed_data" {
  name = "cassandra-data-seed"
}

# Worker node volumes
resource "docker_volume" "cassandra_non_seed_data" {
  count = var.non_seed_node_count
  name  = "cassandra-data-non-seed-${count.index}"
}


resource "docker_container" "cassandra_seed_node" {
  name  = "cassandra-seed-node"
  image = docker_image.cassandra_image.image_id

  networks_advanced {
    name = docker_network.cassandra_network.name
  }

  # 🔥 Resource limits
  cpu_shares  = 512
  memory      = 2048
  memory_swap = 2048

  # 💾 Persistent storage
  volumes {
    volume_name    = docker_volume.cassandra_seed_data.name
    container_path = "/var/lib/cassandra"
  }

  # 🧠 Cassandra config
  env = [
    "CASSANDRA_CLUSTER_NAME=MyCassandraCluster",
    "CASSANDRA_SEEDS=cassandra-seed-node",
    "MAX_HEAP_SIZE=1G",
    "HEAP_NEWSIZE=256M"
  ]

  # 🌐 External access (only seed)
  ports {
    internal = 9042
    external = 9042
  }

  # 🔧 Required for Cassandra
  ulimit {
    name = "nofile"
    soft = 100000
    hard = 100000
  }
}


resource "docker_container" "cassandra_nodes" {
  count = var.non_seed_node_count

  name  = "cassandra-node-${count.index}"
  image = docker_image.cassandra_image.image_id

  networks_advanced {
    name = docker_network.cassandra_network.name
  }

  # 🔥 Resource limits
  cpu_shares  = 512
  memory      = 2048
  memory_swap = 2048

  # 💾 Unique volume per node
  volumes {
    volume_name    = docker_volume.cassandra_non_seed_data[count.index].name
    container_path = "/var/lib/cassandra"
  }

  # 🧠 Cassandra config
  env = [
    "CASSANDRA_CLUSTER_NAME=MyCassandraCluster",
    "CASSANDRA_SEEDS=cassandra-seed-node",
    "MAX_HEAP_SIZE=1G",
    "HEAP_NEWSIZE=256M"
  ]

  # 🌐 Unique ports per node
  ports {
    internal = 9042
    external = 9043 + count.index
  }

  # 🔧 Required for Cassandra
  ulimit {
    name = "nofile"
    soft = 100000
    hard = 100000
  }

  # ⏳ Ensure seed starts first
  depends_on = [
    docker_container.cassandra_seed_node
  ]
}