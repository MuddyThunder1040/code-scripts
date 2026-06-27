variable "docker_host" {
  description = "Docker daemon host. Use tcp://100.64.213.62:2375 for Desktop WSL2 over Tailscale."
  type        = string
  default     = "tcp://100.64.213.62:2375"
}

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

variable "cassandra_jmx_port" {
  description = "Internal JMX/RMI port used by every Cassandra container."
  type        = number
  default     = 7199
}

variable "seed_jmx_port" {
  description = "Host port mapped to the seed container JMX port."
  type        = number
  default     = 7199
}

variable "jmx_host_bind_ip" {
  description = "Host interface used for published Cassandra JMX ports. Use 0.0.0.0 only when protected by firewall/VPN."
  type        = string
  default     = "127.0.0.1"
}

variable "node_1_jmx_port" {
  description = "Host port mapped to cassandra-node-1 JMX."
  type        = number
  default     = 7200
}

variable "node_2_jmx_port" {
  description = "Host port mapped to cassandra-node-2 JMX."
  type        = number
  default     = 7201
}

variable "node_3_jmx_port" {
  description = "Host port mapped to cassandra-node-3 JMX."
  type        = number
  default     = 7202
}

variable "node_4_jmx_port" {
  description = "Host port mapped to cassandra-node-4 JMX."
  type        = number
  default     = 7203
}

variable "node_5_jmx_port" {
  description = "Host port mapped to cassandra-node-5 JMX."
  type        = number
  default     = 7204
}

variable "node_6_jmx_port" {
  description = "Host port mapped to cassandra-node-6 JMX."
  type        = number
  default     = 7205
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

variable "reaper_image" {
  description = "Docker image used for Cassandra Reaper."
  type        = string
  default     = "thelastpickle/cassandra-reaper:latest"
}

variable "reaper_container_name" {
  description = "Name and Docker DNS alias for the Cassandra Reaper container."
  type        = string
  default     = "reaper"
}

variable "reaper_http_port" {
  description = "Host port mapped to the Reaper HTTP UI port 8080."
  type        = number
  default     = 8085
}

variable "reaper_volume_name" {
  description = "Docker volume name used for persistent Reaper local storage."
  type        = string
  default     = "cassandra-reaper-data"
}

variable "reaper_heap_size" {
  description = "JVM heap size for the Reaper process."
  type        = string
  default     = "1G"
}

variable "reaper_jmx_connection_timeout_seconds" {
  description = "Timeout in seconds for Reaper JMX connections to Cassandra nodes."
  type        = number
  default     = 20
}

variable "enable_reaper_cluster_registration" {
  description = "Whether Terraform should register the Cassandra cluster in Reaper through Reaper's REST API."
  type        = bool
  default     = true
}

variable "reaper_registration_image" {
  description = "One-shot curl image used to register the Cassandra cluster in Reaper from the Cassandra Docker network."
  type        = string
  default     = "curlimages/curl:8.8.0"
}

variable "reaper_cluster_registration_container_name" {
  description = "Name for the one-shot container that registers the Cassandra cluster in Reaper."
  type        = string
  default     = "reaper-register-cassandra"
}

variable "reaper_cluster_registration_wait" {
  description = "How long Terraform waits after Reaper and Cassandra containers are created before registering the cluster in Reaper."
  type        = string
  default     = "120s"
}

variable "reaper_registration_retries" {
  description = "Number of HTTP retries used while registering Cassandra in Reaper."
  type        = number
  default     = 30
}

variable "reaper_registration_retry_delay_seconds" {
  description = "Delay in seconds between Reaper registration HTTP retries."
  type        = number
  default     = 5
}
