# Findings on the current TerraformStyleGuide issue slate

## Executive verdict

Do not file T1, T1A, T1B, T2, T3, and T4 unchanged.

The revised slate is much stronger than the versions evaluated by the older
planning artifacts. In particular, T1A now has a full case inventory, T1B has a
single event-owning workflow and complete four-hash flow, and T3 has scheduled
read-only governance with tracked validators. Those corrections should be
retained.

Four findings are blockers because the current text either promises an
invariant the proposed implementation cannot satisfy or makes a copyable
recovery procedure report success after interruption:

| ID | Owner | Blocking finding |
| --- | --- | --- |
| TS-B01 | T1, T1B | The checkout credential invariant is false. The pinned `actions/checkout` implementation uses `github.token` for fetch before removing persisted authentication. |
| TS-B02 | T1 | Generator convergence is incomplete: there is no single final-write helper, complete destination grammar, parseable version contract, or defined failed-write destination state. |
| TS-B03 | T2 | The shared `EXIT HUP INT TERM` trap can convert `HUP`, `INT`, or `TERM` into exit status `0`. |
| TS-B04 | T4 | The common protection contract applies POSIX `umask 077` to a Windows-only PowerShell block and omits the exact Windows ACL, confirmation, identifier, stderr-bound, and strict-decoding contracts needed by its permanent cases. |

T1B's self-defining role allowlist, T1A's remaining non-exact oracles, and T3's
unfixed npm/audit schemas are required revisions. They are not reasons to
collapse the issue split or introduce a cross-repository runtime dependency.

## Scope and baseline

This review used the local worktree at TerraformStyleGuide commit
`4523b280fdff5034d31fa70f97bdc35dc05af129` on 2026-07-29. The six issue drafts
were reviewed in the requested order:

1. T1 — **Make artifact generation byte-deterministic and standardize repository text checkouts on LF**
2. T1A — **Add a fail-closed cross-platform style-guide candidate validator**
3. T1B — **Promote generated style-guide artifacts through a least-privileged verified writer**
4. T2 — **Make state-version discovery and recovery examples copy-safe with guarded identifiers**
5. T3 — **Remediate Markdown lint dependency advisories and add npm update governance**
6. T4 — **Make manual state backup and destructive recovery guidance copy-safe**

The issue H1 titles above should be preserved exactly. The current worktree,
not an older findings artifact, was treated as authoritative. No T or P issue
draft was changed by this review.

Severity meanings:

- **Blocker** — the issue is internally false, unsafe, or not implementable as
  specified.
- **Required** — the acceptance contract is not deterministic or fail-closed
  enough to support the promised permanent evidence.
- **Clarification** — the intended architecture is sound, but the issue should
  remove an ambiguity before implementation.
- **Addressed** — an earlier criticism is valid but the current Terraform issue
  already incorporates its correction.

## Issue-by-issue findings

## T1 — Make artifact generation byte-deterministic and standardize repository text checkouts on LF

### What is now strong

- The issue owns complete-payload normalization rather than relying on
  host-default file-writing behavior.
- It identifies all four final artifact write sites, LF checkout policy,
  action-SHA review, Node 24 workflow movement, Dependabot, and a reciprocal
  P1/T1 evidence matrix.
- The dated npm-risk/order gate and successor handoff wording correct two
  important weaknesses from the prior review.
- Terraform's generated frontmatter is already composed as line data. The
  PowerShell here-string/frontmatter defect should not be copied into this
  issue as though it also exists here.

### Revisions

#### T1-01 — Correct the checkout credential invariant — Blocker

The issue says verification runs “without credentials” and that the token is
materialized only for the exact push. The pinned checkout action defaults its
`token` input to `github.token`, reads that required input, configures Git
authentication before fetch, and removes the extra header after fetch when
`persist-credentials: false`.

Revise the contract to distinguish:

1. transient, reviewed checkout authentication used for fetch;
2. removal of persisted checkout authentication after fetch; and
3. the later, writer-only re-expansion of a push credential.

If verification truly must never receive a repository token, the issue must
name a different reviewed source-acquisition mechanism. Merely setting
`persist-credentials: false` does not provide that property.

#### T1-02 — Define one final-write helper and a complete destination contract — Blocker

T1 describes four final write sites but does not require all of them to cross a
single private serialization/write boundary comparable to P1. This allows
their validation, normalization, encoding, replacement, and failure behavior
to drift.

Require one private helper used by all four writes. Its destination contract
should explicitly reject:

- null, empty, or whitespace-only input;
- wildcard/provider syntax and multiple resolved items;
- malformed or non-filesystem paths;
- relative or nonrooted paths;
- a resolved destination outside the repository-owned output roots; and
- symlink/reparse traversal where the issue's security boundary forbids it.

The contract should say where full-path resolution happens, how ordinal path
containment is evaluated on Windows and Linux, and which exception/status is
the stable oracle for each rejection.

#### T1-03 — Define a parseable generator version field — Blocker

