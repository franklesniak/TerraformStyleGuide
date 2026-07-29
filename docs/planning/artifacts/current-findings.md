# Current findings

## Overall assessment

The T1-then-T2 ordering, H1 titles, and T1/T2 nomenclature are sound. The slate
is materially stronger than the earlier drafts: it is repository-local,
downstream-neutral, explicit about the limits of cross-repository convergence,
and unusually precise about workflow identity, path containment, validation
evidence, and copy-safe recovery commands.

I would nevertheless return both issues for targeted corrections before
implementation:

- T1 has two release-blocking contradictions in its downloaded-artifact trust
  boundary: it does not bind extraction to the exact bytes that passed the
  digest check, and its global rejection postcondition cannot be true for
  preexisting candidate leaves or fail-closed cleanup failures.
- T2 overstates a conclusion that current AWS primary sources contradict and
  can expose the HCP Terraform token when the caller has already enabled Bash
  xtrace.

The remaining findings are lower-severity precision, maintenance, and test
quality improvements. They do not justify changing the issue order or
combining T1 and T2.

## Scope

- Review targets:
  - `docs/planning/TerraformStyleGuide/03TerraformStyleGuideT1.md`
  - `docs/planning/TerraformStyleGuide/04TerraformStyleGuideT2.md`
- Comparison context only:
  - `docs/planning/PSStyleGuide/01PSStyleGuideP1.md`
  - `docs/planning/PSStyleGuide/02PSStyleGuideP2.md`
- Supplied recommendations to adjudicate one by one:
  - `docs/planning/PSStyleGuide/slate-criticism.md`

T1 is assumed to execute before T2. P1/P2 are not independent review targets;
they are used only to evaluate deliberate generator unification and the
cross-repository claims made by T1/T2.

## Current-state anchors

- TerraformStyleGuide branch: `planning-CRT-PR-852`
- TerraformStyleGuide inspected commit:
  `194e27cf75140a6d922a7ca629d589030999967a`
- Current T1 SHA-256:
  `35E601B692DA48E8604E917164342F0ECEC4CEBAF0083C20073D76DC596F35A54`
- Current T2 SHA-256:
  `CDFE23458CFEBB64017CDE0898BDCE0BFA2187F0B5A54694D562D275E85BB334`

## Supplied-recommendation ledger

The current criticism contains nine numbered P1 recommendations plus a P2
assessment and recommended disposition. The dispositions below concern their
validity and any consequence for T1/T2; they do not turn this into a separate
P1/P2 critique.

### 1. Replace the claimed near-total P1/T1 identity with a convergence matrix

**Disposition: the underlying concern is confirmed; the current T1 wording has
already corrected the false-parity claim, but one substantive convergence gap
remains.**

The criticism correctly identifies material differences between P1 and T1. T1
now avoids saying that manifest names are the only difference. Lines 199–211
instead name the intended common public surface, state that the Terraform
requirements remain normative, require a preimplementation side-by-side
comparison, and prohibit the “only manifest names differ” claim unless the
contracts really match. A literal matrix would improve reviewability but is not
required for correctness.

The remaining live T1 consequence is archive identity: P1 hashes and extracts
through one continuously held stream, whereas T1 hashes by path and later
reopens the path as a ZIP. T1 should adopt the stronger same-held-stream
contract. Other differences—frontmatter work, repository-specific filenames,
Node/package decisions, and deliberately different matrix coverage—may remain
when named honestly.

### 2. Adopt T1's complete path-envelope validation in P1

**Disposition: technically valid; already present in T1.**

Current T1:

- resolves explicit checkout and trusted-temporary roots;
- requires them to be mutually non-overlapping;
- requires download and candidate paths to be strict descendants of the
  trusted root and outside checkout;
- walks every existing component from the volume/share root;
- rejects symlink, junction, volume-mount/reparse, dangling, type, attribute,
  resolution, and enumeration failures;
- rechecks at archive-open, candidate-creation, and post-extraction
  boundaries; and
- states the GitHub-hosted, job-owned, no-competing-writer residual race model.

It also requires root/ancestor-link fixtures and prevents a platform-wide skip.
No additional T1/T2 correction is needed for this recommendation.

### 3. Keep the held-stream design and select the sharing mode

**Disposition: confirmed; this reveals a high-priority T1 defect.**

P1's single-open, `Get-FileHash -InputStream`, rewind, and same-stream
`ZipArchive` design binds extraction to the bytes that were hashed. T1 instead
requires `Get-FileHash -Algorithm SHA256` by path and later ZIP opening. A path
replacement between those operations can change the extraction identity even
though the earlier digest matched.

