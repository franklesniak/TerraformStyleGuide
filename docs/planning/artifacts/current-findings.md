# Current TerraformStyleGuide issue-slate findings

## Review status

This review covers the sequential T slate:

1. `03TerraformStyleGuideT1.md`;
2. `03aTerraformStyleGuideT1A.md`;
3. `03bTerraformStyleGuideT1B.md`;
4. `04TerraformStyleGuideT2.md`;
5. `05TerraformStyleGuideT3.md`; and
6. `06TerraformStyleGuideT4.md`.

It uses the corrected criticism at
`docs/planning/TerraformStyleGuide/slate-criticism.md`, the six T drafts at
TerraformStyleGuide planning commit
`d6042f0`, the revised P drafts copied at `45df8ee`, and default `main` at
`6ee3f57b2b71b885a5927b770dde47532944de62`.

Keep all six issue filenames, H1 titles, T identifiers, and their listed order.
Do not take the optional T4/T4A split in this pass; close T4 with explicit
nonmutating/mutating review checkpoints to avoid a filename/prompt migration
that does not itself resolve a technical defect.

## Corrected criticism input

The original Terraform prompt incorrectly referred to
`docs/planning/PSStyleGuide/slate-criticism.md`, even though the cross-repository
loop copies T-slate criticism to
`docs/planning/TerraformStyleGuide/slate-criticism.md`. That prompt reference
has been corrected in both local repositories. This review uses the T-slate
criticism intended by the loop.

## Primary-source validation

Current official sources confirm:

- GitHub workflow push branch filters use short branch names while
  `github.ref` uses full refs;
- active/effective rulesets and Integration bypass modes are queryable;
- S3 general-purpose bucket names reserve the exact official prefixes/suffixes
  identified below and give `-an` an account-regional namespace meaning;
- the command-specific `terraform state rm` reference limits legacy
  `-state`, `-state-out`, and `-backup` flags to local state;
- GitHub primary/secondary rate limits use `403` or `429` plus
  `Retry-After`/`x-ratelimit-*` guidance; and
- the T/P SHA-512 npm descriptor is the hex representation of the stored
  registry SRI.

Detailed URLs, relevant excerpts, live baselines, and the general-state versus
command-specific `state rm` documentation distinction are retained in
`docs/planning/artifacts/prompt-loop-primary-source-research-2026-07-30.md`.

## Recommendation audit

### Generator/writer convergence — prior blocker denied as outdated

The prior criticism that P1 and T1 use incompatible write transactions is no
longer valid. P1 now adopts T1's private per-artifact replacement boundary,
truthful partial completion, and stable 16-row `GF-*` matrix. Keep T1's design.
Do not add a backup/rollback coordinator.

### Versions, lock production, reciprocal rows — confirmed strong

T1 already defines the timeless marker, separately trusted expected version,
authoring progression, exact script-disabled lock producer, frozen consumers,
and 16 stable reciprocal rows. P1 now aligns. No correction is open here.

### Writer evidence and `main` ruleset — confirmed strong

T1/T1B already enumerate the evidence push filter and full-ref predicates,
use an allowed-delta manifest, test the real writer under a temporary
equivalent rule, and gate merge on active/effective persistent governance with
one official-Actions bypass. Preserve these contracts.

### S-01 — second execution graph

**Confirmed high priority.** T1 and T3 support T3-first as an alternate graph,
contrary to the stipulated one sequential order. Convert the advisory decision
to a go/no-go gate: accepted temporary exposure permits the listed order;
refused/expired/materially worsened exposure stops and reissues the slate.

### C-01 — unfinished T1A physical catalog

**Confirmed blocker.** T1A contains correct oracle-profile/result concepts but
still instructs the future author to transcribe rows, split disjunctions,
replace ordinal keys, and add Git/catalog cases “before filing.” Complete that
work in the issue. Each physical row must have one ID, semantic key, profile,
applicability, fixture, expected production outcome, states, cleanup,
diagnostic, sentinels, calls, and source-tree result.

### C-02 — terminal candidate cleanup

**Confirmed reciprocal mismatch.** T1A re-inspects an already disposed
candidate leaf; P1A treats disposed/failed capability states as externally
zero-call. Choose one. The selected correction should adopt P1A's zero-call
terminal behavior because ownership has been released and a reoccupied name is
outside the old capability.

### W-01 — T1B diagnostic producer/consumer

**Confirmed required correction.** T1B describes security properties but does
not publish the exact producer step/output/path and every literal upload value.
Add the exact producer schema, output, action name/path/condition and authored
inputs, with offline positive/negative policy cases.

### P-01 — pre-merge provenance

**Confirmed required correction.** T1/T1B re-resolve supply at implementation
start but not the full tuple immediately before merge. Add a second complete
freeze for action releases/manifests/defaults/runtime, Node/checksums, bundled
manager, package tarballs/integrity/config, and dated security state.

