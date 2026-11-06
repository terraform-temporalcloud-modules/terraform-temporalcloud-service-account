variable "create_service_account" {
  description = "Controls if the service account should be created. Set to `false` to disable the module without removing the call"
  type        = bool
  default     = true
}

################################################################################
# Service account
################################################################################

variable "name" {
  description = "The name of the service account. Pass `\"\"` when `create_service_account` is `false`"
  type        = string
}

variable "description" {
  description = "Description of the service account, shown alongside it in the Temporal Cloud UI. Optional; the service account is created without one when unset"
  type        = string
  default     = null
}

################################################################################
# Account-wide access
#
# `account_access`, `account_access_custom_roles` and `namespace_accesses` form
# one access model; `namespace_scoped_access` below is the other. Exactly one of
# the two must be used.
################################################################################

variable "account_access" {
  description = "The role this service account holds on the account: `owner`, `admin`, `developer`, `read`, `financeadmin` or `metricsread`, matched case-insensitively. Required when `create_service_account` is `true` unless `namespace_scoped_access` is set instead — exactly one of the two access models is needed, and setting both is rejected at plan"
  type        = string
  default     = null

  # try() covers the null case: lower() raises on a null argument, so the whole
  # check is wrapped rather than guarded operand by operand.
  validation {
    condition     = try(contains(["owner", "admin", "developer", "read", "financeadmin", "metricsread"], lower(var.account_access)), true)
    error_message = "Account access must be one of: owner, admin, developer, read, financeadmin, metricsread (case-insensitive)."
  }
}

variable "account_access_custom_roles" {
  description = "IDs of custom roles granted in addition to the built-in `account_access` role. Optional; the service account holds only its `account_access` role when unset. These roles add to `account_access` rather than replacing it, so they do not satisfy the requirement for an access model on their own. Omit rather than passing an empty set. Cannot be combined with `namespace_scoped_access`"
  type        = set(string)
  default     = null

  validation {
    condition     = try(length(var.account_access_custom_roles) > 0, true)
    error_message = "Empty sets are not accepted by the provider. Omit the variable instead."
  }
}

variable "namespace_accesses" {
  description = "Per-namespace permissions, as a set of `namespace_id` and `permission` pairs. `permission` is `admin`, `write` or `read`, matched case-insensitively. Optional; the service account reaches namespaces only through its `account_access` role when unset. A service account whose `account_access` is `owner` or `admin` already reaches every namespace and cannot be given explicit entries here. Omit rather than passing an empty set. Cannot be combined with `namespace_scoped_access`"
  type = set(object({
    namespace_id = string
    permission   = string
  }))
  default = null

  validation {
    condition     = try(length(var.namespace_accesses) > 0, true)
    error_message = "Empty sets are not accepted by the provider. Omit the variable instead."
  }

  validation {
    condition = try(alltrue([
      for access in var.namespace_accesses :
      contains(["admin", "write", "read"], lower(access.permission))
    ]), true)
    error_message = "Namespace access permissions must be one of: admin, write, read (case-insensitive)."
  }
}

################################################################################
# Namespace-scoped access
#
# The alternative access model: a service account confined to a single namespace,
# with no account-level role at all.
################################################################################

variable "namespace_scoped_access" {
  description = "Confines the service account to exactly one namespace, with no account-level role. Required when `create_service_account` is `true` unless `account_access` is set instead — exactly one of the two access models is needed, and setting both is rejected at plan. `permission` is `admin`, `write` or `read`, matched case-insensitively, and can be changed later; `namespace_id` cannot, so changing it replaces the service account and every API key issued for it"
  type = object({
    namespace_id = string
    permission   = string
  })
  default = null

  validation {
    condition     = try(contains(["admin", "write", "read"], lower(var.namespace_scoped_access.permission)), true)
    error_message = "Namespace-scoped permission must be one of: admin, write, read (case-insensitive)."
  }
}

