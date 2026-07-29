# Findings on the revised TerraformStyleGuide issue slate

## Overall assessment

The revised slate is substantially better than the earlier monolithic design.
T1, T1A, and T1B now describe three real trust boundaries: deterministic
generation, untrusted candidate validation, and trusted publication. T2 through
T4 also have unusually strong safety intent, testability, and negative-case
coverage for documentation issues.

The slate is not ready to file or implement unchanged. Five design gaps are
blocking because they make an acceptance criterion impossible to implement or
leave a safety-critical claim unproved:

1. T1 lost the reciprocal generator-convergence contract with PSStyleGuide.
2. T1A does not provide a complete, stable test oracle for its public
   parameters, limits, and caller-context lifecycle.
3. T1B attempts to make a job depend on a job in another workflow, omits the
   transport for four required preparation hashes, and does not define unique
   per-matrix-cell evidence.
4. T3 does not define a permanent residual-audit validator, and its proposed
   advisory-URL/path identity cannot be derived safely from npm audit report
   version 2.
5. T4 requires a copyable PowerShell backup path but supplies neither a
   byte-preserving implementation contract nor Windows tests, while its
   no-replace publication primitive is tested only as a stub.

After those corrections, the issue order should remain T1 → T1A → T1B → T2 →
T3 → T4. Each issue should consume the actual merge commit of its predecessor.
T3 may be expedited only under the security exception already contemplated by
the slate; doing so should be an explicit scheduling decision, not an
alternative dependency graph embedded in the issue text.

This review preserves each issue's H1 as its title and uses T1/T1A/T1B/T2/T3/T4
as the short names. The PSStyleGuide issues were used only to validate the
supplied cross-repository recommendations and generator/workflow convergence;
they were not independently reviewed as a second slate.

## Review anchors

- TerraformStyleGuide `main` was reviewed at
  `6ee3f57b2b71b885a5927b770dde47532944de62`.
- The live repository still has a single build job that generates and pushes
  directly, a separate Markdown workflow, Node 20 setup, mutable action tags,
  and four `Set-Content -Encoding UTF8` generator writes. Those facts make the
  proposed work relevant rather than hypothetical.
- T1/T1A/T1B are 345/457/473 lines respectively. The split improves ownership
  and reviewability even though each issue remains detailed.
- A local `npm --prefix .github/workflows audit --package-lock-only --json`
  produced npm audit report version 2 with package-level `nodes` and
  advisory objects, but no direct advisory-to-node edge. That matters to T3's
  proposed exception identity.

## Review of the seven supplied recommendations

### 1. Split P1 along T1/T1A/T1B trust boundaries

**Decision: Confirmed.**

The recommendation is valid. P1 currently combines generation, validation,
caller-context cleanup, artifact transport, and trusted publication in one
roughly 129 KB issue. The T1/T1A/T1B split is the clearer model because each
issue has one dominant security boundary and can be merged and validated before
the next begins.

Implications for this slate:

- Preserve the Terraform split.
- If the PSStyleGuide slate adopts the same split, route reciprocal comparisons
  to P1/P1A/P1B rather than continuing to call all three layers “P1.”
- Do not move final writer behavior back into T1 or T1A merely to keep the two
  repositories textually similar. Convergence should be by shared contract and
  reusable implementation, not by collapsing distinct trust boundaries.

### 2. Replace P1's stale “parallel T1” comparisons

**Decision: Confirmed.**

The recommendation is valid and is now bidirectional. P1's comparisons target
an older, monolithic understanding of T1. T1A and T1B compare themselves with
monolithic P1, while T1 has no PSStyleGuide comparison at all. The current text
therefore cannot prove the thoughtful generator unification requested for the
two repositories.

Required convergence model:

- T1 ↔ P1: generator input/output bytes, destination-path resolution, BOM,
  newline, and failure postconditions.
- T1A ↔ P1A: candidate validation, resource limits, caller-context lifecycle,
  and stable test cases.
- T1B ↔ P1B: artifact transport, credential lifetime, trusted identity, lease,
  regeneration, and publication behavior.

If the PS issues have not yet been split when a Terraform issue is filed, the
Terraform text should name the exact corresponding section and commit in P1,
then be updated to the final P1/P1A/P1B identifier before implementation.

### 3. Converge the generator destination-path contract

**Decision: Confirmed.**

