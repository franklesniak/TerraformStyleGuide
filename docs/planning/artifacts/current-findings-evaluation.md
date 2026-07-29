# Evaluation of open TerraformStyleGuide findings

## Review controls

This evaluation covers every open TerraformStyleGuide finding in
`current-findings.md`, in recorded order. Each section is completed before the
next finding is considered. Every finding has its own option set, weighted
rubric, scoring table, and implementation-ready selection.

Scores run from 0 (unacceptable) through 5 (excellent). Unless a section says
otherwise, weighted totals use
`sum(weight × score ÷ 5)` and have a maximum of 100. Rubrics are deliberately
finding-specific. Technical correctness, security, and real usability carry
more weight than churn, drafting convenience, or preserving an issue boundary
for its own sake.

## T1-1 — Replace the EOL installed Node target coherently

### Problem statement

T1 correctly distinguishes the Node runtime embedded in an action from the
Node version that `setup-node` installs for repository Markdown tooling.
However, it freezes the latter at Node 20, prohibits changing it, assigns the
eventual runtime policy to a later npm issue, and orders that issue after T2.
Node 20 is now EOL. The installed lint packages both declare Node `>=20`, so a
hosted move to Node 24 is compatible without changing `package.json` or the
lockfile.

The response must eliminate the EOL hosted runtime, preserve the boundary
between workflow-runtime selection and package remediation, and leave a
coherent sequential slate.

### Options

#### Option A — Preserve Node 20 through T1 and T2

Keep T1 unchanged and rely on the future npm issue to discover and correct the
runtime later. This minimizes edits but knowingly validates new workflow work
on an unsupported runtime and leaves the correction in an issue that does not
yet exist.

#### Option B — Move T1 to Node 22 only

Change `markdownlint.yml` to Node 22, explicitly disable setup-node's automatic
package-manager cache, and prove the existing install/lint commands on Node 22.
This reaches a supported LTS and matches the currently expected package minimum
for the future dependency line. It has less lifecycle runway than Node 24 and
does not align with the sister repository's preferred hosted baseline.

#### Option C — Move T1 to Node 24 only

Have T1 own the hosted workflow baseline:

- install exact major 24;
- set `package-manager-cache: false`;
- assert the process is actually Node major 24 before installation;
- record npm version;
- perform a clean `npm ci`;
- run the existing outer and nested lint commands; and
- prove `package.json`, the lockfile, hook, and lint behavior did not change.

Leave the eventual package minimum, `engines.node`, hook guard, dependency
upgrade, advisory disposition, and npm Dependabot entry to T3.

This creates a supported hosted baseline without conflating it with the
contributor/runtime-floor decision.

#### Option D — Add a Node 22/24 matrix to T1

Have T1 validate the unchanged current dependency tree on both Node 22 and 24,
while selecting Node 24 as the ordinary hosted job. This supplies broader
compatibility evidence, but T1 is not selecting the final upgraded package
tree and does not own a repository-declared minimum. The matrix would duplicate
evidence better placed in T3.

#### Option E — Put the complete npm issue first

Draft T3, reorder it ahead of T1, and make it own packages, lockfile,
`engines.node`, hook floor, Node 24 hosted execution, audit remediation,
integration tests, and npm Dependabot. Rebaseline T1 and T2 after it merges.

This is the strongest response if repository policy forbids carrying the
current high-severity findings. It resolves more than the Node defect but adds
an intentional rebase point before the generator/workflow redesign.

#### Option F — Retain Node 20 with commercial post-EOL support

Document a supported commercial Node 20 distribution, pin its provenance, and
validate the current packages there. This can be legitimate in an enterprise
with a real support contract, but no such repository policy or distribution is
present. It would also diverge from the public project's normal reproducible
setup.

#### Option G — Replace host Node with a containerized lint runtime

Run lint in a digest-pinned container based on Node 24 and use the same
container from hooks where available. This is hermetic but materially changes
contributor prerequisites, Windows/GUI Git behavior, action design, and supply
chain governance. It is disproportionate to selecting a supported setup-node
major.

#### Permutations considered

- **Ownership:** T1 may own only the hosted major, or T3 may own every runtime
  surface. Splitting the hosted baseline from the final package floor is safe
  because the current packages declare Node `>=20`.
- **Major:** Node 22 and 24 are supported LTS lines. Node 24 has the longer
  runway and is already the preferred cross-repository hosted target.
- **Cache:** leaving setup-node's automatic cache implicit works with the
  current manifest, but a future `packageManager` field could activate it.
  Explicit `false` keeps the trusted workflow behavior stable.
- **Evidence:** a version string in YAML is indirect. The job must query the
  actual runtime before `npm ci`.
- **Order:** T1 → T2 → T3 remains coherent only if T1 owns Node 24 and policy
  permits the advisories temporarily. Otherwise T3 must move first.

### Evaluation rubric

This rubric is specific to retiring an EOL hosted runtime while preserving a
clean issue boundary.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Supported-runtime and security correctness | 24 | DevOps and security owners must not establish a new workflow on an EOL runtime. |
| Sequential-slate coherence | 18 | Project managers and implementers need every issue to consume a supported merged prerequisite without an invisible future fix. |
| Workflow/package compatibility | 16 | The selected hosted major must be admitted by the current locked tree without an unauthorized dependency change. |
| Executable evidence strength | 14 | A cold-start reviewer needs proof of the actual process major, clean install, and both real lint surfaces. |
| Lifecycle runway | 10 | A longer supported lifetime avoids near-term forced migration and repeated workflow churn. |
| Contributor-policy separation | 8 | Hosted execution must not accidentally claim a final local/hook support floor that only T3 can establish. |
| Cross-repository consistency | 6 | Using the same preferred hosted LTS reduces needless divergence while preserving repository-local packages. |
| Churn and implementation effort | 4 | Small changes are useful, but cannot justify retaining EOL software. |

Scoring constraints:

- Any option that leaves ordinary hosted validation on Node 20 scores 0 for
  supported-runtime correctness.
- A score of 5 for compatibility requires current package-engine evidence and
  no incidental manifest/lockfile mutation.
- A score of 5 for evidence requires querying the actual runtime and executing
  both lint commands after a clean install.
- A score of 5 for contributor-policy separation leaves the final package
  minimum and hook floor explicitly assigned to T3.

### Scoring

Columns follow the rubric: runtime/security (RS), sequence (SQ),
compatibility (CP), evidence (EV), runway (LR), policy separation (PS),
cross-repository consistency (XR), and churn (CH).

| Option | RS | SQ | CP | EV | LR | PS | XR | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Preserve Node 20 | 0 | 1 | 5 | 2 | 0 | 2 | 0 | 5 | 32.4 |
| B — T1 uses Node 22 | 5 | 5 | 5 | 5 | 3 | 5 | 3 | 5 | 93.6 |
| C — T1 uses Node 24 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| D — T1 uses a 22/24 matrix | 5 | 4 | 5 | 5 | 5 | 3 | 5 | 3 | 91.6 |
| E — Complete npm issue first | 5 | 4 | 5 | 5 | 5 | 5 | 5 | 2 | 94.0 |
| F — Commercial Node 20 | 2 | 2 | 3 | 2 | 2 | 3 | 0 | 1 | 41.6 |
| G — Containerized lint | 5 | 3 | 4 | 4 | 5 | 2 | 2 | 0 | 74.4 |

Option C wins because it completely closes the EOL defect with the existing
locked packages, preserves T3's distinct ownership, has the longest LTS runway,
and requires no speculative contributor-policy decision. Option E remains the
mandatory policy exception if open-advisory policy requires remediation before
other work.

### Selected option and implementation specification

**Select Option C: T1 establishes exact hosted Node 24 with automatic
package-manager caching disabled; T3 owns the final package and contributor
floor.**

Revise T1 so that a cold-start implementer must:

1. Remove every instruction that preserves or prohibits changing the hosted
   Markdown workflow's Node version.
2. Configure the approved `setup-node` action with:

   ```yaml
   with:
     node-version: '24'
     package-manager-cache: false
   ```

3. Before `npm ci`, run the resolved `node` application, parse
   `process.versions.node`, and require exact major 24. Record the full Node and
   npm versions in the job log.
4. Run a clean CI-mode `npm ci`, followed by the unchanged outer and nested
   lint commands. Capture and classify every native exit code.
5. Keep the workflow read-only and preserve T1's approved action pin,
   trigger, permission, and lint-command contracts.
6. Prove that `.github/workflows/package.json`,
   `.github/workflows/package-lock.json`, `.husky/pre-commit`, lint rules, and
   lint semantics did not change in T1.
7. Add local or controlled hosted evidence that the lint processes, not merely
   setup-node, observe Node major 24.
8. Update T1 acceptance criteria and T2's concise prerequisite to name hosted
   Node 24 and disabled automatic package-manager caching.
9. Keep T3 responsible for the final dependency set, lockfile,
   `engines.node`, selected supported minimum, hook guard, dual-runtime
   compatibility evidence, advisory disposition, and npm Dependabot.
10. Preserve the policy gate: if project policy prohibits carrying the current
    high-severity advisories, execute T3 first and rebaseline T1/T2 instead of
    applying this default order blindly.

This option does not authorize any package update and does not infer the
repository's final contributor floor from an action's internal Node runtime.

## T1-2 — Define and reuse a trusted temporary-root lifecycle

### Problem statement

T1's archive helper independently validates explicit roots, but every
production and harness caller is merely told to create a “unique trusted
temporary root.” `GetRandomFileName()` does not create anything, and
`Directory.CreateDirectory()` succeeds by returning an existing directory.
The issue therefore does not establish how a caller acquires ownership or how
it tears down only proven invocation-owned state.

The solution must establish one auditable creation/teardown implementation,
retain helper-side distrust, work in PowerShell 5.1 and 7 on Windows and
Ubuntu, and fail closed when cleanup state becomes uncertain.

### Options

#### Option A — Leave creation and cleanup to each implementer

Rely on the hosted runner's temporary-directory cleanup and the helper's root
validation. This avoids code, but a caller can silently reuse an existing
directory or perform unsafe recursive cleanup while still appearing to satisfy
the high-level prose.

#### Option B — Add a prose-only factory algorithm

Specify random-name, absence, create, verify, bounded collision retry, and
nonrecursive cleanup, but let every workflow block and harness implement it
independently. This closes the requirements gap but creates several copies of
security-sensitive lifecycle logic that can drift.

#### Option C — Use deterministic job/run-derived child names

Build a root from run ID, attempt, job, and matrix values under `RUNNER_TEMP`.
These values are useful diagnostics and usually unique in an isolated hosted
job, but they are predictable and still require an absence/create/verify
contract. Reruns, malformed substitutions, or future reuse can collide.

#### Option D — Repeat one identical local function in each consumer

Define the exact same PowerShell factory and teardown functions inside each
workflow `run:` block and the harness. Require textual or AST equivalence and
shared fixtures.

This avoids a new repository file and is stronger than prose, but there are
still multiple production implementations. YAML-embedded functions are also
harder to lint, invoke locally, and compare with PSStyleGuide.

#### Option E — Add one tracked caller-context lifecycle script

Add a versioned PowerShell script dedicated to creating and removing candidate
invocation contexts. Every harness and workflow consumer calls it. The script
owns:

- normalization of the runner-controlled parent;
- bounded random-child acquisition;
- creation of separate download and initially absent candidate topology;
- an explicit ownership record/output; and
- fail-closed, nonrecursive teardown after consumers dispose their streams.

The archive helper remains separate and independently validates every supplied
path. This adds an eighth T1 implementation file but gives the security
boundary one testable source of truth.

#### Option F — Put caller lifecycle functions in the archive helper

Add `New-StyleGuideCandidateInvocationContext` and
`Remove-StyleGuideCandidateInvocationContext` to the existing helper and
definition-only dot-source them from workflow callers.

This avoids a file, but conflates caller trust establishment with archive
validation, expands the helper's special dot-source interface beyond the
cleanup fixture, and creates awkward bootstrapping because the helper's normal
entry point requires paths that the factory has not created yet.

#### Option G — Reserve a random filename, delete it, then create a directory

Use `GetTempFileName()` to create a unique file, delete it, and reuse its name
for the root directory. The delete/create transition reopens a race, cleanup is
more complex, and the temporary file is not the required directory. It is not
an atomic directory-ownership primitive.

#### Option H — Depend exclusively on operating-system temporary APIs

Use platform-specific secure directory creation—such as a Unix `mkdtemp`
binding—and a different Windows implementation. This can improve atomicity,
but it creates divergent native interop paths that are difficult to support
under Windows PowerShell 5.1 and exceeds the hosted-runner threat model.

#### Permutations considered

- **Code location:** prose, duplicated workflow functions, archive helper, or
  a separate lifecycle script.
- **Naming:** random only, run-derived only, or random with run data used only
  for diagnostics. Random acquisition plus diagnostic labels avoids treating
  metadata as authorization.
- **Collision policy:** unbounded retry, bounded retry, or immediate failure.
  A documented finite retry count permits genuine collision recovery without
  hiding permission or classification failures.
- **Teardown:** rely on runner cleanup, recursive deletion, or exact
  journal-based nonrecursive deletion. Only the last matches T1's fail-closed
  posture.
- **File boundary:** preserve seven files at the cost of duplication, or add a
  focused eighth file. The path gate must follow the selected design, not drive
  it.

### Evaluation rubric

This rubric targets caller-side ownership and teardown safety.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Root ownership correctness | 24 | Security reviewers need evidence that the invocation acquired a new ordinary directory rather than accepted pre-existing state. |
| Fail-closed teardown safety | 20 | Cleanup must never recurse through or delete an unexpected replacement merely to leave the runner tidy. |
| Single-source consumer parity | 14 | DevOps maintainers need Windows cells, Ubuntu, writer, and harness to use one behavior rather than drifting copies. |
| Deterministic testability | 12 | Engineers need direct tests of creation output, classification, error handling, and cleanup postconditions. |
| Helper trust-boundary separation | 10 | The archive helper must independently validate caller claims and must not implicitly trust its own companion factory. |
| Cross-edition/platform support | 8 | The solution must remain viable in Desktop 5.1/Core 7 and Windows/Linux jobs. |
| Cold-start implementation clarity | 8 | A new developer must know exactly which component creates, owns, passes, and removes each path. |
| File/churn cost | 4 | Extra code has maintenance cost, but preserving an arbitrary seven-file gate cannot outweigh lifecycle safety. |

