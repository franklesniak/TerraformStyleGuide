# Evaluation and resolution of the current TerraformStyleGuide findings

<!-- markdownlint-disable MD060 -->

## Purpose and method

This artifact evaluates each open TerraformStyleGuide finding in
`current-findings.md`, in issue execution order. Each finding receives:

1. a complete problem statement;
2. multiple resolution options and meaningful permutations;
3. a finding-specific weighted rubric;
4. a scored comparison; and
5. one detailed selected resolution suitable for a downstream author.

Technical correctness, security guarantees, failure behavior, and operator
usability receive substantially more weight than implementation effort, churn,
or preservation of the current draft text. Options that cannot satisfy a
promised invariant are ineligible even if they are easy to implement.

## Evaluation status

Evaluation begins with T1 and proceeds one finding at a time through T4. Issue
edits begin only after every finding has a selected resolution.

## Finding 1 — T1 records the lockfile producer but does not lock it

### Problem

T1 permits the only `package-lock.json` rewrite in the slate and pins the new
direct dependency, `yaml@2.9.0`, but it selects only the Node major before that
rewrite. It asks the implementer to record the observed Node/npm pair
afterward. That is evidence of what happened, not a prior constraint on what
may happen: Node 24 releases carry different npm versions, npm's resolver and
lockfile serialization are producer inputs, and a rerun could legitimately
select a different pair while still claiming conformance.

The resolution must identify the permitted producer before the manifest or
lockfile is edited, preserve T1's narrow parser-only scope, leave T3 as the
owner of the durable package-manager policy, and prove that every other matrix
cell consumes rather than rewrites the resulting lockfile. Manually editing the
lockfile is prohibited.

### Options and permutations considered

#### Option A — Exact official Node release and its bundled npm, scoped to T1

Name an exact Node 24 patch and the npm version bundled in its official release
before the producer runs. Acquire that release through an official Node
artifact, verify its signed checksum material, record the artifact and
executable identities, edit the exact direct dependency in `package.json`, and
run one scripted `npm install --package-lock-only` operation with lifecycle
scripts, audit, and funding side effects disabled. Do not add an interim
`packageManager` field. Every subsequent install uses `npm ci` and proves
manifest/lock hashes are unchanged.

There are two timing permutations. Hard-coding today's
Node `24.18.1`/npm `11.16.0` pair without a freshness gate is reproducible but
can become stale before implementation. Silently resolving “latest Node 24”
during implementation is current but not reviewable. The viable permutation
requires the implementer to re-resolve the current exact Node 24 LTS patch from
the official archive, amend the issue's literal Node/npm pair and checksum
evidence first if it differs, and only then permit dependency edits. If the
current pair remains `24.18.1`/`11.16.0`, those are the locked literals.

The lock command also has two meaningful permutations. Supplying
`yaml@2.9.0 --save-dev --save-exact` asks npm to mutate both manifest and lock.
Editing the reviewed manifest first and then running
`npm install --package-lock-only --ignore-scripts --no-audit --no-fund`
limits npm's producer role to the lockfile and makes the intended manifest
bytes independently reviewable. The latter is stronger.

#### Option B — Pull T3's final npm policy into T1

Add T3's intended exact, hash-qualified `packageManager` selection in T1 and
use it for the lock rewrite. This gives the repository a durable producer
identity immediately and avoids an interim manager transition. It also makes
T1 responsible for the npm 12 engine floor, Corepack/bootstrap behavior, hook
compatibility, workflow compatibility, contributor policy, and the dependency
upgrade validations that T3 is explicitly designed to own. It is viable only
if the slate is restructured so all of that T3 work moves ahead of the parser
change; otherwise T1's “only yaml” boundary becomes false.

#### Option C — Add a temporary exact `packageManager` and replace it in T3

Add an exact npm 11 `packageManager` entry solely for T1, use Corepack to
activate it, and replace the entry with T3's final hash-qualified npm selection
later. This constrains the producer using a standard project field, but creates
two repository package-manager policy changes and makes intermediate commits
advertise a policy that is intentionally short-lived. Variants with an
unhashed version improve reproducibility less; a hash-qualified temporary
entry is stronger but increases the throwaway policy surface.

#### Option D — Verify and invoke a standalone exact npm producer

Keep package metadata unchanged, download an exact npm distribution or prepare
an exact Corepack manager outside project metadata, verify its upstream
integrity, and invoke that binary under an exact Node release. This can match
Option A's resolver determinism and avoids a temporary project field. A raw npm
tarball requires more bootstrap and executable-path logic; a Corepack “last
known good” selection is not acceptable unless the exact downloaded manager is
explicitly selected and verified. Either viable variant has more moving parts
than using the npm already bound to an official Node release.

#### Option E — Use a digest-pinned container as the sole producer

Run the exact lock command inside an immutable container image that fixes Node,
npm, and the base environment by digest. This offers a compact environmental
identity, but requires the issue to specify and verify the image's provenance,
architecture coverage, filesystem ownership behavior, network trust, and
cross-platform access. It adds a new container supply-chain boundary for one
lock update and is awkward for the Windows/Linux validation matrix.

#### Option F — Record whichever pair happened to run

Retain the current “Node 24, then record the exact observed pair” language.
Variants include relying on hosted-runner `PATH`, `setup-node`'s current major
resolution, or the implementer's local installation. All yield useful forensic
data but none makes the resolver input reviewable before it changes the
lockfile. This option fails the determinism requirement.

#### Option G — Hand-edit or normalize the lockfile

Directly edit the v3 lockfile or post-process npm's output to make the desired
diff. This disguises rather than controls the producer, can violate npm's
internal model, and is expressly prohibited. It is ineligible.

### Finding-specific weighted rubric

Scores use a 1–5 scale, where 5 best satisfies the criterion. The weighted
total is `sum(weight × score / 5)`. An option that does not preselect a complete
producer identity, or that requires manual lockfile editing, fails a hard gate
regardless of its numerical score.

| Criterion | Weight | What a score of 5 requires for this finding |
|---|---:|---|
| Resolver and serialization determinism | 30 | The complete Node/npm producer is fixed before any allowed lock rewrite and can be repeated exactly. |
| Producer provenance and side-effect control | 22 | Official artifacts are integrity-verified and install-time scripts, audit mutation, funding output, and unreviewed bootstrap behavior are suppressed. |
| Fit with the T1→T3 ownership boundary | 18 | T1 gains a safe one-time producer without prematurely assuming T3's final runtime, package-manager, hook, or dependency-upgrade policy. |
| Auditability of producer/consumer evidence | 15 | A reviewer can prove which executable produced the lock and that all other cells were frozen consumers. |
| Implementer and reviewer usability | 8 | The procedure is explicit, debuggable, and practical on the slate's supported runners. |
| Scope and repository churn | 4 | The resolution changes only artifacts needed for the parser and avoids temporary public policy. |
| Implementation effort | 3 | The resolution uses existing tools and requires little bespoke bootstrap code. |

### Scoring

| Option | Determinism (30) | Provenance / side effects (22) | T1→T3 fit (18) | Evidence (15) | Usability (8) | Scope (4) | Effort (3) | Total / 100 | Eligibility |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A. Exact official Node/bundled npm | 5 | 4 | 5 | 5 | 4 | 5 | 5 | **94.0** | Eligible |
| B. Pull final npm policy into T1 | 5 | 5 | 2 | 5 | 4 | 2 | 3 | 84.0 | Eligible only with slate restructuring |
| C. Temporary `packageManager` | 5 | 5 | 3 | 5 | 4 | 2 | 3 | 87.6 | Eligible |
| D. Standalone verified npm | 5 | 5 | 4 | 4 | 2 | 4 | 2 | 86.0 | Eligible |
| E. Digest-pinned container | 5 | 4 | 3 | 4 | 2 | 1 | 1 | 75.0 | Eligible |
| F. Record the observed pair | 1 | 2 | 5 | 1 | 4 | 5 | 5 | 49.2 | **Ineligible: producer not preselected** |
| G. Hand-edit/normalize lock | 1 | 1 | 2 | 1 | 1 | 3 | 3 | 26.4 | **Ineligible: prohibited/manual producer** |

### Selected resolution

Select **Option A**, using one exact official Node release and the npm bundled
with that release as T1's sole lockfile producer.

The revised T1 must establish the following contract:

1. **The producer is a reviewed input, not an observed output.** The issue
   names Node `24.18.1` and bundled npm `11.16.0`, the exact pair published in
   the official Node archive on 2026-07-29. Immediately before implementation,
   the implementer rechecks the official Node archive. If the intended Node 24
   LTS patch has changed, work stops before editing `package.json`; the issue is
   amended to name the replacement Node/npm literals and reviewed again.
   “Node 24”, “latest”, a runner's `PATH`, and an after-the-fact observation are
   not acceptable producer identities.
2. **Acquisition and provenance are recorded.** Use the official Node release
   artifact for the selected platform and verify it against that release's
   signed `SHASUMS256.txt`. The implementation evidence records the release
   URL, artifact name, expected and actual SHA-256, signature-verification
   result, `node --version`, `npm --version`, executable paths, operating
   system, architecture, and the clean source commit. Both version commands
   must equal the issue's literals before the producer is enabled.
3. **There is one producer operation.** Start from a clean disposable clone
   with no inherited `node_modules`. In `.github/workflows/package.json`, set
   the direct development dependency to the exact JSON entry
   `"yaml": "2.9.0"`; do not use a range and do not add `packageManager` in T1.
   From `.github/workflows`, using the verified executables, run exactly:

   ```text
   npm install --package-lock-only --ignore-scripts --no-audit --no-fund
   ```

   Do not use `--force`, `--legacy-peer-deps`, a global npm substitution, a
   second install, manual lockfile edits, or a lockfile formatter. Explicitly
   set npm's cache to a fresh T1 evidence directory and record the effective
   npm configuration relevant to registry, proxy, certificates, peer
   resolution, lockfiles, scripts, audit, and funding. Credentials and proxy
   secrets are redacted from evidence.
4. **The resulting diff is bounded and reviewed.** Before the command, hash
   the edited manifest and old lockfile. After it, require lockfile version 3,
   require the root package entry to match exact `yaml@2.9.0`, require the
   selected package record to contain the expected registry identity and
   integrity material, and inspect the complete manifest/lock diff. No file
   outside `.github/workflows/package.json` and
   `.github/workflows/package-lock.json` may change during production. Any
   unrelated dependency re-resolution, lifecycle execution, or unexpected
   metadata churn is a stop condition, not something to normalize manually.
5. **All remaining T1 cells are provably consumers.** Each clean platform and
   runtime cell records pre-install SHA-256 values for both manifest and
   lockfile, runs `npm ci --ignore-scripts` from the exact workflow-package
   directory, and records identical post-install hashes plus an empty
   manifest/lock diff. `npm ci` mismatch or mutation fails the cell. Parser
   validation then runs against the installed `yaml@2.9.0`; no cell may fall
   back to `npm install`.
6. **T3 owns the durable manager policy.** T1 does not add an interim
   `packageManager` or claim that npm 11 is the final contributor policy. T3
   later selects and verifies the final hash-qualified package manager,
   regenerates the lock only under T3's separately reviewed producer contract
   if required, and reruns the parser evidence. Until T3 lands, the T1 evidence
   bundle is the authoritative identity for this one lock rewrite.

This resolves the reproducibility gap without quietly moving T3's broader
runtime and package-manager policy into the parser-foundation issue.

## Finding 2 — T1's reciprocal generator matrix omits shared foundations

### Problem

T1 says its generator layer is reciprocal with PSStyleGuide P1, but its closed
comparison table covers only parameters, destination handling, content,
serialization, write/failure behavior, and host testing. T1 and P1 also share
new first-version, YAML, action, Git, credential, workflow-graph, and temporary
evidence controls. Because those controls have no rows, two implementations can
diverge there while the matrix still reports no blocker.

The resolution must make the reciprocal claim falsifiable without creating a
cross-repository runtime dependency. A security reviewer needs exact observable
controls; implementers need repository-specific literals to remain possible;
maintainers need stable comparison keys; and an auditor must be able to connect
each verdict to two fixed commits and retained evidence.

### Options and permutations considered

#### Option A — Expand one stable, symmetric foundation matrix

Keep a single matrix but rename its scope from only “generator layer” to the
complete “generator and foundation” contract. Assign a stable semantic ID to
every existing and missing row, use the same closed row catalog and evidence
columns in P1 and T1, and make an absent row or unexplained difference a merge
blocker. Repository paths and payload names remain row values rather than
reasons to omit a row.

One permutation merely appends prose rows with no identifiers; it fixes the
immediate omission but makes later reciprocal comparisons vulnerable to
renaming and row splitting. The stronger permutation uses stable domain IDs and
requires both repositories to record their normative locator, implementation
evidence, observed result, status, and rationale against the same semantic key.

#### Option B — Split the comparison into domain-specific matrices

Create separate generator, parser/package, action, Git, workflow/credential,
and evidence-cleanup matrices. This gives each specialist a focused surface and
can carry domain-specific columns. It also fragments the “no omitted shared
foundation” gate: every table needs its own completeness check, common controls
can be duplicated, and readers must reconstruct one overall verdict. A
permutation with a master index mitigates that risk but largely recreates
Option A with more structure.

#### Option C — Generate a requirements diff mechanically

Give normative clauses machine-readable IDs and build a tool that extracts and
compares them across the two issue/implementation commits. This could detect
missing identifiers and schema drift automatically. Text extraction alone
cannot determine behavioral equivalence; a useful implementation still needs
human evidence and intentional-difference judgments. It also introduces a new
tooling deliverable and identifier migration across both slates before the
foundation issues can merge.

#### Option D — Compare only executable outputs and negative fixtures

Treat matching bytes, exit codes, and hostile-fixture results as the reciprocal
contract, without comparing structural policy. This is attractive to
implementers because behavior is concrete, but it cannot prove an authored
action input versus a default, credential materialization boundaries, exact
job eligibility, evidence cleanup, or action provenance. Distinct security
structures can produce the same happy-path output.

#### Option E — Replace the table with a whole-issue cross-reference

Require reviewers to compare every normative section of the two fixed commits
and record a single verdict. This avoids maintaining a catalog, but the scope
is not enumerable, row omissions are invisible, and a cold auditor cannot tell
which differences were examined. A checklist of the missing subjects improves
it only by turning it back into an informal version of Option A.

#### Option F — Declare the missing foundations repository-specific

Limit reciprocity to generator bytes and allow each repository to define
parser, Actions, Git, credential, workflow, and cleanup policy independently.
This is coherent only if the issues withdraw their cross-repository unification
claim. It preserves the exact divergence the current slate is intended to
detect and is therefore ineligible.

### Finding-specific weighted rubric

Scores use 1–5 and the same weighted-total formula defined for Finding 1. An
option is ineligible if a shared security/failure control can be absent without
making the final comparison fail.

| Criterion | Weight | What a score of 5 requires for this finding |
|---|---:|---|
| Shared-foundation coverage | 27 | Every generator, version, parser/package, action, Git, credential, graph, and cleanup concern is represented exactly once. |
| Cross-repository semantic comparability | 22 | Both repositories use the same stable semantic keys and can distinguish equal behavior from legitimate literal differences. |
| Divergence and omission detection | 18 | Missing rows/evidence and unexplained observable differences deterministically block merge. |
| Audit traceability | 13 | Each decision leads from two exact commits and normative locators to retained evidence and rationale. |
| Long-term drift resistance | 10 | Row renames, splits, or additions cannot silently weaken only one repository's matrix. |
| Reviewer and implementer usability | 7 | The complete result is understandable without reconstructing several documents or tools. |
| Scope/churn | 3 | The fix remains documentation/evidence work and creates no shared runtime component. |

### Scoring

| Option | Coverage (27) | Comparability (22) | Detection (18) | Traceability (13) | Drift resistance (10) | Usability (7) | Scope (3) | Total / 100 | Eligibility |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A. One stable symmetric matrix | 5 | 5 | 5 | 5 | 4 | 4 | 4 | **96.0** | Eligible |
| B. Domain-specific matrices | 5 | 5 | 5 | 4 | 3 | 3 | 2 | 88.8 | Eligible |
| C. Machine-generated requirements diff | 5 | 4 | 4 | 5 | 3 | 2 | 1 | 81.4 | Eligible |
| D. Executable results only | 2 | 2 | 2 | 3 | 4 | 5 | 5 | 52.6 | **Ineligible: structural controls can disappear** |
| E. Whole-issue cross-reference | 2 | 1 | 1 | 2 | 4 | 3 | 5 | 39.2 | **Ineligible: omissions are not detectable** |
| F. Declare missing controls repository-specific | 1 | 1 | 1 | 1 | 5 | 5 | 5 | 36.0 | **Ineligible: withdraws the promised invariant** |

### Selected resolution

Select **Option A**. T1 will define one closed reciprocal
generator-and-foundation catalog and require the evidence package to apply that
same catalog to the fixed Terraform T1 and PS P1 commits.

The revised T1 must replace the seven-row informal table with these stable
semantic rows:

| Stable row | Required comparison |
|---|---|
| `GF-PARAMETERS` | Public generator parameter names, types, defaults, omission/null/empty rules, and raw-value preservation. |
| `GF-DESTINATION` | Trusted repository root, allowed destinations, provider/wildcard/rooted-path rules, normalization, comparison semantics, and invalid-input state. |
| `GF-CONTENT` | Source ordering, wrappers/frontmatter, repository-specific names, complete-payload construction, and intentional payload differences. |
| `GF-SERIALIZATION` | CRLF/lone-CR normalization, LF, final-newline rule, BOM-less UTF-8 encoding, and byte checks. |
| `GF-WRITE` | One complete-payload write path, temporary identity/creation, flush/close, atomic replacement, and prohibited fallbacks. |
| `GF-FAILURE` | Failure-phase destination postconditions, cleanup, uncertainty handling, bounded diagnostics, and fault cases. |
| `GF-HOSTS` | Windows PowerShell 5.1, PowerShell 7 on Windows/Linux, executable identity, cross-cell byte equality, and repeat idempotence. |
| `GF-VERSION` | Exact first-version marker grammar, raw occurrence count, extraction/parse algorithm, date validity, ordering rule, and invalid/stale fixtures. |
| `GF-NODE-LOCK` | Exact hosted Node selection, cache policy, sole lockfile producer identity/provenance, exact YAML dependency graph, and frozen-consumer proof. |
| `GF-YAML` | Exact parser package/API, document-count rule, schema/strictness options, parser diagnostics, and bans on aliases, merge keys, duplicate keys, custom tags, and unsupported structures. |
| `GF-ACTION-PINS` | Closed action-role inventory, full commit pins, tag-to-commit and publisher/repository provenance, internal runtime, and atomic pin updates. |
| `GF-ACTION-INPUTS` | Every security/correctness-relevant authored input separated from every relied-on pinned-manifest default, with default drift detected. |
| `GF-GIT` | Raw NUL-delimited path handling, byte-domain allowlists, native exit classification, output cardinality, ref validation, ancestry, lease, and exact refspec semantics. |
| `GF-GRAPH` | Closed production and evidence workflow/job graph: triggers, permissions, direct `needs`, conditions, outputs, side effects, and the sole write-capable path. |
| `GF-CREDENTIALS` | Job-token availability, checkout's transient fetch authentication, disabled persistence and cleanup proof, explicit push-only materialization, redaction, and post-step absence. |
| `GF-EVIDENCE` | Exact temporary workflow/ref identity, structural equality to production with enumerated exceptions, required drills, retained run/commit/remote evidence, deletion, and final absence proof. |

For every row, one record contains:

1. the exact Terraform repository URL and commit;
2. the exact PSStyleGuide repository URL and commit;
3. the normative section/line or durable anchor on each side;
4. the implementation path/function/job/action on each side;
5. the retained evidence path plus SHA-256 on each side;
6. the observed values and fixture/case IDs, not merely “pass”;
7. exactly one status: `same`, `intentional difference`, or `blocker`; and
8. a rationale.

An `intentional difference` additionally names both literal values, explains
the repository need, demonstrates equal security/failure strength, and records
an accountable owner and review/expiry condition. Paths, repository names,
artifact names, payload text, and platform applicability can qualify.
Different credential containment, parser strictness, Git exit handling,
failure postconditions, or evidence-removal guarantees do not qualify merely
because happy-path output matches.

The row catalog is closed for the reviewed pair. Duplicate IDs, absent IDs,
unknown IDs, empty locators/evidence, a changed row meaning, or a missing
required fixture make the comparison a `blocker`. Implementation begins with
fixed commits, and pre-merge validation re-resolves both heads: if either
changed, every row is rerun against the new exact pair. The aggregate result is
successful only when all 16 IDs occur exactly once and none is `blocker`.

This is an evidence schema, not a shared library. Each repository remains
self-contained. Terraform T1 need not edit the PSStyleGuide planning files, but
it may not claim reciprocity until PS evidence can be normalized into this same
catalog; an unmatched PS contract is reported as a blocker and handed to that
repository rather than silently omitted.

## Finding 3 — T1's temporary workflow graph is less exact than its validator claim

### Problem

T1 requires a permanent offline workflow-policy validator whose constants must
come from the issue, yet the issue only names verification and temporary-writer
roles. It does not close the job set, direct dependency graph, job eligibility,
outputs, or side-effect classes, and it leaves the generated-artifact upload's
condition as an unspecified later choice. The validator therefore cannot tell
whether a writer may race or bypass verification, whether an extra job is
permitted, or what literal upload condition is correct.

The temporary graph must preserve current generation/publication behavior while
isolating write permission, and it must be precise enough for T1B to replace
known constants atomically. Security reviewers prioritize the sole write path
and prerequisite; CI operators need useful artifacts and visible verification;
validator authors need literals; and maintainers need a graph small enough to
remove completely in T1B.

### Options and permutations considered

#### Option A — Closed three-job inventory with a direct verified writer edge

Define the exact job set across the two existing workflows: `build.yml` has
`verify` and `temporary-writer`; `markdownlint.yml` has `markdownlint`.
`temporary-writer` directly declares `needs: verify`, is eligible only on a
push to `refs/heads/main` after a successful `verify`, has the only
job-level `contents: write`, exposes no outputs, and independently regenerates
and revalidates its exact checkout. The other jobs have no dependencies and no
write side effects. Give the generated-file upload the literal success-only
condition `${{ success() }}`.

The writer condition can rely only on the default success semantics of
`needs`, or it can also spell out
`needs.verify.result == 'success'`. The latter is redundant at runtime but
better for an offline structural validator and a cold reviewer. Similarly, an
omitted upload `if` has implicit success-only behavior, but an authored literal
avoids a hidden default. Those explicit permutations are selected.

#### Option B — Closed graph but writer runs independently

Give `verify` and `temporary-writer` exact event predicates but no dependency
edge. This minimizes latency, and the writer can repeat all checks itself.
However, the write-capable job may run and publish while the read-only required
verification job fails, and “verification passed before publication” is no
longer structurally true. A concurrency group does not replace the missing
success dependency.

#### Option C — Pass generated output from verification to the writer

Make the writer depend on `verify`, download its uploaded generated files, and
publish those bytes. This avoids regenerating, but it starts the immutable
candidate transport and cross-job consumption model that T1B is supposed to
introduce. It requires download action roles, artifact identity, integrity,
retention, and at-use validation that T1 intentionally excludes. A job output
containing only “changed” avoids transport but still couples publication to an
untrusted stale boolean rather than the writer's own exact Git state.

#### Option D — Put verification and conditional push in one job

Retain a single `build` job with a push step guarded by the event. Steps are
strictly ordered and the graph is simple, but job permissions are established
for the complete job. Giving the job `contents: write` exposes a write-capable
token to pull-request verification and every preceding action/script; keeping
it read-only makes the push impossible. This violates T1's least-privilege job
boundary.

#### Option E — Remove automated publication until T1B

Make T1 entirely read-only and let T1B introduce the next writer. This is the
safest temporary graph in isolation and the easiest to validate, but it does
not preserve the existing direct publication behavior that T1 explicitly owns.
It is viable only after a separate maintainer decision accepting a publication
gap and a corresponding slate rewrite.

#### Option F — Use a reusable workflow for the writer

Move the writer into a locally or remotely called workflow and express the
dependency at the caller. This can isolate implementation detail, but adds
called-workflow permissions, inputs, secrets, internal jobs, commit identity,
and validator recursion. Remote reusable workflows are already prohibited, and
a local one increases the temporary topology T1B must remove without improving
the two-job design.

#### Option G — Leave conditions and graph details to implementation

Continue validating only action roles and broad permission claims. This
maximizes implementer freedom but makes the permanent validator incomplete by
construction and is ineligible.

### Finding-specific weighted rubric

Scores use 1–5. A writer topology is ineligible if publication can occur
without successful verification or if pull-request verification receives a
write-capable job token.

| Criterion | Weight | What a score of 5 requires for this finding |
|---|---:|---|
| Publication prerequisite and write safety | 26 | The sole writer can run only after the exact read-only verification job succeeds for the same triggering SHA. |
| Closed graph/validator precision | 24 | Exact workflows, jobs, direct `needs`, predicates, outputs, permissions, and side-effect classes are literal validator inputs. |
| Least privilege and credential isolation | 18 | Only one short job has `contents: write`; read-only jobs and unrelated steps cannot inherit that capability. |
| Behavioral continuity and artifact utility | 12 | Existing push publication and useful generated-artifact behavior continue on the intended events. |
| Atomic T1B replacement | 9 | T1B can name and delete a small complete temporary topology without inferred remnants. |
| CI diagnosability | 7 | Verification, skip, artifact, no-change, and publication outcomes are independently visible and attributable. |
| Scope/implementation cost | 4 | The solution uses the two existing workflows and avoids premature transport or reusable-workflow machinery. |

### Scoring

| Option | Write safety (26) | Graph precision (24) | Isolation (18) | Continuity (12) | T1B replacement (9) | Diagnosis (7) | Scope (4) | Total / 100 | Eligibility |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A. Closed graph, direct verified edge | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.2** | Eligible |
| B. Independent writer | 2 | 5 | 5 | 5 | 4 | 4 | 5 | 81.2 | **Ineligible: verification can fail while publication runs** |
| C. Transport verification output | 5 | 5 | 4 | 4 | 2 | 3 | 1 | 82.6 | Eligible but violates T1 scope |
| D. One write-capable build job | 1 | 5 | 1 | 5 | 2 | 4 | 5 | 58.0 | **Ineligible: write capability reaches PR verification** |
| E. Remove publication until T1B | 5 | 5 | 5 | 1 | 3 | 3 | 3 | 82.4 | Eligible only after a slate/policy rewrite |
| F. Reusable writer workflow | 4 | 3 | 4 | 4 | 2 | 2 | 1 | 66.4 | Eligible |
| G. Implementation-defined topology | 1 | 1 | 2 | 4 | 1 | 2 | 5 | 35.4 | **Ineligible: validator has no exact policy** |

### Selected resolution

Select **Option A** and make the complete temporary topology a normative input
to `Validate-WorkflowPolicy.mjs`.

The revised issue must publish this exact event and permission boundary:

- `build.yml` has only `pull_request` targeting `main` and `push` targeting
  `main`, with no `paths`, `paths-ignore`, tag, schedule, dispatch, or reusable
  workflow trigger. Its workflow-level permission map is exactly
  `contents: read`.
- `markdownlint.yml` has `pull_request` targeting `main` and `push` for all
  branches, with no path/tag/schedule/dispatch/reusable trigger. Its
  workflow-level permission map is exactly `contents: read`.
- Neither workflow uses workflow-level environment variables, concurrency that
  cancels an in-progress writer, defaults that alter shell/location, or
  unenumerated permissions.

The exact job graph is:

| Workflow/job | Direct `needs` | Literal job `if` | Job permission | Outputs | Permitted side effects |
|---|---|---|---|---|---|
| `build.yml` / `verify` | none/absent | none/ordinary workflow eligibility | `contents: read` (no broader override) | none/absent | Read checkout; ephemeral generation and validation in runner workspace; one success-only Actions artifact upload. No commit, ref, issue, cache, or external publication write. |
| `build.yml` / `temporary-writer` | exactly `[verify]` | `${{ github.event_name == 'push' && github.ref == 'refs/heads/main' && needs.verify.result == 'success' }}` | exactly `contents: write`; every unspecified permission is `none` | none/absent | Read checkout; ephemeral regeneration/validation; at most one commit and one update of `refs/heads/main` through the guarded push step when the exact generated path set changed. |
| `markdownlint.yml` / `markdownlint` | none/absent | none/ordinary workflow eligibility | `contents: read` (no broader override) | none/absent | Read checkout; Node acquisition; ephemeral `node_modules`; lint diagnostics. No artifact, cache, repository, ref, issue, or external publication write. |

There are exactly three jobs and no reusable-workflow call, service, container,
matrix, or dynamically constructed job. The validator rejects extra/missing or
renamed jobs, a second write-capable job, additional direct or transitive
dependencies, any job output, an `always()`, `failure()`, or `cancelled()`
override on the writer, and any condition that widens the literal event/ref/
successful-prerequisite conjunction.

Within `verify`, the stable step order is checkout, credential-absence proof,
generation, exact generated-path/byte validation, then
`upload-generated`. The upload step authors the exact condition:

```yaml
if: ${{ success() }}
```

It has no `continue-on-error`. Thus it runs only after every preceding verify
step succeeds, uploads only the four fixed generated paths, and its failure
fails `verify`. Failure, cancellation, or skip does not upload partial output.
The validator rejects an omitted condition even though GitHub would currently
apply a default success check, because the reviewed literal is part of T1's
portable policy.

Within `temporary-writer`, checkout and credential-removal proof precede all
repository code. The job regenerates from the same triggering SHA and repeats
the path, byte, native-exit, remote, and changed/no-change checks itself; it
does not consume an artifact or trust an output from `verify`. The direct
`needs` edge and explicit result clause are both required. A no-change result
ends successfully without commit or push. Only the final guarded step receives
explicit push credential material and may update the one named ref.

Within `markdownlint`, checkout precedes setup-node, one frozen install, both
lint surfaces, and the final combined result. The exact step/action role table
remains separately normative; the graph table does not weaken its action pin
or input requirements.

Fixture coverage must mutate each graph field independently: add/remove/rename
a job; add/remove/change a direct edge; change each event/ref/result operand or
operator; add `always`; add an output; move/broaden permission; change or omit
the upload condition; add a side-effecting step/action; and add a called
workflow. Each negative fixture is rejected for its intended graph reason.
Positive fixtures cover build PR, build push with successful verification,
failed/cancelled/skipped verification, writer no-change, markdown PR, and
markdown push eligibility.

T1B must replace this complete job table, role table, conditions, and fixtures
atomically with its final transport/matrix/approval/writer graph. It deletes
`temporary-writer` and its direct-generation/commit/push steps; it does not
inherit an inferred edge or leave a disabled fallback.

## Finding 4 — T1/T1A use “stale version” for two different questions

### Problem

The T1 version marker embeds a UTC modification date, and T1A applies the same
convention to three scripts. Their current prose asks the reusable parser to
reject a “stale” date. If stale means older than the execution day, every
unchanged committed script eventually becomes invalid. If it means “not bumped
for this change,” the parser lacks the merge-base version and recorded
implementation date needed to decide it. T1A also needs an exact expected
version check for immutable script identity, which is a third comparison and
should not be conflated with calendar validity.

The resolution must let old committed scripts run indefinitely, enforce the
version convention when a script actually changes, and let a consumer reject
an unexpected script version deterministically. Authors need a clear bump
rule; runtime operators need clock-independent behavior; reviewers need
change-time evidence; and harness maintainers need distinct failure oracles.

### Options and permutations considered

#### Option A — Separate timeless parse, expected identity, and change-time gate

Make the shared parser validate only marker location/count, exact grammar,
numeric bounds, and whether Build is a real Gregorian date. A consumer can
separately compare that parsed value to an explicit expected version from the
reviewed commit. A pull-request/merge gate, not runtime parsing, compares each
changed script to the merge-base marker and the recorded implementation UTC
date, then enforces Major/Minor/Build/Revision progression.

The change gate can use the wall clock at test execution or a recorded
per-script implementation date. The former creates midnight/retry ambiguity.
The stronger permutation records the implementation date when the file is
last materially edited, recomputes it if editing crosses UTC midnight, and
requires the marker's Build to equal that recorded value before merge. The
runtime parser never reads the clock.

#### Option B — Runtime age window

Accept markers no older than today, the current release cycle, or a fixed
number of days. A window tolerates brief delays but merely postpones failure:
an immutable reviewed commit eventually stops working. Clock skew and offline
replay also change the result. No window length makes this a timeless identity
check.

#### Option C — Parse validity only; drop change-time enforcement

Remove “stale” and accept every structurally valid marker forever, without
comparing changed files to a baseline. This fixes runtime longevity and is easy
to maintain, but authors can change behavior without bumping the marker or can
reuse an old date. The version ceases to serve its stated release-discipline
purpose.

#### Option D — Compare the marker to Git commit timestamps

At runtime or merge time, require the embedded date to match an author or
committer date. This avoids today's clock, but commit timestamps are not file
modification timestamps, rebases/cherry-picks change them, shallow archives may
not contain the needed history, and one commit can contain scripts edited on
different UTC dates. Using first-parent history improves attribution but still
does not implement the issue's “actual implementation date” rule.

#### Option E — Replace the dated version with ordinary SemVer

Use `Major.Minor.Patch` (or a four-component counter) without an embedded date.
This is timeless and familiar, but changes the cross-slate convention and
still requires a merge-base bump gate. Migrating existing consumers and
evidence is disproportionate when the date can remain valid metadata.

#### Option F — Rewrite/inject the current date when a script runs

Generate or patch the marker on invocation so it is never stale. This mutates
reviewed source bytes, breaks commit/SHA identity, creates dirty checkouts, and
turns execution into publication. It is ineligible.

#### Option G — Require only an explicit expected version at every invocation

Have every caller supply the exact four-component version and reject mismatch.
This provides excellent immutable identity and remains timeless, but it does
not prove that a changed file received the required new date or version bump.
It is a useful consumer layer within Option A, not a complete authoring policy.

