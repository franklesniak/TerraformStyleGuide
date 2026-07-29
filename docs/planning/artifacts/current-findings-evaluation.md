# Evaluation of open TerraformStyleGuide issue-slate findings

## Completion status

Evaluation and issue-slate incorporation completed on 2026-07-29.

The authoritative findings are in `current-findings.md`. This file evaluates
each open TerraformStyleGuide finding sequentially. Every finding will contain:

1. the finding and desired outcome;
2. an exhaustive option set, including useful permutations;
3. a finding-specific weighted rubric;
4. a scored comparison table; and
5. a detailed selected resolution suitable for a cold implementer.

All six TerraformStyleGuide issue descriptions were revised only after all 36
findings had complete options, rubrics, scoring tables, and selected
resolutions.

## Finding inventory and coverage map

The review's overlapping recommendation, issue-specific, and cross-issue
statements are normalized into the following 36 open Terraform findings. A
compound entry is used only where the source statements describe one decision
with inseparable postconditions.

1. `T1-01` — restore generator convergence and its destination-path matrix.
2. `T1-02` — specify temporary writer authentication.
3. `T1-03` — make predecessor merge-commit evidence temporally possible.
4. `T1-04` — make the temporary writer's retirement explicit.
5. `T1-05` — govern the optional early-T3 scheduling exception.
6. `T1A-01` — make the context-manager implementation input deterministic.
7. `T1A-02` — use one durable, complete oracle row per stable case ID.
8. `T1A-03` — add exact resource-boundary and deceptive-archive cases.
9. `T1A-04` — complete the public-input rejection matrix.
10. `T1A-05` — exercise both production cleanup lifecycles.
11. `T1A-06` — compare the candidate layer with the corresponding PS layer.
12. `T1B-01` — replace the impossible cross-workflow dependency.
13. `T1B-02` — transport the four preparation hashes immutably.
14. `T1B-03` — define unique evidence for all four matrix cells.
15. `T1B-04` — make structural workflow-policy validation executable.
16. `T1B-05` — compare the writer layer with the corresponding PS layer.
17. `T2-01` — define and enforce provider-download partial-file semantics.
18. `T2-02` — identify the sample language as Bash, not generic POSIX.
19. `T2-03` — inherit T1B's implementable workflow topology.
20. `T2-04` — give partial-file cases durable provider-prefixed IDs.
21. `T3-01` — define and invoke one permanent audit validator.
22. `T3-02` — use a residual-audit identity derivable from npm output.
23. `T3-03` — define an exact maximum approval lifetime.
24. `T3-04` — reject stale, excess, malformed, and unused permission.
25. `T3-05` — add a complete stable audit-case inventory.
26. `T3-06` — prove every boundary of the bounded Node policy.
27. `T3-07` — define pull-request, Dependabot, push, and scheduled audit gates.
28. `T4-01` — specify a byte-preserving cross-edition PowerShell backup.
29. `T4-02` — add Windows PowerShell 5.1 and PowerShell 7 evidence.
30. `T4-03` — test the real no-replace publication primitive.
31. `T4-04` — define fail-closed behavior when hard links are unavailable.
32. `T4-05` — give Bash and PowerShell recovery cases stable IDs.
33. `T4-06` — define typed-confirmation digest-prefix strength.
34. `T4-07` — distinguish operator-attested from derived backend identity.
35. `T4-08` — define positive lock waiting for manual state push.
36. `T4-09` — recompute the exact affected-file set for the selected design.

The cross-issue findings are covered as follows: predecessor evidence by
`T1-03`; workflow topology by `T1B-01` and `T2-03`; durable oracles by
`T1A-02`, `T2-04`, `T3-05`, and `T4-05`; generator convergence by `T1-01`,
`T1A-06`, and `T1B-05`; fresh-path ownership by `T1A-05`, `T2-01`, and
`T4-03`; runtime policy by `T3-06`; and durable security exceptions by
`T3-01` through `T3-05`.

## T1-01 — Restore generator convergence and the destination-path matrix

### Finding and outcome

T1 has the stronger generator destination contract but no reciprocal
PSStyleGuide comparison. The outcome must preserve repository independence
while proving that both generator layers intentionally agree on path
resolution, content bytes, failure state, and tests.

### Options

- **A — Accept informal similarity.** Implement T1 alone and trust reviewers to
  notice drift.
- **B — Add a prose comparison.** Name broad similarities and differences
  without exact evidence rows or a merge gate.
- **C — Add a commit-bound reciprocal matrix.** At implementation start and
  before merge, record the exact PS and Terraform commits; compare public
  parameters, one-path resolution, wildcard/provider/multi-match rejection,
  LF/BOM/content assembly, single-write behavior, failure destination state,
  and tests. Classify every row as `same`, `intentional difference`, or
  `blocker`; require evidence and rationale; block unexplained differences.
- **D — Create a shared runtime package immediately.** Move generator code into
  a cross-repository dependency and compare only wrappers.
- **E — Defer all comparison until PSStyleGuide is split.** Leave T1
  ungoverned until P1/P1A/P1B exist.

Useful permutations are B+C (a short human summary above the exact matrix) and
C+D later (first prove convergence, then separately evaluate shared packaging).
D without C would conceal wrapper and rollout differences.

### Evaluation rubric

Score each criterion from 1 (poor) to 5 (excellent); weighted total is out of
100.

- **Behavioral correctness — 35%:** detects security and byte-contract drift.
- **Cross-repository convergence — 25%:** advances one intentional generator
  contract without false equivalence.
- **Auditability — 20%:** ties claims to exact commits, evidence, and a gate.
- **Cold-implementer usability — 15%:** makes comparison work unambiguous.
- **Churn and sequencing cost — 5%:** avoids unnecessary coupling; deliberately
  low weight.

| Option | Correctness | Convergence | Auditability | Usability | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 1 | 1 | 4 | 5 | 33 |
| B | 3 | 3 | 2 | 4 | 4 | 60 |
| C | 5 | 5 | 5 | 4 | 3 | **95** |
| D | 4 | 5 | 4 | 2 | 1 | 76 |
| E | 2 | 2 | 2 | 2 | 4 | 42 |

### Selected resolution

Select **C with B's short summary**. T1 will contain an exact reciprocal matrix
contract and a concise statement that identical security/error behavior is the
default. Repository paths, manifest file names, and workflow topology may be
intentional differences. The comparison targets the then-current
PSStyleGuide generator layer even if it is still housed in P1; it records the
exact section and commit and migrates the label to P1 if that split exists.
Unexplained behavior, error, or destination-state differences block merge.
This is convergence by proved contract, not a premature shared deployment
dependency.

## T1-02 — Specify temporary writer authentication

### Finding and outcome

T1 disables checkout credential persistence but merely says the write
credential is exposed for the exact push. The outcome is a copyable temporary
authentication contract that neither stores a token in Git configuration nor
leaks it into commands, remotes, diagnostics, or later processes.

### Options

- **A — Persist checkout credentials.** Let `actions/checkout` configure the
  token and use ordinary `git push`.
- **B — Put the token in the remote URL.** Construct an authenticated HTTPS
  URL for the push and restore it afterward.
- **C — Use process-scoped Git configuration in environment variables.** Set
  `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_n`, and secret-backed
  `GIT_CONFIG_VALUE_n` for an HTTP authorization header only on the exact push
  process; keep the remote credential-free and checkout persistence disabled.
- **D — Create a temporary credential helper/file.** Scope it to the push and
  delete it afterward.
- **E — Remove publication from T1.** Let generated output remain stale until
  T1B.

Permutations C+E and D+E are unnecessary because E eliminates the operation.
A+C is contradictory. C can and should be combined with credential-free
preflight/postflight diagnostics and log assertions.

### Evaluation rubric

- **Credential exposure minimization — 35%:** limits process, time, and storage
  scope.
- **Push correctness — 25%:** works with an exact HTTPS refspec.
- **Leak resistance and observability — 20%:** avoids remote/config/log
  disclosure.
- **Operational clarity — 15%:** is reproducible by a new workflow author.
- **Implementation churn — 5%:** rewards simplicity only after security.

| Option | Exposure | Correct push | Leak resistance | Clarity | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 4 | 2 | 5 | 5 | 55 |
| B | 1 | 4 | 1 | 4 | 4 | 47 |
| C | 5 | 5 | 5 | 4 | 3 | **95** |
| D | 4 | 5 | 4 | 3 | 2 | 80 |
| E | 5 | 2 | 5 | 2 | 2 | 73 |

### Selected resolution

Select **C**. T1 will reuse T1B's final credential boundary early:
`persist-credentials: false` on checkout; a credential-free origin URL; no
credential helper, remote rewrite, command argument, or persisted config; and
the GitHub token present only as the secret value of a process-scoped HTTP
authorization header for the single `git push` invocation. All ref/object,
diff, and post-push checks run without the secret-bearing environment. The
issue will require masked logs and a structural check proving the secret is
referenced only by the push step.

## T1-03 — Make predecessor merge-commit evidence temporally possible

### Finding and outcome

T1 and T1A ask their own pull requests to record merge commits that do not
exist until after those pull requests merge. The outcome is exact dependency
provenance without requiring future knowledge.

### Options

- **A — Retain self-merge wording.** Expect an implementer to fill in the
  future merge SHA somehow.
- **B — Successor-consumes-predecessor evidence.** The current PR records its
  reviewed head and passing evidence; the successor issue/PR records and
  validates the predecessor's actual merge commit before work.
- **C — Post-merge automation edits the closed PR/issue.** A bot writes the
  resulting merge SHA after completion.
- **D — Record only predecessor branch heads.** Avoid merge SHAs entirely and
  rely on branch history.

B+C is possible but the bot adds no security value if the successor already
validates the actual merge object. B+D is weaker because a branch head is not
the consumed `main` state.

### Evaluation rubric

- **Evidence truthfulness — 35%:** every asserted SHA must exist when asserted.
- **Temporal feasibility — 30%:** the required actor can know the value.
- **Dependency traceability — 20%:** proves the exact merged baseline consumed.
- **Handoff usability — 10%:** is obvious to both issue authors.
- **Administrative burden — 5%:** post-merge machinery has low priority.

| Option | Truth | Feasibility | Traceability | Handoff | Burden | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 1 | 3 | 2 | 5 | 34 |
| B | 5 | 5 | 5 | 5 | 4 | **99** |
| C | 4 | 4 | 5 | 2 | 1 | 77 |
| D | 3 | 5 | 2 | 4 | 5 | 72 |

### Selected resolution

