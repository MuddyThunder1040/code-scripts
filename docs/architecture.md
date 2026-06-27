# Homelab Architecture

## Machine Roles

| Machine        | Tailscale IP   | Role                                      |
|----------------|----------------|-------------------------------------------|
| MacBook Air M5 | 100.87.32.38   | Admin client — Terraform, Ansible, SSH    |
| Dell Laptop    | 100.87.212.105 | Infra node — always-on, runs core services|
| Desktop WSL2   | 100.64.213.62  | Compute node — data, AI, Kafka, databases |

## Service Placement

| Service           | Host    | Port(s)       |
|-------------------|---------|---------------|
| Traefik           | Dell    | 80, 443, 8080 |
| Prometheus        | Dell    | 9090          |
| Grafana           | Dell    | 3000          |
| Loki              | Dell    | 3100          |
| Alertmanager      | Dell    | 9093          |
| Jenkins           | Dell    | 8080, 50000   |
| Gitea             | Dell    | 3001, 222     |
| Docker Registry   | Dell    | 5000          |
| Portainer         | Dell    | 9000          |
| Cassandra (3-node)| Desktop | 9042          |
| PostgreSQL        | Desktop | 5432          |
| Redis             | Desktop | 6379          |
| MongoDB           | Desktop | 27017         |
| Kafka (KRaft)     | Desktop | 9092          |
| Kafka UI          | Desktop | 8090          |
| Ollama            | Desktop | 11434         |
| Open WebUI        | Desktop | 8080          |
| MinIO             | Desktop | 9000, 9001    |

## Network Topology

```
MacBook Air M5 (100.87.32.38)
        |
        |  Tailscale VPN (muddythunder1040.github)
        |
   +---------+---------------------------+
   |                                     |
Dell (100.87.212.105)          Desktop WSL2 (100.64.213.62)
tag:infra                      tag:compute
Docker: /data/docker           Docker: tcp://0.0.0.0:2375
Network: homelab-net           Networks: homelab-net, cass-net
```

ACL rules (managed via `terraform/tailscale/`):
- MacBook → everywhere (admin)
- Dell → Desktop: ports 22, 2375, 9100, 8888
- Desktop → Dell: ports 9090, 3000, 5000

## CI/CD Flow

```
GitHub (push to main)
        |
        | webhook
        v
GitHub Actions
        |
        |-- dell/** changed --> deploy-dell.yml
        |                       Runner: Dell self-hosted
        |                       Copies compose files, docker compose up -d
        |
        |-- desktop/** changed --> deploy-desktop.yml
        |                          Runner: Dell self-hosted
        |                          SSH to Desktop, copies files, up -d
        |
        |-- workflow_dispatch --> terraform-operations.yml
                                  Runner: Dell self-hosted
                                  Terraform plan/apply/destroy
                                  Target: desktop-wsl or dell
```

## Storage Strategy

**Dell** — bind mounts to `/data/services/<service>/` on HDD mounted at `/data`:
- Traefik config/certs, Prometheus data, Grafana data, Loki data
- Jenkins workspace, Gitea repos, Registry blobs, Portainer data

**Desktop** — named Docker volumes (WSL2 filesystem):
- Cassandra, PostgreSQL, MongoDB, Kafka, Ollama models, MinIO objects, Open WebUI data

**Docker data root** — Dell: `/data/docker` (HDD)
