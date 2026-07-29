# TerraformStyleGuide findings evaluation

## Scope and method

This document evaluates only the eight open TerraformStyleGuide findings recorded under “Findings affecting T1” and “Findings affecting T2” in `current-findings.md`. Each finding is completed in sequence: options, a finding-specific weighted rubric, scored results, and an implementation-ready selection.

## T1.1 — Writer remote preflight references the wrong PowerShell variable

### Options

1. **Leave `"$GITHUB_REF"` unchanged.** This preserves the draft but treats a GitHub environment variable as an ordinary PowerShell variable. Unless separately initialized, it is empty and makes the remote guard incorrect.
2. **Make the minimal syntax correction to `$env:GITHUB_REF`.** This makes the command executable and uses GitHub's immutable default environment variable, but the later lease and refspec still use the separately introduced `TARGET_REF`. The writer would have two names for one security-critical value.
3. **Use only `$env:TARGET_REF` in the preflight.** Define `TARGET_REF: ${{ github.ref }}` at job or step scope, validate it as a complete branch ref, and use it for `ls-remote`, the lease, and the refspec. This creates one operational value but does not cross-check it against GitHub's default `GITHUB_REF`.
4. **Hard-code `refs/heads/main`.** This is simple for the production event but prevents the production-form controlled temporary-branch evidence required by the issue and makes future default-branch changes more error-prone.
5. **Use one canonical `TARGET_REF`, cross-check it, and use it everywhere.** Define `TARGET_REF: ${{ github.ref }}` and `EXPECTED_SHA: ${{ github.sha }}` through `env`; in PowerShell require nonempty `$env:TARGET_REF`, require it to equal `$env:GITHUB_REF` using ordinal comparison, require the `refs/heads/` shape, and assign it to a local `$strTargetRef`. Use that exact local value for the parsed `ls-remote` preflight, exact lease, and full destination refspec.
6. **Move the complete writer into a new parameterized script.** Pass target ref and expected SHA as mandatory parameters, compare them to GitHub defaults, and centralize all remote operations there. This can be correct but adds another tracked implementation unit and a larger review surface than the finding requires.
7. **Derive the destination from local Git state.** Infer it from `HEAD`, `git symbolic-ref`, or the checkout's upstream. A detached Actions checkout and mutable local configuration make this less authoritative than the event payload.

Permutations considered:

- Options 2, 3, 5, and 6 can validate only a prefix or can validate prefix, equality, exact remote output shape, and expected SHA. The strict form is materially safer.
- The remote query can consume the environment variable inline or a validated local variable. A validated local variable avoids repeatedly reading security-critical process state.
- Either `GITHUB_REF` or `TARGET_REF` can be canonical. `TARGET_REF` is preferable because the existing issue already uses it for the lease/refspec and it supports controlled branch evidence without editing the command form.

### Evaluation rubric

Score each criterion from 1 (unacceptable) to 5 (excellent), then multiply by the weight and divide by 5. The maximum is 100.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Remote-mutation safety | 27 | The writer has the only write permission; targeting the wrong ref is the highest-impact failure. |
| PowerShell semantic correctness | 18 | The prescribed syntax must actually read the intended value under both supported PowerShell editions. |
| Single ref identity across preflight, lease, and refspec | 16 | A split source of truth can validate one ref and push another. |
| Rejection of missing, malformed, or contradictory state | 12 | Fail-closed validation protects against workflow drift and implementation mistakes. |
| Diagnostic precision | 8 | Operators must be able to distinguish missing ref, stale SHA, malformed output, and configuration mismatch. |
| Controlled-branch evidence compatibility | 7 | The same production command form must be testable without synthetic `main` commits. |
| Implementer clarity | 6 | A developer coming in cold should have one obvious value to validate and reuse. |
| Churn and implementation difficulty | 3 | Lower priority than correctness; small changes are useful only if they retain the safety contract. |
| Adherence to issue scope | 3 | Avoid unnecessary architecture while still fixing the full finding. |

This weighting represents repository security, DevOps reliability, maintainer diagnostics, and contributor comprehension. Churn and scope together account for only 6%.

### Scoring

| Option | Safety | PS correctness | One identity | Fail closed | Diagnostics | Branch evidence | Clarity | Churn | Scope | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Leave unchanged | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 5 | 5 | 24.8 |
| 2. `$env:GITHUB_REF` only | 4 | 5 | 2 | 3 | 3 | 5 | 4 | 5 | 5 | 75.8 |
| 3. `$env:TARGET_REF` only | 4 | 5 | 5 | 4 | 3 | 5 | 5 | 4 | 5 | 88.4 |
| 4. Hard-code `main` | 5 | 4 | 4 | 4 | 3 | 1 | 3 | 4 | 3 | 77.8 |
| 5. Canonical, cross-checked `TARGET_REF` | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 5 | **99.4** |
| 6. New parameterized writer script | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 2 | 2 | 95.2 |
| 7. Derive from local Git state | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 3 | 3 | 41.2 |

### Selected option

Select **Option 5: one canonical, cross-checked `TARGET_REF` used everywhere**.

Implementation requirements:

1. Set `TARGET_REF: ${{ github.ref }}` and `EXPECTED_SHA: ${{ github.sha }}` through workflow `env`, not by interpolating expressions directly into executable PowerShell source.
2. In the writer, copy `$env:TARGET_REF` to `$strTargetRef` and `$env:EXPECTED_SHA` to `$strExpectedSha`.
3. Require both values to be nonempty; require `$strTargetRef` to start with `refs/heads/`; and require it to equal `$env:GITHUB_REF` with ordinal comparison.
4. Resolve the checkout with `git rev-parse --verify "HEAD^{commit}"`; immediately capture `$LASTEXITCODE`, require zero and exactly one complete hexadecimal object ID, and require that full repository-native object ID to equal both `$strExpectedSha` and `$env:GITHUB_SHA`. This rejects abbreviation without hard-coding SHA-1 or SHA-256 length.
5. Run `git ls-remote --exit-code --refs origin $strTargetRef`; immediately capture `$LASTEXITCODE` and require zero.
6. Parse exactly one `<oid><TAB><ref>` result. Require the returned ref to equal `$strTargetRef` and the returned object ID to equal `$strExpectedSha`.
7. Reuse `$strTargetRef` and `$strExpectedSha` unchanged in `--force-with-lease=$strTargetRef:$strExpectedSha` and `HEAD:$strTargetRef`.
8. Preserve the existing no-fetch/no-rebase/no-retry behavior and the post-failure `ls-remote` proof.