“Record one updated generator version using the repository UTC version
convention” is not sufficient. The repository has no machine-readable
generator-version policy, while T1A and T1B require a version to flow into
candidate and promotion evidence.

Name the exact file, field, grammar, update rule, and comparison rule. For
example, define a single named metadata field containing a UTC timestamp or a
semantic version, then require T1A/T1B to parse that field rather than infer a
version from free-form `.NOTES`.

#### T1-04 — Specify the destination postcondition after a failed write — Required

The reciprocal matrix includes a failed-destination-state row, but T1 does not
state whether a pre-existing destination must remain byte-identical, may be
absent, or may be partially changed when the underlying final write fails.
`File.WriteAllText` alone does not guarantee preservation of an old file.

Choose and test one behavior. If preservation is required, specify a
same-directory temporary file, flush/close, atomic replacement where supported,
cleanup, and the exact fallback or failure on unsupported filesystems. If
partial mutation is accepted, say so explicitly and align P1.

#### T1-05 — Make temporary workflow-policy validation reproducible — Required

T1 requires implementation-time structural YAML verification while freezing
the workflow package surface, but it names neither the parser/version nor a
retained command or fixture set. Text search is not a substitute for semantic
YAML inspection.

Name the temporary parser and locked version, the command that runs it, the
properties it checks, and where the evidence is retained. T1B's permanent
`Validate-WorkflowPolicy.mjs` supersedes this temporary mechanism later; that
does not remove T1's need for reproducible evidence at its own merge boundary.

#### T1-06 — Make role/input and affected-path checks exact — Required

For every checkout/upload/setup action in T1, list the exact explicitly
declared input keys and separately record reviewed defaults on which the design
depends. A role name or action count is not enough to prove the selected step
has the required inputs.

Affected-file equality must use NUL-delimited Git output so tabs, spaces, and
newlines in a pathname cannot alter the set comparison. Native comparison
commands must distinguish expected difference (`1`) from execution error
(`>1`), not treat all nonzero results as equivalent.

## T1A — Add a fail-closed cross-platform style-guide candidate validator

### What is now strong

- The current draft replaces grouped test ranges with a stable one-row case
  inventory.
- It defines helper and context-manager paths, same-stream archive identity,
  fresh extraction, cleanup ownership, resource ceilings, real link creation,
  skip metadata, and reciprocal P1A/T1A comparison.
- The earlier criticism that T1A had no complete table is addressed.

### Revisions

#### T1A-01 — Complete the public path-input grammar — Required

The public boundary rejects wildcards, relative paths, multiple resolution, and
non-filesystem providers, but it does not explicitly define null, empty,
whitespace-only, malformed, or nonrooted input. Add those cases and their exact
phase, status/exception, and unchanged-resource postcondition.

Use the same path vocabulary as the corrected T1 helper. A validation API must
not quietly accept a destination form that the generator refuses.

#### T1A-02 — Publish the exact context schema and disposed-state contract — Required

“Structured context containing” a set of values is not a stable API. Name every
field, its type, nullability, ordering rule where applicable, and ownership.
Define how a disposed context is represented and detected.

Case C02 says repeated teardown is a no-op “under the disposed-context
contract,” but that contract is not otherwise public. Specify the first
teardown transition, the second teardown result, field states after disposal,
and which resources the caller still owns.

#### T1A-03 — Give every listed case a final exact oracle — Required

The table is complete by ID but several rows still defer the result:

- E07 and E08 refer to platform ordinal behavior without saying which input
  passes or fails and what state remains.
- R01 and R05 say the manifest passes and “content oracle continues,” rather
  than naming the final result.
- R09 and R13 say the boundary “proceeds,” rather than naming the eventual
  result and cleanup state.
- The S cases use a generic harness-input failure without a fully specified
  phase/status/resource oracle.

Replace continuation language with one final pass/fail/skip result, exact
phase, stable status or exception, and post-case resource state for every ID.
Boundary cases must name which side of the boundary passes.

#### T1A-04 — Align reciprocal stable-ID meanings — Required

The P1A and T1A matrices may compare different case inventories, but a shared
stable ID must not mean different behavior in each repository. The reciprocal
review must classify each mismatch as:

- same ID and same semantic oracle;
- repository-specific ID with an intentional-difference rationale; or
- blocker requiring renaming or alignment.

Do not call the layers converged merely because both contain a similarly named
K03 or R-series case.

#### T1A-05 — Retain the corrected skip model — Addressed

The current draft correctly separates a supported real-link case from a
narrow, recorded environmental skip and records skip metadata/duration. Keep
that design. A missing inventory row or an unattempted primitive is a failure,
not a skip.

## T1B — Promote generated style-guide artifacts through a least-privileged verified writer

### What is now strong

- `build.yml` is now the sole external event owner and invokes
  `markdownlint.yml` with `workflow_call`, so approval can depend on all
  required jobs in one run.
- Preparation exports four path-bound hashes.
- Matrix cells publish four unique outputs rather than overwriting one shared
  matrix output.