Scoring constraints:

- Any solution that permits recursive deletion of uncertain state scores 0 for
  teardown.
- A score of 5 for parity requires one tracked production implementation.
- A score of 5 for ownership requires absence, create-without-force,
  verification, and collision-only retry.
- A score of 5 for separation keeps the archive helper's independent root and
  component validation intact.

### Scoring

Columns are ownership (OW), teardown (TD), parity (PA), testability (TE),
separation (SP), platform support (PL), clarity (CL), and churn (CH).

| Option | OW | TD | PA | TE | SP | PL | CL | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Implementer discretion | 1 | 1 | 0 | 1 | 5 | 5 | 1 | 5 | 34.8 |
| B — Prose algorithm | 4 | 4 | 2 | 2 | 5 | 5 | 4 | 4 | 73.2 |
| C — Deterministic names | 2 | 3 | 3 | 4 | 5 | 5 | 4 | 4 | 67.2 |
| D — Repeated local functions | 4 | 4 | 2 | 3 | 5 | 5 | 3 | 4 | 74.0 |
| E — Tracked lifecycle script | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 3 | **98.4** |
| F — Functions in archive helper | 5 | 5 | 5 | 4 | 2 | 5 | 3 | 4 | 87.6 |
| G — Reserve/delete/recreate | 2 | 3 | 4 | 3 | 5 | 5 | 3 | 3 | 65.2 |
| H — Platform-native divergence | 5 | 5 | 2 | 3 | 5 | 1 | 2 | 1 | 72.4 |

Option E wins because it provides one production lifecycle and one direct test
surface without weakening the archive helper's independent checks. The eighth
file is justified by the distinct caller-side trust responsibility.

### Selected option and implementation specification

**Select Option E: add one tracked, versioned candidate-invocation-context
lifecycle script and use it everywhere.**

Revise T1 as follows:

1. Add
   `.github/workflows/Manage-StyleGuideCandidateInvocationContext.ps1` to the
   affected files, exact working/staged path gates, version requirements,
   validation, acceptance criteria, and T2 prerequisite summary.
2. Require `#Requires -Version 5.1` and one production creation function named
   `New-StyleGuideCandidateInvocationContext` plus one production teardown
   function named `Remove-StyleGuideCandidateInvocationContext`.
3. For creation:
   - accept one explicit runner-controlled temporary parent;
   - normalize it to one ordinary, non-reparse absolute filesystem directory;
   - use `Path.GetRandomFileName()` for the child;
   - prove the proposed child has no filesystem entry;
   - create without `-Force`;
   - verify the returned exact child is one ordinary, non-reparse directory;
   - retry a documented bounded number of times only when exhaustive
     reinspection proves an actual name collision;
   - fail immediately for every permission, type, resolution, attribute, or
     classification error; and
   - create/return absolute download-directory and initially absent
     candidate-directory paths under distinct children.
4. Return a structured context containing the normalized parent, root,
   download directory, candidate path, and exact ownership information needed
   for later cleanup. Use run/artifact labels only for diagnostics.
5. For teardown:
   - run in `finally` or an equivalent always-running workflow cleanup step
     after all entry/archive/file streams are disposed;
   - revalidate the complete envelope and every expected entry before deleting
     anything;
   - delete only known invocation-owned ordinary files and empty directories,
     nonrecursively, deepest first;
   - never follow, traverse, wildcard, or recursively delete an unexpected,
     missing, unreadable, link, reparse, or substituted entry;
   - retain uncertain state and report the root, phase, offending entry, and
     cleanup exception without hiding the primary failure.
6. Require every Ubuntu/Windows production consumer, controlled drill, writer,
   and permanent harness to use the exact tracked lifecycle script. No fixed
   or pre-existing child may substitute.
7. Extend the permanent harness with direct creation/output assertions,
   outside-root sentinels, ordinary successful teardown, and deterministic
   unsafe teardown retention. Static review must prove no workflow copied the
   lifecycle implementation.
8. Keep the archive helper's existing independent root/component/containment
   validation. Factory success is a caller claim, not helper authorization.
9. Add the lifecycle surface to the reciprocal PSStyleGuide/TerraformStyleGuide
   helper matrix. Repository-local names may differ only if recorded as an
   intentional difference.
10. Change every “seven implementation files” assertion to the exact
    implementation-time set produced by the final selected design; with this
    selection, T1 has eight files before any other accepted finding adds one.

The operating model remains GitHub-hosted, runner-controlled ancestors, and no
competing writer. The lifecycle narrows risk and establishes ownership; it
does not claim an atomic OS directory-handle sandbox.

## T1-3 — Give every harness permutation a stable comparable ID

### Problem statement

T1 says stable case identifiers are mandatory but presents only prose fixture
classes, several of which combine independent inputs and oracles. This permits
incomplete coverage, ambiguous failures, inconsistent platform skips, and weak
cross-repository comparison. It also lacks a failure with every optional label
omitted, so `unavailable` is not proved in the failure diagnostic path.

The response must make every executable permutation addressable and pair it
with one expected phase, diagnostic set, and pre-teardown filesystem
postcondition.

### Options

#### Option A — Keep prose fixture classes

Let the implementer invent identifiers in code. This has no issue-draft churn,
but the issue cannot prove one test exists per grouped permutation and gives
reviewers no stable evidence vocabulary.

#### Option B — Assign one ID to each existing grouped row

Add an ID column without splitting rows. This makes log records stable but
still allows one subcase—such as forward traversal—to stand in for another,
such as backward traversal.

#### Option C — Split every permutation and invent a Terraform-only taxonomy

Create separate cases for all grouped inputs and use a new ID scheme tailored
to T1. Coverage becomes complete, but equivalent P1/T1 failures have unrelated
names and cross-repository convergence evidence requires a mapping table.

#### Option D — Reuse P1's stable IDs for shared cases

Adopt the existing category and number scheme for every shared observable
behavior:

- `V-*` valid archives;
- `P-*` valid path classification;
- `D-*` digest and diagnostic-label behavior;
- `Z-*` ZIP readability;
- `M-*` manifest grammar;
- `E-*` envelope/path security;
- `L-*` preexisting leaf state;
- `B-*` post-extraction byte sanitation;
- `K-*` fail-closed cleanup; and
- `X-*` explicitly empty optional labels.

Give every slash direction, overlap direction, leaf type, and label its own
row. Keep repository-specific manifest names and bytes inside the shared IDs.
Allocate a new documented ID only for a genuinely Terraform-only contract.

#### Option E — Store cases in a machine-readable fixture manifest

Add JSON/YAML describing ID, setup, platform, expected phase, diagnostics, and
postcondition; have the harness consume it. This can enforce completeness, but
complex filesystem and raw-ZIP setup still requires code, producing a
data/code indirection layer. It is useful only if the harness architecture
already benefits from data-driven cases.

#### Option F — Derive IDs dynamically from fixture descriptions

Hash or slugify each description at runtime. This avoids maintaining numbers
but produces unstable IDs when wording changes and makes human issue/CI
discussion difficult.

#### Option G — Use hierarchical IDs with a P1/T1 prefix

Name cases `P1-M-01` and `T1-M-01`. Repository attribution is explicit, but CI
already knows the repository. Prefixes make shared cases look different and
reduce the value of a common vocabulary.

#### Permutations considered

- **Granularity:** one row per class, per input variant, or per
  platform-specific expected result. Security-relevant variants require their
  own rows.
- **Identity:** independent numbering, shared numbering, or dynamic IDs.
  Shared stable IDs best support convergence.
- **Platform:** one ID with named platform outcomes versus separate `-W` and
  `-L` IDs. Separate suffixes are appropriate where case-sensitive behavior
  intentionally differs.
- **Diagnostic labels:** success-only omission, supplied failure only, or
  symmetric supplied/omitted failures plus three explicit-empty cases. The
  symmetric set proves every branch.
- **Representation:** Markdown oracle table or external manifest. The table is
  sufficient for an issue; the implementation may still be data-driven.

### Evaluation rubric

This rubric is specific to adversarial harness identity and oracle quality.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Complete permutation coverage | 23 | Security and test engineers must know that every slash, collision, overlap, leaf, and label variant executes independently. |
| Failure attribution and diagnostics | 18 | DevOps responders need one stable ID and one expected phase for a failing cell. |
| Cross-repository comparability | 16 | Shared helper behavior should produce directly comparable P1/T1 evidence without a translation layer. |
| Filesystem postcondition precision | 14 | Cleanup safety depends on distinguishing absent, preexisting, removed-owned, and retained-unsafe states. |
| Platform/skip accountability | 10 | A named case must not disappear behind a platform-wide skip or ambiguous grouped row. |
| Cold-start readability | 8 | A new developer should understand the fixture and oracle from one row. |
| Long-term maintainability | 7 | IDs should survive wording changes and make regression discussion durable. |
| Draft/harness churn | 4 | More rows cost effort, but grouped security cases are false economy. |

Scoring constraints:

- Grouped variants cap complete-coverage scoring at 2.
- Dynamic or description-derived IDs cap maintainability at 2.
- A score of 5 for comparability requires the same ID for the same shared
  behavior.
- A score of 5 for postconditions requires each row to state candidate state
  before unconditional harness teardown.

### Scoring

Columns are coverage (CV), attribution (AT), parity (PA), postconditions (PC),
platform accountability (PL), readability (RD), maintainability (MT), and
churn (CH).

| Option | CV | AT | PA | PC | PL | RD | MT | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Prose classes | 1 | 1 | 1 | 2 | 1 | 2 | 1 | 5 | 27.6 |
| B — IDs on grouped rows | 2 | 4 | 2 | 3 | 2 | 3 | 4 | 4 | 56.0 |
| C — Split Terraform taxonomy | 5 | 5 | 2 | 5 | 5 | 5 | 5 | 3 | 88.8 |
| D — Shared IDs and split rows | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 3 | **98.4** |
| E — Machine-readable manifest | 5 | 5 | 4 | 5 | 5 | 3 | 4 | 1 | 89.0 |
| F — Dynamic IDs | 4 | 2 | 2 | 4 | 3 | 2 | 1 | 4 | 57.0 |
| G — Repository-prefixed IDs | 5 | 5 | 3 | 5 | 5 | 4 | 4 | 3 | 89.0 |

Option D provides complete, durable evidence and the clearest convergence
contract. The small loss for drafting churn is intentional.

### Selected option and implementation specification

**Select Option D: reuse P1's IDs for shared behavior and assign one row per
executable permutation.**

Replace T1's fixture-class table with an ID-first oracle table containing:

1. `V-01` exact archive/matching digest success.
2. `V-02` symlink-like external attributes ignored; ordinary-file success.
3. `P-01` checkout-sibling-prefix success.
4. `P-02` filesystem-provider-qualified absolute-path success.
5. `D-01` wrong well-formed digest with three distinct supplied label
   sentinels.
6. `D-02` equivalent digest failure with all labels omitted and every label
   rendered `unavailable`.
7. `Z-01` invalid/truncated ZIP with a matching digest.
8. `M-01` through `M-14`, separately covering missing, extra, exact duplicate,
   case collision, both nesting separators, both traversal separators,
   leading slash, leading backslash, drive qualification, directory entry,
   file/directory collision, and reviewed raw empty-name ZIP.
9. `E-01` through `E-10`, separately covering outside-root paths, equal roots,
   each contains-the-other direction, relative input, non-filesystem provider,
   Windows/Linux case behavior, root/ancestor links, below-root component
   links, and hidden/system extra download entries.
10. `L-01` through `L-04`, separately covering a preexisting file, directory,
    live link/reparse leaf, and dangling link.
11. `B-01` BOM and `B-02` CR post-extraction rejection and safe ordinary
    cleanup.
12. `K-01` mandatory unjournaled ordinary child retention and `K-02`
    supplemental link/reparse substitution retention.
13. `X-01`, `X-02`, and `X-03` for explicitly empty `ArtifactId`, `RunId`, and
    `RunAttempt`.

For every row, specify:

- platform or setup precondition;
- expected success or exact stable failure phase;
- whether `ZipArchive` may be constructed;
- candidate initial state;
- candidate final state before harness `finally`;
- required normalized path/entry/digest/label diagnostics; and
- outside-sentinel postconditions.

Use the same ID in TerraformStyleGuide and PSStyleGuide for the same observable
case. Manifest filenames, expected file bytes, and archive names remain
repository-specific. A Terraform-only case must receive a new category/number,
be documented beside the table, and be classified as an intentional
cross-repository difference.

The harness must emit one result for every mandatory ID in every applicable
cell. A narrowly justified link-primitive skip must name the ID, platform, and
reason and does not count as a pass. The existing requirement for at least one
real link/reparse rejection per operating-system family remains.

## T1-4 — Normalize all writer identity inputs once

### Problem statement

T1 gives the push writer purpose-specific `TARGET_REF` and `EXPECTED_SHA`
variables, but it does not require all four identity-bearing environment
values to be copied once before validation. Its current checks are also weaker
than Git's ref grammar: a `refs/heads/` prefix and nonempty string do not reject
whitespace, CR/LF, or every name that `git check-ref-format` rejects.

The writer must bind the event identity to one immutable local snapshot, reject
rather than silently trim malformed values, and use the same validated target
and object in checkout, parent, lease, and refspec operations.

### Options

#### Option A — Keep the existing prefix and nonempty checks

Continue reading `TARGET_REF`, `EXPECTED_SHA`, `GITHUB_REF`, and `GITHUB_SHA`
where needed. This is compact, but permits time-of-check/time-of-use drift in
the script and accepts strings that are not valid full branch refs.

#### Option B — Add `git check-ref-format` for `TARGET_REF` only

This closes the largest grammar hole while preserving the current comparison
structure. It still rereads ambient event variables and does not establish a
single identity snapshot.

#### Option C — Snapshot only the purpose-specific pair

Copy `TARGET_REF` and `EXPECTED_SHA` once, validate them, then compare them to
ambient `GITHUB_REF` and `GITHUB_SHA` when required. The pushed pair is stable,
but the event pair remains an implicit mutable input and the cross-repository
writer contract remains weaker than P1's intended four-local form.

#### Option D — Snapshot and validate all four values once

At the first executable lines, copy the purpose-specific pair and GitHub event
pair into four local strings. Reject empty, whitespace-padded, CR/LF-bearing,
or otherwise malformed values; validate the complete branch ref with
`git check-ref-format`; compare the two ref locals ordinally and the two
full-object-ID locals case-insensitively; then never read those environment
variables again.