This fixes the PowerShell error, prevents preflight/push split-brain, retains temporary-branch evidence, and does not require a new production script.

## T1.2 — The new archive helper is not explicitly exercised before merge

### Options

1. **Keep helper tests push-only.** A defective helper cannot authorize a writer because push validation blocks it, but the defect reaches `main` and breaks the post-merge pipeline before it is discovered.
2. **Use only syntax/static inspection on pull requests.** Parse the helper and inspect required strings without executing its production behavior. This catches gross syntax problems but not archive, filesystem, edition, or lifecycle defects.
3. **Run the permanent suite only in the Ubuntu pull-request job.** This proves the exact helper on PowerShell 7/Linux but leaves its declared Windows PowerShell 5.1 and Windows PowerShell 7 behavior untested before merge.
4. **Run it once under each Windows edition but not Ubuntu.** This covers the most divergent PowerShell runtime and Windows behavior, but a Linux path/filesystem regression can still merge.
5. **Run it in Ubuntu and in one designated Windows cell per edition.** For example, run it in the two LF cells and skip it in the CRLF cells because archive fixtures are independent of source EOL. This covers all supported runtime families with less repetition, but introduces conditional coverage inside an otherwise uniform matrix.
6. **Run it in the existing Ubuntu PR job and all four existing Windows PR cells.** Every PR cell invokes the exact tracked helper before generator validation. This repeats the suite twice per Windows edition but has no conditional gaps and exactly mirrors each normative cell's runtime.
7. **Add a separate three-cell cross-platform helper matrix.** Use Ubuntu/PowerShell 7, Windows/PowerShell 7, and Windows PowerShell 5.1 cells. This is cleanly separated and nonredundant, but adds a new job topology and weakens the direct claim that each existing normative cell exercised the helper.
8. **Run Ubuntu once and both Windows editions sequentially in one Windows job.** This reduces jobs but needs manual process orchestration and makes failures less naturally attributable to a matrix cell.

Permutations considered:

- The suite can run before or after source EOL fixture conversion. It should run before conversion because it validates the tracked helper and its own archive fixtures, not source-document EOL behavior.
- Pre-merge execution can replace push-time execution or complement it. Replacement is rejected: pre-merge testing detects defects, while push-time testing protects the exact production consumer and runner state.
- The PR suite can use a copied test implementation or the production helper. Only the exact tracked helper satisfies the finding.

### Evaluation rubric

Score 1–5 and normalize the weighted result to 100.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Ability to prevent a defective helper from merging | 25 | The principal usability and reliability objective is feedback before `main` is broken. |
| Coverage of all declared OS/PowerShell runtime families | 22 | The helper promises Desktop 5.1, Core on Windows, and Core on Ubuntu. |
| Fidelity to the exact production helper and fixtures | 16 | A parallel test implementation would not prove the production trust boundary. |
| Direct proof of shell/edition execution | 12 | The CI result must establish the interpreter actually used for the helper call. |
| Failure localization for contributors | 8 | A new developer should see the failing runtime/cell immediately. |
| Parity with the push consumer topology | 6 | Similar paths reduce pre-merge/post-merge surprises. |
| CI time and runner consumption | 4 | Important operationally, but deliberately lower than correctness and coverage. |
| Maintenance burden | 4 | Avoid unnecessary duplicated YAML and orchestration. |
| Scope fit | 3 | Prefer using the planned topology when it meets the safety requirement. |

The rubric gives 75% to prevention, coverage, exact-code fidelity, and edition proof. CI cost, maintenance, and scope total only 11%.

### Scoring

| Option | Prevent merge | Runtime coverage | Exact helper | Edition proof | Localization | Push parity | CI cost | Maintenance | Scope | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Push-only | 1 | 1 | 1 | 1 | 1 | 1 | 5 | 5 | 5 | 28.8 |
| 2. Static inspection only | 2 | 1 | 2 | 1 | 2 | 1 | 5 | 4 | 4 | 37.2 |
| 3. Ubuntu only | 3 | 2 | 5 | 3 | 5 | 3 | 5 | 5 | 5 | 69.6 |
| 4. Windows editions only | 4 | 4 | 5 | 5 | 4 | 4 | 4 | 4 | 5 | 86.2 |
| 5. Ubuntu + one Windows cell per edition | 5 | 5 | 5 | 5 | 4 | 4 | 5 | 4 | 5 | 96.4 |
| 6. Ubuntu + all four Windows cells | 5 | 5 | 5 | 5 | 5 | 5 | 2 | 4 | 5 | **96.8** |
| 7. Dedicated three-cell helper matrix | 5 | 5 | 5 | 5 | 5 | 3 | 4 | 3 | 3 | 94.0 |
| 8. Sequential editions in one Windows job | 5 | 5 | 5 | 4 | 3 | 3 | 4 | 3 | 4 | 89.0 |

### Selected option

Select **Option 6: execute the permanent suite in the existing Ubuntu PR job and all four existing Windows PR cells**, while retaining every push-consumer execution.

Implementation requirements:

1. In the Ubuntu PR job, after exact-SHA checkout and before generation, create a unique test root under `runner.temp`, run the permanent fixture suite against the exact tracked helper with `shell: pwsh`, assert Core edition/version, and clean up in `finally`.
2. In every Windows PR matrix cell, run the same suite before source EOL mutation:
   - Desktop cells use `shell: powershell` and assert Desktop 5.1.
   - Core cells use `shell: pwsh` and assert Core major version 7.
3. Do not create or download a production candidate on pull requests. The permanent suite itself invokes the production helper against deterministic fixture archives.
4. Do not use `continue-on-error`; a suite failure fails its PR job.
5. Preserve `fail-fast: false` so all Windows runtime/EOL results remain visible.
6. Keep the suite in every executing push consumer. Pre-merge tests are not a substitute for use-time validation.
7. Add pull-request evidence and acceptance criteria explicitly requiring successful Ubuntu, Desktop/LF, Desktop/CRLF, Core/LF, and Core/CRLF helper-suite execution.

