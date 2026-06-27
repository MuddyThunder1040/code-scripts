variable "docker_host" {
  description = "Docker daemon host. Defaults to Dell's local socket."
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "traefik_image" {
  description = "Traefik image."
  type        = string
  default     = "traefik:v3"
}
