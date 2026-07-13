variable "tags" {
  description = "Map of tags to assign to resources"
  type        = map(string)
}

variable "github_token" {
  description = "GitHub Personal Access Token used for authentication. Required scopes: repo, admin:org."
  type        = string
  sensitive   = true
}

variable "config_file" {
  description = "Path to the YAML configuration file that defines the desired state for repositories."
  type        = string
  default     = "config/repos.yaml"
}

variable "repo_filter" {
  description = <<-EOT
    Optional: restrict Terraform to repositories whose names start with one
    or more prefixes.
    Useful for testing changes before rolling them out to the whole organization.
    Leave as [] (default) to process all discovered repositories.
  EOT
  type        = list(string)
  default     = []
}
