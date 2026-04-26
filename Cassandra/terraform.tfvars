cassandra_image            = "cassandra:4.1"
cluster_name               = "demo-cluster"
network_name               = "cassandra-network"
seed_container_name        = "cassandra-seed"
node_container_name_prefix = "cassandra-node"

# Same as MAX_NODES in your bash script: additional nodes after the seed.
cassandra_node_count = 5

num_tokens    = 16
max_heap_size = "2G"
heap_new_size = "512M"

seed_cql_port       = 9042
container_memory_mb = 4096
container_cpus      = "1.0"

seed_bootstrap_wait   = "180s"
node_join_wait_seconds = 180

volume_prefix  = "cassandra-data"
restart_policy = "unless-stopped"
