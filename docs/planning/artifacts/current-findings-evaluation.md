# Evaluation of open TerraformStyleGuide findings

## Review controls

This evaluation considers only the open TerraformStyleGuide findings recorded
in `current-findings.md`. Findings are evaluated and completed in their recorded
order. Each finding receives its own options, unique weighted rubric, scoring
table, and implementation-ready selection before work proceeds to the next
finding.

## T1-1 — Add a reciprocal generator-convergence contract

### Problem statement

T1 already specifies technically correct serialization behavior and coordinates
the archive helper/harness with PSStyleGuide, but it does not put the intended
generator convergence in one auditable contract. The selected response must
make shared algorithms and intentional guide-specific differences clear without
creating an unnecessary cross-repository runtime or release dependency.

### Options

#### Option A — Make no change

Rely on T1's existing serialization requirements and the implementers'
side-by-side reading of P1. This has no drafting cost, but leaves the stated
generator-unification objective implicit and makes accidental divergence hard
to distinguish from an intentional difference.

#### Option B — Add an unstructured prose checklist

Add a paragraph naming common newline normalization, BOM-less UTF-8,
`WriteAllText`, frontmatter, versioning, and cross-edition validation. This is
more explicit than the status quo but makes omissions and later drift less
visible than a row-by-row shared/different comparison.

#### Option C — Add a generator matrix without a coordination checkpoint

Add a matrix with “shared target” and “intentional repository-specific
difference” columns covering final serialization, common artifacts,
instructions/frontmatter, abstraction level, script policy, repository text
policy, and validation. Let each repository implement its own issue without an
explicit reread of whichever implementation lands first.

This is strong static guidance, but the second implementation can still follow
an obsolete draft if the first implementation discovers a necessary contract
change.

#### Option D — Add the matrix plus a reciprocal implementation-start checkpoint

Add the complete matrix from Option C and require whichever implementation
starts second to inspect the merged/current first implementation and its
evidence. Require any remaining difference to be classified as:

1. repository-specific content;
2. a deliberately accepted design difference; or
3. a defect that must be corrected or explicitly tracked.

Define convergence as shared algorithms, invariants, and failure semantics—not
line-for-line identity. Keep both repositories self-contained and independently
implementable. Do not add a shared module/action in T1 or P1.

This option can be implemented with either coordinated inline serialization
boundaries or an equivalent private helper in both generators. The matrix must
make the chosen abstraction level explicit so one repository does not acquire a
one-off helper while the other silently retains four inline implementations.

#### Option E — Require line-for-line generator identity where possible

Require common functions and serialization code to be textually identical,
with guide-specific code isolated behind narrow branches or data parameters.
This can simplify visual comparison, but it couples unrelated guide transforms,
names, frontmatter, and release timing. Textual identity can also obscure
whether equivalent behavior survives differing repository requirements.

#### Option F — Introduce a shared cross-repository module or action now

Move common generator behavior into a separately hosted script, module,
composite action, or reusable workflow consumed by both repositories. Variants
include:

- mutable branch/tag consumption, which is unacceptable for trusted automation;
- immutable commit consumption, which adds update and provenance governance;
- a versioned PowerShell module, which adds packaging and installation
  concerns; or
- source vendoring, which still needs a synchronization and verification
  policy.

This may be reasonable future architecture, but it materially expands the
current issues and creates availability, versioning, trust, and coordinated
release concerns.

#### Option G — Create a separate cross-repository design prerequisite

Do not add detailed convergence text to T1. Instead, require a new design issue
or ADR to settle the common generator contract before either T1 or P1 begins.
This provides a formal decision record but adds a blocking artifact and splits
implementation instructions across locations. It is justified only if the two
teams cannot agree on the matrix in the existing issues.

#### Permutations considered

The options above cover the meaningful architectural choices. Within Options
B–D, the following permutations were considered:

- **Location:** generator section, cross-repository coordination section, or
  validation section. The contract is easiest to discover beside the generator
  requirements, with validation referring back to it.
- **Representation:** prose, checklist, or matrix. A matrix best exposes
  omissions and intentional asymmetry.
- **Enforcement:** drafting-only review, implementation-start reread, or a
  cross-repository automated byte comparison. Automated byte equality is
  inappropriate because guide content is intentionally different; local
  raw-byte tests remain appropriate for shared serialization invariants.
- **Abstraction:** four equivalent inline serialization boundaries, one private
  helper in each repository, or a shared runtime dependency. Either of the
  first two can satisfy the contract; the third should be separately designed.
- **Sequencing:** no dependency, soft second-implementer checkpoint, or hard
  blocked-by relationship. The soft checkpoint preserves independent delivery
  while preventing silent drift.

### Evaluation rubric

Each option is scored from 0 (does not satisfy the criterion) to 5 (excellent).
The weighted result is
`sum(criterion weight × score ÷ 5)`, producing a maximum of 100.