Use the validated purpose-specific locals in every checkout, ancestry,
compare-and-swap lease, and explicit refspec operation. Controlled drills
mutate test-local copies, not production environment state.

#### Option E — Interpolate the GitHub expression context into the script

Use `${{ github.ref }}` and `${{ github.sha }}` directly inside the PowerShell
body. This binds values at workflow expression time, but embeds untrusted
string data into source text and creates an avoidable script-injection and
quoting surface.

#### Option F — Pass identity in a generated file

Serialize the four values to a JSON file, validate a schema, and have the
writer read it once. This can create a clear envelope, but introduces another
mutable file, encoding rules, cleanup, and provenance checks without improving
the trusted source.

#### Option G — Derive identity only from the checkout

Use `git rev-parse HEAD` and the currently checked-out branch as the only
inputs. This proves local repository state but loses the explicit binding to
the triggering ref/SHA and weakens protection against a miswired checkout or
environment.

#### Permutations considered

- **Snapshot timing:** once at script entry, once immediately before push, or
  repeated reads. Entry-time snapshot makes all later diagnostics and
  decisions refer to one event identity.
- **Malformed strings:** trim, normalize, or reject. Identity values must be
  rejected; silently changing them obscures a wiring defect.
- **Ref validation:** prefix only, hand-written regex, or Git's complete
  `check-ref-format` plus the closed `refs/heads/` namespace. Git is the
  authoritative grammar.
- **SHA validation:** regex only or resolution to an exact full commit object.
  The writer needs both lexical rejection and object/type evidence.
- **Drills:** change environment variables or change separate test locals.
  Production inputs should remain immutable even in negative tests.

### Evaluation rubric

This rubric targets immutable writer identity and compare-and-swap safety.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Event-to-writer identity integrity | 24 | The writer must prove that the object and ref it acts on are exactly those authorized by the triggering event. |
| Complete branch-ref grammar | 18 | Git—not a partial prefix test—defines which full branch names can safely appear in commands and refspecs. |
| Single-read/immutable reuse | 16 | All decisions and diagnostics must refer to one snapshot and avoid environment rereads after validation. |
| Push lease and refspec consistency | 14 | Checkout, ancestry, lease, and destination ref must use the same validated pair. |
| Injection and malformed-input resistance | 11 | Identity data must remain data and CR/LF or surrounding whitespace must not reach logs or commands. |
| Executable drill quality | 8 | Negative tests must prove each mismatch without mutating the production inputs they are testing. |
| Cross-repository contract parity | 5 | Equivalent writers should share the stronger four-local rule. |
| Churn and complexity | 4 | Simplicity matters only after the writer authorization boundary is sound. |

Scoring constraints:

- Any option that rereads an identity environment variable after validation
  scores at most 2 for immutability.
- Prefix-only or hand-written-only ref validation scores at most 2 for ref
  grammar.
- A score of 5 for push consistency requires explicit reuse of validated
  locals in the lease and refspec.
- Source interpolation of identity data scores 0 for injection resistance.

### Scoring

Columns are identity integrity (ID), ref grammar (RG), immutable reuse (IR),
push consistency (PC), malformed-input resistance (MI), drills (DR), parity
(PA), and churn (CH).

| Option | ID | RG | IR | PC | MI | DR | PA | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Existing checks | 2 | 1 | 1 | 3 | 2 | 2 | 1 | 5 | 37.4 |
| B — Ref check only | 3 | 5 | 1 | 3 | 4 | 3 | 2 | 4 | 62.8 |
| C — Snapshot two values | 4 | 5 | 3 | 5 | 4 | 4 | 2 | 4 | 81.2 |
| D — Snapshot all four | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.2** |
| E — Expression interpolation | 3 | 4 | 5 | 4 | 0 | 2 | 1 | 3 | 62.6 |
| F — Generated JSON envelope | 5 | 5 | 5 | 5 | 5 | 4 | 3 | 1 | 93.2 |
| G — Checkout-derived only | 1 | 4 | 4 | 3 | 4 | 2 | 1 | 4 | 56.6 |

Option D is the smallest design that binds both input pairs once, uses Git's
grammar, and carries the exact same validated values through the entire
compare-and-swap sequence.

### Selected option and implementation specification

**Select Option D: snapshot, reject, validate, compare, and reuse all four
writer identity values.**

Revise T1 so that the writer's first executable statements create:

```powershell
$strTargetRef = [string]$env:TARGET_REF
$strExpectedSha = [string]$env:EXPECTED_SHA
$strGitHubRef = [string]$env:GITHUB_REF
$strGitHubSha = [string]$env:GITHUB_SHA
```

Then require the implementation to:

1. Reject null/empty values, leading or trailing whitespace, CR/LF, NUL, and
   control characters in every local. Do not trim or rewrite an identity.
2. Require both ref locals to begin with `refs/heads/`, pass the complete
   one-argument `git check-ref-format` grammar, and match with ordinal,
   case-sensitive comparison.
3. Require both SHA locals to be full hexadecimal object IDs of the active
   repository's object format; resolve each with Git; require commit object
   type; and compare their canonical full IDs case-insensitively.
4. Capture and classify every native Git exit code. Never continue by parsing
   output from a failed command.
5. Never read any of the four environment variables again after the local
   assignments. Static review must enforce that single-read property.
6. Use `$strTargetRef` and `$strExpectedSha` for the exact checkout/ref
   verification, parent and ancestry checks, explicit
   `--force-with-lease=<ref>:<expected>` value, and explicit
   `HEAD:<target-ref>` refspec.
7. Keep command arguments as arguments; do not construct a shell command
   string or insert GitHub expressions inside script source.
8. Implement ref mismatch, SHA mismatch, malformed ref, malformed SHA, and
   lease-failure drills with separate test-local copies. Each drill must prove
   no push and an unchanged remote.
9. Apply the same four-local single-read contract to P1 if its final writer
   still has only the two-local wording. Exact convergence must describe
   observable behavior, not perpetuate the weaker literal.

This normalization occurs before token expansion, checkout mutation, archive
download, or any network write.

## T1-5 — Make the archive cleanup function a named production contract

### Problem statement

T1 describes the helper's fail-closed cleanup algorithm and even requires the
harness to invoke production cleanup, but it never gives that function an
exact identifier. A cold-start implementer can therefore create a private
closure, duplicate the logic in tests, or choose a Terraform-only name while
still claiming compliance. P1 already establishes the production name
`Remove-StyleGuideCandidateInvocationState`.

This finding concerns the archive helper's journal-based candidate cleanup,
not the separate caller-context teardown selected in T1-2.

### Options

#### Option A — Keep cleanup as an unnamed behavior

Test outcomes only and let the implementer choose the code boundary. This
maximizes flexibility but cannot prove that controlled teardown tests call the
same routine used after real extraction failures.

#### Option B — Require a function but allow any name

Mandate one production function and direct harness invocation, while leaving
its identifier to the implementation. This closes test/production duplication
inside TerraformStyleGuide but loses exact sister-repository convergence and
makes static review less deterministic.

#### Option C — Adopt P1's exact function name

Require one production function named
`Remove-StyleGuideCandidateInvocationState`, define its inputs and output/error
contract, and have both normal helper teardown and `K-*` harness cases invoke
it. Keep `Remove-StyleGuideCandidateInvocationContext` as the distinct
caller-root function selected in T1-2.

#### Option D — Expose a class method

Create a cleanup-state class and call a static or instance `Remove()` method.
This can encapsulate the journal, but increases PowerShell 5.1 parsing and
dot-sourcing complexity, diverges from P1, and adds no safety property.

#### Option E — Test through a wrapper command

Keep cleanup private and expose a test-only wrapper that creates the expected
failure state. This reduces public surface but permits the wrapper and real
path to drift and makes direct fault injection harder to audit.

#### Option F — Create a separate cleanup script

Move candidate cleanup into its own executable script with a serialized
journal input. This makes the entry point obvious but weakens in-process object
identity, introduces journal serialization trust, and separates cleanup from
the open stream lifetime it must follow.

#### Permutations considered

- **Visibility:** private closure, script-scope function, exported module
  command, or separate process. A script-scope production function is enough.
- **Invocation:** direct from harness, wrapper-mediated, or outcome-only.
  Direct calls best prove the dangerous routine.
- **Inputs:** raw paths, inferred directory contents, or explicit ownership
  journal plus normalized roots. Cleanup must act only on the explicit journal
  and revalidated envelope.
- **Naming:** repository-specific or shared. There is no behavioral reason to
  diverge from P1's already-reviewed identifier.
- **Lifecycle distinction:** candidate state inside the helper versus the
  caller-owned invocation root. Separate exact names prevent accidental
  recursive delegation.

### Evaluation rubric

This rubric targets direct production cleanup testability and semantic naming.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Production-path identity | 24 | Tests must invoke the exact routine that handles real partial-extraction failures. |
| Fail-closed journal contract | 21 | The named surface must accept only explicit ownership state and retain uncertain entries. |
| Direct fault-injection testability | 16 | Security tests need to substitute ordinary/link entries immediately before the destructive call. |
| Cross-repository convergence | 14 | The same behavior should have the same stable production name in P1 and T1. |
| Lifecycle-boundary clarity | 11 | Reviewers must not confuse archive-state cleanup with caller-root teardown. |
| PowerShell 5.1 compatibility | 6 | The implementation must work without newer class/module assumptions. |
| Cold-start readability | 5 | A developer should be able to find the routine and every call site immediately. |
| Churn | 3 | One identifier is nearly free; churn cannot outweigh an ambiguous destructive boundary. |

Scoring constraints:

- An outcome-only or test-wrapper design scores at most 2 for production-path
  identity.
- A score of 5 for convergence requires the literal shared name.
- Any interface that infers ownership by enumerating a directory scores at
  most 1 for the journal contract.
- A score of 5 for boundary clarity names both cleanup functions and forbids
  recursive delegation between them.

### Scoring

Columns are production identity (PI), journal safety (JS), testability (TE),
convergence (CV), boundary clarity (BC), compatibility (CP), readability (RD),
and churn (CH).

| Option | PI | JS | TE | CV | BC | CP | RD | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Unnamed behavior | 1 | 4 | 1 | 1 | 2 | 5 | 1 | 5 | 42.0 |
| B — Arbitrary function name | 5 | 5 | 5 | 2 | 4 | 5 | 4 | 5 | 88.4 |
| C — Exact shared name | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| D — Class method | 5 | 5 | 4 | 1 | 3 | 2 | 3 | 2 | 73.8 |
| E — Test wrapper | 2 | 4 | 3 | 2 | 3 | 5 | 3 | 4 | 59.6 |
| F — Separate script | 4 | 3 | 4 | 1 | 2 | 4 | 4 | 1 | 61.2 |

Option C completely closes the gap with no architectural downside and makes
the two cleanup responsibilities deliberately distinguishable.

### Selected option and implementation specification

**Select Option C: require the production function
`Remove-StyleGuideCandidateInvocationState`.**

Revise T1 to establish the following literal contract:

1. The archive helper defines exactly one production candidate cleanup
   function named `Remove-StyleGuideCandidateInvocationState`.
2. Its parameters carry the normalized candidate root, explicit ordered
   ownership journal, and any primary failure needed for diagnostic
   preservation. It does not discover ownership by recursively enumerating.
3. Before any removal, it resolves and classifies the helper and harness
   ordinary script files, the candidate root, every ancestor below the trusted
   root, every journaled entry, and the expected parent/leaf relationship.
4. It disposes or requires disposal of all `ZipArchive`, entry, and file
   streams before it runs.
5. It deletes only revalidated journal-owned ordinary files and then empty
   ordinary directories, nonrecursively and deepest first.
6. An unexpected, missing, unreadable, substituted, link, reparse, hidden, or
   unjournaled entry causes retention and a cleanup failure diagnostic. The
   cleanup failure never hides the primary archive failure.
7. The normal helper `finally` path, successful post-publication cleanup, and
   every `K-*` controlled case call this exact function. The harness may
   arrange state and inject a narrow operation seam but may not copy the
   cleanup algorithm.
8. Static validation asserts the definition and all required call sites and
   rejects a second candidate-state cleanup implementation.
9. P1 and T1 use the same exact function name and the same observable inputs,
   postconditions, and diagnostic phases.
10. The caller-context lifecycle remains separately named
    `New-StyleGuideCandidateInvocationContext` and
    `Remove-StyleGuideCandidateInvocationContext`; it may run only after
    archive-state cleanup and may not recursively delete retained uncertain
    state.

## T1-6 — Verify an exact action/repository/SHA/role allowlist

### Problem statement

T1 requires every external action to use a full 40-hex commit, but its static
verifier checks only shape. Any arbitrary commit, wrong repository, swapped
upload/download action, or unreviewed extra action would satisfy that rule.
GitHub treats a full commit SHA as the immutable reference and recommends
verifying that the SHA comes from the expected action repository.

The issue must turn the four reviewed upstream releases into a deterministic
supply-chain contract without making ordinary CI depend on live tag state.

### Options

#### Option A — Keep the 40-hex shape check

Reject tags and branches but accept any repository/commit combination. This
prevents mutable references only; it is not an allowlist.

#### Option B — Rely on reviewer inspection

Keep shape validation and tell reviewers to open every commit manually.
Human review is still necessary on upgrades, but it is not durable executable
evidence and can miss a swapped role or newly added action.

#### Option C — Allowlist repository and exact SHA

Parse every local action `uses:` node and require one of four reviewed
repository/SHA tuples. This rejects arbitrary commits and extra external
actions, but still permits `download-artifact` in an upload step or a
publishing-capable action in the read-only workflow if both are otherwise
allowed.

#### Option D — Allowlist exact tuple and workflow role

Maintain a literal table of action repository, full SHA, human-readable
release annotation, workflow path, job/step role, and allowed count. Parse all
workflow YAML and require exact multiset equality. This proves that checkout,
setup, upload, and download occur only in their reviewed trust positions.

#### Option E — Resolve release tags online on every CI run

Fetch each tag from GitHub and compare its current target to the pinned SHA.
This provides current upstream confirmation but makes validation depend on
network availability and live tag/repository state. It also does not by itself
constrain workflow role.

#### Option F — Adopt a third-party policy engine

