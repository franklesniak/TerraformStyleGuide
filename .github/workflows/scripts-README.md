<!-- markdownlint-disable MD013 -->

# Workflow Script Index

## Metadata

- **Status:** Active
- **Owner:** Repository maintainer (@franklesniak)
- **Last Updated:** 2026-10-01
- **Scope:** Repository-owned scripts in `.github/workflows` and their supported local entry points.
- **Related:** [Markdown lint implementation](MARKDOWN-LINTING-IMPLEMENTATION.md)

## Script inventory

| Script | Purpose | Supported command |
| --- | --- | --- |
| `Check-NpmAudit.mjs` | Checks the locked dependency graphs against current npm advisories. | `node .github/workflows/Check-NpmAudit.mjs` |
| `Generate-StyleGuideArtifacts.ps1` | Regenerates consumer style-guide artifacts from the normative and rationale sources. | `pwsh -NoLogo -NoProfile -File .github/workflows/Generate-StyleGuideArtifacts.ps1` |
| `Get-SupplyFreezeDigest.mjs` | Optional manual diagnostic; no routine CI, update, or merge requirement. Reads `historical-supply-profile.json` for the retained historical tuple. Computes the reviewed workflow supply-freeze digest. | See [Prepare and record on Linux/x64](../../docs/T1-SUPPLY-FREEZE-CURRENT-PROVENANCE-v1.md#prepare-and-record-on-linuxx64); bare invocation is unsupported. |
| `install-husky.mjs` | Activates the retained Git hook during setup and prepare. | Called by `NpmTools.mjs install` and the workflow package's `prepare` script; no separate routine invocation is needed. |
| `lint-nested-markdown.js` | Recursively lints `markdown` and `md` fenced content in repository `.md` and `.mdc` files. | `npm run lint:md:nested` |
| `lint-staged-markdown.mjs` | Selects and lints outer and nested staged `.md` and `.mdc` content without replacing worktree files. | `node .github/workflows/lint-staged-markdown.mjs` |
| `NpmTools.mjs` | Installs both locked dependency graphs with isolated npm configuration and activates the retained hook. | `node .github/workflows/NpmTools.mjs install` |
| `Test-AgentInstructions.ps1` | Validates governed instruction capacity, operative policy, final-state metadata, staged-input matching, and behavioral mutation controls. | `npm run test:agent-instructions` |
| `Validate-WorkflowPolicy.mjs` | Validates workflow structure, helper interfaces, and locked parser integrity; run `node --test .github/workflows/Validate-WorkflowPolicy.test.mjs` for negative fixtures. | `node .github/workflows/Validate-WorkflowPolicy.mjs .github/workflows/build.yml .github/workflows/markdownlint.yml` |

The native required checks keep their existing names. `verify` runs deterministic generation and checks the stable result schemas and committed artifacts. `policy` validates the workflow structure, helper selection, and reviewed parser integrity. `markdownlint` runs both existing Markdown lint phases. Candidate instruction tests are separate from the accepted-base maintenance classification. Classification does not grant maintenance authority; the authenticated owner/executor review process still binds scope, current head/base/policy, candidate tests, findings, and independent final quality review.

For current manifest and lock validation before dependency installation, run `node .github/workflows/Validate-WorkflowPolicy.mjs --preflight`. After the locked workflow dependencies are installed, run `node .github/workflows/Validate-WorkflowPolicy.mjs .github/workflows/build.yml .github/workflows/markdownlint.yml`. Historical runtime-selector equality admission is retired; its old implementation remains in Git history.

The shared Linux CI helpers are `Initialize-CiToolchain.ps1`, `Test-CheckoutCredentials.ps1`, `Test-StyleGuideArtifacts.ps1`, and `Invoke-MarkdownLint.ps1`. The runtime declaration is `ci-toolchain.json`. Run helper behavior tests with `node --test .github/workflows/Test-CiHelpers.test.mjs .github/workflows/Test-LocalValidation.test.mjs`; Linux is required for the loader, runtime, and shell-hook cases. Run classifier tests with `node --test .github/workflows/Classify-InstructionMaintenance.test.mjs`.

Run installer and audit tests with `node --test .github/workflows/NpmTools.test.mjs .github/workflows/Check-NpmAudit.test.mjs`. See [dependency maintenance](../../docs/dependency-maintenance.md) for installation behavior, audit results and the `npm-risk-exceptions.json` record.

## Setup and validation

PowerShell 7 (`pwsh`) must be on `PATH` first. [Install](https://learn.microsoft.com/powershell/scripting/install/install-powershell), then verify with `pwsh -NoProfile -Command 'if ($PSVersionTable.PSVersion.Major -lt 7) { exit 1 }'`. Use the exact Node and npm versions in the root `package.json`. After a fresh clone or lock change, run `node .github/workflows/NpmTools.mjs install`. Install the pinned Python tools after a fresh clone or `requirements-dev.txt` change. On Windows, run `py -3.12 -m pip install --requirement requirements-dev.txt`; on other platforms, run `python3.12 -m pip install --requirement requirements-dev.txt`, with a verified Python 3.12 command substituted when necessary. Before a commit, run `py -3.12 -m pre_commit run --all-files` on Windows or `python3.12 -m pre_commit run --all-files` on other platforms, with the same substitution when necessary. The existing Husky hook remains active for staged Markdown.

The nested Markdown linter uses `.github/workflows/.markdownlint.jsonc`. It reports the outer file, source line, nesting depth, and parent path. It exits 0 only when all extracted blocks pass.
