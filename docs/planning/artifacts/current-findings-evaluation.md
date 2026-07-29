# Current findings evaluation

## Scope and process

This evaluation covers only the nine open TerraformStyleGuide findings recorded
under `## Independent T1/T2 review` in
`docs/planning/artifacts/current-findings.md`. The supplied P1/P2 criticism is
context only; P1 and P2 are not revision targets.

The findings will be evaluated sequentially in this order:

1. T1-1 — bind digest verification and ZIP processing to the same file identity.
2. T1-2 — replace the contradictory global rejection oracle with truthful
   per-case outcomes.
3. T2-1 — recheck the alleged AWS KMS documentation conflict against the
   operation- and bucket-class-specific source text.
4. T2-2 — prevent inherited Bash xtrace from exposing the HCP token.
5. T1/T2-1 — track the current Markdown-tooling advisories without silently
   expanding either issue.
6. T1-3 — correct or justify the dated GitHub Actions pins.
7. T2-3 — state the actual S3 Versioning prerequisite for historical recovery.
8. T1-4 — verify the claimed local PowerShell edition in the same child process.
9. T2-4 — make the prerequisite-file non-goal complete.

For each finding, this file will contain a comprehensive option set, a unique
weighted rubric, the applied scoring table, and an implementation-ready
selection before evaluation proceeds to the next finding.

## Finding T1-1 — Bind digest verification and ZIP processing to one file identity

### Options

The design must work in both Windows PowerShell 5.1 and PowerShell 7, preserve
the current fail-closed path envelope, and ensure that the bytes inspected as a
ZIP are the bytes whose SHA-256 matched the upload action's digest.

1. **Retain path hashing and path reopening, with more path checks.** Continue
   using `Get-FileHash -LiteralPath`, repeat component and containment checks
   before opening the ZIP, and rely on the job-owned/no-competing-writer model.
   This is operationally simple but never establishes object identity across
   the two opens.
2. **Retain two opens but compare filesystem identity metadata.** Record
   length, timestamps, and a native file identifier around both operations and
   reject any difference. Strong variants would use a Windows file ID and a
   POSIX device/inode pair; weaker variants would use only portable metadata.
   This can be layered on option 1 but adds platform-specific interop and still
   leaves ambiguity on filesystems with weak or synthetic identifiers.
3. **Read the whole archive into a `MemoryStream`.** Open the retained file,
   copy all bytes to memory, close the source, then hash, rewind, and construct
   `ZipArchive` over the same `MemoryStream`. This gives exact byte identity and
   excellent test isolation, but archive size becomes process-memory pressure
   and duplicates the complete payload.
4. **Stream into a second protected staging file while hashing.** Create a new
   ordinary file below the trusted root, copy source bytes while calculating
   SHA-256, keep the destination handle open, rewind it, and process that same
   handle as the ZIP. This creates a stable verified copy without unbounded
   memory, but adds a second sensitive lifecycle, more cleanup cases, and
   another disk write. Closing and reopening the staging path would recreate
   the original problem and is therefore not an acceptable permutation.
5. **Open the retained archive once with `FileShare.None`.** Use
   `FileMode.Open`, `FileAccess.Read`, and `FileShare.None`; hash the stream,
   require one matching result, rewind it, and build the read-only `ZipArchive`
   over that same stream. This maximizes ordinary sharing exclusion but can
   cause avoidable failures when security scanners, indexers, or other readers
   already hold compatible handles.
6. **Open the retained archive once with `FileShare.Read`.** Use
   `FileMode.Open`, `FileAccess.Read`, and `FileShare.Read`; hash, rewind, and
   process the same continuously held stream. Other readers remain possible,
   but a later ordinary open for writing or deletion is denied by the selected
   sharing contract on platforms that enforce it. Preserve repeated path
   checks before the one open and keep the no-competing-writer residual model.
7. **Open once while permitting delete sharing.** Use a sharing permutation
   such as `FileShare.Read -bor FileShare.Delete` to reduce interference with
   cleanup software. The held handle still identifies bytes on many systems,
   but permitting rename/deletion makes the security story harder to state and
   differs across filesystems and runtimes.
8. **Replace `Get-FileHash` with an incremental hashing wrapper over ZIP reads.**
   Allow `ZipArchive` to consume a stream through a hashing decorator and
   validate the digest after ZIP processing. This binds bytes but validates
   trust too late: malformed or attacker-controlled ZIP structure is processed
   before authenticity is established.

Options 5 and 6 can both be strengthened without changing their identity model:
require a seekable regular-file stream, require exactly one `Get-FileHash`
result, assert the stream remains open, rewind explicitly to zero, use one
read-mode `ZipArchive` with deliberate `leaveOpen` behavior, dispose the
archive before the stream, and add cross-edition harness evidence. Those are
implementation requirements rather than separate architectural alternatives.

### Evaluation rubric

Each option is scored from 1 (unacceptable) to 5 (excellent). The weighted
score is the sum of `weight × score ÷ 5`, producing a maximum of 100.

| Criterion | Weight | What a high score requires |
| --- | ---: | --- |
| Verified-byte identity and security correctness | 30 | ZIP parsing and extraction are provably bound to the bytes whose digest matched, without a path-replacement gap. |
| Cross-edition and cross-platform reliability | 15 | The contract is implementable with supported APIs in Windows PowerShell 5.1 and PowerShell 7 and has predictable filesystem semantics. |
| Fail-closed lifecycle and disposal | 12 | Hash, rewind, archive lifetime, exception handling, disposal order, and cleanup remain deterministic under every failure. |
| Harness observability and falsifiability | 12 | The permanent suite can prove the important identity and failure properties rather than merely infer them. |
| Runner usability and environmental tolerance | 10 | Normal scanners/readers and realistic archive sizes do not create avoidable failures or resource exhaustion. |
| Honest residual-race model | 8 | The issue can clearly state what the design prevents and what still depends on the protected job-owned environment. |
| Maintainability and P1/T1 convergence | 8 | The design is easy to review, minimizes security-sensitive custom code, and supports deliberate shared helper invariants. |
| Implementation churn and issue-scope fit | 5 | The change remains practical inside T1 without disproportionate new lifecycle machinery. |

The weighting reflects a security boundary: byte identity dominates. Developer
ergonomics, CI reliability, testability, and maintainability are meaningful,
but ease and churn cannot compensate for extracting unauthenticated bytes.

### Scoring

Abbreviations follow the rubric order: identity (ID), cross-edition/platform
(XP), lifecycle (LC), harness (HT), usability (US), residual-race clarity
(RR), maintainability/convergence (MC), and churn/scope (CS).

| Option | ID 30 | XP 15 | LC 12 | HT 12 | US 10 | RR 8 | MC 8 | CS 5 | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Path hash plus rechecks | 1 | 5 | 4 | 2 | 5 | 2 | 3 | 5 | 58.4 |
| 2. Two opens plus identity metadata | 3 | 1 | 3 | 3 | 3 | 3 | 1 | 1 | 48.8 |
| 3. Whole archive in memory | 5 | 5 | 4 | 5 | 2 | 5 | 3 | 3 | 86.4 |
| 4. Stream to held staging file | 5 | 4 | 3 | 4 | 4 | 4 | 2 | 1 | 77.4 |
| 5. One stream, `FileShare.None` | 5 | 5 | 5 | 4 | 2 | 5 | 4 | 4 | 89.0 |
| 6. One stream, `FileShare.Read` | 5 | 5 | 5 | 5 | 4 | 5 | 5 | 4 | **97.0** |
| 7. One stream with delete sharing | 4 | 3 | 4 | 3 | 5 | 2 | 2 | 3 | 69.2 |
| 8. Validate through a hashing ZIP wrapper | 3 | 3 | 3 | 2 | 3 | 2 | 1 | 1 | 50.8 |

Option 6 wins because it closes the identity gap with standard cross-edition
APIs while avoiding option 5's unnecessary exclusion of benign concurrent
readers. Options 3 and 4 are defensible fallbacks when streams cannot be held,
but introduce resource or lifecycle costs without improving the core property.