This rubric is specific to cross-repository generator convergence:

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Behavioral convergence correctness | 25 | Senior engineers and maintainers need shared serialization invariants and failure semantics to remain genuinely equivalent, not merely similar in prose. |
| Cold-start implementation clarity | 20 | A new developer must be able to identify the common target and every intentional difference without reconstructing the full conversation. |
| Repository independence and fault isolation | 15 | DevOps, security, and business stakeholders need either repository to build, validate, and release if the other repository or its maintainer is unavailable. |
| Reviewability and drift detection | 15 | Reviewers and project managers need a practical way to notice accidental divergence before it becomes two established implementations. |
| PowerShell/platform compatibility | 10 | The contract must preserve Desktop 5.1/Core 7 and Windows/Linux validation rather than selecting an abstraction that narrows support. |
| Long-term maintainability | 8 | Documentation and engineering owners need a stable contract that can evolve without repeated archaeology or deceptive textual symmetry. |
| Parallel-delivery flexibility | 5 | The repositories are expected to progress in parallel; unnecessary blocking relationships impose real schedule risk. |
| Drafting and implementation churn | 2 | Effort matters, but it is deliberately weighted far below correctness, clarity, and operational independence. |

Scoring guidance:

- A 5 for correctness requires explicit coverage of all shared generator
  boundaries and intentional differences.
- A 5 for independence prohibits runtime reliance on the other repository.
- A 5 for drift detection requires both a structured baseline and a
  current-state comparison when the second implementation begins.
- A 5 for clarity means the issue itself is sufficient for a cold-start
  implementer; an undocumented external convention cannot earn it.
- Churn cannot rescue an option that leaves the convergence objective implicit.

### Scoring

Column abbreviations follow the rubric order: behavioral convergence (BC),
cold-start clarity (CC), repository independence (RI), reviewability/drift
detection (RD), compatibility (PC), maintainability (LM), parallel delivery
(PD), and churn (CH).

| Option | BC | CC | RI | RD | PC | LM | PD | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — No change | 1 | 1 | 5 | 2 | 5 | 2 | 5 | 5 | 50.2 |
| B — Prose checklist | 3 | 3 | 5 | 3 | 5 | 4 | 5 | 4 | 74.0 |
| C — Matrix only | 4 | 5 | 5 | 4 | 5 | 4 | 4 | 4 | 89.0 |
| D — Matrix plus reciprocal checkpoint | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 3 | **98.2** |
| E — Textual identity | 3 | 4 | 2 | 5 | 3 | 2 | 2 | 2 | 64.0 |
| F — Shared runtime component now | 4 | 3 | 1 | 4 | 3 | 3 | 1 | 1 | 59.2 |
| G — Separate design prerequisite | 4 | 4 | 4 | 4 | 5 | 3 | 2 | 2 | 77.6 |

Option D dominates because it combines a complete, reviewable contract with a
current-state drift check while preserving self-contained repositories.
Option C is the strongest lower-effort fallback, but it lacks protection
against discoveries made by the implementation that lands first.

### Selected option and implementation specification

**Select Option D: add a generator-convergence matrix plus a reciprocal
implementation-start checkpoint.**

Update T1 as follows:

1. Add a subsection immediately after the four generator write-site
   requirements and before `.gitattributes`. Title it so a cold-start
   implementer can find “generator convergence” directly.
2. State that T1 and P1 coordinate algorithms, invariants, and failure
   semantics while remaining self-contained. Explicitly reject a
   cross-repository runtime import, forced line-for-line identity, and a hard
   delivery dependency.
3. Add a three-column matrix: generator area, shared target, and intentional
   repository-specific difference.
4. Include rows for:
   - final complete-payload LF normalization;
   - resolved destination plus `UTF8Encoding($false)` and `WriteAllText`;
   - Copilot, Chat, and Full artifact functions;
   - instructions/frontmatter construction;
   - abstraction level (equivalent inline boundaries or coordinated private
     helpers);
   - `#Requires -Version 5.1` and `.NOTES` versioning;
   - LF checkout policy versus producer correctness; and
   - Desktop 5.1/Core 7 plus LF/CRLF raw-byte validation.
5. Name guide-specific payload names, filenames, Full transforms, `applyTo`,
   descriptions, starting versions, current `.gitattributes` state, and
   separately governed Node work as intentional differences.
6. In T1's read-only preparation, require the implementer to inspect the
   merged/current PSStyleGuide generator and its evidence if P1 has already
   landed. If T1 lands first, require the T1 pull request to record the matrix
   as the handoff baseline for P1.
7. Require each observed difference to be recorded as repository-specific,
   deliberately accepted, or a defect/follow-up. Do not allow silence to imply
   acceptance.
8. Add validation and acceptance language proving that the implemented T1
   generator matches every shared row and that all deviations are documented.
   Do not compare final guide bytes across repositories because their content is
   intentionally different.

This closes T1-1 without changing T1/T2 order, introducing a third issue, or
making either repository unavailable when the other cannot be reached.

