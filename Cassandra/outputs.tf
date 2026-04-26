output "seed_container_name" {
  description = "Seed container used for CQL and nodetool checks."
  value       = docker_container.seed.name
}

output "node_container_names" {
  description = "Non-seed Cassandra containers."
  value = concat(
    docker_container.node_1[*].name,
    docker_container.node_2[*].name,
    docker_container.node_3[*].name,
    docker_container.node_4[*].name,
    docker_container.node_5[*].name,
    docker_container.node_6[*].name
  )
}

output "cql_endpoint" {
  description = "Host CQL endpoint for the Cassandra seed."
  value       = "127.0.0.1:${var.seed_cql_port}"
}

output "nodetool_status_command" {
  description = "Command to verify cluster status from the self-hosted runner."
  value       = "docker exec ${docker_container.seed.name} nodetool status"
}