### Selected option and implementation contract

Select **option 6: one continuously held read-only stream with
`FileShare.Read`**.

Revise T1 so an implementer coming in cold must do exactly this:

1. Finish the existing parameter, root, containment, component,
   download-directory, candidate-parent, and ordinary-file checks without
   opening the archive.
2. Repeat the applicable envelope checks immediately before the security
   boundary.
3. Open the one retained ordinary file exactly once with
   `[System.IO.File]::Open($path, [FileMode]::Open, [FileAccess]::Read,
   [FileShare]::Read)`.
4. Require the resulting stream to be readable and seekable.
5. Call `Get-FileHash -InputStream $stream -Algorithm SHA256`, collect its
   output, and require exactly one non-null result with one valid 64-hex hash.
6. Compare that hash to `ExpectedDigest` with ordinal,
   case-insensitive equality. A mismatch must fail before `ZipArchive` is
   constructed and before candidate creation.
7. Set `$stream.Position = 0`; do not close or replace the stream.
8. Construct exactly one read-mode `ZipArchive` over that same object. Choose
   `leaveOpen` deliberately so disposal order is archive first, stream second.
9. Keep both objects continuously alive through complete central-directory
   inspection, manifest validation, candidate creation, extraction, and any
   post-extraction byte validation that still reads archive entries.
10. In `finally`, dispose the archive, then the stream, before candidate
    cleanup. Preserve the primary error and append disposal/cleanup errors
    without masking it.
11. Prohibit `Get-FileHash -Path`/`-LiteralPath`, a second archive-path open,
    a memory copy, or a staging copy in this implementation.
12. State that the held handle binds hash and ZIP bytes under ordinary runtime
    sharing semantics, while full-component validation and the protected
    job-owned/no-competing-writer model remain necessary. Do not claim a
    universal OS-native sandbox or protection from privileged/kernel-level
    mutation.
13. Extend the tracked harness in both PowerShell editions to prove digest
    mismatch occurs before ZIP construction, the stream is rewound, the same
    stream feeds ZIP processing, invalid ZIPs fail without candidate creation,
    and disposal completes before cleanup.

This selection deliberately converges T1 on P1's stronger byte-identity
invariant while leaving repository-specific manifests and workflow coverage
independent.

## Finding T1-2 — Make rejection outcomes and cleanup tests truthful

### Options

The design must distinguish state the helper owns from state it merely
encounters. A rejection test cannot demand absence when the fixture began with
an entry that must not be deleted, and cleanup must never traverse a
substituted link/reparse point.

1. **Keep the global “candidate absent” oracle.** Interpret every rejection as
   requiring deletion of any candidate leaf. This is simple but contradicts
   the preexisting-leaf tests and violates ownership-safe cleanup.
2. **Remove all preexisting-leaf fixtures.** Preserve the global absence oracle
   by testing only initially absent destinations. This avoids the literal
   contradiction but drops essential protection against overwrite, reuse, and
   dangling-link attacks.
3. **Run fixture teardown before asserting absence.** Let the test harness
   remove its own preexisting fixture after helper execution, then assert that
   the leaf is absent. This conflates harness teardown with helper behavior and
   can hide a helper that modified, followed, or deleted the original entry.
4. **Use one generic “safe terminal state” oracle.** Replace absence with broad
   language such as “no unsafe write occurred.” This is truthful but too vague
   to make deterministic tests or diagnose regressions.
5. **Define per-class postconditions only.** Specify distinct outcomes for
   initially absent pre-creation failures, preexisting leaves, controlled
   helper-created failures, and fail-closed cleanup failures. Keep the existing
   combined BOM-or-CR fixture and infer cleanup safety from implementation
   review.
6. **Define per-class postconditions and split content fixtures.** Add separate
   BOM and CR fixtures so each byte rule is independently falsifiable, but do
   not deliberately exercise an unsafe cleanup substitution.
7. **Define per-class postconditions, split BOM/CR, and add a cleanup-safety
   fixture.** After controlled candidate creation, introduce or substitute an
   unexpected/link/reparse/unreadable entry at a deterministic test hook,
   require cleanup to stop without following or recursively deleting it, and
   require the retained path plus primary and cleanup diagnostics. This
   directly tests both normal rollback and fail-closed retention.
8. **Never clean a helper-created candidate after any failure.** Always retain
   partial results for forensics. This avoids dangerous deletion but leaves
   sensitive artifacts and makes routine controlled failures operationally
   messy.
9. **Quarantine or recursively delete any rejected candidate.** Rename the
   candidate or use recursive removal so the expected path becomes absent.
   Rename can cross trust/identity boundaries, and recursive removal can follow
   or erase entries the helper did not create. Neither is compatible with the
   ownership model.

For options 5–7, normal cleanup should use an ownership journal or the exact
four known manifest names, revalidate the complete envelope, inspect every leaf
without following links, delete only ordinary helper-created files
non-recursively, and remove only the now-empty helper-created directory. A
cleanup problem must augment—not replace—the primary error.

### Evaluation rubric

Scores run from 1 (unacceptable) to 5 (excellent); weighted totals are out of
100.

| Criterion | Weight | What a high score requires |
| --- | ---: | --- |
| Ownership-safe cleanup and non-traversal | 26 | The helper deletes only entries it created, never follows unexpected links/reparse points, and fails closed on uncertainty. |
| Oracle truthfulness and determinism | 22 | Every asserted terminal state is logically compatible with its initial state and can be tested without harness teardown masking behavior. |
| Adversarial coverage quality | 16 | Tests independently exercise preexisting leaves, normal post-creation rollback, BOM, CR, and unsafe cleanup mutation. |
| Primary/cleanup diagnostic integrity | 10 | The original failure remains primary while cleanup failure and retained paths are explicit and stable. |
| Cross-filesystem robustness | 9 | The contract accounts for Windows reparse semantics, POSIX links, dangling entries, case behavior, and enumeration failures. |
| Operator safety and forensic usability | 8 | Routine failures do not leak partial state, while unsafe states are retained with actionable handling information. |
| Reviewability and maintainability | 6 | A new contributor can map each fixture to one unambiguous expected state and preserve it over time. |
| Churn and implementation effort | 3 | The option avoids disproportionate machinery; effort is deliberately a minor factor. |

Security ownership and truthful tests dominate this rubric. A smaller patch
that produces an impossible oracle or unsafe deletion cannot outrank a more
complete, falsifiable cleanup contract.

### Scoring

Abbreviations: ownership cleanup (OC), truthful oracle (TO), adversarial
coverage (AC), diagnostics (DG), cross-filesystem behavior (XF), operator
safety (OS), maintainability (MT), and churn (CH).

| Option | OC 26 | TO 22 | AC 16 | DG 10 | XF 9 | OS 8 | MT 6 | CH 3 | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Keep global absence | 1 | 1 | 2 | 2 | 1 | 1 | 2 | 5 | 28.8 |
| 2. Remove preexisting-leaf tests | 4 | 4 | 1 | 3 | 3 | 3 | 3 | 4 | 63.8 |
| 3. Assert after fixture teardown | 1 | 1 | 3 | 2 | 2 | 1 | 1 | 3 | 31.4 |
| 4. Generic safe-state oracle | 4 | 3 | 2 | 3 | 3 | 3 | 2 | 5 | 62.0 |
| 5. Per-class outcomes only | 5 | 5 | 3 | 5 | 4 | 4 | 4 | 4 | 88.4 |
| 6. Per-class outcomes plus split BOM/CR | 5 | 5 | 4 | 5 | 4 | 4 | 5 | 4 | 92.8 |
| 7. Outcomes, split fixtures, cleanup attack | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 3 | **98.8** |
| 8. Always retain partial candidate | 5 | 4 | 2 | 4 | 5 | 2 | 4 | 5 | 78.0 |
| 9. Quarantine/recursive deletion | 1 | 4 | 1 | 1 | 1 | 1 | 2 | 3 | 35.6 |

