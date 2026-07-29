# Current findings evaluation

## Scope and process

This evaluation covers only the open TerraformStyleGuide findings recorded in
`docs/planning/artifacts/current-findings.md`. Findings already resolved in T1
or T2, and the P2-only comment-based-help observation, are not reopened.

The open findings will be evaluated sequentially:

1. reconcile or narrow the false P1/T1 helper-alignment claim;
2. give the permanent fixture suite one tracked, versioned owner;
3. pin checkout in the security-sensitive modified workflow;
4. define an explicit diagnostic-context interface; and
5. make the temporary-path trust envelope and ancestor-link handling explicit.

For each finding, this file will contain the complete option set, a
finding-specific weighted rubric, the scoring table, and the selected
implementation before evaluation proceeds to the next finding.

## Finding 1 — Reconcile the P1/T1 helper-alignment claim

### Options

The options below treat “alignment” as a contract-design decision, not merely
an editorial choice.

#### Option 1A — Narrow the claim and retain the current T1 architecture

Change T1 to say that the repositories share only the helper's high-level
purpose and selected validation behavior. Enumerate the different public
interfaces, checkout-root models, temporary-root models, diagnostics, harness
ownership, and pull-request coverage as intentional.

This is factually honest and immediately implementable, but it leaves T1's
separate security and maintainability gaps for Findings 2, 4, and 5 to solve.
Those later solutions could make the two designs converge again, so the
wording may need another pass.

#### Option 1B — Make T1 adopt P1's stronger complete helper/harness contract

Revise T1 to match P1 on:

- five mandatory helper parameters: `CheckoutRoot`, `TrustedTemporaryRoot`,
  `DownloadDirectory`, `CandidateDirectory`, and `ExpectedDigest`;
- optional `ArtifactId`, `RunId`, and `RunAttempt` diagnostic parameters;
- caller-supplied but helper-validated checkout and temporary trust roots;
- strict descendant and path-component validation;
- validation order and repeat checks;
- explicit diagnostic-label semantics; and
- a separate, tracked, versioned
  `Test-Expand-StyleGuideCandidateArtifact.ps1` as the sole fixture-suite
  definition.

Keep the repositories self-contained. Keep the four Terraform manifest names,
artifact names, and domain-specific generator behavior as repository-specific.
Document the Windows pull-request execution difference explicitly if P1
continues to run the harness only in its two LF cells while T1 runs it in all
four cells.

This option resolves the factual inconsistency by moving T1 to the stronger
current design rather than weakening P1.

#### Option 1C — Create a T1-specific hybrid and claim only behavioral parity

Keep T1's fixed-location checkout-root derivation, but add P1-like trusted
temporary-root validation, optional diagnostic labels, and a separate harness.
Say that validation outcomes are aligned while interfaces and trust-root
origins intentionally differ.

This can be secure, but it preserves two public APIs and two trust models. A
maintainer porting a fix must continue translating between implementations.

#### Option 1D — Coordinate a future P1 change to T1's current three-input model

Leave T1 materially unchanged and require the P1 drafter to remove the explicit
checkout/trusted-root inputs, optional diagnostics, and possibly separate
harness so P1 matches T1.

This could eventually make the statement true, but the Terraform-only revision
cannot deliver it. It also discards stronger explicit trust-boundary and
diagnostic contracts without a compensating technical benefit.

#### Option 1E — Remove all cross-repository alignment language

Delete the alignment statement and specify T1 independently. The generator
serialization contract can still converge without any stated helper parity.

This avoids false claims but loses a useful maintenance objective and makes
future security-fix drift between two nearly identical helpers more likely.

#### Option 1F — Introduce a shared runtime helper dependency

Move the helper or test suite into a common repository, package, reusable
workflow, submodule, or downloaded versioned asset consumed by both
repositories.

Permutations include centralizing only the harness, only archive validation, or
the complete helper/harness pair. This provides the strongest single-source
parity in theory, but adds cross-repository availability, versioning,
supply-chain, bootstrap, and incident-response dependencies. It conflicts with
the established self-contained-repository objective.

### Evaluation rubric

Score each criterion from 1 (poor) to 5 (excellent). The weighted total is:

`sum(weight × score / 5)`, with a maximum of 100.

This rubric is specific to cross-repository contract alignment:

| Criterion | Weight | Detailed meaning |
| --- | ---: | --- |
| Factual truth and internal coherence | 20 | The final T1 wording must be literally true, free of contradictory “only difference” claims, and understandable without comparing hidden implementation assumptions. |
| Security and trust-boundary quality | 25 | The choice should preserve explicit, fail-closed checkout, temporary-root, archive, destination, and diagnostic contracts. Security is weighted above convenience and issue churn. |
| Maintainable cross-repository parity | 20 | A security or correctness fix should be portable between repositories with minimal semantic translation, and future drift should be easy to detect in review. |
| Repository autonomy | 10 | Each repository should build, test, recover, and respond to incidents without another repository or external package being available. |
| Deliverability from the Terraform issue | 10 | A cold implementer must be able to complete the selected change through T1/T2 without waiting for an unspecified P1 rewrite or external project. |
| Clarity and reviewability | 10 | Public parameters, intentional differences, and evidence should be obvious to new developers, reviewers, operations staff, and auditors. |
| Churn and scope cost | 5 | Lower code/file churn and narrower issue expansion score better, but this is deliberately the least important criterion. |

