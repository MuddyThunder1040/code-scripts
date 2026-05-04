variable "cassandra_image" {
  description = "Docker image used for all Cassandra/DSE containers. OpsCenter requires DataStax Enterprise, not the Apache Cassandra image."
  type        = string
  default     = "datastax/dse-server:6.8.48"
}

variable "cassandra_distribution" {
  description = "Container distribution to run. Use dse when enable_opscenter is true."
  type        = string
  default     = "dse"

  validation {
    condition     = contains(["apache", "dse"], var.cassandra_distribution)
    error_message = "cassandra_distribution must be apache or dse."
  }
}

variable "cluster_name" {
  description = "Cassandra cluster name."
  type        = string
  default     = "demo-cluster"
}

variable "network_name" {
  description = "Docker network name for the Cassandra cluster."
  type        = string
  default     = "cassandra-network"
}

variable "create_network" {
  description = "Create the Docker network. Set to false to attach Cassandra and OpsCenter to an existing Docker network."
  type        = bool
  default     = true
}

variable "seed_container_name" {
  description = "Name and Docker DNS alias for the seed container."
  type        = string
  default     = "cassandra-seed"
}

variable "node_container_name_prefix" {
  description = "Prefix used for non-seed Cassandra containers."
  type        = string
  default     = "cassandra-node"
}

variable "cassandra_node_count" {
  description = "Number of non-seed Cassandra nodes to create."
  type        = number
  default     = 5

  validation {
    condition     = var.cassandra_node_count >= 0 && var.cassandra_node_count <= 6
    error_message = "cassandra_node_count must be between 0 and 6."
  }
}

variable "num_tokens" {
  description = "Cassandra vnodes per container."
  type        = number
  default     = 16
}

variable "max_heap_size" {
  description = "Cassandra JVM max heap size."
  type        = string
  default     = "2G"
}

variable "heap_new_size" {
  description = "Cassandra JVM young generation heap size."
  type        = string
  default     = "512M"
}

variable "max_direct_memory_size" {
  description = "DSE JVM max direct memory size. Keep this explicit for multi-container/laptop runs because DSE otherwise calculates from host memory."
  type        = string
  default     = "512m"
}

variable "seed_cql_port" {
  description = "Host port mapped to the seed container CQL port 9042."
  type        = number
  default     = 9042
}

variable "seed_jmx_port" {
  description = "Host port mapped to the seed container JMX port 7199."
  type        = number
  default     = 7199
}

variable "container_memory_mb" {
  description = "Memory limit per Cassandra container in MB."
  type        = number
  default     = 4096
}

variable "container_cpus" {
  description = "CPU limit per Cassandra container, equivalent to Docker Compose cpus."
  type        = string
  default     = "1.0"
}

variable "seed_bootstrap_wait" {
  description = "How long Terraform waits after starting the seed before creating non-seed nodes."
  type        = string
  default     = "180s"
}

variable "node_join_wait_seconds" {
  description = "Additional staggered wait per non-seed node before it is created."
  type        = number
  default     = 180
}

variable "volume_prefix" {
  description = "Prefix for Docker volumes that persist Cassandra data."
  type        = string
  default     = "cassandra-data"
}

variable "restart_policy" {
  description = "Docker restart policy for Cassandra containers."
  type        = string
  default     = "unless-stopped"
}

variable "enable_opscenter" {
  description = "Create a DataStax OpsCenter container on the Cassandra Docker network."
  type        = bool
  default     = true
}

variable "opscenter_image" {
  description = "Docker image for DataStax OpsCenter. Use a locally loaded/tagged IBM Fix Central image if the public image is unavailable."
  type        = string
  default     = "datastax/dse-opscenter:6.8.48"
}

variable "opscenter_container_name" {
  description = "OpsCenter container name and Docker DNS alias."
  type        = string
  default     = "opscenter"
}

variable "opscenter_ui_port" {
  description = "Host port mapped to the OpsCenter UI port 8888."
  type        = number
  default     = 8888
}

variable "opscenter_agent_port" {
  description = "Host port mapped to the OpsCenter agent STOMP communication port 61620."
  type        = number
  default     = 61620
}

variable "opscenter_persistent_volume" {
  description = "Persist OpsCenter state in a Docker volume."
  type        = bool
  default     = true
}

variable "opscenter_volume_name" {
  description = "Docker volume name for OpsCenter state."
  type        = string
  default     = "opscenter-data"
}

variable "opscenter_extra_env" {
  description = "Additional environment variables to pass to the OpsCenter container."
  type        = list(string)
  default     = []
}