- A tracked, locked-parser `Validate-WorkflowPolicy.mjs` and negative fixtures
  permanently enforce the workflow structure.
- The schedule/manual dependency-governance owner remains T3, avoiding a second
  event owner in T1B.

These changes resolve the most serious graph, hash-flow, output, and parser
criticisms from the older review.

### Revisions

#### T1B-01 — Correct the checkout/push credential boundary — Blocker

Apply T1-01 to every T1B role and acceptance statement. “Credentials exist only
for one exact push” is false when checkout uses the default token for fetch.
The true invariant is narrower: checkout auth is transient and not persisted;
only the writer re-expands credentials after approval for the guarded push.

The permanent policy validator should check the corrected properties rather
than encode the false no-credential claim.

#### T1B-02 — Replace the self-defining role allowlist with a normative table — Required

The draft lists roles “at minimum” and says the final YAML determines exact
counts. That lets implementation choices become the specification that the
validator then enforces.

Add one normative table containing, for every job and security-relevant step:

- stable role ID and exact count;
- owning job and `needs`;
- exact `if` condition;
- permissions and environment;
- action SHA or local callable target;
- exact explicitly declared input keys;
- reviewed action defaults;
- token availability and persistence state;
- artifact/output names; and
- allowed external side effects.

The validator fixtures should be derived from this table. Any later role change
then requires an issue-level policy change rather than merely updating code and
tests together.

#### T1B-03 — Specify the temporary-branch proof mechanism — Required

The writer's final condition permits the protected main branch, while validation
also requires a temporary-branch end-to-end push before main is enabled. Name
the exact mechanism that makes both statements true: for example, a separately
reviewed temporary evidence workflow/condition with a unique name and a required
post-test removal commit.

Specify the temporary ref, lease base, token scope, environment, cleanup,
evidence location, and the assertion that the production allowlist is restored.
Do not leave implementers to weaken the permanent main-only condition just to
collect proof.

#### T1B-04 — Move T2's future merge fact to handoff — Required

The acceptance item saying T2 records T1B's exact merge commit is not satisfiable
when T1B merges. Keep T1B's merge-commit recording requirement in the T2
dependency/handoff instructions and require T2 to consume it when T2 is filed or
implemented. T1 and T1A already use the safer predecessor/handoff formulation.

#### T1B-05 — Tighten structural-policy mechanics — Clarification

Require the policy validator to compare exact explicit action input keys and
reviewed defaults, use NUL-safe affected-path equality, and classify native
diff status `0`, `1`, and `>1`. Include negative fixtures for:

- a missing explicit key whose current action default happens to be safe;
- an unexpected extra role;
- a correct action in the wrong job or with the wrong condition; and
- a pathname containing whitespace or a control delimiter relevant to the
  chosen Git parser.

## T2 — Make state-version discovery and recovery examples copy-safe with guarded identifiers

### What is now strong

- The AWS S3, Azure Blob, and Google Cloud Storage blocks are concrete and
  distinguish provider identifiers from installed Terraform resource
  addresses.
- The issue introduces confirmation, partial-identifier lifecycle handling,
  protected temporary resources, a permanent harness, real hard-link cases,
  and a direct-response HCP Terraform path.
- It consumes the generator/validator/writer interfaces instead of restating
  their implementation.

### Revisions

#### T2-01 — Preserve nonzero signal exits — Blocker

Each Bash block installs the same `cleanup_recovery` function for
`EXIT HUP INT TERM`, captures `$?`, and exits with that value. A local Bash
5.2.21 reproduction using the same handler received `SIGTERM`, entered the trap
with status `0`, and exited `0`. Cleanup succeeded, but interruption was
reported as success.

Use an `EXIT` cleanup trap plus signal handlers that terminate with explicit
nonzero statuses, such as `129` for HUP, `130` for INT, and `143` for TERM. The
EXIT cleanup must preserve that primary status and must not recursively retrigger
the signal handler.

Add permanent cases for HUP, INT, and TERM while provider-specific temporary
resources and local files exist. Assert the exact nonzero status, cleanup
attempts, absence of a success message, and the retained primary failure when a
cleanup action also fails.

#### T2-02 — Separate documented parent-directory preconditions from checks — Required

The common contract says the parent must be outside a version-controlled
worktree and outside shared/world-readable temporary storage. The exact provider
blocks verify only that the parent exists, is a directory, and is not a
symlink; they later make the operator responsible for location.

Either implement exact checks for the claimed properties or label them as
operator-attested preconditions and narrow the machine-enforced claim. Define
how the harness proves both accepted and rejected parent examples.

#### T2-03 — Apply an explicit protected-parent contract to direct HCP output — Required

The HCP response path is protected as a file, but its parent-directory
preconditions are less explicit than the provider blocks. State whether the
parent must satisfy the same ordinary-directory, repository-exclusion, and
shared-temp rules, and add corresponding cases.