### Scoring

| Option | Truth (20) | Security (25) | Parity (20) | Autonomy (10) | Deliverability (10) | Clarity (10) | Churn (5) | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1A — Narrow claim, retain T1 design | 5 | 3 | 3 | 5 | 5 | 5 | 5 | 82 |
| 1B — T1 adopts P1's complete contract | 5 | 5 | 5 | 5 | 4 | 5 | 2 | **95** |
| 1C — T1-specific hybrid | 5 | 5 | 3 | 5 | 4 | 4 | 3 | 86 |
| 1D — Wait for P1 to adopt current T1 | 5 | 2 | 5 | 5 | 1 | 4 | 3 | 73 |
| 1E — Remove alignment objective | 5 | 4 | 2 | 5 | 5 | 3 | 5 | 79 |
| 1F — Shared runtime dependency | 5 | 4 | 5 | 1 | 2 | 4 | 1 | 75 |

### Selected option

**Select Option 1B: make T1 adopt P1's stronger complete helper/harness
contract.**

Implementation instructions:

1. Add the five mandatory and three optional parameters to T1's helper
   contract, using the same names and scalar semantics as P1.
2. Require the helper—not the caller—to validate both supplied trust roots,
   every strict-descendant relationship, and every relevant existing path
   component.
3. Copy P1's omitted-versus-explicitly-empty diagnostic-label semantics.
4. Add the separately tracked, versioned test harness and make it the sole
   fixture-suite definition.
5. Align validation order, repeat checks, archive manifest/lifecycle rules,
   and diagnostic phases with P1.
6. Preserve TerraformStyleGuide's four exact manifest names and independent
   files; do not add a runtime cross-repository dependency.
7. Replace the false “only difference” sentence with precise wording:
   the helper/harness contract is aligned; manifest names, workflow artifact
   names, and any explicitly documented invocation-topology differences are
   repository-specific.
8. Propagate the final parameter, trust-root, harness, and topology contract
   into T2's prerequisite verification.

This selection establishes the architectural direction used by Findings 2, 4,
and 5; those findings will still be evaluated independently so their detailed
implementation choices and evidence are defensible on their own.

## Finding 2 — Give the permanent suite one tracked, versioned owner

### Options

#### Option 2A — Add one standalone PowerShell harness

Create
`.github/workflows/Test-Expand-StyleGuideCandidateArtifact.ps1` as the sole
definition of the deterministic fixture suite. It accepts the exact tracked
helper path, builds fixtures, invokes the helper only through its public
interface, verifies phase/postcondition oracles, and cleans up.

Every required workflow cell invokes this same file under its assigned
PowerShell edition. Developers can run the same harness locally without
simulating GitHub Actions.

#### Option 2B — Add a self-test mode to the production helper

Put the fixtures and test runner in
`Expand-StyleGuideCandidateArtifact.ps1`, selected by a `-SelfTest` switch or
parameter set. This creates one physical file but expands the production
interface, interleaves test-only and production control flow, and risks tests
sharing private implementation details instead of exercising only the public
contract.

Permutations include a hidden environment-variable switch, a dot-sourced
private function, or a documented parameter set. Hidden switches are
unacceptable; all variants make the production artifact larger and harder to
audit.

#### Option 2C — Repeat inline PowerShell suites in workflow steps

Embed fixture creation and assertions directly in every Ubuntu, Windows
pull-request, Windows push, and writer step.

This requires no added file but creates several independently editable copies.
The copies can silently drift in case coverage, shell behavior, diagnostics,
and cleanup. Local execution also requires extracting workflow text manually.

#### Option 2D — Define one inline suite through YAML anchors and aliases

Place a large `run:` block in `build.yml`, anchor it, and alias it into the
required steps or jobs. GitHub now documents support for YAML anchors and
aliases.

This reduces textual duplication inside one workflow, but the suite remains
embedded in orchestration YAML, is awkward to invoke locally, and still needs
edition-specific shell and surrounding-step variations. Anchoring a complete
job would also couple unrelated job behavior to the test definition.

#### Option 2E — Implement a local composite action

Create a local action directory with `action.yml` and one or more test scripts.
Invoke the composite action from each job.

This is reusable at the step level, but it adds metadata and shell-indirection
without improving on direct script execution. Composite-action internals are
also grouped differently in logs, which can make a large fixture suite less
transparent during incident diagnosis.