The small duplicated fixture cost is justified because it removes conditional blind spots, gives direct per-cell evidence, and uses the topology already required by T1.

## T1.3 — Helper execution is not unambiguously bound to the assigned matrix edition

### Options

1. **Retain the current general shell prose.** Rely on implementer interpretation of “use `powershell` when Desktop” while also allowing `pwsh` for fixture work. This leaves the identified loophole.
2. **Add prose and acceptance criteria without prescribing workflow structure.** Say helper calls use the assigned edition, but allow the implementer to decide how. This improves reviewability but can still produce a step whose outer shell and helper process are hard to prove.
3. **Use a `pwsh` dispatcher step that launches `powershell.exe` or `pwsh` as a child process.** The dispatcher examines `matrix.edition`, starts the chosen executable, passes helper arguments, and checks its exit code. It can be correct but introduces a second layer of quoting, process exit handling, and diagnostics.
4. **Use two mutually exclusive, explicit-shell steps.** The Desktop step has `if: matrix.edition == 'desktop'` and `shell: powershell`; the Core step has the complementary condition and `shell: pwsh`. Each asserts its edition/version and invokes the self-test and production helper in that same process.
5. **Put the shell name in matrix data and use a dynamic `shell` expression.** This reduces duplicated YAML, but changing the current simple edition × EOL cross-product into object/include data makes it easier to create an invalid combination and less obvious to occasional contributors.
6. **Split Desktop and Core into separate jobs.** Each job can have one fixed shell and a two-value EOL matrix. This is unambiguous but duplicates complete job definitions and moves away from the required visible four-cell cross-product.
7. **Add a tracked edition-dispatch wrapper script.** The workflow always calls a wrapper, which selects and launches the requested interpreter. This centralizes behavior but adds another security-sensitive script whose own cross-edition behavior must be tested.
8. **Use a job-level or platform-default shell.** Windows defaults to PowerShell Core on GitHub-hosted runners, so this cannot establish Desktop coverage and is rejected.

Permutations considered:

- A separate self-test step and production-helper step can each be edition-specific, or one edition-specific step can invoke both in order. One step is preferable when both are applicable because the edition assertion, self-test, and production call share one process.
- Fixture construction may remain a separate `pwsh` step. It must only create inputs; it must not invoke or dot-source the production helper.
- The same structure must appear in pull-request and push Windows matrices. On pull requests, only the self-test runs; on pushes, the self-test is immediately followed by the production invocation.

### Evaluation rubric

Score 1–5 and normalize to 100.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Strength of interpreter-to-helper binding | 28 | The finding exists because generator coverage can be mistaken for helper coverage. |
| Resistance to silent shell fallback or dispatcher error | 18 | CI must fail rather than quietly exercise only Core. |
| Runtime proof in the same process | 15 | `$PSVersionTable` evidence is useful only when it describes the process invoking the helper. |
| Review and log clarity | 12 | Maintainers should identify the edition and failure without reconstructing dispatch logic. |
| Resistance to future workflow drift | 8 | Shell choice and helper call should change together in review. |
| Applicability to both PR and push matrices | 8 | The contract must be uniform across pre-merge and use-time validation. |
| Maintenance and duplication | 5 | Worth considering, but secondary to actual edition proof. |
| Scope fit | 3 | Avoid a new wrapper or topology unless needed. |
| GitHub Actions portability | 3 | Prefer ordinary supported workflow constructs. |

Interpreter evidence, fail-closed behavior, same-process proof, and review clarity account for 73%.

### Scoring

| Option | Binding | No fallback | Same-process proof | Clarity | Drift resistance | PR/push | Maintenance | Scope | Portability | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Current prose | 1 | 1 | 1 | 1 | 1 | 1 | 5 | 5 | 5 | 28.8 |
| 2. Stronger prose only | 2 | 1 | 2 | 3 | 2 | 2 | 5 | 5 | 5 | 45.4 |
| 3. `pwsh` dispatcher | 5 | 4 | 5 | 3 | 3 | 5 | 3 | 3 | 4 | 84.6 |
| 4. Two explicit-shell steps | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 5 | 5 | **99.0** |
| 5. Dynamic matrix shell | 5 | 4 | 5 | 4 | 4 | 5 | 5 | 4 | 4 | 91.2 |
| 6. Separate jobs | 5 | 5 | 5 | 5 | 4 | 5 | 2 | 2 | 2 | 91.8 |
| 7. Tracked dispatch wrapper | 5 | 4 | 5 | 3 | 3 | 5 | 2 | 2 | 2 | 81.8 |
| 8. Default shell | 1 | 1 | 1 | 2 | 1 | 1 | 5 | 4 | 4 | 30.0 |

### Selected option

Select **Option 4: two mutually exclusive explicit-shell steps**.

For every Windows matrix job:

1. Edition-neutral fixture construction and raw-byte inspection may be separate `shell: pwsh` steps.
2. Add a Desktop helper step with:
   - `if: ${{ matrix.edition == 'desktop' }}`;
   - `shell: powershell`;
   - an assertion that `$PSVersionTable.PSEdition -eq 'Desktop'` and the version is exactly 5.1;
   - the permanent self-test invocation;
   - on push only, the production helper invocation with the propagated digest.
3. Add a Core helper step with:
   - `if: ${{ matrix.edition == 'core' }}`;
   - `shell: pwsh`;
   - an assertion that `$PSVersionTable.PSEdition -eq 'Core'` and the major version is 7;
   - the same self-test and, on push, production invocation.
4. Each helper step starts with `$ErrorActionPreference = 'Stop'`, defines all paths it consumes, and cleans its self-test root in `finally`.
5. No `pwsh` fixture-preparation or inspection step may dot-source, call, or launch `Expand-StyleGuideCandidateArtifact.ps1`.
6. The normative generator run and lone-CR probe remain similarly bound to the assigned edition.
7. Evidence and acceptance text must say that the edition assertion and helper invocation occur in the same step/process.

