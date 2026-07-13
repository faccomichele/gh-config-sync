# ---------------------------------------------------------------------------
# CodeQL workflow management
# ---------------------------------------------------------------------------
# This creates a standard CodeQL workflow file in every target repository so
# code scanning is actually enabled (not only required by rulesets).
resource "github_repository_file" "codeql_workflow" {
  for_each = local.all_target_repos

  repository          = each.key
  file                = ".github/workflows/codeql.yml"
  overwrite_on_create = true
  commit_message      = "chore(security): manage CodeQL workflow via Terraform"

  content = <<-EOT
    name: "CodeQL"

    on:
      pull_request:
        branches: ["main"]
      schedule:
        - cron: "30 2 * * 0"

    permissions:
      actions: read
      contents: read
      security-events: write

    jobs:
      analyze:
        name: Analyze
        runs-on: ubuntu-latest

        steps:
          - name: Checkout repository
            uses: actions/checkout@v4

          - name: Initialize CodeQL
            uses: github/codeql-action/init@v3

          - name: Autobuild
            uses: github/codeql-action/autobuild@v3

          - name: Perform CodeQL Analysis
            uses: github/codeql-action/analyze@v3
  EOT

  depends_on = [github_repository.repos]
}