## T1/T2-2 — Expand the linked npm issue's runtime-policy and affected-file contract

### Problem statement

T1 correctly excludes dependency and Node changes from its own implementation,
but its linked npm-remediation contract does not require the later issue to own
the runtime-policy change that the current candidate already makes necessary.
TerraformStyleGuide currently runs Markdown CI on Node 20 and its hook admits
any `npm`; the current `markdownlint-cli2@0.23.2` line requires Node `>=22`,
while Node 20 is now end-of-life.

### Options

#### Option A — Leave the linked-issue contract unchanged

Let the future drafter discover the Node mismatch and decide whether it is in
scope. This preserves the smallest T1/T2 edit but knowingly leaves a critical
compatibility decision outside the tracked issue's ownership.

#### Option B — Upgrade packages and add metadata only

Allow the linked issue to update dependencies, the lockfile, and
`engines.node`, but do not change CI or the hook. Variants include an
`engines.node` lower bound, npm `devEngines`, or both.

This records intent but does not guarantee enforcement: npm documents
`engines` as advisory unless `engine-strict` is enabled, and contributors can
reach the hook with a different Node from their interactive environment.

#### Option C — Standardize all Terraform tooling on Node 22

Set package metadata to Node `>=22`, move Markdown CI to Node 22, and reject
Node below 22 early in the hook. Validate Node 22 on Linux and the relevant
local/hook surfaces. This exactly matches the present package minimum and
maximizes compatibility with contributors already on the oldest supported
candidate line.

The weakness is lifecycle runway and evidence breadth: it does not prove the
preferred/newer LTS line used by the sister repository, and Node 22 will leave
support earlier than Node 24.

#### Option D — Standardize all Terraform tooling on Node 24

Set `engines.node` to Node `>=24`, move CI to Node 24, and reject Node below 24
in the hook. Validate Node 24 on Linux and relevant contributor surfaces.

This supplies one simple, current LTS policy with a longer support runway and
aligns with PSStyleGuide's chosen hosted baseline. It unnecessarily excludes
Node 22 even though the candidate packages support it, unless the maintainer
deliberately wants a single cross-repository floor.

#### Option E — Support the package minimum and validate both LTS baselines

Set `engines.node` to the final selected dependency floor (currently `>=22`);
make the hook reject older majors with a fixed, early diagnostic; and validate
both the selected minimum and Node 24. Use Node 24 as the preferred/default
hosted line while retaining an explicit minimum-version compatibility cell or
equivalent evidence.

This option:

- keeps package metadata, hook admission, and dependency engines consistent;
- proves contributors on the package minimum are supported;
- proves the preferred/latest LTS line used for ordinary CI;
- avoids deriving policy from an action's internal runtime;
- preserves Husky's existing GUI/version-manager troubleshooting; and
- requires the future issue to recompute all affected files.

`devEngines` may be added as a supplemental early npm control only after the
selected npm versions and cross-platform behavior are verified. It must not
replace `engines.node`, the hook check, or CI evidence.

#### Option F — Split runtime policy into a prerequisite issue

Create a dedicated Node-policy issue before the dependency-remediation issue.
The prerequisite would update package metadata, workflow runtime, and hook
guards; the remediation issue would then update dependencies on that baseline.

This offers a narrow security/architecture review boundary and is appropriate
if maintainers require separate approval. It increases sequencing overhead and
temporarily changes runtime without delivering the dependency remediation that
motivates it.

#### Option G — Retain Node 20 by selecting older packages or overrides

Choose the newest Node 20-compatible dependency set, apply transitive
overrides, or defer the CLI upgrade. This can reduce contributor disruption,
but Node 20 is end-of-life and the approach may leave advisories or require
unsupported combinations. It is acceptable only if fresh audit and upstream
metadata prove a supported, security-complete Node 20 solution—which current
evidence does not.

#### Option H — Eliminate host-Node variability with a containerized toolchain

Run Markdown lint and hooks through a pinned container or other hermetic runtime
instead of host Node. This can make execution reproducible, but imposes a
container runtime on contributors, complicates Windows/GUI Git usage, and is a
material workflow redesign. Removing the hook altogether is a weaker variant
that shifts feedback to CI and should not be selected merely to avoid runtime
policy.

#### Permutations considered

- **Floor:** Node 22, Node 24, or a dynamically selected final package minimum.
- **Range:** exact major versus an open lower bound. The dependency's own
  supported range should control unless repository policy deliberately narrows
  it.
- **Enforcement:** `engines`, `devEngines`, explicit hook check, CI selection,
  or combinations. Metadata alone is insufficient; explicit checks plus
  evidence are required.
- **CI topology:** one preferred major, a minimum/preferred two-cell matrix, or
  a larger all-supported-majors matrix. Minimum plus preferred gives strong
  evidence without testing every future major implicitly admitted by a range.
- **Ordering:** after T2 by default or before T1 when security policy requires.
  Either order requires T1/T2 rebaselining if the npm issue lands first.
