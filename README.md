# Temporal Cloud Service Account Terraform module

[![CI](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-service-account/actions/workflows/pre-commit.yml/badge.svg?branch=main)](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-service-account/actions/workflows/pre-commit.yml?query=branch%3Amain)
[![Apply Tests](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-service-account/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-service-account/actions/workflows/test.yml?query=branch%3Amain)

Terraform module which creates a [Temporal Cloud](https://temporal.io/cloud) service account, together
with the API key that gives it usable credentials.

A service account is the machine identity workers and CI systems authenticate as. An API key is issued
*for* a service account and is the only way to obtain credentials for one, which is why both live in
this module.

## Requirements

The `temporalcloud` provider authenticates with an API key, read from the `TEMPORAL_CLOUD_API_KEY`
environment variable:

```bash
export TEMPORAL_CLOUD_API_KEY="<your-api-key>"
```

The provider authenticates when it initialises, so a key is needed even for a `terraform plan` that
would create nothing. Keep the key out of version control — an untracked `.env` file rather than a
committed `.tfvars`.

## Choosing an access model

A service account uses **one of two mutually exclusive** access models. Pick before you write the
configuration: they cannot be combined, and switching between them later replaces the service account.

| | Account-wide | Namespace-scoped |
| --- | --- | --- |
| Inputs | `account_access`, `account_access_custom_roles`, `namespace_accesses` | `namespace_scoped_access` |
| Reaches | the whole account, at the `account_access` role, plus any extra per-namespace grants | exactly one namespace, nothing else |
| Change the namespace later | yes, `namespace_accesses` is mutable | no, `namespace_id` is immutable |
| Use for | platform automation, CI, anything spanning namespaces | a worker fleet serving a single namespace |

Setting inputs from both raises `Invalid Attribute Combination` during `terraform plan`. Setting
neither is rejected at apply with `Either account_access or namespace_scoped_access must be provided`.

## Usage

### Account-wide service account with an API key

```hcl
module "service_account" {
  source  = "terraform-temporalcloud-modules/service-account/temporalcloud"
  version = "~> 2.0"

  name        = "ci-deployer"
  description = "Runs schedule and worker deployments from CI"

  account_access = "developer"

  namespace_accesses = [
    {
      namespace_id = module.orders_namespace.namespace_id
      permission   = "write"
    },
  ]

  create_apikey       = true
  apikey_display_name = "ci-deployer"
  apikey_expiry_time  = "2027-01-01T00:00:00Z"
}
```

### Namespace-scoped service account

The tighter model: the identity exists only inside one namespace and holds no account-level role.

```hcl
module "worker_identity" {
  source  = "terraform-temporalcloud-modules/service-account/temporalcloud"
  version = "~> 2.0"

  name = "payments-workers"

  namespace_scoped_access = {
    namespace_id = module.payments_namespace.namespace_id
    permission   = "write"
  }

  create_apikey       = true
  apikey_display_name = "payments-workers"
  apikey_expiry_time  = "2027-01-01T00:00:00Z"
}
```

### Reading the API key token

The token is the credential a client authenticates with. It is returned only when the key is created,
so the module exposes it as a sensitive output rather than printing it:

```hcl
output "worker_apikey_token" {
  value     = module.worker_identity.apikey_token
  sensitive = true
}
```

```bash
terraform output -raw worker_apikey_token
```

Feed it to a worker through the `TEMPORAL_API_KEY` environment variable, or write it into a secret
store. Do not commit it, and treat the Terraform state as a secret — the token is stored there in
plain text.

## Notes

Provider and Temporal Cloud behaviours worth knowing before you plan:

- **Never derive `apikey_expiry_time` from `timestamp()`.** An expression such as
  `timeadd(timestamp(), "8760h")` produces a different value on every plan, so Terraform replaces the
  API key on every apply and silently invalidates the credential your workers are using. Use a fixed
  RFC 3339 timestamp and change it deliberately when you rotate.
- **An `owner` or `admin` service account cannot be given explicit `namespace_accesses`.** Those roles
  implicitly reach every namespace, and combining the two is rejected during `terraform plan` with
  `Users with account_access roles of owner or admin cannot have namespace accesses`. Use `developer`,
  `read`, `financeadmin` or `metricsread` when you want per-namespace grants.
- **`namespace_scoped_access.namespace_id` is immutable.** Changing it replaces the service account,
  which also destroys every API key issued for it. Plan output will show the replacement — read it
  before applying.
- **Empty sets are rejected.** Omit `namespace_accesses` and `account_access_custom_roles` rather than
  passing `[]`.
- **Rotating a key means replacing it.** There is no in-place rotation. Use `apikeys` to overlap two
  keys on the same service account: add a `next` entry, apply, move clients to it, then remove the old
  entry and apply again. Changing `expiry_time` on an entry replaces that key, so add a new entry rather
  than editing one. A second module instance creates another service account, not another key.
- **Rotating an existing single key.** Keep `create_apikey = true`, add an `apikeys.next` entry, and
  apply. Move clients to `apikey_tokens["next"]`, then set `create_apikey = false` and apply. The
  singular `apikey_*` outputs describe only the single key; the plural ones describe only `apikeys`
  entries.
- **`apikey_disabled = true` blocks authentication without deleting the key.** The key keeps its
  identity and can be re-enabled, which makes it the safe way to test a revocation.

## Examples

- [complete](examples/complete) — an account-wide service account with a per-namespace grant and an
  API key
- [namespace-scoped](examples/namespace-scoped) — a service account confined to a single namespace,
  for a worker fleet

## Managing several service accounts

The [`wrappers`](wrappers) submodule creates many service accounts from one call, for use with
Terragrunt or anywhere a `for_each` on the module block is awkward:

```hcl
module "service_accounts" {
  source  = "terraform-temporalcloud-modules/service-account/temporalcloud//wrappers"
  version = "~> 2.0"

  defaults = {
    account_access = "read"
  }

  items = {
    reporting = { name = "reporting" }
    ci        = { name = "ci", account_access = "developer" }
  }
}
```

## Which inputs are required

The generated **Inputs** table below marks `name` as required, and Terraform enforces that —
including when `create_service_account = false`, where the module creates nothing but still needs a
value. Pass `name = ""` to switch the module off.

Everything else depends on which gates are on, and the tables below are the record of it.

Where a rule is caught differs, and the tables say so:

- **validate** — this module's own `variable` validations. They run under `terraform validate` and need
  no credentials.
- **plan** — the provider's schema validators. They see a module input only once its value is known,
  which is at plan rather than validate. The provider authenticates when it initialises, so reaching
  them needs an API key.
- **apply** — nothing catches it beforehand.

### With `create_service_account = true` (the default)

| Input | Omitting it |
| --- | --- |
| `account_access` **or** `namespace_scoped_access` | Exactly one is required. Setting neither fails at **apply** with `Either account_access or namespace_scoped_access must be provided`. |

`account_access_custom_roles` adds to `account_access` rather than standing in for it: custom roles on
their own plan cleanly and then hit that same apply-time error.

With `create_service_account = false` nothing beyond `name` is needed — every resource is switched off
and the outputs are empty.

### With `create_apikey = true`

`create_apikey` is subordinate to `create_service_account`, because a key is issued for an owner. With
the service account off, no key is created and neither input below is read.

| Input | Omitting it |
| --- | --- |
| `apikey_display_name` | The key is sent with an empty display name. Nothing before **apply** objects. |
| `apikey_expiry_time` | Fails at **apply** with `Invalid ExpiryTime` — the provider parses this as RFC 3339 and the empty default is not a timestamp. A malformed non-empty value is caught earlier, at **validate**. |

### Combinations that are rejected

| Combination | Caught at | Error |
| --- | --- | --- |
| `namespace_scoped_access` with any of `account_access`, `account_access_custom_roles`, `namespace_accesses` | plan | `Invalid Attribute Combination` |
| `account_access` of `owner` or `admin` with `namespace_accesses` | plan | `Users with account_access roles of owner or admin cannot have namespace accesses` |
| Neither `account_access` nor `namespace_scoped_access` | apply | `Either account_access or namespace_scoped_access must be provided` |
| `[]` for `namespace_accesses` or `account_access_custom_roles` | validate | `Empty sets are not accepted by the provider. Omit the variable instead.` |

### Optional

- **Descriptive** — `description`, `apikey_description`. The object is created without a description.
- **Access refinement**, account-wide model only — `account_access_custom_roles`, `namespace_accesses`.
  Without them the service account holds its `account_access` role and nothing more.
- **Key state** — `apikey_disabled`. The key is created enabled.
- **Timeouts** — `timeouts`, `apikey_timeouts`. The provider's own create and delete timeouts apply.
- **Gates** — `create_service_account` (on by default), `create_apikey` (off).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_temporalcloud"></a> [temporalcloud](#requirement\_temporalcloud) | >= 1.6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_temporalcloud"></a> [temporalcloud](#provider\_temporalcloud) | >= 1.6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [temporalcloud_apikey.keys](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/resources/apikey) | resource |
| [temporalcloud_apikey.this](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/resources/apikey) | resource |
| [temporalcloud_service_account.this](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_access"></a> [account\_access](#input\_account\_access) | The role this service account holds on the account: `owner`, `admin`, `developer`, `read`, `financeadmin` or `metricsread`, matched case-insensitively. Required when `create_service_account` is `true` unless `namespace_scoped_access` is set instead — exactly one of the two access models is needed, and setting both is rejected at plan | `string` | `null` | no |
| <a name="input_account_access_custom_roles"></a> [account\_access\_custom\_roles](#input\_account\_access\_custom\_roles) | IDs of custom roles granted in addition to the built-in `account_access` role. Optional; the service account holds only its `account_access` role when unset. These roles add to `account_access` rather than replacing it, so they do not satisfy the requirement for an access model on their own. Omit rather than passing an empty set. Cannot be combined with `namespace_scoped_access` | `set(string)` | `null` | no |
| <a name="input_apikey_description"></a> [apikey\_description](#input\_apikey\_description) | Description of the API key. Optional; the key is created without one when unset | `string` | `null` | no |
| <a name="input_apikey_disabled"></a> [apikey\_disabled](#input\_apikey\_disabled) | Disables the API key without deleting it. Optional; the key is created enabled when unset. A disabled key is rejected at authentication but keeps its identity, so it can be re-enabled | `bool` | `null` | no |
| <a name="input_apikey_display_name"></a> [apikey\_display\_name](#input\_apikey\_display\_name) | Display name of the API key, shown in the Temporal Cloud UI. Required when `create_apikey` is `true`; the empty default is sent as an empty display name and nothing rejects it before apply | `string` | `""` | no |
| <a name="input_apikey_expiry_time"></a> [apikey\_expiry\_time](#input\_apikey\_expiry\_time) | When the API key expires, as an RFC 3339 timestamp such as `2027-01-01T00:00:00Z`. Required when `create_apikey` is `true`; there is no default expiry, and the empty default fails the apply with `Invalid ExpiryTime`. Use a fixed timestamp: an expression derived from `timestamp()` changes on every plan and replaces the key, invalidating credentials already in use | `string` | `""` | no |
| <a name="input_apikey_timeouts"></a> [apikey\_timeouts](#input\_apikey\_timeouts) | Create and delete timeouts for the single API key and every `apikeys` entry, as duration strings such as `30s` or `2h45m`. Optional; the provider's own defaults apply to whichever is unset | <pre>object({<br/>    create = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_apikeys"></a> [apikeys](#input\_apikeys) | Additional API keys for the service account, keyed by a stable name such as `current` and `next`. Each entry needs a `display_name` and an `expiry_time` in UTC with whole seconds, such as `2027-01-01T00:00:00Z`; the provider rewrites other RFC 3339 forms, which causes apply errors or replacement plans. `description` and `disabled` are optional. Map keys must be known at plan time. To rotate without downtime, add an entry, move clients to it, then remove the old entry. Changing `expiry_time` on an entry replaces that key, so rotate by adding a new entry instead. Independent of `create_apikey`, and has no effect when `create_service_account` is `false`. Map entries use `apikey_timeouts` | <pre>map(object({<br/>    display_name = string<br/>    description  = optional(string)<br/>    expiry_time  = string<br/>    disabled     = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_create_apikey"></a> [create\_apikey](#input\_create\_apikey) | Controls the single API key configured with the `apikey_*` inputs. Does not affect `apikeys` entries. Setting it to `true` makes `apikey_display_name` and `apikey_expiry_time` required. Has no effect when `create_service_account` is `false`, since the key needs an owner | `bool` | `false` | no |
| <a name="input_create_service_account"></a> [create\_service\_account](#input\_create\_service\_account) | Controls if the service account should be created. Set to `false` to disable the module without removing the call | `bool` | `true` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the service account, shown alongside it in the Temporal Cloud UI. Optional; the service account is created without one when unset | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the service account. Pass `""` when `create_service_account` is `false` | `string` | n/a | yes |
| <a name="input_namespace_accesses"></a> [namespace\_accesses](#input\_namespace\_accesses) | Per-namespace permissions, as a set of `namespace_id` and `permission` pairs. `permission` is `admin`, `write` or `read`, matched case-insensitively. Optional; the service account reaches namespaces only through its `account_access` role when unset. A service account whose `account_access` is `owner` or `admin` already reaches every namespace and cannot be given explicit entries here. Omit rather than passing an empty set. Cannot be combined with `namespace_scoped_access` | <pre>set(object({<br/>    namespace_id = string<br/>    permission   = string<br/>  }))</pre> | `null` | no |
| <a name="input_namespace_scoped_access"></a> [namespace\_scoped\_access](#input\_namespace\_scoped\_access) | Confines the service account to exactly one namespace, with no account-level role. Required when `create_service_account` is `true` unless `account_access` is set instead — exactly one of the two access models is needed, and setting both is rejected at plan. `permission` is `admin`, `write` or `read`, matched case-insensitively, and can be changed later; `namespace_id` cannot, so changing it replaces the service account and every API key issued for it | <pre>object({<br/>    namespace_id = string<br/>    permission   = string<br/>  })</pre> | `null` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Create and delete timeouts for the service account, as duration strings such as `30s` or `2h45m`. Optional; the provider's own defaults apply to whichever is unset | <pre>object({<br/>    create = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_apikey_display_name"></a> [apikey\_display\_name](#output\_apikey\_display\_name) | The display name of the API key |
| <a name="output_apikey_display_names"></a> [apikey\_display\_names](#output\_apikey\_display\_names) | The display names of the `apikeys` entries, keyed by entry name |
| <a name="output_apikey_id"></a> [apikey\_id](#output\_apikey\_id) | The unique identifier of the API key. Empty when no key was created |
| <a name="output_apikey_ids"></a> [apikey\_ids](#output\_apikey\_ids) | The unique identifiers of the `apikeys` entries, keyed by entry name. Empty when none were created |
| <a name="output_apikey_state"></a> [apikey\_state](#output\_apikey\_state) | The current state of the API key as reported by Temporal Cloud |
| <a name="output_apikey_states"></a> [apikey\_states](#output\_apikey\_states) | The states of the `apikeys` entries as reported by Temporal Cloud, keyed by entry name |
| <a name="output_apikey_token"></a> [apikey\_token](#output\_apikey\_token) | The API key token, the credential a client authenticates with. Returned only when the key is created and stored in Terraform state, so treat the state as a secret. Read it with `terraform output -raw apikey_token` |
| <a name="output_apikey_tokens"></a> [apikey\_tokens](#output\_apikey\_tokens) | The tokens of the `apikeys` entries, keyed by entry name. Returned only when each key is created and stored in Terraform state, so treat the state as a secret |
| <a name="output_service_account_account_access"></a> [service\_account\_account\_access](#output\_service\_account\_account\_access) | The account-level role held by the service account. Empty for a namespace-scoped service account |
| <a name="output_service_account_id"></a> [service\_account\_id](#output\_service\_account\_id) | The unique identifier of the service account. This is the value to pass as `owner_id` when issuing API keys for it elsewhere |
| <a name="output_service_account_name"></a> [service\_account\_name](#output\_service\_account\_name) | The name of the service account |
| <a name="output_service_account_namespace_accesses"></a> [service\_account\_namespace\_accesses](#output\_service\_account\_namespace\_accesses) | The set of per-namespace permissions granted to the service account. Empty when none are granted |
| <a name="output_service_account_namespace_scoped_access"></a> [service\_account\_namespace\_scoped\_access](#output\_service\_account\_namespace\_scoped\_access) | The single namespace the service account is confined to, and its permission there. Empty unless `namespace_scoped_access` was set |
| <a name="output_service_account_state"></a> [service\_account\_state](#output\_service\_account\_state) | The current state of the service account as reported by Temporal Cloud |
<!-- END_TF_DOCS -->

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow, how the test layers are arranged,
and the Temporal Cloud API behaviours the tests exist to guard against.

## License

Apache-2.0 licensed. See [LICENSE](LICENSE).