#### Option 2F — Implement a same-repository reusable workflow

Create another `.github/workflows/*.yml` file with `workflow_call` and call it
for the suite.

GitHub documents that reusable workflows are called as whole jobs, not as steps
inside an existing job. The suite must run immediately before production helper
use in each consumer and under each matrix cell's assigned edition, so a
separate called job cannot prove same-process or same-cell behavior. It is also
not directly locally executable.

#### Option 2G — Add a Pester-based harness

Create a tracked Pester test file plus a thin launcher. This provides rich test
structure and reporting, but introduces a framework/version/bootstrap
dependency that must work under Windows PowerShell 5.1 and PowerShell 7 on
Windows and Ubuntu. The fixture suite needs no mocking framework and is
security-sensitive enough that implicit module discovery is undesirable.

#### Option 2H — Add a test module plus a thin executable harness

Separate fixture builders/assertions into a `.psm1` module and keep a small
`Test-*.ps1` entry point. This offers internal organization for a very large
suite, but creates another versioned file and module-loading boundary. It is
useful only if a single script proves unmaintainable during implementation.

### Evaluation rubric

Score 1 (poor) through 5 (excellent), using
`sum(weight × score / 5)` for a maximum of 100.

This rubric is specific to ownership of a security-sensitive executable test
oracle:

| Criterion | Weight | Detailed meaning |
| --- | ---: | --- |
| Oracle fidelity and regression detection | 30 | Tests must exercise the exact public production helper, distinguish expected phases/postconditions, and make bypasses or implementation-coupled false positives difficult. |
| Single-source drift resistance | 25 | There must be one obvious, versioned definition used by every required consumer, with code review able to detect case additions/removals. |
| Cross-edition and local executability | 20 | The same suite must run under Desktop 5.1 and Core 7, on required operating systems, and from a developer shell without reproducing CI orchestration. |
| Auditability and failure diagnostics | 10 | Reviewers and responders should see stable case IDs, exact failures, and cleanup behavior with little indirection. |
| Dependency and supply-chain simplicity | 10 | Prefer built-in PowerShell/.NET behavior and avoid an extra framework, action runtime, module-resolution assumption, or remote dependency. |
| Churn and implementation cost | 5 | Fewer files and less wiring score better, but only after correctness and maintainability. |

### Scoring

| Option | Oracle (30) | Drift resistance (25) | Cross-edition/local (20) | Auditability (10) | Dependency simplicity (10) | Churn (5) | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2A — Standalone PowerShell harness | 5 | 5 | 5 | 5 | 5 | 3 | **98** |
| 2B — Production-helper self-test mode | 4 | 5 | 5 | 3 | 5 | 4 | 89 |
| 2C — Repeated inline workflow suites | 4 | 1 | 3 | 3 | 5 | 5 | 62 |
| 2D — YAML-anchored inline suite | 4 | 4 | 2 | 3 | 4 | 4 | 70 |
| 2E — Local composite action | 4 | 5 | 4 | 3 | 4 | 2 | 81 |
| 2F — Reusable workflow job | 3 | 5 | 1 | 4 | 4 | 2 | 65 |
| 2G — Pester-based harness | 5 | 5 | 5 | 5 | 2 | 1 | 90 |
| 2H — Module plus thin harness | 5 | 5 | 5 | 5 | 4 | 1 | 94 |

### Selected option

**Select Option 2A: add one standalone, tracked PowerShell harness.**

Implementation instructions:

1. Add
   `.github/workflows/Test-Expand-StyleGuideCandidateArtifact.ps1` to T1's
   affected files and exact staged/working-tree sets.
2. Require `#Requires -Version 5.1`, top-level comment-based-help version
   metadata, strict failure behavior, and a mandatory scalar `HelperPath`.
3. Resolve `HelperPath` exactly once to the existing tracked regular,
   non-reparse-point helper file before changing location; invoke that absolute
   path for every case.
4. Build every deterministic fixture under one unique runner-temporary root.
5. Invoke the helper only as a child script through its documented public
   parameters. Do not copy or dot-source the helper's digest, path, archive, or
   extraction implementation.
6. Use the T1 outcome table as the normative case inventory and assert the
   required phase, candidate-leaf state, sentinel state, extracted type/count,
   and bytes for every case.
7. Change working directory during at least one valid case to prove that
   neither harness nor helper depends on ambient location.
8. Return nonzero for an unexpected outcome, diagnostic, filesystem state, or
   cleanup failure. Clean the complete fixture root in `finally`.
9. Invoke this exact harness in Ubuntu pull-request verification, all four
   Windows pull-request cells, all four Windows push cells, and the writer when
   it executes. Keep each Windows invocation in the same explicit-shell process
   as its edition assertion.
