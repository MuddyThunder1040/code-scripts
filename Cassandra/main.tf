locals {
  cassandra_network_name = var.create_network ? docker_network.cassandra[0].name : data.docker_network.cassandra[0].name

  apache_cassandra_env = [
    "CASSANDRA_CLUSTER_NAME=${var.cluster_name}",
    "CASSANDRA_SEEDS=${var.seed_container_name}",
    "CASSANDRA_NUM_TOKENS=${var.num_tokens}",
    "MAX_HEAP_SIZE=${var.max_heap_size}",
    "HEAP_NEWSIZE=${var.heap_new_size}"
  ]

  dse_env = [
    "DS_LICENSE=accept",
    "CLUSTER_NAME=${var.cluster_name}",
    "SEEDS=${var.seed_container_name}",
    "NUM_TOKENS=${var.num_tokens}",
    "LOCAL_JMX=no",
    "JMX_PORT=7199",
    "JVM_EXTRA_OPTS=-Xms${var.max_heap_size} -Xmx${var.max_heap_size} -Xmn${var.heap_new_size} -XX:MaxDirectMemorySize=${var.max_direct_memory_size} -Dcom.sun.management.jmxremote.port=7199 -Dcom.sun.management.jmxremote.rmi.port=7199 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false"
  ]

  cassandra_env = var.cassandra_distribution == "dse" ? local.dse_env : local.apache_cassandra_env

  cassandra_node_hostnames = concat(
    [var.seed_container_name],
    [for index in range(var.cassandra_node_count) : "${var.node_container_name_prefix}-${index + 1}"]
  )
}

data "docker_network" "cassandra" {
  count = var.create_network ? 0 : 1
  name  = var.network_name
}

resource "docker_network" "cassandra" {
  count = var.create_network ? 1 : 0
  name  = var.network_name
}

resource "docker_image" "cassandra" {
  name         = var.cassandra_image
  keep_locally = true
}

resource "docker_image" "opscenter" {
  count        = var.enable_opscenter ? 1 : 0
  name         = var.opscenter_image
  keep_locally = true
}

resource "docker_volume" "seed_data" {
  name = "${var.volume_prefix}-seed"
}

resource "docker_volume" "node_data" {
  count = var.cassandra_node_count
  name  = "${var.volume_prefix}-node-${count.index + 1}"
}

resource "docker_volume" "opscenter_data" {
  count = var.enable_opscenter && var.opscenter_persistent_volume ? 1 : 0
  name  = var.opscenter_volume_name
}

resource "docker_container" "seed" {
  name     = var.seed_container_name
  image    = docker_image.cassandra.image_id
  hostname = var.seed_container_name
  restart  = var.restart_policy

  networks_advanced {
    name    = local.cassandra_network_name
    aliases = [var.seed_container_name]
  }

  env = local.cassandra_env

  ports {
    internal = 9042
    external = var.seed_cql_port
  }

  ports {
    internal = 7199
    external = var.seed_jmx_port
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

  ulimit {
    name = "nproc"
    soft = 32768
    hard = 32768
  }

  ulimit {
    name = "memlock"
    soft = -1
    hard = -1
  }

  capabilities {
    add = ["IPC_LOCK"]
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
    name    = local.cassandra_network_name
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

  ulimit {
    name = "nproc"
    soft = 32768
    hard = 32768
  }

  ulimit {
    name = "memlock"
    soft = -1
    hard = -1
  }

  capabilities {
    add = ["IPC_LOCK"]
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
    name    = local.cassandra_network_name
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

  ulimit {
    name = "nproc"
    soft = 32768
    hard = 32768
  }

  ulimit {
    name = "memlock"
    soft = -1
    hard = -1
  }

  capabilities {
    add = ["IPC_LOCK"]
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
    name    = local.cassandra_network_name
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

  ulimit {
    name = "nproc"
    soft = 32768
    hard = 32768
  }

  ulimit {
    name = "memlock"
    soft = -1
    hard = -1
  }

  capabilities {
    add = ["IPC_LOCK"]
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
    name    = local.cassandra_network_name
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

  ulimit {
    name = "nproc"
    soft = 32768
    hard = 32768
  }

  ulimit {
    name = "memlock"
    soft = -1
    hard = -1
  }

  capabilities {
    add = ["IPC_LOCK"]
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
    name    = local.cassandra_network_name
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

  ulimit {
    name = "nproc"
    soft = 32768
    hard = 32768
  }

  ulimit {
    name = "memlock"
    soft = -1
    hard = -1
  }

  capabilities {
    add = ["IPC_LOCK"]
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
    name    = local.cassandra_network_name
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

  ulimit {
    name = "nproc"
    soft = 32768
    hard = 32768
  }

  ulimit {
    name = "memlock"
    soft = -1
    hard = -1
  }

  capabilities {
    add = ["IPC_LOCK"]
  }

  depends_on = [time_sleep.after_node_5_join]
}

resource "docker_container" "opscenter" {
  count = var.enable_opscenter ? 1 : 0

  name     = var.opscenter_container_name
  image    = docker_image.opscenter[0].image_id
  hostname = var.opscenter_container_name
  restart  = var.restart_policy

  networks_advanced {
    name    = local.cassandra_network_name
    aliases = [var.opscenter_container_name, "opscenter"]
  }

  env = concat(
    [
      "DS_LICENSE=accept",
      "OPSCENTER_IP=${var.opscenter_container_name}"
    ],
    var.opscenter_extra_env
  )

  ports {
    internal = 8888
    external = var.opscenter_ui_port
  }

  ports {
    internal = 61620
    external = var.opscenter_agent_port
  }

  dynamic "volumes" {
    for_each = var.opscenter_persistent_volume ? [docker_volume.opscenter_data[0].name] : []

    content {
      volume_name    = volumes.value
      container_path = "/var/lib/opscenter"
    }
  }

  lifecycle {
    precondition {
      condition     = var.cassandra_distribution == "dse"
      error_message = "OpsCenter only supports DataStax Enterprise clusters. Set cassandra_distribution = \"dse\" and use a datastax/dse-server image, or set enable_opscenter = false."
    }
  }

  depends_on = [docker_network.cassandra]
}
