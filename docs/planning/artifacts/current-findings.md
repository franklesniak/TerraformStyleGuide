# Findings on the revised TerraformStyleGuide issue slate

## Executive verdict

Do not file the slate unchanged.

The revised issues are materially stronger than the prior Terraform review and
they now incorporate most of the sound P-slate feedback. Keep the
T1→T1A→T1B decomposition, embedded H1 titles, T/P identifiers, reciprocal
semantic model, and default T1→T1A→T1B→T2→T3→T4 order (subject to the existing
npm-risk gate).

The remaining defects are narrower but real. The highest-priority filing
blockers are:

| Owner | Blocker |
| --- | --- |
| T1B and successors | The repository's `main` branch is currently unprotected, while the issues rely on a protected-branch handoff and never authorize/configure that external setting. |
| T1A | Repeated path-only candidate cleanup can mistake a recreated path for old owned state unless the no-delete re-entry rule is closed. |
| T2 | The “final” provider blocks hardcode fields that the normative grammar says must be guarded, and the cleanup trap can lose its promised primary-status behavior under `set -e`. |
| T4 | Raw terminal confirmation has no implementable byte-preserving reader/serializer contract, and the backup blocks omit T2's required parent attestation input. |
| T4 | The secret-safe state-difference engine has no tracked helper/API or sufficient configuration/schema input. |
| T4 | Strictly safe serial progression conflicts with direct rollback of the just-created lower-serial backup while `-force` remains prohibited. |
| T4 | Hard-link preservation of a corrupt local state does not exclude an existing writer to the shared inode. |
| T4 | Exact narrowing of a Terraform resource address is promised but no parser/supported grammar is defined. |

T1, T1A, T1B, and T3 are close after contract/table corrections. T2 needs its
shown blocks reconciled with its normative rules. T4 needs another design pass
before it is suitable for a downstream implementer.

## Scope and review rules

- Review T1, T1A, T1B, T2, T3, and T4 in their stated sequential order.
- Preserve the embedded H1 issue titles and the T/P identifiers; neither is a
  formatting defect.
- Evaluate the older PSStyleGuide recommendations rather than treating them as
  accepted conclusions.
- Prefer semantic convergence between repositories, while keeping both
  implementations repository-local.
- Distinguish blockers from required clarifications and optional improvements.

## Preliminary observations

- The T1/T1A/T1B decomposition is conceptually sound: deterministic generation,
  adversarial candidate validation, and write-enabled promotion are separate
  review and rollback boundaries.
- T2 and T4 are Terraform-specific and do not need artificial PSStyleGuide
  counterparts.
- T3 is the natural dependency-governance counterpart to P3.

## Validated improvements already present

- T1 now specifies a closed four-artifact map, a same-directory
  old-or-complete-new replacement transaction, phase fault injection, an exact
  first-version grammar, `yaml@2.9.0`, strict workflow parsing, explicit action
  inputs, reviewed defaults, and raw Git status/path handling. These changes
  address the corresponding P1 recommendations in `slate-criticism.md`.
- T1A now preserves public paths as raw objects, publishes a typed invocation
  context and lifecycle including `CleanupInProgress` and
  `RetainedUncertain`, makes repeated disposal a zero-filesystem-call no-op,
  namespaces local IDs with `T1A-`, and adds cross-repository semantic keys.
  These changes address the main P1A recommendations in
  `slate-criticism.md`.
- T1B now has one external event owner, one local callable Markdown workflow,
  immutable artifact ID/digest transport, four path-bound hashes, four unique
  Windows outputs, direct approval dependencies, at-use regeneration, exact
  remote preflight/lease/refspec, cancellation-safe diagnostics, and a real-
  writer evidence-ref protocol. Retain this topology.
- T2's discovery/recovery separation, no-auto-selection rule, protected-parent
  model, no-replace hard-link publication, uncertainty retention, signal-
  specific exits, and permanent non-network exact-block harness are strong.
- T3 now contains the exact npm/Corepack descriptor and finite Node floors,
  production-versus-fixture Node-policy split, fail-closed installer scope,
  scheduled/manual read-only execution, raw report-v2 audit boundary, and
  bounded residual exception policy requested by the prior feedback.
