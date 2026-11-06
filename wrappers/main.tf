module "wrapper" {
  source = "../"

  for_each = var.items

  account_access              = try(each.value.account_access, var.defaults.account_access, null)
  account_access_custom_roles = try(each.value.account_access_custom_roles, var.defaults.account_access_custom_roles, null)
  apikey_description          = try(each.value.apikey_description, var.defaults.apikey_description, null)
  apikey_disabled             = try(each.value.apikey_disabled, var.defaults.apikey_disabled, null)
  apikey_display_name         = try(each.value.apikey_display_name, var.defaults.apikey_display_name, "")
  apikey_expiry_time          = try(each.value.apikey_expiry_time, var.defaults.apikey_expiry_time, "")
  apikey_timeouts             = try(each.value.apikey_timeouts, var.defaults.apikey_timeouts, {})
  apikeys                     = try(each.value.apikeys, var.defaults.apikeys, {})
  create_apikey               = try(each.value.create_apikey, var.defaults.create_apikey, false)
  create_service_account      = try(each.value.create_service_account, var.defaults.create_service_account, true)
  description                 = try(each.value.description, var.defaults.description, null)
  name                        = try(each.value.name, var.defaults.name, "")
  namespace_accesses          = try(each.value.namespace_accesses, var.defaults.namespace_accesses, null)
  namespace_scoped_access     = try(each.value.namespace_scoped_access, var.defaults.namespace_scoped_access, null)
  timeouts                    = try(each.value.timeouts, var.defaults.timeouts, {})
}