T1 should open the retained archive exactly once with `FileMode.Open`,
`FileAccess.Read`, and an explicitly chosen sharing mode such as
`FileShare.Read`; hash that stream; require exactly one valid digest result;
rewind it; construct one read-mode `ZipArchive` over that same stream; and keep
the stream/archive lifetime continuous through manifest validation and
extraction. Hash-by-path followed by reopen must be prohibited. T1's stated
no-competing-writer model remains important because this is not a universal
OS-native sandbox.

### 4. Make rejection postconditions truthful and add fail-closed cleanup

**Disposition: confirmed; T1 has the cleanup implementation concept but repeats
the same impossible global oracle.**

T1's table includes preexisting candidate files, directories, links, and
reparse points that must be rejected without reuse or traversal. Its cleanup
contract also permits retaining a path when cleanup encounters an unsafe or
unreadable entry. Nevertheless:

- lines 519–523 require the destination directory to remain nonexistent for
  *every* rejection fixture; and
- acceptance line 1457 says every rejection leaves the candidate leaf absent.

Those statements contradict the preexisting-leaf cases and the documented
fail-closed retained-path outcome.

Replace them with per-case postconditions:

| Rejection class | Required candidate result |
| --- | --- |
| Initially absent; failure before creation | Remains absent |
| Preexisting file/directory/link/reparse leaf | Remains unchanged and is never followed |
| Controlled post-creation BOM or CR failure with only known ordinary helper-created entries | Safely cleaned; leaf absent |
| Cleanup revalidation finds an unexpected, changed, unreadable, link, or reparse entry | No recursive/following deletion; retained path plus primary and cleanup diagnostics |

T1 should also make BOM and CR independent fixtures and add a cleanup-safety
fixture that proves an unsafe substituted/extra entry is not followed or
deleted. Its current implementation rules for disposal, revalidation,
non-recursive deletion, and error preservation should remain.

### 5. Make the trusted temporary-path example satisfy its contract

**Disposition: valid for P1; no current T1 defect.**

T1 does not use P1's contradictory fixed
`${{ runner.temp }}/style-guide-candidate-download` example. It repeatedly
requires one unique job-owned trusted root outside checkout, a download
directory beneath it, and a separate initially nonexistent candidate path
beneath it. The implementation should still use one path-initialization step
and pass the exact resulting values to the download action, harness, and
helper, but T1's current normative text already requires the right
relationships.

### 6. Add an end-to-end malformed-transport drill

**Disposition: technically valid; already present in T1.**

T1 includes both an invalid/truncated ZIP in the permanent harness and a
controlled temporary-branch malformed-transport drill using the pinned upload
and download actions, `archive: false`, immutable ID/digest propagation,
production helper rejection, and downstream approval/writer skip. No further
T1/T2 correction is needed.

### 7. Add review-only GitHub Actions update governance

**Disposition: governance is already present in T1; the dated pin literals need
one current-state correction.**

T1 already requires full-SHA pins for every external action in both workflows,
same-line version comments, preimplementation metadata/runtime/input/output
verification, and weekly review-only GitHub Actions Dependabot without
auto-merge.

However, its “as of 2026-07-29” checkout and setup-node literals are already
behind the official releases used by P1: checkout v7.0.1 and setup-node v7.0.0
were available before that date. T1's preimplementation revalidation prevents
blind implementation of stale values, but the issue should not retain a false
dated-current claim. Update the literals and release references to the current
approved full SHAs after compatibility review, or explicitly document why v6
is the approved ceiling. Do not downgrade P1 merely for cosmetic equality.

### 8. Track the current npm advisories as actual work

**Disposition: confirmed as a cross-repository maintenance concern and a
current T1/T2 planning gap.**

The TerraformStyleGuide lockfile produces the same current audit summary as
PSStyleGuide: seven vulnerable package nodes, five high and two moderate, in
the Markdown tooling dependency graph. T1 explicitly prohibits dependency
changes and Dependabot ecosystems other than GitHub Actions. Keeping those
changes out of an already large workflow/security issue is defensible, but
leaving them untracked is not.

Create and link a separately scoped dependency-remediation issue with an
explicit ordering decision. Ordinarily it can follow T2 to keep T1/T2's lint
baseline stable; if repository policy blocks known high-severity advisories,
make it a prerequisite and rebaseline the issues. Include npm Dependabot for
`/.github/workflows`, audit disposition, and the existing outer/nested lint
suite. T1's read-only pull-request permissions limit impact but do not fix
vulnerable parsers processing pull-request Markdown.

