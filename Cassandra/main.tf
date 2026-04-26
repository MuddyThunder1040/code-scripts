terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
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
provider "time" {}

locals {
  cassandra_env = [
    "CASSANDRA_CLUSTER_NAME=${var.cluster_name}",
    "CASSANDRA_SEEDS=${var.seed_container_name}",
    "CASSANDRA_NUM_TOKENS=${var.num_tokens}",
    "MAX_HEAP_SIZE=${var.max_heap_size}",
    "HEAP_NEWSIZE=${var.heap_new_size}"
  ]
}

resource "docker_network" "cassandra" {
  name = var.network_name
}

resource "docker_image" "cassandra" {
  name         = var.cassandra_image
  keep_locally = true
}

resource "docker_volume" "seed_data" {
  name = "${var.volume_prefix}-seed"
}

resource "docker_volume" "node_data" {
  count = var.cassandra_node_count
  name  = "${var.volume_prefix}-node-${count.index + 1}"
}

resource "docker_container" "seed" {
  name     = var.seed_container_name
  image    = docker_image.cassandra.image_id
  hostname = var.seed_container_name
  restart  = var.restart_policy

  networks_advanced {
    name    = docker_network.cassandra.name
    aliases = [var.seed_container_name]
  }

  env = local.cassandra_env

  ports {
    internal = 9042
    external = var.seed_cql_port
  }

  volumes {
    volume_name    = docker_volume.seed_data.name
    container_path = "/var/lib/cassandra"
  }

  memory = var.container_memory_mb
  cpus   = var.container_cpus

  ulimit {
    name = "nofile"
    soft = 100000
    hard = 100000
  }
}

resource "time_sleep" "after_seed_bootstrap" {
  create_duration = var.seed_bootstrap_wait

  triggers = {
    seed_container_id = docker_container.seed.id
  }
}

resource "time_sleep" "before_node_join" {
  count = var.cassandra_node_count

  create_duration = "${var.node_join_wait_seconds * count.index}s"

  triggers = {
    seed_ready = time_sleep.after_seed_bootstrap.id
  }
}

resource "docker_container" "node" {
  count = var.cassandra_node_count

  name     = "${var.node_container_name_prefix}-${count.index + 1}"
  image    = docker_image.cassandra.image_id
  hostname = "${var.node_container_name_prefix}-${count.index + 1}"
  restart  = var.restart_policy

  networks_advanced {
    name    = docker_network.cassandra.name
    aliases = ["${var.node_container_name_prefix}-${count.index + 1}"]
  }

  env = concat(
    local.cassandra_env,
    ["TERRAFORM_NODE_JOIN_DELAY=${time_sleep.before_node_join[count.index].id}"]
  )

  volumes {
    volume_name    = docker_volume.node_data[count.index].name
    container_path = "/var/lib/cassandra"
  }

  memory = var.container_memory_mb
  cpus   = var.container_cpus

  ulimit {
    name = "nofile"
    soft = 100000
    hard = 100000
  }
}