### Finding-specific weighted rubric

Scores use 1–5. Any option that makes unchanged source expire solely because
time passed is ineligible.

| Criterion | Weight | What a score of 5 requires for this finding |
|---|---:|---|
| Runtime longevity and semantic correctness | 28 | The same valid committed bytes produce the same parse result indefinitely, independent of wall clock. |
| Change-time version discipline | 23 | Every materially changed script proves the required bump, actual edit date, and reset/increment rule against its baseline. |
| Determinism across clocks/history shapes | 18 | Results do not vary with runner date, timezone, skew, rebase, shallow clone, or later replay. |
| Consumer identity strength | 13 | T1A/T1B can require the exact reviewed script version separately from grammar validity. |
| Fixture clarity and diagnostics | 10 | Grammar, impossible date, unexpected expected-version, and invalid bump each have independent deterministic oracles. |
| Author/maintainer usability | 6 | The rule tells authors when to change each component without runtime surprises. |
| Migration/churn | 2 | Existing marker format and downstream contracts remain usable. |

### Scoring

| Option | Longevity (28) | Change discipline (23) | Determinism (18) | Identity (13) | Fixtures (10) | Usability (6) | Churn (2) | Total / 100 | Eligibility |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A. Three distinct layers | 5 | 5 | 5 | 5 | 5 | 4 | 4 | **98.4** | Eligible |
| B. Runtime age window | 1 | 4 | 1 | 2 | 3 | 3 | 4 | 44.0 | **Ineligible: unchanged source expires** |
| C. Parse validity only | 5 | 1 | 5 | 3 | 4 | 5 | 5 | 74.4 | Eligible but incomplete |
| D. Git timestamp comparison | 2 | 4 | 2 | 4 | 3 | 2 | 3 | 56.8 | Eligible but history-dependent |
| E. Replace with ordinary SemVer | 5 | 3 | 5 | 4 | 4 | 3 | 1 | 82.2 | Eligible |
| F. Runtime date injection | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 20.0 | **Ineligible: mutates reviewed source** |
| G. Expected version only | 5 | 2 | 5 | 5 | 4 | 4 | 4 | 82.6 | Eligible but incomplete |

### Selected resolution

Select **Option A**. T1 defines the common three-layer contract, and T1A
applies it to its helper, context manager, and harness without any runtime age
test.

#### Layer 1: timeless marker parsing

After the caller proves the script is the intended ordinary, non-reparse,
strict UTF-8/LF file, the common parser:

1. searches the complete decoded script and requires exactly one raw
   `Version:` marker;
2. requires that marker to be one complete line in the script-level `.NOTES`
   block before the first function;
3. matches exactly
   `Version: <Major>.<Minor>.<YYYYMMDD>.<Revision>`, with one ASCII space after
   the colon, ASCII digits only, no sign or surrounding whitespace, exactly
   four components, and no leading zero in Major, Minor, or Revision unless the
   component is `0`;
4. parses all four components within `System.Version`'s nonnegative integer
   bounds and requires round-trip equality to the canonical components; and
5. parses Build exactly as a real proleptic-Gregorian `yyyyMMdd` date with
   invariant culture and no normalization (including correct leap-day rules).

This layer does not read the clock, Git history, file timestamps, or network.
A real old date and a real future date are both grammatically valid. Missing,
duplicate, out-of-location/decoy, malformed, overflow, extra-component, and
impossible-date markers are `invalid-version` failures. The parsed value does
not authorize the file; commit, path, ordinary-file identity, and SHA-256
remain separate controls.

#### Layer 2: explicit consumer identity

When a harness or workflow expects a reviewed script, it supplies or embeds the
exact canonical version from the same fixed commit that supplied the expected
path and SHA-256. After timeless parsing, require ordinal equality between the
canonical parsed version and that explicit value. A mismatch is
`unexpected-version` and reports bounded expected/actual version strings; it is
not called stale.

T1A's implementation evidence records final literal versions for all three
scripts. The permanent T1A harness requires the helper and context-manager
versions from that table, while an outer T1A/T1B validation step checks the
harness's own version. T1B consumes the same three literals, commits, and
hashes. No consumer derives an expected version from the untrusted script.

#### Layer 3: implementation and merge bump gate

Only the authoring/merge validation uses an implementation date. For every
affected script path, record the exact merge-base commit, baseline marker (or
`absent` for a new file), change classification, accountable author, and the
UTC calendar date on which the final material edit was made. The staged
version must pass Layer 1 and obey:

- a new T1A script starts at `1.0.<final-edit-YYYYMMDD>.0`;
- a breaking public contract or output change increments Major, resets Minor
  to `0`, sets Build to the final-edit date, and resets Revision to `0`;
- a backward-compatible capability increments Minor, preserves Major, sets
  Build to the final-edit date, and resets Revision to `0`;
- a material correction that changes neither Major nor Minor preserves both
  and sets Build to the final-edit date; if that date differs from the
  baseline Build, Revision resets to `0`;
- an additional correction on the same UTC date with unchanged
  Major/Minor/Build increments Revision by exactly one; and
- every other decrease, jump, reused revision, wrong date, or reset violation
  fails.

If work continues after 00:00 UTC and the file is materially edited again, its
recorded final-edit date and Build are recomputed before validation. Merely
rerunning tests on a later day does not require a change. The gate operates on
the exact staged bytes and exact baseline blob, and an unchanged script is
excluded rather than forced to bump.

Fixtures are partitioned by layer. Layer 1 includes a decades-old real date,
a future real date, leap/non-leap dates, duplicate/decoy markers, signs,
whitespace, leading zeros, overflow, and component-count mutations. Layer 2
separately covers exact match and expected-version mismatch. Layer 3 covers a
new file, next-day correction, same-day correction, compatible capability,
breaking change, unchanged file, no bump, wrong date, incorrect reset, and
version decrease. Each case has one diagnostic category, so “stale” is removed
from T1 and T1A rather than redefined ambiguously.

## Finding 5 — The slate assumes protected `main`, but `main` is unprotected

### Problem

Live read-only queries on 2026-07-29 found no repository ruleset and returned
`Branch not protected` for `main`. T1B nevertheless promises a landed
protected-branch commit, and T2 consumes that description. None of the six
issue scopes configures repository settings. The words are therefore factually
false, and the final direct writer's compatibility with any future protection
is unproven.

This decision affects two authorization planes. Repository governance should
block accidental human direct/force/delete operations, while the reviewed
workflow intentionally needs one exact-lease update of `main`. Repository
administrators need a recoverable setting; workflow engineers need the actual
`GITHUB_TOKEN` actor tested; reviewers need required checks to remain meaningful;
and successor authors need a landed commit they can verify without predicting
the merge result.

### Options and permutations considered

#### Option A — Separate active ruleset with one verified Actions bypass

Create a separately authorized repository-settings prerequisite. Install one
active branch ruleset targeting only `refs/heads/main`: require ordinary
updates through a pull request and the terminal T1B approval check, prohibit
deletion and non-fast-forward updates, and allow only the official GitHub
Actions integration to bypass so the final writer can perform its guarded
direct update. Test the actual `GITHUB_TOKEN` writer under an equivalent rule
on the isolated evidence ref before activating the main rule.

The bypass can be broad (`always`) or pull-request-only. The writer performs a
direct Git push, so pull-request-only cannot work; `always` is required. That
means the closed workflow/action/permission validator—not the ruleset—must
remain the control that prevents another workflow from obtaining write
authority. A classic branch-protection rule is less suitable for this personal
repository because selected actor bypass is documented for organization
repositories; a repository ruleset supports an Integration actor explicitly.

#### Option B — Explicitly accept unprotected direct automation writes

Remove every “protected” claim and state that `main` is deliberately
unprotected; rely on T1B's exact workflow graph, matrix approval, identity
snapshot, fast-forward/lease/refspec, and sole write token. This is honest and
immediately implementable. It leaves human/admin direct pushes, deletion, and
force-push governance outside the slate and makes a compromised write-capable
workflow the only effective branch boundary.

#### Option C — Redesign publication as a pull request or merge-queue flow

Keep `main` protected with no direct-writer bypass. Have automation create a
branch/PR containing the four generated blobs and let required checks plus a
human or merge queue land it. This avoids an automation bypass but changes
T1B's one-run candidate/approval/writer architecture, introduces PR API
permissions and lifecycle cleanup, and conflicts with `GITHUB_TOKEN` event
suppression unless a GitHub App/PAT and new secret/installation policy are
added.

#### Option D — Enable protection with no tested writer exception

Turn on required pull requests/status checks and assume the existing
`GITHUB_TOKEN` writer can push. If it cannot bypass, every changed push reaches
approval and then fails publication. If administrators later weaken the rule
ad hoc, the security policy is neither reviewed nor reproducible. This option
is ineligible.

#### Option E — Promise to protect `main` after T1B lands

Keep the current language but defer settings until after implementation. This
might let T1B merge, yet its pre-merge evidence cannot prove production-rule
compatibility and T2 can start during the gap. A future promise does not make
the recorded landed commit protected.

#### Option F — Protect only the temporary evidence branch

Use a temporary rule for the evidence ref and leave `main` unprotected. This is
valuable compatibility evidence but does not establish the production
governance asserted in handoffs. It is a prerequisite inside Option A, not a
complete resolution.

### Finding-specific weighted rubric

Scores use 1–5. A resolution is ineligible if it calls `main` protected without
a live effective-rule proof, or if its configured rule prevents the selected
production writer from operating.

| Criterion | Weight | What a score of 5 requires for this finding |
|---|---:|---|
| Governance integrity/direct-write resistance | 28 | Ordinary actors cannot delete, force-update, or bypass reviewed pull-request/check policy on `main`. |
| Final-writer compatibility | 23 | The exact runtime actor and exact guarded push succeed under the production-equivalent rule without weakening its ordinary path. |
| Factual handoff correctness | 15 | Every protected/unprotected and reviewed-head/landed-commit statement is verified at the time it is recorded. |
| Authorization/audit boundary | 15 | The settings owner, bypass actor, workflow authority, effective rule, evidence, and rollback are explicit and reviewable. |
| Deployability in the current repository | 9 | The policy works for this public personal repository and its present token model. |
| Operations and recovery | 7 | Maintainers can diagnose a blocked writer and restore a known settings state without ad hoc broadening. |
| Slate churn | 3 | The design preserves the existing issue sequence and final writer architecture. |

### Scoring

| Option | Governance (28) | Writer compatibility (23) | Handoff truth (15) | Audit boundary (15) | Deployability (9) | Recovery (7) | Churn (3) | Total / 100 | Eligibility |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A. Ruleset plus verified Actions bypass | 5 | 4 | 5 | 5 | 4 | 4 | 3 | **91.0** | Eligible |
| B. Explicitly accept unprotected `main` | 2 | 5 | 5 | 3 | 5 | 4 | 5 | 75.8 | Eligible |
| C. PR/merge-queue publication | 5 | 2 | 5 | 5 | 2 | 2 | 1 | 74.2 | Eligible after major redesign |
| D. Untested protection/no exception | 5 | 1 | 1 | 4 | 3 | 1 | 4 | 56.8 | **Ineligible: production writer may be blocked** |
| E. Protect after T1B | 3 | 4 | 2 | 3 | 4 | 3 | 5 | 64.6 | **Ineligible: asserted state remains false at handoff** |
| F. Evidence-ref protection only | 2 | 4 | 1 | 2 | 5 | 4 | 4 | 55.6 | **Ineligible: production branch remains ungoverned** |

### Selected resolution

Select **Option A**. T1B gains a separately authorized repository-settings
prerequisite; workflow file scope does not masquerade as authority to change
repository governance.

Before T1B implementation, create and link a repository-settings task with a
named repository administrator, approver, execution window, current-state
export, exact desired JSON, validation commands, and rollback JSON. T1B is
blocked until that task is authorized. The desired persistent rule is:

- one repository branch ruleset named
  `terraform-style-guide-main-protection`;
- target `branch`, enforcement `active`;
- ref include exactly `refs/heads/main`, exclude set empty;
- prohibit deletion and non-fast-forward updates;
- require a pull request for ordinary actors, with zero mandatory approvals
  unless maintainers separately authorize a higher viable count;
- require resolved review conversations;
- require the exact T1B terminal check
  `Build Style Guide Artifacts / approve`, bound to the official GitHub Actions
  integration;
- require the branch to be current with the required check before an ordinary
  merge; and
- contain exactly one bypass actor: official GitHub Actions integration ID
  `15368`, mode `always`.

The settings task must re-resolve `GET /apps/github-actions` immediately before
creation and require the official owner `github`, slug `github-actions`, and
ID `15368`; any drift stops for review. No user, repository-role, deploy-key,
administrator, team, second app, or exempt-mode bypass is allowed. The
integration bypass is deliberately broad enough for a direct Git push, so it
does not replace T1B's enforcement that exactly one reviewed job has
`contents: write`. Any other write-capable workflow would share the app actor
and is therefore prohibited by the permanent workflow-policy validator and
repository review.

Before activating the persistent rule, the settings administrator creates a
separate temporary ruleset with byte/field-equivalent rules and bypass actor,
changing only its name and target to T1B's unique evidence ref. T1B's real
writer, authenticated by that run's `GITHUB_TOKEN`, must:

1. succeed on the positive exact-parent/exact-lease case;
2. fail its stale preflight and lost-lease cases without moving the ref;
3. fail a non-fast-forward and deletion attempt;
4. demonstrate that an ordinary maintainer direct update without a pull request
   is rejected; and
5. leave no credential, alternate writer, or unexpected ref.

Record the temporary ruleset's complete before/after API representation,
effective rules, rule ID, app identity, workflow/run/commit/ref identities,
remote before/after values, and audit/insights entry. Remove the temporary
ruleset and evidence ref with verified restoration. A failed positive test or
successful negative test blocks activation; do not disable a rule, add an
actor, or switch to an unprotected push as fallback.

After a successful T1B pull-request `approve` check establishes the exact check
context, activate the persistent main ruleset before merging T1B. Export the
API response and query the effective rules for `refs/heads/main`. Prove that
ordinary pull-request merge remains possible and that only the named app is a
bypass actor. The exact rule ID and normalized SHA-256 of the retained rule
JSON become T1B handoff fields.

Terminology follows observed state:

- before activation, say `target main commit` or `reviewed head`, never
  “protected”;
- after the active/effective-rule query, say `ruleset-protected main`;
- after merge, distinguish T1B's reviewed head from the actual commit produced
  by the selected merge method and from any generated-artifact child commit;
  and
- T2 re-queries the rule ID/effective rules, validates the landed commit is
  reachable from `refs/heads/main`, and stops if the rule is absent, disabled,
  broadened, or has a different bypass actor.

The settings task remains operational configuration, not an affected
repository file. Its rollback is a reviewed exact restoration of the exported
prior settings, used only by an administrator after disabling the writer and
recording the incident. T1B and successors cannot silently fall back to
Option B; accepting an unprotected branch would require a new explicit
governance decision and corresponding issue revisions.

## Finding 6 — T1A's public raw-value contract is incomplete

### Problem

T1A says the helper's five mandatory and three optional inputs are “scalar.”
Later path rules preserve path values as `[object]`, but `ExpectedDigest` and
diagnostic labels have no declared raw types. A `[string]` parameter can cause
PowerShell to stringify numbers, arrays, or arbitrary objects before the
validator runs. The digest then lacks atomic null/type/empty/whitespace/control
oracles, and optional labels have no complete accepted grammar.

The boundary must behave identically in Windows PowerShell 5.1 and PowerShell
7. A security reviewer needs type confusion rejected before string operations;
a caller needs a simple exact interface; a harness author needs each bad value
to reach the intended production branch; and an operator needs diagnostic
labels bounded so hostile values cannot shape selection, paths, or logs.

### Options and permutations considered

#### Option A — `[object]` boundary plus ordered in-body grammar

Declare every untrusted scalar-looking script/function parameter as `[object]`
and use `AllowNull`, `AllowEmptyString`, and `AllowEmptyCollection` where needed
so negative fixtures reach production validation. Snapshot boundness and the
raw runtime object first. Require the exact `System.String` type for paths,
digest, and present labels before any cast, interpolation, comparison, regex,
trim, or filesystem call. Then apply a closed ordered grammar per parameter.

The optional labels can share a permissive log-safe label grammar or use their
actual semantic domain. Because `ArtifactId`, `RunId`, and `RunAttempt` are
GitHub numeric identifiers and never free-form labels, canonical bounded
positive decimal is the smaller, more accurate grammar. Omission alone maps to
`unavailable`; explicit null/empty/whitespace never does.

#### Option B — Strong `[string]` parameters with binder validation

Declare `[string]` plus `ValidateNotNullOrEmpty`/`ValidatePattern`. This is
concise and rejects many bad invocations before side effects. It also lets
some non-string values convert to strings before validation and gives
binder/version-dependent error categories rather than the promised production
phase/subreason. It cannot prove the raw value was a string.

#### Option C — Preserve only paths and digest as `[object]`

Fix `ExpectedDigest` but leave optional labels typed `[string]`, reasoning that
labels are diagnostic-only. This protects selection and integrity but still
lets objects influence diagnostics through `ToString()`, output-field
separator behavior, or custom formatting. It leaves the explicit request to
close every public raw value unresolved.

#### Option D — Inspect `$PSBoundParameters` after `[string]` binding

Use `$PSBoundParameters` to distinguish omission and examine the value. That
dictionary contains the already bound/converted value, so it can distinguish
omitted from present but cannot recover the caller's original type. It solves
only half of the label problem.

#### Option E — Infer raw values from invocation text or AST

Inspect `$MyInvocation`, command text, or the caller AST to guess what object
was supplied before binding. Calls can arrive through splatting, scriptblocks,
remoting, native command lines, or expressions with no faithful source text.
This is brittle across editions and can never be an authorization boundary.

#### Option F — Replace parameters with one strict JSON envelope

Accept bytes/text for one JSON object, parse with duplicate-key/type checks,
and validate named fields. This preserves JSON types across process boundaries
and can be made deterministic. It is a breaking public API redesign, still
needs a raw text boundary, and adds serialization/escaping complexity to a
PowerShell-to-PowerShell workflow that already has a direct object model.

#### Option G — Use multiple parameter sets for each accepted type

Define string and error-oriented parameter sets or overload functions to route
bad types. PowerShell still performs binding conversions while selecting a
set, array expansion can change arity, and the public surface becomes much
harder for callers and fixtures. Parameter sets express valid alternatives,
not preservation of invalid raw input.

### Finding-specific weighted rubric

Scores use 1–5. An option is ineligible if a non-string can become an accepted
digest or present diagnostic label through implicit conversion.

| Criterion | Weight | What a score of 5 requires for this finding |
|---|---:|---|
| Raw type fidelity at production code | 28 | Null, collections, and arbitrary objects reach the first validation branch without prior stringification. |
| Type-confusion and log/path safety | 22 | Invalid values cannot affect regex, comparison, paths, selection, interpolation, or diagnostics before rejection. |
| Cross-edition binding determinism | 17 | Windows PowerShell 5.1 and PowerShell 7 reach the same production phase/subreason for every raw value class. |
| Atomic fixture/diagnostic precision | 13 | Boundness, null, type, empty, whitespace, control, and grammar failures each have one stable oracle. |
| Valid-caller usability | 10 | Workflow callers pass ordinary strings directly and omission remains simple. |
| API clarity/maintainability | 7 | One table completely states declared types, accepted grammar, normalization, use, and failure order. |
| Implementation churn | 3 | The fix fits the current three scripts and harness without a transport redesign. |

### Scoring

| Option | Raw fidelity (28) | Safety (22) | Cross-edition (17) | Atomic oracles (13) | Caller UX (10) | API clarity (7) | Churn (3) | Total / 100 | Eligibility |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A. `[object]` plus body validation | 5 | 5 | 5 | 5 | 4 | 4 | 4 | **96.0** | Eligible |
| B. `[string]` plus binder validation | 1 | 2 | 4 | 3 | 5 | 4 | 5 | 54.4 | **Ineligible: raw objects can convert** |
| C. Preserve paths/digest only | 3 | 3 | 4 | 3 | 4 | 3 | 4 | 66.0 | **Ineligible: label conversion remains** |
| D. Inspect bound converted strings | 1 | 2 | 4 | 2 | 5 | 4 | 5 | 51.8 | **Ineligible: original type is lost** |
| E. Infer invocation source | 3 | 3 | 2 | 2 | 2 | 1 | 2 | 48.6 | **Ineligible: source text is not a value boundary** |
| F. Strict JSON envelope | 5 | 5 | 4 | 4 | 2 | 2 | 1 | 81.4 | Eligible but breaking |
| G. Multiple parameter sets | 2 | 3 | 3 | 2 | 3 | 3 | 3 | 51.8 | **Ineligible: conversion still precedes routing** |

### Selected resolution

Select **Option A**. Replace “scalar” with an explicit raw-boundary schema and
make production body validation—not the PowerShell binder—the owner of all
provided-value diagnostics.

For `Expand-StyleGuideCandidateArtifact.ps1`, the public declarations are:

| Parameter | Presence | Declared type/attributes | Accepted raw value after common validation |
|---|---|---|---|
| `CheckoutRoot` | mandatory | `[Parameter(Mandatory)] [AllowNull()] [AllowEmptyString()] [AllowEmptyCollection()] [object]` | Actual `System.String`; then the existing exact path grammar. |
| `TrustedTemporaryRoot` | mandatory | same | Actual `System.String`; then the existing exact path grammar. |
| `DownloadDirectory` | mandatory | same | Actual `System.String`; then the existing exact path grammar. |
| `CandidateDirectory` | mandatory | same | Actual `System.String`; then the existing exact path grammar. |
| `ExpectedDigest` | mandatory | same | Actual `System.String` matching exactly 64 ASCII hexadecimal characters. |
| `ArtifactId` | optional | `[Parameter()] [AllowNull()] [AllowEmptyString()] [AllowEmptyCollection()] [object]` | If present, actual `System.String` matching canonical positive decimal, 1–20 digits. |
| `RunId` | optional | same | If present, actual `System.String` matching canonical positive decimal, 1–20 digits. |
| `RunAttempt` | optional | same | If present, actual `System.String` matching canonical positive decimal, 1–20 digits. |

The script is an advanced script with positional binding disabled. Mandatory
omission remains a binder-level interface error, but every provided negative
value reaches the same first production validation block. That block snapshots
the eight parameter boundness flags and raw references without formatting
them. For each provided string-intended value, it rejects in this exact order:

1. null;
2. runtime type other than exactly `System.String`;
3. zero-length string;
4. string consisting entirely of Unicode whitespace;
5. any Unicode control character; and
6. the parameter-specific grammar.

No invalid value is cast with `[string]`, interpolated, trimmed, case-folded,
placed on the pipeline, compared with a string operator, passed to regex/path/
filesystem APIs, or included in an exception/log. A type failure may report
only the parameter name and safe `GetType().FullName`; it never calls the
value's `ToString()`. The common result vocabulary distinguishes
`parameter-null`, `parameter-type`, `parameter-empty`,
`parameter-whitespace`, `parameter-control`, and the parameter's grammar
subreason.

After the common gate:

- path strings proceed unchanged to T1A's ordered wildcard/provider/root/
  containment/component validation; no trim or environment expansion is
  allowed;
- `ExpectedDigest` must match `\A[0-9A-Fa-f]{64}\z`; only after that match may
  a local canonical lowercase copy be created for ordinal digest comparison;
  the raw value is never used as a path or diagnostic label; and
- a present diagnostic ID must match `\A[1-9][0-9]{0,19}\z`. Omission, tested
  only through the snapshotted `$PSBoundParameters`, maps to literal
  `unavailable`. Explicit null, empty, whitespace, control, `0`, leading zero,
  sign, decimal point, exponent, non-ASCII digit, or more than 20 digits fails.

The three diagnostic IDs remain display context only. Even after validation
they cannot select an artifact, form a path/name, authorize bytes, affect
cleanup, or choose a fixture. Diagnostics use fixed templates and bounded
validated strings.

The same rule applies at every other T1A public boundary:

- path-looking parameters of the context manager and permanent harness are
  `[object]` and must pass the common raw string gate before path validation;
- a structured context or ownership journal is accepted as `[object]` and
  must pass its exact runtime-type/closed-shape contract before any property or
  element access—PowerShell collection flattening or hashtable/PSCustomObject
  substitution is not accepted accidentally; and
- a primary failure remains an object (`ErrorRecord`, `Exception`, or explicit
  null under the stated lifecycle contract) and is never converted to text
  while deciding cleanup or return status.

The harness invokes the real entry points with named/splatted arguments and
adds one atomic case per parameter/subreason. At minimum the digest and each
label receive null, integer, Boolean, one/two/empty arrays, hashtable,
`PSCustomObject`, `StringBuilder`, empty string, whitespace-only, and control
values. Digest cases separately cover 63/65 characters and each nonhex class;
label cases cover omission success plus zero, leading zero, sign, non-ASCII
digit, and overlength. Every case proves the intended validation
phase/subreason, no filesystem/archive side effect, no attacker-object
`ToString()` invocation, bounded diagnostics, and equal results on Windows
PowerShell 5.1 and PowerShell 7.

## Finding 7 — T1A's normative case catalog is not structurally atomic

### Problem

T1A's 109-row table is declared normative, but many rows specify only a broad
phase or the word “success” while later prose promises a much larger fixed
result schema. The harness could choose different subreasons, states, cleanup
orders, or diagnostics and still plausibly claim conformance. Seven required
catalog-mutation behaviors have no stable rows at all. Finally, all 109
semantic keys are ordinal placeholders such as `candidate.cleanup.case-03`,
so a P1A/T1A reciprocal comparison cannot survive insertions, splits, or
renumbering.

The solution must leave the issue—not implementation-generated metadata—as the
policy source. Harness authors need machine-transcribable oracles; auditors
need one place to expand every field; cross-repository reviewers need durable
behavior identity; and maintainers need a catalog that can grow append-only
without copying a dozen repeated fields into every row.

### Options and permutations considered

#### Option A — Fully inline every result field in every row

Expand each row to include all promised fields and add rows for every catalog
self-test. Replace ordinal semantic keys with behavior names. This is maximally
explicit and easy for a machine to compare, but produces an extremely wide,
repetitive table. Repeated cleanup/sentinel/default values invite copy/paste
drift and make human review of the meaningful per-case difference harder.

#### Option B — Closed named oracle profiles plus atomic row overrides

Define a small set of fully expanded, immutable oracle profiles. Every row
names exactly one profile and supplies its behavior-specific fixture, initial
state, terminal phase/subreason, diagnostics code, and only the overrides that
the profile explicitly permits. Mechanical expansion yields all fixed result
fields. Add stable rows for catalog integrity and replace every ordinal key
with a behavior-named key shared with P1A when behavior is equal.

Profiles can allow free-form overrides or a closed per-profile override schema.
Free-form overrides merely move ambiguity into an “overrides” cell. The strong
permutation publishes allowed override fields/types and rejects unknown,
missing, or contradictory overrides.

#### Option C — Make a separate machine-readable inventory authoritative

Store JSON/YAML next to the harness and treat it as the sole detailed oracle,
leaving the issue as a summary. This is executable and maintainable, but the
issue's affected-file scope contains only the three scripts, and the prompt
requires the issue to be unambiguous before implementation. Generating the
inventory from the issue is possible only after adopting a structured issue
schema such as Option B.

#### Option D — Keep blanket inherited prose defaults

Retain the compact table and say all failure/success rows inherit common
postconditions. This reduces churn, but a phase-only row still cannot identify
its subreason, exact context state, cleanup sequence, or diagnostics. Several
profiles are needed because pre-context, pre-candidate, partial-removal, and
uncertain-retention cases have materially different states.

#### Option E — Generate expected results from the harness

Let production/harness code emit its catalog and compare executions to that
inventory. This prevents accidental ID omission but makes implementation define
its own expected results; the same bug can change both behavior and oracle.
It is ineligible as a governance inversion.

#### Option F — Group permutations under parameterized rows

Collapse similar path, label, manifest, or platform mutations into one row with
a parameter list. This makes the document shorter but one grouped row can emit
multiple cases, skip only some permutations, or report a disjunctive oracle.
It conflicts with one ID/semantic behavior/result per row.

#### Option G — Fix only currently vague rows

Patch phase-only/success rows and leave apparently detailed rows, ordinal keys,
and catalog mutations unchanged. This is less work but retains multiple schema
classes and guarantees another audit to discover which rows were considered
complete. It does not resolve the structural defect.

### Finding-specific weighted rubric

Scores use 1–5. Any option that permits the implementation to supply a missing
expected field or to group more than one independently reportable behavior in
one row is ineligible.

| Criterion | Weight | What a score of 5 requires for this finding |
|---|---:|---|
| Oracle completeness/unambiguity | 29 | Every field expands to one exact value for every row/runtime with no prose inference or disjunction. |
| Catalog mutation detection | 20 | Missing/duplicate/changed IDs, keys, mappings, fields, classifications, and rationale are themselves stable tested behaviors. |
| Cross-repository semantic durability | 18 | Behavior-named keys remain stable across local renumbering and identify every shared/split P/T behavior exactly. |
| Harness implementability/testability | 14 | Machine metadata can be transcribed and reconciled without inventing defaults or results. |
| Human audit/navigation | 9 | Reviewers can see the unique behavior and expand repeated state without reading implementation code. |
| Append-only maintenance | 7 | New rows/profiles cannot silently change existing meaning and repeated defaults have one controlled definition. |
| Document churn/size | 3 | The normative representation remains manageable in the issue. |

### Scoring

| Option | Completeness (29) | Mutation detection (20) | Semantics (18) | Implementability (14) | Human audit (9) | Maintenance (7) | Size (3) | Total / 100 | Eligibility |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A. Inline all fields | 5 | 5 | 5 | 5 | 3 | 2 | 1 | 89.8 | Eligible |
| B. Closed profiles plus atomic rows | 5 | 5 | 5 | 5 | 5 | 4 | 4 | **98.0** | Eligible |
| C. Separate authoritative inventory | 5 | 5 | 4 | 5 | 2 | 4 | 2 | 87.8 | Eligible only after issue schema exists |
| D. Blanket prose defaults | 2 | 2 | 2 | 2 | 4 | 3 | 5 | 46.8 | **Ineligible: fields remain inferred** |
| E. Harness-generated expectations | 3 | 1 | 2 | 3 | 2 | 4 | 4 | 48.6 | **Ineligible: implementation defines policy** |
| F. Parameterized/grouped rows | 2 | 2 | 2 | 3 | 4 | 4 | 4 | 50.4 | **Ineligible: rows are not atomic** |
| G. Patch vague rows only | 3 | 2 | 1 | 3 | 3 | 2 | 4 | 48.0 | **Ineligible: mixed schemas persist** |

### Selected resolution

Select **Option B**. T1A will contain a closed, versioned profile dictionary
and one atomic row for every behavior. The issue's expanded rows are
authoritative; the harness metadata is an exact transcription checked in both
directions.

#### Unambiguous expected/emitted schemas

Rename ambiguous fields so a negative test's expected production rejection is
not confused with the harness verdict. Every normative row has:

`Id`, `SemanticCase`, `Applicability`, `Fixture`, `InitialState`,
`OracleProfile`, `ExpectedResult` (`success|rejection|skip`),
`ExpectedStatus` (`0|1|null`), `ExpectedPhase`, `ExpectedSubreason`,
`PreCleanupCandidateState`, `FinalCandidateState`, `FinalContextState`,
`CleanupSequence`, `ExpectedDiagnostics`, `SentinelState`, and
`SourceRepositoryState`.

Every emitted record repeats those expected fields and adds the corresponding
`Actual*` fields, runtime/edition/platform identity, exact fixture parameters,
and `HarnessVerdict` (`pass|fail|skip`). A correctly observed negative
production rejection has `ExpectedResult: rejection`, `ExpectedStatus: 1`,
and `HarnessVerdict: pass`. An applicability skip has
`ExpectedResult: skip`, `ExpectedStatus: null`, and `HarnessVerdict: skip`; it
never increments pass totals.

Candidate states are exactly `not-applicable`, `absent`,
`four-valid-files`, `owned-partial`, `preexisting-unchanged`, or
`uncertain-retained`. Context states are exactly `not-created`, `Active`,
`Disposed`, or `RetainedUncertain`. Cleanup sequence is an ordered array drawn
from `candidate-cleanup`, `candidate-cleanup-noop`, `context-cleanup`,
`context-cleanup-noop`, and `none`; a slash, “then,” “applicable,” or
alternative list is invalid metadata.

#### Closed oracle profile dictionary

The initial immutable dictionary is `T1A-ORACLES-v1`:

| Profile | Fixed expansion | Required row fields; only permitted variation |
|---|---|---|
| `OP-SUCCESS-EXTRACT` | success/status 0; phase `complete`; subreason `none`; pre-cleanup `four-valid-files`; final candidate `absent`; final context `Disposed`; cleanup `[candidate-cleanup, context-cleanup]`; unchanged sentinel/source | applicability, fixture, initial state, exact success diagnostics |
| `OP-SUCCESS-CANDIDATE-NOOP` | success/0; final candidate absent; context remains `Active`; cleanup `[candidate-cleanup-noop]`; unchanged sentinel/source | exact phase/subreason `cleanup/candidate-already-disposed`, fixture, initial state, diagnostics |
| `OP-SUCCESS-CONTEXT-NOOP` | success/0; final candidate absent; final context `Disposed`; cleanup `[context-cleanup-noop]`; unchanged sentinel/source | exact phase/subreason `cleanup/context-already-disposed`, fixture, initial state, diagnostics |
| `OP-SUCCESS-PARTIAL-JOURNAL` | success/0; final candidate absent; final context `Disposed`; cleanup `[context-cleanup]`; unchanged sentinel/source | fixture, exact removed-path sequence in initial state/diagnostics |
| `OP-REJECT-PRECONTEXT` | rejection/1; candidate absent; context `not-created`; cleanup `[none]`; unchanged sentinel/source | exact phase, subreason, fixture, initial state, diagnostics |
| `OP-REJECT-PRECANDIDATE` | rejection/1; pre/final candidate absent; final context `Disposed`; cleanup `[context-cleanup]`; unchanged sentinel/source | exact phase, subreason, fixture, initial state, diagnostics |
| `OP-REJECT-PREEXISTING` | rejection/1; pre/final candidate `preexisting-unchanged`; context `Disposed`; cleanup `[context-cleanup]`; unchanged sentinel/source | exact phase, subreason, leaf type/identity, diagnostics |
| `OP-REJECT-PARTIAL-REMOVED` | rejection/1; pre-cleanup `owned-partial`; final candidate absent; context `Disposed`; cleanup `[candidate-cleanup, context-cleanup]`; unchanged sentinel/source | exact phase, subreason, owned-path sequence, diagnostics |
| `OP-REJECT-CANDIDATE-RETAINED` | rejection/1; pre/final candidate `uncertain-retained`; final context `RetainedUncertain`; cleanup `[candidate-cleanup, context-cleanup]`; unchanged sentinel/source | primary phase/subreason, cleanup subreason, exact retained paths, diagnostics |
| `OP-REJECT-CONTEXT-RETAINED` | rejection/1; final candidate absent or the row's proven unchanged state; final context `RetainedUncertain`; cleanup `[context-cleanup]`; unchanged sentinel/source | exact initial/candidate state, phase, subreason, retained paths, diagnostics |
| `OP-SKIP-PRIMITIVE` | skip/null; phase `applicability`; no fixture creation; candidate `not-applicable`; context `not-created`; cleanup `[none]`; unchanged sentinel/source | exact platform, primitive probe, and authorized unavailable reason |
| `OP-CATALOG-REJECTION` | rejection/1; phase `catalog`; candidate/context `not-applicable`; cleanup `[none]`; unchanged sentinel/source | exact mutation fixture, subreason, and mismatch diagnostic |

Each profile definition lists all fixed fields and the only fields a row must
supply. Unknown profiles, unknown row fields, an override of a fixed profile
field, missing required variation, prose alternatives, and contradictory
state fail static catalog validation. After merge, profile meanings are
immutable. A new behavior uses a new profile/row; an existing ID or key is
never silently migrated to altered semantics.

#### Atomic row and semantic-key rules

Every existing row is rewritten to include its profile and exact required row
fields. No row may contain two mutated parameters, paths, separators, platform
outcomes, leaf types, or failure alternatives. The new raw-digest/label cases
from Finding 6 likewise receive individual rows; arrays and objects are not
grouped.

Replace ordinal keys with lower-case behavior identities. Representative
required mappings are:

| Local ID | Behavior-named `SemanticCase` |
|---|---|
| `T1A-V-01` | `archive.valid.exact-four-files` |
| `T1A-V-02` | `archive.valid.external-attributes-ignored` |
| `T1A-P-01` | `path.containment.checkout-sibling-prefix-rejected` |
| `T1A-P-02` | `path.provider.filesystem-qualified-accepted` |
| `T1A-D-01` | `digest.mismatch.labels-supplied` |
| `T1A-D-02` | `digest.mismatch.labels-omitted` |
| `T1A-M-05` | `manifest.name.forward-slash-nesting-rejected` |
| `T1A-M-06` | `manifest.name.backslash-nesting-rejected` |
| `T1A-L-03` | `destination.preexisting.live-reparse-retained` |
| `T1A-K-03` | `cleanup.candidate.repeat-disposed` |
| `T1A-C-02` | `cleanup.context.repeat-disposed` |
| `T1A-R-06` | `limit.declared-total.at-32mib-accepted` |
| `T1A-W-02` | `download.entry-count.two-rejected` |
| `T1A-S-11` | `harness.input.provider-qualified-tracked-scripts-accepted` |

The same behavior in P1A uses the exact same semantic key, regardless of local
ID. A grouped P row must be split into logical evidence rows before comparison;
one P row may not satisfy several T keys without separate fixture/oracle
evidence. A Terraform-only behavior still receives a behavior name and an
explicit counterpart classification; lack of a required P behavior is
`blocker`, not an invented equality.

#### Catalog integrity cases

Add these rows to the normative catalog and run each against a disposable
mutated catalog instance, never by changing the authoritative in-memory object:

| ID | `SemanticCase` | Exact expected oracle |
|---|---|---|
| `T1A-I-01` | `catalog.local-id.duplicate-rejected` | `OP-CATALOG-REJECTION`; `catalog/duplicate-local-id` |
| `T1A-I-02` | `catalog.local-id.missing-rejected` | `OP-CATALOG-REJECTION`; `catalog/missing-local-id` |
| `T1A-I-03` | `catalog.semantic-key.duplicate-rejected` | `OP-CATALOG-REJECTION`; `catalog/duplicate-semantic-key` |
| `T1A-I-04` | `catalog.semantic-key.missing-rejected` | `OP-CATALOG-REJECTION`; `catalog/missing-semantic-key` |
| `T1A-I-05` | `catalog.mapping.changed-rejected` | `OP-CATALOG-REJECTION`; `catalog/id-key-mapping-changed` |
| `T1A-I-06` | `catalog.oracle.divergence-rejected` | `OP-CATALOG-REJECTION`; `catalog/equal-key-oracle-differs` |
| `T1A-I-07` | `catalog.counterpart.classification-missing-rejected` | `OP-CATALOG-REJECTION`; `catalog/counterpart-classification-missing` |
| `T1A-I-08` | `catalog.intentional-difference.rationale-missing-rejected` | `OP-CATALOG-REJECTION`; `catalog/intentional-difference-rationale-missing` |

Startup expands the issue-transcribed profile/row metadata, validates its
schema and unique sets, and computes the exact applicable ID/runtime pairs.
Completion requires one emitted record for every pair and none outside it.
Separate mutation tests prove missing, duplicate, unexpected, and multiply
emitted actual results fail. The retained evidence includes the catalog/profile
version, canonical expanded catalog SHA-256, counts by applicability/profile/
expected result, and per-runtime pass/fail/skip totals.

## Finding 8 — T1A's tracked-script identity lacks a complete Git contract

### Problem

The permanent harness must reject untracked helper/context-manager scripts,
including when their inputs use a provider-qualified spelling, but T1A never
defines the repository root, Git command, output format, status classification,
or comparison. T1's workflow scope verifier is not a reusable PowerShell API.
Merely finding a path in the index also would not prove that the supplied
working bytes equal the path's committed blob.

The proof must bind three identities before either supplied script executes:
the fixed role path in the reviewed `HEAD` tree, the stage-0 index entry, and
the ordinary worktree file actually supplied. Security reviewers need those
bytes equal; Git specialists need literal/NUL-safe paths and correct stages;
Windows users need provider-qualified paths normalized without losing the
canonical repository name; and harness authors need deterministic negative
fixtures.

### Options and permutations considered

#### Option A — Match HEAD tree, index, and no-filter worktree object IDs

Derive a trusted repository root from the harness's fixed `$PSScriptRoot`,
normalize each supplied path, map it to one of two fixed canonical repository
paths, and query Git three ways: `ls-tree -z` for `HEAD`, `ls-files --stage -z`
for the index, and `hash-object --no-filters` for the working bytes. Require
one ordinary stage-0 record and one identical full object ID across all three.
Use literal pathspecs, raw byte parsing, and immediate native-status capture.

The tree and index alone prove tracking at two snapshots but not the invoked
bytes. The index and worktree alone permit a staged script not present in the
reviewed commit. All three comparisons are required.

#### Option B — Use only `git ls-files --error-unmatch`

This is the direct definition of “tracked in the index,” and `--stage -z`
supports safe exact parsing. It does not reject a staged replacement, an
unstaged byte change, or a conflict unless additional mode/stage/working-tree
checks are added. Once those checks include the commit and worktree, it becomes
Option A.

#### Option C — Use porcelain status/diff output

Run `git status --porcelain` or `git diff --quiet` and infer that absence from
modified/untracked sets means tracked. Porcelain text has quoting and
multi-status rules, path absence can mean ignored or outside the queried set,
and a clean result does not itself prove the expected canonical path/mode/tree
entry. It is useful as a broad scope gate, not a positive identity record.

#### Option D — Trust the `HEAD` tree entry only

Require that `git ls-tree HEAD` contains the fixed path and then invoke the
normalized filesystem path. An attacker or fixture can replace working bytes
after checkout while the tree remains correct. Ordinary-file and version
checks narrow this but do not prove blob equality.

#### Option E — Remove “tracked” and rely on explicit SHA-256/commit evidence

Make the caller provide the expected script SHA-256 and commit, verify the
ordinary file directly, and stop claiming runtime tracking. This can provide
strong byte identity if all callers hold trusted expected hashes; however, the
current harness public API supplies only two paths, T1A explicitly promises
tracked-path rejection, and local developer runs would need a new trust input.
It is a coherent redesign but not the selected contract.

#### Option F — Verify through the GitHub API or downloaded source archive

Query the reviewed commit tree/blob remotely and compare local bytes. This
avoids reliance on the local index but adds network credentials, API
availability, rate limits, archive identity, and another serialization
boundary to an offline harness. It still must map local/provider-qualified
paths safely.

#### Option G — Parse `.git/index` directly

Read the index format and object database from PowerShell. This can avoid
subprocess ambiguity but must implement extensions, split/sparse indexes,
object formats, conflict stages, packed objects, alternates, and worktrees.
Git itself already provides the exact read-only plumbing needed.

### Finding-specific weighted rubric

Scores use 1–5. An option that retains the “exact tracked script” claim is
ineligible unless it binds the actual invoked bytes to the fixed canonical path
in the reviewed commit.

| Criterion | Weight | What a score of 5 requires for this finding |
|---|---:|---|
| Commit/index/worktree identity assurance | 30 | Fixed HEAD blob, sole stage-0 index blob, and actual no-filter worktree bytes are ordinary and identical. |
| Raw/literal path correctness | 20 | Provider spelling cannot affect Git selection; NUL output and literal pathspecs preserve exact canonical repository bytes. |
| Native failure/cardinality determinism | 16 | Start failure, status 0/1/other, empty/duplicate/malformed records, stages, modes, object type, and OID format are distinct. |
| Invocation binding/TOCTOU narrowing | 14 | Both scripts are fully proven before either runs and the same normalized ordinary files are invoked without rereading caller paths. |
| Cross-platform Git/PowerShell behavior | 10 | The contract works in Windows PowerShell 5.1 and PowerShell 7 on Windows/Linux without shell parsing. |
| Fixture and evidence quality | 7 | Disposable repositories prove each tree/index/worktree/path/status mutation and retain exact Git/executable/OID evidence. |
| Implementation complexity | 3 | The solution uses supported Git plumbing with little bespoke format logic. |

### Scoring

| Option | Identity (30) | Paths (20) | Native handling (16) | Invocation binding (14) | Cross-platform (10) | Fixtures (7) | Complexity (3) | Total / 100 | Eligibility |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A. HEAD + index + working OIDs | 5 | 5 | 5 | 4 | 4 | 5 | 2 | **93.4** | Eligible |
| B. Index `ls-files` only | 3 | 5 | 5 | 3 | 4 | 4 | 4 | 78.4 | **Ineligible: invoked bytes need not match commit** |
| C. Porcelain status/diff | 2 | 2 | 3 | 2 | 4 | 3 | 5 | 50.4 | **Ineligible: no positive identity proof** |
| D. HEAD tree only | 3 | 5 | 5 | 2 | 4 | 4 | 4 | 75.6 | **Ineligible: working replacement is possible** |
| E. Remove tracked claim/use SHA-256 | 3 | 4 | 4 | 3 | 5 | 3 | 5 | 72.4 | Eligible after API redesign |
| F. GitHub API/archive verification | 4 | 4 | 3 | 2 | 3 | 3 | 1 | 66.0 | Eligible but network-dependent |
| G. Parse Git storage directly | 4 | 5 | 2 | 3 | 2 | 2 | 1 | 66.2 | Eligible in theory |

### Selected resolution

Select **Option A**. The harness implements one private read-only tracked-file
proof and applies it to both supplied scripts before invoking either.

#### Trusted root and canonical role mapping

The running harness first proves its own normalized `$PSScriptRoot` ends in the
ordinary, non-reparse `.github/workflows` directory. It derives the candidate
repository root by exactly two parents, validates every component, and never
uses the caller's current directory or an ambient Git root.

Run Git directly without a command shell. Remove/reject ambient `GIT_DIR`,
`GIT_WORK_TREE`, `GIT_INDEX_FILE`, object-directory/alternate-object variables,
and pathspec-mode variables; set `GIT_LITERAL_PATHSPECS=1` and
`GIT_OPTIONAL_LOCKS=0` for each child only. Include global
`--no-replace-objects`, `--no-pager`, and `-C <trusted-root>` arguments. Record
the Git executable path and version.

Prove the candidate root using separate commands whose raw stdout is exactly
one expected LF-terminated ASCII token:

```text
git ... rev-parse --is-inside-work-tree     # exactly true
git ... rev-parse --show-prefix             # exactly the empty prefix
git ... rev-parse --show-object-format=storage
git ... rev-parse --verify HEAD^{commit}
```

The object format is exactly `sha1` or `sha256`, determining a 40- or
64-lowercase-hex full object ID. `HEAD^{commit}` must produce exactly one full
ID in that format.

Validate each raw `HelperPath`/`ContextManagerPath` under Finding 6's object and
path rules. Normalize the native or `FileSystem::`-qualified input once, then
compare that absolute result to the exact role destination under the trusted
root using ordinal-ignore-case on Windows and ordinal on Linux. Only after the
absolute role match, map it to one fixed UTF-8 repository path:

| Role | Canonical repository path |
|---|---|
| helper | `.github/workflows/Expand-StyleGuideCandidateArtifact.ps1` |
| context manager | `.github/workflows/Manage-StyleGuideCandidateInvocationContext.ps1` |

Never turn the caller's original spelling into a pathspec. Provider
qualification is therefore accepted as an alternate spelling of the same
filesystem object, not compared to Git text.

#### Exact three-way Git proof

For each canonical path, run these exact logical argument arrays:

```text
git ... ls-tree --full-tree -r -z HEAD -- <canonical-repository-path>
git ... ls-files --cached --stage --full-name -z --error-unmatch -- <canonical-repository-path>
git ... hash-object --no-filters -- <normalized-absolute-path>
```

Capture stdout through `BaseStream`, stderr separately, and native status
immediately. Do not decode the full record as lines. The tree command must
return status 0 and exactly one terminal-NUL record shaped
`100644 SP blob SP <full-oid> TAB <exact-path-bytes> NUL`. Status 0 with no
record means `script-not-in-head`; duplicate, nonblob, wrong-mode, abbreviated/
malformed OID, wrong path bytes, missing final NUL, or extra bytes is
`git-tree-output-invalid`.

The index command must return status 0 and exactly one record shaped
`100644 SP <same-full-oid> SP 0 TAB <exact-path-bytes> NUL`. Its documented
status 1 with no accepted record is `script-untracked`; every other nonzero or
start failure is `git-tool-failure`. Multiple/conflict stages, duplicate
records, wrong mode/OID/path, malformed metadata, missing final NUL, or trailing
bytes fail as `git-index-output-invalid`.

The hash command must return status 0 and exactly one LF-terminated full object
ID equal to the HEAD/index OID. Because `--no-filters` hashes the working bytes
as-is, inequality is `script-worktree-bytes-differ`; malformed/cardinality
output is `git-hash-output-invalid`. It must not use `-w`, filters, text
conversion, or the index as the file-content source.

All three OIDs and both raw path fields must be equal before the role is
accepted. The harness proves both roles completely before dot-sourcing or
child-invoking either, stores only their normalized role paths/OIDs/versions,
and never rereads the public path parameters. Immediately before each later
invocation, it repeats ordinary-file/component identity and the no-filter
worktree OID comparison. The supported no-competing-writer runner model is
stated explicitly; Git membership is not claimed to be an OS handle sandbox.

#### Status, diagnostics, and fixtures

Every Git call classifies process-start failure, status 0, documented
`ls-files` status 1, and all other statuses separately. Success output is never
logged wholesale. Failure diagnostics contain the fixed role, fixed command
role, status, bounded structural reason, and expected/actual OIDs when safe;
they do not print raw paths, stdout, environment, file contents, or arbitrary
stderr.

Retain existing `T1A-S-12`/`T1A-S-13` as the two untracked-role cases and add
atomic behavior-keyed rows for: HEAD path absent; index path absent; staged
replacement; unstaged byte replacement; conflict stages; wrong Git mode;
nonblob tree entry; wrong/duplicate/truncated/malformed raw record; raw path
mismatch; abbreviated/wrong-algorithm OID; `ls-files` status 1; unexpected
status 2; and process-start failure. Disposable repositories also use spaces,
tabs, newlines, leading dash, `[`/`*`/`?`, non-ASCII, and pathspec-magic
characters to prove fixed literal selection and raw parsing. The valid native
and provider-qualified controls must yield identical canonical path and OID
evidence on Windows PowerShell 5.1 and PowerShell 7.

## Finding 9 — Repeated candidate cleanup has no durable disposed identity

### Problem

`Remove-StyleGuideCandidateInvocationState` currently accepts a path envelope,
path-only ownership journal, and primary failure. After it safely removes a
candidate, nothing in that public tuple says its destructive authority was
consumed. If the leaf is later reused with matching names, an old journal can
look like initial owned state. `T1A-K-03` promises a repeated success/no-op but
does not require the leaf to remain absent or define reoccupation behavior.

Cleanup must remain idempotent without ever deleting a replacement. The helper
author needs a state it can return and mutate; the caller needs a deterministic
finally path; an incident responder needs retained identity/summary; and
cross-platform maintainers need semantics that do not depend on an unavailable
portable inode API.

### Options and permutations considered

#### Option A — Dedicated candidate ownership lifecycle object

Replace the loose envelope/journal cleanup arguments with a closed candidate
state object carrying schema version, ContextId, CandidateId, normalized
envelope, journal, lifecycle state, and cleanup summary. The same object moves
from `NotCreated|Active` through `CleanupInProgress` to
`Disposed|RetainedUncertain`. A valid `Disposed` repeat succeeds only if exact
inspection proves the leaf absent; any reappeared/unclassifiable entry fails
with zero deletion.

The object can retain journal audit records while clearing their `Owned` flags,
or discard them after cleanup. Retaining immutable acquisition records and
marking ownership consumed is stronger for incident evidence, provided a
disposed entry can never reactivate them. That permutation is selected.

#### Option B — Nest candidate lifecycle inside the caller context

Add candidate state to the existing invocation-context object and make both
cleanup functions consume it. This reuses ContextId/lifecycle machinery and
can be safe. It couples the archive helper to a context it currently treats as
untrusted/independent, makes candidate cleanup depend on caller cleanup schema,
and complicates helper use outside that exact manager.

#### Option C — Clear the journal and add a Boolean disposed flag

After successful cleanup, empty the caller's journal and set `Disposed=true`;
on repeat, require an empty journal and absent leaf. This is a small change but
has no schema/identity/transition contract, and a copied old journal still
matches the cleanup function's current signature. Adding exact identity and
state validation turns it into Option A.

#### Option D — Treat an absent leaf as repeated success

If the candidate path is absent, return success; if present, run ordinary
cleanup using the supplied journal. This handles a normal repeat but cannot
distinguish first cleanup of an active candidate from reuse with an old
journal—the dangerous case is precisely when the path exists.

#### Option E — Hold and compare OS file identities/handles

Capture directory/file IDs or open handles at acquisition and require the same
objects at deletion. This gives strong replacement detection, but Windows and
Linux identity APIs, handle sharing, ZIP stream disposal, link behavior, and
PowerShell 5.1 interop differ. Directory removal also destroys the identity
needed for later repeat checks. It can narrow active-cleanup races but does not
replace a consumed lifecycle.

#### Option F — Make every repeated call fail without deletion

After successful cleanup, a second call returns a stable nonzero result even
when the leaf is absent. This is safe and simpler semantically, but still needs
durable state to distinguish the call. It also makes ordinary nested/finally
cleanup composition noisier and abandons the useful idempotent contract.

#### Option G — Write a tombstone outside the candidate leaf

Persist CandidateId/disposed state in a sibling file and consult it on repeat.
The tombstone becomes another owned path subject to substitution, cleanup, and
eventual removal; once context cleanup removes it, an old journal again loses
state. Leaving tombstones permanently pollutes runner storage and exposes a new
authorization artifact.

### Finding-specific weighted rubric

Scores use 1–5. Any option that lets an old path-only journal authorize
deletion after the candidate state has been disposed is ineligible.

| Criterion | Weight | What a score of 5 requires for this finding |
|---|---:|---|
| Reoccupied-leaf nondeletion guarantee | 30 | Every entry type appearing after disposal yields zero deletion and a stable retained-state result. |
| Lifecycle and repeat determinism | 22 | Initial, in-progress, disposed, uncertain, malformed, and repeated calls have closed transitions and exact results. |
| Primary/cleanup failure preservation | 15 | State and summary retain both reasons without masking the primary status or retrying destructive work. |
| Cross-platform feasibility | 12 | Semantics work under PS 5.1/7 on Windows/Linux without relying on nonportable persistent inode identity. |
| Helper/context API separation | 9 | Candidate ownership remains self-contained while matching ContextId and composing safely with caller cleanup. |
| Adversarial testability/evidence | 8 | Every post-disposal leaf type, object mutation, transition, repeat, and cleanup sequence has an atomic oracle. |
| API/churn cost | 4 | Existing helper/caller flows need minimal additional objects or transport. |

### Scoring

| Option | Nondeletion (30) | Lifecycle (22) | Failure preservation (15) | Cross-platform (12) | Separation (9) | Tests (8) | Churn (4) | Total / 100 | Eligibility |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A. Candidate lifecycle object | 5 | 5 | 5 | 4 | 4 | 5 | 3 | **94.2** | Eligible |
| B. Nest in caller context | 5 | 5 | 5 | 4 | 2 | 4 | 2 | 88.2 | Eligible |
| C. Empty journal + Boolean | 3 | 3 | 4 | 5 | 5 | 4 | 5 | 74.6 | **Ineligible: copied old journal remains authoritative** |
| D. Absence-only repeat | 2 | 3 | 4 | 5 | 5 | 3 | 5 | 67.0 | **Ineligible: reoccupied path is ambiguous** |
| E. OS handles/file IDs | 5 | 5 | 4 | 1 | 3 | 3 | 1 | 77.4 | Eligible only with platform-specific redesign |
| F. Repeats always fail | 5 | 4 | 4 | 5 | 4 | 4 | 4 | 88.4 | Eligible only with durable state |
| G. Filesystem tombstone | 3 | 4 | 3 | 3 | 3 | 3 | 2 | 63.6 | **Ineligible: tombstone loss reopens ambiguity** |

### Selected resolution

Select **Option A**. Candidate cleanup consumes one exact lifecycle object; a
loose envelope and path journal are no longer a valid destructive API.

The helper creates and returns, alongside the four validated candidate paths,
the same mutable object whose first `PSTypeName` is exactly
`TerraformStyleGuide.StyleGuideCandidateOwnershipState.v1`:

| Property | Exact type and meaning |
|---|---|
| `SchemaVersion` | `[uint32]1` |
| `CandidateId` | newly generated nonempty `[guid]`, immutable |
| `LifecycleState` | exact `[string]`: `NotCreated`, `Active`, `CleanupInProgress`, `Disposed`, or `RetainedUncertain` |
| `TrustedTemporaryRootPath` | normalized nonempty `[string]`, immutable |
| `CandidateParentPath` | normalized nonempty `[string]`, immutable strict descendant of trusted root |
| `CandidateDirectoryPath` | normalized nonempty `[string]`, immutable exact leaf under parent |
| `OwnershipJournal` | exact ordered `[object[]]` of the existing closed v1 ownership-entry schema |
| `CleanupAttempt` | `[uint32]`, initially 0; incremented only when a valid nonterminal state enters cleanup |
| `CleanupSummary` | `$null` initially; then a closed summary containing ID, prior/final state, primary reason, cleanup reason, ordered removed/retained entries, and leaf observation |

The helper constructs this object in `NotCreated` before any candidate creation.
After it acquires the fresh candidate directory, it moves to `Active` and
journals each ordinary file at acquisition. Its successful result contains the
same object reference. Its failure path invokes the same production cleanup
with that object. `Remove-StyleGuideCandidateInvocationState` now accepts only
`CandidateOwnershipState` and `PrimaryFailure`; overloads accepting an
envelope/journal or a Boolean disposed claim do not exist.

The cleanup function treats the object as untrusted. Before filesystem work it
requires the exact PSTypeName, property set/types, CandidateId, allowed state,
immutable envelope, journal entry schema/order/unique paths, and consistency
between state, `Owned` flags, attempt count, and prior summary. Unknown,
missing, copied loose, path-mutated, ID-mutated, reactivated, or contradictory
state fails `cleanup/candidate-state-invalid` with zero filesystem/deletion
calls.

Transitions are closed:

1. **`NotCreated`.** Revalidate the trusted parent/component envelope and
   exhaustively enumerate the immediate parent once. If the candidate leaf is
   absent, move directly to `Disposed`, record an empty cleanup, and succeed.
   Any matching or unclassifiable entry moves to `RetainedUncertain` and fails
   without deletion.
2. **`Active`.** Perform the complete pre-deletion ownership/envelope pass.
   Any uncertainty moves to `RetainedUncertain` with zero deletion. Only after
   the pass succeeds, increment attempt and move to `CleanupInProgress`;
   remove the journaled ordinary files nonrecursively in the recorded safe
   order and then the proven empty candidate directory. On complete success,
   mark every journal entry `Owned=false`, retain its immutable acquisition
   evidence, set `Disposed`, record absent leaf, and return success. On a
   deletion/inspection failure, stop immediately, set `RetainedUncertain`, and
   record exactly what was removed and retained without retrying.
3. **`Disposed`.** Validate the complete object and require every journal entry
   remains `Owned=false`. Revalidate parent components and enumerate its
   immediate entries once solely to determine whether the exact candidate leaf
   is absent. If absent, return success/no-op with the identical object,
   attempt count, journal, and summary and make zero deletion calls. If any
   file, directory, live link/reparse, dangling entry, unknown entry, duplicate
   name, or enumeration/classification error can occupy that leaf, transition
   to `RetainedUncertain`, emit
   `cleanup/candidate-disposed-leaf-reoccupied`, and make zero deletion calls.
4. **`CleanupInProgress` or `RetainedUncertain`.** Entry is a stable nonzero
   `cleanup/candidate-state-retained` result with zero inspection below the
   recorded safe envelope and zero deletion. There is no automatic destructive
   retry.

Parent enumeration—not `File.Exists`/`Directory.Exists`—defines absence, so a
dangling link cannot disappear from the check. Enumeration results are
materialized once and compared using the platform's exact path semantics.
Nothing is followed or recursively removed.

The caller-context cleanup consumes the candidate result before attempting its
own root cleanup. It may proceed only when the exact candidate object is
`Disposed` and the candidate leaf is re-proven absent. A
`RetainedUncertain`/invalid candidate makes the context
`RetainedUncertain`; the caller does not delete the invocation root around it.
Primary failure/status remains the returned primary result, with candidate and
context cleanup failures attached separately.

`T1A-K-03` becomes the exact absent-leaf repeat success under
`cleanup.candidate.repeat-disposed`. Add separate atomic rows for reoccupation
by ordinary file, ordinary directory, live link/reparse, dangling link, and
unreadable/unclassifiable entry; each expects retained-state status 1 and zero
deletion. Additional rows cover `NotCreated` absent/reoccupied, normal Active
cleanup, entry in `CleanupInProgress`, entry in `RetainedUncertain`, old loose
journal invocation, `Owned=true` reactivation, CandidateId/path mutation, and
primary failure followed by partial cleanup failure. Every case records the
same CandidateId, state transition, attempt count, exact removed/retained
sequence, outside sentinel, and context consequence.

## Finding 10 — T1B has two credential claims that contradict its token model

### Problem

T1B correctly says GitHub creates a job token before every job, each checkout
explicitly passes `github.token` for authenticated fetch, and
`persist-credentials: false` controls post-checkout persistence. Two earlier
sentences contradict that model: preparation checks out with “credentials
disabled,” and writer revalidation occurs “before token expansion” even though
writer checkout has already expanded the token input.

The issue needs vocabulary that distinguishes token availability, explicit
action-input expansion, temporary checkout Git configuration, cleanup, and the
later push-step environment/header. Security reviewers need an honest exposure
model; implementers need exact phase boundaries; operators need to know which
credential residue checks are meaningful; and maintainers should not redesign
the graph merely to preserve inaccurate prose.

### Options and permutations considered

#### Option A — Correct both claims and define credential lifecycle terms

Say preparation and writer perform transient authenticated checkout **with
credential persistence disabled**. Say writer revalidation happens after
checkout/credential-removal proof but before **explicit push-step token
environment and authorization-header construction** or repository mutation.
Define the distinct phases once and use them throughout T1B.

This preserves the reviewed graph and matches the pinned checkout manifest/
source. It also prevents “token-free job,” “credential-free checkout,” and
“token absent” from reappearing as synonyms for “not persisted.”

#### Option B — Replace checkout with anonymous raw Git fetch

Because the repository is public, read jobs could initialize/fetch over HTTPS
without an Authorization header; the writer could do the same and receive an
explicit token only for push. This would make “unauthenticated fetch” true, but
replaces pinned checkout behavior with substantial raw Git checkout/submodule/
safe-directory logic and still does not make `github.token` unavailable in the
job context. It is a disproportionate architecture change for wording.

#### Option C — Move checkout/revalidation to a read job

Have a read-only job checkout and validate, then transfer a verified workspace
or candidate to a write job that performs no checkout before push. This narrows
explicit use in the write job but adds a transport/trust boundary, changes
direct needs and at-use state, and the write job's `github.token` still exists
from job start. T1B already uses a fresh writer checkout specifically to
revalidate the target at use.

#### Option D — Mint a separate GitHub App token only for push

Use OIDC/App credentials or an installation token created at the push step.
This can provide a separately governed actor, but introduces an app,
installation/private-key or federation policy, new permissions, token action/
code, and ruleset identity. It does not erase the ordinary job
`GITHUB_TOKEN`; it changes the production credential architecture.

#### Option E — Keep the current shorthand

Interpret “credentials disabled” as “persistence disabled” and “before token
expansion” as “before push-step expansion.” A sympathetic reader can infer
that meaning, but the issue elsewhere uses those distinctions precisely.
Security contracts cannot rely on charitable reinterpretation.

#### Option F — Remove credential timing statements

State only `persist-credentials: false` and the final push algorithm. This
avoids direct contradiction but loses the explicit checkout authentication,
cleanup proof, job-context availability, and environment/header lifetime
needed to audit least privilege.

#### Option G — Pass an empty checkout token

Set `token: ''` and retain checkout. The reviewed pinned action declares token
required and uses it for fetch/REST fallback; empty input is not the supported
anonymous mode. This would also violate the exact action-input policy and is
ineligible.

### Finding-specific weighted rubric

Scores use 1–5. An option is ineligible if it describes authenticated checkout
as credential-free or claims the write job's token is absent before push.

| Criterion | Weight | What a score of 5 requires for this finding |
|---|---:|---|
| Authentication-lifecycle factual correctness | 32 | Job token, action input, temporary Git auth, cleanup, push env/header, and expiry are named at their actual phases. |
| Security-boundary clarity | 22 | A reader can tell which exposure is unavoidable, which is explicitly materialized, and what absence checks can prove. |
| Least-privilege auditability | 17 | Permissions and token consumers/lifetimes are closed and every persistence/materialization claim is testable. |
| Fit with reviewed T1B graph | 12 | The resolution preserves fresh writer checkout, at-use revalidation, and the sole push path. |
| Operator/debug usability | 8 | Failures can be assigned to checkout auth, cleanup residue, pre-push validation, header construction, push, or final cleanup. |
| Scope/churn | 6 | No new app, secret, transport, or checkout implementation is introduced. |
| Implementation effort | 3 | A small coherent language/policy change resolves the issue. |

### Scoring

| Option | Factual model (32) | Boundary clarity (22) | Auditability (17) | Graph fit (12) | Operations (8) | Scope (6) | Effort (3) | Total / 100 | Eligibility |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A. Correct terms/define phases | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** | Eligible |
| B. Anonymous raw Git | 5 | 4 | 4 | 2 | 3 | 2 | 1 | 75.8 | Eligible but unnecessary |
| C. Transfer from a read job | 5 | 5 | 5 | 2 | 2 | 1 | 1 | 80.8 | Eligible after graph redesign |
| D. Separate App token | 4 | 4 | 4 | 2 | 2 | 1 | 1 | 66.6 | Eligible after credential redesign |
| E. Keep shorthand | 1 | 1 | 2 | 5 | 3 | 5 | 5 | 43.4 | **Ineligible: claims remain false** |
| F. Remove timing language | 2 | 1 | 1 | 4 | 2 | 5 | 5 | 42.4 | **Ineligible: audit boundary disappears** |
| G. Empty checkout token | 1 | 1 | 1 | 1 | 1 | 4 | 4 | 25.4 | **Ineligible: unsupported action input** |

### Selected resolution

Select **Option A**. T1B defines and consistently uses this credential
lifecycle:

| Phase | Exact claim |
|---|---|
| Job creation | GitHub creates `GITHUB_TOKEN`; `github.token` is available to steps/actions subject to the job's exact permissions. No job is called token-free. |
| Checkout input | The reviewed checkout role explicitly expands `${{ github.token }}` into its `token` input and uses transient authentication for fetch/REST fallback. |
| Checkout persistence | `persist-credentials: false` prevents the action from leaving its configured token/SSH material for later Git commands; it does not make checkout anonymous. |
| Post-checkout proof | After checkout cleanup, fixed presence-only checks require no credential-bearing remote URL, credential helper, `http.*.extraheader`, or token/header environment deliberately supplied to repository scripts. This proves absence of retained Git authentication, not absence of the job token/context. |
| Pre-push validation | Writer artifact/helper/path/ref/parent/tree/lease preparation runs after authenticated checkout but before explicit push-step environment materialization, header construction, commit/ref mutation, or push. |
| Push materialization | Only the guarded push step explicitly maps `${{ github.token }}` to its masked environment and constructs the in-memory Basic header. Only the one `git push` child receives the temporary `GIT_CONFIG_*` header configuration. |
| Final cleanup/expiry | `finally` clears step-created token/header/config values and presence checks prove no retained Git state. GitHub owns job-token expiry. |