#### T2-04 — Define provider-identifier control-character rules — Clarification

Quoting protects shell word splitting but does not by itself define acceptable
bucket, account, container, object, or generation/version input. For each
provider, either cite the provider's authoritative identifier grammar and
validate it or define the narrower grammar accepted by the example. Reject
embedded newlines and control characters before logging or confirmation.

#### T2-05 — Harden Git and native-command evidence — Clarification

Any changed-path gate inherited from the slate must be NUL-delimited. Native
diff checks must distinguish no difference (`0`), expected difference (`1`),
and command failure (`>1`). The permanent harness should test those exit paths,
not only the provider CLI's ordinary success and failure.

## T3 — Remediate Markdown lint dependency advisories and add npm update governance

### What is now strong

- `build.yml` remains the event owner while scheduled and manual dependency
  validation is read-only.
- The maximum exception lifetime is exactly 30 days and uses an exclusive
  expiry boundary.
- `Check-NodePolicy.mjs` and `Validate-NpmAudit.mjs` expose pure logic plus CLI
  wrappers and have permanent fixture inventories.
- T3 updates the T1B workflow validator rather than replacing it.
- The dated npm order/rebaseline gate is explicit.

### Revisions

#### T3-01 — Pin one exact npm and its resolution mechanism — Required

“Select one supported npm” is not a reproducible contract. Name the exact npm
version, how it is installed or selected in CI and local policy checks, its lock
or Corepack/package-manager representation, and how drift is rejected.

Every Node/OS cell, the hook, scheduled audit, and fixture runner must report
and enforce the same selected npm. Record an intentional exception if a
platform cannot do so; do not silently use the npm bundled with each Node line.

#### T3-02 — Derive exact Node patch floors and remove the even-major shortcut — Required

The illustrative range `>=22 <23 || >=24 <25` is too broad for the locally
installed npm 11.7.0, whose declared engine is
`^20.17.0 || >=22.9.0`. It would admit unsupported Node 22.0 through 22.8.

After selecting npm, derive exact supported Node patch floors from its package
metadata and test immediately below and at each floor. Keep an explicit finite
allowlist of reviewed LTS lines.

Do not define “supported LTS” as permanently equivalent to “even-numbered
major.” Node's published release policy says that starting with Node 27, every
major is intended to move to LTS. The issue can choose Node 22 and 24 now, but
the durable rule should be the explicit reviewed allowlist, not parity.

#### T3-03 — Complete the npm audit report-v2 schema and status contract — Required

The promised fail-closed parser needs fixtures and invariants for:

- exact supported `auditReportVersion`;
- `metadata.vulnerabilities` keys, numeric types, nonnegative counts, and
  reconciliation with parsed vulnerability properties;
- every vulnerability property's required name, severity, range, nodes,
  effects, and `via`;
- `via` entries that are either advisory objects or package-name strings;
- `fixAvailable` as `false`, `true`, or a reviewed structured object;
- duplicate/missing nodes and reciprocal `via`/`effects` graph targets;
- malformed, unsupported, truncated, or non-JSON output;
- native npm exit `0` with disallowed findings and exit `1` with allowed
  exception coverage; and
- registry/tool failures and native statuses above the audit-policy statuses.

The pure core should classify parsed input and a supplied native status. The
orchestration wrapper owns process execution and must not turn registry or
parser failure into “no vulnerabilities.”

#### T3-04 — Correct the dated baseline terminology — Required

The current local `npm audit --json` observation reports seven vulnerability
properties: five high and two moderate. It also contains installed node paths,
but “seven affected package nodes” conflates two different counts.

Record, separately:

- vulnerability-property count;
- advisory-object count inside `via`;
- package-name/string `via` edges;
- installed node-path count; and
- metadata severity totals.

Treat these as dated implementation evidence, never acceptance constants.

#### T3-05 — Stop swallowing hook-installation failure — Required

The current `prepare` script ends with `husky || true`. T3 promises a real
installed hook but does not explicitly remove this fail-open installation
behavior. Require setup to fail when Husky installation should occur and does
not produce the expected hook. If a documented environment intentionally skips
installation, give that path an explicit condition and separate oracle.

The permanent cases must validate the installed hook file and run it, not only
call the underlying lint command directly.

#### T3-06 — Separate URL grammar from external issue existence — Clarification

An offline pure validator can verify an approved GitHub issue URL's grammar and
repository/number fields; it cannot prove that the issue exists and remains the
right follow-up. Retain filing evidence or perform one explicitly authorized
network lookup outside the pure core. Do not imply that offline JSON parsing
proves a “real filed issue.”

#### T3-07 — Give Node and hook cases one stable ID each — Required

HOOK-07 currently denotes a family of version cases. Expand it into one row and
one expected result per Node boundary/platform combination. This preserves the
append-only, one-result-per-ID inventory promised elsewhere in the slate.

## T4 — Make manual state backup and destructive recovery guidance copy-safe

### What is now strong

