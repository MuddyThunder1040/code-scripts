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

provider "docker" {
  host = var.docker_host
}
provider "time" {}

locals {
  apache_cassandra_env = [
    "CASSANDRA_CLUSTER_NAME=${var.cluster_name}",
    "CASSANDRA_SEEDS=${var.seed_container_name}",
    "CASSANDRA_NUM_TOKENS=${var.num_tokens}",
    "MAX_HEAP_SIZE=${var.max_heap_size}",
    "HEAP_NEWSIZE=${var.heap_new_size}",
    "LOCAL_JMX=no",
    "JMX_PORT=${var.cassandra_jmx_port}"
  ]

  cassandra_jmx_options = {
    seed   = local.cassandra_jmx_extra_opts[var.seed_container_name]
    node_1 = local.cassandra_jmx_extra_opts["${var.node_container_name_prefix}-1"]
    node_2 = local.cassandra_jmx_extra_opts["${var.node_container_name_prefix}-2"]
    node_3 = local.cassandra_jmx_extra_opts["${var.node_container_name_prefix}-3"]
    node_4 = local.cassandra_jmx_extra_opts["${var.node_container_name_prefix}-4"]
    node_5 = local.cassandra_jmx_extra_opts["${var.node_container_name_prefix}-5"]
    node_6 = local.cassandra_jmx_extra_opts["${var.node_container_name_prefix}-6"]
  }

  cassandra_jmx_extra_opts = {
    for hostname in concat(
      [var.seed_container_name],
      [for index in range(1, 7) : "${var.node_container_name_prefix}-${index}"]
    ) :
    hostname => join(" ", [
      "-Djava.rmi.server.hostname=${hostname}",
      "-Dcom.sun.management.jmxremote=true",
      "-Dcom.sun.management.jmxremote.port=${var.cassandra_jmx_port}",
      "-Dcom.sun.management.jmxremote.rmi.port=${var.cassandra_jmx_port}",
      "-Dcom.sun.management.jmxremote.local.only=false",
      "-Dcom.sun.management.jmxremote.ssl=false",
      "-Dcom.sun.management.jmxremote.authenticate=false"
    ])
  }

  reaper_env = [
    "REAPER_STORAGE_TYPE=memory",
    "REAPER_MEMORY_STORAGE_DIRECTORY=/var/lib/cassandra-reaper/storage",
    "REAPER_ENABLE_DYNAMIC_SEED_LIST=true",
    "REAPER_DATACENTER_AVAILABILITY=ALL",
    "REAPER_JMX_CONNECTION_TIMEOUT_IN_SECONDS=${var.reaper_jmx_connection_timeout_seconds}",
    "REAPER_AUTO_SCHEDULING_SEEDS=${var.seed_container_name}:${var.cassandra_jmx_port}",
    "REAPER_HOST=reaper",
    "REAPER_PORT=8080",
    "REAPER_AUTH_ENABLED=false",
    "REAPER_CASS_AUTH_ENABLED=false",
    "REAPER_HEAP_SIZE=${var.reaper_heap_size}"
  ]

  reaper_registration_command = [
    "--fail",
    "--show-error",
    "--silent",
    "--retry",
    tostring(var.reaper_registration_retries),
    "--retry-delay",
    tostring(var.reaper_registration_retry_delay_seconds),
    "--request",
    "POST",
    "http://${var.reaper_container_name}:8080/cluster?seedHost=${var.seed_container_name}&jmxPort=${var.cassandra_jmx_port}"
  ]
}

resource "docker_network" "cassandra" {
  name = var.network_name
}

resource "docker_image" "cassandra" {
  name         = var.cassandra_image
  keep_locally = true
}

resource "docker_image" "reaper" {
  name         = var.reaper_image
  keep_locally = true
}

resource "docker_image" "reaper_registration" {
  count = var.enable_reaper_cluster_registration ? 1 : 0

  name         = var.reaper_registration_image
  keep_locally = true
}

resource "docker_volume" "seed_data" {
  name = "${var.volume_prefix}-seed"
}

resource "docker_volume" "node_data" {
  count = var.cassandra_node_count
  name  = "${var.volume_prefix}-node-${count.index + 1}"
}

