variable "docker_host" {
  description = "Docker daemon host. Defaults to Dell's local socket."
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "portainer_image" {
  description = "Portainer CE image."
  type        = string
  default     = "portainer/portainer-ce:latest"
}

variable "data_dir" {
  description = "Host path for Portainer data persistence."
  type        = string
  default     = "/data/services/portainer"
}