Select **B** across the slate. T1 requires T1A to record and validate T1's
actual merge commit. T1A requires T1B to do the same for T1A. T1B requires T2
to record its merge commit, and later issues follow the same handoff. Each
current PR may record its reviewed head SHA, evidence runs, and intended
successor; it must not claim to know its own merge SHA. The successor stops if
the merged tree does not match the expected contracts.

## T1-04 — Make the temporary writer's retirement explicit

### Finding and outcome

T1 introduces a transitional direct writer, while T1B introduces the final
verified writer. The outcome is a state transition in which the repository
never retains two active publication paths.

### Options

- **A — Permit both writers.** Treat the T1 path as a fallback after T1B.
- **B — Disable the T1 writer conditionally.** Leave its code present with an
  event or variable that normally prevents execution.
- **C — Require T1B to replace and remove it.** Name the temporary job/steps in
  T1, then make T1B delete them and structurally prove exactly one
  contents-writing writer remains.
- **D — Omit all writing in T1.** Accept stale generated artifacts until T1B.

B+C is redundant: deletion is more auditable than dormant code. C can include
a short rollback note in the PR without retaining a second production writer.

### Evaluation rubric

- **Duplicate-writer safety — 40%:** prevents competing or weaker publication.
- **Transition completeness — 25%:** makes the final state deterministic.
- **Structural provability — 20%:** supports an exact workflow assertion.
- **Maintainer comprehension — 10%:** makes temporary status unmistakable.
- **Change cost — 5%:** values easy migration only after safety.

| Option | Writer safety | Transition | Proof | Comprehension | Cost | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 2 | 1 | 3 | 5 | 33 |
| B | 3 | 3 | 2 | 3 | 4 | 57 |
| C | 5 | 5 | 5 | 5 | 4 | **99** |
| D | 5 | 2 | 5 | 2 | 2 | 76 |

### Selected resolution

Select **C**. T1 will label the publication job as the temporary
pre-promotion writer and name its retirement condition. T1B's requested
changes and acceptance criteria will require removal of every temporary
generation/commit/push step, structural proof that only the verified writer
has `contents: write`, and a search showing no second push path or dormant
fallback remains. Rollback uses version control, not preserved production
code.

## T1-05 — Govern the optional early-T3 scheduling exception

### Finding and outcome

The normal order is T1 through T4, but T3 may need acceleration for an active
high-severity advisory. The outcome must balance vulnerability response with
the need to rebaseline all later workflow and package assumptions.

### Options

- **A — Prohibit reordering.** Always leave T3 after T2.
- **B — Allow informal acceleration.** Let implementers start T3 early without
  a recorded policy or downstream rebaseline.
- **C — Use a formal conditional gate.** Default to the listed order. Before
  starting, record the repository security-policy decision, advisory evidence,
  approver, date, and chosen order. If T3 moves first, require T1/T1A/T1B/T2 to
  consume and revalidate T3's actual merge commit.
- **D — Always run T3 first.** Make dependency remediation the unconditional
  first issue.

C can be paired with a time-boxed decision deadline; it must not be paired with
B's unrecorded discretion. A is acceptable only if policy explicitly accepts
the current risk.

### Evaluation rubric

- **Vulnerability-risk handling — 30%:** permits timely remediation when
  policy requires it.
- **Dependency integrity — 30%:** prevents later issues from using stale
  runtime/workflow assumptions.
- **Governance evidence — 20%:** records accountable, dated rationale.
- **Execution clarity — 15%:** gives the downstream author one deterministic
  path after the decision.
- **Coordination overhead — 5%:** lower priority than risk and integrity.

| Option | Risk | Integrity | Governance | Clarity | Overhead | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 5 | 3 | 5 | 5 | 74 |
| B | 3 | 1 | 1 | 2 | 4 | 38 |
| C | 5 | 5 | 5 | 5 | 3 | **98** |
| D | 5 | 2 | 4 | 4 | 2 | 72 |

### Selected resolution

Select **C**. T1 and T3 will state one decision protocol, not competing
dependency graphs. The dated policy record names the reviewed audit, severity,
accepted waiting period, decision owner, and chosen order. Under the normal
order nothing changes. Under an approved early-T3 order, every displaced issue
records the T3 merge commit, reruns its runtime/action/workflow baseline, and
updates affected-file and allowlist expectations before implementation.

## T1A-01 — Make the context-manager implementation input deterministic

### Finding and outcome

The permanent harness accepts only `HelperPath` even though fixtures must use
the tracked caller-context implementation. An out-of-tree harness invocation
cannot prove which context-manager script it exercised.

### Options

- **A — Resolve a sibling implicitly.** Derive the context-manager path from
  the helper or harness directory.
- **B — Read an environment variable.** Let CI supply the path ambiently.
- **C — Add mandatory `ContextManagerPath`.** Resolve both mandatory paths
  exactly once, require tracked ordinary non-reparse files with expected
  versions, and use only the normalized values.
- **D — Combine both scripts into a module.** Import one manifest/module path.

A+C is unnecessary ambiguity unless A is only a friendly wrapper outside the
security contract. C+D could be a later refactor, but T1A intentionally keeps
three self-contained scripts.

### Evaluation rubric

- **Implementation identity — 35%:** proves the exact production context code
  under test.
- **Path-security consistency — 30%:** applies the same literal/provider/link
  rules as the helper.
- **Cross-platform portability — 15%:** behaves consistently from arbitrary
  working directories.
- **Caller usability — 15%:** errors early and explains both required inputs.
- **Scope churn — 5%:** low-weight preference for a small API change.

| Option | Identity | Path safety | Portability | Usability | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 3 | 3 | 4 | 5 | 5 | 71 |
| B | 1 | 2 | 4 | 3 | 4 | 44 |
| C | 5 | 5 | 5 | 4 | 3 | **95** |
| D | 4 | 4 | 3 | 3 | 1 | 71 |

### Selected resolution

Select **C**. `Test-Expand-StyleGuideCandidateArtifact.ps1` will accept
mandatory scalar `HelperPath` and `ContextManagerPath`. It will reject missing,
relative, wildcard, provider-ambiguous, multi-match, non-file, reparse, or
untracked resolutions; require expected version markers; normalize each once;
and pass those exact paths to child invocations. Tests will include both valid
filesystem-provider-qualified paths and independent negative cases for each
script path.

## T1A-02 — Use one durable, complete oracle row per stable case ID

### Finding and outcome

T1A groups ranges such as `V-01..02`, yet acceptance promises one explicit
oracle per stable ID. The outcome is durable failure identity with enough
pre/postcondition detail to diagnose cleanup and filesystem behavior.

### Options

- **A — Keep grouped ranges.** Let the test implementation infer individual
  expected outcomes.
- **B — Generate case metadata only in the harness.** Use a machine-readable
  case table but keep the issue abbreviated.
- **C — Put one explicit row per ID in the issue.** Include setup, invocation,
  expected result/phase, candidate state before teardown, context state,
  diagnostics, sentinel result, and skip policy.
- **D — Maintain a separate test-plan document.** Link the issue to another
  independently edited oracle.
- **E — Combine B and C.** The issue defines the normative row inventory; the
  harness mirrors it in machine-readable metadata and asserts no missing,
  duplicate, or unexpected IDs.

IDs remain additive under C/E: retire an obsolete ID with rationale, but never
renumber a surviving behavior. D can archive evidence but should not become a
second source of truth.

### Evaluation rubric

- **Requirement traceability — 30%:** maps issue behavior to one durable ID.
- **Oracle exactness — 30%:** states result and filesystem/cleanup
  postconditions.
- **Drift resistance — 20%:** detects missing, duplicate, and silently changed
  cases.
- **Failure diagnosis — 15%:** gives operators useful phase/state evidence.
- **Authoring effort — 5%:** verbosity is intentionally low weight.

| Option | Traceability | Exactness | Drift resistance | Diagnosis | Effort | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 2 | 4 | 2 | 5 | 51 |
| B | 4 | 4 | 5 | 3 | 3 | 80 |
| C | 5 | 5 | 4 | 5 | 3 | 94 |
| D | 3 | 4 | 2 | 3 | 2 | 61 |
| E | 5 | 5 | 5 | 5 | 2 | **97** |

### Selected resolution

Select **E**. T1A will replace every grouped range with one normative row per
ID and add the new IDs without renumbering existing ones. The harness will
contain matching machine-readable metadata and fail if the emitted applicable
ID set differs from the table. Each row specifies fixture/setup, exact
entry-point and relevant parameter form, expected phase/result, candidate and
context state before harness teardown, required diagnostics, outside sentinel,
and whether a platform skip is even eligible. The PR evidence reports exactly
one result per applicable ID.

## T1A-03 — Add exact resource-boundary and deceptive-archive cases

### Finding and outcome

T1A declares 8 MiB per-entry, 32 MiB total-uncompressed, and 32 MiB retained
archive limits but supplies no stable cases proving the inequalities or actual
byte enforcement.

### Options

- **A — Test one oversized archive.** Treat any limit failure as sufficient.
- **B — Test below/exact/above values for ordinary ZIPs.** Cover arithmetic
  boundaries but trust entry metadata.
- **C — Add randomized/property fuzzing only.** Generate many sizes without
  durable exact cases.
- **D — Add deterministic boundary and deceptive fixtures.** Create fixtures
  at just below, exactly at, and one byte above each applicable boundary;
  exercise cumulative overflow, actual streamed output exceeding a misleading
  declared length, negative/overflow/inconsistent metadata where constructible,
  and retained archive size. Generate large content sparsely/streamingly in the
  disposable context rather than commit large blobs.

B+D is subsumed by D. C is useful supplementary evidence but cannot replace
named regression cases. Handcrafted raw ZIP bytes are acceptable for metadata
states `ZipArchive` cannot emit.

### Evaluation rubric

- **Limit correctness — 35%:** proves exact inclusive/exclusive semantics and
  overflow handling.
- **Adversarial ZIP coverage — 25%:** distrusts declarations and malformed
  metadata.
- **Harness resource safety — 20%:** avoids uncontrolled memory/disk work.
- **Reproducibility — 15%:** yields stable named cases on all platforms.
- **Fixture cost — 5%:** discourages giant tracked blobs without weakening
  proof.

| Option | Boundaries | Adversarial ZIP | Harness safety | Reproducibility | Cost | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 1 | 4 | 4 | 5 | 52 |
| B | 4 | 3 | 4 | 5 | 4 | 78 |
| C | 4 | 4 | 2 | 2 | 2 | 64 |
| D | 5 | 5 | 5 | 4 | 3 | **95** |

