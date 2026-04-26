# code-scripts

[![Terraform Operations](https://github.com/MuddyThunder1040/code-scripts/actions/workflows/terraform-operations.yml/badge.svg)](https://github.com/MuddyThunder1040/code-scripts/actions/workflows/terraform-operations.yml)

Terraform and automation scripts for local/self-hosted infrastructure experiments.

## Modules

| Module | Purpose |
| --- | --- |
| `Cassandra` | Builds a Docker-based Cassandra cluster with one seed node and configurable non-seed nodes. |
| `Docker` | Docker provider examples and Cassandra container resources. |
| `Local` | Local Terraform examples. |

## Terraform Workflow

Use the **Terraform Operations** GitHub Actions workflow to run Terraform from the self-hosted runner.

Workflow inputs:

| Input | Values |
| --- | --- |
| `module` | `Cassandra`, `Local`, `Docker`, `S3` |
| `branch` | Branch to check out, for example `dev` |
| `action` | `init`, `validate`, `plan`, `apply`, `show`, `destroy` |

For Cassandra, run:

```text
module: Cassandra
branch: dev
action: apply
```

The workflow installs Terraform `1.5.7`, initializes the selected module, applies or destroys when requested, and sends Slack notifications for `apply` and `destroy`.

## Cassandra Cluster

The `Cassandra` module creates:

- Docker network: `cassandra-network`
- Seed container: `cassandra-seed`
- Non-seed containers: `cassandra-node-1` through `cassandra-node-5` by default
- Persistent volumes: `cassandra-data-seed` and `cassandra-data-node-*`
- CQL endpoint: `127.0.0.1:9042`

The cluster is configured in `Cassandra/terraform.tfvars`:

```hcl
cassandra_image      = "cassandra:4.1"
cluster_name         = "demo-cluster"
cassandra_node_count = 5
num_tokens           = 16
max_heap_size        = "2G"
heap_new_size        = "512M"
```

Nodes are started sequentially with a wait between joins so Cassandra forms a complete ring reliably.

## Verify Cassandra

After `apply`, check the ring from any Cassandra container:

```bash
docker exec cassandra-node-1 nodetool status
```

A healthy 1 seed + 5 node cluster should show 6 rows with `UN`, meaning each node is up and normal.

You can also check containers:

```bash
docker ps -a --filter "name=cassandra"
```

## Cleanup

To remove the Cassandra cluster through Terraform, run the workflow with:

```text
module: Cassandra
branch: dev
action: destroy
```

On `apply`, the workflow removes old Cassandra containers, `cassandra-network`, and `cassandra-data-*` volumes before recreating the cluster. This prevents stale Cassandra data from causing nodes to join incorrectly.