- PowerShell captures Terraform state from
  `StandardOutput.BaseStream`, avoiding text transcoding.
- The draft includes real hard-link and race tests on Windows PowerShell 5.1
  and PowerShell 7, operator-attested backend identity, 16 hexadecimal
  confirmation characters, and lock-timeout handling.
- The issue correctly treats state bytes and stderr as sensitive.

### Revisions

#### T4-01 — Define a Windows protection contract instead of `umask` — Blocker

The common model says all blocks require `umask 077`, while the PowerShell block
is Windows-only. Replace that impossible cross-platform requirement with two
explicit platform contracts:

- POSIX blocks: exact required umask and resulting directory/file modes; and
- Windows PowerShell: exact parent and file ACL/inheritance invariant, the
  command/API used to establish or verify it, allowed principals, and failure
  cleanup.

Cases must inspect the actual ACL or mode, not infer protection from the command
that attempted to set it.

#### T4-02 — Make every confirmation and label grammar executable — Blocker

Define:

- the exact `EXPECTED_BACKEND_ID` grammar;
- the exact typed confirmation template and separators;
- normalization/case rules for the 16-hex digest;
- the optional operation/timestamp label grammar; and
- the exact mismatch status and no-destructive-action postcondition.

Without literal grammars, the harness cannot assert the promised exact command
and confirmation behavior, and operators cannot reliably know what to type.

#### T4-03 — Set an exact stderr byte bound and overflow behavior — Required

“Explicit bound” is not a number. Specify the maximum captured bytes, whether
the count is raw bytes or decoded characters, what happens at exactly the
boundary and one byte above it, how truncation is marked, and whether a
truncated diagnostic may be emitted. Update SM-PS-BACKUP-14 with exact oracles.

#### T4-04 — Require strict BOM-less UTF-8 decoding — Required

PowerShell/.NET UTF-8 APIs can replace invalid byte sequences unless strict
fallback is requested. Require a strict decoder such as
`UTF8Encoding(false, true)` or an equivalent reviewed implementation, reject a
BOM where BOM-less output is required, and test invalid leading, continuation,
overlong, surrogate, truncated, and BOM inputs.

#### T4-05 — Define path, reparse, and hard-link identity mechanics — Required

Name the exact PowerShell APIs/commands used to:

- resolve an ordinary absolute filesystem parent exactly once;
- reject relative, provider, wildcard, symlink, junction, and other reparse
  traversal;
- create the candidate without following a swapped path; and
- verify that no existing path is the same file through a hard link.

State which guarantees are possible on Windows PowerShell 5.1 and PowerShell 7,
and fail closed where an identity primitive is unavailable. Avoid POSIX “mode”
language in Windows acceptance unless a concrete Windows mapping is defined.

#### T4-06 — Define a secret-safe state-difference review — Required

The issue asks the operator to confirm the backup meaningfully differs from the
current state without disclosing secrets, but it does not name a safe
mechanism. Specify whether this is an offline human attestation, a byte digest
comparison, a redacted structural comparison, or another exact process.
Prohibit raw state or state-derived secrets in logs and retained evidence.

#### T4-07 — Consume the corrected T2 interruption contract — Required

T4 expands the Bash recovery harness, so its dependency must explicitly consume
the corrected T2 signal behavior from T2-01. Add the same signal-status and
cleanup assertions to any T4 path that wraps or extends the provider blocks.

## Cross-repository convergence

Generator “unification” should mean common semantic contracts and reciprocal
evidence, not a shared runtime package. Preserve repository ownership and these
intentional differences:

| Layer | P owner | T owner | Required common contract | Current T status |
| --- | --- | --- | --- | --- |
| Deterministic generator | P1 | T1 | One final-write boundary, destination validation, complete-payload normalization, encoding/newlines, metadata/version, host matrix, native exits, failure state | Incomplete until T1-02 through T1-04 are resolved |
| Candidate validation | P1A | T1A | Same-stream identity, component security, ceilings, fresh extraction, context/cleanup ownership, one exact oracle per stable ID | Mostly aligned; context and several final oracles remain incomplete |
| Verified writer | P1B | T1B | One event owner, local callable lint workflow, permanent policy parser, identity/digests/four hashes, unique outputs, approval, at-use regeneration, ref/SHA/lease/token model | Graph and hash flow addressed; credential truth and normative role table remain |
| Content repair | P2 | T2/T4 | Consume the merged generator/writer boundary without weakening it | Different domains are intentional; no forced T blank-line analogue |
| Dependency governance | P3 | T3 | Finite reviewed Node policy, one npm, real hook, audit graph/schema, bounded exceptions, schedule/manual checks, Dependabot | Architecture aligned; exact npm, Node floors, schema, and hook installation remain |

Every reciprocal matrix should record exact P and T commits, concrete evidence,
`same`/`intentional difference`/`blocker`, and a rationale for every intentional
difference. Shared semantic layer names and stable-ID meanings are useful; a
cross-repository module, package, release cadence, or runtime dependency is not.