### Selected resolution

Select **D**, with optional bounded fuzzing after the mandatory cases. Add
stable `R-*` rows for each limit's below/exact/above behavior, declared-total
and actual-total overflow, actual per-entry overflow, retained archive overflow,
and malformed length/arithmetic states. The issue will define “at most” as
inclusive, require checked 64-bit accumulation, stop copying immediately on the
first disallowed byte, keep candidate cleanup semantics intact, and cap
fixture-generation time and disk usage. Fixed raw ZIP fixtures must have
documented SHA-256 values and construction rationale.

## T1A-04 — Complete the public-input rejection matrix

### Finding and outcome

The public helper and harness contracts declare digest, download cardinality,
path, type, and optional-label semantics that the current case list does not
fully exercise.

### Options

- **A — Rely on PowerShell parameter binding.** Test only inputs that reach the
  function body.
- **B — Add representative negatives.** Use one bad digest, one bad path, and
  one empty label.
- **C — Test every declared equivalence class.** Give independent stable IDs to
  digest length/character/prefix failures; zero/multiple/wrong-type downloads;
  relative/wildcard/provider/missing/multi-match/helper/context paths; and
  omitted, explicit-null, empty, whitespace, valid, and type-invalid labels
  where binding permits them. Assert parameter-phase failure precedes
  filesystem/archive work.
- **D — Use generative fuzzing.** Randomize strings and paths and assert only
  success/failure.

C can include A's binding failures as expected native binding results rather
than reimplement binding. C+D is useful only after the durable matrix exists.

### Evaluation rubric

- **Untrusted-input coverage — 35%:** covers each public attack/ambiguity
  class.
- **Contract semantics — 25%:** distinguishes omission, null, empty, type, and
  cardinality precisely.
- **Fail-early ordering — 20%:** proves invalid inputs cause no filesystem work.
- **Diagnostic specificity — 15%:** maps failures to stable phase/reason.
- **Test volume — 5%:** case count is subordinate to coverage.

| Option | Input coverage | Semantics | Ordering | Diagnostics | Volume | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 2 | 4 | 2 | 5 | 51 |
| B | 3 | 3 | 4 | 3 | 4 | 65 |
| C | 5 | 5 | 5 | 5 | 3 | **98** |
| D | 4 | 4 | 3 | 2 | 2 | 68 |

### Selected resolution

Select **C**. Add durable parameter/download/path/label IDs with one row per
equivalence class. Expected native binder failures remain native; all
application-level grammar failures must report the `parameter` or `download`
phase as specified. Every invalid-input case asserts no candidate creation, no
archive open where applicable, no mutation of preexisting leaves, unchanged
sentinels, and the exact diagnostic distinction between an omitted label
(`unavailable`) and an explicitly supplied invalid value.

## T1A-05 — Exercise both production cleanup lifecycles

### Finding and outcome

Current `K-*` coverage emphasizes candidate cleanup. The companion
caller-context teardown also owns files/directories and must preserve the
primary failure while retaining uncertain state.

### Options

- **A — Test candidate cleanup only.** Assume context cleanup is a thin wrapper.
- **B — Unit-test context cleanup separately.** Cover normal and idempotent
  removal but not the combined failure path.
- **C — Test each lifecycle independently and together.** Add normal,
  idempotent, unjournaled entry, substituted link/reparse, missing/read-error,
  primary-failure-plus-cleanup-failure, and partial-owned-state cases. Assert
  nonrecursive deepest-first behavior, retained uncertain state, and both
  diagnostics.
- **D — Add a recursive best-effort fallback.** Prefer leaving the runner clean
  even when ownership becomes uncertain.

B+C is included in C. A recursive fallback contradicts the ownership model and
must remain prohibited even for CI hygiene.

### Evaluation rubric

- **Data-loss resistance — 35%:** never deletes unproved or substituted state.
- **Primary-error preservation — 25%:** cleanup cannot hide the cause.
- **Lifecycle completeness — 20%:** covers candidate and caller ownership.
- **Idempotency/postcondition proof — 10%:** repeated safe teardown is defined.
- **OS-family evidence — 5%:** executes relevant link behavior on both.
- **Implementation simplicity — 5%:** deliberately subordinate to safety.

| Option | Data safety | Error preservation | Completeness | Idempotency | OS evidence | Simplicity | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 3 | 2 | 2 | 4 | 5 | 50 |
| B | 3 | 3 | 3 | 4 | 4 | 4 | 64 |
| C | 5 | 5 | 5 | 5 | 5 | 3 | **98** |
| D | 1 | 2 | 4 | 3 | 4 | 5 | 48 |

### Selected resolution

Select **C**. Extend `K-*` with distinct candidate and context families. Every
combined case captures a primary exception, disposes streams, invokes the
production candidate cleanup, then invokes the production caller cleanup with
the primary failure. The oracle requires the primary reason to remain
prominent, the cleanup reason and retained exact root to remain available,
sentinels unchanged, and no deletion after the first uncertain ownership
condition. Normal and repeated teardown must finish with only the explicit
test-owned parent eligible for harness cleanup.

## T1A-06 — Compare the candidate layer with the corresponding PS layer

### Finding and outcome

T1A currently says “PSStyleGuide P1,” which becomes ambiguous when P1 is split
and can accidentally compare generator or writer behavior with candidate
validation.

### Options

- **A — Keep the generic P1 label.** Let reviewers locate relevant text.
- **B — Target the candidate-validation layer by name, section, commit, and
  eventual issue ID.** Compare only public inputs, artifact identity, path
  security, limits, extraction, context ownership, cleanup, diagnostics, cases,
  and platform support.
- **C — Wait for a PS P1A file before implementing T1A.**
- **D — Share the production validator module between repositories now.**

B works whether PS is monolithic or split: the evidence records “P1,
candidate-validation section” or “P1A” at the exact reviewed commit. B+D can be
considered later but runtime sharing is an explicit T1A non-goal.

### Evaluation rubric

- **Security-semantic equivalence — 40%:** compares behaviors that must not
  drift.
- **Boundary relevance — 25%:** excludes unrelated generator/writer rows.
- **Version traceability — 20%:** binds comparison to an exact PS state.
- **Reviewer actionability — 10%:** makes blockers and intentional differences
  obvious.
- **Cross-repo coordination — 5%:** avoids unnecessary waiting.

| Option | Security | Boundary | Traceability | Actionability | Coordination | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 3 | 2 | 2 | 3 | 5 | 53 |
| B | 5 | 5 | 5 | 5 | 4 | **99** |
| C | 2 | 4 | 1 | 2 | 2 | 46 |
| D | 4 | 5 | 4 | 2 | 1 | 78 |

### Selected resolution

Select **B**. T1A will call this the reciprocal
**candidate-validation-layer** matrix. It records the exact PS commit, current
issue/section identifier, and row evidence. The name automatically becomes
P1A if the split exists; otherwise it names the exact P1 section. Repository
manifest names may differ. Unexplained differences in path, digest, resource,
cleanup, diagnostic, or skip behavior block merge. This keeps the comparison
stable across planning-file renames.

## T1B-01 — Replace the impossible cross-workflow dependency

### Finding and outcome

T1B says approval depends on Markdown/Ubuntu validation, but
`markdownlint.yml` is independently triggered and cannot appear in
`build.yml`'s `needs` context. The writer must have an enforceable dependency
on validation of the same commit.

### Options

- **A — Keep workflows independent.** Rely on branch protection for pull
  requests and let the push writer proceed without the Markdown result.
- **B — Duplicate Markdown steps in `build.yml`.** Keep the independent
  workflow and add a second local job for writer gating.
- **C — Make `markdownlint.yml` reusable.** Give it `workflow_call`, remove
  duplicate direct triggers, and call it as a job from the event-owning
  `build.yml`. Approval directly needs that called job, preparation, and
  Windows validation.
- **D — Move all Markdown steps into `build.yml`.** Delete the separate
  workflow.
- **E — Chain with `workflow_run`.** Start publication after a separate
  Markdown workflow completes and rediscover its event/SHA/artifact.

C+D both produce one job graph, but C retains a coherent reusable validation
unit for T2/T3/T4. E introduces a privileged second event and complex
untrusted-artifact/SHA binding without benefit here.

### Evaluation rubric

- **Gate correctness — 35%:** writer consumes a mandatory result for the same
  event commit.
- **No duplicate execution — 20%:** avoids two drifting lint pipelines.
- **Permission/event security — 20%:** preserves read-only validation and one
  write job.
- **Future harness maintainability — 15%:** T2/T3/T4 can extend one validation
  surface.
- **Actions UI clarity — 5%:** failures remain understandable.
- **Migration churn — 5%:** low-weight scope concern.

| Option | Gate | Duplication | Security | Maintainability | UI | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 5 | 4 | 4 | 4 | 5 | 64 |
| B | 5 | 2 | 4 | 2 | 3 | 3 | 71 |
| C | 5 | 5 | 5 | 5 | 4 | 3 | **97** |
| D | 5 | 5 | 5 | 4 | 3 | 2 | 92 |
| E | 3 | 3 | 2 | 2 | 2 | 1 | 50 |

### Selected resolution

Select **C**. `build.yml` remains the sole event owner for pull requests,
`main` pushes, and optional merge queue. `markdownlint.yml` exposes only the
reviewed `workflow_call` interface and runs as a read-only caller job for the
same SHA. The approval job uses `if: always()` and directly needs preparation,
the called Markdown/Ubuntu workflow, and the Windows matrix; it requires all
three results to be `success`. T2/T3/T4 extend that reusable workflow. No
independent trigger or duplicate lint run remains, and only the final writer
has `contents: write`.

## T1B-02 — Transport the four preparation hashes immutably

### Finding and outcome

Preparation records four candidate SHA-256 values, the writer must compare
against them, but the declared job-output list omits them. The outcome is an
explicit same-run trust path without changing the helper's exact four-entry
artifact manifest.

### Options

- **A — Remove the preparation-hash comparison.** Trust the upload artifact
  digest plus writer regeneration.
- **B — Put hashes only in logs/job summary.** Let the writer or reviewer read
  them informally.
- **C — Add four statically named preparation job outputs.** Emit one bare
  64-lowercase-hex hash per exact repository path and propagate them through
  approval to the writer.
- **D — Upload a second evidence artifact.** Store a hash manifest separately
  and bind both artifact IDs/digests.
- **E — Put a manifest inside the candidate ZIP.** Expand the helper contract
  to five entries.

A remains cryptographically defensible but removes an inexpensive independent
cross-check. C+D is excessive. E breaks the exact candidate manifest and
cross-repository validator convergence.