The recommendation is valid. T1's proposed contract is stronger: accept one
filesystem path; reject unresolved wildcards, provider paths, and ambiguous
multi-match inputs; perform one explicit BOM-less UTF-8 write; and do not alter
the destination on failure. P1's sample path resolution does not state all of
those rejection and postcondition rules.

T1 should keep its stronger semantics and add a reciprocal matrix that records
whether PSStyleGuide is identical for each behavior. The intended end state is
one shared generator contract and, where practical, one shared implementation.
Any deliberate difference must include a repository-specific reason and test.
An unresolved difference must block the “unified generator” acceptance
criterion rather than be recorded as informational drift.

### 4. Add candidate resource limits and a caller-context lifecycle

**Decision: Confirmed.**

The recommendation is valid. T1A's archive, entry, and generated-file byte
limits and its explicit `New-...`/`Remove-...` caller context are meaningful
improvements over P1. They bound decompression and cleanup work and make
adversarial cleanup testable.

T1A does not yet prove its own stronger contract. It needs one exact oracle row
per stable case ID for:

- each 8 MiB entry, 32 MiB archive, and 32 MiB generated-file boundary;
- just-below, exactly-at, and just-above cases where the boundary permits them;
- invalid artifact digest grammar;
- zero, one, and multiple artifact-download results;
- wrong download result types;
- wildcard, provider, missing, and multi-match path resolution;
- omitted, explicit-null, empty, and non-empty optional labels;
- candidate cleanup and caller-context cleanup after validation failures and
  cleanup failures.

The permanent harness also needs an explicit `ContextManagerPath` parameter or
a normative, testable sibling-resolution rule. A `HelperPath` alone does not
tell an out-of-tree caller which context-manager implementation is under test.

### 5. Bring the P writer to T1B's credential and identity boundary

**Decision: Confirmed.**

The recommendation is valid. T1B's four-local model, process-scoped HTTP
authorization for only the exact push, no credential persistence, NUL-safe
enumeration, ref/object identity checks, independent regeneration, and
force-with-lease publication are a better least-privilege boundary.

Persisted checkout credentials can be functional, but they leave the write
credential available for more steps and subprocesses than the exact push
requires. That conflicts with the slate's own least-privilege goal. The two
repositories should converge on the T1B model unless a documented platform
constraint makes one element impossible.

T1 should also name the same process-scoped authorization method for its
temporary writer. “Expose its write credential only for the exact push step”
states a goal, not an implementation contract, and could otherwise be
implemented with a credential-bearing remote URL or another broader mechanism.

### 6. Bound P3's Node support policy

**Decision: Confirmed.**

The recommendation is valid. A minimum-only range silently admits unsupported
future majors and intervening releases. T3's bounded engine policy plus an
exact CI major is the safer contract.

T3 should retain that policy and make the hook oracle explicit:

- the minimum supported version passes;
- each supported major passes;
- a version below the minimum fails;
- an intervening unsupported major fails; and
- the first major above the upper bound fails.

The package `engines.node`, hook message, local tests, and CI setup must all
derive from or assert the same range so they cannot drift.

### 7. Make residual P3 audit approvals durable

**Decision: Confirmed, with a correction to the Terraform identity model.**

The recommendation is valid. A one-time array or issue snapshot does not
enforce expiry, topology, or clean-baseline behavior after merge. T3 correctly
moves toward a conditional, versioned exception file and recurring CI
enforcement.

However, T3 should not make an advisory URL/path pair the primary identity.
npm's audit report exposes package nodes and advisory objects without a direct
edge proving that every advisory applies to every node. Blind pairing can
over-approve paths. Use:

- primary identity: `(Package, AdvisoryUrl)`;
- a separate, exact package-keyed set of approved audit node paths;
- an exact semver-aware validator if advisory-to-node pairing is retained; and
- no exception file at all when a clean install has no residual findings.

The validator must run after a clean install in local integration tests and in
the hosted workflow, reject expired or unused entries, reject new packages,
advisories, or paths, and require deletion of the exception file when the
baseline becomes clean.

## Sequential TerraformStyleGuide issue review

## T1 — Make artifact generation byte-deterministic and standardize repository text checkouts on LF

**Disposition: Good foundation; revise before filing.**

### Improvements to preserve

- The issue is now limited to repository text policy, deterministic generator
  writes, pinned workflow actions, Node 24, and a temporary publication path.