- T4 usefully replaces truncating redirects, distinguishes POSIX permissions
  from Windows SID/DACL controls, uses raw .NET process streams on Windows,
  validates strict UTF-8, verifies file IDs/link counts, treats interruption
  after mutation as unknown, and prefers declarative/provider-native recovery.

## Findings recorded so far

### T1: the lockfile producer is recorded but not locked

T1 fixes the direct parser at `yaml@2.9.0`, but it only says to resolve and
record a Node/npm pair while updating the version-3 lockfile. Node major 24 does
not select one npm patch, and the implementation predates T3's final hashed
package-manager contract.

Require one exact implementation-time Node/npm pair and exact lockfile command,
record its provenance, and make every other validation cell prove it does not
rewrite the lock. This is the still-valid part of the older P1 parser/producer
recommendation that T1 has not yet incorporated.

### T1: the reciprocal generator matrix omits its new shared foundations

The reciprocal table still covers only parameters, destination, content,
serialization, write/failure state, and host tests. It omits T1's newly added
first-version parser, strict YAML parser/package identity, authored versus
default action policy, raw Git semantics, checkout/push token boundary,
temporary-writer graph, and evidence cleanup.

Add those rows. Otherwise the matrix cannot detect divergence in the exact
cross-repository controls that this revision says it is unifying.

### T1: the temporary workflow graph is less exact than its validator claim

T1 names verification and temporary-writer roles but does not publish one
closed job table with direct `needs`, job eligibility, outputs, and side
effects. The generated-artifact upload condition is described as
“failure/success policy stated below” without one exact condition. This leaves
the permanent validator's T1 constants partly implementation-defined.

Add the exact temporary job graph and literal conditions, including whether the
writer directly requires successful verification. T1B can then replace a
known table rather than an inferred topology.

### T1/T1A: “stale” version rejection needs two separate meanings

The version parser can validate four components and a real date, but an older
committed script must remain valid when executed later. “Stale date” is only
meaningful as an implementation/merge gate comparing a changed script with the
recorded modification date; it cannot be a permanent runtime-parser rejection
based on today's UTC date.

Separate timeless parse validity from implementation-time bump/date evidence
in T1 and all three T1A scripts.

### Cross-slate: `main` is currently unprotected, contrary to the handoff model

A read-only GitHub query on 2026-07-29 reports this public repository's `main`
branch as unprotected. T1B and every successor repeatedly call the landed value
a protected-branch commit, but none of the affected-file scopes or requested
changes creates a branch protection/ruleset.

Choose and record one real policy before filing:

- add a separately authorized repository-settings task that protects `main`
  and proves the exact writer actor can satisfy/bypass the applicable rule
  without weakening required checks; or
- stop claiming protection and describe the actual unprotected-main risk.

The isolated evidence ref does not prove that a `GITHUB_TOKEN` writer can push
through rules that apply only to `main`. This repository setting must be tested
on the real final topology, not inferred from an evidence branch.

### T1A: the public raw-value contract is incomplete

T1A closes raw path validation but does not do the same for `ExpectedDigest`.
The public contract still calls the five required inputs “scalar,” while the
later path rules explicitly preserve only path values as `[object]`. Optional
labels have array/object rejection cases, but their declared parameter types
and a complete raw grammar are not stated.

Require every untrusted public value—including `ExpectedDigest` and diagnostic
labels—to reach validation without PowerShell string coercion. Add atomic
null/type/empty/whitespace/control cases for the digest and close the label
grammar and parameter types. Otherwise an array or object may be stringified
before the advertised validator sees it.

### T1A: the normative case catalog is not yet structurally atomic

The table promises fixed result fields and exact phase/subreason/status oracles,
but many rows contain only a phase (for example, `manifest`) or prose such as
“success,” and the catalog-mutation fixtures required near the end of the issue
have no stable IDs or rows. The keys such as
`candidate.cleanup.case-03` are unique but are ordinal placeholders, not durable
semantic identities such as `cleanup.candidate.repeat-disposed`.

Put every required field—or a named, closed inherited oracle—into each row;
assign IDs to all catalog-integrity fixtures; and replace ordinal semantic keys
with behavior-named keys shared with P1A. A separate machine-readable inventory
cannot safely resolve ambiguity in the issue that is supposed to be its
normative oracle.

