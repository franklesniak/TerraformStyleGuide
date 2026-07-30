# Evaluation and resolution of current TerraformStyleGuide findings

## Evaluation status

Evaluation started on 2026-07-29 from:

- `docs/planning/artifacts/current-findings.md`;
- TerraformStyleGuide commit
  `4523b280fdff5034d31fa70f97bdc35dc05af129`; and
- the current local worktree.

Only open findings for the TerraformStyleGuide issue slate are in scope. Each
finding will be completed here, in issue order, before evaluation proceeds to
the next finding. Each completed section will contain:

1. the finding and decision constraints;
2. comprehensive resolution options;
3. a finding-specific weighted rubric;
4. a scored option comparison; and
5. an implementation-ready selected resolution.

After every finding has a selected resolution, those resolutions will be
incorporated into T1, T1A, T1B, T2, T3, and T4 in their intended execution
order.

## Finding inventory

There are 34 open Terraform findings. T1A-05 is excluded because
`current-findings.md` marks it **Addressed**.

| Order | Issue | Open findings |
| --- | --- | --- |
| 1 | T1 | T1-01, T1-02, T1-03, T1-04, T1-05, T1-06 |
| 2 | T1A | T1A-01, T1A-02, T1A-03, T1A-04 |
| 3 | T1B | T1B-01, T1B-02, T1B-03, T1B-04, T1B-05 |
| 4 | T2 | T2-01, T2-02, T2-03, T2-04, T2-05 |
| 5 | T3 | T3-01, T3-02, T3-03, T3-04, T3-05, T3-06, T3-07 |
| 6 | T4 | T4-01, T4-02, T4-03, T4-04, T4-05, T4-06, T4-07 |

The next finding to evaluate is T1-01.

## T1-01 — Correct the checkout credential invariant

### Finding and decision constraints

T1 currently says that verification checks out and generates “without
credentials,” that the push credential is referenced only by the temporary push
step, and that diagnostics are “credential-free.” Those claims cannot coexist
with the selected `actions/checkout` configuration:

- the pinned action defaults its required `token` input to `github.token`;
- the action configures authentication before fetching;
- `persist-credentials: false` removes that Git authentication after checkout
  rather than preventing its use; and
- GitHub creates a job token before the job and documents that actions can
  access `github.token` even when it is not explicitly passed.

The resolution must be factually exact, preserve trusted-source checkout for
pull requests and private-repository configurations, minimize the authority of
each job, avoid leaking the credential into Git remotes/configuration after
checkout, remain enforceable by T1/T1B's workflow-policy checks, and be
understandable to maintainers who do not know `actions/checkout` internals.

Primary-source evidence is retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Explicit authenticated checkout with an honest three-layer token contract

Retain the pinned checkout action. Explicitly declare
`token: ${{ github.token }}` and `persist-credentials: false` at every checkout.
Describe three distinct layers:

1. GitHub creates a job-scoped token with the job's declared permissions.
2. Checkout receives that token for fetch and removes its Git auth configuration
   before the next step.
3. The temporary writer explicitly expands the token into process-scoped Git
   authorization only at the guarded push step.

Replace “credential-free” with testable statements: later shell processes
receive no explicit token/header/config environment, the origin contains no
credential, and no checkout extra-header remains in local/global Git config.
Constrain write authority through job-level permissions, the exact action/step
allowlist, and the guarded push condition.

Permutations:

- use `${{ github.token }}` or `${{ secrets.GITHUB_TOKEN }}` as the explicit
  input; prefer `github.token` because it names the actual context property used
  by the action default and does not imply a separately configured secret;
- check post-checkout config with PowerShell or a policy helper; use both
  structural YAML validation and a runtime presence-only assertion for defense
  in depth; and
- pair this resolution with T1-06/T1B-02's exact input-key tables so later
  action-default changes cannot silently alter the boundary.

#### Option B — Keep the implicit checkout-token default but correct the prose

Retain checkout with only `persist-credentials: false`; acknowledge in prose
that the action resolves `github.token` for fetch. This is operationally close
to Option A but leaves a security-relevant input implicit and makes the
validator depend on an upstream default.

#### Option C — Replace checkout with a manual authenticated Git fetch

Use trusted in-workflow Git commands, initialize a repository, and expose a
process-scoped HTTP authorization header only to `git fetch`. Remove the header,
validate the fetched commit/ref, and check it out. This gives precise control
over Git configuration and could make fetch/push symmetry clearer, but it
reimplements checkout's ref, fork, safe-directory, REST fallback, submodule,
object-format, cleanup, and platform behavior.

Permutations include placing the fetch logic in an inline shell block, a
tracked helper, or a local action. A tracked helper is testable but expands T1's
affected files and security-review surface.

#### Option D — Use unauthenticated public archive or Git transport

Download a commit archive or fetch the public repository without a token.
Verify the archive/commit identity before use. This can make one specific public
repository checkout genuinely credential-free, but fails for private
repositories, may lose `.git` data required by path/ref checks, introduces
rate-limit and archive-integrity concerns, and diverges sharply from the
current issue architecture.

#### Option E — Transfer source from a read-only producer job

Have a read-only job check out and package the exact source, then let the writer
download that artifact instead of performing a second checkout. This reduces
the number of times a write-capable job uses checkout, but does not eliminate
the producer's authenticated fetch. It also introduces artifact identity,
retention, permission, and extraction-security requirements that T1A/T1B are
specifically intended to own later.

#### Option F — Keep the present wording and treat `persist-credentials: false` as sufficient

Make no behavioral or prose change. This is minimal churn but knowingly encodes
a false invariant and causes the structural validator and acceptance evidence
to certify a property they cannot prove.

#### Option G — Persist checkout credentials and reuse them for push

Set or retain `persist-credentials: true` and let Git use the configured token
for the later push. This is simple and functional, but broadens credential
lifetime, hides push authorization in Git config, weakens diagnostics, and
directly contradicts the least-privilege objective.

### Finding-specific evaluation rubric

Scores use a 1–5 scale, where 5 is best. The weighted result is
`weight × score ÷ 5`. This rubric is specific to the checkout-token truth
boundary:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Factual and security-boundary correctness | 30 | Security reviewers and implementers must be able to prove every credential statement against GitHub and the pinned action source. |
| Least privilege and secret-exposure containment | 25 | A write-capable job token is material; authority, explicit expansion, Git configuration, and process inheritance must be minimized. |
| Source integrity and workflow compatibility | 20 | The design must reliably acquire the exact trusted commit for push, pull-request, public, and potentially private repository use. |
| Structural and runtime verifiability | 15 | DevOps maintainers need deterministic policy checks that fail when inputs, permissions, persistence, or role placement drift. |
| Maintainer/operator clarity | 7 | A new developer must understand job-token availability versus checkout and push use without studying action internals. |
| Churn and implementation burden | 3 | Low churn is useful, but it cannot outrank truth, containment, or source integrity. |

Security correctness and least privilege dominate. Project-management desire
for a small diff is intentionally low-weighted. Compatibility represents
developers and business continuity; verifiability represents DevOps and audit;
clarity represents documentation and onboarding.

### Scored comparison

| Option | Correctness 30 | Least privilege 25 | Integrity 20 | Verifiability 15 | Clarity 7 | Churn 3 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — explicit checkout plus honest layers | 5 | 4 | 5 | 5 | 5 | 4 | **94.4** |
| B — implicit default plus corrected prose | 5 | 4 | 5 | 3 | 3 | 5 | 86.2 |
| C — manual authenticated fetch | 5 | 5 | 4 | 4 | 3 | 1 | 87.8 |
| D — unauthenticated public transport | 4 | 5 | 2 | 3 | 3 | 1 | 70.8 |
| E — source-artifact handoff | 4 | 4 | 3 | 3 | 2 | 1 | 68.4 |
| F — retain the false invariant | 1 | 3 | 5 | 1 | 1 | 5 | 48.4 |
| G — persist and reuse checkout auth | 2 | 1 | 5 | 2 | 2 | 4 | 48.2 |

Option C slightly improves theoretical control over explicit fetch credential
exposure, but its reimplementation risk and issue-scope expansion outweigh that
gain. Option A gives the highest combined correctness, compatibility,
verifiability, and usability.

### Selected resolution

Select **Option A — explicit authenticated checkout with an honest three-layer
token contract**.

Implement it in T1 as follows:

1. Replace every statement that checkout or a whole job is “without
   credentials” or “credential-free.” State instead that GitHub creates a token
   for each job; job-level permissions bound its authority.
2. Require every checkout role to declare the exact keys
   `token: ${{ github.token }}` and `persist-credentials: false` in addition to
   its other role-specific inputs. No security-relevant checkout default may be
   silently relied upon.
3. State that checkout uses the token transiently for repository acquisition
   and removes its configured Git authentication before returning when
   persistence is false.
4. For the read-only verification and Markdown jobs, retain
   `contents: read`. For the temporary writer, retain the minimum
   `contents: write` job permission needed by the guarded push and prohibit
   unrelated permissions.
5. Replace “the token is referenced only by the push step” with two separate
   enforceable rules:
   - the token may be explicitly expanded only into action `token` inputs and
     the exact guarded push step named by the normative role table; T1-06 must
     include checkout and, if retained, setup-node's reviewed distribution-
     download token input rather than relying on either default; and
   - only the push step may construct a process-scoped Git authorization
     header for `git push`.
6. After each checkout, test only for the **presence** of credential-bearing
   remote URLs, credential helpers, and HTTP authorization configuration.
   Never print a header or secret value. Fail if any persists.
7. State that non-checkout diagnostic and generation processes receive no
   explicit token, header, credential-helper, or Git-config environment. Do not
   claim the job token object is absent; GitHub documents that `github.token`
   exists in execution steps.
8. Update the structural verifier and negative fixtures to reject an implicit
   security-relevant token input, `persist-credentials` other than literal
   false, token expansion in an unallowlisted role, write permissions in a
   verification job, persisted auth, or a push-header construction outside the
   exact push step.
9. Apply the same vocabulary and invariant to T1B under finding T1B-01 so the
   temporary and final writer layers do not disagree.

This resolution is factual about GitHub's job token, explicit about the pinned
action's fetch behavior, and strict about the controls the repository can
actually enforce.

**Status: selected and ready for incorporation into T1.**

The next finding to evaluate is T1-02.

## T1-02 — Define one final-write helper and a complete destination contract

### Finding and decision constraints

T1 currently repeats the final-write sequence at four sites and gives an
incomplete destination contract. Its chosen PowerShell API accepts relative,
provider-qualified, and wildcard-bearing input; it returns one unresolved path,
so “reject multiple resolution” is not itself a meaningful oracle. The generator
is invoked in a repository checkout that may contain untrusted pull-request
content, and the result must behave identically in Windows PowerShell 5.1 and
PowerShell 7 on Windows/Linux.

The resolution must:

- make newline normalization, encoding, destination validation, failure
  reporting, and final writing impossible to drift among four artifacts;
- reject null/empty/whitespace, wildcard, relative, malformed,
  non-filesystem/provider-internal, out-of-repository, and unsafe reparse
  destinations;
- derive production paths independently of the caller's current directory;
- remain testable with stable failure IDs; and
- expose a semantic contract that P1 can match without sharing code.

PowerShell/.NET path API facts are retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — One private artifact-aware helper with an exact destination allowlist

Add one private helper such as:

```text
Write-StyleGuideArtifact(ArtifactId, DestinationPath, CompletePayload)
```

At script initialization, derive the repository root from trusted
`$PSScriptRoot`, then derive the exact four allowed absolute destinations.
`ArtifactId` is a closed set and maps to exactly one expected path. The helper:

1. validates the raw destination grammar;
2. converts it once with the
   `GetUnresolvedProviderPathFromPSPath` overload that returns provider/drive;
3. requires `FileSystem`;
4. obtains one normalized full path;
5. requires exact equality with the path mapped from `ArtifactId`;
6. rejects reparse traversal from the repository root through the destination;
7. normalizes the complete payload;
8. encodes it with one BOM-less strict UTF-8 policy; and
9. performs the selected T1-04 write/failure transaction.

All four generators must call this helper and may not write directly.

Permutations:

- keep `DestinationPath` to permit negative testing, or remove it and let the
  helper derive the path solely from `ArtifactId`; retaining it plus exact
  ID/path matching gives the strongest mismatch oracle;
- make path/normalization subroutines separately testable while retaining one
  sole final-write entry point; and
- use an internal exception taxonomy or stable returned status. Either is
  viable if every public generator continues returning exact `0`/`1` and
  tests assert the same failure IDs across editions.

#### Option B — One general repository-root-contained helper

Accept any fully qualified filesystem path beneath a supplied repository root
and enforce separator-boundary containment. This is reusable for future
artifacts and can share more literal code with P1, but a compromised or mistaken
caller could write an unreviewed file under the repository. It also makes the
current four-file promise indirect.

Permutations include a leaf-name allowlist, extension allowlist, or caller-
supplied allowed-path collection. A caller-supplied allowlist weakens the trust
boundary unless it is immutable and constructed only at script initialization.

#### Option C — Remove destination parameters and select only by artifact ID

Refactor content functions to return complete strings. A single top-level
writer maps a closed artifact ID to a fixed path and writes the returned
payload. This eliminates arbitrary destination input from production code and
is highly secure, but changes function contracts and makes filesystem failure
fixtures require a temporary repository-shaped script layout or an injectable
trusted root.

#### Option D — Share path validation but leave four physical write calls

Add `Resolve-SafeArtifactPath`, call it from all generators, then keep one
`File.WriteAllText` call in each function. This improves path handling but still
allows normalization, encoding, exception, failure-state, or write-mode drift.

#### Option E — Use `Set-Content -LiteralPath`

Switch from `-Path` to `-LiteralPath` and rely on cmdlet provider behavior.
This handles wildcard interpretation better, but does not establish exact
provider/root/encoding semantics across PowerShell editions and preserves four
host-sensitive write sites.

#### Option F — Create a shared cross-repository generator module

Move the helper into a package/module consumed by PSStyleGuide and
TerraformStyleGuide. This could eliminate code drift, but introduces version,
availability, review, bootstrap, and supply-chain coupling that both slates
explicitly reject.

#### Option G — Let each caller canonicalize before a minimal byte writer

Make a tiny `Write-Utf8` helper and require each caller to validate/canonicalize
its own path. This centralizes encoding but leaves the security boundary
distributed and lets one caller omit or reorder a check.

### Finding-specific evaluation rubric

Scores use 1–5 and are weighted as `weight × score ÷ 5`. Unlike T1-01's
credential rubric, this rubric emphasizes the completeness and singularity of
the filesystem serialization boundary:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Destination-contract completeness and cross-platform correctness | 30 | The public behavior must reject every ambiguous path class consistently in Windows PowerShell 5.1 and PowerShell 7. |
| Single-boundary drift prevention | 22 | Four artifacts must not acquire different newline, encoding, exception, or write semantics over time. |
| Filesystem security containment | 18 | Pull-request content and path tricks must not redirect writes outside the four repository-owned artifacts. |
| Stable negative-case testability | 15 | Developers and CI need exact IDs/oracles for every rejected grammar, provider, containment, and reparse state. |
| API usability and diagnostic quality | 10 | A new maintainer should know which artifact/path failed without understanding provider internals. |
| Churn and implementation cost | 5 | Refactoring cost matters, but is subordinate to a correct long-lived boundary. |

The weights reflect security engineering (contract and containment), senior
engineering (drift prevention), DevOps (testability), documentation/onboarding
(usable diagnostics), and project delivery (cost).

### Scored comparison

| Option | Contract 30 | Drift 22 | Security 18 | Tests 15 | Usability 10 | Churn 5 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — artifact-aware exact helper | 5 | 5 | 5 | 5 | 4 | 4 | **97.0** |
| B — general root-contained helper | 4 | 5 | 4 | 4 | 5 | 4 | 86.4 |
| C — artifact ID only | 5 | 5 | 5 | 4 | 5 | 2 | 94.0 |
| D — shared validation, four writes | 4 | 2 | 3 | 3 | 4 | 4 | 65.6 |
| E — `Set-Content -LiteralPath` | 2 | 2 | 2 | 2 | 4 | 5 | 47.0 |
| F — shared cross-repository module | 4 | 5 | 4 | 4 | 3 | 1 | 79.4 |
| G — caller validation, minimal writer | 3 | 3 | 2 | 3 | 4 | 4 | 59.4 |

Option C is nearly as strong but makes failure injection and existing function
integration harder. Option A combines a closed artifact identity with explicit
path-mismatch tests and the least contract churn.

### Selected resolution

Select **Option A — one private artifact-aware helper with an exact destination
allowlist**.

Implement it in T1 as follows:

1. Add one private `Write-StyleGuideArtifact` boundary. Direct final file writes
   anywhere else in the generator are prohibited and machine-searched.
2. Give it a closed `ArtifactId`, a destination string, and the complete final
   payload. Define the four IDs and their one-to-one filenames in a normative
   table.
3. Derive the repository root from `$PSScriptRoot` and the script's fixed
   `.github/workflows` location. Do not use the process current directory as a
   trust anchor.
4. Reject destination input in this exact order, with stable case IDs:
   null; empty; whitespace-only; NUL/control or otherwise malformed; PowerShell
   wildcard syntax; provider-qualified syntax; relative, drive-relative, or
   rooted-but-not-fully-qualified syntax.
5. Call the out-parameter overload of
   `GetUnresolvedProviderPathFromPSPath`; require provider name
   `FileSystem`. Because the API returns one unresolved string and wildcards
   were already rejected, state that a resolving/multi-match API is prohibited
   rather than inventing a multiple-result check.
6. Normalize the provider-native result exactly once, then compare it with the
   expected path for `ArtifactId`. Use ordinal-ignore-case on Windows and
   ordinal on Linux, with full path/leaf equality—not string-prefix
   containment.
7. Inspect every existing component from the trusted repository root through
   the parent and destination. Reject symlink/reparse components, non-directory
   parents, and an existing non-ordinary destination. Treat an absent final
   leaf according to T1-04's selected transaction.
8. Normalize the complete payload inside this helper, instantiate the one
   selected BOM-less UTF-8 encoder, and perform the T1-04 final-write
   transaction. Callers may compose content but cannot pre-encode or write it.
9. Return/report stable artifact ID, safe normalized destination, phase, and
   exception category without logging content. Preserve each generator's
   documented external `0` success/`1` failure contract.
10. Add a one-row-per-case test table covering all raw-input classes, every
    non-filesystem provider available in the harness, ID/path mismatch,
    out-of-allowlist paths, case behavior on each OS, reparse parent/final
    entries, all four positive IDs, and proof that no other write API remains.
11. Mirror these semantics—not repository-specific filenames or source
    composition—in P1's reciprocal matrix. Do not create a shared runtime
    module.

T1-04 will choose the exact no-partial-write transaction used inside this
helper; T1-02 establishes that there is only one place to implement it.

**Status: selected and ready for incorporation into T1.**

The next finding to evaluate is T1-03.

## T1-03 — Define a parseable generator version field

### Finding and decision constraints

T1 asks for “one updated generator version using the repository's UTC version
convention,” but the generator has no version field and TerraformStyleGuide has
no such convention. T1A requires version markers on three more scripts and T1B
expects exact prerequisite versions. Free-form `.NOTES`, a guide-document
version, a filename, or a Git timestamp cannot satisfy those consumers.

The resolution must define a single field, grammar, initial value,
calculation/bump rule, parser scope, failure behavior, and successor handoff.
It should converge with PSStyleGuide's observable convention while remaining
self-contained and must not confuse human-readable version metadata with
immutable source identity.

The PSStyleGuide primary-source convention and current Terraform baseline are
retained in `docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Adopt the PSStyleGuide-compatible `.NOTES` `Version:` field

Put exactly one script-level line in the generator's `.NOTES`:

```text
Version: Major.Minor.YYYYMMDD.Revision
```

Define all calculation rules in T1. Because the generator has no previously
published script version, T1 assigns
`1.0.<actual-implementation-UTC-YYYYMMDD>.0`. Validate the four numeric
components as `[System.Version]`, validate `YYYYMMDD` as a real UTC calendar
date, and reject missing, duplicate, malformed, or unexpected fields.

For later published changes, change Major for breaking interfaces, Minor for
non-breaking capabilities, Build for every UTC-date change, and Revision for a
second published update on the same Major/Minor/date. T1A uses the same
self-contained rule for each new script. T1B consumes both exact parsed
versions and exact merge commits.

Permutations:

- name the field `Version:` exactly for cross-repository convergence, or use a
  Terraform-specific `Script-Version:` name; the exact shared name reduces
  parser drift;
- parse with a small PowerShell helper or T1B's Node policy validator; use a
  PowerShell implementation at T1/T1A and make the later Node validator
  independently confirm it; and
- supplement the version with a file SHA-256. The hash is useful promotion
  evidence but must not replace the human version or merge commit.

#### Option B — Use a canonical RFC 3339 modification timestamp

Add `Script-Version: 2026-07-29T23:59:59Z`. This is sortable and simple, but
seconds introduce unnecessary build-time variation, same-second collision
handling, and no breaking/non-breaking semantics. It also diverges from P1.

#### Option C — Use conventional semantic versioning only

Add `Version: 1.0.0` and bump it manually. This is parseable and familiar but
does not implement the requested UTC convention, gives no deterministic
same-day rule, and invites forgotten bumps.

#### Option D — Use the exact Git commit SHA as the script version

Embed or report the commit containing the script. A commit is immutable and
collision-resistant, but embedding a commit into the file changes the commit
being named, creating a self-reference problem. Runtime environment metadata
can report the checked-out SHA but cannot serve as a field in the source.

#### Option E — Use a SHA-256 content digest as the version

Treat the script's byte hash as its version. This detects every change but is
unfriendly to humans, changes for comments/line endings, does not express
compatibility, and is self-referential if embedded in the hashed file.

#### Option F — Add a separate JSON/YAML script manifest

Store versions, paths, and hashes in a new machine-readable manifest. This
scales to many scripts and centralizes policy, but expands every issue's
affected-file surface, creates a manifest/source synchronization problem, and
is unnecessary for four version fields.

#### Option G — Add a typed `$script:GeneratorVersion` variable

Declare `[version]$script:GeneratorVersion = '1.0.YYYYMMDD.0'` and let consumers
parse the PowerShell AST or execute a safe metadata-only path. This is strongly
typed at runtime, but execution to read metadata is unsafe before identity
validation and AST parsing is more complex than a uniquely scoped comment
field.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric is tailored to durable
source-version metadata rather than path or credential behavior:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Parseability and one-value unambiguity | 25 | Automated consumers must distinguish exactly one valid field from missing, duplicate, malformed, or unrelated document metadata. |
| P/T semantic convergence without coupling | 20 | Matching the observable P convention simplifies reciprocal evidence while retaining repository independence. |
| Change meaning and stale-version detection | 20 | Maintainers need deterministic Major/Minor/date/revision rules that expose an omitted or incorrect bump. |
| Safe successor consumption | 15 | T1A/T1B must verify metadata before executing scripts and combine it with immutable commit identity. |
| Human readability and operational usefulness | 10 | Reviewers should understand age and compatibility intent without special tooling. |
| Collision resistance and monotonic update behavior | 7 | Same-day and later-day published changes need deterministic distinct values. |
| Churn and maintenance cost | 3 | Extra files/parsers have a cost, but metadata correctness is more important. |

### Scored comparison

| Option | Parse 25 | Convergence 20 | Change meaning 20 | Consumption 15 | Human 10 | Collision 7 | Churn 3 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — `.NOTES` `Version:` convention | 5 | 5 | 5 | 5 | 5 | 4 | 4 | **98.0** |
| B — RFC 3339 timestamp | 5 | 3 | 4 | 4 | 5 | 3 | 4 | 81.6 |
| C — semantic version only | 5 | 3 | 3 | 4 | 5 | 2 | 5 | 76.8 |
| D — Git commit SHA | 5 | 2 | 5 | 5 | 3 | 5 | 3 | 82.8 |
| E — content digest | 5 | 2 | 5 | 5 | 2 | 5 | 2 | 80.2 |
| F — separate manifest | 5 | 3 | 4 | 5 | 4 | 4 | 1 | 82.2 |
| G — typed script variable | 5 | 4 | 4 | 5 | 4 | 4 | 3 | 87.4 |

Option A is the only choice that simultaneously provides an exact parser
target, deterministic change semantics, easy human review, and direct P/T
convergence without an added runtime or manifest.

### Selected resolution

Select **Option A — the PSStyleGuide-compatible `.NOTES` `Version:` field**.

Implement it across the slate as follows:

1. T1 must define the complete convention rather than link to P1 as normative:
   exactly one `Version: Major.Minor.Build.Revision` line in the script-level
   `.NOTES`; four nonnegative decimal components accepted by
   `[System.Version]`; Build exactly eight digits and a valid UTC
   `YYYYMMDD` date.
2. The T1 generator has no previously published field, so its expected value is
   `1.0.<implementation UTC date>.0`. Recompute the date if implementation
   crosses UTC midnight. Work-in-progress commits do not increment Revision.
3. For a later **published** version:
   - increment Major for a breaking public interface/return/output change;
   - otherwise increment Minor for a new non-breaking capability;
   - set Build to the actual UTC modification date for every change;
   - set Revision to `0` when Major, Minor, or Build differs from the previously
     published version; otherwise use prior Revision plus one.
4. Scope parsing to the one script-level comment-help block before the first
   function. Do not accept a function's `.NOTES`, generated guide version,
   filename, filesystem timestamp, or unanchored text match.
5. Fail distinctly for missing, duplicate, malformed, invalid-date,
   non-`[version]`, stale, or unexpected values. Record the safe expected and
   actual version strings.
6. Add positive and negative fixtures for initial version, same-day revision,
   next-day reset, Major/Minor reset, leap-day validity, impossible date,
   leading sign/whitespace, extra component, duplicate field, and a decoy
   `Version:` inside a function.
7. T1A must give each new helper/context/harness script its own
   `1.0.<actual implementation UTC date>.0` script-level field and use the same
   parser contract.
8. T1B must read expected values from the exact T1/T1A prerequisite commits,
   independently parse the checked-out files before execution, and require
   exact equality. It must also verify ordinary-file identity.
9. Retain exact merge commits and SHA-256 hashes as separate immutable evidence.
   Never use the human version as a substitute for commit/file identity.
10. Put the PSStyleGuide versioning link in `References` as convergence evidence,
    while keeping all normative rules above in each Terraform issue that owns
    or consumes the fields.

**Status: selected and ready for incorporation into T1, T1A, and T1B.**

The next finding to evaluate is T1-04.

## T1-04 — Specify the destination postcondition after a failed write

### Finding and decision constraints

T1's reciprocal matrix asks whether a failed destination remains safe, yet its
permitted `File.WriteAllText` implementation may create or truncate the real
destination before all bytes are written. T1 does not say whether failure may
leave old, missing, partial, or new bytes. That ambiguity is incompatible with
four tracked generated artifacts and with a fail-closed P/T generator contract.

The resolution must define a single commit point, exact pre/post-commit
failure states, temporary-file lifecycle, durability behavior, race assumptions,
supported filesystems, and stable fault-injection cases for Windows PowerShell
5.1 and PowerShell 7 on Windows/Linux. It should not claim crash/power-loss
guarantees the chosen API does not document.

Primary .NET replacement/flush facts are retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Same-directory durable temporary file plus `File.Replace`

Require all four destinations to be pre-existing ordinary files. Inside the
sole T1-02 helper:

1. create an unpredictable temporary sibling with `FileMode.CreateNew`;
2. write all encoded bytes with exclusive sharing;
3. call `Flush(true)`, close, and verify length/hash;
4. commit once with `File.Replace(temp, destination, $null)`; and
5. delete any uncommitted temporary file in `finally`.

Before the commit call, every failure leaves the old destination byte-identical.
A replacement exception is failure and must leave the old destination. A
successful replacement is the point of no return and yields the complete new
payload. No later fallible check may report it as though the old destination
were retained.

Permutations:

- provide a backup path to `File.Replace`, verify it, then delete it; this adds
  recovery evidence but also creates another sensitive lifecycle and path;
  use `$null` because Git already supplies versioned rollback;
- use `FileOptions.WriteThrough` in addition to `Flush(true)`; the latter is the
  cross-edition common denominator and is sufficient for the declared
  durability scope; and
- skip the replacement when old/new hashes are equal. This is a safe
  optimization only after the helper proves both byte sets; it must not create
  a second write path.

#### Option B — Direct `File.WriteAllText` with an explicitly weak failure contract

State that failure may leave a missing, truncated, or partial destination and
require users/CI to restore from Git. This is honest and minimal but makes a
routine disk/write error mutate a tracked artifact and weakens P/T convergence.

#### Option C — Move old file aside, move new file in, and roll back on failure

Rename the destination to a backup, rename the temporary into place, then
restore the backup on error. This works with older APIs but creates an interval
where the destination is absent and rollback itself can fail. It is not one
atomic commit.

#### Option D — Compare bytes and avoid writes when unchanged

Hash/compare the generated bytes and return success without writing when they
match. This handles T1's expected unchanged-artifact case, but future legitimate
content changes still require a defined safe replacement path.

#### Option E — Use platform-native replacement APIs

P/Invoke Windows `ReplaceFile` and Unix `rename`/`renameat2`, with platform-
specific directory flushing. This offers maximal control and could strengthen
crash consistency, but substantially expands unsafe interop, error mapping, OS/
filesystem support, and cross-edition testing.

#### Option F — Publish a new immutable filename and update a pointer

Write content-addressed files and atomically switch a manifest/symlink/reference.
This is a strong deployment pattern, but generated artifact consumers require
the four stable repository filenames and Git does not need a release-store
abstraction.

#### Option G — Restore from Git in `catch`

Write directly and run `git checkout`/`git restore` on failure. This depends on
Git availability and clean index state, can overwrite user changes, still has a
partial interval, and creates a destructive recovery action inside the
generator.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric focuses on transactional
file-state integrity:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Precise failure-state guarantee | 30 | The defining question is whether old or complete-new bytes exist after every injected process-level failure. |
| Windows PowerShell/PowerShell 7 portability | 20 | The same contract must work on .NET Framework Windows and modern .NET Windows/Linux. |
| Race and path-swap resistance | 15 | A checked destination must not be replaced through a second unvalidated path or multi-step gap. |
| Durability before commit | 12 | Reviewers need confidence that the complete temporary payload reached the filesystem before it becomes the named artifact. |
| Fault-injection testability | 10 | CI must deterministically exercise write, flush, close, verification, replacement, and cleanup failures. |
| Cleanup and recovery ergonomics | 8 | Failed runs should leave no ambiguous sibling files or require manual repair. |
| Churn/complexity | 5 | Complexity matters, but cannot outrank preservation of tracked files. |

### Scored comparison

| Option | Failure state 30 | Portability 20 | Races 15 | Durability 12 | Tests 10 | Cleanup 8 | Churn 5 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — temp plus `File.Replace` | 5 | 4 | 5 | 5 | 5 | 5 | 3 | **94.0** |
| B — direct write/weak contract | 1 | 5 | 2 | 2 | 4 | 4 | 5 | 56.2 |
| C — backup/move/rollback | 3 | 5 | 2 | 4 | 4 | 2 | 3 | 67.8 |
| D — skip unchanged writes | 2 | 5 | 3 | 3 | 3 | 5 | 4 | 66.2 |
| E — native interop | 5 | 2 | 5 | 5 | 3 | 3 | 1 | 76.8 |
| F — immutable file/pointer | 4 | 5 | 4 | 4 | 4 | 3 | 2 | 80.4 |
| G — Git restore in `catch` | 2 | 5 | 2 | 2 | 2 | 2 | 4 | 54.0 |

Option A is the best common-denominator transaction. Its only material limit is
that support and exact exception categories can vary by filesystem/runtime;
the issue can fail closed on unsupported filesystems and test every supported
runner rather than fall back to a direct write.

### Selected resolution

Select **Option A — same-directory durable temporary file plus
`File.Replace`**.

Implement it in T1 as follows:

1. State that all four production destinations must already exist as tracked,
   ordinary, non-reparse files. Absence is a validation failure; T1 does not
   create a brand-new generated artifact.
2. After T1-02 path validation and payload normalization, encode the full
   payload once to BOM-less UTF-8 bytes before opening any output.
3. Generate an unpredictable sibling temporary name in the destination's
   already validated directory. Use bounded collision retries and
   `FileMode.CreateNew`, `FileAccess.Write`, `FileShare.None`.
4. Write the complete byte array, call `Flush(true)`, dispose the stream, then
   independently verify the closed temporary file's exact length and SHA-256.
   Do not reopen or mutate the destination during preparation.
5. Recheck that the destination and parent still satisfy the ordinary-file/
   non-reparse identity assumptions available to the cross-platform contract.
   The controlled checkout prohibits competing writers.
6. Call `File.Replace(temp, destination, $null)` exactly once. There is no
   copy, delete-then-move, direct-write, or fallback branch.
7. Define states:
   - any failure before replacement: destination remains byte-identical old
     content; temporary file is removed;
   - replacement throws: report failure, require byte-identical old content,
     and remove the still-existing temporary file;
   - replacement returns: destination is the complete new payload, the
     temporary path is absent, and the operation is committed success.
8. Put no fallible semantic validation after the commit. All byte/hash checks
   occur on the temporary file. A logging problem after commit must not be
   misclassified as an old-destination-preserved failure.
9. Fail closed if `File.Replace` is unsupported. Do not fall back to
   `WriteAllText`, `Copy`, or backup/move. Record the runtime/filesystem and
   stop.
10. In `finally`, delete only the exact validated temporary sibling if it still
    exists, never the destination. Preserve the primary failure; cleanup
    failure is secondary diagnostic data.
11. Add fault injection before/after create, during partial write, on flush,
    close, temporary verification, precommit recheck, replacement, and cleanup.
    For each, assert destination bytes, temp absence/presence, primary status,
    and no unallowlisted path changes.
12. Test successful replacement and every injected failure in Windows
    PowerShell 5.1, PowerShell 7 on Windows, and PowerShell 7 on Linux. Record
    an unsupported-filesystem failure as a blocker rather than weakening the
    contract.
13. Scope the guarantee to ordinary process/filesystem failures covered by the
    API and tests. Do not promise survival of power loss, kernel failure, or a
    malicious concurrent process beyond the declared filesystem contract.

The reciprocal P1/T1 matrix must use the same old-or-complete-new state names
and treat a direct/partial write on either side as a blocker.

**Status: selected and ready for incorporation into T1.**

The next finding to evaluate is T1-05.

## T1-05 — Make temporary workflow-policy validation reproducible

### Finding and decision constraints

T1 introduces exact action and workflow policy, requires semantic parsing and
negative fixtures, but allows no tracked validator/parser/package change.
“Implementation-time verifier” therefore has no reproducible tool, version,
command, or retained implementation. A text/regex check cannot correctly
distinguish YAML mappings, duplicate keys, comments, quoted scalars, aliases,
or swapped job/step structure.

The resolution must parse YAML semantically, be deterministic and offline in
ordinary validation, reject ambiguous YAML features, co-version policy with the
workflows, preserve exact negative fixtures, and hand off cleanly to T1B.
Churn and original affected-file count matter less than merging an enforceable
security policy with the configuration it claims to protect.

Current lock-tree evidence and `yaml@2.9.0` primary-source behavior are retained
in `docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Temporary tracked-by-evidence script using locked transitive `js-yaml`

After current `npm ci`, use the transitive `js-yaml@4.1.1` already locked via
`markdownlint-cli2`. Generate a temporary verifier/fixtures outside the
repository, hash them, run them offline, and retain their exact text/hashes/
command in pull-request evidence. T1B later creates the permanent validator and
declares a direct parser.

This preserves T1's file scope, but security enforcement disappears from the
merged repository and depends on a transitive package that the manifest does
not promise.

#### Option B — Move the permanent locked-parser validator into T1

Make T1 the owner of:

- exact direct `yaml@2.9.0`;
- its version-3 lockfile resolution/integrity;
- tracked `Validate-WorkflowPolicy.mjs`;
- one stable positive/negative fixture inventory; and
- the exact invocation used locally and in `markdownlint.yml`.

Use strict, single-document YAML 1.2 core parsing; fail on errors **and**
warnings; require string keys; reject duplicate keys, directives, custom tags,
anchors/aliases, merge keys, multi-document streams, and non-JSON-like node
types. T1 validates its own role/input/event/permission policy. T1B updates the
same validator/table/fixtures atomically when it replaces the workflow graph.

Permutations:

- choose exact `yaml@2.9.0`, direct exact `js-yaml`, or another reviewed parser;
  `yaml` exposes a document tree and diagnostics needed for feature rejection
  and has no runtime dependencies;
- keep fixtures as in-module immutable strings or tracked files. In-module
  fixtures keep T1's new-file count low; separate files are easier to inspect.
  Either is valid if each stable case is independently addressable; and
- invoke the validator from the Markdown job and a local npm script, or directly
  with Node. Direct `node Validate-WorkflowPolicy.mjs ...` avoids changing
  public lint script names.

#### Option C — Install an exact parser only in a disposable validation directory

Use `npm install --ignore-scripts --no-save --package-lock=false
yaml@2.9.0` outside the repository, verify the registry integrity, run an exact
temporary verifier, then delete it. This names a version but ordinary evidence
depends on the network and the script remains absent after merge.

#### Option D — Use a runner-provided Python/Ruby YAML parser

Use PyYAML or Ruby Psych already on hosted images. This is convenient but its
availability/version changes with runner images, schema semantics differ, and
the parser is neither locked nor part of the Node toolchain being validated.

