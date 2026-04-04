terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# ✅ Network
resource "docker_network" "cassandra_network" {
  name = var.cas_network
}

# ✅ Image
resource "docker_image" "cassandra_image" {
  name = "cassandra:latest"
}

# ✅ Volume (data persistence)
resource "docker_volume" "cassandra_data" {
  name = "cassandra_data_seed"
}

# ✅ Seed Node
resource "docker_container" "cassandra_seed_node" {
  name  = "cassandra-seed-node"
  image = docker_image.cassandra_image.image_id

  networks_advanced {
    name = docker_network.cassandra_network.name
  }

  # 🔥 Resource limits
  cpu_shares = 512
  memory     = 2048
  memory_swap = 2048

  # 💾 Persistent storage
  volumes {
    volume_name    = docker_volume.cassandra_data.name
    container_path = "/var/lib/cassandra"
  }

  # 🧠 Cassandra config
  env = [
    "CASSANDRA_CLUSTER_NAME=MyCassandraCluster",
    "CASSANDRA_SEEDS=cassandra-seed-node",
    "MAX_HEAP_SIZE=1G",
    "HEAP_NEWSIZE=256M"
  ]

  # 🌐 Expose ONLY CQL port
  ports {
    internal = 9042
    external = 9042
  }

  # 🔧 Required for Cassandra stability
  ulimit {
    name = "nofile"
    soft = 100000
    hard = 100000
  }
}