### T1A: tracked-script identity has no complete Git contract

The harness must reject untracked helper/context-manager scripts, but T1A does
not specify the repository root, exact Git command, raw path/status parsing,
native exit classification, or how a provider-qualified input is compared with
the tracked repository path. T1's raw Git rules are workflow scope gates, not a
published reusable PowerShell API in this repository.

Specify the exact tracked-file proof and fixtures, or remove “tracked” from the
runtime trust claim and rely on the recorded commit, ordinary-file identity,
version, and SHA-256. Do not leave a security decision to ad hoc parsing of
human-readable Git output.

### T1A: repeated candidate cleanup has no durable disposed identity

The caller context has a `Disposed` lifecycle, but
`Remove-StyleGuideCandidateInvocationState` accepts only an envelope, journal,
and failure. After successful removal, a later entry can reuse the same path.
The `T1A-K-03` no-op oracle says only “no unrelated deletion.”

Define repeated candidate cleanup as success only when the leaf remains absent;
if any entry has appeared, return a stable retained-state failure with zero
deletion. Alternatively give candidate ownership its own lifecycle object and
identity. A path-only old journal must never authorize deleting a recreated
file.

### T1B: two credential claims still contradict the truthful token model

T1B correctly states later that every checkout explicitly receives
`github.token`, uses it for authenticated fetch, and merely disables
persistence. However:

- preparation says it checks out with “credentials disabled”; and
- writer revalidation is introduced as occurring “before token expansion,”
  even though authenticated checkout is its first listed operation.

Use “with credential persistence disabled” for preparation and “before explicit
push-header construction or repository mutation” for writer revalidation. This
is the same valid correction made in the older P1B feedback.

### T1B: the complete job inventory omits the called workflow's internal jobs

The normative graph lists the `markdown` caller job and its action roles, but it
does not enumerate the job or jobs inside `markdownlint.yml`, nor does it give
exact static and expanded total job counts. Since the issue calls the table the
complete job/role/data-flow policy, include the called workflow's internal job
IDs, direct permissions, eligibility, and side effects and assert both caller
and expanded totals. Otherwise an extra local-workflow job can escape the
purported complete graph while still using no external action.

### T2: the guarded provider-identifier contract has no usable public input map

The “final” AWS, Azure, and GCS blocks hardcode bucket/account/container/object
values, but the later normative table requires those values to be validated and
passed byte-for-byte unchanged. Several fields have no environment-variable
name at all (“AWS key,” “Azure account,” “GCS object”), and only the version or
generation is actually read and guarded in the shown blocks.

Define an exact input variable for every provider field and use it in both
discovery and recovery, or explicitly classify hardcoded reviewed literals as
outside the runtime grammar. Then publish one final block per marker rather
than calling shorter contradictory snippets “final” and relying on a later
supersession clause.

### T2: the destination leaf and cleanup algorithms are not closed

The recovery blocks accept almost any nonempty direct-child leaf, including
control/newline bytes that can corrupt diagnostics. Define the path-byte
grammar separately from provider identifiers.

Also disable `errexit` on entry to `cleanup_recovery` and explicitly classify
every inspection, diagnostic, unlink, and `rmdir` outcome. As written, the
surrounding `set -e` remains active inside the EXIT trap, so a cleanup-internal
failure can abort before the trap preserves the primary status promised by the
normative signal contract.

### T2: the provider lifecycle race rows use disjunctive oracles

Each `*-PART-06` row combines “existing final before provider” and “racing final
at publication” with “provider skipped or publication refuses.” These are
different call counts and filesystem postconditions; in the racing case the
validated temporary/root is retained, while in the preexisting case nothing is
created. Split each provider's row so every ID has one setup and one exact
oracle.

### T2: sensitive temporary/final file identity is weaker than T4's successor

T2 sets `umask 077` but verifies only nonempty ordinary/non-link type and byte
equality. A provider can leave a different mode/owner or an already hard-linked
inode; hard-link publication preserves those properties. T4 later requires
effective-UID ownership, mode `0600`, same volume, and exact link counts for
equally sensitive state.