10. Update T2 to require this named harness and include the harness in the final
    T1 implementation set. Finding 3 may add further files, so use the
    consolidated final count rather than freezing this finding's interim
    five-file count.

The GitHub reuse alternatives remain documented in
`docs/planning/artifacts/prompt-02-primary-source-research.md`; they are not a
better fit for a directly executable cross-edition test program.

## Finding 3 — Pin checkout in the security-sensitive modified workflow

### Options

#### Option 3A — Retain movable major tags

Keep `actions/checkout@v4`, `actions/setup-node@v4`, and any other existing
major tags, relying on GitHub's ownership of the `actions` organization and
ordinary release management.

This is convenient but does not address the finding. GitHub's secure-use
reference says that only a full commit SHA makes the selected action revision
immutable.

#### Option 3B — Pin checkout only in `build.yml`

Pin every checkout step in the modified build/push workflow to the current
approved full SHA. Keep T1's artifact-action pins, and leave
`markdownlint.yml` unchanged.

This closes the identified credential-bearing writer path with minimal churn,
but leaves another checkout reference and setup-node on mutable tags and
establishes no repository-wide policy.

#### Option 3C — Pin every checkout reference, but no other existing action

Pin checkout in both `build.yml` and `markdownlint.yml`, mirroring P1's
action-class scope. Leave `actions/setup-node` on its major tag while pinning
the artifact actions introduced or changed by T1.

This is more consistent for checkout and updates both workflows to the Node 24
action runtime. It still requires reviewers to explain why one executable
third-party action in `markdownlint.yml` remains mutable.

#### Option 3D — Pin every external action in both workflows

Pin checkout, setup-node, upload-artifact, and download-artifact to verified
full SHAs with adjacent release comments. Add `markdownlint.yml` to T1's
affected files and validation sets.

This gives the repository one simple execution-time policy. Its weakness is
maintenance: without a reminder or updater, immutable references can silently
age.

#### Option 3E — Pin only the build workflow and add Dependabot

Combine Option 3B with a new `.github/dependabot.yml` entry for GitHub Actions.
Dependabot can propose updates for both SHA- and tag-based references.

This maintains the critical pins, but Dependabot's presence does not make the
remaining tags immutable between update reviews. The policy remains mixed.

#### Option 3F — Pin all external actions and add Dependabot version updates

Combine Option 3D with a minimal weekly GitHub Actions Dependabot
configuration. Dependabot opens reviewable pull requests that update the SHA
and adjacent version comment; no update is auto-merged.

Permutations include daily, weekly, or monthly schedules; grouped or separate
pull requests; and major-version ignores. A weekly schedule with separate
default pull requests gives timely visibility and isolated release review
without daily noise. The issue must still require human verification of the
upstream repository, release notes, Node runtime, inputs, and compatibility.

#### Option 3G — Depend on an organization/repository SHA-enforcement policy

Configure or assume a GitHub Actions policy that rejects non-SHA references,
without explicitly revising every workflow reference in this issue.

Enforcement is valuable defense in depth but is external state and cannot make
the committed workflow runnable until the references are converted. It also
does not select or validate the intended releases.

#### Option 3H — Vendor or replace the actions

Check action code into the repository, use a local composite action, or replace
checkout/setup with handwritten Git and tool-install commands.

This removes movable remote references but shifts patching, credential
handling, platform behavior, and supply-chain review onto this repository.
Vendoring the large JavaScript distributions would be disproportionate and
handwritten checkout would weaken a mature security boundary.

### Evaluation rubric

Score 1 through 5. Weighted total:
`sum(weight × score / 5)`, maximum 100.

This rubric is specific to executable workflow dependency governance:

| Criterion | Weight | Detailed meaning |
| --- | ---: | --- |
| Execution-time supply-chain protection | 35 | Every action capable of reading the checkout, token, generated artifacts, or workflow environment should execute immutable, upstream-verified code. |
| Policy consistency and auditability | 15 | A reviewer should be able to state and mechanically inspect one repository-wide rule without action-class exceptions. |
| Runtime currency and compatibility | 15 | Selected releases must use supported runtimes, retain required inputs/credential behavior, and work on the targeted GitHub-hosted runners. |
| Sustainable update lifecycle | 15 | The design should surface new releases and keep SHA comments synchronized without silently reverting to mutable tags. |
| Operational control and review burden | 10 | Updates must remain human-reviewable, avoid unbounded alert/PR noise, and permit release-specific risk assessment. |
| Verification and rollback simplicity | 5 | Each update should have a clear upstream identity, focused diff, test path, and reversible commit. |
| Churn and issue expansion | 5 | Fewer affected files and new automation surfaces score better, with intentionally low weight. |

### Scoring

