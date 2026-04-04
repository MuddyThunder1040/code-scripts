variable "cas_network" {
    default = "cassandra-network"
    type = string
    description = "The name of the Docker network for Cassandra containers"
}