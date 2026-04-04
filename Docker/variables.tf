variable "cas_network" {
    default = "cassandra-network"
    type = string
    description = "The name of the Docker network for Cassandra containers"
}
variable "seed_node_cont" {
    default = 1
    type = number
    description = "The number of seed nodes to create for the Cassandra cluster"
}
variable "non_seed_node_count" {
    default = 3
    type = number
    description = "The number of non-seed nodes to create for the Cassandra cluster"
}