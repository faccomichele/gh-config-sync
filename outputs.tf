output "discovered_repositories" {
  description = "All non-archived repositories discovered in the organization."
  value       = sort(tolist(local.all_discovered))
}

output "managed_repositories" {
  description = "Repositories fully managed by Terraform (listed in the 'repositories' config section)."
  value       = sort(keys(local.explicitly_configured))
}

output "label_managed_repositories" {
  description = "Repositories whose labels are managed by Terraform (all discovered repos)."
  value       = sort(keys(local.all_target_repos))
}

output "repo_filter_active" {
  description = "Whether one or more repository prefix filters are currently active."
  value       = length(local.repo_filters) > 0
}

output "active_repo_filter" {
  description = "The repository name prefixes used as filters, or null when no filter is active."
  value       = length(local.repo_filters) > 0 ? local.repo_filters : null
}