| Option | Protection (35) | Consistency (15) | Compatibility (15) | Updates (15) | Operations (10) | Verification (5) | Churn (5) | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 3A — Retain major tags | 1 | 1 | 3 | 5 | 5 | 5 | 5 | 54 |
| 3B — Pin build checkout only | 4 | 3 | 5 | 2 | 5 | 5 | 5 | 78 |
| 3C — Pin all checkout references | 4 | 4 | 5 | 2 | 5 | 5 | 4 | 80 |
| 3D — Pin every external action | 5 | 5 | 5 | 2 | 5 | 5 | 2 | 88 |
| 3E — Build pins plus Dependabot | 4 | 3 | 5 | 5 | 3 | 4 | 3 | 80 |
| 3F — All pins plus Dependabot | 5 | 5 | 5 | 5 | 3 | 4 | 1 | **91** |
| 3G — Enforcement policy only | 2 | 5 | 2 | 3 | 2 | 2 | 4 | 54 |
| 3H — Vendor or replace actions | 4 | 4 | 2 | 1 | 2 | 2 | 1 | 56 |

### Selected option

**Select Option 3F: pin every external action in both workflows and add
review-only Dependabot version updates.**

Implementation instructions:

1. Add `.github/workflows/markdownlint.yml` and
   `.github/dependabot.yml` to T1's affected files and all exact path-set
   checks.
2. As of 2026-07-29, prescribe these verified full action-distribution SHAs:

   ```yaml
   actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6.1.0
   actions/setup-node@249970729cb0ef3589644e2896645e5dc5ba9c38 # v6.5.0
   actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
   actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1
   ```

3. Require immediate preimplementation revalidation of every SHA, adjacent
   comment, upstream repository, latest required security release, action
   metadata/runtime, and every relied-on input/output. Update references and
   evidence atomically if a release changes.
4. Preserve markdown lint's current Node/package behavior; pinning and runtime
   currency do not authorize changing lint semantics or dependency versions.
5. Configure:

   ```yaml
   version: 2
   updates:
     - package-ecosystem: github-actions
       directory: /
       schedule:
         interval: weekly
   ```

   Keep update pull requests separate by default and require human review; do
   not add auto-merge.
6. Validate the checkout v6 credential model and runner compatibility. Prove
   the controlled writer can push and post-job cleanup completes.
7. Require a static scan that every nonlocal `uses:` in both workflow files is
   a 40-hex full SHA with an adjacent version comment.
8. Update T2's prerequisite and affected-path expectations to the resulting
   seven-file T1 implementation set.

The upstream facts and exact refs are preserved in
`docs/planning/artifacts/prompt-02-primary-source-research.md`.

## Finding 4 — Define an explicit diagnostic-context interface

### Options

#### Option 4A — Add three optional scalar diagnostic parameters

Add optional `ArtifactId`, `RunId`, and `RunAttempt` parameters beside the five
mandatory functional parameters selected in Finding 1. Use
`$PSBoundParameters` to distinguish an omitted label from an explicitly bound
empty value.

Callers that possess the labels pass them explicitly. Local validation and
fixtures may omit them and receive an unambiguous “unavailable” representation.
The helper owns a stable phase/context diagnostic format.

#### Option 4B — Make all three diagnostic parameters mandatory

Require every helper call to provide artifact ID, run ID, and attempt.
Production CI always has or can propagate these values.

This maximizes production consistency but forces local use and most fixtures to
invent labels. Invented IDs undermine provenance and make logs look more
authoritative than they are.

#### Option 4C — Keep the helper silent about workflow context and enrich in callers

The helper reports only phase, paths, entry names, and digests. Each workflow
step catches its failure and adds artifact/run context.

This can work, but multiple wrappers can format context differently or lose the
original phase/exception. A helper contract requiring the labels “when
available” remains untestable unless every caller wrapper is separately
specified.

#### Option 4D — Read context from environment variables

Have the helper inspect standard GitHub variables and custom environment
variables such as `CANDIDATE_ARTIFACT_ID`.

This avoids parameters, but couples behavior to mutable ambient process state,
makes local behavior implicit, and risks stale variables leaking between cases.
It is particularly unsuitable for a helper whose trust boundaries are intended
to be explicit.

#### Option 4E — Return or throw a structured diagnostic object

Define a custom PowerShell class, error-record schema, JSON payload, or result
object containing phase, paths, digest data, and optional labels. Callers render
it.

This provides strong machine readability, but custom-class serialization and
error propagation across Windows PowerShell 5.1, PowerShell 7, child scripts,
and workflow logs add considerable complexity. A failed child script also needs
a reliable exit code and human-readable message.

#### Option 4F — Accept one extensible `DiagnosticContext` dictionary

Take a hashtable/dictionary with keys such as `ArtifactId`, `RunId`, and
`RunAttempt`. Future callers can add fields without changing the parameter
list.

This is flexible, but key spelling, value type, omission, emptiness, and unknown
keys require another schema. It is less discoverable through PowerShell help
and tab completion than three stable scalar parameters.

