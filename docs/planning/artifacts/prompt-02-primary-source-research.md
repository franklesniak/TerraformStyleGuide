# Prompt 02 primary-source research

Research date: 2026-07-29 UTC.

## Finding T1/T2-2 — Node runtime policy

### Current TerraformStyleGuide state

The current repository was inspected directly:

- `.github/workflows/markdownlint.yml` selects Node 20.
- `.github/workflows/package.json` has no `engines.node` or `devEngines`
  declaration.
- `.husky/pre-commit` requires `npm` and the installed
  `markdownlint-cli2` binary but does not query or constrain Node.
- the lockfile currently installs `markdownlint-cli2@0.20.0` and
  `markdownlint@0.40.0`, whose recorded engine floors are Node `>=20`.

### Candidate package-engine change

Primary sources:

- [`markdownlint-cli2` v0.23.2 `package.json`](https://github.com/DavidAnson/markdownlint-cli2/blob/v0.23.2/package.json)
- [`markdownlint` v0.41.1 `package.json`](https://github.com/DavidAnson/markdownlint/blob/v0.41.1/package.json)
- [`markdownlint-cli2` v0.23.2 changelog](https://github.com/DavidAnson/markdownlint-cli2/blob/v0.23.2/CHANGELOG.md)

Durable retrieved facts:

- `markdownlint-cli2@0.23.2` declares `"engines": { "node": ">=22" }`.
- Its package metadata selects `markdownlint@0.41.1`.
- `markdownlint@0.41.1` also declares Node `>=22`.
- The upstream 0.23.0 changelog explicitly says Node 20 support was removed.
- Therefore, installing that line while CI or the hook admits Node 20 is a
  known contradiction, not a compatibility risk that can be deferred as
  hypothetical.

The final remediation issue must re-query the selected versions and lockfile;
these facts establish the current decision baseline, not an immutable future
version mandate.

### Supported Node releases on the research date

Primary source:

- [Node.js release status](https://nodejs.org/en/about/previous-releases)

Retrieved status on 2026-07-29:

- Node 20 is end-of-life; its last listed update is 2026-03-24.
- Node 22 is LTS.
- Node 24 is LTS and is identified by the page as the latest LTS line.
- Node 26 is Current, not LTS.
- The Node project recommends production applications use Active LTS or
  Maintenance LTS releases.

This makes continued Node 20 admission indefensible for a newly upgraded
toolchain. Both Node 22 and Node 24 are supportable choices. Testing the package
minimum (22) and the preferred/latest LTS line (24) provides broader evidence
than silently choosing one.

### What package metadata can and cannot enforce

Primary source:

- [npm `package.json` documentation: `engines` and `devEngines`](https://docs.npmjs.com/cli/v11/configuring-npm/package-json#engines)

Durable retrieved facts:

- `engines.node` records the Node versions on which a package/project works.
- Without npm's `engine-strict` setting, `engines` is advisory and ordinarily
  warns rather than enforcing when the package is installed as a dependency.
- npm documents `devEngines` as a source-tree contributor control that runs
  before `install`, `ci`, and `run`; it is structurally and behaviorally
  different from `engines`.
- Because repository contributors can arrive through a Git hook or an npm
  version with different enforcement behavior, metadata alone is not sufficient
  evidence. The hook and workflow need explicit, consistent runtime checks.

### Husky and contributor environments

Primary source:

- [Husky “How To”: Node version managers and GUIs](https://typicode.github.io/husky/how-to.html#node-version-managers-and-guis)

Durable retrieved facts:

- GUI Git clients may not inherit version-manager initialization and can resolve
  no Node/npm or a different Node than an interactive shell.
- Husky documents `~/.config/husky/init.sh` as the initialization point for
  version-manager setup.
- The repository already gives this troubleshooting guidance. A runtime-policy
  change should preserve it and add an early actual-version diagnostic rather
  than allowing an opaque later package failure.

### Planning consequence

The separate npm-remediation issue must own the Node decision and all affected
files. The strongest current policy is:

1. declare a minimum compatible Node line in package metadata;
2. reject an older runtime early in the hook with a stable message;
3. validate the selected minimum and the preferred LTS line in CI/evidence; and
4. recompute the exact file set after the final dependency choice.

This is separate from the Node runtime embedded inside pinned GitHub Actions;
an action's internal runtime does not itself establish the repository's npm
tooling policy.

## Finding T1/T2-3 — Executable evidence and governance

### The actual Terraform hook is the integration target

Primary sources:

- [Git `githooks` documentation](https://git-scm.com/docs/githooks)
- [`markdownlint-cli2` v0.20.0 README exit-code contract](https://github.com/DavidAnson/markdownlint-cli2/blob/v0.20.0/README.md#exit-codes)

Durable retrieved facts:

- Git invokes `pre-commit` before creating the commit; a nonzero hook result
  aborts the commit, although the user can deliberately bypass it with
  `--no-verify`.
- `markdownlint-cli2` documents exit 0 as successful lint with no errors, exit
  1 as successful lint that found Markdown errors, and exit 2 as a tooling or
  execution failure.
- TerraformStyleGuide's hook uses these distinctions for the outer lint, then
  invokes its separate nested-lint script. It does not use PSStyleGuide's
  programmatic `main`/`nonFileContents` integration.
- Therefore, ordinary lint commands alone are insufficient. Validation must
  invoke the exact Terraform hook in an isolated index/repository state and
  prove its skip, pass, lint-rejection, and tooling-failure outcomes.

### Negative fixtures

Current repository inspection found only:

- `samples/test-nested-markdown-linting.md`; and
- `samples/test-recursive-nested-markdown.md`.

Both are positive samples. `samples/test-violations-recursive.md` does not
exist. A claim about “existing negative fixtures” would therefore be false.
Tracked negative fixtures would also make the repository-wide ordinary lint
fail unless excluded or encoded specially. Deterministic temporary fixtures in
an isolated clone/worktree are the safer default:

1. stage the test-owned fixture so the hook activates;
2. require the exact expected rule/file/depth diagnostic;
3. distinguish lint exit 1 from startup/configuration failure;
4. clean only the test-owned repository/fixture; and
5. leave the implementation index untouched.

### Audit semantics and residual approvals

Primary source:

- [npm `audit` documentation](https://docs.npmjs.com/cli/v11/commands/npm-audit/)

Durable retrieved facts:

- `npm audit` sends the configured dependency tree to the registry for known
  vulnerability analysis and remediation calculation.
- It exits zero when no vulnerabilities are found and ordinarily nonzero when
  findings meet the configured failure threshold.
- `--audit-level` changes the failure threshold but does not filter the report.
- `--package-lock-only` uses the lockfile while ignoring `node_modules`.
- `--json` returns detailed machine-readable evidence.
- `--force` can install outside declared dependency ranges and bypass engine
  protections; npm explicitly advises against using it without understanding
  the consequences.

The current seven-node/five-high/two-moderate result is a dated baseline.
Package nodes are not a sufficient approval key because a node can have
multiple advisories and dependency paths. The implementation must enumerate
the complete current URL/path set. Any residual exception must be structured
with URL, dependency path, owner, UTC expiration, and a real follow-up issue,
then validated for completeness, uniqueness, and nonexpiration.

### Dependabot final-state evidence

Primary source:

- [GitHub Dependabot options reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference)

Durable retrieved facts:

- Dependabot configuration version is `2`.
- Every update entry requires a package ecosystem, manifest directory, and
  schedule interval.
- The Terraform npm manifest is in `/.github/workflows`; the existing T1
  GitHub Actions entry is for `/`.
- A final two-entry file can be validated structurally and by normalized exact
  content. That validation should reject duplicate/extra entries and
  auto-approval/auto-merge additions in the changed scope.

### Supersession consequence

T1's implementation-time gate requires exactly one GitHub Actions Dependabot
entry. A later npm entry necessarily makes that assertion false. T1 and T2 also
have issue-specific changed-path/staged-set gates that are not enduring
repository invariants.

The remediation issue must distinguish:

- enduring behavior that remains green (generator, helper, permissions,
  immutable action pins, artifact behavior, and lint semantics);
- final-state assertions that replace an intermediate assertion (two
  Dependabot entries instead of one); and
- one-time implementation scope gates that are superseded by the new issue's
  own affected-file contract.