### 9. Keep CI evidence wording exact

**Disposition: technically valid; already addressed in T1 and inherited
accurately by T2.**

T1 deliberately runs the tracked harness in all four Windows pull-request
cells, all four Windows push cells, Ubuntu pull-request verification, and the
writer only when `has_changes=true`. It distinguishes no-drift writer skip
evidence from controlled change-producing writer evidence. T2 accurately
requires four successful push cells and a skipped writer whose steps did not
run. No further correction is needed.

### Supplied P2 assessment and recommended disposition

**Disposition: reasonable as P1/P2 context; it does not create a T2 content
requirement.**

The criticism's P2 conclusion is consistent with the supplied P2 text: P2 uses
the script-block validator, explicit four-middle-dot visualization, drift-only
metadata snapshot, and precise no-drift writer semantics. Its recommendation
not to import Terraform recovery content into P2 is correct. T2 should inherit
the final T1 prerequisite accurately, but its provider-specific recovery
guidance remains unrelated to P2.

## Independent T1/T2 review

### T1-1 — The digest check and ZIP read do not have the same file identity

**Severity:** high

**Evidence.** T1 requires component checks, then a path-based
`Get-FileHash -Algorithm SHA256`, then a later ZIP open. Its no-competing-writer
model reduces ordinary risk but does not make those two path resolutions the
same object. P1's proposed continuously held stream avoids this particular
identity gap. PowerShell 5.1 and current PowerShell both expose
`Get-FileHash -InputStream`, and .NET permits an explicit
`FileMode`/`FileAccess`/`FileShare` choice.

**Impact.** A retained archive path replaced after the digest read but before
the ZIP open can cause unverified bytes to reach manifest inspection and
extraction. That violates T1's core claim that the downloaded artifact is bound
to the upload action's propagated digest.

**Required correction.**

1. Complete the existing path and ordinary-file checks.
2. Open the retained archive once using `FileMode.Open`, `FileAccess.Read`, and
   a consciously selected sharing mode. `FileShare.Read` is a reasonable
   cross-edition choice because it permits other readers while denying a new
   writer or deleter through ordinary sharing semantics; document the residual
   platform and privileged-writer limits.
3. Pass that `FileStream` to `Get-FileHash -InputStream -Algorithm SHA256`.
4. Require exactly one digest result and compare it to the expected digest.
5. If it matches, rewind the same stream to position zero.
6. Construct one read-mode `ZipArchive` over that exact stream.
7. Keep the stream and archive continuously alive through full manifest
   validation and extraction, then dispose them before any cleanup.
8. Explicitly prohibit hash-by-path followed by reopen.
9. Add a harness assertion or reviewed implementation check proving the same
   stream instance is used for hashing and ZIP processing under both supported
   PowerShell editions.

This is also the unresolved consequence of supplied recommendation 3.

### T1-2 — The rejection oracle contradicts valid preexisting and fail-closed states

**Severity:** high

**Evidence.** T1 correctly requires preexisting candidate files, directories,
links, reparse points, and dangling links to be rejected without reuse or
traversal. It also correctly says an unsafe or unreadable cleanup entry must be
retained and reported rather than followed or recursively deleted. But the
fixture-wide rule requires the destination to remain nonexistent for every
rejection, and the acceptance criteria repeat that every rejection leaves the
candidate leaf absent.

**Impact.** An implementation cannot satisfy both requirements. A test author
must either delete an entry T1 says to preserve, weaken the test, or report a
false failure. More seriously, a cleanup implementation could be encouraged to
delete through an unsafe substituted entry merely to satisfy the global
absence oracle.

**Required correction.** Replace the global absence rule with explicit
case-specific outcomes:

| Rejection class | Required candidate result |
| --- | --- |
| Candidate initially absent; failure occurs before helper creation | Remains absent |
| Candidate file, directory, link, reparse point, or dangling link already exists | Original entry remains unchanged and is never followed |
| Controlled post-creation content failure containing only known ordinary helper-created entries | Files are safely deleted non-recursively and the helper-created leaf is removed |
| Cleanup revalidation finds an unexpected, changed, unreadable, link, or reparse entry | Entry is not followed or recursively deleted; retained path and both primary and cleanup diagnostics are reported |

Also:

- split the combined BOM-or-CR fixture into one BOM fixture and one CR fixture,
  so either branch cannot accidentally satisfy both requirements; and
