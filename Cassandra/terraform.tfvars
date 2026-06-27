docker_host              = "tcp://100.64.213.62:2375"
cassandra_image          = "cassandra:5.0"
cluster_name             = "demo-cluster"
network_name             = "cassandra-network"
seed_container_name      = "cassandra-seed"
node_container_name_prefix = "cassandra-node"

# Same as MAX_NODES in your bash script: additional nodes after the seed.
cassandra_node_count = 2

num_tokens    = 16
max_heap_size = "512M"
heap_new_size = "128M"

seed_cql_port       = 9042
cassandra_jmx_port  = 7199
seed_jmx_port       = 7199
jmx_host_bind_ip    = "0.0.0.0"
node_1_jmx_port     = 7200
node_2_jmx_port     = 7201
node_3_jmx_port     = 7202
node_4_jmx_port     = 7203
node_5_jmx_port     = 7204
node_6_jmx_port     = 7205
container_memory_mb = 1024
container_cpus      = "1.0"

seed_bootstrap_wait    = "120s"
node_join_wait_seconds = 90

volume_prefix  = "cassandra-data"
restart_policy = "unless-stopped"

reaper_image                          = "thelastpickle/cassandra-reaper:latest"
reaper_container_name                 = "reaper"
reaper_http_port                      = 8085
reaper_volume_name                    = "cassandra-reaper-data"
reaper_heap_size                      = "256M"
reaper_jmx_connection_timeout_seconds = 20

enable_reaper_cluster_registration         = true
reaper_registration_image                  = "curlimages/curl:8.8.0"
reaper_cluster_registration_container_name = "reaper-register-cassandra"
reaper_cluster_registration_wait           = "120s"
reaper_registration_retries                = 30
reaper_registration_retry_delay_seconds    = 5