#### Option E — Implement a restricted YAML scanner with regex/text rules

Limit accepted workflow syntax and parse indentation/keys manually. This avoids
a dependency but recreates a security-sensitive parser and will mishandle
quoted keys, flow mappings, block scalars, comments, tags, and duplicate-key
semantics.

#### Option F — Rely on GitHub accepting/running the workflow

Use GitHub's workflow parser as the only syntax check and inspect run results.
This is online, cannot run negative fixtures safely, does not expose a stable
AST, and cannot enforce exact role/input/permission multiset policy.

#### Option G — Vendor a standalone parser source file

Commit reviewed parser source under `.github/workflows` and verify its hash.
This is offline and versionable, but transfers patch/license/provenance
maintenance into the repository and makes upstream security updates harder than
a locked direct package.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric is specific to executable
workflow-policy enforcement:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Semantic YAML and policy correctness | 30 | The validator must understand actual YAML structure and fail on ambiguity, not merely match text. |
| Offline reproducibility | 20 | The same workflows/fixtures must produce the same result after a clean locked install without live registry or GitHub state. |
| Policy/enforcement co-versioning | 18 | A workflow policy is only durable when the validator and fixtures merge with the workflow changes. |
| Parser supply-chain control | 12 | Version, integrity, provenance, dependencies, and intentional upgrades need review. |
| Negative-fixture quality | 10 | Missing, duplicate, swapped, dynamic, malformed, and YAML-feature bypasses must each have stable cases. |
| T1B/T3 evolution path | 5 | Later issues should extend one validator rather than replace or fork it. |
| Scope/churn/implementation effort | 5 | Delivery cost counts, but intentionally carries little weight versus permanent correctness. |

### Scored comparison

| Option | Semantics 30 | Offline 20 | Co-version 18 | Supply chain 12 | Fixtures 10 | Evolution 5 | Churn 5 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — temporary transitive parser | 5 | 5 | 2 | 4 | 5 | 3 | 5 | 84.8 |
| B — permanent direct parser in T1 | 5 | 5 | 5 | 5 | 5 | 5 | 2 | **97.0** |
| C — disposable network install | 5 | 3 | 1 | 3 | 4 | 2 | 4 | 66.8 |
| D — runner Python/Ruby parser | 4 | 2 | 1 | 2 | 3 | 1 | 5 | 52.4 |
| E — regex/restricted scanner | 1 | 5 | 1 | 5 | 2 | 2 | 5 | 52.6 |
| F — GitHub run acceptance | 2 | 2 | 1 | 2 | 1 | 1 | 5 | 36.4 |
| G — vendored parser | 4 | 5 | 4 | 2 | 4 | 4 | 2 | 77.2 |

The permanent validator is decisively stronger. The original T1/T1B boundary
would leave a security policy unenforced between merges; adding three affected
files to T1 is justified by the low-weighted churn and much higher
co-versioning/supply-chain scores.

### Selected resolution

Select **Option B — move the permanent locked-parser validator into T1**.

Implement it across T1/T1B/T3 as follows:

1. Expand T1's exact affected files to include:
   - `.github/workflows/Validate-WorkflowPolicy.mjs` — add;
   - `.github/workflows/package.json`; and
   - `.github/workflows/package-lock.json`.
2. Add direct exact `"yaml": "2.9.0"`—no range—to `devDependencies`; update the
   version-3 lockfile with the official resolved tarball/integrity and no
   lifecycle scripts. Re-resolve version/integrity and run the dated audit gate
   immediately before implementation; stop/rebaseline on drift or new policy-
   blocking findings.
3. Implement a pure parser/policy core plus a thin CLI in the tracked
   `Validate-WorkflowPolicy.mjs`. The CLI accepts exactly the two tracked
   workflow paths in canonical order and never fetches the network.
4. Parse one document with strict YAML 1.2 core semantics, string keys, unique
   keys, and precise line information. Treat every parser warning as failure.
   Reject directives, custom/explicit non-core tags, anchors, aliases, merge
   keys, multi-document streams, complex/non-string keys, and non-JSON-like
   values before policy evaluation.
5. Encode T1's complete normative event/job/step/action/input/permission table
   in the issue and validator. Do not let observed YAML define expected counts.
6. Include stable positive and negative fixture records for syntax errors,
   duplicate keys, warnings, aliases/anchors, merge/custom tags, multiple
   documents, missing/extra/swapped roles, mutable/arbitrary action refs, wrong
   annotations, implicit/missing exact inputs, wrong permissions/events/
   conditions, and dynamic/local/remote `uses:` violations.
7. Run the fixture suite and real-workflow validation after the same clean
   `npm ci` and exact Node 24 assertion as lint. Report one result per fixture
   ID and fail on missing/duplicate IDs.
8. Require no network access after `npm ci`; prove the validator does not import
   unlisted packages or invoke child/network processes.
9. Update T1's exact scope and acceptance gates so package/lock changes are
   limited to the one parser and its lock metadata; all other dependency/hook/
   lint policy remains unchanged.
10. Change T1B from “create” to **extend** the same validator, normative table,
    and fixture suite atomically with the final graph. T1B must not add another
    parser or enforcement path.
11. T3 must retain/revalidate the direct parser during dependency remediation,
    update it only through the same reviewed package/audit process, and keep all
    T1/T1B fixtures passing.
12. Add the parser documentation/package and GitHub workflow syntax/security
    references to T1's `References`.

This moves enforcement to the first issue that owns the policy and eliminates
an intentionally untracked interim control.

**Status: selected and ready for incorporation into T1, T1B, and T3.**

The next finding to evaluate is T1-06.

## T1-06 — Make role/input and affected-path checks exact

### Finding and decision constraints

T1 names action repositories/SHAs and role counts but does not make the
security-relevant job, condition, permission, explicit `with:` key set, value,
or reviewed omitted defaults normative. A validator could therefore accept
unsafe defaults or encode whatever implementation happened to choose.

Its affected-file gates also do not require NUL-delimited Git output, and native
commands are described as “classify” without an exact `0`/`1`/error contract.
Pathnames containing whitespace/newlines and a failed diff process must not be
misread as a safe exact set or expected difference.

The resolution must establish one reviewed source of truth for action roles,
values, defaults, permissions, and conditions; make the permanent validator
independent of observed YAML; compare path bytes safely; and preserve native
statuses immediately. Pinned action metadata and Git's `-z`/`--exit-code`
contracts are retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — One normative role table plus structural and byte-safe gates

Add a complete issue table with one row per action/local-callable role and:

- stable role ID and exact count;
- workflow/job/step and `needs`;
- exact `if`, permissions, environment, and external side effects;
- exact action repository/SHA/annotation or local target;
- exact explicitly declared input-key set and values; and
- every security-relevant omitted action default reviewed separately.

Encode the same constant policy in the T1-05 validator. For affected files, use
`git ... --name-only -z`, `git ls-files ... -z`, and
`git status --porcelain=v1 -z`, read stdout as bytes, split only on NUL, and
compare exact byte sets. For `git diff --exit-code`, capture status immediately
and distinguish `0`, `1`, and every other value.

Permutations:

- put values directly in one wide table or use a role table plus per-action
  exact-input tables. The latter is more readable if cross-references are
  one-to-one and machine-checkable;
- implement NUL parsing in a tracked Node helper or an exact PowerShell
  `System.Diagnostics.Process` block reading `StandardOutput.BaseStream`.
  T1 already has a pure workflow validator, so a separately documented
  PowerShell native-process helper avoids giving the YAML parser hidden
  subprocess authority; and
- compare path sets as raw buffers or strict UTF-8. All current allowed paths
  are ASCII; raw-byte equality is the least ambiguous.

#### Option B — Put the policy only in validator constants

Make the tracked validator's JavaScript object the sole expected policy. This
is executable and exact, but reviewers reading the GitHub issue cannot see or
approve the values without reverse-engineering code; implementation defines
policy.

#### Option C — Require a subset of inputs and accept all other defaults/keys

Check only values such as `persist-credentials: false`,
`node-version: '24'`, and artifact path. This is simpler but permits an extra
registry/mirror/cache/SSH/custom path input or an upstream default change to
alter behavior without issue-level review.

#### Option D — Validate action input schemas but not role placement

Check that supplied keys exist in each action's `action.yml` and values have the
right primitive shape. Schema validity does not prove a checkout belongs in the
read-only job, an upload is failure-only, or a token is unavailable elsewhere.

#### Option E — Keep repository/SHA/count allowlisting only

Treat every use of the pinned official action as equivalent. The same action
with a different path, ref, token, cache, artifact, condition, or job permission
can have materially different security behavior, so repository/SHA/count is
insufficient.

#### Option F — Add a general policy engine and schema language

Convert YAML to JSON and enforce OPA/Rego, JSON Schema, or another policy
engine. This can be expressive and testable but adds a second runtime,
dependency/supply chain, policy language, and bootstrap path for a two-workflow
repository.

#### Option G — Rely on manual code review

Include a reviewer checklist but no exact machine gate. This can catch design
issues, but cannot prevent later drift or reliably handle hostile pathname/
native-status cases.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric measures the authority and
completeness of declarative workflow and repository-scope policy:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Reviewed-intent authority | 25 | The issue—not observed implementation—must define the exact policy that code enforces. |
| Security-relevant role/input completeness | 25 | Job placement, conditions, permissions, explicit values, and defaults jointly determine action behavior. |
| Hostile-path correctness | 18 | File-scope equality must survive spaces, tabs, newlines, quoting, renames, and untracked paths. |
| Native-status correctness | 12 | Expected differences and tool execution failures require distinct outcomes. |
| Fixture coverage and evolvability | 10 | Intentional action updates should require atomic policy and negative-test changes. |
| Reviewer/developer clarity | 7 | A cold reader must understand why every action and input is present. |
| Churn and implementation effort | 3 | Table/parser work is low priority compared with enforcing the actual trust boundary. |

### Scored comparison

| Option | Authority 25 | Completeness 25 | Paths 18 | Status 12 | Fixtures 10 | Clarity 7 | Churn 3 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — normative table and exact gates | 5 | 5 | 5 | 5 | 5 | 5 | 3 | **98.8** |
| B — policy only in code | 4 | 5 | 5 | 5 | 5 | 3 | 3 | 91.0 |
| C — subset inputs/defaults | 3 | 3 | 5 | 5 | 3 | 4 | 4 | 74.0 |
| D — action schema only | 2 | 3 | 1 | 2 | 3 | 2 | 3 | 44.0 |
| E — repository/SHA/count only | 2 | 2 | 1 | 1 | 2 | 2 | 5 | 35.8 |
| F — general policy engine | 5 | 5 | 5 | 5 | 4 | 3 | 1 | 92.8 |
| G — manual review | 2 | 2 | 1 | 1 | 1 | 3 | 5 | 35.2 |

Option F is technically powerful but disproportionate; Option A reaches a
higher clarity/evolvability score with the already selected parser and no
second policy runtime.

### Selected resolution

Select **Option A — one normative role table plus structural and byte-safe
gates**.

Implement it in T1 as follows:

1. Add a **Normative T1 workflow-role policy** section. Give every role an ID
   that remains stable through fixtures:
   `build.verify.checkout`, `build.writer.checkout`,
   `build.verify.upload-generated`, `markdown.checkout`, and
   `markdown.setup-node`.
2. For each role, name exact workflow/job/step ID, count `1`, job `needs`,
   literal/expression `if`, job permissions, environment, action SHA/release
   annotation, and allowed side effect.
3. Require checkout roles to declare, at minimum, exact values for
   `repository`, `ref`, `token`, `persist-credentials`, `fetch-depth`,
   `fetch-tags`, `show-progress`, `lfs`, `submodules`, `clean`,
   `set-safe-directory`, and `allow-unsafe-pr-checkout`. Record every omitted
   input/default—SSH, sparse checkout/filter, path, server URL—as reviewed and
   required to remain absent unless the issue policy changes.
4. Require `markdown.setup-node` to declare exact
   `node-version: '24'`, `check-latest: false`,
   `package-manager-cache: false`, and its selected explicit `token` value.
   Require registry, scope, cache, cache-dependency-path, version-file,
   architecture, mirror, and mirror-token inputs to be absent. This explicitly
   reconciles T1-01 with setup-node's `github.token` default.
5. Require `build.verify.upload-generated` to declare exact artifact name,
   four literal generated paths, `if-no-files-found: error`, bounded
   `retention-days`, `compression-level`, `overwrite: false`,
   `include-hidden-files: false`, and the reviewed archive choice. No wildcard
   or directory-wide path is permitted.
6. List reviewed defaults in a separate table with action commit, input,
   upstream default, reason for omission, and security consequence. Prefer
   explicit values for every default whose change could affect identity,
   credentials, caching, transport, overwrite, or path scope.
7. Make the tracked validator's policy constants a literal transcription of
   these issue tables. It must reject missing/extra keys, wrong values,
   expression-versus-literal substitutions, wrong jobs/conditions/permissions,
   duplicate roles, swapped roles, or an action-default drift detected during
   the reviewed upgrade process.
8. Add negative fixtures for each security-relevant key, an unexpected benign-
   looking extra key, missing explicit false, setup-node token/cache changes,
   upload wildcard/directory path, role moved to a write job, and an extra
   `uses:`.
9. Define one exact native-process helper for validation that launches Git with
   an argument array (no command string), redirects stdout/stderr, reads stdout
   from `BaseStream`, and captures `ExitCode` immediately after completion.
10. Calculate working-tree, index, and untracked path sets from NUL-delimited
    Git modes (`--name-only -z`, `ls-files ... -z`, or
    `status --porcelain=v1 -z` with a correctly specified record parser).
    Split bytes only on `00`; reject a missing final NUL, malformed record,
    duplicate path, invalid status, decode ambiguity, or unexpected path.
11. Compare sorted ordinal raw repository-path byte sequences against the exact
    T1 affected-file set. Test spaces, tabs, leading dashes, quotes,
    non-ASCII, and embedded-newline path fixtures in a disposable repository.
    Such paths are not allowed in the expected set, but the parser must report
    them as one unexpected path rather than split or hide them.
12. For every `git diff --exit-code`, map `0` to no difference, `1` to
    difference, and all other statuses to tool failure. Capture
    `$LASTEXITCODE`/`ExitCode` before any formatting, pipeline, cleanup, or
    subsequent native command.
13. Disable external diff/text-conversion where exact native Git comparison is
    required and record Git version/config assumptions.
14. Reuse this table/parser model in T1B. T1B replaces T1's temporary roles
    atomically with its own complete normative table; it must not say final YAML
    determines policy.

**Status: selected and ready for incorporation into T1 and T1B.**

The next finding to evaluate is T1A-01.

## T1A-01 — Complete the public path-input grammar

### Finding and decision constraints

T1A rejects relative, wildcard, multi-match, and non-filesystem paths, but it
does not define null, empty, whitespace-only, non-string, control-character,
malformed, rooted-but-not-fully-qualified, or invalid provider-qualified
inputs. It also uses several public boundaries: five archive-helper paths, one
context-parent path, and two harness script paths.

The helper must fail before filesystem/archive/context work, produce the same
phase/status under Windows PowerShell 5.1 and PowerShell 7, preserve the
intentional positive support for native and `FileSystem::`-qualified absolute
paths, and use the corrected T1 destination vocabulary where semantics overlap.
PowerShell 7-only validation attributes cannot define a 5.1 contract.

Primary parameter-validation evidence is retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Raw scalar boundary plus ordered manual grammar/resolver

Declare each public path input as mandatory `[object]`, then immediately require
its runtime type to be exactly `System.String`. Run one deterministic semantic
resolver per self-contained script:

1. reject null/non-string;
2. reject empty and whitespace-only;
3. reject NUL/control characters and malformed provider/path syntax;
4. reject wildcard syntax;
5. classify native versus provider-qualified form;
6. allow only native fully qualified or exactly `FileSystem::`-qualified
   absolute paths;
7. call the out-parameter unresolved-provider API and require `FileSystem`;
8. normalize exactly once; and
9. continue with existence/type/component/containment checks.

Define one grammar table and stable cases shared by helper, context manager, and
harness. Implementations remain self-contained but must pass cross-script
conformance fixtures.

Permutations:

- preserve `[string]` parameters and add `[AllowNull()]`/manual checks; the
  binder can erase original type distinctions, so `[object]` is stronger where
  exact null/non-string oracles are required;
- use one copied private resolver in all three scripts or have the harness
  invoke each production resolver through public operations. Copying is
  acceptable only with byte/hash and behavior-conformance evidence; and
- distinguish every path parameter with separate IDs or define grammar IDs
  parameterized by boundary/parameter. One row per executable permutation is
  clearest and consistent with the stable-ID requirement.

#### Option B — `[string]` plus 5.1 validation attributes and manual whitespace checks

Use `[ValidateNotNullOrEmpty()] [string]` and manually test whitespace/path
grammar. This is idiomatic and low churn, but binding may convert arrays,
objects, or null before the code can enforce exact raw scalar semantics.

#### Option C — Use `ValidateNotNullOrWhiteSpace`

Apply the modern attribute plus a `ValidateScript` path check. It expresses
basic text rules neatly but is not available in the Windows PowerShell 5.1
common denominator and mixes environment-dependent checks into binding.

#### Option D — Accept any PowerShell path the provider API can convert

Let `GetUnresolvedProviderPathFromPSPath` handle relative/provider syntax and
validate only the returned provider/path. This accepts current-directory-
dependent and provider-internal forms the security model says to reject.

#### Option E — Narrow support to native fully qualified paths only

Reject all PowerShell provider-qualified syntax. This is the smallest and least
ambiguous grammar and would be secure, but removes an explicitly promised
public input form and the P-02/S-11 positive cases without a usability/security
need.

#### Option F — Accept only a trusted pre-normalized context object

Remove raw paths from the archive helper and require the context manager to
return normalized values. This simplifies one API but violates the requirement
that the archive helper independently distrust the caller/context and leaves
the harness/context-manager inputs unresolved.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric is specific to raw
PowerShell parameter classification:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Input-taxonomy completeness | 28 | Every raw type/text/path class needs one deterministic accepted or rejected state. |
| PowerShell 5.1/7 binding parity | 22 | Parameter conversion and validation must not change the public result between editions. |
| Fail-before-side-effect ordering | 20 | Bad public input must create no context, directory, archive stream, or candidate state. |
| Filesystem/provider security | 15 | Only deterministic fully qualified FileSystem paths may reach .NET APIs. |
| Stable diagnostic/test semantics | 10 | Every grammar class needs exact phase, status, and unchanged-state evidence. |
| Caller usability | 3 | Native and intentionally supported provider-qualified paths should remain understandable. |
| Churn | 2 | Signature/test changes are intentionally much less important than exact classification. |

### Scored comparison

| Option | Taxonomy 28 | Edition parity 22 | No side effect 20 | Path security 15 | Diagnostics 10 | Usability 3 | Churn 2 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — raw scalar plus ordered resolver | 5 | 5 | 5 | 5 | 5 | 4 | 3 | **98.6** |
| B — string/attributes/manual | 3 | 5 | 4 | 5 | 3 | 5 | 5 | 80.8 |
| C — modern whitespace attribute | 5 | 1 | 5 | 5 | 5 | 5 | 4 | 82.0 |
| D — accept provider conversion | 2 | 4 | 2 | 2 | 2 | 5 | 5 | 51.8 |
| E — native absolute only | 5 | 5 | 5 | 5 | 5 | 3 | 3 | 98.0 |
| F — trusted context object only | 3 | 5 | 3 | 4 | 3 | 3 | 2 | 71.4 |

Option E is secure but needlessly breaks two intentional positive interfaces.
Option A retains those forms while scoring slightly higher through explicit
taxonomy and diagnostic behavior.

### Selected resolution

Select **Option A — raw scalar boundary plus ordered manual grammar/resolver**.

Implement it in T1A as follows:

1. Add a normative path-parameter table listing each public boundary and
   parameter:
   - archive helper: `CheckoutRoot`, `TrustedTemporaryRoot`,
     `DownloadDirectory`, `CandidateDirectory`, and the retained archive path
     derived from exact enumeration;
   - context creation: runner-controlled temporary parent;
   - context cleanup: every explicit owned path;
   - harness: `HelperPath` and `ContextManagerPath`.
2. For caller-supplied paths, preserve the raw value as `[object]`; before any
   other operation require exact scalar `System.String`. Do not enumerate or
   join collection input.
3. Apply the same ordered grammar:
   - null → `parameter/path-null`;
   - non-string scalar or collection → `parameter/path-type`;
   - empty → `parameter/path-empty`;
   - Unicode whitespace-only → `parameter/path-whitespace`;
   - NUL/C0/C1 control or malformed provider syntax →
     `parameter/path-malformed`;
   - unescaped PowerShell wildcard grammar →
     `parameter/path-wildcard`;
   - relative, drive-relative, root-relative, or otherwise non-fully-qualified
     → `parameter/path-not-fully-qualified`;
   - unsupported/non-filesystem provider → `parameter/path-provider`.
4. Accept only:
   - a platform-native fully qualified filesystem path; or
   - exactly one `FileSystem::`-qualified fully qualified path.
   Reject aliases/custom PSDrives unless the issue explicitly defines and tests
   their trust/normalization semantics. Do not accept `~`.
5. Use `GetUnresolvedProviderPathFromPSPath` with provider/drive out values;
   require `FileSystem`; then normalize once. Because wildcards are rejected and
   this API returns one unresolved string, remove “multiple resolution” from
   the API description. Keep a negative fixture proving that use of a resolving
   multi-match API is prohibited, rather than pretending the selected API
   returns a collection.
6. After grammar, run the existing per-parameter existence/type/component/
   containment checks in the published phase order. Preserve the raw safe label
   and normalized path separately for diagnostics.
7. For every grammar rejection, assert: nonzero stable status, exact parameter
   phase/subreason, no context/directory/archive/candidate creation, no cleanup
   attempt for unowned state, and unchanged outside sentinel.
8. Expand the permanent table with one row per raw grammar class at each public
   script boundary. At minimum, execute all classes against one path in each
   production script and execute null/empty/whitespace/non-string independently
   for every public path parameter to catch binding drift.
9. Keep P-02 and S-11 as positive native-versus-`FileSystem::` equivalence
   cases, but give them exact final results under T1A-03.
10. Compare T1/T1A/P1A grammar rows semantically. T1's artifact destinations
    intentionally use an exact four-path allowlist; T1A accepts a broader
    trusted-root envelope, but raw type/provider/absolute/wildcard semantics
    should match.

**Status: selected and ready for incorporation into T1A.**

The next finding to evaluate is T1A-02.

## T1A-02 — Publish the exact context schema and disposed-state contract

### Finding and decision constraints

T1A says context creation returns a “structured context containing” several
values, and C-02 expects repeated teardown to be a no-op under a
“disposed-context contract.” It does not name fields, types, lifecycle states,
mutation rules, journal schema, or the difference between disposed, uncertain,
and malformed contexts. An implementation could infer disposal from a missing
directory and accidentally treat substitution/deletion by another actor as safe
prior cleanup.

The resolution must make cleanup authorization explicit, reject forged/
malformed/missing state without deletion, preserve the primary failure, support
same-process Windows PowerShell 5.1/PowerShell 7 callers, give C-02 an exact
oracle, and preserve enough evidence for uncertain-state recovery.

### Resolution options

#### Option A — Versioned `PSCustomObject` schema with an explicit state machine

Return one object whose first `PSTypeName`, exact property names/types, schema
version, context ID, normalized paths, journal entries, lifecycle state, and
diagnostic metadata are normative. Validate the complete schema on every
cleanup call.

Use closed states:

- `Active`;
- `CleanupInProgress`;
- `Disposed`; and
- `RetainedUncertain`.

Only an already valid `Disposed` context returns success/no-op. `Active` can
transition through cleanup to `Disposed`; any uncertain ownership/cleanup state
transitions to `RetainedUncertain`. An input already marked
`CleanupInProgress` or `RetainedUncertain` causes no deletion and returns a
stable retained-state failure. Missing/invalid state is not “already clean.”

Permutations:

- mutate the same context in place or return a replacement context. In-place
  mutation makes an immediate repeated call simple and preserves caller
  identity; return it as well for explicit consumption;
- store a strongly typed generic list or a fixed `[object[]]` of exact journal
  records. The latter serializes more easily, while the former catches local
  type drift; exact entry validation is required either way; and
- retain normalized paths after disposal or scrub them. Retain them for
  identity/evidence but prohibit all future filesystem action; state and a
  cleanup summary—not path absence—authorize the no-op.

#### Option B — Define a PowerShell class

Create `StyleGuideCandidateInvocationContext` and a journal-entry class with
typed properties/methods. This gives compile-time shape, but PowerShell class
definitions are awkward to reload/dot-source in the permanent harness, can
collide across editions/sessions, and do not eliminate the need to revalidate
filesystem ownership.

#### Option C — Use a hashtable with required keys

Return a hashtable and validate key sets/types. It is portable and easy to
construct but unordered/loosely typed, easy for callers to modify, and less
discoverable than a named object contract.

#### Option D — Return an opaque token and keep context in process-global storage

Map a random token to private state inside the context-manager script. This
reduces caller mutation but breaks across child processes, complicates
teardown after exceptions, introduces global lifetime/concurrency state, and
does not fit local reusable workflow invocations.

#### Option E — Use immutable state objects and return a new object per transition

Never mutate a context; cleanup returns a separate disposed/retained record.
This is theoretically clean, but a caller that accidentally reuses the original
Active object could attempt cleanup again. Preventing that requires a registry
or consumed-token mechanism.

#### Option F — Infer disposal from absence of the invocation root

If the root no longer exists, return success/no-op. This confuses successful
cleanup with external deletion, missing/unreadable state, or path substitution
and contradicts fail-closed ownership rules.

#### Option G — Add only an `IsDisposed` Boolean

Mutate `IsDisposed` after cleanup. This makes C-02 easy but cannot distinguish
cleanup in progress, retained uncertainty, malformed objects, or why disposal
is trustworthy.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric focuses on lifecycle
authority and cleanup state:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Deletion authorization and malformed-context safety | 28 | Context metadata can guide cleanup only after exact schema and current filesystem ownership are both validated. |
| State-transition/idempotence precision | 22 | Active, in-progress, disposed, and uncertain states must have one legal transition/result each. |
| PowerShell 5.1/7 process compatibility | 15 | The object must work in both editions and the harness's dot-source/child invocation model. |
| Failure preservation and recovery evidence | 15 | Primary failures and retained paths/journal entries must survive cleanup trouble. |
| Exact schema/testability | 12 | Cases need field/type/state/order oracles and mutation/second-call assertions. |
| Caller usability | 5 | A new developer should be able to inspect and pass the context correctly. |
| Churn/complexity | 3 | More schema code is acceptable when it prevents unsafe deletion. |

### Scored comparison

| Option | Safety 28 | State 22 | Compatibility 15 | Recovery 15 | Tests 12 | Usability 5 | Churn 3 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — versioned object/state machine | 5 | 5 | 5 | 5 | 5 | 4 | 3 | **97.8** |
| B — PowerShell classes | 5 | 5 | 3 | 4 | 4 | 3 | 1 | 84.2 |
| C — hashtable schema | 3 | 4 | 5 | 4 | 4 | 4 | 5 | 78.0 |
| D — opaque token/global registry | 5 | 5 | 3 | 3 | 3 | 1 | 1 | 76.8 |
| E — immutable replacement contexts | 5 | 5 | 4 | 4 | 4 | 2 | 2 | 86.8 |
| F — infer from path absence | 1 | 1 | 5 | 1 | 2 | 4 | 5 | 39.8 |
| G — Boolean only | 2 | 3 | 5 | 2 | 3 | 5 | 5 | 60.6 |

Option A gives the clearest cold-reader and harness contract while remaining
portable. Its object is not a security token; the selected resolution still
requires full filesystem revalidation before deletion.

### Selected resolution

Select **Option A — versioned `PSCustomObject` schema with an explicit state
machine**.

Implement it in T1A as follows:

1. Define the context's first `PSTypeName` exactly as
   `TerraformStyleGuide.StyleGuideCandidateInvocationContext.v1`.
2. Define this exact ordered property schema:

   | Property | Exact type/initial value | Purpose |
   | --- | --- | --- |
   | `SchemaVersion` | `[uint32]1` | Reject incompatible context layouts. |
   | `ContextId` | nonempty `[guid]` | Diagnostic/correlation identity only. |
   | `LifecycleState` | `[string]'Active'` | Closed state-machine authority. |
   | `TemporaryParentPath` | normalized nonempty `[string]` | Revalidated runner-controlled parent. |
   | `InvocationRootPath` | normalized nonempty `[string]` | Exact created root. |
   | `DownloadDirectoryPath` | normalized nonempty `[string]` | Exact created download directory. |
   | `CandidateDirectoryPath` | normalized nonempty `[string]` | Exact absent candidate leaf at creation. |
   | `DiagnosticLabel` | nonempty `[string]` | Safe correlation only; never ownership. |
   | `OwnershipJournal` | exact `[object[]]` | Ordered v1 journal entries defined below. |
   | `CleanupSummary` | `$null` initially; exact object after attempt | Stable final/retained evidence. |

3. Define each journal record's first `PSTypeName` as
   `TerraformStyleGuide.StyleGuideCandidateOwnershipEntry.v1`, with exact
   `Sequence [uint32]`, `Kind [string]` (`File` or `Directory`), normalized
   `Path [string]`, `Acquisition [string]`, and `Owned [bool]`. Sequence values
   are unique/contiguous and cleanup order is explicitly deepest-first then
   descending sequence.
4. Context creation journals only entries it actually acquires. At return,
   journal the invocation root and download directory as owned ordinary
   directories; `CandidateDirectoryPath` is an expected absent leaf and is not
   owned merely because its path was chosen.
5. On cleanup entry, validate exact PSTypeName, property set (no missing or
   extra properties), types, schema version, closed state, unique context ID,
   journal schema/order, path relationships, and current filesystem envelope.
   Treat the object as untrusted despite its type name.
6. Define transitions:
   - valid `Active` → `CleanupInProgress` before the first deletion;
   - successful complete cleanup → `Disposed`;
   - any ownership, inspection, deletion, or summary failure before complete
     disposal → `RetainedUncertain`;
   - valid `Disposed` → `Disposed` success/no-op with zero filesystem calls;
   - `CleanupInProgress` or `RetainedUncertain` on entry → stable nonzero
     retained-state result with zero deletion attempts;
   - missing/unknown/invalid state → invalid-context failure with zero
     filesystem calls.
7. Do not set `Disposed` merely because a path is absent. Set it only after the
   cleanup function itself validates and removes every owned entry and proves
   the invocation root absent.
8. `CleanupSummary` after success contains exact context ID, prior/final state,
   attempt count, ordered removed paths, retained paths (empty), primary-failure
   presence, and cleanup result. On uncertainty it contains the offending path/
   reason, removed-before-failure paths, retained journal, primary failure, and
   cleanup failure without secret content.
9. Mutate and return the same context object. Callers must replace their
   reference with the returned object anyway, making the data flow explicit.
10. Update C-01: exact transition Active→CleanupInProgress→Disposed, journal
    removed in defined order, summary exact.
11. Update C-02: pass the same valid Disposed object again; return success,
    state/summary/path fields byte/value-identical, zero enumeration/deletion
    calls, outside sentinel unchanged.
12. Add cases for every missing/extra/wrong-type property, wrong PSTypeName/
    schema, empty GUID, invalid state, altered journal, cleanup-in-progress
    reentry, retained-uncertain reentry, and a syntactically forged Disposed
    object. A schema-valid Disposed object is a no-op and never authorizes
    deletion; document that this return describes the supplied object and is
    not external proof that historical cleanup occurred. C-02 additionally
    proves `[object]::ReferenceEquals` with the object returned by the first
    production cleanup in the supported same-process model.
13. State clearly that context metadata is not cryptographic authorization.
    Every Active cleanup still independently revalidates ordinary-file
    ownership and retains uncertain state.

**Status: selected and ready for incorporation into T1A.**

The next finding to evaluate is T1A-03.

## T1A-03 — Give every listed case a final exact oracle

### Finding and decision constraints

T1A now lists stable IDs, but several rows stop at an intermediate state
(`proceeds`, `manifest passes`, `content oracle continues`), name only a
platform comparison rule, group distinct fixtures, or allow alternative phases
(`applicable path phase`, `native binding or parameter`). The global default
postcondition does not determine a final success/failure/skip, exact subreason,
context lifecycle, or emitted-record count for those rows.

The resolution must give every executable fixture one stable ID and exactly one
final result on every applicable platform/edition. The issue table and
machine-readable harness metadata must agree, resource-boundary success cases
must run through post-extraction and both cleanups, and a future case may be
appended without changing an existing ID's meaning.

### Resolution options

#### Option A — Canonical one-row table with fixed final-oracle columns

Replace the three-column table with one row per executable fixture and fixed
columns:

- ID and applicability;
- exact fixture;
- final result (`pass`, `fail`, or `skip`);
- terminal phase/subreason and process status;
- candidate state before caller teardown;
- caller-context state before harness teardown;
- required diagnostic keys;
- outside-sentinel state; and
- production cleanup calls/order.

No cell may say “continues,” “proceeds,” “applicable,” “or,” or contain two
fixtures. Every successful boundary case uses a complete valid archive and ends
with four validated files plus successful candidate/context cleanup. Split
grouped rows by appending new IDs while preserving the original ID for one
meaning. Mirror the table as immutable harness metadata and compare the two
during review.

Permutations:

- put repeated unchanged-sentinel/no-unproved-deletion states in normative
  defaults and show explicit deltas. For maximum auditability, retain explicit
  compact state tokens in every row even when prose definitions are shared;
- make process status uniformly `0`/`1` or assign distinct nonzero codes. The
  current public contract uses nonzero failure; retain one exact nonzero value
  per phase if multiple codes are not already a documented interface; and
- represent expected states as strings or structured enums in harness
  metadata. Structured enums reduce spelling drift.

#### Option B — Keep the table compact and rely on global default oracles

Define broad rules such as “unless stated, all failures leave candidate absent”
and leave intermediate wording. This reduces duplication but still requires a
reviewer to infer whether a boundary case ultimately succeeds and which cleanup
ran.

#### Option C — Split every phase transition into a separate test case

Create separate IDs for “manifest passed,” “extraction passed,” “post-check
passed,” and “cleanup passed.” This gives precise diagnostics but multiplies
fixtures and can prove isolated stages without proving one end-to-end lifecycle.

#### Option D — Make an executable JSON/PowerShell manifest the sole oracle

Put complete fixture/result objects in the harness and generate documentation
from them. This is highly deterministic, but the GitHub issue no longer
independently reviews the security contract and prompt handoff becomes
code-dependent.

#### Option E — Replace the table with per-case prose narratives

Explain each scenario in paragraphs. This is readable for a few cases but hard
to compare, machine-check, count, and keep append-only across roughly one
hundred cases.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric focuses on executable
oracle precision:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Final-result determinism | 30 | One invocation must have one terminal result, phase/subreason, and status with no reviewer inference. |
| Complete resource/lifecycle state | 22 | Candidate, context, cleanup, diagnostics, and outside sentinels must all have postconditions. |
| Platform/boundary precision | 15 | Windows/Linux and below/exact/above cases must state which pass or fail. |
| Issue-to-harness synchronization | 15 | Human-reviewed rows and executable metadata must be provably equivalent. |
| Debugging/documentation usability | 10 | A failing ID should immediately tell a new developer what diverged. |
| Stable evolution | 5 | IDs need one durable meaning and append-only growth. |
| Table/test churn | 3 | Duplication cost is deliberately low-weighted versus proof completeness. |

### Scored comparison

| Option | Determinism 30 | State 22 | Platforms 15 | Sync 15 | Usability 10 | Evolution 5 | Churn 3 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — fixed final-oracle table | 5 | 5 | 5 | 5 | 5 | 5 | 2 | **98.2** |
| B — global defaults/inference | 3 | 4 | 4 | 4 | 3 | 4 | 5 | 72.6 |
| C — case per phase | 5 | 5 | 5 | 4 | 4 | 3 | 1 | 90.6 |
| D — executable manifest only | 5 | 5 | 5 | 5 | 3 | 4 | 2 | 93.2 |
| E — prose narratives | 2 | 2 | 2 | 1 | 4 | 2 | 4 | 43.2 |

Option A combines the determinism of executable metadata with an independently
reviewable issue contract.

### Selected resolution

Select **Option A — canonical one-row table with fixed final-oracle columns**.

Implement it in T1A as follows:

1. Define enums/tokens in prose and harness metadata:
   - result: `pass`, `fail`, `skip`;
   - process status: exact `0` for pass and exact selected nonzero status for
     harness/helper failure;
   - phase/subreason: closed values such as
     `parameter/path-null`, `containment/case-mismatch`,
     `manifest/declared-entry-limit`, `extraction/actual-total-limit`;
   - candidate state: `absent`, `four-valid-files`, `owned-partial-removed`,
     `preexisting-unchanged`, or `uncertain-retained`;
   - context state: the T1A-02 lifecycle states; and
   - cleanup sequence: exact candidate cleanup and then context cleanup calls.
2. Give every row the fixed columns listed in Option A. Use compact enum tokens,
   not vague prose. A nonapplicable OS cell is not an emitted result; the
   harness inventory declares applicability and expected count.
3. Correct E-07:
   - applicability Windows only;
   - case-only variation within the same existing path envelope;
   - final `pass`, status `0`, phase `complete`;
   - four valid files, candidate cleanup success, context `Disposed`, sentinel
     unchanged.