- **Affected paths:** package/lockfile only versus the complete set derived from
  package metadata, workflow runtime, hook guard, tests, and Dependabot policy.

### Evaluation rubric

Each option is scored from 0 to 5 and weighted to 100 with
`sum(weight × score ÷ 5)`. This rubric is unique to a Node/dependency runtime
transition:

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Supported-runtime and security correctness | 25 | Security and engineering owners must not advertise or admit an end-of-life/unsupported runtime for the selected dependency tree. |
| CI/package/hook consistency | 20 | DevOps needs one coherent contract across metadata, clean install, hosted execution, and pre-commit behavior. |
| Contributor usability and diagnostics | 15 | Contributors need an early actionable message, including GUI/version-manager users, rather than an opaque engine or import failure. |
| Compatibility evidence strength | 15 | The selected minimum and preferred baseline must actually install and execute the relevant tooling; metadata is indirect evidence. |
| Lifecycle runway | 10 | Business and maintenance owners benefit from avoiding another forced runtime migration immediately after remediation. |
| Cross-platform portability | 8 | The policy and guard must work in the repository's Linux CI and Windows/POSIX-hook contributor environments. |
| Security-remediation sequencing | 5 | Project managers need a policy that works under both the normal T1→T2→npm order and the policy-driven npm-first exception. |
| Change cost and churn | 2 | Scope matters, but it cannot outweigh a knowingly inconsistent or unsupported toolchain. |

Scoring rules:

- An option cannot score above 2 for correctness if it leaves Node 20 admitted
  with a dependency tree that declares Node `>=22`.
- An option cannot score above 2 for consistency if it changes only package
  metadata.
- A 5 for evidence requires executing both the selected minimum and the
  preferred/default baseline.
- A 5 for contributor usability requires a pre-tooling version check with
  stable remediation guidance.
- A high portability score requires preserving the existing Husky GUI/version
  manager guidance and validating the relevant shells/platforms.

### Scoring

Column abbreviations are runtime/security correctness (RS), contract
consistency (CC), contributor usability (CU), evidence (CE), lifecycle runway
(LR), portability (PP), sequencing (SQ), and churn (CH).

| Option | RS | CC | CU | CE | LR | PP | SQ | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Unchanged contract | 0 | 1 | 2 | 1 | 0 | 4 | 5 | 5 | 26.4 |
| B — Package metadata only | 2 | 1 | 2 | 2 | 2 | 4 | 5 | 4 | 43.0 |
| C — Uniform Node 22 | 5 | 5 | 4 | 4 | 3 | 5 | 4 | 3 | 88.2 |
| D — Uniform Node 24 | 5 | 5 | 3 | 4 | 5 | 4 | 4 | 3 | 87.6 |
| E — Minimum plus preferred LTS | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 2 | **97.8** |
| F — Separate runtime prerequisite | 5 | 5 | 4 | 5 | 5 | 5 | 2 | 1 | 92.4 |
| G — Preserve Node 20 | 2 | 4 | 4 | 3 | 1 | 5 | 4 | 3 | 62.2 |
| H — Containerize the toolchain | 5 | 5 | 2 | 4 | 4 | 2 | 2 | 1 | 76.6 |

Option E supplies the best combination of current package compatibility,
contributor support, preferred-LTS runway, and executable evidence. Option F is
technically strong but creates a separate sequencing boundary without a
demonstrated need. Options C and D are coherent fallbacks if the maintainer
explicitly wants exactly one supported major.

### Selected option and implementation specification

**Select Option E: require the linked issue to support the final dependency
minimum and validate both that minimum and the preferred Node 24 LTS baseline.**

Revise T1's linked npm-remediation subsection and acceptance criteria so the
future issue must:

1. Re-run npm registry/package metadata, changelog, lockfile, audit, and
   repository-usage discovery before selecting versions.
2. Record the current known transition: Terraform currently uses Node 20 and
   `markdownlint-cli2@0.20.0`; the current
   `markdownlint-cli2@0.23.2`/`markdownlint@0.41.1` candidate requires Node
   `>=22`; Node 20 is end-of-life. Treat these as dated planning evidence, not a
   frozen implementation oracle.
3. Derive the supported minimum from the final selected dependency tree.
   Current expected policy is `engines.node: ">=22"` with Node 24 as the
   preferred/default hosted LTS line.
4. Keep package metadata, `.github/workflows/markdownlint.yml`, and
   `.husky/pre-commit` consistent. The hook must query the actual Node version
   before invoking npm tooling, reject a version below the selected minimum,
   and emit stable remediation plus existing GUI/version-manager guidance.
5. Include at least `.github/workflows/package.json`,
   `.github/workflows/package-lock.json`,
   `.github/workflows/markdownlint.yml`, and `.husky/pre-commit` in the
   candidate affected-file discovery. Add test/fixture/Dependabot paths required
   by the selected evidence design rather than freezing this as an exhaustive
   list.
