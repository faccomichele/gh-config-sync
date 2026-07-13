# ---------------------------------------------------------------------------
# Repository discovery
# ---------------------------------------------------------------------------
# Fetches all non-archived repositories in the organization via GitHub Search.
# GitHub Search returns up to 1,000 results; for organizations with more repos
# consider supplementing with additional targeted queries.
data "github_repositories" "all" {
  query            = "org:${local.organization} archived:false"
  results_per_page = 100
}

# ---------------------------------------------------------------------------
# Local values — parse config, compute targets, flatten child resources
# ---------------------------------------------------------------------------
locals {
  # ── Configuration file ────────────────────────────────────────────────────
  config   = yamldecode(file(var.config_file))
  defaults = lookup(local.config, "defaults", {})

  # Index per-repository config blocks by repository name for O(1) lookup.
  repo_overrides = {
    for r in lookup(local.config, "repositories", []) : r.name => r
  }

  # ── Target repository set ─────────────────────────────────────────────────
  all_discovered = toset(data.github_repositories.all.names)

  # Prefix filters can come from the YAML config or from the Terraform var.
  repo_filters = length(var.repo_filter) > 0 ? var.repo_filter : lookup(local.config, "filter", [])

  # When filters are set, restrict to repositories whose names start with one
  # of the accepted prefixes; otherwise operate on the full discovered set.
  target_repo_names = length(local.repo_filters) > 0 ? toset(flatten([
    for prefix in local.repo_filters : [
      for name in local.all_discovered : name
      if startswith(name, prefix)
    ]
  ])) : local.all_discovered

  # ── Merged per-repository configurations ─────────────────────────────────
  # Repositories explicitly listed in the YAML 'repositories' section AND
  # present in the organization.  These get full Terraform management
  # (core settings, labels, environments, rulesets).
  explicitly_configured = {
    for name in local.target_repo_names :
    name => merge(local.defaults, local.repo_overrides[name])
    if contains(keys(local.repo_overrides), name)
  }

  # All target repositories with defaults merged.
  # Used for child resources (labels) that apply org-wide.
  all_target_repos = {
    for name in local.target_repo_names : name => merge(
      local.defaults,
      lookup(local.repo_overrides, name, {})
    )
  }

  # ── Flattened child-resource maps ─────────────────────────────────────────
  # Labels are applied to ALL discovered repositories (defaults + per-repo).
  # Key format: "<repo_name>/<label_name>"
  all_labels = merge([
    for repo_name, repo_cfg in local.all_target_repos : {
      for lbl in lookup(repo_cfg, "labels", []) :
      "${repo_name}/${lbl.name}" => merge(lbl, { repo = repo_name })
    }
  ]...)

  # Environments are configured for ALL target repositories.
  # Default environments (defined in 'defaults.environments') apply to every
  # discovered repository; per-repo entries override them entirely for that repo.
  # Key format: "<repo_name>/<environment_name>"
  all_environments = merge([
    for repo_name, repo_cfg in local.all_target_repos : {
      for env in lookup(repo_cfg, "environments", []) :
      "${repo_name}/${env.name}" => merge(env, { repo = repo_name })
    }
  ]...)

  # Rulesets are configured for ALL target repositories.
  # Default rulesets (defined in 'defaults.rulesets') apply to every discovered
  # repository; per-repo entries override them entirely for that repo.
  # Key format: "<repo_name>/<ruleset_name>"
  all_rulesets = merge([
    for repo_name, repo_cfg in local.all_target_repos : {
      for rs in lookup(repo_cfg, "rulesets", []) :
      "${repo_name}/${rs.name}" => merge(rs, { repo = repo_name })
    }
  ]...)
}
