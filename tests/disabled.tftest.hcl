// Verifies create_service_account = false against a real provider.
//
// Separate file so it gets its own state and cannot interfere with the service
// account created in service_account.tftest.hcl. Creates no resources, so it is
// cheap — but it still configures the provider, which is why it needs
// TEMPORAL_CLOUD_API_KEY.

provider "temporalcloud" {}

run "creates_nothing" {
  variables {
    create_service_account = false

    // name has no default, so Terraform requires it even when nothing is
    // created. This empty value is never read.
    name = ""

    // Set, and must still produce nothing: an API key has no owner without the
    // service account, so create_apikey is subordinate to it.
    create_apikey       = true
    apikey_display_name = "should-not-be-created"
    apikey_expiry_time  = "2027-01-01T00:00:00Z"

    // Also set, and must also produce nothing: map entries need the same owner.
    apikeys = {
      current = {
        display_name = "should-not-be-created"
        expiry_time  = "2027-01-01T00:00:00Z"
      }
    }
  }

  // Every output is count-gated behind try(); these assertions prove the
  // fallbacks evaluate rather than erroring when the module is switched off.
  assert {
    condition     = output.service_account_id == ""
    error_message = "service_account_id should fall back to empty when create_service_account = false"
  }

  assert {
    condition     = output.service_account_name == ""
    error_message = "service_account_name should fall back to empty"
  }

  assert {
    condition     = output.service_account_state == ""
    error_message = "service_account_state should fall back to empty"
  }

  assert {
    condition     = output.service_account_account_access == ""
    error_message = "service_account_account_access should fall back to empty"
  }

  assert {
    // length(), not == tolist([]): the output is an empty tuple, which never
    // compares equal to a list.
    condition     = length(output.service_account_namespace_accesses) == 0
    error_message = "service_account_namespace_accesses should fall back to an empty list"
  }

  assert {
    condition     = length(output.service_account_namespace_scoped_access) == 0
    error_message = "service_account_namespace_scoped_access should fall back to an empty map"
  }

  assert {
    condition     = output.apikey_id == ""
    error_message = "an API key was created without a service account to own it"
  }

  assert {
    condition     = output.apikey_display_name == ""
    error_message = "apikey_display_name should fall back to empty"
  }

  assert {
    condition     = output.apikey_state == ""
    error_message = "apikey_state should fall back to empty"
  }

  assert {
    condition     = output.apikey_token == ""
    error_message = "apikey_token should fall back to empty"
  }

  assert {
    condition     = length(output.apikey_ids) == 0 && length(output.apikey_display_names) == 0 && length(output.apikey_states) == 0 && length(output.apikey_tokens) == 0
    error_message = "apikeys entries were created without a service account to own them"
  }
}