Option 7 is the only design that makes every terminal state truthful and
directly proves the dangerous cleanup branch. Option 6 is close but leaves the
most security-sensitive cleanup behavior supported only by code inspection.

### Selected option and implementation contract

Select **option 7: per-class outcomes, separate BOM and CR fixtures, and a
deterministic cleanup-safety fixture**.

Revise T1 as follows:

1. Delete the fixture-wide statement that every rejection leaves the candidate
   nonexistent. Replace it everywhere, including acceptance criteria, with the
   following four classes:
   - initially absent plus failure before helper creation → remains absent;
   - preexisting leaf → remains byte/type/target-identical and is never
     followed;
   - controlled post-creation failure with only known ordinary helper-owned
     entries → those files are removed non-recursively and the now-empty
     helper-owned leaf is removed; and
   - unsafe/unreadable/changed cleanup state → nothing uncertain is followed or
     recursively deleted, the path is retained, and primary plus cleanup
     diagnostics identify it.
2. Give every rejection row its own expected phase and one of those terminal
   state classes. The harness must capture initial state before invocation and
   compare final state before its own `finally` teardown.
3. Split “BOM or CR” into two archives and two stable case IDs. Each must pass
   manifest validation, create the candidate, fail post-extraction byte
   validation for only its targeted condition, and demonstrate safe normal
   rollback.
4. Keep an exact ownership journal containing only the candidate directory and
   ordinary files created by the current invocation. Cleanup may act only on
   that journal after revalidating the root, parent, candidate, and each
   immediate child.
5. Before each deletion, enumerate without following links and require the
   expected entry type. Delete known files individually and non-recursively;
   delete the candidate directory only when enumeration proves it empty and
   ordinary.
6. If an entry is missing, replaced, extra, unreadable, a link, a reparse
   point, or otherwise uncertain, stop cleanup. Never use recursive deletion,
   wildcard deletion, or traversal through the entry.
7. Preserve the primary phase/error. Add a distinct cleanup phase, the exact
   retained path, the offending entry when safely available, and any cleanup
   exception. Return nonzero.
8. Make the cleanup algorithm a named function in the exact tracked production
   helper. Give the tracked harness a documented definition-only way to load
   that function without executing the helper's main entry point; do not
   duplicate cleanup logic in the harness.
9. In the cleanup-safety fixture, construct a helper-owned candidate and
   ownership journal below the fixture root, replace one journaled ordinary
   file with a symlink/reparse point or add an unexpected entry, call the exact
   production cleanup function, and assert:
   - the external target is unchanged;
   - the unsafe entry was not followed or deleted;
   - the candidate remains;
   - diagnostics contain the primary failure, cleanup failure, and retained
     path; and
   - the result is nonzero.
10. Exercise the link/reparse variant on at least one platform where creation
    is supported and never allow a platform-wide skip. Use an ordinary
    unexpected-entry or type-change variant on environments where link creation
    is unavailable.
11. Only after all assertions may the harness's own `finally` remove the
    complete isolated fixture root.

The definition-only loading mechanism is test infrastructure, not a second
public artifact-expansion interface. Production workflow calls must continue to
use the five mandatory and three optional helper parameters already specified
by T1.

## Finding T2-1 — Alleged AWS KMS documentation conflict

### Validity recheck

This recorded finding is **not valid** after inspecting the current AWS pages'
document structure. The `GetObject` API statement requiring both
`kms:GenerateDataKey` and `kms:Decrypt` is inside the **Directory bucket
permissions** list item. It is not a conflicting general-purpose-bucket rule.
The general SSE-KMS guide and S3 policy-action table both identify
`kms:Decrypt` for general-purpose retrieval and `kms:GenerateDataKey` for
upload/destination operations. T2 already distinguishes those cases and keeps
directory buckets outside historical version recovery.

### Options

1. **Keep T2's current reconciliation unchanged.** Preserve the dated
   seven-point explanation, the general-purpose `kms:Decrypt` rule, the
   directory-bucket both-actions rule, the effective-authorization caveat, and
   the immediate-preimplementation source recheck.
2. **Keep the substance but clarify the `GetObject` page's list nesting.** Add
   that the both-actions sentence belongs to the directory-bucket permissions
   bullet. This can prevent the same misreading but adds implementation detail
   to an already precise rationale.
3. **Remove the reconciliation and cite only the general SSE-KMS guide.** This
   shortens the issue but leaves reviewers vulnerable to misreading the
   adjacent directory-bucket API text and loses the reason directory buckets
   are excluded.
4. **Describe an unresolved official conflict.** State that the `GetObject` API
   requires both actions for general-purpose retrieval. This repeats the
   invalid finding and misrepresents the source hierarchy.
5. **Recommend both KMS actions for every KMS-encrypted download.** This may
   avoid some authorization failures but violates least privilege for the
   documented general-purpose path and grants an upload-related cryptographic
   capability without evidence.
6. **Avoid all permission statements and defer to an administrator.** This
   eliminates the risk of stale detail but substantially reduces the example's
   diagnostic usefulness for operators and security reviewers.
7. **Add a live AWS permission probe to the example.** Attempt retrieval and
   infer missing policy actions from failure. Service errors cannot reliably
   distinguish identity policy, key policy, grants, SCPs, account topology, or
   encryption mode, and the issue intentionally documents rather than
   automates authorization.

Option 2 is a compatible editorial permutation of option 1. It should be chosen
only if the extra clause materially prevents reviewer confusion; it must not
recast the directory-bucket rule as relevant to the actual recovery command.

### Evaluation rubric

Scores run from 1 to 5 and produce a weighted total out of 100.

| Criterion | Weight | What a high score requires |
| --- | ---: | --- |
| Fidelity to current AWS primary sources | 30 | Every permission statement matches the source's bucket class, operation, and structural context. |
| Least-privilege security guidance | 22 | The issue requests no cryptographic action that current evidence does not require for the documented path. |
| Operator diagnostic usefulness | 15 | A reader can identify the likely S3/KMS permission class and understand that policy, key, grant, and account topology still matter. |
| Bucket/operation scope clarity | 12 | General-purpose historical retrieval cannot be confused with directory-bucket or upload behavior. |
| Resilience to provider change | 10 | The plan requires a timely source recheck and avoids pretending documentation is immutable. |
| Reviewer auditability | 7 | A security reviewer can trace each conclusion to a named primary source. |
| Editorial churn and scope | 4 | Unnecessary prose and unrelated authorization machinery are avoided. |

Correct attribution and least privilege dominate. More permissive guidance does
not score as “safer” when the additional action is unsupported for the scoped
operation.

### Scoring

Abbreviations: source fidelity (SF), least privilege (LP), operator diagnostics
(OD), bucket scope (BS), future resilience (FR), reviewer auditability (RA),
and editorial churn (EC).

| Option | SF 30 | LP 22 | OD 15 | BS 12 | FR 10 | RA 7 | EC 4 | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Keep current reconciliation | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| 2. Add list-nesting clarification | 5 | 5 | 5 | 5 | 5 | 5 | 4 | 99.2 |
| 3. Cite only general SSE-KMS guide | 4 | 5 | 2 | 2 | 4 | 2 | 5 | 71.6 |
| 4. Describe a conflict | 1 | 2 | 2 | 1 | 3 | 1 | 2 | 32.2 |
| 5. Recommend both actions everywhere | 2 | 1 | 3 | 2 | 3 | 2 | 3 | 41.4 |
| 6. Remove permission guidance | 3 | 5 | 1 | 1 | 5 | 1 | 4 | 60.0 |
| 7. Add a live permission probe | 2 | 3 | 2 | 2 | 2 | 2 | 1 | 43.6 |

Option 1 scores perfectly because T2 already contains the precise distinction
that option 2 would add in different words. Options 4 and 5 would convert a
misreading into either inaccurate or overprivileged guidance.

