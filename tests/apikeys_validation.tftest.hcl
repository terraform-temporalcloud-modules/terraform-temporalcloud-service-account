// The `apikeys` validations reject a bad entry at plan, naming the variable,
// rather than letting the provider fail at apply. Plan-only: a rejection has no
// apply to run.

provider "temporalcloud" {
  // Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

run "rejects_null_entry" {
  command = plan

  variables {
    name           = "yulei-tftest-validation"
    account_access = "read"
    apikeys        = { current = null }
  }

  expect_failures = [var.apikeys]
}

run "rejects_empty_display_name" {
  command = plan

  variables {
    name           = "yulei-tftest-validation"
    account_access = "read"
    apikeys = {
      current = {
        display_name = ""
        expiry_time  = "2027-01-01T00:00:00Z"
      }
    }
  }

  expect_failures = [var.apikeys]
}

run "rejects_invalid_expiry" {
  command = plan

  variables {
    name           = "yulei-tftest-validation"
    account_access = "read"
    apikeys = {
      current = {
        display_name = "yulei-tftest-validation"
        expiry_time  = "2027-01-01"
      }
    }
  }

  expect_failures = [var.apikeys]
}