Move the common POSIX file identity checks into T2: require owner, exact mode,
same device, and initial link count one before publication; link count two
after `ln`; and link count one on the final name after temporary unlink. Add
mode/owner/multiple-hard-link fixtures for AWS, Azure, GCS, and HCP response
files where applicable.

### T3: the Husky installation identity is underspecified

T3 does not define:

- the version marker/identity required of `.husky/pre-commit`;
- the exact command/API by which `Install-Husky.mjs` invokes the locally
  installed Husky package; or
- the closed set and expected identities of “every required shim.”

Husky's `.husky/_` shims are generated/ignored state, whereas the real
`.husky/pre-commit` is tracked; the grouped “missing/linked/untracked
shim/hook” wording blurs that distinction. Close the tracked-hook and generated
shim schemas separately and give each installer-state case its own oracle.

### T3: the audit contract is stronger than its stable-ID catalog

The report-v2 section correctly adds raw-byte, duplicate-key, closed-schema,
and native signal/timeout/start-failure handling, but the table has no atomic
IDs for most of those boundaries (BOM, invalid UTF-8, second JSON value,
oversize/depth ceilings, duplicate keys at each object layer, signal, timeout,
start failure, and so on). “Audit all remaining rows and split any family”
defers the normative inventory to implementation.

Add the complete IDs now, close the production CLI's structured native-outcome
input (earlier prose says only “native status”), and set an exact stderr ceiling
and timeout/termination contract.

### T3: live follow-up evidence has no durable location or verification input

The exception hashes a canonical live-issue evidence record, but the affected
files, production CLI inputs, and retention language do not say where that
record lives or how a later reviewer recomputes its hash. Name an access-
controlled durable location and schema, or state that the hash is an external
human-reviewed attestation and define the retrieval/revalidation protocol.

### T4: the backend identifier length is arithmetically wrong

`backend-v1:<type>:<authority>:<scope>` with three 63-byte components has a
maximum length of 202 bytes, not 206 (`backend-v1` is 10 bytes plus three
colons). Correct the limit and add exact 201/202/203 boundary fixtures.

### T4: the terminal-confirmation algorithm is not implementable as specified

The issue requires raw UTF-8, NUL, CR, second-line, EOF, and 4,096-byte
classification from `/dev/tty`, plus a “reviewed serializer,” but names neither
the serializer nor a byte-preserving read algorithm. Bash variables cannot
contain NUL, and ordinary `read` cannot itself prove all of these raw-stream
conditions.

Name the exact local tool/algorithm, byte ceiling, descriptor lifecycle, and
JSON serializer. If that requires a tracked helper, add it to affected files
and the permanent harness rather than leaving a large security boundary as
unspecified inline code.

### T4: backup/publication inputs do not consume T2's attestation contract

T4 says T2 supplies the canonical protected-destination primitive, but
`SM-BACKUP-PULL` accepts only the final path, workspace, backend ID, and optional
label. It has no protected-parent attestation input equivalent to T2's literal
`private-outside-vcs-no-competing-writers`.

Add exact parent and attestation inputs for backup, proposed-state, verification,
and command-created backup paths, with the same inspected-versus-attested
distinction. A final path alone cannot carry T2's operator assertion.

### T4: state capture and state JSON parsing are unbounded

PowerShell bounds stderr but copies stdout/state indefinitely, and neither Bash
nor PowerShell publishes a state-byte, time, JSON depth/property/string, or
duplicate-key limit. A hung or unexpectedly huge `terraform state pull` can
consume unbounded time/disk, and a permissive JSON parser can erase duplicate
top-level lineage/serial evidence.

Set reviewed configurable ceilings, terminate/drain safely on overflow or
timeout, and use one closed raw JSON grammar for state metadata. Keep the actual
state-size limit high enough for documented large-state operation, with an
explicit reviewed escape procedure rather than silent relaxation.

### T4: the state-difference helper has no file, API, or provable input model

The issue requires a substantial offline redaction engine but adds no tracked
helper for it, names no serializer/parser, and does not define how
configuration/provider-schema identities are supplied. A state-file
`terraform show -json` representation alone does not necessarily contain every
configuration/schema input the prose relies on.

Make this a versioned tracked helper with closed inputs, output schema,
resource ceilings, and canary fixtures, and add it to affected files. Otherwise
the most sensitive T4 review boundary is implementation-defined.