resource "docker_volume" "reaper_data" {
  name = var.reaper_volume_name
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

  env = concat(local.apache_cassandra_env, [
    "JVM_EXTRA_OPTS=${local.cassandra_jmx_options.seed}"
  ])

  ports {
    internal = 9042
    external = var.seed_cql_port
  }

  ports {
    internal = var.cassandra_jmx_port
    external = var.seed_jmx_port
    ip       = var.jmx_host_bind_ip
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

  env = concat(local.apache_cassandra_env, [
    "JVM_EXTRA_OPTS=${local.cassandra_jmx_options.node_1}"
  ])

  ports {
    internal = var.cassandra_jmx_port
    external = var.node_1_jmx_port
    ip       = var.jmx_host_bind_ip
  }

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

  env = concat(local.apache_cassandra_env, [
    "JVM_EXTRA_OPTS=${local.cassandra_jmx_options.node_2}"
  ])

  ports {
    internal = var.cassandra_jmx_port
    external = var.node_2_jmx_port
    ip       = var.jmx_host_bind_ip
  }

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

  env = concat(local.apache_cassandra_env, [
    "JVM_EXTRA_OPTS=${local.cassandra_jmx_options.node_3}"
  ])

  ports {
    internal = var.cassandra_jmx_port
    external = var.node_3_jmx_port
    ip       = var.jmx_host_bind_ip
  }

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

  env = concat(local.apache_cassandra_env, [
    "JVM_EXTRA_OPTS=${local.cassandra_jmx_options.node_4}"
  ])

  ports {
    internal = var.cassandra_jmx_port
    external = var.node_4_jmx_port
    ip       = var.jmx_host_bind_ip
  }

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

  env = concat(local.apache_cassandra_env, [
    "JVM_EXTRA_OPTS=${local.cassandra_jmx_options.node_5}"
  ])

  ports {
    internal = var.cassandra_jmx_port
    external = var.node_5_jmx_port
    ip       = var.jmx_host_bind_ip
  }

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

  env = concat(local.apache_cassandra_env, [
    "JVM_EXTRA_OPTS=${local.cassandra_jmx_options.node_6}"
  ])

  ports {
    internal = var.cassandra_jmx_port
    external = var.node_6_jmx_port
    ip       = var.jmx_host_bind_ip
  }

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

resource "docker_container" "reaper" {
  name     = var.reaper_container_name
  image    = docker_image.reaper.image_id
  hostname = var.reaper_container_name
  restart  = var.restart_policy

  networks_advanced {
    name    = docker_network.cassandra.name
    aliases = [var.reaper_container_name]
  }

  env = local.reaper_env

  ports {
    internal = 8080
    external = var.reaper_http_port
  }

  volumes {
    volume_name    = docker_volume.reaper_data.name
    container_path = "/var/lib/cassandra-reaper"
  }

  depends_on = [time_sleep.after_seed_bootstrap]
}

resource "time_sleep" "before_reaper_cluster_registration" {
  count = var.enable_reaper_cluster_registration ? 1 : 0

  create_duration = var.reaper_cluster_registration_wait

  triggers = {
    reaper_container_id = docker_container.reaper.id
    seed_container_id   = docker_container.seed.id
    node_ids = join(",", concat(
      docker_container.node_1[*].id,
      docker_container.node_2[*].id,
      docker_container.node_3[*].id,
      docker_container.node_4[*].id,
      docker_container.node_5[*].id,
      docker_container.node_6[*].id
    ))
  }

  depends_on = [
    docker_container.reaper,
    docker_container.node_1,
    docker_container.node_2,
    docker_container.node_3,
    docker_container.node_4,
    docker_container.node_5,
    docker_container.node_6
  ]
}

resource "docker_container" "reaper_cluster_registration" {
  count = var.enable_reaper_cluster_registration ? 1 : 0

  name     = var.reaper_cluster_registration_container_name
  image    = docker_image.reaper_registration[0].image_id
  hostname = var.reaper_cluster_registration_container_name
  must_run = false
  restart  = "no"
  command  = local.reaper_registration_command

  networks_advanced {
    name = docker_network.cassandra.name
  }

  depends_on = [time_sleep.before_reaper_cluster_registration]
}
