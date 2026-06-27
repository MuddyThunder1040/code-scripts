terraform {
  required_version = ">= 1.5.0"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.17"
    }
  }
}

provider "tailscale" {
  api_key = var.tailscale_api_key
  tailnet  = var.tailnet_name
}

resource "tailscale_acl" "homelab" {
  acl = jsonencode({
    tagOwners = {
      "tag:infra"    = ["autogroup:owner"]
      "tag:compute"  = ["autogroup:owner"]
      "tag:admin"    = ["autogroup:owner"]
    }

    acls = [
      # MacBook admin can reach everything
      {
        action = "accept"
        src    = ["100.87.32.38"]
        dst    = ["*:*"]
      },
      # tag:infra (Dell) can reach tag:compute (Desktop) on specified ports
      {
        action = "accept"
        src    = ["tag:infra"]
        dst    = ["tag:compute:22", "tag:compute:2375", "tag:compute:9100", "tag:compute:8888"]
      },
      # tag:compute (Desktop) can reach tag:infra (Dell) on specified ports
      {
        action = "accept"
        src    = ["tag:compute"]
        dst    = ["tag:infra:9090", "tag:infra:3000", "tag:infra:5000"]
      },
    ]
  })
}

resource "tailscale_tailnet_key" "dell" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  description   = "Dell infra node auth key"
  tags          = ["tag:infra"]
}

resource "tailscale_tailnet_key" "desktop" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  description   = "Desktop WSL2 compute node auth key"
  tags          = ["tag:compute"]
}

output "dell_auth_key" {
  value     = tailscale_tailnet_key.dell.key
  sensitive = true
}

output "desktop_auth_key" {
  value     = tailscale_tailnet_key.desktop.key
  sensitive = true
}
