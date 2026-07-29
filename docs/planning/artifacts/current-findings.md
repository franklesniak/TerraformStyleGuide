# Findings on the TerraformStyleGuide T1/T2 issue slate

## Scope and review basis

This review assesses
[T1](../TerraformStyleGuide/03TerraformStyleGuideT1.md) and
[T2](../TerraformStyleGuide/04TerraformStyleGuideT2.md) as sequential issues,
with T1 implemented before T2. The PSStyleGuide P1/P2/P3 drafts were consulted
only where T1/T2 claim or require cross-repository convergence; they are not
independently critiqued here.

The review also evaluates every recommendation in the supplied
[TerraformStyleGuide slate criticism](../TerraformStyleGuide/slate-criticism.md).
“Confirmed” means the criticism identifies a real gap. It does not necessarily
mean its severity or exact remedy is accepted.

Current-state checks included the repository workflows, generator-related
surfaces, Markdown package manifest and hook, state-management source sections,
the corresponding PSStyleGuide contracts, current Node release status, the
named action tags, HCP Terraform API/Europe documentation, and curl config-file
grammar.

## Overall assessment

The proposed work is technically serious and security-conscious, but the slate
is not ready to file unchanged.

The most important blockers are:

1. T1 explicitly preserves Node 20 even though Node 20 is now end-of-life.
2. T1 and T2 require a real linked npm-remediation issue, but the slate has no
   Terraform T3 draft.
3. T1 leaves several executable contracts underspecified: trusted-root
   creation, harness case IDs, writer input normalization, and exact action
   tuple validation.
4. T2's HCP example does not support the documented Europe host and does not
   validate its page number or curl-config-sensitive token characters.
5. T2 supplies behavioral evidence only for HCP xtrace, not for the four
   published recovery/discovery blocks as a whole.
6. Independent of the supplied criticism, T1 is approximately 2,000 lines and
   94 KB and combines deterministic serialization, repository text policy,
   action governance, a cross-platform secure ZIP subsystem, and an automated
   write pipeline. It is an epic-sized specification, not a reviewable
   single-purpose issue.

The generator-convergence direction is sound: converge observable algorithms
and failure semantics while keeping each repository self-contained. The same
approach should replace T1's now-stale hypothetical helper-convergence prose.

## Current-state anchors

- T1 is 93,982 bytes and 2,030 lines; T2 is 40,506 bytes and 912 lines.
- The live Markdown workflow selects Node 20. The current nested package
  manifest has no `engines.node`, `packageManager`, or
  `devEngines.packageManager` field, and the Husky hook has no Node-major
  guard.
- Registry metadata for the installed direct lint versions,
  `markdownlint-cli2@0.20.0` and `markdownlint@0.40.0`, declares Node `>=20`.
  Moving only the hosted workflow to Node 24 is therefore within those declared
  engine ranges and does not itself require a package or lockfile change.
- A fresh `npm audit --package-lock-only --audit-level=moderate --json` on
  2026-07-29 with npm 11.7.0 returned the documented vulnerability exit and
  the same seven affected nodes: five high and two moderate. Their
  object-valued `via` entries expose 14 distinct advisory URLs; string-valued
  `via` links are a separate relationship and must also be traversed by T3.
- All seven T2 Bash fences pass `bash -n` after normalizing the planning
  checkout's CRLF transport to LF. This establishes syntax only, not the
  behavioral contracts discussed below.
- The live source contains copy-sensitive state operations outside T2's four
  target blocks, including backup redirections in `STYLE_GUIDE.md` and
  `STYLE_GUIDE_RATIONALE.md`, plus corruption recovery using
  `terraform state push`.

## Recommendation-by-recommendation audit

### T1-1: The action pins are current, but the installed Node target is not

**Decision: Confirmed. The defect is real; the proposed ownership choice is
reasonable but not the only coherent remedy.**

T1 lines 730–731 require preserving Markdown lint's existing Node behavior,
lines 788–790 prohibit changing the Node version, and lines 908–914 put the npm
issue after T2 by default. The live workflow selects Node 20.

The current Node release table identifies Node 20 as EOL and Node 24 as LTS.
The four action tag/SHA pairs named by T1 were independently resolved from the
official repositories and match the draft.

Preferred correction if the order remains T1 → T2 → T3:

- T1 should change only the hosted lint runtime to Node 24, explicitly set
  `package-manager-cache: false`, assert the actual Node major before
  installation, and run the existing clean install plus both lint commands.