### T4: the rollback and serial rules are not jointly satisfiable

For a content-changing push, “proposed serial is not lower” permits an
equal-serial mutation; require a strictly greater serial unless the candidate
is byte-identical. Conversely, the just-created pre-push backup will have a
lower serial after a successful push, so a promised rollback by pushing that
file is normally rejected by Terraform's retained serial safety check. T4 also
prohibits `-force`.

Replace “tested rollback command” with a tested reviewed recovery procedure:
prefer backend-native version rollback, or explicitly construct and validate a
new recovery state with the original content/lineage and a safe higher serial.
Do not promise a direct backup push that the documented safety controls reject.

### T4: local-corruption hard linking needs source-writer exclusion

`SM-LOCAL-CORRUPTION` creates a second name for the same inode and then unlinks
the source. A process with the source open for writing can change both names
before or after unlink. T4's protected destination directory does not revoke
existing source handles.

Require a specific source-side exclusion/paused-Terraform attestation and verify
owner/type/link count before and after publication, or use a true atomic
no-replace rename primitive with a documented platform contract.

### T4: the stable-ID tables contradict the one-case-per-row rule

T4 explicitly says grouped harness rows are not accepted, yet multiple rows
group distinct fixtures and outcomes:

- `SM-BASH-BACKUP-06`, `09`, and `11`;
- `SM-PS-BACKUP-06`, `09`, and `10`;
- `SM-BASH-PUSH-07` and `08`; and
- `SM-BASH-RM-02`, `03`, `07`, and `10`.

The required confirmation rejection cases and T2-derived signal/phase cases are
also promised without actual IDs. Split every disjunction into one append-only
ID with one phase/status/call-count/filesystem oracle before filing.

### T4: exact resource-address narrowing is not defined

`RESOURCE_ADDRESS` is passed as one quoted argument, but “no wildcard/broader
address” is not an executable grammar. Terraform intentionally permits
addresses that select a whole resource or module as well as instance addresses,
and string-key instances require quotes/escapes.

Define the supported address subset and how it is parsed. Prefer a trusted
Terraform-produced exact match set and require one intended instance; do not
parse localized `state rm -dry-run` prose or reject legitimate quoting with an
ad hoc shell regex. Give empty, module-wide, multi-instance resource,
integer-key, string-key, escaped-key, and malformed cases separate IDs.

## Disposition of every recommendation in `slate-criticism.md`

The ledger below judges the recommendation itself first. “Outstanding in P”
describes only whether the supplied P draft already incorporates that feedback;
it is not an independent critique of the P slate.

### Slate structure and sequencing

| Recommendation | Verdict | Current disposition |
| --- | --- | --- |
| Keep P1/P1A/P1B boundaries | Confirmed | The same T1/T1A/T1B separation remains appropriate. |
| Keep the default order subject to the advisory-risk gate | Confirmed | T1 and T3 encode the conditional reorder/rebaseline path. Do not let an old approval authorize materially worse audit evidence. |
| Preserve all H1 titles and P/T identifiers | Confirmed | They are deliberate issue titles/handles, not Markdown defects. |
| Distinguish reviewed head from landed protected-branch commit | Confirmed | The T handoffs mostly do this. The word “protected” is currently factually unsupported; see the repository-settings finding. |

### P1 recommendations

| Recommendation | Verdict | Current disposition |
| --- | --- | --- |
| Replace generic direct write with a closed verified replacement transaction | Confirmed for the promised failure postcondition | Outstanding in P. T1 now has the correct semantic transaction. This is stronger than byte determinism alone but necessary if the issue promises old-or-complete-new failure behavior. |
| Publish the exact first generator version | Confirmed | Outstanding in P. T1 addresses it, subject to separating timeless parse validity from implementation-time “stale” checks. |
| Lock the YAML parser and lockfile producer | Confirmed | Outstanding in P. T1 pins `yaml@2.9.0` but still must pin the exact lockfile-producing Node/npm pair. |
| Complete authored action inputs or classify an intentional default | Confirmed with nuance | Explicit inputs and reviewed pinned defaults are both acceptable if the distinction is closed. P is still partial; T1 is substantially complete. |
| Expand the P1↔T1 matrix to the new shared foundations | Confirmed | Neither current reciprocal table fully covers transaction/version/parser/action/token/Git/evidence semantics. |