Add actionlint/OPA/StepSecurity or another policy tool and encode the
allowlist there. Mature tooling may help at scale, but introduces a new
dependency and pinning surface for a four-action repository. The exact local
policy is small enough to validate directly.

#### Option G — Let Dependabot define the allowlist

Trust the GitHub Actions Dependabot ecosystem to propose valid updates.
Dependabot is useful update automation, not proof that the checked-in workflow
contains only approved repositories, commits, and roles.

#### Permutations considered

- **Identity depth:** hash shape, repository/SHA tuple, or
  repository/SHA/workflow/role/count. Only the last captures least privilege.
- **Scope:** changed workflows only or all tracked workflows. The verifier
  must scan all tracked `.yml`/`.yaml` files under `.github/workflows`.
- **Comparison:** membership or exact multiset equality. Equality catches
  missing, duplicate, and extra uses.
- **Upstream state:** live lookup in CI or reviewed lookup during updates.
  Normal CI should be deterministic; upstream resolution is update evidence.
- **Annotations:** comments as authority or checked assertions. A version
  comment aids humans but never substitutes for the full SHA.

### Evaluation rubric

This rubric targets immutable third-party workflow provenance.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Repository/commit provenance | 25 | Security reviewers need exact evidence that each immutable commit is the reviewed upstream action. |
| Workflow-role least privilege | 18 | An approved action in the wrong job can expand write or artifact authority. |
| Exact coverage and extra-action rejection | 15 | The verifier must detect omissions, duplicates, and newly introduced actions. |
| Offline deterministic validation | 13 | Required checks must not fail or change meaning with network/tag availability. |
| Safe update workflow | 11 | Maintainers need a deliberate, atomic path to upgrade release and pin. |
| Diagnostic usefulness | 8 | Failures should identify workflow, job, step, repository, observed SHA, and expected role. |
| Maintainability | 6 | The policy should remain understandable without a new policy stack. |
| Churn and setup cost | 4 | Tooling cost matters less than closing the supply-chain gap. |

Scoring constraints:

- Shape-only validation scores 0 for provenance.
- A score of 5 for role requires exact workflow/job/role/count assertions.
- Live upstream dependency scores at most 1 for deterministic validation.
- A score of 5 for updates requires implementation-time upstream resolution
  plus atomic allowlist/`uses:` changes.

### Scoring

Columns are provenance (PV), role (RL), coverage (CV), determinism (DT),
updates (UP), diagnostics (DG), maintainability (MT), and churn (CH).

| Option | PV | RL | CV | DT | UP | DG | MT | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Shape only | 0 | 0 | 2 | 5 | 2 | 2 | 5 | 5 | 36.6 |
| B — Reviewer inspection | 2 | 2 | 1 | 5 | 3 | 1 | 3 | 5 | 49.0 |
| C — Exact repository/SHA | 5 | 2 | 4 | 5 | 4 | 4 | 5 | 4 | 81.6 |
| D — Exact tuple and role | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.2** |
| E — Online tag lookup | 5 | 1 | 3 | 1 | 3 | 3 | 3 | 2 | 56.8 |
| F — Policy engine | 5 | 5 | 5 | 4 | 4 | 4 | 2 | 0 | 86.0 |
| G — Dependabot as policy | 2 | 1 | 1 | 4 | 5 | 1 | 4 | 5 | 48.4 |

Option D supplies the strongest offline proof and makes action placement as
reviewable as action identity. Its small literal table is easier to audit than
a new policy dependency.

### Selected option and implementation specification

**Select Option D: enforce exact repository/SHA/workflow/role/count equality.**

T1 must carry this implementation-time baseline, re-resolved from the official
repositories immediately before implementation:

| Action | Exact full SHA | Reviewed release |
| --- | --- | --- |
| `actions/checkout` | `3d3c42e5aac5ba805825da76410c181273ba90b1` | `v7.0.1` |
| `actions/setup-node` | `820762786026740c76f36085b0efc47a31fe5020` | `v7.0.0` |
| `actions/upload-artifact` | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` | `v7.0.1` |
| `actions/download-artifact` | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` | `v8.0.1` |

Revise the static verifier and issue contract to:

1. Parse every tracked workflow YAML file structurally; do not validate
   `uses:` lines with a text regex alone.
2. Reject remote reusable workflows, Docker actions, local actions outside an
   explicit closed local allowlist, mutable refs, abbreviated hashes, dynamic
   `uses:`, and every external repository not in the table.
3. Compare an exact multiset keyed by workflow path, job ID, stable step role,
   repository, full SHA, and expected count.
4. Permit `checkout` only where repository contents are required;
   `setup-node` only in the read-only lint/tooling role; `upload-artifact` only
   in matrix producers; and `download-artifact` only in the single writer's
   controlled artifact-consumption role. Encode the final exact counts after
   the workflow design is frozen.
5. Require each `uses:` line to carry the matching reviewed release annotation
   for humans while treating the SHA and tuple table as authority.
6. Emit a stable diagnostic with observed and expected workflow/job/role,
   repository, SHA, and count.
7. Keep the verifier offline. Store implementation-time `git ls-remote` output
   or equivalent official release evidence in the PR.
8. On an intentional action upgrade, review upstream release/commit
   provenance and change every affected `uses:` value, annotation, allowlist
   row, and fixture atomically. Do not automatically widen the set for a
   Dependabot proposal.
9. Add negative fixtures for a valid-looking arbitrary SHA, wrong repository,
   swapped upload/download role, duplicate allowed use, missing use, extra
   workflow, and mutable tag.
10. Apply the same exact-role verifier principle to P1; repository-specific
    workflow/job names and counts belong in the reciprocal intentional-
    differences matrix.

## T1/T2-1 — Make helper convergence reciprocal and implementation-time

### Problem statement

T1 claims exact observable convergence with PSStyleGuide P1 and includes
selected implementation details, while T2 repeats a long frozen prerequisite
summary. Neither issue requires a reciprocal matrix against P1 at
implementation time, so later P1 clarifications can be missed and T2 can
silently preserve an obsolete duplicate.

The slate needs one authoritative Terraform contract, one explicit comparison
surface, and concise downstream consumption of merged evidence.

### Options

#### Option A — Keep the current one-way prose

Treat T1's references to P1 as sufficient and leave T2's duplicate unchanged.
This is easy to read in isolation but has no exhaustive parity check and
creates two Terraform copies that can drift before implementation.

#### Option B — Add a narrative “match P1” requirement

Require the implementer to review the latest P1, without defining comparison
axes or evidence. This improves timing but leaves “exact observable behavior”
subjective.

#### Option C — Add a reciprocal matrix to T1 only

T1 compares both repositories across named contract axes and records every
intentional difference. T2 keeps its long prerequisite copy. T1 becomes
auditable, but T2 can still contradict the selected or merged implementation.

#### Option D — Matrix in T1, checkpoint at implementation, concise T2 link

Make T1 own the complete Terraform requirements and a reciprocal P1/T1 matrix.
At implementation start and again before merge, compare the current P1 issue
and merged implementation. T2 names only the enduring invariants it consumes,
links to T1 and its evidence, and does not restate helper internals.

#### Option E — Create a shared runtime module used by both repositories

Extract one versioned helper package/submodule and consume it from P1 and T1.
This provides code reuse but introduces cross-repository release,
bootstrapping, trust, and availability concerns that the repositories do not
currently have.

#### Option F — Copy P1's entire final issue into T1 and T2

Literal duplication makes every issue self-contained at one point in time.
It maximizes drift surfaces and obscures legitimate repository differences.

#### Option G — Make T2 wait for implementation and say nothing else

Remove every helper detail and rely on issue order. This avoids duplication but
is too weak for a cold-start implementer to understand which merged properties
are safety prerequisites for recovery-document generation.

#### Permutations considered

- **Authority:** P1, T1, a shared module, or merged implementation. T1 must own
  Terraform decisions while comparison uses the current P1/implementation.
- **Timing:** draft time, implementation start, or pre-merge. Both latter
  checkpoints are needed because either repository can change.
- **Axes:** names only versus full observable contract. The matrix must cover
  parameters, archive identity, path security, manifests, lifecycle,
  diagnostics/IDs, transport, CI placement, and tests.
- **Downstream detail:** full duplicate, bare link, or concise enduring
  invariants plus linked evidence. The last is both usable and maintainable.
- **Differences:** prohibit all differences or require justified recorded
  differences. Repository-local manifest/files/workflow topology may differ;
  security behavior may not drift silently.

### Evaluation rubric

This rubric targets durable cross-repository behavioral convergence.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Observable-contract parity | 23 | Security and platform reviewers need exhaustive comparison of every behavior, not a shared aspiration. |
| Drift resistance over implementation time | 19 | The drafts and implementations can evolve independently before either issue lands. |
| Terraform source-of-truth clarity | 15 | Implementers need one normative local contract rather than competing P1/T1/T2 copies. |
| Downstream cold-start usability | 13 | T2 still needs enough merged prerequisite context to execute safely. |
| Intentional-difference accountability | 11 | Legitimate repository differences must be visible and justified. |
| Executable evidence/traceability | 9 | Matrix rows should point to stable tests, case IDs, commits, and workflow evidence. |
| Delivery independence | 6 | Terraform work should not depend on a new cross-repository runtime service. |
| Draft churn | 4 | Editing duplicated prose is less important than eliminating drift. |

Scoring constraints:

- Narrative-only comparison scores at most 2 for parity.
- Draft-time-only comparison scores at most 2 for drift resistance.
- A score of 5 for source-of-truth clarity gives T1 one normative contract and
  removes T2's duplicate internals.
- A bare downstream link scores at most 2 for cold-start usability.

### Scoring

Columns are parity (PA), drift resistance (DR), authority clarity (AC),
downstream usability (DU), differences (DF), traceability (TR), independence
(IN), and churn (CH).

| Option | PA | DR | AC | DU | DF | TR | IN | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Current one-way prose | 2 | 1 | 2 | 4 | 1 | 2 | 5 | 5 | 45.2 |
| B — Narrative current-P1 review | 2 | 3 | 3 | 4 | 2 | 2 | 5 | 4 | 57.2 |
| C — T1 matrix, T2 duplicate | 5 | 4 | 3 | 4 | 5 | 4 | 5 | 3 | 84.2 |
| D — Matrix, checkpoints, concise T2 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.2** |
| E — Shared runtime module | 5 | 5 | 4 | 4 | 4 | 5 | 0 | 0 | 82.2 |
| F — Full copies | 4 | 1 | 1 | 5 | 2 | 3 | 5 | 1 | 54.8 |
| G — T2 bare dependency | 3 | 4 | 5 | 1 | 3 | 3 | 5 | 5 | 68.6 |

Option D supplies exact convergence evidence while keeping Terraform's own
contract authoritative and T2 usable after T1 merges.

### Selected option and implementation specification

**Select Option D: T1 owns a reciprocal matrix and two current-state
checkpoints; T2 consumes concise enduring invariants and merged evidence.**

Revise T1 to require a matrix with one row for each of:

1. public parameters, types, empty/omitted semantics, and
   definition-only/direct-invocation behavior;
2. exact artifact ID/name/run metadata and SHA-256 provenance flow;
3. trusted-context creation, candidate absence, root/component
   classification, containment, and link/reparse policy;
4. ZIP pre-scan, raw-name treatment, exact manifest, duplicate/collision
   behavior, resource limits, and post-extraction byte checks;
5. the `New/Remove-StyleGuideCandidateInvocationContext` caller lifecycle;
6. `Remove-StyleGuideCandidateInvocationState`, ownership journaling,
   fail-closed nonrecursive cleanup, and diagnostic preservation;
7. stable `V/P/D/Z/M/E/L/B/K/X` case IDs, phases, diagnostics, skips, and
   pre-finally postconditions;
8. workflow triggers, permissions, hosted shells, artifact upload/download,
   writer identity, lease/refspec, and no-op behavior; and
9. CI placement, Node boundary, action allowlist, line-ending checks, and
   evidence retention.

For every row, record the P1 requirement/evidence, T1
requirement/evidence, status (`same`, `intentional difference`, or `blocker`),
and rationale. Manifest names/bytes, repository paths, and workflow topology
can be intentional differences. An unexplained difference in security or
observable error behavior is a blocker.

At implementation start, compare the then-current P1 issue and repository
state before editing TerraformStyleGuide. Before merge, rerun the comparison
against the exact commits tested. Store the completed matrix in the PR or a
tracked design artifact and link every shared harness row by stable ID.

Revise T2 by deleting its frozen helper design copy. Its prerequisite section
must instead require:

- merged T1 commit/evidence;
- the exact candidate generator and helper public entry point it consumes;
- verified digest, exact manifest, containment/link rejection, caller-owned
  context, and fail-closed cleanup as enduring invariants;
- the merged Node/action-pin/workflow security baseline; and
- a link to T1's final reciprocal matrix and CI run.

T2 may restate an invariant it directly relies on, but must not invent helper
parameters, cleanup internals, or test IDs that differ from merged T1.

## T1/T2-2 — Add the missing npm remediation and governance issue

### Problem statement

T1 and T2 defer Node/package/hook/advisory decisions to a later npm issue, but
the TerraformStyleGuide slate contains only T1 and T2. The deferral therefore
has no executable owner, acceptance criteria, sequencing rule, or evidence
contract. Current audit findings and the absent runtime floor are real, not
optional editorial notes.

The slate must include a cold-start issue that owns the complete npm final
state and explains how its final assertions supersede T1's intermediate
package/Dependabot gates.

### Options

#### Option A — Delete the deferral and leave package policy unchanged

Remove references to future work. This makes the two-file slate internally
consistent but knowingly leaves advisories, no declared Node floor, and no npm
update governance.

#### Option B — Add a one-paragraph placeholder

Create a T3 file with a title and broad “upgrade dependencies” instruction.
This fixes the missing filename but not the research, residual-risk approval,
hook behavior, integration evidence, or supersession contract.

#### Option C — Put npm remediation inside T1

Have the already large generator/workflow issue also update packages, lockfile,
hook, runtime policy, audit state, and Dependabot. This eliminates a later
rebase but conflates two independent security changes and makes regression
attribution harder.

#### Option D — Create one complete, separately reviewable T3

Add a real issue that owns package selection, lockfile, declared Node minimum,
hook runtime guard, actual-hook integration tests, advisory disposition,
residual exception schema, npm Dependabot, and final-state revalidation of T1
and T2.