### T2-01 — missing native Git interface

**Confirmed blocker.** T2 consumes a named reusable reader/classifier that no
T1/T1B affected path creates. Put a complete reusable helper in T2's scope
rather than reopen landed predecessors. Define raw NUL semantics, fixed root,
closed modes, object IDs, native outcomes, result schema, and hostile cases.

### T2-02 — HCP page-number grammar

**Confirmed.** Choose the bounded canonical decimal grammar
`^[1-9][0-9]{0,19}$` everywhere, treat it as a string, and add 19/20/21-digit
and overflow-forbidden cases. This matches the existing public map and closes
resource use.

### T2-03 — AWS reserved forms

**Confirmed high priority.** Freeze the official general-purpose prefix set
`xn--|sthree-|amzn-s3-demo-` and suffix set
`-s3alias|--ol-s3|.mrap|--x-s3|--table-s3`. T2 is not teaching the new
account-regional namespace, so reject names ending `-an` in this copyable
global-namespace policy and say why. Add literal boundary cases.

### T2-04 — Bash minimum

**Confirmed.** Select Bash `4.4.0` as the minimum for the copyable helpers,
guard it exactly, and test unavailable/malformed/below/at/above. The hosted
runner image is evidence, not authority.

### T3-01 — observed facts versus approvals

**Confirmed blocker.** Split report-derived `ObservedFindings` from
governance-only `Approvals`, require exact `(Package,AdvisoryUrl)` key equality,
compare copied observed security/topology fields, and validate approval
metadata separately.

### T3-02 — remaining case families

**Confirmed blocker.** T3's 184 audit meanings are physical, but Node/npm/hook
and capture cases still use family/range language incompatible with
one-result-per-ID. Allocate one physical ID per applicable platform/runtime
case, or make the declared tuple the primary key. Select physical IDs to match
the existing acceptance model.

### T3-03 — literal schedule

**Confirmed.** Use P3's exact Wednesday schedule
`'23 17 * * 3'` and add mutated/extra/missing/event-topology fixtures.

### T3-04 — package-operation authority

**Confirmed required correction.** Add `T3-NPM-OPERATIONS-v1` with complete
ordered argv, Node/Corepack identity, cwd, environment/config/network/cache,
streams/timeout/termination, exits, and filesystem side effects. Existing
workflows/hooks/audit consume its rows/digest rather than constructing commands
independently.

### T3-05 — capture/live retry behavior

**Confirmed required correction.** Add exact API version/headers, response
caps, redirect policy, total attempts, retryable statuses, bounded
`Retry-After`/`x-ratelimit-reset` handling, fallback/fail behavior, and physical
cases. Prefer bounded fail-closed behavior over long sleeps.

### T4-01 — backend-invalid universal `state rm -backup`

**Confirmed blocker.** The specific `state rm` reference limits legacy
`-backup` to local state. Use protected pre-mutation `state pull` as universal
recovery evidence and publish separate exact local versus HCP/remote argv. Do
not discover unsupported flags by retrying a destructive command.

### T4-02 — incomplete state-bearing role table

**Confirmed blocker.** One canonical table must cover every public or
helper-private state-derived role, with creator, consumer, parent/path/
attestation, identity/size/content, lifetime, cleanup, failure postconditions,
and retained uncertainty.

### Optional T4/T4A split

**Valid reviewability concern, not selected.** Keep one T4 file but add two
mandatory review/evidence gates: nonmutating inspection foundation first;
destructive mutation/recovery layer second. The second cannot begin until the
first is independently approved and frozen.

## Independent findings

### T2 should own its missing Git helper

Changing a completed predecessor solely to create T2's missing interface would
force predecessor revalidation and complicate the existing handoff. T2 already
needs native Git behavior, so add the helper, tests, and handoff there with an
explicit scope expansion.

### T3's operation table need not force P3's wrapper architecture

Converge on literal operation semantics and evidence, not runtime packaging.
T3 may keep Corepack execution in its existing driver/hook surfaces if one
T-local frozen table is the authority and all consumers prove the same digest.

### T4 needs backend mode selection before any state mutation

Backend classification is security authority. Select and attest exactly one
`local|hcp-cloud|remote-backend` mode before generating mutation argv. Unknown,
ambiguous, drifted, or differently reinitialized backend state stops before a
lock or mutation command.

## Filing assessment

Do not file unchanged. Preserve the six issue names/order and close the
sixteen findings above. The next reciprocal review should expect:

- T1/P1 generator and governance rows to remain converged;
- T1A to have a fully physical catalog and an explicit terminal-lifecycle row;
- T2 to own an executable Git interface and closed input policies;
- T3 to have physical non-audit rows plus schedule/operation/retry authority;
  and
- T4 to have backend-valid mutation modes and complete path ownership.