- The one-path, no-wildcard/no-provider/no-multi-match destination contract is
  precise and reusable.
- A single `UTF8Encoding(false)` plus `WriteAllText` boundary is a sound way to
  avoid PowerShell-edition-dependent BOM behavior.
- Exact action SHAs and explicit Node 24 setup reduce mutable runtime inputs.
- Separating untrusted validation and the final writer into T1A/T1B is the
  correct trust-boundary design.
- The five-file LF normalization scope is feasible against the reviewed `main`
  tree; the issue does not need a repository-wide historical rewrite.

### Required revisions

1. **Restore the missing generator-convergence matrix.** Add the T1 ↔ P1
   comparison described under recommendation 2. It should cover public
   parameters, path resolution, content assembly, LF/BOM behavior, write count,
   failure destination state, and shared tests. Classify every row as identical,
   deliberate difference, or unresolved blocker.
2. **Specify temporary push authentication.** Reuse T1B's process-scoped
   environment-backed HTTP authorization, prohibit credential-bearing remote
   URLs and persisted checkout credentials, and limit the token to the exact
   `git push` process.
3. **Fix the merge-commit acceptance criterion.** A T1 pull request cannot know
   its own future merge commit. T1 should require T1A's issue/PR to record the
   T1 merge commit it consumes. T1 may record the reviewed head commit and the
   required successor handoff.
4. **Name the temporary boundary clearly.** State that T1's publication path is
   intentionally transitional and must be removed, not preserved alongside,
   T1B's final writer. This prevents the two writers from coexisting after T1B.

### Concern, not a blocker

The issue allows T3 to be run early under a policy exception. That is sensible
for an active advisory, but the normal dependency remains T1 through T1B first.
Record an actual exception decision and the commits compared if the order is
changed; do not weaken T1's Node/action requirements to accommodate it.

## T1A — Add a fail-closed cross-platform style-guide candidate validator

**Disposition: Strong design; test contract is incomplete.**

### Improvements to preserve

- The helper has a narrow parameter surface and a single structured result.
- Candidate materialization is fail-closed, avoids following directory links,
  and holds the validated file open through inspection.
- The 8/32/32 MiB limits bound individual entries, archive work, and generated
  content.
- The caller context gives normal and adversarial cleanup explicit ownership.
- The permanent harness and Windows PowerShell 5.1/PowerShell 7 coverage turn a
  subtle helper into a maintainable repository contract.
- Exact candidate names and cleanup ownership reduce path-substitution and
  stale-file reuse.

### Required revisions

1. **Make the context-manager input deterministic.** Add a mandatory exact
   `ContextManagerPath`, or define and test one safe sibling-resolution rule.
   Reject missing, wildcard, provider, multiple, and non-file resolutions for
   both helper scripts.
2. **Replace grouped case ranges with one row per stable ID.** Each row should
   name setup, invocation, expected result or exception class, expected
   candidate state, expected context state, and expected cleanup diagnostics.
   “V01–V08” is not the promised exact oracle.
3. **Add resource-boundary cases.** Test every declared limit, actual
   decompressed byte counting, misleading ZIP metadata, and cumulative archive
   overflow. Include exact-at-limit behavior so future maintainers cannot
   silently change `<` to `<=`.
4. **Complete public-input coverage.** Add invalid digest grammar, zero and
   multiple downloads, unexpected result types, wildcard/multi-match paths,
   explicit-null labels, and invalid label types where PowerShell binding does
   not already make the result unambiguous.
5. **Exercise both production cleanup paths.** Current cleanup cases emphasize
   candidate deletion. Add failures and idempotency tests for caller-context
   cleanup, including a primary validation error followed by cleanup failure
   without losing either diagnostic.
6. **Fix the future-merge wording.** The T1A pull request cannot record its own
   future merge commit. T1B must record the T1A merge commit it consumes.
7. **Update the reciprocal comparison target.** If PSStyleGuide is split, this
   layer should compare with P1A rather than monolithic P1.

### Exactness improvement

Assign stable IDs to the newly added cases rather than renumbering existing
ones. Stable IDs are valuable only if a historical failure can still be mapped
to the same behavior after the suite grows.

## T1B — Promote generated style-guide artifacts through a least-privileged verified writer

**Disposition: Security model is good; workflow topology is not implementable
as written.**

### Improvements to preserve

