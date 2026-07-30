# TerraformStyleGuide open-finding evaluations

## Evaluation method

Each finding uses a distinct weighted rubric. Criterion scores are 1–5 and
totals are normalized to 100. Correctness, failure truth, security, and
copyable-example usability outweigh churn and implementation convenience.

## F01 — Enforce one sequential issue graph

### Options

- **A:** retain both T1-first and T3-first graphs.
- **B:** always run T3 first.
- **C:** keep the listed order; make advisory authorization a go/no-go gate.
- **D:** fold partial package remediation into T1.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Dependency determinism | 35 | Filed edges must describe one graph. |
| Security decision truth | 25 | Refused exposure must stop, not be hidden. |
| Handoff clarity | 20 | Every successor needs one predecessor state. |
| Rebaseline safety | 15 | Alternate urgency needs explicit reissue. |
| Churn | 5 | Lower than correctness. |

### Scores

| Option | Determinism | Truth | Handoff | Rebaseline | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 3 | 1 | 2 | 5 | 38 |
| B | 5 | 3 | 4 | 2 | 2 | 73 |
| C | 5 | 5 | 5 | 5 | 4 | **99** |
| D | 2 | 2 | 2 | 1 | 2 | 37 |

### Selected resolution

Select **C**. T1 states the only graph T1→T1A→T1B→T2→T3→T4. A current
accountable advisory decision permits entering it. Missing, refused, expired,
or materially worsened evidence stops and reissues/reorders the entire slate;
no current issue implements the alternate graph or partial dependency work.

## F02 — Complete T1A's physical case catalog

### Options

- **A:** leave allocation to implementation.
- **B:** inline every field independently in every row.
- **C:** physical rows with immutable oracle profiles and exact variations.
- **D:** generate IDs dynamically from fixture names.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Pre-filing completeness | 30 | The issue must already decide every ID. |
| Oracle singularity | 25 | One fixture must have one expected outcome. |
| Mutation detection | 20 | Missing/regrouped rows must fail. |
| Reciprocal semantics | 15 | Stable keys enable P1A comparison. |
| Maintainability | 10 | Profiles should control safe repetition. |

### Scores

| Option | Complete | Singular | Mutation | Reciprocal | Maintain | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 2 | 1 | 2 | 3 | 33 |
| B | 5 | 5 | 5 | 5 | 2 | 92 |
| C | 5 | 5 | 5 | 5 | 5 | **100** |
| D | 2 | 3 | 2 | 2 | 4 | 48 |

### Selected resolution

Select **C**. Retain all existing T1A IDs but finish the physical table before
filing: replace every ordinal key/disjunction, assign exactly one profile and
literal variation set, and append every Git identity/catalog-integrity row.
The issue freezes exact row/profile counts after expansion. JSON contains no
range row. Every applicable `(ID,runtime)` emits once; mutation rows reject
missing, duplicate, unknown, regrouped, skipped, orphaned, or unused records.

## F03 — Make disposed candidate cleanup zero-call

### Options

- **A:** retain T1A reinspection and record an intentional difference.
- **B:** retry/reinspect only on Windows.
- **C:** align with P1A: terminal disposed/retained states make zero calls.
- **D:** recursively remove any reoccupied name.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Capability safety | 35 | Released ownership must not reach new objects. |
| State determinism | 25 | Terminal calls should be stable. |
| Cross-repo convergence | 20 | Same lifecycle simplifies shared evidence. |
| Adversarial behavior | 15 | Reoccupation must never authorize deletion. |
| Migration effort | 5 | Secondary. |

### Scores

| Option | Safety | Determinism | Converge | Adversarial | Effort | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 4 | 2 | 2 | 5 | 5 | 67 |
| B | 3 | 2 | 1 | 4 | 3 | 49 |
| C | 5 | 5 | 5 | 5 | 4 | **99** |
| D | 1 | 2 | 1 | 1 | 3 | 27 |

### Selected resolution

Select **C**. After candidate cleanup proves absence and transitions to
`Disposed`, ownership is released. A repeated valid disposed call returns the
identical object/summary with zero provider/path/filesystem/native calls.
`RetainedUncertain` is terminal failure with zero calls. New occupancy at the
old name is outside the capability. Add spy cases proving zero calls.

## F04 — Close T1B failure diagnostics

### Options