Default execution remains T1 → T2 → T3 because T1 first establishes hosted
Node 24 without changing the compatible current tree. If repository policy
forbids carrying the current advisories during that interval, T3 moves first
and T1/T2 are explicitly rebaselined.

#### Option E — Split runtime policy and dependency remediation

Create one issue for Node/metadata/hook behavior and another for package
updates/audit/Dependabot. This increases independent reviewability but the
runtime floor depends on selected package engines and the hook integration
must validate the final installed tree. The split creates a fragile order and
duplicated clean-install evidence.

#### Option F — Move a complete T3 first unconditionally

Resolve packages and runtime policy before generator/workflow work in every
case. This is the safest order for a zero-open-advisory policy and avoids
testing old packages, but forces T1's large workflow design to rebaseline
before any evidence shows that policy actually requires the interruption.

#### Option G — Merge npm remediation into T2

Update packages while changing state-recovery documentation. The concerns,
reviewers, files, failure modes, and validation platforms are unrelated, so
this reduces both reviewability and rollback safety.

#### Permutations considered

- **Issue count:** none, placeholder, one complete issue, or two coupled
  issues. One complete issue matches the atomic package/runtime boundary.
- **Order:** T1/T2/T3 default or T3 first. The deciding input is repository
  advisory policy, not drafting convenience.
- **Node ownership:** T1's hosted major versus T3's final contributor/package
  minimum. Both must be explicit and compatible.
- **Audit outcome:** zero findings or structured residual exceptions. Both
  require exact machine-readable evidence; “audit ran” is insufficient.
- **Tests:** ordinary lint only or exact hook integration. The actual
  `.husky/pre-commit` skip/pass/lint/tool-failure behavior is mandatory.
- **Dependabot:** replace T1's one-entry intermediate invariant with exactly
  two final entries, not simply append unchecked YAML.

### Evaluation rubric

This rubric targets a complete, schedulable npm security work item.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Security/remediation completeness | 23 | The owner must address packages, advisories, runtime policy, hook behavior, and update governance together. |
| Executable final-state evidence | 18 | Reviewers need clean install, audit, lint, and exact-hook outcomes on supported runtimes. |
| Independent review/rollback boundary | 15 | Package security changes should be attributable and reversible separately from workflow and prose redesigns. |
| Sequential-slate coherence | 14 | Every deferred requirement needs a real issue and a policy-aware execution order. |
| Supersession precision | 11 | Final two-entry Dependabot and changed package files must intentionally replace intermediate T1 assertions. |
| Contributor usability | 9 | The chosen floor and hook failure must be understandable on terminals and GUI Git clients. |
| Cold-start implementability | 6 | A new engineer needs exact files, decisions, commands, and acceptance evidence. |
| Draft/churn cost | 4 | Another issue file is cheap compared with an ownerless security obligation. |

Scoring constraints:

- A placeholder scores at most 1 for completeness and evidence.
- Combining unrelated state-document work scores at most 1 for review
  boundary.
- A score of 5 for supersession names the intermediate assertions that the
  final issue replaces while retaining enduring T1/T2 behavior.
- A score of 5 for sequence includes the zero-advisory-policy exception.

### Scoring

Columns are completeness (CP), evidence (EV), review boundary (RB), sequence
(SQ), supersession (SP), usability (US), implementability (IM), and churn
(CH).

| Option | CP | EV | RB | SQ | SP | US | IM | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Leave policy unchanged | 0 | 0 | 3 | 1 | 0 | 1 | 1 | 5 | 18.8 |
| B — Placeholder T3 | 1 | 1 | 4 | 3 | 1 | 2 | 1 | 4 | 38.8 |
| C — Fold into T1 | 5 | 5 | 1 | 4 | 3 | 5 | 3 | 1 | 75.2 |
| D — Complete separate T3 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.2** |
| E — Split into two issues | 5 | 4 | 4 | 3 | 4 | 4 | 3 | 1 | 78.2 |
| F — T3 first always | 5 | 5 | 5 | 3 | 5 | 5 | 5 | 3 | 92.8 |
| G — Fold into T2 | 4 | 4 | 1 | 3 | 2 | 3 | 2 | 1 | 57.2 |

Option D creates the missing owner without coupling unrelated work. Its
policy-aware ordering makes the default practical without treating known
advisories as indefinitely acceptable.

### Selected option and implementation specification

**Select Option D: create
`docs/planning/TerraformStyleGuide/05TerraformStyleGuideT3.md` as a complete
npm remediation and governance issue.**

The issue's H1 title will be:

`# Remediate Markdown lint dependency advisories and add npm update governance`

It must:

1. Start from exact merged T1/T2 commits and classify T1's package/lock/hook
   path gate and one-entry Dependabot assertion as implementation-time
   intermediate controls, not enduring final invariants.
2. Inventory `package.json`, lockfile version/tree, `.husky/pre-commit`,
   nested-lint entry point, lint configuration, current Node/npm versions, and
   the complete `npm audit --package-lock-only --json` URL/dependency-path set.
3. Select maintained compatible direct package versions without `--force`;
   justify every major change and regenerate the lockfile with the selected
   supported npm.
4. Declare an exact supported minimum in `engines.node`; retain hosted Node 24
   as the preferred CI line; and add an early hook guard whose stable
   diagnostic explains the observed version, required minimum, and remediation.
5. Prove clean `npm ci`, ordinary outer lint, nested lint, and the actual
   Terraform `.husky/pre-commit` skip, pass, lint-rejection, and tooling-failure
   paths in an isolated repository/index on both the minimum and Node 24.
6. Require zero audit findings at the chosen threshold, or a structured,
   exhaustive, unique residual exception for every advisory URL and dependency
   path with owner, UTC expiry, rationale, and real follow-up issue. A package
   count alone is not approval.
7. Change `.github/dependabot.yml` to an exact two-entry final state:
   `github-actions` at `/` and `npm` at `/.github/workflows`, with approved
   schedules and no automatic approval/merge additions.
8. Re-run T1 generator, helper/harness, action allowlist, workflow permissions,
   artifact, writer/no-op, LF, and lint behavior; re-run T2 exact-block shell
   tests and generated-output checks.
9. Distinguish one-time path gates that are superseded from enduring behavior
   that must remain green. Recompute T3's exact affected-file set after package
   selection rather than copying an old count.
10. Use default slate order T1 → T2 → T3 only after recording that repository
    policy permits the interim audit state. If policy requires zero current
    high-severity findings, execute T3 first and rebaseline both later issues
    on its exact merge commit.

## T2-1 — Close the HCP host, page-number, and token grammars

### Problem statement

T2's HCP state-version example hardcodes `app.terraform.io`, checks only that
the page is nonempty, and places an arbitrary token inside a quoted curl config
value. That excludes the official Europe control plane while leaving query
syntax and curl's own backslash/quote parser under-specified.

The example must support the two public HCP Terraform control planes without
turning a bearer token into a general-purpose arbitrary-host credential.

### Options

#### Option A — Keep the US host hardcoded

Validate the page and token more strongly but document the example as non-EU
only. This is secure for its stated destination but fails a real supported HCP
deployment and invites users to hand-edit URLs.

#### Option B — Accept arbitrary `TFC_ADDRESS`

Let users supply any HTTPS base URL and append `/api/v2`. This supports HCP and
Terraform Enterprise but creates a credential-destination boundary that the
example cannot validate from syntax alone.

#### Option C — Use a closed two-host selector

Require `TFC_HOST` to equal exactly `app.terraform.io` or
`app.eu.terraform.io`; reject everything else before token expansion or file
creation. Require canonical positive-decimal `PAGE_NUMBER`, fixed page size
100, and a token grammar that rejects config-file metacharacters and controls.

#### Option D — Publish separate US and EU command blocks

Duplicate the complete example with only the hostname changed. This is
explicit, but every safety fix and test must remain synchronized across two
large blocks.

#### Option E — Derive the hostname from Terraform CLI credentials

Parse the user's CLI config/credentials file and select the matching host.
This may be convenient, but adds a sensitive-file parser, precedence rules,
and implicit behavior to a recovery command that should show its destination.

#### Option F — Support an administrator-maintained host allowlist

Accept HCP or Terraform Enterprise hosts only if they appear in a separate
allowlist file. This is the right pattern for an enterprise-specific guide,
but the public repository has no trusted distribution or ownership mechanism
for such a file.

#### Option G — Put the bearer header directly on curl's command line

Avoid curl config quoting by passing `--header "Authorization: Bearer ..."`
as an argument. This makes the secret more likely to appear in process
listings, shell traces, history, and diagnostics and does not solve host/page
validation.

#### Permutations considered

- **Host:** hardcoded US, closed US/EU selector, arbitrary URL, or
  administrator allowlist. Public HCP scope supports exactly two closed hosts.
- **Host representation:** host only versus scheme/base URL. Host-only input
  prevents scheme, path, userinfo, port, query, and fragment injection.
- **Page:** nonempty, digits, canonical positive decimal, or machine integer.
  Canonical decimal rejects zero, signs, whitespace, leading zeros, and query
  characters without shell arithmetic overflow.
- **Token:** arbitrary quoted value, escaped value, or closed rejection
  grammar. Rejecting quote/backslash/control is easier to audit than writing a
  new curl-config escaper.
- **Secret transport:** command line, environment-expanded heredoc, private
  config file, or stdin config. One private owned file enables explicit
  permissions, controlled invocation, and cleanup.

### Evaluation rubric

This rubric targets credential destination and parser safety in a recovery
example.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Bearer-token destination confinement | 24 | A high-privilege state token must never be sent to an arbitrary or malformed host. |
| Token/config parser safety | 19 | curl's config grammar must not reinterpret token bytes as escapes, new options, or lines. |
| Supported HCP deployment coverage | 15 | The guide must work for both official HCP Terraform control planes. |
| Query/page semantic correctness | 13 | Page inputs must produce one unambiguous state-version request. |
| Secret exposure and cleanup | 11 | The example must minimize process/history leakage and remove only its owned secret file. |
| Testability and diagnostics | 8 | Stub tests need deterministic pre-curl failures and exact argv/config evidence. |
| Reader usability | 6 | Operators must see and deliberately select the credential destination. |
| Documentation churn | 4 | Duplication cost matters after credential safety and coverage. |

Scoring constraints:

- An arbitrary caller-supplied host scores 0 for destination confinement.
- A command-line bearer value scores at most 1 for secret exposure.
- A score of 5 for page correctness requires a canonical positive decimal
  before URL construction.
- A score of 5 for token safety rejects curl-config metacharacters and controls
  before file creation.

### Scoring

Columns are destination (DS), token parser safety (TS), coverage (CV), page
semantics (PG), secret handling (SH), tests (TE), usability (US), and churn
(CH).

| Option | DS | TS | CV | PG | SH | TE | US | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — US only | 5 | 5 | 2 | 5 | 5 | 5 | 3 | 5 | 88.6 |
| B — Arbitrary address | 0 | 5 | 5 | 5 | 5 | 3 | 4 | 4 | 70.8 |
| C — Closed US/EU selector | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.2** |
| D — Duplicate US/EU blocks | 5 | 5 | 5 | 5 | 5 | 4 | 3 | 1 | 92.8 |
| E — CLI-config discovery | 3 | 3 | 5 | 5 | 3 | 2 | 2 | 1 | 66.8 |
| F — External allowlist | 5 | 5 | 5 | 5 | 4 | 3 | 2 | 1 | 87.8 |
| G — Header on argv | 4 | 2 | 5 | 5 | 1 | 4 | 4 | 4 | 71.4 |

Option C covers both official public services while retaining a closed,
visible credential destination and a simple reject-before-side-effects parser.

### Selected option and implementation specification

**Select Option C: exact US/EU HCP host allowlist, canonical positive page,
and closed curl-config token grammar.**

Revise T2's exact source blocks and tests to require:

1. Inputs named `TFC_HOST`, `TFC_ORGANIZATION`, `TFC_WORKSPACE`,
   `PAGE_NUMBER`, and `TFC_TOKEN`. Assign every input once before validation.
2. `TFC_HOST` must be exact ordinal text `app.terraform.io` or
   `app.eu.terraform.io`. It contains no scheme, port, slash, userinfo, query,
   or fragment. Validate it before expanding/reading the token.
3. `PAGE_NUMBER` must match `^[1-9][0-9]*$` exactly. Do not trim, coerce, or
   evaluate it arithmetically. Use fixed `page[size]=100`.
4. Organization and workspace values must be nonempty, canonical for the
   documented HCP name grammar, and passed through curl's URL-query encoding
   rather than concatenated as raw query text.
5. `TFC_TOKEN` must be nonempty and must contain no CR, LF, NUL/control
   character, double quote, or backslash. Reject before any config file or
   network operation; never print the token.
6. Create one unpredictable, absent, mode-0600 config file in an owned
   temporary directory with restrictive `umask`; write one option per physical
   line and the quoted bearer header only after validation.
7. Invoke the resolved curl binary with `--disable`, an explicit
   `--config <exact-file>`, fail/show-error/silent controls, and the exact
   HTTPS URL whose authority is the selected host. Do not read ambient
   `.curlrc`.
8. Remove only the exact ordinary file and owned empty directory in a trap on
   every exit; refuse recursive or link-following cleanup.
9. Keep Terraform Enterprise out of this public block. Add separate
   enterprise guidance only when a repository-controlled host trust model is
   designed.
10. Add stubbed tests for both allowed hosts; arbitrary host, scheme, port,
    path, and userinfo; page empty/zero/negative/plus/space/leading-zero/query
    payloads; token empty/CR/LF/quote/backslash/control; exact URL/query
    encoding; config mode/content; no ambient config; and failure cleanup.

## T2-2 — Match state-safety claims to an exact inventory

### Problem statement

T2 hardens four provider-specific state-version retrieval blocks, but the two
source documents contain other state operations: direct-redirection backups,
destructive `terraform state push`, `terraform state rm`, a local corruption
move, and another S3 listing path. “Every recovery destination” could be read
as local to T2, but it is not explicit enough to support a universal claim.

The four retrieval blocks should remain sharply testable, while genuinely
unsafe adjacent state-management examples receive a real owner.

### Options

#### Option A — Keep the broad wording

Assume readers understand “every” to mean the four modified blocks. This avoids
edits but leaves acceptance criteria apparently contradicted by live source.

