// Rotation with the `apikeys` map: {current}, then {current, next}, then {next}.
//
// One service account, updated across run blocks. Each step compares
// server-issued IDs with the previous run, so a key that was replaced rather
// than kept fails the test. The single-key interface is switched on in the
// middle step to prove the two interfaces do not interfere.

provider "temporalcloud" {
  // Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

run "setup" {
  module {
    source = "./tests/setup"
  }

  // No namespace grants are needed here.
  variables {
    create_namespace = false
  }
}

run "current_only" {
  variables {
    name           = run.setup.service_account_name
    account_access = "read"

    apikeys = {
      current = {
        display_name = "${run.setup.service_account_name}-current"
        expiry_time  = run.setup.apikey_expiry_time
      }
    }
  }

  assert {
    condition     = output.service_account_id != ""
    error_message = "service_account_id is empty, so the service account was not created"
  }

  assert {
    condition     = keys(output.apikey_ids) == ["current"] && output.apikey_ids["current"] != ""
    error_message = "expected exactly one map key, current, got: ${jsonencode(output.apikey_ids)}"
  }

  assert {
    condition     = output.apikey_id == ""
    error_message = "the single-key interface created a key despite create_apikey defaulting to false"
  }
}

run "current_and_next" {
  variables {
    name           = run.setup.service_account_name
    account_access = "read"

    apikeys = {
      current = {
        display_name = "${run.setup.service_account_name}-current"
        expiry_time  = run.setup.apikey_expiry_time
      }
      next = {
        display_name = "${run.setup.service_account_name}-next"
        expiry_time  = run.setup.apikey_expiry_time
      }
    }

    create_apikey       = true
    apikey_display_name = "${run.setup.service_account_name}-single"
    apikey_expiry_time  = run.setup.apikey_expiry_time
  }

  assert {
    condition     = output.service_account_id == run.current_only.service_account_id
    error_message = "the service account was replaced when a key was added"
  }

  assert {
    condition     = output.apikey_ids["current"] == run.current_only.apikey_ids["current"]
    error_message = "adding next replaced current; the overlap would revoke the key clients are using"
  }

  assert {
    condition     = output.apikey_ids["next"] != "" && output.apikey_ids["next"] != output.apikey_ids["current"]
    error_message = "next was not created as a distinct key, got: ${jsonencode(output.apikey_ids)}"
  }

  assert {
    condition     = output.apikey_id != "" && !contains(values(output.apikey_ids), output.apikey_id)
    error_message = "the single key and the map keys must be separate keys"
  }

  // The credential, not only the ID: clients hold the token.
  assert {
    condition     = length(output.apikey_tokens["next"]) > 0 && output.apikey_tokens["current"] == run.current_only.apikey_tokens["current"]
    error_message = "adding next must issue a token for next and keep current's token unchanged"
  }
}

run "next_only" {
  variables {
    name           = run.setup.service_account_name
    account_access = "read"

    apikeys = {
      next = {
        display_name = "${run.setup.service_account_name}-next"
        expiry_time  = run.setup.apikey_expiry_time
      }
    }
  }

  assert {
    condition     = output.service_account_id == run.current_only.service_account_id
    error_message = "the service account was replaced when a key was removed"
  }

  assert {
    condition     = keys(output.apikey_ids) == ["next"]
    error_message = "expected only next after removing current, got: ${jsonencode(output.apikey_ids)}"
  }

  assert {
    condition     = output.apikey_ids["next"] == run.current_and_next.apikey_ids["next"]
    error_message = "removing current replaced next"
  }

  assert {
    condition     = output.apikey_tokens["next"] == run.current_and_next.apikey_tokens["next"]
    error_message = "removing current changed next's token"
  }
}
