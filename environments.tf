# ---------------------------------------------------------------------------
# Environment management
# ---------------------------------------------------------------------------
# Environments are configured for ALL discovered repositories.
# Default environments defined under 'defaults.environments' in
# config/repos.yaml are applied to every repository automatically.
# Per-repository 'environments' entries override the defaults entirely for
# that specific repository.
#
# Note: the 'reviewers.users' and 'reviewers.teams' fields accept numeric IDs,
# not usernames/team slugs. Retrieve them via the GitHub API.
resource "github_repository_environment" "environments" {
  for_each = local.all_environments

  repository          = each.value.repo
  environment         = each.value.name
  wait_timer          = lookup(each.value, "wait_timer", null)
  can_admins_bypass   = lookup(each.value, "can_admins_bypass", null)
  prevent_self_review = lookup(each.value, "prevent_self_review", null)

  # dynamic "reviewers" {
  #   for_each = (
  #     lookup(each.value, "reviewers", null) != null
  #     && (
  #       length(lookup(each.value.reviewers, "users", [])) > 0
  #       || length(lookup(each.value.reviewers, "teams", [])) > 0
  #       || (lookup(each.value.reviewers, "current", false) && var.current_reviewer_user_id != null)
  #     )
  #   ) ? [each.value.reviewers] : []
  #   content {
  #     users = concat(
  #       lookup(reviewers.value, "users", []),
  #       (lookup(reviewers.value, "current", false) && var.current_reviewer_user_id != null) ? [var.current_reviewer_user_id] : []
  #     )
  #     teams = lookup(reviewers.value, "teams", [])
  #   }
  # }

  dynamic "deployment_branch_policy" {
    for_each = lookup(each.value, "deployment_branch_policy", null) != null ? [each.value.deployment_branch_policy] : []
    content {
      protected_branches     = lookup(deployment_branch_policy.value, "protected_branches", true)
      custom_branch_policies = lookup(deployment_branch_policy.value, "custom_branch_policies", false)
    }
  }

  depends_on = [github_repository.repos]
}
