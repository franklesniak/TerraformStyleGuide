<!-- markdownlint-disable MD013 -->

# Markdown Linting Implementation

## Metadata

<!-- Version: 1.0.20260907.0 -->
- **Status:** Active
- **Owner:** Repository maintainer (@franklesniak)
- **Last Updated:** 2026-09-07
- **Scope:** Active outer-file and recursive nested-Markdown lint behavior in TerraformStyleGuide.
- **Related:** [Workflow script index](scripts-README.md), [Markdown workflow](markdownlint.yml)

## Active checks

The outer lint checks repository `.md` and `.mdc` files with `.github/workflows/.markdownlint.jsonc`. The recursive lint uses `lint-nested-markdown.js` to parse Markdown and inspect fenced blocks whose language is `markdown` or `md`. It excludes dependency directories and reports the source path, source line, nesting depth, and parent-block path for each violation.

The existing Husky hook runs both lint phases when staged Markdown changes. The `markdownlint.yml` workflow runs the same two phases in a separate lint job and preserves the repository's independent workflow-policy job. The separation prevents repository-controlled lint code and repository-controlled policy code from sharing a runner filesystem.

## Local validation

Run the workflow-local commands to reproduce the existing Husky and CI checks:

```bash
npm --prefix .github/workflows ci --ignore-scripts --no-audit --fund=false
npm --prefix .github/workflows run lint:md
npm --prefix .github/workflows run lint:md:nested
```

Run the root commands after the agent-governance dependencies are installed:

```bash
npm run lint:md
npm run lint:md:nested
```

Both lint phases exit 0 when no violation exists. A lint violation or tooling failure produces a nonzero exit. The CI workflow also verifies its reviewed package, lock, lint configuration, nested-lint helper, Node distribution, and workflow-policy inputs before it accepts the result.

## Nested-fence behavior

The recursive parser handles empty fences, different fence lengths, `markdown` and `md` identifiers, sibling blocks, and Markdown nested to arbitrary depth. It disables MD041 only for extracted snippets because a snippet does not need a top-level heading. All other configured rules remain active.