This is intentionally a little repetitive: the repetition makes the security claim visible in YAML and Actions logs.

## T1.4 — The helper's checkout boundary and exhaustive enumeration need an implementation contract

### Options

1. **Leave the root and enumeration method implementation-defined.** The issue continues to require “outside” and “exactly,” but compatible-looking implementations can use the current directory, omit hidden files, or miss a dangling leaf.
2. **Add a mandatory `CheckoutRoot` parameter and require exhaustive enumeration.** The caller passes `$env:GITHUB_WORKSPACE`; the helper canonicalizes it, cross-checks that its own tracked path is beneath it, uses `.NET` entry enumeration, and rejects any preexisting candidate-leaf entry. This is explicit but expands the public interface and lets a non-CI caller supply the trust boundary.
3. **Derive the trusted root from the helper's fixed tracked location and use exhaustive .NET enumeration.** Resolve the filesystem path corresponding to `$PSScriptRoot/../..`, verify that the helper is at `.github/workflows/Expand-StyleGuideCandidateArtifact.ps1` under that root, and use that root for separator-aware containment checks. Use `Directory.EnumerateFileSystemEntries` for exact entry sets and parent enumeration for leaf absence.
4. **Use `$env:GITHUB_WORKSPACE` and `Get-ChildItem -LiteralPath -Force`.** This is natural in Actions and includes hidden items, but makes the production helper dependent on runner-specific process state and complicates local/self-test invocation.
5. **Run `git rev-parse --show-toplevel` inside the helper.** This discovers the checkout but depends on current working directory/repository context, adds a native command to a filesystem helper, and can consult mutable Git configuration rather than the helper's own location.
6. **Use only `Path.GetFullPath`, string prefixes, and `Test-Path`.** This is small and cross-version, but a naive prefix accepts siblings such as `repo-other`, and existence APIs can miss a dangling final link.
7. **Create a separate path-safety module shared by the helper and workflow.** Centralize canonicalization, OS-aware comparison, enumeration, and link checks. This is reusable but creates another production dependency and a larger scope than one helper requires.
8. **Use OS-specific native canonicalization and link APIs.** Call Windows handle/final-path APIs and POSIX `realpath`/`lstat` equivalents. This can model physical paths deeply but is difficult to implement and test in Windows PowerShell 5.1, and the protected runner-temporary-parent model does not require a full filesystem security library.

Important permutations:

- **Root source:** explicit parameter, `GITHUB_WORKSPACE`, Git discovery, or fixed helper location.
- **Enumeration:** plain `Get-ChildItem` (rejected), `Get-ChildItem -LiteralPath -Force`, or `.NET` filesystem-entry enumeration.
- **Leaf absence:** `Test-Path` only (rejected), or enumerate the existing parent and compare the final leaf using filesystem-appropriate case rules.
- **Containment:** naive prefix (rejected), or equal-root/descendant comparison with a trailing directory-separator boundary and OS-appropriate ordinal comparison.

### Evaluation rubric

Score 1–5 and normalize to 100.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Correct checkout trust boundary | 25 | A wrong root invalidates every “outside checkout” assurance. |
| Detection of all entry types, including hidden and dangling links | 22 | Archive and destination exactness must describe actual directory entries, not a filtered view. |
| Windows PowerShell 5.1 / PowerShell 7 portability | 16 | The helper's declared contract spans .NET Framework and modern .NET on two OS families. |
| Independence from caller working directory and mutable process state | 12 | The same inputs should produce the same boundary decision in CI and self-tests. |
| Preservation of fresh-destination lifecycle | 8 | A preexisting leaf must never be reused or followed. |
| Testability and diagnostics | 7 | Fixtures must be able to prove hidden-extra, sibling-prefix, reparse, and dangling-leaf rejection. |
| Implementer comprehensibility | 5 | Security-sensitive path logic needs a concrete, reviewable recipe. |
| Churn/difficulty | 3 | Kept low relative to correctness. |
| Scope fit | 2 | Avoid a general-purpose path library when a local contract suffices. |

Trust-boundary correctness, exhaustive enumeration, portability, and caller independence account for 75%.

### Scoring

| Option | Boundary | All entries | Portability | Independence | Lifecycle | Tests/diagnostics | Clarity | Churn | Scope | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Implementation-defined | 1 | 1 | 3 | 1 | 1 | 1 | 1 | 5 | 5 | 30.4 |
| 2. `CheckoutRoot` parameter | 4 | 5 | 5 | 3 | 5 | 5 | 4 | 3 | 4 | 87.6 |
| 3. Fixed-location root + .NET enumeration | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 4 | 5 | **98.4** |
| 4. `GITHUB_WORKSPACE` + `Get-ChildItem -Force` | 4 | 4 | 5 | 4 | 4 | 3 | 4 | 5 | 5 | 82.8 |
| 5. `git rev-parse` + exhaustive enumeration | 3 | 5 | 4 | 2 | 5 | 4 | 3 | 3 | 3 | 74.2 |
| 6. Lexical prefix + `Test-Path` | 1 | 1 | 5 | 4 | 1 | 2 | 4 | 5 | 5 | 48.4 |
| 7. Separate path-safety module | 5 | 5 | 5 | 5 | 5 | 5 | 3 | 1 | 1 | 94.0 |
| 8. OS-specific native APIs | 5 | 5 | 3 | 5 | 5 | 4 | 2 | 1 | 1 | 85.2 |

### Selected option

Select **Option 3: derive the root from the tracked helper's fixed location and use exhaustive .NET enumeration**.

Implementation requirements:

1. Keep the existing three-parameter interface. Do not trust the process working directory or add a caller-selected boundary.
2. At startup, resolve the helper's actual filesystem path and derive the checkout root as two parents above `$PSScriptRoot`. Verify the expected relative helper path beneath that root; fail if the tracked-location invariant is false.
3. Convert every caller-supplied PowerShell path to an absolute filesystem provider path before using .NET. Do not pass unresolved relative paths to `Path.GetFullPath`.
4. Implement one separator-aware descendant test:
   - use `StringComparison.OrdinalIgnoreCase` on Windows;
   - use `StringComparison.Ordinal` on non-Windows;
   - compare either equality or a root string ending in a directory separator, so sibling prefixes do not pass.
