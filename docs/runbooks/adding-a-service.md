# Adding a New Service

## 1. Choose the host and create the compose file

**Dell** — put it under `dell/services/<service-name>/compose.yml`  
**Desktop** — put it under `desktop/services/<service-name>/compose.yml`

## 2. Add Traefik labels (Dell services only)

Every Dell service that needs HTTP access via `homelab.local` needs these labels:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<service>.rule=Host(`<service>.homelab.local`)"
  - "traefik.http.services.<service>.loadbalancer.server.port=<internal-port>"
```

And join `homelab-net`:

```yaml
networks:
  - homelab-net

networks:
  homelab-net:
    external: true
```

## 3. Add Prometheus scrape config

Edit `dell/services/monitoring/prometheus.yml` and add a job:

```yaml
  - job_name: <service-name>
    static_configs:
      - targets: ['<host-ip>:<metrics-port>']
        labels:
          host: <dell|desktop-wsl2>
```

Then redeploy monitoring: `ansible-playbook -i ansible/inventory.yml ansible/playbooks/deploy-monitoring.yml`

## 4. Update bootstrap playbook (if new bind-mount dirs needed)

If the service needs a directory on Dell's HDD, add it to the `loop` in `ansible/playbooks/bootstrap-dell.yml` under "Create /data/services subdirectories".

For Desktop, add to the loop in `bootstrap-desktop.yml`.

## 5. Trigger deployment via GitHub Actions

**Option A — push to main:**  
Committing compose files under `dell/**` or `desktop/**` automatically triggers `deploy-dell.yml` or `deploy-desktop.yml`.

**Option B — manual dispatch:**  
Go to Actions → `Deploy Dell Services` or `Deploy Desktop Services` → Run workflow.

## 6. Verify

```bash
# Dell
docker ps | grep <service>
curl http://<service>.homelab.local

# Desktop
ssh vishnu@100.64.213.62 "docker ps | grep <service>"
```