### Selected option and implementation contract

Select **option 1: keep T2's current AWS reconciliation unchanged**.

No corrective T2 edit is warranted for this recorded finding. When revising
the slate:

1. Retain the general-purpose statement that SSE-KMS/DSSE-KMS retrieval
   requires applicable `kms:Decrypt` authorization.
2. Retain the statement that `kms:GenerateDataKey` appears on
   general-purpose upload/destination paths, not this historical download path.
3. Retain the separate directory-bucket statement that ordinary SSE-KMS access
   there requires both actions.
4. Retain the explanation that these are different bucket classes and
   operations.
5. Retain the identity-policy, key-policy, grant, encryption-mode, and account
   topology caveat.
6. Retain the immediate-preimplementation AWS source recheck.
7. Retain the directory-bucket exclusion from version recovery.
8. Do not add a claim of unresolved conflict and do not grant
   `kms:GenerateDataKey` merely as speculative troubleshooting.

The earlier T2-1 entry in `current-findings.md` is superseded by this
source-structure recheck for purposes of the issue revisions.

## Finding T2-2 — Prevent inherited Bash xtrace from exposing the HCP token

### Options

1. **Keep only the prose warning not to use `set -x`.** This depends on the
   operator noticing the warning before pasting the block and does not defend
   against xtrace inherited from the current shell or a wrapper.
2. **Put `set +x` first inside the existing subshell.** Because the block
   already runs in parentheses, disabling xtrace there does not alter the
   interactive parent after the block ends. No token expansion occurs before
   the command.
3. **Detect xtrace and refuse to run.** Inspect `$-` for `x` as the first
   operation and exit with a nonsensitive message if tracing is active. This
   prevents leakage but makes the copy-safe example fail in an otherwise
   recoverable environment and still requires care that the detection command
   itself contains no secret.
4. **Disable xtrace, then restore it before leaving the block.** Save the prior
   flag, run `set +x`, perform recovery, and re-enable tracing at the end.
   Restoration is unnecessary in a subshell and risks tracing later
   token-adjacent cleanup or error handling.
5. **Launch a fresh `bash +x` process for the sensitive portion.** This can
   isolate options but complicates quoting, environment inheritance, file
   descriptors, exit status, and copy/paste behavior.