5. Require the download directory and the candidate parent to be outside the checkout. Require each existing parent to be an ordinary directory rather than a reparse point.
6. Materialize `Directory.EnumerateFileSystemEntries($strDownloadDirectory)` once and require exactly one entry. Check its attributes and require a regular, non-reparse-point file.
7. To prove candidate-leaf absence, enumerate its existing parent and compare every returned leaf name using OS-appropriate filesystem comparison. Reject any matching entry even if `File.Exists`, `Directory.Exists`, or `Test-Path` would report false because it is a dangling link.
8. Repeat the parent enumeration immediately before creating the leaf. Create it once; never delete/recreate or reuse it.
9. Use the same exhaustive enumeration after extraction to require exactly the four expected ordinary files.
10. Extend the permanent suite with at least:
    - a hidden extra entry in the download directory;
    - a checkout-sibling prefix path that must not be classified as inside the checkout;
    - an existing candidate leaf;
    - a reparse-point/symlink candidate leaf;
    - a dangling candidate-leaf link where the runner permits creating it.
11. If a runner cannot create a required link fixture, fail or explicitly record a narrowly justified platform skip; do not silently count an unexecuted case as passing.

This preserves the simple caller interface while making every boundary and exact-count assertion implementable and testable.

## T1.5 — Both successful fixture cases are not classified explicitly

### Options

1. **Keep the singular “valid fixture” wording.** Depend on the list item's phrase “must still extract” to communicate the second success outcome. This remains internally ambiguous.
2. **Change only “the valid fixture” to “each valid fixture.”** This is a useful grammatical repair but still forces an implementer to infer which list items are positive, what each must prove, and which postconditions differ.
3. **Add an explicit fixture outcome table.** Give every fixture a stable case name, classify it as success or rejection, state the required failure phase where applicable, and state exact destination postconditions.
4. **Define positive and negative fixture arrays in the implementation guidance.** Require the harness to iterate data records with expected outcomes. This is implementable, but without a human-readable issue table it makes the contract dependent on code structure not yet written.
5. **Create separate positive- and negative-fixture scripts/files.** This is auditable but adds tracked test artifacts and file-management overhead for a suite that can remain inside the workflow/helper test harness.
6. **Reclassify symlink-like external attributes as invalid.** Reject the archive. This simplifies the oracle but contradicts the extraction design: metadata is intentionally ignored while permitted bytes are copied into new ordinary files.
7. **Remove the external-attributes fixture.** Avoid the ambiguity by dropping the case. That loses evidence that the helper does not restore attacker-controlled ZIP metadata.

Permutations considered:

- The outcome table can group negative fixtures by common postcondition while retaining a row for each case and its diagnostic identifier.
- The metadata-ignored positive case can modify one or all expected entries. One modified entry is sufficient to exercise the behavior; post-extraction inspection must cover all four destination files.
- The table and data-driven harness can be combined. The table is the normative issue contract; implementation arrays are an allowed realization.

### Evaluation rubric

Score 1–5 and normalize to 100.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Correctness and completeness of the test oracle | 25 | A fixture without an explicit expected result is not a reliable test specification. |
| Preservation of the intended archive-metadata security model | 20 | The helper must ignore metadata while creating ordinary files, not restore or reflexively reject it. |
| Resistance to false passes or inverted expectations | 16 | Ambiguous classification can make the suite accept the wrong behavior. |
| Clarity for an implementer coming in cold | 14 | Case names, phases, and postconditions should be directly translatable into tests. |
| Diagnostic and maintenance quality | 10 | Stable case identifiers make cross-platform failures actionable. |
| Cross-runtime determinism | 6 | Every edition/OS must apply the same outcome oracle. |
| Audit traceability | 5 | Reviewers should map every acceptance bullet to a concrete fixture. |
| Churn/difficulty | 2 | Very low weight because clarity is worth a few lines. |
| Scope fit | 2 | Avoid unnecessary test-file architecture. |

Oracle correctness, the security model, false-pass resistance, and implementer clarity account for 75%.

### Scoring

| Option | Oracle | Security model | False-pass resistance | Clarity | Diagnostics | Determinism | Audit | Churn | Scope | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Keep singular wording | 1 | 3 | 1 | 2 | 2 | 3 | 1 | 5 | 5 | 38.4 |
| 2. Plural wording only | 3 | 5 | 3 | 4 | 3 | 5 | 3 | 5 | 5 | 74.8 |
| 3. Explicit outcome table | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 5 | **99.6** |
| 4. Positive/negative implementation arrays | 5 | 5 | 5 | 4 | 5 | 5 | 4 | 4 | 4 | 95.4 |
| 5. Separate fixture files/scripts | 5 | 5 | 5 | 4 | 5 | 5 | 5 | 1 | 1 | 94.0 |
| 6. Reject external attributes | 2 | 1 | 4 | 4 | 4 | 5 | 3 | 5 | 2 | 57.8 |
| 7. Remove metadata fixture | 1 | 1 | 2 | 4 | 3 | 5 | 2 | 5 | 3 | 43.8 |

### Selected option

Select **Option 3: add a normative fixture outcome table**, and permit a data-driven harness that mirrors it.

The table must include at least these classifications:

| Fixture class | Expected result | Required phase/postcondition |
| --- | --- | --- |
| Exact valid archive + correct digest | Success | Extract exactly four ordinary, non-reparse files with expected bytes. |
| Exact valid archive + symlink-like external attributes | Success | Extract exactly four ordinary, non-reparse files; restore no link/type/mode/timestamp metadata. |
| Correct archive + altered well-formed digest | Reject | Fail before opening the ZIP and before destination creation. |
| Missing, extra, duplicate, case collision, nested, traversal, absolute, drive-qualified, directory, file/directory collision, or empty-name entry | Reject | Fail after ZIP open but before destination creation or entry extraction. |
| Invalid or truncated ZIP | Reject | Fail during ZIP open/read before destination creation. |
| Hidden extra download-directory entry | Reject | Fail before selecting/opening an archive. |
| Existing, reparse-point, symlink, or dangling candidate leaf | Reject | Fail before ZIP extraction; never reuse or follow the leaf. |