### Evaluation rubric

- **Candidate/path binding — 30%:** associates each hash with one exact output
  path.
- **Same-run tamper resistance — 25%:** uses immutable workflow transport.
- **Transport simplicity — 15%:** avoids a second artifact/protocol.
- **Writer cross-check value — 20%:** independently detects extraction/path
  mistakes before regeneration.
- **Secret/output-limit safety — 10%:** values are nonsecret and bounded.

| Option | Binding | Tamper resistance | Simplicity | Cross-check | Output safety | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 3 | 5 | 4 | 5 | 68 |
| B | 1 | 1 | 4 | 2 | 5 | 41 |
| C | 5 | 5 | 5 | 5 | 5 | **100** |
| D | 5 | 5 | 2 | 4 | 4 | 85 |
| E | 4 | 4 | 2 | 3 | 4 | 70 |

### Selected resolution

Select **C**. Preparation emits
`copilot_instructions_sha256`,
`terraform_instructions_sha256`, `style_guide_chat_sha256`, and
`style_guide_full_sha256` in addition to artifact ID/digest/name, change flag,
event SHA, and target ref. Each value is computed from the already validated
ordinary candidate file, normalized to lowercase bare 64-hex, and validated
again by approval and writer. The writer maps each output to one fixed path,
compares it with the extracted file, then still independently regenerates and
compares all four bytes. Hashes never come from the artifact itself.

## T1B-03 — Define unique evidence for all four matrix cells

### Finding and outcome

A matrix job cannot safely expose one shared output name because the
last-finishing cell overwrites it. Approval needs proof that exactly the four
Windows edition/EOL cells ran against the same candidate.

### Options

- **A — Use one shared matrix output.** Treat matrix job success as enough.
- **B — Use four static unique outputs in one matrix job.** Each cell emits only
  its own key and a canonical evidence payload; approval requires exactly all
  four.
- **C — Replace the matrix with four named jobs.** Duplicate the validation
  steps and inspect each job directly.
- **D — Upload one evidence artifact per cell.** Aggregate four unique artifact
  IDs/digests later.

B+C is unnecessary duplication. B may additionally use uniquely named failure
diagnostic artifacts, but those artifacts are not success evidence. GitHub's
documented unique-output requirement rules out A.

### Evaluation rubric

- **Four-cell completeness — 35%:** proves every exact edition/EOL pair.
- **Overwrite/order safety — 30%:** is independent of matrix finish order.
- **Definition maintainability — 15%:** avoids four drifting scripts.
- **Failure diagnosis — 15%:** identifies the exact missing/failing cell.
- **Workflow churn — 5%:** low-weight YAML size concern.

| Option | Completeness | Order safety | Maintainability | Diagnosis | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 1 | 5 | 2 | 5 | 39 |
| B | 5 | 5 | 5 | 4 | 4 | **96** |
| C | 5 | 5 | 3 | 5 | 2 | 91 |
| D | 4 | 5 | 2 | 4 | 2 | 78 |

### Selected resolution

Select **B**. The static matrix assigns canonical IDs
`windows-powershell-5.1-lf`, `windows-powershell-5.1-crlf`,
`powershell-7-lf`, and `powershell-7-crlf`. Each cell writes only the matching
statically declared output key. Its compact canonical JSON contains the cell
ID, artifact ID/digest, event SHA, full ref, and the four candidate hashes.
Approval rejects missing, empty, duplicate, extra, malformed, or mismatched
payloads and validates the expected key-to-cell mapping. `fail-fast: false`
preserves all failure evidence; no output value is trusted if the matrix job
result is not success.

## T1B-04 — Make structural workflow-policy validation executable

### Finding and outcome

T1B requires structural proof of actions, roles, permissions, triggers, and
dependencies but names no parser. Text/regular-expression checks cannot
reliably interpret YAML mappings, anchors, scalars, or nesting.

### Options

- **A — Use regular expressions and line matching.**
- **B — Rely on GitHub accepting the workflow.** Add no repository validator.
- **C — Add a direct locked Node YAML parser and an in-repository policy
  script.** Parse both workflows with duplicate-key rejection, validate an
  exact schema/policy model, and test positive/negative fixtures.
- **D — Download and pin `actionlint`.** Use its syntax/schema checks plus text
  policy assertions.
- **E — Use a runner-preinstalled Ruby/Python YAML library.** Avoid manifest
  changes but depend on hosted-image contents.

C+D can be complementary, but `actionlint` alone does not express the
repository's exact role/count/credential policy. C expands T1B's file scope;
that cost ranks below deterministic parsing. T3 later revalidates the direct
parser dependency with the complete package tree.

### Evaluation rubric

- **YAML interpretation correctness — 35%:** handles structure and duplicate
  keys safely.
- **Policy expressiveness — 25%:** can enforce exact repository-specific
  invariants.
- **Dependency reproducibility — 20%:** the parser version is declared and
  locked.
- **Local/hosted portability — 10%:** same command works for contributors and
  CI.
- **Supply-chain surface — 5%:** minimizes new trust where possible.
- **Issue-scope churn — 5%:** lowest-weight concern.

| Option | Parsing | Policy | Reproducibility | Portability | Supply chain | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 2 | 5 | 5 | 5 | 5 | 64 |
| B | 3 | 1 | 5 | 5 | 5 | 5 | 66 |
| C | 5 | 5 | 5 | 5 | 3 | 2 | **95** |
| D | 4 | 3 | 4 | 4 | 3 | 3 | 73 |
| E | 5 | 5 | 2 | 3 | 4 | 4 | 82 |

### Selected resolution

Select **C**. Add
`.github/workflows/Validate-WorkflowPolicy.mjs` and declare one reviewed direct
YAML parser in `package.json`/lockfile. The script accepts exact workflow paths,
uses safe core-schema parsing with duplicate keys rejected, forbids custom
tags/aliases if unsupported by the validator, and validates events,
permissions, job graph, called-workflow boundary, action
repository/SHA/comment/role/count, checkout credentials, Node/cache settings,
artifact options, matrix IDs, outputs, and the sole write job. It has stable
fixture IDs for missing, extra, duplicate, dynamic, mutable, wrong-role, and
swapped-action cases. T1B's affected files will expand accordingly; T3 later
owns the final dependency upgrade/audit state rather than deleting this
validator.

## T1B-05 — Compare the writer layer with the corresponding PS layer

### Finding and outcome

T1B's generic reference to PSStyleGuide P1 obscures whether credential,
identity, artifact, and lease behavior are actually compared with the PS
writer layer.

### Options

- **A — Retain generic P1 comparison.**
- **B — Define a writer-layer semantic matrix.** Bind it to the exact PS commit
  and current section/issue ID; compare artifact identity, trusted rerun,
  credential lifetime, four-local object identity, changed paths, commit
  construction, lease/refspec, diagnostics, and workflow topology.
- **C — Block T1B until a formal P1B issue exists.**
- **D — Require textually identical workflows.** Treat any repository-specific
  topology difference as failure.

B permits intentional event/path/artifact-name differences while blocking
unexplained trust-boundary differences. Textual identity would make harmless
repository differences obscure the security comparison.

### Evaluation rubric

- **Credential-boundary congruence — 35%:** detects wider secret lifetime.
- **Git/artifact identity congruence — 30%:** compares the complete trusted
  publication model.
- **Topology relevance — 15%:** distinguishes intentional repository event/job
  differences.
- **Evidence provenance — 15%:** records exact commits and row evidence.
- **Coordination delay — 5%:** avoids waiting on filenames.

| Option | Credentials | Identity | Topology | Provenance | Delay | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 2 | 2 | 2 | 5 | 43 |
| B | 5 | 5 | 5 | 5 | 4 | **99** |
| C | 2 | 3 | 4 | 1 | 1 | 48 |
| D | 4 | 4 | 2 | 4 | 2 | 72 |

### Selected resolution

Select **B**. T1B will call the artifact/promotion comparison the reciprocal
**writer-layer** matrix and record the exact PS commit plus the current P1
writer section or P1B identifier. Wider credential persistence, weaker
artifact selection, absent trusted regeneration, ambiguous Git object
identity, or a weaker lease is a blocker. Different guide paths, event names,
and job decomposition require rationale and tests but may be intentional.

## T2-01 — Define and enforce provider-download partial-file semantics

### Finding and outcome

AWS, Azure, and GCS CLIs can leave output after a failed download. T2's
destination is sensitive state, so the sample must define exactly what exists
after success, ordinary failure, and ownership uncertainty.

### Options

- **A — Retain the failed final destination.** Label it invalid and require a
  new path for retry.
- **B — Download directly to the final path and delete it on nonzero exit.**
- **C — Use an invocation-owned private temporary directory and success-only
  publication.** Download to one absent temporary leaf, inspect exit/type,
  validate state, then create the requested absent final path without
  replacement. On failure, delete only a proven ordinary owned partial;
  otherwise retain uncertain state and report it.
- **D — Leave provider behavior unspecified.** Merely warn that a partial may
  exist.

A is useful as a forensic mode but poor default confidentiality. C can expose
an explicit `KEEP_FAILED_STATE=1` advanced option only if the operator requests
it before invocation; that permutation is unnecessary for copy-safe baseline
guidance. B has a larger window where the user-visible final name contains
invalid state.

### Evaluation rubric

- **State-integrity postcondition — 30%:** the final path means validated state
  or remains absent.
- **Sensitive-data minimization — 25%:** removes proven invalid partials.
- **Ownership/link safety — 25%:** never deletes or overwrites uncertain state.
- **Operator usability — 15%:** retries and errors are deterministic.
- **Sample complexity — 5%:** low priority for a destructive-recovery guide.

| Option | Integrity | Confidentiality | Ownership | Usability | Complexity | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 2 | 4 | 2 | 5 | 53 |
| B | 3 | 4 | 3 | 3 | 4 | 66 |
| C | 5 | 5 | 5 | 5 | 2 | **97** |
| D | 1 | 1 | 1 | 3 | 5 | 30 |

### Selected resolution

Select **C** for AWS, Azure, and GCS. Each block sets `umask 077`, validates an
explicit absolute recovery parent/final path, creates one private
invocation-owned temporary directory, and gives the provider one absent
temporary leaf. It captures native status without allowing `set -e` to bypass
cleanup. Success requires one ordinary non-link nonempty file, expected state
validation, and a no-replace publication to the still-absent final leaf.
Ordinary provider failure deletes only the exact journaled ordinary partial
and empty owned directory. A missing, substituted, linked, unreadable, or
unjournaled entry is retained; the command fails and reports the exact retained
root. It never recursively removes, follows, or retries into the same final
path.

