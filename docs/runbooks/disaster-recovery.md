# Disaster Recovery Runbook

## Dell Failure

1. Reinstall Ubuntu on Dell.
2. Install Docker, set data root to `/data/docker` in `/etc/docker/daemon.json`:
   ```json
   { "data-root": "/data/docker" }
   ```
3. Mount HDD at `/data` (update `/etc/fstab`).
4. Install Tailscale and rejoin the tailnet:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up --authkey <dell-auth-key>
   ```
   Auth key: `terraform output -raw dell_auth_key` from `terraform/tailscale/`.
5. Clone the repo:
   ```bash
   git clone https://github.com/MuddyThunder1040/code-scripts ~/projects/code-scripts
   ```
6. Run bootstrap playbook from MacBook:
   ```bash
   ansible-playbook -i ansible/inventory.yml ansible/playbooks/bootstrap-dell.yml
   ```
7. Deploy services:
   ```bash
   ansible-playbook -i ansible/inventory.yml ansible/playbooks/deploy-proxy.yml
   ansible-playbook -i ansible/inventory.yml ansible/playbooks/deploy-monitoring.yml
   ansible-playbook -i ansible/inventory.yml ansible/playbooks/deploy-ci.yml
   ```
8. Re-register Dell self-hosted runner:
   ```bash
   cd ~/actions-runner && ./config.sh --url https://github.com/MuddyThunder1040/code-scripts --token <runner-token>
   sudo ./svc.sh install && sudo ./svc.sh start
   ```

---

## Desktop WSL2 Reset

1. Reinstall WSL2 Ubuntu or reset the distro.
2. Enable systemd in `/etc/wsl.conf`:
   ```ini
   [boot]
   systemd=true
   ```
3. Install Docker Engine.
4. Install Tailscale and rejoin:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up --authkey <desktop-auth-key>
   ```
   Auth key: `terraform output -raw desktop_auth_key` from `terraform/tailscale/`.
5. Run bootstrap playbook from MacBook:
   ```bash
   ansible-playbook -i ansible/inventory.yml ansible/playbooks/bootstrap-desktop.yml
   ```
6. Bring up services manually or trigger `deploy-desktop.yml` via GitHub Actions.

---

## Full Rebuild From Scratch

1. Follow **Dell Failure** steps above.
2. Follow **Desktop WSL2 Reset** steps above.
3. From MacBook, run Tailscale Terraform to regenerate auth keys:
   ```bash
   cd terraform/tailscale
   terraform init && terraform apply
   ```
4. Re-apply Cassandra Terraform if needed:
   ```bash
   cd Cassandra
   terraform init && terraform apply
   ```
5. Verify cluster health:
   ```bash
   docker exec cassandra-seed nodetool status
   ```