### P1A recommendations

| Recommendation | Verdict | Current disposition |
| --- | --- | --- |
| Validate raw public values before PowerShell coercion | Confirmed | Outstanding in P. T1A fixes paths but not the digest/label contract completely. |
| Publish exact context and journal schemas | Confirmed | Outstanding in P. T1A publishes the caller context/journal schema; the candidate-cleanup journal should also be made explicitly closed if it is a different type. |
| Add complete lifecycle and safe repeated disposal | Confirmed | Outstanding in P. T1A addresses caller disposal. Candidate-cleanup re-entry still needs an explicit recreated-path no-delete oracle. |
| Give all three scripts exact first-publication versions | Confirmed | Outstanding in P; addressed in T1A with the stale-date clarification above. |
| Namespace local IDs and use shared semantic keys | Confirmed | Outstanding in P. T1A namespaces all 109 IDs, but all 109 keys are ordinal `*.case-N` placeholders rather than behavior-named identities. |
| Close the result-record schema | Confirmed | Outstanding in P. T1A declares fields but does not supply exact values/inherited oracles for every row. |

### P1B recommendations

| Recommendation | Verdict | Current disposition |
| --- | --- | --- |
| Write one complete job/role/data-flow table | Confirmed | Outstanding in P. T1B is close but omits the called workflow's internal jobs and total job counts. |
| Make action inputs explicit or record intentional differences | Confirmed | Outstanding in P. T1B closes candidate retention/compression and reviewed omissions. |
| Use `failure() && !cancelled()` for diagnostics | Confirmed; this is an internal-consistency fix | Outstanding in P. T1B uses the correct condition. |
| Remove false checkout/token phrases | Confirmed | Outstanding in P, and two equivalent phrases remain in T1B. |
| Prove the actual writer on an isolated evidence ref | Confirmed for a workflow that will really write | Outstanding in P. T1B adopts the stronger real-writer method. It still cannot substitute for testing `main`-specific protection/rules. |
| Make reviewed-head/landed-commit handoff explicit | Confirmed | Outstanding in P. T1B addresses it, apart from assuming branch protection that does not exist. |

### P2 recommendation

| Recommendation | Verdict | Current disposition |
| --- | --- | --- |
| Remove/defer the impossible future P3 URL requirement | Confirmed | Still outstanding in the supplied P2 draft: P3 is filed after P2, so P2 cannot require P3's real URL “at filing.” Backpatch later or let P3 point backward. There is no direct T analogue. |

### P3 recommendations

| Recommendation | Verdict | Current disposition |
| --- | --- | --- |
| Select exact hashed npm/Corepack identity and finite Node floors | Confirmed as a dated reviewed choice | Outstanding in P. T3 adopts npm 12.0.2 and the 22/24 floors and correctly requires implementation-time re-resolution. |
| Do not let production callers supply observed Node/policy | Confirmed | Outstanding in P. T3's production CLI reads `process.versions.node`; only the pure fixture API accepts test values. |
| Add and harden the actual prepare installer | Confirmed | Outstanding in P. T3 adds Terraform's equivalent installer but still needs exact hook/shim identity. |
| Validate raw audit bytes before parsing | Confirmed | Outstanding in P. T3 adopts the raw report-v2/native-outcome boundary. |
| Expand audit cases around that raw boundary | Confirmed | Outstanding in P and still incomplete in T3's stable-ID table. |
| Bind residual exceptions to canonical live issue evidence | Confirmed in principle; prescribed storage is a policy choice | A canonical live issue is a sound accountability requirement, but the exact record/hash scheme must name a durable location and revalidation protocol. T3 adopts the scheme without closing that location. |

### Cross-slate convergence and consistency recommendations