## T2-02 — Identify the sample language as Bash, not generic POSIX

### Finding and outcome

The GCS filter and harness use Bash-specific `[[ ... =~ ... ]]` behavior.
Calling the environment “Bash or compatible POSIX” overclaims portability and
invites copying under shells that parse the code differently.

### Options

- **A — Keep the generic POSIX claim.**
- **B — Label and test Bash exactly.** Add a `#!/usr/bin/env bash` contract,
  minimum supported Bash version, strict options, and a runtime version guard.
- **C — Rewrite every block to strict POSIX `sh`.** Remove arrays, `[[ ]]`,
  regex operators, and Bash-only parameter behavior.
- **D — Publish both Bash and POSIX variants.** Maintain parallel marker blocks
  and tests.

B is compatible with the provider CLIs and current harness. C is viable but
adds broad sample churn with little operator benefit. B+C is contradictory
unless separate variants are maintained as D.

### Evaluation rubric

- **Copy/paste correctness — 35%:** the named interpreter accepts the syntax.
- **Syntax-contract truthfulness — 30%:** documentation matches actual
  language features.
- **Portability honesty — 20%:** makes platform prerequisites explicit.
- **Documentation clarity — 10%:** avoids duplicate variants and caveats.
- **Revision churn — 5%:** low-weight preference for the existing samples.

| Option | Copy correctness | Truthfulness | Portability | Clarity | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 1 | 2 | 3 | 5 | 39 |
| B | 5 | 5 | 4 | 5 | 5 | **96** |
| C | 5 | 5 | 5 | 3 | 1 | 92 |
| D | 5 | 5 | 5 | 2 | 1 | 90 |

### Selected resolution

Select **B**. Every shell marker and the permanent harness will be described as
Bash, use a Bash shebang, reject execution under another shell, and record the
actual version. The implementation selects and documents a minimum available
on the supported GitHub-hosted Ubuntu runner; syntax tests execute with that
interpreter. The issue will remove “compatible POSIX” wording without claiming
that the provider CLIs themselves are Bash-specific.

## T2-03 — Inherit T1B's implementable workflow topology

### Finding and outcome

T2 adds a permanent Bash harness to Markdown validation. It must extend the
same-run callable workflow selected in T1B rather than recreate an independent
check that the approval job cannot observe.

### Options

- **A — Add one stable step to the T1B reusable `markdownlint.yml`.** The
  event-owning build call automatically gates the exact SHA.
- **B — Create a new independently triggered state-sample workflow.**
- **C — Duplicate the T2 harness in a new `build.yml` job.**
- **D — Run the harness only in local validation, outside Actions.**

A can use a dedicated step and timeout while remaining within the called job.
If runtime duration later warrants a separate called job, it must still be a
direct dependency in the same caller graph; that is a safe permutation of A.

### Evaluation rubric

- **Promotion dependency integrity — 30%:** failure blocks approval/writer.
- **Exact-SHA association — 25%:** evidence belongs to the candidate event.
- **No duplicated contract — 20%:** one harness invocation definition.
- **Later-issue maintainability — 15%:** T3/T4 can extend the same topology.
- **File/workflow scope — 10%:** avoids unnecessary event surfaces.

| Option | Gate integrity | SHA binding | Duplication | Maintainability | Scope | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 5 | 5 | 5 | 5 | 4 | **98** |
| B | 2 | 3 | 3 | 2 | 3 | 51 |
| C | 4 | 5 | 2 | 3 | 2 | 70 |
| D | 1 | 2 | 5 | 4 | 5 | 58 |

### Selected resolution

Select **A**. T2 modifies the callable `markdownlint.yml` and adds one named,
read-only Bash-harness step after checkout and before the called workflow
returns success. `build.yml` needs no new cross-workflow edge: its existing
Markdown callable job now includes T2 evidence for the same SHA. The structural
workflow validator's allowlist/fixtures are updated atomically for the exact
new step and no new trigger, permission, action, or writer path is introduced.

## T2-04 — Give partial-file cases durable provider-prefixed IDs

### Finding and outcome

The harness anticipates failure/partial behavior but does not give each
provider outcome a durable identity. Failures need to identify both provider
adapter and lifecycle phase.

### Options

- **A — Keep prose behavior groups.**
- **B — Add explicit provider-prefixed rows.** Use independent `AWS-*`,
  `AZURE-*`, and `GCS-*` IDs for nonzero/no-file, nonzero/ordinary-partial,
  nonzero/substituted-or-uncertain partial, success/invalid-state, successful
  no-replace publication, and existing-final refusal.
- **C — Use one shared parameterized ID per behavior.** Report the provider as
  data rather than part of identity.
- **D — Generate IDs from marker names and loop indexes.**

B may share fixture functions internally; stable identity need not imply code
duplication. C is compact but makes a regression in one provider harder to
track historically.

### Evaluation rubric

- **Provider traceability — 30%:** identifies the exact adapter contract.
- **Failure diagnosis — 25%:** names provider plus lifecycle state.
- **Future-provider extensibility — 20%:** new providers add without renumber.
- **Oracle completeness — 20%:** one setup/result/filesystem row per ID.
- **Table verbosity — 5%:** intentionally minor.

| Option | Traceability | Diagnosis | Extensibility | Oracle | Verbosity | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 2 | 3 | 2 | 5 | 47 |
| B | 5 | 5 | 5 | 5 | 4 | **99** |
| C | 4 | 3 | 5 | 4 | 3 | 78 |
| D | 4 | 4 | 4 | 3 | 2 | 74 |

### Selected resolution

Select **B**. Add one normative row for every provider/lifecycle permutation,
with IDs such as `AWS-PART-01`, `AZURE-PART-01`, and `GCS-PART-01`; retain
existing unrelated IDs. Each row names stub exit behavior, bytes/entry type
left at the temporary path, expected final-path state, expected proven cleanup
or retention, diagnostics, and sentinels. The harness asserts the complete
applicable ID set and reports exactly one result per ID.

## T3-01 — Define and invoke one permanent audit validator

### Finding and outcome

T3 describes exception rules but names no permanent implementation that owns
normalization, schema, expiry, topology equality, or CI failure.

### Options

- **A — Implement rules inline in workflow YAML.**
- **B — Put validation only inside the PowerShell integration harness.**
- **C — Add a tracked Node validator with a pure core and CLI.** Feed it the
  captured npm audit JSON and optional exception file; invoke the same script
  locally, from the PowerShell harness, and from the hosted workflow.
- **D — Adopt an external audit-suppression utility.**
- **E — Forbid all residuals.** Fail on every nonzero npm audit and remove the
  exception design.

C+E is the preferred clean-baseline behavior: the validator passes clean
without a file while retaining the governed residual path if genuinely needed.
A can only be a thin command invocation, not the policy implementation.

### Evaluation rubric

- **Recurring enforcement — 35%:** one durable gate runs on every required
  event.
- **Normalization/schema correctness — 30%:** exact comparison is implemented
  once.
- **Fixture testability — 20%:** deterministic reports and clocks can exercise
  negative cases.
- **Operator diagnostics — 10%:** stable exit classes and actionable diffs.
- **Added-code burden — 5%:** subordinate to enforcement quality.

| Option | Enforcement | Correctness | Testability | Diagnostics | Burden | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 3 | 3 | 2 | 2 | 5 | 56 |
| B | 2 | 4 | 4 | 3 | 4 | 64 |
| C | 5 | 5 | 5 | 5 | 3 | **98** |
| D | 3 | 3 | 2 | 3 | 2 | 55 |
| E | 5 | 3 | 4 | 5 | 5 | 84 |

### Selected resolution

Select **C**, with zero residuals as the preferred state. Add
`.github/workflows/Validate-NpmAudit.mjs`. Its pure exported core accepts an
audit object, optional exception object, and injected UTC instant for unit
fixtures; its CLI always obtains real current UTC and has no clock-bypass
argument. The workflow captures `npm audit --package-lock-only --json` and
native status, then calls the validator. The validator emits a canonical
summary, uses stable exit classes for usage/schema, unapproved/mismatched
residuals, and expired policy, and never treats `--audit-level` as approval.
The integration harness imports the pure core for fixtures and invokes the
real CLI for clean-install evidence.

## T3-02 — Use a residual-audit identity derivable from npm output

### Finding and outcome

npm audit report version 2 does not directly relate every advisory URL to each
installed node path. T3's advisory-URL/path-pair identity can therefore
over-approve a Cartesian product not proved by the report.

### Options

- **A — Keep one record per advisory URL/path pair.** Pair all URLs and nodes
  under a vulnerability object.
- **B — Separate finding identity from topology.** Use unique
  `(Package, AdvisoryUrl)` findings plus an exact package-keyed
  `AuditNodePaths` set.
- **C — Use only GHSA/CVE/source IDs.** Ignore package and path topology.
- **D — Approve package names only.**
- **E — Implement semver-aware advisory-to-installed-node mapping.** Resolve
  each node's installed version and test it against every advisory range before
  forming pairs.

E is correct but materially more complex and dependent on npm report/tree
details. B preserves exact finding and topology equality without asserting an
edge npm did not supply. B+E could later add stronger derived evidence without
changing the approval key.

### Evaluation rubric

- **Source derivability — 35%:** every key follows from report/tree evidence.
- **Over-approval resistance — 30%:** avoids granting unrelated advisory/path
  combinations.
- **Topology sensitivity — 20%:** new or removed installed paths are detected.
- **Human review clarity — 10%:** approvers understand what risk is accepted.
- **Algorithmic complexity — 5%:** low weight but favors fewer parsing traps.

| Option | Derivable | Least approval | Topology | Review clarity | Complexity | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 2 | 4 | 3 | 4 | 52 |
| B | 5 | 5 | 5 | 5 | 4 | **99** |
| C | 3 | 3 | 2 | 4 | 4 | 59 |
| D | 5 | 1 | 1 | 3 | 5 | 56 |
| E | 5 | 5 | 5 | 3 | 1 | 92 |

### Selected resolution

Select **B**. The normalized current state has two sorted sets:
`Findings`, uniquely keyed by exact package name plus canonical advisory URL,
and `AuditNodePaths`, keyed by exact package name with a sorted unique array of
npm node paths. Severity, vulnerable range, source ID, fix availability, and
analysis remain attributes of a finding but are not identity substitutes. The
validator requires exact equality for both sets, rejects duplicates and
unknown packages, and reports additions/removals separately. It never creates
an advisory/path Cartesian product.

