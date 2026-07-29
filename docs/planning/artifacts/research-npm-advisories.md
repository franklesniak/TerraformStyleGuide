# Research — current Markdown-tooling advisories

Retrieved and checked 2026-07-29.

## Current repository audit

Command run from `.github/workflows`:

```text
npm audit --package-lock-only --json
```

Recorded result:

- exit code: 1;
- total vulnerable package nodes: 7;
- high: 5;
- moderate: 2; and
- nodes: `brace-expansion`, `js-yaml`, `linkify-it`, `markdown-it`,
  `markdownlint-cli2`, `minimatch`, and `picomatch`.

Only names and aggregate counts are retained here because advisory details can
change. The dedicated remediation issue must rerun the audit.

## npm audit behavior

Primary source:

- <https://docs.npmjs.com/cli/v11/commands/npm-audit/>

Durable facts:

- `npm audit` submits the configured dependency tree for known-vulnerability
  analysis and calculates impact/remediation.
- It returns zero when no vulnerabilities are found and normally returns
  nonzero when vulnerabilities are present.
- `--audit-level` changes the failure threshold, not which findings appear in
  the report.
- `--package-lock-only` uses the lockfile rather than `node_modules`.
- Some findings require manual review; `npm audit fix --force` can install
  dependencies outside declared ranges and should not be an unreviewed default.

## Dependabot

Primary sources:

- <https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/configure-version-updates>
- <https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference>

Durable facts:

- Each monitored ecosystem needs a `package-ecosystem`, manifest `directory`,
  and schedule.
- The TerraformStyleGuide npm manifest/lockfile are in
  `/.github/workflows`, so that is the npm ecosystem directory.
- Dependabot creates reviewable update pull requests; it does not disposition
  the current audit by itself.

## Planning consequence

Dependency remediation should be separately owned and linked. Default ordering
after T2 preserves the T1/T2 tooling baseline. If repository policy blocks
current high advisories, move remediation before T1 and then rebaseline both
issue descriptions.