#### Option 4G — Accept a logger callback or diagnostic sink

Pass a script block, delegate, or interface that receives structured events.
Workflows can format or route diagnostics independently.

This is appropriate for a library but disproportionate for a child script. It
creates executable caller input, complicates process boundaries, and reduces
P1/T1 parity.

#### Option 4H — Split a diagnostic-aware wrapper from a private extraction module

Add a workflow-facing wrapper that accepts context and calls a separate private
module containing validation/extraction.

This isolates concerns, but creates another production file and risks the
harness testing the wrapper while callers or future code bypass it. The
selected single production helper already has a manageable public interface.

### Evaluation rubric

Score 1 through 5, with
`sum(weight × score / 5)` and a maximum of 100.

This rubric is specific to provenance-quality failure diagnostics:

| Criterion | Weight | Detailed meaning |
| --- | ---: | --- |
| Diagnostic accuracy and provenance | 25 | Logs must never invent identity, confuse omitted with empty, or associate a failure with stale ambient context. |
| Interface explicitness and testability | 25 | Inputs and semantics must be visible in help/parameter binding and directly exercisable by the permanent harness. |
| Local and fixture usability | 15 | Developers and deterministic tests without real GitHub artifact metadata must be able to invoke the same production path honestly. |
| Failure-path completeness | 15 | Digest, archive, manifest, containment, lifecycle, extraction, and cleanup failures must retain phase plus all context known at that point. |
| P1/T1 parity and maintenance | 15 | The solution should match the corresponding PSStyleGuide contract so diagnostic fixes port cleanly. |
| Churn and complexity | 5 | Simpler interfaces score better after provenance and completeness. |

### Scoring

| Option | Provenance (25) | Explicit/testable (25) | Local use (15) | Failure completeness (15) | Parity (15) | Churn (5) | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4A — Optional scalar parameters | 5 | 5 | 5 | 5 | 5 | 4 | **99** |
| 4B — Mandatory diagnostic parameters | 5 | 5 | 2 | 5 | 4 | 3 | 86 |
| 4C — Caller-only enrichment | 4 | 3 | 5 | 3 | 2 | 4 | 69 |
| 4D — Ambient environment variables | 2 | 1 | 5 | 2 | 2 | 5 | 47 |
| 4E — Structured result/error object | 5 | 4 | 4 | 5 | 3 | 2 | 83 |
| 4F — Diagnostic-context dictionary | 4 | 4 | 5 | 4 | 3 | 4 | 80 |
| 4G — Logger callback/sink | 5 | 3 | 3 | 4 | 2 | 1 | 68 |
| 4H — Wrapper plus private module | 4 | 4 | 4 | 4 | 2 | 1 | 71 |

### Selected option

**Select Option 4A: add explicit optional scalar diagnostic parameters.**

Implementation instructions:

1. Add optional `ArtifactId`, `RunId`, and `RunAttempt` string parameters to
   the helper after the five mandatory functional parameters.
2. Reject null or empty values when a label is explicitly bound. Use
   `$PSBoundParameters.ContainsKey(<name>)` to distinguish omission from an
   invalid supplied value.
3. Treat the values only as caller-supplied diagnostic labels. Do not use them
   for selection, authorization, path construction, or digest trust, and never
   derive or invent a missing value.
4. Represent each omitted label consistently as `unavailable`.
5. Require production callers to pass the validated artifact ID and the
   workflow's run ID/attempt. Local callers may omit the labels.
6. Define stable validation-phase identifiers and require diagnostics to
   include:
   - every supplied or unavailable label;
   - normalized checkout and trusted-temporary roots;
   - normalized download/candidate paths;
   - archive path once selected;
   - expected digest and actual digest once computed;
   - offending entry or destination when applicable; and
   - the failing phase.
7. Preserve the original exception and a nonzero child-process result while
   adding context; do not replace a precise helper failure with a generic
   wrapper message.
8. Add harness cases for omitted labels, all supplied labels, and each
   explicitly empty label. Prove supplied labels appear, omitted labels are
   marked unavailable, and empty labels fail before archive or destination
   processing.
9. Keep event, edition, version, fixture EOL, and workflow artifact-path
   context in the workflow layer; those describe the consumer, while the three
   optional labels travel through the shared helper interface.
10. Propagate the exact interface into T2's prerequisite verification.

## Finding 5 — Define the complete temporary-path trust envelope

### Options

#### Option 5A — Keep immediate-parent checks and narrow the guarantee

Retain T1's current checks for the download directory, candidate leaf, and
their immediate parents. Explicitly call all checkout comparisons lexical and
state that callers alone guarantee link-free ancestors beneath a protected
runner-temporary directory.

This is honest and inexpensive, but the security-sensitive helper cannot
verify the central assumption. A caller mistake can silently make an
apparently outside path traverse into the checkout or another location.

