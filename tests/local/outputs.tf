# Referencing every output forces Terraform to evaluate each one, so a broken
# output expression fails validation here rather than in a consumer's plan.

output "all_inputs" {
  description = "Every output of the fully configured module instance"
  value = {
    service_account_id                      = module.all_inputs.service_account_id
    service_account_name                    = module.all_inputs.service_account_name
    service_account_state                   = module.all_inputs.service_account_state
    service_account_account_access          = module.all_inputs.service_account_account_access
    service_account_namespace_accesses      = module.all_inputs.service_account_namespace_accesses
    service_account_namespace_scoped_access = module.all_inputs.service_account_namespace_scoped_access
    apikey_id                               = module.all_inputs.apikey_id
    apikey_display_name                     = module.all_inputs.apikey_display_name
    apikey_state                            = module.all_inputs.apikey_state
    apikey_token                            = module.all_inputs.apikey_token
    apikey_ids                              = module.all_inputs.apikey_ids
    apikey_display_names                    = module.all_inputs.apikey_display_names
    apikey_states                           = module.all_inputs.apikey_states
    apikey_tokens                           = module.all_inputs.apikey_tokens
  }
  # apikey_token is sensitive, which propagates to the whole object.
  sensitive = true
}

output "namespace_scoped" {
  description = "Outputs from the namespace-scoped access model"
  value = {
    service_account_id                      = module.namespace_scoped.service_account_id
    service_account_account_access          = module.namespace_scoped.service_account_account_access
    service_account_namespace_scoped_access = module.namespace_scoped.service_account_namespace_scoped_access
  }
}

output "disabled" {
  description = "Outputs when create_service_account is false — every one must fall back rather than error"
  value = {
    service_account_id                      = module.disabled.service_account_id
    service_account_name                    = module.disabled.service_account_name
    service_account_state                   = module.disabled.service_account_state
    service_account_account_access          = module.disabled.service_account_account_access
    service_account_namespace_accesses      = module.disabled.service_account_namespace_accesses
    service_account_namespace_scoped_access = module.disabled.service_account_namespace_scoped_access
    apikey_id                               = module.disabled.apikey_id
    apikey_display_name                     = module.disabled.apikey_display_name
    apikey_state                            = module.disabled.apikey_state
    apikey_token                            = module.disabled.apikey_token
  }
  sensitive = true
}

output "minimal" {
  description = "Outputs from the minimum viable module call"
  value       = module.minimal.service_account_id
}

output "wrapper" {
  description = "Wrapper outputs, keyed by item name"
  value       = module.wrapper.wrapper
  sensitive   = true
}
