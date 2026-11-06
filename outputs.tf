################################################################################
# Service account
#
# Outputs are wrapped in `try()` so they still evaluate to an empty value when
# `create_service_account = false` leaves no resource to reference.
#
# Attributes that are optional in the provider schema are additionally
# null-guarded: the provider returns null — not an empty value — when nothing is
# assigned, and `try()` only catches errors, so it passes a null straight
# through. Without this a consumer gets null from `namespace_accesses` on an
# account-scoped service account, and `length()` on it fails.
################################################################################

output "service_account_id" {
  description = "The unique identifier of the service account. This is the value to pass as `owner_id` when issuing API keys for it elsewhere"
  value       = try(temporalcloud_service_account.this[0].id, "")
}

output "service_account_name" {
  description = "The name of the service account"
  value       = try(temporalcloud_service_account.this[0].name, "")
}

output "service_account_state" {
  description = "The current state of the service account as reported by Temporal Cloud"
  value       = try(temporalcloud_service_account.this[0].state, "")
}

output "service_account_account_access" {
  description = "The account-level role held by the service account. Empty for a namespace-scoped service account"
  value       = try(coalesce(temporalcloud_service_account.this[0].account_access, ""), "")
}

output "service_account_namespace_accesses" {
  description = "The set of per-namespace permissions granted to the service account. Empty when none are granted"
  value       = try(coalesce(temporalcloud_service_account.this[0].namespace_accesses, toset([])), toset([]))
}

output "service_account_namespace_scoped_access" {
  description = "The single namespace the service account is confined to, and its permission there. Empty unless `namespace_scoped_access` was set"
  # A conditional rather than coalesce(): coalesce requires its arguments to
  # share a type, and this attribute is an object rather than a collection.
  value = try(temporalcloud_service_account.this[0].namespace_scoped_access == null ? {} : temporalcloud_service_account.this[0].namespace_scoped_access, {})
}

################################################################################
# API key
################################################################################

output "apikey_id" {
  description = "The unique identifier of the API key. Empty when no key was created"
  value       = try(temporalcloud_apikey.this[0].id, "")
}

output "apikey_display_name" {
  description = "The display name of the API key"
  value       = try(temporalcloud_apikey.this[0].display_name, "")
}

output "apikey_state" {
  description = "The current state of the API key as reported by Temporal Cloud"
  value       = try(temporalcloud_apikey.this[0].state, "")
}

output "apikey_token" {
  description = "The API key token, the credential a client authenticates with. Returned only when the key is created and stored in Terraform state, so treat the state as a secret. Read it with `terraform output -raw apikey_token`"
  value       = try(temporalcloud_apikey.this[0].token, "")
  sensitive   = true
}

output "apikey_ids" {
  description = "The unique identifiers of the `apikeys` entries, keyed by entry name. Empty when none were created"
  value       = { for k, v in temporalcloud_apikey.keys : k => v.id }
}

output "apikey_display_names" {
  description = "The display names of the `apikeys` entries, keyed by entry name"
  value       = { for k, v in temporalcloud_apikey.keys : k => v.display_name }
}

output "apikey_states" {
  description = "The states of the `apikeys` entries as reported by Temporal Cloud, keyed by entry name"
  value       = { for k, v in temporalcloud_apikey.keys : k => v.state }
}

output "apikey_tokens" {
  description = "The tokens of the `apikeys` entries, keyed by entry name. Returned only when each key is created and stored in Terraform state, so treat the state as a secret"
  value       = { for k, v in temporalcloud_apikey.keys : k => v.token }
  sensitive   = true
}