#### Option 5B — Adopt P1's declared-root-to-working-path envelope

Accept explicit `CheckoutRoot` and `TrustedTemporaryRoot` parameters. Require
both roots to exist, be separate, and be ordinary non-reparse directories.
Require download and candidate paths to be strict descendants of the trusted
root. Walk and reject links/reparse points from each declared root through each
working path.

This is substantially stronger and matches P1. It does not inspect ancestors
above the two declared roots, so two lexically separate roots could theoretically
arrive through earlier indirection.

#### Option 5C — Reject indirection in every absolute existing component

Use the explicit roots from Option 5B, but inspect every existing component
from each filesystem volume/share root through:

- `CheckoutRoot`;
- `TrustedTemporaryRoot`;
- `DownloadDirectory` and the retained archive;
- the existing parent of `CandidateDirectory`; and
- every created candidate path.

Reject any component with `FileAttributes.ReparsePoint` or any attribute/read
failure. After establishing an indirection-free absolute envelope, apply
separator-aware lexical strict-descendant tests. Repeat relevant component and
containment checks immediately before archive open, immediately before
candidate creation, and after extraction.

State the residual model: runner-controlled ancestors, job-owned roots, and no
competing writer. This is the strongest common-denominator design available
without OS-specific handle APIs.

#### Option 5D — Resolve physical targets with modern .NET or external `realpath`

Canonicalize each root and working path using
`FileSystemInfo.ResolveLinkTarget`, `realpath`, or platform-specific
equivalents, then compare final targets.

This can follow rather than reject links, which complicates dangling links and
root-overlap rules. More importantly, the modern .NET API is not a reliable
Windows PowerShell 5.1 common denominator, while external tools differ by
runner and platform.

#### Option 5E — Use OS-native no-follow handles for race resistance

Implement Unix `openat`/`O_NOFOLLOW`-style traversal and Windows handle/reparse
APIs so every component is opened relative to a trusted directory handle.

This offers stronger time-of-check/time-of-use protection but requires native
interop, separate operating-system implementations, careful resource
management, and extensive review. It is disproportionate for four files on
ephemeral GitHub-hosted runners and conflicts with the portable PowerShell 5.1
contract.

#### Option 5F — Let the helper create and own all temporary paths

Pass only an approved runner-temporary root or derive it from ambient state.
The helper creates unique download/candidate children and returns paths.

This reduces caller mistakes but does not fit the download action, which must
receive a destination before the helper runs. Deriving `RUNNER_TEMP` from the
environment also reintroduces hidden trust input; accepting it explicitly
becomes a variant of Option 5B or 5C.

#### Option 5G — Rely on directory permissions or ACLs

Require a private temporary parent and assume permissions prevent link
replacement, without exhaustively checking path components.

Permissions help the no-competing-writer model but do not prove that the path
used to reach the protected directory is itself free of indirection. They are
defense in depth, not a replacement for validation.

#### Option 5H — Isolate extraction in a container or sandbox

Perform download validation/extraction inside a container, restricted user
namespace, or dedicated sandbox and copy the four outputs out afterward.

This adds image/runtime trust, cross-platform asymmetry, another transfer
boundary, and weak Windows PowerShell 5.1 parity. It does not remove the need
to validate host paths used for ingress and egress.

### Evaluation rubric

Score 1 through 5. Weighted total:
`sum(weight × score / 5)`, maximum 100.

This rubric is specific to filesystem containment under a portable
GitHub-hosted-runner threat model:

| Criterion | Weight | Detailed meaning |
| --- | ---: | --- |
| Containment and indirection correctness | 30 | Lexical sibling prefixes, root overlap, ancestor links, final links, dangling links, and reparse points must fail closed before an unsafe read/write. |
| Windows PowerShell 5.1 and cross-platform compatibility | 20 | The same normative algorithm must work with built-in APIs under Desktop 5.1 and Core 7 on Windows and Ubuntu. |
| Race resistance within the stated threat model | 20 | Relevant checks must be repeated near use, roots must be job-owned/protected, and residual no-competing-writer assumptions must be explicit. |
| Caller and maintainer clarity | 10 | Trust inputs, strict-descendant rules, ownership, and unsupported topologies must be obvious to a cold implementer. |
| Deterministic testability | 10 | The harness must be able to build positive and negative roots, sibling prefixes, component links, final links, and overlap cases with stable oracles. |
| P1/T1 portability | 5 | The contract should minimize semantic divergence between the two self-contained helpers. |
| Churn and implementation difficulty | 5 | Simpler algorithms score better only after containment and portability. |

### Scoring