## T3-03 — Define an exact maximum approval lifetime

### Finding and outcome

“Within repository maximum” is unenforceable because no maximum, clock format,
or boundary is defined.

### Options

- **A — Require only a future expiration.**
- **B — Use a fixed 90-day maximum.**
- **C — Use a fixed 30-day maximum, permitting shorter approvals.**
- **D — Use severity-specific maxima.** For example, 7/14/30/90 days.
- **E — Expire at the end of a project sprint/release.**

C can be tightened by policy for a particular finding. D may be useful in a
larger risk platform, but adds classification and severity-change edge cases to
this small repository. Calendar labels alone in E are timezone-ambiguous.

### Evaluation rubric

- **Residual-risk window — 35%:** forces timely removal or reapproval.
- **Rule precision — 25%:** exact timestamps and boundary semantics.
- **Clock-test determinism — 20%:** fixtures can prove before/at/after expiry.
- **Accountability/renewal quality — 15%:** requires a new evidence review.
- **Administrative effort — 5%:** low priority relative to exposure.

| Option | Risk window | Precision | Testability | Accountability | Effort | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 1 | 2 | 2 | 5 | 31 |
| B | 3 | 5 | 5 | 4 | 4 | 82 |
| C | 5 | 5 | 5 | 5 | 3 | **98** |
| D | 5 | 3 | 4 | 4 | 2 | 80 |
| E | 4 | 2 | 3 | 3 | 3 | 62 |

### Selected resolution

Select **C**. Each approval uses canonical whole-second RFC 3339 UTC
`createdAt` and `expiresAt` values ending in `Z`. `expiresAt` must be later than
`createdAt`, no later than exactly 30 × 24 hours afterward, and is an exclusive
boundary: the record is invalid when `now >= expiresAt`. The CLI uses actual
UTC. Pure-core tests inject instants one second before, exactly at, and one
second after. Renewal requires updated clean-install/audit evidence, risk
analysis, owner approval, and follow-up status; editing only the timestamp is
forbidden.

## T3-04 — Reject stale, excess, malformed, and unused permission

### Finding and outcome

An exception mechanism is least-privileged only when it fails for permission
that is no longer needed, not merely for newly unapproved findings.

### Options

- **A — Require current residuals to be a subset of exceptions.** Permit stale
  exception entries.
- **B — Require exact closed-schema equality.** Reject missing and extra
  findings/paths, duplicates, unknown fields, malformed values, expired
  records, and any exception file when the audit is clean.
- **C — Permit supersets with warnings.**
- **D — Automatically rewrite/prune the exception file in CI.**
- **E — Validate only JSON syntax and required fields.**

B can be paired with a separate local `--explain` report, but CI remains
read-only and fail-closed. D risks turning an approval change into an
unreviewed generated edit.

### Evaluation rubric

- **Least-privilege equality — 35%:** permission exactly matches current risk.
- **Stale-approval detection — 25%:** removed advisories/paths force cleanup.
- **Schema integrity — 20%:** rejects ambiguity, duplicates, and hidden fields.
- **Remediation diagnostics — 15%:** distinguishes missing versus excess data.
- **Routine noise — 5%:** warnings/churn have low priority.

| Option | Equality | Staleness | Schema | Diagnostics | Noise | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 1 | 2 | 3 | 5 | 41 |
| B | 5 | 5 | 5 | 5 | 4 | **99** |
| C | 3 | 1 | 3 | 3 | 4 | 51 |
| D | 4 | 4 | 3 | 5 | 2 | 77 |
| E | 1 | 1 | 2 | 2 | 5 | 31 |

### Selected resolution

Select **B**. The validator implements a versioned, closed JSON schema and
canonical normalization. It rejects unknown/missing properties, wrong types,
noncanonical/duplicate URLs or paths, duplicate finding identities, duplicate
package topology, invalid severity/ranges/timestamps, empty ownership and
follow-up fields, missing real issue URLs, expired approvals, current residuals
without approval, approvals without current residuals, topology additions or
removals, and a present exception file when the normalized audit is empty.
Output names every exact addition/removal without dumping sensitive package
contents.

## T3-05 — Add a complete stable audit-case inventory

### Finding and outcome

The current stable inventory covers npm install/lint and hook behavior but not
the new audit validator's clean, residual, topology, schema, or clock states.

### Options

- **A — Exercise only the current live audit.**
- **B — Add ad hoc unit assertions inside the validator.**
- **C — Add one normative `AUDIT-*` row per behavior and mirror it in the
  integration harness.** Generate deterministic in-memory JSON fixtures and
  call the pure validator core; also run the CLI on the real clean-install
  report.
- **D — Add a separate test framework and tracked fixture tree.**

C+D may be worthwhile if fixtures become large, but the current schema can be
covered without another framework or dozens of files. The live registry result
cannot replace deterministic negative cases.

### Evaluation rubric

- **Policy-state coverage — 35%:** clean, approved, new, removed, and topology
  states.
- **Production integration proof — 20%:** real CLI and clean audit are run.
- **Expiry-boundary proof — 15%:** clock behavior is deterministic.
- **Schema-adversary coverage — 15%:** malformed/duplicate/unknown cases fail.
- **Failure-message quality — 10%:** each ID asserts reason/class.
- **Fixture maintenance cost — 5%:** low priority.

| Option | Policy states | Integration | Clock | Schema | Messages | Cost | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 1 | 1 | 1 | 1 | 5 | 24 |
| B | 4 | 2 | 5 | 5 | 4 | 4 | 78 |
| C | 5 | 5 | 5 | 5 | 5 | 4 | **99** |
| D | 5 | 3 | 5 | 5 | 5 | 2 | 89 |

### Selected resolution

Select **C**. Add stable rows for: clean/no-file pass; clean/file-present fail;
residual/no-file fail; exact approved residual pass; new and removed finding;
new and removed node path; one second before expiry, exact expiry, and after
expiry; malformed timestamp/schema; unknown field; duplicate finding, URL,
package, and node path; missing owner/follow-up/approval; invalid issue URL;
non-JSON/truncated audit; and canonical-order independence. Each row asserts
exit class, normalized additions/removals, exception-file state, and no input
mutation. A separate integration ID captures a real `npm audit` report and
invokes the tracked CLI after `npm ci`.

## T3-06 — Prove every boundary of the bounded Node policy

### Finding and outcome

T3 intends to support reviewed even LTS lines while rejecting lower, odd,
intervening, and unreviewed future majors. `engines.node` alone is advisory and
the hook must validate before `node_modules` exists.

### Options

- **A — Use an unbounded minimum (`>=22`).**
- **B — Put a bounded range only in `package.json`.**
- **C — Add a dependency-free tracked Node policy module.** The real hook
  resolves `node`, invokes the module with the actual process version, and then
  resolves npm. Tests import its pure range function; workflow/package values
  are structurally cross-checked.
- **D — Use the installed `semver` package.** Require `npm ci` before policy
  validation.
- **E — Parse major versions directly in shell.**

C can use simple explicit admitted-major intervals rather than implementing
general semver. D contradicts the fail-before-package-check requirement. E is
viable but duplicates logic across Git Bash/PowerShell test contexts.

### Evaluation rubric

- **Actual hook enforcement — 30%:** the commit fails before tooling use.
- **Pre-install independence — 25%:** no `node_modules` is required.
- **Gap/future rejection — 25%:** lower, odd, intervening, and upper boundaries.
- **Policy-source consistency — 15%:** engines, CI, hook, and diagnostics agree.
- **Added-file churn — 5%:** low-weight scope concern.

| Option | Enforcement | Independence | Boundaries | Consistency | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 5 | 1 | 3 | 5 | 56 |
| B | 1 | 5 | 3 | 2 | 5 | 57 |
| C | 5 | 5 | 5 | 5 | 3 | **98** |
| D | 5 | 1 | 5 | 4 | 3 | 75 |
| E | 4 | 5 | 4 | 3 | 4 | 82 |

### Selected resolution

Select **C**. Add a small dependency-free Node policy module with an exported
pure predicate and a CLI that always examines `process.versions.node`; there
is no production version-override argument. The implementation-time package
tree and Node release evidence select the exact reviewed intervals, expected
to admit majors 22 and 24 only. Stable cases cover malformed versions, one
below the minimum, minimum, latest admitted 22, odd 23, minimum 24, latest
admitted 24, odd 25, and first unreviewed even 26. The workflow-policy
validator asserts that `engines.node`, setup-node cells, hook message, and
policy-module constants encode the same set.

## T3-07 — Define pull-request, Dependabot, push, and scheduled audit gates

### Finding and outcome

T3 does not say exactly when residual-audit validation runs. Dependency changes
must fail before merge, and newly disclosed advisories must be found even when
the lockfile has not changed.

### Options

- **A — Run only on pull requests.**
- **B — Run only on a schedule.**
- **C — Use all relevant events through the T1B event owner.** The callable
  Markdown workflow runs audit on ordinary/Dependabot PRs, merge queue, and
  `main` pushes; add a read-only scheduled path in `build.yml` that calls the
  same workflow but skips candidate preparation, Windows matrix, approval, and
  writer.
- **D — Add a separate scheduled audit workflow.** Duplicate setup/install and
  validator invocation.
- **E — Give Dependabot a special audit workflow or bypass.**

C may add `workflow_dispatch` for operator evidence, with the same read-only
scheduled topology. No event changes approval semantics: only a changed
push-to-`main` can authorize the writer.

### Evaluation rubric

- **Pre-merge protection — 30%:** ordinary and Dependabot changes use the gate.
- **New-advisory detection — 25%:** unchanged lockfiles are periodically
  reassessed.
- **Single-implementation consistency — 20%:** every event invokes the same
  validator.
- **Privilege isolation — 15%:** schedules and PRs cannot reach the writer.
- **Failure visibility — 5%:** one stable job/report surface.
- **Compute cost — 5%:** lower weight than risk coverage.

| Option | Pre-merge | New advisories | Consistency | Privilege | Visibility | Cost | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 5 | 1 | 4 | 5 | 4 | 5 | 75 |
| B | 1 | 5 | 4 | 5 | 3 | 5 | 70 |
| C | 5 | 5 | 5 | 5 | 5 | 3 | **98** |
| D | 5 | 5 | 3 | 4 | 4 | 3 | 86 |
| E | 3 | 2 | 2 | 4 | 3 | 2 | 53 |

### Selected resolution