- add a cleanup-safety fixture that substitutes or introduces an unsafe entry
  after controlled creation and proves the helper neither follows nor deletes
  it.

Retain T1's existing disposal order, envelope revalidation, non-recursive
deletion, original-error preservation, and nonzero return requirements. This
is also the unresolved consequence of supplied recommendation 4.

### T2-1 — The AWS KMS reconciliation is not supported consistently by current AWS documentation

**Severity:** high

**Evidence.** T2 says general-purpose SSE-KMS and DSSE-KMS retrieval needs
`kms:Decrypt`, that `kms:GenerateDataKey` belongs to upload/destination paths
rather than this download path, and that the sources differ because they cover
different bucket classes or operations. Current AWS sources do not divide that
cleanly:

- the SSE-KMS user guide describes `GenerateDataKey` for `PutObject` and a
  `Decrypt` request during download;
- the S3 policy-action table conditionally associates `kms:Decrypt` with
  `GetObject`/`GetObjectVersion`; but
- the current `GetObject` API reference says an SSE-KMS retrieval requires both
  `kms:GenerateDataKey` and `kms:Decrypt` in IAM and KMS key policies.

The last statement appears in the general `GetObject` authorization material,
not only in a directory-bucket subsection. T2's bucket-class explanation
therefore does not reconcile all three primary sources.

**Impact.** A copy-safe recovery example can still fail for an operator who
grants only the categorically described permission, while a security reviewer
cannot tell whether the issue intentionally resolved or accidentally ignored
an official documentation conflict.

**Required correction.**

1. Preserve the statements that SSE-S3 needs no KMS authorization, SSE-C is out
   of scope, and effective authorization depends on identity policy, key
   policy, grants, encryption mode, and account topology.
2. Say that `kms:Decrypt` is consistently documented for KMS-encrypted
   retrieval.
3. Explicitly disclose that the current `GetObject` API reference additionally
   lists `kms:GenerateDataKey`, while the general SSE-KMS guide and
   policy-action table describe retrieval with `kms:Decrypt`.
4. Do not infer that `kms:GenerateDataKey` is categorically absent from this
   path until AWS resolves or the implementation revalidates the discrepancy.
5. Direct the implementer/operator to verify the current documentation and the
   actual bucket/encryption/key-policy/account configuration, then grant the
   least privilege that succeeds. If desired, open an AWS documentation issue
   separately; this GitHub issue need not resolve AWS's inconsistency.
6. Keep directory buckets out of the historical-version recovery procedure.

### T2-2 — Inherited Bash xtrace can print the HCP token before the warning applies

**Severity:** medium

**Evidence.** The HCP section says not to use `set -x`, but the example assigns
the guarded `TFC_TOKEN` inside a subshell without first disabling an inherited
xtrace setting. Bash traces expanded commands and arguments. A local
synthetic-token test confirmed that an inherited `set -x` prints
`TFC_TOKEN=SYNTHETIC-TRACE-MARKER`; placing `set +x` first in the subshell
prevents that value from being traced.

**Impact.** A token can enter terminal output, CI logs, shell capture, or support
transcripts even though T2 correctly keeps it out of curl's ordinary argument
list. The curl protection and the shell-trace protection are different
boundaries.

**Required correction.**

1. Make `set +x` the first command inside the HCP subshell, before any guarded
   expansion or assignment of `TFC_TOKEN`.
2. Retain the prose prohibition against tracing and explain that `set +x`
   protects against inherited xtrace, while the operator must still avoid
   external wrappers that log input or environment data.
3. Add a validation case that enters the block with xtrace enabled and uses
   only a synthetic sentinel token; fail if the sentinel appears in captured
   standard output or standard error.

### T1/T2-1 — Current Markdown-tooling advisories are deliberately excluded but untracked

**Severity:** medium

**Evidence.** On 2026-07-29,
`npm audit --package-lock-only --json` in `.github/workflows` exited 1 and
reported seven vulnerable package nodes: five high and two moderate. The nodes
were `brace-expansion`, `js-yaml`, `linkify-it`, `markdown-it`,
`markdownlint-cli2`, `minimatch`, and `picomatch`. T1 prohibits dependency
changes and any Dependabot ecosystem other than GitHub Actions; T2 preserves
that prerequisite baseline.

**Impact.** Scope control is reasonable, but the current slate leaves known
high-severity parser/tooling findings without an owner or ordering decision.
Pull-request Markdown is untrusted repository content even when workflow
permissions are read-only.