6. Use `engines.node` as durable package metadata. `devEngines` may supplement
   it only after npm-version and cross-platform behavior are verified; it may
   not substitute for hook and CI enforcement.
7. Prove `npm ci`, outer lint, nested lint, and the actual hook/integration at
   the selected minimum and Node 24. Do not claim support for an untested
   runtime merely because a semver range admits it.
8. Preserve the normal T1→T2→npm order. If policy moves npm remediation first,
   require both T1 and T2 to be rebaselined after the runtime/package changes
   merge.

Revise T2's prerequisite verification so it confirms that the real linked issue
owns this full runtime-policy contract. T2 itself must continue to preserve the
current toolchain unless the npm-first exception has already merged and T2 has
been rebaselined.

This selection keeps the dependency migration out of T1/T2 while making it
impossible for the later issue to update packages and leave Node admission
knowingly inconsistent.

## T1/T2-3 — Make the linked npm issue's evidence and supersession rules executable

### Problem statement

The linked issue currently promises clean install, two ordinary lint commands,
and documented advisory disposition. That does not test the actual Terraform
pre-commit hook, provide real negative fixtures, prove structured residual-risk
approval, validate the final Dependabot state, or explain which T1/T2
intermediate gates the later issue intentionally replaces.

### Options

#### Option A — Keep the current high-level contract

Trust the future issue drafter to choose sufficient tests and explain gate
changes. This is concise but cannot ensure that “remediated” means the actual
hook, negative paths, advisory set, and final governance were tested.

#### Option B — Require a narrative verification report

Add prose requiring the pull request to describe hook behavior, residual
advisories, and superseded checks, but do not prescribe machine-verifiable
fixtures or record structures. This improves review awareness but relies on
manual interpretation and is vulnerable to missing URLs, paths, expired
exceptions, or mislabeled startup failures.

#### Option C — Add minimal executable tests and require a clean audit

Require:

- `npm ci`;
- outer and nested positive lint;
- one temporary ordinary Markdown violation;
- direct invocation of `.husky/pre-commit`; and
- zero moderate/high/critical audit findings.

This is substantially stronger and avoids designing an exception format.
However, it does not cover nested-negative behavior, no-staged/tooling-failure
hook paths, or a legitimate case where no supported dependency set can
immediately eliminate every advisory. It also leaves Dependabot supersession
underspecified.

#### Option D — Require a complete integration, risk, and governance contract using ephemeral fixtures

Require all of the following in the linked issue:

1. Isolated tests of the exact Terraform hook for:
   - no staged Markdown;
   - compliant staged Markdown;
   - an outer violation;
   - a nested fenced-Markdown violation; and
   - a tooling/startup failure.
2. Deterministic temporary outer/nested fixtures in a disposable
   clone/worktree or isolated index. Require exact rule, file, and nested
   context diagnostics; distinguish lint exit 1 from tool failure; clean only
   test-owned state.
3. Positive outer and nested sample coverage.
4. A fresh complete current set of moderate/high/critical advisory URLs and
   dependency paths, with the seven-node result retained only as a dated
   comparison.
5. Either a clean audit or structured residual records containing exact URL,
   dependency path, owner, invariant UTC expiration date, and real follow-up
   issue URL. Validate uniqueness, nonempty fields, unexpired dates, exact set
   equality, and absence of stale approvals after a clean audit.
6. Durable issue/pull-request evidence for the audit and any residual approval.
7. A normalized exact final Dependabot check when npm updates are enabled:
   weekly review-only `github-actions` for `/` and npm for
   `/.github/workflows`, with no duplicates, extras, auto-approval, or
   auto-merge.
8. Explicit supersession of T1's exact-one-entry Dependabot check and T1/T2's
   one-time changed-path gates, while preserving all nonsuperseded behavior.

#### Option E — Use tracked permanent negative fixtures with the complete contract

Use Option D's complete evidence/governance contract but add permanent outer and
nested invalid Markdown files to the repository. Exclude or encode them so
ordinary lint remains green, then invoke them explicitly in negative tests.

This makes fixtures readily inspectable, but every exclusion/encoding mechanism
can accidentally prevent the negative path from exercising production
configuration. Permanent intentionally invalid content also creates maintenance
and contributor confusion. It is viable if reviewers strongly prefer tracked
test data and the issue proves the fixtures fail without the exclusion layer.

#### Option F — Split integration, audit governance, and Dependabot into separate issues

Create separate issues for:

- dependency/runtime migration;
- hook and fixture tests;
- residual-risk governance; and
- npm Dependabot/final gate reconciliation.

This provides narrow ownership and review but creates several sequencing edges.
The dependency issue could merge without the tests or governance that establish
its safety unless the relationships are hard prerequisites.

#### Option G — Permit no residual moderate/high/critical advisories

Make a zero-result `npm audit` the only acceptable security outcome. Do not
define exception records. Still add hook/fixture and Dependabot testing.

