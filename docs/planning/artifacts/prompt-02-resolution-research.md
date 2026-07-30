# Primary-source research for prompt 02 resolutions

Research began 2026-07-29. This artifact records the source facts used to
select resolutions in `current-findings-evaluation.md`. Source URLs and the
relevant behavior are retained so later issue editing does not depend on
retrieving the pages again.

## T1 lockfile producer — exact Node/npm identity and frozen installs

Sources:

- [Node.js v24.18.1 archive](https://nodejs.org/en/download/archive/v24.18.1)
- [npm 11 `npm install`](https://docs.npmjs.com/cli/v11/commands/npm-install/)
- [npm 11 `npm ci`](https://docs.npmjs.com/cli/v11/commands/npm-ci/)
- [Node.js Corepack documentation](https://nodejs.org/download/release/v24.0.1/docs/api/corepack.html)
- [npm `packageManager` field documentation](https://nodejs.org/download/release/v24.0.1/docs/api/packages.html#packagemanager)

Retained facts:

1. The official archive identifies Node.js `v24.18.1` as an LTS release and
   identifies its bundled npm version as `11.16.0`. The archive also links the
   release's signed `SHASUMS256.txt` and binary artifacts. A Node major such as
   `24` does not identify this npm patch.
2. `npm install --package-lock-only` updates only `package-lock.json`; it does
   not populate `node_modules`. The ordinary package/lock reconciliation rules
   still apply, so the command must run after the intended exact dependency is
   present in `package.json`.
3. `npm ci` requires an existing lockfile, exits when the manifest and lockfile
   disagree, removes an existing `node_modules`, and never writes either
   `package.json` or a lockfile. It is the appropriate nonproducer install
   operation.
4. Corepack can download and run package managers, and a project's
   `packageManager` field can select an exact manager version. Package managers
   are not part of the Corepack distribution itself.
5. Introducing or changing `packageManager` is therefore a durable repository
   policy change, not merely evidence about the one process that generated a
   lockfile.

Resolution consequence:

- T1 must name an exact Node/npm producer pair before it permits the lockfile
  update. If implementation begins while `v24.18.1` remains the selected Node
  24 LTS patch, the recorded pair is Node `24.18.1` with its bundled npm
  `11.16.0`; a later implementation must re-resolve the pair and amend the
  issue's literal values before editing the manifest or lockfile.
- The producer must be acquired from the official Node release, verified
  against its signed checksum material, and recorded with executable version
  output and hashes.
- T1 should not introduce an interim `packageManager` field because T3 already
  owns the repository's final npm policy. T1 instead confines the exact pair to
  its one lock-producing operation.
- Every other install in T1 uses `npm ci --ignore-scripts`; pre/post manifest
  and lockfile hashes prove those cells did not become accidental producers.

## T1 reciprocal matrix — repository contract inventory

Repository sources reviewed:

- `docs/planning/TerraformStyleGuide/03TerraformStyleGuideT1.md`, especially
  requested changes 9–12 and its current reciprocal matrix.
- `docs/planning/PSStyleGuide/01PSStyleGuideP1.md`, especially requested
  changes 10–12 and its validation/handoff contracts.

Retained facts:

1. Terraform T1's reciprocal table currently enumerates public parameters,
   destination resolution, content assembly, byte serialization, the write
   boundary, failure destination state, and edition/host tests.
2. Both foundation issues separately impose cross-repository-relevant
   contracts that the table does not enumerate: the first-version grammar and
   consumer, exact YAML package/lock producer, strict workflow parsing,
   action provenance, explicit authored inputs versus reviewed pinned-manifest
   defaults, native/raw Git result semantics, the checkout/push credential
   boundary, the temporary writer's workflow graph, and removal/retention of
   temporary evidence.
3. PS P1's prose comparison list mentions Node/action foundations, native
   exits, and temporary publication, but it likewise does not provide stable
   row identifiers or a closed evidence schema for those subjects.
4. Both issues already require exact implementation-start and pre-merge
   commits, per-row evidence, a status of `same`, `intentional difference`, or
   `blocker`, and a rationale. The missing work is an exhaustive, symmetric row
   catalog and precise evidence fields—not a new runtime dependency.

Resolution consequence:

- retain one self-contained reciprocal matrix in each repository;
- give every shared generator/foundation concern a stable semantic row ID;
- require the same row set and evidence schema on both sides;
- treat a missing row, missing locator, missing evidence, or unexplained
  security/failure difference as a blocker; and
- permit repository-specific paths, names, and payloads only as documented
  intentional differences, never as a reason to omit a shared control.

## T1 temporary workflow graph — `needs`, eligibility, and permissions

Primary sources:

- [GitHub Actions workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [GitHub Actions contexts reference](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts)
- [GitHub job conditions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions)

Retained facts:

1. Jobs run in parallel by default. `jobs.<job_id>.needs` is the mechanism that
   makes named jobs direct prerequisites and, absent an overriding condition,
   requires them to complete successfully.
2. A failed or skipped prerequisite causes a dependent job to skip unless an
   expression such as `always()` overrides the normal success requirement.
3. The `needs` context contains only direct dependencies. Its
   `needs.<job_id>.result` value is one of `success`, `failure`, `cancelled`,
   or `skipped`.
4. A job-level `if` controls eligibility. A skipped job reports a successful
   check status, so a skipped write job is not itself evidence that verification
   ran; the verification job remains the required check/evidence source.
5. Job-level `permissions` can narrow or expand the token independently.
   Specifying any permission sets unspecified permissions to `none`; therefore
   one `contents: write` job can coexist with a workflow-level
   `contents: read` default without granting write to verification.

Resolution consequence:

- publish a closed table for every job in both in-scope workflows;
- make the temporary writer directly `needs: verify`;
- give it a literal push-to-`main` job condition that also requires
  `needs.verify.result == 'success'`;
- define no job outputs because the writer regenerates and validates from its
  own exact checkout;
- keep workflow-level `contents: read` and place `contents: write` only on the
  temporary writer;
- author an exact success-only condition on the generated-file upload instead
  of asking the implementation to choose a failure/success policy; and
- validate the exact job set, direct edges, conditions, outputs, permissions,
  and side-effect classes, not only external-action roles.

## T1/T1A version markers — timeless parsing versus change-time policy

Repository sources reviewed:

- `docs/planning/TerraformStyleGuide/03TerraformStyleGuideT1.md`, requested
  change 9.
- `docs/planning/TerraformStyleGuide/03aTerraformStyleGuideT1A.md`, affected
  files, public contracts, harness input validation, validation, and acceptance
  criteria.

Retained facts:

1. T1 defines a four-component `System.Version` marker whose Build component is
   an eight-digit real UTC calendar date. It also defines a release rule:
   Major for breaking change, Minor for compatible capability, Build for the
   actual modification date, and Revision reset/increment behavior.
2. T1 currently lists a “stale date” beside timeless grammar failures even
   though it does not define a stable reference date.
3. T1A repeats “stale” for all three newly created scripts and requires its
   harness to check the exact expected script versions recorded by the T1A
   commit.
4. Comparing a committed marker to the execution day's clock would eventually
   invalidate unchanged, known-good scripts. Comparing it to an explicit
   expected version remains deterministic and is already part of T1A's
   immutable-identity defense.

Resolution consequence:

- the reusable parser is clock-free: it proves marker location/count, exact
  four-component grammar, integer bounds, and a real Gregorian Build date;
- a consumer may separately require equality to an explicit version from its
  reviewed source commit, and that mismatch is `unexpected-version`, not a
  stale calendar date;
- the pull-request/merge gate compares a changed script to its merge-base
  version and the recorded implementation UTC date, enforcing the bump/date/
  reset rules;
- unchanged old scripts continue to parse and run indefinitely; and
- T1 and all three T1A scripts use the same two-layer vocabulary and fixtures.

## Cross-slate `main` governance — current state and compatible protection

Live read-only evidence on 2026-07-29:

- `GET /repos/franklesniak/TerraformStyleGuide/rulesets` returned `[]`.
- `GET /repos/franklesniak/TerraformStyleGuide/branches/main/protection`
  returned HTTP 404, `Branch not protected`.
- `GET /apps/github-actions` identified the GitHub-owned GitHub Actions App as
  integration ID `15368` and showed its current repository permissions,
  including contents write.

Primary sources:

- [About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [Creating a repository ruleset](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository)
- [Repository rulesets REST API](https://docs.github.com/en/rest/repos/rules)
- [`GITHUB_TOKEN` event behavior](https://docs.github.com/en/actions/concepts/security/github_token)

Retained facts:

1. Branch protection/rulesets can prevent deletion and force pushes and can
   require pull requests and status checks before ordinary updates.
2. For a personal repository, classic branch-protection bypass lists are not
   a general actor-selection solution: GitHub documents actor bypass lists for
   classic rules as organization-repository behavior.
3. Repository rulesets support bypass actors of type `Integration`, including
   on personal repositories; `OrganizationAdmin` is the actor type explicitly
   documented as inapplicable to personal repositories.
4. A bypass actor with mode `always` bypasses the ruleset. Therefore adding the
   GitHub Actions integration does not make an arbitrary write-capable workflow
   safe; T1/T1B's closed workflow graph and sole `contents: write` job remain
   the authorization boundary. The ruleset principally blocks unreviewed human
   direct/force/delete operations while allowing the reviewed writer design.
5. A push performed with the repository `GITHUB_TOKEN` does not trigger a new
   workflow run. Required-check policy cannot assume the generated child commit
   will produce a second run.

Resolution consequence:

- create a separately authorized repository-settings prerequisite rather than
  implying that issue file changes configure protection;
- use one active branch ruleset targeting only `refs/heads/main`, with deletion
  and non-fast-forward updates prohibited and ordinary actors required to use
  a pull request and the T1B terminal approval check;
- give only the exact GitHub Actions integration ID `15368` an `always` bypass,
  after re-resolving the official app identity at implementation time;
- prove the exact `GITHUB_TOKEN` writer actor can update an equivalent isolated
  evidence ref under byte/field-equivalent rules before activating main;
- record the full returned ruleset JSON/ID, effective-rules API response,
  actor identity, test results, and rollback document; and
- call a commit “landed on ruleset-protected main” only after a live
  post-merge query proves that exact state.

## T1A public inputs — PowerShell binder conversion boundary

Primary sources:

- [PowerShell type conversion](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_type_conversion)
- [PowerShell advanced function parameters](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters)
- [`AllowNullAttribute`](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.allownullattribute)

Retained facts:

1. PowerShell performs implicit conversion during parameter binding when a
   function/script parameter declares a specific type.
2. Any value can be coerced to String through `ToString()`. Arrays can be
   converted element-by-element and joined using the output-field separator.
   Advanced functions reject some array-to-scalar conversions, but other
   objects and numeric values can still convert before function code sees them.
3. A parameter declared `[object]` (or without a specific type) permits the
   caller's value type to reach the function without target-type conversion.
4. A mandatory parameter normally rejects null; `AllowNull` explicitly lets
   null reach the function. `AllowEmptyString` and `AllowEmptyCollection`
   similarly permit those values so the function can classify them under its
   own deterministic validation/diagnostic contract.
5. Validation-attribute ordering can itself change whether validation occurs
   before or after type conversion. Binder-owned regex/type validation is
   therefore the wrong layer when the issue promises raw-type classification
   and stable subreasons across PowerShell editions.

Resolution consequence:

- every untrusted scalar-looking public argument is declared `[object]`, with
  the allow attributes needed for negative values to reach body validation;
- the first executable validation snapshots boundness and raw runtime type,
  rejects null/type/collection before string operations, and never casts or
  interpolates an invalid value;
- paths and digest require an actual `System.String`; optional labels
  distinguish omission through `$PSBoundParameters` and require an actual
  string when present;
- digest and label validation use closed, ordered grammars after raw-type
  validation; and
- the permanent harness includes numeric, Boolean, array, hashtable,
  `PSCustomObject`, `StringBuilder`, null, empty, whitespace, and control-value
  cases under both Windows PowerShell 5.1 and PowerShell 7.

## T1A catalog — normative rows, profiles, and reciprocal semantics

Repository sources reviewed:

- `docs/planning/TerraformStyleGuide/03aTerraformStyleGuideT1A.md`, requested
  changes 10 and 13–14.
- `docs/planning/PSStyleGuide/01aPSStyleGuideP1A.md`, permanent stable-ID
  harness and reciprocal comparison.

Retained facts:

1. Terraform T1A currently has 109 unique local IDs and 109 unique
   `SemanticCase` strings, but every semantic string ends in an ordinal
   `.case-N` rather than naming behavior.
2. The four-column Terraform table frequently states only a phase or prose
   such as “success”; the later schema promises many more exact fields:
   applicability, fixture, initial state, pass/fail/skip result, status,
   phase, subreason, candidate/context states, cleanup sequence, diagnostics,
   and sentinel state.
3. T1A's prose also requires catalog-integrity mutations (duplicate/missing
   local ID, duplicate/missing semantic key, changed mapping, divergent
   expected fields, missing classification, and missing rationale), but those
   fixtures have no stable IDs/rows.
4. PS P1A has a related 96-ID table but no durable semantic-key column and
   groups several behaviors that Terraform already splits. Shared semantic
   identity must therefore be established by behavior, not by matching local
   ordinals.
5. Both issues already prohibit grouped ranges as final oracles and require
   one result for every ID/runtime pair.

Resolution consequence:

- the issue remains the normative source; implementation metadata must be an
  exact transcription, never the source of policy;
- each row names one closed oracle profile plus exact row-specific phase,
  subreason, fixture, and any permitted profile overrides;
- the issue defines each profile as a complete expansion of every result
  field, making omitted fields mechanically resolvable without blanket prose;
- every semantic key describes the behavior (for example
  `cleanup.candidate.repeat-disposed`) and shared P/T behaviors use identical
  keys even when local IDs differ;
- grouped P rows must split in reciprocal evidence or become blockers; and
- catalog-integrity behaviors receive their own append-only `T1A-I-*` rows and
  are themselves included in inventory/result reconciliation.

## T1A tracked-script proof — commit, index, and worktree identity

Primary sources:

- [`git ls-files`](https://git-scm.com/docs/git-ls-files)
- [`git ls-tree`](https://git-scm.com/docs/git-ls-tree)
- [`git hash-object`](https://git-scm.com/docs/git-hash-object)
- [`git rev-parse`](https://git-scm.com/docs/git-rev-parse)
- [Git global literal-pathspec behavior](https://git-scm.com/docs/git)

Retained facts:

1. `git ls-files --cached --stage` reports the index mode, object ID, stage,
   and path. With `-z`, the path is emitted verbatim and the record is
   NUL-terminated. `--error-unmatch` returns status 1 when a supplied path is
   absent from the index.
2. `git ls-tree --full-tree -z <tree-ish> -- <path>` reports
   `<mode> <type> <object><TAB><path><NUL>` from a committed tree. Its path
   argument is normally a path pattern, so literal-pathspec mode is needed even
   when `--` already terminates options.
3. `git hash-object --no-filters -- <file>` computes the blob object ID from
   the worktree bytes as-is, explicitly ignoring attributes-based filters and
   end-of-line conversion. Without `-w`, it does not write the object.
4. `git rev-parse --verify HEAD^{commit}` proves HEAD resolves to a commit;
   `--is-inside-work-tree` and `--show-prefix` can prove a precomputed
   directory is the repository root without trusting/parsing a potentially
   hostile returned path.
5. `--literal-pathspecs` (or its equivalent environment setting) makes every
   pathspec literal rather than wildcard/magic-driven.

Resolution consequence:

- derive the candidate repository root from the tracked harness's fixed
  `$PSScriptRoot` location and verify Git is at that root;
- normalize provider-qualified and native caller paths first, compare them to
  the two fixed absolute role paths, then map the role to a fixed canonical
  repository path; never convert caller spelling into a Git pathspec;
- invoke Git without a shell, capture raw stdout bytes and native status, use
  literal pathspecs and `-z`, and parse exact cardinality/format;
- require the HEAD tree entry, stage-0 index entry, and no-filter worktree blob
  all to have the same full object ID and ordinary-file mode; and
- test missing/untracked, wrong role/path, staged replacement, unstaged byte
  change, conflict stages, malformed/truncated/duplicate raw records, path
  metacharacters, statuses 0/1/2, and process-start failure in disposable
  repositories before either supplied script is invoked.

## T1A candidate cleanup — disposed-state identity

Repository sources reviewed:

- `docs/planning/TerraformStyleGuide/03aTerraformStyleGuideT1A.md`, public
  candidate cleanup contract, requested change 9, case `T1A-K-03`, and the
  caller-context v1 lifecycle.

Retained facts:

1. The caller context has a mutable identity/schema and explicit
   `Active → CleanupInProgress → Disposed|RetainedUncertain` lifecycle.
2. Candidate cleanup instead accepts an envelope, an ordered path ownership
   journal, and a primary failure. After a successful removal, that tuple
   carries no durable fact that its destructive authority was consumed.
3. `T1A-K-03` promises repeated cleanup is a success/no-op but only states “no
   unrelated deletion.” It does not say what happens if any file, directory,
   live/dangling link, or unreadable entry has since occupied the old candidate
   leaf.
4. Path absence alone cannot distinguish an initial not-yet-created candidate
   from a previously disposed candidate when an old nonempty journal is passed.
   A caller flag or cleared journal can be lost/copied and does not make the
   public destructive API self-describing.

Resolution consequence:

- candidate ownership receives its own closed v1 lifecycle object and unique
  `CandidateId`; the cleanup API no longer accepts a loose envelope/journal;
- successful cleanup consumes destructive authority by mutating the same
  object to `Disposed` and clearing every entry's `Owned` flag while retaining
  audit identities;
- entry with `Disposed` performs only envelope/leaf-absence inspection: absent
  is success/no-op, while any reappeared or unclassifiable entry becomes a
  retained-state failure with zero deletion;
- `CleanupInProgress`, `RetainedUncertain`, forged/unknown schema, ID/path/
  journal mutation, and a loose old journal all fail with zero deletion; and
- cases cover absent repeat plus ordinary file, directory, live link, dangling
  link, and unreadable/reparse reoccupation after disposal on each applicable
  OS family.

## T1B reusable-workflow graph — caller and called jobs

Primary sources:

- [GitHub reusable workflow reference](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations)
- [GitHub reusable-workflow concepts](https://docs.github.com/en/actions/concepts/workflows-and-actions/reusing-workflow-configurations)
- [GitHub contexts reference](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts)

Retained facts:

1. A reusable workflow is called directly in a caller job, not from a step,
   and the caller job has a restricted keyword set. It cannot also contain
   ordinary `runs-on`/`steps` work.
2. A called reusable workflow can contain one or more ordinary jobs. Each such
   job and step is logged separately and executes as part of the caller run.
   A one-line caller can therefore expand to an unbounded authority/side-effect
   surface unless the called file is also closed.
3. The caller job may set permissions; a called/nested workflow can maintain
   or reduce those token permissions but cannot elevate them. Omitting caller
   permissions allows defaults to flow, so both levels should author exact
   values.
4. A same-repository local workflow reference resolves from the same commit as
   the caller. This binds file identity but does not validate the called file's
   internal job set.
5. Called workflow jobs can define results/outputs that map through
   `workflow_call`; a complete graph must therefore close internal jobs,
   outputs, direct needs, permissions, conditions, runners, actions/steps, and
   further reusable calls.

Resolution consequence:

- keep the `build.yml` caller job `markdown`, but enumerate
  `markdownlint.yml`'s sole internal job `markdownlint`;
- require the caller's exact local `uses`, `contents: read`, no inputs/secrets/
  outputs/strategy/concurrency, and no unsupported caller-job keys;
- require the called workflow's exact empty input/secret/output interface and
  one read-only Ubuntu job with no needs/condition/outputs or nested workflow;
- validate both authored declarations and their expansion, with five caller
  job nodes, one called internal job declaration, six total static job
  declarations, a four-instance Windows matrix, nine expanded graph result
  nodes including the reusable caller, and seven/eight runner-executing jobs
  when the writer is skipped/runs; and
- reject any extra called job even when it uses no external action.

## T2 provider identifiers — closed public environment map

Repository source reviewed:

- `docs/planning/TerraformStyleGuide/04TerraformStyleGuideT2.md`, the four
  provider sections and normative provider-field grammar.

Retained facts:

1. The shown AWS block hard-codes bucket/key and names only generic
   `VERSION_ID`; Azure hard-codes account/container/blob and names only
   `AZURE_VERSION_ID`; GCS hard-codes bucket/object and names only
   `GCS_GENERATION`.
2. The later normative grammar table names the missing field concepts but not
   their public variables. It also promises every accepted byte is passed to
   the provider unchanged.
3. HCP names `TFC_HOST`, `TFC_PAGE_NUMBER`, `TFC_TOKEN`, and response paths but
   leaves the organization/workspace variable names implicit.
4. Calling the hard-coded blocks “final” and later saying a normative table
   supersedes them creates two apparent contracts. A copy-safe guide needs one
   executable block per marker with all runtime inputs visible at its first
   boundary.

Resolution consequence:

- use exact environment inputs `AWS_S3_BUCKET`, `AWS_S3_KEY`,
  `AWS_S3_VERSION_ID`; `AZURE_STORAGE_ACCOUNT`,
  `AZURE_STORAGE_CONTAINER`, `AZURE_STORAGE_BLOB`,
  `AZURE_STORAGE_VERSION_ID`; `GCS_BUCKET`, `GCS_OBJECT`,
  `GCS_GENERATION`; and `TFC_HOST`, `TFC_ORGANIZATION`, `TFC_WORKSPACE`,
  `TFC_PAGE_NUMBER`, `TFC_TOKEN` plus the existing protected response paths;
- discovery validates and uses the provider location fields; recovery
  validates the same location fields plus the deliberately selected version/
  generation;
- snapshot every environment value once into a provider-prefixed readonly
  local, never reread ambient state, validate before composing query/URI/argv,
  and pass accepted bytes unchanged in quoted argument arrays; and
- replace the contradictory shorter snippets with one final block per marker
  and one preceding copy-ready input table/export example using obvious
  nonsecret placeholders.

## T1-01 and T1B-01 — GitHub Actions checkout/token lifecycle

### Pinned `actions/checkout` metadata and source

Reviewed commit:
`actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1`
(`v7.0.1` in the current issue slate).

Sources:

- [`action.yml`](https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/action.yml)
- [`src/input-helper.ts`](https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/src/input-helper.ts)
- [`src/git-source-provider.ts`](https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/src/git-source-provider.ts)
- [`src/git-auth-helper.ts`](https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/src/git-auth-helper.ts)

Retained facts:

1. `action.yml` lines 11–21 define `token` as the credential used to fetch the
   repository and default it to `${{ github.token }}`.
2. `action.yml` lines 47–49 define `persist-credentials` as controlling whether
   the token or SSH key remains configured in local Git config; its action
   default is `true`.
3. `input-helper.ts` line 145 reads `token` with
   `core.getInput('token', {required: true})`. An explicit empty token is not a
   supported way to make this checkout credential-free.
4. `git-source-provider.ts` lines 136–139 call `configureAuth()` before the
   fetch at lines 160–212.
5. When `persist-credentials` is false, the `finally` block at lines 291–300
   removes authentication after checkout work. It does not retroactively make
   fetch unauthenticated.
6. The REST fallback also receives `settings.authToken` at lines 70–93.

Conclusion: `persist-credentials: false` is an important post-checkout
containment control, but “checkout without credentials” and “the token exists
only at the push step” are false for this action/configuration.

### GitHub job-token availability and least privilege

Sources:

- [Use `GITHUB_TOKEN` for authentication in workflows](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token)
- [`GITHUB_TOKEN` concept](https://docs.github.com/en/actions/concepts/security/github_token)
- [Contexts reference](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts)
- [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)

Retained facts:

1. GitHub creates a unique `GITHUB_TOKEN` before each job begins; it expires
   when the job ends or reaches the applicable maximum lifetime.
2. `github.token` is available within execution steps.
3. GitHub explicitly warns that an action can access `github.token` even when
   the workflow does not pass `GITHUB_TOKEN` as an explicit action input.
4. GitHub's recommended control is therefore least-privilege job/workflow
   permissions, combined with careful action selection—not a claim that the
   token object is absent from all non-push steps.

Resolution consequence:

- distinguish token creation/availability at job scope from explicit expansion
  into an action input or step environment;
- explicitly pass each security-relevant action `token` input and set
  checkout's `persist-credentials: false`, so the reviewed YAML and policy
  validator have no hidden action-default dependency; the T1-06 audit found
  that pinned `setup-node` also defaults its distribution-download `token` to
  `github.token`, so its selected explicit value must also appear in the
  normative role table;
- restrict permissions per job and allow only reviewed actions/code in a
  write-capable job;
- state that checkout uses transient authentication for fetch and removes its
  Git configuration afterward; and
- reserve explicit push environment/header construction for the exact guarded
  push step without claiming the job token did not otherwise exist.

## T1-02 — PowerShell destination-path boundary

Sources:

- [`PathIntrinsics.GetUnresolvedProviderPathFromPSPath`](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.pathintrinsics.getunresolvedproviderpathfrompspath)
- [`WildcardPattern.ContainsWildcardCharacters`](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.wildcardpattern.containswildcardcharacters)
- [`Path.GetFullPath`](https://learn.microsoft.com/en-us/dotnet/api/system.io.path.getfullpath)
- [PowerShell path syntax](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_path_syntax)

Retained facts:

1. `GetUnresolvedProviderPathFromPSPath` returns one provider-internal string.
   It intentionally does not resolve wildcard characters. The overload with
   `ProviderInfo` and `PSDriveInfo` out parameters lets a caller prove that the
   selected provider is `FileSystem`.
2. The API accepts relative paths and provider-qualified paths. Therefore,
   merely calling it does not enforce a fully qualified, native-filesystem-only
   public grammar.
3. `WildcardPattern.ContainsWildcardCharacters` supports Windows PowerShell
   5.1 and PowerShell 7 and detects PowerShell's `*`, `?`, and `[` wildcard
   grammar.
4. `Path.GetFullPath(String)` depends on the current directory when its input is
   relative. A deterministic contract must reject relative input before this
   call or use a predetermined fully qualified base.
5. `GetUnresolvedProviderPathFromPSPath` does not produce multiple matches.
   Once wildcards are rejected, “multiple resolution” is not an applicable
   state for this API. The issue should prohibit a later switch to a resolving
   API rather than promise to count results that cannot occur here.

Repository-specific design consequence:

- compute the repository root from the generator's trusted `$PSScriptRoot`,
  not the caller's current directory;
- derive the four exact allowed destination paths from that root;
- require a nonempty, wildcard-free, fully qualified native filesystem input;
- use the out-parameter overload and require the `FileSystem` provider;
- normalize once and compare with the exact four-path allowlist using ordinal
  ignore-case on Windows and ordinal on Linux; and
- route all four payloads through one private helper so validation, newline
  normalization, encoding, failure handling, and write mechanics cannot drift.

## T1-03 — Parseable script-version convention

Primary source:

- [PSStyleGuide — Function and Script Versioning](https://github.com/franklesniak/PSStyleGuide/blob/main/STYLE_GUIDE.md#function-and-script-versioning)

Retained observable convention:

1. A script's comment-based-help `.NOTES` contains one line in the form
   `Version: Major.Minor.Build.Revision`.
2. The four numeric components are compatible with `[System.Version]`.
3. `Build` is the UTC modification date in `YYYYMMDD`.
4. `Major` changes for a breaking interface change; `Minor` changes for a
   non-breaking feature/capability change.
5. `Revision` is `0` when `Major`, `Minor`, or `Build` differs from the
   previously published version, and otherwise is the prior published
   revision plus one for another same-day published update.
6. A new script with no previously published version begins at
   `1.0.<implementation-UTC-YYYYMMDD>.0`.

TerraformStyleGuide baseline:

- `Generate-StyleGuideArtifacts.ps1` has a script-level `.NOTES` section but no
  version field.
- No repository-local parser or alternate script-version convention exists.
- T1A and T1B nevertheless refer to exact expected script versions.

Resolution consequence:

- adopt the same **observable** field and calculation rules directly in the
  Terraform issue text, so TerraformStyleGuide remains self-contained;
- treat the T1 generator as a new versioned script and assign
  `1.0.<actual implementation UTC date>.0`;
- parse exactly one field from the script-level `.NOTES`, validate the date as
  a real calendar date and the whole value as `[System.Version]`, and reject a
  missing, duplicate, malformed, stale, or unexpected field; and
- use both the parsed version and exact prerequisite merge commit in T1A/T1B.
  A version is human change metadata; a commit is immutable source identity.

## T1-04 — Transactional artifact replacement

Sources:

- [`File.Replace`](https://learn.microsoft.com/en-us/dotnet/api/system.io.file.replace)
- [`FileStream.Flush(Boolean)`](https://learn.microsoft.com/en-us/dotnet/api/system.io.filestream.flush)
- [.NET 6 Unix `File.Replace` exception alignment](https://learn.microsoft.com/en-us/dotnet/core/compatibility/core-libraries/6.0/file-replace-exceptions-on-unix)

Retained facts:

1. `File.Replace` replaces one existing destination with one source file,
   deletes the source, and optionally creates a backup. The source and
   destination can be placed in the same existing directory.
2. The API is present in .NET Framework used by Windows PowerShell 5.1 and in
   modern cross-platform .NET used by PowerShell 7. Microsoft's .NET 6
   compatibility note specifically documents its Unix behavior.
3. `FileStream.Flush(true)` is available in .NET Framework 4.0+ and modern .NET
   and flushes managed and intermediate file buffers.
4. T1's four generated destinations are tracked, pre-existing ordinary files.
   T1 can deliberately require that invariant rather than adding an
   absent-destination publication branch.

Selected transaction boundary for later issue editing:

1. create an unpredictable same-directory temporary file with
   `FileMode.CreateNew`, `FileAccess.Write`, and `FileShare.None`;
2. write the already encoded complete payload, flush to disk, and close;
3. verify the closed temporary file's length/hash;
4. call `File.Replace(temp, destination, $null)` as the sole commit point; and
5. delete a still-existing temporary file in `finally`.

The guarantee is process/filesystem scoped: before the commit point, any
failure leaves the destination byte-identical; a failed replacement must leave
the old destination and report failure; a successful replacement is success
and no later fallible validation may relabel it as a pre-commit failure.
Power-loss guarantees beyond the filesystem/API contract are not claimed.

## T1-05 — Reproducible semantic workflow validation

Current package evidence collected 2026-07-29:

- the existing lockfile happens to contain transitive `js-yaml@4.1.1` through
  `markdownlint-cli2`;
- it is not a direct dependency and no tracked workflow-policy validator exists;
- the current issue freezes `package.json`/`package-lock.json`, while T1B plans
  to add a permanent direct parser later.

Primary sources:

- [`yaml` package documentation](https://eemeli.org/yaml/)
- [`yaml@2.9.0` npm package](https://www.npmjs.com/package/yaml)

Retained facts for `yaml@2.9.0`:

1. The package has no runtime dependencies and requires Node `>=14.6`.
2. It supports `parseDocument`, exposes parse `errors` and `warnings`, checks
   unique keys by default, and supports strict YAML 1.2 parsing.
3. `schema: 'core'` selects the YAML 1.2 core schema.
4. `stringKeys: true` rejects non-string mapping keys.
5. `maxAliasCount: 0` on conversion disallows aliases. The validator should
   also walk the parsed node tree and reject alias/anchor/custom-tag/directive
   syntax before conversion, rather than rely on expansion limits alone.
6. The package version observed from the registry is `2.9.0`; its published
   integrity is
   `sha512-2AvhNX3mb8zd6Zy7INTtSpl1F15HW6Wnqj0srWlkKLcpYl/gMIMJiyuGq2KeI2YFxUPjdlB+3Lc10seMLtL4cA==`.

Design consequence:

- the policy owner and enforcement should merge together. T1 should add the
  exact direct parser, lockfile entry, tracked
  `Validate-WorkflowPolicy.mjs`, and fixtures when it first pins/allowlists
  actions;
- ordinary validation runs after `npm ci` and is offline;
- T1B extends the same validator and normative role table rather than creating
  a new enforcement mechanism later; and
- parser/version/action policy changes occur atomically and are reviewed like
  executable security policy.

## T1-06 and T1B-02/T1B-05 — Exact action inputs and Git path/status gates

Primary sources:

- [Pinned `actions/setup-node` metadata](https://raw.githubusercontent.com/actions/setup-node/820762786026740c76f36085b0efc47a31fe5020/action.yml)
- [Pinned `actions/upload-artifact` metadata](https://raw.githubusercontent.com/actions/upload-artifact/043fb46d1a93c77aae656e7c1c64a875d1fc6a0a/action.yml)
- [Git `status` documentation](https://git-scm.com/docs/git-status)
- [Git `diff` documentation](https://git-scm.com/docs/git-diff)

Retained action facts:

1. `setup-node` accepts both `node-version` and `node-version-file`;
   `check-latest` defaults false; its `token` default may resolve
   `github.token`; and `package-manager-cache` defaults true. A role that
   promises exact Node 24, no cache, and a reviewed token boundary must declare
   the relevant keys rather than rely on these defaults.
2. `upload-artifact` requires `path`, but defaults `name` to `artifact`,
   `if-no-files-found` to warning, `overwrite` to false,
   `include-hidden-files` to false, `compression-level` to 6, and `archive` to
   true. Exact immutable-candidate or failure-diagnostic roles need explicit
   names, paths, missing-file behavior, retention, overwrite, hidden-file,
   compression/archive choices as applicable.

Retained Git facts:

1. `git status --porcelain=v1 -z` is stable for scripts and terminates entries
   with NUL rather than newline.
2. `git diff --name-only -z` emits unmodified path bytes terminated by NUL;
   without `-z`, unusual pathnames are quoted/escaped.
3. `git diff --exit-code` returns `0` for no differences and `1` for
   differences. Other statuses are execution failures and must not be treated
   as the expected-difference state.

Additional T1B action source:

- [Pinned `actions/download-artifact` metadata](https://raw.githubusercontent.com/actions/download-artifact/3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c/action.yml)

Retained download facts:

1. If neither `artifact-ids` nor `name` is supplied, the action downloads all
   artifacts; exact consumers must explicitly provide `artifact-ids`.
2. `path` defaults to the workspace and supports tilde expansion; a protected
   invocation directory must be explicit.
3. `pattern` and `merge-multiple` enable multi-artifact selection/merging and
   must remain absent for the one-ID contract.
4. `repository` and `run-id` have context defaults and cross-run/repository
   behavior is activated with `github-token`; same-run consumers should keep
   those cross-boundary inputs absent.
5. `skip-decompress` defaults false, so the immutable ZIP/same-stream helper
   design requires explicit literal true.
6. `digest-mismatch` defaults error, but should be explicitly declared as
   `error` because it is a security-relevant failure policy.

Design consequence:

- one normative role table must define exact job, step, action/local target,
  condition, permissions, explicit input-key set, explicit values, and
  separately reviewed omitted defaults;
- the tracked validator compares the actual structure with that table rather
  than deriving expectations from observed YAML; and
- every affected-file/path equality gate parses NUL-delimited bytes and every
  native result captures `$LASTEXITCODE` immediately and classifies all
  permitted statuses.

## T1A-01 — PowerShell 5.1-compatible raw parameter grammar

Primary sources:

- [PowerShell advanced parameter validation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters)
- [`ValidateNotNullOrWhiteSpaceAttribute`](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.validatenotnullorwhitespaceattribute)
- [`ValidateScript` attribute](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/validatescript-attribute-declaration)

Retained facts:

1. Validation attributes run during parameter binding before the function body.
2. `ValidateNotNullOrWhiteSpace` expresses the desired null/empty/whitespace
   rule, but the documented class is from modern System.Management.Automation
   and is not a Windows PowerShell 5.1 common-denominator attribute.
3. `ValidateScript` is available, but a reusable script block in a parameter
   attribute is a poor place for ordered multi-phase filesystem/provider checks
   and stable case-specific diagnostics.
4. Strong `[string]` binding can convert caller values before the function can
   classify their original type/value. A mandatory `[object]` boundary followed
   immediately by exact scalar-string validation can distinguish null,
   non-string, empty, whitespace-only, wildcard/provider/path grammar, and
   malformed conversion states in both editions.

Design consequence:

- define one ordered raw path grammar for every public T1A path parameter;
- accept only an exact scalar `System.String`, then reject null, empty,
  whitespace-only, NUL/control, wildcard, relative/non-fully-qualified, and
  unsupported provider forms before filesystem work;
- retain the deliberate positive grammar for native fully qualified paths and
  `FileSystem::`-qualified absolute paths;
- use the same semantic resolver in each self-contained production script and
  the harness, with cross-script conformance fixtures rather than a shared
  cross-repository runtime; and
- assign stable status/phase/resource postconditions to every grammar case.

## T1B-03 — Disposable-branch writer proof

Primary sources:

- [GitHub Actions workflows](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows)
- [Events that trigger workflows — `push`](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#push)
- [Events that trigger workflows — `workflow_dispatch`](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch)
- [`GITHUB_TOKEN` event behavior](https://docs.github.com/en/actions/concepts/security/github_token#when-github_token-triggers-workflow-runs)

Retained facts:

1. GitHub finds workflow files in the commit SHA or Git ref associated with an
   event, and a workflow run uses the workflow version at that SHA/ref.
2. A `push` event runs workflows that have not been merged to the default
   branch and can be restricted to one literal branch through
   `on.push.branches`.
3. `workflow_dispatch` is unsuitable for introducing a temporary proof
   workflow solely on a disposable branch because the workflow must already
   exist on the default branch to receive that event.
4. A code push performed with the repository's `GITHUB_TOKEN` does not create
   another workflow run. A successful evidence writer can therefore advance
   the disposable ref without recursively invoking itself.

Selected proof consequence:

- create one unpredictable, fully recorded branch under
  `refs/heads/t1b-evidence/`, starting at the exact reviewed implementation
  commit;
- commit an evidence-only variant to that branch whose allowed delta manifest
  changes every production `main` trigger/approval/writer/target-policy literal
  to that one exact evidence ref, adds bounded test instrumentation and one
  source-guide fixture that guarantees a generated change, and changes no
  permissions, role, action pin/input, identity, candidate, staging, commit,
  credential, lease, or refspec rule;
- use `push`, not `workflow_dispatch`, so GitHub executes that branch-local
  workflow without putting a temporary dispatch surface on the default branch;
- require the real writer to update the exact evidence ref by one commit with
  the expected parent and only the four generated artifact changes;
- use evidence-only, hard-coded scenario commits for controlled negative
  drills, never a free-form runtime ref or command input;
- retain the implementation base commit, evidence commits, run IDs/URLs,
  target-ref observations, allowed-delta diff, and cleanup proof; and
- delete the remote evidence ref after the drills, prove it is absent, and
  prove the merge candidate is descended from the reviewed implementation base
  but contains none of the evidence-only commits, event/ref literals,
  instrumentation, fixtures, or policy allowances.

The evidence branch is deliberately outside the production branch-protection
boundary. If repository/environment rules must be adjusted to allow its writer,
record the exact before-state, apply only the evidence-ref-scoped temporary
change, restore the exact before-state in `finally`, and treat failed
restoration as a release blocker.

## T2-01 — Bash signal and `EXIT` cleanup semantics

Primary sources:

- [GNU Bash Reference Manual — Signals](https://www.gnu.org/software/bash/manual/html_node/Signals)
- [GNU Bash Reference Manual — Bourne Shell Builtins (`trap`)](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins)
- [POSIX shell command language — exit status and signals](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html)

Retained facts:

1. A trapped signal does not make `$?` inside its trap a portable
   `128 + signal-number` oracle. In particular, a signal can arrive after a
   successful shell operation and the trap body can observe `0`.
2. Bash reports a simple command terminated by signal `n` as `128+n`; POSIX
   requires a signal-terminated command status greater than 128 but does not
   standardize that exact arithmetic for every shell.
3. Bash runs an `EXIT` trap before the shell terminates. An explicit
   signal-specific handler can therefore call `exit` with a chosen nonzero
   value and let one `EXIT` handler own cleanup.
4. A trapped signal received while Bash waits for a foreground command may be
   handled only after that command completes; while Bash waits through the
   `wait` builtin, a trapped signal makes `wait` return greater than 128 before
   the trap runs. Tests need a deterministic stub/ready marker rather than
   assuming the trap executes at an arbitrary instruction immediately.

Selected consequence:

- install `cleanup_recovery` only for `EXIT`;
- install separate HUP/INT/TERM handlers which first ignore all three handled
  signals, then `exit 129`, `exit 130`, or `exit 143`;
- have the `EXIT` handler capture the supplied status before any command,
  disable its own trap, keep handled signals ignored during cleanup, perform
  cleanup exactly once, and preserve a nonzero primary status even when cleanup
  also fails;
- if the primary status is zero but cleanup fails, return one specified
  cleanup-failure status rather than success; and
- exercise every provider/signal at a harness synchronization point after the
  private root/partial exists, including an induced cleanup failure.

## Finding 13 — destination-leaf bytes and cleanup under `errexit`

Primary sources:

- [GNU Bash, `set` builtin](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html)
- [GNU Bash, Bourne shell builtins (`trap`)](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html)
- [GNU Bash, conditional constructs](https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html)
- [GNU coreutils, `rm`](https://www.gnu.org/software/coreutils/manual/html_node/rm-invocation.html)
- [GNU coreutils, `rmdir`](https://www.gnu.org/software/coreutils/manual/html_node/rmdir-invocation.html)

Findings retained for the issue rewrite:

1. Bash `-e` exits on an unhandled failing simple command, pipeline, list, or
   compound command, subject to documented conditional-context exceptions. An
   `EXIT` trap is not an automatic exception. The repository probe recorded in
   `current-findings.md` demonstrated the consequence directly: with `set -e`,
   a failing command in the `EXIT` trap stopped the remainder of cleanup and
   changed the process status to `1`.
2. The cleanup function must capture `$?` as its first expansion and run
   `set +e` before any fallible cleanup operation. It also disables `nounset`
   after capture and uses `${name-}` when reading state so an incomplete
   initialization cannot abort cleanup.
3. `if command; then ... else ... fi` and immediate explicit status capture
   make each fallible operation an enumerated branch. The selected algorithm
   applies that treatment to trap changes, diagnostic writes, directory
   enumeration, `wait`, unlink, and `rmdir`; no cleanup command is permitted as
   an unclassified bare command.
4. `rm -- "$exact_file"` is reserved for an exact owned ordinary file.
   Recursive removal is prohibited. `rmdir -- "$exact_root"` is the only
   directory removal operation, so a nonempty or uncertain root is retained.
5. Public recovery destinations use a repository-defined path-leaf grammar
   independent of AWS, Azure, GCS, or HCP Terraform identifier grammars: under
   `LC_ALL=C`, 1–128 bytes matching
   `[A-Za-z0-9][A-Za-z0-9._-]{0,127}`. This excludes separators, leading
   option-like `-`, dot-only components, whitespace, control bytes, newlines,
   and locale-dependent characters.
6. Unvalidated path text is never interpolated into diagnostics. Paths that
   must be reported are first rendered with Bash
   `printf -v rendered '%q' -- "$value"` under `LC_ALL=C`; diagnostic failure
   is itself recorded without replacing a pre-existing nonzero primary status.
7. Directory enumeration uses a waited producer, not unchecked glob expansion
   or a process substitution whose exit status is discarded. The contract
   opens a dynamic file descriptor from
   `find -- "$root" -mindepth 1 -maxdepth 1 -print0`, captures the producer PID,
   reads NUL-delimited entries, closes the descriptor, and classifies
   `wait "$producer_pid"`. An enumeration failure permits no deletion.
8. Final status precedence is closed: a nonzero primary status wins; otherwise
   any cleanup inspection, diagnostic, unlink, or `rmdir` failure produces
   cleanup status `1`; otherwise the result is `0`.

## Finding 14 — atomic provider lifecycle oracles

This finding is resolved from the issue's own executable contract; it does not
require an additional external source.

Retained local facts:

1. `AWS-PART-06`, `AZURE-PART-06`, and `GCS-PART-06` each currently combine
   two different initial states: a final that exists before preflight and a
   final that appears between preflight and no-replace publication.
2. The preexisting-final path exits before `mktemp` and before provider
   invocation. Its exact provider call count is zero, and there is no private
   recovery root to clean or retain.
3. The publication-race path has already invoked the provider, created and
   validated a private temporary state, and attempted `ln
   --no-target-directory`. The competing final remains unchanged and the
   validated private temporary/root is retained because publication identity
   is uncertain.
4. The existing IDs are declared append-only. The least disruptive closed
   allocation narrows each `*-PART-06` row to the preexisting-final case and
   appends a `*-PART-07` publication-race row.
5. The race fixture must be deterministic. A harness-owned `ln` wrapper creates
   the competing final immediately before delegating the exact no-replace call
   to the real GNU `ln`; it logs NUL-safe argv and confirms the real call
   refuses replacement.

## Finding 15 — POSIX state-file identity across publication

Primary sources:

- [GNU coreutils, `stat`](https://www.gnu.org/software/coreutils/manual/html_node/stat-invocation.html)
- [GNU coreutils, `ln`](https://www.gnu.org/software/coreutils/manual/html_node/ln-invocation.html)
- [GNU coreutils, `chmod`](https://www.gnu.org/software/coreutils/manual/html_node/chmod-invocation.html)

Findings retained for the issue rewrite:

1. `umask 077` constrains the permission bits requested at creation; it does not
   prove the provider preserved a file created by the shell, created the file
   with mode `0600`, or did not substitute an inode that already has another
   hard link.
2. GNU `stat -c` exposes device (`%d`), inode (`%i`), owner UID (`%u`),
   permissions in octal (`%a`), hard-link count (`%h`), and size (`%s`). Under
   `LC_ALL=C`, one fixed numeric format can be parsed as an exact snapshot
   without logging path or state bytes.
3. A hard link gives two directory entries to one inode. The selected
   publication contract therefore requires the same `(device,inode)` at both
   temporary and final names, link count exactly `2` while both exist, and the
   original identity with link count exactly `1` after the temporary name is
   unlinked.
4. GNU `ln --no-target-directory -- temp final`, without force or backup,
   remains the single no-replace publication attempt. The identity checks
   validate its result; they do not add a fallback.
5. Publication eligibility and cleanup ownership are separate predicates.
   Publication requires ordinary non-link type, effective-UID ownership, mode
   `0600`, parent device, and link count `1`. A wrong-mode candidate that still
   has proven owner/device/single-link identity may be removed as an invalid
   owned partial; owner, device, link-count, or identity uncertainty retains the
   root.
6. HCP response acquisition has no hard-link publication. It records the
   response `(device,inode)` immediately after noclobber creation and requires
   effective-UID ownership, mode `0600`, parent device, and link count `1` both
   while acquired and after curl closes. Its established retention policy keeps
   the response on any curl/content/identity failure.

## Finding 16 — tracked Husky hook versus generated installation

Primary sources and package evidence:

- [Husky — Get started](https://typicode.github.io/husky/get-started.html)
- [Husky — How To](https://typicode.github.io/husky/how-to.html)
- [Husky — Troubleshoot](https://typicode.github.io/husky/troubleshoot.html)
- [Husky upstream repository](https://github.com/typicode/husky)
- Locally lock-resolved `husky@9.1.7` package files under
  `.github/workflows/node_modules/husky`, compared with
  `.github/workflows/package-lock.json`.

Retained facts:

1. Husky documents `.husky/pre-commit` as the user-maintained hook and
   `core.hooksPath=.husky/_` as the installed Git integration. The startup
   wrapper sources `${XDG_CONFIG_HOME:-$HOME/.config}/husky/init.sh` and honors
   `HUSKY=0`.
2. In this repository, only `.husky/pre-commit` is tracked. `.husky/_/.gitignore`
   contains `*`, and Git confirms `_` support files/shims are ignored generated
   state.
3. The lock-resolved package identity is `husky@9.1.7`, tarball integrity
   `sha512-5gs5ytaNjBrh5Ow3zrvdUUY+0VxIuWVL4i9irt6friV+BqdCfmV11CQTWMiBYWHbXhco+J1kHfTOUkePhCDvMA==`,
   with binary mapping `husky -> bin.js`. Upstream still exposes 9.1.7 as the
   latest released v9 identity at the research date.
4. The local package hashes needed to make invocation non-ambient are:
   `bin.js` SHA-256
   `c6965589a83667d43c4dc22f90dccfa91c133f8ed23629b896ce326f0a6c5cc8`;
   `index.js`
   `ccd8b0953cd9283575466a6b40d1afccdfeabb4a5ef4415b5be40d9c33a5cdbd`;
   and executable support file `husky`
   `70200b200ca709b0622784f93839a5b2872333a917a09afddefd7dc2d8cdc680`.
5. `husky@9.1.7` generates exactly three support files
   (`.gitignore`, `h`, `husky.sh`) and 14 hook-name shims:
   `applypatch-msg`, `commit-msg`, `post-applypatch`, `post-checkout`,
   `post-commit`, `post-merge`, `post-rewrite`, `pre-applypatch`,
   `pre-auto-gc`, `pre-commit`, `pre-merge-commit`, `pre-push`, `pre-rebase`,
   and `prepare-commit-msg`.
6. Every generated hook-name shim is exactly 39 bytes with SHA-256
   `34fe496008be71d8fdd446b2cce81e4bb0406109c130eafc583fbd9fe33244e2`.
   `.gitignore` is one byte `*`; `h` is 551 bytes and byte-equal to the package
   `husky` file; `husky.sh` is 160 bytes with SHA-256
   `21122903fca7209a13c991e5be68780636e28f1b8f0ae7ea07ed0065dfe37268`.
7. The selected invocation is the exact local CLI, not `npx`, PATH lookup, or
   an unpinned package-manager resolution: spawn `process.execPath` with the
   verified absolute `node_modules/husky/bin.js`, `cwd` equal to the verified
   repository root, `shell:false`, and no positional command. This is run by
   the `prepare` lifecycle of the exact Corepack-selected npm installation.

## Finding 17 — audit process envelope and strict report-v2 catalog

Primary sources:

- [Node.js `child_process`](https://nodejs.org/api/child_process.html)
- [Node.js `Buffer`](https://nodejs.org/api/buffer.html)
- [npm audit](https://docs.npmjs.com/cli/v11/commands/npm-audit/)
- [`npm@12.0.2` registry metadata](https://registry.npmjs.org/npm/12.0.2)

Retained facts and selected limits:

1. Node documents that a failed spawn emits `error`, that `exit` can precede
   stdio completion, and that `close` occurs after the process ends and stdio
   closes. A collector must listen for both error and close, reconcile them once,
   and drain both byte streams concurrently.
2. Node's ordinary UTF-8 `Buffer.toString()` replaces invalid bytes with U+FFFD.
   The audit reader must use raw `Buffer` input plus strict validation
   (`buffer.isUtf8` or a fatal `TextDecoder`) before tokenization.
3. Node's `maxBuffer` behavior terminates a child and truncates output. The
   selected orchestration instead uses `spawn`, retains only a bounded prefix,
   marks byte `limit+1` as overflow, and continues draining/discarding to EOF so
   the process lifecycle remains observable.
4. Exact retained limits are stdout `8,388,608` bytes and stderr `65,536`
   bytes. Overflow sentinels are the first rejected bytes, `8,388,609` and
   `65,537`; counters saturate at those sentinel values.
5. Production audit execution has an exact `120,000` ms deadline. On hosted
   Ubuntu it spawns a shell-free detached process group, sends `SIGTERM` to the
   group at the deadline, waits exactly `5,000` ms, then sends `SIGKILL` if any
   process remains. A delivery/close failure is process/tool failure. Windows
   exercises the pure outcome/validator cases but is not a second production
   process-tree implementation.
6. The structured outcome has one discriminated `exit`, `signal`, `timeout`, or
   `startFailure` state plus hashes/retained lengths/overflow flags for separate
   stdout and stderr. It contains no path, error message, or captured output.
   The validator receives the protected files as separate arguments and
   recomputes their identities.
7. Strict JSON tokenizer ceilings are: raw file `8,388,608` bytes; maximum
   nesting depth `64`; maximum total value tokens `250,000`; maximum raw bytes
   in one JSON string token `1,048,576`; and maximum raw bytes in one number
   token `64`. Duplicate object keys are rejected at tokenization before
   `JSON.parse`.
8. Decision precedence is exact: invalid/unverifiable process evidence or
   stderr overflow is `20 PROCESS_TOOL`; report raw/UTF-8/tokenizer failure or
   stdout overflow is `21 AUDIT_INPUT_JSON`; supported JSON with wrong
   report-v2 shape/graph is `22 AUDIT_REPORT_SCHEMA`; valid graph inconsistent
   with native exit is `23 AUDIT_STATUS_MISMATCH`; residual-set disagreement is
   `24 AUDIT_POLICY_MISMATCH`; and exception governance failure is
   `25 AUDIT_GOVERNANCE`.

## Finding 18 — durable, recomputable follow-up evidence

Primary sources are retained in `T3-06` above:

- GitHub canonical issue URL documentation;
- GitHub REST issue response shape, including the `pull_request` discriminator;
  and
- GitHub Actions/REST read-permission behavior.

Selected storage and verification consequences:

1. The bounded canonical evidence record is embedded in the optional tracked
   `npm-audit-exceptions.json`, under a top-level `followUpEvidence` array.
   Protected-branch review controls its integrity; its fields are deliberately
   safe for this public repository. Raw API responses, tokens, headers, email,
   and arbitrary issue body/title text are not stored.
2. Each exception finding references one embedded record by exact issue number,
   verified time, scope hash, and SHA-256. The validator canonicalizes the
   embedded record and recomputes the hash offline on every run.
3. Initial approval and every renewal use a tracked capture helper and one live
   verification session: authenticated `GET /user` identifies the verifier and
   `GET /repos/franklesniak/TerraformStyleGuide/issues/<number>` captures the
   issue. The helper rejects redirect, wrong repository/number, pull request,
   non-open state, missing responsible assignee, or scope-marker mismatch.
4. The canonical record stores safe identities/timestamps and SHA-256 values
   for title/body, not the title/body. It records the parsed scope marker,
   owner, and target date. Canonical JSON is a fixed property order with sorted
   identity arrays, UTF-8, no BOM, and no final newline; the evidence SHA-256 is
   over exactly those bytes.
5. `verifiedAt <= approvedAt <= verifiedAt + 3600 seconds`, and issue
   `updatedAt <= verifiedAt`. The overall exception remains exclusive-expiry
   bounded to 30 days; renewal performs a new live session and replaces the
   embedded record/hash along with substantive review.
6. Ordinary PR/push/schedule validation is offline and reports only that the
   tracked evidence record is internally valid and fresh enough for its
   approval. It does not claim the issue is still currently open. The live
   capture helper owns that assertion at approval/renewal.

## Finding 19 — backend identifier length arithmetic

This resolution is derived entirely from T4's literal grammar:

```text
backend-v1:<type>:<authority>:<scope>
```

Retained arithmetic:

- `backend-v1` is 10 ASCII bytes.
- The serialization contains exactly three colon bytes.
- Each of three components is 1–63 ASCII bytes.
- Minimum total is `10 + 3 + (3 × 1) = 16` bytes.
- Maximum total is `10 + 3 + (3 × 63) = 202` bytes.
- A 201-byte positive fixture uses component lengths `63,63,62`.
- A 202-byte positive fixture uses `63,63,63`.
- Any 203-byte value with the correct prefix/separator count necessarily has a
  component of at least 64 bytes and is rejected at the component-length phase.

## Finding 20 — byte-preserving controlling-terminal confirmation

Primary sources:

- [Node.js TTY](https://nodejs.org/api/tty.html)
- [Node.js file descriptors and `fs.open`](https://nodejs.org/api/fs.html)
- [Microsoft `ReadConsole`](https://learn.microsoft.com/en-us/windows/console/readconsole)
- [Microsoft console handles (`CONIN$`/`CONOUT$`)](https://learn.microsoft.com/en-us/windows/console/console-handles)

Retained facts and selected consequences:

1. Node exposes raw terminal input as `Buffer` data and provides
   `tty.ReadStream.setRawMode()`, which disables echo/canonical special
   processing and makes input available character by character.
2. A `tty.ReadStream` can be constructed from an already-open TTY descriptor.
   Production opens `/dev/tty` on POSIX and the Windows console devices
   `CONIN$`/`CONOUT$`, rather than trusting redirected stdin/stdout.
3. Windows console input is fundamentally a Unicode console API which the
   runtime converts to a byte stream; arbitrary malformed UTF-8 cannot be typed
   through that path. The pure byte-classifier fixtures still cover invalid
   UTF-8, NUL, BOM, CR/LF framing, and overflow independently of the live
   adapter.
4. The selected helper treats CR or LF generated by the Enter key as a framing
   terminator, not part of the ordinal confirmation payload. A CR/LF before the
   expected payload is complete produces mismatch; NUL or malformed UTF-8 in
   payload rejects. Any bytes already delivered after the first terminator are
   a second record and reject. Later terminal input is irrelevant because the
   helper closes the descriptor and destructive children receive no stdin.
5. Payload length is at most exactly 4,096 raw bytes. Byte 4,097 rejects before
   decoding. The expected serialized confirmation must itself be 1–4,096 bytes.
6. A tracked Node helper owns both canonical serialization and terminal input.
   It receives validated fields separately, constructs the exact array, and
   uses `JSON.stringify` on the newly constructed array. All string fields are
   prevalidated ASCII/safe grammar and serials are canonical nonnegative safe
   integers, making the compact BOM-less UTF-8 result deterministic.
7. The helper restores terminal mode and closes input/output descriptors in
   `finally` and in HUP/INT/TERM handlers. It never returns typed bytes through
   stdout/stderr, environment, a file, or evidence. A failure exits before the
   caller can start a destructive child.

## Finding 21 — T4 protected-parent inputs and T2 continuity

Primary sources:

- [Terraform state command backups](https://developer.hashicorp.com/terraform/cli/commands/state)
- [Terraform state push](https://developer.hashicorp.com/terraform/cli/commands/state/push)
- [Terraform state locking](https://developer.hashicorp.com/terraform/language/state/locking)

Retained facts and selected consequences:

1. HashiCorp documents that state-modifying subcommands write sensitive backup
   files and that their path is controlled by `-backup`; backups cannot be
   disabled. T4 must supply an exact protected fresh `-backup` destination for
   `state rm`, not allow a working-directory default to appear.
2. `state push PATH` consumes a caller-selected proposed state and the remote
   safety checks do not establish local path privacy/ownership. The proposed
   state needs its own explicit protected-parent tuple.
3. Every state pull used before or after mutation creates another sensitive
   local destination. The pre-mutation backup and post-mutation verification
   therefore each need their own explicit tuple, even when an operator chooses
   the same protected parent.
4. The T2 literal remains exactly
   `private-outside-vcs-no-competing-writers`. It is an operator assertion about
   facts the block cannot prove. POSIX owner/mode/type/canonicalization and
   Windows SID/DACL/reparse/volume checks are the machine-inspected subset.
5. A path is never allowed to imply the attestation. Each role accepts parent,
   direct-child path, and attestation separately, snapshots all three once, and
   rejects before state/provider/Terraform activity on any mismatch.

## Finding 22 — bounded state capture and streaming JSON metadata

Primary sources:

- [Terraform JSON output format](https://developer.hashicorp.com/terraform/internals/json-format)
- [Terraform state versions API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/state-versions)
- [Terraform state file version metadata](https://developer.hashicorp.com/terraform/tutorials/configuration-language/versions)
- [Node.js streams/backpressure](https://nodejs.org/api/stream.html)
- [Node.js child processes](https://nodejs.org/api/child_process.html)

Retained facts and selected consequences:

1. HashiCorp exposes state-version byte size but does not publish one universal
   maximum local state size that applies to every backend. The repository must
   choose an operational default and a reviewed bounded override rather than
   label a provider limit as universal.
2. Official examples show raw state metadata at the top level:
   `version`, `terraform_version`, `serial`, and `lineage`. Current raw state
   format is version `4`; a future raw-state major needs an explicit parser/
   issue update.
3. `terraform show -json` is a separate compatibility-oriented JSON
   representation whose `format_version` uses major/minor semantics. Major `1`
   is supported; unknown minor properties are ignored by semantic consumers
   after the strict JSON/token limits succeed.
4. Node stream documentation requires honoring writable backpressure and warns
   that unrestricted writes can grow memory without bound. The selected helper
   writes/counts raw chunks, waits for `drain`, and never buffers a whole state
   or show document.
5. Default limits are raw state 512 MiB (`536870912`), show JSON 2 GiB
   (`2147483648`), and one Terraform child 15 minutes (`900000` ms), with a
   5-second TERM-to-KILL grace. A reviewed large-state profile is still hard
   capped at raw 2 GiB, show JSON 8 GiB, and 60 minutes.
6. The streaming strict-JSON tokenizer uses maximum nesting 256, total values
   10,000,000, properties per object 100,000, items per array 2,000,000, one
   string token 16 MiB raw bytes, and one number token 128 raw bytes. It detects
   duplicate keys in every object before projecting only safe metadata.

## Finding 23 — inputs for a secret-safe state-difference helper

Primary sources:

- [Terraform JSON output format](https://developer.hashicorp.com/terraform/internals/json-format)
- [`terraform providers schema -json`](https://developer.hashicorp.com/terraform/cli/commands/providers/schema)
- [Terraform dependency lock file](https://developer.hashicorp.com/terraform/language/files/dependency-lock)

Retained facts and selected consequences:

1. HashiCorp's state representation from `terraform show -json` contains
   values, resource addresses/mode/type/name/index, `provider_name`,
   `schema_version`, and `sensitive_values`, but it is not a configuration
   representation.
2. Resource addresses in that output are documented as opaque values suitable
   for exact comparison. `provider_name` is only the provider name; it omits
   provider configuration module path and alias. A state-only helper cannot
   truthfully call those identities “known from reviewed configuration.”
3. `terraform providers schema -json` supplies provider, resource, and data
   source schemas for providers used throughout the configuration tree,
   including schema versions. It is a required separate bounded input.
4. `.terraform.lock.hcl` records provider selections/checksums and is intended
   for version control, but HashiCorp explicitly notes it does not lock remote
   module versions. The review manifest must separately identify configuration
   files and resolved module package trees.
5. The selected helper therefore consumes current/proposed raw state and show
   JSON, provider-schema JSON, exact configuration/lock/module identities, and
   a peer-reviewed safe identity/change manifest. It never infers configuration
   truth from state alone.
6. To compare large sensitive structures without retaining values, the helper
   uses a per-run random HMAC key held only in memory and protected temporary
   indexes keyed by reviewed manifest IDs. HMACs and indexes are deleted in
   `finally` and never enter the final report/evidence; dynamic/unreviewed keys
   collapse to a fixed rejection reason.

## Finding 24 — serial progression and a usable recovery path

Primary sources:

- [`terraform state push`](https://developer.hashicorp.com/terraform/cli/commands/state/push)
- [Terraform backend state storage and locking](https://developer.hashicorp.com/terraform/language/state/backends)
- [HCP Terraform state-version API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/state-versions)
- [Managing HCP Terraform workspace state](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/state)

Retained facts and selected consequences:

1. Terraform blocks a push when the destination has a *higher* serial, not
   when the serials are equal. Therefore an equal-serial candidate can overwrite
   different content and is not an acceptable progression rule for this guide.
2. Terraform describes serial as monotonically increasing. For a reviewed
   content-changing manual push, the selected repository rule is exactly
   `proposedSerial = currentSerial + 1` under one continuous, separately
   verified writer-exclusion interval. An equal/older/skipped/overflowing
   serial stops. Byte-identical input stops as a no-op rather than being pushed.
3. The backup taken immediately before a successful push has an older serial.
   Pushing it directly is consequently rejected by Terraform's retained
   higher-remote-serial safety check; `-force` would disable both serial and
   lineage protection and remains prohibited.
4. HCP Terraform's rollback endpoint duplicates the selected historical state
   as a new current state version, requires the workspace to be locked, and
   documents both permissions and conflict responses. This is the preferred
   model: use a reviewed backend-native version restore when the exact backend
   supports one.
5. For a backend without such a facility, the fallback is a new reviewed
   candidate, not the old file. A tracked helper copies the validated desired
   backup byte-for-byte while replacing only its unique top-level raw-state
   `serial` token with `freshRemoteSerial + 1`; it proves the original and
   candidate differ only at that token and emits no state value. The normal
   protected diff then reviews fresh remote content against that candidate.
6. The recovery is a second destructive operation with a fresh remote pull,
   incident/peer review, continuous writer exclusion, full input/diff
   validation, typed confirmation, unforced push, and post-push verification.
   Drift after review stops and restarts the procedure; it is never an
   automatic retry or automatic rollback.

## Finding 25 — hard-link publication does not exclude an existing writer

Primary sources:

- [GNU Coreutils `ln`](https://www.gnu.org/software/coreutils/manual/html_node/ln-invocation.html)
- [Linux `link(2)`](https://man7.org/linux/man-pages/man2/link.2.html)
- [Linux `open(2)`](https://man7.org/linux/man-pages/man2/open.2.html)
- [Linux `unlink(2)`](https://man7.org/linux/man-pages/man2/unlink.2.html)
- [POSIX file/link definitions](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html)
- [POSIX `sys/stat.h`](https://pubs.opengroup.org/onlinepubs/7908799/xsh/sysstat.h.html)

Retained facts and selected consequences:

1. A hard link is another directory entry for the same underlying file; changes
   made through either name affect that same file. GNU `ln` normally does not
   replace an existing destination, and `--no-target-directory` closes its
   directory-operand ambiguity.
2. Removing a pathname does not invalidate an open file description. If a
   process already has the inode open for writing, it can continue writing
   after either source unlink or rename. Therefore neither hard-link
   publication nor no-replace rename is a writer-exclusion primitive.
3. POSIX exposes device, inode, owner, mode, link count, and size. The selected
   workflow requires source link count `1`, both-name count `2` after link, and
   destination count `1` after exact source unlink, with the same device/inode,
   owner, mode, size, and digest at each applicable checkpoint.
4. Machine inspection cannot portably prove that every other process lacks a
   writable open description. The selected design adds a separate exact
   operator attestation that Terraform, automation, editors, recovery tools,
   and all other possible source writers are paused and hold no writable handle.
   This is an explicit premise, not an inference from lock-file absence,
   `lsof`, permissions, or the metadata checks.
5. Any mutation or identity uncertainty after the link is created retains all
   remaining names and reports them. Removing a “new” destination could remove
   the only trustworthy name after an unexpected source-side event.

## Finding 26 — stable case IDs must identify one result

Repository evidence reviewed:

- `06TerraformStyleGuideT4.md`, “Extend the permanent cross-platform
  harnesses”
- `04TerraformStyleGuideT2.md`, “Signal-specific exit and one cleanup owner”
- Findings 20, 24, and 25 in `current-findings-evaluation.md`

Retained facts and selected consequences:

1. Existing IDs are declared append-only, so the first subcase keeps each
   grouped ID and every additional subcase receives a new ID after that
   family's current maximum. No existing number is reused, renumbered, or
   made broader.
2. Confirmation byte classes belong to the shared tracked confirmation helper,
   not duplicated Bash/PowerShell lists. A new `SM-CONFIRM-*` family gives
   every serializer, terminal, malformed-byte, length-boundary, and signal case
   one literal ID/result across the applicable platform cells.
3. Bash signal cases need a closed product of marker, named ownership phase,
   HUP/INT/TERM, and cleanup success/failure. The ID encodes all four
   dimensions and every expansion must appear literally in machine-readable
   harness metadata; a loop may execute rows but cannot collapse their results.
4. Each row has one setup, one injection point, one expected status/reason, one
   cleanup count, one filesystem state, and one mutation/remote-call count.
   Disjunctive fixture or oracle text is rejected structurally before tests run.
5. Finding 27 owns the address grammar, but its empty, broad, exact integer,
   exact string/escaped-string, and malformed classes receive a separate
   append-only `SM-ADDRESS-*` family rather than being hidden under an rm row.

## Finding 27 — exact Terraform resource-address narrowing

Primary sources:

- [Terraform resource address reference](https://developer.hashicorp.com/terraform/cli/state/resource-addressing)
- [`terraform state list`](https://developer.hashicorp.com/terraform/cli/commands/state/list)
- [`terraform state rm`](https://developer.hashicorp.com/terraform/cli/commands/state/rm)
- [Terraform configuration identifier syntax](https://developer.hashicorp.com/terraform/language/syntax/configuration)
- [Terraform quoted-string syntax](https://developer.hashicorp.com/terraform/language/expressions/strings)

Retained facts and selected consequences:

1. HashiCorp defines a resource address as selecting zero or more instances.
   Module-only addresses select all resources below the module, and omitting an
   index from a `count`/`for_each` resource can select every instance.
2. `terraform state rm` accepts one or more addresses and removes every
   matching instance. `-dry-run` reports matches, but its prose is not a stable
   structured protocol and is not used as the count oracle.
3. `terraform state list ADDRESS` returns the canonical resource addresses
   matching the address pattern. A bounded result containing exactly
   `inputAddress + LF` proves both that Terraform parsed the input canonically
   and that the current state match set contains exactly one instance. A
   module-only, omitted multi-instance index, zero match, multiple match, or
   noncanonical spelling fails that equality.
4. Terraform identifiers support Unicode plus ASCII hyphen. The guide chooses
   a narrower ASCII identifier subset and a strict canonical quoted-key subset
   for predictable terminal/evidence handling; Terraform's exact match remains
   the semantic authority.
5. Integer indices and quoted string keys are both legitimate. The selected
   parser supports canonical nonnegative safe integers and canonical JSON/HCL-
   compatible quoted printable-ASCII keys, including necessary `\"` and `\\`
   escapes, instead of rejecting all quotes/backslashes with a shell regex.
6. The repeated `state list` check and `state rm -dry-run` run under the same
   pinned Terraform/config/workspace/backend and continuously held writer
   exclusion. The list output supplies the exact-match oracle; dry-run must
   succeed but its localized text is never parsed.

## T2-04 — Provider identifier grammars

Primary sources:

- [Amazon S3 general-purpose bucket naming rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html)
- [Amazon S3 object-key naming](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-keys.html)
- [Amazon S3 version IDs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/versioning-workflows.html#version-ids)
- [Azure storage-account overview](https://learn.microsoft.com/azure/storage/common/storage-account-overview#storage-account-name)
- [Azure container/blob naming](https://learn.microsoft.com/rest/api/storageservices/naming-and-referencing-containers--blobs--and-metadata)
- [Azure Blob versioning](https://learn.microsoft.com/azure/storage/blobs/versioning-overview#version-id)
- [Google Cloud Storage buckets](https://cloud.google.com/storage/docs/buckets#naming)
- [Google Cloud Storage objects](https://cloud.google.com/storage/docs/objects#naming)
- [HCP Terraform workspace API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/workspaces)

Retained facts:

1. S3 general-purpose bucket names have a detailed 3–63-character DNS-like
   grammar plus reserved prefixes/suffixes. S3 keys are case-sensitive UTF-8
   sequences up to 1,024 bytes and can legally contain characters—including
   controls—that are unsuitable for a copyable shell/log interface.
2. S3 version IDs are service-generated, opaque, URL-ready UTF-8 strings no
   longer than 1,024 bytes. The example value includes `+`; a validator must not
   assume an alphanumeric-only identifier or parse/normalize it.
3. Azure storage-account names are 3–24 lowercase alphanumeric characters.
   Containers are 3–63 lowercase alphanumeric/hyphen names with no consecutive
   hyphens and alphanumeric endpoints. Blob names can contain arbitrary
   characters and are 1–1,024 characters; Azure describes a blob version ID as
   an opaque `DateTime` value whose service value is a timestamp.
4. Cloud Storage permits broader bucket/object naming than the guide needs.
   Object names are Unicode, cannot contain literal CR/LF, and have additional
   tool-compatibility warnings for controls, `#`, and wildcard-like characters.
   The service assigns a generation number.
5. HCP Terraform workspace names allow letters, numbers, hyphen, and
   underscore. The issue already sends organization/workspace as
   `--data-urlencode` data rather than concatenating them into a URL path.

Resolution consequence:

- do not attempt to reproduce every mutable provider grammar in Bash;
- publish a clearly labeled, narrower ASCII grammar for this example's bucket,
  account, container, key/object, organization, workspace, and opaque selected
  version interfaces;
- retain provider-generated opaque version IDs byte-for-byte within a bounded
  printable-ASCII subset broad enough for documented values, and fail with an
  instruction to revise the example deliberately if an actual valid ID falls
  outside that subset;
- reject controls before confirmation, diagnostics, URI construction, or
  provider invocation and never echo rejected raw values; and
- retain primary provider links and require the chosen subset/source snapshot
  to be rechecked when the example is intentionally broadened.

## T3-01/T3-02 — Exact npm selection and Node engine floors

Implementation-planning snapshot taken 2026-07-29:

Primary sources:

- [`npm@12.0.2` registry metadata](https://registry.npmjs.org/npm/12.0.2)
- [`npm@12.0.2` package tarball](https://registry.npmjs.org/npm/-/npm-12.0.2.tgz)
- [Corepack project documentation](https://github.com/nodejs/corepack)
- [Node Corepack documentation](https://nodejs.org/api/corepack.html)

Retained facts:

1. The registry's `latest` npm release observed on the evidence date is
   `12.0.2`.
2. Its published engine is
   `^22.22.2 || ^24.15.0 || >=26.0.0`.
3. Its published tarball SRI is
   `sha512-uIXokLlBj6FpNUTQX1PmT5pz7BlIN9QlixX+zdaSNHsd0qUXsbDLr50xzY6Sw7cJVr0uzHKDOle0swmPW/p5Qw==`;
   the equivalent lowercase SHA-512 hex is
   `b885e890b9418fa1693544d05f53e64f9a73ec194837d4258b15fecdd692347b1dd2a517b1b0cbaf9d31cd8e92c3b70956bd2ecc72833a57b4b3098f5bfa7943`.
4. Corepack accepts `npm` in a `packageManager` descriptor with an exact version
   and optional integrity hash. Explicit `corepack npm` uses that selected
   manager; npm shims are not enabled by default, so merely adding
   `packageManager` while continuing to call ambient `npm` does not enforce it.
5. Corepack is bundled with Node releases from 14.19 through (but not including)
   Node 25. The selected repository runtime lines 22 and 24 therefore provide
   the explicit resolver, but its actual version/path must still be recorded.
6. Corepack can otherwise consult or update a “known good”/latest release.
   `COREPACK_DEFAULT_TO_LATEST=0`, an exact hashed project descriptor, strict
   project behavior, and an explicit version assertion are needed to prevent
   fallback from becoming policy.

Selected consequence:

- use exact `npm@12.0.2` through a hashed `packageManager` field and invoke it
  as `corepack npm` on every supported surface;
- reject disabling integrity/strict project selection and reject any reported
  npm version other than `12.0.2`;
- regenerate lockfile version 3 with that exact npm and use the same manager
  for install, list, lint scripts, hook, audit, fixtures, schedule, and local
  validation; and
- derive the reviewed Node-line floors from npm's exact engine:
  Node `22.22.2` and Node `24.15.0`, with no Node 20/26 line admitted merely
  because npm itself supports it.

Additional Node sources/snapshot:

- [Node.js release status](https://nodejs.org/en/about/previous-releases)
- [Node.js evolving release schedule](https://nodejs.org/en/blog/announcements/evolving-the-nodejs-release-schedule)
- [Node.js official distribution index](https://nodejs.org/dist/index.json)
- [Node.js Release Working Group schedule](https://github.com/nodejs/Release/blob/main/schedule.json)

Retained 2026-07-29 facts:

1. Node 22 is Maintenance LTS with scheduled end 2027-04-30; Node 24 is
   Active LTS with scheduled end 2028-04-30. Node 20 is EOL; Node 26 is Current.
2. The latest exact releases observed in the official distribution index are
   Node `22.23.2` and `24.18.1`.
3. Starting with Node 27, Node's announced annual schedule intends every major
   to become LTS. “Even major” is therefore neither a durable LTS predicate nor
   an authorization rule.
4. The repository's policy can admit the finite intervals
   `>=22.22.2 <23` and `>=24.15.0 <25` while using exact setup/evidence cells at
   both engine floors and current reviewed patches. Node 26 and future 27+
   remain rejected until an explicit policy/package-manager review.

## T3-03/T3-04 — npm audit report-v2 structure and baseline counts

Primary sources:

- [npm audit documentation](https://docs.npmjs.com/cli/v11/commands/npm-audit/)
- [`npm@12.0.2` exact registry package](https://registry.npmjs.org/npm/12.0.2)
- [`@npmcli/arborist` audit report source as bundled by the selected npm
  package](https://registry.npmjs.org/npm/-/npm-12.0.2.tgz)

Local dated observation (2026-07-29, pre-T3 baseline, Node 26.5.1/npm 11.7.0):

1. `npm audit --package-lock-only --json` returned native status `1` and a
   top-level object with exact properties `auditReportVersion`,
   `vulnerabilities`, and `metadata`; `auditReportVersion` was numeric `2`.
2. There were seven vulnerability **properties** keyed by package:
   `brace-expansion`, `js-yaml`, `linkify-it`, `markdown-it`,
   `markdownlint-cli2`, `minimatch`, and `picomatch`.
3. Their property severities were five high and two moderate, matching
   `metadata.vulnerabilities`; that metadata also had exact keys `info`, `low`,
   `moderate`, `high`, `critical`, and `total`.
4. Each vulnerability property had exact keys `name`, `severity`, `isDirect`,
   `via`, `effects`, `range`, `nodes`, and `fixAvailable`.
5. `via` contained both advisory objects and package-name strings. Advisory
   objects carried source/name/dependency/title/url/severity/CWE/CVSS/range
   data; string entries represented meta-vulnerability dependency edges.
6. `fixAvailable` appeared as booleans and objects with
   `name`, `version`, and `isSemVerMajor`.
7. The seven-property report contained more than seven advisory objects across
   advisory-object `via` entries, string `via` edges, and installed node paths.
   Those are different count domains and must not be labeled “seven affected
   package nodes.”
8. npm documents status `0` for no vulnerabilities. With the default
   `audit-level` (no threshold override), a vulnerability report is nonzero;
   registry/invalid-response/tool failures can also be nonzero. Report schema
   and native status therefore must be classified together rather than using
   either alone as “clean.”

Resolution consequence:

- freeze the exact report-v2 schema emitted by selected npm `12.0.2` after a
  clean implementation-time install and fail on any unsupported version/shape;
- separately validate/reconcile vulnerability-property severity counts,
  advisory objects, string graph edges, and package-keyed node paths;
- let a pure core classify strict raw report input plus supplied native process
  outcome and exception state;
- let orchestration own process launch, protected stdout/stderr capture,
  signal/start/timeout handling, and immediate native status; and
- label all implementation-time counts by their actual domain and date, never
  promote them to permanent acceptance constants.

## T3-05 — Husky installation and skip behavior

Primary sources:

- [Husky — How To](https://typicode.github.io/husky/how-to.html)
- [Husky — Get started](https://typicode.github.io/husky/get-started.html)
- [Husky — Troubleshoot](https://typicode.github.io/husky/troubleshoot.html)
- [Git hooks](https://git-scm.com/docs/githooks)

Retained facts:

1. Husky recommends a `prepare` script and configures Git through
   `core.hooksPath`; its troubleshooting guide expects the installed path to
   resolve to `.husky/_`.
2. Husky documents `HUSKY=0` as an intentional way to disable installation/
   execution in CI/Docker and illustrates a separate install script for an
   explicit production/CI skip.
3. The same documentation shows `husky || true` as a way to avoid a failure
   when devDependencies are absent, but that behavior is incompatible with this
   repository's promise that a full tooling install actually establishes and
   tests the hook.
4. A package located below the Git root needs an explicit directory change/
   target; Husky deliberately does not traverse arbitrary parents on its own.
5. Verifying only the `prepare` process status is insufficient: the actual
   local Git config, generated Husky shim, tracked hook, and a `git commit`
   pass/reject need to be observed in an owned repository.

Selected consequence:

- replace `husky || true` with a tracked, fail-closed installer which has an
  explicit `required` state and one tightly defined `skip` state;
- in required state, install at the independently resolved repository root and
  verify `core.hooksPath`, generated ordinary shim/launcher files, and tracked
  hook identity before success;
- in skip state, require explicit `HUSKY=0`, a closed reason, and proof that no
  hook/config mutation was expected or performed; and
- permanently test required success/failure, every skip near-miss, and actual
  `git commit` invocation in disposable repositories on both OS families.

## T3-06 — Follow-up issue syntax versus existence

Primary sources:

- [GitHub autolinked issue/PR URL forms](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/autolinked-references-and-urls)
- [GitHub REST issue response shape](https://docs.github.com/en/rest/issues/issues#get-an-issue)
- [GitHub Actions token permissions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions)

Retained facts:

1. A canonical repository issue URL has the recognizable form
   `https://github.com/OWNER/REPOSITORY/issues/NUMBER`, but parsing that string
   proves only syntax/selected repository/number.
2. GitHub's REST issue response carries repository/URL/number/state/database
   identities. The Issues API can also return pull requests; such responses
   include a `pull_request` property, so an existence check must reject that
   state when policy requires a filed issue.
3. A network lookup needs explicit authority and can fail independently of the
   pure audit/exception decision. GitHub Actions supports a job-scoped
   `issues: read` permission if an automated read is intentionally added;
   otherwise a maintainer can retain the lookup as approval evidence.

Selected consequence:

- the dependency-free pure core validates only a closed canonical URL grammar,
  exact `franklesniak/TerraformStyleGuide` repository, canonical positive issue
  number, and internal exception-field equality;
- exception approval/renewal separately retains an explicitly authorized GitHub
  read showing the issue exists, is an issue rather than a PR, remains open,
  and has a scope marker/hash matching the exact normalized residual findings;
- the external verification time/actor/immutable issue identities are recorded
  in reviewed evidence and referenced by the exception;
- ordinary offline validation does not claim it performed or can reproduce the
  network assertion; and
- the maximum 30-day exception renewal rechecks follow-up state/scope rather
  than treating one historical lookup as perpetual proof.

## T4-01/T4-05 — Windows ACL, reparse, and file identity

Primary sources:

- [.NET FileSystemSecurity](https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemsecurity?view=netframework-4.8.1)
- [.NET SetAccessRuleProtection](https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.objectsecurity.setaccessruleprotection?view=netframework-4.8.1)
- [CreateFile and `FILE_FLAG_OPEN_REPARSE_POINT`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilea)
- [GetFileInformationByHandleEx](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getfileinformationbyhandleex)
- [FILE_ID_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_id_info)
- [BY_HANDLE_FILE_INFORMATION](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/ns-fileapi-by_handle_file_information)
- [GetFinalPathNameByHandle](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfinalpathnamebyhandlea)
- [CreateHardLinkW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-createhardlinkw)

Retained facts:

1. `SetAccessRuleProtection(true,false)` protects a DACL and removes inherited
   rules; `AreAccessRulesProtected`, `AreAccessRulesCanonical`, `GetOwner`, and
   `GetAccessRules` expose the actual descriptor state for inspection.
2. `FILE_FLAG_OPEN_REPARSE_POINT` prevents normal reparse processing for the
   opened leaf; `FILE_FLAG_BACKUP_SEMANTICS` is required to obtain directory
   handles through `CreateFile`.
3. `FILE_ID_INFO` combines a volume serial number with a 128-bit file ID and
   explicitly documents that the pair can compare whether two open handles
   represent the same file.
4. The older `BY_HANDLE_FILE_INFORMATION` exposes link count and a 64-bit file
   ID; Microsoft notes the 64-bit ID is not guaranteed unique on ReFS, so the
   selected identity comparison uses `FILE_ID_INFO` and uses the older
   structure only for `nNumberOfLinks`.
5. `GetFinalPathNameByHandle` returns the final normalized path for an open
   handle, but neither it nor path-based .NET creation supplies a portable
   Windows `openat`-style adversarial namespace sandbox.
6. Microsoft documents `CreateHardLinkW` as NTFS-only, files-only, same-volume
   publication; its third parameter is reserved and must be null. It can hard
   link a symbolic-link entry, so the separate no-follow ordinary-file identity
   checks are mandatory.

Selected consequence:

- define a SID-based protected parent/file DACL and inspect the resulting
  descriptor rather than parsing localized command output;
- use one reviewed Win32 interop helper under PowerShell 5.1 and 7 for
  no-follow component checks, 128-bit file identity, link count, and exact
  hard-link publication;
- require NTFS for positive Windows publication and treat ReFS/unsupported
  filesystems as the explicit final-absent/validated-temp-retained failure;
- require the protected-parent/no-authorized-competitor premise explicitly and
  avoid claiming the handle checks defeat an authorized namespace racer; and
- fail closed when the filesystem or identity primitive is unavailable.

## T4-03 — Raw redirected-process streams

Primary source:

- [.NET Process.BeginErrorReadLine](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.beginerrorreadline)

Retained facts:

1. .NET requires a redirected stream to remain in either synchronous or
   asynchronous mode once reading starts.
2. Concurrent drainage is needed to avoid filling a child pipe while waiting
   for process completion; a retained-memory bound must not stop drainage at
   the boundary.

Selected consequence:

- drain stdout and stderr through independent raw-stream pumps;
- retain exactly 65,536 raw stderr bytes, treat byte 65,537 as overflow, and
  continue draining/discarding through EOF;
- fail overflow separately from the captured native outcome; and
- emit only bounded metadata, never captured diagnostic bytes.

## T4-04 — Strict BOM-less UTF-8

Primary sources:

- [.NET UTF8Encoding](https://learn.microsoft.com/en-us/dotnet/api/system.text.utf8encoding?view=netframework-4.8.1)
- [.NET UTF8Encoding(Boolean, Boolean)](https://learn.microsoft.com/en-us/dotnet/api/system.text.utf8encoding.-ctor)
- [.NET UTF8Encoding.GetPreamble](https://learn.microsoft.com/en-us/dotnet/api/system.text.utf8encoding.getpreamble)

Retained facts:

1. Microsoft explicitly recommends `UTF8Encoding(Boolean,Boolean)` with
   `throwOnInvalidBytes=true` for error detection/security.
2. The first constructor Boolean controls only what `GetPreamble` returns; it
   does not automatically add/remove a BOM during byte conversion.
3. UTF-8 BOM bytes are `EF BB BF`, so the issue needs an independent prefix
   rejection in addition to a throwing decoder.

Selected consequence:

- reject the BOM prefix on the original candidate bytes;
- validate the entire unchanged stream with
  `UTF8Encoding(false,true).GetDecoder()` and a final flush;
- place strict encoding validation before JSON/Terraform/metadata/publication;
  and
- permanently test every malformed sequence class and incremental-buffer
  boundary on both PowerShell editions.