| Recommendation | Verdict | Current disposition |
| --- | --- | --- |
| Align semantic contracts without a shared runtime dependency | Confirmed | Keep both repositories self-contained. Shared reviewed skeletons, semantic cases, and evidence schemas are sufficient. |
| Converge deterministic-generation semantics | Confirmed | T1 now leads on failure transaction/version/parser/action policy; P1 remains to converge. |
| Converge workflow/path policy | Confirmed | Use one locked validator per repository and exact raw Git outcomes; do not derive policy from positive YAML. |
| Converge candidate-validation semantics | Confirmed | Manifest names may differ; raw inputs, archive identity, cleanup, schema, and meaningful semantic cases should not. |
| Converge verified-writer semantics | Confirmed | Repository-local job names may differ; permission, identity, hash, approval, regeneration, and lease weakness is not cosmetic. |
| Converge dependency-governance semantics | Confirmed | Keep Terraform full-lint versus PS staged-index behavior as an intentional difference. |
| Do not force a PS counterpart for T2/T4 | Confirmed | Provider/state recovery is legitimately Terraform-specific. |
| Record exact immutable P/T commits and evidence per matrix row | Confirmed | A branch name or “current” link is insufficient. |
| Classify every matrix row as same/difference/blocker with rationale | Confirmed | Add meaningful semantic keys; do not let grouped or absent counterparts become assumed passes. |
| File real issue URLs/dependency edges without inventing future IDs | Confirmed | Backpatch forward links only after the target issue exists. |
| Reuse one workflow-policy validator through later issues | Confirmed | T1 creates it; T1B/T2/T3/T4 must extend it, not replace it. |
| Reuse P1's raw Git verifier throughout P | Confirmed | P-specific implementation choice. Terraform needs an equally explicit reusable contract wherever later scripts claim tracked identity. |
| Record authored inputs and reviewed manifest defaults separately | Confirmed | Retain this throughout every action upgrade. |
| Re-resolve actions/packages/integrity/engines before implementation and merge | Confirmed | Listed versions are reviewed snapshots, not permission to silently follow “latest.” |
| Namespace local IDs and compare shared semantic keys | Confirmed | T1A namespaces IDs but needs meaningful keys; later T test catalogs should also avoid cross-repository short-ID ambiguity. |
| Keep generated artifacts derived-only and synchronized with source | Confirmed | T2/T4 do so; T3 correctly expects no content change. |
| Treat temporary evidence refs/files/settings as explicit test state | Confirmed | T1B's allowed-delta/evidence cleanup is the right model. |

### Criticism's final filing gate

The criticism's opening priority table and final filing bullets summarize its
detailed recommendations rather than introduce new technical claims. Reviewed
individually:

| Filing-gate summary | Verdict | Current disposition |
| --- | --- | --- |
| P1 transaction/version/parser/matrix gate | Confirmed | T1 has the transaction/version/parser but still needs the exact lock producer and expanded matrix. |
| P1A raw/schema/lifecycle/semantic-case gate | Confirmed | T1A is partial for raw digest/labels, meaningful semantic keys, complete row oracles, and candidate re-entry. |
| P1B graph/diagnostic/token/real-writer gate | Confirmed | T1B has diagnostics and real-writer evidence; called-workflow totals, two phrases, and actual `main` policy remain. |
| P2 future-link gate | Confirmed | Outstanding in the supplied P2 draft. |
| P3 npm/Node/installer/raw-audit/live-evidence gate | Confirmed | T3 has the architecture and pins; its installer identity, audit cases, and live-evidence retention remain. |
| No unexplained reciprocal security/failure blocker | Confirmed | This is the correct final cross-repository merge condition. |

## Recommended revision and filing gate

1. Revise T1 to lock its lockfile producer, close the temporary job graph, and
   expand the reciprocal matrix.
2. Revise T1A to validate every raw scalar, make repeated candidate cleanup
   incapable of deleting a reused path, publish the exact tracked-file proof,
   and make all 109 rows complete with behavior-named semantic keys.
3. Resolve real `main` protection/ruleset policy, then revise T1B's two token
   phrases and include called-workflow internal jobs/counts in the normative
   graph. Prove the final real-main writer policy in addition to the evidence
   ref when protection differs by ref.
4. Reconcile T2's displayed blocks with one exact public provider-variable map;
   make cleanup status-preserving under every failure; verify state
   owner/mode/device/link count; and split the existing/racing lifecycle cases.
5. Revise T3's hook/shim identity, native audit CLI/orchestration schema, full
   raw-boundary ID catalog, and durable follow-up evidence location.
