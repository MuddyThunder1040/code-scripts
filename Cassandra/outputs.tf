output "seed_container_name" {
  description = "Seed container used for CQL and nodetool checks."
  value       = docker_container.seed.name
}

output "node_container_names" {
  description = "Non-seed Cassandra containers."
  value       = docker_container.node[*].name
}

output "cql_endpoint" {
  description = "Host CQL endpoint for the Cassandra seed."
  value       = "127.0.0.1:${var.seed_cql_port}"
}

output "nodetool_status_command" {
  description = "Command to verify cluster status from the self-hosted runner."
  value       = "docker exec ${docker_container.seed.name} nodetool status"
}