| Option | Containment (30) | Compatibility (20) | Race model (20) | Clarity (10) | Testability (10) | Parity (5) | Churn (5) | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 5A — Immediate parent plus narrow claim | 2 | 5 | 2 | 5 | 4 | 2 | 5 | 65 |
| 5B — Declared-root envelope | 4 | 5 | 4 | 5 | 5 | 5 | 3 | 88 |
| 5C — Full existing-component rejection | 5 | 5 | 4 | 4 | 5 | 4 | 2 | **90** |
| 5D — Physical target-resolution APIs | 5 | 2 | 4 | 3 | 4 | 2 | 2 | 72 |
| 5E — OS-native no-follow handles | 5 | 1 | 5 | 1 | 3 | 1 | 1 | 64 |
| 5F — Helper-owned temporary paths | 4 | 5 | 4 | 5 | 4 | 2 | 4 | 84 |
| 5G — Permissions/ACLs only | 2 | 4 | 3 | 3 | 2 | 2 | 4 | 56 |
| 5H — Container or sandbox | 4 | 3 | 4 | 2 | 3 | 1 | 1 | 64 |

### Selected option

**Select Option 5C: explicit roots plus rejection of indirection in every
absolute existing component.**

Implementation instructions:

1. Require the five mandatory helper parameters selected in Finding 1.
2. Resolve `CheckoutRoot` and `TrustedTemporaryRoot` through the filesystem
   provider to exactly one existing directory each. Reject relative paths,
   wildcards, non-filesystem providers, files, and missing roots.
3. Convert all accepted paths to deterministic absolute filesystem paths before
   using .NET.
4. Build a component sequence from the filesystem volume/share root through
   every existing root and working-path component. For each component:
   - require exactly one existing filesystem entry of the expected kind;
   - obtain attributes with APIs available under Windows PowerShell 5.1;
   - reject `FileAttributes.ReparsePoint`;
   - reject a symbolic link, junction, Windows volume-mount/reparse entry,
     dangling entry, or attribute/read failure; and
   - never follow a component merely to classify it as safe.
5. Require the two declared roots to be mutually non-overlapping: neither may
   equal or contain the other. Require download and candidate paths to be strict
   descendants of the trusted root and outside checkout. Use separator-aware
   ordinal-ignore-case comparison on Windows and ordinal comparison elsewhere.
6. For the initially nonexistent candidate leaf, validate every existing
   component through its parent and enumerate that parent exhaustively to
   reject every same-name leaf entry, including a dangling link.
7. Repeat the applicable full component, containment, parent, leaf, and
   ordinary-file/directory checks:
   - immediately before opening the retained archive;
   - after complete archive/manifest validation and immediately before creating
     the candidate directory; and
   - after extraction before returning paths.
8. Use `FileMode.CreateNew` and no sharing for extracted files, as already
   required. Do not delete/recreate or follow an existing candidate leaf.
9. State the residual race model explicitly: supported jobs use GitHub-hosted
   runners; ancestors are runner-controlled; checkout and the unique trusted
   temporary root are job-owned; and no competing writer may replace entries
   during the helper call. The repeated checks narrow but do not claim to
   eliminate all same-user races.
10. Extend the harness with root-overlap, ancestor-link, component-link,
    dangling-final-link, sibling-prefix, case-variant, and
    filesystem-provider-qualified path cases. If a link cannot be created on a
    runner, emit a narrowly justified skip and require the same case on another
    mandatory runner.
11. Align P1 in a coordinated pass if exact helper parity remains the declared
    objective. Until then, T1 must describe the stronger full-component walk
    as an intentional contract improvement rather than claiming a nonexistent
    line-for-line implementation identity.
12. Propagate the complete root/component/recheck contract into T2's
    prerequisite verification.

The API portability and runner facts supporting this choice are preserved in
`docs/planning/artifacts/prompt-02-primary-source-research.md`.

## Consolidated selected design

The five selected options combine into one coherent T1 implementation:

1. T1 adopts P1's explicit five mandatory helper inputs, three optional
   diagnostic labels, and separate harness architecture.
2. The tracked harness is the sole fixture-suite definition and runs under
   every required edition/cell.
3. Every external action in both workflows is pinned to a verified full SHA,
   with weekly review-only Dependabot updates.
4. Diagnostic provenance is explicit and testable; ambient environment state
   is not part of the helper interface.
5. Both declared roots and every existing absolute path component are
   indirection-free, with repeat checks and an explicit protected/no-competing-
   writer model.

These selections expand T1's implementation set to seven files:

1. `.gitattributes`;
2. `.github/dependabot.yml`;
3. `.github/workflows/Expand-StyleGuideCandidateArtifact.ps1`;
4. `.github/workflows/Generate-StyleGuideArtifacts.ps1`;
5. `.github/workflows/Test-Expand-StyleGuideCandidateArtifact.ps1`;
6. `.github/workflows/build.yml`; and
7. `.github/workflows/markdownlint.yml`.

T2 remains the second issue. It does not reimplement T1, but its prerequisite
verification, exact prerequisite path set, evidence, and acceptance language
must reflect this final seven-file contract.