For every case:

1. Use a stable diagnostic case identifier.
2. Compute the actual fixture digest except in the deliberate digest-mismatch case.
3. Assert success or failure explicitly; a thrown exception alone is not a complete negative-test oracle.
4. For every rejection, assert the candidate leaf remains absent and no path outside the fixture root changed.
5. For each success, inspect exact path set, file kind, bytes, BOM/CR policy, and absence of restored metadata.
6. Clean all fixture state in `finally`.

This eliminates the wording ambiguity and makes the metadata-ignored behavior a deliberate positive security test.

## T2.1 — Every destination preflight misses a dangling final symlink

### Options

1. **Retain `[ -e "$PATH" ]` alone.** This detects resolvable existing objects but follows the final link and therefore misses a dangling symlink.
2. **Reject either a resolvable object or a final symlink with `-e || -L`.** Apply `[ -e "$PATH" ] || [ -L "$PATH" ]` to every `RECOVERY_PATH` and `TFC_RESPONSE_PATH` preflight.
3. **Use `-e || -h`.** POSIX defines `-h` and `-L` equivalently for this purpose. It is correct, but `-L` communicates “link” more directly and matches the primary-source wording used in the issue.
4. **Inspect with `readlink` or `realpath`.** Attempt to resolve the destination and infer whether it is a link. Tool availability and behavior for nonexistent targets differ, and parsing adds complexity unnecessary for the final component.
5. **Parse `ls -ld` output.** Human-oriented output, locale, escaping, and aliases make this unsuitable for a copy-safe security guard.
6. **Rely only on provider-native no-clobber options.** Azure and GCS have useful native protections, but AWS lacks the needed flag and HCP's curl flow has different behavior. It also does not give one consistent diagnostic before network access.
7. **Atomically reserve every recovery path before calling the provider command.** This would detect all preexisting entries, but AWS/Azure/GCS commands expect to own/open the pathname and have inconsistent behavior when an empty reservation already exists.
8. **Rely solely on a protected parent/no-competing-writer assumption.** This narrows likelihood but leaves an operator-created dangling link undetected and contradicts the stated fresh-path check.

Permutations considered:

- `-L` can replace `-e` or supplement it. It must supplement it because ordinary existing files and directories are not links.
- The two tests can use deprecated/ambiguous `-o` inside one `[` expression or shell `||` between two simple tests. Use shell `||`; it is clearer and avoids `test` expression-precedence pitfalls.
- The guard can be applied only to provider recovery paths or to those plus the HCP response page. Apply it uniformly to all final output paths.

### Evaluation rubric

Score 1–5 and normalize to 100.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Detection of every final-leaf state | 26 | The guard must catch files, directories, resolvable links, and dangling links. |
| Prevention of unintended target writes | 22 | A followed link can redirect sensitive state to an unintended path. |
| POSIX/Bash portability | 16 | The examples promise POSIX-style Bash paths and should use standard primitives. |
| Copy-paste clarity | 11 | Operators must understand exactly why execution was refused. |
| Uniform applicability across providers | 9 | One common contract reduces provider-specific mistakes. |
| Diagnostic quality | 6 | The error should name the exact refused destination before network access. |
| Compatibility with native provider behavior | 5 | The preflight should compose with existing Azure/GCS no-clobber defenses and AWS output handling. |
| Churn/difficulty | 3 | Kept low; a small fix is valuable because it is complete. |
| Scope fit | 2 | Do not create a general path-management framework. |

Detection, write prevention, and portability account for 64%; churn and scope only 5%.

### Scoring

| Option | All states | Prevent redirect | Portable | Copy-safe | Uniform | Diagnostics | Provider compatibility | Churn | Scope | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. `-e` only | 1 | 1 | 5 | 2 | 1 | 2 | 5 | 5 | 5 | 44.2 |
| 2. `-e \|\| -L` | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| 3. `-e \|\| -h` | 5 | 5 | 5 | 4 | 5 | 5 | 5 | 5 | 5 | 97.8 |
| 4. `readlink`/`realpath` | 4 | 4 | 3 | 2 | 4 | 3 | 3 | 2 | 3 | 68.6 |
| 5. Parse `ls` | 2 | 2 | 3 | 1 | 3 | 2 | 3 | 3 | 2 | 44.4 |
| 6. Native no-clobber only | 3 | 4 | 5 | 3 | 1 | 3 | 3 | 3 | 4 | 67.6 |
| 7. Reserve all paths first | 5 | 5 | 2 | 2 | 1 | 3 | 1 | 1 | 1 | 66.2 |
| 8. Protected-parent assumption only | 1 | 3 | 5 | 4 | 5 | 2 | 5 | 5 | 5 | 64.6 |

### Selected option

Select **Option 2: use `[ -e "$path" ] || [ -L "$path" ]` uniformly**.

Implementation requirements:

1. In the AWS, Azure, and GCS recovery blocks, replace the current preflight with:

   ```sh
   if [ -e "$RECOVERY_PATH" ] || [ -L "$RECOVERY_PATH" ]; then
     printf 'Refusing to overwrite or follow an existing recovery destination: %s\n' \
       "$RECOVERY_PATH" >&2
     exit 1
   fi
   ```

2. Apply the identical predicate to `TFC_RESPONSE_PATH`, with an HCP-response-specific message.
3. Keep the absolute POSIX path check and `umask 077`.
4. Keep Azure's `--overwrite false` and GCS's `--no-clobber` as provider-native defense in depth.
5. Retain AWS's documented protected-parent/no-competing-writer limitation because its preflight and output open remain non-atomic.
6. Treat parent-directory symlink topology as the operator's responsibility, as already scoped; explicitly distinguish that non-goal from the now-guarded final leaf.
7. Add validation cases for an ordinary existing file, directory, valid symlink, and dangling symlink at each generic path shape. Every case must fail before the provider command is invoked.

This is the only option that is complete, portable, uniform, and minimally invasive.

## T2.2 — HCP response-file creation does not match the stated no-overwrite assurance

