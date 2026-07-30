# Feedback on the proposed PSStyleGuide issue slate

## Overall assessment

Keep the P1/P1A/P1B/P2/P3 split and the proposed sequential order, subject to
one explicit npm-risk decision described below. The split creates useful review
boundaries:

- P1 establishes deterministic generation and temporary publication controls.
- P1A adds security-sensitive candidate validation without activating it.
- P1B activates immutable transport and the final writer.
- P2 makes the source and generated content change through that completed
  pipeline.
- P3 owns the final Node, npm, package, hook, audit, and dependency-update
  policy.

This is a sounder plan than combining generator, archive, workflow-permission,
content, and package changes in one pull request. P2 is close to filing-ready,
and the security model intended by P1A and P1B is strong.

The slate should not be filed unchanged. Several requirements still cannot be
implemented or proved from the current issue text:

| Priority | Issue | Required correction |
| --- | --- | --- |
| Blocker | P1 | Replace direct `File.WriteAllText` publication with a closed artifact-ID/destination map and an old-or-complete-new sibling-file transaction. |
| Blocker | P1 | Add the permanent locked structural workflow-policy validator in P1; the draft currently demands structural enforcement while forbidding the files needed to implement it. |
| Blocker | P1B | Put Markdown validation in P1B's actual job graph by making `build.yml` the event owner and `markdownlint.yml` a local callable workflow. |
| Blocker | P1B | Export, attest, approve, and consume four path-bound preparation hashes; the writer currently requires values that preparation does not export. |
| Blocker | P1/P1B | Correct the token boundary. `persist-credentials: false` prevents post-checkout persistence; it does not make authenticated checkout token-free. |
| Blocker | P1B | Define the exact isolated-ref writer proof and the reviewed-head-to-landed-commit handoff. “Controlled temporary branch” is not yet an executable evidence protocol. |
| Blocker | P3 | Add `build.yml`, the existing Husky installer, and P1's workflow-policy validator to scope; add scheduled read-only audit execution and a closed exception lifetime. |
| Blocker | P3 | Select the exact npm/Corepack identity and Node patch floors already resolved by T3, or record evidence for an intentional difference. |
| Required | P1A | Define raw public parameter grammar, the exact invocation-context schema/lifecycle, and one atomic oracle per repository-local case ID. |
| Required | P2 | Reconcile its pull-request evidence with P1B, make every Git path gate NUL-safe, classify native difference statuses, and machine-check the unchanged Compliant example. |
| Required | Slate | Record whether repository policy permits the currently observed high-severity npm findings to remain until P3. If not, move P3 first and rebaseline every later issue. |

After these corrections, the slate will be suitable for sequential filing and
implementation.

## Review baseline

