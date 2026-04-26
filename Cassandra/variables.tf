variable "cassandra_image" {
  description = "Docker image used for all Cassandra containers."
  type        = string
  default     = "cassandra:4.1"
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

variable "seed_cql_port" {
  description = "Host port mapped to the seed container CQL port 9042."
  type        = number
  default     = 9042
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