### Options

1. **Keep the preflight plus `curl --output` and disclose the race.** This makes the prose accurate but leaves curl able to truncate an exact path created between preflight and open.
2. **Add curl `--no-clobber`.** Curl chooses a numbered alternate filename when the requested name exists. That violates the exact `TFC_RESPONSE_PATH` contract and can cause an operator to inspect the wrong page file.
3. **Open the exact response path through a Bash noclobber file descriptor, then stream curl stdout to it.** After variable/path prevalidation and `-e || -L`, enable `set -C`, run `exec 3> "$TFC_RESPONSE_PATH"`, disable noclobber, invoke curl without `--output` and with `>&3`, capture curl's status, close descriptor 3, and report any empty/partial file on failure.
4. **Use direct noclobber redirection on the curl command.** `curl ... > "$TFC_RESPONSE_PATH"` under `set -C` is shorter, but it combines path-open failures, shell expansion failures, and curl failures into one command and makes diagnostics/descriptor closure less explicit.
5. **Download to a protected temporary file and publish with `mv -n`.** This avoids a partial final file but `mv -n` is not POSIX, can have platform-specific replacement semantics, and does not give a universally atomic “exact destination or fail” guarantee.
6. **Use `mktemp` and make its generated pathname the response path.** This provides fresh secure creation but abandons the operator-selected `TFC_RESPONSE_PATH`, complicates pagination bookkeeping, and adds another command dependency.
7. **Use Python or another helper to call `open(..., O_CREAT|O_EXCL)` and pass a descriptor.** This can be robust but adds a runtime dependency and substantially reduces copy-paste accessibility for a shell example.
8. **Precreate a mode-600 file, then pass it to `curl --output`.** This reserves the name but curl reopens/truncates the pathname; it loses descriptor identity and remains vulnerable to replacement by a competing parent-directory writer.

Permutations considered:

- The example can automatically remove a partial response on curl failure or retain it. Automatic deletion risks unlinking a replaced path and prescribes sensitive-data deletion behavior. Retain the protected partial/empty file, emit a warning, and require a fresh path for retry.
- Curl can use `--output` or stdout. Stdout is required when the shell owns the already-open exact descriptor.
- Noclobber can remain enabled throughout the subshell or be disabled immediately after descriptor acquisition. Disable it after the exact open so it does not have surprising effects on unrelated later redirections.

### Evaluation rubric

Score 1–5 and normalize to 100.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Exact-path create-or-fail behavior | 25 | The operator must know which file contains the requested page; alternate names are unsafe. |
| Confidential file creation and permissions | 18 | Response pages contain state download URLs and must begin life under `umask 077`. |
| Failure and partial-file semantics | 15 | HTTP/network failure must not be mistaken for a valid response or silently erase evidence. |
| Preservation of token secrecy | 12 | The bearer token must remain off the argument list and ordinary output. |
| Link/race behavior within the documented threat model | 10 | The design must reject existing links and state the protected-parent assumption honestly. |
| Portability and dependency availability | 8 | The example should work in the declared Bash/curl environment without an extra language runtime. |
| Copy-paste usability | 6 | Operators need a sequence they can safely execute and understand. |
| Diagnostic quality | 3 | Distinguish refusal to create, curl failure, and success. |
| Churn/difficulty | 2 | Low weight; a few shell lines are justified by exactness. |
| Scope fit | 1 | Avoid a general download utility. |

Exact creation, confidentiality, failure semantics, token secrecy, and race behavior account for 80%.

### Scoring

| Option | Exact path | Confidentiality | Failure semantics | Token secrecy | Link/race model | Portability | Copy-safe | Diagnostics | Churn | Scope | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Keep and disclose | 2 | 4 | 2 | 5 | 2 | 5 | 4 | 3 | 5 | 5 | 64.0 |
| 2. curl `--no-clobber` | 1 | 5 | 3 | 5 | 4 | 3 | 2 | 3 | 5 | 5 | 64.0 |
| 3. Noclobber descriptor + curl stdout | 5 | 5 | 5 | 5 | 4 | 5 | 5 | 5 | 4 | 5 | **97.6** |
| 4. Direct noclobber redirection | 5 | 5 | 4 | 5 | 4 | 5 | 4 | 4 | 5 | 5 | 93.2 |
| 5. Temporary file + `mv -n` | 3 | 5 | 5 | 5 | 3 | 2 | 3 | 3 | 2 | 3 | 76.0 |
| 6. Generated `mktemp` path | 2 | 5 | 5 | 5 | 5 | 3 | 2 | 4 | 3 | 2 | 76.2 |
| 7. Python `O_EXCL` helper | 5 | 5 | 5 | 5 | 5 | 2 | 2 | 3 | 1 | 1 | 88.0 |
| 8. Precreate, then `curl --output` | 3 | 5 | 3 | 5 | 2 | 5 | 3 | 3 | 3 | 4 | 73.4 |

### Selected option

Select **Option 3: acquire the exact output through a Bash noclobber descriptor and stream curl stdout to it**.

The HCP block must follow this order:

1. Enter a subshell and set `umask 077`.
2. Guard and assign every required variable before creating the response file:
   - `TFC_RESPONSE_PATH`;
   - `TFC_TOKEN`;
   - organization name;
   - workspace name;
   - page number default.
3. Validate the absolute path and reject `[ -e "$TFC_RESPONSE_PATH" ] || [ -L "$TFC_RESPONSE_PATH" ]`.
4. Enable noclobber and acquire descriptor 3:

   ```bash
   set -C
   exec 3> "$TFC_RESPONSE_PATH" || {
     printf 'Unable to create new HCP response file without overwriting: %s\n' \
       "$TFC_RESPONSE_PATH" >&2
     exit 1
   }
   set +C
   ```

5. Invoke `curl -q --config - ...` without `--output`; preserve the here-document on standard input and direct only the response body to descriptor 3 with `>&3`.
6. Immediately save curl's exit status, then close descriptor 3 with `exec 3>&-`.
7. If curl failed, report its exact exit code and state that the protected path may contain an empty or partial response, must not be treated as valid, and must be handled under retention/deletion policy before a retry uses a new path. Exit with curl's status.
8. On success, state that the exact requested path contains the response page and should be inspected only with a trusted local JSON viewer.
9. Explain that noclobber descriptor creation plus the link preflight protects the final name under the required protected-parent/no-competing-writer model. Do not claim safety against a process that can unlink/replace entries in that parent.
10. Explicitly explain why curl `--no-clobber` is not used: it can write a numbered alternate name.