6. Redesign the identified T4 boundaries before filing. At minimum add tracked
   helpers for byte-exact confirmation and secret-safe diffing, consume T2's
   parent attestation, bound state capture/parsing, define resource-address
   narrowing, and replace the infeasible direct-backup rollback promise.

T4 is also a reasonable candidate for a T4/T4A split if the downstream author
will implement one reviewable unit at a time: establish cross-platform backup,
confirmation, and redacted-diff primitives first; add exceptional state
push/rm/local-corruption mutation only after those primitives land. This is a
review-size recommendation, not an objection to embedded H1 titles.

The minimum filing gate is no unresolved blocker above, no disjunctive
stable-ID oracle, a real issue-link protocol, exact reviewed-head/landed
handoffs, and a reciprocal matrix with no unexplained security/failure
difference.

## Evidence checked

### Repository and mechanical evidence

- Local review baseline:
  `73735fd7df87671cba208a6b8db44ece22afa23f` on
  `planning-CRT-PR-852`.
- The working tree was clean before this findings artifact was overwritten.
- A live `gh api` query on 2026-07-29 confirmed the repository is public,
  defaults to `main`, and `GET /branches/main/protection` returns
  “Branch not protected.”
- T1A contains 109 table rows, 109 unique `T1A-*` IDs, and 109 unique
  `SemanticCase` strings; every semantic string ends in generic `.case-N`.
- T2 contains 18 provider lifecycle table IDs; T3 contains 27 explicit
  `AUDIT-*` table IDs; T4 contains five marker IDs plus 77 explicit `SM-*`
  harness rows. The additional prose-mandated raw/signal/confirmation cases do
  not all have rows.
- A local Bash probe with `set -e` and a failing command inside an `EXIT` trap
  skipped the remaining trap body and returned `1`, confirming that T2 must
  explicitly control `errexit` before promising primary-status preservation.

### Primary-source checks

- The pinned checkout manifest defaults `token` to `github.token` and describes
  it as the credential used to fetch; `persist-credentials: false` controls
  persistence, not whether checkout authenticates:
  <https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/action.yml>.
- The pinned setup-node manifest confirms `check-latest`, `token`, and
  `package-manager-cache`; the latter defaults true:
  <https://raw.githubusercontent.com/actions/setup-node/820762786026740c76f36085b0efc47a31fe5020/action.yml>.
- The pinned upload/download manifests confirm artifact ID/digest,
  `archive`, retention/compression, ID selection, `skip-decompress`, and
  `digest-mismatch` contracts:
  <https://raw.githubusercontent.com/actions/upload-artifact/043fb46d1a93c77aae656e7c1c64a875d1fc6a0a/action.yml>
  and
  <https://raw.githubusercontent.com/actions/download-artifact/3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c/action.yml>.
- npm registry metadata confirms npm 12.0.2's engine
  `^22.22.2 || ^24.15.0 || >=26.0.0` and the exact SHA-512 hex used by T3's
  `packageManager`; registry metadata also confirms `yaml@2.9.0`.
- The Node distribution index confirms the dated 22/24/26 release evidence:
  <https://nodejs.org/dist/index.json>.
- Terraform documents that `state push` rejects a pushed state only when the
  destination serial is higher, and `-force` disables that and lineage safety:
  <https://developer.hashicorp.com/terraform/cli/commands/state/push>.
- Terraform's state JSON representation contains values and Terraform version;
  configuration is a plan representation, not a guaranteed state
  representation:
  <https://developer.hashicorp.com/terraform/internals/json-format>.
- Terraform documents that state JSON exposes sensitive values in plaintext:
  <https://developer.hashicorp.com/terraform/cli/commands/show>.
- Terraform documents that `state rm` can match whole resources/modules and
  individual keyed instances:
  <https://developer.hashicorp.com/terraform/cli/commands/state/rm>.
- Microsoft documents `CreateHardLink` as NTFS-only and notes that writes
  through one link are visible through every link:
  <https://learn.microsoft.com/windows/win32/api/winbase/nf-winbase-createhardlinkw>.
- Bash executes `EXIT` traps under the shell's active option semantics; cleanup
  that promises exhaustive classification should explicitly take control of
  `errexit`:
  <https://www.gnu.org/software/bash/manual/bash.html>.