- T1 should continue to prohibit dependency, lockfile, lint-rule, and hook-floor
  changes; those remain T3 work.
- T2 should treat hosted Node 24 as a merged T1 invariant.

The alternative is to draft and execute T3 first, then rebaseline T1 and T2.
What is not coherent is preserving an EOL runtime through T1 and T2 while
leaving the issue that owns the replacement unfiled and last.

The cache setting is worth making explicit even though the current package
manifest does not activate setup-node's automatic npm cache. This prevents a
later `packageManager` or `devEngines.packageManager` field from silently
changing the workflow's cache behavior.

Primary source:
[Node.js release status](https://nodejs.org/en/about/previous-releases).

### T1-2: The caller-owned trusted-root factory is still undefined

**Decision: Confirmed as an implementation-contract gap; severity is Medium,
not High under T1's hosted-runner/no-competing-writer threat model.**

T1 repeatedly requires a “unique trusted temporary root,” but it defines only
helper-side validation. It does not define how workflow and harness callers
establish uniqueness and ownership, nor does it give them a consistent
nonrecursive teardown contract. A careless implementation can use
`Directory.CreateDirectory()` or `New-Item -Force` and silently accept a
pre-existing child.

Add a normative caller contract covering:

- normalized runner-controlled parent;
- bounded retries around `Path.GetRandomFileName()`;
- absence, create-without-force, then ordinary/non-reparse verification;
- retry only for a proved collision;
- separate download and initially absent candidate children;
- absolute path propagation; and
- caller-owned, journaled, nonrecursive `finally` teardown that preserves the
  primary error and reports cleanup failure.

The criticism's algorithm is appropriate. “Reuse one factory” needs a concrete
home, however. If that means another tracked script, T1's exact seven-file
boundary must change. If the contract is repeated in workflow blocks, the issue
should require one reviewed implementation pattern and parity tests rather than
pretend there is one shared function.

Primary source:
[Path.GetRandomFileName](https://learn.microsoft.com/dotnet/api/system.io.path.getrandomfilename).

### T1-3: The harness promises stable IDs but still groups distinct cases

**Decision: Confirmed; severity is Medium.**

T1 requires stable case identifiers, but its oracle table supplies prose
classes and combines materially distinct cases. A future implementation could
technically assign IDs, but the issue would not prove that every listed
permutation received one executable case. This is especially weak for
cross-repository parity and platform skip accounting.

Split the grouped rows and assign stable IDs in the issue. Add:

- a supplied-label induced failure;
- an equivalent all-labels-omitted failure requiring `unavailable`; and
- separate empty-value cases for `ArtifactId`, `RunId`, and `RunAttempt`.

Each row should state platform/precondition, expected phase, diagnostic fields,
candidate initial/final state before harness teardown, and whether
`ZipArchive` construction is permitted.

The criticism is right about the missing omitted-label failure. The existing
omitted-label success proves formatting on success, not the fallback carried
by a failure diagnostic.

### T1-4: Writer inputs are not normalized to a one-read contract

**Decision: Confirmed, with a correction to the criticism's comparison.**

T1 copies only `TARGET_REF` and `EXPECTED_SHA`, checks nonemptiness and a
`refs/heads/` prefix, then compares against ambient `GITHUB_REF` and
`GITHUB_SHA`. It does not reject whitespace or CR/LF and does not run
`git check-ref-format`.

Require one-time locals for all four values; reject missing/empty,
leading/trailing whitespace, and CR/LF; validate the full branch ref with
`git check-ref-format`; compare only the locals; and reuse them unchanged for
checkout, remote, parent, lease, and refspec proofs.

The criticism says this “matches P1,” but current P1 actually copies only
`TARGET_REF` and `EXPECTED_SHA` at its first boundary, reads `GITHUB_REF` and
`GITHUB_SHA` once during comparison, and then prohibits all four rereads. The
criticism's proposed four-local rule is stronger than P1's literal text. It is
still a clean convergence improvement and should be applied to both drafts if
exact symmetry is intended.

Because all four values originate from GitHub-controlled contexts, this is
primarily fail-closed validation and maintainability, not a demonstrated
high-likelihood exploit.

### T1-5: The directly tested cleanup function is never actually named

**Decision: Partially confirmed as a convergence/clarity improvement; denied as
a High-severity correctness defect.**

T1 already requires one named function in the exact production helper, requires
the production failure path to invoke it, requires the harness to call that
same exact production function directly, and prohibits copied cleanup logic or
a test wrapper. A compliant implementation cannot choose unrelated production
and harness functions merely because the issue does not preselect the
identifier.

Using P1's `Remove-StyleGuideCandidateInvocationState` name is nevertheless
desirable if the helper contracts are intentionally converging. Add the exact
name to T1's lifecycle, harness, validation, acceptance, and T2 prerequisite
text. Treat this as Low-severity specification closure rather than evidence
that the current contract permits two cleanup implementations.

The recommendation to resolve helper and harness files to ordinary absolute
paths before launching children is valid independently and should be retained.

### T1-6: The action-pin verifier accepts unreviewed full-SHA tuples

**Decision: Confirmed; severity is Medium.**

T1's automated/static instruction checks only SHA shape and a nonempty version
comment, followed by a separate manual upstream review. A substituted 40-hex
commit and plausible comment can pass the shape check.

Add an exact repository → SHA → version allowlist plus workflow-role rules.
Reject unknown action repositories, tuple mismatches, and roles in unapproved
workflows. The implementation-time upstream check still controls freshness;
when it selects a newer approved release, update the allowlist, table, comments,
and evidence atomically.

The current tuples do resolve exactly:

| Action | Tag | SHA |
| --- | --- | --- |
| `actions/checkout` | `v7.0.1` | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/setup-node` | `v7.0.0` | `820762786026740c76f36085b0efc47a31fe5020` |
| `actions/upload-artifact` | `v7.0.1` | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` |
| `actions/download-artifact` | `v8.0.1` | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` |

The criticism overstates this as High severity because T1 also mandates
implementation-time official-repository verification. The gap is that the
checked-in state is not mechanically bound to the result of that review.

### T1/T2-1: Helper convergence is hypothetical and T2 duplicates T1

**Decision: Confirmed.**

T1's generator matrix is concrete and reciprocal. Its helper text still says
the Terraform rules govern “even if” P1 has not adopted them, although current
P1 already has a convergence matrix and many shared contracts. Replace this
with a current reciprocal matrix covering parameters, archive identity, path
security, manifest grammar, lifecycle, diagnostics, fixtures, transport, and
intentional CI-placement differences.

Use the same first/second-mover evidence rule as the generator. Keep scripts,
manifests, names, and transforms repository-local.

T2's prerequisite is too large and already depends on details that the
criticism proposes changing. After T1 and T3 are final, T2 should link to their
actual issues and merged acceptance evidence, summarize only the invariants T2
relies on, and stop restating their implementation specifications.

### T1/T2-2: The required npm-remediation issue does not exist

**Decision: Confirmed; this is a High-severity slate-completeness defect.**

T1 says a real separately reviewable linked issue must exist before T1 closes.
T2 treats that issue as a prerequisite invariant. The planning directory has no
`05TerraformStyleGuideT3.md`. Detailed seed requirements embedded in T1/T2 do
not create a fileable, independently orderable issue.

Draft T3 now, retain its title as an H1, and link it reciprocally. T3 should own
the Terraform repository's real full-lint Husky integration rather than copy
PSStyleGuide's nonexistent-here staged-content API. The criticism's proposed
T3 scope is directionally correct:

- final package and lockfile selection;
- final package minimum plus hosted Node policy;
- `engines.node` and hook guard;
- clean install, `npm ls --all`, positive/negative/tooling-failure evidence;
- a tracked cross-platform integration harness and at least one real installed
  Husky invocation;
- normalized audit/advisory/path evidence and structured expiring residual
  approvals;
- exact npm Dependabot policy/final state; and
- explicit supersession of T1/T2's one-time path and intermediate Dependabot
  gates.

Remove T1's “documented equivalent evidence” escape hatch for the real
installed-hook smoke test. T3 should require at least one actual disposable
repository invocation.

The final filing/implementation order must be explicit:

- T1 → T2 → T3 only if T1 establishes Node 24 and policy permits the current
  advisories to remain through T2; or
- T3 → T1 → T2 if Node ownership stays in T3 or policy requires advisory
  remediation first.

### T2-1: The HCP block has endpoint and input-grammar gaps

**Decision: Confirmed in full; severity is High.**

The HCP example hardcodes `app.terraform.io`, accepts arbitrary page values, and
interpolates the token into curl's quoted config-file grammar without rejecting
characters that can alter that grammar.

Add a closed host selector accepting only:

- `app.terraform.io`; and
- `app.eu.terraform.io`.

Reject every other value before token expansion or response-file creation.
Construct the HTTPS URL only from the accepted host. Explicitly keep Terraform
Enterprise out of scope; arbitrary enterprise hosts require a separate
certificate, redirect, and token-destination trust contract.

Require `TFC_PAGE_NUMBER` to match canonical positive decimal syntax
(`^[1-9][0-9]*$`) before file creation. Reject token values containing CR, LF,
double quote, backslash, or other control characters before producing curl
config input, unless a separately specified escaping algorithm is used and
behaviorally tested.

HashiCorp documents `app.eu.terraform.io` as the Europe hostname. Curl documents
that quoted config parameters recognize backslash escapes and require
quote/backslash handling, so ordinary shell quoting alone is not a sanitizer.

Primary sources:

- [HCP Terraform in Europe](https://developer.hashicorp.com/terraform/cloud-docs/europe)
- [HCP Terraform state versions API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/state-versions)
- [curl config-file grammar](https://curl.se/docs/manpage.html)

### T2-2: The state-safety quantifier exceeds the issue inventory

**Decision: Partially confirmed.**

The live source contains state operations outside the four target blocks,
including `terraform state pull` backup redirections, `terraform state push`,
state removal, another S3 version-listing example, and corruption-recovery
guidance. T2 does not harden those locations.

The phrase “every recovery destination” can reasonably be read as scoped to the
blocks modified by this issue, so the criticism overstates the present wording
as a universal claim. Still, the issue should remove doubt:

- say “every destination introduced or modified by this issue”;
- name the four S3/Azure/GCS/HCP blocks as the exact scope;
- inventory nearby state operations as reviewed but out of scope; and
- open a follow-up only for locations that the inventory finds copy-unsafe,
  rather than presuming every adjacent operation belongs in T2.

Do not expand T2 into all state-management guidance. The provider-neutral
sensitive-state warning should remain.

### T2-3: Only the HCP xtrace behavior is executed

**Decision: Confirmed.**

Syntax review and one HCP xtrace stub are not enough evidence for shell examples
whose selling point is copy safety. Require non-network behavioral tests of the
exact finalized blocks, with `aws`, `az`, `gcloud`, and `curl` stubs and exact
argument-vector capture.

At minimum cover:

- `bash -n`;
- missing/empty/relative/existing/file/directory/link/dangling-link
  destinations before provider invocation;
- literal paths containing spaces and shell metacharacters;
- unchanged selected IDs/generations;
- exact provider filters and native no-clobber flags;
- both HCP hosts, invalid host classes, valid/invalid page values, and
  config-breaking token values;
- inherited xtrace;
- simulated curl failure and retained invalid partial output; and
- expected rejection reason, not merely any nonzero status.

The criticism allows an untracked temporary harness to preserve T2's six-file
scope. That is acceptable as implementation evidence, but a tracked harness is
better regression protection if the maintainer is willing to change the file
boundary. The issue must choose explicitly.

### T2-4: Local npm validation does not establish the T1 runtime boundary

**Decision: Confirmed if T1 owns Node 24; otherwise parameterize it to the merged
T3 contract.**

T2 runs ambient `npm` without checking `node`, does not bind one node/npm
executable pair, and does not explicitly scope `CI=true` around `npm ci`.

After the ordering decision, T2 should resolve one application pair, assert the
merged required Node major before installation, record npm version, reuse the
same npm executable for installation and both lint commands, and restore the
prior `CI` environment value in `finally`.

This is validation discipline only. T2 must not update dependencies or
lockfiles.

## Independent findings

### I-1: T1 is an epic disguised as one issue

**Severity: High planning and review risk.**

T1 is roughly 2,000 lines/94 KB. Its title foregrounds deterministic generation
and LF checkouts, but its acceptance surface also includes:

- action pinning and Dependabot policy;
- least-privilege workflow permissions and event redesign;
- a new secure cross-platform ZIP validator/extractor;
- a permanent multi-platform adversarial harness;
- immutable artifact promotion;
- four-cell Windows pull and push matrices;
- an approval stage and exact-lease automated writer; and
- cross-repository generator/helper convergence.

These concerns are related, but they are not one review unit. A defect in the
custom archive subsystem can block a straightforward serialization fix, and a
reviewer must validate too many trust boundaries at once.

The same normative requirements are repeated in requested changes, validation,
acceptance criteria, T2's prerequisite, and cross-repository drafts. That
repetition has already produced the stale helper-convergence wording and makes
future drift likely. Each child issue should have one normative contract, with
validation and downstream prerequisites linking to it rather than paraphrasing
it.

Preferred correction: treat the current document as an epic/design record and
create sequential child issues for:

1. deterministic serialization, script version, and `.gitattributes`;
2. helper plus tracked harness and convergence;
3. workflow permissions, immutable candidate transport, matrices, approval,
   and writer; and
4. Node/package governance (the proposed T3, ordered according to policy).

If the maintainer deliberately keeps T1 atomic, record that decision and expect
one correspondingly large PR. In that case, all criticism corrections must be
integrated before filing because review-time discovery will be expensive.

### I-2: T2 should validate the GCS generation grammar

**Severity: Low to Medium.**

T2 describes the selected GCS generation as numeric but only checks that
`GCS_GENERATION` is nonempty. Quoting prevents shell injection, and gcloud
should reject an invalid generation, but the example can fail earlier and more
clearly.

Require the selected generation to match canonical positive decimal syntax
before provider invocation. Do not similarly invent narrow grammars for opaque
S3 or Azure version IDs.

Primary source:
[Google Cloud object generation identifiers](https://docs.cloud.google.com/storage/docs/objects).

### I-3: The full CI topology needs an explicit cost decision

**Severity: Low; operational choice.**

T1 intentionally runs Ubuntu verification plus four Windows pull-request cells,
and on every push to `main` runs preparation plus four Windows cells even when
the final writer will skip. With unfiltered events, unrelated documentation
changes pay the full matrix cost.

This is stronger evidence, not a correctness defect. Before filing, explicitly
accept that cost or reduce redundant helper placement while preserving required
checks and the unfiltered required-check behavior. Do not let the topology be
an accidental consequence of convergence wording.

## Strengths to preserve

- Keep issue titles as H1 headers and continue using T1/T2/T3 terminology.
- Preserve T1's complete-payload LF normalization, resolved BOM-less
  `WriteAllText` boundaries, LF checkout policy, and cross-edition raw-byte
  evidence.
- Preserve the generator convergence definition: shared observable algorithms,
  invariants, and failure semantics without cross-repository runtime coupling.
- Preserve the retained-stream digest/ZIP identity, manifest validation,
  explicit roots, full-component checks, case-specific cleanup outcomes, and
  same-child PowerShell edition assertions.
- Preserve immutable artifact ID/digest propagation, download-by-ID,
  least-privilege writer, blob identity proofs, exact expected-SHA lease, and
  no retry/adaptation.
- Preserve review-only action/Dependabot governance and implementation-time
  upstream verification.
- Preserve T2's separation of discovery and recovery, exact-object filters,
  deliberate selection, no-clobber destination design, restrictive `umask`,
  AWS bucket/KMS reconciliation, Azure HNS limitation, GCS Object
  Versioning/soft-delete distinction, and `gcloud storage` modernization.
- Preserve `set +x` as the first HCP subshell command, protected exact-path
  response creation, no token in ordinary process arguments, explicit curl
  failure handling, manual pagination, and sensitive state/Archivist URL
  handling.
- Do not copy PSStyleGuide's staged-content lint implementation into this
  repository; TerraformStyleGuide has a different full-lint Husky surface.

## Recommended disposition

Before the slate is filed:

1. Decide whether current T1 becomes an epic with child issues or remains one
   unusually large issue.
2. Resolve the Node/order policy.
3. Draft and reciprocally link a real Terraform T3.
4. Apply the confirmed T1 contract corrections, while treating cleanup naming
   and writer one-read details at their proportionate severity.
5. Replace helper hypothetical convergence with a current reciprocal matrix.
6. Shorten T2's prerequisite after T1/T3 are final.
7. Close HCP host/page/config grammar, GCS generation grammar, and T2 scope
   language.
8. Add exact non-network behavioral evidence for all four shell surfaces.
9. Make T2's local npm validation assert the merged runtime contract.

## Primary references

- [T1 issue draft](../TerraformStyleGuide/03TerraformStyleGuideT1.md)
- [T2 issue draft](../TerraformStyleGuide/04TerraformStyleGuideT2.md)
- [Supplied slate criticism](../TerraformStyleGuide/slate-criticism.md)
- [Node.js release status](https://nodejs.org/en/about/previous-releases)
- [HCP Terraform state versions API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/state-versions)
- [HCP Terraform in Europe](https://developer.hashicorp.com/terraform/cloud-docs/europe)
- [HCP Terraform API overview](https://developer.hashicorp.com/terraform/cloud-docs/api-docs)
- [curl manual](https://curl.se/docs/manpage.html)
- [setup-node automatic cache guidance](https://github.com/actions/setup-node)