This is easy to explain and gives the strongest risk-avoidance posture when a
supported clean tree exists. It can block indefinitely on an upstream advisory
with no compatible fix, encouraging unsupported overrides or quiet scope
evasion. A time-bounded, owned exception is more transparent than an impossible
gate.

#### Option H — Use a simple advisory-URL allowlist

Allow residual findings when every current URL appears in an approved string
array. This can prove URL set equality but cannot prove affected path, owner,
expiration, follow-up issue, duplicate semantic approvals, or applicability to
the actual dependency path.

#### Option I — Copy PSStyleGuide's programmatic staged-lint tests

Import tests for `markdownlint-cli2.main` and `nonFileContents`. This would test
an API that TerraformStyleGuide does not call and could pass while its real
shell hook is broken. The transferable principle is integration fidelity, not
identical test code.

#### Permutations considered

- **Fixture persistence:** tracked invalid files, ephemeral files in the main
  worktree, isolated index, disposable worktree, or disposable clone. The
  disposable clone/worktree best protects the implementation index.
- **Hook invocation:** execute the script directly, use `git hook run
  pre-commit`, or attempt real commits. Direct/scripted hook execution plus an
  isolated Git state is deterministic; a real commit can be added but must not
  leave history or user configuration changes.
- **Audit gate:** clean-only, manual exception, URL allowlist, or structured
  exact-set records. Structured records are the only option that supports
  accountable time-bounded exceptions.
- **Evidence location:** console only, issue comment, PR description, or a
  durable checked artifact. Issue/PR evidence is required; a checked artifact
  is optional if it would contain no sensitive data and has an owner.
- **Dependabot decision:** require npm entry or permit a documented policy
  decision. If selected, exact final-state validation is mandatory; if rejected
  by policy, record the rationale and do not falsely claim a two-entry state.
- **Supersession wording:** “all old checks stay green” versus explicit
  enduring/intermediate/final-state categories. Only the categorized model is
  logically satisfiable.

### Evaluation rubric

Options receive 0–5 per criterion and
`sum(weight × score ÷ 5)` out of 100. This rubric is specific to remediation
evidence and governance; it does not reuse the runtime-policy rubric.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Assurance completeness | 25 | Security and engineering reviewers need positive, negative, integration, audit, and final-state evidence—not a subset that can leave the real failure path untested. |
| False-pass/false-fail resistance | 20 | A lint failure must not be confused with tool startup failure, a missing fixture, a stale approval, or a test that never invoked production behavior. |
| Risk accountability and expiry | 15 | Cybersecurity executives and maintainers need every accepted residual risk tied to its actual path, owner, deadline, and follow-up. |
| Production-integration fidelity | 15 | Tests must exercise TerraformStyleGuide's actual hook and commands rather than a PSStyleGuide API or copied implementation. |
| Test isolation and operational safety | 10 | Contributors and DevOps need validation that cannot corrupt the implementation index, leave invalid files, or delete non-test-owned state. |
| Cold-start auditability | 8 | A new developer, reviewer, or auditor must be able to reproduce the evidence and understand which earlier gates were superseded. |
| Future-baseline maintainability | 5 | Dynamic advisories and later updates must be checked against current state without copying a frozen count/URL list forever. |
| Implementation churn | 2 | Test work has a cost, but it is intentionally subordinate to trustworthy remediation evidence. |

Scoring constraints:

- No option can score above 2 for integration fidelity if it does not execute
  `.husky/pre-commit`.
- No option can score above 2 for false-pass resistance if it lacks both real
  lint failures and tooling-failure discrimination.
- No option can score above 2 for risk accountability if residual acceptance is
  an unstructured URL list or prose.
- A 5 for operational safety requires an isolated Git state and exact ownership
  cleanup.
- A 5 for maintainability requires current audit-set derivation and explicit
  replacement of stale/intermediate assertions.

### Scoring

Columns are assurance completeness (AC), false-pass resistance (FP), risk
accountability (RA), integration fidelity (IF), operational safety (OS),
cold-start auditability (CA), future maintainability (FM), and churn (CH).

| Option | AC | FP | RA | IF | OS | CA | FM | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Current high-level contract | 1 | 1 | 1 | 2 | 3 | 2 | 2 | 5 | 31.2 |
| B — Narrative report | 2 | 2 | 3 | 2 | 4 | 4 | 3 | 4 | 52.0 |
| C — Minimal tests, clean audit | 3 | 3 | 3 | 4 | 4 | 3 | 3 | 3 | 65.0 |
| D — Complete contract, ephemeral fixtures | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 2 | **98.8** |
| E — Complete contract, tracked negatives | 5 | 5 | 5 | 5 | 4 | 5 | 4 | 2 | 95.8 |
| F — Split into several issues | 5 | 5 | 5 | 5 | 4 | 3 | 3 | 1 | 91.2 |
| G — Zero-advisory-only gate | 4 | 4 | 5 | 3 | 4 | 5 | 4 | 3 | 81.2 |
| H — URL allowlist | 3 | 2 | 2 | 3 | 4 | 3 | 2 | 4 | 54.4 |
| I — Copy PS programmatic tests | 2 | 2 | 2 | 1 | 3 | 2 | 2 | 2 | 39.0 |

