# Current findings

## Review scope and method

This review covers the proposed TerraformStyleGuide issues T1 and T2 in
execution order. P1 and P2 are cross-repository context only; they are not
independently critiqued here. Each recommendation in
`docs/planning/PSStyleGuide/slate-criticism.md` will be assessed explicitly
before independent T1/T2 findings are finalized.

Authoritative evidence being checked:

- the current TerraformStyleGuide and PSStyleGuide repository states;
- `docs/planning/TerraformStyleGuide/03TerraformStyleGuideT1.md`;
- `docs/planning/TerraformStyleGuide/04TerraformStyleGuideT2.md`;
- `docs/planning/PSStyleGuide/01PSStyleGuideP1.md`;
- `docs/planning/PSStyleGuide/02PSStyleGuideP2.md`; and
- `docs/planning/PSStyleGuide/slate-criticism.md`.

## Supplied recommendation assessments

### Recommendation 1 — Reconcile the claimed P1/T1 helper alignment

**Disposition: confirmed defect; proposed resolution only partially confirmed.**

The factual criticism is correct. T1 says that the helper's “filename, parameter
interface, validation order, and diagnostics” are aligned with P1 and that the
four manifest names are the intentional difference. They are not:

- T1 has three public inputs and derives the checkout root from the helper's
  fixed tracked location.
- P1 has five mandatory path/digest inputs, three optional diagnostic inputs, a
  caller-supplied checkout boundary, a caller-supplied trusted temporary root,
  and a separate tracked harness.
- T1 runs the suite in all four Windows pull-request cells; P1 runs it in two LF
  cells.

This is a remaining **high-priority T1 finding** because T1 itself makes the
false cross-repository claim.

The criticism's preferred architecture—changing P1 to T1's
fixed-root/three-input design—is reasonable but is not logically forced by the
inconsistency, and this review is not a P1/P2 critique. The required T1 action
is to do one of the following before filing:

1. coordinate a genuinely shared helper contract and update both slates; or
2. narrow T1's claim to the actual common elements and document the interface,
   trust-boundary, harness, and PR-coverage differences as intentional.

Do not claim that only manifest names differ while the published interfaces and
trust models remain incompatible. Generator unification does not require
pretending that helper designs are identical.

### Recommendation 2 — Use one writer ref identity

**Disposition: confirmed as technically valid; already addressed in T1.**

The recommendation correctly identifies the risk of validating `GITHUB_REF` and
pushing a separately named `TARGET_REF`. Current T1 now:

- defines `TARGET_REF` and `EXPECTED_SHA` through workflow `env`;
- copies them to local variables;
- cross-checks `TARGET_REF` against `GITHUB_REF`;
- resolves and verifies the complete `HEAD^{commit}` object ID;
- queries the remote with the validated local ref; and
- reuses the same local ref/SHA for the exact lease and explicit destination
  refspec.

No further T1/T2 finding remains for this recommendation.

### Recommendation 3 — Bind helper calls to explicit edition-specific processes

**Disposition: confirmed as technically valid; already addressed in T1 and
inherited accurately by T2.**

Current T1 requires:

- Ubuntu execution under explicit `pwsh` with a same-process Core 7 assertion;
- mutually exclusive Desktop and Core Windows steps;
- explicit `powershell` for Desktop 5.1 and `pwsh` for Core 7;
- same-process edition assertions and helper invocation; and
- no helper call from an edition-neutral fixture step.

It also runs the permanent suite in all four Windows pull-request cells. T2's
prerequisite verification accurately inherits this topology. No additional T1/T2
change is needed.

### Recommendation 4 — Specify exhaustive enumeration and final-leaf detection

**Disposition: confirmed as technically valid; already addressed in T1.**

