cassandra_image            = "datastax/dse-server:6.8.48"
cassandra_distribution     = "dse"
cluster_name               = "demo-cluster"
network_name               = "cassandra-network"
create_network             = true
seed_container_name        = "cassandra-seed"
node_container_name_prefix = "cassandra-node"

# Additional DSE nodes after the seed. Keep this at 0 for a single-node DSE cluster.
cassandra_node_count = 0

num_tokens    = 16
max_heap_size = "1g"
heap_new_size = "256m"
max_direct_memory_size = "512m"

seed_cql_port       = 9042
container_memory_mb = 2048
container_cpus      = "1.0"

seed_bootstrap_wait   = "30s"
node_join_wait_seconds = 30

volume_prefix  = "cassandra-data"
restart_policy = "unless-stopped"

enable_opscenter             = true
opscenter_image              = "datastax/dse-opscenter:6.8.48"
opscenter_container_name     = "opscenter"
opscenter_ui_port            = 8888
opscenter_agent_port         = 61620
opscenter_persistent_volume  = true
opscenter_volume_name        = "opscenter-data"
opscenter_extra_env          = []