4. Correct E-08:
   - applicability Linux only;
   - differently cased sibling path outside the trusted root;
   - final `fail`, selected nonzero status,
     `containment/case-sensitive-outside`;
   - candidate absent, context remains Active until successful context cleanup,
     then Disposed; sentinel unchanged.
5. Make every accepted boundary run end-to-end:
   - R-01 (entry 8 MiB − 1), R-02 (entry exactly 8 MiB), R-05 (declared total
     32 MiB − 1), R-06 (declared total exactly 32 MiB), R-09 (archive exactly
     32 MiB), and R-13 (archive 32 MiB − 1) all use valid ASCII/LF/BOM-less
     payloads, finish post-extraction, produce four exact ordinary files, and
     complete both production cleanups with status `0`.
   - R-03/R-04/R-07/R-08/R-10 retain their exact named failure phase and final
     candidate/context states.
6. Replace `applicable path phase`:
   - E-10 below-root reparse → `containment/component-reparse`;
   - E-14 becomes checkout-root missing → `root/checkout-missing`;
   - E-15 becomes checkout-root wrong type → `root/checkout-not-directory`;
   - append separate IDs for missing/wrong-type trusted root, download
     directory, archive file, candidate parent, helper path, and context path.
7. Reconcile “multiple resolution” with T1A-01:
   - E-13 and S-04/S-09 use a wildcard-bearing path that would match multiple
     entries under a resolving API;
   - final failure is `parameter/path-wildcard` or
     `harness-input/path-wildcard` before resolution/context creation;
   - static policy proves production code never calls a resolving/multi-match
     API.
8. Give every S row exact final data:
   - S-01/S-06 `harness-input/script-missing`;
   - S-02/S-07 `harness-input/path-wildcard`;
   - S-03/S-08 `harness-input/path-provider`;
   - S-04/S-09 the multi-match-capable wildcard rejection above;
   - S-05 is reparse helper and S-10 reparse context manager,
     `harness-input/script-reparse`;
   - append separate IDs for untracked ordinary helper and context-manager
     files;
   - all fail nonzero before context creation, invoke neither supplied script,
     emit one record, and leave sentinel unchanged;
   - S-11 uses exact tracked/versioned scripts and continues through one named
     valid end-to-end control with final pass/Disposed state.
9. Split X-08/X-09/X-10:
   - keep each existing ID for array input;
   - append one ID for object input for each label;
   - manual raw-value validation yields
     `parameter/label-not-scalar-string`, no filesystem work, candidate absent,
     and exact context state. Remove “native binding or” alternatives.
10. Audit every remaining row—not only those named by the finding—for
    `or`, slash-combined fixtures, `applicable`, `continues`, `proceeds`,
    missing status, or missing cleanup/context/sentinel fields. Split or rewrite
    until the audit returns none.
11. Store the complete expected record for each ID in harness metadata. At
    startup compare the applicable ID set with executed fixtures; at completion
    require exactly one record per applicable ID and zero records for
    nonapplicable IDs. Fail for missing, duplicate, unexpected, or changed
    expected fields.
12. Retain skip as a result only for the narrow primitive-availability rule:
    exactly one record, explicit platform/reason, no fixture pass credited, and
    at least one real link rejection on each OS family.
13. In reciprocal P1A/T1A evidence, compare semantic IDs only after the P and T
    rows each have the same fixed fields. An equal ID with different fixture or
    oracle is a blocker under T1A-04.

**Status: selected and ready for incorporation into T1A.**

The next finding to evaluate is T1A-04.

## T1A-04 — Align reciprocal stable-ID meanings

### Finding and decision constraints

The current P1A and T1A drafts reuse short IDs/ranges without proving identical
fixtures and final oracles. At least one visible collision already differs:
P1A's grouped K-03 coverage refers to a caller unknown child, while T1A K-03 is
repeated candidate cleanup. An ID is not stable across repositories if the same
text names different behavior.

Only Terraform issues may be edited in this task. The resolution must avoid
claiming P convergence before P1A has one exact row per case, keep both
repositories self-contained, permit repository-specific manifests/paths, and
give future evidence an immutable identifier after filing/implementation.

### Resolution options

#### Option A — Repository-namespaced local IDs plus shared semantic case keys

Before filing, namespace every Terraform candidate case as
`T1A-<family>-<number>`. Add a globally meaningful `SemanticCase` key such as
`candidate.valid.exact-manifest` to every issue/harness record.

The reciprocal matrix maps:

```text
SemanticCase ↔ exact P local ID/commit/oracle ↔ exact T1A ID/commit/oracle
```

A semantic key is shared only when fixture, applicability, terminal result,
phase/subreason, resource state, diagnostics, and cleanup are equal. Otherwise
use separate keys and record an intentional repository difference, or mark a
blocker. Existing current-draft T IDs may be renamed now because they have not
been filed/implemented; after merge, IDs and semantic keys are append-only.

Permutations:

- prefix with repository (`T-`) or issue layer (`T1A-`); issue-layer prefix is
  globally clearer when artifacts contain results from multiple layers;
- use descriptive dotted keys or UUIDs. Dotted semantic names are reviewable;
  commit plus local ID supplies immutable evidence without opaque UUIDs; and
- let identical cases use the same numeric suffix. This helps visual comparison
  but is not required and must never override semantic correctness.

#### Option B — Force identical local IDs/catalogs in P1A and T1A

Define one exact catalog and require both repositories to use it verbatim,
adding repository-only suffixes. This maximizes symmetry but cannot be completed
by editing Terraform alone and forces irrelevant manifest/path cases into each
repository.

#### Option C — Keep current short IDs and add only a reciprocal mapping table

Map P K-03 and T K-03 to different meanings in the evidence. This documents the
collision but leaves logs/searches ambiguous and violates “one meaning per
stable ID.”

#### Option D — Prefix every Terraform ID but omit semantic keys

`T1A-K-03` and `P1A-K-03` become unambiguous. However, reviewers still need
free-form rationale to determine which differently named cases should be equal,
and automated reciprocal coverage is harder.

#### Option E — Generate both catalogs from one shared package/file

Use a cross-repository schema/package as the source of IDs. This prevents
catalog drift but introduces the runtime/availability/supply-chain dependency
the slates reject and complicates repository-specific cases.

#### Option F — Drop stable IDs and use descriptive test names

Long names are readable, but wording changes break historical evidence,
machine counts, and issue-to-harness mapping.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric evaluates identity and
cross-repository traceability:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Globally unambiguous case identity | 25 | A log/result ID must refer to one behavior even when P and T evidence is combined. |
| Reciprocal semantic correctness | 25 | Equality requires complete fixture/oracle equivalence, not similar numbering. |
| Append-only historical stability | 15 | Once implemented, evidence and failures must remain searchable under the same identity. |
| Commit/evidence traceability | 15 | A matrix row must resolve to exact issue/harness rows and commits on both sides. |
| Repository independence | 10 | Convergence must not create shared runtime or release coupling. |
| Reviewer usability | 7 | Names and mappings should be understandable without memorizing catalogs. |
| Renaming/mapping churn | 3 | Pre-filing churn is low priority versus eliminating durable collisions. |

### Scored comparison

| Option | Identity 25 | Semantics 25 | Stability 15 | Traceability 15 | Independence 10 | Usability 7 | Churn 3 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — namespaced ID plus semantic key | 5 | 5 | 5 | 5 | 5 | 5 | 2 | **98.2** |
| B — forced identical catalogs | 4 | 5 | 3 | 4 | 4 | 5 | 2 | 82.2 |
| C — mapping with colliding IDs | 2 | 3 | 4 | 4 | 5 | 3 | 5 | 66.2 |
| D — prefix only | 5 | 3 | 5 | 4 | 5 | 4 | 3 | 84.4 |
| E — shared package/catalog | 5 | 5 | 5 | 5 | 1 | 3 | 1 | 86.8 |
| F — descriptive names only | 2 | 2 | 1 | 2 | 5 | 4 | 4 | 47.0 |

Option A provides both collision-free local evidence and an enforceable concept
of semantic equality.

### Selected resolution

Select **Option A — repository-namespaced local IDs plus shared semantic case
keys**.

Implement it in T1A as follows:

1. Before filing/implementation, prefix every current Terraform case ID with
   `T1A-`: for example, `V-01` becomes `T1A-V-01`, `K-03` becomes
   `T1A-K-03`, and every new split case from T1A-03 follows the same form.
   The final issue presents only the namespaced IDs; it need not discuss draft
   renaming.
2. Add exact `SemanticCase` to every issue-table row and harness record. Use a
   documented lowercase dotted grammar:
   `^[a-z][a-z0-9]*(\.[a-z][a-z0-9-]*)+$`.
3. Choose descriptive keys based on behavior, not implementation, such as:
   - `candidate.valid.exact-manifest`;
   - `candidate.path.checkout-sibling-prefix`;
   - `candidate.cleanup.repeated-disposed-noop`;
   - `context.cleanup.unjournaled-entry-retained`; and
   - `candidate.limit.entry-declared-above`.
4. Require local `Id` and `SemanticCase` each to be unique, nonempty, present in
   issue metadata, and emitted exactly once per applicable case. Neither may be
   changed or reused after the issue merges; append new cases.
5. Define reciprocal equality as exact equality of semantic key, fixture
   preconditions, applicability, result, terminal phase/subreason/status,
   candidate/context states, diagnostics, sentinel, and cleanup sequence.
6. Build the P1A↔T1A matrix with columns:
   `SemanticCase`, P commit/local ID/evidence, T commit/local ID/evidence,
   classification, and rationale.
7. If current P1A supplies only a grouped range or a colliding/different ID,
   classify the row `blocker`; do not invent its final P oracle. T1A can merge
   only after the reviewed P counterpart exposes an exact row or the matrix
   records a justified repository-specific semantic key/difference permitted by
   both issues.
8. Repository-specific manifest filenames/bytes use the same semantic key only
   when “exact repository manifest” is the abstraction being compared and all
   security/result semantics match. Otherwise use repository-qualified keys.
9. Add fixtures that reject duplicate local IDs, duplicate semantic keys,
   changed mappings, an equal semantic key with different expected fields, a
   missing counterpart classification, and an intentional difference with no
   rationale.
10. Keep the catalogs and matrix in tracked issue/PR evidence and immutable
    commits. Do not fetch or execute code from the other repository at runtime.

This resolves the existing short-ID collision on the Terraform side and makes
any incomplete P catalog an explicit evidence blocker rather than an assumed
endorsement.

**Status: selected and ready for incorporation into T1A.**

The next finding to evaluate is T1B-01.

## T1B-01 — Correct the checkout/push credential boundary

### Finding and decision constraints

T1B repeats T1's false claim that credentials exist only for one exact push.
Its final writer has `contents: write`; GitHub creates that job's token before
the job, the pinned checkout uses it for fetch, and actions can access
`github.token` from execution steps. `persist-credentials: false` removes Git
configuration after checkout but does not make the write-capable job or fetch
token-free.

The resolution must preserve exact trusted source/candidate identity,
at-use regeneration, ref/SHA/lease checks, and one push path while accurately
describing what workflow YAML can constrain. It must avoid adding a PAT,
GitHub App, or other credential unless that materially improves the selected
trust boundary enough to justify new secret/supply-chain operations.

T1-01 research and its selected explicit-action-token vocabulary apply, but
this finding uses a separate final-writer rubric.

### Resolution options

#### Option A — Honest job-token boundary with an exact write-job allowlist

Retain `GITHUB_TOKEN` and the one writer job. State:

- a job token exists for the duration of every job;
- only the writer job receives `contents: write`;
- checkout receives it transiently for fetch and removes persisted auth;
- all write-job actions/local code are exact allowlisted trusted roles; and
- only the final guarded push step explicitly constructs process-scoped Git
  push authorization.

The policy validator enforces exact token-consuming action inputs, permissions,
step conditions/order, post-checkout auth absence, and push-header placement.
Diagnostics receive no explicit token/header/config environment, but the issue
does not claim the job token object is absent.

#### Option B — Pass a prepared trusted source artifact into a checkout-free writer

Have a read-only preparation job upload the trusted repository source/tree and
candidate; the write job downloads it, regenerates, and pushes without
`actions/checkout`. The job token still exists, and recreating a Git repository/
object/ref/remote for the exact lease adds a second artifact transport and
identity protocol.

#### Option C — Mint a GitHub App installation token only near push

Give the job read-only `GITHUB_TOKEN`, then use a registered GitHub App private
key to mint a short-lived write token at the approval/push boundary. This can
separate read and write credentials more strongly, but requires a new secret,
app installation, token-generation action/code, rotation, incident response,
and an additional trusted supply chain explicitly outside current scope.

#### Option D — Use a fine-grained PAT/deploy credential

Store a write credential as a repository/environment secret and expose it only
to the push step. This may make explicit expansion narrower, but the long-lived
secret has broader lifecycle/rotation risk and does not remove the job's
ordinary `GITHUB_TOKEN`.

#### Option E — Persist checkout authentication and reuse it

Let checkout configure write-capable auth for all later Git commands. This
simplifies push but maximizes credential lifetime, makes diagnostics/preflight
implicitly authenticated, and hides the exact write boundary.

#### Option F — Fetch the public repository without auth, then bind token at push

Replace checkout with unauthenticated Git commands/archive acquisition in the
writer. This can make explicit fetch token-free for the current public repo,
but loses checkout's reviewed ref/fork behavior, fails if repository visibility
changes, and expands manual source-integrity logic.

#### Option G — Write through the GitHub Contents/Git Data REST API

Use one API call/sequence instead of `git push`. This changes commit/tree/ref
construction and lease semantics, can require multiple API operations, and
does not eliminate the job token; it also diverges from P1B's reviewed writer.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric emphasizes authority in a
write-capable final job:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Write-authority containment | 25 | Only the minimum job/step/process should be able to turn reviewed bytes into a branch update. |
| Factual credential-lifecycle accuracy | 20 | The issue and validator must never certify absence when GitHub/action behavior provides a token. |
| Source/candidate/at-use identity preservation | 20 | Credential changes cannot weaken commit, artifact, four-hash, regeneration, tree, or lease proofs. |
| New secret/supply-chain burden | 15 | PAT/App/token actions create rotation, compromise, ownership, and availability risks. |
| Structural/runtime verifiability | 10 | Permissions, inputs, auth removal, environment expansion, and push placement need deterministic fixtures. |
| Lease/failure recovery behavior | 5 | Stale refs and push failures must remain fail-closed and diagnosable. |
| Churn/implementation effort | 5 | Cost matters, but is below security truth and immutable identity. |

### Scored comparison

| Option | Containment 25 | Truth 20 | Identity 20 | Secret burden 15 | Verification 10 | Lease 5 | Churn 5 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — honest token/allowlist boundary | 4 | 5 | 5 | 5 | 5 | 5 | 4 | **94.0** |
| B — source artifact to writer | 4 | 5 | 4 | 5 | 4 | 4 | 2 | 85.0 |
| C — GitHub App token | 5 | 5 | 5 | 2 | 4 | 5 | 1 | 85.0 |
| D — PAT/deploy credential | 2 | 4 | 5 | 1 | 3 | 5 | 3 | 63.0 |
| E — persist checkout auth | 1 | 2 | 5 | 4 | 2 | 5 | 5 | 59.0 |
| F — unauthenticated manual fetch | 5 | 5 | 3 | 4 | 4 | 4 | 2 | 83.0 |
| G — REST-based writer | 3 | 5 | 4 | 4 | 3 | 1 | 2 | 72.0 |

Option A preserves the strongest existing identity/lease design without adding
a long-lived secret or pretending the job token can be created only at a
single step.

### Selected resolution

Select **Option A — honest job-token boundary with an exact write-job
allowlist**.

Implement it in T1B as follows:

1. Set workflow-level `permissions: {}`. Give every verification/preparation/
   matrix/approval/Markdown job only its exact required read permissions; give
   only the final writer job `contents: write`.
2. State that GitHub creates a unique job token before each job and that
   `github.token` is available during execution steps. Do not use “no token,”
   “credentials exist only at push,” or “credential-free job.”
3. Require the writer checkout to explicitly declare
   `token: ${{ github.token }}` and `persist-credentials: false` plus the full
   exact T1B-02 input set. State that fetch is authenticated with the
   write-capable job token.
4. Immediately after checkout, run a presence-only check that origin URLs,
   credential helpers, and local/global HTTP authorization configuration do
   not contain persisted credentials. Do not print any value.
5. Name every action/local step allowed in the write job. No downloaded
   candidate code, untrusted PR code, remote reusable workflow, shell-evaluated
   command string, or unallowlisted action may execute there.
6. Define **explicit expansion** separately from **job availability**:
   - reviewed action `token` inputs listed in the normative policy may explicitly
     receive `github.token`;
   - only the guarded push step may expand it into the process-scoped Basic
     authorization header/Git config environment used by `git push`;
   - all other script processes receive no explicit token/header/helper/config
     environment.
7. Keep origin credential-free and pass the authorization header through
   process-scoped `GIT_CONFIG_COUNT`/key/value variables to the one direct Git
   child process. Clear step-local variables in `finally`; never place secrets
   in args, files, remotes, ordinary Git config, outputs, artifacts, or logs.
8. Run all candidate, regeneration, ref/SHA, parent, tree, lease, path, and
   diagnostic checks before push-header construction. After push, perform only
   the minimum identity check that requires the result; do not log auth.
9. Update the permanent validator/fixtures for exact permissions, explicit
   token input placement, persisted-auth false, a token expression in an
   unallowlisted role, a write permission in another job, push auth constructed
   early, secret in remote/config/argument, and a diagnostic step with explicit
   token environment.
10. Replace acceptance wording with:
    “Only the writer job has contents-write authority; checkout authentication
    is transient and not persisted; only the exact guarded push process receives
    an explicit Git push authorization header.”
11. Apply the same vocabulary to T1 so temporary and final policy evidence use
    one honest lifecycle model.
12. Cite GitHub's `GITHUB_TOKEN`, secure-use, context, and pinned checkout
    sources in `References`.

**Status: selected and ready for incorporation into T1B.**

The next finding to evaluate is T1B-02.

## T1B-02 — Replace the self-defining role allowlist with a normative table

### Finding and decision constraints

T1B lists roles “at minimum,” then says final YAML determines exact counts.
That reverses specification authority: an implementer can add or move an action,
update validator expectations, and still claim conformance even though the
issue never reviewed the resulting token, artifact, condition, or side-effect
surface.

T1B's graph is security-sensitive: one external event owner, a local reusable
Markdown job, preparation, four expanded Windows cells, terminal approval, and
one writer. Static YAML occurrences and expanded runtime instances differ.
Artifact uploads/downloads have dangerous selection/extraction/default
permutations, and each matrix output must be unique.

The resolution must make the issue the sole normative source, define the
complete job/step/action/input/condition/data-flow topology, and let the
already-selected validator reject every deviation. Pinned download-action
defaults are retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Complete normative job, role, input, and data-flow tables

Add four linked issue tables:

1. jobs/events/permissions/`needs`/conditions/outputs;
2. every `uses:` or security-relevant local/run step role;
3. exact explicit input keys/values and reviewed absent defaults; and
4. producer-output-to-consumer-input mappings.

Distinguish static action occurrence count from matrix-expanded runtime count.
Encode these tables as immutable validator constants. A role/table change is a
policy change requiring issue-level review; code and fixtures cannot redefine
it.

Permutations:

- one very wide table versus normalized linked tables. Linked tables are more
  readable and can still use stable role IDs as foreign keys;
- include every run step or only security-relevant ones. Include every step
  whose order/condition/environment touches source, candidate, identity,
  approval, credentials, Git, diagnostics, or outputs; ordinary version logging
  may be grouped only if exact placement remains enforced; and
- express matrix runtime count as `4` or formula `size(matrix)`. Require the
  static four canonical entries and calculate exact expanded count `4`.

#### Option B — Generate expected policy from the final workflow

Parse final YAML and serialize its jobs/roles/inputs into fixtures. This is easy
to keep synchronized but makes implementation authoritative and cannot detect
an unreviewed extra role.

#### Option C — Keep minimum roles and let validator finalize counts

Preserve the current design. It catches accidental drift after implementation
but does not prove that the initial final design was authorized.

#### Option D — Specify the graph in prose and validate only action schemas

Require expected jobs/needs/conditions narratively and check that action input
keys are valid. This leaves exact values, counts, expressions, and producer/
consumer mappings open to interpretation.

#### Option E — Add a separate signed/hashed machine-readable policy manifest

Store the complete desired topology in JSON and make validator/workflows match
it. This is strong mechanically, but adds another affected file/source of truth;
unless the issue reproduces the values, reviewers still approve an opaque
implementation artifact.

#### Option F — Wrap each external action in local composite/reusable actions

Expose narrow local interfaces for checkout/upload/download/setup. This can
centralize inputs but adds wrapper code/actions, may obscure token contexts,
and does not by itself define job placement, conditions, or runtime counts.

#### Option G — Depend on manual security review

Ask reviewers to inspect final YAML/expanded jobs without a complete normative
table. This is valuable as a second control but cannot support deterministic
negative fixtures or future drift detection.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric is specific to the final
multi-job writer topology:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Least-privilege topology assurance | 30 | Job permissions, conditions, ordering, and action placement determine whether unapproved code can write. |
| End-to-end data-flow correctness | 20 | Candidate ID/digest/four hashes/ref/SHA/matrix evidence must reach exact consumers without missing or ambiguous outputs. |
| Action input/default completeness | 15 | Download selection/extraction, checkout token, setup cache, and upload scope depend on exact values and absences. |
| Matrix/output expansion correctness | 12 | One static role can execute four times; each canonical cell must write only its own output. |
| Human auditability | 10 | Security, DevOps, and new maintainers need one issue-level design they can review cold. |
| Mutation/negative-fixture coverage | 8 | Every policy dimension needs a failing near-miss. |
| Maintenance/churn | 5 | Detailed tables cost effort but are subordinate to writer safety. |

### Scored comparison

| Option | Least privilege 30 | Data flow 20 | Inputs 15 | Matrix 12 | Audit 10 | Fixtures 8 | Churn 5 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — complete normative tables | 5 | 5 | 5 | 5 | 5 | 5 | 3 | **98.0** |
| B — derive from workflow | 2 | 4 | 4 | 4 | 2 | 4 | 5 | 65.0 |
| C — minimum roles/final counts | 2 | 3 | 3 | 3 | 3 | 3 | 5 | 56.0 |
| D — prose graph/schema inputs | 3 | 4 | 3 | 3 | 4 | 3 | 4 | 67.0 |
| E — separate policy manifest | 5 | 5 | 5 | 5 | 3 | 5 | 1 | 92.0 |
| F — local action wrappers | 4 | 4 | 4 | 3 | 3 | 4 | 2 | 73.6 |
| G — manual review | 1 | 2 | 2 | 1 | 3 | 1 | 5 | 35.0 |

Option A is the only design that is both fully executable and independently
reviewable without another policy artifact.

### Selected resolution

Select **Option A — complete normative job, role, input, and data-flow
tables**.

Implement it in T1B as follows:

1. Replace workflow-level `contents: read` with default
   `permissions: {}` and define exact per-job permissions.
2. Define exact jobs and direct dependencies:
   - `markdown` calls only
     `./.github/workflows/markdownlint.yml`, has `contents: read`, no secrets
     inheritance, and no steps;
   - `prepare` has `contents: read` and no dependencies;
   - `validate_windows` has `contents: read`, needs `prepare`, and owns the
     exact static four-cell matrix;
   - `approve` has no write permission, uses `always()`, directly needs
     `markdown`, `prepare`, and `validate_windows`, and computes one terminal
     decision for success/failure/skipped/no-change;
   - `writer` has only `contents: write`, directly needs every output/result it
     reads (including `prepare`, `validate_windows`, and `approve`), and is
     eligible only for a push to the exact protected main ref, approval success,
     and `has_changes == 'true'`.
3. Define the exact static action-role inventory:

   | Role ID | Static count | Expanded runtime count |
   | --- | ---: | ---: |
   | `prepare.checkout` | 1 | 1 |
   | `prepare.upload-candidate` | 1 | 1 |
   | `windows.checkout` | 1 | 4 |
   | `windows.download-candidate` | 1 | 4 |
   | `windows.upload-failure-diagnostics` | 1 | at most 4 |
   | `writer.checkout` | 1 | at most 1 |
   | `writer.download-candidate` | 1 | at most 1 |
   | `writer.upload-failure-diagnostics` | 1 | at most 1 |
   | `markdown.checkout` | 1 | 1 |
   | `markdown.setup-node` | 1 | 1 |

   No other external-action or remote-workflow role is permitted.
4. Add exact job/step IDs, SHA/release annotation, `if`, `continue-on-error`,
   environment, order, side effects, and output ownership for every row.
   Failure diagnostic uploads use `failure() && !cancelled()`,
   `continue-on-error: true`, and may not mask the primary result.
5. Apply T1-06's full explicit checkout and setup-node input sets to the final
   roles, with exact ref/repository/token/persistence/depth values.
6. Candidate upload must declare a collision-free run-ID/attempt name, the four
   exact literal paths, missing-file error, shortest approved retention,
   reviewed compression/archive settings, no overwrite, and no hidden files.
7. Both download roles must declare:
   - `artifact-ids` from the exact preparation output;
   - a new protected context download directory;
   - `skip-decompress: true`; and
   - `digest-mismatch: error`.

   Require `name`, `pattern`, `merge-multiple`, `github-token`, `repository`,
   and `run-id` to be absent. Selection by name or cross-run/repository is
   prohibited.
8. Diagnostic uploads must name exact test-owned paths, 7-day retention,
   explicit missing-file behavior that cannot hide the primary failure, no
   hidden files/overwrite, and collision-free job/cell/run/attempt names.
   Candidate archives, state, tokens, signed URLs, Git config, and arbitrary
   workspace directories are forbidden.
9. Define every producer/consumer edge in a table:
   - preparation → Windows/writer: artifact ID, bare artifact digest, unique
     artifact name for diagnostics only, event SHA, target ref, `has_changes`,
     and four path-bound hashes;
   - each matrix cell → approval: exactly one cell-specific canonical JSON
     output;
   - preparation/Windows/Markdown results → approval;
   - approval plus preparation/cell evidence → writer.
10. Name exact job output keys and exact step output sources. Require a direct
    `needs` edge for every consumed job output; no transitive assumption.
11. The matrix include entries contain immutable cell ID, runner, executable,
    expected edition/version, source EOL, and unique output key. Each matrix
    step may set only the key selected by its static include row. Approval
    rejects empty, duplicate embedded IDs, duplicate keys, wrong IDs, invalid
    JSON/schema, or evidence not matching preparation.
12. Encode tables as hand-authored validator constants. The validator rejects
    missing/extra jobs, dependencies, permissions, conditions, actions, inputs,
    outputs, matrix fields, roles, or side effects. It never writes expected
    data from parsed workflow YAML.
13. Add one negative fixture per table dimension plus combined attacks:
    correct action in wrong job, correct input on wrong role, name-based
    download, decompression enabled/implicit, cross-run token, diagnostic upload
    on success/cancellation, hidden/wildcard diagnostic path, missing direct
    `needs`, shared matrix output, and a second/dormant writer.
14. Change upgrade policy: any intentional role/input/default/count/data-flow
    change requires updating the GitHub issue/security decision, normative
    tables, workflow, validator constants, fixtures, action provenance, and
    references atomically.
15. Remove “at minimum” and “final YAML determines exact counts” everywhere.

**Status: selected and ready for incorporation into T1B.**

The next finding to evaluate is T1B-03.

## T1B-03 — Specify the temporary-branch proof mechanism

### Finding and decision constraints

T1B correctly makes the production writer eligible only for an approved,
changed push to `refs/heads/main`, but later asks maintainers to exercise the
real writer and exact remote lease on a temporary branch before enabling main.
It does not say how that branch can trigger the otherwise main-only graph,
which condition may differ, how changes are guaranteed, how negative scenarios
are selected, or how the repository proves that no temporary write surface
survives.

The mechanism must:

- execute GitHub's real hosted workflow, artifact service, job token, remote
  preflight, commit, and `git push --force-with-lease` behavior;
- make the temporary target incapable of naming or reaching `main`;
- keep permissions, action pins/inputs, role topology, candidate identity,
  credential timing, staged-path restriction, parent/tree checks, and lease
  semantics identical to the reviewed production design;
- deterministically force a legitimate generated-artifact change;
- support the controlled success, no-op, stale-preflight, race, identity,
  transport, dependency, and secret-sentinel drills without accepting an
  arbitrary runtime ref or command;
- retain reproducible evidence; and
- prove deletion/restoration before the production workflow is eligible on
  main.

GitHub's branch-local workflow selection, `push`, `workflow_dispatch`, and
token-recursion behavior are retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Exact branch-local push variant plus an allowed-delta manifest

Create a cryptographically unpredictable short branch name under
`t1b-evidence/` and record its full ref. Start it at the exact reviewed
implementation commit, then add evidence-only commits which never enter the
merge candidate. A branch-local variant of `build.yml`:

- changes every production `main` event, approval, writer, target-ref, and
  validator-policy literal to the one hard-coded evidence branch/ref;
- retains the production graph, permissions, roles, action pins and exact
  inputs, immutable candidate transport, four-cell matrix, credential boundary,
  path gates, commit checks, and exact lease/refspec;
- adds only bounded, enumerated evidence instrumentation and hard-coded
  scenario identifiers; and
- includes a temporary source-guide fixture change which makes the four
  generated outputs stale and guarantees the positive writer path.

Use a `push` trigger because GitHub evaluates the workflow at the pushed ref.
After every run, compare the production base to the evidence commit against a
reviewed allowed-delta manifest. A positive run must advance only the evidence
ref by exactly one expected-parent commit containing only the four generated
paths. Scenario commits exercise each negative path against the same temporary
ref; they may choose only a closed enum and may not supply a runtime ref,
credential, path, or command string.

Finally restore any evidence-ref-scoped repository/environment setting, delete
the remote ref, prove it is absent, and prove the merge candidate contains no
evidence commit or allowed-delta marker.

Permutations:

- edit the production workflow in place only on the evidence branch, or add a
  separately named evidence workflow. Prefer the in-place variant because the
  graph and writer have a smaller diff and no second workflow copy can drift;
- use one evidence branch for all drills with lease-recorded controller pushes,
  or a fresh unpredictable branch per drill. One branch is easier to audit,
  while fresh branches isolate state; require a single recorded namespace and
  exact base/target observations either way;
- make a source-guide-only fixture commit or inject different generated bytes.
  Use a source-guide fixture so the normal generator creates the candidate and
  every byte-identity proof remains real; and
- change repository/environment rules only if the evidence ref otherwise
  cannot be written. Any change must be scoped to the exact evidence ref, have
  captured before-state, and restore that state even after failure.

#### Option B — Production workflow dry run with the push suppressed

Run every local and hosted validation but replace `git push` with logging or
`--dry-run`. This is safe and easy, but does not prove real job-token
authorization, server-side expected-SHA lease enforcement, branch update, or
post-push ref identity.

Permutations include dry-running only the final Git command or mocking
`ls-remote` and `push` through a wrapper. The latter proves orchestration but
less of the production transport.

#### Option C — Local bare repository as the remote

Run the writer logic against a temporary local bare Git repository, including a
real concurrent ref update. This gives deterministic preflight and lease tests
without changing GitHub state, but bypasses GitHub-hosted runner boundaries,
the repository token, HTTPS authorization, server enforcement, and the actual
remote service.

It remains valuable as a permanent lower-level fixture, not as the required
end-to-end promotion proof.

#### Option D — Disposable repository or fork

Copy the exact workflow and relevant repository state into a temporary
repository/fork, grant its token write permission, and run against its main or
temporary branch. This protects the production repository but introduces a
different repository ID, settings, protection environment, artifact boundary,
token grant, default branch, and possibly fork approval model. Reproducing and
later deleting all external state is also harder to audit.

Permutations include an organization-owned test repository, a personal fork,
or a repository created per run. None proves the exact target repository's
permission and rule configuration.

#### Option E — Temporarily loosen the production workflow on the implementation branch

Add the temporary branch to the final workflow's event/condition patterns,
collect evidence, then make a removal commit. Without an exact delta contract
and ancestry/removal proof this is the current ambiguity: a glob or condition
can accidentally include main, a proof-only input may remain dormant, and
reviewers cannot tell which other semantics changed.

This becomes Option A only when the ref is one exact literal, the variant is
confined to non-merge evidence commits, every allowed delta is enumerated, and
restoration is a release gate.

#### Option F — Permanent `workflow_dispatch` evidence mode

Add a boolean/scenario/ref input to the production workflow and dispatch it at
the temporary branch. The event is easy to rerun, but GitHub requires the
workflow to exist on the default branch to receive `workflow_dispatch`.
Keeping it permanently expands the production event and input surface; adding
it temporarily cannot bootstrap a workflow that exists only on the evidence
branch. A caller-controlled target ref also creates a dangerous confused-
deputy path in a write-capable workflow.

Narrower permutations hard-code the branch or restrict an environment, but
still leave a permanent proof mode or require a temporary default-branch
change.

#### Option G — Use a PAT, GitHub App, deploy key, or maintainer push as proof

Exercise the exact lease manually or from a separate workflow with a different
credential. This proves Git's remote compare-and-swap behavior, but not the
production writer's job-scoped `GITHUB_TOKEN`, permissions, checkout lifecycle,
or push-only credential expansion. Long-lived credentials also add rotation
and disclosure risk.

#### Option H — Rely on unit fixtures and first production main push

Treat local/mock lease tests as sufficient and let the first changed push to
main be the real integration test. This leaves the highest-consequence boundary
untested until it can modify the protected target and contradicts T1B's staged
enablement requirement.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric emphasizes whether the
proof genuinely exercises the production promotion boundary while remaining
incapable of altering the production ref:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Real production-boundary fidelity | 25 | Artifact service, hosted jobs, job token, GitHub remote, writer code, and post-push checks must all be exercised. |
| Main-branch isolation | 25 | A proof defect must be unable to select, authorize, or update the protected production ref. |
| Exact semantic-delta control | 14 | Reviewers need to know that only trigger/target literals and bounded instrumentation differ. |
| Repeatable success/failure drill coverage | 12 | Positive, no-op, stale/race, transport, dependency, and sentinel cases need deterministic selection and outcomes. |
| Cleanup and no-residual proof | 10 | Branches, temporary policy/settings, fixtures, inputs, and alternate write paths must not survive. |
| Evidence reproducibility | 8 | Exact commits, refs, run IDs, ref observations, and diffs must support later audit. |
| Credential/lease authenticity | 4 | The selected route should use the real token and server-side expected-SHA lease. |
| Effort and operational churn | 2 | Setup cost matters only after safety, fidelity, and evidence quality. |

### Scored comparison

| Option | Fidelity 25 | Main isolation 25 | Delta control 14 | Drill coverage 12 | Cleanup 10 | Evidence 8 | Auth/lease 4 | Effort 2 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — branch-local allowed-delta variant | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 2 | **98.8** |
| B — suppressed/dry-run push | 3 | 5 | 4 | 4 | 5 | 4 | 1 | 4 | 78.0 |
| C — local bare remote | 3 | 5 | 5 | 5 | 5 | 5 | 2 | 4 | 87.2 |
| D — disposable repository/fork | 4 | 5 | 3 | 4 | 3 | 3 | 4 | 1 | 76.8 |
| E — loosely temporary workflow condition | 4 | 2 | 2 | 4 | 2 | 2 | 5 | 4 | 55.6 |
| F — permanent dispatch evidence mode | 4 | 2 | 3 | 5 | 2 | 4 | 5 | 3 | 65.4 |
| G — alternate credential/manual push | 2 | 4 | 3 | 3 | 4 | 3 | 2 | 3 | 56.8 |
| H — fixtures then first main push | 2 | 1 | 4 | 2 | 5 | 2 | 5 | 5 | 45.6 |

Option A is the only approach that proves the actual GitHub writer and
server-side lease while giving reviewers a closed, auditable difference from
production and a conclusive removal gate.

### Selected resolution

Select **Option A — exact branch-local push variant plus an allowed-delta
manifest**.

Implement it in T1B as follows:

1. After the final production candidate passes static/local and pull-request
   checks, record its full commit as `PRODUCTION_BASE`. Generate an
   unpredictable lowercase branch suffix and record one full target ref:
   `refs/heads/t1b-evidence/<utc>-<random>`. Reject whitespace, controls,
   malformed refs, patterns, and any value equal to/prefixing `main`.
2. Create the evidence ref at `PRODUCTION_BASE`. Evidence-only commits must
   remain on that ref and must never be merged, rebased, cherry-picked, or
   squashed into the production candidate.
3. On that branch only, patch the same `build.yml` rather than copying the
   writer. Change the literal push branch filter, approval promotion ref,
   writer eligibility ref, `TARGET_REF`, and corresponding validator constants
   from `main` to the one exact evidence branch/ref. No wildcard, prefix
   expression, caller-supplied ref, `workflow_dispatch`, `repository_dispatch`,
   reusable-workflow secret inheritance, or second external event owner is
   permitted.
4. Define an allowed-delta manifest in the issue before running evidence. It
   names exact file/hunk/old/new values for those ref literals, bounded
   evidence instrumentation, the closed scenario selector, and the single
   source-guide fixture. A structural/diff check must reject any other
   difference from `PRODUCTION_BASE`, including permission, job/needs,
   condition shape other than the literal ref, action/SHA/input, candidate,
   path, credential, commit, lease, refspec, or diagnostic policy.