- **A:** retain descriptive prose.
- **B:** specify upload action inputs only.
- **C:** specify producer schema/output plus every upload literal and fixtures.
- **D:** remove diagnostics.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Secret minimization | 30 | Diagnostics must not leak workspace/token state. |
| Producer/consumer closure | 25 | The uploader needs one exact authority. |
| Policy testability | 20 | Literal values must be structurally validated. |
| Failure preservation | 15 | Diagnostics cannot mask the primary failure. |
| Operational usefulness | 10 | Bounded evidence should remain actionable. |

### Scores

| Option | Secrets | Closure | Tests | Primary | Useful | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 3 | 2 | 2 | 3 | 3 | 51 |
| B | 4 | 3 | 3 | 4 | 3 | 68 |
| C | 5 | 5 | 5 | 5 | 5 | **100** |
| D | 5 | 5 | 5 | 5 | 1 | 92 |

### Selected resolution

Select **C**. For Windows and writer roles, name the producer step ID, one
fresh exact output path/output, canonical redacted schema, allowlisted copied
files, literal artifact name/path/condition, and exact upload inputs:
`if-no-files-found:error`, retention 7, compression 0, overwrite false, hidden
false, archive true. Producer/upload may continue on error but never hide the
primary result. Add one policy mutation per field and forbidden source.

## F05 — Add pre-merge supply freeze

### Options

- **A:** implementation-start freeze only.
- **B:** check only immutable full SHAs before merge.
- **C:** repeat the complete supply/provenance/security tuple before merge.
- **D:** automatically update to the newest releases before merge.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Supply-chain freshness | 30 | Review justification can drift during a PR. |
| Provenance completeness | 25 | Tag, manifest, runtime, and tarball all matter. |
| Review control | 20 | Drift must trigger accountable renewed review. |
| Reproducibility | 20 | Producer/consumer inputs remain exact. |
| Cost | 5 | Repeated reads are low-cost. |

### Scores

| Option | Fresh | Complete | Review | Reproduce | Cost | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 4 | 3 | 4 | 5 | 65 |
| B | 2 | 2 | 3 | 3 | 5 | 48 |
| C | 5 | 5 | 5 | 5 | 4 | **99** |
| D | 5 | 2 | 1 | 2 | 2 | 50 |

### Selected resolution

Select **C**. T1 and T1B repeat action release/tag/SHA/manifest/default/runtime,
Node artifact/checksum/signature, bundled manager, package tarball/integrity/
bytes, effective config, and audit/security reads immediately before merge.
Any drift stops for reviewed atomic update; never silently repin.

## F06 — Put a reusable native Git helper in T2

### Options

- **A:** keep consuming an implicit predecessor interface.
- **B:** reopen T1/T1B to add the helper.
- **C:** add the helper, cases, and handoff to T2's affected scope.
- **D:** inline independent Git commands in every T2 block.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Callable-interface truth | 30 | Consumed APIs must exist at a fixed path. |
| Raw pathname safety | 25 | NUL bytes/status/cardinality must be closed. |
| Native outcome handling | 20 | Exit/stdout/stderr failures need stable classes. |
| Predecessor stability | 15 | Landed foundations should not be reopened needlessly. |
| Scope cost | 10 | T2 can reasonably own its dependency. |

### Scores

| Option | Interface | Path safety | Native | Stability | Cost | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 2 | 2 | 5 | 5 | 43 |
| B | 5 | 5 | 5 | 1 | 2 | 76 |
| C | 5 | 5 | 5 | 5 | 4 | **98** |
| D | 3 | 3 | 3 | 5 | 3 | 66 |

### Selected resolution

Select **C**. Add a versioned T2 helper and fixture manifest. It derives a
fixed root, accepts raw scalar inputs and closed modes, uses argument arrays,
raw NUL records/literal pathspecs, complete active-format IDs, exact status/
cardinality/termination rules, and a stable result schema. T2 owns hostile
names, conflicts, modes, malformed records, missing objects, and native failure
cases and hands the helper identity to successors.

## F07 — Choose the HCP page-number grammar

### Options

- **A:** use unbounded decimal.
- **B:** parse into platform integer.
- **C:** canonical 1–20 digit string `^[1-9][0-9]{0,19}$`.
- **D:** allow zero/leading zeros and normalize.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Cross-shell correctness | 30 | Values must not overflow or coerce differently. |
| Canonicality | 25 | One spelling avoids request ambiguity. |
| Resource bound | 20 | Input size must be finite. |
| Copyability | 15 | Users should understand the rule. |
| Compatibility | 10 | Valid service page values should work. |