Replace preparation step 1 with:

> Check out the exact event SHA using the reviewed checkout action's explicit
> `github.token` input, with credential persistence disabled; after checkout
> cleanup, prove no retained Git credential state before repository code runs.

Replace the writer introduction with:

> After its transient authenticated checkout and credential-removal proof, and
> before explicit push-step token environment/header construction or any
> repository mutation, the writer revalidates the artifact, candidate, target
> identity, and exact generated bytes.

Replace writer revalidation step 1 with:

> Check out the exact expected commit with transient authentication and
> credential persistence disabled, then prove checkout left no retained Git
> credential state.

Apply the same wording to every summary, step, table, acceptance criterion, and
fixture; the phrases “credentials disabled,” “credential-free checkout,”
“before token expansion,” and “token absent” are forbidden unless the subject
is the exact retained state or explicit push materialization named above.

The validator continues to require explicit token inputs so an action-manifest
default cannot drift silently. Its separate reviewed-default table and job
permissions acknowledge that reviewed actions can access `github.token` from
context; absence of an explicit mapping is not treated as proof an action could
not access it. Fixtures independently mutate checkout token input, persistence,
job permission, post-checkout residue, push-step environment owner, header
child scope, arguments/remotes/config, and final cleanup. Logs and evidence
record only presence/absence and role/phase, never credential values.

## Finding 11 — T1B's “complete” job inventory omits called-workflow jobs

### Problem

T1B's graph lists the `build.yml` caller job `markdown`, and its role table
mentions checkout/setup-node actions that will run inside
`markdownlint.yml`, but no normative row identifies the called workflow's job
or jobs. A local reusable workflow can contain multiple jobs, permissions,
conditions, outputs, services, environments, or nested calls without adding an
external action. Such a change would escape the purported complete
job/role/data-flow policy.

The validator must close both the authored caller graph and its local expansion.
Security reviewers need every token/runner/side effect enumerated; workflow
authors need the caller/called distinction; CI operators need meaningful total
counts; and T2 needs one known internal Markdown job it can extend without
creating an unseen parallel job.

### Options and permutations considered

#### Option A — One hierarchical allowlist covering caller and called jobs

Retain `build.yml`'s `markdown` caller and require `markdownlint.yml` to contain
exactly one internal job, `markdownlint`. Publish exact rows for the caller
interface and internal job permissions, needs, eligibility, outputs, runner,
steps/roles, and side effects. Validate both per-file static declaration counts
and expanded graph/runner counts.

The internal job could be treated as a child row under the caller or flattened
into one table with qualified IDs. Qualified identity
`markdown::markdownlint` plus separate caller and internal tables is clearest:
it preserves GitHub's actual two-level semantics while permitting one aggregate
count/reachability check.

#### Option B — Inline Markdown steps into `build.yml`

Remove the reusable workflow and make `markdown` an ordinary runner job. This
creates a single visible graph and scores well on closure. It abandons T1B's
deliberate local reusable-workflow interface and makes later independent
Markdown maintenance harder. It is a valid redesign but unnecessary to fix
the inventory.

#### Option C — Treat the local workflow as an opaque commit-bound unit

Rely on same-commit local `uses` and perhaps hash the workflow file. That binds
which bytes execute but does not say what jobs/permissions/side effects those
bytes are allowed to contain. A reviewed hash update could silently expand
authority unless the update review recreates the missing policy manually.

#### Option D — Recursively accept whatever jobs the parser discovers

Have the validator enumerate local called jobs and compute totals dynamically,
rejecting only remote/nested calls or write permissions. This detects syntax
and broad privilege, but observed YAML becomes the allowlist for job IDs,
dependencies, conditions, outputs, and side effects. It violates T1B's rule
that hand-authored policy determines exact counts.

#### Option E — Add a second validator for `markdownlint.yml`

Keep the current build validator and add a called-workflow-specific validator.
Both surfaces can be closed, but policy parsing, pins, fixtures, and aggregate
counts can drift. T1/T1B explicitly require extending one permanent parser/
validator.

#### Option F — Assert only aggregate static/expanded counts

Require six declarations and nine expanded nodes but not exact qualified IDs
and fields. An extra job can replace an expected one, or two jobs can trade
permissions/side effects while totals remain equal. Counts are necessary
cross-checks, not identity.

#### Option G — Require “one internal job” but leave it implementation-defined

This blocks additional jobs but lets the sole job change name, permissions,
condition, runner, outputs, services, environment, steps, or nested calls.
It resolves only the numeric symptom.

### Finding-specific weighted rubric

Scores use 1–5. An option is ineligible if a called workflow can add/change a
job authority or side effect without changing an expected hand-authored row.

| Criterion | Weight | What a score of 5 requires for this finding |
|---|---:|---|
| Complete executable authority surface | 29 | Every caller/internal job, runner instance, condition, environment, service, nested call, output, and step class is closed. |
| Permission and side-effect isolation | 22 | Caller and called levels author read-only permissions and no hidden job can gain credentials or external writes. |
| Graph/result/data-flow correctness | 18 | Qualified direct needs, results, outputs, matrix expansion, approval consumption, and skip behavior are exact. |
| Offline validator determinism | 14 | One validator compares parsed YAML to hand-authored hierarchical constants, not observed inventory. |
| Runtime-count evidence | 8 | Static declarations, expanded graph nodes, runner executions, skips, and API job evidence reconcile. |
| Maintenance clarity | 6 | T2 can extend the named internal job without accidentally adding another layer or job. |
| Scope/churn | 3 | The selected local reusable-workflow architecture remains intact. |

### Scoring

| Option | Authority surface (29) | Isolation (22) | Graph/data (18) | Validator (14) | Counts (8) | Maintenance (6) | Scope (3) | Total / 100 | Eligibility |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A. Hierarchical closed allowlist | 5 | 5 | 5 | 5 | 5 | 4 | 4 | **98.2** | Eligible |
| B. Inline Markdown job | 5 | 5 | 5 | 5 | 5 | 3 | 2 | 95.8 | Eligible but redesigns topology |
| C. Opaque commit-bound call | 2 | 2 | 3 | 2 | 3 | 5 | 5 | 50.6 | **Ineligible: internals remain policy-free** |
| D. Accept discovered internal jobs | 4 | 3 | 4 | 2 | 4 | 4 | 4 | 70.0 | **Ineligible: YAML defines its own allowlist** |
| E. Second validator | 5 | 4 | 4 | 4 | 4 | 2 | 2 | 82.2 | Eligible but fragments policy |
| F. Counts only | 2 | 2 | 2 | 3 | 4 | 5 | 5 | 51.4 | **Ineligible: substitutions preserve totals** |
| G. One implementation-defined job | 3 | 3 | 3 | 3 | 3 | 5 | 5 | 63.6 | **Ineligible: authority fields remain open** |

### Selected resolution

Select **Option A**. Extend the existing workflow-policy validator with a
two-level, hand-authored graph; do not discover and approve called jobs
dynamically.

The caller row is:

| Qualified job | Exact contract |
|---|---|
| `build::markdown` | `build.yml` job ID `markdown`; local `uses` exactly `./.github/workflows/markdownlint.yml`; permissions exactly `contents: read`; no direct needs or job condition; no `with`, secrets, `secrets: inherit`, outputs, strategy, concurrency, environment, or name override; and no ordinary-job-only keys such as `runs-on`, container, services, or steps. |

The called interface is exact:

- `markdownlint.yml` has only `on: workflow_call`;
- `workflow_call` declares no inputs, secrets, or outputs;
- there is no independent event, dispatch, schedule, environment, workflow
  concurrency, workflow env/default, or nested reusable call; and
- the local reference resolves from the same commit as `build.yml`, but the
  validator still parses and validates its content.

The sole called job row is:

| Qualified job | Direct needs / eligibility | Permission / runner / outputs | Permitted steps and side effects |
|---|---|---|---|
| `markdown::markdownlint` | none/absent; no job `if` (ordinary called-workflow eligibility) | exactly `contents: read`; `ubuntu-latest`; no outputs, strategy, concurrency, environment, container, services, or `continue-on-error` | Exact ordered roles: checkout; setup-node; Node assertion; frozen npm install; workflow-policy fixtures/real files; outer lint; nested lint; T1A helper/harness validation; final lint-result gate. Side effects are limited to transient authenticated read checkout with no persistence, Node/tool installation in the workspace, diagnostics, and test-owned cleanup. No cache, artifact, repository/ref, issue, deployment, package, or external publication write. |

The called job's checkout/setup roles use the exact existing T1/T1B action
pins and authored-input/default tables. `npm ci` is the sole package install and
must leave manifest/lock bytes unchanged. The two lint steps retain the
reviewed `continue-on-error: true` needed to collect both outcomes; every other
step has it absent/false, and the final gate fails if either lint outcome
failed. No step creates job/workflow output, writes `GITHUB_ENV` for the caller,
or accesses an undeclared secret. The job token exists but is bounded by
`contents: read`.

Publish and validate these separate count domains:

| Count domain | Exact nominal count |
|---|---:|
| Static job declarations in `build.yml` | 5 |
| Static internal job declarations in `markdownlint.yml` | 1 |
| Total static declarations across both files | 6 |
| Static reusable-workflow call edges | 1 |
| Nested reusable-workflow call edges | 0 |
| Expanded structural result nodes (five caller nodes, one called internal node, and three additional Windows matrix instances) | 9 |
| Runner-executing jobs when writer is ineligible/no-change | 7 |
| Runner-executing jobs when writer is eligible and changed | 8 |

The seven runner jobs are the one called Markdown job, `prepare`, four
`validate_windows` cells, and `approve`; `writer` is the eighth when eligible.
The `markdown` caller is a dependency/result node but has no runner of its own.
Skipped/failed/cancelled paths retain the same structural inventory while
their actual runner-start count and conclusions are recorded separately; they
do not redefine the allowlist.

`approve` directly needs qualified caller result `build::markdown` and requires
it to be `success`. The internal result rolls up through that exact local call;
no build job reads a nonpublic called-job output, and the called workflow
publishes none.

The validator rejects an added/renamed internal job, caller pointed at another
path, nested workflow, input/secret/output, permission drift at either level,
extra runner/matrix, service/container/environment, changed step order/owner/
condition/side effect, or any mismatch in the five/one/six/one/zero/nine
structural counts. Negative fixtures include an extra internal shell-only job
and an internal read-only job with no external action, proving action-role
counts alone cannot pass them. Retained run evidence maps each expected
qualified node to its conclusion/runner record and reconciles the applicable
seven/eight execution count.

T2 may add its permanent state-recovery harness as one new stable step in
`markdown::markdownlint` and atomically update the ordered step policy. It may
not create a second called job, output, permission, runner, or workflow layer.

## Finding 12 — T2's provider-identifier contract has no usable input map

### Problem

T2 calls its AWS/Azure/GCS snippets final while hard-coding the provider
location and reading only a selected version/generation variable. A later
normative table says bucket/account/container/object fields are validated and
passed byte-for-byte unchanged but gives several of them no variable names.
HCP similarly names host/page/token but not organization/workspace inputs.
A copier therefore cannot know which literals to edit, what validation they
must traverse, or whether discovery and recovery refer to identical objects.

The public map must make deliberate selection obvious without auto-reading a
backend or current version. Operators need copy-ready variables; security
reviewers need each byte validated before query/URI construction; harness
authors need one input-to-argv mapping; and documentation maintainers need one
final block per stable marker.

### Options and permutations considered

#### Option A — Exact provider-prefixed environment variables

Give every provider field one public environment variable. Each standalone
discovery/recovery block snapshots its required variables once into readonly
locals, applies the field-specific normative grammar, and uses only those
locals in quoted provider argv/query/URI construction. Discovery and recovery
share location-variable names; recovery additionally requires the selected
version/generation.

Provider-specific version names avoid generic `VERSION_ID` collisions when
operators compare providers. HCP receives explicit organization/workspace
names. Copy examples show placeholders outside the final marked block, so
placeholders cannot be mistaken for executable reviewed literals.

#### Option B — Keep reviewed hard-coded literals

State that bucket/key/account/container/blob/object values are intentional
repository literals outside runtime grammar and validate only selected version
variables. This is deterministic for one environment and avoids ambient input,
but a general style guide becomes unsafe to copy: users must edit several
command/query occurrences consistently, and the harness cannot verify one
public source flowed unchanged to all occurrences.

#### Option C — Wrap each block in a function with positional arguments

Accept location/version/destination as function arguments. This can preserve
bytes and avoid environment collisions, but long positional sequences are easy
to swap, function definitions obscure the standalone copy flow, and discovery
and recovery invocations need a separately documented ordered map. Named
options would require a parser as complex as the environment map.

#### Option D — Prompt interactively with `read -r`

Ask for each identifier/version at runtime. This encourages deliberate
selection but breaks noninteractive validation/automation, risks terminal
echo/history handling, and still needs exact variable names and grammars after
input. Piped input changes the trust surface.

#### Option E — Read a provider configuration file

Use a protected env/JSON/YAML file shared by discovery and recovery. This
centralizes values but adds file ownership/mode/link/parser/duplicate-key/
encoding/cleanup requirements and can accidentally mix credentials with safe
identifiers. It is excessive for a handful of shell strings.

#### Option F — Derive identifiers from Terraform backend configuration

Parse `.terraform`, HCL, `terraform init` output, or state metadata to discover
location fields. This can reduce typing but reads sensitive/generated state,
requires an HCL/backend parser, may select a different workspace/configuration,
and violates deliberate explicit version/location selection.

#### Option G — Permit environment variables with hard-coded fallbacks

Use `${VAR:-example}` so examples run with no setup. This creates two input
sources, silently targets demonstration infrastructure after a misspelling or
empty value, and makes validation/argv evidence conditional. Missing values
must fail, not select a default.

### Finding-specific weighted rubric

Scores use 1–5. An option is ineligible if any provider argv/query field can
come from an undocumented or ambiguous source, or if a missing input silently
selects a target/version.

| Criterion | Weight | What a score of 5 requires for this finding |
|---|---:|---|
| Copy/operator usability and explicitness | 25 | One table tells a cold reader exactly what to set for each provider/operation and missing values fail clearly. |
| Byte-preserving input-to-argv integrity | 24 | Each raw value is snapshotted once, validated, never normalized, and appears unchanged in the exact intended argument/query. |
| Security/validation closure | 18 | Every location, version, host, page, token, and destination field reaches its own ordered closed grammar before side effects/logging. |
| Discovery/recovery identity consistency | 14 | Both blocks consume the same named location fields and only recovery adds deliberate version selection. |
| Harness oracle quality | 9 | Stubs can assert one exact environment-to-local-to-argv mapping plus atomic missing/invalid/boundary cases. |
| Provider/documentation clarity | 7 | Names are collision-resistant, semantically accurate, and one final block owns each marker. |
| Churn/implementation effort | 3 | The fix uses ordinary Bash variables without a new parser or credential store. |

### Scoring

| Option | Usability (25) | Byte integrity (24) | Validation (18) | Pair consistency (14) | Harness (9) | Clarity (7) | Effort (3) | Total / 100 | Eligibility |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A. Provider-prefixed environment map | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.4** | Eligible |
| B. Reviewed hard-coded literals | 2 | 5 | 5 | 5 | 4 | 2 | 5 | 79.0 | Eligible but not reusable |
| C. Function arguments | 4 | 5 | 5 | 4 | 4 | 4 | 3 | 87.8 | Eligible |
| D. Interactive prompts | 3 | 4 | 4 | 3 | 2 | 3 | 3 | 66.6 | Eligible but nonautomatable |
| E. Protected config file | 3 | 4 | 3 | 4 | 3 | 3 | 2 | 67.0 | Eligible after new file trust contract |
| F. Backend derivation | 2 | 2 | 2 | 3 | 2 | 2 | 1 | 42.2 | **Ineligible: selection is not deliberate/closed** |
| G. Environment plus fallback | 3 | 3 | 3 | 2 | 2 | 2 | 4 | 55.0 | **Ineligible: missing input selects a target** |

### Selected resolution

Select **Option A** and replace every hard-coded “final” provider location with
this closed public map:

| Provider/field | Exact environment input | Discovery | Recovery/API | Exact supported subset |
|---|---|---:|---:|---|
| AWS bucket | `AWS_S3_BUCKET` | required | required | Existing 3–63 lowercase alphanumeric/hyphen subset; alphanumeric endpoints; no `--`/reserved form |
| AWS object key | `AWS_S3_KEY` | required | required | Existing 1–1024-byte nonempty safe-segment grammar |
| AWS selected version | `AWS_S3_VERSION_ID` | absent | required | Existing 1–1024-byte safe version grammar; literal `null` allowed |
| Azure account | `AZURE_STORAGE_ACCOUNT` | required | required | Existing 3–24 lowercase ASCII alphanumeric subset |
| Azure container | `AZURE_STORAGE_CONTAINER` | required | required | Existing 3–63 lowercase alphanumeric/hyphen subset |
| Azure blob | `AZURE_STORAGE_BLOB` | required | required | Existing 1–1024-byte nonempty safe-segment grammar |
| Azure selected version | `AZURE_STORAGE_VERSION_ID` | absent | required | Existing 1–128-byte `[A-Za-z0-9._~:+%-]+` subset |
| GCS bucket | `GCS_BUCKET` | required | required | Existing 3–63 lowercase alphanumeric/hyphen subset |
| GCS object | `GCS_OBJECT` | required | required | Existing 1–1024-byte nonempty safe-segment grammar |
| GCS selected generation | `GCS_GENERATION` | absent | required | `[1-9][0-9]{0,19}` |
| HCP hostname | `TFC_HOST` | n/a | required | exactly `app.terraform.io` or `app.eu.terraform.io` |
| HCP organization | `TFC_ORGANIZATION` | n/a | required | `[A-Za-z0-9][A-Za-z0-9_-]{0,63}` |
| HCP workspace | `TFC_WORKSPACE` | n/a | required | same 1–64-byte subset |
| HCP page | `TFC_PAGE_NUMBER` | n/a | required | `[1-9][0-9]{0,19}` |
| HCP bearer token | `TFC_TOKEN` | n/a | required secret | Existing nonempty token grammar excluding quote, backslash, CR/LF/control |

AWS/Azure/GCS recovery also requires exactly `RECOVERY_PARENT`,
`RECOVERY_PATH`, and `RECOVERY_PARENT_ATTESTATION`; HCP requires exactly
`TFC_RESPONSE_PARENT`, `TFC_RESPONSE_PATH`, and
`TFC_RESPONSE_PARENT_ATTESTATION`. Those destination/attestation fields retain
their separate filesystem grammar and are not provider identifiers. CLI/cloud
credentials retain the provider's documented ambient authentication model and
are never repurposed as location inputs.

Each marked block is a standalone Bash subshell. Before validation or
filesystem/provider work, it sets `LC_ALL=C`, reads every applicable public
environment variable exactly once with the `${NAME-}` form into a uniquely
provider-prefixed local (for example `aws_s3_bucket`, `azure_storage_blob`, or
`gcs_generation`), marks locals readonly, and unsets the copied public names
inside the subshell. HCP executes `set +x` before its first secret expansion.
No code later rereads an ambient input, uses indirect expansion, accepts an
alias, or chooses a default.

Validation uses only the locals in the issue's exact ordered byte grammar.
Unset and empty both fail the field's `input-missing-or-empty` case before any
command; type is necessarily an environment string, while NUL remains
unrepresentable at the POSIX environment boundary. Control/non-ASCII/
whitespace/length/shape cases are separate. Do not trim, case-fold,
percent-decode, normalize, perform shell arithmetic, or rewrite an accepted
identifier.

Provider construction is exact:

- AWS discovery passes `--bucket "$aws_s3_bucket"` and
  `--prefix "$aws_s3_key"` and embeds the unchanged safe key once in the exact
  equality query; recovery passes those two locals plus
  `--version-id "$aws_s3_version_id"`.
- Azure discovery/recovery pass the account/container/blob locals to
  `--account-name`, `--container-name`, and `--prefix`/`--name`; discovery's
  equality query contains the same unchanged safe blob; recovery passes
  `--version-id "$azure_storage_version_id"`.
- GCS discovery constructs exactly
  `gs://${gcs_bucket}/${gcs_object}`; recovery constructs exactly that URI plus
  `#${gcs_generation}`. The delimiters are added only after the field
  grammars prohibit delimiter ambiguity.
- HCP supplies organization/workspace/status/page fields only through separate
  `curl --data-urlencode` arguments, constructs the URL from the validated host,
  and writes the validated token only to the protected curl config.

The harness records redacted field name, accepted byte length/SHA-256, and the
stub's NUL-safe argv. It requires the provider-location locals/bytes to match
between discovery and recovery and the selected version to appear only in
recovery. One atomic case covers each missing/empty/control/ASCII/endpoint/
length/metacharacter boundary and one valid sentinel proves byte-for-byte
preservation through query or URI construction.

The issue must publish exactly one executable final block inside each of the
seven `SR-*` marker pairs. Remove the shorter hard-coded blocks and the later
“supersedes” clause. Immediately before each block, a copy table shows only the
applicable `export NAME='replace-with-…'` placeholders and instructs the
operator to run discovery first, inspect its empty/nonempty result, and set the
version/generation deliberately before recovery. No placeholder, “latest,”
live-version query, or hard-coded demonstration target appears inside a marked
block.

## Finding 13 — T2 destination-leaf and cleanup algorithms are not closed

### Problem to resolve

The T2 recovery contract currently treats “nonempty direct-child leaf” as
sufficient. That allows control bytes, newline bytes, leading option-like text,
and locale-dependent characters into paths and diagnostics even though those
bytes have no relationship to a provider identifier’s validity. The same
contract installs an `EXIT` cleanup handler while `errexit` remains active. A
cleanup-internal failure can consequently stop later inspection and removal
decisions and can replace the primary command’s status. This finding needs one
closed answer for both the public destination leaf and every cleanup outcome.

### Exhaustive option and permutation inventory

The meaningful path-leaf choices are:

1. Define a deliberately narrow repository-owned ASCII leaf grammar and reject
   every other byte before filesystem use.
2. Accept the full POSIX filename byte space other than NUL and slash, but
   introduce a lossless encoding for every diagnostic, evidence field, and
   comparison.
3. Remove the caller-selected leaf and generate a fixed or random leaf
   internally.
4. Normalize or sanitize a caller leaf into an accepted leaf.
5. Reuse each provider’s identifier grammar as the destination-leaf grammar.

Option 5 is ineligible: cloud object keys, blob names, workspace names, and
local path components are different domains, and the same local recovery path
must have provider-independent behavior. Option 4 is also ineligible because
normalization can create collisions and means the bytes written are not the
bytes the operator selected.

The meaningful cleanup-control choices are:

1. Capture the primary status, disable `errexit`, and implement cleanup as a
   closed state machine in which every fallible operation is inside an explicit
   status branch.
2. Keep `errexit` and append `||` guards to selected cleanup commands.
3. Move cleanup to a separate helper process or tracked script.
4. Use recursive removal and rely on recovery-root validation as the safety
   boundary.
5. Make cleanup best-effort and always return the primary status.

Recursive removal is ineligible because an inspection error or reoccupation
must never expand the deletion set. Always returning the primary status is
ineligible because cleanup failure after a successful primary operation would
be silently reported as success. The viable combined candidates are therefore:

- **A — narrow leaf plus in-process closed cleanup state machine.**
- **B — broad POSIX leaf plus lossless encoding plus the same closed cleanup
  state machine.**
- **C — internally generated leaf plus the same closed cleanup state machine.**
- **D — sanitized leaf plus a partially guarded cleanup.**
- **E — narrow leaf plus an external cleanup helper.**
- **F — narrow leaf plus `errexit` and scattered `||` guards.**
- **G — narrow leaf plus recursive best-effort cleanup.**

The relevant stakeholder perspectives are:

- Operators need a recovery destination that is easy to choose, reproduce,
  quote, and locate.
- Incident responders need diagnostics that cannot be forged into multiple
  lines and a retained artifact whenever ownership is uncertain.
- Maintainers need shell control flow whose result does not depend on subtle
  `errexit` contexts.
- Security reviewers need the deletion set to stay at one exact owned ordinary
  file and one exact empty directory.
- Test authors need fixtures for every status branch, including diagnostic and
  enumeration failures.
- Provider users need path rules that do not change when the selected state
  provider changes.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| Filesystem and diagnostic byte safety | 23 | Untrusted leaf bytes must not become control flow, options, or forged evidence. |
| Primary-status and cleanup-status correctness | 25 | Cleanup must neither mask a failure nor report a damaged successful run as success. |
| Retention under uncertainty | 19 | Failed inspection must never authorize deletion. |
| Signal and strict-mode robustness | 14 | The handler must finish despite `errexit`, `nounset`, and a second signal. |
| Operator usability | 8 | A cold reader must be able to choose and recover a destination predictably. |
| Fixtureability and auditability | 8 | Every outcome must map to an executable test and stable evidence. |
| Scope and implementation churn | 3 | Smaller change is useful only after correctness is satisfied. |

### Scoring

| Candidate | Byte safety (23) | Status (25) | Uncertainty (19) | Robustness (14) | Usability (8) | Tests (8) | Churn (3) | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — narrow leaf, closed in-process state machine | 5 | 5 | 5 | 5 | 4 | 5 | 3 | **97.2** |
| B — broad leaf, encoded everywhere | 4 | 5 | 5 | 5 | 2 | 4 | 2 | 87.2 |
| C — generated leaf, closed state machine | 5 | 5 | 5 | 5 | 2 | 4 | 2 | 91.8 |
| D — sanitized leaf, partial guards | 3 | 4 | 4 | 4 | 4 | 3 | 4 | 73.8 |
| E — narrow leaf, external helper | 5 | 5 | 5 | 4 | 2 | 4 | 1 | 88.4 |
| F — narrow leaf, scattered guards under `errexit` | 3 | 2 | 3 | 2 | 4 | 2 | 5 | 53.4 |
| G — narrow leaf, recursive best effort | 1 | 2 | 1 | 3 | 4 | 3 | 5 | 41.0 |

### Selected resolution: A — narrow leaf plus a closed in-process cleanup state machine

T2 will define one public destination-leaf rule used by `RECOVERY_PATH` and
`TFC_RESPONSE_PATH`, independent of the selected provider. Set `LC_ALL=C`; the
leaf is 1–128 bytes and must match:

```text
[A-Za-z0-9][A-Za-z0-9._-]{0,127}
```

The full destination must already satisfy the issue’s absolute-path and
direct-child requirements. Derive the leaf only after proving the destination
has the exact form `"$recovery_parent/$leaf"` with one nonempty component after
the parent. Reject slash, leading `-` or `.`, `.` and `..`, whitespace, control
bytes, newline, non-ASCII bytes, and a length outside 1–128. Provider bucket,
key, account, container, blob, object, organization, and workspace validation
remains separate and cannot weaken or strengthen this filesystem rule.

No diagnostic may contain raw unvalidated path text. When a validated or
retained path must be shown, render it first with:

```bash
LC_ALL=C printf -v rendered_path '%q' -- "$path"
```

and print `rendered_path` through a fixed format string. A failed diagnostic
write is a cleanup failure and is not allowed to abort later cleanup.

The executable marked block will implement cleanup with this ordering:

1. Install traps only after every cleanup variable and ownership flag has an
   explicit initial value.
2. On HUP, INT, or TERM, record only the conventional status (`129`, `130`, or
   `143`) and transfer control to the single `EXIT` cleanup owner. Ignore later
   HUP/INT/TERM signals once final cleanup begins.
3. In `cleanup_recovery`, expand and store `$?` in `primary_status` before any
   other expansion or command.
4. Immediately run `set +e`, followed by `set +u`; clear the `EXIT` trap and
   install ignored signal traps. Each trap operation’s status is classified.
5. Maintain `cleanup_status=0`, an ownership/lifecycle state, and an explicit
   `inspection_complete=false`. No deletion branch is reachable until every
   relevant inspection succeeded.
6. Enumerate the recovery root with a waited producer: open a dynamic
   descriptor from
   `find -- "$root" -mindepth 1 -maxdepth 1 -print0`, save `$!`, read
   NUL-delimited entries, close the descriptor, and explicitly classify
   `wait "$producer_pid"`. A failed open, read, close, producer wait, type
   check, or ownership check sets `cleanup_status=1`, retains the entire root,
   and authorizes no unlink.
7. Permit `rm -- "$exact_owned_partial"` only when the inventory contains
   exactly that path, it is a non-symlink ordinary file, and the lifecycle state
   says this invocation created it but did not publish it. Classify success and
   failure explicitly.
8. Permit `rmdir -- "$exact_root"` only after successful inspection and only
   after the owned partial was removed successfully or the root was proven
   empty. Never use recursive removal. A nonempty, unreadable, reoccupied,
   symlinked, or otherwise uncertain root is retained.
9. Put every fallible diagnostic, descriptor operation, `find`, `wait`, `rm`,
   and `rmdir` in an `if`/`else` branch or capture its status immediately. There
   are no unclassified bare cleanup commands whose failure can decide control
   flow.
10. Exit with `primary_status` when it is nonzero. Otherwise exit `1` when any
    cleanup classification failed. Otherwise exit `0`.

The fixture matrix will cover all grammar boundaries; a newline/control-byte
leaf; leading dot and dash; non-ASCII bytes under `LC_ALL=C`; a diagnostic
write failure; `find`, descriptor, and `wait` failure; owned-partial unlink
success/failure; empty-root `rmdir` success/failure; unknown entry, symlink,
dangling symlink, and unreadable root retention; primary nonzero plus cleanup
failure; primary zero plus cleanup failure; and a second signal during cleanup.
Each case asserts the selected final status, exact remaining filesystem
identities, and stable reason code. This makes cleanup behavior executable
rather than relying on prose such as “best effort.”

## Finding 14 — T2 provider lifecycle rows use disjunctive oracles

### Problem to resolve

Each provider’s `*-PART-06` row currently joins two different executions with
“or”: a destination that already exists at preflight, and a destination that a
competitor creates immediately before publication. The first execution invokes
neither `mktemp` nor the provider and creates no private root. The second
invokes the provider, validates a temporary file, attempts no-replace
publication, and retains the validated temporary/root. A machine-readable row
cannot have both call counts and both filesystem postconditions as its one
oracle.

### Exhaustive option and permutation inventory

The available approaches are:

1. Narrow each existing `*-PART-06` to the preexisting-final setup and append
   one `*-PART-07` publication-race row for each provider.
2. Keep one row and put two named subcases or conditional expected values in
   its oracle.
3. Change implementation so preexisting and racing destinations execute the
   same provider/publication path and therefore have one postcondition.
4. Remove preflight so every conflict is observed only at publication.
5. Keep provider-specific preexisting rows but use one provider-neutral shared
   race row.
6. Replace or rename `*-PART-06` with two suffix IDs such as `*-PART-06A` and
   `*-PART-06B`.
7. Delete the race case and treat no-competing-writers attestation as sufficient.

Option 7 is ineligible because the issue explicitly says preflight is not an
atomic filesystem lock and requires no-replace publication. Options 3 and 4
are ineligible because they knowingly perform a sensitive provider download
after an already-detectable destination conflict. Option 2 remains
machine-executable only by hiding two cases inside one row, which preserves the
defect rather than resolving it.

Stakeholder perspectives:

- Harness maintainers need one setup, call count, status, diagnostic, and
  filesystem oracle per stable ID.
- Provider users need AWS, Azure, and GCS behavior to remain independently
  visible.
- Security reviewers need proof that preflight avoids a provider call and that
  no-replace publication preserves a racing final.
- Incident responders need the race case to retain the exact validated
  temporary state rather than erase possible recovery evidence.
- Issue maintainers need the append-only stable-ID promise preserved.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| One exact oracle per ID | 30 | The finding is fundamentally an atomic-case defect. |
| Preflight/race boundary coverage | 22 | Both sides of the no-replace boundary must be exercised. |
| Sensitive-state safety postconditions | 18 | Existing finals remain unchanged and uncertain validated state is retained. |
| Append-only ID compatibility | 12 | Existing evidence and future audits depend on stable identifiers. |
| Exact provider/publication call evidence | 10 | Zero versus one provider call is the key observable difference. |
| Cold-reader clarity | 5 | A row must be understandable without reconstructing shell control flow. |
| Scope and churn | 3 | A small table/harness expansion is preferable after correctness. |

### Scoring

| Option | Atomicity (30) | Boundary (22) | Safety (18) | IDs (12) | Calls (10) | Clarity (5) | Churn (3) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Preserve `06`, append provider-specific `07` | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.4** |
| B. One row with conditional subcases | 2 | 4 | 4 | 5 | 3 | 2 | 5 | 67.0 |
| C. Force both executions through one lifecycle | 3 | 3 | 2 | 3 | 4 | 3 | 2 | 57.8 |
| D. Remove preflight | 4 | 3 | 2 | 2 | 4 | 3 | 4 | 62.6 |
| E. One provider-neutral race row | 4 | 5 | 5 | 4 | 3 | 4 | 3 | 85.4 |
| F. Replace `06` with suffix IDs | 5 | 5 | 5 | 1 | 5 | 5 | 2 | 88.6 |

### Selected resolution: preserve `06` and append provider-specific `07`

Keep all existing IDs. Narrow these rows to one preflight execution:

- `AWS-PART-06`
- `AZURE-PART-06`
- `GCS-PART-06`

