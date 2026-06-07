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

output "cassandra_seed_ip" {
  description = "Seed container IP address on the Cassandra Docker network."
  value       = docker_container.seed.network_data[0].ip_address
}

output "cassandra_seed_jmx_port" {
  description = "Host JMX port mapped to the Cassandra seed container."
  value       = var.seed_jmx_port
}

output "reaper_url" {
  description = "Host URL for the Cassandra Reaper UI."
  value       = "http://127.0.0.1:${var.reaper_http_port}/webui/"
}

output "reaper_cluster_registration_endpoint" {
  description = "Reaper API endpoint used to register or refresh the Cassandra cluster."
  value       = "http://${var.reaper_container_name}:8080/cluster?seedHost=${var.seed_container_name}&jmxPort=${var.cassandra_jmx_port}"
}

output "reaper_host_cluster_registration_command" {
  description = "Host command to manually register or refresh the Cassandra cluster in Reaper."
  value       = "curl --fail --show-error --request POST 'http://127.0.0.1:${var.reaper_http_port}/cluster?seedHost=${var.seed_container_name}&jmxPort=${var.cassandra_jmx_port}'"
}

output "reaper_host_cluster_list_command" {
  description = "Host command to list clusters registered in Reaper."
  value       = "curl --fail --show-error 'http://127.0.0.1:${var.reaper_http_port}/cluster'"
}

output "cassandra_network_name" {
  description = "Docker network used by Cassandra, Reaper, and future monitoring containers."
  value       = docker_network.cassandra.name
}

output "nodetool_status_command" {
  description = "Command to verify cluster status from the self-hosted runner."
  value       = "docker exec ${docker_container.seed.name} nodetool status"
}