- The preparation, four-cell read-only validation, approval, and writer stages
  express the intended trust boundary well.
- The four-local writer identity model prevents branch/ref/object ambiguity.
- The writer independently regenerates both artifacts rather than trusting the
  promoted bytes alone.
- Exact artifact identity/digest checks and archive-entry checks reduce
  transport substitution.
- NUL-safe changed-path enumeration, canonical ref resolution, four-object
  equality, and an explicit lease make the write set and push target auditable.
- The credential is limited to one exact push process; diagnostic checks are
  explicitly credential-free.
- The cost guard prevents an expensive four-cell matrix from running on
  irrelevant changes.

### Required revisions

1. **Resolve the cross-workflow dependency.** `markdownlint.yml` is a separate
   workflow, so a job in `build.yml` cannot name its Markdown job in
   `jobs.<job_id>.needs` or consume its result. GitHub documents `needs` as the
   jobs that a job depends on in the workflow, and the `needs` context contains
   direct dependency jobs. Keep Markdown as an independent required check and
   add a build-local Ubuntu/preparation gate, or deliberately consolidate the
   jobs into one workflow. Do not leave “approval depends on Markdown/Ubuntu”
   as an impossible cross-workflow edge.
2. **Transport the four preparation hashes.** The preparation step records four
   candidate SHA-256 values, but the exhaustive job-output list omits them
   while the writer must compare against them. Add four explicitly named
   immutable outputs, include them in the approval/writer contract, or remove
   that comparison and rely on the artifact service digest plus independent
   writer regeneration.
3. **Define unique matrix evidence.** Matrix job outputs are combined only when
   output names are unique; duplicate names can be overwritten by the
   last-finishing cell, whose order is not guaranteed. Give each of the four
   static cells unique result/digest keys or use four explicitly named jobs.
   The approval job must prove that all four expected cells ran, not merely that
   some matrix execution succeeded.
4. **Make the YAML structural check executable.** Name the parser or exact
   in-repository validation method used to prove action SHAs, permissions,
   credential settings, job dependencies, and event routing. Text matching is
   insufficient for nested YAML structure.
5. **Update the comparison target to P1B** if the PSStyleGuide split is adopted.