For each, setup places an ordinary non-link sentinel at the exact final path
before the block starts. The exact oracle is: exit `1`; stable reason
`destination-preexisting`; provider call count `0`; `mktemp`/private-root count
`0`; publication call count `0`; final path has the same file identity, bytes,
mode, and modification time as its setup sentinel; no private root or temporary
exists; and every outside sentinel is unchanged.

Append:

- `AWS-PART-07`
- `AZURE-PART-07`
- `GCS-PART-07`

For each `07`, preflight observes an absent final. The provider stub is invoked
exactly once with that row’s exact selected version and writes one valid state
to the exact private temporary path. The Terraform validator succeeds. A
harness-owned `ln` wrapper then creates an ordinary competing-final sentinel
immediately before delegating the block’s unchanged
`ln --no-target-directory -- "$recovery_temp" "$recovery_path"` call to the
real GNU `ln`. The real call must fail without replacing the competitor.

The exact `07` oracle is: exit `1`; stable reason `publication-race`; provider
call count `1`; validation call count `1`; publication call count `1`;
competing final retains its original identity, bytes, mode, and modification
time; the private root remains; that root contains exactly one validated
ordinary non-link temporary state at the journaled path; the temporary and
final have different identities and bytes; no cleanup unlink or `rmdir`
succeeds; and every outside sentinel is unchanged. The wrapper records NUL-safe
argv and the harness confirms the delegated real GNU `ln` returned nonzero.

All 21 provider lifecycle rows remain provider-specific, append-only, and
atomic. Shared fixture functions may build the two setups, but no expected
field may contain an alternative, wildcard, “provider skipped or,” or
provider-dependent branch. The harness continues to reject a missing,
duplicate, unexpected, or multiply emitted ID.

## Finding 15 — T2 sensitive temporary/final identity is weaker than T4

### Problem to resolve

T2 currently assumes `umask 077` is enough and checks only that provider output
is nonempty, ordinary, non-link, and byte-equal after publication. A provider
can replace its destination with an inode having the wrong owner or mode, or
with an inode that already has another hard link. Hard-link publication
preserves those properties. T4 later defines the necessary POSIX identity
sequence for equally sensitive state, so T2 must establish the common
foundation its successor consumes.

### Exhaustive option and permutation inventory

The meaningful implementation choices are:

1. Capture a numeric `stat` identity tuple at each phase and require owner,
   exact mode, same device, inode continuity, and exact link counts.
2. Repair provider output with `chown`/`chmod` and then continue publication.
3. Check only owner and mode, leaving device/inode/link count implicit.
4. Copy provider output into a second shell-created mode-`0600` file and
   publish the copy.
5. Trust `umask`, ordinary-file type, and byte comparison as currently written.
6. Defer the checks to T4 because T2 is “only” recovery.
7. Compare only file bytes or digest before and after publication.

The phase permutations that must be represented are:

- AWS, Azure, and GCS provider temporary before validation;
- both names immediately after no-replace hard-link publication;
- final alone after temporary unlink;
- publication failure with a validated retained temporary;
- invalid candidate whose exact single-link ownership is still sufficient for
  cleanup;
- owner/device/link identity uncertainty that prohibits cleanup; and
- HCP response immediately after noclobber acquisition and after curl/close.

Repair is not selected because it hides a provider or fixture that violated the
creation contract, and `chown` is neither generally authorized nor appropriate
for an unexpected owner. Copying creates a second sensitive-data lifecycle and
no longer publishes the exact validated provider inode. Byte equality alone
cannot reveal an undisclosed hard link.

Stakeholder perspectives:

- Operators need a final recovery file that is private and is exactly the
  validated object, not merely an equal copy at one instant.
- Security reviewers need proof that no preexisting hard link exposes state
  through another name.
- Incident responders need ambiguous ownership retained and precisely
  diagnosed.
- T4 implementers need one inherited POSIX identity contract instead of a
  subtly stronger parallel version.
- Harness authors need real mode, owner, inode, device, and hard-link fixtures
  with exact phase postconditions.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| Identity completeness | 28 | Device/inode/owner/mode/link count jointly define the sensitive file being trusted. |
| Confidentiality and access-control assurance | 22 | Mode and undisclosed links directly affect who can read state. |
| Publication continuity | 20 | The validated temporary and final must be the same inode through unlink. |
| Cleanup safety under uncertainty | 12 | Rejection must not authorize deletion of an object with unclear ownership. |
| Executable fixture quality | 10 | Every phase and negative property needs a stable observable oracle. |
| T4 consistency | 5 | T4 should consume, not reinvent, the common POSIX contract. |
| Scope and churn | 3 | Added checks should remain local to the existing Bash lifecycle. |

### Scoring

| Option | Identity (28) | Confidentiality (22) | Continuity (20) | Cleanup (12) | Fixtures (10) | T4 (5) | Churn (3) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Exact `stat` tuple at every boundary | 5 | 5 | 5 | 5 | 4 | 5 | 3 | **96.8** |
| B. Repair with `chown`/`chmod` | 4 | 3 | 4 | 3 | 4 | 3 | 4 | 72.2 |
| C. Owner/mode only | 2 | 3 | 2 | 2 | 3 | 2 | 5 | 48.2 |
| D. Copy into a second private file | 5 | 5 | 4 | 4 | 3 | 4 | 1 | 86.2 |
| E. Trust `umask` and current checks | 1 | 2 | 1 | 2 | 3 | 1 | 5 | 33.2 |
| F. Defer entirely to T4 | 1 | 1 | 1 | 1 | 1 | 1 | 5 | 22.4 |
| G. Byte/digest comparison only | 2 | 2 | 3 | 2 | 3 | 2 | 4 | 47.2 |

### Selected resolution: exact numeric identity at every boundary

T2 will define a shared POSIX state-file identity record:

```text
device:inode:owner_uid:mode_octal:link_count:size
```

With `LC_ALL=C`, obtain it from one fixed
`stat -c '%d:%i:%u:%a:%h:%s' -- "$path"` call with native stderr suppressed.
Reject a nonzero status, extra/missing output, or anything other than six
canonical nonnegative decimal fields plus the octal mode field. Separately
require `-f "$path"` and `! -L "$path"` before trusting the tuple. Resolve the
effective UID once with `id -u` and the protected-parent device once with
`stat -c '%d'`; both outputs have the same closed numeric parsing. Diagnostics
contain stable reason codes and encoded paths, never raw state or native error
text.

For AWS, Azure, and GCS, after provider success and before Terraform validation
or publication, require:

- one exact journaled ordinary non-link temporary;
- owner UID equal to the effective UID;
- mode exactly `600`;
- device equal to the protected parent and private root;
- link count exactly `1`; and
- nonzero size.

Store its `(device,inode)` as `candidate_identity`. After the single real
no-replace `ln` succeeds, snapshot both names and require both are ordinary
non-links with the same `candidate_identity`, effective owner, mode `600`,
equal size, and link count exactly `2`. Require `cmp -- temp final` success.
Only then unlink the exact temporary. Reopen/snapshot the final and require the
same identity, owner, mode, size, parent device, and link count exactly `1`
before removing the empty private root and reporting success.

Publication-eligibility and cleanup-ownership predicates remain distinct:

- Wrong mode fails publication. If the exact journaled path is still an
  ordinary non-link with effective owner, parent device, and link count `1`,
  cleanup may remove it as a proven owned invalid partial.
- Wrong owner, different device, link count other than `1`, inode substitution,
  failed/unparseable inspection, or an additional entry is
  `candidate-identity-uncertain`; cleanup retains the entire private root and
  performs no unlink.
- Any mismatch after publication is `publication-identity-uncertain`; keep both
  names and the root. Do not attempt to guess which name is safe to unlink.
- A supported publication failure keeps the final absent and retains the
  already validated, strict-identity temporary as specified by the race and
  unsupported-publication cases.

For HCP, snapshot the response immediately after the noclobber descriptor is
acquired and again after curl exits and the descriptor closes. Both snapshots
must name the same `(device,inode)`, effective UID, mode `600`, response-parent
device, and link count `1`; the success response must also be nonempty. HCP has
no hard-link publication sequence and retains the exact response on
curl/content/identity failure under its existing sensitive-evidence rule.

Append atomic AWS/Azure/GCS cases for wrong mode, wrong owner, initial link
count `2`, device mismatch/inspection failure, post-link unequal identity or
link count, and post-unlink link count not `1`. Append HCP acquisition and
post-curl cases for wrong mode, wrong owner, extra link, inode substitution,
and inspection failure. Positive rows assert the exact tuple at every phase.
The hosted Ubuntu harness exercises real GNU `stat`/`ln`; owner-negative setup
uses a declared noninteractive privileged fixture step only to arrange the
foreign UID, never in production code. Every row has one status, reason, tuple,
call count, and final/temp/root postcondition.

## Finding 16 — T3 Husky installation identity is underspecified

### Problem to resolve

T3 currently calls `.husky/pre-commit` an “exact ordinary versioned hook” and
requires “every required shim,” but defines neither identity. It also says the
installer invokes project-pinned Husky without naming the command or package
entry point. The tracked repository hook and Husky’s ignored generated
`.husky/_` integration have different ownership and lifecycle rules; grouping
them into “missing/linked/untracked shim/hook” gives no implementable oracle.

### Exhaustive option and permutation inventory

The meaningful installation designs are:

1. Commit a closed install-contract manifest; invoke one verified local Husky
   CLI entry point; verify the tracked hook and generated inventory under
   separate schemas.
2. Derive all expected identities dynamically from whatever lock-resolved
   package is present and retain no reviewed manifest.
3. Run `corepack npm exec husky` or an npm script and verify only
   `core.hooksPath` plus a few representative shims.
4. Import the package API directly and verify only successful return plus
   selected outputs.
5. Treat a successful real `git commit` as sufficient without inspecting
   package, hook, or generated identities.
6. Add `.husky/_` to Git and make every generated shim tracked.
7. Replace Husky with a repository-owned wrapper while leaving the Husky
   dependency installed.

The state permutations are independent and must not be grouped:

- required install versus each single authorized skip source;
- no skip source versus one source versus multiple/conflicting sources;
- package absent, wrong version/integrity, linked/substituted package component,
  wrong binary mapping, spawn failure, and nonzero Husky exit;
- root and `core.hooksPath` mismatch;
- tracked hook absent, untracked, wrong Git mode, wrong type/link, wrong marker,
  and wrong bytes;
- generated directory absent/link, generated entry missing/extra, wrong
  type/link, wrong bytes, and wrong POSIX executable mode; and
- direct hook invocation versus an actual `git commit` reaching the installed
  wrapper.

Tracking `.husky/_` is ineligible because those files are package-generated and
ignored by Husky’s own installation. A real commit is necessary behavioral
proof but cannot reveal that a substituted package or incomplete shim set
happens to work on one platform.

Stakeholder perspectives:

- Contributors need deterministic install or an explicit, truthful skip.
- Supply-chain reviewers need the exact package entry point and bytes that ran.
- Hook maintainers need the tracked script versioned independently from
  generated Husky internals.
- Windows and POSIX users need cross-platform file/type checks plus real Git
  execution.
- Future upgrade authors need one manifest diff that exposes every changed
  package, hook-schema, or generated-file identity.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| Pinned package and invocation identity | 24 | The installer must not execute an ambient or substituted Husky. |
| Tracked-hook identity closure | 22 | The repository-owned hook needs a version, Git identity, and byte contract. |
| Generated inventory closure | 20 | Every ignored runtime shim/support file must be expected and verified. |
| Cross-platform real-Git behavior | 14 | Static identity still must result in Git invoking the hook. |
| Atomic state diagnostics | 10 | Each installer failure/skip state needs one exact oracle. |
| Upgrade maintainability | 7 | A package upgrade should produce one reviewable contract change. |
| Scope and churn | 3 | The mechanism should remain within the npm/hook surface. |

### Scoring

| Option | Invocation (24) | Hook (22) | Generated (20) | Real Git (14) | Atomicity (10) | Upgrade (7) | Churn (3) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Reviewed contract, exact local CLI, separate schemas | 5 | 5 | 5 | 5 | 5 | 4 | 2 | **96.8** |
| B. Dynamic package-derived expectations | 4 | 4 | 4 | 4 | 4 | 4 | 3 | 79.4 |
| C. `npm exec` plus representative shims | 3 | 4 | 3 | 4 | 3 | 4 | 4 | 69.2 |
| D. Package API plus representative outputs | 4 | 4 | 3 | 3 | 3 | 3 | 4 | 69.8 |
| E. Real commit only | 2 | 2 | 2 | 5 | 2 | 5 | 5 | 54.4 |
| F. Track generated `_` directory | 4 | 5 | 5 | 4 | 4 | 1 | 1 | 82.4 |
| G. Repository wrapper beside Husky | 3 | 4 | 3 | 3 | 3 | 3 | 2 | 63.8 |

### Selected resolution: reviewed contract and exact local CLI

Add `.github/workflows/husky-install-contract.json` to T3’s required files.
It is strict JSON with schema `TerraformStyleGuide.HuskyInstallContract.v1`,
closed keys, no BOM, LF only, duplicate-key rejection, and these sections:

- exact package name `husky`, version `9.1.7`, lockfile SHA-512 integrity,
  package relative root, binary mapping `husky: bin.js`, and reviewed SHA-256
  plus byte length for `package.json`, `bin.js`, `index.js`, and `husky`;
- tracked hook path `.husky/pre-commit`, Git mode `100644`, marker
  `# terraform-style-guide-hook-schema: 1`, exact marker line `2`, final byte
  length, and final SHA-256;
- generated root `.husky/_`, expected `core.hooksPath` value `.husky/_`, and an
  exact 17-entry file array with relative path, role, length, SHA-256, and POSIX
  executable expectation; and
- installer contract version `Install-Husky.v1`.

The implementation resolves the tracked hook’s final length and SHA-256 only
after its behavior is complete, then commits that exact value in the manifest.
The installer rejects any manifest/package/lock/root disagreement; it never
updates the contract itself.

Set `.github/workflows/package.json` to exact dependency
`"husky": "9.1.7"` and exact lifecycle
`"prepare": "node Install-Husky.mjs"`. The lock entry must be exactly version
`9.1.7`, tarball
`https://registry.npmjs.org/husky/-/husky-9.1.7.tgz`, integrity
`sha512-5gs5ytaNjBrh5Ow3zrvdUUY+0VxIuWVL4i9irt6friV+BqdCfmV11CQTWMiBYWHbXhco+J1kHfTOUkePhCDvMA==`,
and binary `husky: bin.js`. T3’s implementation-time package research must
reconfirm this release identity; any new release is a reviewed issue/manifest
change, not an automatic substitution.

`Install-Husky.mjs` resolves its own directory from `import.meta.url`, derives
the repository root as exactly two parents, and proves that root with Git before
reading or changing install state. In required mode it:

1. parses the contract with duplicate-key and closed-schema enforcement;
2. proves the package root and each executable package component is an ordinary
   non-link under `.github/workflows/node_modules/husky`;
3. proves package manifest, root dependency, lock version/integrity/bin mapping,
   byte lengths, and hashes equal the contract;
4. spawns exactly `process.execPath` with the verified absolute
   `node_modules/husky/bin.js`, no arguments, `cwd` equal to the repository
   root, `shell:false`, and bounded captured stdout/stderr;
5. requires native exit `0`;
6. reads local Git config as raw bytes and requires exactly one
   `core.hooksPath` value equal to `.husky/_`; and
7. verifies the tracked and generated schemas below before reporting
   `installed`.

There is no `npx`, PATH-resolved `husky`, `npm exec`, shell command string,
download, `init`, or API import. The CLI runs only as the prepare lifecycle of
the project’s exact Corepack npm installation, and the installer verifies the
exact local files it executes.

The tracked-hook schema is independent:

- `.husky/pre-commit` is exactly one Git-tracked stage-0 blob with Git mode
  `100644`, never an ignored/untracked/submodule/symlink entry;
- its working object is one ordinary non-link file;
- bytes are LF-only, BOM-less, and contain the schema marker exactly once as
  physical line 2 immediately after `#!/bin/sh`;
- byte length and SHA-256 equal the contract; and
- installer verification never writes this file.

The generated schema requires ordinary non-link `.husky` and `.husky/_`
directories and exactly these 17 ordinary non-link files—no missing or extra
entry:

- support: `.gitignore`, `h`, `husky.sh`;
- shims: `applypatch-msg`, `commit-msg`, `post-applypatch`, `post-checkout`,
  `post-commit`, `post-merge`, `post-rewrite`, `pre-applypatch`, `pre-auto-gc`,
  `pre-commit`, `pre-merge-commit`, `pre-push`, `pre-rebase`,
  `prepare-commit-msg`.

The manifest records each byte identity. For 9.1.7, every shim is the exact
39-byte package-generated body with SHA-256
`34fe496008be71d8fdd446b2cce81e4bb0406109c130eafc583fbd9fe33244e2`;
`.gitignore` is the single byte `*`; `h` is byte-equal to the package `husky`
file, length `551`, SHA-256
`70200b200ca709b0622784f93839a5b2872333a917a09afddefd7dc2d8cdc680`;
and `husky.sh` is length `160`, SHA-256
`21122903fca7209a13c991e5be68780636e28f1b8f0ae7ea07ed0065dfe37268`.
On POSIX, `h` and all 14 hook-name shims must have every executable bit
required by the package contract; on Windows, content/type checks plus the real
Git Bash commit are authoritative.

Environment parsing is closed. `HUSKY_INSTALL_MODE` is absent, `required`, or
`skip`; `HUSKY` is absent or `0`; `CI` is absent, `false`, or `true`, all
case-sensitive. Default is required. Exactly one of install-mode `skip`,
`HUSKY=0`, or `CI=true` selects skip with reason
`explicit-install-mode`, `husky-disabled`, or `read-only-ci-install`.
Unknown values, explicit `required` plus a skip source, or multiple skip sources
are conflicts and fail. Skip mode snapshots local config plus the complete
tracked/generated trees before and after verification, requires byte/type/mode
identity, invokes neither Husky nor a write-capable Git command, and reports
only `skipped:<reason>`.

Add one `HUSKY-INSTALL-###` row for each enumerated state: required success;
package absent/version/integrity/bin/hash/link failures; spawn start/nonzero;
wrong root; missing/duplicate/wrong hooksPath; every distinct tracked-hook
missing/untracked/mode/type/link/marker/hash failure; generated-root
missing/link; generated file missing/extra/type/link/hash/mode; each authorized
skip; every unknown environment value; explicit-required conflict; multiple
skip conflict; skip immutability success/failure; direct-invocation-only false
positive; and real `git commit` pass/reject. No row says
“shim/hook,” “missing/linked,” or otherwise joins fixtures. Each result includes
one ID, phase, native status, reason, Husky/Git call counts, hooksPath, and exact
tracked/generated post-state.

## Finding 17 — T3 audit contract is stronger than its stable-ID catalog

### Problem to resolve

T3 specifies raw-byte, strict-UTF-8, duplicate-key, resource-ceiling,
closed-report-v2, native-signal, timeout, and start-failure behavior, but its
27-row catalog does not name most of those cases. It also gives the production
validator “native status” even though its decision table distinguishes four
process-outcome kinds, and it leaves stderr and termination unbounded. Deferring
case discovery to implementation would make the eventual evidence define the
contract it is supposed to prove.

### Exhaustive option and permutation inventory

The viable design choices are:

1. Add a strict case manifest with every stable ID, a discriminated process
   outcome file, exact stream ceilings, and exact timeout escalation.
2. Leave the prose normative and let implementation append whatever rows its
   author finds necessary.
3. Generate property-based cases at runtime and use generated names instead of
   reviewed stable IDs.
4. Keep one stable row per category and put many fixtures/outcomes beneath it.
5. Use `JSON.parse` plus a byte-length check and remove duplicate/depth/token
   promises.
6. Add a third-party JSON parser and rely primarily on that package’s tests.
7. Move all parser/process work into a later issue while leaving T3’s validator
   acceptance broad.

The independent permutations are:

- process: ordinary exit `0`, exit `1`, other exit, external signal, timeout
  ending after TERM, timeout requiring KILL, start failure, kill failure,
  stream failure, and error/close double-notification;
- streams: zero, exact limit, first overflow byte, and protected-file
  length/hash disagreement for stdout and stderr independently;
- raw report: empty, BOM, every malformed UTF-8 class, incomplete JSON, second
  value, non-whitespace suffix, whitespace suffix, and exact/over each resource
  ceiling;
- duplicate JSON property at every report, nested report, native-outcome,
  exception, finding, and topology object layer;
- report schema: missing/extra/wrong type at every closed object layer,
  graph-edge reciprocity, key/name equality, sorted uniqueness, safe counts,
  and metadata reconciliation;
- status/report matrix: `0` with empty/nonempty/malformed, `1` with
  nonempty/empty/malformed, and all non-policy process outcomes; and
- exception state: absent, exact, stale, malformed, missing/extra, topology
  mismatch, expiry boundaries, and follow-up governance.

Options 2–4 are ineligible because one stable result would still represent
multiple observable cases. Options 5 and 7 weaken already-selected security
behavior. A parser dependency could be viable, but it would add a second
supply-chain surface and still would not provide repository-specific schema,
graph, status, or process-envelope cases.

Stakeholder perspectives:

- Security reviewers need malformed or oversized registry output to fail before
  object construction and exception policy.
- CI maintainers need a hung process and unbounded stderr to terminate
  deterministically without deadlock or secret-bearing console output.
- Audit approvers need native tool failure distinguished from a governable
  residual.
- Test maintainers need a finite append-only case set with one result per row.
- Future npm upgraders need schema drift to fail as one explicit case rather
  than silently broaden acceptance.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| Complete atomic contract coverage | 32 | Every promised parser/schema/status boundary needs a stable executable row. |
| Process-outcome trustworthiness | 20 | Exit, signal, timeout, start and stream failures must not collapse. |
| Raw parser resource/security closure | 18 | Invalid bytes, duplicates, second values, and ceilings are pre-policy boundaries. |
| Audit evidence traceability | 12 | Reviewers must reconcile one ID to one input, class, normalized set, and diagnostic. |
| Maintainer usability | 8 | The catalog and outcome schema must remain implementable and reviewable. |
| Append-only stability | 7 | Existing IDs/evidence must keep one narrowed meaning. |
| Scope and churn | 3 | Additional files/dependencies matter only after correctness. |

### Scoring

| Option | Coverage (32) | Process (20) | Parser (18) | Evidence (12) | Usability (8) | Stability (7) | Churn (3) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Closed manifest, outcome envelope, exact limits | 5 | 5 | 5 | 5 | 4 | 5 | 1 | **96.0** |
| B. Prose plus implementation-derived rows | 3 | 3 | 3 | 2 | 3 | 2 | 4 | 56.8 |
| C. Runtime-generated property cases | 4 | 4 | 5 | 3 | 2 | 2 | 2 | 74.0 |
| D. Category rows with subcases | 2 | 4 | 3 | 2 | 3 | 2 | 4 | 55.2 |
| E. `JSON.parse` and byte length only | 1 | 3 | 1 | 2 | 4 | 3 | 5 | 40.4 |
| F. Third-party parser plus package tests | 4 | 4 | 4 | 3 | 3 | 3 | 3 | 74.0 |
| G. Defer to a later issue | 5 | 5 | 5 | 4 | 2 | 3 | 1 | 87.6 |

### Selected resolution: closed manifest, process envelope, limits, and IDs

Add `.github/workflows/npm-audit-cases.json` to T3’s required files. It is the
closed append-only manifest for the pure tokenizer, report validator, exception
validator, production CLI, and process-driver fixtures. Every row has exact
`Id`, `Layer`, literal fixture reference, `NativeOutcome`, `ExceptionState`,
`ExpectedExit`, `ExpectedReason`, `ExpectedNormalizedFindings`,
`ExpectedAuditNodePaths`, `ExpectedParserState`, and
`ExpectedProcessCallCount`. No range, wildcard, family, or multi-result row is
valid.

Keep `AUDIT-01` through `AUDIT-27`, but narrow their fixtures so their existing
plain-language labels have exactly one meaning:

- `01`–`11` retain their current clean/residual/topology/expiry meanings.
- `12` is invalid `createdAt`; `13` is one extra exception-root property; `14`
  is one duplicate normalized exception finding identity; `15` omits only
  `owner`; `16` uses the canonical repository path on the wrong GitHub host.
- `17` is raw ASCII `not-json`; `18` is one exact reversed-order equivalent;
  `19` is the real tracked CLI.
- `20` is numeric `auditReportVersion: 1`; `21` makes top-level
  `vulnerabilities` an array; `22` duplicates one canonical advisory URL in
  approved findings; `23` repeats one package key as a raw JSON property in
  report `vulnerabilities`; `24` duplicates one exact report `nodes` string;
  `25` omits only `followUpEvidenceSha256`; `26` omits only
  `approvalIdentity`; and `27` removes the final byte from one otherwise valid
  report.

Append the following allocations. Range notation below only allocates IDs
compactly; the committed manifest and issue table contain one physical row per
ID in the exact stated order.

| IDs | One fixture allocated to each ID, in order |
| --- | --- |
| `AUDIT-28`–`AUDIT-37` | empty raw report; UTF-8 BOM; UTF-16LE BOM; stray UTF-8 continuation; truncated multibyte UTF-8; exactly 8,388,608-byte valid empty report; byte 8,388,609; second JSON value; trailing non-whitespace; trailing JSON whitespace |
| `AUDIT-38`–`AUDIT-45` | depth 64; depth 65; 250,000 values; 250,001 values; 1,048,576-byte string token; 1,048,577-byte string token; 64-byte number token; 65-byte number token |
| `AUDIT-46`–`AUDIT-57` | raw duplicate key in report root; vulnerability object; advisory object; `cvss`; `fixAvailable`; `metadata`; `metadata.vulnerabilities`; `metadata.dependencies`; native-outcome root; exception root; exception finding; exception topology row |
| `AUDIT-58`–`AUDIT-68` | outcome BOM; outcome invalid UTF-8; outcome second value; outcome extra property; non-string `kind`; impossible `exit` combination; impossible `signal` combination; impossible `timeout` combination; impossible `startFailure` combination; stdout length/hash mismatch; missing stdout file |
| `AUDIT-69`–`AUDIT-80` | exit `2`; external `SIGTERM`; timeout ends after TERM; timeout requires KILL; start failure; stderr exactly 65,536 bytes; stderr byte 65,537; stdout stream failure; stderr stream failure; termination delivery failure; error then close emits one result; close without prior exit/error |
| `AUDIT-81`–`AUDIT-89` | report-root extra property; missing `auditReportVersion`; missing `vulnerabilities`; missing `metadata`; null `vulnerabilities`; array `metadata`; unsafe vulnerability package-property name; property-key/name mismatch; vulnerability extra property |
| `AUDIT-90`–`AUDIT-97` | vulnerability missing, respectively, `name`, `severity`, `isDirect`, `via`, `effects`, `range`, `nodes`, `fixAvailable` |
| `AUDIT-98`–`AUDIT-105` | the same eight vulnerability fields with one exact wrong type/value apiece |
| `AUDIT-106`–`AUDIT-116` | invalid `via` entry type; advisory extra property; advisory missing, respectively, `source`, `name`, `dependency`, `title`, `url`, `severity`, `cwe`, `cvss`, `range` |
| `AUDIT-117`–`AUDIT-125` | those nine advisory fields with one exact wrong type/value apiece |
| `AUDIT-126`–`AUDIT-131` | non-string CWE entry; CVSS extra property; CVSS missing `score`; CVSS missing `vectorString`; out-of-range/nonfinite score; non-string vector |
| `AUDIT-132`–`AUDIT-137` | package-string `via` target absent; `effects` target absent; via edge lacks reciprocal effect; effect lacks reciprocal via edge; unsorted `nodes`; invalid `fixAvailable: null` |
| `AUDIT-138`–`AUDIT-144` | fix object extra property; missing `name`; missing `version`; missing `isSemVerMajor`; wrong `name`; wrong `version`; wrong `isSemVerMajor` |
| `AUDIT-145`–`AUDIT-151` | metadata extra property; missing vulnerability counts `info`, `low`, `moderate`, `high`, `critical`, `total` |
| `AUDIT-152`–`AUDIT-157` | missing dependency counts `prod`, `dev`, `optional`, `peer`, `peerOptional`, `total` |
| `AUDIT-158`–`AUDIT-164` | negative metadata count; unsafe-integer count; non-integer count; severity total arithmetic mismatch; property-severity reconciliation mismatch; dependency total mismatch; duplicate normalized advisory identity in report |

For ceiling rows whose deliberately deep/count/long value cannot satisfy the
closed npm schema, `ExpectedParserState` distinguishes “accepted through strict
tokenizer, then schema rejection” from “rejected by tokenizer.” Thus the exact
limit and first-over-limit are both tested without pretending an artificial
deep object is a valid npm report.

#### Structured native outcome and production CLI

The process driver writes strict
`TerraformStyleGuide.NpmAuditNativeOutcome.v1` JSON with exactly:

```text
schemaVersion
commandContract
kind
exitCode
signal
termination
timeoutMilliseconds
terminationGraceMilliseconds
stdoutRetainedBytes
stdoutOverflow
stdoutSha256
stderrRetainedBytes
stderrOverflow
stderrSha256
```

`schemaVersion` is `1`; `commandContract` is
`corepack-npm-audit-package-lock-v1`; timeout fields are `120000` and `5000`.
Retained lengths are safe integers bounded by `8,388,608` and `65,536`; hashes
are lowercase 64-hex SHA-256. The discriminated states are:

| Kind | `exitCode` | `signal` | `termination` |
| --- | --- | --- | --- |
| `exit` | integer `0`–`255` | `null` | `none` |
| `signal` | `null` | one canonical supported `SIG*` name | `external-signal` |
| `timeout` | `null` | `null` | `sigterm` or `sigkill` |
| `startFailure` | `null` | `null` | `not-started` |

All other combinations fail `20 PROCESS_TOOL`. The file contains no command
path, output path, native error text, stdout, or stderr.

The CLI syntax is exactly:

```text
node Validate-NpmAudit.mjs --report REPORT --stderr STDERR --outcome OUTCOME
[--exceptions EXCEPTIONS]
```

Options are in that order, occur once, have nonempty separate values, and have
no aliases. The validator opens ordinary non-link protected inputs, recomputes
stdout/stderr length and SHA-256 against the outcome, and never prints file
contents or native exception text.

Production orchestration runs only the resolved exact Corepack executable with
arguments `npm`, `audit`, `--package-lock-only`, `--json`, `shell:false`, from
the exact package root. It uses asynchronous `spawn`, drains stdout and stderr
concurrently as raw `Buffer` chunks, retains only the bounded prefix, and
continues draining after overflow. It waits for `close`, reconciles a possible
earlier `error` exactly once, and writes all three protected files mode `0600`.

At exactly 120,000 ms on hosted Ubuntu, it sends `SIGTERM` to the detached
process group, waits 5,000 ms, and sends `SIGKILL` if still open. Failed
delivery or failure to reach `close` is `PROCESS_TOOL`. Production Windows
process-tree termination is out of scope; Windows runs every pure
outcome/validator fixture. This is explicit rather than falsely assuming
`child.kill()` terminates descendants on every platform.

`stdoutOverflow` produces `21`; `stderrOverflow` produces `20`. The collector
never decodes stderr, and no stderr bytes enter diagnostics or evidence. After
the validator records safe lengths, hashes, class, and normalized sets, the
orchestrator removes report, stderr, and outcome files in `finally`; a removal
failure fails the job without changing the validator’s recorded class.

#### Parser and decision precedence

Before `JSON.parse`, reject BOM, invalid UTF-8, more than one JSON value,
non-whitespace suffix, any raw duplicate key, raw input over 8,388,608 bytes,
depth over 64, more than 250,000 value tokens, a string token over 1,048,576
raw bytes, or a number token over 64 raw bytes. The tokenizer is an exported
dependency-free core in `Validate-NpmAudit.mjs`; it counts raw bytes, not
JavaScript replacement characters.

Classification order is process envelope (`20`), raw report (`21`), report
schema/graph (`22`), exit/report agreement (`23`), residual equality (`24`),
then exception governance (`25`). Only an `exit` outcome with code `0` or `1`
can reach report parsing. Exit `0` requires a valid empty graph; exit `1`
requires a valid nonempty graph. A signal, timeout, start failure, other exit,
stderr overflow, unverifiable file, or impossible envelope can never be
approved by an exception.

The harness preloads the manifest and rejects any missing, duplicate,
unexpected, reordered-with-changed-meaning, or multiply emitted result. Every
row asserts exact class/reason, parser phase, native outcome, stream identities,
normalized finding/topology sets, exception state, call/termination counts, and
safe diagnostic. This replaces “audit remaining rows during implementation”
with a complete reviewable contract.

## Finding 18 — T3 live follow-up evidence has no durable location/input

### Problem to resolve

T3 requires `followUpEvidenceSha256` to hash a canonical live-issue record, but
does not say where that record is retained or give it to the production
validator. A later reviewer can validate only that a digest is shaped like a
digest, not recompute it or inspect the facts it purports to bind. “Retained
external record” also leaves access, lifetime, schema, renewal, and deletion
undefined.

### Exhaustive option and permutation inventory

The available retention models are:

1. Embed one minimized canonical evidence record per referenced issue inside
   the tracked optional exception file.
2. Track each minimized record as a separate file under a repository evidence
   directory and give the validator that directory.
3. Put records in an organization-controlled external evidence store and
   retain a URI/object version/digest in the exception.
4. Store no snapshot; fetch the GitHub issue live during every validation.
5. Retain workflow artifacts from the approval run.
6. Keep the current external human-attestation hash and document a manual
   retrieval protocol.
7. Commit the entire raw GitHub API response.

The lifecycle permutations are:

- initial approval, ordinary offline validation, schedule, renewal, expiry, and
  exception removal;
- one finding per issue, several findings sharing one issue, missing record,
  duplicate record, unreferenced record, stale scope, and stale issue identity;
- valid issue, nonexistent response, pull request, closed/transferred issue,
  wrong repository/number, missing responsible assignee, changed body marker,
  and API/authorization failure; and