**Required correction.** Create a separate, linked dependency-remediation
issue. Include:

- npm Dependabot coverage for the manifest location
  `/.github/workflows`;
- an explicit disposition for direct and transitive audit findings;
- lockfile regeneration;
- the existing outer and nested Markdown lint suites; and
- a stated order relative to T1/T2.

Default to after T2 to preserve the carefully specified lint baseline. Move it
before T1 only if repository policy blocks work while high-severity advisories
remain. Do not silently expand T1 with package upgrades. This is also the live
consequence of supplied recommendation 8.

### T1-3 — Two action pins are stale despite a dated current-state claim

**Severity:** medium

**Evidence.** T1 says “As of 2026-07-29, use” checkout v6.1.0 and setup-node
v6.5.0. Official releases available before that date include:

- checkout v7.0.1 at
  `3d3c42e5aac5ba805825da76410c181273ba90b1`, released July 20; and
- setup-node v7.0.0 at
  `820762786026740c76f36085b0efc47a31fe5020`, released July 14.

T1 separately requires immediate preimplementation verification, which limits
implementation risk but does not make the dated literals accurate.

**Impact.** Reviewers may approve pins based on a false currency claim, and the
intended cross-repository convergence can diverge unnecessarily.

**Required correction.** Revalidate the v7 actions' runtime, runner
compatibility, inputs, outputs, and changelogs. If approved, replace the two
pins and comments with the current full SHAs and release labels. If a v6
ceiling is deliberate, retain v6 only with an explicit compatibility or risk
rationale and change “current” wording to “approved.” Keep full-SHA pinning,
review-only weekly GitHub Actions Dependabot, and the no-auto-merge rule.

### T2-3 — “Versioning-capable” does not state the prerequisite for historical S3 recovery

**Severity:** low

**Evidence.** T2 calls the target a “versioning-capable general-purpose
bucket.” S3 Versioning is disabled by default. Historical versions exist only
if versioning was enabled before the relevant writes and retention/lifecycle
rules have not removed the selected version. A bucket may currently be
versioning-enabled or versioning-suspended and still retain earlier versions.

**Impact.** A new operator may read “capable” as sufficient and expect
`list-object-versions` to recover history that was never created or has already
expired.

**Required correction.** State that the example targets a general-purpose
bucket on which S3 Versioning was enabled before the desired historical version
was created, and that the version must still be retained. Explain that the
bucket can now be `Enabled` or `Suspended`; default-never-enabled buckets do not
have the required history. Do not add version selection automation.

### T1-4 — Local validation labels editions without verifying them in the child process

**Severity:** low

**Evidence.** The local validation block labels any resolved `pwsh` application
as “PowerShell 7” and any resolved `powershell` application as “Windows
PowerShell 5.1,” then launches the harness and generator. Unlike the CI
contract, it does not assert `$PSVersionTable.PSEdition` and major/version
identity in that exact child process.

**Impact.** A PATH shim or a future unsupported `pwsh` major can produce
apparently valid local evidence for the wrong runtime. CI still supplies the
authoritative coverage, so this is not a release blocker.

**Required correction.** Invoke a small checked script block or tracked entry
point in each child process that first asserts Desktop 5.1 or Core major 7 and
then runs the harness/generator in that same process. Avoid a parent-process
assertion or an edition-neutral dispatcher, because neither proves the helper's
actual runtime.

### T2-4 — The prerequisite-file non-goal is incomplete

**Severity:** low

**Evidence.** T2 says not to modify the prerequisite issue's files but names
only four of T1's seven affected implementation files. It omits:

- `.github/dependabot.yml`;
- `.github/workflows/Test-Expand-StyleGuideCandidateArtifact.ps1`; and
- `.github/workflows/markdownlint.yml`.

T2's exact six-file positive scope elsewhere prevents accidental expansion, so
this is a documentation inconsistency rather than an authorization gap.

**Required correction.** List all seven T1 files or replace the partial list
with an unambiguous statement that none of T1's seven affected implementation
files may change, followed by the complete list. Keep T2's six-file changed-path
and cached-path oracles.

## Confirmed strengths to preserve

- Keep the issue titles as H1 headings and retain T1/T2 nomenclature and
  execution order.
- Keep `* text=auto eol=lf` as the repository-wide checkout policy and keep the
  generator's explicit byte serialization as the common artifact boundary.
  `.gitattributes` checkout normalization is not a replacement for explicit
  UTF-8-without-BOM/LF serialization.
