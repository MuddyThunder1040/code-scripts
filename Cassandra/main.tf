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

resource "docker_container" "node_1" {
  count = var.cassandra_node_count >= 1 ? 1 : 0

  name     = "${var.node_container_name_prefix}-1"
  image    = docker_image.cassandra.image_id
  hostname = "${var.node_container_name_prefix}-1"
  restart  = var.restart_policy

  networks_advanced {
    name    = docker_network.cassandra.name
    aliases = ["${var.node_container_name_prefix}-1"]
  }

  env = local.cassandra_env

  volumes {
    volume_name    = docker_volume.node_data[0].name
    container_path = "/var/lib/cassandra"
  }

  memory = var.container_memory_mb
  cpus   = var.container_cpus

  ulimit {
    name = "nofile"
    soft = 100000
    hard = 100000
  }

  depends_on = [time_sleep.after_seed_bootstrap]
}

resource "time_sleep" "after_node_1_join" {
  count = var.cassandra_node_count >= 2 ? 1 : 0

  create_duration = "${var.node_join_wait_seconds}s"

  triggers = {
    node_id = docker_container.node_1[0].id
  }
}

resource "docker_container" "node_2" {
  count = var.cassandra_node_count >= 2 ? 1 : 0

  name     = "${var.node_container_name_prefix}-2"
  image    = docker_image.cassandra.image_id
  hostname = "${var.node_container_name_prefix}-2"
  restart  = var.restart_policy

  networks_advanced {
    name    = docker_network.cassandra.name
    aliases = ["${var.node_container_name_prefix}-2"]
  }

  env = local.cassandra_env

  volumes {
    volume_name    = docker_volume.node_data[1].name
    container_path = "/var/lib/cassandra"
  }

  memory = var.container_memory_mb
  cpus   = var.container_cpus

  ulimit {
    name = "nofile"
    soft = 100000
    hard = 100000
  }

  depends_on = [time_sleep.after_node_1_join]
}

resource "time_sleep" "after_node_2_join" {
  count = var.cassandra_node_count >= 3 ? 1 : 0

  create_duration = "${var.node_join_wait_seconds}s"

  triggers = {
    node_id = docker_container.node_2[0].id
  }
}

resource "docker_container" "node_3" {
  count = var.cassandra_node_count >= 3 ? 1 : 0

  name     = "${var.node_container_name_prefix}-3"
  image    = docker_image.cassandra.image_id
  hostname = "${var.node_container_name_prefix}-3"
  restart  = var.restart_policy

  networks_advanced {
    name    = docker_network.cassandra.name
    aliases = ["${var.node_container_name_prefix}-3"]
  }

  env = local.cassandra_env

  volumes {
    volume_name    = docker_volume.node_data[2].name
    container_path = "/var/lib/cassandra"
  }

  memory = var.container_memory_mb
  cpus   = var.container_cpus

  ulimit {
    name = "nofile"
    soft = 100000
    hard = 100000
  }

  depends_on = [time_sleep.after_node_2_join]
}

resource "time_sleep" "after_node_3_join" {
  count = var.cassandra_node_count >= 4 ? 1 : 0

  create_duration = "${var.node_join_wait_seconds}s"

  triggers = {
    node_id = docker_container.node_3[0].id
  }
}

resource "docker_container" "node_4" {
  count = var.cassandra_node_count >= 4 ? 1 : 0

  name     = "${var.node_container_name_prefix}-4"
  image    = docker_image.cassandra.image_id
  hostname = "${var.node_container_name_prefix}-4"
  restart  = var.restart_policy

  networks_advanced {
    name    = docker_network.cassandra.name
    aliases = ["${var.node_container_name_prefix}-4"]
  }

  env = local.cassandra_env

  volumes {
    volume_name    = docker_volume.node_data[3].name
    container_path = "/var/lib/cassandra"
  }

  memory = var.container_memory_mb
  cpus   = var.container_cpus

  ulimit {
    name = "nofile"
    soft = 100000
    hard = 100000
  }

  depends_on = [time_sleep.after_node_3_join]
}

resource "time_sleep" "after_node_4_join" {
  count = var.cassandra_node_count >= 5 ? 1 : 0

  create_duration = "${var.node_join_wait_seconds}s"

  triggers = {
    node_id = docker_container.node_4[0].id
  }
}

resource "docker_container" "node_5" {
  count = var.cassandra_node_count >= 5 ? 1 : 0

  name     = "${var.node_container_name_prefix}-5"
  image    = docker_image.cassandra.image_id
  hostname = "${var.node_container_name_prefix}-5"
  restart  = var.restart_policy

  networks_advanced {
    name    = docker_network.cassandra.name
    aliases = ["${var.node_container_name_prefix}-5"]
  }

  env = local.cassandra_env

  volumes {
    volume_name    = docker_volume.node_data[4].name
    container_path = "/var/lib/cassandra"
  }

  memory = var.container_memory_mb
  cpus   = var.container_cpus

  ulimit {
    name = "nofile"
    soft = 100000
    hard = 100000
  }

  depends_on = [time_sleep.after_node_4_join]
}

resource "time_sleep" "after_node_5_join" {
  count = var.cassandra_node_count >= 6 ? 1 : 0

  create_duration = "${var.node_join_wait_seconds}s"

  triggers = {
    node_id = docker_container.node_5[0].id
  }
}

resource "docker_container" "node_6" {
  count = var.cassandra_node_count >= 6 ? 1 : 0

  name     = "${var.node_container_name_prefix}-6"
  image    = docker_image.cassandra.image_id
  hostname = "${var.node_container_name_prefix}-6"
  restart  = var.restart_policy

  networks_advanced {
    name    = docker_network.cassandra.name
    aliases = ["${var.node_container_name_prefix}-6"]
  }

  env = local.cassandra_env

  volumes {
    volume_name    = docker_volume.node_data[5].name
    container_path = "/var/lib/cassandra"
  }

  memory = var.container_memory_mb
  cpus   = var.container_cpus

  ulimit {
    name = "nofile"
    soft = 100000
    hard = 100000
  }

  depends_on = [time_sleep.after_node_5_join]
}
