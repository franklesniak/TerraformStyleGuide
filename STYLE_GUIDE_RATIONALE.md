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

---

## Upgrading Terraform Versions

This section provides guidance for safely upgrading Terraform versions, including preparation steps, upgrade procedures, and rollback strategies.

### Version Upgrade Checklist

Before upgrading Terraform, complete the following checklist:

- [ ] Read the [Terraform Changelog](https://github.com/hashicorp/terraform/blob/main/CHANGELOG.md) for breaking changes
- [ ] Create a state backup before upgrading
- [ ] Test the upgrade in a non-production environment first
- [ ] Update `.terraform.lock.hcl` after upgrading
- [ ] Run `terraform plan` and verify no unexpected changes
- [ ] Update CI/CD pipeline Terraform version after validation
- [ ] Update `required_version` constraint if needed

### Pre-Upgrade Preparation

Before upgrading, document your current state and create recovery points:

```bash
# 1. Backup current state
terraform state pull > terraform.tfstate.backup

# 2. Document current version
terraform version

# 3. Review current plan (baseline)
terraform plan -out=pre-upgrade.tfplan
```

> **Note:** Store the backup and plan output in a secure location outside the working directory. These files **MUST NOT** be committed to version control as they may contain sensitive information.

### Upgrade Process

The upgrade process varies based on the scope of the version change.

#### Patch and Minor Upgrades (e.g., 1.7.0 → 1.7.5 or 1.7.0 → 1.8.0)

Patch and minor version upgrades are generally safe:

1. Update the Terraform binary to the new version
2. Run `terraform init -upgrade` to update provider dependencies
3. Run `terraform plan` and compare output to your pre-upgrade baseline
4. Verify no unexpected changes appear in the plan
5. If the plan is clean, proceed with normal operations

#### Major Version Upgrades (e.g., 1.x → 2.x, when applicable)

Major version upgrades require additional care:

1. Read the official upgrade guide for the specific version transition
2. Review the changelog for all breaking changes and deprecated features
3. Update the Terraform binary to the new version
4. Run `terraform init -upgrade` to update provider lock file
5. Address any deprecation warnings or errors
6. Update configuration for any removed or changed features
7. Run `terraform plan` and carefully review all changes
8. Test thoroughly in a non-production environment before production deployment

### Lock File Updates

After upgrading Terraform, regenerate the `.terraform.lock.hcl` file to ensure all platforms used by your team and CI/CD systems are covered:

```bash
# Regenerate lock file for all platforms
terraform providers lock \
  -platform=linux_amd64 \
  -platform=linux_arm64 \
  -platform=darwin_amd64 \
  -platform=darwin_arm64 \
  -platform=windows_amd64 \
  -platform=windows_arm64

# Commit the updated lock file
git add .terraform.lock.hcl
git commit -m "chore: Update provider lock file for Terraform X.Y.Z"
```

### CI/CD Considerations

When managing Terraform versions in CI/CD pipelines:

- **Pin Terraform versions:** Use explicit version pinning in CI workflows for reproducibility
- **Test in branches first:** Test new Terraform versions in a feature branch before updating main/production pipelines
- **Update after local validation:** Update the version in workflow files **after** successful local validation

**Example GitHub Actions workflow snippet:**

```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: "1.7.0"  # Pin to specific version
```

### Rollback Procedure

If issues occur after upgrading Terraform, follow this rollback procedure:

1. **Restore the previous Terraform binary version:**
   - Use your version manager to switch back (e.g., `tfenv use 1.6.0`)
   - Or download and install the previous version manually

2. **Restore state if modified:**
   - If the new Terraform version modified state, restore from your backup:

     ```bash
     terraform state push terraform.tfstate.backup
     ```

     > **Warning:** `terraform state push` overwrites the remote state. Ensure no other operations are in progress and that you have verified the backup contents before pushing.

3. **Regenerate lock file:**
   - Run `terraform providers lock` with the previous Terraform version

4. **Document the issue:**
   - Record what went wrong for future reference
   - Consider opening an issue on the Terraform repository if you encountered a bug

### Version Managers

Using a version manager simplifies switching between Terraform versions and ensures team consistency:

**tfenv:**

```bash
# Install a specific version
tfenv install 1.7.0

# Use a specific version
tfenv use 1.7.0

# List installed versions
tfenv list
```

**asdf:**

```bash
# Add Terraform plugin (one-time)
asdf plugin add terraform

# Install a specific version
asdf install terraform 1.7.0

# Set local version for a project
asdf local terraform 1.7.0
```

> **Note:** Version specification files (`.terraform-version` for tfenv or `.tool-versions` for asdf) **MAY** be committed to the repository to ensure team consistency. If committed, these files **SHOULD** be updated as part of the version upgrade process.

---

## Provider-Specific Examples

> The main guide shows one representative example per rule. This section preserves provider-specific variants that were removed from the main guide for token efficiency.

### Version Constraints File Examples

**Azure Example:**

```hcl
# versions.tf

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
```

**GCP Example:**

```hcl
# versions.tf

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}
```

### Provider Configuration File Examples

**Azure Example:**

```hcl
# providers.tf

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}
```

> **Note:** Azure does not support provider-level default tags, and Resource Group tags are not automatically inherited by resources. Define common tags in a `locals` block (for example, `local.common_tags`) and apply `tags = local.common_tags` consistently to each taggable resource; you can optionally enforce required tags via Azure Policy.

**GCP Example:**

```hcl
# providers.tf

provider "google" {
  project = var.project_id
  region  = var.region
}
```

> **Note:** GCP supports `default_labels` at the provider level (Google provider 4.x+), but label keys must be lowercase. For consistent lowercase enforcement or cross-provider compatibility, consider using a `locals` block for common labels.

### Backend Configuration Examples

**Azure Example:**

```hcl
# backend.tf - Example configuration

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"  # Use your resource group
    storage_account_name = "stacmeterraform"  # Use your storage account
    container_name       = "tfstate"
    key                  = "environments/prod/terraform.tfstate"
  }
}
```

**GCP Example:**

```hcl
# backend.tf - Example configuration

terraform {
  backend "gcs" {
    bucket = "acme-corp-terraform-state"  # Use your state bucket name
    prefix = "environments/prod"
  }
}
```

### Partial Backend Configuration Examples

**Azure Backend file (committed):**

```hcl
# backend.tf - partial configuration

terraform {
  backend "azurerm" {
    key = "environments/prod/terraform.tfstate"
    # resource_group_name, storage_account_name, container_name provided via -backend-config
  }
}
```

**Azure Backend config file (environment-specific):**

```hcl
# config/prod.azurerm.tfbackend

resource_group_name  = "rg-terraform-state"
storage_account_name = "stacmeterraform"
container_name       = "tfstate"
```

**GCP Backend file (committed):**

```hcl
# backend.tf - partial configuration

terraform {
  backend "gcs" {
    prefix = "environments/prod"
    # bucket provided via -backend-config
  }
}
```

**GCP Backend config file (environment-specific):**

```hcl
# config/prod.gcs.tfbackend

bucket = "acme-corp-terraform-state"
```

### Remote Backend Configuration Examples

**Azure Example:**

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stacmeterraform"
    container_name       = "tfstate"
    key                  = "environments/prod/terraform.tfstate"
  }
}
```

**GCP Example:**

```hcl
terraform {
  backend "gcs" {
    bucket = "acme-corp-terraform-state"
    prefix = "environments/prod"
  }
}
```

### State Encryption Examples

**Azure Example:**

```hcl
# Azure Storage backend (encryption is enabled by default on Azure Storage accounts)
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stacmeterraform"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}
```

> **Note:** Azure Storage accounts have encryption enabled by default. Ensure your storage account is configured with appropriate encryption settings.

**GCP Example:**

```hcl
# GCS backend (encryption is enabled by default on GCS buckets)
terraform {
  backend "gcs" {
    bucket = "acme-corp-terraform-state"
    prefix = "prod"
  }
}
```

> **Note:** GCS buckets are encrypted by default using Google-managed encryption keys. For additional security, configure Customer-Managed Encryption Keys (CMEK).

### State Locking Examples

**Azure Example:**

```hcl
# Azure Storage backend (locking is built-in via blob leases)
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stacmeterraform"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}
```

> **Note:** Azure Storage backend uses blob leases for state locking automatically. No additional configuration is required.

**GCP Example:**

```hcl
# GCS backend (locking is built-in)
terraform {
  backend "gcs" {
    bucket = "acme-corp-terraform-state"
    prefix = "prod"
  }
}
```

> **Note:** GCS backend supports state locking natively. No additional configuration is required.

### Bootstrapping State Infrastructure Examples

**Azure Example (`bootstrap/main.tf`):**

```hcl
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Backend will be added after bootstrap
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "stacmeterraform"
  #   container_name       = "tfstate"
  #   key                  = "bootstrap/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "terraform_state" {
  name     = "rg-terraform-state"
  location = "eastus"
}