5. Make the positive evidence commit alter one source-guide fixture in a way
   that deterministically changes generated bytes. Do not hand-edit the four
   outputs. The normal preparation job must generate and upload the resulting
   candidate, all matrix cells must validate it, and the real writer must
   consume it.
6. On success, prove the evidence ref moved from the captured event/
   `EXPECTED_SHA` to exactly one new commit; its sole parent is that SHA, its
   tree differs only at the four generated paths, all four committed blobs
   match the propagated candidate hashes, and the run's exact lease/refspec
   named only the evidence ref. GitHub's token-suppressed recursion means the
   writer-created commit must not start another run; record that assertion.
7. Encode negative drills as separate, reviewed evidence-only scenario commits
   using a closed enum and bounded test-owned fixtures/hooks. The selector may
   not contain or derive a ref, path, command, credential, expression, or
   arbitrary data. Before each drill, capture the evidence ref/SHA and use a
   maintainer/controller update with its own exact lease to establish the next
   scenario base.
8. For each negative drill, record the scenario commit, run ID/URL, expected
   phase/status, observed remote SHA before/after, approval/writer result,
   diagnostic artifact identity if any, and sentinel scan. The stale/race drill
   must use a separate controlled ref update after preflight and prove the
   writer's exact lease loses; it may never weaken or omit the lease.
9. Do not modify main protection. If an environment/repository rule prevents
   the evidence ref from being written, capture its exact before-state, apply
   the smallest rule change scoped only to the evidence ref, record actor/time/
   reason, and restore the byte/field-equivalent before-state in `finally`.
   A failed or unverified restoration blocks production enablement.
10. Retain evidence under the issue/PR: `PRODUCTION_BASE`, all evidence commit
    IDs, exact branch/ref, allowed-delta manifest and result, run IDs/URLs,
    artifact ID/digest/four hashes, ref observations, commit/tree/parent
    evidence, negative-drill table, setting before/after evidence, and cleanup
    commands/results. Do not retain credentials, signed URLs, or secret-bearing
    logs.
11. Cleanup requires: cancel/wait for all evidence runs; restore temporary
    settings; delete the remote evidence ref using an exact expected-old-object
    guard; query the exact ref and require it absent; remove the local branch;
    and prove no environment, rule, artifact policy, or active run still names
    the evidence ref.
12. Before main enablement/merge, prove the production candidate is descended
    from `PRODUCTION_BASE` and contains none of the evidence commits. Search the
    full production diff and parsed workflow/policy for the evidence branch,
    scenario IDs, instrumentation, source fixture, alternate event, alternate
    writer condition, or second push path; require the original exact
    main-only normative tables and all positive/negative policy fixtures.
13. Replace “use a unique temporary branch” with this protocol and make cleanup,
    exact production-policy restoration, and absence of every evidence-only
    delta explicit acceptance criteria.

**Status: selected and ready for incorporation into T1B.**

The next finding to evaluate is T1B-04.

## T1B-04 — Move T2's future merge fact to handoff

### Finding and decision constraints

T1B's final acceptance checklist currently requires “T2 records this issue's
exact merge commit as its prerequisite.” That statement cannot be made true by
the T1B implementation or pull request: the exact T1B merge commit does not
exist until after T1B is merged, and T2 is intentionally later in the execution
order. A squash or rebase merge also means neither the reviewed T1B head nor an
intermediate test commit predicts the eventual branch commit.

The resolution must keep immutable predecessor identity mandatory, preserve the
T1B → T2 block, assign the post-merge handoff to an identifiable owner/location,
make T2 fail before work if the handoff is missing or wrong, and keep T1B's own
acceptance criteria satisfiable at T1B merge time.

### Resolution options

#### Option A — Satisfiable predecessor record plus mandatory successor handoff

Make T1B record the exact reviewed implementation head, its validation
evidence, the T2 successor, and a named handoff owner/location before merge.
After T1B merges, record the actual commit that landed on the protected branch
in T2's dependency/issue/PR evidence. T2 must validate that commit object and
the enduring T1B interfaces before editing.

This matches the already-correct T1 and T1A formulation: the predecessor
requires its successor to consume a future value; it does not claim the value
already exists. The T1B checklist can require a complete handoff instruction
and assignment, while T2 owns consumption.

Permutations:

- retain the actual landed commit in T2's issue body, first implementation
  comment, or pull-request evidence. Prefer the durable T2 dependency section
  plus PR evidence, with the real GitHub blocked-by relationship;
- identify a GitHub merge commit, squash commit, or rebase-landed commit.
  Always record the actual commit on the protected target branch, independent
  of merge method;
- have the T1B merger, T2 implementer, or release owner write the value.
  Assign the T1B merger/issue owner to publish the handoff and require the T2
  implementer to verify it; and
- automate the post-merge update as a convenience. Automation may propose the
  value, but T2's explicit validation remains authoritative.

#### Option B — Keep the current future-fact acceptance item

Require T2 to contain a value before T1B can be accepted. This either deadlocks
the ordered slate, encourages a placeholder/prediction, or makes reviewers
check an impossible item as though it were optional.

#### Option C — Substitute T1B's reviewed pull-request head

Record the last reviewed head and call it the prerequisite. This value exists
before merge and is important evidence, but may not be the commit T2 actually
consumes after squash/rebase or a final merge commit. It answers a different
identity question.

Permutations include recording both head and tree hash. Both remain useful
review evidence but neither replaces the landed branch commit.

#### Option D — Pre-edit T2 with a placeholder or predicted commit

Change T2 before T1B merges, using `TBD`, a PR head, an anticipated SHA, or a
template field. This violates the intended execution order and can silently
leave stale provenance. A placeholder is acceptable only in a draft as an
explicit unsatisfied filing gate, not as acceptance evidence.

#### Option E — Depend solely on post-merge automation

Have a workflow or bot discover the landed commit and edit/link T2. This can
reduce handoff loss and is a useful permutation of Option A, but automation may
fail, lack issue permissions, select the wrong merge method/ref, or be changed
with the workflow. Without a T2-side validation gate it turns provenance into a
best-effort side effect.

#### Option F — Remove exact commit identity and rely on issue links/order

Keep only the blocked-by relationship or issue number. This shows intent but
does not bind T2's implementation to immutable code, cannot distinguish a
later branch state, and weakens all prerequisite version/interface checks.

#### Option G — Identify T1B through a tag, release, or artifact

Create a post-merge tag/release or publish a handoff artifact. A signed tag can
provide strong identity but adds a release lifecycle the repository does not
otherwise need; an artifact is retained for a bounded time and is not the Git
ancestry T2 consumes. Both still require a post-merge handoff and therefore do
not simplify Option A.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric focuses on temporal and
provenance correctness between sequential issues:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Temporal satisfiability | 28 | Every T1B checklist item must be knowable and completable before T1B merges. |
| Immutable consumed-code identity | 22 | T2 must bind to the actual protected-branch commit, not a prediction or mutable branch. |
| Dependency enforcement | 18 | Missing, malformed, nonexistent, or wrong predecessor identity must stop T2 before edits. |
| Correct issue ownership | 12 | T1B should own the handoff requirement and T2 should own future consumption. |
| Reviewer/audit clarity | 10 | Reviewed head, landed commit, link, and validation evidence must not be conflated. |
| Handoff-loss resilience | 7 | The process should remain reliable across merge methods, people, and automation failure. |
| Administrative effort | 3 | Updating a successor after merge should be lightweight but never outrank provenance. |

### Scored comparison

| Option | Temporal 28 | Identity 22 | Enforcement 18 | Ownership 12 | Audit 10 | Resilience 7 | Effort 3 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — predecessor record + successor handoff | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.4** |
| B — current future-fact checklist | 1 | 1 | 2 | 2 | 2 | 1 | 5 | 30.4 |
| C — reviewed head as prerequisite | 2 | 2 | 3 | 4 | 3 | 2 | 4 | 51.6 |
| D — pre-edit T2/predict value | 3 | 3 | 4 | 2 | 3 | 2 | 2 | 59.2 |
| E — automation only | 5 | 5 | 4 | 4 | 4 | 2 | 2 | 86.0 |
| F — links/order without commit | 5 | 1 | 1 | 5 | 1 | 1 | 5 | 54.4 |
| G — tag/release/artifact identity | 4 | 4 | 3 | 3 | 4 | 3 | 2 | 71.4 |

Option A is the only resolution that makes T1B independently completable while
retaining exact, enforceable code identity at the point T2 can actually know
it.

### Selected resolution

Select **Option A — satisfiable predecessor record plus mandatory successor
handoff**.

Implement it in T1B/T2 as follows:

1. In T1B's dependency/handoff section, name T2's exact title and state that T2
   is blocked until T1B merges and consumes the exact commit that lands on the
   protected branch.
2. Before T1B merge, record the full reviewed T1B head commit, exact workflow/
   script versions, final validation/evidence run IDs, and real T2 blocked-by
   relationship. Label that SHA **reviewed head**, never **merge commit**.
3. Assign the T1B merger/issue owner to publish the post-merge handoff in T2's
   dependency record. The handoff contains T1B's issue/PR URLs, actual full
   protected-branch landed commit, merge method, and merge time.
4. For a merge commit, record that actual commit; for squash merge, record the
   squash commit; for rebase merge, record the final landed commit containing
   T1B's completed change set. Do not predict or derive it from the PR head.
5. At T2 implementation start, parse the value as a full repository object ID,
   require it exists as a commit, require it is reachable from the protected
   branch, and verify T1B's exact enduring generator/helper/context/harness/
   writer versions and interfaces at that commit. Stop before edits on any
   absence or mismatch.
6. Retain both identities when merge strategy changes content:
   `reviewed_head` proves what was reviewed; `landed_predecessor_commit` proves
   what T2 consumed. Record any difference and revalidation evidence.
7. Automation may prepare or post the handoff, but T2 must independently verify
   the selected commit and link. Automation success is not an acceptance
   substitute.
8. Replace T1B's impossible acceptance item with:
   “The reviewed T1B head, T2 blocked-by relationship, handoff location, and
   handoff owner are recorded; T2 is required to record and validate T1B's
   actual landed commit after this issue merges.”
9. Retain T2's existing dependency requirement to record the real relationship
   and exact merge commit, making it T2's own pre-edit acceptance/validation
   obligation.

**Status: selected and ready for incorporation into T1B and T2.**

The next finding to evaluate is T1B-05.

## T1B-05 — Tighten structural-policy mechanics

### Finding and decision constraints

T1B says its permanent policy validator checks action roles and artifact
options, but it does not yet require exact equality of explicit action input
key/value maps or separately enumerate every intentionally omitted default. Its
affected-file checks do not define a byte-safe Git protocol, and native
difference commands are described in ways that can collapse “differences
found” and “command failed.” Those gaps allow a currently safe action default,
an extra accepted role, a moved condition, or a pathname containing a line
delimiter to evade the intended policy.

The resolution must integrate with the one T1-selected locked YAML validator,
keep issue tables—not the current workflow—as the authority, compare semantic
YAML types/expressions exactly, parse Git path sets without line/string
ambiguity, distinguish every documented native result immediately, and prove
each dimension with a near-miss fixture.

The relevant pinned action defaults and Git `-z`/exit-code facts are retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — One normative semantic schema plus byte/status-safe Git gates

Extend the tracked validator with immutable constants copied from the issue's
complete T1B-02 tables. Each role has an exact job/step/condition/action SHA and
an exact `with` mapping of semantic key, YAML value type, and exact literal or
expression. A separate allowlist names every permitted omitted action input and
the reviewed upstream default/rationale; any other omission or extra key fails.

Use raw `Buffer` output from Git's `--name-only -z`/porcelain-v1 `-z` forms,
split only on NUL bytes, reject malformed missing/empty records, and compare
sorted/deduplicated path-byte sets with exact expected ASCII path buffers.
Invoke the difference predicate separately, capture its exit status
immediately, and classify `0 = no difference`, `1 = difference`, every other
status as execution failure.

Add mutation fixtures for every table/grammar/status dimension, including names
with spaces, tabs, and newlines. The validator must never regenerate expected
constants from a workflow or positive snapshot.

Permutations:

- store constants in JavaScript objects or a tracked JSON policy. Keep them in
  the existing validator because a new manifest would add a second affected
  policy file; the issue tables remain the human source either way;
- compare expression source literally after semantic YAML parse or normalize a
  narrowly defined expression AST. Literal equality is simpler and rejects
  alternate/dynamic expressions; allow normalization only if its grammar and
  cases are fully specified;
- run Git gates in PowerShell or Node. Use a reusable local implementation that
  captures native stdout bytes and status without host text decoding; test it
  from every supported runner shell; and
- sort path sets or preserve Git order. Treat them as sets after rejecting
  duplicate/empty records; order must not change acceptance.

#### Option B — Validate action repositories/SHAs but review inputs manually

Keep role placement and pins mechanical while relying on code review for
`with:` keys and defaults. This misses precisely the mutation class in the
finding: removing `persist-credentials`, `skip-decompress`, digest policy,
cache policy, or another explicit control can silently activate an upstream
default.

#### Option C — Use action schemas/actionlint plus regular expressions

Check whether input keys are valid for each action and grep workflow text for
required values. Schema validity cannot prove the issue-authorized key set,
role, condition, semantic type, expression, or reviewed omission. Text matching
is also sensitive to comments, aliases, quoting, duplicate syntax, and YAML
representation.

#### Option D — Golden-snapshot the accepted workflow

Hash or serialize the current parsed YAML and fail on any difference. This
catches drift but makes the implementation snapshot the policy authority,
produces poor diagnostics, and either rejects harmless representation changes
or requires regenerating the golden file from the new implementation.

Permutations include a whole-file hash, canonical YAML/JSON snapshot, or one
snapshot per job. None independently states why an input/default/role is
authorized.

#### Option E — Separate machine-readable role-policy manifest

Create a hand-authored JSON document containing every role/input/default and
validate workflows against it. This can be as rigorous as Option A and improves
data/code separation, but adds another changed file/source that can disagree
with the issue tables. It is viable only if the issue reproduces the full
policy and reviews manifest/workflow/validator atomically.

#### Option F — Local wrappers around every external action

Expose a narrower repository-local interface for checkout, setup, upload, and
download so call sites cannot omit most inputs. Wrappers still need their own
exact policy, can conceal the token boundary and matrix role, add executable
code in a write-capable graph, and do not solve Git path/status parsing.

#### Option G — Line-delimited paths and “nonzero means changed”

Use `git diff --name-only` text lines and accept any nonzero `--exit-code` as
the expected difference state. This is concise but aliases valid path bytes
containing newline/tab/escape syntax and converts repository/read/process errors
into successful policy observations.

#### Option H — Runtime assertions only

Assert final paths, permissions, artifact count, and write result in CI without
semantic workflow validation. Runtime coverage depends on the paths exercised;
dormant jobs, alternate conditions, omitted defaults, and a second role can
remain unexecuted until an attacker-controlled event selects them.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric focuses on closing
representation and process-observation gaps in executable workflow policy:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Normative structural completeness | 24 | Every authorized role, job, condition, action, input, value, and omission must come from reviewed issue policy. |
| Default/input drift detection | 20 | Removing one explicit security input or adding a valid but unreviewed input must fail even when today's action default seems safe. |
| Arbitrary-filename path-set correctness | 18 | Whitespace, tabs, newlines, quoting, and platform decoding cannot alter the exact changed/staged set. |
| Native failure-state separation | 15 | Git execution errors must never be accepted as “difference found” or “clean.” |
| Near-miss mutation sensitivity | 12 | Fixtures need to demonstrate detection of wrong role/job/condition/key/path/status, not only happy-path parsing. |
| Cross-platform deterministic operation | 7 | Ubuntu/Windows and PowerShell editions must reach the same policy result offline. |
| Maintenance/churn | 4 | Policy updates should be reviewable, but ease cannot make implementation self-authorizing. |

### Scored comparison

| Option | Structure 24 | Defaults 20 | Paths 18 | Status 15 | Mutations 12 | Cross-platform 7 | Churn 4 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — semantic schema + byte/status gates | 5 | 5 | 5 | 5 | 5 | 5 | 3 | **98.4** |
| B — pins plus manual input review | 3 | 1 | 2 | 2 | 2 | 4 | 5 | 48.0 |
| C — schemas/actionlint/regex | 3 | 3 | 1 | 1 | 3 | 4 | 4 | 49.2 |
| D — golden workflow snapshot | 3 | 4 | 2 | 2 | 3 | 4 | 3 | 57.6 |
| E — separate policy manifest | 5 | 5 | 5 | 5 | 5 | 4 | 2 | 96.0 |
| F — local action wrappers | 4 | 4 | 1 | 1 | 3 | 4 | 1 | 58.2 |
| G — text paths/nonzero changed | 2 | 2 | 1 | 1 | 2 | 2 | 5 | 36.8 |
| H — runtime assertions only | 2 | 2 | 3 | 3 | 2 | 3 | 4 | 49.2 |

Option A supplies the same rigor as a separate manifest without creating
another policy artifact or allowing the parsed workflow to define expected
behavior.

### Selected resolution

Select **Option A — one normative semantic schema plus byte/status-safe Git
gates**.

Implement it in T1B as follows:

1. Extend the single validator introduced in T1; do not add a second parser,
   policy generator, manifest, action wrapper, or workflow-specific ad hoc
   checker.
2. Encode the T1B-02 issue tables as hand-authored constants keyed by stable
   role ID. For each role require exact job ID, step ID, order, `uses` target/
   full SHA, release annotation, `if`, `continue-on-error`, permissions,
   environment-key set, and `with` key/value map. Reject missing and extra
   roles before comparing values.
3. For each `with` entry, compare the semantic YAML scalar type and exact value:
   literal booleans remain booleans where the action contract accepts them;
   numeric-looking strings remain exact strings where identity requires them;
   GitHub expressions equal the one authorized expression text and may not be
   composed dynamically. Reject aliases, merges, tags, coercion, duplicate
   keys, and alternate expression sources under T1-05's parser policy.
4. List every permitted omitted input separately by role, with the pinned
   action version, documented default, and why omission is safe. For the
   selected checkout/setup/upload/download controls, prefer the exact explicit
   keys required by T1-06/T1B-02; a default is not “reviewed” merely because it
   exists upstream. Unknown, extra, missing-explicit, or unlisted-omitted keys
   fail.
5. Ensure the expected schema is never read, copied, serialized, or updated
   from the parsed positive workflow. Intentional policy change requires the
   issue tables, action provenance/default review, validator constants,
   workflow, and fixtures to change in one reviewed commit.
6. Implement one path-set reader over native stdout bytes. Invoke Git with
   `--name-only -z` or `status --porcelain=v1 -z` as applicable; retain stdout
   as bytes, require successful process status, require the stream to be empty
   or end in one NUL, split only on byte `0x00`, remove only the single terminal
   empty segment, and reject any interior empty/duplicate record.
7. Compare paths as raw byte arrays after set sorting, not decoded lines,
   whitespace-trimmed strings, quoted Git text, regex matches, or shell words.
   The allowed affected paths are fixed ASCII/UTF-8 byte sequences. Reject
   absolute paths, `.`/`..` components, backslash aliases, or noncanonical byte
   sequences before equality.
8. Run the difference predicate separately with `git diff --quiet` or
   `git diff --exit-code`, capture the native status immediately, and classify
   only `0` as no differences and `1` as differences. Treat negative/
   unavailable and every status greater than `1` as an execution failure. Never
   infer status from stdout or `$?`, and never run another native command before
   capture.
9. Apply the reader/classifier to working-tree, index, commit/parent, issue
   affected-file, evidence-variant, and generated-four-path gates. State each
   command's compared endpoints and whether the expected set is equality,
   subset, or empty; do not use one command's success as evidence for another
   layer.
10. Add stable negative fixtures for:
    - one missing explicit input whose pinned default currently matches;
    - an unexpected valid input key;
    - an unexpected extra action/role;
    - the correct pinned action in the wrong job;
    - the correct role with the wrong/missing condition;
    - a correct value with the wrong YAML scalar type or expression source;
    - an unlisted omitted default;
    - duplicate/empty/missing-final-NUL path records;
    - filenames containing a space, tab, newline, leading dash, and Git quote/
      escape characters;
    - a line-parser fixture that would falsely split a newline-bearing name;
    - native statuses `0`, `1`, `2`, and process-start failure; and
    - a combined extra-role plus misleading path/status mutation.
11. Because Git forbids NUL in a pathname, use NUL solely as the record
    delimiter and test malformed injected NUL records at the parser boundary;
    use newline/tab filenames to prove why line parsing is forbidden.
12. Run the validator and byte/status fixtures after clean locked install on
    hosted Ubuntu and the required Windows surfaces. Output stable failure IDs
    and role/path metadata only—never token values, authorization headers,
    signed artifact URLs, or arbitrary environment dumps.
13. Replace general validation prose with exact acceptance items for key/value
    equality, reviewed omitted defaults, byte-delimited set equality, and
    `0`/`1`/other native classification.

**Status: selected and ready for incorporation into T1B.**

The next finding to evaluate is T2-01.

## T2-01 — Preserve nonzero signal exits

### Finding and decision constraints

Each AWS/Azure/GCS recovery block currently attaches the same
`cleanup_recovery` function to `EXIT HUP INT TERM`. The function captures `$?`
and exits with it. A signal trap is not guaranteed to enter with a status that
identifies the signal; the confirmed TERM reproduction entered after a
successful command with status `0`, cleaned up, and falsely reported success.
The same function can also be invoked through both a signal trap and the
subsequent exit path unless trap state is controlled precisely.

The resolution must report HUP/INT/TERM as exact nonzero statuses, perform
ownership-aware cleanup exactly once, preserve the original failure when
cleanup also fails, never print a success message after interruption, and be
permanently reproducible at a deterministic lifecycle point for all three
provider recovery blocks.

GNU Bash/POSIX signal and exit facts are retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Signal-specific terminators feeding one `EXIT` cleanup owner

Install `cleanup_recovery` for `EXIT` only. Install three tiny signal handlers
which ignore HUP/INT/TERM and explicitly `exit 129`, `exit 130`, or `exit 143`.
The resulting exit invokes the sole cleanup owner, which captures the primary
status as its first operation, disables its own trap, retains handled signals
as ignored during cleanup, and exits once with a precedence rule:

1. any nonzero primary status is returned unchanged;
2. a cleanup failure is diagnosed but cannot replace that primary status; and
3. when the primary status was zero, a cleanup failure returns exact status
   `1`, never success.

Successful publication still disarms all traps only after the final and
temporary state is proven. The harness launches the extracted block, waits for
a provider-stub synchronization marker after the private root/partial exists,
sends one signal to the exact subshell PID, and asserts status, cleanup journal,
diagnostics, and filesystem state.

Permutations:

- use one parameterized `terminate_from_signal 129|130|143` function or three
  named functions. A parameterized function reduces drift if each trap passes
  a literal reviewed status;
- reset signal handlers to default or ignore while exiting/cleaning. Ignore
  them until termination so a second handled signal cannot interrupt or
  recursively invoke cleanup;
- return a provider-independent cleanup-only status `1` or a dedicated status.
  Use `1` because it is portable and the stable diagnostic ID supplies the
  reason; and
- test only one provider per signal or every provider/signal pair. Require the
  full cross-product because the exact blocks are independently published and
  may drift despite shared fixture helpers.

#### Option B — Keep one trap function but infer signal from `$?`

Map `$?` greater than 128 to a signal and otherwise treat it as the primary
status. This retains the defect: a trapped signal can enter with `0` or the
status of an unrelated command. `$BASH_COMMAND`/`BASH_LINENO` do not make the
arrival reason a reliable status oracle.

#### Option C — One trap function with hard-coded status based on trap text

Register `cleanup_recovery 129` for HUP, `... 130` for INT, `... 143` for TERM,
and `cleanup_recovery "$?"` for EXIT. This can report correct statuses, but
cleanup remains owned by multiple entry points. It needs an additional
reentrancy/disarm state machine and can still run again as the signal handler
exits. Splitting termination from sole cleanup is simpler and more auditable.

#### Option D — Cleanup, restore default, and re-raise the signal

On HUP/INT/TERM, perform cleanup, restore the default disposition, and send the
same signal to the shell. This preserves true signal termination rather than a
normal `exit 128+n`, which some supervisors distinguish. It complicates
exactly-once cleanup, can be altered by runner/process-group behavior, makes
portable exact wait statuses less direct, and risks interruption during
cleanup unless signals are masked/ignored first.

It is a valid design when signal-cause fidelity is required; this issue asks for
exact nonzero shell statuses and filesystem postconditions instead.

#### Option E — Remove signal traps and rely on default termination

Default HUP/INT/TERM behavior reports interruption, but the shell may terminate
without removing proven-owned partial state or diagnosing retained uncertain
sensitive state. The protected cleanup contract is then violated.

#### Option F — Use `ERR`/`RETURN` traps for cleanup

An `ERR` trap does not run for every failure context and is not a signal
cleanup owner; a `RETURN` trap follows function/source returns rather than
process termination. Interactions with `set -e`, conditional provider calls,
and function scopes make both unsuitable as the sole lifecycle boundary.

#### Option G — External watchdog/supervisor performs cleanup

Have the harness/workflow wrapper observe termination and remove a recorded
directory. The wrapper cannot safely prove ownership after substitutions/races,
duplicates policy outside the copyable example, and would let copied examples
remain unsafe outside CI.

#### Option H — Accept any nonzero interruption status

Fix false success but do not require HUP/INT/TERM to remain distinguishable.
This is safer than the current block, but weakens diagnostics and cannot prove
that the intended handler ran rather than an unrelated error.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric emphasizes termination
truth and lifecycle ownership:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Exact interruption status | 25 | HUP, INT, and TERM must never become success and must remain distinguishable. |
| Exactly-once cleanup ownership | 22 | A signal-induced exit cannot recursively clean, double-delete, or skip cleanup. |
| Primary-status precedence | 18 | Cleanup failure must be visible without replacing the signal/provider/validation failure. |
| Sensitive-state postconditions | 14 | Proven-owned partials are removed; uncertain state is retained and named; final paths are never overwritten. |
| Deterministic signal testability | 10 | The harness must signal a known PID at a known lifecycle point and assert exact outcomes. |
| Bash/hosted-runner portability | 7 | The copied block and CI harness must not depend on interactive job-control timing. |
| Complexity/churn | 4 | The three examples should remain understandable, below correctness and cleanup safety. |

### Scored comparison

| Option | Status 25 | Once 22 | Precedence 18 | State 14 | Tests 10 | Portability 7 | Churn 4 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — signal terminators + one EXIT owner | 5 | 5 | 5 | 5 | 5 | 5 | 3 | **98.4** |
| B — infer reason from `$?` | 1 | 3 | 2 | 4 | 2 | 2 | 5 | 45.2 |
| C — cleanup from four trap entries | 5 | 2 | 4 | 4 | 4 | 4 | 3 | 71.2 |
| D — cleanup then re-raise | 5 | 4 | 5 | 4 | 3 | 4 | 2 | 85.0 |
| E — default signal termination | 5 | 1 | 3 | 1 | 4 | 5 | 5 | 57.2 |
| F — ERR/RETURN cleanup | 2 | 2 | 2 | 2 | 2 | 2 | 3 | 40.8 |
| G — external watchdog | 4 | 2 | 3 | 2 | 4 | 3 | 1 | 55.0 |
| H — any nonzero status | 3 | 4 | 4 | 4 | 3 | 5 | 4 | 69.8 |

Option A directly separates “why the shell exits” from “who cleans,” avoiding
the ambiguous trap-entry status and recursion at the same time.

### Selected resolution

Select **Option A — signal-specific terminators feeding one `EXIT` cleanup
owner**.

Implement it in T2 as follows:

1. Use the same literal lifecycle in each AWS, Azure, and GCS recovery block:

   ```bash
   terminate_recovery_from_signal() {
     local signal_status=$1
     trap '' HUP INT TERM
     exit "$signal_status"
   }

   cleanup_recovery() {
     local primary_status=$?
     trap - EXIT
     trap '' HUP INT TERM
     # Ownership-aware cleanup; never use an unchecked command under errexit.
     # Record cleanup_failed=1 for any incomplete proven-owned cleanup.
     if (( primary_status != 0 )); then
       exit "$primary_status"
     fi
     (( cleanup_failed == 0 )) || exit 1
     exit 0
   }

   trap cleanup_recovery EXIT
   trap 'terminate_recovery_from_signal 129' HUP
   trap 'terminate_recovery_from_signal 130' INT
   trap 'terminate_recovery_from_signal 143' TERM
   ```

   The finalized body must spell out the cleanup operations and initialize
   `cleanup_failed=0`; the pseudocode comment is not copied into production as
   an implementation substitute.
2. Capture `$?` as the first `cleanup_recovery` command. Disable the `EXIT` trap
   before any fallible cleanup work and keep HUP/INT/TERM ignored until process
   exit. Do not restore/re-raise a handled signal or call cleanup directly from
   a signal handler.
3. Make every cleanup command explicit in an `if`/status capture so
   `set -e` cannot leave the handler early. Preserve the ownership journal:
   remove only the exact ordinary non-link partial and then the empty exact
   root; retain substituted, linked, extra, unreadable, raced, or undeletable
   state with its stable diagnostic.
4. Status precedence is exact:
   - HUP `129`, INT `130`, TERM `143`;
   - any preexisting provider/validation/publication nonzero status unchanged;
   - cleanup failure plus any nonzero primary returns the primary;
   - cleanup failure after a zero primary returns `1`;
   - normal completed publication disarms all four traps and returns `0`.
5. No success/publication message may occur before all final checks, cleanup,
   and trap disarm complete. Signal cases assert that no success text appears
   and that the final destination is absent/unchanged.
6. Add append-only harness IDs for the full
   `AWS|AZURE|GCS × HUP|INT|TERM × ordinary-cleanup|cleanup-failure`
   cross-product, for example `AWS-SIG-HUP-01` and `AWS-SIG-HUP-02`, with one
   machine-readable row per ID and no grouped alternative result.
7. Each test starts the exact extracted block in its own process, obtains its
   exact subshell PID, waits for a NUL-delimited provider-stub ready record
   proving the private root and expected partial exist, sends exactly one
   literal signal with `kill`, and captures `wait` status immediately.
8. Ordinary-cleanup rows require the exact signal status, one cleanup attempt,
   removal of the proven-owned partial/root, absent final, unchanged outside
   sentinels, and no success message. Cleanup-failure rows make the owned
   partial or root undeletable/raced through a test-owned mechanism, require
   the same signal status, retained path and cleanup diagnostic, and unchanged
   final/outside sentinels.
9. Add provider-failure-plus-cleanup-failure cases separately to prove the
   provider's exact nonzero status is likewise retained; do not rely only on
   signal precedence.
10. Fail the harness if the target process exits before the ready record, the
    signal targets a wrapper/child instead of the exact subshell, more than one
    cleanup record occurs, an ID is absent/duplicated, or a timeout/kill result
    is accepted as the intended oracle.
11. Update all three marked source blocks, generated copies, marker inventory,
    rationale, stable harness inventory, and acceptance language together.

**Status: selected and ready for incorporation into T2.**

The next finding to evaluate is T2-02.

## T2-02 — Separate documented parent-directory preconditions from checks

### Finding and decision constraints

T2's common contract says a recovery parent “must” be outside
version-controlled worktrees and shared/world-readable temporary locations.
The copyable AWS/Azure/GCS blocks actually prove only that the derived parent
exists, is a directory, and is not itself a symbolic link, then say the
operator remains responsible for its location. Filesystem mode bits do not
fully describe ACLs, other principals, mount policy, competing writers, every
version-control system, or the organization's definition of inappropriate
shared storage. The current prose therefore attributes more assurance to the
code than the code can portably supply.

The resolution must distinguish human/environmental assertions from exact
machine checks, require a deliberate operator act before provider invocation,
bind the selected parent to `RECOVERY_PATH`, retain the no-competing-writer
assumption, and make both the enforceable checks and the attestation gate
permanently testable without pretending the harness can prove a real
operator's storage policy.

### Resolution options

#### Option A — Explicit two-layer contract with path-bound attestation

Split the contract into:

1. **operator-attested preconditions**: the selected parent is outside every
   version-controlled worktree and inappropriate shared/world-readable
   temporary storage, is access-controlled for sensitive state, is not subject
   to another writer, and supports the same-filesystem no-replace primitive;
2. **machine-enforced checks**: snapshot a separate absolute
   `RECOVERY_PARENT`, require `RECOVERY_PATH`'s lexical parent to equal it,
   require a canonical existing ordinary non-link directory, reject controls/
   ambiguous syntax and existing final paths, verify effective ownership and
   restrictive mode on the supported GNU/Linux surface, and require one exact
   literal attestation value before provider invocation.

The prose explicitly says owner/mode/canonical checks are defense in depth and
do not prove ACL, VCS, storage-sharing, or concurrent-writer facts. The harness
tests the path grammar, binding, owner/mode/type checks, and missing/wrong/exact
attestation; it statically checks that the source labels the remaining
properties as preconditions. It does not claim to validate the truth of a
human attestation.

Permutations:

- derive the parent only from `RECOVERY_PATH` or require it separately.
  Require separate `RECOVERY_PARENT` and exact equality so the deliberate
  protected location is visible and cannot disagree with the destination;
- use a generic `yes` flag or a descriptive closed token. Use the exact literal
  `private-outside-vcs-no-competing-writers` so copied code names what is being
  asserted;
- enforce exact mode `0700` or allow an equivalent platform ACL. The scoped
  blocks target GNU/Linux and already require `umask 077`; require effective
  owner plus mode `0700`, while documenting that the operator must also assess
  ACL/mount policy; and
- search for `.git`/run `git rev-parse` as defense in depth. Avoid claiming
  completeness: alternate worktrees, other VCSs, environment overrides, and
  errors make operator attestation the authoritative location boundary.

#### Option B — Claim full machine enforcement with Git/mode/temp-root probes

Run `git rev-parse`, inspect owner/mode/ACL output, reject a list of temporary
roots, and call the result proof of all properties. This can catch many errors
but is not complete across VCSs, linked worktrees, ACL implementations,
containers/mounts, enterprise storage, and concurrency. A finite unsafe-root
denylist is not a definition of private storage.

#### Option C — Narrow the prose to current directory/type checks only

Remove “must be outside Git/shared storage” from the contract and keep it as
informal advice without an explicit attestation. This becomes mechanically
truthful, but a copy/paste can proceed in a repository or shared directory
without any deliberate checkpoint despite the plaintext-secret warning.

#### Option D — Create and own a dedicated protected parent automatically

Given a trusted base directory, create a fresh mode-0700 parent and perform all
work beneath it. This improves ownership/mode/no-competing-writer properties
and reduces caller error, but choosing the trusted base still requires the same
outside-VCS/shared-storage policy decision. Creating persistent sensitive
storage also adds a lifecycle that the current examples deliberately leave to
the operator.

Permutations include `$HOME/.local/state`, an organization path, or a
caller-supplied base. No universal default proves the policy for every host.

#### Option E — Require a specific runtime-private directory such as `$XDG_RUNTIME_DIR`

Constrain all recovery to one conventional per-user runtime directory. The
variable can be absent, have environment-specific retention/size/mount rules,
or be unsuitable for durable recovery evidence. It also excludes valid
organization-controlled storage and still needs verification.

#### Option F — Run recovery only inside an isolated container or ephemeral VM

Isolation can make ownership and competing-writer assumptions stronger, but
state must still cross a host/storage boundary for operational use. The copied
guide would become dependent on container configuration, volume semantics, and
secret transport outside this issue's scope.

#### Option G — Download directly to the final path with provider no-clobber

Eliminate the private parent/invocation directory where the provider supports a
no-overwrite flag. AWS lacks the required flag, validation occurs after output
creation, provider failure can leave partial final state, and there is no
portable atomic validated publication step.

#### Option H — Documentation-only operator warning

Clearly label all location properties as operator responsibilities but add no
required input/confirmation. This is honest and portable, yet the executable
block gives no observable evidence that a copier saw or accepted the
precondition, and the harness can test only the prose's presence.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric emphasizes truthful
assurance boundaries for sensitive recovery locations:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Claim/enforcement truthfulness | 24 | The guide must never label an organizational or concurrency assumption as a portable filesystem proof. |
| Sensitive-state confidentiality | 22 | A copied recovery must have a deliberate private-location boundary before plaintext state is created. |
| Copy/paste usability | 16 | Operators need a concrete, understandable contract that permits legitimate controlled locations. |
| Deterministic machine enforcement | 14 | Type, canonical form, ownership, mode, final absence, and path binding should fail before the provider. |
| Environment portability | 10 | The contract must survive different VCS, ACL, mount, and storage-policy environments without false proof. |
| Harness/oracle quality | 10 | Accepted/rejected fixtures must say exactly what code proves and what remains attested. |
| Complexity/churn | 4 | Added ceremony matters, below truthful confidentiality and usability. |

### Scored comparison

| Option | Truth 24 | Confidentiality 22 | Usability 16 | Enforcement 14 | Portability 10 | Tests 10 | Churn 4 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — two layers + bound attestation | 5 | 5 | 5 | 4 | 5 | 5 | 4 | **96.4** |
| B — claim complete probing | 4 | 5 | 2 | 4 | 2 | 4 | 1 | 71.6 |
| C — only current machine checks | 2 | 2 | 5 | 3 | 5 | 2 | 5 | 60.8 |
| D — automatically create parent | 4 | 5 | 4 | 5 | 3 | 5 | 2 | 85.6 |
| E — force runtime-private directory | 3 | 4 | 2 | 4 | 2 | 4 | 3 | 64.0 |
| F — container/VM only | 4 | 4 | 1 | 4 | 2 | 3 | 1 | 62.8 |
| G — direct provider destination | 2 | 1 | 4 | 4 | 5 | 3 | 5 | 58.0 |
| H — documentation warning only | 5 | 2 | 5 | 1 | 5 | 1 | 5 | 67.6 |