## Disposition of every PSStyleGuide criticism recommendation

The following ledger first judges the technical validity of each recommendation
in `docs/planning/PSStyleGuide/slate-criticism.md`, then records its relevance to
the current Terraform slate. “P-specific” means the recommendation is valid but
does not describe a current T defect. No recommendation below was accepted
merely because it appeared in the supplied criticism.

### Overall architecture recommendations

| Ref | Validity | Current Terraform disposition |
| --- | --- | --- |
| ARCH-1 — retain the P1/P1A/P1B split | Confirmed | The same generator/candidate/writer separation is sound in T1/T1A/T1B and should not be collapsed. |
| ARCH-2 — retain sequential implementation after blockers are corrected | Confirmed | Keep T1→T1A→T1B→T2→T3→T4, subject to the existing dated npm-risk decision and rebaseline rule. |
| ARCH-3 — use reciprocal semantic contracts, not a shared runtime | Confirmed | The two repositories should share matrices, terminology, and stable semantics without adding cross-repository package or availability coupling. |

### Priority-table summary

The criticism's priority table summarizes later detailed recommendations; it
does not add independent requirements.

| Ref | Validity | Current Terraform disposition |
| --- | --- | --- |
| PRI-1 — same job graph | Confirmed | T1B addressed it; see P1B-1. |
| PRI-2 — four preparation hashes | Confirmed | T1B addressed it; see P1B-2. |
| PRI-3 — permanent workflow parser | Confirmed | T1B addressed it; see P1B-3. T1 still needs reproducible temporary validation. |
| PRI-4 — checkout token boundary | Confirmed | Still blocks T1/T1B; see T1-01 and T1B-01. |
| PRI-5 — continuous P3 governance | Confirmed | T3 addressed schedule and lifetime; audit detail remains under P3-3. |
| PRI-6 — complete P1A oracle table | Confirmed | T1A now has all IDs, but not every row has a final exact oracle. |
| PRI-7 — P1 upload path | Confirmed | P-specific wording defect; T1 correctly refers to generated files, though exact action inputs remain. |
| PRI-8 — P2 stale graph/path checks | Confirmed | Stale graph is P-specific; NUL-safe path handling applies across the T slate. |
| PRI-9 — dated npm order decision | Confirmed | Addressed by T1/T3; retain the rebaseline gate. |

### P1 recommendations

| Ref | Validity | Current Terraform disposition |
| --- | --- | --- |
| P1-1 — correct failure-upload path | Confirmed | The stated P1 list names implementation files, so the criticism is valid. T1 does not repeat that exact mistake. Its normative role table should still name exact generated upload paths and inputs. |
| P1-2 — make checkout credential statement true | Confirmed | Directly applicable and unresolved in T1/T1B; TS-B01. |
| P1-3 — define temporary structural workflow validation | Confirmed | T1 still lacks a named parser/version/retained command while its package surface is frozen; T1-05. T1B's permanent parser is addressed. |
| P1-4 — add advisory-order decision | Confirmed | Addressed by the dated T1/T3 owner-decision and rebaseline gates. |
| P1-5 — move successor-only facts out of acceptance | Confirmed | T1 and T1A now use handoff language. T1B still puts a future T2 fact in acceptance; T1B-04. |
| P1-6 — define “complete inputs” | Confirmed | Applies to T1/T1B. Exact declared input keys and separately reviewed defaults belong in the normative role table; T1-06/T1B-02. |
| P1↔T1 convergence | Confirmed | T1 adds a reciprocal matrix, but common helper, destination, version, and failure-state contracts remain blockers; T1-02 through T1-04. |

### P1A recommendations

| Ref | Validity | Current Terraform disposition |
| --- | --- | --- |
| P1A-1 — full stable oracle table | Confirmed | Addressed structurally by T1A's one-row inventory. |
| P1A-2 — exact phase and state per ID | Confirmed | Partially addressed. E07/E08, R01/R05/R09/R13, and the S rows still lack final exact oracles; T1A-03. |
| P1A-3 — concrete context/disposed contract | Confirmed | Directly applicable and unresolved; T1A-02. |
| P1A-4 — distinguish skip from missing case | Confirmed | Addressed by T1A's real-link attempts and recorded narrow environmental skips; retain T1A-05. |
| P1A↔T1A convergence | Confirmed | The reciprocal comparison exists, but equal stable IDs must have equal meanings; T1A-04. |

### P1B recommendations

| Ref | Validity | Current Terraform disposition |
| --- | --- | --- |
| P1B-1 — same-run Markdown dependency graph | Confirmed | Addressed: `build.yml` owns events and calls `markdownlint.yml` through `workflow_call`. |
| P1B-2 — export four preparation hashes | Confirmed | Addressed with four path-bound hashes. |
| P1B-3 — permanent structural policy enforcement | Confirmed | Addressed with a tracked locked-parser validator and fixtures. |
| P1B-4 — correct checkout/push credential boundary | Confirmed | Directly applicable and unresolved; T1B-01. |
| P1B-5 — exact temporary-branch proof | Confirmed | Directly applicable and unresolved; T1B-03. |
| P1B-6 — unique matrix outputs and mapping tests | Confirmed | Addressed with four unique outputs and validator fixtures; retain them. |
| P1B↔T1B convergence | Confirmed | The matrix exists. Credential truth, exact role/input policy, and temporary proof still prevent full convergence. |