resource "azurerm_storage_account" "terraform_state" {
  name                     = "stacmeterraform"
  resource_group_name      = azurerm_resource_group.terraform_state.name
  location                 = azurerm_resource_group.terraform_state.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "terraform_state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.terraform_state.name
  container_access_type = "private"
}
```

**GCP Example (`bootstrap/main.tf`):**

```hcl
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  # Backend will be added after bootstrap
  # backend "gcs" {
  #   bucket = "acme-corp-terraform-state"
  #   prefix = "bootstrap"
  # }
}

resource "google_storage_bucket" "terraform_state" {
  name     = "acme-corp-terraform-state"
  location = "US"

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true
}
```

### State Backup and Recovery Examples

**Azure Storage Backend:**

Enable blob versioning or soft delete on the storage account:

```hcl
resource "azurerm_storage_account" "terraform_state" {
  name                     = "stacmeterraform"
  resource_group_name      = azurerm_resource_group.terraform_state.name
  location                 = azurerm_resource_group.terraform_state.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 90
    }

    container_delete_retention_policy {
      days = 90
    }
  }
}
```

To recover a previous state version from Azure Storage:

```bash
# List blob versions
az storage blob list \
  --account-name stacmeterraform \
  --container-name tfstate \
  --include v \
  --prefix environments/prod/terraform.tfstate \
  --output table

# Download a specific version
az storage blob download \
  --account-name stacmeterraform \
  --container-name tfstate \
  --name environments/prod/terraform.tfstate \
  --version-id <VERSION_ID> \
  --file terraform.tfstate.recovered
```

**GCS Backend:**

Enable object versioning on the GCS bucket:

```hcl
resource "google_storage_bucket" "terraform_state" {
  name     = "acme-corp-terraform-state"
  location = "US"

  versioning {
    enabled = true
  }

  # Optional: Configure lifecycle policy for version retention
  # GCS uses count-based retention (num_newer_versions) while AWS uses
  # time-based retention (noncurrent_days). Choose based on your needs:
  # - Count-based: Keeps last N versions regardless of age
  # - Time-based: Keeps versions for N days regardless of count
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
  }

  uniform_bucket_level_access = true
}
```

To recover a previous state version from GCS:

```bash
# List object versions
gsutil ls -la gs://acme-corp-terraform-state/environments/prod/

# Copy a specific generation (version)
gsutil cp gs://acme-corp-terraform-state/environments/prod/terraform.tfstate#<GENERATION> \
  terraform.tfstate.recovered
```

**Terraform Cloud:**

State versioning is automatic in Terraform Cloud. To access state history:

1. Navigate to your workspace in the Terraform Cloud UI
2. Click on "States" in the left navigation
3. Browse the list of state versions with timestamps
4. Click on any version to view details or download

State versions can also be accessed via the Terraform Cloud API:

```bash
# List state versions for a workspace
curl \
  --header "Authorization: Bearer $TFC_TOKEN" \
  https://app.terraform.io/api/v2/workspaces/<WORKSPACE_ID>/state-versions