Option A is the strongest honest contract: it enforces everything the portable
block can observe and makes the remaining environmental judgment explicit,
deliberate, and path-bound.

### Selected resolution

Select **Option A — explicit two-layer contract with path-bound attestation**.

Implement it in T2 as follows:

1. Replace the undifferentiated “protected parent” prose with two titled lists.
   **Operator-attested preconditions** are:
   - outside every version-controlled worktree;
   - outside shared/world-readable or otherwise inappropriate temporary
     storage under organizational policy;
   - owned/access-controlled for plaintext Terraform state, including ACL and
     mount/share policy;
   - no other process/principal can create, replace, or rename entries during
     the invocation; and
   - the parent and final destination share a filesystem that supports the
     required GNU hard-link no-replace behavior.
2. State that the script cannot prove those facts completely. Canonical path,
   effective UID, mode, and optional Git probes are defense in depth, not a
   substitute for the attestation.
3. Require the operator to set three independent values once:
   - `RECOVERY_PARENT` — the exact selected absolute protected directory;
   - `RECOVERY_PATH` — one new absolute file directly beneath that parent; and
   - `RECOVERY_PARENT_ATTESTATION` — exact literal
     `private-outside-vcs-no-competing-writers`.
4. At the start of each subshell, snapshot all three strings once without
   trimming. Reject unset/empty, leading/trailing whitespace, CR/LF/control,
   relative, repeated/trailing separator, `.`/`..`, and malformed values before
   filesystem/provider activity. Environment variables cannot carry NUL; state
   that boundary rather than pretending to test an embedded NUL value.
5. Resolve `RECOVERY_PARENT` with the required GNU `realpath -e --`; require
   exact byte equality with the supplied value so symlink components and
   lexical aliases are rejected. Require it is an existing directory and
   `! -L`.
6. Require GNU `stat` to report the parent owned by the effective UID and mode
   exactly `0700`. Treat inability to obtain/parse either value as failure.
   Explain that these checks do not rule out ACL, root/administrator, mount, or
   remote-storage access; those remain attested.
7. Derive `RECOVERY_PATH`'s lexical parent without invoking provider tools and
   require exact equality with the validated parent. Require a nonempty leaf,
   and require both `! -e` and `! -L` immediately before creating the private
   invocation directory.
8. Require the exact attestation literal only after all three values are
   snapshotted and before `mktemp` or provider invocation. Wrong case, added
   whitespace, alternate wording, missing value, or a value sourced from the
   destination path fails with one stable diagnostic.
9. Preserve the explicit statement that the preflight is not a filesystem
   lock. If the no-competing-writer attestation is false, the operator must
   stop; neither repeated `test` nor `ln --no-target-directory` makes the whole
   workflow safe against a hostile parent.
10. Extend the harness inventory with exact parent-boundary cases:
    - accepted canonical owned mode-0700 directory + direct fresh child + exact
      attestation;
    - missing/wrong/case-varied/whitespace attestation;
    - parent/path mismatch and nested child;
    - relative/noncanonical/dot/trailing-separator parent;
    - absent/file/symlinked parent and symlinked ancestor;
    - wrong owner where the runner can create one, otherwise a narrowly
      recorded environmental skip;
    - modes `0777`, `0755`, `0750`, `0711`, and `0700`;
    - existing file/directory/live link/dangling link final; and
    - provider stub proof that every rejected row makes zero provider calls.
11. For the semantic preconditions the harness asserts only:
    - the exact attestation label and literal exist in all three extracted
      blocks and generated copies;
    - missing/wrong attestation rejects; and
    - the guide/rationale explicitly says VCS/shared-storage/ACL/concurrency
      truth is operator-attested, not machine-proven.

    It must not label a synthetic fixture as proof of a real operator's VCS,
    ACL, mount, or competing-writer environment.
12. Apply the identical parent contract and stable reason IDs to AWS, Azure, and
    GCS while preserving separate provider lifecycle rows.

**Status: selected and ready for incorporation into T2.**

The next finding to evaluate is T2-03.

## T2-03 — Apply an explicit protected-parent contract to direct HCP output

### Finding and decision constraints

The HCP Terraform block gives `TFC_RESPONSE_PATH` fresh-file/noclobber/mode
protection, but it does not apply the same explicit parent selection,
repository exclusion, shared-storage attestation, canonical/type/owner/mode
checks, or accepted/rejected parent cases selected for AWS/Azure/GCS. HCP state-
version API pages can contain the same plaintext secrets as a recovered state
file. Its temporary curl config additionally contains the bearer token, so an
underspecified config-root location is a second confidentiality gap.

The resolution must preserve HCP's intentionally different direct-response
lifecycle—failed empty/partial pages are retained as invalid sensitive
evidence and a caller chooses a fresh path for every retry—while giving the
response parent and token-bearing config root a protection contract at least as
strong and as honestly stated as T2-02.

### Resolution options

#### Option A — HCP-specific names implementing the same two-layer parent contract

Require `TFC_RESPONSE_PARENT`, `TFC_RESPONSE_PATH`, and
`TFC_RESPONSE_PARENT_ATTESTATION`. Give the parent the identical
operator-attested preconditions and canonical/type/effective-owner/mode-0700
machine checks selected in T2-02, and require the response path to be one fresh
direct child. Create the random curl-config root under that validated parent,
with mode 0700 and a mode-0600 ordinary config file. Open the response once
under Bash noclobber/umask 077, pass its descriptor to curl, and never invent an
alternate filename.

HCP retains its own postconditions:

- success leaves one protected response page for deliberate inspection;
- curl/HTTP failure leaves the exact empty/partial protected page, labels it
  invalid, and requires a new path for retry;
- config cleanup removes only the exact owned ordinary config and empty root;
  uncertainty retains/names the root and fails; and
- no result deletes or follows a response path automatically.

Permutations:

- reuse generic `RECOVERY_PARENT` variables or use HCP-specific names. Use
  HCP-specific names so a page response cannot be confused with a validated
  provider recovery artifact;
- place the curl-config directory under the response parent or a separately
  attested private parent. Use the same parent to avoid a second independent
  policy decision and keep both sensitive files within one declared boundary;
- share textual validation logic among marked blocks or duplicate it. Shared
  harness helpers are appropriate, but the published HCP block remains
  self-contained; and
- remove a failed empty page automatically or retain every opened page. Retain
  it as the current contract requires because response bytes/HTTP diagnostics
  can aid investigation and cleanup cannot infer sensitivity/ownership beyond
  the exact file.

#### Option B — Reuse the generic recovery variables and lifecycle verbatim

Apply `RECOVERY_PARENT`/`RECOVERY_PATH` and the candidate-validation/hard-link
publication flow to HCP pages. Protection is strong, but terminology suggests
the JSON page is already validated recoverable state; HCP pagination and
failed-partial retention do not match provider download/publication semantics.

#### Option C — Keep file protection and add a documentation-only parent warning

Say the response parent should be private/outside Git but require no distinct
parent or attestation. This is honest only if phrased as advice, and a copied
block can still create the state response and token config in the current
directory or another unintended parent without a deliberate gate.

#### Option D — Use `$TMPDIR`/runner temp for response and config

Create both files in the ambient temporary directory with mode 0600. Mode
reduces exposure, but the parent's ownership, sharing, retention, cleanup, and
artifact collection policies are environment-dependent and contradict the
explicit outside-inappropriate-temporary-storage precondition.

#### Option E — Use the current working directory

Require only fresh names and restrictive modes in `$PWD`. This is highly usable
but often places state/API pages inside a cloned Git worktree, where status
commands, editor/indexers, backups, or accidental commits can expose them.

#### Option F — Download to a private temporary file, validate JSON, then no-replace publish

Adopt the recovery blocks' staging model for each API page. This provides a
clean final-only-on-success property, but HCP's selected contract intentionally
retains failed partial responses as invalid evidence and pagination metadata may
need inspection even when the API body is semantically unexpected. It also adds
a JSON/API schema validation scope not specified by this issue.

#### Option G — Let `mktemp` choose and print the response filename

Avoid caller-selected paths and use a protected random leaf. This reduces name
races but makes pagination/retry evidence harder to organize, risks printing a
sensitive path, and still depends on a safe parent. It does not remove the need
for T2-02's policy boundary.

#### Option H — Keep the API response on stdout/in a shell variable

Avoid a response file and pipe directly to an operator tool. State JSON can
reach terminals, logs, command substitutions, CI captures, or environment/
memory limits; it prevents the intended protected per-page evidence lifecycle.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric is specific to direct HCP
API page and bearer-config containment:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| State/token confidentiality | 25 | Both response pages and the curl config contain high-value plaintext secrets. |
| Fresh no-clobber response integrity | 20 | The chosen page path must never overwrite, redirect through, or silently rename an existing object. |
| Cross-provider protection consistency | 16 | “Protected parent” must have the same semantic meaning while preserving HCP's distinct lifecycle. |
| Curl-config containment/cleanup | 14 | The token-bearing config needs an exact owned root, restrictive modes, and fail-closed cleanup. |
| Operator pagination/retry usability | 10 | Operators need deliberate page paths and clear retained-invalid behavior without confusing them with recovered state. |
| Exact harness coverage | 10 | Parent, path, config, response, failure, and retry outcomes need stable cases. |
| Scope/churn | 5 | Added machinery matters, below protection of token and state. |

### Scored comparison

| Option | Confidentiality 25 | No-clobber 20 | Consistency 16 | Config 14 | Usability 10 | Tests 10 | Churn 5 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — HCP-specific same parent contract | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.0** |
| B — generic recovery variables/lifecycle | 5 | 5 | 3 | 5 | 2 | 4 | 3 | 83.6 |
| C — protected file + parent advice | 3 | 4 | 2 | 3 | 5 | 2 | 5 | 64.8 |
| D — ambient temporary directory | 1 | 4 | 2 | 1 | 4 | 3 | 4 | 48.2 |
| E — current working directory | 1 | 3 | 1 | 2 | 5 | 2 | 5 | 44.8 |
| F — staged page publication | 5 | 5 | 4 | 5 | 3 | 4 | 1 | 86.8 |
| G — `mktemp`-selected response | 4 | 5 | 2 | 4 | 2 | 3 | 2 | 69.6 |
| H — stdout/shell response | 1 | 5 | 1 | 4 | 3 | 2 | 5 | 54.4 |

Option A gives HCP pages and the bearer config the same confidentiality boundary
without falsely treating an API page as a validated recovered state artifact.

### Selected resolution

Select **Option A — HCP-specific names implementing the same two-layer parent
contract**.

Implement it in T2 as follows:

1. Add the same T2-02 **Operator-attested preconditions** to HCP response
   storage: outside VCS and inappropriate shared temporary storage,
   access-controlled including ACL/mount/share policy, no competing writer, and
   suitable local filesystem semantics. Explicitly label them as attested, not
   fully machine-proven.
2. Require/snapshot once:
   - `TFC_RESPONSE_PARENT`;
   - `TFC_RESPONSE_PATH`; and
   - `TFC_RESPONSE_PARENT_ATTESTATION` with exact literal
     `private-outside-vcs-no-competing-writers`.
3. Apply T2-02's ordered raw grammar and canonical checks with HCP-specific
   stable reason IDs: no missing/empty/whitespace/control/relative/ambiguous
   value; `realpath -e` exact equality; existing ordinary non-link parent;
   effective-UID ownership; exact mode 0700; exact attestation.
4. Require `TFC_RESPONSE_PATH` to be a nonempty direct child of the exact
   validated parent, with neither `-e` nor `-L` true. Recheck that exact absence
   immediately before opening, and reject every mismatch before token config or
   curl invocation.
5. Run `set +x` as the subshell's first command, then `set -euo pipefail`,
   `umask 077`, and the validations. Never print or trace the raw parent,
   response path if policy treats it as sensitive, token, config, URL query
   values, or response bytes.
6. Create the curl-config root with `mktemp -d --` directly under the validated
   parent. Require it is the exact expected direct child, ordinary non-link,
   effective-UID-owned, and mode 0700. Create the config once with noclobber,
   require ordinary non-link mode 0600, and write only the already-validated
   fixed option grammar.
7. Open the exact response with Bash noclobber while `umask 077` is active;
   require one ordinary non-link effective-UID-owned mode-0600 file and pass
   only the opened descriptor to the exact curl command. Do not use curl output
   filename selection, alternate names, stdout capture, `tee`, or shell
   variables for the body.
8. Capture curl's status immediately, close the response descriptor on every
   path, and preserve these exact response postconditions:
   - success: response file retained and marked ready for the documented
     pagination inspection;
   - curl/HTTP/validation failure: exact empty/partial file retained and
     reported as **invalid sensitive evidence**, retry forbidden at that path;
   - pre-open validation failure: response absent.
9. Give config cleanup one `EXIT` owner and HUP/INT/TERM terminators using
   T2-01's status precedence. Remove only the exact ordinary config then empty
   root; retain/name substituted, linked, extra, raced, or undeletable config
   state. Never delete or follow the response in cleanup.
10. Extend the harness with the complete T2-02 parent/path/attestation matrix
    under HCP-specific IDs, plus:
    - config root/file exact parent/type/owner/modes;
    - response pre-open absence and post-open type/owner/mode;
    - existing file/directory/live/dangling response path;
    - curl success, HTTP failure, empty partial, nonempty partial, and fresh-path
      retry;
    - config cleanup success/uncertainty;
    - HUP/INT/TERM after config and response creation; and
    - zero token/response bytes in stdout, stderr, argv records, and ordinary
      logs.
11. Add a reciprocal contract test which maps the AWS/Azure/GCS and HCP
    parent semantics field-by-field, requiring equality for grammar,
    attestation, canonical/type/owner/mode checks, and provider-before-call
    behavior, while marking response retention/publication as an intentional
    lifecycle difference.
12. Update HCP source/rationale/generated blocks and acceptance wording to say
    that direct response files have the same protected-parent preconditions as
    recovery files; do not use the bare phrase “protected response” without
    linking it to this exact contract.

**Status: selected and ready for incorporation into T2.**

The next finding to evaluate is T2-04.

## T2-04 — Define provider-identifier control-character rules

### Finding and decision constraints

T2 quotes shell expansions, but quoting only preserves an argument boundary; it
does not decide whether a bucket, account, container, object/key,
organization/workspace, selected version ID, or generation is acceptable to
embed in diagnostics, confirmation text, CLI-specific resource syntax, or curl
data. Provider grammars differ sharply: S3/Azure/GCS object names can be much
broader than a safe copyable shell surface, while S3/Azure version IDs are
provider-generated opaque values that must not be parsed or normalized.

The resolution must define every public identifier once, reject CR/LF and all
controls before it is logged or used, preserve accepted bytes exactly, support
documented real version values, distinguish “valid provider name” from “narrow
grammar accepted by this example,” and provide a field-by-field fixture
inventory.

Provider documentation and the design implications are retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Publish a deliberate per-field safe subset and pass bytes unchanged

Add one normative identifier table listing each variable, ASCII grammar,
minimum/maximum byte length, forbidden forms, CLI destination, and whether the
value is a service-generated opaque identifier. Use a conservative subset:

- DNS-label-like lowercase bucket/account/container names;
- slash-separated ASCII object/key segments composed only of letters, digits,
  dot, underscore, and hyphen, excluding empty/`.`/`..` segments;
- bounded printable-ASCII opaque S3/Azure version IDs with the provider's
  documented punctuation, no whitespace/control/quotes/backslash, never
  decoded or parsed;
- canonical positive decimal GCS generation; and
- bounded ASCII alphanumeric/hyphen/underscore HCP organization/workspace
  names.

State prominently that this is not the provider's complete acceptance grammar.
If a legitimate resource/version falls outside it, stop and deliberately revise
the example/table/tests after checking current provider documentation; never
trim, escape, transliterate, case-fold, percent-decode, or auto-select another
identifier.

Permutations:

- implement full official bucket/account/container grammar or a stricter common
  DNS label. Use provider-specific narrow rows so valid existing examples work,
  while avoiding rarely used periods/underscores/reserved forms;
- allow full provider Unicode object names or only a shell/tool-safe ASCII
  subset. Use the subset because these examples construct CLI resource syntax
  and operator-visible evidence, not a general SDK;
- parse Azure's timestamp-looking version ID or preserve it as opaque. Preserve
  it; the service describes the field as opaque even though current values are
  timestamps;
- allow S3's literal `null` version. Permit it within the opaque grammar and
  require deliberate selection/documentation of its versioning semantics; and
- share one validator or retain self-contained blocks. Share exact fixture
  helpers, while each published block snapshots/validates its own fields.

#### Option B — Reimplement every current provider grammar exactly

Cite and encode full AWS/Azure/GCS/HCP name rules, UTF-8 byte/character/segment
limits, reserved prefixes, URI/tool quirks, and version formats. This maximizes
provider acceptance today but creates a large mutable policy engine in Bash,
still cannot authoritatively validate service-generated resource existence,
and encourages opaque-version parsing.

#### Option C — Keep fixed example resource literals; validate only selected versions

Hard-code bucket/account/container/object values and add controls/length checks
only for `VERSION_ID`, `AZURE_VERSION_ID`, `GCS_GENERATION`, and HCP filters.
The checked-in examples are safe, but operators necessarily replace the
resource literals when copying and receive no validation contract for their
new values.

#### Option D — Accept any nonempty control-free scalar

Snapshot values, reject ASCII/Unicode controls and leading/trailing whitespace,
quote each argument, and let the provider decide the rest. This is simple and
preserves broad valid names, but resource syntaxes such as `gs://bucket/key#id`
give `#`, slash, wildcard-like characters, and provider parsing special
meanings; a provider rejection occurs after confirmation/logging and is not a
stable local oracle.

#### Option E — Percent-encode or Base64-wrap every identifier

Transform broad input to a safe alphabet before command construction. Provider
CLIs do not uniformly decode such transformations at argument boundaries, so
the command may select a different resource. Encoding an opaque identifier
violates exact selection unless the specific interface explicitly requires it.

#### Option F — Depend on shell quoting alone

Use `"${value}"` and `${value:?}`. This prevents word splitting/globbing at the
shell layer but admits embedded newline/control content into logs and
confirmation, empty-adjacent resource segments, CLI wildcard/version syntax,
and identifiers the examples promise to guard.

#### Option G — Invoke the provider first as the validator

Let discovery/recovery fail on invalid names and use the exit status. This
performs authenticated network activity before local rejection, can expose
raw values in CLI diagnostics, conflates invalid grammar with authorization/
network/not-found failures, and cannot satisfy “before logging or confirmation.”

#### Option H — Shell-escape values for display and execution

Render `%q`/escaped values and feed those strings into commands. Display
escaping is useful for bounded diagnostics, but passing the escaped form changes
identity; evaluating it restores injection risk. Accepted raw bytes should be
passed as one argv element and rejected raw bytes should never be echoed.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric balances copy-safe syntax
with preservation of provider-generated identity:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Pre-log/CLI injection safety | 24 | Controls and syntax-active values must fail locally before evidence or network activity. |
| Provider semantic compatibility | 20 | Accepted values need to name real supported resource/version forms without pretending to be exhaustive. |
| Opaque identity preservation | 17 | Selected version/generation bytes cannot be parsed, normalized, encoded, or substituted. |
| Copy/paste usability | 14 | Operators need understandable field-specific rules and actionable failure guidance. |
| Documentation evolution safety | 10 | Provider grammar drift should cause deliberate review, not silent acceptance or false rejection claims. |
| Fixture completeness | 10 | Every field needs boundary, control, punctuation, and unchanged-argv cases. |
| Complexity/churn | 5 | Guard code should stay readable, subordinate to safety and identity. |

### Scored comparison

| Option | Safety 24 | Compatibility 20 | Identity 17 | Usability 14 | Evolution 10 | Tests 10 | Churn 5 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — explicit safe subsets | 5 | 4 | 5 | 4 | 5 | 5 | 3 | **91.2** |
| B — full provider grammars | 5 | 5 | 5 | 2 | 2 | 5 | 1 | 81.6 |
| C — fixed resources/version guards | 4 | 3 | 5 | 4 | 3 | 4 | 5 | 78.4 |
| D — any control-free scalar | 4 | 2 | 5 | 5 | 5 | 4 | 5 | 81.2 |
| E — encode every identifier | 5 | 1 | 1 | 2 | 2 | 3 | 2 | 47.8 |
| F — quoting only | 2 | 3 | 5 | 5 | 2 | 2 | 5 | 62.2 |
| G — provider as validator | 1 | 5 | 5 | 2 | 4 | 2 | 5 | 61.8 |
| H — shell-escaped identity | 4 | 1 | 1 | 2 | 3 | 3 | 3 | 47.6 |

Option A intentionally trades uncommon provider-valid names for a small,
reviewable interface while never modifying an accepted opaque selection.

### Selected resolution

Select **Option A — publish a deliberate per-field safe subset and pass bytes
unchanged**.

Implement it in T2 as follows:

1. Add a normative table to the issue/source/rationale with columns:
   provider, variable, semantic role, accepted ASCII grammar, byte min/max,
   explicit forbidden forms, opaque/locally structured, exact argv/config use,
   and primary provider source.
2. At the start of each exact block set `LC_ALL=C` within its subshell, snapshot
   every input exactly once, and validate it before confirmation, diagnostic,
   URI/resource-string construction, filesystem creation, config/token
   expansion, or provider invocation. Do not trim or normalize.
3. Apply these exact example-interface rows:
   - `AWS_S3_BUCKET`: 3–63 bytes, lowercase letter/digit/hyphen, alphanumeric
     endpoints, no `--`, no reserved prefix/suffix listed in the rechecked
     source; deliberately excludes periods;
   - `AWS_S3_KEY`: 1–1,024 bytes, slash-separated nonempty segments matching
     `[A-Za-z0-9][A-Za-z0-9._-]*`, no `.`/`..`, repeated/trailing slash;
   - `VERSION_ID`: 1–1,024 bytes, opaque printable ASCII subset
     `[A-Za-z0-9._~+/%=-]+`, including deliberate literal `null`, with no
     parsing/decoding;
   - `AZURE_STORAGE_ACCOUNT`: 3–24 lowercase alphanumeric bytes;
   - `AZURE_CONTAINER`: 3–63 lowercase alphanumeric/hyphen bytes,
     alphanumeric endpoints, no `--`;
   - `AZURE_BLOB_NAME`: the same 1–1,024-byte safe segment grammar as the S3
     key;
   - `AZURE_VERSION_ID`: 1–128 bytes, opaque
     `[A-Za-z0-9._~:+%-]+`; do not parse the timestamp-looking value;
   - `GCS_BUCKET`: 3–63 lowercase alphanumeric/hyphen bytes, alphanumeric
     endpoints, no `--`; deliberately excludes broader valid dotted names;
   - `GCS_OBJECT`: the same 1–1,024-byte safe segment grammar;
   - `GCS_GENERATION`: canonical `[1-9][0-9]{0,19}`, passed as a string without
     arithmetic or range coercion; and
   - `TFC_ORGANIZATION`/`TFC_WORKSPACE`: 1–64 bytes,
     `[A-Za-z0-9][A-Za-z0-9_-]{0,63}`.
4. Immediately before implementation, re-read every linked provider source.
   If a selected subset is no longer wholly valid, stop and revise the issue,
   table, blocks, and fixtures. Do not automatically broaden the subset merely
   because the provider accepts more.
5. Bash ERE alone does not enforce byte count/segment semantics reliably in
   every locale. Under `LC_ALL=C`, check `${#value}` boundaries, the full ERE,
   then explicit structural exclusions (`--`, empty/`.`/`..` segments,
   reserved forms) in a fixed order with stable field/reason IDs.
6. Environment variables cannot contain NUL. Reject all other ASCII controls
   (`0x01`–`0x1f`, `0x7f`), CR/LF, leading/trailing whitespace, and non-ASCII
   bytes through the closed grammar. Diagnostics name only the field and stable
   reason; never echo the rejected value.
7. Build resource arguments only after every component passes. Pass each
   accepted variable unchanged as one quoted argv element. For GCS, concatenate
   the three already-validated components into exactly
   `gs://${GCS_BUCKET}/${GCS_OBJECT}#${GCS_GENERATION}` without `eval`; for HCP,
   keep organization/workspace as distinct `--data-urlencode` values.
8. Discovery must use the same validated bucket/account/container/object
   values as recovery. It may display provider-generated selected IDs as part
   of the provider's reviewed output, but the shell must not interpolate raw
   rejected input into its own diagnostic/confirmation.
9. Require deliberate selection variables and pass accepted opaque
   `VERSION_ID`/`AZURE_VERSION_ID` and structured `GCS_GENERATION` byte-for-byte
   unchanged. No case folding, Unicode normalization, percent/Base64
   encode/decode, timestamp parsing, shell arithmetic, locale digit, or
   fallback to latest/current is permitted.
10. If a real legitimate identifier falls outside the subset, instruct the
    operator to stop and have the example deliberately revised/retested. Do not
    recommend bypassing the guard or pre-transforming the identifier.
11. Add one machine-readable row per field for:
    missing/empty; just below/at/above byte bounds; accepted endpoints and
    punctuation; space/tab/CR/LF/other control/DEL/non-ASCII; leading/trailing
    whitespace; wrong case; field-specific repeated/empty/dot segments,
    consecutive hyphens, reserved bucket forms, and opaque documented samples.
12. Every positive row records the exact NUL-delimited stub argv and proves the
    accepted bytes appeared unchanged once in the correct position. Every
    negative row asserts its exact reason/status, zero provider calls, no raw
    value in stdout/stderr/call logs, absent destination/config, and unchanged
    sentinels.

**Status: selected and ready for incorporation into T2.**

The next finding to evaluate is T2-05.

## T2-05 — Harden Git and native-command evidence

### Finding and decision constraints

T2 requires exact nine-path working/staged gates and a no-further-generator-
diff proof, but it does not bind them to Git's NUL protocol or define native
exit classification. A line-based path list is ambiguous for valid filenames
containing newline/tab/escape characters. Treating any nonzero
`git diff --exit-code` result as “differences found” also accepts bad revisions,
repository/config failures, or process-launch errors as evidence.

T1B-05 already selects one permanent raw-byte Git path/status primitive in the
tracked workflow-policy validator. T2 must consume that merged interface rather
than create a subtly different shell parser, apply it to working/index/commit
endpoints, and make its shell harness execute real and injected `0`/`1`/error
states.

### Resolution options

#### Option A — Reuse the merged raw-byte gate through closed endpoint modes

Extend/consume the T1B validator's hand-authored Git gate as a CLI with closed
modes such as `status`, `cached-diff`, and `commit-diff`. The helper constructs
the exact Git argv itself, retains stdout as a `Buffer`, parses only NUL
records, and compares the complete set to explicit expected ASCII path buffers.
It immediately classifies diff status `0 = equal/no difference`,
`1 = differences`, and all other/start failures as command failure.

T2's permanent shell harness creates owned repositories containing normal and
delimiter-bearing paths, invokes the exact tracked helper, and asserts each
stable status/reason. Local validation uses that same helper before/after
staging and after regeneration, so tests and evidence cannot drift.

Permutations:

- pass an arbitrary Git argv or expose closed semantic modes. Use closed modes
  so a caller cannot omit `-z`, `--no-ext-diff`, endpoints, or the `--`
  separator;
- compare decoded JavaScript strings or raw buffers. Use buffers through record
  parsing/set equality and escape only bounded diagnostics;
- have T2 copy the code into Bash or consume the merged helper. Consume the
  merged helper, with an exact prerequisite version/commit check; and
- combine changed-path output and diff predicate in one Git call or run
  separate calls. A single `--exit-code --name-only -z` call can produce both,
  but each acceptance statement still records the classified status and parsed
  set independently.

#### Option B — Implement an independent Bash NUL parser

Redirect `git ... -z` to a protected temporary file, capture status, then use
`readarray -d ''`/quoted arrays and associative-set equality. This can be safe
if command substitution is forbidden and porcelain rename records are handled
exactly. It duplicates T1B's parser/status policy across Bash/Node and creates a
second fixture surface for the same semantic gate.

#### Option C — Use newline-delimited `git diff --name-only`

Sort textual lines and compare them to nine expected strings. Git may quote/
escape unusual paths or emit an actual newline-bearing name as multiple lines,
depending on options/config; trimming/sorting further changes identity.

#### Option D — Use only `git diff --quiet`

Correctly classify whether any difference exists but do not enumerate paths.
This proves clean/dirty, not that the complete change set is exactly the nine
authorized files or that no unrelated path is staged.

#### Option E — Parse human-oriented `git status --short`

The output is compact but subject to quoting/config and has multi-column
rename/copy syntax. Without `--porcelain=v1 -z` it is not a stable
machine/path-record protocol.

#### Option F — Hash the whole repository tree/worktree

Compute a tree or directory digest and compare with a prepared expectation.
This may detect change but gives no authorized path-set proof, handles untracked
files/modes/metadata inconsistently, and makes the expected hash another
implementation-derived snapshot.

#### Option G — Use GitHub's changed-files API

Ask the pull-request/commit API for changed paths. It does not describe the
developer's working tree/index during local validation, adds network/token/
pagination behavior, and cannot prove the staged contents being merged.

#### Option H — Manual `git status` review

Display status and require a reviewer to confirm nine paths. Human review is a
useful secondary check but cannot give the permanent exact fixture/status
oracles required by the issue.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric is specific to trustworthy
repository-scope evidence:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Complete affected-set identity | 24 | Worktree, index, commit, and regeneration evidence must name exactly the authorized nine paths. |
| Native error fidelity | 20 | Bad Git/revisions/process failures must never masquerade as expected differences or cleanliness. |
| Delimiter/quoting resilience | 16 | Valid spaces, tabs, newlines, leading dashes, quotes, and backslashes cannot alter records. |
| Predecessor-policy reuse | 14 | T2 should consume the merged T1B primitive rather than establish a divergent security contract. |
| Endpoint/layer coverage | 12 | Working state, staged state, base-to-head change, and post-generator state are distinct facts. |
| Fixture realism and diagnostics | 9 | Real repositories plus controlled command failures need stable, secret-safe reason output. |
| Effort/churn | 5 | Reuse is valuable, below correctness of repository evidence. |

### Scored comparison

| Option | Set 24 | Status 20 | Delimiters 16 | Reuse 14 | Layers 12 | Fixtures 9 | Churn 5 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — merged raw-byte closed-mode gate | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.0** |
| B — independent Bash NUL parser | 5 | 5 | 4 | 2 | 5 | 5 | 3 | 86.4 |
| C — newline name list | 3 | 3 | 1 | 1 | 4 | 2 | 5 | 49.0 |
| D — quiet predicate only | 1 | 5 | 5 | 4 | 2 | 3 | 5 | 59.8 |
| E — short-status text | 3 | 3 | 1 | 1 | 4 | 2 | 4 | 48.0 |
| F — repository hash | 2 | 4 | 4 | 1 | 2 | 3 | 2 | 51.0 |
| G — GitHub changed-files API | 3 | 4 | 5 | 1 | 1 | 3 | 1 | 56.0 |
| H — manual status review | 2 | 2 | 2 | 1 | 3 | 1 | 5 | 36.2 |

Option A provides exact local evidence with no new path grammar and makes the
T2 harness a consumer/tester of the writer-layer invariant it inherits.

### Selected resolution

Select **Option A — reuse the merged raw-byte gate through closed endpoint
modes**.

Implement it in T2 as follows:

1. At implementation start, resolve T1B's actual landed commit/version and
   verify the tracked validator exposes the selected raw-buffer path-set/native-
   status contract. Stop and rebaseline if its interface or fixtures differ;
   do not paste an independent line/Bash parser.
2. Expose only hand-authored modes with exact Git argv:
   - `status`: `git status --porcelain=v1 -z --untracked-files=all`;
   - `cached-diff`: a fixed `git diff --cached --name-only -z --exit-code`
     form between the validated base and index;
   - `commit-diff`: a fixed
     `git diff --name-only -z --exit-code <base> <head> --`; and
   - `quiet-diff`: a fixed `git diff --quiet` form for the named endpoint pair.

   Add `--no-ext-diff`, disable text conversion where applicable, include the
   literal `--` terminator, and accept only separately validated full commit
   IDs/closed endpoint choices—not caller-provided option strings.
3. For `status`, require Git status `0`; any other/process-start result is a
   command failure. Parse each NUL record's exact porcelain-v1 status prefix and
   path bytes. Reject rename/copy, conflict, submodule, duplicate, empty,
   malformed, or unexpected status records because T2 authorizes only modified
   known files and one added known harness.
4. For each diff mode, capture status before any other process:
   - `0`: no difference and the path stream must be empty;
   - `1`: differences exist and a complete well-formed NUL path set is
     required;
   - every other numeric, signal, timeout, or process-start result: execution
     failure; ignore any partial stdout as evidence.
5. Retain stdout as bytes, require empty or exactly one terminal NUL, split
   only at byte `0x00`, discard only the terminal empty segment, reject
   duplicate/interior-empty records, and compare sorted raw path-byte sets.
   Never use command substitution, decoded lines, whitespace trimming, Git
   quoted output, regex substring matching, or locale collation.
6. Expected paths are the exact nine T2 ASCII repository-relative byte strings.
   Reject absolute paths, leading dash aliases, empty/`.`/`..` components,
   backslash separator aliases, and noncanonical encodings before equality.
   Diagnostics emit a stable reason plus bounded hexadecimal/JSON-escaped path,
   never raw control-bearing text.
7. Before staging, require `status`'s complete changed/untracked set equals the
   nine paths and has only authorized unstaged/new statuses. Stage exactly the
   nine literal paths with `git add --`, capture its status immediately, then
   require `status` and `cached-diff` both equal the nine paths with authorized
   staged statuses.
8. Rerun source/harness/generator validation from staged content. Require the
   staged blob set remains nine, then use the correct quiet/diff endpoint to
   prove the generator introduces no additional unstaged byte change. Record
   the actual `0`/empty result; do not call a `>1` error “no diff.”
9. At commit/PR evidence time, compare the exact validated prerequisite/base
   commit to reviewed head and require the complete set equals nine. Keep this
   distinct from index/worktree observations.
10. Add permanent harness cases in owned temporary Git repositories for:
    empty set/status `0`; one expected difference/status `1`; exact nine;
    missing/extra/duplicate; untracked; rename/copy/conflict; and paths
    containing space, tab, newline, leading dash, quote, backslash, and
    Git-quote-looking bytes. Git forbids NUL in a pathname, so malformed NUL
    streams are parser-unit fixtures, not fake filesystem names.
11. Exercise real invalid revision/repository/config cases producing Git errors
    and controlled process results `2`, `126`/`127` or start failure. Assert
    each stable failure reason, that partial stdout is discarded, and that no
    later command overwrote the captured status. Test timeout/signal
    classification separately where supported.
12. Make the shell harness invoke the exact tracked validator/helper for these
    cases after its own syntax/provider cases. Reject missing, duplicate, or
    skipped Git/status IDs. Preserve offline operation and the existing
    workflow action/permission topology.
13. Replace all inherited “changed files”/“no diff” prose with the exact
    endpoint, NUL-byte parser, expected set relation, and status classification;
    acceptance must name all four layer observations independently.

**Status: selected and ready for incorporation into T2.**

The next finding to evaluate is T3-01.

## T3-01 — Pin one exact npm and its resolution mechanism

### Finding and decision constraints

T3 currently says to use “one selected supported npm” but names no version,
representation, resolver, integrity, or drift gate. Node 22 and 24 distribute
different bundled npm versions; a `packageManager` field alone does not
intercept ordinary `npm` calls because npm's Corepack shim is not enabled by
default. Consequently CI cells, Git/Husky hooks, audit collection, fixture
runners, and local validation could produce different lock/audit/install
behavior while all appearing to follow the issue.

The resolution must choose a maintained compatible release as of the planning
snapshot, bind its package bytes, give every supported Node/OS surface one
invocation form, make bootstrapping explicit, reject ambient/global fallback,
remain usable from a real Git hook, and make tool-version drift a policy failure
rather than a log annotation.

Registry/Corepack facts and integrity are retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Hashed `packageManager` descriptor and explicit Corepack npm

Select `npm@12.0.2`. Add:

```json
"packageManager": "npm@12.0.2+sha512.b885e890b9418fa1693544d05f53e64f9a73ec194837d4258b15fecdd692347b1dd2a517b1b0cbaf9d31cd8e92c3b70956bd2ecc72833a57b4b3098f5bfa7943"
```

Invoke every package operation as `corepack npm ...`, never ambient `npm`/`npx`.
The admitted Node 22/24 lines include Corepack; exact Node cells plus recorded
Corepack version/path make resolution observable. Disable latest auto-selection
and auto-pin mutation, require strict project selection/integrity, hydrate the
exact manager, then require `corepack npm --version` to equal `12.0.2` before
any install/script/audit. The real hook uses the same command.

Permutations:

- enable an npm shim and call `npm`, or invoke `corepack npm` explicitly.
  Prefer the explicit form so PATH/global npm cannot silently bypass Corepack;
- include an exact npm devDependency too. Avoid it because npm's large package
  tree would become an application/audit dependency solely to locate the
  package manager;