- valid canonical record, hash mismatch, noncanonical ordering/encoding,
  malformed timestamps, verification/approval skew, and issue update after the
  captured verification time.

Raw API retention is ineligible because it preserves arbitrary mutable content
and more personal metadata than policy needs. Workflow artifacts have
repository-configurable expiry and are not a durable offline validator input.
Live fetch on every CI run can be strong current-state evidence but makes
ordinary validation depend on network/API authority and rate limits. A hash-only
external attestation remains impossible for future repository reviewers to
recompute without separate access.

Stakeholder perspectives:

- Audit approvers need a record tied to the exact live issue they reviewed.
- Future reviewers need to recompute the digest from versioned bytes without
  privileged external storage access.
- Privacy/security reviewers need tokens, raw response bodies, email, and
  arbitrary issue prose excluded.
- CI maintainers need ordinary audit validation to remain deterministic and
  offline.
- Repository maintainers need renewal/removal to be one reviewable atomic
  change with the exception it authorizes.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| Offline digest recomputability | 28 | The central defect is a hash with no available preimage. |
| Integrity and durable retention | 20 | Evidence must survive and change only through reviewed governance. |
| Data minimization/privacy | 16 | Live API records can include unnecessary identity and arbitrary prose. |
| Truthful current-state semantics | 14 | Offline evidence must not be mislabeled as a live assertion. |
| Validator/cold-reader usability | 10 | Input discovery and cross-linking must be deterministic. |
| Renewal and cleanup closure | 8 | Initial, renewal, expiry, and removal states need one lifecycle. |
| Scope and churn | 4 | Fewer storage systems/files are preferable after correctness. |

### Scoring

| Option | Recompute (28) | Integrity (20) | Privacy (16) | Semantics (14) | Usability (10) | Lifecycle (8) | Churn (4) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Embed minimized records in exception file | 5 | 5 | 5 | 4 | 5 | 5 | 4 | **96.4** |
| B. Separate tracked evidence files | 5 | 5 | 5 | 4 | 4 | 4 | 3 | 92.0 |
| C. External controlled evidence store | 4 | 5 | 4 | 4 | 2 | 3 | 2 | 76.8 |
| D. Live API fetch on every run | 5 | 3 | 4 | 5 | 2 | 4 | 3 | 79.6 |
| E. Workflow artifacts | 2 | 2 | 3 | 2 | 2 | 1 | 3 | 42.4 |
| F. External hash/manual attestation only | 1 | 4 | 4 | 3 | 1 | 2 | 5 | 52.0 |
| G. Track raw API response | 5 | 5 | 1 | 4 | 3 | 3 | 2 | 74.8 |

### Selected resolution: embed minimized canonical records

Add `.github/workflows/Capture-NpmAuditFollowUpEvidence.mjs` to T3’s required
files. Keep the optional evidence itself inside the already-conditional
`.github/workflows/npm-audit-exceptions.json`; do not add an external store or
evidence directory.

The exception root has exactly four properties:

```text
schemaVersion
findings
auditNodePaths
followUpEvidence
```

`followUpEvidence` is a sorted unique array with exactly one record for every
distinct issue number referenced by `findings` and no unreferenced record.
Several findings may share a record only when their exact sorted identities
produce that record’s one scope hash. Each finding’s
`followUpIssueNumber`, `followUpIssueUrl`, `followUpScopeSha256`,
`followUpVerifiedAt`, and `followUpEvidenceSha256` must equal its record.

Each record has exactly these properties in this canonical order:

```text
evidenceSchema
verificationMethod
apiVersion
verifiedAt
verificationActor
repository
issueUrl
issueNumber
issueDatabaseId
issueNodeId
state
isPullRequest
createdAt
updatedAt
author
assignees
responsibleOwner
targetDate
scopeMarker
scopeSha256
titleSha256
bodySha256
```

Exact meanings:

- `evidenceSchema` is
  `TerraformStyleGuide.NpmAuditFollowUpEvidence.v1`;
  `verificationMethod` is `github-rest-user-and-issue-v1`; and `apiVersion` is
  the exact GitHub REST version used by the helper.
- `verifiedAt`, `createdAt`, and `updatedAt` are canonical whole-second RFC
  3339 UTC. Require `createdAt <= updatedAt <= verifiedAt`.
- `verificationActor` and `author` are closed
  `{login,databaseId,nodeId}` objects. Every assignee is the same closed object;
  `assignees` is sorted/unique by login and immutable IDs.
- `repository` is exactly
  `{owner:"franklesniak",name:"TerraformStyleGuide"}`. URL/number have the
  existing canonical grammar. Database ID is a positive safe integer and node
  ID is a 1–128-byte safe ASCII opaque string.
- `state` is exactly `open`; `isPullRequest` is exactly `false`.
- `responsibleOwner` is one canonical GitHub login, equals the exception
  finding owner, appears exactly once in `assignees`, and is not inferred from
  issue author.
- `targetDate` is canonical `YYYY-MM-DD`, present in the issue body’s reviewed
  marker set, and not later than the exception expiry date.
- `scopeMarker` is exactly
  `npm-audit-findings-sha256: <scopeSha256>`; its value and
  `scopeSha256` equal the finding-to-issue canonical scope calculation.
- `titleSha256` and `bodySha256` hash the exact UTF-8 strings returned by the
  live response (empty body is allowed only if the required markers would
  consequently fail). Raw title/body are not retained.

Canonicalization constructs a new null-prototype object in the property order
above, constructs nested identity/repository objects in their stated order,
sorts arrays by their stated key, and serializes with the native
`JSON.stringify` algorithm after rejecting lone surrogates. The evidence digest
is SHA-256 over the exact BOM-less UTF-8 serialization with no whitespace and
no final newline. The digest itself is not part of the record, avoiding a
circular hash. The validator independently reconstructs these bytes and
requires lowercase hex equality to every referencing finding.

Initial approval and every renewal run the tracked capture helper in a private
local/hosted Ubuntu session. Its exact inputs are issue number, expected scope
SHA-256, responsible owner, and a new protected output path. It accepts the
GitHub token only through a non-logged environment variable, calls
authenticated `GET /user` and
`GET /repos/franklesniak/TerraformStyleGuide/issues/<number>` with no redirect,
and bounds each raw response to 1 MiB. It rejects non-200, malformed/extra
response shape needed by the projection, repository/URL/number mismatch,
presence of `pull_request`, non-open state, missing responsible assignee, and
missing/multiple/wrong scope, owner, or target-date markers. It writes only the
canonical minimized record with create-new mode `0600`; it never writes the
token, headers, raw response, title, body, or email.

The approver copies that exact object into `followUpEvidence`, deletes the
scratch record, and updates the exception in the same reviewed change.
`verificationActor.login` must equal `approvalIdentity`; require:

```text
verifiedAt <= createdAt == approvedAt <= verifiedAt + 3600 seconds
```

for every referencing finding. Expiry remains later than approval and no more
than 30×24 hours after it, with `now >= expiresAt` invalid. Renewal repeats both
live reads, current fix-availability analysis, scope/body/assignee review, and
approval; changing only timestamps or reusing the old record is invalid.

The production validator needs no new path argument because the preimage is in
the exception input it already receives. It reports only
`offline-follow-up-evidence-valid`, never “issue currently open.” Ordinary PR,
push, schedule, and manual runs perform no network request and require no
`issues:read`; the record proves the live state observed at its `verifiedAt`,
not current state after that instant. The 30-day approval bound is the maximum
offline staleness window.

When all residuals are removed, delete the exception file from the branch tip;
its reviewed history remains the durable record. When only one issue scope is
removed, remove its findings and record together. A referenced record missing,
an unreferenced/duplicate record, changed record bytes/hash, or incomplete
cleanup fails governance.

Append atomic `AUDIT-165` through `AUDIT-184` for: missing evidence array;
missing referenced record; extra unreferenced record; duplicate issue record;
evidence hash mismatch; verified-time mismatch; verifier/approval mismatch;
closed issue record; pull-request record; wrong repository; URL/number mismatch;
invalid database/node identity; responsible owner absent from assignees; scope
marker/hash mismatch; invalid title hash; invalid body hash; timestamp/order
failure; approval-session over 3,600 seconds; valid single-issue record; and
valid shared-issue scope. The capture helper separately stubs nonexistent,
redirect, API failure, pull request, closed, wrong repository/ID, missing
assignee, changed marker/body, oversized response, and valid open issue, one ID
and one oracle apiece.

## Finding 19 — T4 backend identifier maximum is arithmetically wrong

### Problem to resolve

T4 says `backend-v1:<type>:<authority>:<scope>` has a maximum length of 206
bytes while independently limiting each of its three components to 63 ASCII
bytes. The literal prefix is 10 bytes and the serialization has three colon
bytes, so its reachable maximum is 202. The inaccurate constant makes a cold
reader wonder whether four bytes or a fourth component are missing and leaves
the actual boundary without fixtures.

### Exhaustive option and permutation inventory

The available choices are:

1. Correct the maximum to 202, keep the component grammar, and add exact
   whole-string/component-boundary fixtures.
2. Delete the total-length statement as redundant and rely only on component
   limits.
3. Increase one or more component limits until 206 becomes reachable.
4. Keep 206 as a harmless loose upper bound because component validation still
   rejects 203–206.
5. Lower the total below 202 as an additional conservative policy.
6. Count Unicode characters rather than bytes.

The relevant permutations are minimum/maximum component length in each of the
three positions; totals 16, 201, 202, and 203; empty/additional components;
leading/trailing punctuation; and non-ASCII input whose code-point count differs
from its UTF-8 byte count. Options 3, 5, and 6 change the selected identifier
policy without a need. Option 4 leaves contradictory normative text. Option 2
is technically safe but removes a useful copy/review ceiling rather than
correcting it.

Stakeholder perspectives:

- Operators need one grammar and one truthful maximum.
- Harness authors need reachable positive endpoints and the first rejected
  value.
- Bash and PowerShell implementers need the same ASCII-byte calculation.
- Reviewers need to distinguish a derived redundant guard from an unexplained
  magic constant.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| Arithmetic/grammar correctness | 35 | The defect is a direct contradiction in the accepted language. |
| Boundary closure | 25 | Minimum, maximum, and first-invalid values must be executable. |
| Cold-reader clarity | 15 | Prefix, separators, components, and total should reconcile visibly. |
| Fixture precision | 12 | Tests must identify which component makes 203 invalid. |
| Bash/PowerShell consistency | 8 | Both surfaces must count the same ASCII bytes. |
| Scope and churn | 5 | A constant and cases should not redesign the identifier. |

### Scoring

| Option | Correctness (35) | Boundary (25) | Clarity (15) | Fixtures (12) | Cross-platform (8) | Churn (5) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Correct to 202 and test derivation | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| B. Remove total limit | 5 | 4 | 3 | 4 | 4 | 5 | 85.0 |
| C. Expand components to reach 206 | 1 | 3 | 2 | 3 | 2 | 2 | 40.4 |
| D. Keep loose 206 | 2 | 2 | 2 | 2 | 3 | 5 | 44.6 |
| E. Add a lower conservative total | 4 | 4 | 3 | 4 | 4 | 4 | 77.0 |
| F. Count characters, not ASCII bytes | 1 | 1 | 2 | 2 | 1 | 3 | 28.8 |

### Selected resolution: maximum 202 with derived boundary fixtures

Replace every T4 `206` backend-identifier ceiling with `202`. State the
derivation beside the grammar:

```text
10-byte "backend-v1" + 3 colon bytes + 3 × 63-byte components = 202 bytes
```

The minimum is similarly `16`. Set `LC_ALL=C` in Bash before length/grammar
checks. In PowerShell, reject non-ASCII first and use the original byte array or
strict ASCII/UTF-8 byte count, not `.Length` as a general Unicode proxy.

Validation order is exact: require a raw string; reject control/non-ASCII;
split into exactly literal `backend-v1` plus exactly three components; validate
each component’s 1–63-byte length and
`[a-z0-9](?:[a-z0-9._-]{0,61}[a-z0-9])?` shape; then assert the derived whole
length is 16–202. Grammar success remains an operator-attested label, not
backend discovery.

Add one stable row per literal case:

- 16 bytes with three one-byte components: pass.
- 201 bytes with component lengths `63,63,62`: pass.
- 202 bytes with `63,63,63`: pass.
- 203 bytes with `63,63,64`: reject `backend-component-too-long` before any
  Terraform/state/path action.
- Repeat the 64-byte component in type, authority, and scope as three atomic
  rows.
- Add separate empty type/authority/scope, fourth component, missing component,
  non-ASCII, and leading/trailing punctuation rows.

Every positive row asserts exact round-trip serialization and byte length in
both Bash and PowerShell. Every negative row asserts one reason, zero child
calls, and no filesystem mutation. The structural harness also rejects any
remaining literal `206` tied to this grammar.

## Finding 20 — T4 terminal-confirmation algorithm is not implementable

### Problem to resolve

T4 promises one canonical JSON line and byte-level rejection of NUL, CR,
invalid UTF-8, second lines, EOF, and input over 4,096 bytes, but assigns the
work to an unnamed “reviewed serializer” and a shell read from `/dev/tty`.
Bash variables cannot contain NUL and ordinary `read` performs line/character
processing before the issue’s promised raw classifications. The PowerShell
surface has a different string-oriented console API. Neither the expected
bytes, descriptor ownership, line framing, nor cleanup after a signal is
currently implementable from the issue.

### Exhaustive option and permutation inventory

The available approaches are:

1. Add one tracked Node helper with exported pure serializer/byte-classifier
   cores and POSIX/Windows controlling-terminal adapters.
2. Keep independent Bash `read` and PowerShell `Read-Host` implementations.
3. Add a Python helper and require Python on every operator platform.
4. Compose `stty`, `dd`, and shell utilities on POSIX and a separate
   PowerShell/.NET reader on Windows.
5. Require a protected confirmation file containing the expected bytes.
6. Accept confirmation through argv/environment/stdin instead of a controlling
   terminal.
7. Build separate native C/Win32 executables for POSIX and Windows.

The independent permutations are:

- push versus rm canonical array shape;
- string escaping, serial zero/maximum/invalid, digest case/prefix, and maximum
  expected line;
- controlling terminal present/absent, redirected standard streams,
  open/read/write/mode-restore/close failure, and HUP/INT/TERM;
- exact LF, CR, and CRLF Enter framing; EOF before terminator; empty, mismatch,
  leading/trailing whitespace, wrong case, NUL, BOM, malformed UTF-8, second
  record, exact 4,096 bytes, and byte 4,097; and
- Bash caller, Windows PowerShell 5.1 caller, and PowerShell 7 caller.

Options 2 and 4 retain two semantic implementations and cannot make Bash string
variables raw-byte evidence. Option 5 is byte-exact but removes the explicit
human controlling-terminal act. Option 6 is noninteractive and can consume
redirected attacker-controlled input. Separate native binaries are technically
strong but introduce toolchains, binary provenance, and two maintained
implementations when Node is already a locked T3 prerequisite.

Stakeholder perspectives:

- Operators need one visible line and familiar Enter-key interaction.
- Security reviewers need comparison before any destructive child and no
  redirected-stdin substitution.
- Cross-platform maintainers need Bash and PowerShell to share serialization
  and byte classification.
- Test authors need a pure Buffer seam for impossible-to-type malformed bytes
  plus real pseudo-terminal/console integration.
- Incident responders need confirmation bytes omitted from logs/evidence and
  terminal state restored on interruption.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| Raw-byte/framing/descriptor correctness | 28 | This is the unimplemented security boundary. |
| Canonical serializer and operation binding | 22 | The human must confirm exactly the reviewed operation identity. |
| Cross-platform semantic parity | 17 | Bash, Windows PowerShell 5.1, and PowerShell 7 need one contract. |
| Destructive-child exclusion on failure | 15 | Any read/classification failure must leave mutation count zero. |
| Fixtureability | 10 | Malformed bytes and terminal failures require deterministic seams. |
| Operator usability | 5 | The procedure is intentionally exceptional but must remain usable. |
| Scope and churn | 3 | Existing locked Node is preferable to new runtimes/binaries. |

### Scoring

| Option | Raw (28) | Serializer (22) | Parity (17) | Exclusion (15) | Tests (10) | Usability (5) | Churn (3) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Tracked Node helper | 5 | 5 | 5 | 5 | 5 | 4 | 2 | **97.2** |
| B. Bash `read` plus `Read-Host` | 2 | 3 | 2 | 4 | 3 | 5 | 5 | 57.2 |
| C. Python helper | 4 | 5 | 3 | 5 | 4 | 4 | 2 | 82.8 |
| D. POSIX utilities plus .NET reader | 4 | 4 | 2 | 4 | 3 | 2 | 3 | 68.6 |
| E. Protected confirmation file | 5 | 5 | 5 | 5 | 4 | 1 | 2 | 92.2 |
| F. Arg/env/redirected input | 1 | 4 | 5 | 2 | 4 | 3 | 5 | 60.2 |
| G. Two native platform binaries | 5 | 5 | 3 | 5 | 3 | 2 | 1 | 83.8 |

### Selected resolution: tracked Node serializer and terminal helper

Add `.github/workflows/Confirm-StateMutation.mjs` to T4’s affected files,
increasing the exact count. T4 depends on T3’s locked Node/npm policy; this
helper has no package dependency. It exports:

```text
serializeConfirmation(fields) -> Buffer
classifyConfirmationBytes(expectedBuffer, deliveredBuffer) -> closed result
readAndConfirm(fields, terminalAdapter) -> closed result
```

The production CLI exposes only `readAndConfirm`; there is no production
fixture/input-file/stdin override. The Bash/PowerShell harness imports the two
pure exports for malformed-byte cases.

#### Canonical serializer

The CLI has exactly two shapes:

```text
node Confirm-StateMutation.mjs --operation state-push
  --workspace W --backend B --current-serial C --proposed-serial P --digest D

node Confirm-StateMutation.mjs --operation state-rm
  --workspace W --backend B --resource-address A --digest D
```

Each option occurs once, in that order, with one separate nonempty value; there
are no aliases, positional values, environment fallbacks, command strings, or
unknown options. The helper independently reapplies T4’s exact workspace,
backend, serial, digest, and resource-address grammars. Serials are canonical
ASCII decimal nonnegative safe integers. Digest is exactly 64 ASCII hex,
converted `A-F` to lowercase once, and only its first 16 characters enter the
confirmation.

Construct a new array, never parse a caller-supplied expected line:

```text
["state-push",W,B,C,P,D[0:16]]
["state-rm",W,B,A,D[0:16]]
```

Serialize it with the Node/ECMAScript `JSON.stringify` algorithm, no replacer
or spacing, encode once with `TextEncoder`, and require round-trip strict UTF-8
plus length 1–4,096. Because every string field has already passed its exact
ASCII/safe grammar and numbers are safe integers, this is a deterministic
compact BOM-less byte sequence with no final newline. The helper prints that
line exactly once to the controlling terminal as the requested confirmation;
stdout/stderr receive only fixed safe reason/status text.

#### Controlling-terminal and descriptor lifecycle

The helper ignores redirected stdin/stdout. On POSIX it opens `/dev/tty`
read/write and proves the resulting descriptors are TTYs. On Windows it opens
`CONIN$` and `CONOUT$` and proves console/TTY identity. Unsupported/open failure
returns `65 environment/identity`; it never falls back to standard streams.

Wrap the input descriptor in `tty.ReadStream`, remember its initial mode, install
HUP/INT/TERM restoration handlers where supported, set raw mode, and disable
echo. Accumulate only Buffer chunks. The payload ceiling is exactly 4,096 raw
bytes; seeing byte 4,097 records `confirmation-overflow` and continues only far
enough to restore/close safely. A first CR or LF is the Enter framing byte and
is not part of the payload. An immediate LF after CR is the same CRLF
terminator. Any other byte already delivered after the terminator, including a
second CR/LF, is `confirmation-second-record`.

After the terminator, drain `read()` through the current libuv poll turn; queued
bytes reject. Input typed later is irrelevant and cannot feed the Terraform
child because the helper closes the terminal and every destructive child has
stdin set to null/closed. This scope is stated explicitly instead of claiming
the helper can reject bytes a user has not yet typed.

Before equality, reject NUL, UTF-8/UTF-16 BOM, malformed/incomplete UTF-8, EOF
before a terminator, and any extra record. Decode is used only to classify
strict UTF-8; equality is `Buffer.equals` against the serialized expected bytes.
There is no trim, Unicode normalization, case fold, retry, partial match, or
return of typed bytes.

In `finally`, restore the exact prior raw mode, remove handlers, destroy the
TTY streams without closing a descriptor twice, and close input/output
descriptors. A read, write, mode-change, restore, or close uncertainty returns
`68 confirmation`; HUP/INT/TERM return `129/130/143` after restoration. Success
is `0`. The caller treats every nonzero result as final and asserts mutation
child count `0`.

PowerShell invokes exact resolved Node/helper through
`ProcessStartInfo(UseShellExecute=false)` with `ArgumentList` on 7 and the
already-reviewed literal argument encoder on 5.1; Bash invokes an exact Node
path and fixed quoted argv. Neither caller computes JSON or reads confirmation
itself. Both record helper version/hash, expected-operation safe fields, and
result reason, never the typed line.

#### Permanent cases

Add separate `SM-CONFIRM-*` rows for exact push/rm serialization; escaping;
serial zero/maximum/leading-zero/negative/overflow; digest lowercase/uppercase/
nonhex/length; expected length 4,096/4,097; redirected stdin with valid text;
missing/non-TTY terminal; open/write/read/raw-mode/restore/close failure; exact
LF/CR/CRLF match; EOF; empty; mismatch; wrong case; leading/trailing whitespace;
NUL; UTF-8/UTF-16 BOM; every malformed UTF-8 class; early CR/LF; same-chunk and
queued second record; payload lengths 4,095/4,096/4,097; and each supported
signal during the read. Each is one row with exact helper/caller status,
terminal state, typed-byte-retention count `0`, destructive-child count `0` on
failure, and unchanged local/remote sentinels. Real pseudo-terminal tests run
on Ubuntu; Windows console integration runs on both PowerShell editions, while
the pure Buffer rows run identically on all cells.

## Finding 21 — T4 backup/publication does not consume T2 attestation

### Problem to resolve

T4 declares T2’s protected-destination primitive a dependency, yet its backup
block accepts only a final path and derives or assumes the parent facts. Its
push/rm workflows introduce proposed-state, pre-mutation backup,
post-mutation verification, and Terraform-created backup paths without exact
parent/attestation inputs. A final path cannot carry the operator’s assertion
that its parent is private, outside version control/shared storage, and free of
authorized competing writers.

### Exhaustive option and permutation inventory

The available interface designs are:

1. Require an exact `(parent,path,parent-attestation)` triple for every
   state-bearing path role.
2. Require one global protected parent/attestation and force every path into it.
3. Derive each parent with `dirname`/`GetDirectoryName` and use no separate
   attestation input.
4. Add one structured attestation manifest listing every role/path.
5. Rely only on machine owner/mode/DACL/type checks.
6. Put one prose attestation at the outer incident procedure but omit it from
   copyable blocks.

The path-role permutations are:

- standalone Bash/PowerShell backup final;
- push proposed input, current backup, and post-push verification pull;
- rm current backup, Terraform command-created backup, and post-rm
  verification pull;
- distinct versus byte-equal parents among those roles;
- missing/wrong literal, wrong parent/path binding, nested/sibling path,
  machine-inspection failure, syntactically valid but intentionally false
  attestation, and a parent that changes after validation.

A single global parent is overly restrictive and still cannot prove callers
did not swap role/path values. A structured manifest is viable but adds another
parser and makes copyable exceptional commands harder to stage. Machine checks
cannot prove other principals, mount-layer policy, version-control intent, or
absence of an authorized process. Outer prose is not an executable interface.

Stakeholder perspectives:

- Operators need every sensitive input/output path named before the incident
  command.
- Security reviewers need the same attested-versus-inspected distinction T2
  established.
- Windows/POSIX implementers need platform inspections without divergent human
  claims.
- Harness authors need to prove that a correct-looking path with a wrong/missing
  tuple stops before any state child.
- Incident responders need evidence labeled by role even when several paths
  share one parent.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| T2 semantic continuity | 26 | T4 explicitly depends on and must not weaken the earlier primitive. |
| Complete path-role coverage | 24 | Every state-bearing source/destination needs a closed interface. |
| Attested-versus-inspected truthfulness | 20 | Machine evidence cannot prove real-world privacy/competitor facts. |
| Filesystem/publication safety | 15 | Wrong role/parent binding must fail before sensitive I/O. |
| Operator usability | 7 | Exceptional workflows can be verbose but must remain copyable. |
| Fixture/evidence quality | 5 | Each tuple failure needs a zero-child oracle. |
| Scope and churn | 3 | Plain values are preferable to a new manifest parser. |

### Scoring

| Option | T2 continuity (26) | Roles (24) | Semantics (20) | Safety (15) | Usability (7) | Tests (5) | Churn (3) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Exact triple per role | 5 | 5 | 5 | 5 | 4 | 5 | 2 | **96.8** |
| B. One global parent triple | 4 | 2 | 5 | 4 | 4 | 4 | 4 | 74.4 |
| C. Derive parents from paths | 2 | 2 | 2 | 3 | 4 | 3 | 5 | 48.6 |
| D. Structured multi-role manifest | 5 | 5 | 5 | 5 | 2 | 4 | 1 | 92.4 |
| E. Machine inspections only | 1 | 3 | 1 | 2 | 4 | 3 | 4 | 40.6 |
| F. Outer prose attestation only | 3 | 3 | 3 | 3 | 4 | 2 | 4 | 61.0 |

### Selected resolution: exact parent/path/attestation triple per role

Use the same literal in every tuple:

```text
private-outside-vcs-no-competing-writers
```

The literal means the operator separately reviewed OS/storage evidence and
asserts the parent is private across relevant principals/mount layers, outside
version control and shared temporary storage, and has no active authorized
entry-mutating process. Code proves only its platform-specific subset and must
say `operator-attested`, never “machine verified.”

Add these exact inputs:

| Surface/role | Parent | Path | Attestation |
| --- | --- | --- | --- |
| Standalone backup | `STATE_BACKUP_PARENT` | `STATE_BACKUP_PATH` | `STATE_BACKUP_PARENT_ATTESTATION` |
| Push proposed source | `PUSH_PROPOSED_PARENT` | `PUSH_PROPOSED_PATH` | `PUSH_PROPOSED_PARENT_ATTESTATION` |
| Push current backup | `PUSH_BACKUP_PARENT` | `PUSH_BACKUP_PATH` | `PUSH_BACKUP_PARENT_ATTESTATION` |
| Push verification pull | `PUSH_VERIFY_PARENT` | `PUSH_VERIFY_PATH` | `PUSH_VERIFY_PARENT_ATTESTATION` |
| Rm current backup | `RM_BACKUP_PARENT` | `RM_BACKUP_PATH` | `RM_BACKUP_PARENT_ATTESTATION` |
| Rm command-created backup | `RM_COMMAND_BACKUP_PARENT` | `RM_COMMAND_BACKUP_PATH` | `RM_COMMAND_BACKUP_PARENT_ATTESTATION` |
| Rm verification pull | `RM_VERIFY_PARENT` | `RM_VERIFY_PATH` | `RM_VERIFY_PARENT_ATTESTATION` |

The PowerShell backup uses the same public names, not a second alias set. Each
block snapshots every applicable environment value exactly once before path
inspection, marks/holds the local immutable, and removes the public variable
from its child environment. Missing and empty are distinct fixture inputs but
both reject; there is no default, `dirname`, current-directory, repository-root,
or temp-directory fallback.

For every tuple, require exact literal equality first. Then require the full
path is the tuple’s one direct child under the separately supplied canonical
parent, using the destination-leaf grammar established by T2/its T4 extension.
Do not accept string-prefix containment or a nested leaf. Distinct roles remain
distinct inputs even when their parent bytes are equal; the evidence records
role, parent identity, path leaf, attestation result, and platform inspections.

POSIX reapplies T2’s canonical absolute non-root ordinary non-link directory,
effective-UID owner, exact mode `0700`, outside-known-repository/shared-root,
device, direct-child, and absent/existing-leaf checks appropriate to the role.
Windows applies T4’s exact local path, no-reparse component walk, current SID,
protected canonical DACL, allowed ACE set, volume, direct-child, and absent/
existing-leaf checks. Unsupported inspection fails; neither platform claims
the real-world attestation is proven.

Role-specific postconditions:

- Standalone/push/rm backup and verification destinations are initially absent,
  acquired/published under their exact parent, and never redirected elsewhere.
- `PUSH_PROPOSED_PATH` is an existing strict protected state file whose parent
  tuple is checked before parsing, diffing, or confirmation.
- `terraform state rm` always receives exact
  `-backup="$RM_COMMAND_BACKUP_PATH"` (or the platform’s one-argument equivalent)
  because HashiCorp documents that state-modifying subcommands create a backup
  and permit its path to be controlled. The path is fresh/absent before the
  child and exactly inventoried/validated afterward. An installed Terraform
  lacking that option is unsupported and stops before mutation; it does not
  fall back to a working-directory backup.
- Post-push/rm verification uses a new path and tuple, never reuses/truncates
  the pre-mutation backup.

Add one atomic case for missing, empty, wrong literal, parent/path mismatch,
nested path, sibling prefix, wrong owner/mode/DACL/type/reparse/device,
repository/shared-root membership, existing destination, and unsupported
inspection for each applicable role and platform. A syntactically valid but
fixture-declared false attestation demonstrates that the harness records only
literal acceptance and does not claim external truth. Every rejection asserts
status `64` or `65` by phase, state/confirmation/mutation child count `0`, no
new path, and unchanged sentinels.

## Finding 22 — T4 state capture and JSON parsing are unbounded

### Problem to resolve

T4 bounds PowerShell stderr but can write unlimited `terraform state pull`
stdout to disk, wait forever, and parse raw state or `terraform show -json`
without depth/count/string/duplicate-key limits. Bash has the same state/time
problem. A hung backend or unexpectedly large/malformed response can consume
unbounded disk, time, or memory, and a permissive object parser can let a later
duplicate `serial` or `lineage` overwrite the value the operator reviewed.

### Exhaustive option and permutation inventory

The available designs are:

1. Add one dependency-free tracked streaming Node helper, fixed defaults, and a
   reviewed hard-capped large-state profile used by both shells.
2. Implement equivalent bounded collectors/tokenizers independently in Bash
   and PowerShell.
3. Combine OS `timeout`/`ulimit`/pipeline tools on POSIX with .NET stream code
   on Windows and ordinary JSON parsers after capture.
4. Select one fixed relatively low limit, such as 64 MiB, with no override.
5. Select one fixed very high limit, such as 2 GiB, with no review profile.
6. Check free disk before launch but do not cap child output or parsing.
7. Keep the current unbounded behavior and document operator monitoring.

The independent permutations are:

- state pull start/exit/signal/timeout, stdout/stderr read error, destination
  write error/backpressure, TERM success, KILL escalation, and close failure;
- zero, exact state byte limit, first overflow byte, exact/over stderr, and
  simultaneous large stdout/stderr;
- default versus reviewed profile, malformed/partial profile, missing review
  ID/attestation, hard-cap boundary, and inadequate free space;
- BOM/invalid UTF-8/truncation/second JSON value/trailing bytes;
- exact/over depth, total value, object-property, array-item, string-token, and
  number-token ceilings;
- duplicate top-level metadata and duplicate keys at deeper state/value layers;
- missing/wrong raw `version`, `terraform_version`, `serial`, `lineage`; and
- supported/unsupported `terraform show` format major and schema drift through
  an added minor-version property.

A fixed low ceiling silently excludes legitimate large operations. One
unreviewed high ceiling reduces but does not close time/parser risk and offers
no capacity review. Disk-free checks are a snapshot, not an output limit.
Platform-specific implementations double the most security-sensitive streaming
and tokenizer logic.

Stakeholder perspectives:

- Large-estate operators need a deliberately generous default and a documented
  bounded escape procedure.
- Security reviewers need hard maximums, strict JSON, and duplicate rejection
  before metadata is trusted.
- CI/harness maintainers need deterministic timeout/overflow termination.
- Windows/POSIX maintainers need identical bytes, classes, and metadata.
- Incident responders need partial sensitive state cleaned only when exact
  ownership remains proven, with no captured diagnostics leaked.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| Time/disk/memory bound correctness | 28 | The primary defect is unbounded resource consumption. |
| Large-state operational usability | 22 | The control must not silently make documented large estates unusable. |
| JSON/metadata integrity | 20 | Duplicate or over-complex input must not alter lineage/serial evidence. |
| Cross-platform semantic parity | 14 | Bash and both PowerShell editions need the same limits/results. |
| Secret-safe failure handling | 8 | Overflow/error must not print or retain arbitrary state/diagnostics. |
| Boundary fixture quality | 5 | Every exact limit and termination phase needs an oracle. |
| Scope and churn | 3 | One helper is preferable after correctness. |

### Scoring

| Option | Bounds (28) | Large state (22) | JSON (20) | Parity (14) | Secrets (8) | Tests (5) | Churn (3) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Shared streaming helper plus reviewed profile | 5 | 5 | 5 | 5 | 5 | 5 | 1 | **97.6** |
| B. Separate Bash/PowerShell implementations | 5 | 5 | 5 | 3 | 5 | 4 | 2 | 91.6 |
| C. OS limits plus ordinary parsers | 3 | 4 | 2 | 2 | 4 | 3 | 4 | 59.8 |
| D. Fixed 64 MiB | 5 | 2 | 4 | 5 | 5 | 5 | 4 | 82.2 |
| E. Fixed 2 GiB | 4 | 4 | 4 | 5 | 4 | 4 | 4 | 82.8 |
| F. Free-space check only | 1 | 4 | 1 | 3 | 2 | 2 | 5 | 43.8 |
| G. Documented unbounded behavior | 1 | 5 | 1 | 3 | 1 | 1 | 5 | 45.6 |

### Selected resolution: shared streaming helper with reviewed ceilings