### Scores

| Option | Shell | Canonical | Bound | Copyable | Compatible | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 4 | 5 | 1 | 3 | 5 | 70 |
| B | 2 | 4 | 4 | 3 | 2 | 60 |
| C | 5 | 5 | 5 | 5 | 5 | **100** |
| D | 3 | 2 | 4 | 3 | 5 | 62 |

### Selected resolution

Select **C** everywhere. Never convert to a numeric type. Add empty, zero,
sign, leading-zero, nondigit, 19-digit, 20-digit, and 21-digit rows and require
the exact original canonical string in request evidence.

## F08 — Freeze S3 reserved names

### Options

- **A:** keep “no reviewed reserved form.”
- **B:** fetch AWS docs during validation.
- **C:** embed the dated official set and reject `-an` for this global mode.
- **D:** allow all character-valid names.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| AWS correctness | 35 | Copyable names must respect official reservations. |
| Offline determinism | 25 | Permanent fixtures cannot depend on live pages. |
| Namespace clarity | 20 | Account-regional `-an` must be deliberate. |
| Boundary coverage | 15 | Each literal needs exact tests. |
| Update effort | 5 | Dated policy can be reviewed later. |

### Scores

| Option | Correct | Offline | Namespace | Tests | Effort | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 3 | 1 | 1 | 5 | 39 |
| B | 5 | 1 | 3 | 3 | 2 | 62 |
| C | 5 | 5 | 5 | 5 | 4 | **99** |
| D | 1 | 5 | 1 | 1 | 5 | 35 |

### Selected resolution

Select **C**. Embed prefixes `xn--`, `sthree-`, `amzn-s3-demo-`; suffixes
`-s3alias`, `--ol-s3`, `.mrap`, `--x-s3`, `--table-s3`; and reject `-an`
because T2 does not establish an account-regional namespace. Add
shorter/exact/longer and position/case rows and cite the dated AWS source.

## F09 — Select a Bash minimum

### Options

- **A:** rely on `/usr/bin/env bash`.
- **B:** require Bash 3.2.
- **C:** require canonical Bash `>=4.4.0` with exact guard.
- **D:** rewrite all blocks as POSIX `sh`.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Syntax guarantee | 30 | The examples need one known feature floor. |
| Hosted/user portability | 25 | Common current environments should pass. |
| Guard correctness | 20 | Malformed/unavailable/below must fail clearly. |
| Maintenance clarity | 15 | Authors know which syntax is permitted. |
| Rewrite cost | 10 | Lower than correctness. |

### Scores

| Option | Syntax | Portable | Guard | Clear | Cost | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 4 | 1 | 2 | 5 | 39 |
| B | 3 | 5 | 4 | 4 | 4 | 79 |
| C | 5 | 5 | 5 | 5 | 4 | **98** |
| D | 5 | 5 | 4 | 4 | 1 | 83 |

### Selected resolution

Select **C**. Use Bash `4.4.0`, compare canonical numeric components without
locale/coercion ambiguity, emit one stable remediation diagnostic, and test
unavailable, malformed, `4.3.999`, `4.4.0`, and a current higher version.

## F10 — Separate observed findings from approvals

### Options

- **A:** retain whole-object equality.
- **B:** copy governance fields into observed findings.
- **C:** separate collections keyed by exact finding identity.
- **D:** approve only a single aggregate report digest.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Data provenance truth | 35 | Audit bytes cannot derive human approval. |
| Drift invalidation | 25 | Security/topology changes must revoke approval. |
| Least approval scope | 20 | Keys must cover exact residuals only. |
| Operator usability | 15 | Reviews should show observed versus governed data. |
| Schema churn | 5 | Secondary. |

### Scores

| Option | Provenance | Drift | Scope | Usable | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 3 | 3 | 2 | 5 | 44 |
| B | 2 | 2 | 3 | 2 | 4 | 43 |
| C | 5 | 5 | 5 | 5 | 4 | **99** |
| D | 4 | 3 | 2 | 2 | 3 | 59 |

### Selected resolution

Select **C**. `ObservedFindings` contains only report/tree/lock/native facts.
`Approvals` contains reason, controls, owner, approval, expiry, and follow-up.
Require exact `(Package,AdvisoryUrl)` key equality; compare copied severity/
range/source/fix/types/topology fields; validate governance separately. Any
observed-field/topology/scope/expiry drift fails.