Select **C**. The called Markdown workflow performs clean install, normalized
audit capture, and validation on every PR to `main` (including Dependabot),
merge-group run, and `main` push. The event-owning build workflow adds a
read-only UTC schedule and optional manual dispatch that run only the callable
validation job plus a read-only terminal result; all candidate, matrix,
approval, artifact, and writer jobs are explicitly event-gated off. Scheduled
failure creates visible evidence and requires normal issue/PR remediation; it
does not auto-edit, auto-approve, or auto-merge.

## T4-01 — Specify a byte-preserving cross-edition PowerShell backup

### Finding and outcome

Ordinary native redirection decodes/re-encodes stdout in Windows PowerShell
5.1. T4 nevertheless promises a copyable binary-safe equivalent for both
Windows PowerShell 5.1 and PowerShell 7.

### Options

- **A — Use `terraform state pull > file` or `Out-File`.**
- **B — Branch by edition/version.** Use native redirection on PowerShell 7.4+
  and text conversion on older editions.
- **C — Use one .NET `Process`/raw-stream algorithm.** Redirect native stdout,
  copy `StandardOutput.BaseStream` to a create-new `FileStream`, drain bounded
  stderr concurrently, wait, check exit, validate, and publish no-replace.
- **D — Invoke the Bash sample from PowerShell.**
- **E — Remove the PowerShell equivalent.**

C is edition-independent and makes byte fidelity testable. B still leaves the
older path vulnerable to encoding differences. D adds a Bash-on-Windows
prerequisite and is not a native PowerShell equivalent.

### Evaluation rubric

- **Byte fidelity — 35%:** no text decoding/re-encoding of state stdout.
- **Exit/deadlock correctness — 25%:** drains streams and observes native
  completion safely.
- **No-overwrite acquisition — 20%:** temporary/final names are create-new.
- **Cross-edition usability — 15%:** one behavior on 5.1 and 7.
- **Sample complexity — 5%:** low weight given state sensitivity.

| Option | Byte fidelity | Process correctness | No overwrite | Cross-edition | Complexity | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 3 | 2 | 1 | 5 | 38 |
| B | 4 | 4 | 3 | 2 | 3 | 69 |
| C | 5 | 5 | 5 | 5 | 3 | **98** |
| D | 4 | 4 | 3 | 2 | 2 | 68 |
| E | 1 | 5 | 5 | 1 | 5 | 60 |

### Selected resolution

Select **C**. The PowerShell marker block resolves one ordinary Terraform
executable, constructs fixed `state pull` arguments, sets
`UseShellExecute=false`, redirects stdout/stderr, and opens an absent temporary
leaf with `FileMode.CreateNew`, write-only access, and no sharing. It copies
`StandardOutput.BaseStream` bytes while draining bounded stderr concurrently,
waits for both streams/process, and requires exit zero plus nonempty output.
It then checks ordinary-file identity, UTF-8/no-BOM state validity, lineage and
serial, computes SHA-256, and publishes through the selected atomic
no-replace primitive. Any start/nonzero/stream/validation failure deletes only
a still-proven owned ordinary temporary file; uncertainty is retained and
reported. It never uses `>`, `Out-File`, `Set-Content`, shell interpolation, or
user-controlled process arguments.

## T4-02 — Add Windows PowerShell 5.1 and PowerShell 7 evidence

### Finding and outcome

T4's permanent harness is Bash on Ubuntu, so it cannot prove the PowerShell
sample, Windows filesystem behavior, or the edition that motivated the raw
stream design.

### Options

- **A — Keep Ubuntu/Bash tests only.**
- **B — Add one PowerShell 7 job on Windows.**
- **C — Add a tracked PowerShell harness and run Windows PowerShell exactly
  5.1 plus PowerShell major 7 on Windows.** Use real temporary files and stub
  only Terraform/provider processes.
- **D — Simulate PowerShell behavior from Bash or Pester-free static analysis.**

C can share fixture bytes and expected records with the Bash harness, but each
language retains its own marker and stable IDs. A temporary evidence workflow
is insufficient; coverage must remain hosted after merge.

### Evaluation rubric

- **Edition proof — 30%:** executes both promised PowerShell runtimes.
- **Byte/adversarial coverage — 25%:** non-ASCII, partial, empty, and truncated
  streams.
- **Windows filesystem proof — 20%:** existing target, link, cleanup, race.
- **Durable CI ownership — 15%:** evidence remains in the same-run gate.
- **Diagnostic parity — 5%:** failures identify edition/case/phase.
- **Runner cost — 5%:** low priority for destructive-state safety.

| Option | Editions | Byte cases | Filesystem | Durability | Diagnostics | Cost | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 1 | 2 | 1 | 2 | 5 | 29 |
| B | 3 | 3 | 3 | 4 | 3 | 4 | 64 |
| C | 5 | 5 | 5 | 5 | 5 | 3 | **98** |
| D | 2 | 4 | 2 | 2 | 4 | 3 | 53 |

### Selected resolution

Select **C**. Add
`.github/workflows/Test-StateRecoveryPowerShell.ps1`, marked
`#Requires -Version 5.1`, and one stable PowerShell marker block in the guide.
The Windows matrix runs the exact harness under 5.1 and 7. Mandatory cases
cover byte-identical ASCII/non-ASCII state, native start failure, nonzero with
no/partial output, empty/truncated/invalid state, existing final path, ordinary
success, link/reparse substitution, cleanup failure, real hard-link
publication, and competing creation. The callable validation workflow reports
the exact edition, executable, OS/filesystem, case set, skips, and duration.

## T4-03 — Test the real no-replace publication primitive

### Finding and outcome

Stubbing Terraform isolates remote state safely, but stubbing the hard-link or
equivalent publication operation cannot prove the safety-critical filesystem
claim.

### Options

- **A — Stub both Terraform and publication.**
- **B — Unit-test a mocked publication wrapper.**
- **C — Stub Terraform but exercise real same-filesystem publication.** Test
  absent target success, existing target refusal without byte change, source
  identity, final bytes, link count/cleanup where available, and two competing
  creators with exactly one winner.
- **D — Run a long probabilistic race stress test only.**
- **E — Test against real remote/network filesystems.**

C may include a bounded repeated race loop as supplemental evidence. E is
backend/environment-dependent and outside the stated local-backup contract.

### Evaluation rubric

- **Atomic primitive proof — 35%:** executes the actual OS operation.
- **No-replace/race proof — 30%:** an existing or competing target is never
  overwritten.
- **Supported-OS coverage — 20%:** Linux Bash and Windows PowerShell.
- **Determinism — 10%:** produces a stable expected winner/count.
- **CI duration/flakiness — 5%:** low weight but rejects unbounded stress.

| Option | Real primitive | No replace | OS coverage | Determinism | Duration | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 1 | 1 | 5 | 5 | 32 |
| B | 2 | 2 | 2 | 4 | 4 | 46 |
| C | 5 | 5 | 5 | 5 | 4 | **99** |
| D | 5 | 5 | 4 | 2 | 2 | 87 |
| E | 4 | 4 | 3 | 1 | 1 | 67 |

### Selected resolution

Select **C**. The Bash harness calls real `ln` on one local filesystem; the
PowerShell harness calls real `New-Item -ItemType HardLink` without `-Force`.
Each proves a fresh target shares the expected bytes, a preexisting ordinary or
link/reparse target remains untouched, and two synchronized publisher
processes targeting one absent name yield exactly one success and one
already-exists failure. Cleanup removes only journaled links/files. Terraform,
remote locks, and provider calls remain stubs. An unavailable link primitive is
handled by T4-04, never reported as a pass.

## T4-04 — Define fail-closed behavior when hard links are unavailable

### Finding and outcome

The issue says “hard link or equivalent” but defines no safe equivalent.
Ordinary copy/rename fallbacks can overwrite or expose a partial final file.

### Options

- **A — Fall back to `cp`/`Copy-Item` plus `mv`/`Move-Item`.**
- **B — Fail closed.** Require temporary and final paths on one filesystem with
  hard-link support; retain the validated temporary backup and print exact
  recovery guidance when publication is unsupported.
- **C — Implement OS-specific no-replace rename APIs.** Use `renameat2` or
  platform-native equivalents and maintain separate implementations.
- **D — Reserve the final file with create-new, then copy bytes into it.**
- **E — Silently choose a new unique final filename.**

B leaves room for C as a separately specified future enhancement. A and D
weaken the semantic meaning of the final name. E breaks typed confirmation and
operator path expectations.

### Evaluation rubric

- **Overwrite prevention — 40%:** no fallback can replace existing data.
- **Atomic final-state semantics — 25%:** final is absent or complete.
- **Portability honesty — 15%:** unsupported filesystems are identified.
- **Recovery clarity — 15%:** retained sensitive state and next steps are exact.
- **Happy-path convenience — 5%:** intentionally minor.

| Option | No overwrite | Atomic state | Honesty | Recovery | Convenience | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 2 | 5 | 4 | 5 | 50 |
| B | 5 | 5 | 4 | 5 | 3 | **95** |
| C | 5 | 5 | 3 | 3 | 2 | 85 |
| D | 2 | 1 | 4 | 3 | 4 | 46 |
| E | 4 | 4 | 4 | 2 | 3 | 73 |

### Selected resolution

Select **B**. Both samples verify that the validated temporary file and
requested final parent are on the same filesystem, attempt the real no-replace
hard-link creation once, and fail if the operation is unsupported. On failure,
the final path remains absent, the proven temporary backup remains protected
and is reported explicitly as sensitive retained state, and the operator is
told to choose an access-controlled local filesystem and rerun with a new
absent final path. There is no automatic copy, move, overwrite, recursive
cleanup, or alternate final name. Unsupported cases are failures, not skips,
on the declared supported runner filesystems.

## T4-05 — Give Bash and PowerShell recovery cases stable IDs

### Finding and outcome

T4 lists behavior groups but no durable case identities. With two
implementations, evidence must distinguish shared semantics from
language/OS-specific failures.

### Options

- **A — Keep prose behavior bullets.**
- **B — Use one shared ID with a language column.**
- **C — Use semantic families with explicit language-prefixed instances.**
  Maintain parallel `SM-BASH-*` and `SM-PS-*` rows where behavior is shared and
  language-specific rows for stream/process/edition cases.
- **D — Generate IDs from test function names.**

C can share numeric suffixes for equivalent semantics without treating one
runtime as evidence for the other. IDs are append-only and never derived from
execution order.

### Evaluation rubric