This is exact, dependency-light, token-safe, and honest about both partial files and parent-directory trust.

## T2.3 — Post-merge evidence contradicts the no-drift writer skip

### Options

1. **Keep “every push consumer” in the evidence.** Treat the skipped writer's successful check status as if its steps ran. This is factually false.
2. **Change only the one numbered evidence item to “every Windows push cell.”** This fixes the immediate contradiction, but broad “every push consumer on every run” wording elsewhere in T2/T1 can still recreate it.
3. **Define “consumer” to mean only a job when it executes.** Say every executing consumer runs the helper. Logically defensible, but easy for readers to misinterpret when adjacent text says “every run.”
4. **Make the write-enabled synchronization job run on no-drift pushes.** Always download/self-test/extract, then condition only mutation steps. This would make the evidence true but unnecessarily activates the sole write-permission job when no write is needed.
5. **Split synchronization validation and mutation into separate jobs.** Always run a read-only writer-validation job and condition a write-only mutation job. This is strong architecture but materially redesigns T1 for a T2 evidence wording problem.
6. **Remove helper/writer statements from T2 post-merge evidence.** Limit T2 to content generation and no drift. This avoids contradiction but loses useful proof that the inherited matrix transport still worked.
7. **State two precise execution branches.** Require all four Windows push cells to self-test and invoke the helper on every push candidate; require the synchronization job to do so only when `has_changes=true`; for T2's expected no-drift merge, require the writer to be skipped and cite T1's controlled write-path/static evidence.
8. **Refer only to T1 by dependency link.** Say T1 establishes all workflow behavior and omit T2-specific runtime expectations. Concise, but insufficiently actionable when collecting post-merge evidence.

Permutations considered:

- The wording must be corrected in prerequisite verification, post-merge evidence, and acceptance criteria—not just one numbered line.
- A no-drift run can prove the writer is correctly skipped, not that its internals ran.
- T1 controlled evidence proves the `has_changes=true` branch; T2 post-merge evidence proves the `has_changes=false` branch. Together they cover the conditional topology without synthetic drift.

### Evaluation rubric

Score 1–5 and normalize to 100.

| Criterion | Weight | Why it matters |
| --- | ---: | --- |
| Factual correspondence between prose and executed jobs | 28 | Evidence language must describe steps that actually ran. |
| Integrity of security and release evidence | 20 | False claims weaken confidence in the sole writer's controls. |
| Consistency between T1 prerequisite and T2 inherited behavior | 15 | The two sequential issues must describe the same conditional topology. |
| Clarity for operators collecting evidence | 13 | A person after merge needs an exact pass/skip checklist. |
| Preservation of least privilege | 10 | No-drift runs should not activate a write-permission job merely to satisfy prose. |
| Auditability of both conditional branches | 7 | Controlled T1 evidence and ordinary T2 evidence should cover complementary paths. |
| Maintenance quality | 4 | Precise terminology should remain correct as content issues are added. |
| Churn/difficulty | 2 | Wording changes are cheap, but low weight prevents architecture decisions based on churn. |
| Scope fit | 1 | Avoid redesigning T1 solely for evidence phrasing. |

Factual accuracy, evidence integrity, cross-issue consistency, and operator clarity account for 76%.

### Scoring

| Option | Factual | Evidence integrity | T1/T2 consistency | Operator clarity | Least privilege | Both branches auditable | Maintenance | Churn | Scope | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Keep wording | 1 | 1 | 1 | 1 | 3 | 1 | 4 | 5 | 5 | 28.8 |
| 2. Fix one line only | 4 | 4 | 3 | 4 | 5 | 4 | 5 | 5 | 5 | 80.4 |
| 3. “Executing consumer” definition | 4 | 4 | 4 | 3 | 5 | 3 | 4 | 5 | 5 | 78.6 |
| 4. Always run writer | 5 | 3 | 5 | 5 | 2 | 5 | 3 | 1 | 1 | 82.0 |
| 5. Split validation/write jobs | 5 | 5 | 5 | 5 | 5 | 5 | 3 | 1 | 1 | 96.0 |
| 6. Remove helper evidence | 5 | 3 | 3 | 3 | 5 | 2 | 5 | 5 | 4 | 76.4 |
| 7. Precise two-branch semantics | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| 8. Dependency reference only | 4 | 4 | 4 | 3 | 5 | 3 | 5 | 5 | 4 | 79.2 |

### Selected option

Select **Option 7: define and evidence the two conditional execution branches precisely**.

Apply this terminology throughout T1 and T2:

1. **Windows push cells:** every one of the four cells downloads the candidate, runs the permanent suite, and invokes the production helper on every push pipeline.
2. **Synchronization job:** it is the only push consumer with `contents: write`; it runs only when approval reports `has_changes=true`. Whenever it runs, it downloads the same candidate, runs the permanent suite, invokes the production helper, proves identity, and performs the exact-lease write.
3. **No-drift branch:** when `has_changes=false`, approval succeeds and the synchronization job is expected to be `skipped`; none of its steps executed.
4. **Evidence allocation:**
   - T1's controlled synchronization drill proves the writer's `has_changes=true` helper and write path.
   - T1/T2 ordinary no-drift post-merge runs prove all four read-only Windows cells and the expected writer skip.
   - Static inspection confirms the writer still invokes the same tracked helper before any copy or mutation.
5. In T2 post-merge evidence, replace “Every push consumer” with “Every Windows push cell.”
6. Retain the explanatory paragraph that the skipped writer's integration is inherited from T1's controlled evidence; make it part of the numbered evidence rather than a potential contradiction.
7. Require the UI/result evidence to distinguish `success` for the four cells from `skipped` for synchronization.

This makes the evidence truthful without weakening least privilege or manufacturing a write-enabled no-op job.
