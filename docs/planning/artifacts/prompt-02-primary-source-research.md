# Prompt 02 primary-source research

Research date: 2026-07-29 UTC.

## Current finding T1-1 — Hosted Node 24 boundary

Primary sources:

- [Node.js release status](https://nodejs.org/en/about/previous-releases)
- [`actions/setup-node` usage and cache behavior](https://github.com/actions/setup-node)
- [`markdownlint-cli2@0.20.0` package metadata](https://www.npmjs.com/package/markdownlint-cli2/v/0.20.0)
- [`markdownlint@0.40.0` package metadata](https://www.npmjs.com/package/markdownlint/v/0.40.0)

Durable facts rechecked on 2026-07-29:

- Node 20 is EOL. Node 22 and Node 24 are LTS; Node 24 is the latest LTS line
  on the release table.
- The official setup-node documentation recommends specifying the installed
  Node version instead of relying on `PATH`.
- Setup-node can automatically enable npm caching when `packageManager` or
  `devEngines.packageManager` declares npm. The
  `package-manager-cache: false` input disables that behavior explicitly.
- The current TerraformStyleGuide package manifest has neither of those
  package-manager fields, so caching is currently inactive; setting the input
  to `false` prevents a later metadata change from silently altering the
  trusted workflow.
- Registry metadata queried with npm 11.7.0 confirms that both currently
  installed direct lint packages declare `engines.node` as `>=20`. Node 24 is
  inside that range, so T1 can update the hosted major without changing the
  package or lockfile.

Planning consequence: T1 can own exact hosted Node 24 plus explicit cache
disablement while T3 retains the final package minimum, `engines.node`, hook
guard, dependency upgrade, and dual-runtime evidence.

## Current finding T1-2 — Trusted temporary-root creation

Primary sources:

- [.NET `Path.GetRandomFileName`](https://learn.microsoft.com/dotnet/api/system.io.path.getrandomfilename?view=netframework-4.8.1)
- [.NET `Directory.CreateDirectory`](https://learn.microsoft.com/dotnet/api/system.io.directory.createdirectory?view=netframework-4.8.1)
- [GitHub Actions variables](https://docs.github.com/en/actions/reference/workflows-and-actions/variables)

Durable facts:

- `Path.GetRandomFileName()` returns a random folder or file name but does not
  create an entry.
- `Directory.CreateDirectory(path)` creates missing directories but returns a
  `DirectoryInfo` even when the target directory already exists. A successful
  call is therefore not evidence that the current invocation acquired a new
  root.
- GitHub documents `RUNNER_TEMP` as a runner temporary directory emptied at
  the beginning and end of a job, subject to the runner account's ability to
  delete entries.
- T1's hosted-runner/no-competing-writer model makes the runner temporary
  directory an appropriate parent, but does not establish ownership of an
  arbitrary child. The caller still needs absence, create-without-force, and
  ordinary/non-reparse verification.

Planning consequence: define one exact bounded-retry creation algorithm and a
separate fail-closed caller teardown algorithm. The helper must continue to
validate the caller's claim independently.

## Current finding T1-3 — Stable helper-harness case IDs

Repository evidence:

- T1's current fixture table has no ID column and groups missing/extra,
  duplicate/collision, slash variants, traversal variants, root-overlap
  directions, and optional-label permutations.
- Current P1 already defines a stable comparable taxonomy:
  `V-*` valid archives, `P-*` valid path classification, `D-*` digest and
  label diagnostics, `Z-*` ZIP readability, `M-*` manifest grammar, `E-*`
  envelope/path security, `L-*` preexisting leaves, `B-*` post-extraction byte
  rejection, `K-*` cleanup, and `X-*` explicitly empty labels.
- P1 assigns a separate row to every forward/backslash, overlap direction,
  leaf type, and optional label. It pairs each ID with platform/precondition,
  expected phase, candidate-leaf postcondition, and required diagnostics.
- P1 has symmetric digest failures: supplied diagnostic sentinels (`D-01`) and
  all labels omitted/rendered `unavailable` (`D-02`).

Planning consequence: reuse the same IDs for behaviorally shared cases so
cross-repository evidence can be compared directly. Use repository-specific
manifest bytes/names inside those cases, and allocate a new documented ID only
for a genuinely Terraform-only behavior.

## Current finding T1-4 — Writer environment/ref normalization

Primary sources:

- [Git `check-ref-format`](https://git-scm.com/docs/git-check-ref-format)
- [Git `push`](https://git-scm.com/docs/git-push)
- [GitHub Actions variables](https://docs.github.com/en/actions/reference/workflows-and-actions/variables)

Durable facts:

- `git check-ref-format <refname>` is Git's own validation boundary for a
  complete ref and returns nonzero for an unacceptable name.
- Git's ref grammar rejects ASCII controls, spaces, backslash, wildcard
  characters, ambiguous dot sequences, and several revision/refspec syntax
  characters. A string-prefix check for `refs/heads/` does not implement that
  grammar.
- A push refspec explicitly controls the source object and destination ref.
  `--force-with-lease=<ref>:<expect>` binds the permitted update to an expected
  remote value.
- GitHub supplies `GITHUB_REF` and `GITHUB_SHA` as default environment
  variables. T1 also maps the corresponding workflow expressions into
  purpose-specific `TARGET_REF` and `EXPECTED_SHA` values.
- Current P1 reads `TARGET_REF`/`EXPECTED_SHA` into locals, reads the GitHub
  variables once for comparison, and then forbids rereads. The criticism's
  four-local first-boundary rule is stronger than P1's literal current text.

Planning consequence: copy all four values once, validate each local, compare
the two independent pairs, and never read ambient values again. Use
`git check-ref-format` on the complete target ref and the unchanged validated
locals for remote observation, parent proof, lease, and refspec.

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

### Dated audit snapshot retrieved for this evaluation

On 2026-07-29, local Node 26.5.0/npm 11.7.0 ran:

```text
npm audit --package-lock-only --json
```

against the unchanged lockfile. It returned seven affected package nodes
(five high, two moderate, zero critical) and these advisory mappings:

| Package node | Advisory URLs in the report |
| --- | --- |
| `node_modules/brace-expansion` | `GHSA-f886-m6hf-6m8v`, `GHSA-3jxr-9vmj-r5cp`, `GHSA-mh99-v99m-4gvg` |
| `node_modules/js-yaml` | `GHSA-h67p-54hq-rp68`, `GHSA-52cp-r559-cp3m` |
| `node_modules/linkify-it` | `GHSA-22p9-wv53-3rq4`, `GHSA-v245-v573-v5vm` |
| `node_modules/markdown-it` | `GHSA-38c4-r59v-3vqw`, `GHSA-6v5v-wf23-fmfq` |
| `node_modules/markdownlint-cli2` | aggregate effect through `js-yaml` and `markdown-it` |
| `node_modules/minimatch` | `GHSA-3ppc-4f35-3m26`, `GHSA-7r86-cg39-jmmj`, `GHSA-23c5-xmqv-rm74` |
| `node_modules/picomatch` | `GHSA-3v7f-55p6-f55p`, `GHSA-c2c7-rcm5-vvqj` |

Every identifier above is a GitHub Advisory Database path under:

```text
https://github.com/advisories/<GHSA identifier>
```

The report offered a semver-major move to `markdownlint-cli2` 0.23.2 for the
aggregate direct-package path and reported fixes available for the other
transitive nodes. This remains research input only: T3 must refresh the full
report and dependency paths with its selected supported Node/npm immediately
before package selection.

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

## Current finding T1-6 — Exact GitHub Action allowlist

Primary sources:

- [GitHub secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [`actions/checkout` v7.0.1 release](https://github.com/actions/checkout/releases/tag/v7.0.1)
- [`actions/setup-node` v7.0.0 release](https://github.com/actions/setup-node/releases/tag/v7.0.0)
- [`actions/upload-artifact` v7.0.1 release](https://github.com/actions/upload-artifact/releases/tag/v7.0.1)
- [`actions/download-artifact` v8.0.1 release](https://github.com/actions/download-artifact/releases/tag/v8.0.1)

Retrieval and verification:

- On 2026-07-29, `git ls-remote` against each official repository resolved the
  exact tag refs to:
  - `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1`
    (`v7.0.1`);
  - `actions/setup-node@820762786026740c76f36085b0efc47a31fe5020`
    (`v7.0.0`);
  - `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`
    (`v7.0.1`); and
  - `actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c`
    (`v8.0.1`).
- The GitHub release pages display the matching abbreviated commits and
  verified signatures. `setup-node` marks the release immutable.
- GitHub's secure-use guidance says a full-length commit SHA is the only
  immutable release reference and recommends verifying that the SHA belongs to
  the action's repository.

Planning consequence:

- A verifier that checks only “40 hexadecimal characters” prevents mutable
  tags but still admits an arbitrary commit or the wrong action in a workflow
  role.
- T1 should carry an offline exact allowlist of repository, full SHA, reviewed
  release annotation, and allowed workflow/role. The release commits must be
  re-resolved at implementation time; an intentional upgrade changes the
  allowlist and every corresponding `uses:` line atomically.
- An online lookup during ordinary CI would make validation depend on current
  network and tag state. Upstream verification belongs in the reviewed update
  process, while ordinary validation should be deterministic and offline.

## Current finding T2-1 — HCP host, page, and curl token grammar

Primary sources:

- [HashiCorp: HCP Terraform in Europe](https://developer.hashicorp.com/terraform/cloud-docs/europe)
- [HashiCorp: state versions API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/state-versions)
- [HashiCorp: API overview and pagination](https://developer.hashicorp.com/terraform/enterprise/api-docs)
- [curl command-line and config-file manual](https://curl.se/docs/manpage.html)

Durable retrieved facts:

- HashiCorp identifies `app.eu.terraform.io` as the HCP Europe Terraform host.
  The public non-EU API examples use `app.terraform.io`. Europe organizations
  are separate and are not a hostname alias for the non-EU control plane.
- Listing workspace state versions is
  `GET /api/v2/state-versions` and requires both
  `filter[workspace][name]` and `filter[organization][name]`.
- The endpoint supports `page[number]` and `page[size]`; the API overview says
  list endpoints default to 20 and cap page size at 100.
- curl config files accept one option per physical line. Quoted values process
  backslash escapes including `\"`, `\\`, `\t`, `\n`, `\r`, and `\v`.
  Therefore, inserting an arbitrary bearer token between quotes is not safe
  merely because shell expansion is avoided.

Planning consequence:

- The public guide should use a closed HCP host selector with exactly
  `app.terraform.io` and `app.eu.terraform.io`, validated before URL or token
  file construction. An arbitrary host would silently broaden the credential
  destination to Terraform Enterprise and attacker-controlled hosts.
- `PAGE_NUMBER` needs a canonical positive-decimal grammar such as
  `^[1-9][0-9]*$`; checking only nonempty permits query/config injection and
  ambiguous page zero/leading-zero values.
- Before a token is written to a curl config file, reject empty values, CR/LF,
  control bytes, double quote, and backslash. Create the file privately, invoke
  curl with an explicit `--config` and `--disable`, and remove only that exact
  owned file on every exit.

## Current finding T2-2 — Inventory outside the four recovery blocks

Repository sources inspected:

- `STYLE_GUIDE.md`
- `STYLE_GUIDE_RATIONALE.md`
- `docs/planning/TerraformStyleGuide/04TerraformStyleGuideT2.md`

Durable local facts:

- T2's provider-specific target is four surfaces: S3, Azure Blob Storage,
  Google Cloud Storage, and HCP Terraform state-version discovery/retrieval.
- Outside those blocks, `STYLE_GUIDE.md` contains two
  `terraform state pull > ...` backup examples, an unguarded
  `terraform state push`, and related state-manipulation guidance.
- `STYLE_GUIDE_RATIONALE.md` contains additional direct-redirection backups,
  destructive `terraform state push` examples, a local `mv` corruption-
  recovery operation, another S3 listing example, `terraform state rm`, and
  older Azure/GCS/HCP examples.
- Direct shell redirection truncates an existing path before Terraform's exit
  status can prove a valid backup. The destructive operations also require a
  different concurrency/confirmation/rollback contract than versioned-object
  retrieval.

Planning consequence:

- T2 must say “every destination introduced or modified by this issue” and
  enumerate only the four provider-specific blocks. Its generic sensitive-
  state warning can remain provider-neutral.
- The adjacent backup, state-push, state-rm, and corruption-recovery examples
  are genuinely copy-unsafe but constitute a distinct destructive-state
  workflow. They should receive a real follow-up issue rather than either
  remaining ownerless or silently expanding T2's already broad retrieval
  contract.

## Current finding T2-3 — Executable Bash evidence

Primary reference:

- [GNU Bash manual](https://www.gnu.org/software/bash/manual/bash.html)

Local implementation reference:

- GNU Bash 5.2.21 built-in help was queried on 2026-07-29 for `set` and `trap`.

Durable facts:

- `bash -n` reads commands without executing them, so it is a syntax check and
  cannot prove argument vectors, destination postconditions, provider
  ordering, or cleanup.
- `set -x` prints commands and arguments as executed. Secret-bearing examples
  must explicitly contain inherited xtrace before token expansion and restore
  the caller's prior xtrace state without printing the token.
- An `EXIT` trap runs when the shell exits and can drive exact owned-file
  cleanup, but behavioral tests must prove the trap does not recursively
  remove or follow substituted state.

Planning consequence:

- Static Markdown/shell review and one HCP xtrace probe are insufficient for
  copy-safety claims.
- A tracked harness should extract the exact marked source blocks, use
  non-network command stubs, capture NUL-delimited argument vectors, and assert
  both expected rejection reasons and filesystem postconditions.
- The harness should run in ordinary CI so later edits cannot silently
  invalidate evidence produced only once in an implementation PR.

## Current finding I-1 — T1 review-unit size

Repository measurement on 2026-07-29:

- `03TerraformStyleGuideT1.md` is 93,982 bytes and 2,029 lines.
- It has only six H2 navigation sections, while 17 H3 sections carry distinct
  generator, line-ending, supply-chain, archive-security, harness, artifact,
  matrix, approval, and writer contracts.
- Its current seven-file scope becomes eight after the selected caller-context
  lifecycle script.

Dependency analysis:

1. Generator byte determinism, LF checkout policy, hosted lint runtime, and
   immutable action/update foundations can be implemented and validated
   without activating a new artifact consumer.
2. The archive helper, caller-context lifecycle, and adversarial harness form
   one security-library boundary and can be reviewed before workflow use.
3. Artifact production/consumption, approval, and exact-lease writer form one
   activation boundary and should consume the already reviewed scripts.

Planning consequence:

- The original issue is too large for one review unit, but arbitrary splitting
  inside the helper or inside writer activation would create unsafe partial
  contracts.
- Three sequential issues preserve natural atomic boundaries. The first keeps
  the existing T1 H1; two ordered `03a`/`03b` issue files can be inserted
  without renumbering the already selected state-recovery T2, npm T3, and
  destructive-state T4 files.

## Current finding I-2 — GCS generation grammar

Primary sources:

- [Google Cloud: use versioned objects](https://cloud.google.com/storage/docs/using-versioned-objects)
- [Google Cloud: object metadata](https://cloud.google.com/storage/docs/metadata)
- [`gcloud storage cp` reference](https://cloud.google.com/sdk/gcloud/reference/storage/cp)
- [Google Cloud object naming](https://cloud.google.com/storage/docs/objects)

Durable retrieved facts:

- Every Cloud Storage object has a numeric generation that uniquely identifies
  that object version. Generation ordering must not be inferred across objects
  or future versions.
- Google documents selecting a noncurrent CLI object as
  `OBJECT_NAME#GENERATION_NUMBER`; gcloud interprets an object name ending in
  `#` plus a numeric string as a version identifier.
- Google documents generation inputs as positive 64-bit values. Generation
  zero is a special write-precondition value, not a valid historical object
  version selector.
- `gcloud storage cp --no-clobber` refuses to overwrite an existing
  destination and is an appropriate defense in depth after a local fresh-path
  preflight.

Planning consequence:

- T2 must validate `GCS_GENERATION` as canonical positive decimal
  (`^[1-9][0-9]*$`) before constructing the source URL or invoking gcloud.
- The shell does not need to convert the value to a machine integer; preserving
  the reviewed decimal string avoids arithmetic overflow and passes the exact
  generation unchanged to gcloud.
- Negative tests must reject empty, zero, signs, whitespace, leading zeros,
  separators, `#`, query/metacharacter payloads, and overlong/non-numeric
  values before the provider stub is called.

## Current finding I-3 — GitHub Actions coverage and cost

Primary sources:

- [GitHub Actions billing and usage](https://docs.github.com/en/actions/concepts/billing-and-usage)
- [GitHub Actions workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [GitHub required-check troubleshooting](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks)

Repository fact:

- The upstream repository is currently public. Its GitHub repository page
  reports public visibility.

Durable retrieved facts:

- Standard GitHub-hosted runner use is free for public repositories. Larger
  runners are still charged, and artifact/cache storage remains a separately
  governed resource.
- A matrix creates independent jobs; `fail-fast` defaults to true and can
  cancel other cells after one failure. Complete cross-edition evidence needs
  `fail-fast: false`.
- GitHub warns that a workflow skipped by path/branch/commit-message filtering
  can leave an associated required check pending and block merge.
- GitHub exposes Actions usage metrics to authorized owners, allowing runtime
  and storage decisions to be revisited with observed data.

Planning consequence:

- For this public repository, the four-cell Windows matrices primarily cost
  queue time, reviewer latency, platform capacity, and artifact storage—not
  standard hosted-runner dollars.
- The security design depends on actual Windows PowerShell 5.1/PowerShell 7
  and CRLF/LF permutations at pull-request and push consumption points.
  Reducing them before collecting data would trade known coverage for an
  unmeasured saving.
- Keep the complete topology initially, avoid workflow-level path filters, use
  failure-only bounded diagnostic artifacts, and require a post-merge usage/
  latency review with explicit thresholds.

## Selected follow-up T4 — Manual and destructive state operations

Primary sources:

- [Terraform `state pull`](https://developer.hashicorp.com/terraform/cli/commands/state/pull)
- [Terraform `state push`](https://developer.hashicorp.com/terraform/cli/commands/state/push)
- [Terraform `state rm`](https://developer.hashicorp.com/terraform/cli/commands/state/rm)
- [Terraform state locking](https://developer.hashicorp.com/terraform/language/state/locking)
- [Terraform backend state storage and locking](https://developer.hashicorp.com/terraform/language/state/backends)

Durable retrieved facts:

- `terraform state pull` writes the raw state to stdout and upgrades the
  returned snapshot to the newest state format compatible with the locally
  installed Terraform. A failed command can therefore leave a shell-redirection
  destination truncated or partial, and the pulled bytes are not necessarily
  the original remote format.
- `terraform state push` is intended only for necessary manual repair.
  Terraform rejects differing lineage and a higher remote serial unless
  `-force` disables both checks. The guide should prohibit `-force`, not present
  it as a routine escape.
- Backends lock state for write operations when supported; not all backends
  support locking. Disabling locking is unsafe where concurrent operations are
  possible.
- `terraform state rm` removes Terraform's binding while leaving the remote
  object. HashiCorp recommends declarative `removed` blocks when possible,
  supports `-dry-run`, and exposes lock/lock-timeout options.
- State modification commands write backup files; their backup paths and
  sensitive contents require explicit protection.

Planning consequence:

- A manual backup example needs fresh temporary capture, successful Terraform
  exit, state parse/identity evidence, and no-overwrite publication before it
  can be called a backup.
- Destructive examples need exact workspace/backend/current-state identity,
  a validated current backup, lock support/concurrency control, dry-run or
  lineage/serial review, explicit human confirmation, and a tested rollback
  plan before the command appears.