- **Longitudinal traceability — 30%:** an ID retains one behavior over time.
- **Platform diagnosis — 25%:** failures identify implementation/edition.
- **Oracle detail — 25%:** setup, result, final/temporary state, and diagnostics.
- **Coverage-set assertion — 15%:** harness rejects missing/duplicate IDs.
- **Documentation volume — 5%:** low-weight readability concern.

| Option | Traceability | Platform | Oracle | Coverage set | Volume | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 2 | 2 | 3 | 5 | 46 |
| B | 4 | 3 | 4 | 4 | 4 | 75 |
| C | 5 | 5 | 5 | 5 | 3 | **98** |
| D | 4 | 4 | 4 | 3 | 2 | 75 |

### Selected resolution

Select **C**. T4 will contain a one-row-per-ID inventory. Each row states
language/edition, stub behavior, initial filesystem, command/confirmation,
expected phase/status, temporary and final state, remote-call count,
diagnostics, and sentinels. Shared families cover backup, inspection,
confirmation, mutation, recovery, lock, existing-target, unsupported-link, and
race behavior. PowerShell-only families cover raw stdout/stderr/process and
5.1/7 parity. Both harnesses assert exactly the applicable IDs and emit one
result per row.

## T4-06 — Define typed-confirmation digest-prefix strength

### Finding and outcome

T4 requires a typed digest prefix but gives no length or case grammar. An
arbitrarily short prefix does not meaningfully bind the operator to the
reviewed backup.

### Options

- **A — Accept any nonempty prefix.**
- **B — Require exactly 8 hexadecimal characters.**
- **C — Require exactly the first 16 lowercase hexadecimal characters.**
- **D — Require the full 64-character SHA-256.**
- **E — Let each operator select a length above a minimum.**

C provides a 64-bit displayed binding while remaining realistically typable.
The confirmation still includes operation, workspace/backend label, lineage or
address as applicable, and serials; the digest prefix is not the sole control.

### Evaluation rubric

- **Reviewed-object binding — 35%:** resists accidental/wrong-backup
  confirmation.
- **Human transcription usability — 30%:** can be typed accurately from a
  terminal.
- **Parser determinism — 20%:** one exact length/alphabet/case.
- **Context/replay resistance — 10%:** combines with operation-specific fields.
- **Documentation churn — 5%:** negligible priority.

| Option | Binding | Human use | Parsing | Context | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 5 | 2 | 3 | 5 | 56 |
| B | 3 | 5 | 5 | 4 | 5 | 84 |
| C | 5 | 4 | 5 | 5 | 5 | **94** |
| D | 5 | 1 | 5 | 5 | 4 | 75 |
| E | 3 | 3 | 2 | 3 | 3 | 56 |

### Selected resolution

Select **C**. Normalize SHA-256 to lowercase and require the operator to type
exactly its first 16 hexadecimal characters. The prompt prints the full digest
and a literal expected confirmation grammar; input comes from a controlling
terminal, is trimmed only as explicitly documented, and is compared ordinally.
The confirmation also binds the exact operation, workspace/backend label,
current/proposed serial, and resource address where relevant. Empty,
wrong-case, nonhex, short, long, pasted-extra-text, and digest-mismatch cases
all fail before a mutating Terraform command.

## T4-07 — Distinguish operator-attested from derived backend identity

### Finding and outcome

`EXPECTED_BACKEND_ID` is supplied by the operator. A generic sample cannot
truthfully claim that comparing a user-supplied label mechanically proves the
configured remote backend.

### Options

- **A — Call the supplied label mechanically verified.**
- **B — Treat it as explicit operator attestation.** Require the operator to
  derive/review it from backend-specific trusted evidence and bind it to logs,
  filenames, and confirmations; do not claim generic derivation.
- **C — Implement exact derivation for every supported backend.**
- **D — Parse Terraform's local `.terraform` metadata generically.**
- **E — Remove backend identity and rely only on workspace/lineage.**

B can include optional backend-specific commands as separately tested examples.
C is strongest per backend but is a different, expanding support project. D
relies on internal/local metadata and may expose backend credentials/config.

### Evaluation rubric

- **Claim truthfulness — 30%:** documentation distinguishes attestations from
  computed facts.
- **Wrong-backend prevention — 30%:** gives the operator a meaningful target
  check.
- **Credential/config safety — 20%:** avoids dumping backend metadata.
- **Backend portability — 15%:** works without pretending all APIs are alike.
- **Automation depth — 5%:** useful but subordinate to honest guarantees.

| Option | Truthfulness | Target safety | Secret safety | Portability | Automation | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 2 | 2 | 5 | 5 | 52 |
| B | 5 | 4 | 5 | 5 | 3 | **92** |
| C | 5 | 5 | 4 | 2 | 1 | 83 |
| D | 3 | 4 | 2 | 3 | 3 | 62 |
| E | 3 | 1 | 5 | 5 | 5 | 64 |

### Selected resolution

Select **B**. Rename the concept in prose to an
**operator-attested backend identity**. Before running, the operator records a
nonsecret canonical label derived from separately reviewed backend
configuration/account/workspace evidence; the sample checks exact grammar and
uses it consistently but explicitly does not prove the remote endpoint.
Lineage, serial, workspace, lock/exclusion, and post-operation state remain
mechanical controls. Any backend-specific derivation added later must have its
own marker, secret-redaction rules, and harness; it cannot silently strengthen
the generic claim.

## T4-08 — Define positive lock waiting for manual state push

### Finding and outcome

T4 prohibits disabled locking but does not state how long recovery waits for a
supported backend lock. Terraform's default zero timeout can fail immediately
under ordinary contention.

### Options

- **A — Rely on Terraform's default timeout.**
- **B — Use a fixed positive `-lock-timeout=5m`.**
- **C — Accept a configurable timeout with validated minimum/maximum.**
- **D — Implement a shell retry loop around immediate failures.**
- **E — Omit Terraform locking and require external exclusion for every
  backend.**

B provides one copy-safe command. C is flexible but creates grammar and
operator-choice cases. D may retry non-lock failures and loses Terraform's
native lock semantics. Backends without locking still need explicit external
exclusion under B/C.

### Evaluation rubric

- **Concurrent-writer safety — 35%:** locking stays enabled and contention is
  handled by Terraform.
- **Command determinism — 20%:** one reviewed timeout and no ad hoc loop.
- **Operational patience — 15%:** allows a legitimate holder to finish.
- **No-lock-backend handling — 20%:** requires external exclusion when needed.
- **Copy/paste simplicity — 10%:** meaningful for emergency recovery.

| Option | Concurrency | Determinism | Patience | No-lock backend | Simplicity | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 3 | 5 | 1 | 3 | 5 | 66 |
| B | 5 | 5 | 4 | 5 | 5 | **97** |
| C | 5 | 3 | 5 | 5 | 3 | 88 |
| D | 4 | 2 | 2 | 3 | 2 | 58 |
| E | 2 | 4 | 3 | 5 | 3 | 65 |

### Selected resolution

Select **B**. Every manual recovery `terraform state push` includes exactly
`-lock-timeout=5m`, never `-lock=false`, and never `-force`. The sample
distinguishes lock acquisition failure from lineage/serial/input failure and
does not retry automatically. Before use, the operator verifies whether the
configured backend supports locking. If it does not, a documented
backend-appropriate maintenance window/external exclusion with accountable
owner is mandatory before confirmation; the flag is retained but is not
misrepresented as effective.

## T4-09 — Recompute the exact affected-file set for the selected design

### Finding and outcome

T4 says exactly eight files may change, but the selected PowerShell harness,
Windows called-workflow jobs, and structural policy allowlist require
additional tracked files.

### Options

- **A — Retain the eight-file gate and use temporary/untracked PowerShell
  evidence.**
- **B — Declare the exact ten-file final set.** Add the PowerShell harness and
  workflow-policy validator to the existing two sources, four generated files,
  Bash harness, and callable Markdown workflow.
- **C — Remove the exact list and discover changed files at implementation
  end.**
- **D — Add a temporary workflow and delete it before merge.**

B assumes T1B's selected callable workflow can contain its own Windows jobs, so
`build.yml` needs no T4 change. If implementation evidence disproves that
topology, the issue must be amended before editing rather than silently exceed
the gate.

### Evaluation rubric

- **Implementation completeness — 35%:** every selected production/test change
  is permitted.
- **Permanent gate correctness — 25%:** Windows evidence and policy validation
  survive merge.
- **Generated-source consistency — 20%:** sources regenerate exactly four
  outputs.
- **Review auditability — 15%:** staged paths equal one predeclared set.
- **Scope churn — 5%:** extra files are low-weight when required.

| Option | Completeness | Permanent gate | Generated consistency | Auditability | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 2 | 5 | 3 | 5 | 58 |
| B | 5 | 5 | 5 | 5 | 3 | **98** |
| C | 4 | 4 | 4 | 3 | 2 | 75 |
| D | 3 | 3 | 4 | 2 | 3 | 61 |

### Selected resolution

Select **B**. T4's exact paths become:

1. `STYLE_GUIDE.md`;
2. `STYLE_GUIDE_RATIONALE.md`;
3. `copilot-instructions.md`;
4. `terraform.instructions.md`;
5. `STYLE_GUIDE_CHAT.md`;
6. `STYLE_GUIDE_FULL.md`;
7. `.github/workflows/Test-StateRecoveryExamples.sh`;
8. `.github/workflows/Test-StateRecoveryPowerShell.ps1`;
9. `.github/workflows/markdownlint.yml`; and
10. `.github/workflows/Validate-WorkflowPolicy.mjs`.

Generated files are changed only by the tracked generator. The callable
workflow adds permanent Windows 5.1/7 jobs; the policy validator updates exact
job/action/role/count fixtures. Validation requires working and staged path
equality to these ten paths and no temporary workflow residue.

## Evaluation and incorporation result

All 36 normalized open TerraformStyleGuide findings were evaluated in sequence
with finding-specific options, rubrics, scored tables, and selected
resolutions. Those selections were then applied to T1, T1A, T1B, T2, T3, and
T4 without changing their embedded H1 titles or execution order.

Primary-source research used for the decisions is preserved in
`current-findings-research.md`. Completion validation proved:

- 36 finding sections, option sets, unique rubrics, scoring tables, and
  detailed selections;
- exact H1 equality for all six issues;
- selected-resolution evidence in every applicable issue;
- zero Markdown lint errors across all 46 discovered Markdown files and zero
  nested-Markdown errors across 25 discovered fenced blocks;
- clean `git diff --check`;
- Bash syntax success for every fenced Bash block in T2; and
- executed non-network success and partial-failure lifecycle checks for the
  AWS, Azure, and GCS recovery bodies.