Option D is the most defensible because it tests the production Terraform
integration, makes false passes difficult, supports accountable exceptions
without normalizing them, and protects the active index. Option E is nearly as
strong but adds permanent invalid-content maintenance and exclusion risk.

### Selected option and implementation specification

**Select Option D: require the complete integration/risk/governance contract
with deterministic ephemeral fixtures in an isolated Git state.**

Expand T1's linked-issue ownership and acceptance language so the future issue
must do all of the following:

1. Create a disposable clone or worktree with an isolated index. Record the
   baseline commit and resolve every cleanup target inside that disposable
   root. Never use the maintainer's active index for negative-hook fixtures.
2. Install the final dependency tree cleanly at the selected Node minimum and
   Node 24.
3. Invoke the exact tracked `.husky/pre-commit` behavior for:
   - no staged Markdown → success with no lint execution;
   - staged compliant Markdown → outer and nested lint success;
   - staged outer violation → hook rejection with the expected rule ID and
     fixture path;
   - staged nested fenced-Markdown violation → hook rejection with the expected
     nested rule, file, and depth/context; and
   - absent/broken tooling or another deterministic startup failure → the
     stable tooling diagnostic, never a falsely successful negative test.
4. Include at least one real Git/Husky-installed smoke invocation in the
   disposable clone, or explain and prove an equivalent exact-shell invocation.
   Configure only disposable local Git identity/signing state; do not create
   commits in the implementation repository.
5. Generate the invalid outer and nested fixtures deterministically inside the
   disposable root, stage them to activate the hook, and remove only
   test-owned state in `finally`. Keep the two tracked positive samples
   positive; do not refer to nonexistent “existing negative fixtures.”
6. Check and classify every Git, npm, Node, hook, outer-lint, and nested-lint
   exit status immediately. Use the upstream CLI distinction between lint
   errors and tooling failure where applicable.
7. Rerun `npm audit --package-lock-only --json` at implementation time and
   derive every moderate/high/critical advisory URL plus affected dependency
   path. Compare with T1's seven-node snapshot only as dated drift evidence.
8. Prefer a clean audit. For every unavoidable residual, require a structured
   record with:
   - exact advisory URL;
   - exact affected package/dependency path;
   - nonempty named owner;
   - invariant `YYYY-MM-DD` UTC expiration;
   - real follow-up GitHub issue URL; and
   - concise rationale.
9. Mechanically reject duplicate URLs/paths, blank fields, invalid or expired
   dates, non-issue follow-up values, approvals not present in the current
   audit, current findings without approvals, and approvals remaining after a
   clean audit. Record the table and command result in durable issue/PR
   evidence. Clearly label any element that remains a human review rather than
   claiming code proves it.
10. If repository policy selects npm Dependabot, require normalized exact final
    content with precisely:
    - weekly review-only `github-actions` updates for `/`; and
    - weekly review-only npm updates for `/.github/workflows`.
11. Reject duplicate/extra ecosystems or directories, malformed schedules,
    loss of T1's action entry, and auto-approval/auto-merge mechanisms in the
    changed scope. If policy rejects npm Dependabot, record the rationale and
    validate the retained one-entry state instead of claiming two entries.
12. State supersession precisely:
    - the final Dependabot assertion replaces T1's implementation-time
      exact-one-entry assertion if npm is added;
    - the remediation issue's affected-file set replaces T1's seven-file and
      T2's six-file implementation-time working/staged-set gates;
    - all nonsuperseded generator, helper/harness, permission, immutable action
      pin, artifact, workflow-security, and Markdown behavior remains green.

Update T2's prerequisite sentence to point to this full evidence/governance
contract. T2 need not reproduce the tests because the linked issue is normally
later; it must only require rebaselining if policy causes that issue to merge
first.

This selection does not copy PSStyleGuide's programmatic API tests. It applies
the underlying principle—test the integration that can actually break—to
TerraformStyleGuide's shell hook.

## T2-1 — Remove the stale illustrative version/date snapshot

### Problem statement

T2's six-step version algorithm is normative and correct. The following
conditional example names an implementation date that has already passed and
can be copied despite “Otherwise recompute.” The response should maximize
copy-safety without making a simple version update harder to understand.

### Options

#### Option A — Keep the current dated example

Retain `2.7.20260728.0` and rely on the conditional wording. This preserves
context but leaves an attractive stale value adjacent to the instructions.

#### Option B — Refresh the example to today's date

Replace the literal with a 2026-07-29 candidate. This makes the example locally
current for one day and immediately recreates the same maintenance defect.

#### Option C — Replace the literal with symbolic notation

Show a pattern such as:

```text
<incremented-major>.<incremented-minor>.<UTC-YYYYMMDD>.0
```