- vendor/cache the Corepack package-manager archive for fully offline bootstrap
  or hydrate from the registry. The repository already performs networked clean
  installs; use the exact hash-verified registry artifact and test a second
  run with network disabled/cache hydrated;
- pin one Corepack version across both Node lines or consume each exact Node
  release's bundled Corepack. Record each bundled resolver and test descriptor
  behavior; npm bytes/version remain identical; and
- select npm 11.7.0 from the baseline or current npm 12.0.2. Select 12.0.2
  because it is the registry latest on the evidence date and explicitly
  supports the reviewed Node lines at exact patch floors.

#### Option B — Exact npm as a root devDependency/local CLI

Add `"npm": "12.0.2"` to devDependencies and invoke
`node node_modules/npm/bin/npm-cli.js`. This is deterministic after install and
works offline in the hook, but the initial clean install still uses an ambient
manager unless another bootstrap is specified. It also adds npm's own large
dependency graph to the application lock/audit and can create self-referential
upgrade noise.

#### Option C — Install npm globally at the start of each job

Run `npm install --global npm@12.0.2`, then verify `npm --version`. This makes
the later manager exact but uses an uncontrolled bundled npm for bootstrap,
mutates runner/global state, differs under permissions/version managers, and
does not give local hooks a project-bound resolver or tarball hash.

#### Option D — Use the npm bundled with each exact Node release

Pin Node patches and accept their bundled npm. Setup is simple and supported by
Node, but the selected npm differs across the Node 22/24 matrix and over Node
patch updates, directly violating the one-manager audit/lock contract.

#### Option E — Use `npx npm@12.0.2`/`npm exec` for every operation

An exact package spec is better than a tag, but the ambient npm remains the
resolver, each invocation can fetch/cache independently, hook execution may
require network, and the project has no hashed manager identity unless another
mechanism is added.

#### Option F — Add `packageManager` but keep calling ambient `npm`

The field documents intent, and some tools warn on mismatch, but Node's
Corepack documentation says npm shims are not enabled by default. A global/
bundled npm can therefore ignore the selection.

#### Option G — Vendor the npm tarball or expanded CLI

Commit the exact package-manager bytes and run them with Node. This gives
offline bootstrap and immutable repository identity, but adds a large vendored
third-party distribution, license/update/scanning burden, affected files, and
diff noise. The existing registry/lock workflow does not require this cost.

#### Option H — Use a range or `latest`

Declare `npm@^12`, `npm@12`, or resolve `latest` per run. This picks up fixes
automatically but makes lockfile/audit output and engine floors time-dependent;
the exact behavior being governed is unknowable until runtime.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric is specific to package-
manager identity across a multi-Node/multi-OS hook and audit surface:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Exact package-manager identity | 25 | Install/lock/audit semantics must come from one full version and verified artifact. |
| Node/OS/hook consistency | 20 | Ubuntu, Windows/Git Bash, Node 22/24, local checks, and real hooks must invoke the same npm. |
| Bootstrap/integrity assurance | 15 | The first resolution step cannot silently substitute a tag, known-good release, or disabled integrity. |
| Hook/offline-after-hydration usability | 12 | A normal commit should not depend on ambient npm or refetch when the selected manager is cached. |
| Mechanical drift rejection | 12 | Package metadata, workflow, commands, diagnostics, and observed version must agree. |
| Supply-chain/audit surface | 10 | Selecting npm should not needlessly add npm itself to the governed application dependency graph. |
| Churn/implementation effort | 6 | Setup cost matters after reproducibility and hook behavior. |

### Scored comparison

| Option | Identity 25 | Consistency 20 | Bootstrap 15 | Hook 12 | Drift 12 | Surface 10 | Churn 6 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — hashed Corepack npm | 5 | 5 | 5 | 4 | 5 | 5 | 4 | **96.4** |
| B — npm devDependency | 5 | 5 | 3 | 5 | 5 | 2 | 3 | 85.6 |
| C — global exact install | 5 | 4 | 3 | 4 | 3 | 3 | 2 | 75.2 |
| D — Node-bundled npm | 2 | 1 | 4 | 5 | 2 | 5 | 5 | 59.8 |
| E — `npx` exact package | 4 | 4 | 2 | 2 | 4 | 4 | 4 | 66.4 |
| F — metadata only/ambient npm | 2 | 1 | 1 | 4 | 2 | 5 | 5 | 48.6 |
| G — vendor npm | 5 | 5 | 5 | 5 | 5 | 2 | 1 | 89.2 |
| H — range/latest | 1 | 1 | 1 | 3 | 1 | 5 | 5 | 40.2 |

Option A pins both the semantic manager version and downloaded package bytes
while avoiding a second application dependency tree or global install.

### Selected resolution

Select **Option A — hashed `packageManager` descriptor and explicit Corepack
npm**, with exact npm `12.0.2`.

Implement it in T3 as follows:

1. Re-query the official registry immediately before implementation. Record
   npm version, publish time, engines, tarball URL, SRI, unpacked provenance,
   license, and changelog. If `12.0.2` is withdrawn, deprecated, integrity-
   changed, or incompatible, stop and revise this issue/evaluation rather than
   substituting `latest`.
2. Add the exact hashed `packageManager` descriptor shown above to
   `.github/workflows/package.json`; do not add npm as a dependency. The
   structural validator requires exact field/type/value and the lock/package
   policy records this as the only selected manager.
3. Regenerate lockfile version 3 only through `corepack npm` reporting
   `12.0.2`. Record the manager's resolved executable/package location and
   `process.execPath`; never hand-edit the lock.
4. Standardize the invocation everywhere as:
   `corepack npm <subcommand>`. This includes CI clean installs, `npm ls`,
   outer/nested scripts, audit capture, outdated/inventory, integration
   fixtures, scheduled/manual governance, local validation, and the real
   Husky hook. Ban direct `npm`, `npx`, `npm.cmd`, global npm paths, aliases, and
   package-manager ranges/tags in governed scripts/workflows.
5. Before hydration/use, require `corepack` resolves as an application and
   record its absolute path/full version. Reject values which disable integrity,
   strict project selection, or project spec. Set/validate:
   `COREPACK_DEFAULT_TO_LATEST=0`,
   `COREPACK_ENABLE_AUTO_PIN=0`,
   `COREPACK_ENABLE_STRICT=1`, and
   `COREPACK_ENABLE_PROJECT_SPEC=1`; require
   `COREPACK_INTEGRITY_KEYS` is neither `0` nor empty.
6. Invoke `corepack npm --version` before any project install and require exact
   stdout `12.0.2`, status `0`, no extra line/whitespace. Reject missing
   Corepack, descriptor/hash mismatch, download/signature/integrity failure, a
   different version, or execution under a Node outside T3-02 policy as a
   tooling failure.
7. Hydration may access the registry during the normal networked install phase.
   After one clean successful install, run the second clean install and core
   fixture subset with `COREPACK_ENABLE_NETWORK=0` against the hydrated cache
   to prove no fallback/refetch is needed. CI caches remain disabled; this is a
   job-local resolver cache, not a cross-run dependency cache.
8. In `.husky/pre-commit`, resolve/check actual Node policy first, then resolve
   `corepack`, assert the exact selected npm through `corepack npm --version`,
   and invoke scripts through `corepack npm`. A missing/unhydrated/wrong
   manager fails with stable remediation guidance; it never falls back to
   bundled npm or downloads silently during a commit.
