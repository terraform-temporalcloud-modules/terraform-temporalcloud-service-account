output "service_account_name" {
  description = "Unique service account name for this test run, prefixed `yulei-tftest-sa-` so leftovers from an interrupted run are identifiable in the Temporal Cloud account"
  # `yulei-` identifies the owner, `tftest-` distinguishes test resources from
  # anything created by hand. scripts/check-orphans.sh matches on this prefix.
  value = "yulei-tftest-sa-${random_pet.this.id}"
}

output "namespace_id" {
  description = "The ID of the namespace created for this run, for the tests that grant namespace permissions. Empty when `create_namespace` is false"
  value       = try(temporalcloud_namespace.this[0].id, "")
}

output "namespace_name" {
  description = "The name of the namespace created for this run. Empty when `create_namespace` is false"
  value       = try(temporalcloud_namespace.this[0].name, "")
}

output "available_regions" {
  description = "Every region this account may use. Surfaced so a test run documents the account's actual entitlements, which differ from the published region list"
  value       = local.region_ids
}

output "apikey_expiry_time" {
  description = "An API key expiry 30 days after setup, in UTC with whole seconds, so apply tests never use a date that has passed"
  value       = timeadd(timestamp(), "720h")
}