#### Option B — Narrow T2 to four blocks and stop

Say “every destination introduced or modified by this issue,” enumerate the
four blocks, and record all other operations as out of scope. The claim becomes
truthful, but confirmed direct-redirection and destructive examples remain
ownerless.

#### Option C — Narrow T2 and create a concrete follow-up

Keep T2 on exact S3/Azure/GCS/HCP version discovery and fresh-file retrieval.
Record the complete adjacent inventory and create a separately reviewable T4
for safe manual backups, destructive push/rm recovery, and local corruption
handling.

#### Option D — Expand T2 to every state-management example

Harden retrieval, backups, push, rm, moves, concurrency, confirmation, and
rollback in one issue. This achieves source-wide coverage, but combines
read-only provider retrieval with destructive state mutation and substantially
expands an already large issue and harness.

#### Option E — Expand T2 only within `STYLE_GUIDE.md`

Fix the main guide's adjacent examples while leaving the rationale's older
examples for later. This creates inconsistent source authority and generated
outputs can continue propagating unsafe rationale content.

#### Option F — Split provider/destructive workflows into separate issues

Create S3, Azure, GCS, HCP, backup, and destructive-recovery issues. This gives
maximum review isolation but duplicates the shared destination primitive,
generation pipeline, shell harness, and state-secret warnings.

#### Option G — Replace command hardening with warnings

Add prominent warnings that users must choose fresh paths and verify backups.
Warnings are useful context but do not stop redirection truncation, unsafe
identifiers, or accidental destructive commands when copied.

#### Permutations considered

- **Quantifier:** universal, implicit local, or explicit
  introduced/modified scope. Only the last is mechanically reviewable.
- **Inventory:** target blocks only, main guide only, or both authoritative
  source documents. Both sources must be examined before declaring follow-up.
- **Ownership:** leave adjacent findings as notes, absorb them, or file a real
  issue. Confirmed unsafe examples require a fileable owner.
- **Boundary:** versioned-object retrieval versus state creation/mutation.
  Their credentials, concurrency, rollback, and test oracles differ.
- **Warning:** provider-specific repetitions or one shared sensitive-state
  warning. The shared warning remains useful without claiming universal code
  hardening.

### Evaluation rubric

This rubric targets truthful scope and complete safety ownership.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Claim-to-source accuracy | 21 | Acceptance language must describe exactly the commands the issue changes and tests. |
| Unsafe-example ownership | 20 | Confirmed truncating/destructive examples cannot disappear into an out-of-scope note. |
| Reviewable safety boundary | 17 | Read-only version retrieval and destructive state mutation need distinct review and rollback reasoning. |
| Inventory completeness | 14 | Both source documents and generated surfaces must be accounted for. |
| Executable evidence focus | 11 | T2's shell harness needs a finite exact block set with stable oracles. |
| Sequential-slate clarity | 8 | Project managers need a real follow-up position and dependency, not an indefinite TODO. |
| Reader safety/usability | 6 | Users need consistent warnings and copy-safe commands at every owned surface. |
| Issue/file churn | 3 | An extra issue costs less than a false universal guarantee or mixed mutation scope. |

Scoring constraints:

- A universal claim without source-wide changes scores 0 for accuracy.
- An out-of-scope inventory with no real owner scores at most 1 for ownership.
- Mixing retrieval and destructive mutation scores at most 2 for boundary.
- A score of 5 for inventory covers both source documents and generated
  outputs.

### Scoring

Columns are accuracy (AC), ownership (OW), boundary (BD), inventory (IN),
evidence focus (EV), sequence (SQ), reader safety (RS), and churn (CH).

| Option | AC | OW | BD | IN | EV | SQ | RS | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Broad wording | 0 | 0 | 3 | 1 | 2 | 1 | 1 | 5 | 23.2 |
| B — Narrow and stop | 5 | 1 | 5 | 5 | 5 | 2 | 2 | 5 | 75.6 |
| C — Narrow plus real follow-up | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.4** |
| D — Expand T2 source-wide | 5 | 5 | 2 | 5 | 2 | 3 | 5 | 1 | 77.6 |
| E — Main guide only | 4 | 2 | 3 | 2 | 3 | 2 | 3 | 3 | 55.8 |
| F — Six issues | 5 | 5 | 5 | 5 | 3 | 2 | 4 | 0 | 86.6 |
| G — Warnings only | 2 | 1 | 4 | 3 | 1 | 1 | 2 | 5 | 43.6 |

Option C gives T2 a finite truthful test boundary and converts the confirmed
adjacent risk into an independently schedulable work item.

### Selected option and implementation specification

**Select Option C: constrain T2 to four named retrieval surfaces and create a
real destructive-state follow-up.**

Revise T2 to:

1. Replace every universal phrase with “every recovery destination introduced
   or modified by this issue” where that is the actual quantifier.
2. Name the exact four owned blocks: S3 object-version discovery/retrieval,
   Azure Blob version discovery/retrieval, GCS generation
   discovery/retrieval, and HCP Terraform state-version API discovery/download.
3. Give each exact finalized source block a stable extraction marker and shell
   harness ID. Acceptance is exact equality between the inventory, markers,
   extracted blocks, and tests.
4. Retain one provider-neutral warning that state files, provider responses,
   signed/Archivist URLs, and diagnostics can contain secrets. Do not claim the
   warning hardens unmodified commands elsewhere.
5. List the reviewed out-of-scope locations in `STYLE_GUIDE.md` and
   `STYLE_GUIDE_RATIONALE.md`, including each direct `state pull` redirection,
   `state push`, `state rm`, corruption move, and overlapping S3/provider
   example.
6. State that T2 neither authorizes nor validates destructive state mutation.

Create
`docs/planning/TerraformStyleGuide/06TerraformStyleGuideT4.md` with H1:

`# Make manual state backup and destructive recovery guidance copy-safe`

T4 must be ordered after T2 and may run before or after npm-only T3 when teams
are independent; the linear slate lists it after T3 to avoid simultaneous
edits to shared generated documentation. It must:

- replace truncating backup redirections with a fresh protected-file primitive
  that validates `terraform state pull` before publication;
- guard local corruption moves against existing/link destinations;
- put `state push` and `state rm` behind explicit current-state backup,
  workspace/backend identity, lock/concurrency, review, confirmation, and
  rollback preconditions;
- consolidate or cross-reference duplicate provider examples rather than
  preserving older unsafe variants;
- cover both source documents and all four generated guide outputs; and
- add non-network behavioral tests for fresh/existing/link destinations,
  Terraform failures, confirmation refusal, concurrency/identity mismatch,
  and no destructive command before prerequisites pass.

## T2-3 — Permanently test the exact finalized shell blocks

### Problem statement

T2 relies mainly on syntax/static review and an HCP xtrace exercise, even
though its central claim is that four multi-step shell surfaces are safe to
copy. Syntax checks cannot prove exact provider arguments, validation order,
fresh-file behavior, link rejection, cleanup, or preserved IDs.

The implementation evidence should remain coupled to the exact Markdown source
and run without cloud credentials or network access.

### Options

#### Option A — Retain static review and `bash -n`

Validate syntax, prohibited text patterns, and generated output. This is cheap
but does not execute any safety behavior.

#### Option B — Use an untracked implementation-time harness

Build a temporary test script in the PR, store its logs, and leave T2's source
file set unchanged. This can prove the initial implementation, but future edits
lose the test and exact source/harness drift is undetectable.

#### Option C — Track a harness that copies the examples

Add a permanent Bash test with function versions of the provider commands.
It gives regression coverage, but the tested copies can diverge from the
Markdown readers actually paste.

#### Option D — Track and run an exact-block extraction harness

Put stable invisible markers around each finalized source block. A tracked
Bash harness extracts the literal body, syntax-checks it, executes it in an
owned sandbox with non-network stubs, and asserts NUL-delimited argument
vectors, call ordering, diagnostics, and filesystem postconditions. Run it in
the ordinary Ubuntu Markdown workflow.

#### Option E — Adopt Bats and test extracted blocks

Use Bats for readable cases and fixtures. It provides a mature test format but
adds another package/tool bootstrap and version pin for a focused repository
harness that can be expressed in Bash.

#### Option F — Run live provider integration tests

Use test cloud accounts and real AWS/Azure/GCP/HCP calls. This proves current
CLI/service behavior but requires secrets, billable resources, retention
fixtures, cleanup, rate handling, and redaction. It is unsuitable as the only
required PR check.

#### Option G — Run shellcheck only

Lint the extracted scripts for common shell defects. Shellcheck is useful
static evidence but cannot prove provider argv, no-clobber semantics, token
redaction, or destination postconditions.

#### Permutations considered

- **Persistence:** PR artifact only or tracked test. Safety claims need
  regression protection.
- **Source relation:** copy, source function, or exact marker extraction.
  Extraction proves the actual reader-visible body.
- **Provider behavior:** live services, generic success/failure commands, or
  provider-specific stubs. Stubs give deterministic exact argv and sequencing.
- **Argument capture:** shell-joined strings or NUL-delimited vectors.
  NUL-delimited capture preserves spaces and metacharacters unambiguously.
- **CI placement:** new workflow, existing Markdown job, or manual command.
  The existing Ubuntu job already owns these source files and Bash runtime.
- **Fixtures:** only happy paths or full destination/identifier/secret
  matrices. Every promised guard needs a positive and negative oracle.

### Evaluation rubric

This rubric targets executable fidelity of copyable shell documentation.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Exact reader-visible block fidelity | 22 | The test must execute the command body users copy, not a similar test implementation. |
| Behavioral safety coverage | 20 | Destinations, identifiers, token handling, provider order, cleanup, and failures all need postconditions. |
| Durable regression protection | 17 | A later prose edit must not invalidate one-time evidence silently. |
| Non-network determinism and secret safety | 13 | Required PR checks must run without credentials, billable services, or secret exposure. |
| Argument/call-order observability | 10 | Tests must distinguish exact argv elements and prove no provider call before validation. |
| Failure diagnostics | 8 | Each case must assert the intended rejection reason, not merely nonzero exit. |
| CI/toolchain fit | 6 | The harness should run on the existing supported Bash/Ubuntu surface. |
| File/churn cost | 4 | Two tracked changes are worthwhile when they preserve the security contract. |

Scoring constraints:

- Copied example logic scores at most 2 for block fidelity.
- Untracked evidence scores at most 1 for durability.
- Live-only tests score at most 1 for non-network determinism.
- A score of 5 for observability requires unambiguous argv capture and ordered
  call records.

### Scoring

Columns are fidelity (FD), coverage (CV), durability (DU), determinism (DT),
observability (OB), diagnostics (DG), CI fit (CI), and churn (CH).

| Option | FD | CV | DU | DT | OB | DG | CI | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Static and syntax only | 3 | 1 | 4 | 5 | 0 | 2 | 5 | 5 | 57.0 |
| B — Untracked harness | 5 | 5 | 1 | 5 | 5 | 5 | 4 | 5 | 85.2 |
| C — Tracked copied harness | 2 | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 86.0 |
| D — Tracked exact extraction | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.2** |
| E — Bats extraction | 5 | 5 | 5 | 4 | 5 | 5 | 3 | 1 | 91.8 |
| F — Live integrations | 5 | 4 | 3 | 1 | 3 | 3 | 1 | 0 | 62.8 |
| G — Shellcheck only | 4 | 2 | 5 | 5 | 1 | 2 | 3 | 3 | 66.8 |

Option D tests the shipped text, remains deterministic, and makes the modest
file-boundary expansion explicit.

### Selected option and implementation specification

**Select Option D: add a tracked exact-block Bash harness and run it in the
ordinary Ubuntu Markdown workflow.**

Revise T2 to add:

- `.github/workflows/Test-StateRecoveryExamples.sh`; and
- `.github/workflows/markdownlint.yml`

to its affected files, path gates, version requirements, validation, and
acceptance criteria. Together with the two sources and four generated outputs,
the selected T2 file set is eight files.

Implementation requirements:

1. Add paired, unique, invisible Markdown markers around every exact finalized
   S3, Azure, GCS, and HCP discovery/retrieval block in the two authoritative
   sources. Give each block a stable `SR-*` ID and do not nest markers.
2. The harness validates exact one-to-one equality among the issue inventory,
   source markers, extracted bodies, generated copies, and executed tests.
   Missing, duplicate, malformed, or unexpected markers fail.
3. Extract block bodies without evaluating the surrounding Markdown. Run
   `bash -n` on each exact body before any behavioral case.
4. Execute in a newly created owned sandbox with a closed `PATH` containing
   test-owned `aws`, `az`, `gcloud`, `curl`, `terraform`, and supporting
   command stubs. Block or fail every unexpected executable and every network
   attempt.
5. Capture each stub invocation as a NUL-delimited argv record plus an ordered
   call log. Never compare a shell-reconstructed command string.
6. Cover missing, empty, relative, existing ordinary file, existing directory,
   live link, and dangling-link destinations before a provider call; valid
   absolute fresh destinations containing spaces and shell metacharacters;
   successful output; provider failure; partial-file retention/removal exactly
   as documented; restrictive modes; and owned cleanup.
7. Assert selected S3/Azure IDs and GCS generations are unchanged argument
   elements, exact provider filters and native no-clobber flags, and no
   automatic version selection.
8. Cover both HCP hosts; every rejected host class; valid/invalid page
   grammar; token empty/CR/LF/quote/backslash/control; inherited xtrace; exact
   curl config/argv; simulated curl failure; invalid partial response
   retention; and absence of token bytes from stdout/stderr/call logs.
9. Assert the expected stable rejection code/message and filesystem
   postcondition in every negative case, not only a nonzero status.
10. Invoke the harness from the existing `markdownlint` Ubuntu job after T1's
    clean install and lint steps. Preserve T1's exact action allowlist,
    permissions, triggers, Node 24 boundary, and one read-only job. The
    verifier must include the new stable step role.

## T2-4 — Bind local npm validation to the merged Node contract

### Problem statement

T2 tells an implementer to run ambient `npm ci` and lint, but does not verify
the Node process that npm will use, bind one executable pair, or contain the
temporary `CI=true` environment change. With T1 now owning hosted Node 24,
ambient success on an older or unrelated runtime is not evidence for the
merged workflow.

T2 must validate, not change, the package/runtime baseline.

### Options

#### Option A — Keep ambient `npm`

Rely on the developer's PATH and record command success. This is convenient
but cannot show which Node/npm pair executed or whether it matches CI.