## F11 — Allocate physical T3 non-audit cases

### Options

- **A:** retain family IDs with multiple results.
- **B:** make `(ID,Platform,Runtime)` the primary key.
- **C:** give every platform/runtime case one immutable physical ID.
- **D:** rely on randomized property testing.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Evidence cardinality | 30 | One ID/result rule must be satisfiable. |
| Platform specificity | 25 | OS/runtime behavior must be explicit. |
| Catalog immutability | 20 | Implementers cannot invent allocation. |
| Reciprocal mapping | 15 | Stable semantic keys compare with P3. |
| Catalog size | 10 | Lower than executable clarity. |

### Scores

| Option | Cardinality | Platform | Immutable | Reciprocal | Size | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 3 | 1 | 2 | 5 | 37 |
| B | 5 | 5 | 4 | 4 | 4 | 90 |
| C | 5 | 5 | 5 | 5 | 3 | **97** |
| D | 2 | 4 | 1 | 1 | 4 | 42 |

### Selected resolution

Select **C**. Expand every Node pure/CLI, NPM, Husky/hook, and capture-helper
case into a physical ID with one literal platform/runtime applicability,
fixture, expected identity/outcome/side effects/diagnostic. Freeze counts and
reject missing/duplicate/unknown/regrouped/orphaned IDs.

## F12 — Select the T3 schedule

### Options

- **A:** leave cadence to implementation.
- **B:** run hourly.
- **C:** use P3's `23 17 * * 3`.
- **D:** omit schedule and retain manual dispatch only.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Governance freshness | 30 | Live exception state must be checked regularly. |
| Exact policy validation | 25 | Structural fixtures need one literal. |
| Cross-repo consistency | 20 | Same cadence simplifies operations. |
| CI load | 15 | Read-only weekly checks are proportionate. |
| Contributor predictability | 10 | Timing should be documented. |

### Scores

| Option | Fresh | Exact | Converge | Load | Predictable | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 1 | 2 | 3 | 1 | 36 |
| B | 5 | 5 | 2 | 1 | 5 | 76 |
| C | 5 | 5 | 5 | 5 | 5 | **100** |
| D | 1 | 5 | 2 | 5 | 2 | 51 |

### Selected resolution

Select **C**. Put literal `'23 17 * * 3'` in T3 and add exact, mutated,
missing, duplicate/extra, and schedule/manual-to-publication-ineligibility
fixtures.

## F13 — Add a literal package-operation authority

### Options

- **A:** retain distributed prose/caller commands.
- **B:** adopt P3's wrapper file wholesale.
- **C:** keep T3 architecture but freeze one T-local operation table/digest.
- **D:** use shell command strings.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Invocation exactness | 30 | Ordered argv changes semantics. |
| Ambient-config resistance | 25 | Environment/config cannot weaken policy. |
| Multi-consumer consistency | 20 | Workflow/hook/audit must share authority. |
| Architectural fit | 15 | Convergence need not force runtime packaging. |
| Implementation cost | 10 | Secondary. |

### Scores

| Option | Exact | Resistant | Consistent | Fit | Cost | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 3 | 2 | 5 | 5 | 52 |
| B | 5 | 5 | 5 | 2 | 1 | 82 |
| C | 5 | 5 | 5 | 5 | 4 | **98** |
| D | 1 | 1 | 1 | 3 | 3 | 25 |

### Selected resolution

Select **C**. Define `T3-NPM-OPERATIONS-v1` for every install/audit/no-op/lint/
hook manager call with verified Node/Corepack entry, full argv, cwd,
environment/config/network/cache, streams/timeout/termination, accepted exits,
and side effects. Existing surfaces consume exact rows/digest; no new shared
cross-repository runtime is introduced.

## F14 — Close GitHub live-client retry behavior

### Options

- **A:** one attempt; every non-200 fails.
- **B:** unbounded exponential retries.
- **C:** bounded attempts with exact rate-limit/header/max-wait rules.
- **D:** accept cached evidence when live reads fail.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Fail-closed freshness | 30 | Network failure cannot preserve stale approval. |
| API citizenship | 25 | Rate limits must be respected. |
| Bounded execution | 20 | CI cannot sleep/retry indefinitely. |
| Deterministic evidence | 15 | Attempts/statuses become testable. |
| Simplicity | 10 | A small policy is preferable. |

