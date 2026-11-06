locals {
  create_service_account = var.create_service_account

  # An API key is issued for an owner, and the only owner this module manages is
  # the service account it creates. With the service account switched off there
  # is nothing for the key to belong to.
  create_apikey = local.create_service_account && var.create_apikey
}

################################################################################
# Service account
#
# `namespace_accesses` and `namespace_scoped_access` are nested attributes in the
# provider schema rather than blocks, so they are assigned straight from their
# variables and a null value omits them. `timeouts` is the only true block, hence
# the dynamic block below.
#
# The two access models are mutually exclusive — see the variable descriptions.
################################################################################

resource "temporalcloud_service_account" "this" {
  count = local.create_service_account ? 1 : 0

  name        = var.name
  description = var.description

  account_access              = var.account_access
  account_access_custom_roles = var.account_access_custom_roles
  namespace_accesses          = var.namespace_accesses

  namespace_scoped_access = var.namespace_scoped_access

  dynamic "timeouts" {
    for_each = length([for v in var.timeouts : v if v != null]) > 0 ? [var.timeouts] : []

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
    }
  }
}

################################################################################
# API key
#
# Folded into this module because a key is issued *for* a service account and is
# the only way to obtain usable credentials for one. `owner_type` is fixed: this
# module only ever creates keys for the service account above.
#
# The token is returned once, at creation, and is written to Terraform state.
################################################################################

resource "temporalcloud_apikey" "this" {
  count = local.create_apikey ? 1 : 0

  owner_id   = temporalcloud_service_account.this[0].id
  owner_type = "service-account"

  display_name = var.apikey_display_name
  description  = var.apikey_description
  expiry_time  = var.apikey_expiry_time
  disabled     = var.apikey_disabled

  dynamic "timeouts" {
    for_each = length([for v in var.apikey_timeouts : v if v != null]) > 0 ? [var.apikey_timeouts] : []

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
    }
  }
}

################################################################################
# Additional API keys
#
# One resource per entry, keyed by name, so adding or removing a key does not
# disturb the state addresses of the others. That is what makes rotation with an
# overlap possible: add `next`, move clients, remove `current`.
#
# Independent of `create_apikey` and the single key above. `expiry_time` forces
# replacement in the provider, so rotation adds a new entry rather than editing
# an existing one.
################################################################################

resource "temporalcloud_apikey" "keys" {
  for_each = local.create_service_account ? var.apikeys : {}

  owner_id   = temporalcloud_service_account.this[0].id
  owner_type = "service-account"

  display_name = each.value.display_name
  description  = each.value.description
  expiry_time  = each.value.expiry_time
  disabled     = each.value.disabled

  dynamic "timeouts" {
    for_each = length([for v in var.apikey_timeouts : v if v != null]) > 0 ? [var.apikey_timeouts] : []

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
    }
  }
}