Current T1 prescribes absolute filesystem-provider paths, OS-appropriate
separator-aware comparison, `Directory.EnumerateFileSystemEntries` for every
exact entry assertion, `Get-ChildItem -LiteralPath -Force` only for supporting
diagnostics, parent enumeration for existing/dangling candidate leaves,
immediate re-enumeration, and exhaustive post-extraction inspection. Its
fixtures include hidden extras and existing, reparse, symlink, and dangling
candidate leaves.

No further T1/T2 finding remains for this recommendation.

### Recommendation 5 — Replace ambiguous fixture prose with an outcome table

**Disposition: confirmed as technically valid; already addressed in T1.**

Current T1 has a normative fixture table with explicit success/rejection
classifications and required failure phases/postconditions. It distinguishes:

- the normal valid archive;
- the valid archive whose external attributes must be ignored;
- negative digest/archive/manifest/download/destination cases; and
- the successful sibling-prefix path-classification case.

It also requires stable case identifiers and explicit oracles rather than
treating any thrown exception as sufficient. No additional T1/T2 change is
needed.

### Recommendation 6 — Make consumer wording match the conditional graph

**Disposition: confirmed as technically valid; already addressed in T1 and T2.**

Current T1 distinguishes the always-running four Windows push cells from the
writer that runs only when `has_changes=true`. Its no-drift evidence requires
the writer to skip and allocates writer-path evidence to the controlled
synchronization drill and static inspection.

Current T2 likewise requires four successful Windows cells and a `skipped`
writer whose steps did not execute. The prior “every push consumer on every run”
contradiction is gone. No additional T1/T2 change is needed.

### Recommendation 7 — Preserve a deliberate generator-unification boundary

**Disposition: confirmed as a sound design principle; current T1 observes it.**

T1 and P1 intentionally share the serialization boundary:

- `#Requires -Version 5.1`;
- final-payload CR canonicalization;
- resolved filesystem destinations;
- BOM-less `UTF8Encoding($false)`; and
- `WriteAllText` without an implicit newline.

T1 correctly preserves TerraformStyleGuide's already-correct LF-joined
frontmatter rather than changing it merely to mimic P1's implementation work.
The instruction artifact names, chat branding, executive-summary/rationale
model, and full-guide merge logic are legitimate repository-specific
differences. The repositories should remain self-contained.

This recommendation does not reveal a further T1/T2 defect beyond the separate
false helper-alignment statement in Recommendation 1.

### Recommendation 8 — Make P2's validation helper conform to the guide

**Disposition: partially confirmed, low priority, and outside the T1/T2 review
scope.**

P2 declares `Get-OrdinalOccurrenceCount` without full comment-based help, while
the PSStyleGuide says functions in covered PowerShell files require such help.
The concern is valid if the block is intended to be saved as canonical `.ps1`
implementation or reusable code.

The issue presents the block as ad hoc commands to run from the repository root,
not as a committed `.ps1` file. The guide's stated file scope therefore does not
conclusively make this a violation. Avoiding a named function would remove the
ambiguity, but this is a P2-only editorial concern and creates no T1/T2 finding.

## Independent T1/T2 review

### Verified baseline

- T1 and T2 are in the correct execution order. T1 establishes the
  serialization, line-ending, helper, workflow, transport, and writer contracts
  on which T2 relies.
- TerraformStyleGuide's current `main` baseline has no root `.gitattributes`;
  its generator already declares PowerShell 5.1 but still writes the four
  generated artifacts with edition-sensitive
  `Set-Content -Encoding UTF8 -NoNewline`; and its workflows still use movable
  action tags.
- PSStyleGuide's current `main` baseline already has exactly
  `* text=auto eol=lf`. The two repositories therefore need the same resulting
  text policy but different implementation work.
- T1 correctly preserves TerraformStyleGuide's existing LF-joined Terraform
  frontmatter while adopting the same final serialization algorithm proposed by
  P1.
