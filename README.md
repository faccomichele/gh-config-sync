# gh-config-sync

> Terraform-based IaC that keeps all repository settings for a GitHub organization in sync.

## Overview

`gh-config-sync` uses Terraform with the official GitHub provider to:

1. **Discover** all non-archived repositories in a GitHub organization automatically.
2. **Read** a YAML configuration file (`config/repos.yaml`) that defines the desired state.
3. **Detect and apply drift** — repository settings, labels, environments, and rulesets.
4. **Filter** to repositories by prefix for safe, incremental testing.
5. **Enable CodeQL scanning** by managing a standard workflow file in target repositories.

## Prerequisites

| Tool | Minimum Version |
|------|----------------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | 1.7.0 |
| [GitHub Terraform Provider](https://registry.terraform.io/providers/integrations/github/latest) | ~> 6.0 |
| GitHub PAT | scopes: `repo`, `admin:org` |

## Quick Start

### 1. Configure credentials

```sh
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set github_token and org_name
```

Or use environment variables (recommended for CI):

```sh
export TF_VAR_github_token="ghp_..."
export TF_VAR_org_name="my-organization"
```

### 2. Customize the configuration

Edit `config/repos.yaml` to describe your desired repository state.  
See [Configuration Reference](#configuration-reference) below for all available options.

### 3. Initialize Terraform

```sh
terraform init
```

### 4. Preview changes

```sh
terraform plan
```

On the **first run**, Terraform automatically imports every repository discovered  
in the organization into Terraform state.

### 5. Apply changes

```sh
terraform apply
```

### Test against a single repository

Use `repo_filter` to limit the scope to repositories whose names start with one
or more prefixes before rolling out org-wide:

```sh
terraform plan  -var='repo_filter=["aws-", "gh-", "gha-"]'
terraform apply -var='repo_filter=["aws-", "gh-", "gha-"]'
```

---

## Repository Management Model

| Feature | All discovered repos | Repos in `repositories` section |
|---------|---------------------|----------------------------------|
| Core settings (visibility, features, merge strategy) | ✅ Enforced (from `defaults`) | ✅ Enforced (per-repo overrides) |
| Labels | ✅ Enforced (from `defaults.labels`) | ✅ Enforced (per-repo overrides) |
| Environments | ✅ Enforced (from `defaults.environments`) | ✅ Enforced (per-repo overrides) |
| Rulesets | ✅ Enforced (from `defaults.rulesets`) | ✅ Enforced (per-repo overrides) |

---

## Configuration Reference

The configuration file is `config/repos.yaml` (path overridable via `var.config_file`).

### Top-level structure

```yaml
defaults:      # applied to ALL repos; per-repo sections override these
  ...

repositories:  # explicit per-repo configuration
  - name: "repo-name"
    ...
```

### `defaults` — global settings

| Key | Type | Description |
|-----|------|-------------|
| `has_issues` | bool | Enable the Issues tab |
| `has_discussions` | bool | Enable Discussions |
| `has_projects` | bool | Enable Projects |
| `has_wiki` | bool | Enable the Wiki |
| `has_downloads` | bool | Enable Downloads (legacy) |
| `is_template` | bool | Mark as a template repository |
| `allow_merge_commit` | bool | Allow merge commits |
| `allow_squash_merge` | bool | Allow squash merges |
| `allow_rebase_merge` | bool | Allow rebase merges |
| `allow_auto_merge` | bool | Allow auto-merge |
| `delete_branch_on_merge` | bool | Delete head branch after merge |
| `allow_update_branch` | bool | Show "Update branch" button |
| `vulnerability_alerts` | bool | Enable Dependabot alerts |
| `labels` | list | Default label set (see below) |
| `environments` | list | Default environments applied to every repo (see below) |
| `rulesets` | list | Default rulesets applied to every repo (see below) |

### `repositories[*]` — per-repo overrides

Every key from `defaults` is available here and takes precedence.  
For list fields (`labels`, `environments`, `rulesets`) the per-repo list **replaces** the defaults entirely for that repository.  
Additional per-repo keys:

| Key | Type | Description |
|-----|------|-------------|
| `name` | string | **Required.** Repository name |
| `description` | string | Repository description |
| `homepage_url` | string | Homepage / website URL |
| `visibility` | string | `"public"` \| `"private"` \| `"internal"` |
| `topics` | list(string) | Repository topics |
| `archived` | bool | Archive the repository |
| `labels` | list | Repo-specific labels (**replaces** `defaults.labels` entirely) |
| `environments` | list | Repo-specific environments (**replaces** `defaults.environments` entirely) |
| `rulesets` | list | Repo-specific rulesets (**replaces** `defaults.rulesets` entirely) |

### Labels

```yaml
labels:
  - name: "bug"
    color: "d73a4a"        # hex color, with or without '#'
    description: "..."     # optional
```

Labels are **fully enforced**: any label not present in the effective configuration  
(defaults merged with per-repo overrides) will be **deleted** from the repository.

> **Note:** Labels created outside Terraform are not automatically removed unless  
> they are first imported:  
> `terraform import 'github_issue_label.labels["repo/label"]' 'repo:label'`

### Environments

```yaml
environments:
  - name: "production"
    wait_timer: 30               # minutes to wait before deployment
    can_admins_bypass: false
    prevent_self_review: true
    reviewers:
      users: [12345678]          # numeric GitHub user IDs
      teams: [87654321]          # numeric GitHub team IDs
    deployment_branch_policy:
      protected_branches: true
      custom_branch_policies: false
```

### Rulesets

```yaml
rulesets:
  - name: "main-branch-protection"
    target: "branch"             # "branch" | "tag"
    enforcement: "active"        # "active" | "evaluate" | "disabled"
    conditions:
      ref_name:
        include: ["~DEFAULT_BRANCH"]
        exclude: []
    bypass_actors:
      - actor_id: 1
        actor_type: "OrganizationAdmin"   # RepositoryRole | Team | Integration | OrganizationAdmin
        bypass_mode: "always"
    rules:
      creation: false
      deletion: true
      non_fast_forward: true
      required_linear_history: false
      required_signatures: false
      update: false
      update_allows_fetch_and_merge: false
      pull_request:
        required_approving_review_count: 1
        dismiss_stale_reviews_on_push: true
        require_code_owner_review: false
        require_last_push_approval: false
        required_review_thread_resolution: true
      required_status_checks:
        strict_required_status_checks_policy: false
        required_checks:
          - context: "ci / build"
          - context: "ci / test"
      required_deployments:
        environments: ["staging"]
      branch_name_pattern:       # branch rulesets only
        operator: "starts_with"  # starts_with | ends_with | contains | regex
        pattern: "feat/"
        negate: false
      tag_name_pattern:          # tag rulesets only
        operator: "regex"
        pattern: "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
      commit_message_pattern:
        operator: "contains"
        pattern: "[skip ci]"
        negate: true
      commit_author_email_pattern:
        operator: "ends_with"
        pattern: "@example.com"
      committer_email_pattern:
        operator: "ends_with"
        pattern: "@example.com"
```

---

## Variables Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `github_token` | string | — | GitHub PAT (sensitive) |
| `org_name` | string | — | GitHub organization name |
| `repo_filter` | list(string) | `[]` | Limit to repositories matching one or more name prefixes; empty = all repos |
| `current_reviewer_user_id` | number | `null` | Optional user ID used when `reviewers.current=true`; required for GitHub App IAT auth |
| `config_file` | string | `"config/repos.yaml"` | Path to YAML config |

---

## State Management

### First-time setup

Repositories listed in the `repositories` section are **automatically imported** into  
Terraform state on the first `terraform plan` (Terraform 1.7+ `import` blocks with  
`for_each`).  No manual `terraform import` is required.

### Removing a repository from management

Managed repositories have `prevent_destroy = true` to prevent accidental deletion.  
To stop managing a repository without deleting it from GitHub:

```sh
terraform state rm 'github_repository.repos["repo-name"]'
```

### Large organizations

The `github_repositories` data source uses the GitHub Search API, which returns up  
to 1 000 results.  For organizations with more repositories, consider splitting the  
configuration into multiple Terraform workspaces filtered by naming convention.

---

## Remote Backend (recommended for teams)

Add a `backend` block to `providers.tf`, or create `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "gh-config-sync/terraform.tfstate"
    region = "us-east-1"
  }
}
```

---

## Security Notes

- `terraform.tfvars` is excluded from version control by `.gitignore`.
- **Never commit** your GitHub PAT to source control.
- For CI/CD, export the token as `TF_VAR_github_token` via a secrets manager or  
  GitHub Actions secrets.
- The minimum required PAT scopes are `repo` and `admin:org`.

### Enable Private Vulnerability Reporting

The Terraform GitHub provider (v6.12.0 in this repo) does not currently expose
the `private_vulnerability_reporting` setting on `github_repository`, so this
toggle cannot be managed declaratively in Terraform yet.

Use the script below to enable it for all non-archived repositories in an org,
optionally filtered by name prefixes:

PowerShell example:

scripts/enable-private-vulnerability-reporting.ps1 \
  -Organization "my-organization" \
  -Token "$env:TF_VAR_github_token" \
  -Prefixes "aws-","gh-","gha-"

---

## File Structure

```
.
├── config/
│   └── repos.yaml            # YAML configuration (desired state)
├── providers.tf              # Terraform + GitHub provider configuration
├── variables.tf              # Input variables
├── main.tf                   # Discovery data source + local computations
├── repos.tf                  # github_repository resources + import blocks
├── labels.tf                 # github_issue_label resources
├── environments.tf           # github_repository_environment resources
├── rulesets.tf               # github_repository_ruleset resources
├── outputs.tf                # Useful outputs
└── terraform.tfvars.example  # Example variable values
```