Add `.github/workflows/Inspect-TerraformState.mjs` to T4’s affected files. It
is dependency-free, versioned `Inspect-TerraformState.v1`, and exports the same
streaming tokenizer/metadata core used by its CLI. Bash and PowerShell retain
platform-specific protected-parent/file identity acquisition, but neither
implements child stream limits or state JSON parsing.

#### Limit profiles

The default profile is exactly:

| Limit | Value |
| --- | ---: |
| Raw state bytes | `536870912` (512 MiB) |
| `terraform show -json` bytes | `2147483648` (2 GiB) |
| Terraform child deadline | `900000` ms (15 minutes) |
| TERM grace | `5000` ms |
| Stderr retained bytes | `65536` |
| JSON nesting | `256` |
| Total JSON values | `10000000` |
| Properties in one object | `100000` |
| Items in one array | `2000000` |
| Raw bytes in one string token | `16777216` |
| Raw bytes in one number token | `128` |

`STATE_LIMIT_PROFILE` is absent/`default-v1` or exactly
`reviewed-large-state-v1`. The reviewed profile additionally requires:

```text
STATE_MAX_BYTES
STATE_SHOW_JSON_MAX_BYTES
STATE_TOOL_TIMEOUT_MS
STATE_LIMIT_REVIEW_ID
STATE_LIMIT_REVIEW_ATTESTATION
```

Values are canonical positive ASCII decimal safe integers. Raw state is
`536870913..2147483648`; show JSON is at least the selected state limit and at
most `8589934592`; timeout is `900001..3600000`; review ID is 1–64 safe ASCII
bytes `[A-Za-z0-9][A-Za-z0-9._-]{0,63}`; and attestation is exactly
`reviewed-capacity-and-large-state-v1`. Missing, extra-in-default, leading-zero,
sign, whitespace, exponent, unsafe integer, inconsistent, or hard-cap-exceeding
values fail before file/child creation.

The review record must document observed current state size, expected growth,
available protected-volume capacity, selected raw/show/time limits, backend
latency, operator and peer reviewer, and incident/change ID. Code validates only
the literal/profile numbers and reports them as operator-reviewed. A state over
2 GiB, show output over 8 GiB, or operation needing more than 60 minutes is
outside the copyable path and requires a separately reviewed specialized
procedure; there is no “unlimited” value.

Before capture, require available bytes on the selected protected volume at
least selected raw maximum plus 64 MiB working reserve, using one
platform-native volume query and an exact success/integer result. The check is
admission evidence, not the enforcement mechanism.

#### Exact helper modes and stream lifecycle

The CLI has closed `capture` and `validate` modes. Both receive exact resolved
Terraform path, exact verified state path, exact selected limit profile values,
and exact working-directory identity as separate argv values; no environment
fallback, shell, stdin, user command, or arbitrary Terraform argument is
accepted.

For capture, the platform block creates an empty protected candidate, records
its file identity, closes/disposes the acquisition handle only as the selected
platform contract requires, and invokes the helper. The helper reopens the exact
ordinary non-link zero-length identity without truncation and spawns exactly:

```text
terraform state pull
```

with `shell:false`, stdin closed, and separate stdout/stderr pipes. It writes
Buffer chunks to the candidate while honoring writable backpressure. It retains
only the first 65,536 stderr bytes in memory, never persists/prints them, and
continues draining. Counters saturate at limit+1.

At stdout byte `stateMax+1`, stderr byte 65,537, stream/write error, or deadline,
stop candidate writes, send TERM to the exact process/process group, wait 5,000
ms, send KILL if still open, and drain/discard both streams through close.
Start, exit, signal, timeout, TERM/KILL, read/write, and close are distinct
outcomes. No success is considered until child close, output flush, candidate
close, and caller identity reinspection all succeed.

Stderr overflow returns class `73` regardless of native result. State overflow,
timeout, start/read/write/close failure, empty state, and nonzero/signal result
return `66`. The helper outputs only one bounded result object containing safe
profile, observed saturated counts, native outcome, termination phase, metadata
on success, and digest—never state/stderr bytes or native error text. A proven
owned unpublished candidate is removed by the caller; identity uncertainty
retains it.

Validate mode spawns exactly:

```text
terraform show -json <exact-state-path>
```

under the same timeout/stderr lifecycle. It feeds stdout chunks directly into
the strict streaming JSON tokenizer while counting/discarding after any limit;
ordinary backup validation does not materialize show JSON. Finding 23’s diff
mode may direct the same bounded bytes into its separately protected input, but
cannot raise these limits.

#### Strict streaming JSON and metadata

Read raw state and show output as Buffer chunks. Reject UTF-8/UTF-16 BOM,
invalid/incomplete UTF-8, NUL outside a JSON escape, JSON grammar error, second
value, non-whitespace suffix, any resource ceiling, or a duplicate decoded key
in any object. The tokenizer maintains a bounded key set per active object and
honors the listed depth/object/array/global limits; it never constructs resource
values or secret strings in a general object graph.

For raw state format `4`, project exactly one top-level occurrence of:

- `version`: integer exactly `4`;
- `terraform_version`: 1–64-byte canonical ASCII Terraform version;
- `serial`: nonnegative JavaScript-safe integer written canonically; and
- `lineage`: 1–128 safe ASCII bytes.

Other format-4 state properties are grammar/tokenized but not retained. Missing,
duplicate, wrong-type, unsafe, or unsupported metadata is `66`. Supporting a
future raw state format requires an issue/parser/case update, not ignoring the
version.

For `terraform show -json`, require top-level `format_version` with supported
major `1` and one canonical `terraform_version`; validate the complete JSON
stream under all ceilings. Per HashiCorp’s versioning rule, an unknown property
under a supported minor is allowed semantically after strict JSON/duplicate/
resource validation; an unsupported major rejects. Record the exact format
version.

Compute whole-state SHA-256 incrementally over original raw bytes. Never
decode/re-encode before hashing/publishing. Metadata output uses a fixed
serializer and contains only format/version/lineage/serial/byte count/digest and
selected limits.

Add atomic default/review-profile and every numeric boundary case; raw/show
byte limit−1/limit/limit+1; timeout just before/at deadline, TERM success, KILL
escalation/failure; simultaneous stream/backpressure/read/write/close failures;
every UTF-8/BOM/JSON suffix class; each parser limit at/over; duplicate keys at
top and nested layers; each metadata missing/duplicate/type/range case; raw
version 4/unsupported; show format 1.x/unsupported 2.x; and safe unknown minor
property. Each result asserts phase/status, termination calls, retained byte
count, file identity/postcondition, no secret output, and unchanged remote
sentinel.

## Finding 23 — T4 state-difference helper has no file, API, or input model

### Problem to resolve

T4 assigns approval to a substantial offline redaction/difference engine but
does not add a helper file, name a serializer/parser, or provide trusted
configuration and provider-schema inputs. `terraform show -json` for a state is
a values representation, not a configuration representation; its
`provider_name` omits provider configuration aliases/module paths. A helper
cannot truthfully label identities “configuration-known” or safely decide which
dynamic paths may be emitted from the two state documents alone.

### Exhaustive option and permutation inventory

The available designs are:

1. Add a versioned tracked helper consuming bounded current/proposed state/show
   snapshots, provider schema, exact configuration/module/lock identities, and
   a peer-reviewed safe identity/change manifest.
2. Consume only the two `terraform show -json` state representations and treat
   their identities as trusted.
3. Generate the trusted manifest automatically from the current state.
4. Add a complete HCL/module parser and derive configuration/schema identity
   inside this repository.
5. Have operators review raw `terraform show -json` output manually.
6. Require an external commercial/state-analysis service.
7. Split/defer the entire diff boundary to another issue while T4 retains
   manual push/rm.

The input permutations are:

- raw current/proposed state and show JSON identity, same/different Terraform,
  missing/substituted/symlinked files, and digest mismatch;
- configuration Git commit/tree/index/worktree, tracked `.tf`/`.tf.json`/
  lock files, untracked configuration, and resolved local/remote modules;
- provider lock, installed provider schema, schema format/version, provider
  aliases/config addresses, and state resource schema versions;
- manifest missing/extra/duplicate/unsafe resource, output, instance, path, or
  allowance identities;
- equal files, serialization-only difference, allowed difference, missing
  expected difference, extra difference, unknown resource/output/provider/
  schema/instance/dynamic path, and sensitivity disagreement;
- non-sensitive scalar/object/list/set/map changes versus a sensitive subtree;
  and
- every raw/resource/output/report ceiling, parser failure, temporary-index
  failure, cleanup failure, and secret canary.

State-derived trust is circular: a malicious proposed state can nominate the
identities used to approve itself. A full HCL/module evaluator would duplicate
Terraform and still need installed provider schemas. Raw manual review leaks
state secrets. Deferral leaves the destructive operation’s most important
review gate undefined.

Stakeholder perspectives:

- Peer reviewers need a finite safe manifest that states exactly which
  configuration identities and changes they approved.
- Security reviewers need no value, dynamic secret-like key, encoding, length
  clue, or stable leaf digest in output/evidence.
- Terraform maintainers need provider/schema/module provenance aligned with the
  exact initialized configuration.
- Large-state operators need bounded streaming/spill behavior rather than
  loading two multi-hundred-megabyte object graphs.
- Harness authors need deterministic canaries at input, temporary, diagnostic,
  report, and artifact boundaries.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| Secret non-disclosure | 28 | The helper processes plaintext state and its output is intended for review/evidence. |
| Configuration/schema/input provenance | 24 | State alone cannot establish the identities the policy claims. |
| Semantic diff/allowlist correctness | 20 | Missing, extra, dynamic, sensitive, and schema changes must fail exactly. |
| Resource bounds and fixtureability | 14 | Two large states require bounded streaming and exhaustive canaries. |
| Cross-platform deterministic output | 7 | Bash and PowerShell callers need one report. |
| Reviewer/operator usability | 4 | Manual state mutation can be demanding but the manifest must be preparable. |
| Scope and churn | 3 | One large helper/manifest is still preferable to duplicated engines. |

### Scoring

| Option | Secrets (28) | Provenance (24) | Semantics (20) | Bounds/tests (14) | Parity (7) | Usability (4) | Churn (3) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Tracked helper plus reviewed manifest/all snapshots | 5 | 5 | 5 | 5 | 5 | 3 | 1 | **96.0** |
| B. Two show documents only | 3 | 1 | 3 | 4 | 5 | 4 | 5 | 58.0 |
| C. Manifest generated from current state | 3 | 2 | 2 | 4 | 5 | 4 | 4 | 58.2 |
| D. Repository-owned full HCL evaluator | 4 | 4 | 5 | 4 | 3 | 3 | 1 | 80.0 |
| E. Raw human state review | 1 | 1 | 3 | 1 | 3 | 3 | 5 | 34.8 |
| F. External analysis service | 4 | 4 | 4 | 3 | 3 | 2 | 1 | 72.4 |
| G. Defer diff while retaining mutation | 5 | 5 | 5 | 4 | 5 | 2 | 1 | 92.4 |

### Selected resolution: tracked helper with closed reviewed inputs

Add `.github/workflows/Review-TerraformStateDifference.mjs` to T4’s affected
files. It is dependency-free and versioned
`Review-TerraformStateDifference.v1`. It imports the strict streaming tokenizer
and limits from `Inspect-TerraformState.mjs`; it cannot raise them. Its
production CLI has one exact option order:

```text
node Review-TerraformStateDifference.mjs
  --manifest MANIFEST
  --configuration-root ROOT
  --current-state CURRENT
  --current-show CURRENT_SHOW
  --proposed-state PROPOSED
  --proposed-show PROPOSED_SHOW
  --provider-schema PROVIDER_SCHEMA
  --output REPORT
```

There are no aliases, environment paths, network calls, stdin, arbitrary
Terraform arguments, or raw-value output modes. All seven input files and the
fresh output are separately validated as exact protected ordinary non-link
identities under the applicable parent/attestation contract. Current/proposed
raw states have already passed `Inspect-TerraformState`; show and provider
schema captures use that helper’s bounded shell-free collector with the exact
same Terraform executable/version, timeout, strict UTF-8/JSON, and no network
attestation.

#### Reviewed manifest

The manifest is compact strict JSON, BOM-less UTF-8, schema
`TerraformStyleGuide.StateDifferenceReview.v1`, maximum 16 MiB, depth 32,
100,000 rows, 4,096 bytes per safe string, duplicate-key rejection, and exact
closed sections:

1. **Review** — nonsecret review ID, whole-second UTC time, operator, peer
   reviewer, incident/change reference, and literal
   `reviewed-exact-configuration-schema-and-change-set-v1`.
2. **Tool** — exact helper version/hash, Terraform executable hash/version, and
   selected limit profile.
3. **Configuration** — Git object format, exact full commit/tree IDs, exact
   sorted tracked configuration-file rows (`path`, Git mode/blob ID, working
   SHA-256), `.terraform.lock.hcl` SHA-256, and proof that index/worktree have no
   extra/changed `.tf`, `.tf.json`, or lock path.
4. **Modules** — exact sorted local/remote module rows with module key, reviewed
   source/version, resolved relative directory, and canonical package-tree
   SHA-256. This is mandatory because Terraform’s dependency lock file does not
   lock remote modules.
5. **Inputs** — whole-file SHA-256/byte count/format metadata for current state,
   current show, proposed state, proposed show, provider schema, and lock file.
6. **Provider identities** — source address, selected lock version/checksums,
   schema provider key/version, and reviewed provider-configuration aliases/
   module addresses. No development override is accepted.
7. **Subjects** — exact safe resource/output identities. A resource row assigns
   an opaque manifest ID to reviewed module/resource address, mode, type, name,
   provider source/config identity, schema version, and a sorted explicit set of
   allowed instance-key identities. An output row assigns an ID to reviewed
   name, type shape, and sensitivity.
8. **Paths** — safe manifest IDs for provider-schema/configuration-known
   attribute/output paths. Dynamic map/set elements are represented only by
   their nearest reviewed schema path, never by a state-derived key.
9. **Allowances** — an exact sorted unique set of
   `(subjectId,pathId,oldKind,newKind,change,sensitivity)` rows that the peer
   approved. The observed changed-row set must equal it; missing expected rows
   are as invalid as extra rows.

The helper proves the Git root/commit/tree with fixed shell-free Git commands,
compares manifest file rows to HEAD, stage-0 index, and no-filter working-byte
hashes, and rejects untracked Terraform configuration. It verifies module tree
digests, lock digest, state/show/schema file digests, Terraform identity, and
provider-schema identities. It does not parse HCL and must label the subject/
path manifest `operator-and-peer-reviewed`, not mechanically derived
configuration truth.

#### Provider schema and state/show reconciliation

The provider-schema input is exact bounded output of:

```text
terraform providers schema -json
```

from the same initialized root and executable with registry/network access
disabled. Require supported schema format major, exact provider source keys,
resource/data-source schema presence and version, and lock/manifest equality.

For each show resource, require exact manifest identity for address, module,
mode, type, name, instance key, `provider_name`, mapped provider configuration,
and `schema_version`; then require the corresponding provider schema. State
show’s provider name alone never supplies alias/configuration identity.
Outputs require an exact manifest row. Any absent/extra/duplicate/unsafe/
unreviewed identity yields only fixed `unreviewed-identity-present`, never the
state-derived identity.

Lineage must be equal before diff. Serial and whole-state digests are safe
metadata handled under Finding 24’s progression rule. Show format/Terraform
versions and input digests must match the manifest. Equal whole-state digests
produce `identical` with zero rows. Unequal digests plus no semantic changed row
produce `serialization-only-difference` and stop; they are not silently
approved.

#### Secret-safe comparison algorithm

Generate one cryptographically random 256-bit HMAC key per invocation and hold
it only in process memory. Stream each show document once. For every reviewed
subject/path, combine provider-schema sensitivity with both
`sensitive_values` trees:

- If either side marks a subtree sensitive, do not descend. Compare canonical
  subtree tokens with per-run HMAC and emit only `sensitive-subtree-changed` or
  no row.
- For a reviewed non-sensitive scalar/path, compare canonical token HMACs and
  retain only old/new JSON kinds plus
  `added|removed|type-changed|value-changed|unchanged`.
- For an object/list path, recurse only through provider-schema/manifest-known
  children. A dynamic/unknown key, element identity, duplicate, or count beyond
  the manifest collapses to the fixed rejection.
- Resource/provider/schema/instance/output/sensitivity changes are separate
  fixed enums, never inferred as a value change.

HMAC permits bounded comparison without a stable dictionary-testable leaf
digest. The random key never leaves memory. Bounded intermediate indexes contain
only manifest numeric IDs, JSON-kind/sensitivity enums, and HMACs, are created
mode `0600` under the validated protected root, and are removed in `finally`.
They are never logged, uploaded, or included in the report. Failure to prove
their exact identity/removal returns `67` and blocks mutation.

The helper observes `STATE_DIFF_MAX_INDEX_BYTES=268435456`,
`STATE_DIFF_MAX_ROWS=100000`, and report maximum 16 MiB in addition to Finding
22 limits. Overflow stops. It never constructs or retains a full general state
object and never writes raw state/show/provider values to a temporary index.

#### Closed output

The fresh report is compact canonical JSON:

```text
schemaVersion
helperVersion
reviewId
configurationIdentity
terraformVersion
currentMetadata
proposedMetadata
providerSchemaSha256
outcome
rows
counts
summarySha256
```

Every row contains only manifest-provided safe labels/IDs, old/new JSON kind,
sensitivity enum, and change enum. It contains no value, state-derived unknown
identifier, dynamic key, raw/encoded fragment, length/entropy clue, native
diagnostic, stable leaf digest, HMAC, or index path. Counts use closed
categories. `summarySha256` hashes the canonical report fields/rows excluding
itself. The helper prints only outcome, row counts, whole-file digests already
approved elsewhere, and summary hash.

Proceed to confirmation only if all provenance checks pass, no fixed rejection
reason exists, and observed changed rows equal the allowance set exactly.
`identical` needs no destructive push. `serialization-only-difference`,
unreviewed identity, allowance mismatch, parser/limit/temp cleanup failure, or
any sensitivity ambiguity returns `67`.

Fixtures cover every manifest section/property/type/duplicate; Git
commit/tree/index/worktree/untracked/module/lock drift; state/show/schema/
Terraform digest/version mismatch; provider alias/name/schema disagreement;
resource/output/instance/path missing/extra/duplicate/unsafe; every change enum;
missing/extra allowance; sensitive flag on either/both side; dynamic secret-like
keys; exact/over index/row/report limits; HMAC/index cleanup failures; and
canaries as raw, Base64, hex, URL encoding, JSON escapes, substrings, and
stable/ephemeral hashes. Scan stdout, stderr, report, result objects, temp
directory after cleanup, and uploaded artifacts. Each row has one status/reason,
report digest, row/count oracle, and mutation call count `0` on failure.

## Finding 24 — T4 rollback and serial rules are not jointly satisfiable

### Problem to resolve

For a content-changing push, T4 currently accepts a proposed serial “not lower
than” the current serial. Terraform rejects only when the remote serial is
higher, so equal-serial different content can overwrite state. The promised
rollback command has the inverse defect: after a successful push, the
just-created backup has a lower serial and Terraform's retained safety check
normally rejects a direct push of it. T4 also correctly prohibits `-force`.
The issue therefore needs both a monotonic forward rule and a recovery
procedure that can actually pass the stated safety controls.

### Exhaustive option and permutation inventory

The available designs are:

1. Require exact next-serial progression for every content-changing push;
   prefer a reviewed backend-native historical-version restore and otherwise
   construct a new candidate by changing only the validated desired backup's
   top-level serial under a tracked helper.
2. Require exact next-serial progression but support only backend-native
   rollback/vendor support, with no generic recovery for other backends.
3. Keep equal serials and make direct backup rollback work with `-force`.
4. Keep equal serials and continue promising a direct unforced backup push.
5. Parse and fully reserialize the old state as generic JSON with a new serial.
6. Require an arbitrary greater serial and leave recovery as prose/operator
   editing.
7. Remove rollback detail and defer all recovery design while retaining manual
   push.

The progression permutations are byte-identical, semantically identical but
byte-different, content-changing, lower/equal/exact-next/skipped/max-safe/
overflow serial, same/different/empty lineage, and raw-state format
supported/unknown. Byte identity is checked before progression: a byte-identical
candidate is a no-op, while serialization-only change remains a rejection.

The concurrency permutations are:

- a continuous backend/workspace/external writer exclusion established before
  the fresh pull and held through verification, versus a lock held only during
  the final command or no effective exclusion;
- no remote drift, a competitor writing current+1 before the push, a lock
  conflict, timeout, unknown child outcome, and post-push verification
  disagreement; and
- initial push, intentional recovery, interrupted recovery, and a request to
  retry after any ambiguous outcome.

The recovery permutations are:

- backend-native immutable version history with a documented restore operation,
  HCP's locked duplicate-as-new-current rollback, no native facility, and an
  unsupported/unknown backend;
- desired backup/current remote same or different lineage; desired backup
  older/equal/newer serial; format `4` or unknown; valid/invalid UTF-8/JSON/
  Terraform rendering; and current serial with/without a safe successor;
- unique top-level `serial` number, missing/duplicate/nested-only/noninteger
  serial, token at every stream-buffer boundary, and exact output-byte
  preservation outside that token;
- remote-versus-recovery semantic diff allowed/missing/extra/unknown/sensitive;
  and
- protected input/output identity, partial write, cleanup failure, remote drift
  after review, fresh confirmation mismatch, push failure, and verification
  failure.

Stakeholder perspectives:

- State owners need a rollback claim that is executable without disabling
  Terraform's lineage/serial protections.
- Concurrent operators and automation owners need one exclusion interval; a
  command-local lock does not protect the review gap and an equal concurrent
  serial could otherwise be overwritten.
- Incident responders need a backend-native fast path and a precise
  backend-agnostic fallback, but no automatic rollback during an unknown
  outcome.
- Security reviewers need the fallback to preserve all state bytes except the
  serial token and never emit state values.
- Peer reviewers need a second change record, diff, and confirmation for a
  recovery rather than treating it as a consequence of the first approval.
- Harness authors need deterministic normal, drift, overflow, token-boundary,
  interruption, and mutation-count fixtures.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| State-safety correctness | 30 | A false serial/rollback rule can silently replace the authoritative state. |
| Recovery validity | 24 | The advertised rollback must pass the retained lineage/serial checks. |
| Concurrency/serial closure | 18 | Equal serial and review-window races must be stopped. |
| Secret and byte integrity | 12 | Recovery construction processes the complete plaintext state. |
| Deterministic verification/tests | 9 | The destructive and recovery paths need reproducible proof. |
| Incident usability | 4 | Recovery must remain operable under pressure. |
| Scope and churn | 3 | Additional helper/workflow work matters only after correctness. |

### Scoring

| Option | Safety (30) | Recovery (24) | Concurrency (18) | Integrity (12) | Tests (9) | Usability (4) | Churn (3) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Exact next serial plus native/byte-splice recovery | 5 | 5 | 5 | 5 | 5 | 3 | 1 | **96.0** |
| B. Exact next serial plus native/vendor recovery only | 5 | 3 | 5 | 5 | 4 | 2 | 3 | 85.0 |
| C. Equal serial plus forced direct rollback | 1 | 2 | 1 | 2 | 2 | 4 | 4 | 33.2 |
| D. Equal serial plus unforced direct backup push | 1 | 1 | 1 | 3 | 1 | 4 | 5 | 29.6 |
| E. Generic JSON reserialization with a new serial | 3 | 4 | 4 | 2 | 4 | 3 | 2 | 67.2 |
| F. Arbitrary greater serial plus operator-edited recovery | 3 | 3 | 2 | 4 | 2 | 3 | 3 | 57.0 |
| G. Defer recovery while retaining push | 2 | 1 | 1 | 3 | 1 | 1 | 5 | 33.2 |

### Selected resolution: exact progression and a new reviewed state version

For ordinary manual push, T4 applies this closed progression:

1. Establish the already-required continuous writer-exclusion control before
   the authoritative pull and retain it through post-push verification. It must
   pause all human and automated writers and name its accountable owner. A
   lock acquired by only `terraform state pull` or `state push` is not described
   as protecting the gap.
2. Inspect current/proposed raw state with the selected helper and compare full
   SHA-256 first. Equal bytes return `no-change`, make zero push calls, and
   require no confirmation.
3. Unequal bytes with no approved semantic difference return
   `serialization-only-difference`.
4. Require supported raw format, identical nonempty lineage, and canonical
   nonnegative safe-integer serials. For changed content require exactly
   `proposedSerial = currentSerial + 1`. Lower, equal, skipped, or successor
   overflow returns `67`.
5. Bind the current/proposed serials and proposed digest into the reviewed
   report and confirmation, run one unforced push, and verify the fresh remote
   state. Any intervening drift, lost exclusion, unknown child outcome, or
   verification mismatch stops; it never retries or rolls back automatically.

The stricter “exactly next” repository rule makes skipped generations visible
and gives fixtures one oracle. It does not claim that Terraform itself rejects
all other greater values. Its safety depends on the continuous exclusion
premise; a command-local lock plus Terraform's “higher remote” test is not a
compare-and-swap on the reviewed digest.

#### Preferred backend-native recovery

Replace every “tested rollback command” promise with “tested reviewed recovery
procedure.” The first choice is the exact backend's documented immutable
state-version restore, verified in T2's provider-specific contract. The
procedure names the selected historical version, permissions, lock/exclusion
behavior, whether the service creates a new version, verification read, and
failure/ambiguous-outcome action. HCP Terraform specifically uses its documented
workspace-locked rollback that duplicates the chosen version as a new current
version. A provider/version combination without an implemented and tested
contract cannot be presented as a native recovery example.

Native recovery is still destructive. It requires a fresh incident/change
record, named operator and peer, current and desired version identities,
secret-safe reviewed difference, continuous exclusion, explicit confirmation,
one restore call, and fresh verification. The pre-push backup remains evidence;
it is not submitted directly.

#### Backend-agnostic recovery candidate

For a supported backend lacking native restore, add the dependency-free tracked
helper:

```text
.github/workflows/Prepare-TerraformStateRecovery.mjs
```

with version `Prepare-TerraformStateRecovery.v1` and this exact interface:

```text
node Prepare-TerraformStateRecovery.mjs
  --desired-backup DESIRED
  --fresh-remote CURRENT
  --output RECOVERY
  --report REPORT
```

There are no aliases, stdin, environment paths, arbitrary Terraform arguments,
network access, in-place mode, or force mode. All inputs/outputs use Finding
21's separately bound protected parent/path/attestation identities and Finding
22's raw-state limits. `RECOVERY` and `REPORT` must be fresh direct children.
The helper imports the same strict tokenizer/metadata projection rather than
adding a second permissive JSON parser.

The helper requires:

- both inputs are unchanged BOM-less UTF-8 raw-state format `4`, have one
  top-level nonempty `lineage`, one top-level canonical integer `serial`, pass
  complete strict JSON/token limits, and render under the pinned Terraform;
- desired/current lineage is byte-equal;
- `current.serial + 1` is a safe integer; and
- the continuously held exclusion and fresh-current identity are recorded by
  the caller before invocation.

It locates the unique top-level `serial` numeric token by parser byte offset,
opens a fresh protected output, copies every desired-backup byte before the
token, writes only the canonical decimal successor, and copies every byte after
the token. It does not parse/re-emit the state object. A second independent
stream comparison proves the candidate is byte-for-byte the desired backup
outside that one token, has the same lineage, has exactly the successor serial,
passes strict state/Terraform validation, and changed at least that token.
Partial output is removed only under exact owned-file cleanup proof; uncertain
output is retained and reported.

The compact report contains only schema/helper versions, whole-file SHA-256s,
lineage, desired/current/recovery serials, the old/new serial token byte
offset/length, byte counts, and `candidate-is-desired-except-serial`. It contains
no state value, resource/output identity, fragment, diagnostic, native command,
temporary path, or token-neighbor bytes.

The recovery caller then:

1. reviews fresh current remote versus `RECOVERY` using
   `Review-TerraformStateDifference.mjs` and a recovery-specific approved
   manifest; the prepare report proves that `RECOVERY` contains the desired
   backup content with only its metadata serial advanced;
2. pulls the authoritative state once more before confirmation and requires
   byte/digest/lineage/serial equality with `CURRENT`; any drift restarts review
   rather than regenerating or retrying in place;
3. displays a `state-recovery-push` confirmation binding workspace/backend,
   fresh-current serial, recovery serial, desired backup digest prefix, and
   recovery-candidate digest prefix;
4. executes exactly one normal `terraform state push -lock-timeout=5m
   <absolute-recovery-path>` with no force/bypass/stdin; and
5. pulls to a new path and verifies lineage, serial, candidate digest/content,
   expected diff, workspace/backend, and exclusion before release.

The ordinary diff helper's `serialization-only-difference` remains a failure;
only the prepare helper can certify the deliberate top-level serial splice.
The actual recovery diff is current-remote versus recovery-candidate and must
contain the intended content reversal.

Directly pushing the old backup, changing serial in an editor, full JSON
reserialization, `-force`, automatic recovery, automatic retry, or proceeding
after unknown outcome is prohibited. An unknown state format, serial overflow,
unavailable continuous exclusion, or inability to prepare/review the candidate
routes to backend-native recovery or vendor support.

Fixtures cover all progression classes; no-op and serialization-only states;
safe-integer boundaries; loss of exclusion and each remote-drift instant;
native rollback supported/unsupported/permission/lock/conflict/unknown/success;
both helper input identities; format/UTF-8/JSON/Terraform/lineage/serial errors;
missing/duplicate/nested serial; every token/buffer boundary; shorter/equal/
longer replacement token; exact preservation of all other bytes; protected
publication/cleanup failures; review and confirmation mismatch; push exit/
signal/unknown outcome; and post-recovery verification. Every failure proves
zero mutation calls; success proves one and preserves both original evidence
files.

## Finding 25 — T4 local-corruption hard linking lacks source-writer exclusion

### Problem to resolve

`SM-LOCAL-CORRUPTION` creates a second name for the source inode, validates that
name, and then unlinks the source. A process that already has the source open
for writing can alter the inode through the entire sequence and after source
unlink. A protected destination parent prevents destination namespace
competition; it does not revoke a source handle. The workflow needs a distinct
source-side exclusion premise and link-count/identity transitions, or it cannot
claim that the preserved bytes are stable.

### Exhaustive option and permutation inventory

The available designs are:

1. Retain no-replace hard-link publication, add a source-specific paused-writer
   attestation, and prove source/destination identity, link count, size, and
   digest before, during, and after source unlink.
2. Use a tracked `renameat2(RENAME_NOREPLACE)`-class helper plus the same
   writer attestation.
3. Use no-replace atomic rename without source-writer exclusion.
4. Retain the current hard-link procedure and infer safety from destination
   protection.
5. Copy to an exclusive-create destination, verify, and unlink source.
6. Treat `lsof`, an advisory `flock`, lock-file absence, or permission change
   as proof that no writer exists.
7. Refuse preservation and leave the corrupt source in place for a future
   manual procedure.

The source permutations are ordinary file, symlink/reparse/directory/device/
FIFO/socket, path with symlinked component, missing/replaced source, wrong
owner, owner-only or broader mode, zero/nonzero size, link count
`0|1|2|many`, and source/destination same/different device. Corrupt bytes need
not be valid JSON and an empty corrupt file can still be evidence; content
parsing is deliberately not a gate.

The writer permutations are:

- Terraform/local backend, editor, recovery tool, automation, unknown process,
  or no writer;
- writer opening before inspection, between any two checks, during link,
  during hashing, before/after unlink, and after successful return;
- access by source name, undisclosed preexisting hard-link name, destination
  name, or an already-open file description; and
- cooperative advisory-lock user, noncooperative user, privileged process, and
  a process invisible to a partial process-list tool.

The publication permutations are destination absent, ordinary/link/directory
entry present, competitor-created entry, link success/nonzero/ambiguous signal,
source mutation before or after link, source unexpectedly removed/replaced,
same/different inode at either name, expected link counts `1→2→1`, unexpected
counts, digest/size/mode/owner change, source unlink success/failure/unknown,
and signal at each ownership phase.

An atomic rename closes the two-name publication window but, like unlink, does
not invalidate a process's existing writable open description. It cannot serve
as the writer-exclusion alternative by itself. Copying has both source-change
and partial-copy windows. Advisory locks and process enumeration cannot prove
the absence of a noncooperating or invisible writer.

Stakeholder perspectives:

- Incident responders need at least one name retained even when corruption
  preservation fails halfway.
- State owners need an explicit operational pause covering Terraform,
  automation, editors, and recovery tools, not a claim inferred from a
  destination ACL.
- Security reviewers need exact owner/mode/type/link checks and no corrupt
  state bytes in diagnostics.
- Cross-platform maintainers need the existing Bash/GNU contract to fail
  clearly on unsupported filesystems rather than silently switch primitives.
- Harness authors need a controllable writer process and barriers at every
  identity/hash/link/unlink phase.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| Source-byte immutability premise | 30 | The preserved name is useless if an extant writer can keep changing it. |
| No-loss/no-clobber behavior | 24 | Failure must retain at least one known name and never replace destination. |
| Identity/race closure | 18 | Type, inode, owner, mode, link, and digest transitions establish what was moved. |
| Deterministic verification/tests | 12 | Writer timing and publication failures require barrier-driven proof. |
| Supported-platform clarity | 7 | The example must not imply primitives/filesystems it did not test. |
| Operator usability | 5 | The pause and outcome must be understandable during recovery. |
| Scope and churn | 4 | Reusing the existing publication path reduces change, after safety. |

### Scoring