6. **Move the token to curl's command line.** Use `--header
   "Authorization: Bearer $TFC_TOKEN"` directly. Xtrace and the process list can
   expose it, so this regresses two boundaries.
7. **Write a temporary curl configuration or netrc file.** Disable tracing
   while creating a mode-restricted credential file, point curl to it, and
   delete or retain it under policy. This keeps the token off argv but creates a
   new secret-at-rest lifecycle and cleanup problem.
8. **Use curl's variable/environment expansion features.** Import the token
   from the environment and expand it into a header inside curl. Version
   availability varies, and shell commands that prepare the expansion can
   still be traced. It is not a substitute for disabling inherited xtrace.
9. **Require operators to start a clean shell.** Document `bash --noprofile
   --norc` and paste the block there. This is cumbersome, profile behavior is
   not the only source of tracing, and the example still lacks a local defense.

Options 2 and 3 can be combined: disable tracing first, then optionally assert
that `x` is no longer present. The security property comes from option 2; a
post-disable assertion is diagnostic defense in depth, not a separate secret
transport.

### Evaluation rubric

Scores run from 1 to 5 and produce a weighted total out of 100.

| Criterion | Weight | What a high score requires |
| --- | ---: | --- |
| Token non-disclosure | 32 | The bearer token is not exposed through shell trace, argv, ordinary curl configuration discovery, or new persistent files. |
| Earliest-boundary protection | 18 | Protection takes effect before the first guarded expansion, assignment, here-document expansion, or command containing the token. |
| Copy/paste functional reliability | 14 | The example works predictably in an interactive Bash session without a preparatory shell ritual. |
| Parent-shell side-effect containment | 10 | Security option changes do not unexpectedly alter the user's parent shell after the recovery block. |
| Preservation of existing curl protections | 9 | `-q`, stdin configuration, pre-opened exact output descriptor, status capture, and pagination behavior remain intact. |
| Negative-test quality | 8 | A synthetic sentinel test can prove inherited tracing does not emit the token. |
| Bash/curl version portability | 7 | The solution uses long-established shell behavior and does not depend on a new curl feature. |
| Churn and explanatory cost | 2 | The issue remains understandable and concise; this is intentionally the lowest weight. |

Secret containment and protection timing dominate. An option that usually
works in a clean shell cannot score well if inherited state can disclose the
token before its guard runs.

### Scoring

Abbreviations: token nondisclosure (TN), earliest protection (EP), copy/paste
reliability (CP), parent-shell containment (PS), curl protections (CU),
negative testing (NT), Bash portability (BP), and churn (CH).

| Option | TN 32 | EP 18 | CP 14 | PS 10 | CU 9 | NT 8 | BP 7 | CH 2 | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Prose warning only | 1 | 1 | 4 | 5 | 5 | 1 | 5 | 5 | 50.8 |
| 2. First-command `set +x` | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| 3. Refuse when xtrace is active | 5 | 5 | 2 | 5 | 5 | 4 | 5 | 4 | 89.6 |
| 4. Disable and later restore | 4 | 5 | 4 | 3 | 4 | 3 | 5 | 3 | 81.0 |
| 5. Launch a fresh Bash | 4 | 4 | 2 | 5 | 3 | 3 | 3 | 1 | 70.4 |
| 6. Put token on curl argv | 1 | 1 | 5 | 5 | 1 | 1 | 5 | 5 | 46.4 |
| 7. Temporary credential file | 4 | 4 | 2 | 5 | 3 | 3 | 5 | 1 | 73.2 |
| 8. Curl variable expansion | 3 | 3 | 3 | 5 | 4 | 3 | 1 | 2 | 62.6 |
| 9. Require a clean shell | 2 | 1 | 1 | 5 | 4 | 1 | 4 | 2 | 44.4 |

Option 2 is both the strongest and simplest because the existing parentheses
already provide the exact scope needed: xtrace is disabled before token use and
the parent shell's tracing preference returns automatically when the subshell
ends.

### Selected option and implementation contract

Select **option 2: make `set +x` the first command in the HCP subshell**.

Revise T2 so:

1. The HCP code fence begins:

   ```bash
   (
     set +x
     umask 077
   ```

2. No variable expansion, assignment, command substitution, function call, or
   other token-adjacent operation appears between `(` and `set +x`.
3. The block does not re-enable xtrace. The subshell boundary automatically
   preserves the parent's prior state after the block exits.
4. The existing guarded `TFC_TOKEN` assignment, curl `-q` first option,
   `--config -`, unquoted intentional here-document, pre-opened descriptor 3,
   exact-path noclobber behavior, status capture, and retained partial-file
   handling remain unchanged.
5. The explanation says that `set +x` suppresses inherited Bash xtrace before
   the token is expanded, while stdin curl configuration keeps the token out of
   curl's ordinary argv. These are complementary controls.
6. The warning also says the block cannot protect against an external wrapper,
   terminal recorder, debugger, environment dumper, or modified shell that
   records secret input independently.
7. Validation runs the HCP block's variable-initialization/configuration path
   with xtrace enabled in the parent and a synthetic sentinel token, captures
   stdout and stderr, and fails if the sentinel appears. It must also confirm
   that tracing remains enabled in the parent after the subshell returns.
8. Validation never uses a real HCP token or makes the synthetic test depend on
   a successful network request.

The first traced line may be the nonsensitive `+ set +x`; that is acceptable.
The acceptance property is that no secret value or token-bearing header appears
after inherited xtrace was enabled.

## Finding T1/T2-1 — Track current Markdown-tooling advisories without destabilizing the slate

### Options

1. **Take no action.** Leave dependency changes outside T1/T2 and rely on
   maintainers to remember the audit result. This preserves scope but does not
   create ownership, priority, or a closure condition.
2. **Expand T1 to remediate npm dependencies.** Update direct/transitive
   packages, lockfile, npm Dependabot, audit policy, and lint baselines alongside
   the generator/artifact security work. This creates one comprehensive
   security issue but materially increases T1's already large failure surface.
3. **Expand T2 to remediate npm dependencies.** Perform the package changes
   while editing documentation. This mixes unrelated provider guidance and
   toolchain risk, and changes T2's prerequisite baseline after T1.
4. **Create a new T0 prerequisite before T1.** Remediate advisories and
   rebaseline lint first. This is appropriate if repository policy prohibits
   proceeding with high-severity findings, but otherwise invalidates many
   carefully dated T1/T2 assumptions before implementation.
5. **Create a new T3 follow-up after T2.** Draft and add a third slate issue for
   npm dependency remediation and Dependabot. This cleanly owns the work but
   exceeds the prompt's named T1/T2 revision artifacts.
6. **Require a separately filed and linked follow-up, ordered after T2 by
   default.** Add a T1 planning/acceptance requirement that a dedicated npm
   remediation issue is filed and linked before T1 closes; carry that tracking
   relationship into T2. If policy blocks known high advisories, explicitly
   invert the order and rebaseline T1/T2 before work starts. Do not draft or
   implement the third issue inside this two-file slate.
7. **Add npm Dependabot in T1 but defer current remediation.** Extend
   `.github/dependabot.yml` with the npm ecosystem while leaving the known
   lockfile findings for future pull requests. This improves maintenance but
   does not disposition current vulnerabilities and produces PRs against a
   moving lint baseline.
8. **Add an audit-only CI gate.** Run `npm audit` in pull requests with a chosen
   threshold while preserving package versions. With five current high
   findings, the gate either fails immediately or must baseline/ignore known
   findings, neither of which replaces remediation ownership.
9. **Update only the two direct dev dependencies opportunistically.** Upgrade
   `markdown-it` and `markdownlint-cli2` without a separately tracked audit
   objective. This may resolve transitive nodes but hides the decision,
   validation, and future maintenance policy in unrelated work.

Options 4 and 6 have an explicit ordering permutation controlled by repository
policy. The order must be decided before implementation; “after T2 unless
policy requires otherwise” is not permission to leave the issue unfiled.

### Evaluation rubric

Scores run from 1 to 5 and produce a weighted total out of 100.

| Criterion | Weight | What a high score requires |
| --- | ---: | --- |
| Accountable security-risk ownership | 24 | A named issue, ownerable scope, and closure path exist for the known audit findings. |
| Disposition of the current findings | 18 | The plan addresses the seven current vulnerable nodes rather than only future updates or a failing signal. |
| T1/T2 baseline stability | 16 | Generator, workflow, and provider-documentation acceptance criteria are not invalidated midstream without deliberate rebaselining. |
| Sustainable dependency maintenance | 12 | npm Dependabot and a review policy are included in the owned work. |
| Validation completeness | 11 | Lockfile install/audit plus outer and nested Markdown lint behavior are covered. |
| Priority and ordering governance | 9 | Policy can promote the work ahead of T1, otherwise the default order is explicit and non-forgetful. |
| Stakeholder/reviewer clarity | 7 | Security, project, and business stakeholders can see why work is split and when it completes. |
| Churn and issue-scope fit | 3 | The current two issues avoid disproportionate expansion; this remains a minor criterion. |

The rubric rewards actual ownership and current remediation. Merely adding a
scanner or future updater cannot compensate for leaving known high-severity
findings undispositioned.

### Scoring

Abbreviations: ownership (OW), current disposition (CD), baseline stability
(BS), maintenance (DM), validation (VL), ordering (OR), clarity (CL), and
scope/churn (SC).

| Option | OW 24 | CD 18 | BS 16 | DM 12 | VL 11 | OR 9 | CL 7 | SC 3 | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. No action | 1 | 1 | 5 | 1 | 1 | 1 | 1 | 5 | 35.2 |
| 2. Expand T1 | 5 | 5 | 1 | 5 | 5 | 2 | 2 | 1 | 75.2 |
| 3. Expand T2 | 5 | 5 | 1 | 5 | 5 | 1 | 1 | 1 | 72.0 |
| 4. Add a T0 prerequisite | 5 | 5 | 2 | 5 | 5 | 5 | 5 | 2 | 88.6 |
| 5. Draft a T3 follow-up in this slate | 5 | 5 | 5 | 5 | 5 | 4 | 5 | 3 | 97.0 |
| 6. Require separately filed linked follow-up | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| 7. Dependabot now, remediation later | 4 | 1 | 3 | 5 | 3 | 2 | 3 | 3 | 60.6 |
| 8. Audit-only CI gate | 3 | 2 | 2 | 1 | 3 | 2 | 3 | 3 | 46.6 |
| 9. Opportunistic direct upgrades | 2 | 3 | 2 | 1 | 4 | 1 | 1 | 2 | 42.4 |

Option 6 edges out a drafted T3 because it provides the same ownership and
ordering without silently expanding the prompt's two named issue artifacts.
Its success depends on making the filing/link a real T1 gate, not a vague
future-work sentence.

### Selected option and implementation contract

Select **option 6: require a separately filed, linked npm-remediation issue,
ordered after T2 by default**.

Revise the two-file slate as follows:

1. Add a short T1 tracking subsection that records the 2026-07-29
   lockfile-only audit baseline: seven vulnerable package nodes, five high and
   two moderate, involving `brace-expansion`, `js-yaml`, `linkify-it`,
   `markdown-it`, `markdownlint-cli2`, `minimatch`, and `picomatch`.
2. Require a separate TerraformStyleGuide dependency-remediation issue to be
   filed and linked from T1 before T1 is closed. The link must be a real issue
   URL/number in the filed issue or implementation PR; a local placeholder is
   not closure evidence.
3. State that the dedicated issue—not T1 or T2—owns:
   - `.github/workflows/package.json` and `package-lock.json` upgrades;
   - npm Dependabot for `/.github/workflows`;
   - direct and transitive advisory disposition;
   - lockfile regeneration without an unreviewed `--force` major jump;
   - `npm ci`, the outer Markdown lint suite, the nested-fence suite, and a
     lockfile-only audit at the repository's selected threshold; and
   - documented risk acceptance or upstream constraints for any finding that
     cannot be remediated immediately.
4. Default the dependency issue to execute after T2 so T1/T2 retain one stable
   lint/toolchain baseline.
5. If repository policy forbids proceeding with current high findings, require
   the dependency issue to move before T1. After it lands, the author must
   re-read and rebaseline both T1 and T2 rather than assuming their package,
   action, Node, or lint statements remain accurate.
6. Keep npm dependency and lockfile changes outside T1's seven implementation
   files and outside T2's six affected files.
7. In T2's prerequisite/baseline language, acknowledge the linked dependency
   issue and say it is non-blocking only under the default after-T2 order. T2
   must not claim that known advisories were remediated.
8. Add the npm and GitHub Dependabot primary references to T1.

This selection creates visible accountable work without turning either current
issue into a dependency-upgrade project or inventing an unrequested third local
issue description.

## Finding T1-3 — Correct or justify the dated GitHub Actions pins

### Options

1. **Keep the four current literals and the “as of 2026-07-29” claim.** The
   preimplementation recheck may catch drift later, but checkout v7.0.1 and
   setup-node v7.0.0 already existed on the stated date, making the claim false.
2. **Update checkout and setup-node to the current v7 releases.** Pin their
   exact full SHAs, retain upload-artifact v7.0.1 and download-artifact v8.0.1,
   and keep immediate metadata/runtime/input/output verification.
3. **Keep checkout/setup-node v6 as an explicit approved ceiling.** Replace
   “current” with “approved,” document a concrete runner/runtime/caching/ESM
   compatibility reason for declining v7, and set a review trigger. This is
   valid only if implementation research finds an actual incompatibility.
4. **Remove literal SHAs from the issue.** Require the implementer to select
   current full SHAs at execution time. This avoids stale prose but makes the
   issue less reproducible and moves a security-sensitive decision out of
   review.
5. **Use mutable major tags such as `@v7`.** This follows current majors with
   minimal maintenance but gives upstream tag movement control over executed
   code and violates T1's immutable-pin requirement.
6. **Pin the newest upstream default-branch commit.** This maximizes currency
   but bypasses release boundaries, versioned compatibility expectations, and
   release-note review.
7. **Update every action even when already current.** Re-resolve all four SHAs
   and change literals whether or not their release identity changed. This can
   create meaningless churn and increases transcription risk.
8. **Keep stale pins and rely only on Dependabot after merge.** Dependabot
   improves future visibility but does not make the initial dated assertion
   accurate or review the v7 transition before T1 lands.
9. **Use a centralized variable or reusable wrapper for action references.**
   GitHub Actions does not support arbitrary expressions in `uses`, and a
   wrapper adds indirection without eliminating the need to pin its own
   executable identity.

Option 2 can be combined with a deliberate option-3 fallback: attempt v7
validation first; retain v6 only if a specific incompatibility is recorded.
That is the selected decision procedure, not permission to choose v6 for lower
churn.

### Evaluation rubric

Scores run from 1 to 5 and produce a weighted total out of 100.

| Criterion | Weight | What a high score requires |
| --- | ---: | --- |
| Immutable supply-chain identity | 25 | Every external action executes by a verified full commit SHA belonging to the intended upstream release. |
| Dated factual currency | 20 | The issue's stated “as of” versions existed and were current on the stated date, or an older approved ceiling is honestly labeled and justified. |
| Runner/runtime compatibility | 16 | Node runtime, minimum runner, action inputs/outputs, checkout credentials, artifact digest/ID behavior, and repository workflow semantics are checked. |
| Security-review reproducibility | 12 | Reviewers see exact version/SHA pairs and the decision evidence before implementation. |
| Ongoing update visibility | 10 | Dependabot produces review-only update proposals and no auto-merge bypasses human review. |
| Existing workflow behavior preservation | 9 | Node/lint/cache, artifact transport, permissions, and writer behavior do not change unintentionally. |
| Deliberate P1/T1 alignment | 5 | Shared pins converge where compatible without downgrading either repository merely for symmetry. |
| Churn and implementation effort | 3 | Unnecessary edits are avoided; this cannot outweigh accuracy or immutability. |

Currency alone is insufficient: a mutable or unvalidated latest reference
cannot beat a fully reviewed release SHA. Conversely, immutability does not
make a false dated-current claim acceptable.

### Scoring

Abbreviations: immutable identity (II), factual currency (FC), runtime
compatibility (RC), reproducibility (SR), update visibility (UV), behavior
preservation (BP), cross-repo alignment (CA), and churn (CH).

| Option | II 25 | FC 20 | RC 16 | SR 12 | UV 10 | BP 9 | CA 5 | CH 3 | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Keep stale dated literals | 5 | 1 | 3 | 3 | 5 | 4 | 2 | 5 | 68.0 |
| 2. Update checkout/setup-node to v7 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| 3. Document an approved v6 ceiling | 5 | 5 | 5 | 5 | 5 | 5 | 2 | 5 | 97.0 |
| 4. Choose SHAs only at implementation | 4 | 5 | 3 | 1 | 5 | 3 | 3 | 5 | 73.4 |
| 5. Use mutable major tags | 1 | 5 | 4 | 2 | 5 | 2 | 5 | 5 | 64.2 |
| 6. Pin unreleased default-branch commits | 5 | 5 | 1 | 2 | 2 | 1 | 1 | 2 | 61.0 |
| 7. Rewrite all four references | 5 | 5 | 5 | 4 | 5 | 3 | 4 | 2 | 91.2 |
| 8. Dependabot later, stale pins now | 5 | 1 | 3 | 2 | 5 | 4 | 2 | 5 | 65.6 |
| 9. Add an action-reference wrapper | 3 | 4 | 2 | 2 | 3 | 2 | 3 | 1 | 55.4 |

Option 2 wins. Option 3 is a valid contingency only if an actual v7
incompatibility is found and documented; without one it is unjustified
divergence, not a lower-churn tie.

### Selected option and implementation contract

Select **option 2: update checkout and setup-node to the current v7 full
SHAs**, with option 3 available only for a documented incompatibility.

Revise T1's dated pin block to:

```yaml
uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

```yaml
uses: actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0
```

Retain:

```yaml
uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
```

```yaml
uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1
```

Implementation requirements:

1. Verify all four full SHAs in their official repositories immediately before
   implementation and check for later required security releases.
2. Review checkout v7's fork-checkout protection, ESM/dependency changes,
   inherited v6 credential storage under `RUNNER_TEMP`, Node 24/minimum-runner
   requirements, persisted-credential behavior, and post-job cleanup.
3. Review setup-node v7's ESM/dependency changes, Node runtime, inputs, outputs,
   caching defaults, and minimum runner. Preserve the explicit Node 20 lint
   setup and existing cache behavior; set the documented cache-control input
   explicitly if needed to prevent automatic behavior from changing.
4. Prove every writer checkout still supports authenticated push and cleans
   credentials in post-job processing.
5. Revalidate upload/download immutable artifact ID, digest,
   `skip-decompress`, `artifact-ids`, and digest-mismatch behavior.
6. If any v7 incompatibility is found, record it in T1, label the retained v6
   release as the approved ceiling rather than current, and add a dated review
   trigger. Do not silently fall back.
7. Keep weekly review-only GitHub Actions Dependabot and prohibit auto-merge.
8. Keep P1/T1 action pins aligned only where each repository's compatibility
   review approves the same release.

This fixes the false dated-current claim while preserving T1's
preimplementation defense against future staleness.

## Finding T2-3 — State the actual S3 Versioning prerequisite

### Options

1. **Keep “versioning-capable general-purpose bucket.”** This is technically
   broad but does not say versioning is disabled by default or that history must
   have existed and survived retention.
2. **Require the bucket to be currently `Enabled`.** This is easy to explain but
   incorrectly excludes a currently `Suspended` bucket that still retains
   older version IDs.
3. **State the historical and retention prerequisites in prose.** Require that
   S3 Versioning was enabled before the desired version was written and that
   the selected version still exists. Explain that current status may be
   `Enabled` or `Suspended`, while a never-enabled bucket lacks that history.
4. **Add `get-bucket-versioning` as a mandatory preflight and accept `Enabled`
   or `Suspended`.** This makes status visible, but AWS documents that retrieving
   bucket versioning state requires the bucket owner. A delegated recovery
   principal with `s3:ListBucketVersions`/`s3:GetObjectVersion` may not be able
   to run it.
5. **Add `get-bucket-versioning` as an optional diagnostic.** Keep option 3's
   prose and show the command only for an authorized bucket owner. This is
   accurate but lengthens a procedure whose exact-version listing already
   proves whether a retained candidate is available.
6. **Treat a nonempty `list-object-versions` result as the only prerequisite.**
   Let discovery speak for itself and omit versioning-state explanation. This
   is operationally sufficient for a found version but does not teach why no
   history may appear.
7. **Enable versioning automatically before recovery.** This affects future
   writes only, changes backend governance, and cannot manufacture past
   versions; it is outside a read-only recovery example.
8. **Document every lifecycle, Object Lock, replication, and delete-marker
   permutation.** This is comprehensive but obscures the core retained-version
   prerequisite and expands the issue far beyond copy-safe retrieval.

Options 3 and 5 are compatible. The optional status command should be added
only if its owner-only authorization constraint provides more value than the
additional complexity.

### Evaluation rubric

Scores run from 1 to 5 and produce a weighted total out of 100.

| Criterion | Weight | What a high score requires |
| --- | ---: | --- |
| Historical-version correctness | 27 | The guidance accurately states when version IDs are created and whether suspended buckets can retain them. |
| Delegated-operator usability | 18 | A principal with the documented list/get permissions can follow the procedure without an unnecessary owner-only command. |
| Recovery-expectation clarity | 16 | Operators understand why history may be absent and that a desired version must still be retained. |
| Read-only/non-mutating safety | 13 | The procedure does not enable versioning or change bucket governance during recovery. |
| Authorization accuracy | 10 | Any added status check states its distinct authorization requirement and is not confused with object-version permissions. |
| Primary-source alignment | 8 | Enabled, Suspended, never-enabled, and lifecycle/retention statements match current AWS documentation. |
| New-operator comprehensibility | 5 | A reader coming in cold can distinguish capability, prior enablement, current state, and retained history. |
| Scope and prose churn | 3 | The issue remains focused; low churn cannot compensate for inaccurate recovery assumptions. |

The rubric prioritizes historical truth and delegated usability. A seemingly
helpful preflight loses value if it requires a more privileged principal than
the recovery itself.

### Scoring

Abbreviations: historical correctness (HC), delegated operation (DO), expected
results (ER), non-mutating safety (NS), authorization (AA), primary sources
(PS), newcomer clarity (NC), and scope/churn (SC).

| Option | HC 27 | DO 18 | ER 16 | NS 13 | AA 10 | PS 8 | NC 5 | SC 3 | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Keep “versioning-capable” | 2 | 5 | 2 | 5 | 5 | 2 | 1 | 5 | 65.4 |
| 2. Require currently Enabled | 2 | 4 | 3 | 5 | 4 | 3 | 3 | 5 | 66.6 |
| 3. State prior enablement and retention | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| 4. Mandatory status preflight | 4 | 1 | 5 | 5 | 3 | 5 | 4 | 2 | 73.4 |
| 5. Optional owner status diagnostic | 5 | 4 | 5 | 5 | 5 | 5 | 4 | 3 | 94.2 |
| 6. Infer everything from list results | 4 | 5 | 2 | 5 | 5 | 4 | 2 | 5 | 80.4 |
| 7. Enable versioning during recovery | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 2 | 20.6 |
| 8. Document every S3 lifecycle permutation | 5 | 2 | 5 | 5 | 3 | 5 | 1 | 1 | 78.8 |

Option 3 communicates every fact needed for safe expectations without adding an
owner-only command. Option 5 is accurate but unnecessary because exact-key
version listing already provides the recovery-relevant evidence.

### Selected option and implementation contract

Select **option 3: state prior enablement and retained-history prerequisites in
prose without adding an owner-only status command**.

Revise T2's S3 applicability language so a new operator is told:

1. The example applies only to a general-purpose S3 bucket.
2. S3 Versioning is disabled by default.
3. Versioning must have been enabled before the desired historical state
   version was created or overwritten. Enabling it now cannot create earlier
   history.
4. A bucket that was once enabled can currently report `Enabled` or
   `Suspended`; suspension does not erase already retained versions.
5. The exact desired version must still exist. Lifecycle expiration, explicit
   version deletion, or other retention policy may have removed it.
6. Objects that predate first enablement can have the `null` version ID; the
   operator must inspect the exact-key listing rather than infer age or identity
   from status alone.
7. An empty exact-key `Versions` result means this procedure has no retained
   version to retrieve; it is not a reason to enable versioning or guess an ID.
8. Directory buckets remain excluded because they do not support S3 Versioning
   or `ListObjectVersions`.
9. Do not make `get-bucket-versioning` mandatory. AWS documents it as an
   owner-only operation, while the recovery example deliberately states the
   narrower list/get object-version permissions.

Add the S3 Versioning user-guide reference. Preserve exact-key discovery,
manual selection, the quoted `VERSION_ID` guard, fresh destination, and
read-only copy semantics.

## Finding T1-4 — Verify local PowerShell identity in the executing child process

### Options

1. **Keep executable-name labels only.** Treat `pwsh` as Core 7 and
   `powershell` as Desktop 5.1. This is normally true on supported Windows
   hosts but can be falsified by PATH shims, unexpected versions, or a future
   `pwsh` major.
2. **Check the version once in the parent process.** Assert the shell running
   the local validation block, then launch both applications. This proves
   nothing about either child executable.
3. **Launch a separate child version probe before each script.** Run
   `$PSVersionTable` through the resolved executable, then launch the harness or
   generator in a new process. This checks the binary path but does not prove
   the actual script invocation's process identity.
4. **Wrap each child script invocation in a same-process `-Command` prelude.**
   The child first asserts expected `PSEdition` and version, then invokes the
   harness or generator in that exact process and propagates its failure/exit
   code.
5. **Add expected-edition parameters to the harness and generator.** Each
   script checks its own runtime when the parameter is supplied. This is strong
   evidence but exposes validation-only parameters on production scripts and
   requires interface changes in two files.
6. **Add an eighth tracked local-validation driver.** A new `.ps1` asserts the
   runtime and invokes the target scripts. This is clean and reusable but
   expands T1's exact seven-file scope for a low-severity local-only concern.
7. **Parse `--version` output from each executable.** This is simple but does
   not prove `PSEdition`, localization/format can vary, and the actual script
   still runs in a later process.
8. **Rely exclusively on CI.** Remove or weaken local edition claims and state
   that the four-cell workflow provides authoritative evidence. This is honest
   but gives local contributors slower feedback and leaves the provided local
   validation snippet incomplete.
9. **Run the whole local validation block once under each child shell.** Restart
   the complete block via `powershell` and `pwsh`, assert at its top, and avoid
   nested child launches. This provides strong evidence but requires
   restructuring the copy/paste script to prevent recursion and duplicate Git
   checks.

Option 4 can use a fixed inline command string or a UTF-16LE
`-EncodedCommand`; both PowerShell targets support the underlying `-Command`
execution model. No untrusted values should be interpolated into executable
code.

### Evaluation rubric

Scores run from 1 to 5 and produce a weighted total out of 100.

| Criterion | Weight | What a high score requires |
| --- | ---: | --- |
| Same-process evidence strength | 30 | Edition/version are asserted inside the exact process that invokes the harness or generator. |
| Coverage of both scripts and editions | 18 | Harness and generator each run under Desktop 5.1 and Core major 7 when locally available. |
| Resistance to false labels/shims | 15 | A renamed executable, PATH shim, future major, or unexpected edition fails before the target script. |
| Cross-edition command compatibility | 12 | The mechanism uses CLI and language behavior supported by both Windows PowerShell 5.1 and PowerShell 7. |
| Exit/error propagation | 10 | Child exceptions and native/script exit codes reliably make the parent validation fail. |
| Contributor usability | 7 | The repository-root command remains understandable, gives clear skip/failure messages, and needs no new setup. |
| Maintenance clarity | 5 | Expected edition/major data have one reviewable owner without test-only production interfaces. |
| Scope/churn | 3 | The exact implementation-file scope is preserved when practical; low churn is subordinate to evidence. |

The rubric deliberately treats a separate probe as weaker than a same-process
assertion even when both resolve to the same executable path. The requirement
is evidence about execution, not a likely inference.

### Scoring

Abbreviations: same-process evidence (SE), coverage (CV), shim resistance (SR),
command compatibility (CC), error propagation (EP), contributor usability
(CU), maintenance clarity (MC), and scope/churn (SC).

| Option | SE 30 | CV 18 | SR 15 | CC 12 | EP 10 | CU 7 | MC 5 | SC 3 | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Trust executable names | 1 | 5 | 1 | 5 | 4 | 5 | 4 | 5 | 61.0 |
| 2. Check only parent process | 1 | 2 | 1 | 5 | 3 | 4 | 2 | 5 | 44.8 |
| 3. Separate child probe | 3 | 5 | 3 | 5 | 4 | 3 | 3 | 5 | 75.2 |
| 4. Same-process command prelude | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| 5. Add validation parameters | 5 | 5 | 5 | 5 | 5 | 4 | 2 | 3 | 94.4 |
| 6. Add a tracked driver file | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 1 | 98.2 |
| 7. Parse `--version` | 2 | 4 | 3 | 4 | 3 | 4 | 3 | 5 | 62.6 |
| 8. CI only | 1 | 1 | 5 | 5 | 5 | 2 | 4 | 5 | 56.4 |
| 9. Relaunch the complete validation block | 5 | 5 | 5 | 5 | 5 | 2 | 3 | 2 | 92.0 |

Option 4 provides exact evidence without modifying production interfaces or
adding an eighth file. Option 6 is nearly as strong but is disproportionate for
a local-only evidence correction.

### Selected option and implementation contract

Select **option 4: run a same-process runtime-assertion prelude for every local
harness and generator invocation**.

Revise T1's local validation block as follows:

1. Extend each edition descriptor with the expected `PSEdition` and version:
   - `powershell` → `Desktop`, major 5, minor 1; and
   - `pwsh` → `Core`, major 7.
2. Continue resolving each executable with `Get-Command -CommandType
   Application` and warning/skipping when it is unavailable locally. CI remains
   mandatory coverage.
3. For each available executable, invoke the harness through a child
   `-NoLogo -NoProfile -Command` prelude that:
   - sets `$ErrorActionPreference = 'Stop'`;
   - asserts `$PSVersionTable.PSEdition` with ordinal equality;
   - asserts Desktop exactly 5.1 or Core major exactly 7;
   - invokes the exact tracked harness and helper in that same process;
   - catches and reports failures without losing the expected/actual runtime;
     and
   - exits nonzero for an assertion, exception, or harness failure.
4. Invoke the generator through the same prelude pattern in a separate child
   process and repeat the edition/version assertion there. A successful harness
   process does not prove the generator process.
5. Pass expected values as fixed data—such as temporarily scoped inherited
   environment values saved/restored in `finally`—rather than interpolating
   arbitrary text into executable command source.
6. Capture and check each child `$LASTEXITCODE` immediately. Do not let a later
   Git command overwrite it.
7. Only after the checked generator returns zero may the parent perform its
   byte, Git-object, BOM, CR, and cross-edition comparisons.
8. Increment the validated-edition count only after both the harness and
   generator succeed under the asserted runtime.
9. Keep the CI requirement that edition assertions and helper invocation occur
   in the same explicit-shell step process.

No new tracked file and no validation-only parameter on either production
script is needed.

## Finding T2-4 — Make the prerequisite-file non-goal complete

### Options

1. **Keep the four-file partial list.** T2's exact six-file positive scope
   still prevents implementation drift, but the phrase “the prerequisite
   issue's files” remains factually incomplete.
2. **List all seven T1 implementation files explicitly.** Add
   `.github/dependabot.yml`, the tracked test harness, and
   `.github/workflows/markdownlint.yml` to the existing four and retain T2's
   six-file changed/cached path oracles.
3. **Replace the list with “do not modify any T1 file.”** This is concise but
   forces a cold reader to search another long issue and can be read as
   including planning artifacts rather than affected implementation files.
4. **Reference T1's affected-files section by heading only.** This reduces
   duplication but GitHub headings can change and the issue description is less
   self-contained when copied or handed off.
5. **Use a complete table mapping T1's seven files and T2's six files.** This is
   maximally explicit and useful for automation review, but duplicates the
   already complete positive scope table and adds more prose than the defect
   needs.
6. **Delete the prerequisite-file non-goal.** Rely only on T2's positive
   six-file scope and changed-path assertions. This is behaviorally sufficient
   but loses useful handoff context about the stable prerequisite boundary.
7. **Use broad path globs.** Prohibit `.github/workflows/**` and
   `.gitattributes`. This accidentally forbids T2's required generator change
   and is less exact than named paths.
8. **Derive the list dynamically during implementation.** Compare the T1 commit
   and use its changed paths as the exclusion set. This adds Git-history
   dependency and can include incidental changes not part of T1's normative
   scope.
9. **List only the three omitted files as an addendum.** This repairs the facts
   but leaves the reader to merge two lists mentally and makes future review
   harder.

Options 2 and 5 provide the same boundary. Option 2 is preferable unless a
single consolidated scope matrix replaces—not duplicates—the existing
affected-files sections.

### Evaluation rubric

Scores run from 1 to 5 and produce a weighted total out of 100.

| Criterion | Weight | What a high score requires |
| --- | ---: | --- |
| Scope-boundary correctness | 26 | Every T1 implementation file is protected and no T2-required file is accidentally forbidden. |
| Cold-reader review clarity | 20 | The non-goal is understandable without cross-document reconstruction or Git history. |
| Resistance to interpretation drift | 15 | “T1 files,” implementation paths, and planning artifacts cannot be confused. |
| Handoff usability | 13 | An implementer or project manager can copy the issue and know the exact prohibited paths. |
| Changed-path oracle compatibility | 11 | The negative boundary agrees with T2's exact six-file working-tree and cached-path assertions. |
| Internal issue consistency | 9 | Affected files, prerequisites, non-goals, and acceptance criteria tell one story. |
| Maintenance/readability | 4 | The list is easy to update and does not duplicate large tables unnecessarily. |
| Editorial churn | 2 | The correction is proportionate; this is intentionally least important. |

Exact authorization boundaries outweigh deduplication. A self-contained
seven-path list is worth a few repeated lines in a handoff-ready issue.

### Scoring

Abbreviations: scope boundary (SB), cold-reader clarity (CR), interpretation
drift (ID), handoff usability (HU), changed-path compatibility (CO), internal
consistency (IC), maintainability (MT), and editorial churn (EC).

| Option | SB 26 | CR 20 | ID 15 | HU 13 | CO 11 | IC 9 | MT 4 | EC 2 | Weighted total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1. Keep four-file partial list | 2 | 3 | 2 | 3 | 5 | 2 | 4 | 5 | 56.0 |
| 2. List all seven files | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | **100.0** |
| 3. Say only “any T1 file” | 4 | 2 | 2 | 2 | 4 | 3 | 5 | 5 | 60.2 |
| 4. Heading-only cross-reference | 4 | 2 | 3 | 2 | 4 | 3 | 4 | 4 | 62.0 |
| 5. Consolidated T1/T2 scope table | 5 | 5 | 5 | 5 | 5 | 5 | 3 | 2 | 97.2 |
| 6. Delete the non-goal | 4 | 3 | 3 | 2 | 5 | 3 | 5 | 5 | 69.4 |
| 7. Use broad globs | 1 | 3 | 2 | 2 | 1 | 1 | 2 | 3 | 35.2 |
| 8. Derive from Git history | 3 | 1 | 2 | 1 | 3 | 2 | 1 | 1 | 39.6 |
| 9. Add only the omitted paths separately | 5 | 3 | 3 | 3 | 5 | 4 | 2 | 4 | 76.2 |

Option 2 is complete, self-contained, and smallest. A consolidated table is
nearly equivalent but would duplicate T2's existing positive scope without
materially improving the seven-path prohibition.

### Selected option and implementation contract

Select **option 2: list all seven T1 implementation files explicitly**.

Replace T2's partial prerequisite-file non-goal with:

- Do not modify any of T1's seven affected implementation files:
  - `.gitattributes`
  - `.github/dependabot.yml`
  - `.github/workflows/Generate-StyleGuideArtifacts.ps1`
  - `.github/workflows/Expand-StyleGuideCandidateArtifact.ps1`
  - `.github/workflows/Test-Expand-StyleGuideCandidateArtifact.ps1`
  - `.github/workflows/build.yml`
  - `.github/workflows/markdownlint.yml`

Keep the existing separate prohibition on
`.github/copilot-instructions.md`, the generated-artifact no-hand-edit rule,
and T2's exact six-file affected/working-tree/cached-path assertions.

During final slate validation, compare this list mechanically to T1's affected
files and require exact set equality. The order should match T1 to make visual
review easy.