variable "timeouts" {
  description = "Create and delete timeouts for the service account, as duration strings such as `30s` or `2h45m`. Optional; the provider's own defaults apply to whichever is unset"
  type = object({
    create = optional(string)
    delete = optional(string)
  })
  default = {}
}

################################################################################
# API key
#
# Managed here rather than as a separate module: a key is issued for a service
# account and is the only way to get usable credentials out of one.
################################################################################

variable "create_apikey" {
  description = "Controls the single API key configured with the `apikey_*` inputs. Does not affect `apikeys` entries. Setting it to `true` makes `apikey_display_name` and `apikey_expiry_time` required. Has no effect when `create_service_account` is `false`, since the key needs an owner"
  type        = bool
  default     = false
}

variable "apikey_display_name" {
  description = "Display name of the API key, shown in the Temporal Cloud UI. Required when `create_apikey` is `true`; the empty default is sent as an empty display name and nothing rejects it before apply"
  type        = string
  default     = ""
}

variable "apikey_description" {
  description = "Description of the API key. Optional; the key is created without one when unset"
  type        = string
  default     = null
}

variable "apikey_expiry_time" {
  description = "When the API key expires, as an RFC 3339 timestamp such as `2027-01-01T00:00:00Z`. Required when `create_apikey` is `true`; there is no default expiry, and the empty default fails the apply with `Invalid ExpiryTime`. Use a fixed timestamp: an expression derived from `timestamp()` changes on every plan and replaces the key, invalidating credentials already in use"
  type        = string
  default     = ""

  # formatdate() parses RFC 3339 and nothing else, so it accepts exactly the
  # strings the provider parses at apply time and rejects the rest here, naming
  # the variable.
  validation {
    condition     = var.apikey_expiry_time == "" || can(formatdate("YYYY-MM-DD", var.apikey_expiry_time))
    error_message = "The API key expiry time must be an RFC 3339 timestamp, for example 2027-01-01T00:00:00Z."
  }
}

variable "apikey_disabled" {
  description = "Disables the API key without deleting it. Optional; the key is created enabled when unset. A disabled key is rejected at authentication but keeps its identity, so it can be re-enabled"
  type        = bool
  default     = null
}

variable "apikey_timeouts" {
  description = "Create and delete timeouts for the single API key and every `apikeys` entry, as duration strings such as `30s` or `2h45m`. Optional; the provider's own defaults apply to whichever is unset"
  type = object({
    create = optional(string)
    delete = optional(string)
  })
  default = {}
}

variable "apikeys" {
  description = "Additional API keys for the service account, keyed by a stable name such as `current` and `next`. Each entry needs a `display_name` and an `expiry_time` in UTC with whole seconds, such as `2027-01-01T00:00:00Z`; the provider rewrites other RFC 3339 forms, which causes apply errors or replacement plans. `description` and `disabled` are optional. Map keys must be known at plan time. To rotate without downtime, add an entry, move clients to it, then remove the old entry. Changing `expiry_time` on an entry replaces that key, so rotate by adding a new entry instead. Independent of `create_apikey`, and has no effect when `create_service_account` is `false`. Map entries use `apikey_timeouts`"
  type = map(object({
    display_name = string
    description  = optional(string)
    expiry_time  = string
    disabled     = optional(bool, false)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = try(alltrue([for k, v in var.apikeys : v != null && v.display_name != null && v.display_name != ""]), true)
    error_message = "Each apikeys entry must be an object with a non-empty display_name."
  }

  # formatdate() parses RFC 3339 and nothing else. Unlike apikey_expiry_time there
  # is no empty-string exception: every entry explicitly requests a key.
  validation {
    condition     = try(alltrue([for k, v in var.apikeys : can(formatdate("YYYY-MM-DD", v.expiry_time))]), true)
    error_message = "Each apikeys entry's expiry_time must be an RFC 3339 timestamp, for example 2027-01-01T00:00:00Z."
  }
}
