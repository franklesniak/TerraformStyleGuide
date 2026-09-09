<!-- markdownlint-disable MD013 -->

# Workflow Script Index

## Metadata

- **Status:** Active
- **Owner:** Repository maintainer (@franklesniak)
- **Last Updated:** 2026-09-08
- **Scope:** Repository-owned scripts in `.github/workflows` and their supported local entry points.
- **Related:** [Markdown lint implementation](MARKDOWN-LINTING-IMPLEMENTATION.md)

## Script inventory

| Script | Purpose | Supported command |
| --- | --- | --- |
| `Generate-StyleGuideArtifacts.ps1` | Regenerates consumer style-guide artifacts from the normative and rationale sources. | `pwsh -NoLogo -NoProfile -File .github/workflows/Generate-StyleGuideArtifacts.ps1` |
| `Get-SupplyFreezeDigest.mjs` | Computes the reviewed workflow supply-freeze digest. | `node .github/workflows/Get-SupplyFreezeDigest.mjs` |
| `lint-nested-markdown.js` | Recursively lints `markdown` and `md` fenced content in repository `.md` and `.mdc` files. | `npm run lint:md:nested` |
| `lint-staged-markdown.mjs` | Selects and lints outer and nested staged `.md` and `.mdc` content without replacing worktree files. | `node .github/workflows/lint-staged-markdown.mjs` |
| `Test-AgentInstructionParserManifest.mjs` | Validates the root parser manifest and lock as inert data before dependency installation. | `node .github/workflows/Test-AgentInstructionParserManifest.mjs --repository-root . --trusted-revision $(git rev-parse HEAD) --input-revision $(git rev-parse HEAD) --self-test` |
| `Test-AgentInstructions.ps1` | Validates governed instruction capacity, operative policy, metadata transitions, Git ranges, and mutation controls. | `npm run test:agent-instructions` |
| `Validate-WorkflowPolicy.mjs` | Validates the repository's embedded workflow policy and negative fixtures. | `node .github/workflows/Validate-WorkflowPolicy.mjs .github/workflows/build.yml .github/workflows/markdownlint.yml` |

## Setup and validation

Use the exact Node and npm versions in the root `package.json`. After a fresh clone or lock change, run `npm run bootstrap:agent-instructions`. Install the pinned Python tools after a fresh clone or `requirements-dev.txt` change. On Windows, run `py -3.12 -m pip install --requirement requirements-dev.txt`; on other platforms, run `python3.12 -m pip install --requirement requirements-dev.txt`, with a verified Python 3.12 command substituted when necessary. Before a commit, run `py -3.12 -m pre_commit run --all-files` on Windows or `python3.12 -m pre_commit run --all-files` on other platforms, with the same substitution when necessary. The existing Husky hook remains active for staged Markdown.

The nested Markdown linter uses `.github/workflows/.markdownlint.jsonc`. It reports the outer file, source line, nesting depth, and parent path. It exits 0 only when all extracted blocks pass.