- The exact proposed artifact-action SHAs are valid current upstream pins:
  - `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` is v7.0.1
    and exposes `artifact-id` and `artifact-digest`;
  - `actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` is
    v8.0.1 and exposes `artifact-ids`, `skip-decompress`, and `digest-mismatch`;
    and
  - the pinned download implementation passes GitHub's artifact digest as the
    expected hash and throws for a mismatch when the selected behavior is
    `error`.
- Independent review did not find another defect in T2's provider commands,
  no-overwrite examples, HCP response handling, conditional writer evidence, or
  T1 prerequisite inheritance. T2 must, however, inherit any T1 file-set or
  contract corrections selected below.

### High — T1 gives the permanent suite no single, versioned owner

T1 requires the same substantial deterministic fixture suite in the Ubuntu
pull-request job, all four Windows pull-request cells, all four Windows push
cells, and the conditional writer. Its affected-file set contains only
`.gitattributes`, the generator, the production helper, and `build.yml`. It
neither adds a tracked test harness nor names another sole definition of the
suite.

An implementer could therefore duplicate a large inline PowerShell suite across
jobs, create subtly different suites, or place test-only behavior inside the
production helper. The phrase “the deterministic fixture self-test suite” does
not by itself establish one maintainable implementation. This is especially
risky because the suite is the executable oracle for security-sensitive archive
and filesystem behavior.

Preferred correction:

1. Add `.github/workflows/Test-Expand-StyleGuideCandidateArtifact.ps1` as the
   sole tracked definition of the deterministic suite.
2. Give it the same PowerShell 5.1/cross-platform and script-version contracts
   as the helper.
3. Have every required job/cell invoke that exact harness, passing the exact
   tracked production-helper path.
4. Keep edition assertions and the harness invocation in the same explicit
   `powershell` or `pwsh` process.
5. Add the harness to T1's affected-file list, all exact
   working-tree/staged-path sets and counts, validation, acceptance criteria,
   and T2's prerequisite verification.

A single nonduplicated alternative could work, but T1 must name it and prove
that all consumers use it. A separate harness is the clearest design and already
matches P1's maintainability model without creating a cross-repository runtime
dependency.

### High — T1 leaves the checkout action mutable in the write-capable workflow

T1 adopts full-SHA pinning for both artifact actions, but the current
`build.yml` also uses `actions/checkout@v4`. T1 does not prescribe a checkout
pin and explicitly says not to migrate unrelated actions. Checkout is not
unrelated here: it obtains the exact source tree, persists the credential used
for authenticated Git operations, and participates directly in the sole
write-capable job.

GitHub's secure-use reference says that a full-length commit SHA is the only
immutable way to consume an action. Leaving checkout on a movable major tag
creates an avoidable supply-chain exception in the very workflow T1 is
hardening.

Preferred correction:

1. Treat every `actions/checkout` use in the modified `build.yml` as in scope.
2. Immediately before implementation, select and verify the current approved
   checkout release and its action-distribution commit, adjacent version
   comment, Node runtime, and runner compatibility.
3. Pin each `build.yml` checkout use to that full SHA.
4. Prove the controlled writer can still perform its authenticated push and that
   credentials are cleaned up.
5. Update T1's validation and acceptance wording accordingly.

As of this review, `actions/checkout` v6.1.0 is newer than the v6.0.2 pin shown
in P1. Do not copy P1's older literal without rerunning the required
upstream-release check. Repository-wide pinning of `markdownlint.yml` and
`actions/setup-node` can be a separately stated decision; the security-sensitive
`build.yml` checkout should not be deferred as “unrelated.”

### Medium — T1 requires diagnostic context that its helper interface cannot receive

The helper accepts only the download directory, candidate directory, and
expected digest. The helper contract nevertheless requires diagnostics to record
artifact ID, run ID, and run attempt “when available,” and later requires
failures to include those values when available. T1 does not say whether the
helper reads ambient environment variables, receives caller enrichment, or
returns structured failure data for a wrapper.

