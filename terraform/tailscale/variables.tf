variable "tailscale_api_key" {
  description = "Tailscale API key. Pass via TF_VAR_tailscale_api_key env var — never hardcode."
  type        = string
  sensitive   = true
}

variable "tailnet_name" {
  description = "Tailnet name (organization)."
  type        = string
  default     = "muddythunder1040.github"
}