### P2 recommendations

| Ref | Validity | Current Terraform disposition |
| --- | --- | --- |
| P2-1 — update stale P1B PR expectations | Confirmed | P-specific content defect. T2 consumes the merged T1B interface and does not assert the stale separate-workflow graph. |
| P2-2 — NUL-delimited Git path sets | Confirmed | General and applicable to all T affected-file gates; T1-06, T1B-05, and T2-05. |
| P2-3 — classify `git diff --exit-code` | Confirmed | General and applicable to T native-command evidence; do not collapse `1` and `>1`. |
| P2-4 — machine-check unchanged Compliant example | Confirmed | P-specific content invariant; no direct Terraform analogue. |
| P2-5 — do not inconsistently restate P1B | Confirmed | T2 already consumes the predecessor interfaces instead of redefining the writer. Retain that boundary. |

### P3 recommendations

| Ref | Validity | Current Terraform disposition |
| --- | --- | --- |
| P3-1 — continuous scheduled/manual execution | Confirmed | Addressed in T3 through read-only schedule/manual execution owned by `build.yml`. |
| P3-2 — exact exception lifetime | Confirmed | Addressed with an exclusive, at-most-30-day lifetime. |
| P3-3 — deterministic audit-policy oracles | Confirmed | Partially addressed. T3 has AUDIT-01..19, but the report-v2 graph/schema and native-status cases remain incomplete; T3-03/T3-04. |
| P3-4 — pure validator plus orchestration | Confirmed | Addressed by the module/CLI split; retain explicit process-error ownership in the wrapper. |
| P3-5 — one tracked Node-policy decision | Confirmed | Architecture addressed by `Check-NodePolicy.mjs`; exact npm, patch floors, parity wording, and one-ID-per-case remain; T3-01/T3-02/T3-07. |
| P3-6 — consume the corrected P1B parser | Confirmed | Addressed: T3 updates rather than replaces the validator/package/lock. |
| P3-7 — reconcile package-update order | Confirmed | Addressed by the T1/T3 dated owner decision; retain the rebaseline path. |
| Recommended P3 scope | Confirmed with intentional differences | T3's affected-file scope contains the Terraform equivalents. PS staged-index lint internals do not need a Terraform counterpart; Terraform's full-lint hook is intentionally different. |

### Cross-issue convergence-model recommendations

| Ref | Validity | Current Terraform disposition |
| --- | --- | --- |
| X-1 — deterministic generator layer | Confirmed | Convergence is incomplete until T1 uses one helper and exact destination/version/failure contracts. Source composition, frontmatter, and filenames may differ. |
| X-2 — candidate-validation layer | Confirmed | Mostly aligned; exact context schema, final oracles, and stable-ID meanings remain. The four Terraform manifest filenames are intentional. |
| X-3 — verified-writer layer | Confirmed | Graph, hashes, and outputs are aligned. Token truth and normative role/input policy remain. |
| X-4 — content-repair layer | Confirmed | Domain differences are intentional. P2's blank-line repair does not force a Terraform issue; T2/T4 must only preserve predecessor interfaces. |
| X-5 — dependency-governance layer | Confirmed | T3 follows the correct architecture but needs exact npm/Node/audit details. Hook scope is intentionally different. |
| X-6 — semantic convergence without shared runtime | Confirmed | Prefer reciprocal matrices and common contracts. Do not introduce a shared package, module, release, or runtime dependency. |

### Reciprocal-matrix evidence recommendations

| Ref | Validity | Current Terraform disposition |
| --- | --- | --- |
| MX-1 — record exact P and T commits | Confirmed | Require immutable commit IDs in every T1/T1A/T1B/T3 reciprocal comparison, not branch names or “current” prose. |
| MX-2 — retain concrete evidence on both sides | Confirmed | Require commands, fixture/result IDs, hashes, or tracked evidence sufficient to reproduce each classification. |
| MX-3 — classify every row | Confirmed | Use only `same`, `intentional difference`, or `blocker`; an unclassified or merely informational mismatch does not prove convergence. |
| MX-4 — explain every intentional difference | Confirmed | Repository-specific filenames, frontmatter, manifests, and hook scope are acceptable only with a recorded rationale. |
| MX-5 — retain stable semantic layer names | Confirmed | Use generator, candidate validation, verified writer, content repair, and dependency governance even if planning filenames change. |
| MX-6 — retain matrices in reviewed evidence | Confirmed | Keep them in pull-request evidence or tracked planning artifacts, not an unreviewed external document. |

### Cross-slate consistency recommendations