- Keep T1 repository-local and self-contained. Cross-repository convergence
  should share public helper parameters, security invariants, fixture concepts,
  diagnostics, and maintenance policy without making one repository depend on
  the other at build time.
- Keep T1's full component walk, mutually non-overlapping checkout/trusted
  roots, repeated boundary checks, tracked permanent harness, four-cell Windows
  coverage, Ubuntu coverage, exact writer-ref identity, immutable
  artifact-ID/digest propagation, and malformed-transport drill.
- Keep T1's distinction between no-drift writer-skip evidence and controlled
  change-producing writer evidence.
- Keep T2's exact-key/provider-identifier discovery, guarded quoted
  identifiers, destination preflights, provider-native no-clobber controls,
  explicit non-atomicity model, manual selection, and retrieval-copy rather
  than rollback posture.
- Keep the Azure non-HNS, GCS Object Versioning versus soft-delete, and HCP
  manual-pagination boundaries. They are appropriately narrow and
  provider-neutral with respect to downstream adopters.
- Keep the six-file T2 scope, generated-artifact workflow, version/date
  consistency checks, and exact four-cell push evidence.

## Recommended disposition and execution order

1. **Amend T1 before implementation.** Resolve T1-1 and T1-2 as blockers.
   Correct or justify the action versions, strengthen local edition assertions,
   and link the separately ordered npm-remediation work.
2. **Amend T2 after T1 is final.** Update its prerequisite summary if T1's
   contract changes. Resolve the AWS KMS documentation conflict and inherited
   xtrace exposure, then make the S3 applicability and non-goal wording exact.
3. **Keep T1 before T2.** T2 depends on T1's generator, clean-worktree, and
   workflow baseline; the findings do not support merging or reordering them.
4. **Track npm maintenance separately.** Place it before T1 only if policy
   requires remediation of current high advisories first; otherwise place it
   after T2 to avoid moving the lint baseline during both issues.

With these corrections, the slate is suitable to hand to implementers. P1/P2
remain comparison context, not additional critique targets or prerequisites
for the TerraformStyleGuide repository.

## Validation performed

- Read T1 and T2 in full and reviewed them in execution order.
- Adjudicated all nine numbered recommendations and the P2 assessment in
  `slate-criticism.md`.
- Used P1/P2 only as comparison context for convergence and stated prerequisite
  behavior.
- Compared the planning branch with the current TerraformStyleGuide and
  PSStyleGuide repository baselines.
- Parsed all seven T2 Bash fences with `bash -n`; all returned zero.
- Reproduced the inherited-xtrace exposure with a synthetic token and confirmed
  that a first-command `set +x` suppresses the assignment trace.
- Ran the lockfile-only npm audit and recorded only package names and aggregate
  severity counts.
- Rechecked unstable action and provider claims against current primary
  sources on 2026-07-29.

## Primary references

### T1 and repository maintenance

- [Microsoft Learn: `Get-FileHash`, including the PowerShell 5.1 stream parameter set](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash?view=powershell-5.1)
- [Microsoft Learn: `File.Open` with explicit mode, access, and sharing](https://learn.microsoft.com/en-us/dotnet/api/system.io.file.open)
- [GitHub: checkout v7.0.1 release](https://github.com/actions/checkout/releases/tag/v7.0.1)
- [GitHub: checkout v7.0.1 full-SHA commit](https://github.com/actions/checkout/commit/3d3c42e5aac5ba805825da76410c181273ba90b1)
- [GitHub: setup-node v7.0.0 release](https://github.com/actions/setup-node/releases/tag/v7.0.0)
- [GitHub: setup-node v7.0.0 full-SHA commit](https://github.com/actions/setup-node/commit/820762786026740c76f36085b0efc47a31fe5020)
- [GitHub Docs: keeping actions up to date with Dependabot](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/auto-update-actions)
- [GitHub Docs: configuring Dependabot version updates](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/configuring-dependabot-version-updates)
- [npm Docs: `npm audit`](https://docs.npmjs.com/cli/v11/commands/npm-audit/)

### T2

- [AWS: `GetObject` API authorization and SSE-KMS statement](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html)
- [AWS: using SSE-KMS in general-purpose S3 buckets](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html)
- [AWS: required permissions for S3 API operations](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-with-s3-policy-actions.html)
- [AWS: retaining multiple versions with S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [GNU Bash manual: `set`, including xtrace and noclobber](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
- [Curl manual: command-line and configuration-file behavior](https://curl.se/docs/manpage.html)
- [HashiCorp: HCP Terraform state-versions API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/state-versions)