9. Setup instructions tell contributors to use admitted Node 22/24, explicitly
   hydrate the project's hashed manager once, and verify `corepack npm
   --version`. Do not recommend a global npm update as the repository contract.
10. Make `Check-NodePolicy.mjs`/workflow policy verify exact agreement among
    `packageManager`, commands, observed version evidence, and the
    package-manager constant. The audit summary records npm `12.0.2`; a
    different value is input/tool failure, not a changed baseline.
11. Add stable cases for missing Corepack; direct ambient npm on PATH at wrong
    version; exact manager on both Node lines/OS families; malformed/ranged/
    tag/wrong hash descriptor; known-good/latest fallback attempt; integrity/
    strict/network override; empty/unhydrated cache; hydrated offline use; and
    exact real-hook invocation. Each asserts whether any install/script ran.
12. Any npm update requires atomically revising the issue decision, exact
    descriptor/hash, engine-derived Node floors, lockfile, policy constants,
    all observed-version assertions, audit baseline evidence, fixtures, and
    references.

**Status: selected and ready for incorporation into T3.**

The next finding to evaluate is T3-02.

## T3-02 — Derive exact Node patch floors and remove the even-major shortcut

### Finding and decision constraints

T3's illustrative `>=22 <23 || >=24 <25` accepts Node 22 releases that cannot
run the selected npm. With T3-01's npm `12.0.2`, the published manager engine is
`^22.22.2 || ^24.15.0 || >=26.0.0`. The repository deliberately supports
reviewed LTS contributor lines, not every runtime npm supports: Node 26 is still
Current at the planning snapshot, and Node 27 begins a release model in which
every major—not only even majors—is intended to become LTS.

The resolution must intersect exact npm/package-tree engine constraints with a
finite reviewed Node release-line policy; name real patch floors; reject
pre-release/malformed/below-floor/EOL/current/unreviewed-future versions; keep
`package.json`, pure predicate, workflow cells, hook, and diagnostics identical;
and provide real plus synthetic boundary cases.

Current registry/Node release evidence is retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Finite per-major interval table derived from npm and release review

Admit exactly:

```text
Node 22: >=22.22.2 <23
Node 24: >=24.15.0 <25
```

Encode the same canonical range in `engines.node` and a dependency-free table
in `Check-NodePolicy.mjs`. Node 22/24 are admitted because their current
release-status/lifetime and full final dependency tree are reviewed; npm's
additional `>=26.0.0` engine branch is not repository authorization. Use exact
real CI cells at both floors and current reviewed patches (`22.23.2`,
`24.18.1` at the evidence date), while the pure predicate tests immediately
below/at/above every boundary and all intervening/future majors.

Permutations:

- use a semver library or a small exact parser/table. Use a dependency-free
  canonical `major.minor.patch` parser and lexicographic integer comparison so
  runtime policy does not depend on the packages it gates;
- admit only Node 24 or both 22/24. Retain both reviewed LTS lines because npm
  and selected tooling support them and T3 explicitly promises a minimum plus
  preferred line;
- set the policy floor to each npm engine floor or the latest patch. Floors
  define supported compatibility; exact current patches are CI evidence, not a
  rule that rejects later security patches;
- accept leading `v`, prerelease, build metadata, or leading zeros. Production
  `process.versions.node` is canonical, so reject all non-`x.y.z` synthetic
  forms and validate only the actual process in the CLI/hook; and
- infer LTS from parity/status at runtime or record a finite table. Record the
  finite table with evidence dates/end dates; future lines require review.

#### Option B — Copy npm's full `engines.node` range

Use `^22.22.2 || ^24.15.0 || >=26.0.0`. This guarantees npm compatibility but
automatically admits Current Node 26 and every future major, even when
repository packages/hooks and release status have not been reviewed. It also
becomes increasingly wrong as npm's open-ended branch outlives policy.

#### Option C — Keep the generic even-major rule

Admit supported-looking even majors and reject odd majors. It accepts
22.0–22.22.1 despite npm's engine, may admit EOL Node 20 or unreviewed 26, and
will reject intended LTS Node 27 under the announced schedule change.

#### Option D — One unbounded minimum such as `>=22.22.2`

This fixes the immediate npm floor but admits Node 23/25 EOL lines, Node 26
Current, future breaking majors, and versions of Node 24 below npm's separate
24.15.0 floor.

#### Option E — Support only Node 24 at `>=24.15.0 <25`

This is coherent, simple, and strong if the repository chooses one line. It
unnecessarily drops a maintained Node 22 contributor line that the selected
manager/dependencies can support and contradicts the requested minimum/
preferred compatibility evidence without a motivating incompatibility.

#### Option F — Read dependency engines dynamically on each run

Traverse installed metadata, intersect ranges, and combine with live Node
release data. This occurs too late for clean install/hook gating, needs a semver
implementation and perhaps network, produces a time-dependent support policy,
and lets dependency drift redefine authorization.

#### Option G — Allow only a short exact patch list

Admit exactly `22.22.2`, `22.23.2`, `24.15.0`, and `24.18.1`. This is highly
deterministic but rejects later compatible security patches until every patch
updates the repository, turning normal patch adoption into unnecessary policy
outage.

#### Option H — Use setup-node `lts/*`, `lts/jod`, or broad `22`/`24` aliases

Aliases install convenient current patches but move over time and do not
express engine floors. They are useful for periodic discovery evidence, not
the reproducible cells or local predicate.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric emphasizes the intersection
between package compatibility and reviewed runtime governance:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Exact engine compatibility | 26 | No admitted patch may fall below npm or final dependency requirements. |
| Release-policy truth | 20 | LTS/EOL/Current status and the post-26 schedule must be represented accurately. |
| Unreviewed-future exclusion | 16 | A compatible/current/future major is not automatically an authorized contributor/runtime line. |
| Boundary evidence quality | 14 | Below/at/current/next-major/malformed cases and real process cells must prove the predicate. |
| Contributor usability | 10 | Maintained compatible patches within reviewed lines should work without needless exact-patch lockout. |
| Cross-surface equality | 9 | Engines, workflow, hook, pure core, diagnostics, and npm resolver need one admitted set. |
| Maintenance/churn | 5 | Updating a finite table should be manageable, below correct support claims. |

### Scored comparison

| Option | Engines 26 | Release truth 20 | Future 16 | Boundaries 14 | Usability 10 | Equality 9 | Churn 5 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — finite per-major intervals | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.0** |
| B — npm engine verbatim | 5 | 2 | 1 | 4 | 4 | 4 | 5 | 68.6 |
| C — generic even-major rule | 2 | 1 | 1 | 2 | 5 | 4 | 5 | 45.4 |
| D — one unbounded minimum | 2 | 1 | 1 | 2 | 5 | 4 | 5 | 45.4 |
| E — Node 24 only | 5 | 5 | 5 | 4 | 2 | 5 | 4 | 90.2 |
| F — dynamic engine/release discovery | 5 | 2 | 1 | 3 | 4 | 2 | 4 | 61.2 |
| G — exact patch list | 3 | 4 | 5 | 5 | 1 | 5 | 1 | 73.6 |
| H — moving setup-node aliases | 3 | 4 | 3 | 2 | 5 | 2 | 5 | 65.4 |

Option A expresses the actual reviewed policy: compatibility floors within two
finite supported lines, not parity and not npm's open-ended engine branch.

### Selected resolution

Select **Option A — finite per-major interval table derived from npm and
release review**.

Implement it in T3 as follows:

1. At implementation time, recompute the engine intersection across npm
   `12.0.2`, every selected direct/transitive package, Husky, Markdown tooling,
   Corepack behavior, and actual hook shells. Stop if any requires a higher
   floor or drops a line.
2. Record the dated Node release evidence: Node 22 maintenance LTS/end
   2027-04-30; Node 24 active LTS/end 2028-04-30; Node 20 EOL; Node 26 Current;
   every major from Node 27 intended for LTS but not yet reviewed here.
3. Set exact `package.json`:
   `"engines": { "node": ">=22.22.2 <23 || >=24.15.0 <25" }`.
   Do not use `>=22`, `^22`, `>=22.22.2`, parity, `lts/*`, or an unbounded
   future clause.
4. In `Check-NodePolicy.mjs`, define one immutable table:

   ```text
   [{ major: 22, minimum: [22,22,2] },
    { major: 24, minimum: [24,15,0] }]
   ```

   Parse only canonical ASCII `major.minor.patch`: three decimal components,
   no sign/whitespace/leading zeros (except component `0`), no `v`, omitted
   component, prerelease/build metadata, Unicode digit, overflow, or trailing
   text. Compare bounded safe integers component-wise; do not use numeric float
   version coercion.
5. The exported pure predicate accepts a supplied string for fixtures. The
   production CLI accepts no version override and reads only
   `process.versions.node`, then also verifies `process.execPath`/actual process
   identity. The hook cannot claim a synthetic supported version.
6. Re-resolve the official distribution index at implementation. For the
   current snapshot, define exact setup/evidence versions:
   - Node 22 floor: `22.22.2`;
   - Node 22 reviewed-current: `22.23.2`;
   - Node 24 floor: `24.15.0`; and
   - Node 24 reviewed-current/preferred: `24.18.1`.

   Pin literal full versions in setup-node cells; no moving major/LTS alias.
7. Run actual install/manager/policy/hook evidence on Ubuntu and Windows/Git
   Bash at Node 22 floor and Node 24 preferred. Add actual Ubuntu floor evidence
   for Node 24. Use pure cases for Node 22 current and every remaining semantic
   boundary; T3-07 assigns one stable ID to each platform/version result.
8. At minimum test:
   - `22.22.1` reject, `22.22.2` pass, `22.23.2` pass, `22.999.999` pass;
   - `23.0.0` reject;
   - `24.14.999` and the latest actual pre-floor release reject,
     `24.15.0` pass, `24.18.1` pass, `24.999.999` pass;
   - `25.0.0`, `26.0.0`, `26.5.1`, and `27.0.0` reject;
   - Node 20 latest/EOL reject; and
   - every malformed representation listed in step 4 rejects.
9. Require exact equality of the admitted table/range across package.json,
   lock root metadata as applicable, Check-NodePolicy constants/summary, every
   workflow matrix value/condition, hook guidance, tooling harness expectations,
   and workflow-policy validator constants. Do not generate expectations from
   package.json at test time.
10. Diagnostics identify the observed canonical version, exact accepted
    intervals, stable reason, and remediation, without saying “even LTS.”
    A version in npm's engine but outside the finite table reports
    **compatible with npm but unreviewed by repository policy**.
11. Schedule/manual governance compares the current date with the tracked Node
    release-review record and fails visibly before an admitted line reaches its
    recorded EOL or when upstream changes the schedule. It does not
    auto-admit/drop a line.
12. Any line/floor/current-patch update requires a dated Node schedule and full
    dependency-engine review, issue decision, package range, manager descriptor
    check, workflow cells, hook, validator constants, stable fixtures, and
    evidence to change atomically.

**Status: selected and ready for incorporation into T3.**

The next finding to evaluate is T3-03.

## T3-03 — Complete the npm audit report-v2 schema and status contract

### Finding and decision constraints

T3 promises a fail-closed pure audit validator but currently specifies mostly
the exception schema. It does not fully define the npm report it trusts:
report-version/type/count reconciliation, vulnerability property shape,
advisory-object versus string `via`, three-form `fixAvailable`, node
uniqueness, reciprocal meta-vulnerability graph, or the joint meaning of JSON
and native process status. npm status `1` can be the expected
vulnerabilities-found result, while invalid registry/tool output can also be
nonzero; status alone cannot authorize or clear a report.

The resolution must freeze the selected npm 12.0.2 report-v2 contract, validate
raw input before normalization, reconcile independent count/graph domains,
classify process start/signal/timeout/`0`/`1`/other separately, allow an exact
approved exception only after valid residual normalization, and give every
malformed/near-miss fixture one stable reason/result.

Source and dated shape observations are retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Closed bounded report-v2 graph schema plus an explicit status table

Make the pure core accept raw report bytes, parsed/validated exception state,
injected fixture time, and a supplied native outcome record. It:

1. bounds bytes, rejects BOM/invalid UTF-8/duplicate JSON keys/malformed or
   trailing JSON;
2. requires exact report version `2` and closed top/metadata/property schemas;
3. validates every advisory object/string edge/fix form/node;
4. reconciles metadata severity totals with vulnerability properties and
   verifies reciprocal `via`/`effects` graph edges;
5. normalizes separate `Findings` and package-keyed `AuditNodePaths`; and
6. applies a complete decision table for status `0`, `1`, other, signal,
   timeout, and process-start failure before exception equality/expiry.

The wrapper executes only exact `corepack npm audit --package-lock-only --json`
without `--audit-level`, captures stdout/stderr/status separately in protected
bounded files, then supplies an immutable outcome. A valid residual plus status
`1` may be governed; every parser/schema/tool/status mismatch fails in a
distinct class.

Permutations:

- validate a parsed object or raw bytes. Accept raw bytes at the CLI so strict
  UTF-8, size, duplicate-key, and truncation policy remains enforceable; the
  exported semantic function may accept already parsed immutable fixtures only
  behind the same schema entry point;
- use JSON Schema/Ajv or hand-authored dependency-free checks. Use explicit
  code and a small duplicate-key-aware JSON tokenizer because the audit
  validator should not depend on the package graph it is deciding; all fields/
  bounds remain issue constants;
- treat unknown properties as failure or ignore for forward compatibility.
  Fail closed; an npm schema change requires review with the pinned npm update;
- accept npm status `1` for any nonempty JSON or only a valid nonempty report.
  Require the latter; error JSON is not a vulnerability report; and
- derive property severity from advisory edges or trust metadata. Recompute
  from validated properties/graph and require all representations agree.

#### Option B — Trust npm's exit code and parse only exception identities

Treat `0` as clean and `1` as residual, then extract package/advisory URLs when
present. Registry/proxy/parser failures can become empty/malformed reports,
metadata can disagree, and status `0` with disallowed findings is not detected
as a tool-contract violation.

#### Option C — Validate a JSON Schema only

Use a locked schema validator for types/properties. A schema can strongly cover
shape but cannot by itself prove severity totals, property-key/name equality,
duplicate node/advisory identities, reciprocal graph edges, exception equality,
expiry, or native status semantics; custom semantic code is still required.

#### Option D — Extract a tolerant subset and ignore unknown/missing detail

Read only package, severity, URL, and node strings, allowing other report
changes. This survives npm evolution but can silently discard a changed
`via`/fix/topology meaning or accept a partial report as complete.

#### Option E — Parse human-readable `npm audit`

The table/detail output is designed for operators and changes with terminal/
version/localization. It lacks a stable graph/count schema and is unsuitable as
the governed evidence source; retain it only as secondary human evidence.

#### Option F — Use `--audit-level` as the policy

Let npm return success below a severity threshold. The option changes exit
behavior but does not filter the report, does not govern exact advisory/
topology/expiry, and can turn known unapproved findings into CI success.

#### Option G — Export to a different service/SARIF and trust that result

Convert npm output or query another vulnerability service. This adds network,
conversion, advisory-identity, availability, and schema boundaries and no
longer validates the exact `npm audit` result the repository promises.

#### Option H — Compare the report/file hash with an approved baseline

Hash one accepted JSON document. Key/order/metadata/registry changes create
noise; an implementation-derived snapshot cannot explain additions/removals or
expiry and may preserve stale findings without semantic checks.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric centers on preventing a
tool/parser failure or malformed graph from becoming a false clean audit:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| False-clean resistance | 27 | No registry, process, parse, schema, count, or status failure may become “zero/approved.” |
| Report schema completeness | 20 | Every report-v2 object/array/scalar union and unknown field needs a closed bounded contract. |
| Graph/count/topology reconciliation | 16 | Severity totals, property names, via/effects targets, advisory identities, and node paths must agree. |
| Native outcome fidelity | 15 | `0`, `1`, other exit, signal, timeout, and launch failure have distinct meanings owned by orchestration/core. |
| Exception/governance correctness | 10 | Only a valid nonempty normalized residual may proceed to exact exception/expiry comparison. |
| Fixture diagnostics | 8 | One mutation should yield one stable class/reason without depending on property order. |
| Complexity/churn | 4 | Parser detail matters, below fail-closed correctness. |

### Scored comparison

| Option | False clean 27 | Schema 20 | Graph 16 | Status 15 | Governance 10 | Fixtures 8 | Churn 4 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — closed graph schema/status table | 5 | 5 | 5 | 5 | 5 | 5 | 3 | **98.4** |
| B — exit code + identities | 2 | 2 | 1 | 2 | 3 | 2 | 5 | 45.2 |
| C — JSON Schema only | 4 | 5 | 2 | 4 | 4 | 4 | 2 | 77.6 |
| D — tolerant subset | 2 | 2 | 2 | 3 | 3 | 3 | 5 | 49.8 |
| E — human output | 1 | 1 | 1 | 2 | 2 | 1 | 4 | 25.0 |
| F — audit severity threshold | 1 | 1 | 1 | 3 | 1 | 2 | 5 | 28.8 |
| G — external/SARIF source | 3 | 3 | 3 | 2 | 3 | 3 | 1 | 54.8 |
| H — report hash baseline | 2 | 1 | 1 | 2 | 2 | 1 | 5 | 35.2 |

Option A is the only design in which report syntax, semantic graph, process
result, and governance all have independent fail-closed proof.

### Selected resolution

Select **Option A — closed bounded report-v2 graph schema plus an explicit
status table**.

Implement it in T3 as follows:

1. Immediately after selecting/installing npm 12.0.2, retain its exact
   `@npmcli/arborist` audit-report/vulnerability source and real clean/residual
   outputs. Confirm the schema below; if the pinned package differs, revise the
   issue/tests before implementation rather than accepting a variant.
2. The production CLI reads the report as a `Buffer` with an exact 8 MiB
   maximum, rejects empty/oversize, UTF-8 BOM, invalid UTF-8 through
   `TextDecoder('utf-8', { fatal: true })`, NUL/control outside JSON whitespace,
   duplicate object keys at any depth through a tested lexical JSON reader,
   malformed/truncated/multiple/trailing-nonwhitespace JSON, arrays/objects
   above explicit 10,000-entry bounds, and strings above field-specific bounds.
3. Require one ordinary non-array JSON object with exactly:
   - `auditReportVersion`: safe integer exactly `2`;
   - `vulnerabilities`: ordinary object; and
   - `metadata`: ordinary object.
   Reject prototype-sensitive/dangerous property names and every unknown/
   missing key.
4. `metadata` has exact objects:
   - `vulnerabilities`: nonnegative safe integers `info`, `low`, `moderate`,
     `high`, `critical`, `total`; and
   - `dependencies`: nonnegative safe integers `prod`, `dev`, `optional`,
     `peer`, `peerOptional`, `total`.
   Do not sum dependency categories because npm categories can overlap; do
   require each count and total is bounded and internally possible under the
   pinned source contract.
5. Every `vulnerabilities[packageKey]` is an ordinary object with exact keys:
   `name`, `severity`, `isDirect`, `via`, `effects`, `range`, `nodes`,
   `fixAvailable`. Require:
   - `name` exact-equals `packageKey` and both use one bounded canonical npm
     package-name grammar;
   - severity exactly one of `info|low|moderate|high|critical`;
   - `isDirect` boolean;
   - `range` nonempty bounded control-free string;
   - `via` nonempty bounded array;
   - `effects` array of unique canonical package-name strings;
   - `nodes` nonempty sorted-then-normalized unique array of bounded relative
     forward-slash npm locations beginning with `node_modules/`, with no
     absolute/backslash/empty/dot/dot-dot/control segment; and
   - the exact `fixAvailable` union in step 7.
6. Each `via` element is exactly:
   - a canonical package-name string naming another vulnerability property; or
   - an ordinary advisory object with exact keys `source`, `name`,
     `dependency`, `title`, `url`, `severity`, `cwe`, `cvss`, `range`.

   Advisory requirements: positive safe-integer source; canonical name/
   dependency matching the owning property as the pinned source dictates;
   bounded nonempty control-free title/range; canonical absolute HTTPS URL with
   no credentials/fragment; closed severity; unique bounded `CWE-[1-9][0-9]*`
   array; and exact CVSS object `{score, vectorString}` with finite score
   `0..10` and the pinned nullable/nonempty vector-string form. Reject unknown,
   duplicate, or missing advisory properties.
7. `fixAvailable` is only:
   - boolean `false`;
   - boolean `true`; or
   - exact object `{name, version, isSemVerMajor}` with canonical package name,
     canonical full SemVer string, and boolean.
   Reject null, strings, arrays, partial/extra objects, ranges/tags, and
   noncanonical versions.
8. Reject duplicate advisory `(owning package, canonical URL)` and source IDs,
   duplicate string vias/effects/nodes, or a node repeated within the same
   package. Normalize:
   - `Findings`: one sorted row per advisory object keyed only by exact
     `(Package, AdvisoryUrl)` plus source/severity/range/fix metadata; and
   - `AuditNodePaths`: one sorted package row with its complete sorted unique
     node paths.
   Do not form advisory-to-node pairs.
9. Validate the graph:
   - every string `A.via = B` names a property `B`, and `B.effects` contains
     `A`;
   - every `B.effects = A` has the reciprocal string edge in `A.via`;
   - no self/duplicate/dangling edge;
   - each property's severity equals the maximum required by its validated
     advisory/string-via causes under the pinned npm algorithm; and
   - `metadata.vulnerabilities` counts vulnerability **properties** by their
     final property severity, `total` equals property count, and severity sum
     equals total.
10. Define an immutable native outcome:
    `{kind:'exit', code:safe integer}` or
    `{kind:'signal', signal:closed name}` or `{kind:'timeout'}` or
    `{kind:'startFailure', reason:closed value}`. The pure core's decision table
    is:
    - exit `0` + valid empty report + absent exception → pass;
    - exit `0` + nonempty report → status mismatch;
    - exit `1` + valid nonempty report → continue to exact exception policy;
    - exit `1` + empty/malformed/unsupported report → status/input failure;
    - any other exit, signal, timeout, or start failure → process/tool failure,
      never governed; and
    - any valid clean report plus exception file → stale-governance failure.
11. Assign exact validator exit classes:
    `0 PASS`, `20 PROCESS_TOOL`, `21 AUDIT_INPUT_JSON`,
    `22 AUDIT_REPORT_SCHEMA`, `23 AUDIT_STATUS_MISMATCH`,
    `24 AUDIT_POLICY_MISMATCH`, and `25 AUDIT_GOVERNANCE`.
    Stable subreason IDs distinguish fields/edges; never accept merely “any
    nonzero.”
12. The orchestration wrapper invokes only
    `corepack npm audit --package-lock-only --json` with no `--audit-level`,
    omit/workspace/registry override, shell command string, or stderr merge.
    It writes stdout/stderr to separate fresh protected bounded files, captures
    start/signal/timeout/native status immediately, closes streams, hashes the
    immutable report, then calls the CLI with exact paths/outcome values.
13. Registry, TLS, DNS, proxy HTML, auth, npm crash, invalid error JSON,
    truncated/oversize output, write failure, and stderr-only failure all map
    to `PROCESS_TOOL` or `AUDIT_INPUT_JSON` as specified, not an empty report.
    The wrapper never fabricates `{vulnerabilities:{}}`.
14. Add one stable append-only fixture ID and exact oracle for every schema
    field/union/bound, each metadata mismatch, property-key/name mismatch,
    advisory/string-via form, all three fix forms plus near misses, duplicate/
    missing node, reciprocal edge direction, dangling/self edge, duplicate JSON
    key, invalid UTF-8/BOM/truncation/non-JSON, and each decision-table row.
    Do not group multiple alternative expected results under one ID.
15. Include explicit integration rows for native `0` with injected disallowed
    findings, native `1` with exactly approved residual, native `1` clean/error
    JSON, exits `2` and `>2`, signal, timeout, and process-start failure. Assert
    report/exception inputs are byte-unchanged and diagnostics contain no raw
    audit body, registry credential, or arbitrary node paths.
16. Report/npm schema change is an intentional policy update requiring exact
    npm descriptor/integrity, source snapshot, schema constants, normalizer,
    exception comparison, wrapper, all fixtures, and dated evidence to change
    atomically.

**Status: selected and ready for incorporation into T3.**

The next finding to evaluate is T3-04.

## T3-04 — Correct the dated baseline terminology

### Finding and decision constraints

T3's dated baseline says npm reported “seven affected package nodes: five high
and two moderate.” The seven/five/two values in
`metadata.vulnerabilities` count vulnerability **properties** by each
property's final severity. The report also contains advisory objects inside
`via`, package-name string `via` edges, and installed node-location strings.
Those domains happen to share or relate to package names, but they are not one
count and npm does not supply an advisory-to-node Cartesian mapping.

The current pre-T3 observation has seven vulnerability properties, fourteen
advisory objects, two string `via` edges, and seven installed node paths. These
are dated facts from the old tree, not desired final values. The resolution
must label them independently, retain identity sets as evidence, avoid invented
relationships, and keep final acceptance based on current normalized policy,
not baseline numbers.

### Resolution options

#### Option A — Typed dated observation with four independent count domains

Replace the sentence with a structured dated record containing:

- vulnerability-property count and per-property severity metadata;
- advisory-object count/unique `(Package, AdvisoryUrl)` finding set;
- package-name string `via` edge count/edge set; and
- installed node-path count plus package-keyed path sets.

Record tool/runtime/command/status/time/report hash beside the counts. State
explicitly which relations npm provides: properties own `via` arrays and node
arrays; string `via`/`effects` are reciprocal package graph edges; the report
does not attach each advisory object to each installed node path. Treat all
values as pre-change diagnostic evidence. Implementation-time/final reports
recompute the same schema; acceptance uses exact current sets/exception policy.

Permutations:

- retain only counts or counts plus exact sets. Require both: counts make review
  readable; exact identities/topology make it reproducible;
- record node paths globally or by package. Keep package-keyed sorted arrays,
  as T3 already selected, then derive a global count without cross joining;
- call seven “vulnerable packages” or “vulnerability properties.” Use the exact
  report structural term and separately state the seven distinct property
  package keys; and
- update the old snapshot with today's registry or preserve its date. Preserve
  the original dated run with corrected labels, then add a separately dated
  implementation run.

#### Option B — Keep one generic “affected package” count

Say “seven affected packages” and omit nodes/advisories. This is less false
than “package nodes” if property keys are unique packages, but it still hides
four distinct report structures and cannot reconcile exception findings or
topology.

#### Option C — Report only `metadata.vulnerabilities.total`/severity

Use npm's displayed five-high/two-moderate aggregate and no other counts. This
is an exact metadata claim but provides no advisory identity, meta-edge, or
installed topology evidence and can pass if metadata is internally wrong.

#### Option D — Count advisory objects only

Call fourteen advisory objects the vulnerability count. This improves
advisory-level triage but meta-vulnerability property/string edges and installed
nodes remain separate; property severity metadata no longer reconciles with the
headline.

#### Option E — Count installed node paths only

Call seven node locations the affected count. Duplicate installations can make
this useful for remediation effort, but it says nothing about how many advisory
identities or vulnerability properties exist and still encourages unsupported
advisory/path pairing.

#### Option F — Count distinct package names across all structures

Deduplicate property/advisory/edge/node package names into one number. It hides
multiple advisories and duplicate installation paths and is not a native field
with one stable meaning.

#### Option G — Remove all counts and retain identities only

Exact sets avoid headline ambiguity and are sufficient mechanically, but
reviewers lose useful high-level severity/topology scale and cannot quickly
cross-check metadata/count reconciliation.

#### Option H — Turn corrected baseline counts into acceptance constants

Require the final audit to contain the same four numbers. That would preserve
known vulnerabilities/topology, reject successful remediation, and become
stale as the registry changes. A baseline describes risk; it never authorizes
or specifies the final report.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric focuses on measurement
semantics rather than the audit parser mechanics already decided in T3-03:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Count-domain accuracy | 28 | Property, advisory, graph-edge, and installed-path counts must never share a misleading label. |
| Reproducible evidence | 18 | Runtime/tool/command/status/hash and exact sets must let reviewers reproduce each number. |
| Remediation usefulness | 15 | Maintainers need both advisory identities and installed topology without conflation. |
| No invented advisory/path mapping | 15 | The record must preserve only relationships npm actually reports. |
| Registry/tree drift resilience | 10 | Dated observations must change without becoming acceptance or stale authorization. |
| Human clarity | 9 | A reviewer should understand the risk scale and why same-valued counts differ. |
| Administrative effort | 5 | Generating the summary should be automatic, below semantic truth. |

### Scored comparison

| Option | Accuracy 28 | Reproduce 18 | Triage 15 | No false map 15 | Drift 10 | Clarity 9 | Effort 5 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — typed four-domain observation | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **99.0** |
| B — one affected-package count | 2 | 2 | 2 | 3 | 3 | 3 | 5 | 50.2 |
| C — metadata totals only | 3 | 3 | 2 | 4 | 3 | 3 | 5 | 60.0 |
| D — advisory count only | 3 | 3 | 4 | 3 | 3 | 3 | 5 | 60.0 |
| E — node-path count only | 3 | 3 | 3 | 2 | 3 | 3 | 5 | 54.0 |
| F — deduplicated package count | 2 | 2 | 2 | 3 | 3 | 2 | 4 | 44.4 |
| G — identities without counts | 5 | 5 | 5 | 5 | 5 | 2 | 3 | 91.6 |
| H — baseline as acceptance | 3 | 3 | 1 | 3 | 1 | 3 | 5 | 48.0 |

Option A preserves readable scale and exact machine evidence without asserting
relationships the report does not contain.

### Selected resolution

Select **Option A — typed dated observation with four independent count
domains**.

Implement it in T3 as follows:

1. Replace the current opening baseline sentence with:
   “On 2026-07-29, `npm audit --package-lock-only --json` under Node
   26.5.1/npm 11.7.0 returned status 1/report-v2 with seven vulnerability
   properties (five high, two moderate), fourteen advisory-object `via`
   entries, two package-name string `via` edges, and seven installed node-path
   entries. These are separate count domains.”
2. Name the seven vulnerability property keys exactly:
   `brace-expansion`, `js-yaml`, `linkify-it`, `markdown-it`,
   `markdownlint-cli2`, `minimatch`, and `picomatch`. Do not call that list
   seven advisories or seven nodes.
3. Retain the exact fourteen normalized `(Package, AdvisoryUrl)` rows and their
   source/severity/range evidence, the exact two directed string-via edges with
   reciprocal effects, and the package-keyed sorted arrays containing the seven
   node paths in issue/PR evidence. Counts alone are not the artifact.
4. For every baseline/final observation emit a closed summary:
   `schemaVersion`, `observedAt`, exact Node/npm versions/paths, exact audit
   argv, native outcome, report version/byte length/SHA-256,
   `vulnerabilityPropertyCount`, `propertySeverityCounts`,
   `advisoryObjectCount`, `stringViaEdgeCount`, `installedNodePathCount`, plus
   hashes/links for the four exact normalized sets.
5. Derive counts only after T3-03 strict validation. Require:
   property count = metadata total = severity sum; advisory-object count =
   number of normalized advisory entries before `(Package, URL)` uniqueness;
   edge count = exact string via entries; node count = sum of lengths of
   package-keyed node arrays. Fail on duplicate entries rather than decrementing
   through deduplication.
6. Explicitly state the relationships:
   - a vulnerability property contains advisory/string vias and node paths;
   - a string via has one reciprocal effects edge;
   - `metadata.vulnerabilities` counts properties by property severity; and
   - npm does **not** provide one edge from every advisory object to every node
     path.
7. Do not create advisory/path pairs, multiply fourteen by seven, infer an
   advisory applies to only/each listed installation, or derive advisory count
   from metadata total.
8. Run and label three independent observations where applicable:
   pre-change dated baseline, post-selection implementation report, and final
   clean-install report. Never overwrite one label/time with another.
9. The final preferred zero report is expressed in the same schema (all four
   vulnerability-derived counts zero and no exception file). If residuals are
   approved, current exact Findings/edge/topology sets—not any old count—must
   equal the valid exception/governance contract.
10. Remove every use of “affected package nodes” and audit the issue for bare
    “finding count,” “package count,” or “vulnerability count”; qualify each as
    property, advisory object/normalized finding, string edge, or installed
    node path.
11. Add fixtures where domains differ deliberately (one property with two
    advisories/three nodes, two properties joined by one string edge, duplicate
    advisory, duplicate node) and require the exact four counts/sets or the
    intended duplicate failure. This prevents future code from relying on the
    baseline's coincidental seven-property/seven-node equality.
12. Acceptance states only that the dated record is correctly typed and the
    current report satisfies T3-03/exception policy; it must not require the
    numbers `7`, `14`, `2`, `7`, `5`, or `2`.

**Status: selected and ready for incorporation into T3.**

The next finding to evaluate is T3-05.

## T3-05 — Stop swallowing hook-installation failure

### Finding and decision constraints

The current `prepare` script is `cd ../.. && husky || true`. It reports install
success even when Husky is missing, the repository root is wrong, Git config
cannot be written, or the generated hook path is absent. T3 nevertheless
promises that clean install establishes the repository's real hook and that a
real `git commit` invokes it. Husky also has legitimate explicit skip use cases
(`HUSKY=0` in CI/production), so simply treating every non-install as the same
failure would make the contract inaccurate.

The resolution must give “installation required” and “installation
intentionally skipped” disjoint observable states, never let a required failure
return zero, independently verify the installed Git/Husky postcondition, and
execute the installed hook through Git in disposable repositories without
mutating the implementer's source repository/config/index.

Primary behavior is retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Tracked fail-closed installer with a closed state machine

Add a small tracked `Install-Husky.mjs` invoked by `prepare`. Default/explicit
`required` mode resolves the repository root independently, runs the pinned
Husky API/CLI, and verifies:

- local `core.hooksPath` exactly `.husky/_`;
- expected generated Husky launcher/shim files are ordinary non-links with
  pinned content/mode appropriate to the OS/Git environment;
- the tracked `.husky/pre-commit` is the expected ordinary file; and
- a disposable repository can make Git invoke that installed path.

There is one explicit `skip` mode only for the documented read-only install
surface: it requires `HUSKY=0`, a closed reason, emits a stable skipped record,
and proves no config/shim mutation. Every missing/contradictory value fails.
Remove `|| true`. The integration harness tests installer state and then a real
`git commit` pass/reject.

Permutations:

- keep the install logic in a shell string or a tracked Node module. Use the
  module for cross-platform exact argv/path/postcondition checks and stable
  reasons;
- default to required or demand a mode every time. Default to required for
  contributor safety; CI skip must be explicit;
- allow generic `CI=true`/`NODE_ENV=production` to skip or require a closed
  combination. Require a closed mode/reason plus `HUSKY=0`; ambient `CI` alone
  is not authorization;
- test only the tracked hook directly or invoke Git. Use direct invocation for
  focused cases and at least one real installed `git commit` for each required
  OS/runtime surface; and
- reuse the source repository or clone a sandbox. Only owned disposable
  repositories may have local Git config/index/commits mutated.

#### Option B — Change prepare to plain `cd ../.. && husky`

Removing `|| true` makes command failure visible and follows basic Husky
guidance. It does not prove `core.hooksPath`/shim/tracked hook postconditions,
does not give an explicit skip oracle, and tests can still call the hook
directly without proving Git's installed route.

#### Option C — Keep `husky || true` and add a later warning/check

A later job might detect the missing hook, but `npm ci` itself remains a false
success and local contributors may never run the later check. Failure cause/
status is also lost.

#### Option D — Always set `HUSKY=0` in CI and directly run `.husky/pre-commit`

This keeps installs read-only and tests hook logic, but never proves installation
or Git routing on the surfaces where T3 claims it. A tracked hook can pass while
`core.hooksPath` is absent/wrong.

#### Option E — Manually set `core.hooksPath` and bypass Husky install

Configure Git directly to `.husky` or a wrapper. This can be deterministic but
no longer tests the selected Husky integration or its generated launchers and
may diverge from contributor installation behavior.

#### Option F — Track `.git/hooks/pre-commit` or local Git config

Git's `.git` state is clone-local and cannot be committed as repository policy.
Copying files there during tests can work, but replaces rather than validates
Husky and has different worktree/submodule semantics.

#### Option G — Move installation to `postinstall`

Changing lifecycle hooks may reduce some `prepare` invocations, but it does not
solve fail-open handling, skips, postcondition verification, or actual Git
execution. It also diverges from current Husky recommendation without need.

#### Option H — Replace Husky with another hook manager

A different manager may have stronger installation APIs, but dependency/
hook/workflow behavior and contributor guidance would all change. T3's goal is
to govern the existing real hook, not redesign the hook platform.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric emphasizes observable hook
installation rather than merely hook-script logic:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Required-install truth | 26 | A full tooling install may succeed only when Git/Husky postconditions actually exist. |
| Real Git invocation proof | 20 | The installed route must cause a real commit to execute the tracked hook and affect commit state. |
| Explicit skip safety | 16 | Intentional non-install must have one narrow condition/reason and never mask a required failure. |
| Failure classification | 14 | Missing package/Git root/config write/shim/hook/execution failures need stable distinct outcomes. |
| Source-repository isolation | 10 | Tests cannot mutate the developer's real Git config, index, hooks, commits, or worktree. |
| Cross-platform behavior | 8 | Ubuntu and Windows/Git Bash need actual installation/execution evidence. |
| Churn/complexity | 6 | Another small helper costs maintenance, below installation truth. |

### Scored comparison

| Option | Install 26 | Git invocation 20 | Skip 16 | Failures 14 | Isolation 10 | Platforms 8 | Churn 6 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — tracked installer state machine | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **98.8** |
| B — plain failing prepare | 4 | 3 | 2 | 3 | 4 | 4 | 5 | 68.0 |
| C — swallow then later check | 1 | 2 | 1 | 1 | 4 | 3 | 5 | 37.6 |
| D — always skip/direct hook | 1 | 2 | 4 | 3 | 5 | 4 | 4 | 53.6 |
| E — manual hooksPath | 3 | 4 | 3 | 4 | 4 | 4 | 3 | 67.6 |
| F — mutate `.git/hooks` | 2 | 4 | 2 | 3 | 1 | 3 | 3 | 48.8 |
| G — postinstall only | 3 | 2 | 2 | 2 | 4 | 3 | 4 | 53.2 |
| H — replace manager | 3 | 4 | 3 | 4 | 4 | 3 | 1 | 64.4 |

Option A turns install/skip into verified states and makes the real Git
integration—not a direct shell call—the final oracle.

### Selected resolution

Select **Option A — tracked fail-closed installer with a closed state machine**.

Implement it in T3 as follows:

1. Add `.github/workflows/Install-Husky.mjs` to T3's required affected files
   and change `prepare` to invoke it through the actual selected Node:
   `"prepare": "node Install-Husky.mjs"`. Remove every `|| true`, unconditional
   zero exit, and fallback install command.
2. The installer accepts no CLI path/mode override. It derives the package
   directory from `import.meta.url`, derives the expected repository root by
   two literal parent steps, resolves actual Git top-level with an exact
   non-shell `git` child, and requires exact canonical equality. Reject missing/
   malformed/non-worktree/wrong-root state before invoking Husky.
3. Snapshot exact environment once. Modes are:
   - unset or exact `HUSKY_INSTALL_MODE=required`: installation required and
     `HUSKY` must not be `0`;
   - exact `HUSKY_INSTALL_MODE=skip` only when `HUSKY=0`,
     `CI=true`, and
     `HUSKY_INSTALL_SKIP_REASON=read-only-ci-install`.
   Reject all other values/case/whitespace, `HUSKY=0` in required mode, or skip
   without every companion field.
4. Required mode verifies pinned Husky package version/integrity from the clean
   install, changes cwd only to the independently validated repository root,
   invokes the selected Husky v9 API/CLI without a shell/eval, captures native
   result immediately, and treats any message/status denoting failure as an
   exact nonzero installer failure.
5. After invocation, independently query local-only Git config with exact argv
   and require one value `.husky/_`. Reject global/system-only value, multiple/
   newline/control output, wrong case/separators, absolute/out-of-repository
   path, or command failure.
6. From pinned Husky source, enumerate the exact generated launcher/shim paths,
   contents, and executable-bit expectations for the supported Git
   environments. Require each expected item ordinary/non-reparse and exact;
   reject missing, extra active hook launcher, modified, linked, non-executable
   POSIX, or wrong target. Separately require tracked `.husky/pre-commit` is the
   exact expected ordinary non-reparse file.
7. Required success emits one bounded record with mode, stable `installed`
   state, Husky version, repository-relative hooksPath, and hashes of the
   generated launcher/tracked hook—no full environment or user path.
8. Skip mode snapshots local `core.hooksPath` and relevant `.husky/_` state
   before/after, invokes no Husky install, and requires byte/value equality.
   It emits stable `skipped/read-only-ci-install`. Skip is not evidence that a
   hook was installed and cannot satisfy installation acceptance.
9. Ordinary main-repository CI installs may use the explicit read-only skip to
   avoid mutating the checkout's local config. The integration harness must
   perform an independent required install inside every disposable test
   repository; at least one required install per Node/OS cell is mandatory.
10. The harness creates a disposable Git repository with isolated
    `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM`, copies exact tracked package/lock/
    hook content, performs selected npm clean install in required mode, and
    validates the install record/config/shims. Never point installer/test
    operations at the source repository.
11. It then stages test-owned Markdown and invokes ordinary `git commit` without
    `--no-verify` or direct hook execution. A valid case creates exactly one
    commit and proves the installed hook marker/lint ran; invalid outer/nested/
    runtime/tooling cases reject and leave HEAD/index per their exact oracle.
12. Add stable one-result IDs for required success; Husky command failure;
    missing/wrong Git root; config read/write failure; wrong/multiple
    hooksPath; missing/modified/linked/non-executable shim; missing/changed
    tracked hook; `HUSKY=0` required; exact skip; every partial/wrong skip
    combination; skip mutation; and actual Git pass/reject on Ubuntu and
    Windows/Git Bash.
13. The workflow-policy validator requires exact prepare script, installer
    step/mode placement, read-only CI skip conditions, mandatory disposable
    required-install cells, and absence of `|| true`, `--ignore-scripts` on
    required evidence, direct `.husky/pre-commit` as the only integration
    oracle, or global/manual hook setup.
14. Acceptance distinguishes:
    - clean required install completed and verified;
    - documented read-only install explicitly skipped and unchanged; and
    - real Git commit invoked the installed hook.
    No one state substitutes for another.

**Status: selected and ready for incorporation into T3.**

The next finding to evaluate is T3-06.

## T3-06 — Separate URL grammar from external issue existence

### Finding and decision constraints

T3 requires every residual-audit exception to name a “real filed follow-up
GitHub issue,” while `Validate-NpmAudit.mjs` is explicitly pure/offline. An
offline parser can prove that a string is one canonical issue URL in the
intended repository and agrees with structured fields. It cannot prove GitHub
currently has that issue, that the endpoint is an issue rather than a pull
request, that it remains open, or that its body/ownership actually covers the
normalized findings.

The resolution must keep the pure core deterministic and unprivileged, define
an exact URL/repository/number grammar, retain a separate authorized existence/
scope observation with bounded freshness, make every claim accurately labeled,
and fail approval/renewal when external evidence is missing or mismatched.

GitHub URL/API/permission facts are retained in
`docs/planning/artifacts/prompt-02-resolution-research.md`.

### Resolution options

#### Option A — Offline canonical grammar plus approval-time filing evidence

The pure core validates a structured follow-up reference whose URL is exactly:

```text
https://github.com/franklesniak/TerraformStyleGuide/issues/<canonical-positive-decimal>
```

It checks URL/repository/number/scope-hash/time fields and exception equality,
then reports only **syntactically valid follow-up reference**. At initial
approval and every renewal, an explicitly authorized maintainer/API read
records the actual issue's immutable ID/node ID, canonical URL/number/repo,
open state, absence of `pull_request`, owner, and a canonical scope marker hash
covering the exact normalized `(Package, AdvisoryUrl)` set. The exception
references that reviewed evidence and its verification time; it remains bounded
by the same maximum 30-day approval.

Ordinary audit validation stays offline. It verifies the evidence reference and
freshness fields but says it cannot re-prove remote state. Filing/renewal cannot
merge without the external record; issue closure/scope change requires the
exception owner to re-evaluate immediately.

Permutations:

- store the network response in the repository, PR evidence, or issue comment.
  Retain a bounded canonical record/hash in reviewed PR/issue evidence rather
  than committing mutable GitHub JSON to the package directory;
- automate the lookup in CI with `issues: read` or perform a maintainer read.
  Prefer approval/renewal evidence so ordinary validation remains deterministic
  and no new token permission/network dependency is introduced;
- use one follow-up for all residuals or one per finding. Permit either if the
  scope marker maps each current finding exactly and no finding has an empty/
  stale reference;
- require open state always or allow closed-with-resolution. A residual cannot
  rely on a closed follow-up; closure triggers remediation/new filing/
  reapproval; and
- check title/body text loosely or use a canonical scope marker. Require a
  stable `npm-audit-findings-sha256` marker computed from canonical current
  finding identities, plus human review of owner/remediation plan.

#### Option B — Offline grammar and call it proof of a real issue

Keep the pure validator only, but let its pass diagnostic/acceptance say “real
filed issue.” This is deterministic yet factually false for nonexistent,
deleted/transferred, PR-number, closed, or unrelated URLs.

#### Option C — Put GitHub lookup inside the pure core

Have `Validate-NpmAudit.mjs` fetch GitHub directly whenever it validates.
Existence can be current, but the core is no longer pure/offline; DNS/rate/
auth/outage behavior contaminates deterministic audit classification and needs
token permission on every surface.

#### Option D — Accept any HTTPS URL

Check URL syntax/scheme and let reviewers decide. This permits other hosts/
repositories, pull requests, query/fragment/userinfo variants, noncanonical
numbers, and links that cannot be mechanically tied to the governed project.

#### Option E — Store only repository and issue number

Use `{owner, repo, number}` and derive the URL. This is structurally cleaner but
still cannot prove existence/state/scope. It is a viable representation within
Option A, not a replacement for external evidence.

#### Option F — Lookup issue state on every validation run

Add an `issues: read` network job for PR/push/schedule/manual/local equivalents
and fail closed on lookup failure. This provides fresher evidence but makes
ordinary CI dependent on GitHub API availability/rate/auth, complicates forks/
local runs, and expands the token allowlist for a governance value already
limited to 30 days.

#### Option G — Allow an external ticket system

Support Jira/other issue URLs and provider adapters. This may fit organizational
governance but expands grammar/auth/schema and is outside the repository's
explicit GitHub follow-up requirement. It can be reconsidered deliberately.

#### Option H — Remove the follow-up requirement

Keep owner/expiry/analysis only. This avoids a false existence claim but loses
the durable remediation work item needed for an accepted known vulnerability.

### Finding-specific evaluation rubric

Scores use 1–5 and `weight × score ÷ 5`. This rubric focuses on the boundary
between deterministic validation and mutable external governance:

| Criterion | Weight | Why it matters for this finding |
| --- | ---: | --- |
| Claim truthfulness | 25 | Offline syntax, historical evidence, and current remote state must never be presented as the same proof. |
| Existence/scope governance | 22 | A residual needs an actual open issue whose reviewed scope covers every exact finding. |
| Pure-core determinism | 15 | Local/fixture audit classification should not depend on network/token/rate state. |
| Least-privilege operation | 12 | Ordinary jobs/hooks should not gain issue permissions or secrets solely to parse exceptions. |
| Freshness/renewal behavior | 10 | A historical issue lookup cannot authorize residual risk indefinitely. |
| Exact schema/fixtures | 10 | Host/repo/path/number/evidence/scope mutations need stable offline and external oracles. |
| Effort/churn | 6 | Evidence capture should be practical, below truthful governance. |

### Scored comparison

| Option | Truth 25 | Governance 22 | Pure 15 | Privilege 12 | Freshness 10 | Schema 10 | Churn 6 | Total / 100 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — grammar + filing evidence | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **98.8** |
| B — offline called real | 1 | 1 | 5 | 5 | 1 | 4 | 5 | 52.4 |
| C — network in pure core | 5 | 5 | 1 | 2 | 5 | 3 | 1 | 72.0 |
| D — any HTTPS URL | 1 | 1 | 5 | 5 | 1 | 1 | 5 | 46.4 |
| E — issue number only | 3 | 2 | 5 | 5 | 2 | 3 | 5 | 66.8 |
| F — lookup every run | 5 | 5 | 2 | 3 | 5 | 4 | 1 | 79.4 |
| G — external ticket adapters | 4 | 4 | 4 | 4 | 4 | 3 | 3 | 76.8 |
| H — no follow-up | 3 | 1 | 5 | 5 | 1 | 5 | 5 | 64.4 |

Option A preserves pure, offline enforcement while making existence/scope a
real reviewed gate with the same bounded lifetime as the risk exception.

### Selected resolution

Select **Option A — offline canonical grammar plus approval-time filing
evidence**.

Implement it in T3 as follows:

1. Replace the bare exception `follow-up GitHub issue URL` with exact fields per
   finding (shared values allowed):
   `followUpIssueUrl`, `followUpIssueNumber`,
   `followUpScopeSha256`, `followUpVerifiedAt`, and
   `followUpEvidenceSha256`. Require exact closed property sets/types.
2. Parse the URL with the platform URL parser, then require exact serialized
   equality to
   `https://github.com/franklesniak/TerraformStyleGuide/issues/<number>`:
   HTTPS, lowercase canonical host, no credentials/port/query/fragment/trailing
   slash/percent encoding/dot segment, exact owner/repo case and `issues`
   segment.
3. `followUpIssueNumber` is a JSON safe integer and its canonical decimal text
   matches `[1-9][0-9]*` and the URL segment exactly—no sign, leading zero,
   exponent, fraction, whitespace, Unicode digit, overflow, `/pull/`, comment/
   anchor, or other repository.
4. Compute `followUpScopeSha256` from a versioned canonical JSON array of the
   exact sorted current `(Package, AdvisoryUrl)` identities assigned to that
   issue. Require every current finding is covered exactly once or by one
   explicitly shared issue scope; reject missing/extra/stale identities.
5. The follow-up issue body must contain a reviewed marker
   `npm-audit-findings-sha256: <same lowercase 64-hex>` plus owner, remediation
   objective, and target date. Human approval assesses that prose; the hash
   binds its declared scope.
6. At exception creation and every renewal, after the issue is filed, an
   authorized maintainer performs one exact GitHub API/UI read and records:
   API endpoint/time/actor, repository, canonical HTML URL, issue number,
   immutable database ID and node ID, `state=open`, absence of a
   `pull_request` field, creation/update times, owner/assignee, title/body hash,
   observed scope marker, and current finding-scope hash.
7. Canonicalize that bounded evidence record and store its SHA-256 as
   `followUpEvidenceSha256`; `followUpVerifiedAt` equals the evidence time and
   lies at/before approval within the same review session. Retain the record in
   reviewed T3 issue/PR evidence; do not store token, headers, arbitrary API
   response, user email, or signed URL.
8. The pure validator checks only grammar, repository/number equality, hashes,
   finding coverage, canonical timestamps, evidence reference presence, and
   that verification is no older than the current approval/maximum 30-day
   window. Its summary says **offline reference/evidence fields valid**, never
   **issue exists/open**.
9. Initial approval/renewal is blocked unless a reviewer independently checks
   the retained record against the live issue. If the issue is closed,
   transferred, converted, deleted, loses owner/scope, or no longer represents
   the residual, remediate the finding or file/reapprove a correct issue; do
   not edit only the URL/hash/timestamp.
10. Ordinary PR/push/local/scheduled pure validation performs no GitHub issue
    lookup and needs no `issues` permission. If the owner later chooses
    continuous live checks, that is a separately reviewed read-only job/role/
    token/default/failure policy, not a silent change to the pure core.
11. Add offline fixtures for wrong scheme/host/case/port/repo/path, `/pull/`,
    number forms, query/fragment/trailing slash/encoding, URL-number mismatch,
    malformed/missing/stale evidence hash/time, scope missing/extra/duplicate,
    and shared-issue exact coverage.
12. Add retained external-evidence fixture records for nonexistent issue,
    pull-request response, closed issue, wrong repository/number/node ID,
    missing owner, changed scope marker/body hash, and valid open issue. These
    test the approval checklist/record parser without claiming the pure audit
    core performed the lookup.
13. Rewrite acceptance to require two distinct facts:
    - the offline validator accepts the canonical follow-up reference/evidence
      schema; and
    - reviewed filing evidence proves the issue existed/open/correctly scoped
      at initial approval or latest renewal.

**Status: selected and ready for incorporation into T3.**

## T3-07 — Give Node and hook cases one stable ID each

### Resolution options

The defect is not merely that `HOOK-07` contains several assertions. It is that
one inventory key can produce different results depending on a hidden version
and platform parameter, so a retained `HOOK-07: pass` result does not identify
what actually ran.

1. **Option A — atomic manifest rows for pure inputs and real platform cells.**
   Replace the family row with a closed, version-controlled manifest in which
   every pure version string and every real hook `(platform, exact Node
   version)` cell has its own immutable ID, literal input, literal expected
   result/reason, and exactly one recorded result. Generate CI matrices from
   that manifest, reject duplicate/missing/unexpected result IDs, and prohibit
   range/family/wildcard rows.
2. **Option B — one version ID with platforms grouped.** Give every boundary
   version one ID but allow Ubuntu and Windows results to share it.
3. **Option C — dynamic parameterized IDs.** Keep a matrix family and construct
   display labels from the current matrix values at runtime.
4. **Option D — one platform ID with versions grouped.** Split Ubuntu and
   Windows while retaining a list of version cases under each row.
5. **Option E — retain `HOOK-07` with named subtests.** Make console output more
   descriptive but keep one retained inventory result.
6. **Option F — encode the version/platform only in the ID.** Create atomic
   rows, but derive the input and oracle by parsing the identifier instead of
   recording them independently.
7. **Option G — property/randomized version testing.** Replace the finite
   inventory with generated semantic-version samples and property assertions.
8. **Option H — test only real supported jobs.** Remove synthetic and rejected
   boundary cases and assign one ID to each already-required CI runtime.

Option A can use descriptive suffixes without making those suffixes executable
semantics. Pure policy cases are platform-independent; real hook evidence is
not, so it receives a separate ID for each actual platform/runtime cell.

### Weighted decision rubric

This rubric is specific to inventory identity and result traceability. Scores
are 1 (poor) through 5 (excellent); the weighted total is out of 100.

| Criterion | Weight | What a 5 requires |
| --- | ---: | --- |
| One-ID/one-oracle atomicity | 24 | No ID can legitimately produce two outcomes |
| Boundary-case completeness | 20 | Every accepted edge, rejected neighbor, and malformed class is explicit |
| Platform/runtime traceability | 16 | A real-hook result identifies the exact OS and actual Node runtime |
| Append-only identity stability | 14 | IDs and meanings never depend on matrix order, “latest,” or runtime derivation |
| Inventory/result enforcement | 11 | Automation rejects duplicate, missing, unexpected, or multiply emitted IDs |
| Failure diagnosability | 9 | Retained evidence directly names input, expected result, actual result, and phase |
| Maintenance and CI cost | 6 | The inventory is economical to update and run |

Correctness, boundary completeness, and evidence usability carry 94% of the
weight; maintenance cost is deliberately subordinate.

### Scored options

| Option | Atomicity 24 | Completeness 20 | Traceability 16 | Stability 14 | Enforcement 11 | Diagnosis 9 | Cost 6 | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — atomic manifest rows | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **98.8** |
| B — version IDs, platforms grouped | 4 | 5 | 2 | 5 | 4 | 3 | 4 | 78.6 |
| C — dynamic parameterized IDs | 2 | 5 | 3 | 2 | 2 | 2 | 5 | 58.8 |
| D — platform IDs, versions grouped | 2 | 2 | 4 | 4 | 2 | 3 | 5 | 57.4 |
| E — one ID with subtests | 1 | 5 | 3 | 1 | 2 | 1 | 5 | 49.4 |
| F — derive semantics from IDs | 3 | 4 | 4 | 4 | 2 | 3 | 4 | 69.0 |
| G — randomized properties | 2 | 4 | 2 | 1 | 1 | 2 | 3 | 44.2 |
| H — supported jobs only | 4 | 1 | 4 | 4 | 3 | 4 | 5 | 67.0 |

### Selected resolution

Select **Option A — atomic manifest rows for pure inputs and real platform
cells**.

Implement it in T3 as follows:

1. Add one tracked Node-test manifest consumed by the pure tests, hook
   integration harness, and result reconciler. Each closed row has exactly:
   `Id`, `Layer` (`policy-module`, `policy-cli`, or `installed-hook`),
   `Platform`, `NodeVersionSource`, `Input`, `ExpectedExit`,
   `ExpectedReason`, `ExpectCorepack`, `ExpectNpm`, and `ExpectLint`.
   `Platform` is `platform-independent` only for direct pure-module inputs;
   installed-hook rows name `ubuntu-latest` or `windows-latest-git-bash`.
2. Treat an ID as opaque. Validate the manifest's exact property set, types,
   unique IDs, canonical ordering, allowed enums, literal expected values, and
   absence of family/range/wildcard inputs. Never derive an oracle by parsing
   an ID.
3. Replace the old `HOOK-07` family with these exact real-hook IDs and inputs
   on **each** platform:

   | ID suffix under `HOOK-07-` | Exact actual Node | Expected result |
   | --- | --- | --- |
   | `U-22-BELOW` / `W-22-BELOW` | `22.22.1` | reject before Corepack/npm/lint: below reviewed 22 floor |
   | `U-22-FLOOR` / `W-22-FLOOR` | `22.22.2` | accept; installed hook runs pinned npm and lint |
   | `U-22-CURRENT` / `W-22-CURRENT` | `22.23.2` | accept; installed hook runs pinned npm and lint |
   | `U-23` / `W-23` | `23.0.0` | reject before Corepack/npm/lint: major not reviewed |
   | `U-24-BELOW` / `W-24-BELOW` | `24.14.0` | reject before Corepack/npm/lint: below reviewed 24 floor |
   | `U-24-FLOOR` / `W-24-FLOOR` | `24.15.0` | accept; installed hook runs pinned npm and lint |
   | `U-24-CURRENT` / `W-24-CURRENT` | `24.18.1` | accept; installed hook runs pinned npm and lint |
   | `U-25` / `W-25` | `25.0.0` | reject before Corepack/npm/lint: major not reviewed |
   | `U-26` / `W-26` | `26.5.1` | reject before Corepack/npm/lint: unreviewed current major |

   `U` means `ubuntu-latest`; `W` means
   `windows-latest-git-bash`. These are 18 independent rows and 18 independent
   results. Before implementation, re-resolve the two dated `CURRENT` patch
   observations; if they change, append new IDs and retire the old rows with a
   recorded reason rather than silently changing an ID's input.
4. Give every direct policy input its own `NODE-POLICY-###` row. The finite
   inventory includes separate rows for empty, whitespace, `v` prefix, missing
   component, extra component, leading zero, sign, prerelease, build metadata,
   Unicode digit, overflow-sized component, Node 20, Node 21, `22.22.1`,
   `22.22.2`, `22.23.2`, `22.999.999`, `23.0.0`, `24.14.0`,
   `24.14.999`, `24.15.0`, `24.18.1`, `24.999.999`, `25.0.0`,
   `26.0.0`, `26.5.1`, and `27.0.0`. Each row records its literal string,
   exit, and exact reason; no row says “malformed cases” or “boundary cases.”
5. Give the CLI's actual `process.versions.node` checks separate
   `NODE-CLI-###` IDs. At minimum, retain one Ubuntu and one Windows result for
   each admitted floor plus the selected current evidence versions; do not
   reuse the corresponding pure-policy ID.
6. Provision the exact real Node version for every installed-hook row. The hook
   reads the actual process runtime; an environment variable, fixture override,
   or mocked version is not acceptable evidence for these rows. Rejected rows
   prove no Corepack/npm/lint child starts. Accepted rows prove the project
   package-manager identity, lint invocation, exit, and commit outcome.
7. Require every harness invocation to emit one canonical result object for one
   ID. The aggregator fails on duplicate, missing, unknown, skipped-without-
   allowed-reason, or more-than-one result per ID, and publishes the manifest,
   per-ID results, and reconciliation summary.
8. A narrowly allowed infrastructure skip has its own result state and recorded
   environmental prerequisite; it is never rewritten as pass and cannot apply
   to a policy rejection. Ordinary absence of a case is failure.
9. Audit the remaining `NPM-*`, `HOOK-*`, and `AUDIT-*` tables during
   implementation. Any row that still denotes a family is split into new
   immutable one-input/one-platform/one-oracle IDs before evidence is accepted.
10. Acceptance requires a fixture that intentionally emits two results for one
    ID, omits an ID, injects an unknown ID, changes a manifest meaning under an
    existing ID, and uses a family input; every fixture must fail in the
    reconciler before the evidence can be reported as complete.

**Status: selected and ready for incorporation into T3.**

The next finding to evaluate is T4-01.

## T4-01 — Define a Windows protection contract instead of `umask`

### Resolution options

1. **Option A — two exact, inspected platform contracts.** Keep `umask 077`
   plus owner/mode checks for POSIX; define a SID-based protected-DACL contract
   for Windows and inspect the actual owner/DACL of the parent, temporary file,
   and final file.
2. **Option B — POSIX-only copyable guidance.** Remove the PowerShell block and
   its Windows evidence so every remaining block can use the POSIX contract.
3. **Option C — `icacls` command contract.** Establish and verify the Windows
   ACL through fixed `icacls` commands and parse its localized text.
4. **Option D — trusted inherited Windows ACL.** Require a user-owned parent
   and accept whatever child ACL it inherits without closing or enumerating the
   DACL.
5. **Option E — retain common `umask` prose.** Treat `umask 077` as conceptual
   language on Windows and test only file readability by the current user.
6. **Option F — encrypt state instead of defining ACLs.** Permit broader
   directory access if every temporary/final snapshot is encrypted before it
   reaches disk.
7. **Option G — operator-attested Windows protection.** Ask the operator to
   attest that the directory is private but add no machine inspection.
8. **Option H — dedicated service-account directory.** Require a separately
   provisioned Windows account and preconfigured directory outside the
   copyable block, with only a shallow local check.

The permutations that mix ACL establishment with command-text inference are
inferior to inspecting the resulting security descriptor. Encryption could be
valuable defense in depth, but it does not replace exact authorization and
cleanup semantics for plaintext process output.

### Weighted decision rubric

This rubric measures platform protection rather than generic implementation
quality. Scores are 1 through 5.

| Criterion | Weight | What a 5 requires |
| --- | ---: | --- |
| State confidentiality boundary | 26 | Unauthorized ordinary principals have no read/write/delete path |
| Executable invariant | 20 | Every owner, ACE, inheritance, UID, and mode rule is literal |
| Cross-platform truthfulness | 15 | POSIX and Windows claims use their real security models |
| Post-establishment inspection | 15 | Tests inspect actual mode/security descriptors, not attempted commands |
| Failure cleanup safety | 10 | Protection failure leaves no published state and handles uncertain files safely |
| Adversarial testability | 8 | Owner, inherited ACE, extra principal, reparse, and mode failures are fixtures |
| Operator/implementation burden | 6 | The contract remains practical to use |

Security correctness, executable meaning, and observable postconditions receive
94%; convenience receives 6%.

### Scored options

| Option | Confidentiality 26 | Executable 20 | Platform truth 15 | Inspection 15 | Cleanup 10 | Tests 8 | Burden 6 | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — exact dual contracts | 5 | 5 | 5 | 5 | 5 | 5 | 3 | **97.6** |
| B — POSIX only | 5 | 5 | 1 | 5 | 5 | 2 | 5 | 83.2 |
| C — parse `icacls` | 4 | 4 | 4 | 3 | 4 | 4 | 4 | 77.0 |
| D — inherited ACL | 2 | 3 | 4 | 2 | 3 | 3 | 5 | 57.2 |
| E — conceptual `umask` | 1 | 1 | 1 | 1 | 2 | 2 | 5 | 28.4 |
| F — encryption substitute | 4 | 2 | 4 | 3 | 3 | 3 | 1 | 61.8 |
| G — attestation only | 2 | 1 | 5 | 1 | 2 | 2 | 5 | 45.6 |
| H — dedicated account | 5 | 3 | 4 | 4 | 4 | 3 | 1 | 76.0 |

### Selected resolution

Select **Option A — two exact, inspected platform contracts**.

Implement it in T4 as follows:

1. Replace “all blocks require `umask 077`” with a normative platform table.
   POSIX blocks set `umask 077` before any path creation and verify:
   the canonical protected parent is an ordinary non-link directory owned by
   the effective UID with mode exactly `0700`; every unpublished temporary and
   published state file is an ordinary non-link file owned by the effective UID
   with mode exactly `0600`; no group/other bit is set. Inspect with a
   documented `stat` implementation/format and fail closed if the required
   fields cannot be obtained.
2. Windows accepts only an already-existing local NTFS/ReFS parent whose
   canonical path is outside the repository and shared temporary roots. Its
   owner SID is the current process token's user SID. Its DACL is protected
   (`AreAccessRulesProtected == true`), canonical, contains no inherited ACE,
   no deny ACE, and exactly three explicit allow principals:
   the current user SID, `S-1-5-18` (LOCAL SYSTEM), and
   `S-1-5-32-544` (BUILTIN Administrators). Each receives `FullControl`;
   parent ACEs apply to the directory and inherit to containers/objects. No
   other SID or unresolved identity is allowed.
3. Immediately after `FileMode.CreateNew` succeeds, while the candidate handle
   remains exclusively open, set a protected file DACL with inheritance
   removed and exactly the same three explicit allow SIDs with `FullControl`
   and no inheritance/propagation flags. The final hard link shares that same
   file security descriptor. Reinspect both names after publication and the
   remaining final name after temporary-name removal.
4. Use .NET security-descriptor APIs, not localized command output:
   `WindowsIdentity.GetCurrent().User`,
   `DirectoryInfo.GetAccessControl`/`SetAccessControl` and
   `FileInfo.GetAccessControl`/`SetAccessControl` on .NET Framework, with the
   corresponding `FileSystemAclExtensions` methods where PowerShell 7 exposes
   them; `SetOwner`, `SetAccessRuleProtection($true,$false)`,
   `FileSystemAccessRule`, `GetOwner`, `AreAccessRulesProtected`,
   `AreAccessRulesCanonical`, and
   `GetAccessRules($true,$true,[SecurityIdentifier])`.
5. The implementation uses SIDs and numeric rights/flags for comparisons; it
   never compares localized account names, `icacls` prose, or only an SDDL
   substring. Serialize a canonical evidence projection of owner SID,
   protection/canonical flags, and sorted ACE tuples; never include state.
6. ACL verification occurs before Terraform starts, after candidate creation,
   after hard-link publication, and after temporary-name removal. A mismatch
   before creation/pull leaves no candidate/final. A mismatch after creation
   deletes only a still-open/proven-owned unpublished candidate; inability to
   prove identity retains the uncertain root and reports its path without
   state bytes.
7. Add permanent negative cases for wrong owner; inheritance enabled; inherited
   ACE; extra user/group; missing SYSTEM/Administrators/current-user ACE;
   deny ACE; noncanonical/unreadable DACL; FAT or another filesystem without
   persistent ACL/file-ID support; child ACL mutation; POSIX wrong owner/modes;
   and an attempted command that reports success while the actual descriptor
   remains wrong.
8. State the threat boundary precisely: these checks protect against ordinary
   principals and accidental sharing. Administrators/SYSTEM retain their normal
   authority, and the operator still attests that no authorized principal is
   concurrently mutating the namespace.

**Status: selected and ready for incorporation into T4.**

The next finding to evaluate is T4-02.

## T4-02 — Make every confirmation and label grammar executable

### Resolution options

1. **Option A — canonical JSON confirmation records.** Define narrow ASCII
   input grammars; generate one canonical single-line JSON array containing all
   operation-specific fields; read one raw terminal line; compare it byte for
   byte; and give every rejection one exact status/no-call oracle.
2. **Option B — delimiter-safe key/value text.** Use one line of fixed
   `key=value` fields, prohibit the separators from every input grammar, and
   compare ordinally.
3. **Option C — digest-only confirmation.** Display all fields separately and
   require the operator to type only a digest/prefix that binds a canonical
   record.
4. **Option D — prose plus regular-expression examples.** Describe the desired
   strings and let the implementation choose exact separators and limits.
5. **Option E — normalized friendly text.** Trim whitespace, normalize Unicode,
   and compare case-insensitively to reduce operator mistakes.
6. **Option F — multiple interactive prompts.** Ask for operation, workspace,
   backend, serials/address, and digest separately, validating each answer.
7. **Option G — cryptographically signed approval token.** Replace typed text
   with a separately generated signed record containing every binding.
8. **Option H — remove copyable destructive commands.** Retain warnings and
   checklists but provide no push/rm execution path or confirmation grammar.

JSON provides escaping for the resource address without inventing a second
delimiter language. A digest-only design cryptographically binds the values but
does not make the operator visibly re-attest the critical identity fields.

### Weighted decision rubric

| Criterion | Weight | What a 5 requires |
| --- | ---: | --- |
| Grammar correctness and closure | 26 | Every accepted byte string and maximum length is defined |
| Unambiguous human confirmation | 22 | Separators/escaping produce exactly one parse and comparison |
| Cross-edition machine checkability | 17 | Bash and harness can construct and verify the same bytes |
| Destructive-action binding | 14 | Operation, workspace, backend, serials/address, and digest are all bound |
| Exact rejection/no-mutation oracle | 10 | Every mismatch has one status and zero destructive calls |
| Operator usability | 7 | The expected value is visible and copyable |
| Implementation churn | 4 | The design is reasonably small |

Correctness, binding, and no-mutation evidence receive 89%; usability and churn
remain secondary.

### Scored options

| Option | Grammar 26 | Confirmation 22 | Machine 17 | Binding 14 | No mutation 10 | Usability 7 | Churn 4 | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — canonical JSON record | 5 | 5 | 5 | 5 | 5 | 4 | 4 | **97.8** |
| B — key/value text | 4 | 4 | 5 | 4 | 5 | 5 | 4 | 86.8 |
| C — digest only | 4 | 3 | 5 | 3 | 5 | 4 | 5 | 79.0 |
| D — regex examples | 3 | 2 | 3 | 3 | 4 | 4 | 5 | 60.6 |
| E — friendly normalization | 2 | 1 | 3 | 2 | 3 | 5 | 5 | 47.6 |
| F — multiple prompts | 4 | 4 | 3 | 5 | 4 | 3 | 2 | 76.4 |
| G — signed token | 5 | 4 | 4 | 5 | 5 | 1 | 1 | 83.4 |
| H — no destructive block | 5 | 5 | 5 | 1 | 5 | 1 | 2 | 80.8 |

### Selected resolution

Select **Option A — canonical JSON confirmation records**.

Implement it in T4 as follows:

1. Accept `EXPECTED_BACKEND_ID` only as
   `backend-v1:<type>:<authority>:<scope>`. Each component is 1–63 ASCII bytes,
   matches
   `[a-z0-9](?:[a-z0-9._-]{0,61}[a-z0-9])?`, and is compared ordinally.
   Total length is at most 206 bytes. No uppercase, whitespace, control,
   Unicode, slash, backslash, percent escape, empty component, leading/trailing
   punctuation, or additional colon is accepted. It remains explicitly
   operator-attested; satisfying the grammar does not prove backend identity.
2. For these copyable destructive blocks, support workspace labels only when
   they match `[A-Za-z0-9][A-Za-z0-9._-]{0,89}`. This is an intentional
   confirmation-safe subset, not a claim about every Terraform backend or
   historical workspace name; an unsupported name stops and requires an
   independently reviewed procedure.
3. Accept `OPERATION_LABEL` only when absent/empty or when it is exactly
   `<UTC>-<slug>`, where UTC is a real calendar instant in
   `yyyyMMdd'T'HHmmss'Z'` form and slug matches
   `[a-z0-9](?:[a-z0-9-]{0,30}[a-z0-9])?`. The complete label is at most 49
   ASCII bytes. It is diagnostic only and never changes a path or command.
4. Canonicalize a tool-computed SHA-256 by first requiring exactly 64 ASCII hex
   characters, mapping `A-F` to `a-f`, and then requiring
   `[0-9a-f]{64}`. Do not normalize any user-supplied digest. The confirmation
   field is exactly `Substring(0,16)` and accepts lowercase ASCII only.
5. Generate the expected confirmation with the same reviewed JSON serializer
   used by the harness, using compact UTF-8 JSON and no BOM/newline:
   - push:
     `["state-push","<workspace>","<backend-id>",<current-serial>,<proposed-serial>,"<proposed-sha256-first16>"]`;
   - rm:
     `["state-rm","<workspace>","<backend-id>","<exact-resource-address>","<backup-sha256-first16>"]`.
   Serials are canonical nonnegative JSON safe integers. JSON string escaping
   is the sole escaping language; after decoding, the resource-address element
   must equal the one exact argv value ordinally.
6. Display the generated line once, then read exactly one line from the
   controlling terminal (`/dev/tty`), with echo enabled and inherited stdin
   unused. Reject EOF, NUL, CR, more than 4096 raw bytes, invalid UTF-8,
   leading/trailing whitespace, a second line, or any byte inequality. Perform
   no trim, case fold, Unicode normalization, shell evaluation, reparsing into
   argv, or retry.
7. Establish exact Bash status classes for the whole canonical block:
   `64` input/grammar, `65` environment/identity, `66` snapshot/parse,
   `67` review/diff, `68` confirmation, `69` lock/exclusion,
   `70` Terraform mutation, `71` post-verification, and `72` cleanup/uncertain
   state. Any confirmation mismatch exits `68`; the push/rm stub call count is
   exactly zero and all local/remote mutation sentinels remain unchanged.
8. Give every invalid grammar and confirmation variant its own stable fixture
   ID and exact result. Include every separator edge, non-ASCII/control byte,
   length boundary, invalid calendar instant, JSON escape, address containing
   quotes/backslashes, serial number form, digest case/length, terminal EOF,
   CRLF, extra line/text, and correct record for the wrong operation.
9. The harness records the expected/actual lengths and a safe reason code, not
   the typed record, backend identifier, resource address, or state-derived
   value. It proves all validation completes before any destructive child is
   started.

**Status: selected and ready for incorporation into T4.**

The next finding to evaluate is T4-03.

## T4-03 — Set an exact stderr byte bound and overflow behavior

### Resolution options

1. **Option A — 64-KiB raw-byte cap, drain-to-EOF, fail closed.** Retain at
   most 65,536 stderr bytes, count raw bytes, continue draining/discarding
   excess so the child cannot deadlock, and make any 65,537th byte a distinct
   failure even if Terraform exits zero. Emit no stderr payload.
2. **Option B — 64-KiB truncation and continue.** Drain/discard excess and mark
   truncation, but otherwise honor the native Terraform exit.
3. **Option C — terminate at overflow.** Stop reading and kill the Terraform
   process as soon as the cap is exceeded.
4. **Option D — decoded-character cap.** Use `StandardError.ReadToEndAsync`,
   then truncate to a maximum number of .NET characters.
5. **Option E — unbounded concurrent capture.** Drain concurrently into a
   memory buffer so pipes cannot deadlock, with no maximum.
6. **Option F — spool all stderr to a protected file.** Avoid memory growth by
   writing stderr to disk and retain or delete it according to native outcome.
7. **Option G — merge stderr with stdout.** Use one redirected stream and split
   diagnostics from state after process completion.
8. **Option H — do not redirect stderr.** Let Terraform inherit the terminal's
   stderr while only stdout is captured.

The independent choices are cap unit (bytes/characters), overflow action
(continue/fail, continue/succeed, kill), retention (memory/file), and emission.
Option A is the only combination that is bounded, deadlock-safe, byte-exact,
and incapable of treating truncated diagnostics as a successful capture.

### Weighted decision rubric

| Criterion | Weight | What a 5 requires |
| --- | ---: | --- |
| Pipe/deadlock safety | 24 | stdout and stderr are drained concurrently through EOF |
| Hard resource bound | 20 | Retained memory/disk has an exact raw-byte maximum |
| Boundary determinism | 18 | Exactly limit and limit+1 have explicit distinct oracles |
| Diagnostic/state secrecy | 14 | No child diagnostic or state-derived secret reaches logs/artifacts |
| Native/overflow attribution | 10 | Native exit and overflow remain independently observable |
| PowerShell 5.1/7 parity | 8 | One byte-stream algorithm behaves equally on both editions |
| Implementation complexity | 6 | The pump and lifecycle remain reviewable |

### Scored options

| Option | Deadlock 24 | Bound 20 | Boundary 18 | Secrecy 14 | Attribution 10 | Parity 8 | Complexity 6 | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — cap, drain, fail | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **98.8** |
| B — truncate, continue | 5 | 5 | 5 | 3 | 3 | 5 | 5 | 90.4 |
| C — kill at cap | 3 | 5 | 5 | 5 | 2 | 4 | 3 | 80.4 |
| D — character cap | 4 | 3 | 2 | 4 | 4 | 4 | 5 | 70.0 |
| E — unbounded capture | 5 | 1 | 1 | 2 | 4 | 5 | 5 | 59.2 |
| F — protected spool | 5 | 4 | 4 | 1 | 4 | 4 | 2 | 74.0 |
| G — merged streams | 2 | 3 | 2 | 1 | 1 | 4 | 4 | 44.8 |
| H — inherited stderr | 1 | 5 | 1 | 4 | 1 | 5 | 5 | 55.6 |

### Selected resolution

Select **Option A — 64-KiB raw-byte cap, drain-to-EOF, fail closed**.

Implement it in T4 as follows:

1. Define `MAX_STDERR_BYTES = 65536`. This is a count of bytes read from
   `Process.StandardError.BaseStream`, not decoded characters, lines, buffer
   capacity, or the combined stdout/stderr size.
2. Start independent raw-stream pumps immediately after process start:
   stdout copies only to the exclusively held candidate `FileStream`; stderr
   reads fixed-size byte buffers. Retain at most the first 65,536 stderr bytes
   in memory. On any additional byte, set `StderrOverflow = true`, discard that
   and all later stderr bytes while continuing to read to EOF, and keep only a
   saturating observed count of `65537+`.
3. Do not call synchronous `ReadToEnd`, mix synchronous/asynchronous operations
   on one stream, wait for the process before both pumps have started, or stop
   draining merely because the bound was reached. Await both EOF pumps and
   process completion, dispose the stream/process objects, then decide.
4. Exactly 65,536 stderr bytes is within the bound. Exactly 65,537 bytes sets
   overflow. Overflow has the stable reason `stderr-byte-limit-exceeded` and
   status `73`; it fails the capture regardless of native exit and prevents
   validation/publication. Preserve the separately captured native exit in
   in-memory/test evidence rather than replacing it with `73`.
5. No captured stderr bytes—truncated or complete—may be printed, embedded in
   an exception, persisted in an artifact, or written to an alternate file.
   The safe diagnostic is limited to reason, native exit/start outcome,
   `stderrLimitBytes=65536`, and
   `stderrObservedBytes=0..65536|65537+`.
6. On overflow, remove only a still-proven owned ordinary unpublished
   candidate after both pumps and the process have released it. Final remains
   absent. If ownership/identity or cleanup cannot be proved, retain the
   uncertain root and return the cleanup/uncertain-state class instead while
   also recording the overflow as the primary failure.
7. Make `SM-PS-BACKUP-14` atomic rather than “edge cases”: give separate stable
   rows/results for `65535`, `65536`, and `65537` stderr bytes, zero/nonzero
   native exit permutations, stdout larger than a pipe buffer, simultaneous
   large stdout/stderr, multibyte-looking arbitrary bytes, read exception, and
   delayed EOF. Each row runs on Windows PowerShell 5.1 and PowerShell 7.
8. Assert no deadlock with a finite harness-owned process deadline. A deadline
   is an infrastructure/test failure, not the expected overflow result and not
   permission to publish partial stdout.

**Status: selected and ready for incorporation into T4.**

The next finding to evaluate is T4-04.

## T4-04 — Require strict BOM-less UTF-8 decoding

### Resolution options

1. **Option A — explicit BOM check plus throwing incremental decoder.** Inspect
   the first bytes, reject UTF-8 BOM, and validate the entire file with
   `UTF8Encoding(false,true).GetDecoder()` through final flush before JSON or
   metadata extraction.
2. **Option B — default `StreamReader`.** Rely on its default UTF-8 replacement
   fallback and BOM detection.
3. **Option C — strip BOM, then decode strictly.** Treat BOM as harmless input
   metadata while rejecting every other invalid sequence.
4. **Option D — byte-pattern regular expressions.** Search for known invalid
   leading/continuation byte ranges without using a complete decoder.
5. **Option E — rely on `terraform show`.** Treat Terraform's acceptance of the
   state file as sufficient proof of BOM-less valid UTF-8.
6. **Option F — rely on the JSON parser.** Decode with platform defaults and
   assume JSON parse success proves the original bytes were valid UTF-8.
7. **Option G — replacement normalization.** Decode permissively, replace
   malformed input with U+FFFD, and validate the normalized JSON.
8. **Option H — base64-encode process output first.** Store encoded bytes and
   decode/validate only when a rollback consumes the backup.

Strict decoding and BOM policy are independent: Option C is strict but violates
the promised BOM-less byte contract; Options B/F/G lose original-byte
information before validation.

### Weighted decision rubric

| Criterion | Weight | What a 5 requires |
| --- | ---: | --- |
| UTF-8 acceptance correctness | 28 | Accept exactly well-formed UTF-8 and reject all malformed sequences |
| Original-byte fidelity | 18 | Validation never repairs, strips, or transcodes the candidate |
| Adversarial fixture completeness | 17 | Every required invalid class and chunk boundary has an exact oracle |
| Secret-safe failure | 13 | Invalid bytes/text never enter diagnostics or artifacts |
| PowerShell edition parity | 10 | The same .NET contract works under 5.1 and 7 |
| Validation-pipeline integration | 8 | Encoding failure precedes JSON/show/metadata/publication |
| Complexity | 6 | The implementation is small and auditable |

### Scored options

| Option | UTF-8 28 | Fidelity 18 | Fixtures 17 | Secrecy 13 | Parity 10 | Pipeline 8 | Complexity 6 | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — throwing decoder | 5 | 5 | 5 | 5 | 5 | 5 | 4 | **98.8** |
| B — default reader | 1 | 4 | 2 | 4 | 5 | 5 | 5 | 61.2 |
| C — strip BOM, strict | 4 | 5 | 4 | 5 | 5 | 5 | 4 | 89.8 |
| D — byte regexes | 2 | 4 | 2 | 5 | 5 | 3 | 3 | 63.8 |
| E — Terraform parser only | 3 | 4 | 3 | 5 | 5 | 5 | 5 | 78.4 |
| F — JSON parser only | 2 | 4 | 3 | 5 | 5 | 5 | 5 | 73.8 |
| G — replacement normalization | 1 | 2 | 1 | 3 | 5 | 4 | 5 | 46.4 |
| H — base64 wrapper | 4 | 5 | 4 | 4 | 3 | 2 | 1 | 74.8 |

### Selected resolution

Select **Option A — explicit BOM check plus throwing incremental decoder**.

Implement it in T4 as follows:

1. After process success/EOF/disposal and ordinary-file identity checks, open
   the candidate read-only with `FileShare.None`. Read the first three bytes
   without text decoding. If they equal `EF BB BF`, reject with
   `state-utf8-bom`; reset to byte zero otherwise.
2. Instantiate exactly
   `[System.Text.UTF8Encoding]::new($false,$true)` (or the equivalent
   two-argument constructor on Windows PowerShell 5.1), call `GetDecoder()`,
   and feed the complete `FileStream` through fixed byte/character buffers.
   Call `Decoder.Convert(..., flush=$true)` at EOF. Any
   `DecoderFallbackException`, incomplete final sequence, read error, or
   unconsumed input rejects the candidate.
3. The decoder is validation-only: discard decoded characters after each
   conversion and leave the original candidate bytes untouched. Do not use
   `Encoding.UTF8`, parameterless `UTF8Encoding`, `StreamReader` default
   detection/fallback, `Get-Content`, `Out-File`, or a decode/re-encode
   round trip.
4. Only after complete strict validation may the trusted JSON validation,
   `terraform show -json`, and top-level metadata extraction run. Encoding
   failure uses the snapshot/parse status `66`; final is absent, no metadata is
   emitted, and cleanup follows the proven-identity rule.
5. Add one stable case/result per exact byte fixture on both PowerShell
   editions: invalid leading/stray continuation (`80`), missing continuation
   (`C2 20`), overlong (`C0 AF` and `E0 80 AF`), surrogate
   (`ED A0 80`), code point above U+10FFFF (`F4 90 80 80`), truncated
   2/3/4-byte endings, repeated invalid sequence, UTF-8 BOM, UTF-16LE/BE BOM,
   and valid ASCII/non-ASCII/maximum scalar.
6. Force every valid/invalid multibyte sequence across each incremental-buffer
   boundary so a decoder that validates chunks independently cannot pass.
   Verify that valid non-ASCII final bytes remain byte-identical.
7. Failure diagnostics contain only the stable reason and byte offset (if the
   decoder supplies a trustworthy numeric offset); they never contain the
   decoded character, surrounding bytes, state fragment, exception message, or
   candidate content.
8. The Bash block retains its explicit BOM rejection and must name and test its
   reviewed strict UTF-8 validator. Terraform/JSON parse success is an
   additional state-validity gate, not a substitute for byte-valid UTF-8.

**Status: selected and ready for incorporation into T4.**

The next finding to evaluate is T4-05.

## T4-05 — Define path, reparse, and hard-link identity mechanics

### Resolution options

1. **Option A — one Win32 handle-identity helper on both editions.** Embed a
   reviewed `Add-Type` helper using fixed Unicode Win32 calls to walk/reject
   reparse components, record handle-based file IDs/link counts, create the
   hard link once, and compare open-handle identities. Keep the protected-parent
   and no-authorized-competitor precondition explicit.
2. **Option B — managed path/attribute checks.** Use `Path.GetFullPath`,
   `File.GetAttributes`, `FileStream(CreateNew)`, and path-based digest checks
   without native handle identity.
3. **Option C — PowerShell cmdlet checks.** Rely on `Resolve-Path`,
   `Get-Item`, `LinkType`, and `New-Item -ItemType HardLink` output.
4. **Option D — PowerShell 7 only.** Remove Windows PowerShell 5.1 support and
   use newer `FileSystemInfo.LinkType`/`ResolveLinkTarget` plus .NET APIs.
5. **Option E — external Windows utilities.** Parse `fsutil`, `cmd /c dir /al`,
   and `icacls` output for reparse/link/identity evidence.
6. **Option F — resolve reparse points once and allow them.** Canonicalize the
   final target, then proceed so long as it currently lies under the protected
   root.
7. **Option G — replace hard-link publication with copy/CreateNew.** Avoid
   file-identity mechanics by copying validated bytes into a fresh final file
   and rehashing.
8. **Option H — drop the Windows block.** Retain only Bash publication rather
   than claim guarantees that the Windows implementation does not establish.

Path syntax, traversal, entry type, file identity, link count, and race model
are separate questions. Option A answers each at the handle layer while
truthfully limiting what a path-based Windows script can promise against an
authorized namespace adversary.

### Weighted decision rubric

| Criterion | Weight | What a 5 requires |
| --- | ---: | --- |
| Namespace/traversal correctness | 26 | Every component is ordinary, local, canonical, and non-reparse |
| Handle-based identity proof | 22 | Volume/file ID and link count are compared on live handles |
| No-replace publication proof | 16 | One native create fails on every preexisting entry and proves same file |
| PowerShell 5.1/7 parity | 12 | One algorithm and primitive work on both required editions |
| Race-model honesty | 10 | Achievable guarantees and no-competitor assumptions are explicit |
| Fail-closed portability | 8 | Unsupported identity/filesystem primitives stop without fallback |
| Complexity | 6 | The implementation remains reviewable |

### Scored options

| Option | Namespace 26 | Identity 22 | Publication 16 | Parity 12 | Race 10 | Fail closed 8 | Complexity 6 | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — Win32 handle helper | 5 | 5 | 5 | 5 | 5 | 5 | 2 | **96.4** |
| B — managed path checks | 3 | 2 | 4 | 5 | 2 | 3 | 5 | 64.0 |
| C — cmdlet checks | 2 | 1 | 4 | 3 | 1 | 2 | 5 | 46.0 |
| D — PowerShell 7 only | 4 | 5 | 5 | 1 | 4 | 5 | 4 | 82.0 |
| E — external utilities | 4 | 4 | 4 | 4 | 3 | 4 | 2 | 75.6 |
| F — allow resolved reparse | 1 | 2 | 4 | 5 | 1 | 2 | 5 | 50.0 |
| G — copy/CreateNew | 3 | 2 | 1 | 5 | 2 | 3 | 5 | 54.4 |
| H — remove Windows block | 1 | 1 | 1 | 1 | 5 | 5 | 5 | 39.2 |

### Selected resolution

Select **Option A — one Win32 handle-identity helper on both editions**.

Implement it in T4 as follows:

1. Accept only a fully qualified local drive path matching a reviewed Windows
   drive-root form. Reject relative paths, UNC/device/extended-device syntax,
   PowerShell provider syntax, alternate data streams/extra colon, wildcard
   characters, trailing separator for a file, and NUL/control characters.
   Apply `Path.GetFullPath` exactly once, require an ordinary filename leaf,
   and use only that canonical string thereafter.
2. Walk every existing component from the volume root through the protected
   parent with `CreateFileW(OPEN_EXISTING)` using
   `FILE_FLAG_OPEN_REPARSE_POINT` and, for directories,
   `FILE_FLAG_BACKUP_SEMANTICS`. Inspect
   `FILE_ATTRIBUTE_TAG_INFO`; reject `FILE_ATTRIBUTE_REPARSE_POINT`, a
   non-directory component, volume change, open/attribute failure, or a final
   normalized handle path unequal to the expected canonical parent.
3. Perform exact leaf-absence checks through the already-validated parent's
   directory view and a no-follow leaf open. Treat any ordinary file,
   directory, symlink, junction, mount point, dangling reparse entry, or
   unreadable/indeterminate entry as existing. `Test-Path` false alone is not
   proof of absence.
4. Create the candidate once with `FileStream` using `FileMode.CreateNew`,
   write-only access, and `FileShare.None`. While its `SafeFileHandle` is held,
   call `GetFileInformationByHandleEx(FileAttributeTagInfo)`,
   `GetFileInformationByHandleEx(FileIdInfo)`, and
   `GetFileInformationByHandle` for link count. Require ordinary non-reparse,
   the parent volume, and `NumberOfLinks == 1`; record
   `(VolumeSerialNumber, 128-bit FileId)` as its opaque identity.
5. Implement the interop once in a fixed C# `Add-Type` block compatible with
   Windows PowerShell 5.1 and PowerShell 7. Use `SafeFileHandle`, `CharSet.Unicode`,
   `SetLastError=true`, fixed numeric flags/structures, checked buffer sizes,
   and `GetLastWin32Error`. Do not use deprecated raw `IntPtr` handles,
   localized utility output, `LinkType`, or edition-specific branches.
6. Publish exactly once with `CreateHardLinkW(final,temp,NULL)`. No `-Force`,
   delete/recreate, copy, move, alternate filename, or retry is allowed.
   Preexisting-target errors are refusal; unsupported filesystem/privilege/API
   errors are fail-closed publication failure with final absent and validated
   temporary retained.
7. Open both names no-follow after publication and require: ordinary
   non-reparse attributes; equal volume plus 128-bit file ID; link count exactly
   `2`; equal length, SHA-256, and ACL. Only then close handles and unlink the
   exact temporary name. Reopen final and require the same identity plus link
   count exactly `1`. Any initial candidate link count above one proves an
   undisclosed hard link and stops; any unavailable/ambiguous ID or link-count
   primitive also stops.
8. These mechanics prove identity of the handles actually inspected and
   no-replace creation in a protected directory. Windows PowerShell 5.1 and 7
   do **not** gain an `openat`-style adversarial namespace sandbox from
   path-based .NET code. Therefore the T4 Windows contract also requires the
   T4-01 ACL and operator attestation that no current-user, Administrator, or
   SYSTEM process is competing. If that cannot be asserted, refuse operation.
9. Add real local NTFS/ReFS cases for every rejected path class, reparse at
   each parent depth, junction/symlink/dangling leaf, alternate stream, parent
   swap by an authorized harness process (must fail/retain uncertain state),
   candidate extra hard link, wrong-volume final, file-ID API failure, link
   count `1/2/>2`, existing-target classes, and the synchronized exactly-one-
   winner publication race on both editions.

**Status: selected and ready for incorporation into T4.**

The next finding to evaluate is T4-06.

## T4-06 — Define a secret-safe state-difference review

### Resolution options

1. **Option A — offline redacted structural/change-kind projection.** Parse
   both states only inside the protected workstation, compare values in memory,
   and emit a canonical allowlisted summary of configuration-known identities,
   JSON paths, types, and change kinds—never values or value digests. Require
   human approval of that exact summary and its hash.
2. **Option B — whole-file SHA-256 inequality.** Prove only that current and
   proposed state bytes differ, with no semantic description.
3. **Option C — raw JSON/text diff.** Let the operator review the complete
   state diff locally and retain or paste the relevant lines.
4. **Option D — `terraform show` text diff.** Compare Terraform's human-readable
   rendering and rely on its sensitive-value redaction.
5. **Option E — ephemeral-key HMAC leaf diff.** HMAC every canonical leaf with a
   random session key, compare those digests, display changed paths, and destroy
   the key.
6. **Option F — unstructured offline human attestation.** Require the operator
   to inspect both files but define no tool, projection, or retained evidence.
7. **Option G — plan-only review.** Treat a post-push `terraform plan` as the
   sole proof of the state difference.
8. **Option H — encrypted full diff artifact.** Retain the complete diff in an
   encrypted evidence bundle for reviewers with decryption access.

Byte inequality and semantic acceptability are distinct. A secret-safe review
also needs to avoid equality hashes of low-entropy leaf values; therefore the
selected projection compares values only in memory and outputs change kinds.

### Weighted decision rubric

| Criterion | Weight | What a 5 requires |
| --- | ---: | --- |
| Secret non-disclosure | 27 | No raw value, reversible encoding, or value-derived stable digest leaves memory |
| Semantic review sufficiency | 22 | A reviewer can identify the exact binding/shape/change class intended |
| Determinism and oracle quality | 17 | The same validated inputs yield one canonical summary and decision |
| Operator usability | 13 | Review is bounded and understandable |
| Retained evidence quality | 10 | Evidence binds approval without retaining state secrets |
| Cross-platform/tool feasibility | 7 | The process works offline with reviewed repository tooling |
| Implementation/cost | 4 | Added machinery remains proportionate |

### Scored options

| Option | Secrecy 27 | Semantics 22 | Determinism 17 | Usability 13 | Evidence 10 | Feasibility 7 | Cost 4 | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — redacted projection | 5 | 5 | 5 | 4 | 5 | 4 | 3 | **94.4** |
| B — file digest only | 5 | 2 | 5 | 5 | 4 | 5 | 5 | 84.8 |
| C — raw diff | 1 | 5 | 5 | 3 | 3 | 5 | 5 | 69.2 |
| D — `terraform show` diff | 2 | 4 | 3 | 4 | 3 | 5 | 5 | 66.0 |
| E — ephemeral HMAC | 5 | 5 | 4 | 3 | 4 | 3 | 2 | 84.2 |
| F — human attestation only | 1 | 5 | 2 | 2 | 1 | 5 | 5 | 52.4 |
| G — plan only | 5 | 2 | 3 | 5 | 3 | 5 | 5 | 76.0 |
| H — encrypted full diff | 4 | 5 | 4 | 1 | 4 | 2 | 1 | 71.4 |

### Selected resolution

Select **Option A — offline redacted structural/change-kind projection**.

Implement it in T4 as follows:

1. Add a reviewed, offline diff helper invoked only against the already
   validated current/proposed files in the protected operator directory. It
   performs no network access, writes no raw intermediate/output file, disables
   xtrace/transcripts, applies explicit size/depth/count ceilings and
   duplicate-key rejection, and holds parsed values only in process memory.
2. Obtain the exact reviewed `terraform show -json` representation for each
   file using the same resolved Terraform version. Capture its stdout into
   separately protected, proven-owned temporary streams/files that are never
   logged and are exactly cleaned under the same identity contract.
3. Build a closed canonical comparison projection containing:
   state lineage/serial/Terraform format labels; configuration-known module and
   resource addresses; resource mode/type/name/provider address/schema version
   and instance key; output name/type/sensitivity flag; JSON property path;
   old/new JSON kind; and one change enum
   (`added`, `removed`, `type-changed`, `value-changed`,
   `sensitive-subtree-changed`, or `unchanged`). Never include an old/new value,
   string length, entropy clue, encoded value, raw/state fragment, ordinary
   hash of a leaf, or provider diagnostic.
4. Validate every displayed address/property identifier against the reviewed
   configuration/schema inventory. If an identifier exists only in state or
   contains an unsafe byte, collapse it to a bounded opaque count/category
   (`unreviewed-identity-present`) and require separate protected local review;
   do not print it.
5. Use the `sensitive_values` tree and output sensitivity metadata only to
   collapse a marked subtree; never traverse it into display rows. Treat
   unrecognized schema/marking shapes as failure. Values are compared for
   equality only in memory. The helper never persists per-value hashes, even
   for nonsensitive fields.
6. Require an operator/peer-reviewed allowlist of exact projected paths and
   permitted change enums before confirmation. Any missing, extra, duplicate,
   unknown, unreviewed-identity, provider-address, resource-binding, output,
   or sensitivity-flag change stops. Record only sorted summary rows, aggregate
   counts, tool/Terraform versions, current/proposed whole-file SHA-256 already
   required by T4, and SHA-256 of the canonical redacted summary.
7. Whole-file digest equality means there is no proposed byte change and stops.
   Digest inequality with an empty redacted semantic summary is classified
   `serialization-only-difference`, not “meaningfully different,” and also
   stops the copyable push path pending a separate reviewed procedure.
8. The typed confirmation binds the proposed whole-file digest prefix only
   after the redacted summary hash and allowlist are peer-approved. A successful
   diff never authorizes mutation by itself; every concurrency/identity/backup/
   confirmation gate still applies.
9. Add fixtures with canary secrets in strings, numbers, booleans, object keys,
   arrays, outputs, provider/private data, nested sensitive subtrees, low-
   entropy values, diagnostics, and unsafe state-only identities. Search all
   stdout/stderr/results/artifacts for raw, encoded, and digest canaries while
   asserting exact safe summary rows and mismatch status `67`.

**Status: selected and ready for incorporation into T4.**

The next finding to evaluate is T4-07.

## T4-07 — Consume the corrected T2 interruption contract

### Resolution options

1. **Option A — normative dependency plus shared harness contract.** T4 embeds
   the same signal-specific trap/one-EXIT-owner semantics as merged T2 and
   extends T2's existing harness driver with phase-specific T4 cases for HUP,
   INT, TERM, cleanup failure, and destructive-call uncertainty.
2. **Option B — copy T2's traps into T4 independently.** Reproduce the current
   text and write a separate signal harness without a drift check.
3. **Option C — TERM-only integration.** Test the most common termination path
   and assume HUP/INT are equivalent.
4. **Option D — timeout-only testing.** Kill the entire harness after a deadline
   and inspect remaining files, without asserting the shell's signal exit.
5. **Option E — rely on Terraform signal handling.** Remove shell traps and let
   the Terraform process determine status and cleanup.
6. **Option F — external supervisor.** Add a new wrapper executable that owns
   signals/cleanup for both T2 and T4.
7. **Option G — automatic resume/rollback.** On interruption, retry backup or
   automatically roll back a possibly started push/rm.
8. **Option H — prose/manual interruption guidance.** Describe operator
   response but add no permanent executable signal cases.

Backup-file cleanup and destructive remote mutation need different interruption
postconditions. The selected design reuses the common signal semantics while
adding T4-specific phase ownership/uncertainty rules.

### Weighted decision rubric

| Criterion | Weight | What a 5 requires |
| --- | ---: | --- |
| T2 contract fidelity | 25 | T4 names and mechanically checks the exact merged predecessor contract |
| Signal/status accuracy | 20 | HUP=129, INT=130, TERM=143 with exact precedence |
| Exactly-once cleanup safety | 19 | One EXIT owner handles every owned path and cleanup failure |
| Destructive-call uncertainty safety | 14 | Interruption never causes retry, bypass, or automatic rollback |
| Permanent regression evidence | 10 | Every signal/phase/cleanup permutation has a stable result |
| Dependency traceability | 7 | Exact predecessor commit/evidence is retained |
| CI/maintenance cost | 5 | The expanded matrix remains manageable |

### Scored options

| Option | Fidelity 25 | Status 20 | Cleanup 19 | Uncertainty 14 | Evidence 10 | Traceability 7 | Cost 5 | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A — consume and extend | 5 | 5 | 5 | 5 | 5 | 5 | 3 | **98.0** |
| B — independent copy | 4 | 5 | 4 | 4 | 4 | 3 | 4 | 82.6 |
| C — TERM only | 2 | 2 | 3 | 3 | 2 | 3 | 5 | 51.0 |
| D — timeout only | 2 | 1 | 3 | 3 | 2 | 2 | 5 | 45.6 |
| E — Terraform owns signals | 1 | 1 | 1 | 2 | 1 | 2 | 5 | 28.2 |
| F — external supervisor | 4 | 4 | 4 | 4 | 4 | 4 | 2 | 78.0 |
| G — auto resume/rollback | 1 | 1 | 1 | 1 | 1 | 2 | 4 | 25.4 |
| H — prose only | 2 | 2 | 2 | 3 | 1 | 2 | 5 | 43.8 |

### Selected resolution

Select **Option A — normative dependency plus shared harness contract**.

Implement it in T4 as follows:

1. Record the exact merged T2 commit and retained T2 signal evidence as a T4
   prerequisite. Extend the same
   `.github/workflows/Test-StateRecoveryExamples.sh` driver and its canonical
   signal/cleanup assertions; do not introduce a second interpretation.
2. Every T4 Bash block installs distinct handlers for HUP, INT, and TERM. A
   handler records the signal reason, disables/ignores further HUP/INT/TERM,
   and exits with `129`, `130`, or `143`. One `EXIT` trap captures the primary
   status first, disables itself, performs cleanup exactly once, and returns the
   primary nonzero status. Cleanup-only failure returns `1`; cleanup failure
   never replaces a prior native/safety/signal status but is separately
   reported.
3. The embedded copyable blocks and the T2 canonical fragment must have the
   same normalized trap semantics. Add a permanent drift check over handler
   signals, status constants, trap ownership, disable order, cleanup call
   count, and primary/cleanup precedence; a prose claim of reuse is not enough.
4. Define exact T4 phase postconditions:
   - before candidate creation: no file and no remote/destructive call;
   - during state pull/write: final absent; remove only the still-proven owned
     partial candidate;
   - after candidate validation but before publication: final absent; clean the
     proven candidate unless publication uncertainty has begun;
   - during/after hard-link publication: never guess which name won; retain and
     report every uncertain name unless handle identity proves the exact safe
     cleanup;
   - before push/rm child start: destructive call count zero;
   - while or after push/rm child start: mutation outcome is `unknown`;
     retain the pre-operation backup/evidence, never retry, force, unlock,
     delete evidence, or auto-rollback, and require incident/manual remote-state
     verification before another operation.
5. The signal status remains 129/130/143 when it is the primary failure,
   including cleanup failure. If a nonzero primary failure was already fixed
   before the signal handler ran, preserve that earlier primary status and
   record the later signal separately. A zero native child exit does not turn
   an observed signal/unknown mutation phase into success.
6. Assign one stable ID/result to every combination of:
   T4 block (`SM-BACKUP-PULL`, `SM-LOCAL-CORRUPTION`, `SM-STATE-PUSH`,
   `SM-STATE-RM`), applicable ownership/mutation phase, HUP/INT/TERM, and
   cleanup success/failure. Use synchronized stub barriers so the signal lands
   in the named phase; never infer phase from timing sleeps.
7. Each result records signal, expected/actual status, phase, cleanup call
   count, exact path states, destructive child start/call count, remote
   mutation sentinel, retained-backup state, and safe diagnostics. Assert no
   state bytes, proposed-state values, backend secrets, or confirmation record
   enters evidence.
8. Run the new signal cases in the permanent callable workflow on the same Bash
   host as all T2 `SR-*` cases. Acceptance requires all prior T2 signal IDs
   unchanged/green and all T4 IDs exactly once; a skip, missing result, grouped
   signal family, or platform timeout is not pass.

**Status: selected and ready for incorporation into T4.**

All 34 open findings have now been evaluated in required order. The selected
resolutions below are ready to be incorporated into the six Terraform issue
drafts.