| Ref | Validity | Current Terraform disposition |
| --- | --- | --- |
| CS-1 — real issue URLs and blocked-by links | Confirmed | Apply at filing time. Draft placeholders are acceptable only until real issue URLs exist. |
| CS-2 — predecessor commits in successors; no future facts in predecessor acceptance | Confirmed | T1/T1A are corrected. Move T1B's future T2 fact; T1B-04. |
| CS-3 — one stable test-ID meaning across P/T | Confirmed | Apply through T1A-04 and every reciprocal matrix. |
| CS-4 — one external event owner | Confirmed | Addressed by current T1B/T3; retain `build.yml` ownership. |
| CS-5 — one tracked workflow-policy validator | Confirmed | Addressed: T1B introduces it and T3 updates it. |
| CS-6 — exact declared input keys plus reviewed defaults | Confirmed | Still needs a normative T1/T1B role/input table. |
| CS-7 — re-resolve action tags before implementation and merge | Confirmed | Current T1/T1B require this. Treat listed SHAs as reviewed snapshots, not permanent truth. |
| CS-8 — NUL-safe affected-file equality | Confirmed | Apply to every T gate; current text should say so explicitly. |
| CS-9 — preserve exact H1 titles | Confirmed | All six current T titles are preserved in this review and should remain unchanged. |

### Filing-gate recommendations

These bullets repeat detailed findings but are individually valid:

| Ref | Validity | Current Terraform disposition |
| --- | --- | --- |
| FG-1 — every priority blocker has an issue-level resolution | Confirmed | Not yet satisfied because TS-B01 through TS-B04 remain. |
| FG-2 — complete one-row P1A oracle table | Confirmed | T1A has one row per ID; exact final results still need T1A-03. |
| FG-3 — executable P1B graph and complete hashes | Confirmed | Addressed in T1B. |
| FG-4 — truthful checkout credential claim | Confirmed | Not satisfied; T1-01/T1B-01. |
| FG-5 — scheduled deterministic at-most-30-day P3 governance | Confirmed | Schedule/lifetime addressed; deterministic audit schema still needs T3-03. |
| FG-6 — P2 evidence matches corrected P1B graph | Confirmed | P-specific. T2 already consumes the corrected T1B graph. |
| FG-7 — dated npm-risk decision permits order | Confirmed | Addressed; rebaseline if the recorded owner decision no longer permits the wait. |

## Recommended revision and filing gate

Keep the requested sequential order. Before filing:

1. Correct the T1/T1B checkout statements and encode the true boundary in the
   permanent validator.
2. Give T1 one final-write helper, exact destination/version/failure-state
   contracts, and reproducible temporary YAML validation.
3. Complete T1A's public path/context contracts and replace continuation rows
   with final exact oracles.
4. Add T1B's normative role/input table, temporary-branch proof mechanism, and
   successor-only handoff correction.
5. Correct T2's signal traps and test HUP/INT/TERM plus parent protection.
6. Select exact npm, derive exact Node patch floors, complete the audit schema,
   make hook installation fail closed, and expand grouped case IDs in T3.
7. Define T4's Windows ACL, literal confirmation/identifier grammars, exact
   stderr bound, strict decoder, identity mechanics, and secret-safe diff.
8. Perform one final reciprocal P/T read using exact commits and classify every
   matrix row as `same`, `intentional difference`, or `blocker`.
9. Re-resolve external action tags immediately before implementation and merge,
   add real issue URLs/blocked-by relationships when available, and retain
   NUL-safe affected-file equality.

The issue split itself is sound. The required response is precision at each
merge boundary, not fewer issues and not a shared cross-repository runtime.

## Evidence

### Direct local evidence

- Current baseline: `git rev-parse HEAD` returned
  `4523b280fdff5034d31fa70f97bdc35dc05af129`.
- Bash 5.2.21 signal reproduction: a handler shaped like T2's shared
  `EXIT HUP INT TERM` trap entered on `SIGTERM` with `$? == 0` and the shell
  exited `0`.
- Current `npm audit --json`: native exit `1`, report version `2`, seven
  vulnerability properties, metadata totals of five high and two moderate, and
  both Boolean and structured-object `fixAvailable` values.
- Installed npm 11.7.0 declares
  `^20.17.0 || >=22.9.0`, which disproves the illustrative Node 22.0 floor.

### Primary references

- [`actions/checkout` pinned action metadata](https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/action.yml)
- [`actions/checkout` input handling](https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/src/input-helper.ts)
- [`actions/checkout` authentication lifecycle around fetch](https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/src/git-source-provider.ts)
- [Node.js releases and LTS policy](https://nodejs.org/en/about/previous-releases)
- [npm audit command documentation](https://docs.npmjs.com/cli/commands/npm-audit/)
- [GNU Bash signal traps](https://www.gnu.org/software/bash/manual/html_node/Signals.html)

The runtime and audit observations are dated evidence supporting the issue
contracts. They must not be turned into permanent acceptance counts.