The first three points are acceptance blockers. GitHub's documented matrix
output behavior explicitly requires unique names when combining matrix outputs:
[workflow syntax for job outputs](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idoutputs).
The job dependency boundary is documented in
[Using jobs in a workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs)
and the
[`needs` context](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#needs-context).

## T2 — Make state-version discovery and recovery examples copy-safe with guarded identifiers

**Disposition: Nearly ready; define failure-state semantics.**

### Improvements to preserve

- The AWS, Azure, GCS, and HCP examples separate discovery from retrieval and
  require operators to inspect identifiers before use.
- Closed filters, exact cardinality checks, explicit pagination behavior, and
  GCS generation qualification reduce “latest-looking object” mistakes.
- The HCP host, endpoint, page, and token constraints are appropriately
  fail-closed.
- Recovery uses a fresh destination and requires validation before the file is
  treated as usable state.
- Seven marker-owned blocks plus a permanent harness make the documentation
  samples testable without live provider accounts.
- The warnings about plaintext sensitive values are necessary; Terraform's
  machine-readable state can expose sensitive values in plain text. Preserve
  the exact cleanup and access-control guidance.

### Required revisions

1. **Choose one postcondition for provider failure.** AWS, Azure, and GCS
   download commands may create a partial destination before returning failure.
   The provider sections must say whether the exact newly owned partial file is
   retained as invalid evidence or safely removed. The harness already expects
   partial-file cases, but it cannot assert an unstated result.
2. **Make ownership conditions executable.** If partials are removed, deletion
   must be limited to the exact fresh ordinary file created by that invocation;
   never recursively clean or follow a substituted link. If retained, label it
   invalid, stop before `terraform show`, and require a different fresh path on
   retry.
3. **Say Bash, not “Bash or compatible POSIX.”** The GCS examples use Bash
   `[[ ... =~ ... ]]`, and the permanent harness is Bash. Calling the contract
   generic POSIX invites incompatible copying.
4. **Carry T1B's workflow decision forward.** T2 may add its Bash harness to
   Markdown validation, but must not recreate the impossible cross-workflow
   approval dependency identified in T1B.

Terraform documents that `terraform state pull` writes state to stdout and may
upgrade it to the locally supported format:
[`terraform state pull`](https://developer.hashicorp.com/terraform/cli/commands/state/pull).
It also documents JSON inspection and the plaintext-sensitive-value risk:
[`terraform show`](https://developer.hashicorp.com/terraform/cli/commands/show).
Those behaviors support T2's insistence on fresh destinations and validation,
but make the partial-output rule important.

### Minor clarity improvement

Give each partial-retention/removal case a stable provider-prefixed ID. This
will keep failures useful when more provider variants are added.

## T3 — Remediate Markdown lint dependency advisories and add npm update governance

**Disposition: Correct policy direction; residual-audit enforcement needs a
redesign.**

### Improvements to preserve

- The issue requires a fresh clean-install audit rather than assuming the
  planning snapshot remains accurate.
- A bounded Node support range, exact CI major, package engines, and hook guard
  create a coherent runtime policy.
- The real-git-commit hook harness is much stronger than testing an isolated
  shell fragment.
- The full outer/nested lint sequence is retained.
- The exception file is conditional and must disappear when no residual
  findings remain.
- Update governance covers lockfile maintenance instead of treating the first
  remediation as permanent.

### Required revisions

1. **Define one permanent audit validator.** Name its path, command line,
   inputs, output, exit codes, and stable cases. Invoke that same validator
   after a clean install in the local integration harness and the hosted
   workflow.
2. **Use a derivable residual identity.** Prefer `(Package, AdvisoryUrl)` plus
   exact package-keyed `AuditNodePaths`. If T3 keeps advisory/path pairs, it
   must implement advisory semver-range evaluation against the installed node,
   not take a Cartesian product of advisory URLs and package paths.
3. **Define the repository maximum approval lifetime.** “Within repository
   maximum” has no value. Specify an exact duration, the timestamp basis and
   timezone, whether the boundary is inclusive, and which owners may approve a
   renewal.
4. **Reject stale permission, not just new risk.** The validator must fail for
   expired entries, unused entries, extra paths, extra advisory URLs, unknown
   schema fields, duplicate identities, malformed timestamps, and an exception
   file that remains after a clean audit.
5. **Add stable audit cases.** The current NPM/HOOK inventory needs AUDIT cases
   for clean/no-file, findings/no-file, exact approved residual, new advisory,
   new node, removed advisory, expiry boundary, malformed schema, duplicate
   record, and clean-with-file.
6. **Expand the Node boundary cases.** Explicitly cover below-minimum,
   intervening unsupported, maximum supported, and first future unsupported
   major.
7. **State the workflow event behavior.** Dependency changes from Dependabot
   and ordinary pull requests must exercise the validator before merge. A
   scheduled run is useful for newly published advisories but cannot replace
   pull-request enforcement.

### Evidence behind the identity concern

The reviewed npm report placed `nodes` at the package vulnerability level and
placed source advisory URLs in advisory objects. It did not state which node
was affected by which one of several advisory ranges. The proposed
URL/path-pair identity therefore requires additional semver reasoning that the
issue does not specify. Keeping approval identity and topology as separate
exact sets is simpler and less likely to grant accidental coverage.

## T4 — Make manual state backup and destructive recovery guidance copy-safe

**Disposition: Sound recovery sequence; PowerShell and no-replace claims are
unproved.**

### Improvements to preserve

- The issue correctly prefers declarative `moved`, `removed`, and `import`
  mechanisms before destructive state commands.
- Backup, inspection, typed confirmation, destructive mutation, and recovery
  are separated into explicit phases.
- The backup path is fresh, protected, and tied to digest, serial, lineage, and
  backend identity.
- The no-overwrite publication goal prevents an existing backup from being
  silently replaced.
- Recovery rechecks lineage and serial before `state push` and requires
  external exclusion when the backend cannot lock.
- Provider calls are stubbed in the permanent harness, preventing tests from
  touching real state.

### Required revisions

1. **Specify the PowerShell backup implementation.** Ordinary native-output
   redirection is not byte-preserving in Windows PowerShell 5.1; Microsoft
   documents that it treats byte streams as strings and can corrupt them.
   PowerShell 7.4 introduced byte-preserving native redirection. The copyable
   cross-edition example therefore needs an exact .NET process/file strategy
   that copies redirected stdout bytes to a `FileMode.CreateNew` temporary file,
   observes the native exit code, and publishes without replacement.
2. **Add Windows PowerShell tests.** Give the PowerShell block its own stable
   marker and extend the affected-file list with a PowerShell harness. Test
   Windows PowerShell 5.1 and current PowerShell 7 on Windows, including
   non-ASCII state, empty/truncated output, command failure after partial
   output, existing destination, link substitution, and cleanup failure.
3. **Test the real no-replace primitive.** Stubbing `terraform` is appropriate;
   stubbing the safety-critical hard-link/publication operation is not enough.
   Add real same-filesystem tests proving create-new behavior, existing-target
   refusal, and the competing-creator race on each supported implementation.
4. **Define fallback support.** If hard links are unavailable, either fail
   closed with a clear message or specify an equally atomic no-replace
   primitive and test it. Do not silently fall back to copy/rename operations
   that can overwrite.
5. **Assign stable case IDs.** The current behavior groups should become
   durable Bash and PowerShell case identifiers with one exact oracle per row.
6. **Define typed-confirmation strength.** Specify the digest-prefix length and
   case format; accepting an arbitrary one-character prefix does not meaningfully
   bind the operator to the reviewed backup.
7. **Describe backend identity honestly.** If `EXPECTED_BACKEND_ID` is supplied
   manually, call the check operator-attested. A claim that the script
   mechanically verifies the exact backend needs an exact derivation method for
   every supported backend.
8. **Specify lock waiting for recovery.** Keep locking enabled and use an
   explicit positive lock timeout for `terraform state push`, or state why an
   immediate lock failure is the deliberate policy.
9. **Update the exact affected-file list.** Adding the required PowerShell
   harness and Windows workflow coverage changes the present eight-path claim.

Microsoft's Windows PowerShell documentation states the binary-redirection
limitation:
[about_Redirection for Windows PowerShell 5.1](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection?view=powershell-5.1#redirecting-binary-data).
The current documentation identifies byte preservation as a PowerShell 7.4
change:
[about_Redirection for PowerShell 7.5](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection?view=powershell-7.5#redirecting-binary-data).

Terraform already rejects some unsafe pushes using lineage and serial, but also
warns that manual push is dangerous:
[manual state pull/push](https://developer.hashicorp.com/terraform/language/state/backends#manual-state-pull-push).
T4's additional operator checks remain justified.

## Cross-issue consistency changes

These edits should be made consistently rather than repaired in only one issue:

1. **Predecessor evidence:** the successor issue/PR records the actual merge
   commit consumed. A pull request never promises to record its own unknown
   future merge commit.
2. **Workflow topology:** decide in T1B whether Markdown remains an independent
   required workflow or becomes part of one consolidated workflow. T2, T3, and
   T4 must extend that decision without inventing cross-workflow `needs` edges.
3. **Stable oracle format:** every permanent harness should use one row per
   durable case ID with setup, command, exact expected result, filesystem
   postcondition, and cleanup postcondition.
4. **Generator convergence:** compare the same layer on each side—T1/P1,
   T1A/P1A, T1B/P1B—and make unexplained differences merge blockers.
5. **Fresh-path ownership:** candidate files, recovered state, and local backups
   should share one vocabulary for exact path ownership, ordinary-file checks,
   link rejection, no-replace creation, failure state, and cleanup.
6. **Runtime policy:** Node bounds, CI major, package engines, hook error text,
   and tests should state one policy. Do not duplicate subtly different ranges.
7. **Security exceptions:** exception records require an exact schema, durable
   validator, stable negative cases, expiry rule, owner, and delete-when-clean
   behavior.

## Recommended disposition before downstream authoring

Revise all six descriptions in place while preserving their current H1 titles.
The minimum ready-to-file gate is:

- T1 contains the generator convergence matrix and an exact temporary
  credential method.
- T1A has an exact context-manager input and a complete one-ID-per-oracle test
  inventory.
- T1B has an implementable single-workflow dependency graph, immutable hash
  transport, and unique four-cell evidence.
- T2 defines the partial-output postcondition and calls its shell contract
  Bash.
- T3 defines and invokes a permanent, semver-correct residual-audit validator
  with an exact maximum approval lifetime.
- T4 supplies and tests a real cross-edition PowerShell backup path and real
  no-replace filesystem publication.

With those changes, the slate will have a coherent progression from
deterministic bytes, through untrusted validation, to least-privileged
publication, followed by independently testable documentation and dependency
governance.