#### Option B — Check `node --version`, then call ambient npm repeatedly

Require Node major 24 before install. A PATH mutation, shim, or separate npm
launcher can still cause later commands to use another Node installation.

#### Option C — Resolve and reuse one Node/npm pair

Resolve the concrete Node and npm applications once, query both versions,
prove npm's actual Node process is major 24, then invoke the exact npm
application for clean install and both existing lint scripts. Set `CI=true`
only around `npm ci` and restore the prior value in `finally`.

#### Option D — Validate both Node 22 and 24 in T2

Create two local environments and run the unchanged tree twice. This anticipates
T3's contributor-floor decision, but T2 owns neither package compatibility nor
the future minimum and would duplicate T3 evidence.

#### Option E — Use a Node 24 container

Run npm and lint inside a digest-pinned container. This proves one runtime but
changes path, permission, Git, line-ending, and hook context and is not the
hosted/local boundary T1 established.

#### Option F — Install a temporary version manager/toolchain

Have the issue install Node 24 through nvm/fnm/Volta before validation. This
can produce a known runtime but adds network/install trust and changes the
developer machine. T2 should fail clearly and let the contributor select their
normal supported installation method.

#### Option G — Defer all npm validation to T3

Skip local lint in T2 because T3 later owns packages. That leaves T2 unable to
prove its large Markdown changes lint under the current merged workflow.

#### Permutations considered

- **Required major:** T1's exact hosted 24, a future T3 minimum, or both. In
  default order T2 consumes T1's major 24; a T3-first order consumes the
  rebaselined merged contract.
- **Resolution:** names on PATH for every call or exact resolved applications
  once. One pair makes logs and failures comparable.
- **npm/Node binding:** infer from file adjacency or query npm's running
  `process.execPath`/`process.versions.node`. Behavior is stronger than layout.
- **CI environment:** process-wide unbounded assignment, command prefix, or
  saved/restored scoped value. PowerShell `finally` handles success/failure.
- **Ownership:** validate unchanged package/lock/hook or update them. T2 must
  not perform npm policy work.

### Evaluation rubric

This rubric targets trustworthy local reproduction of the merged lint runtime.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Runtime-contract fidelity | 23 | Local evidence must use the major established by the merged prerequisite. |
| Node/npm executable binding | 19 | All install/lint commands must demonstrably use one resolved toolchain. |
| Clean-install and lint evidence | 17 | T2 must prove both real lint surfaces after `npm ci`. |
| Environment containment | 13 | Temporary CI semantics must not leak into the caller's shell. |
| Failure/diagnostic clarity | 10 | A cold-start user needs observed paths/versions and exact failed phase. |
| Package-scope preservation | 9 | T2 must not mutate package, lockfile, hook, or runtime policy. |
| Cross-platform usability | 5 | The procedure should work from PowerShell on supported local systems. |
| Setup/churn cost | 4 | No toolchain installer is needed for a validation gate. |

Scoring constraints:

- Ambient npm without actual runtime evidence scores 0 for binding.
- A score of 5 for environment containment saves absence/value and restores
  it in `finally`.
- A score of 5 for evidence requires clean install plus both exact lint
  commands through the same npm application.
- Any package/runtime-policy mutation scores 0 for scope preservation.

### Scoring

Columns are runtime fidelity (RF), binding (BD), evidence (EV), environment
(EN), diagnostics (DG), scope (SC), usability (US), and churn (CH).

| Option | RF | BD | EV | EN | DG | SC | US | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Ambient npm | 1 | 0 | 4 | 2 | 1 | 5 | 5 | 5 | 43.4 |
| B — Check node, ambient npm | 4 | 2 | 4 | 3 | 3 | 5 | 5 | 5 | 71.4 |
| C — One resolved pair | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| D — Node 22/24 local matrix | 4 | 4 | 5 | 5 | 4 | 3 | 2 | 2 | 80.6 |
| E — Container | 5 | 5 | 4 | 5 | 4 | 5 | 1 | 1 | 87.4 |
| F — Temporary installer | 5 | 4 | 5 | 3 | 3 | 3 | 2 | 0 | 76.4 |
| G — Defer to T3 | 0 | 0 | 0 | 5 | 2 | 5 | 3 | 5 | 33.0 |

Option C supplies exact local evidence with no repository or machine mutation
beyond the ordinary clean install.

### Selected option and implementation specification

**Select Option C: resolve one Node/npm pair, require the merged major, and
scope `CI=true` to installation.**

Revise T2's local validation procedure to:

1. Resolve `node` and `npm` as applications once, reject aliases/functions/
   scripts that obscure the selected executable, and record normalized paths.
2. Invoke the resolved Node application to record full version and require
   exact major 24 under the default T1 → T2 order.
3. Invoke the resolved npm application to record full npm version and execute
   a small no-package script proving its observed Node version and
   `process.execPath` match the selected Node application/major.
4. Save whether process environment variable `CI` existed and its exact value.
   Set process-scoped `CI=true` only for the clean install. In `finally`, restore
   the prior value exactly or remove the variable if it was initially absent.
5. Run the exact resolved npm application with `ci` from
   `.github/workflows`, capture its native exit, and stop on failure.
6. Use the same npm application for the unchanged outer and nested lint
   scripts. Record and classify each exit independently.
7. Prove `package.json`, `package-lock.json`, `.husky/pre-commit`, Node policy,
   lint configuration, and npm configuration are unchanged by T2.
8. If T3 is executed first due to advisory policy, replace “major 24” with the
   exact merged T3 minimum/preferred contract and rebaseline T2 before work;
   do not guess a runtime from the draft.

## I-1 — Split T1 at natural atomic review boundaries

### Problem statement

The current T1 is 93,982 bytes and 2,029 lines. Its H1 describes deterministic
generation and LF checkouts, while the issue also designs a secure archive
library, adversarial harness, artifact transport, approval topology, and
compare-and-swap writer. The concerns are related in sequence, but they are not
one review or rollback unit.

A split must not sever the archive helper from its cleanup/harness or activate
the writer before its validation dependencies exist.

### Options

#### Option A — Keep the current issue unchanged

One issue and PR can land the entire end state atomically. It avoids temporary
states but makes assignment, review, evidence, reruns, rollback, and failure
attribution unmanageably broad.

#### Option B — Keep one issue but add a table of contents and work packages

Restructure T1 into explicit requirement IDs, implementation phases, and
review checkpoints while retaining one filing and merge. This materially
improves navigation, but the issue still has one enormous acceptance surface
and cannot be scheduled or rolled back by concern.

#### Option C — Split generator/LF from everything else

Keep T1 focused on its title and put helper, harness, artifact pipeline, and
writer into one second issue. The first issue becomes coherent, but the second
remains a very large security and workflow activation review.

#### Option D — Split into three sequential atomic issues

Use:

1. foundations: deterministic generator, LF, hosted Node/action/update
   baseline;
2. security library: archive helper, trusted caller context, exact cleanup,
   stable-ID adversarial harness; and
3. activation: artifact producer/consumer, matrices, approval, writer, lease,
   no-op, and at-use harness integration.

Keep the current T1 filename/H1 for the first, then insert ordered `03a` and
`03b` issue files before the existing T2.

#### Option E — Create an umbrella T1 plus three child issues

Retain the 2,000-line document as an epic and create three separately complete
children. This gives project tracking but duplicates acceptance language and
leaves ambiguity about whether closing the umbrella or each child is the
normative gate.

#### Option F — Split every subsystem into its own issue

Create individual generator, LF, action, helper, context, harness, producer,
consumer, matrix, approval, and writer issues. Each review is small, but
security invariants span issues and many intermediate states are unusable or
unsafe.

#### Option G — Keep one issue but use multiple PRs into an integration branch

Review scoped PRs against a temporary branch and merge that branch atomically
to `main`. This can work operationally, but the repository does not document
such a branch/release process and the one issue still obscures dependency and
closure status.

#### Permutations considered

- **Split count:** one, two, three, or subsystem-per-issue. Three matches the
  dependency graph without fragmenting a security boundary.
- **Activation timing:** each issue immediately changes production behavior or
  library-first then activation. The helper issue adds reviewed inactive code;
  the activation issue is the only consumer/writer topology change.
- **Filename/order:** renumber all later issues or insert `03a`/`03b`.
  Insertion preserves the already evaluated T2/T3/T4 identities.
- **Foundational action policy:** pin the current workflow in the first issue,
  then atomically update the exact role/count allowlist during activation.
- **Evidence:** one giant validation record or per-boundary evidence plus a
  final end-to-end gate. Each issue needs its own proof; activation reruns all.

### Evaluation rubric

This rubric targets issue atomicity without weakening the security sequence.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Natural boundary correctness | 22 | Files and requirements that enforce one security invariant must land and review together. |
| Human reviewability | 20 | Reviewers need a bounded design, diff, test matrix, and acceptance decision. |
| Intermediate-state safety | 17 | Sequential merges must not activate an unvalidated writer or weaken the current repository. |
| Dependency/sequence clarity | 14 | Each issue must consume exact merged evidence and expose a clear blocker chain. |
| Requirement traceability | 10 | Every original and selected finding must have one new owner with no loss or duplication. |
| Rollback/failure attribution | 8 | A regression should map to a coherent change that can be reverted independently. |
| Cold-start implementability | 6 | Each filing must stand alone after following its explicit prerequisite. |
| Slate/file churn | 3 | Two extra issue files are a small cost relative to a 94 KB mixed review. |

Scoring constraints:

- An issue that still combines the complete helper library and activation
  pipeline scores at most 3 for reviewability.
- Splitting helper validation from cleanup/harness scores at most 1 for natural
  boundaries.
- A score of 5 for intermediate safety keeps new library code inactive until
  activation and reruns it at use.
- An umbrella plus duplicated child requirements scores at most 3 for
  traceability.

### Scoring

Columns are boundary correctness (BC), reviewability (RV), intermediate safety
(IS), sequence (SQ), traceability (TR), rollback (RB), implementability (IM),
and churn (CH).

| Option | BC | RV | IS | SQ | TR | RB | IM | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — One unchanged issue | 3 | 1 | 5 | 3 | 3 | 1 | 2 | 5 | 55.6 |
| B — One structured issue | 4 | 3 | 5 | 4 | 4 | 2 | 4 | 4 | 76.2 |
| C — Two issues | 4 | 3 | 5 | 5 | 4 | 3 | 4 | 4 | 80.6 |
| D — Three atomic issues | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.4** |
| E — Epic plus children | 5 | 5 | 5 | 4 | 3 | 5 | 4 | 1 | 89.6 |
| F — Subsystem issues | 2 | 5 | 2 | 2 | 3 | 4 | 2 | 0 | 56.0 |
| G — Integration branch | 4 | 4 | 5 | 3 | 3 | 3 | 2 | 2 | 73.4 |

Option D is the smallest split that makes every review coherent while keeping
the archive security boundary and workflow activation boundary intact.

### Selected option and implementation specification

**Select Option D: replace the monolithic T1 with three sequential issue
filings.**

The final allocation is:

1. `03TerraformStyleGuideT1.md`, retaining H1
   `# Make artifact generation byte-deterministic and standardize repository
   text checkouts on LF`, owns:
   - generator CR/encoding/path determinism and unchanged regenerated bytes;
   - `.gitattributes` LF policy and cross-edition validation;
   - Markdown workflow hosted Node 24 with disabled automatic cache;
   - immutable pins for existing external actions, the initial exact role
     allowlist, and one GitHub Actions Dependabot entry; and
   - current-workflow trigger/permission review without activating the new
     artifact writer.
2. `03aTerraformStyleGuideT1A.md`, with H1
   `# Add a fail-closed cross-platform style-guide candidate validator`, owns:
   - `Expand-StyleGuideCandidateArtifact.ps1`;
   - `Manage-StyleGuideCandidateInvocationContext.ps1`;
   - `Test-Expand-StyleGuideCandidateArtifact.ps1`;
   - exact manifest/digest/path/link/resource/byte rules;
   - the two exact cleanup functions and ownership journals;
   - the complete stable-ID harness table and reciprocal P1 matrix; and
   - local Windows PowerShell 5.1, PowerShell 7, Ubuntu, and Windows evidence.
   The scripts remain inactive repository library code until T1B.
3. `03bTerraformStyleGuideT1B.md`, with H1
   `# Promote generated style-guide artifacts through a least-privileged
   verified writer`, owns:
   - final `build.yml` and `markdownlint.yml` topology;
   - immutable artifact upload/download by ID and digest;
   - all pull/push matrices and at-use harness execution;
   - approval, single writer, four-local identity snapshot, ancestry,
     no-op, exact lease/refspec, and diagnostic artifacts;
   - the final action role/count allowlist and workflow permission/event
     invariants; and
   - end-to-end revalidation of T1 and T1A.

T1A is blocked by the exact T1 merge commit; T1B is blocked by exact T1 and
T1A commits. Existing T2 is blocked by T1B. Earlier evaluation sections use
“T1” as the original-draft label; this split relocates their requirements
without weakening any selected behavior.

Each issue gets an exact, recomputed affected-file set and staged-path gate.
No issue preserves the original arbitrary “seven/eight files” count. T1B must
update the action allowlist atomically for its final roles and counts and must
rerun the entire generator/helper/harness contract before activating writes.

## I-2 — Require a canonical positive GCS generation

### Problem statement

T2 tells readers to select an “exact numeric generation” but its recovery block
accepts any nonempty `GCS_GENERATION` and interpolates it after `#` in a gcloud
object URL. Empty checking does not reject whitespace, signs, shell/query
metacharacters, zero, leading zeros, or multiple syntactic representations.

Google defines the suffix as a numeric generation and documents generation
selectors as positive 64-bit values. The shell should preserve the reviewed
identifier without interpreting it.

### Options

#### Option A — Keep nonempty validation

Let gcloud reject invalid values. This permits shell and gcloud argument
grammar to be influenced before the provider can validate the generation.

#### Option B — Accept any digits

Require `^[0-9]+$`. This closes metacharacter injection but admits zero and
noncanonical leading-zero spellings that do not identify a reviewed historical
generation consistently.

#### Option C — Require canonical positive decimal

Require `^[1-9][0-9]*$`, reject before URL construction/provider invocation,
and pass the exact string unchanged in
`gs://.../terraform.tfstate#${GCS_GENERATION}`. Let the provider prove existence
and numeric bounds.