| Option | Immutability (30) | No loss (24) | Identity (18) | Tests (12) | Platform (7) | Usability (5) | Churn (4) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Hard link plus source attestation/transitions | 5 | 5 | 5 | 5 | 4 | 3 | 3 | **95.0** |
| B. No-replace rename plus source attestation | 5 | 4 | 5 | 4 | 2 | 4 | 2 | 85.2 |
| C. No-replace rename alone | 2 | 4 | 3 | 3 | 2 | 4 | 2 | 57.6 |
| D. Current hard link/destination protection | 1 | 4 | 3 | 3 | 4 | 4 | 5 | 56.8 |
| E. Exclusive-create copy then unlink | 2 | 4 | 2 | 3 | 4 | 3 | 4 | 57.4 |
| F. `lsof`/advisory-lock/permission heuristic | 3 | 4 | 4 | 3 | 2 | 3 | 3 | 67.0 |
| G. Leave corrupt source in place | 3 | 2 | 4 | 2 | 5 | 2 | 5 | 59.8 |

### Selected resolution: source exclusion plus `1→2→1` hard-link proof

Retain GNU hard-link publication because it creates the destination without
overwrite and retains the source name until destination verification. Add a
separate source role to the common identity model:

```text
LOCAL_CORRUPTION_SOURCE_PARENT
LOCAL_CORRUPTION_SOURCE
LOCAL_CORRUPTION_SOURCE_ATTESTATION
```

`SOURCE` is an absolute, canonical, direct child of the separately snapshotted
`SOURCE_PARENT`; neither is inferred from the destination role. The exact
required literal is:

```text
terraform-paused-no-open-state-writers-v1
```

Before accepting that literal, the copyable prose instructs the accountable
operator to stop and verify all Terraform commands, local-backend automation,
CI agents, editors, recovery utilities, scheduled tasks, and other processes
that could have the source inode open for writing, and to prevent new source
writers until success/failure handoff. The literal is an operator attestation,
not a machine-derived fact. Absence of `.terraform.tfstate.lock.info`, `lsof`
output, advisory lock acquisition, `chmod`, parent protection, or a quiet
interval cannot substitute for it. The destination retains its separate
`private-outside-vcs-no-competing-writers` parent attestation.

The positive path is one state machine:

1. Snapshot all six source/destination parent/path/attestation values once and
   validate their closed grammar before touching either state path.
2. Require the source parent and leaf have canonical no-symlink paths; the
   leaf is an existing ordinary non-link file directly owned by the current
   UID, mode `0600`, and link count exactly `1`. Record
   `(device,inode,uid,mode,nlink,size)` and SHA-256 without printing bytes.
   Size zero is permitted because this is corruption evidence.
3. Require the destination parent contract, direct fresh destination leaf, no
   entry under either existence or link tests, same device as source, and GNU
   `ln` capability already proven by the implementation tests.
4. Recheck source tuple/link count/digest and destination absence immediately
   before exactly one:

   ```text
   ln --no-target-directory -- "$LOCAL_CORRUPTION_SOURCE" "$DESTINATION"
   ```

   Do not use force, backup, interactive, logical-following, fallback,
   alternate name, copy, or retry.
5. After zero exit, inspect both paths without following links. Require
   ordinary files with the original device/inode/uid/mode/size, link count
   exactly `2` at both names, and both complete SHA-256 values equal the
   original. Recheck the same tuple/digests once more immediately before
   source unlink.
6. Unlink only the exact still-proven source name once. Reopen the destination
   no-follow and require the original device/inode/uid/mode/size, link count
   exactly `1`, and unchanged digest. Only this reaches `preserved`.
7. Release the source-writer exclusion only after the operator receives the
   final destination identity/digest and source-absent postcondition.

Every observation is obtained under `LC_ALL=C` through the issue's reviewed
identity routine and compared as structured fields; localized `ls` output is
not parsed. The routine never validates or displays corrupt state content.

If failure occurs before link creation, destination must remain absent and the
source remains. Once a link may exist, failure never deletes either remaining
name: report fixed categories plus safe path labels, observed identities/link
counts/digests, and require incident inspection. If source unlink outcome is
ambiguous, retain destination and report both path states. A digest/identity
change is an attestation breach, not permission to “refresh” the expected
digest. Signals use the existing phase owner: before link proves zero publish
calls; after link retains all names/evidence and does not resume automatically.

No-replace rename remains an implementation alternative only if a later issue
names a tested platform primitive and retains the same source-writer
attestation: rename does not revoke open file descriptions. It is not a
fallback inside this block.

Fixtures cover every source/parent/destination type and identity field;
link-count `0|1|2|many`; same/different device; empty and nonempty bytes;
destination conflict types; writer mutation/open before and at each barrier;
source removal/replacement; link and unlink nonzero/signal/unknown outcomes;
each tuple/digest mismatch; exact `1→2→1` success; unsupported GNU/filesystem
behavior; cleanup/retention; and HUP/INT/TERM at every phase. Each row proves
one status/reason, source/destination existence and identity, link counts,
digests, operation counts, no state bytes in output/artifacts, and at least one
remaining name whenever publication began.

## Finding 26 — T4 stable-ID tables group multiple cases

### Problem to resolve

T4 rejects grouped harness results but its own stable rows contain disjunctive
setups and outcomes. The shared confirmation and T2-derived signal contracts
promise many permanent cases without assigning IDs at all. A failed result
cannot be traced to one fixture, injection point, status, call count, and
filesystem oracle until the catalog is atomic and closed.

### Exhaustive option and permutation inventory

The available designs are:

1. Add one checked-in machine-readable case catalog, narrow each grouped
   existing ID to its first case, append an ID for every other case, and give
   confirmation/signal/address helpers their own literal families.
2. Split only the Markdown tables and keep independent unvalidated metadata in
   each harness.
3. Generate case IDs dynamically from runtime parameter combinations.
4. Keep one existing ID and emit several named subresults beneath it.
5. Renumber all tables into a new visually contiguous sequence.
6. Put the detailed IDs in an external test-management system.
7. Defer the split until implementation while keeping the disjunctive issue
   rows.

The independent case dimensions are:

- Bash backup path class, captured-byte class, metadata property, publication,
  substitution, cleanup, signal, and expected state;
- PowerShell edition, native process outcome, raw stream boundary, encoding,
  reparse/final class, publication, cleanup, and expected state;
- confirmation operation/serializer input, terminal adapter, delivered byte
  class/framing/length, signal, and caller/platform cell;
- local-corruption source/destination type, source exclusion, identity/link
  transition, injected writer/unlink outcome, and retention;
- push identity/diff/progression/exclusion/confirmation/provider/lock/recovery/
  verification outcome and destructive-call count;
- rm address/backup/concurrency/dry-run/confirmation/mutation/verification
  outcome and call count; and
- for each Bash marker phase, HUP/INT/TERM crossed with cleanup success/failure.

The result dimensions are also independent: one primary status, one closed
reason, one phase, cleanup count, each owned-path postcondition, child/remote
call count, remote sentinel/outcome, and secret-canary scan. Combining two
setups merely because they share a status is still a grouped row.

Stakeholder perspectives:

- Maintainers need append-only evidence that survives future case additions.
- Reviewers need an issue table and executable inventory that refer to the
  exact same case.
- CI investigators need one failure to identify one input and one oracle.
- Cross-platform maintainers need a common helper case to emit one result per
  applicable OS/PowerShell cell without duplicating semantic IDs.
- Audit consumers need missing, duplicate, unexpected, skipped, and multiply
  emitted `(ID,cell)` results to be distinguishable.
- Test authors need shared fixture functions without hiding multiple assertions
  behind one reported case.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| Audit traceability | 26 | A stable ID must resolve to exactly one setup and result. |
| Oracle precision | 22 | Status alone is insufficient; phase/calls/filesystem must be singular. |
| Required-case completeness | 20 | Confirmation and signal promises need an exact finite catalog. |
| Append-only stability | 14 | Existing evidence IDs cannot be renumbered or silently broadened. |
| Cross-platform result identity | 10 | Shared semantics still need per-cell execution results. |
| Catalog maintainability | 5 | Large matrices need structural validation and reusable fixture code. |
| Scope and churn | 3 | A shared catalog is additional surface but prevents drift. |

### Scoring

| Option | Trace (26) | Oracle (22) | Complete (20) | Stable (14) | Parity (10) | Maintain (5) | Churn (3) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Checked-in atomic catalog and append-only splits | 5 | 5 | 5 | 5 | 5 | 4 | 2 | **97.2** |
| B. Split Markdown only | 4 | 5 | 4 | 5 | 4 | 3 | 3 | 85.6 |
| C. Runtime-generated IDs | 3 | 4 | 5 | 2 | 5 | 4 | 4 | 75.2 |
| D. Group ID with several subresults | 3 | 3 | 4 | 4 | 4 | 4 | 5 | 71.0 |
| E. Renumber every table | 4 | 5 | 5 | 1 | 5 | 4 | 2 | 80.8 |
| F. External test-management inventory | 2 | 3 | 3 | 1 | 3 | 2 | 4 | 48.8 |
| G. Defer split | 1 | 1 | 1 | 4 | 1 | 3 | 5 | 32.8 |

### Selected resolution: one literal catalog row per result

Add `.github/workflows/StateRecoveryCaseCatalog.json`, canonical BOM-less UTF-8
JSON with schema `TerraformStyleGuide.StateRecoveryCaseCatalog.v1`. Each case
object has exactly:

```text
id
surface
applicableCells
fixture
phase
expectedStatus
expectedReason
expectedCleanupCount
expectedCalls
expectedPathState
expectedRemoteState
canaryOracle
```

`fixture`, `phase`, and every expected field are one closed scalar/object, not
an `or`, slash-list, regular expression, array of alternatives, or prose
disjunction. `applicableCells` only states where the identical semantic case
runs; every applicable `(id,cell)` still emits one independent result. A shared
fixture function may be called by many rows but cannot emit, loop over, or
aggregate their results.

The Bash, PowerShell, confirmation, state-inspection/diff, and address harnesses
load the same catalog and reject missing, duplicate, unexpected, inapplicable,
skipped-without-reason, or multiply emitted `(id,cell)` keys. A structural
validator compares exact catalog IDs with the issue tables, source marker
inventory, harness dispatch inventory, result set, and workflow cells.
Catalog/schema changes land atomically with all consumers.

#### Existing grouped IDs

Keep the first listed subcase under the existing number and append after that
family's old maximum:

| Existing family | Preserved/narrowed ID | Appended atomic IDs |
| --- | --- | --- |
| Bash backup path | `SM-BASH-BACKUP-06` = relative path | `SM-BASH-BACKUP-16` = absolute path outside attested parent |
| Bash backup bytes | `SM-BASH-BACKUP-09` = invalid JSON | `SM-BASH-BACKUP-17` = leading UTF-8 BOM |
| Bash backup metadata | `SM-BASH-BACKUP-11` = missing lineage | `SM-BASH-BACKUP-18` malformed lineage; `19` missing serial; `20` malformed serial |
| PowerShell captured bytes | `SM-PS-BACKUP-06` = zero/empty | `SM-PS-BACKUP-21` = zero/truncated JSON |
| PowerShell reparse final | `SM-PS-BACKUP-09` = live reparse final | `SM-PS-BACKUP-22` = dangling reparse final |
| PowerShell cleanup | `SM-PS-BACKUP-10` = cleanup substitution | `SM-PS-BACKUP-23` = cleanup operation failure |
| Push confirmation | `SM-BASH-PUSH-07` = valid-grammar unequal confirmation | `SM-BASH-PUSH-12` empty; `13` wrong case; `14` nonhex; `15` short; `16` long; `17` extra text |
| Push execution | `SM-BASH-PUSH-08` = Terraform safety rejection | `SM-BASH-PUSH-18` lock failure; `19` provider/tool failure |
| Rm address | `SM-BASH-RM-02` = empty address | `SM-BASH-RM-11` control byte; `12` syntactically valid broad address |
| Rm prerequisites | `SM-BASH-RM-03` = workspace mismatch | `SM-BASH-RM-13` backend mismatch; `14` backup invalid; `15` concurrency/exclusion invalid |
| Rm confirmation | `SM-BASH-RM-07` = valid-grammar unequal confirmation | `SM-BASH-RM-16` bad digest prefix |
| Rm verification | `SM-BASH-RM-10` = post-state mismatch | `SM-BASH-RM-17` post-plan mismatch |

The numeric-only abbreviations `19`, `20`, and so on in this explanatory table
mean the full prefix in that row; the actual issue and JSON catalog always
spell the complete ID.

Earlier selected resolutions add these atomic rows rather than folding them
back into a generic rejection:

- `SM-BASH-CORR-07` wrong source-writer attestation;
  `SM-BASH-CORR-08` source owner; `09` source mode; `10` initial link count;
  `11` writer mutation before link; `12` writer mutation after link; `13`
  post-link identity/count; `14` source-unlink uncertainty; and `15` final
  `1→2→1` postcondition.
- `SM-BASH-PUSH-20` equal-serial changed content; `21` skipped serial; `22`
  exact-next serial; `23` byte-identical no-op; `24` serialization-only; `25`
  serial overflow; `26` native recovery; `27` prepared-candidate recovery;
  `28` direct old-backup rejection; and `29` remote drift before recovery
  confirmation.

As above, the checked-in catalog spells each full prefix.

#### Shared confirmation IDs

The following mapping is exact and append-only:

| ID | One fixture/oracle |
| --- | --- |
| `SM-CONFIRM-01` | canonical push serialization |
| `SM-CONFIRM-02` | canonical rm serialization with singleton address |
| `SM-CONFIRM-03` | canonical JSON escaping of a supported string-key address |
| `SM-CONFIRM-04` | serial zero accepted |
| `SM-CONFIRM-05` | maximum safe serial accepted |
| `SM-CONFIRM-06` | leading-zero serial rejected |
| `SM-CONFIRM-07` | negative serial rejected |
| `SM-CONFIRM-08` | over-safe-integer serial rejected |
| `SM-CONFIRM-09` | lowercase 64-hex digest accepted |
| `SM-CONFIRM-10` | uppercase digest normalized by serializer |
| `SM-CONFIRM-11` | nonhex digest rejected |
| `SM-CONFIRM-12` | 63-character digest rejected |
| `SM-CONFIRM-13` | 65-character digest rejected |
| `SM-CONFIRM-14` | serialized expected payload exactly 4,096 bytes accepted |
| `SM-CONFIRM-15` | serialized expected payload 4,097 bytes rejected before terminal open |
| `SM-CONFIRM-16` | redirected stdin containing a match is ignored |
| `SM-CONFIRM-17` | controlling terminal absent |
| `SM-CONFIRM-18` | opened endpoint is not a TTY/console |
| `SM-CONFIRM-19` | terminal open failure |
| `SM-CONFIRM-20` | terminal write failure |
| `SM-CONFIRM-21` | terminal read failure |
| `SM-CONFIRM-22` | raw-mode change failure |
| `SM-CONFIRM-23` | terminal-mode restore failure |
| `SM-CONFIRM-24` | descriptor/stream close uncertainty |
| `SM-CONFIRM-25` | exact match terminated by LF |
| `SM-CONFIRM-26` | exact match terminated by CR |
| `SM-CONFIRM-27` | exact match terminated by CRLF |
| `SM-CONFIRM-28` | EOF before terminator |
| `SM-CONFIRM-29` | empty terminated payload |
| `SM-CONFIRM-30` | same-length byte mismatch |
| `SM-CONFIRM-31` | wrong-case delivered payload |
| `SM-CONFIRM-32` | leading whitespace |
| `SM-CONFIRM-33` | trailing whitespace |
| `SM-CONFIRM-34` | NUL byte |
| `SM-CONFIRM-35` | UTF-8 BOM |
| `SM-CONFIRM-36` | UTF-16LE BOM |
| `SM-CONFIRM-37` | UTF-16BE BOM |
| `SM-CONFIRM-38` | stray UTF-8 continuation |
| `SM-CONFIRM-39` | missing UTF-8 continuation |
| `SM-CONFIRM-40` | two-byte overlong UTF-8 |
| `SM-CONFIRM-41` | three-byte overlong UTF-8 |
| `SM-CONFIRM-42` | UTF-8 surrogate |
| `SM-CONFIRM-43` | scalar above U+10FFFF |
| `SM-CONFIRM-44` | truncated two-byte sequence |
| `SM-CONFIRM-45` | truncated three-byte sequence |
| `SM-CONFIRM-46` | truncated four-byte sequence |
| `SM-CONFIRM-47` | premature CR terminator |
| `SM-CONFIRM-48` | premature LF terminator |
| `SM-CONFIRM-49` | same-chunk second record |
| `SM-CONFIRM-50` | next-poll-turn queued second record |
| `SM-CONFIRM-51` | delivered payload exactly 4,095 bytes |
| `SM-CONFIRM-52` | delivered payload exactly 4,096 bytes |
| `SM-CONFIRM-53` | delivered byte 4,097 overflow |
| `SM-CONFIRM-54` | HUP during terminal read, restored status 129 |
| `SM-CONFIRM-55` | INT during terminal read, restored status 130 |
| `SM-CONFIRM-56` | TERM during terminal read, restored status 143 |
| `SM-CONFIRM-57` | wrong operation field |
| `SM-CONFIRM-58` | wrong workspace field |
| `SM-CONFIRM-59` | wrong backend field |
| `SM-CONFIRM-60` | wrong resource-address field |
| `SM-CONFIRM-61` | wrong serial field |
| `SM-CONFIRM-62` | wrong digest-prefix field |
| `SM-CONFIRM-63` | malformed delivered JSON escape |
| `SM-CONFIRM-64` | unescaped delivered address quote |
| `SM-CONFIRM-65` | invalid delivered address backslash |

Input-classification rows use the pure Buffer seam on every cell; terminal
adapter rows additionally use a real Ubuntu pseudo-terminal and real Windows
console on PowerShell 5.1 and 7 where applicable. The result key includes the
cell, but IDs do not acquire edition suffixes.

#### Literal T4 Bash signal IDs

Signal IDs have the exact form:

```text
SM-BASH-SIGNAL-<PHASE>-<SIGNAL>-<CLEANUP>
```

The allowed suffix pairs are exactly
`HUP-OK`, `HUP-FAIL`, `INT-OK`, `INT-FAIL`, `TERM-OK`, and `TERM-FAIL`.
They mean injected signal/status `129|130|143` and cleanup result; cleanup
failure never replaces the signal status.

The exact phase tokens, each expanded with all six literal suffix pairs in the
static JSON catalog, are:

| Marker | Phase tokens |
| --- | --- |
| `SM-BACKUP-PULL` | `BACKUP-PRECREATE`, `BACKUP-PULL-PARTIAL`, `BACKUP-VALIDATED`, `BACKUP-PUBLISH-UNCERTAIN` |
| `SM-LOCAL-CORRUPTION` | `CORR-PRELINK`, `CORR-LINK-UNCERTAIN`, `CORR-PREUNLINK`, `CORR-UNLINK-UNCERTAIN` |
| `SM-STATE-PUSH` | `PUSH-PRECONFIRM`, `PUSH-CONFIRM-READ`, `PUSH-PREPUSH`, `PUSH-REMOTE-UNKNOWN`, `PUSH-VERIFY` |
| `SM-STATE-RM` | `RM-PREDRYRUN`, `RM-DRYRUN`, `RM-PRECONFIRM`, `RM-CONFIRM-READ`, `RM-PRERM`, `RM-REMOTE-UNKNOWN`, `RM-VERIFY` |

For example, the first phase expands to the six distinct literal IDs
`SM-BASH-SIGNAL-BACKUP-PRECREATE-HUP-OK`,
`...-HUP-FAIL`, `...-INT-OK`, `...-INT-FAIL`, `...-TERM-OK`, and
`...-TERM-FAIL`; ellipses are never stored in the issue/catalog. The closed
18-phase × 6-suffix product contains exactly 108 catalog rows and 108 emitted
results. The structural validator constructs the expected product independently
and compares literal equality, so omission or a spelling collision fails.

Pre-destructive phases require destructive call count `0` and unchanged remote
sentinel. `PUSH-REMOTE-UNKNOWN` and `RM-REMOTE-UNKNOWN` require one started
child, remote outcome `unknown`, retained evidence, and no retry/force/unlock/
automatic rollback. Verification phases use `unverified-after-return`, retain
evidence, and also prohibit retry/rollback. Backup/corruption publication
uncertainty follows each selected ownership policy. Every row records cleanup
count exactly `1`, exact status/reason/path state, and canary absence.

Finding 27 supplies the exact `SM-ADDRESS-*` mapping; this finding reserves the
separate family and prohibits hiding address cases under `SM-BASH-RM-02`.

Validation intentionally fails when a catalog row includes slash-separated or
`or` fixture/oracle text; when an existing ID is missing or broadened; when one
ID emits two results; when one applicable cell omits a result; or when a signal
product row has the wrong status, cleanup count, path state, child count, or
remote sentinel. A human-readable summary may group passing counts only after
all atomic result records have been validated.

## Finding 27 — T4 exact resource-address narrowing is undefined

### Problem to resolve

`RESOURCE_ADDRESS` is passed as one quoted argument, but T4 never defines an
executable grammar or proves that the address denotes one instance. Terraform
addresses intentionally include module-wide and resource-wide patterns, and a
resource without an index can match every `count`/`for_each` instance. String
keys legitimately contain quotes and escapes. A shell regex cannot safely
equate “quoted once” with “one exact instance,” and localized
`state rm -dry-run` prose is not a structured count interface.

### Exhaustive option and permutation inventory

The available designs are:

1. Add a tracked byte parser for a documented canonical subset, then require
   pinned Terraform's bounded `state list ADDRESS` match set to be exactly the
   same one canonical address before accepting `state rm -dry-run`.
2. Use Terraform's `state list` exact match alone, with no documented lexical
   subset/parser shared by confirmation.
3. Accept/reject addresses with a Bash regular expression alone.
4. Count resource names by parsing `state rm -dry-run` human-readable output.
5. Require an explicit integer-indexed root resource and reject string keys,
   data resources, nested modules, and singleton resources.
6. Parse the full configuration/module graph to prove `count`/`for_each`
   cardinality before consulting state.
7. Keep one quoted argument and defer grammar/match semantics to implementation.

The syntax permutations are:

- empty, control, BOM, non-ASCII, whitespace around the address, leading dash,
  wildcard/splat, trailing token, incomplete delimiter, and over-limit bytes;
- root/nested module path; module-only path; singleton module; multi-instance
  module with omitted/integer/string index; and repeated module steps;
- managed/data resource, valid/invalid type/name identifier, resource-only
  versus resource-instance address, and unexpected extra address argument;
- integer `0`, positive, leading zero, negative, sign, decimal/exponent,
  maximum safe, overflow, missing bracket, and extra bracket;
- simple quoted string key, space/punctuation, embedded quote, embedded
  backslash, empty/over-limit key, malformed escape, noncanonical Unicode
  escape, decoded control, non-ASCII, and unterminated string; and
- canonical versus alternate-but-Terraform-valid spelling outside the selected
  subset.

The match permutations are zero, one byte-equal canonical instance, one
different canonical instance, two/many instances, module descendants, missing
multi-instance index, malformed/over-limit/stdout-without-final-LF, stderr,
Terraform nonzero/signal/timeout, and first/second match-set drift. Dry-run can
succeed/fail/timeout and emit any locale/version prose; only its exit and
resource/address-independent bounded execution contract are consumed.

The workflow permutations are declarative `removed` alternative, supported
address rejected by reviewed manifest, exact reviewed match, continuous
exclusion absent/lost, dry-run, confirmation mismatch, repeat-match drift,
mutation failure/unknown/success, and post-state/plan verification.

Stakeholder perspectives:

- Operators need normal singleton, `count`, `for_each`, data, and nested-module
  addresses without shell-escape folklore.
- State owners need proof that one and only one current instance will be
  forgotten.
- Security reviewers need no eval, glob expansion, option injection, control
  byte, or unreviewed state-derived address in confirmation/evidence.
- Terraform maintainers need Terraform—not a repository regex—to remain the
  semantic authority for parsing/matching the pinned version.
- Cross-platform helper maintainers need one parser/serializer used by address
  resolution and typed confirmation.
- Harness authors need exact syntax, canonicalization, match-count, drift, and
  argv fixtures.

### Finding-specific weighted rubric

Scoring is 1–5, with 5 best. Weighted result is `weight × score / 5`.

| Criterion | Weight | Why it matters here |
| --- | ---: | --- |
| Exact-one-instance guarantee | 30 | `state rm` removes every match, so cardinality is the core boundary. |
| Parser/canonical correctness | 22 | Integer/string/module syntax and escaping must be unambiguous. |
| Terraform semantic authority | 18 | Repository parsing cannot know current state cardinality by itself. |
| Injection/display safety | 12 | The address crosses shell argv, terminal confirmation, and evidence. |
| Concurrency/drift closure | 8 | The proved match must remain current through mutation. |
| Deterministic fixtureability | 7 | Syntax/match/dry-run cases need one stable result each. |
| Operator usability | 2 | Legitimate common exact addresses should work. |
| Scope and churn | 1 | One small parser is acceptable after destructive safety. |

### Scoring

| Option | Exact one (30) | Parser (22) | Terraform (18) | Safety (12) | Drift (8) | Tests (7) | Usability (2) | Churn (1) | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A. Tracked subset parser plus exact Terraform match set | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 2 | **99.0** |
| B. Terraform match set only | 5 | 3 | 5 | 3 | 5 | 4 | 4 | 4 | 84.4 |
| C. Bash regex only | 2 | 2 | 1 | 4 | 4 | 4 | 5 | 5 | 49.0 |
| D. Parse dry-run prose | 3 | 2 | 3 | 3 | 4 | 2 | 3 | 4 | 56.0 |
| E. Integer-indexed root subset only | 4 | 3 | 2 | 5 | 4 | 4 | 1 | 4 | 69.6 |
| F. Full configuration/cardinality parser | 5 | 4 | 4 | 4 | 4 | 2 | 2 | 1 | 81.8 |
| G. Defer grammar/matching | 1 | 1 | 1 | 2 | 2 | 1 | 2 | 5 | 25.2 |

### Selected resolution: canonical subset plus Terraform-produced singleton

Add the dependency-free tracked helper:

```text
.github/workflows/Resolve-TerraformStateAddress.mjs
```

versioned `Resolve-TerraformStateAddress.v1`. It exports the pure
`parseCanonicalResourceAddress(Buffer)` function; both its production resolver
and `Confirm-StateMutation.mjs` import that exact function. Its production
interface is:

```text
node Resolve-TerraformStateAddress.mjs
  --address RESOURCE_ADDRESS
  --matches MATCH_FILE
  --output REPORT
```

Every option occurs once in that order. There are no aliases, stdin, environment
fallbacks, network calls, command strings, Terraform execution, multiple
addresses, permissive mode, or normalization mode. The address is an already
reviewed nonsecret identifier and may be present in argv. Match/report files
use their separately validated protected parent/path/attestation roles.

#### Supported canonical syntax

Parse raw ASCII bytes with a small deterministic lexer/recursive-descent parser,
not a shell regex:

```text
address       := module-step* resource-spec
module-step   := "module." identifier instance-key? "."
resource-spec := "data."? identifier "." identifier instance-key?
instance-key  := "[" (integer-index | quoted-key) "]"
```

The closed limits/rules are:

- the complete address is 1–2,048 raw bytes; it contains only ASCII and no
  control/DEL, leading/trailing whitespace, NUL/BOM, wildcard/splat, or extra
  token;
- there are at most 64 module steps;
- `identifier` is `[A-Za-z_][A-Za-z0-9_-]{0,127}`. This is intentionally
  narrower than Terraform's Unicode identifier language;
- `integer-index` is canonical `0|[1-9][0-9]*`, parsed without floating-point
  rounding and bounded to `9007199254740991`; signs, leading zeros, decimal,
  exponent, and overflow are rejected;
- `quoted-key` is one strict JSON/HCL-compatible quoted string. Decode it with
  the helper's strict string parser, require 1–128 decoded ASCII bytes, require
  alphanumeric/underscore endpoints, and allow internally only ASCII
  alphanumeric, underscore, dot, hyphen, tilde, colon, slash, at, percent,
  plus, equals, comma, space, double quote, and backslash. Controls and
  non-ASCII are rejected; and
- serialize a decoded key once with `JSON.stringify` and require byte equality
  with the original token. Thus necessary `\"` and `\\` are supported, while
  unnecessary/alternate escapes, decoded control characters, and normalization
  are rejected.

The parser requires a terminal resource spec, so `module.foo` is not in the
supported subset. It permits an omitted module/resource index because a
singleton configuration legitimately has no index. Omission does not imply
singularity; the Terraform match-set check below proves it. Managed and data
resource instances, nested singleton/multi-instance modules, integer keys, and
canonical string keys are supported.

Successful parse returns one immutable structure of segment types, decoded
keys/integers, and the exact canonical address. It never evaluates HCL,
configuration, templates, shell text, or arbitrary expressions. Failure emits
only a fixed reason and safe byte count, not rejected input.

#### Terraform-produced exact match set

Under the already pinned Terraform executable, exact configuration root,
initialized workspace/backend, credential phase, and continuously held writer
exclusion, the Bash caller runs exactly one address argument:

```text
terraform state list "$RESOURCE_ADDRESS"
```

It uses Finding 22's shell-free bounded collector to a fresh protected
`MATCH_FILE`, with stdout maximum 65,536 bytes, maximum 1,024 LF-terminated
records, each maximum 2,048 bytes, strict BOM-less UTF-8/ASCII, stderr maximum
65,536 bytes drained but never emitted, and the normal timeout. Nonzero,
signal, timeout, nonempty stderr, CR, empty record, missing final LF, parser/
limit error, or cleanup uncertainty stops.

The resolver first parses `RESOURCE_ADDRESS`, then requires the complete match
file bytes equal exactly:

```text
RESOURCE_ADDRESS + LF
```

and parses that one line independently to the same canonical structure. This
single equality is the cardinality/canonicalization oracle:

- zero matches is empty, not equal;
- several instances produce several lines, not equal;
- a module-wide address produces descendant resource addresses, not equal;
- an omitted index on a multi-instance resource/module produces indexed
  address lines, not equal; and
- a noncanonical spelling cannot equal Terraform's one canonical output.

The accepted address must also equal one safe reviewed subject address in the
Finding 23 manifest. The report contains only schema/helper versions,
Terraform/config/workspace/backend identities already approved, canonical
address, address SHA-256, `matchCount:1`, match-set SHA-256, and
`outcome:"exact-singleton"`. It contains no object ID/value, provider
diagnostic, unreviewed address, or match fragment. The protected match file is
not evidence and is removed only under exact cleanup proof.

Run `terraform state rm -dry-run "$RESOURCE_ADDRESS"` with the same exact
single argument and bounded raw capture. Require start/exit zero and an empty
bounded stderr, but never parse/count/grep the localized stdout. The trusted
singleton oracle is `state list`, not dry-run prose. After dry-run/review and
before confirmation, repeat state-list capture/resolution to a new path and
require byte/digest/report equality. Loss of exclusion or any drift stops.

Typed confirmation consumes the shared parser and binds the exact canonical
address plus current backup digest. After success the caller executes exactly:

```text
terraform state rm -lock-timeout=5m "$RESOURCE_ADDRESS"
```

with one address argv element, closed stdin, no glob/eval/word splitting,
`-lock=false`, force, ignore-version, retry, or additional address. It then
performs the selected protected post-state and plan verification. The
continuous exclusion is the premise that closes the last check-to-mutation
gap; the issue does not call state-list equality a remote compare-and-swap.

#### Atomic address IDs

Add these full catalog rows:

| ID | One fixture/oracle |
| --- | --- |
| `SM-ADDRESS-01` | empty input |
| `SM-ADDRESS-02` | control/NUL pure-buffer input |
| `SM-ADDRESS-03` | non-ASCII input |
| `SM-ADDRESS-04` | address byte 2,049 |
| `SM-ADDRESS-05` | module-only address |
| `SM-ADDRESS-06` | root multi-instance resource with omitted index |
| `SM-ADDRESS-07` | multi-instance module with omitted module index |
| `SM-ADDRESS-08` | singleton root managed resource accepted |
| `SM-ADDRESS-09` | singleton nested-module resource accepted |
| `SM-ADDRESS-10` | integer index zero accepted |
| `SM-ADDRESS-11` | maximum-safe integer index accepted |
| `SM-ADDRESS-12` | leading-zero integer rejected |
| `SM-ADDRESS-13` | negative integer rejected |
| `SM-ADDRESS-14` | integer overflow rejected |
| `SM-ADDRESS-15` | simple string key accepted |
| `SM-ADDRESS-16` | embedded-quote string key accepted canonically |
| `SM-ADDRESS-17` | embedded-backslash string key accepted canonically |
| `SM-ADDRESS-18` | noncanonical Unicode escape rejected |
| `SM-ADDRESS-19` | decoded control escape rejected |
| `SM-ADDRESS-20` | empty string key rejected |
| `SM-ADDRESS-21` | decoded key byte 129 rejected |
| `SM-ADDRESS-22` | malformed/unterminated quoted key |
| `SM-ADDRESS-23` | malformed/missing bracket |
| `SM-ADDRESS-24` | wildcard/splat rejected |
| `SM-ADDRESS-25` | trailing token rejected |
| `SM-ADDRESS-26` | exact data-resource instance accepted |
| `SM-ADDRESS-27` | zero Terraform matches |
| `SM-ADDRESS-28` | two Terraform matches |
| `SM-ADDRESS-29` | one non-equal canonical match |
| `SM-ADDRESS-30` | malformed match-file framing |
| `SM-ADDRESS-31` | match-file limit overflow |
| `SM-ADDRESS-32` | state-list nonzero/signal is one tool-failure fixture |
| `SM-ADDRESS-33` | state-list nonempty stderr |
| `SM-ADDRESS-34` | dry-run nonzero |
| `SM-ADDRESS-35` | exact first match followed by repeated-match drift |
| `SM-ADDRESS-36` | exact singleton through one exact mutation argv |

Additional parser error classes receive appended IDs rather than being folded
into `22` or `23`. Each failure proves confirmation/rm call count `0`; positive
resolver cases prove exact report/address/match bytes; `36` proves one dry-run,
one confirmation, one mutation, exact NUL-delimited argv, protected backup
inventory, and post-verification. Canary scans include address shell
metacharacters only where the supported decoded-key grammar allows them and
prove no shell evaluation.