or a worked example using obviously fictional values. This avoids a stale real
candidate but duplicates information already conveyed by the numbered
algorithm and introduces placeholder-copy risk.

#### Option D — Remove the example and retain only the normative algorithm

Delete the conditional paragraph, literal version, and “Otherwise recompute.”
Keep the six steps requiring current-version reread, Minor increment, UTC date,
Revision reset, `Last Updated`, and changelog update. This leaves one source of
truth and no expiring candidate.

#### Option E — Add an executable version-calculation snippet

Replace the example with PowerShell or shell that parses the current version,
increments Minor, formats the UTC date, and emits the candidate. This can reduce
manual error, but version parsing/validation then becomes a new program that
must be specified and tested. T2 already tells the implementer to inspect and
update metadata manually.

#### Option F — Move the worked example to non-normative reference material

Keep T2 concise and link to a separate versioning example. This reduces the
chance of direct copying in T2 but creates another artifact that can age and is
unnecessary for a six-step calculation.

#### Permutations considered

- **Example type:** real current literal, fictional literal, symbolic pattern,
  or no example.
- **Location:** inline next to the algorithm, validation section, or external
  reference. Proximity increases copy risk when a literal is stale.
- **Automation:** manual calculation with validation versus executable
  generation. Automation is justified only if version calculation is complex
  enough to warrant another tested implementation.
- **Validation:** inspect the computed version and UTC date regardless of
  whether an example exists. The final T2 validation should remain the source
  of implementation evidence.

### Evaluation rubric

Options are scored 0–5 and weighted to 100. This rubric is specific to a
copy-safety/documentation defect:

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Copy correctness over time | 30 | The issue may be handed to an implementer later; no nearby literal should become a plausible but wrong command/value. |
| Single-source normative clarity | 25 | Documentation owners and reviewers need one authoritative calculation rule without examples that compete with it. |
| Cold-start usability | 15 | A new implementer must be able to calculate the value correctly without prior project context. |
| Maintenance entropy | 12 | Project managers should not need recurring issue-draft edits merely because time passed. |
| Consistency with repository version policy | 10 | The response must preserve current-version reread, Minor increment, UTC date, Revision reset, metadata, and changelog rules. |
| Validation simplicity | 5 | Reviewers need a direct way to compare the implemented version with the normative algorithm. |
| Editing churn | 3 | Minimal edits are preferable only after copy-safety and clarity are satisfied. |

Scoring rules:

- A real dated literal cannot score above 2 for copy correctness because it
  expires.
- An external or automated mechanism loses clarity points unless it is
  necessary to understand the calculation.
- A 5 for normative clarity requires exactly one authoritative algorithm.
- A 5 for usability requires the remaining text to be sufficient without an
  external reference.

### Scoring

Columns are copy correctness (CC), normative clarity (NC), cold-start usability
(CU), maintenance entropy (ME), policy consistency (PC), validation simplicity
(VS), and churn (CH).

| Option | CC | NC | CU | ME | PC | VS | CH | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Keep current example | 1 | 3 | 4 | 1 | 4 | 3 | 5 | 49.4 |
| B — Refresh today's literal | 2 | 3 | 4 | 1 | 4 | 3 | 4 | 54.8 |
| C — Symbolic example | 4 | 4 | 4 | 4 | 5 | 4 | 4 | 82.0 |
| D — Remove the example | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| E — Executable calculator | 5 | 4 | 4 | 3 | 5 | 5 | 2 | 85.4 |
| F — External worked example | 3 | 4 | 4 | 3 | 5 | 3 | 4 | 72.6 |

Option D scores perfectly because the existing normative algorithm is already
complete. Removing the expiring duplicate improves every criterion and costs
less than maintaining or testing a replacement example.

### Selected option and implementation specification

**Select Option D: remove the illustrative literal and keep the normative
algorithm as the sole source of truth.**

In T2 section “Advance guide version and metadata”:

1. Preserve the six numbered instructions exactly in substance.
2. Delete the conditional sentence beginning “If the branch remains…”.
3. Delete the fenced `2.7.20260728.0` value.
4. Delete “Otherwise recompute.”
5. Do not replace them with today's date, another literal, a placeholder, or an
   executable calculator.
6. Preserve the following changelog-content requirements and the validation
   that confirms the final version/date/metadata.

This is an editorial correction only. It does not change T2's affected files,
execution order, version policy, generated-artifact requirements, or acceptance
criteria.

## Evaluation conclusion

All four open TerraformStyleGuide findings from `current-findings.md` have now
been evaluated in order. The selected responses are:

1. T1-1 — generator convergence matrix plus reciprocal current-state
   checkpoint.
2. T1/T2-2 — linked issue owns a coherent minimum/preferred-LTS Node policy and
   complete affected-file discovery.
3. T1/T2-3 — complete Terraform hook, ephemeral-negative, audit, residual-risk,
   Dependabot, and supersession evidence contract.
4. T2-1 — remove the stale version literal and retain one normative algorithm.
