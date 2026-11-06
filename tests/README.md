# Tests

Not usage examples — see [examples/](../examples) for those.

| Path | Runs on | Credentials |
| --- | --- | --- |
| `local/` | every pull request | no |
| `*.tftest.hcl` | on demand, weekly | **yes** |
| `setup/` | helper for `*.tftest.hcl` | no |

`local/` passes every module input and references every output, so `terraform
validate` fails there as soon as the variable surface changes.

`*.tftest.hcl` applies against a real Temporal Cloud account, which is the only
way to catch the API rejecting a configuration that type-checks.

| File | Covers |
| --- | --- |
| `service_account.tftest.hcl` | Create with an account-level role and timeouts; update in place to add `namespace_accesses` and issue an API key; update again to narrow both roles and disable the key |
| `namespace_scoped.tftest.hcl` | `namespace_scoped_access` with an API key, asserting no account-level role comes back; then narrowing the permission in place |
| `wrappers.tftest.hcl` | The `wrappers` submodule: two service accounts from one call, with per-item overrides and a per-item API key |
| `disabled.tftest.hcl` | `create_service_account = false` creates nothing — including no API key, despite `create_apikey = true` and a non-empty `apikeys` — and every output falls back |
| `apikeys.tftest.hcl` | Rotation with the `apikeys` map: `{current}`, then `{current, next}`, then `{next}`, asserting the service account and the surviving key keep their IDs and tokens; the single-key interface alongside the map in the middle step. Expiry comes from `setup/`, 30 days ahead, so the dates never pass |
| `apikeys_validation.tftest.hcl` | Plan-only: a null entry, an empty `display_name`, and a non-RFC 3339 `expiry_time` are each rejected by the `apikeys` validations |

Fixtures: `setup/` generates a unique name and, when asked, creates the namespace
that `namespace_accesses` and `namespace_scoped_access` point at. Both take a real
namespace ID, so the suite has to create one. It is gated behind
`create_namespace` because namespace creation is slow and `wrappers.tftest.hcl`
only needs names. `liveness/` and `orphan-check/` create nothing.

## What is not apply-tested

`account_access_custom_roles` is covered only by `local/`. Applying it needs a
`temporalcloud_custom_role`, which belongs to a different module in this family;
creating one here would couple this suite to that resource's own constraints. To
run it by hand, create a custom role in the account, then add its ID to the
`create_service_account` run block in `service_account.tftest.hcl`.

`apikey_timeouts` is also covered only by `local/`, so it is type-checked but never
sent to the API. The parent `timeouts` input is apply-covered, and both are passed
straight through to a provider `timeouts` block.

Files run sequentially and each is torn down before the next begins, so only
`wrappers.tftest.hcl` has more than one service account alive at a time.

[CONTRIBUTING.md](../CONTRIBUTING.md) explains why the layers are split this way
and which API behaviours they guard against.

## What the apply tests cannot assert

`apikey_disabled` is applied by the `reduce_access` run block, but its effect is
not observable: Temporal Cloud still reports `state = "active"` for a key that was
applied with `disabled = true`. The only assertable consequence is that disabling a
key keeps its identity, so the test compares the key ID against the prior run
block's. Do not add an assertion claiming `apikey_state` reflects the flag — it
does not.

Assertions that claim a resource was **updated rather than replaced** compare the
ID against the prior run block's, never against a name the same block passed in as
a variable, which would hold either way. Both `service_account` and `apikey` IDs
are opaque and server-issued, so those comparisons are real evidence.

## Account access the apply tests require

Only `TEMPORAL_CLOUD_API_KEY` — no AWS, GCP, mail domain or other external
credential. The key does, however, need **more privilege than the other modules in
this family**:

| Requirement | Why | If absent |
| --- | --- | --- |
| An **account-admin scoped** key | The suite creates service accounts and issues API keys for them. A key scoped to `read` or `developer`, or to a single namespace, cannot do either | The apply fails with a permission error, not a validation error |
| Headroom for 2 concurrent service accounts | `wrappers.tftest.hcl` | Service account quota error |
| Namespace create/delete rights and one entitled region | `setup/` creates a namespace for `namespace_accesses` and `namespace_scoped_access` to point at | `check-api.sh` fails first when no region is entitled |

The key issued *by* the suite is a real, usable credential returned in
`apikey_token` and written to test state. Treat the state as a secret; it is
discarded on teardown.

## Running the apply tests

```bash
export TEMPORAL_CLOUD_API_KEY="<key for a scratch account>"
terraform init
terraform test -verbose
```

Point them at a scratch account: they create and destroy **real, billable**
service accounts, API keys and namespaces.

Without a key, every run block is skipped — a cheap way to confirm the test files
parse:

```text
Failure! 0 passed, 0 failed, 10 skipped.
```

## Cleaning up leftovers

`terraform test` destroys what it created, including after a failed assertion, but
a cancelled or crashed run can orphan a resource. The CI workflow therefore runs
`scripts/check-orphans.sh` afterwards — always, including when the tests fail,
since that is when something is most likely to be left behind. It fails the job and
names anything still present. Run it by hand the same way:

```bash
scripts/check-orphans.sh
```

It checks service accounts and namespaces. API keys are not checked and cannot be:
the provider exposes no data source for them. A key belongs to a service account,
so deleting a reported leftover removes its keys with it.

Test resources are prefixed so they are identifiable:

| Prefix | Created by |
| --- | --- |
| `yulei-tftest-sa-<random>` | `*.tftest.hcl`, both service accounts and the namespace fixture |
| `yulei-tflocal-*` | `local/`, only if applied by hand — CI never applies it |

Anything matching those prefixes that no live configuration owns can be deleted.

The `examples/` directories are not covered by this prefix; they create
`ex-complete` and `ex-namespace-scoped`, plus a namespace each. Example code is
published to the Terraform Registry, so it carries no test-specific naming. Check
for those separately if you have applied an example by hand.
