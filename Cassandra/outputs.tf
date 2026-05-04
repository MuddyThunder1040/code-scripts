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
  value       = "docker exec ${docker_container.seed.name} nodetool -h ${docker_container.seed.name} -p 7199 status"
}

output "docker_network_name" {
  description = "Docker network shared by Cassandra and OpsCenter."
  value       = local.cassandra_network_name
}

output "cassandra_node_hostnames" {
  description = "Docker DNS names OpsCenter can use to reach Cassandra nodes."
  value       = local.cassandra_node_hostnames
}

output "opscenter_ui_url" {
  description = "OpsCenter UI URL on the Docker host."
  value       = var.enable_opscenter ? "http://127.0.0.1:${var.opscenter_ui_port}" : null
}

output "opscenter_agent_endpoint" {
  description = "Endpoint DataStax agents use for OpsCenter STOMP communication."
  value       = var.enable_opscenter ? "${var.opscenter_container_name}:61620" : null
}

output "opscenter_add_cluster_hosts" {
  description = "Use these Docker DNS names in OpsCenter when adding the existing Cassandra cluster."
  value       = local.cassandra_node_hostnames
}

output "opscenter_debug_commands" {
  description = "Useful commands for checking OpsCenter connectivity."
  value = var.enable_opscenter ? [
    "docker logs ${var.opscenter_container_name}",
    "docker exec ${var.opscenter_container_name} sh -lc 'getent hosts ${var.seed_container_name} && nc -vz ${var.seed_container_name} 9042'",
    "docker exec ${docker_container.seed.name} nodetool -h ${docker_container.seed.name} -p 7199 status"
  ] : []
}