#### Option D — Parse as an unsigned 64-bit shell integer

Require canonical decimal and convert it before use. Bash arithmetic is
typically signed and implementation-sized; external conversion adds locale/
overflow behavior. Conversion provides no benefit when the CLI accepts the
decimal identifier.

#### Option E — Select directly from discovery JSON

Pipe one discovery result into the copy command to avoid manual transcription.
This risks automatic selection, hides the deliberate review checkpoint, and
requires secure JSON transport/selection logic.

#### Option F — Query `gcloud storage objects describe` before copy

Validate the syntax, then make an extra provider call to prove the generation
exists and matches the key before copy. This can be defense in depth but does
not replace local grammar and introduces a time-of-check/time-of-use request.

#### Option G — Impose a fixed 64-bit digit-length regex

Accept only 1–20 digits and compare lexically to `18446744073709551615`.
This fully enforces the documented range locally but adds easy-to-misimplement
numeric logic that the provider already owns. Canonical syntax plus exact
provider identifier is sufficient.

#### Permutations considered

- **Lexical set:** nonempty, digits, or positive canonical digits. Positive
  canonical digits exactly match the documented use.
- **Bounds:** local numeric conversion, lexical uint64 comparison, or provider
  validation. Provider validation avoids shell overflow.
- **Selection:** manual reviewed value or automatic first/latest value. T2
  deliberately prohibits automatic recovery selection.
- **Construction timing:** validate before or after building the object URL.
  Rejection must occur before any provider argument exists.
- **Identity:** normalize/convert or pass exact string. Exact pass-through makes
  discovery-to-recovery evidence comparable.

### Evaluation rubric

This rubric targets safe, deliberate version-identifier handling.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Shell/argument injection resistance | 24 | Generation text must not alter the provider argument or introduce shell syntax. |
| Exact reviewed-version preservation | 20 | Recovery must use precisely the manually selected generation, not a normalized or automatic alternative. |
| GCS semantic correctness | 17 | The accepted grammar must represent a positive historical object generation. |
| Reject-before-provider ordering | 13 | Invalid input must not trigger authentication or a cloud request. |
| Overflow/portability safety | 10 | Bash arithmetic must not misclassify valid 64-bit identifiers. |
| Behavioral testability | 8 | Stubs need a closed positive/negative matrix and exact argv oracle. |
| Reader clarity | 5 | Operators should understand the accepted value at a glance. |
| Churn | 3 | A one-line grammar is preferable only when technically complete. |

Scoring constraints:

- Metacharacter-bearing input that can reach gcloud scores 0 for injection.
- Automatic selection scores 0 for reviewed-version preservation.
- A score of 5 for ordering validates before source-URL construction and every
  provider call.
- Shell numeric conversion scores at most 2 for overflow portability.

### Scoring

Columns are injection resistance (IR), identity (ID), GCS semantics (GS),
ordering (OR), portability (PT), tests (TE), clarity (CL), and churn (CH).

| Option | IR | ID | GS | OR | PT | TE | CL | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Nonempty only | 0 | 3 | 1 | 1 | 5 | 1 | 2 | 5 | 34.6 |
| B — Digits | 5 | 4 | 3 | 5 | 5 | 4 | 4 | 5 | 86.6 |
| C — Canonical positive decimal | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| D — Parse uint64 | 5 | 3 | 4 | 5 | 2 | 3 | 3 | 2 | 75.6 |
| E — Discovery pipeline | 4 | 0 | 4 | 2 | 5 | 2 | 2 | 1 | 53.8 |
| F — Describe then copy | 5 | 5 | 5 | 4 | 5 | 4 | 3 | 2 | 92.0 |
| G — Lexical uint64 bounds | 5 | 5 | 5 | 5 | 5 | 4 | 2 | 1 | 93.0 |

Option C exactly matches the required semantic set without exposing the
identifier to shell arithmetic or adding a mutable discovery step.

### Selected option and implementation specification

**Select Option C: require canonical positive decimal and pass it unchanged.**

Revise T2's GCS block and exact-block harness to:

1. Assign `[the shell string]` `GCS_GENERATION` once before constructing any
   object URL.
2. Require an exact Bash regex match to `^[1-9][0-9]*$`. Do not trim, perform
   arithmetic, invoke `eval`, or accept locale digits.
3. Reject with a stable diagnostic naming `GCS_GENERATION` and “canonical
   positive decimal”; do not echo an untrusted value.
4. Construct exactly one quoted source argument:
   `gs://acme-corp-terraform-state/environments/prod/terraform.tfstate#${GCS_GENERATION}`.
5. Pass that argument unchanged to `gcloud storage cp --no-clobber` after the
   common protected fresh-destination preflight. Do not select the first,
   newest, or live generation automatically.
6. Treat provider not-found/out-of-range failure as a provider failure, retain
   the exact selected identifier in nonsecret diagnostics, and preserve the
   documented safe destination postcondition.
7. Add positive tests for representative one-digit and 20-digit canonical
   values and negative tests for empty, zero, signs, whitespace, leading zero,
   decimal point, exponent, comma, Unicode digits, `#`, slash, query/shell
   metacharacters, and alphabetic text.
8. For every negative, prove no gcloud call and no destination. For positives,
   prove one NUL-captured argv element contains the exact original generation.

## I-3 — Keep complete CI coverage with an explicit measured budget

### Problem statement

The selected workflow design runs Ubuntu validation plus four Windows
edition-by-fixture-EOL cells on pull requests and pushes, with the harness in
every relevant consumer and writer. T1 explains the security value but does not
make an explicit cost/latency decision or define when observed usage should
cause the topology to be revisited.

This repository is public, so standard hosted-runner minutes are currently
free; queue time, feedback latency, platform load, and diagnostic storage
remain real costs.

### Options

#### Option A — Keep full coverage without a budget

Preserve every cell and artifact rule and accept the cost implicitly. This
protects correctness but gives maintainers no evidence-based review trigger.

#### Option B — Full pull-request matrix, reduced push matrix

Run all four cells before merge but only one PowerShell 7/LF cell on push.
This saves push capacity but fails to validate the exact post-merge artifact
consumption and writer prerequisite on Windows PowerShell 5.1 and CRLF
fixtures.

#### Option C — Representative pull-request cells, full push matrix

Run PowerShell 7/LF and Windows PowerShell 5.1/CRLF on PRs, then all four after
merge. This shortens PR feedback but allows interaction defects in the two
cross combinations to merge.

#### Option D — Add workflow-level path filters

Run the expensive workflow only for source/generator/workflow changes. This
can save runs, but undermines the selected unfiltered required-check contract,
can leave required checks pending, and misses repository-wide supply-chain or
configuration changes.

#### Option E — Run the full matrix on a schedule

Use one or two representative PR cells and execute all four nightly/weekly.
This shifts defects after merge and makes the schedule, rather than the
candidate, the evidence unit.

#### Option F — Move Windows coverage to self-hosted runners

Avoid hosted-minute accounting and control installed editions. This transfers
patching, isolation, credential, persistence, and cleanup risk to a new runner
fleet and is disproportionate for a public repository.

#### Option G — Keep full coverage and establish a measured budget

Retain all required cells, unfiltered events, and at-use harness checks.
Explicitly record why, bound failure-only diagnostics, collect actual runtime/
storage data after rollout, and require a follow-up decision if defined
latency/storage thresholds are exceeded or repository visibility/billing
changes.

#### Permutations considered

- **When:** PR, push, scheduled, or combinations. The exact candidate must be
  proved before merge and the exact promoted candidate at push.
- **Cells:** four cross-product cells versus diagonal representatives.
  Edition and fixture EOL can interact; the full product is intentional.
- **Harness placement:** once per workflow or at every consumer. At-use
  validation catches runner- and transport-specific defects.
- **Failure strategy:** default fail-fast or complete matrix. Complete evidence
  needs `fail-fast: false`.
- **Filtering:** workflow-level filters or unfiltered workflow with safe
  job/step no-op behavior. Required-check predictability favors unfiltered.
- **Cost response:** speculate now or measure public-repository latency/storage
  after rollout. Measured thresholds support a defensible future change.

### Evaluation rubric

This rubric targets coverage value relative to observable CI cost.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Pre-merge defect prevention | 22 | Every supported edition/EOL interaction must fail before merge. |
| Post-merge promotion integrity | 19 | The exact candidate and writer prerequisites must be re-proved where the write occurs. |
| Required-check predictability | 15 | Contributors must always receive a terminal check rather than a path-filtered pending state. |
| At-use security evidence | 13 | The helper/harness must run in the same jobs that consume artifacts. |
| Resource/latency accountability | 12 | Maintainers need measurements, thresholds, and an owner for excessive usage. |
| Diagnostic storage discipline | 8 | Failure evidence should be useful, bounded, short-lived, and absent on success. |
| Operational simplicity | 7 | Standard hosted runners avoid a new trusted fleet or schedule-only workflow. |
| Workflow churn | 4 | Coverage should not be reduced merely to minimize YAML. |

Scoring constraints:

- Any design missing a cross-product cell before merge scores at most 3 for
  defect prevention.
- Any design missing it at promotion scores at most 2 for promotion integrity.
- Workflow-level path filtering scores at most 2 for required-check
  predictability.
- A score of 5 for accountability requires measured review thresholds and a
  visibility/billing-change trigger.

### Scoring

Columns are pre-merge prevention (PR), promotion integrity (PI), check
predictability (CK), at-use evidence (AU), accountability (AC), diagnostics
(DG), operations (OP), and churn (CH).

| Option | PR | PI | CK | AU | AC | DG | OP | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Full, implicit cost | 5 | 5 | 5 | 5 | 1 | 4 | 5 | 5 | 88.8 |
| B — Reduced push | 5 | 2 | 5 | 2 | 3 | 4 | 5 | 3 | 72.8 |
| C — Reduced PR | 3 | 5 | 5 | 4 | 3 | 4 | 5 | 3 | 80.6 |
| D — Path filters | 4 | 4 | 1 | 4 | 4 | 4 | 4 | 2 | 69.4 |
| E — Scheduled full matrix | 3 | 3 | 5 | 2 | 4 | 4 | 3 | 2 | 66.6 |
| F — Self-hosted Windows | 5 | 5 | 5 | 5 | 3 | 4 | 0 | 0 | 82.6 |
| G — Full with measured budget | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.2** |

Option G preserves the evidence that justifies the pipeline while making the
resource choice visible, bounded, and revisitable with actual data.

### Selected option and implementation specification

**Select Option G: retain full coverage and add an explicit CI
cost/latency/storage decision record.**

T1B must require:

1. Unfiltered `pull_request` targeting `main` and `push` to `main`; no workflow
   path filters or skip-commit convention for required validation.
2. The complete Windows PowerShell 5.1/PowerShell 7 × LF/CRLF fixture matrix on
   both events, plus the required Ubuntu PowerShell 7 surface.
3. `strategy.fail-fast: false` so every applicable cell reports evidence.
   Keep the four Windows cells eligible to run concurrently on standard
   hosted runners; do not use paid larger runners.
4. The permanent helper harness in every applicable consumer cell and again in
   the writer when `has_changes=true`. A no-change push still proves generator
   no-op and workflow invariants but does not create an empty diagnostic
   artifact or invoke a writer.
5. One terminal aggregate/approval check using `if: always()` as needed so
   failed/skipped dependencies cannot accidentally report success.
6. Diagnostic artifacts only after ordinary failure, never success or
   cancellation; redact secrets; cap content to the documented fixtures/logs;
   use a collision-free name; and set `retention-days: 7`.
7. A recorded baseline after at least ten qualifying PR runs and ten qualifying
   push runs, capturing per-job duration, queue time, total workflow duration,
   failure rate, diagnostic bytes, and rerun causes.
8. A review after that baseline and quarterly thereafter. Open a real topology
   follow-up if median end-to-end validation exceeds 15 minutes, p95 exceeds
   25 minutes, diagnostic storage exceeds 250 MB in a month, runner
   availability materially blocks contributors, or repeated evidence shows a
   cell is redundant.
9. Immediate re-evaluation if the repository becomes private, standard-runner
   billing changes, larger runners are proposed, or artifact retention policy
   changes. Cost changes do not silently remove a security cell; they trigger
   a scored replacement design.

## Final decision map

All 15 open findings have now been evaluated in the order recorded in
`current-findings.md`. The selected slate consequences are:

| Finding | Selected consequence |
| --- | --- |
| T1-1 | Hosted Node 24, cache disabled; final contributor floor remains npm-issue work. |
| T1-2 | One tracked caller-context lifecycle script with fail-closed teardown. |
| T1-3 | Shared stable `V/P/D/Z/M/E/L/B/K/X` IDs, one row per permutation. |
| T1-4 | Four writer identity locals, copied once and reused through lease/refspec. |
| T1-5 | Exact production cleanup name `Remove-StyleGuideCandidateInvocationState`. |
| T1-6 | Exact offline action repository/SHA/workflow-role/count allowlist. |
| T1/T2-1 | Reciprocal P1/Terraform matrix at implementation start and pre-merge; concise T2 consumption. |
| T1/T2-2 | Real npm remediation/governance issue in `05TerraformStyleGuideT3.md`. |
| T2-1 | Closed US/EU HCP hosts, canonical page, closed curl-config token grammar. |
| T2-2 | T2 owns four retrieval surfaces; real destructive-state follow-up in `06TerraformStyleGuideT4.md`. |
| T2-3 | Tracked exact-block Bash harness in ordinary CI. |
| T2-4 | One resolved Node/npm pair and scoped `CI=true`. |
| I-1 | Split original T1 into foundations, validator, and activation issues. |
| I-2 | Canonical positive GCS generation passed unchanged. |
| I-3 | Full matrices retained with bounded diagnostics and measured review thresholds. |

The issue-file execution order is:

1. `03TerraformStyleGuideT1.md`;
2. `03aTerraformStyleGuideT1A.md`;
3. `03bTerraformStyleGuideT1B.md`;
4. `04TerraformStyleGuideT2.md`;
5. `05TerraformStyleGuideT3.md`; and
6. `06TerraformStyleGuideT4.md`.

The policy exception remains: if the repository forbids carrying current
high-severity npm advisories, execute T3 first, then rebaseline the five later
implementation issues on its exact merge commit. H1 titles are issue titles;
none of the filings should describe itself as a revision of an earlier draft.