### Scores

| Option | Fresh | API | Bounded | Deterministic | Simple | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 5 | 3 | 5 | 5 | 5 | 90 |
| B | 3 | 4 | 1 | 2 | 1 | 51 |
| C | 5 | 5 | 5 | 5 | 4 | **98** |
| D | 1 | 5 | 5 | 3 | 4 | 59 |

### Selected resolution

Select **C**. Use exact API version/headers, no redirects, 1-MiB responses,
three total attempts, named retryable statuses, canonical `Retry-After` or
`x-ratelimit-reset` parsing capped at 30 seconds, fixed fallback delays, and
fail if the required wait exceeds the cap or attempts exhaust. Never accept
cached state. Add physical response/header/drift cases.

## F15 — Make `state rm` backend-specific

### Options

- **A:** keep universal `-backup`.
- **B:** omit `-backup` everywhere.
- **C:** attest backend mode; local uses supported backup flag, remote/HCP uses
  protected `state pull` recovery without the local-only flag.
- **D:** try with `-backup`, then retry without it.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Command validity | 30 | Destructive argv must match the backend. |
| Recovery strength | 25 | Every mode needs pre-mutation state evidence. |
| No-retry safety | 20 | Failed mutation attempts cannot be probed/replayed. |
| Backend identity | 15 | Mode drift/ambiguity must stop. |
| Copyable clarity | 10 | Operators need literal mode-specific commands. |

### Scores

| Option | Valid | Recovery | No retry | Identity | Clear | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 4 | 4 | 1 | 3 | 47 |
| B | 5 | 4 | 5 | 2 | 4 | 82 |
| C | 5 | 5 | 5 | 5 | 5 | **100** |
| D | 2 | 4 | 1 | 2 | 2 | 43 |

### Selected resolution

Select **C**. Before mutation, attest exactly one
`local|hcp-cloud|remote-backend` mode and fixed configuration/workspace. Every
mode has a protected `state pull` capture. Local mode may use the pinned
version's local-only `-backup`; HCP/remote argv omits it by construction.
Unknown/changed mode stops. Never retry a destructive command after
unknown-option or partial failure.

## F16 — Complete T4 state-bearing ownership and review gates

### Options

- **A:** retain distributed path prose.
- **B:** split T4/T4A without first closing roles.
- **C:** one canonical role table plus two mandatory internal approval gates.
- **D:** let helpers create arbitrary OS temporary paths.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Path authority | 30 | Every sensitive file needs one owner/parent. |
| Destructive review isolation | 25 | Mutation waits for approved inspection foundation. |
| Cleanup/uncertainty truth | 20 | Retained sensitive state must be accounted for. |
| Cold-operator usability | 15 | Public versus helper-private paths are explicit. |
| Planning churn | 10 | Avoiding filename changes is useful but secondary. |

### Scores

| Option | Authority | Review | Cleanup | Usable | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 2 | 2 | 2 | 5 | 46 |
| B | 3 | 4 | 3 | 3 | 1 | 60 |
| C | 5 | 5 | 5 | 5 | 5 | **100** |
| D | 1 | 1 | 1 | 1 | 4 | 16 |

### Selected resolution

Select **C**. Enumerate every public/state-derived role in one table, or mark
it helper-private under one exact invocation-context owner. Each row gives
creator, consumer, parent/path/attestation, identity/content/size, lifetime,
cleanup owner/order, failure postconditions, and retained uncertainty.

T4 has two evidence gates in the same issue: Gate A approves/fixes the
nonmutating capture/inspection/diff/address/confirmation foundation; Gate B
may begin destructive push/rm/recovery only from Gate A's immutable identities
and independent approval. This closes reviewability without adding a T4A file.

## Integration trace

| Finding | Issue integration |
| --- | --- |
| F01 | T1/T3 one graph and go/no-go advisory gate |
| F02–F03 | T1A physical catalog and zero-call terminal cleanup |
| F04 | T1B literal diagnostic contract |
| F05 | T1/T1B pre-merge supply freeze |
| F06–F09 | T2 Git helper, page grammar, S3 literals, Bash floor |
| F10–F14 | T3 observed/approval split, physical cases, cron, operations, retries |
| F15–F16 | T4 backend modes, ownership table, two review gates |

No selected resolution adds, deletes, renames, or reorders a GitHub Issue
draft file.