```

### Cross-Stack Data Sharing Examples

#### Azure: App Configuration or Key Vault (Data Plane)

**Publishing values (network stack):**

```hcl
resource "azurerm_app_configuration" "main" {
  name                = "appconf-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_app_configuration_key" "vnet_id" {
  configuration_store_id = azurerm_app_configuration.main.id
  key                    = "network/vnet_id"
  value                  = azurerm_virtual_network.main.id
}

resource "azurerm_app_configuration_key" "subnet_ids" {
  configuration_store_id = azurerm_app_configuration.main.id
  key                    = "network/subnet_ids"
  value                  = jsonencode(azurerm_subnet.private[*].id)
}
```

**Consuming values (application stack):**

```hcl
data "azurerm_app_configuration" "main" {
  name                = "appconf-${var.project_name}-${var.environment}"
  resource_group_name = var.shared_resource_group_name
}

data "azurerm_app_configuration_key" "vnet_id" {
  configuration_store_id = data.azurerm_app_configuration.main.id
  key                    = "network/vnet_id"
}

data "azurerm_app_configuration_key" "subnet_ids" {
  configuration_store_id = data.azurerm_app_configuration.main.id
  key                    = "network/subnet_ids"
}

locals {
  vnet_id    = data.azurerm_app_configuration_key.vnet_id.value
  subnet_ids = jsondecode(data.azurerm_app_configuration_key.subnet_ids.value)
}
```

#### GCP: Cloud Storage with Metadata or Runtime Config

> **Note:** GCP does not have a direct equivalent to AWS SSM Parameter Store. For cross-stack configuration sharing, Cloud Storage buckets with JSON configuration files provide a simple, cost-effective approach.

**Publishing values (network stack):**

```hcl
resource "google_storage_bucket" "config" {
  name     = "${var.project_id}-terraform-config"
  location = var.region

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "network_config" {
  name    = "config/${var.environment}/network.json"
  bucket  = google_storage_bucket.config.name
  content = jsonencode({
    vpc_id     = google_compute_network.main.id
    subnet_ids = google_compute_subnetwork.private[*].id
  })
}
```

**Consuming values (application stack):**

```hcl
data "google_storage_bucket_object_content" "network_config" {
  name   = "config/${var.environment}/network.json"
  bucket = "${var.project_id}-terraform-config"
}

locals {
  network_config = jsondecode(data.google_storage_bucket_object_content.network_config.content)
  vpc_id         = local.network_config.vpc_id
  subnet_ids     = local.network_config.subnet_ids
}
```

### Provider Aliasing Examples

**Azure Example - Defining aliased providers:**

```hcl
# providers.tf

provider "azurerm" {
  features {}
  subscription_id = var.primary_subscription_id
  # Default provider (no alias)
}

provider "azurerm" {
  alias           = "secondary"
  features {}
  subscription_id = var.secondary_subscription_id
}
```

**Azure Example - Using aliased providers in resources:**

```hcl
# Use default provider
resource "azurerm_storage_account" "primary" {
  name                     = "stacmeprimary"
  resource_group_name      = azurerm_resource_group.primary.name
  location                 = azurerm_resource_group.primary.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Use aliased provider
resource "azurerm_storage_account" "secondary" {
  provider                 = azurerm.secondary
  name                     = "stacmesecondary"
  resource_group_name      = azurerm_resource_group.secondary.name
  location                 = azurerm_resource_group.secondary.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

**GCP Example - Defining aliased providers:**

```hcl
# providers.tf

provider "google" {
  project = var.primary_project_id
  region  = "us-central1"
  # Default provider (no alias)
}

provider "google" {
  alias   = "europe"
  project = var.primary_project_id
  region  = "europe-west1"
}

provider "google" {
  alias   = "secondary_project"
  project = var.secondary_project_id
  region  = "us-west1"
}
```

**GCP Example - Using aliased providers in resources:**

```hcl
# Use default provider
resource "google_storage_bucket" "primary" {
  name     = "acme-corp-primary-data"
  location = "US"
}

# Use aliased provider for different region
resource "google_storage_bucket" "europe" {
  provider = google.europe
  name     = "acme-corp-europe-data"
  location = "EU"
}
```

### Cross-Account and Service Account Pattern Examples

#### Azure: Subscription and Tenant Patterns

Azure provider configuration supports multi-subscription and multi-tenant scenarios through explicit subscription and tenant IDs.

**Basic multi-subscription configuration:**

```hcl
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id  # Required for multi-tenant scenarios

  # Skip provider registration when lacking permissions
  skip_provider_registration = true  # Use when service principal lacks registration permissions
}
```

**When to use `skip_provider_registration = true`:**

- Service principal lacks `Microsoft.Authorization/*/register/action` permission
- Deploying to shared subscriptions where resource providers are pre-registered
- Operating in environments with strict permission boundaries

> **Note:** When using `skip_provider_registration = true`, the required resource providers **MUST** already be registered in the subscription. Terraform will fail if it attempts to create resources for unregistered providers.

**Multi-subscription pattern with provider aliases:**

```hcl
provider "azurerm" {
  alias = "production"
  features {}

  subscription_id = var.production_subscription_id
  tenant_id       = var.tenant_id
}

provider "azurerm" {
  alias = "shared_services"
  features {}

  subscription_id = var.shared_services_subscription_id
  tenant_id       = var.tenant_id
}

resource "azurerm_resource_group" "prod" {
  provider = azurerm.production
  name     = "rg-prod-app"
  location = "eastus"
}

resource "azurerm_resource_group" "shared" {
  provider = azurerm.shared_services
  name     = "rg-shared-networking"
  location = "eastus"
}
```

#### GCP: Service Account Impersonation

Service account impersonation allows Terraform to act as a service account without requiring its key file. This pattern **SHOULD** be preferred over service account key files.

**Basic impersonation configuration:**

```hcl
provider "google" {
  project = var.project_id
  region  = var.region

  # Impersonate a service account instead of using default credentials
  impersonate_service_account = "terraform@${var.project_id}.iam.gserviceaccount.com"
}
```

**When to use impersonation:**

- CI/CD pipelines where the runner uses a less-privileged service account
- Local development with user credentials that need elevated access
- Implementing least-privilege access patterns
- Avoiding long-lived service account key files

**Required IAM permissions for impersonation:**

The calling identity must have `roles/iam.serviceAccountTokenCreator` on the target service account, or the `iam.serviceAccounts.getAccessToken` permission.

<!-- RATIONALE: benefits-of-service-account-impersonation-over-keys -->

**Multi-project pattern with impersonation:**

```hcl
provider "google" {
  alias   = "production"
  project = var.production_project_id
  region  = var.region

  impersonate_service_account = "terraform@${var.production_project_id}.iam.gserviceaccount.com"
}

provider "google" {
  alias   = "staging"
  project = var.staging_project_id
  region  = var.region

  impersonate_service_account = "terraform@${var.staging_project_id}.iam.gserviceaccount.com"
}
```

### Secret Manager Examples

**Azure Example - Key Vault:**

```hcl
data "azurerm_key_vault" "main" {
  name                = "kv-acme-prod"
  resource_group_name = "rg-terraform-state"
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  key_vault_id = data.azurerm_key_vault.main.id
}

resource "azurerm_mssql_server" "main" {
  administrator_login_password = data.azurerm_key_vault_secret.db_password.value
  # ... other configuration
}
```

**GCP Example - Secret Manager:**

```hcl
data "google_secret_manager_secret_version" "db_password" {
  secret  = "database-password"
  project = var.project_id
}

resource "google_sql_database_instance" "main" {
  # Password accessed via: data.google_secret_manager_secret_version.db_password.secret_data
  # ... other configuration
}
```

**HashiCorp Vault - Azure and GCP Examples:**

```hcl
# Azure Example
resource "azurerm_mssql_server" "main" {
  administrator_login          = data.vault_generic_secret.db_creds.data["username"]
  administrator_login_password = data.vault_generic_secret.db_creds.data["password"]
  # ... other configuration
}

# GCP Example
resource "google_sql_user" "main" {
  name     = data.vault_generic_secret.db_creds.data["username"]
  password = data.vault_generic_secret.db_creds.data["password"]
  instance = google_sql_database_instance.main.name
}
```

### Local Tags Pattern Examples

**GCP Example (Labels - lowercase keys required):**

```hcl
locals {
  # GCP labels must use lowercase keys
  common_labels = {
    name        = "${var.project_name}-${var.environment}"
    environment = var.environment
    project     = var.project_name
    managed_by  = "terraform"
  }

  # Merge common labels with resource-specific labels
  instance_labels = merge(local.common_labels, {
    role = "web-server"
  })
}
```

> **Note:** GCP label keys must be lowercase and can only contain lowercase letters, numeric characters, underscores, and dashes. AWS and Azure tags support mixed-case keys.

**Azure Example - Applying local tags to resources:**

```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}
```

**GCP Example - Applying local labels to resources:**

```hcl
resource "google_compute_instance" "main" {
  name         = "${var.project_name}-${var.environment}"
  machine_type = var.machine_type
  zone         = var.zone

  labels = local.common_labels
}
```

### Globally Unique Resource Names Examples

**Azure Example:**

```hcl
resource "random_id" "storage_suffix" {
  byte_length = 4
}

resource "azurerm_storage_account" "main" {
  # Azure Storage Account names must be 3-24 characters, lowercase alphanumeric only
  name                     = "st${var.project_short}${random_id.storage_suffix.hex}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
```

**GCP Example:**

```hcl
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "main" {
  name     = "${var.project_name}-${var.environment}-${random_id.bucket_suffix.hex}"
  location = var.region
}
```

---

## JSON Configuration Files (.tf.json)

Terraform supports JSON syntax for configuration files using the `.tf.json` extension. When using JSON configuration:

- `.tf.json` files **MUST** be valid JSON and **SHOULD** be consistently formatted
- JSON files **SHOULD** use 2 spaces for indentation to match HCL conventions
- JSON files **SHOULD** be validated and formatted using standard JSON tools such as `jq`, `prettier`, or IDE-integrated formatters
- JSON configuration **SHOULD** be reserved for programmatically generated Terraform code; hand-written configuration **SHOULD** use HCL (`.tf`) format for readability

**Validation command:**

```bash
# Validate JSON syntax
jq empty *.tf.json

# Format JSON files with jq
jq '.' input.tf.json > formatted.tf.json

# Format with prettier (if available)
prettier --write "*.tf.json"
```

**Note:** `terraform fmt` does not format `.tf.json` files. Use external JSON formatting tools as part of your pre-commit or CI workflow.

---

## Template File Formatting (.tftpl)

Template files (`.tftpl`) are processed by the `templatefile()` function and generate dynamic content. Formatting expectations for template files:

- Template files **MUST** use UTF-8 encoding
- Template files **MUST** end with a single newline
- Template files **SHOULD** use Unix-style line endings (LF) for cross-platform compatibility
- Template variables **SHOULD** be documented at the top of the file using comments appropriate to the output format
- Terraform template directives (`%{ ... }`, `${ ... }`) **SHOULD** be clearly formatted for readability
- When generating structured output (JSON, YAML), the template **SHOULD** produce valid, well-formatted output

**Comment conventions by output type:**

| Output Format | Comment Style | Example |
| --- | --- | --- |
| Shell scripts | `#` comments | `# Variable: environment (string)` |
| JSON | Document in separate header or external docs | N/A (JSON has no comments) |
| YAML | `#` comments | `# Variable: app_name (string)` |
| XML | `<!-- -->` comments | `<!-- Variable: config_value (string) -->` |

**Validation:**

- Template syntax errors are caught at `terraform plan` time when `templatefile()` is evaluated
- For templates generating JSON/YAML, validate the rendered output format as part of testing
- Use Terraform tests to verify template output for critical templates

---

## Troubleshooting Common Issues

This section provides guidance for resolving common Terraform errors and issues. Each entry includes the error message or symptom, cause, solution, and prevention strategies.

### Error: Error acquiring the state lock

**Symptom:**

```text
Error: Error acquiring the state lock

Error message: ConditionalCheckFailedException: The conditional request failed
Lock Info:
  ID:        a1b2c3d4-e5f6-7890-abcd-ef1234567890
  Path:      terraform.tfstate
  Operation: OperationTypePlan
  Who:       user@hostname
  Version:   1.7.0
  Created:   2026-01-15 10:30:00.000000000 +0000 UTC
```

**Cause:** A previous Terraform operation was interrupted (crash, network failure, timeout), or another user/process is running Terraform concurrently against the same state file.

**Solution:**

1. **Verify no other operations are running.** Check with your team and CI/CD system to confirm no other Terraform operations are in progress.
2. **If confirmed safe, force-unlock the state:**

   ```bash
   terraform force-unlock a1b2c3d4-e5f6-7890-abcd-ef1234567890
   ```

3. **If in CI/CD,** check for stuck or parallel jobs that may be holding the lock.

**Prevention:**

- Implement a single-operator policy or use CI/CD serialization to prevent concurrent operations
- Configure appropriate timeouts for long-running operations
- Use CI/CD pipelines with proper concurrency controls

> **Warning:** Never force-unlock a state if another operation is genuinely in progress. This can cause state corruption.

### Error: Provider configuration not present

**Symptom:**

```text
Error: Provider configuration not present

To work with aws_instance.example its original provider configuration at
provider["registry.terraform.io/hashicorp/aws"] is required, but it has been removed.
```

**Cause:** A resource exists in the state file, but the provider configuration that created it has been removed from the Terraform code.

**Solution:**

1. **Re-add the provider configuration** if the resource should still be managed:

   ```hcl
   provider "aws" {
     region = "us-east-1"
   }
   ```

2. **Remove the orphaned resource from state** if it was intentionally deleted:

   ```bash
   terraform state rm aws_instance.example
   ```

3. **Use a `removed` block** (Terraform 1.7+) to cleanly remove from state without destroying:

   ```hcl
   removed {
     from = aws_instance.example

     lifecycle {
       destroy = false
     }
   }
   ```

**Prevention:**

- Use `moved` blocks when refactoring resources
- Never remove provider configurations while resources using them still exist in state
- Review `terraform plan` output carefully before removing providers

### Error: Cycle detected

**Symptom:**

```text
Error: Cycle: aws_security_group.a, aws_security_group.b
```

**Cause:** Circular dependency between resources where resource A depends on resource B, and resource B depends on resource A.

**Solution:**

1. **Identify the cycle** from the error message—Terraform lists the resources involved
2. **Restructure to break the cycle:**
   - Use separate `aws_security_group_rule` resources instead of inline rules:

     ```hcl
     resource "aws_security_group" "a" {
       name = "sg-a"
       # No inline ingress/egress rules
     }

     resource "aws_security_group" "b" {
       name = "sg-b"
       # No inline ingress/egress rules
     }

     resource "aws_security_group_rule" "a_to_b" {
       type                     = "ingress"
       security_group_id        = aws_security_group.a.id
       source_security_group_id = aws_security_group.b.id
       from_port                = 443
       to_port                  = 443
       protocol                 = "tcp"
     }
     ```

   - Create a shared resource that both can reference
   - Reorganize dependencies to create a one-way relationship

**Prevention:**

- Avoid bidirectional references between resources
- Prefer one-way dependency graphs
- Use separate rule resources instead of inline blocks for security groups
- Review resource relationships before adding cross-references

### Error: Invalid for_each argument

**Symptom:**

```text
Error: Invalid for_each argument

The "for_each" value depends on resource attributes that cannot be determined until apply,
so Terraform cannot predict how many instances will be created.
```

**Cause:** The `for_each` or `count` expression depends on values that are not known until after `terraform apply` runs (e.g., resource IDs, computed attributes).

**Solution:**

1. **Restructure to use values known at plan time:**

   ```hcl
   # Instead of using computed values
   # BAD: for_each = toset(aws_subnet.private[*].id)

   # Use input variables or static values
   # GOOD: for_each = var.subnet_names
   variable "subnet_names" {
     type    = set(string)
     default = ["private-a", "private-b", "private-c"]
   }
   ```

2. **Split into separate configurations** if the dependency is unavoidable
3. **Use `-target` to create dependencies first** (not recommended for regular use):

   ```bash
   terraform apply -target=aws_subnet.private
   terraform apply
   ```

**Prevention:**

- Design `for_each` keys to use static values, input variables, or `locals` computed from known values
- Avoid using computed resource attributes as `for_each` keys
- Consider data architecture that separates resource creation from resource consumption

### Error: Unsupported Terraform Core version

**Symptom:**

```text
Error: Unsupported Terraform Core version

This configuration does not support Terraform version 1.5.0. To proceed,
either choose another supported Terraform version or update this version constraint.
Required version: >= 1.7.0
```

**Cause:** The installed Terraform version does not meet the `required_version` constraint specified in the configuration.

**Solution:**

1. **Install a compatible Terraform version:**

   ```bash
   # Using tfenv (recommended)
   tfenv install 1.7.0
   tfenv use 1.7.0

   # Or download directly from HashiCorp
   # https://releases.hashicorp.com/terraform/
   ```

2. **Update the version constraint** if the older version is acceptable for your use case:

   ```hcl
   terraform {
     required_version = ">= 1.5.0"  # Lowered from 1.7.0
   }
   ```

**Prevention:**

- Document version requirements in README files
- Use version managers like `tfenv` or `asdf` for consistent environments
- Pin Terraform versions in CI/CD pipelines
- Communicate version requirements to team members

### Error: Failed to query available provider packages

**Symptom:**

```text
Error: Failed to query available provider packages

Could not retrieve the list of available versions for provider hashicorp/aws:
could not connect to registry.terraform.io
```

**Cause:** Network connectivity issues, registry temporarily unavailable, proxy misconfiguration, or incorrect provider source specification.

**Solution:**

1. **Check network and proxy settings:**

   ```bash
   # Test registry connectivity
   curl -I https://registry.terraform.io

   # If using a proxy, ensure Terraform can access it
   export HTTPS_PROXY=http://proxy.example.com:8080
   ```

2. **Verify provider source is correct** in `required_providers`:

   ```hcl
   terraform {
     required_providers {
       aws = {
         source  = "hashicorp/aws"  # Verify this is correct
         version = "~> 5.0"
       }
     }
   }
   ```

3. **Wait and retry** if the registry is temporarily unavailable
4. **For air-gapped environments,** use provider mirroring:

   ```bash
   # Create a local mirror
   terraform providers mirror /path/to/mirror

   # Configure Terraform to use the mirror
   # In ~/.terraformrc or terraform.rc:
   provider_installation {
     filesystem_mirror {
       path = "/path/to/mirror"
     }
   }
   ```

**Prevention:**

- Commit `.terraform.lock.hcl` to version control to cache provider checksums
- Consider setting up a provider mirror for reliability in enterprise environments
- Use explicit provider source specifications in all configurations
- Test network connectivity before long Terraform operations

### Debugging with TF_LOG

Terraform provides environment variables for enabling detailed logging when troubleshooting unexpected behavior. These logs can help diagnose issues that don't match specific error patterns.

**TF_LOG levels:**

| Level | Description |
| --- | --- |
| `TRACE` | Most verbose; includes all internal operations |
| `DEBUG` | Detailed information for debugging |
| `INFO` | General operational information |
| `WARN` | Warning messages only |
| `ERROR` | Error messages only |

**Basic usage examples:**

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform plan

# Save logs to a file
export TF_LOG=TRACE
export TF_LOG_PATH=./terraform.log
terraform apply

# Disable logging when done
unset TF_LOG TF_LOG_PATH
```

**Provider-specific logging:**

Use `TF_LOG_PROVIDER` to isolate provider logs from core Terraform logs. This is useful when debugging provider-specific issues without the noise from Terraform core operations:

```bash
export TF_LOG_CORE=WARN
export TF_LOG_PROVIDER=DEBUG
terraform plan
```

**Common debugging scenarios:**

| Scenario | Recommended Level | What to Look For |
| --- | --- | --- |
| API errors | DEBUG | HTTP request/response details |
| Authentication issues | DEBUG | Credential resolution, assume role operations |
| Unexpected resource changes | TRACE | Attribute comparisons, diff calculations |
| Slow operations | INFO | Timing information, API call patterns |

> **Security Warning:** Terraform logs **MAY** contain sensitive information including credentials, API keys, and resource configurations. Log files **MUST NOT** be committed to version control or shared without careful redaction of sensitive data.

**Clean up reminder:**

After debugging, always unset the logging environment variables to avoid log accumulation and potential sensitive data exposure:

```bash
unset TF_LOG TF_LOG_PATH TF_LOG_CORE TF_LOG_PROVIDER
```

---

## Common State Problems and Recovery

### Error: "Error acquiring the state lock"

**Symptoms:**

```text
Error: Error acquiring the state lock

Error message: ConditionalCheckFailedException: The conditional request failed
Lock Info:
  ID:        a1b2c3d4-e5f6-7890-abcd-ef1234567890
  Path:      terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@hostname
  Version:   1.7.0
  Created:   2026-02-01 10:30:00.000000000 +0000 UTC
```

**Cause:**

- A previous Terraform operation was interrupted (crash, network failure, timeout)
- Another user or CI job is currently running Terraform against the same state
- The lock was not properly released after a failed operation

**Solution:**

1. **First, verify no operations are in progress.** Check with your team and CI system.

2. **If confirmed safe, force-unlock the state:**

   ```bash
   terraform force-unlock a1b2c3d4-e5f6-7890-abcd-ef1234567890
   ```

3. **If the lock ID is unknown, check your backend directly:**
   - For DynamoDB (AWS): Check the lock table for the lock entry
   - For Azure: Check blob lease status
   - For GCS: Lock is file-based; typically auto-expires

**Prevention:**

- Ensure only one operator or CI job runs Terraform at a time
- Use CI/CD pipelines with proper concurrency controls
- Configure appropriate timeouts for long-running operations

> **Warning:** Never force-unlock a state if another operation is genuinely in progress. This can cause state corruption.

### Error: "State file corrupted or invalid JSON"

**Symptoms:**

```text
Error: Failed to load state: unexpected end of JSON input
```

or

```text
Error: Failed to load state: invalid character '<' looking for beginning of value
```

**Cause:**

- Write operation was interrupted (network failure, process termination)
- Manual editing of state file with syntax errors
- Storage backend returned an error page instead of state file

**Solution:**

1. **Restore from backend versioning:**

   ```bash
   # Example for S3 - list versions and recover previous
   aws s3api list-object-versions \
     --bucket your-state-bucket \
     --prefix path/to/terraform.tfstate
   ```

2. **Restore from manual backup (if available):**

   ```bash
   terraform state push terraform.tfstate.backup.YYYYMMDD_HHMMSS
   ```

3. **If no backup exists, reconstruct from infrastructure:**

   ```bash
   # Remove corrupted state (create backup first)
   mv terraform.tfstate terraform.tfstate.corrupted

   # Re-import all resources using import blocks
   # See "Importing Resources with Import Blocks" section
   ```

**Prevention:**

- State files **MUST NOT** be manually edited
- Enable versioning on state storage (see [State Versioning Requirements](STYLE_GUIDE.md#state-versioning-requirements))
- Use reliable network connections for Terraform operations

### Error: "Resource exists in state but not in cloud"

**Symptoms:**

```text
Error: Error reading resource: ResourceNotFoundException
```

Terraform shows a resource in state, but the actual cloud resource has been deleted outside of Terraform (manually, via console, or by another tool).

**Cause:**

- Resource was deleted outside Terraform (console, CLI, another tool)
- Resource was deleted by cloud provider (expiration, policy enforcement)
- Incorrect AWS account, Azure subscription, or GCP project configured

**Solution:**

**Option 1: Remove from state using `removed` block (preferred):**

```hcl
removed {
  from = aws_instance.deleted_instance

  lifecycle {
    destroy = false
  }
}
```

**Option 2: Remove from state using CLI:**

```bash
# Create backup first
terraform state pull > terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)

# Remove the resource from state
terraform state rm aws_instance.deleted_instance
```

**Prevention:**

- Establish processes to ensure infrastructure changes go through Terraform
- Use `prevent_destroy` lifecycle rule for critical resources
- Implement drift detection (scheduled `terraform plan` in CI)

### Error: "Resource exists in cloud but not in state"

**Symptoms:**

Terraform plans to create a resource, but the resource already exists in the cloud. Or, you have infrastructure created outside Terraform that you want to bring under management.

**Cause:**

- Resource was created outside Terraform (manually, via console, or by another tool)
- State was lost or corrupted
- Resource was removed from state but not destroyed

**Solution:**

**Option 1: Use `import` block (preferred, Terraform 1.5+):**

```hcl
import {
  to = aws_instance.existing
  id = "i-0abc123def456789"
}

resource "aws_instance" "existing" {
  ami           = "ami-0abcdef1234567890"
  instance_type = "t3.micro"
  # ... configuration matching existing resource
}
```

Then run:

```bash
terraform plan  # Verify import will succeed
terraform apply # Perform the import
```

**Option 2: Use CLI import (legacy):**

```bash
terraform import aws_instance.existing i-0abc123def456789
```

After importing, review the state and update your configuration to match the imported resource's attributes.

**Prevention:**

- Establish processes to ensure infrastructure creation goes through Terraform
- Use workspace-specific naming conventions to identify Terraform-managed resources
- Tag resources with `ManagedBy = "terraform"` to identify ownership

---

## Scope Exceptions & Deviations from Standards

This section documents justified deviations from the standards defined in this document. When adopting this template, use this section to record exceptions specific to your organization, project, or deployment environment.

### How to Document Deviations

When a deviation from these standards is necessary, document it using the following format:

```markdown
#### [Short Description of Deviation]

- **Standard Affected:** [Link to or name of the standard being modified]
- **Reason:** [Business, technical, or organizational justification]
- **Scope:** [Which files, modules, or configurations are affected]
- **Approved By:** [Person or team who approved the deviation]
- **Date:** [YYYY-MM-DD]
- **Review Date:** [Optional: When this deviation should be reconsidered]
```

### Common Deviation Scenarios

The following are common scenarios where deviations may be justified:

- **Alternative Backend Workflows:** Using Terraform Cloud, Terraform Enterprise, Spacelift, or other orchestration tools instead of `backend.tf`. Document which backend sections do not apply.
- **Provider-Specific Requirements:** Organization policies that mandate specific provider configurations (e.g., required regions, mandatory tags beyond those listed).
- **Legacy Compatibility:** Maintaining compatibility with older Terraform versions or modules that cannot be immediately updated.
- **Organizational Naming Conventions:** Pre-existing naming conventions that conflict with this template but are required for consistency with other systems.
- **Security Policy Overrides:** Stricter security requirements that go beyond or differ from those specified here.

### Recorded Deviations

> **Note:** Replace the example below with actual deviations for your project, or remove this section if no deviations apply.

*No deviations recorded yet. When deviations are necessary, document them here using the format above.*

<!--
#### Example: Alternative Backend (Terraform Cloud)

- **Standard Affected:** Remote Backend Configuration
- **Reason:** Organization uses Terraform Cloud for state management, which provides built-in state storage, locking, and encryption.
- **Scope:** All root modules in this repository
- **Approved By:** @platform-team
- **Date:** 2026-01-15
- **Review Date:** 2027-01-15

The following Remote Backend Configuration requirements are handled by Terraform Cloud and do not require explicit configuration:
- State encryption (automatic in Terraform Cloud)
- State locking (automatic in Terraform Cloud)
- DynamoDB lock table configuration (not applicable)
- S3/GCS/Azure Storage bucket configuration (not applicable)

The `cloud` block in `versions.tf` replaces the `backend` block for this repository.
-->

---

## Changelog

This section tracks significant changes to the Terraform instruction file.

| Version | Date | Changes |
| --- | --- | --- |
| 2.2.20260412.0 | 2026-04-12 | Reduced token footprint of STYLE_GUIDE.md for LLM/agent consumption: removed TOC, metadata, cross-reference links; condensed RFC 2119 keywords; consolidated multi-provider examples to single AWS representative with inline notes; relocated procedural/runbook content, troubleshooting, changelog, glossary, .tf.json/.tftpl sections, and provider-specific examples to STYLE_GUIDE_RATIONALE.md |
| 2.1.20260412.0 | 2026-04-12 | Added extended rationale content to companion STYLE_GUIDE_RATIONALE.md: terraform_data advantages over null_resource, environment separation comparison table, workspace limitations, directory-based recommendation details, terraform_remote_state caveats, configuration_aliases rationale, and service account impersonation benefits |
| 2.0.20260412.0 | 2026-04-12 | Restructured into main guide (STYLE_GUIDE.md) and companion rationale document (STYLE_GUIDE_RATIONALE.md) |
| 1.17.20260202.0 | 2026-02-02 | Added Upgrading Terraform Versions section with version upgrade checklist, pre-upgrade preparation steps, patch/minor and major upgrade procedures, lock file update guidance, CI/CD considerations, rollback procedures, and version manager recommendations |
| 1.16.20260202.0 | 2026-02-02 | Added Troubleshooting Common Issues section with guidance for 6 common Terraform errors: state lock acquisition, provider configuration not present, cycle detected, invalid for_each argument, unsupported Terraform version, and failed provider package queries |
| 1.15.20260202.0 | 2026-02-02 | Added Cross-Account and Service Account Patterns section with AWS assume_role, Azure skip_provider_registration and multi-subscription patterns, GCP impersonate_service_account, summary comparison table, and security considerations |
| 1.14.20260202.0 | 2026-02-02 | Added State Backup and Recovery section with backup strategies, manual backup procedures, common state problems and recovery guidance, and state versioning requirements |
| 1.13.20260202.0 | 2026-02-02 | Added Environment Separation Strategies section with guidance on workspaces vs directory-based environment separation |
| 1.12.20260202.0 | 2026-02-02 | Added Table of Contents entry for Code Authoring Guidelines section, updated AWS provider version reference in README template to `~> 6.0`, made version constraint examples in Provider Version Constraints table and glossary provider-agnostic |
| 1.12.20260201.0 | 2026-02-01 | Added `configuration_aliases` for module provider configuration, module-level `depends_on` documentation, sensitive output exposure in CLI security guidance, Terraform Cloud workspace tags pattern |
| 1.11.20260201.0 | 2026-02-01 | Added ephemeral values (1.10+), terraform_data resource (1.4+), updated security scanning tools (tfsec → trivy transition), added changelog |
| 1.10.20260201.0 | 2026-02-01 | Initial version targeting Terraform 1.10+ |

When updating this document, add a new row describing the changes made.

---

## Glossary

This glossary defines key Terraform terms used throughout this document.

| Term | Definition |
| --- | --- |
| **.tf.json extension** | An alternative JSON syntax for Terraform configuration, typically used for programmatically generated code. |
| **.tftpl extension** | The recommended file extension for Terraform template files used with `templatefile()`. |
| **backend** | The configuration that determines where Terraform stores its state file. Common backends include S3, Azure Storage, GCS, and Terraform Cloud. |
| **check block** | A Terraform construct (v1.5+) that runs continuous validation assertions on every `plan` and `apply`, producing warnings rather than errors when assertions fail. |
| **child module** | A module that is called by another module (the parent). Child modules are reusable components typically located in a `modules/` directory. Contrast with root module. |
| **configuration_aliases** | A list in the `required_providers` block that declares which provider aliases a module expects to receive from calling modules. Required when modules use provider aliases internally. |
| **data source** | A Terraform configuration element that reads information from external sources (cloud APIs, files, other Terraform state) without creating or managing resources. Data sources are declared with `data` blocks and provide read-only access to existing infrastructure or external data. |
| **force-unlock** | A Terraform CLI command (`terraform force-unlock <LOCK_ID>`) that manually releases a state lock. Used to recover from interrupted operations but dangerous if used while another operation is genuinely in progress. |
| **HCL** | HashiCorp Configuration Language. The primary language used to write Terraform configurations in `.tf` files. |
| **import block** | A declarative block (v1.5+) that brings existing infrastructure under Terraform management without using CLI commands, enabling version-controlled and reviewable imports. |
| **lifecycle block** | A nested block within resource or data source blocks that customizes resource behavior. Supports `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`, `precondition`, and `postcondition` arguments. |
| **locals** | Named expressions defined in a `locals` block that can be referenced throughout a module. Local values simplify configuration by assigning names to expressions, reducing repetition, and improving readability. Also called "local values." |
| **moved block** | A declarative block (v1.1+) that tells Terraform to treat a resource at a new address as the same resource that previously existed at a different address, enabling safe refactoring without destroying resources. |
| **partial backend configuration** | A pattern where static backend settings are committed to version control while dynamic values (bucket names, regions) are provided at runtime via `-backend-config` flags or files. |
| **pessimistic constraint operator** | The `~>` operator used in version constraints that allows only the rightmost version component to increment (for example, `~> X.0` allows versions `>= X.0.0` and `< (X+1).0.0`, i.e., all `X.*` but no `(X+1).0.0` or later). |
| **provider** | A plugin that Terraform uses to interact with cloud platforms, SaaS providers, and other APIs. Examples include `aws`, `azurerm`, and `google`. |
| **provider alias** | A named instance of a provider configuration that enables deploying resources to multiple regions, accounts, or with different settings within the same configuration. |
| **removed block** | A declarative block (v1.7+) that removes a resource from Terraform state without destroying the underlying infrastructure. |
| **resource** | A block that describes one or more infrastructure objects, such as virtual machines, storage buckets, or DNS records. |
| **reusable module** | A self-contained Terraform configuration designed to be called from root modules or other modules. Located in `modules/` directories and versioned for reuse. |
| **root module** | The top-level Terraform configuration directory where `terraform init`, `plan`, and `apply` are executed. Contains provider and backend configuration. Contrast with reusable (child) modules. |
| **state file** | A JSON file (typically named `terraform.tfstate`) that Terraform uses to map configuration to real-world resources and track metadata. |
| **state locking** | A mechanism that prevents concurrent Terraform operations on the same state file, avoiding race conditions and state corruption. |
| **state versioning** | A backup mechanism where the state storage backend (S3, GCS, Azure Storage) retains previous versions of state files, enabling recovery from corruption or accidental changes. |
| **templatefile() function** | A Terraform function that reads a template file and renders it with provided variables, commonly used for generating scripts, policies, or configuration files. |
| **terraform.lock.hcl** | The dependency lock file that records the exact provider versions and checksums used, ensuring reproducible installations across team members and CI systems. |
| **tfvars** | A file with the `.tfvars` extension that provides values for input variables. Commonly used for environment-specific configuration. |
| **variable validation** | Custom validation rules defined within variable blocks that enforce constraints on input values at plan time. |
| **workspace** | An isolated instance of state data within a single Terraform configuration. Workspaces enable multiple deployments of the same configuration with separate state files. The default workspace is named "default." Referenced via `terraform.workspace` in configuration. |
