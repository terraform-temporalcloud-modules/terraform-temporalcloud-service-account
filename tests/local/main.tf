provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

################################################################################
# Local regression coverage
#
# The examples/ directories source the PUBLISHED module so they are copy-pasteable
# for consumers. That means they validate the last release, not the code in this
# repo — a renamed or removed variable would slip through CI unnoticed.
#
# This directory closes that gap: it sources the module by relative path and
# passes EVERY input, so `terraform validate` fails here the moment the variable
# surface changes incompatibly. CI picks it up automatically because it contains a
# versions.tf with required_version.
#
# When you add a variable to the root module, add it here in the same PR. Adding
# it to examples/ has to wait until the next release publishes it.
#
# The namespace IDs below are placeholders. Nothing here is ever applied by CI.
################################################################################

# Every input the account-wide access model accepts, plus an API key.
#
# `namespace_scoped_access` is deliberately absent: the provider rejects it
# alongside account_access at validate time, so it is covered by the separate
# call below rather than here.
module "all_inputs" {
  source = "../../"

  create_service_account = true

  name        = "yulei-tflocal-test"
  description = "Local regression coverage"

  account_access              = "developer"
  account_access_custom_roles = ["custom-role-id"]

  namespace_accesses = [
    {
      namespace_id = "yulei-tflocal-ns.00000"
      permission   = "write"
    },
  ]

  timeouts = {
    create = "10m"
    delete = "10m"
  }

  create_apikey       = true
  apikey_display_name = "yulei-tflocal-key"
  apikey_description  = "Local regression coverage"
  apikey_expiry_time  = "2027-01-01T00:00:00Z"
  apikey_disabled     = false

  apikey_timeouts = {
    create = "10m"
    delete = "10m"
  }

  apikeys = {
    current = {
      display_name = "yulei-tflocal-current"
      description  = "Local regression coverage"
      expiry_time  = "2027-01-01T00:00:00Z"
      disabled     = false
    }
    next = {
      display_name = "yulei-tflocal-next"
      expiry_time  = "2027-06-01T00:00:00Z"
    }
  }
}

# The other access model: confined to a single namespace, no account-level role.
module "namespace_scoped" {
  source = "../../"

  name = "yulei-tflocal-scoped"

  namespace_scoped_access = {
    namespace_id = "yulei-tflocal-ns.00000"
    permission   = "read"
  }
}

# The create flag off: proves the module produces no resources and that every
# output still evaluates via its try() fallback.
module "disabled" {
  source = "../../"

  create_service_account = false

  # name has no default, so Terraform requires it even when nothing is created.
  # This empty value is never read.
  name = ""
}

# Minimum viable call: a name and an account role.
module "minimal" {
  source = "../../"

  name           = "yulei-tflocal-minimal"
  account_access = "read"
}

# The wrapper, exercised through the local path as well.
module "wrapper" {
  source = "../../wrappers"

  defaults = {
    account_access = "read"

    apikeys = {
      current = {
        display_name = "yulei-tflocal-wrapper-current"
        expiry_time  = "2027-01-01T00:00:00Z"
      }
    }
  }

  items = {
    reporting = { name = "yulei-tflocal-reporting" }
    workers = {
      name                = "yulei-tflocal-workers"
      account_access      = "developer"
      create_apikey       = true
      apikey_display_name = "yulei-tflocal-workers-key"
      apikey_expiry_time  = "2027-01-01T00:00:00Z"
      apikeys             = {}
    }
  }
}
