output "default_branch" {
  description = "Default branch name"
  value       = one([for default in github_branch_default.this : default.branch])
}

output "node_id" {
  description = "GraphQL global node id for use with v4 API"
  value       = github_repository.this.node_id
}