That ambiguity prevents a cold implementer from satisfying and testing one
stable diagnostics contract. It also undermines the claim that T1 and P1
diagnostics are aligned, because P1 has explicit optional diagnostic parameters.

Preferred correction:

1. Add optional scalar `ArtifactId`, `RunId`, and `RunAttempt` parameters to the
   helper.
2. Define omitted values as unavailable, reject an explicitly supplied empty
   value, and never invent a label.
3. Require callers with the values to pass them explicitly.
4. Require every diagnostic and failure record to distinguish supplied labels
   from unavailable labels.
5. Add positive, omitted-label, and explicitly-empty-label harness cases.

Alternatively, T1 may explicitly assign helper-local diagnostics to the helper
and caller context to a wrapper, but then it must define how exceptions are
enriched and tested. Hidden ambient-environment coupling should not be the
unstated interface.

### Medium — T1's physical path-boundary guarantee stops at the immediate parent

T1 rejects a reparse-point download directory, its immediate parent, and the
candidate leaf/immediate parent. It does not require walking every existing
component from a trusted root. A lexically outside path can still traverse an
ancestor symbolic link or reparse point and resolve physically into the checkout
or another untrusted location.

The normal GitHub-hosted-runner design—one fresh directory directly beneath a
protected runner-temporary root with no competing writer—can make that residual
risk acceptable. T1 currently describes only a caller-created “protected
temporary parent,” however, without defining the full ancestor envelope that
makes the assumption true.

Preferred correction:

1. Choose and state one trust model:
   - accept a caller-supplied trusted temporary root, require both working
     directories to be strict descendants, and reject reparse/symbolic-link
     components throughout every existing path component; or
   - retain the three-path design but precisely require a freshly created,
     job-owned immediate child of the runner's trusted temporary root, validate
     the relevant ancestor chain, and state the no-competing-writer assumption.
2. Repeat the applicable containment and indirection checks immediately before
   opening the archive and immediately before candidate-directory creation.
3. Add an ancestor-link fixture on capable runners.
4. Describe any remaining containment guarantee accurately as lexical or
   physical; do not conflate the two.

P1's explicit `TrustedTemporaryRoot` envelope is stronger on this surface. The
cross-repository alignment decision should preserve the stronger boundary or
document why the narrower T1 model is sufficient.

## Overall disposition

T2 is ready after its prerequisite wording is updated for the final T1 contract.
T1 is close but should not be filed unchanged.

Before filing T1:

1. resolve or narrow the false P1/T1 helper-alignment claim;
2. give the permanent fixture suite one tracked, versioned owner;
3. pin checkout in the security-sensitive modified workflow;
4. define an explicit diagnostic-context interface; and
5. make the temporary-path trust envelope and ancestor-link handling explicit.

The remaining recommendations from the supplied criticism are either already
incorporated or do not create a T1/T2 defect. The embedded H1 issue titles,
T1/T2 naming, sequential ordering, repository-generic T2 guidance, and
deliberate generator-unification boundary should remain unchanged.

## Primary references

- [GitHub secure-use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [`actions/checkout` v6.1.0 release](https://github.com/actions/checkout/releases/tag/v6.1.0)
- [`actions/upload-artifact` v7.0.1 exact metadata](https://raw.githubusercontent.com/actions/upload-artifact/043fb46d1a93c77aae656e7c1c64a875d1fc6a0a/action.yml)
- [`actions/upload-artifact` v7.0.1 release](https://github.com/actions/upload-artifact/releases/tag/v7.0.1)
- [`actions/download-artifact` v8.0.1 exact metadata](https://raw.githubusercontent.com/actions/download-artifact/3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c/action.yml)
- [`actions/download-artifact` v8.0.1 exact implementation](https://raw.githubusercontent.com/actions/download-artifact/3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c/src/download-artifact.ts)
- [`actions/download-artifact` v8.0.1 release](https://github.com/actions/download-artifact/releases/tag/v8.0.1)