This review uses PSStyleGuide `main` commit
[`4346310e7deebffb4159c75e30d9546263dfd649`](https://github.com/franklesniak/PSStyleGuide/commit/4346310e7deebffb4159c75e30d9546263dfd649),
dated 2026-07-26.

The baseline supports the proposed work:

- [`Generate-StyleGuideArtifacts.ps1`](https://github.com/franklesniak/PSStyleGuide/blob/4346310e7deebffb4159c75e30d9546263dfd649/.github/workflows/Generate-StyleGuideArtifacts.ps1)
  has no parseable script version, uses four host-sensitive `Set-Content`
  writes, and constructs frontmatter with a source-newline-sensitive
  here-string.
- [`build.yml`](https://github.com/franklesniak/PSStyleGuide/blob/4346310e7deebffb4159c75e30d9546263dfd649/.github/workflows/build.yml)
  is path-filtered, grants workflow-wide `contents: write`, uses mutable action
  tags, configures checkout with the job token, and directly commits and pushes.
- [`markdownlint.yml`](https://github.com/franklesniak/PSStyleGuide/blob/4346310e7deebffb4159c75e30d9546263dfd649/.github/workflows/markdownlint.yml)
  is a separate event-triggered Node 20 workflow. It is not a job that a
  `build.yml` approval job can name in `needs`.
- [`package.json`](https://github.com/franklesniak/PSStyleGuide/blob/4346310e7deebffb4159c75e30d9546263dfd649/.github/workflows/package.json)
  has no finite Node policy or pinned package-manager identity.
- [`.husky/pre-commit`](https://github.com/franklesniak/PSStyleGuide/blob/4346310e7deebffb4159c75e30d9546263dfd649/.husky/pre-commit)
  and
  [`lint-staged-markdown.mjs`](https://github.com/franklesniak/PSStyleGuide/blob/4346310e7deebffb4159c75e30d9546263dfd649/.github/workflows/lint-staged-markdown.mjs)
  independently accept every Node major at or above 20.
- [`install-husky.mjs`](https://github.com/franklesniak/PSStyleGuide/blob/4346310e7deebffb4159c75e30d9546263dfd649/.github/workflows/install-husky.mjs)
  is the real `prepare` installer, but P3 currently omits it from scope.
- `.gitattributes` is already exactly `* text=auto eol=lf`, and
  `.github/dependabot.yml` is absent.

A read-only audit rerun on this exact commit under Node 26.5.1/npm 11.7.0
reproduced the material P3 baseline: exit 1, report version 2, seven
vulnerability properties, fourteen advisory objects, two package-string graph
edges, and seven installed node paths. The seven keys were `brace-expansion`,
`js-yaml`, `linkify-it`, `markdown-it`, `markdownlint-cli2`, `minimatch`, and
`picomatch`; metadata reported five high and two moderate properties. P3 is
right to call these dated observations rather than acceptance constants.

The pinned action metadata also matters to the criticism:

- [`actions/checkout` at the proposed SHA](https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/action.yml)
  defaults `token` to `github.token`; `persist-credentials: false` changes what
  remains after checkout, not whether checkout performs authenticated fetch.
- [`actions/upload-artifact` at the proposed SHA](https://raw.githubusercontent.com/actions/upload-artifact/043fb46d1a93c77aae656e7c1c64a875d1fc6a0a/action.yml)
  does have the proposed `archive` input. Retain it if wanted; the problem is
  the absence of a complete explicit-input and reviewed-omission policy, not
  that this input is invalid.
- [`actions/setup-node` at the proposed SHA](https://raw.githubusercontent.com/actions/setup-node/820762786026740c76f36085b0efc47a31fe5020/action.yml)
  has token, `check-latest`, and automatic package-manager cache behavior that
  should be part of that same policy.

## Slate architecture and sequencing

### Keep the issue boundaries

P1/P1A/P1B is the right decomposition of the generator/publication work.
Deterministic serialization, an adversarial archive helper, and a write-enabled
workflow are different risk surfaces. P1A's workflow-inert boundary is
particularly valuable because it allows the helper, context lifecycle, and
failure cleanup to be reviewed before permissions or workflow topology change.

P2 should remain after P1B. It then becomes the first normal source/generated
content change that demonstrates the completed no-drift path. P3 should remain
last if and only if an accountable repository decision permits the dated high
findings to wait.

### Make the npm-risk gate explicit

Before P1 implementation, record:

- the exact audit command, Node/npm versions, date, raw-report digest, and
  normalized findings;
- the repository policy that applies to current high-severity findings;
- the accountable decision owner;
- the accepted waiting period and compensating controls; and
- the selected issue order.

If policy permits the wait, use P1→P1A→P1B→P2→P3. If policy requires immediate
remediation, implement P3 first, then rebaseline P1/P1A/P1B/P2 against P3's
landed commit. Do not leave this as an unstated assumption.

### Separate reviewed heads from landed commits

An issue cannot prove its own merge commit before it merges. Each predecessor
should close with:

- the exact reviewed head;
- parsed script versions;
- final run IDs/URLs;
- the successor's real blocked-by link;
- a handoff location and owner; and
- the evidence expected after landing.

The successor should then record the actual protected-branch landed commit,
which may differ after merge, squash, or rebase, and rerun the required
identity/behavior checks. Move “P1A/P1B/P2 records this issue's merge commit”
out of predecessor acceptance lists and into successor entry criteria.

## P1 — Make artifact generation byte-deterministic across PowerShell editions and hosts

### What is strong

P1 identifies the correct content boundary: normalize the complete final
payload after all transformations, encode explicitly as BOM-less UTF-8, add no
implicit newline, and apply the same boundary to all four outputs. The explicit
frontmatter line array removes a real host/source-EOL dependency. The three-cell
Windows PowerShell 5.1/PowerShell 7 matrix, cross-cell hashes, second-run fixed
point, and unchanged committed artifacts are strong acceptance evidence.

The temporary/final publication split is also clear. P1 correctly excludes ZIP
validation, the caller context, permanent helper harness, immutable download,
matrix approval, and the final P1B writer.

### Required revisions

1. **Use a closed artifact writer, not a generic destination writer.**

   A helper that accepts an arbitrary destination string centralizes encoding
   but does not constrain what the generator may overwrite. Give the helper a
   closed artifact ID and exact leaf map:

   | Artifact ID | Exact destination |
   | --- | --- |
   | `copilot` | `copilot-instructions.md` |
   | `powershell-instructions` | `powershell.instructions.md` |
   | `chat` | `STYLE_GUIDE_CHAT.md` |
   | `full` | `STYLE_GUIDE_FULL.md` |

   Derive the repository root from the fixed `$PSScriptRoot` location, never
   from the current working directory. Require the mapped destinations to
   already exist as tracked ordinary non-reparse files. Validate every existing
   component and reject an artifact-ID/path mismatch.

2. **Replace `File.WriteAllText` with an exact failure transaction.**

   `File.WriteAllText` can truncate the destination before a later write failure.
   Determinism is incomplete if failure can leave a partial artifact. Encode the
   complete normalized payload once, create an unpredictable same-directory
   sibling with bounded collision-only retry and `FileMode.CreateNew`, write all
   bytes, `Flush(true)`, dispose, and verify exact length and SHA-256. Recheck
   parent and destination, then call `File.Replace` exactly once.

   The contract should be:

   - before `File.Replace` returns, every failure leaves the old destination
     byte-identical and removes only a proven owned temporary sibling;
   - after it returns, the complete new file and absent temporary sibling are
     committed success, with no fallible semantic check afterward; and
   - unsupported replacement, cleanup uncertainty, or a substituted path fails
     closed with no copy/move/direct-write fallback.

   Add fault-injection cases for every phase in all three generator cells. This
   is the most important generator-layer refinement from T1 and should converge
   in P1.

3. **Make script version metadata literal and testable.**

   The baseline script has no version field, so “use the existing parseable
   `.NOTES` location” is misleading. Require exactly one script-level line
   before the first function:

   ```text
   Version: 1.0.<actual-UTC-implementation-YYYYMMDD>.0
   ```

   Define the four-component parser, real-date check, first-publication rule,
   Major/Minor/Build/Revision bump behavior, and rejection of duplicate,
   malformed, stale, impossible-date, whitespace/sign/extra-component, or
   function-level decoy versions. P1A and P1B should consume this exact contract.

4. **Add the permanent structural workflow-policy validator in P1.**

   P1 currently requires structural YAML parsing, exact roles/inputs, and
   negative fixtures while its four-file scope forbids a parser dependency or
   tracked validator. That requirement is not implementable as written.

   Follow T1's resolved boundary. Add:

   - `.github/workflows/Validate-WorkflowPolicy.mjs`;
   - exact direct `"yaml": "2.9.0"` in
     `.github/workflows/package.json`; and
   - the corresponding reviewed lockfile update.

   Re-resolve the version/tarball/integrity and audit immediately before
   implementation. The validator should use strict YAML 1.2 core semantics,
   unique string keys, warnings as errors, and reject directives, anchors,
   aliases, merge keys, tags, multiple documents, complex keys, and non-JSON-like
   values. It should have one pure offline parser/policy core, a thin CLI, and
   atomic positive/negative fixture IDs.

   This changes P1's exact implementation scope from four to seven files:
   generator, two workflows, Dependabot, validator, package manifest, and
   lockfile. P1B then extends the same validator; P3 upgrades and revalidates it.
   Do not create a second parser in P1B or P3.

5. **Define one complete authored action policy and one reviewed-default policy.**

   “Complete inputs” currently means only a small subset of authored `with:`
   keys, while “no unrecorded default may become policy” is stronger. Record
   both:

   - the exact authored role/job/step/action/SHA/condition/input map; and
   - a separate table of deliberately omitted inputs, upstream defaults,
     rationale, and security consequence for each pinned action commit.

   At minimum, checkout should explicitly state repository, ref, token,
   persistence, fetch depth/tags, progress, LFS, submodules, clean,
   safe-directory, and unsafe-PR behavior. Setup Node should explicitly state
   Node version, `check-latest`, token, and automatic-cache behavior. Upload
   should explicitly state name, literal paths, missing-file behavior,
   retention, compression, overwrite, hidden files, and `archive`.

   Preserve `archive: true` if that is the reviewed design; it is valid at the
   pinned upload SHA. Reject unknown/missing/extra keys and undocumented
   omissions structurally.

6. **State the checkout credential boundary truthfully.**

   GitHub creates a job token before the job, and the pinned checkout action
   uses its explicit/default token for fetch. `persist-credentials: false`
   requires the action to remove configured authentication afterward; it does
   not mean no token was materialized.

   Say that checkout may use the job token transiently, then perform a
   presence-only check for credential-bearing remotes, credential helpers, and
   local/global HTTP authorization configuration before running repository
   scripts. Other generator/diagnostic processes receive no explicit
   token/header/helper/config environment. The guarded writer push may later
   create its own process-scoped authorization header.

7. **Make every Git path/status gate byte-safe.**

   Every affected-file, worktree, index, untracked, staged, and generated-path
   gate should invoke Git with an argument array, read raw stdout, and parse
   NUL-delimited modes. Reject a missing terminal NUL, malformed/duplicate
   record, ambiguous decoding, or unexpected raw path bytes. Include names with
   spaces, tabs, newlines, leading dashes, quotes, escapes, and non-ASCII bytes
   in disposable-repository fixtures.

   Classify every `git diff --exit-code` as 0 equal, 1 ordinary difference, and
   every other status/start failure as native-tool failure. Capture status
   immediately and disable external diff/text-conversion behavior.

8. **Correct the failure-upload path reference.**

   P1 says the upload path is “the four-file list in Affected files,” but its
   implementation Affected files are the generator, workflows, and Dependabot.
   Name the generated evidence paths literally and in order:

   - `copilot-instructions.md`;
   - `powershell.instructions.md`;
   - `STYLE_GUIDE_CHAT.md`; and
   - `STYLE_GUIDE_FULL.md`.

   If the intent is a separate bounded diagnostic bundle, name its producer and
   exact paths instead. Do not use “Affected files” for two meanings.

### P1↔T1 convergence

Use the same semantic generator skeleton in P1 and T1:

- closed artifact-ID/destination mapping;
- trusted root derived from script location;
- final complete-payload CR/LF normalization;
- BOM-less UTF-8 and exact final-newline behavior;
- same-directory verified replacement transaction;
- exact script version grammar;
- permanent strict workflow-policy parser;
- complete action-role/default review;
- honest checkout/push credential terminology;
- raw Git path/status handling; and
- cross-edition hashes, idempotence, and fault injection.

Source composition, exact artifact names, and frontmatter are intentional
repository differences. A generic shared runtime package is neither necessary
nor desirable: each repository should retain a self-contained reviewed copy
whose semantic matrix proves convergence.

## P1A — Add a fail-closed cross-platform style-guide candidate validator

### What is strong

P1A's workflow-inert boundary is excellent. Its intended implementation treats
paths, labels, archive entries, resource declarations, and cleanup claims as
untrusted. It holds one archive stream through hashing and parsing, validates
the manifest and ceilings before candidate creation, writes only fresh ordinary
files, and retains uncertain state instead of recursively deleting it.

Explicit `HelperPath` and `ContextManagerPath` harness inputs, separate caller
and candidate cleanup owners, actual-byte ceilings, and required real
link/reparse rejection on both OS families should all be retained.

### Required revisions

1. **Apply one raw public parameter grammar before PowerShell coercion.**

   Inventory every public path boundary: helper paths, checkout/trusted roots,
   download/candidate paths, context parent, and every cleanup journal path.
   Receive each raw value as `[object]` and prevent collection enumeration or
   string joining before validation. A `[string]` binder can erase the
   distinction between a real scalar and an array or non-string object.

   Reject in a fixed order: null, non-string scalar/collection, empty,
   Unicode-whitespace-only, NUL/control/malformed provider syntax, wildcard,
   relative/drive-relative/root-relative/tilde, and unsupported/nonfilesystem
   provider. Accept only a platform-native fully qualified filesystem path or
   exactly one `FileSystem::`-qualified fully qualified path. Every grammar
   failure occurs before filesystem creation/enumeration and leaves sentinels
   unchanged.

   Apply the same raw scalar rule to optional labels so explicit null, empty,
   collection, and omission remain distinguishable.

2. **Publish the exact invocation-context schema and lifecycle.**

   “Structured context containing” is not enough for P1B to consume safely.
   Define a closed first `PSTypeName`, schema version, context ID, lifecycle
   state, normalized parent/root/download/candidate paths, diagnostic label,
   exact ordered ownership journal, and cleanup summary. Define the journal
   entry `PSTypeName`, property set/types, contiguous sequence, kind, acquisition
   phase, normalized path, and ownership flag.

   Define transitions such as:

   - `Active` → `CleanupInProgress` → `Disposed` only after complete safe
     removal;
   - uncertainty → `RetainedUncertain`;
   - a valid `Disposed` context → successful no-op with zero filesystem calls;
   - `CleanupInProgress`/`RetainedUncertain` re-entry → stable retained-state
     rejection with zero deletion; and
   - unknown/forged schema or state → invalid-context rejection with zero
     deletion.

   Cleanup must treat the context object itself as untrusted, revalidate every
   property and filesystem claim, and preserve the primary failure.

3. **Give the three new scripts exact first-publication versions.**

   Each should contain exactly one script-level
   `Version: 1.0.<actual-UTC-date>.0` under P1's parser/bump contract. Reject
   duplicate, malformed, stale, impossible-date, and function-level decoy
   versions. Commit and file hashes remain immutable evidence; version metadata
   is not authorization.

4. **Replace every grouped ID range with one atomic row.**

   `M-01..14`, `E-01..10`, `R-01..08`, and similar grouped rows do not tell an
   implementer which ID owns which fixture, phase, terminal state, or diagnostic.
   That contradicts the requirement for exactly one result per mandatory ID.

   Every catalog row and emitted result should have fixed fields for local ID,
   semantic case, applicability, fixture, initial state, pass/fail/skip, exact
   process status, phase, subreason, candidate state, context state, cleanup
   sequence, diagnostics, and sentinel state. A slash-combined fixture, “or”
   oracle, “continues,” or “proceeds” is not a final result.

   Expand the catalog to cover the categories already explicit in T1A but
   missing or collapsed in P1A, including:

   - invalid digest grammar;
   - wildcard/missing/wrong-type/non-scalar paths;
   - exact download cardinality and unreadable/wrong-type entries;
   - helper/context/harness identity substitution;
   - normal, repeated, uncertain, partial, and combined caller cleanup;
   - below/exact/above archive and copied-byte boundaries;
   - valid, omitted, empty, null, collection, and non-string labels; and
   - missing/duplicate/unexpected/multiply emitted catalog results.

   A skip must still emit exactly one record and never receive pass credit.

5. **Namespace local IDs and share semantic identities.**

   P1A and T1A already give some short IDs different meanings. Prefix P IDs
   with `P1A-` and T IDs with `T1A-`. Give every row a stable semantic key, such
   as `archive.manifest.case-collision`, and compare counterparts by semantic
   key rather than assuming equal short numbers.

   The reciprocal matrix should record semantic key, immutable P/T commits,
   local IDs, evidence, exact expected fields, classification
   (`same|intentional difference|blocker`), and rationale. Add fixtures for
   duplicate/missing IDs or keys, changed mappings, equal keys with divergent
   expectations, and an intentional difference without rationale.

### P1A↔T1A convergence

This layer should be almost identical semantically. Exact manifest filenames
are the main intentional difference. Public input grammar, same-stream archive
identity, component security, ceilings, extraction, context schema, cleanup
states, diagnostics, semantic cases, and platform behavior should converge.

Keep both implementations repository-local. The matrix should unify the
security and failure contract without creating a cross-repository runtime,
download, or availability dependency.

## P1B — Promote generated style-guide artifacts through a least-privileged verified writer

### What is strong

The intended topology is strong: one immutable candidate, Ubuntu validation,
four Windows edition/EOL cells, unique cell attestations, a fail-closed terminal
approval, and one write-enabled job that revalidates and regenerates at use.
Exact remote preflight, one expected parent, an explicit refspec, and a
full expected-SHA lease are the right stale-writer controls.

The draft also correctly rejects automatic extraction, artifact-name trust,
matrix filesystem trust, no-op commits, credential persistence, retry/rebase,
and concurrency as a correctness mechanism.

### Blocking revisions

1. **Create one executable job graph.**

   An approval job cannot use `needs` to depend on a job in an independently
   triggered `markdownlint.yml` run. Make `build.yml` the only owner of
   `pull_request`, `push`, and any enabled `merge_group`. Give
   `markdownlint.yml` `on: workflow_call`, remove its independent PR/push
   triggers, and call it locally with:

   ```yaml
   uses: ./.github/workflows/markdownlint.yml
   ```

   Then define a closed graph such as:

   | Job | Direct needs | Permission | Role |
   | --- | --- | --- | --- |
   | `markdown` | none | `contents: read` | local callable Markdown/Ubuntu validation |
   | `prepare_candidate` | none | `contents: read` | generate, hash, upload, emit outputs |
   | `verify_candidate_windows` | `prepare_candidate` | `contents: read` | static four-cell validation |
   | `approve_promotion` | all three producers | `{}` | `always()` terminal decision |
   | `synchronize_generated_artifacts` | every result/output producer it reads | `contents: write` | changed push-to-`main` only |

   Use workflow-level `permissions: {}` and exact per-job permissions. The
   workflow-policy validator must reject a missing direct `needs`; do not assume
   transitive output/result availability.

2. **Propagate the four file hashes end to end.**

   Preparation records four SHA-256 values but its output list omits them. The
   writer later compares against “preparation hashes” that cannot cross the job
   boundary. Add four statically named, path-bound job outputs. Include them in
   every cell's closed attestation, compare them in approval, and pass them to
   the writer. Each output name must unambiguously identify one of:

   - `copilot-instructions.md`;
   - `powershell.instructions.md`;
   - `STYLE_GUIDE_CHAT.md`; and
   - `STYLE_GUIDE_FULL.md`.

   Approval should reject missing/empty/duplicate/wrong-path hashes. The writer
   should prove candidate, regenerated, destination, staged, committed, and
   post-push remote blobs all equal the propagated values.

3. **Extend P1's permanent validator.**

   P1B's “exactly two files” scope is incompatible with permanent enforcement.
   Its affected files should be exactly the two workflows plus P1's existing
   `.github/workflows/Validate-WorkflowPolicy.mjs`. Extend, rather than replace,
   the locked parser and fixtures. Package/lock bytes should remain unchanged in
   P1B.

   The validator needs exact tables for:

   - events, filters, local callable workflow, and permissions;
   - job IDs, order, direct `needs`, conditions, and output ownership;
   - static action roles and expanded runtime counts;
   - action repository/SHA/release annotation and full input map;
   - reviewed omitted defaults;
   - the four-cell include rows and unique output mapping;
   - candidate ID/digest/four-hash data flow;
   - failure-only diagnostic conditions/paths; and
   - exactly one write-enabled writer.

   Positive YAML must not generate its own allowlist. Fixtures should mutate one
   dimension at a time and expect one exact rejection.

4. **Correct the token claim everywhere.**

   The sentence that the token is not materialized until the exact push is
   false with the selected checkout action. State instead:

   - GitHub creates the token before each job; job permissions bound authority.
   - Every checkout explicitly receives the appropriate job token for fetch.
   - `persist-credentials: false` prevents it from remaining configured after
     checkout.
   - A presence-only post-checkout check rejects credential-bearing remotes,
     helpers, or HTTP authorization config without printing values.
   - Repository scripts receive no explicit token/header/helper/config
     environment.
   - Only the exact guarded push child receives a process-scoped derived HTTP
     authorization setting, cleared in `finally`.

   No job should be called token-free or credential-free. The meaningful
   boundary is read versus write authority, post-checkout persistence, and
   push-only construction of a new authorization header.

5. **Write one complete role/input/data-flow policy.**

   P1B's role table repeats P1's partial checkout/setup input sets and does not
   state all job-level side effects or data owners. Reuse P1's complete explicit
   checkout and setup-node input policy. Add an exact candidate-upload policy,
   including an explicit compression level and deliberate retention. Record
   absent download selectors such as name/pattern/cross-run token when immutable
   same-run artifact ID is required.

   Keep `archive: true`, `skip-decompress: true`, and
   `digest-mismatch: error` if re-review confirms the pinned action semantics.
   Distinguish the artifact's bare digest from any display prefix. Diagnostics
   should run only for ordinary failure and not cancellation, be
   `continue-on-error`, name only bounded test-owned paths, and never include a
   candidate archive, repository tree, token, Git configuration, or signed URL.

6. **Define the real-writer evidence protocol.**

   “Use unique temporary branch/artifact fixtures” does not explain how a
   writer whose production predicate is exact push-to-`main` can be exercised
   without weakening the reviewed workflow.

   Adopt an isolated evidence-ref protocol:

   - create one unpredictable `refs/heads/p1b-evidence/<utc>-<random>` from the
     reviewed production base;
   - use evidence-only commits that are never merged, rebased, cherry-picked,
     or squashed into production;
   - apply one upfront allowed-delta manifest covering only the exact event/ref
     literals, validator constants, bounded scenario selector, and one
     deterministic source fixture;
   - run the real prepare/matrix/approval/writer path against only that ref;
   - make every negative drill a closed data-only scenario, not a ref/path/
     command/expression injection channel;
   - retain run/ref/lease/tree/hash/diagnostic evidence without credentials;
   - restore any exact evidence-ref protection settings and delete the ref with
     an expected-old guard; and
   - prove the final production candidate contains no evidence condition,
     string, fixture, instrumentation, or alternate push path.

   Do not weaken `main` protection or prove only a copied writer.

7. **Use raw Git evidence and a satisfiable handoff.**

   Extend P1's raw NUL-delimited path/status contract to every worktree, index,
   generated-four, evidence-delta, tree, and commit gate. Classify all native
   statuses and start failures exactly. Add misleading path/status/extra-role
   combined fixtures.

   Before P1B merges, record the reviewed head, not a nonexistent future merge
   commit. P2 should record the actual landed commit and revalidate when the
   identities differ.

### P1B↔T1B convergence

P1B should converge with T1B on:

- one external event owner and one exact local callable workflow;
- one permanent locked workflow-policy parser;
- complete job/role/input/default/data-flow tables;
- immutable artifact ID, upload digest, and four path-bound hashes;
- four unique cell results and fail-closed approval;
- at-use helper execution and independent regeneration;
- exact captured ref/SHA, preflight, parent, tree, lease, refspec, and post-push
  identity;
- truthful token existence, checkout use, persistence, and push-header
  boundaries;
- isolated evidence-ref proof and cleanup;
- raw Git path/status handling; and
- bounded diagnostics and measured CI cost.

Repository-local names, artifact filenames, and job IDs may differ if their
semantics are equal and the matrix records why. Wider credentials, weaker
selection or lease, missing hash propagation, a second event owner, or an
unproved writer is a blocker.

## P2 — Make the non-compliant blank-line example visibly distinct

### What is strong

P2's content design is good. A `text` fence containing exactly four U+00B7
MIDDLE DOT characters makes the intended defect visible without storing
trailing spaces. The pre-block warning makes clear that the dots are
documentation substitutes and must not be copied into PowerShell.

The source/rationale split is also correct. `STYLE_GUIDE.md` should contain the
concise operational visualization once, while the existing Blank Line Usage
section in `STYLE_GUIDE_RATIONALE.md` explains the durability reason without
duplicating the example. Updating both sources and regenerating all four
artifacts in one commit is the correct normal path.

### Required revisions

1. **Update the stale pull-request evidence.**

   P2 currently says preparation and approval are push-only and that only the LF
   Windows cells run the helper suite. P1B instead requires:

   - preparation and immutable candidate upload on pull requests and pushes;
   - every Windows cell to run every applicable P1A stable case and validate the
     exact transported candidate;
   - read-only terminal approval on pull requests; and
   - only the writer to skip on a pull request.

   Rewrite P2's PR evidence after P1B's graph is finalized. Avoid repeating a
   different subset of P1B's implementation details in P2 acceptance.

2. **Replace both line-based path parsers.**

   `git status --porcelain=v1` plus `^..\s+`, and
   `git diff --cached --name-only`, are not safe exact-path protocols. Quoted
   paths, rename records, embedded newlines, tabs, and non-ASCII bytes can split,
   disappear, or spoof records. Use P1's raw NUL-delimited implementation for
   the complete working-tree/index/untracked union and the staged set, then
   compare canonical ordinal path bytes with exactly the six affected paths.

3. **Classify the final generator difference status.**

   The rerun block currently treats every nonzero `git diff --exit-code` as
   “generator changed the staged result.” Preserve 0 equal, 1 ordinary
   idempotency/content difference, and every other status/start failure as a
   distinct Git tool failure.

4. **Machine-check the unchanged Compliant example.**

   The Non-Compliant replacement has a strong exact snippet/count oracle, but
   “The Compliant example is unchanged” remains a visual assertion. At the
   recorded P1B landed commit, capture the exact source-blob-local Compliant
   section boundaries and bytes, or its exact canonical snippet plus ordinal
   location/count. Require byte equality after the edit and after regeneration.
   Include a negative fixture that changes only the Compliant block.

5. **Consume P1B instead of restating it.**

   P2 should identify P1B's landed commit, final job/output names, and run
   evidence, then validate the merged interface. Keep P2's durable acceptance
   focused on the six content files, metadata, regeneration, exact snippets,
   lint, and expected `has_changes=false` post-merge path. The writer's
   `has_changes=true` proof belongs to P1B's isolated evidence ref.

6. **Synchronize the scope exclusions with final P1/P1A/P1B files.**

   Add the context manager and permanent workflow-policy validator to the
   explicit “do not change” list. This is a consistency edit; the authoritative
   six-file affected set should remain unchanged.

With these changes, P2 is filing-ready.

## P3 — Remediate Markdown lint dependency advisories and add npm update governance

### What is strong

P3 correctly treats Node, npm, packages, the staged-index API, the actual Husky
hook, audit governance, workflow roles, and Dependabot as one final policy. It
also correctly keeps PSStyleGuide's staged-content behavior as an intentional
difference from TerraformStyleGuide's full-repository hook.

The audit identity model is sound:

- unique `(Package, AdvisoryUrl)` findings;
- a separate exact package-keyed `AuditNodePaths` set;
- no advisory/path Cartesian product;
- dated observations rather than acceptance counts;
- zero findings preferred;
- no empty exception mechanism when clean; and
- a real installed hook invoked through `git commit`.

### Blocking revisions

1. **Resolve the exact npm and Node policy in the issue.**

   “Choose one maintained exact npm” and “Node 22/24 with any required patch
   floor” leave the central contract undecided even though T3 has already
   resolved a compatible dated policy. Unless implementation-time re-resolution
   disproves it, converge on:

   - npm exactly `12.0.2`;
   - hashed Corepack `packageManager` identity;
   - Node `>=22.22.2 <23 || >=24.15.0 <25`;
   - Node 22.22.2 as the minimum cell; and
   - Node 24.15.0 as the preferred-line floor, with the implementation-time
     current Node 24 patch also tested.

   Use the exact integrity string already recorded in T3 after re-resolving it
   immediately before implementation. Run every package operation as
   `corepack npm ...`; do not use ambient/bundled npm, `npx`, a global install,
   or an npm devDependency. Assert exact npm identity and active Node process in
   every cell, designate one exact Node 24/npm pair as the lockfile producer,
   and prove other cells do not rewrite the lock.

   If PSStyleGuide evidence requires a different pair or floor, record that as
   an intentional difference with release, engine, integrity, and compatibility
   evidence. Do not leave the decision open merely because P3 is implemented
   later.

2. **Use one tracked Node-policy implementation and atomic cases.**

   Add a dependency-free `Check-NodePolicy.mjs` with a pure exported predicate
   and a production CLI that reads only actual `process.versions.node`. Have the
   hook invoke it and `lint-staged-markdown.mjs` import it. Do not maintain
   independent shell and JavaScript predicates.

   Add one closed case manifest, for example `node-policy-cases.json`, with one
   ID and one final oracle for every empty/malformed/prefix/suffix/whitespace/
   extra-component form, every below-floor/floor/current patch, intervening
   major, Node 26, and a future major. Give actual installed-hook runtime cells
   separate IDs from pure predicate inputs. `HOOK-08` cannot stand for all
   unsupported, malformed, and future cases.

3. **Bring the real Husky installer into scope and make it fail closed.**

   The live package's `prepare` script invokes
   `.github/workflows/install-husky.mjs`, but P3 neither lists nor specifies that
   file. Add it to the required affected set.

   Define an explicit state machine:

   - required install is the default;
   - skip is allowed only through named canonical states, such as
     `HUSKY_INSTALL_MODE=skip`, `HUSKY=0`, or exact `CI=true` with a recorded
     read-only-CI reason;
   - unknown values or conflicting skip sources fail;
   - required mode resolves the repository root, invokes the pinned Husky
     through the selected package environment, and verifies exact
     `core.hooksPath`, ordinary non-link shims, and the tracked pre-commit hook;
   - skip mode proves filesystem/config/byte immutability and never reports
     “installed”; and
   - every install, invocation, or verification error is nonzero.

   Add atomic cases for required success/failure, each skip, conflicts, wrong
   root/hooks path, missing/linked/substituted hook/shim, and a direct hook that
   passes while Git does not invoke it.

4. **Add continuous read-only execution.**

   Expiring exceptions are not continuous policy if audit runs only on PR and
   push. Corrected P1B makes `build.yml` the event owner, so P3 must add
   `build.yml` to scope and add:

   - ordinary and Dependabot pull requests to `main`;
   - pushes to `main`;
   - `merge_group` when enabled;
   - one read-only UTC schedule; and
   - optional read-only `workflow_dispatch`.

   Schedule/manual runs should invoke only the local Markdown/dependency
   validation and a read-only terminal result. They must not run candidate
   preparation/upload, Windows candidate validation, promotion approval, or the
   writer.

5. **Close the audit process, raw-input, and report schema.**

   Split the pure parser/policy core from PowerShell orchestration. Add
   `Validate-NpmAudit.mjs`; let `Test-NpmAuditPolicy.ps1` invoke the exact npm
   process and run integration fixtures.

   Define exactly:

   - argv: `corepack npm audit --package-lock-only --json`, with no
     `--audit-level`;
   - separate bounded stdout/stderr streams;
   - native outcomes `exit|signal|timeout|startFailure`;
   - a raw stdout size ceiling, BOM-less strict UTF-8, one complete JSON value,
     duplicate-key detection, and depth/count/string/number ceilings;
   - closed report-version-2 top-level, vulnerability, advisory, CVSS,
     `fixAvailable`, and metadata schemas;
   - reciprocal `via`/`effects` graph references;
   - sorted unique node paths resolved against the lockfile; and
   - closed stable validator exit classes for process/tool, JSON input, schema,
     status mismatch, policy mismatch, and governance failure.

   The exact decision table should distinguish exit 0/empty, exit 0/nonempty,
   exit 1/nonempty, exit 1/empty or malformed, and every other process outcome.
   A registry/network/tool failure must never become a governed residual.

6. **Define exception lifetime and external-issue evidence.**

   Replace “within repository maximum” with an actual maximum:

   - canonical whole-second RFC 3339 UTC timestamps ending in `Z`;
   - creation and approval at the same reviewed instant;
   - expiry later than approval and no later than exactly 30×24 hours;
   - exclusive expiry (`now >= expiresAt` fails); and
   - renewal requiring new clean-install, audit, fix-availability, controls,
     owner, and follow-up-status evidence—not timestamp-only editing.

   A pure offline validator can prove URL grammar but cannot prove a GitHub issue
   exists, is open, is not a pull request, has the expected owner, or still
   covers the current findings. Define the canonical PSStyleGuide issue URL
   grammar and retain a bounded live GitHub API/UI verification record at
   approval/renewal. The exception should bind its scope hash and retained
   evidence hash. The validator should report only that offline references are
   structurally valid; a reviewer separately validates the live record.

7. **Make every audit and hook case structurally atomic.**

   Add one exact `AUDIT-*` result for clean/no exception, clean/stale exception,
   residual/unapproved, exact approved residual, added/removed finding, added/
   removed node path, before/at/after expiry, malformed timestamp, unknown or
   duplicate property, schema/type/graph/status mismatch, invalid follow-up
   reference, non-JSON/truncated report, real current report, and process
   outcomes. Every row should assert one exit class, normalized finding set,
   node-path set, exception state, immutable input, and safe diagnostic.

   Apply the same rule to `NPM-*`, `LINT-*`, `HOOK-*`, installer, Node-policy,
   and workflow-policy cases. The harness must reject missing, duplicate,
   unexpected, or multiply emitted IDs.

8. **Consume P1's workflow-policy validator and update P1B atomically.**

   P3 changes the Markdown Node job/matrix, package manager, schedule/manual
   events, and package graph. Its affected set must therefore include
   `.github/workflows/Validate-WorkflowPolicy.mjs` and `build.yml`. Update the
   final P1B role/event/input/default tables and fixtures atomically. Retain the
   direct YAML parser through the dependency upgrade and rerun its offline
   positive/negative suite.

### Expected P3 scope after convergence

The final exact set depends on package compatibility and residual findings, but
the issue should expect at least:

- `.github/workflows/build.yml`;
- `.github/workflows/markdownlint.yml`;
- `.github/workflows/Validate-WorkflowPolicy.mjs`;
- `.github/workflows/Check-NodePolicy.mjs` — add;
- `.github/workflows/node-policy-cases.json` — add;
- `.github/workflows/install-husky.mjs`;
- `.github/workflows/lint-staged-markdown.mjs`;
- `.github/workflows/Test-LintStagedMarkdown.ps1` — add;
- `.github/workflows/Validate-NpmAudit.mjs` — add;
- `.github/workflows/Test-NpmAuditPolicy.ps1` — add;
- `.github/workflows/package.json`;
- `.github/workflows/package-lock.json`;
- `.husky/pre-commit`; and
- `.github/dependabot.yml`.

Add `.github/workflows/npm-audit-exceptions.json` only for a real approved
residual. Add the nested-lint implementation or Markdown configuration only
when a reviewed selected-package compatibility change requires it. No source
guide, generated artifact, generator, candidate helper, or writer semantics
should change.

## Cross-slate convergence model

The useful form of generator unification is contract and evidence convergence,
not a shared runtime dependency:

| Semantic layer | PS issue | Terraform issue | Required convergence | Intentional differences |
| --- | --- | --- | --- | --- |
| Deterministic generation | P1 | T1 | Closed artifact map, trusted root, complete-payload normalization, exact encoding/newline, verified replacement, version metadata, host matrix | Source composition, frontmatter, exact filenames |
| Workflow policy foundation | P1 | T1 | One locked strict YAML parser, authored role/input/default policy, raw Git gates, token terminology | Repository-local role/job names |
| Candidate validation | P1A | T1A | Raw inputs, same-stream digest/ZIP, component security, ceilings, fresh extraction, context schema, cleanup, semantic cases | Exact four manifest filenames |
| Verified publication | P1B | T1B | One event owner/callable workflow, ID/digest/four hashes, unique cells, approval, at-use regeneration, exact writer identity/lease/refspec, evidence ref | Repository-local names and generated paths |
| Dependency governance | P3 | T3 | Exact npm/Corepack, finite Node policy, real hook/installer, closed audit, bounded exceptions, schedule, Dependabot | PS staged-index API versus Terraform full lint |
| PS content repair | P2 | none required | Consume the merged generator/writer boundary without weakening it | Blank-line documentation is PS-specific |
| Terraform recovery guidance | none required | T2 and T4 | No forced PS analogue | Terraform state/provider safety is Terraform-specific |

Each reciprocal row should include exact immutable P and T commits, concrete
evidence, classification (`same`, `intentional difference`, or `blocker`), and
rationale. A repository-specific name is normally intentional. An unexplained
difference in path safety, failure transaction, archive identity, cleanup,
permissions, token handling, artifact selection, hash propagation, approval,
or lease is a blocker.

Keep both repositories self-contained. It is reasonable to copy the same
reviewed semantic skeleton and tests into each repository while retaining local
artifact maps, transformations, and issue ownership. Do not introduce a package
that makes either generator, validator, or writer depend on the other
repository at runtime.

## Cross-issue consistency edits

Before filing:

1. Preserve all five H1 issue titles exactly as drafted.
2. Refer to issues consistently as P1, P1A, P1B, P2, and P3; use T1/T1A/T1B/T2/
   T3/T4 for Terraform counterparts.
3. Add real issue URLs and GitHub blocked-by relationships as each issue is
   filed.
4. Put predecessor landed commits in successor Dependencies sections; do not
   make future successor actions predecessor closure criteria.
5. Use one external event owner after P1B and one local callable Markdown
   workflow.
6. Create one workflow-policy validator in P1, extend it in P1B, and update it
   in P3.
7. Use exact authored action inputs plus an explicit reviewed-omission/default
   table; do not conflate absent YAML keys with nonexistent action defaults.
8. Re-resolve action/package release tags, commit SHAs, metadata, integrity, and
   engine requirements immediately before implementation and merge.
9. Use repository-local IDs plus shared semantic keys instead of assuming equal
   short IDs across P and T.
10. Use raw NUL-delimited Git path evidence and exact native outcome classes in
    every issue.
11. Calculate each affected/staged path set exactly, and update it whenever a
    required validator, harness, or policy file is added.
12. Keep generated artifacts derived-only and commit ordinary source/artifact
    synchronization together.

## Filing recommendation

Revise all five drafts in place, then perform one final reciprocal read against
the revised Terraform slate. The minimum filing gate is:

- the dated npm-risk decision permits the selected order;
- P1 has the closed verified replacement transaction, literal version
  convention, permanent locked policy validator, complete action policy, and
  raw Git gates;
- P1A has raw input grammar, an exact context lifecycle, repository-local IDs,
  semantic keys, and one complete oracle per case;
- P1B has a same-run callable-workflow graph, four-hash data flow, one extended
  validator, truthful token model, isolated writer proof, and satisfiable
  handoff;
- P2's PR/post-merge expectations match P1B and its path/content checks are
  machine-exact; and
- P3 has exact npm/Node policy, the real installer, one Node-policy
  implementation, scheduled validation, a closed audit process/schema, bounded
  exception governance, atomic cases, and updated workflow policy.

Once those points are resolved, the slate will preserve the strongest parts of
the Terraform refinements while remaining appropriately specific to
PSStyleGuide.
