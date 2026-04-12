# Terraform Writing Style — Rationale and Design Philosophy

This companion document preserves the extended rationale, design philosophy, and historical context behind the rules in [STYLE_GUIDE.md](STYLE_GUIDE.md). The main guide contains all actionable rules, normative guidance, examples, and reference material. This document explains *why* those rules exist.

## Table of Contents

- [Executive Summary: Terraform Philosophy](#executive-summary-terraform-philosophy)
- [Resource Configuration Rationale](#resource-configuration-rationale)
  - [Why for_each is Preferred](#why-for_each-is-preferred)
  - [Advantages of terraform_data over null_resource](#advantages-of-terraform_data-over-null_resource)
- [State Management Rationale](#state-management-rationale)
  - [Environment Separation Strategies: Comparison Table](#environment-separation-strategies-comparison-table)
  - [Workspace Limitations](#workspace-limitations)
  - [Environment Separation Recommendation](#environment-separation-recommendation)
- [Cross-Stack Data Sharing Rationale](#cross-stack-data-sharing-rationale)
  - [Approaches Comparison](#approaches-comparison)
  - [Caveats when using terraform_remote_state](#caveats-when-using-terraform_remote_state)
- [Provider Management Rationale](#provider-management-rationale)
  - [Why configuration_aliases is Required](#why-configuration_aliases-is-required)
  - [Benefits of Service Account Impersonation over Keys](#benefits-of-service-account-impersonation-over-keys)

---

## Executive Summary: Terraform Philosophy

> For the actionable rules derived from this philosophy, see the [Quick Reference Checklist](STYLE_GUIDE.md#quick-reference-checklist) in the main guide.

This repository approaches Terraform as **infrastructure as code** with the same rigor applied to application code. The following principles guide all Terraform development:

- **Deterministic and reproducible:** Infrastructure changes **MUST** produce predictable, repeatable results. The same configuration **MUST** produce the same infrastructure across environments.

- **Security-first:** Secrets **MUST NEVER** appear in code or state unencrypted. Least-privilege **MUST** be the default for all IAM policies and resource access controls.

- **Modular and reusable:** Common infrastructure patterns **SHOULD** be extracted into versioned modules with well-defined interfaces. Modules **MUST** be designed for reuse across projects.

- **Well-documented:** Every variable, output, and module **MUST** be documented. Documentation is not optional—it is a first-class deliverable.

- **Testable:** Infrastructure **SHOULD** be validated with automated tests before deployment. Terraform's native test framework enables validation of configuration logic.

- **Version-controlled:** All Terraform code, including lock files, **MUST** be version-controlled. State files **MUST** be stored remotely with encryption and locking.

The coding standards in the main guide enforce these principles through specific, actionable requirements.

> **Provider-Agnostic Guidance:** The main guide includes parallel examples for AWS, Azure, and GCP where applicable. All style rules and best practices are **provider-agnostic**. Users **MAY** remove examples for providers they do not use. The principles of naming, structure, security, and documentation apply equally across all providers.

---

## Resource Configuration Rationale

> For the resource configuration rules themselves, see [Resource Configuration](STYLE_GUIDE.md#resource-configuration) in the main guide.

### Why for_each is Preferred

Removing an item from a `count`-based list causes all subsequent resources to be recreated due to index shifting. `for_each` uses map keys, so only the specific resource is affected.

---

### Advantages of terraform_data over null_resource

The `terraform_data` resource is the preferred replacement for `null_resource` in modern Terraform configurations for the following reasons:

- No provider dependency (built into Terraform core)
- Clearer semantics with `input` and `output` attributes
- Better integration with the dependency graph

---

## State Management Rationale

> For the state management rules themselves, see [State Management](STYLE_GUIDE.md#state-management) in the main guide.

### Environment Separation Strategies: Comparison Table

| Approach | Use When | Advantages | Disadvantages |
| --- | --- | --- | --- |
| **Workspaces** | Identical infrastructure across environments; only variable values differ; small team with clear workflow | Single codebase; easy to switch between environments; built-in Terraform feature | Shared backend configuration; risk of applying to wrong workspace; no visible configuration differences in version control |
| **Directory-based** | Different configurations per environment; team isolation needed; production requires explicit review; compliance requirements | Explicit, reviewable configuration per environment; no risk of workspace confusion; better audit trail; environment-specific customization | Some code duplication; requires discipline to keep shared modules updated |
| **Hybrid** | Large organizations with both simple and complex environments; gradual migration between approaches | Flexibility; can use workspaces for non-production and directories for production | Increased complexity; requires clear documentation of which pattern applies where |

---

### Workspace Limitations

Workspaces have the following limitations that inform the recommendation for directory-based separation:

- All environments share the same backend configuration
- No visible difference in repository between environments
- Risk of running `terraform apply` in the wrong workspace
- Difficult to implement environment-specific features or configurations
- Code review cannot distinguish between environment configurations

---

### Environment Separation Recommendation

1. **Explicit configuration:** Each environment has its own visible, reviewable configuration in version control
2. **Safety:** No risk of accidentally applying changes to the wrong environment
3. **Flexibility:** Easy to implement environment-specific configurations or features
4. **Audit trail:** Git history clearly shows what changed in each environment
5. **Team isolation:** Different teams or approval processes can manage different environments
6. **Compliance:** Easier to demonstrate separation of concerns for auditors

Workspaces **MAY** be used for:

- Development and testing environments where rapid iteration is prioritized
- Scenarios where infrastructure is truly identical across environments
- Small teams with established workspace discipline
- Temporary or ephemeral environments

Teams **SHOULD** document their chosen approach in the repository's README or contributing guide to ensure consistency.

---

## Cross-Stack Data Sharing Rationale

> For the cross-stack data sharing rules themselves, see [Cross-Stack Data Sharing](STYLE_GUIDE.md#cross-stack-data-sharing) in the main guide.

### Approaches Comparison

| Approach | Recommendation | Coupling | Security |
| --- | --- | --- | --- |
| Cloud-native parameter stores | **PREFERRED** | Loose | Configurable per-value |
| `terraform_remote_state` data source | Acceptable with caveats | Tight | Full state exposure |
| Hardcoding values | **DISCOURAGED** | None (brittle) | Poor |

---

### Caveats when using terraform_remote_state

The `terraform_remote_state` data source has the following limitations that inform the preference for cloud-native parameter stores:

- **Tight coupling:** Changes to the source stack's outputs can break consuming stacks.
- **State file access:** Consumers need read access to the entire state file, not just specific outputs.
- **Least Privilege violation:** Consumers gain access to **all** outputs in the source state file, potentially exposing sensitive data not intended for sharing. This over-fetching of permissions violates security best practices.
- **No explicit contract:** No clear interface definition between producer and consumer.
- **Harder to test:** Mocking remote state in tests is more complex than mocking parameter store lookups.

---

## Provider Management Rationale

> For the provider management rules themselves, see [Provider Management](STYLE_GUIDE.md#provider-management) in the main guide.

### Why configuration_aliases is Required

- Modules **SHOULD NOT** define provider configurations directly; provider configurations **MUST** be defined in root modules. Terraform **CAN** accept provider blocks in child modules only as a legacy pattern and imposes limitations on such modules.
- Modules that use provider aliases internally must declare which aliases they expect
- This creates an explicit contract between the module and its callers

---

### Benefits of Service Account Impersonation over Keys

Service account impersonation (GCP) is preferred over static service account keys because:

- No key rotation required—credentials are short-lived
- Audit trail shows both the calling identity and impersonated account
- Reduced risk of credential exposure
- Easier to revoke access by removing IAM bindings
