# Findings on the TerraformStyleGuide T1/T2 issue slate

## Scope and review basis

This review treats
[T1](../TerraformStyleGuide/03TerraformStyleGuideT1.md) and
[T2](../TerraformStyleGuide/04TerraformStyleGuideT2.md) as the critique targets
and assumes that they are implemented sequentially, T1 before T2. The
PSStyleGuide [P1](../PSStyleGuide/01PSStyleGuideP1.md),
[P2](../PSStyleGuide/02PSStyleGuideP2.md), and
[P3](../PSStyleGuide/03PSStyleGuideP3.md) drafts were used only to understand
the intended cross-repository coordination. They are not independently
re-reviewed here.

Each recommendation in the supplied
[PSStyleGuide slate criticism](../PSStyleGuide/slate-criticism.md) is evaluated
below before drawing conclusions about T1 and T2. “Confirmed” means that the
recommendation accurately identifies a problem in the PS draft it discusses.
It does not mean that the same change should be copied into TerraformStyleGuide.

The review also checked the current TerraformStyleGuide implementation,
including:

- `.github/workflows/package.json` and its lockfile;
- `.github/workflows/markdownlint.yml`;
- `.husky/pre-commit`;
- the tracked Markdown samples;
- the generator and workflow surfaces named by T1; and
- a fresh `npm audit --package-lock-only --json` result on 2026-07-29.

## Overall assessment

T1 and T2 are unusually thorough and are substantially ready to file. The
security-sensitive corrections previously made to archive handling, cleanup,
PowerShell process identity, link coverage, KMS reconciliation, HCP token
handling, and S3 versioning should be preserved.

I found one material omission in T1's treatment of the stated
cross-repository-generator objective, two related gaps in the contract for the
separate Terraform npm-remediation issue, and one low-risk stale example in T2:

1. T1 coordinates the archive helper across repositories but does not define an
   equally explicit generator-convergence contract.
2. T1's linked npm-remediation contract omits a now-known Node runtime-policy
   decision and the files that decision may need to change.
3. The same contract does not require enough executable evidence or explain
   precisely how the later npm issue supersedes T1/T2's intermediate
   governance and changed-path gates.
4. T2 contains an already-stale illustrative version/date snapshot that should
   be removed while retaining the normative recalculation procedure.

None of these findings calls for merging the two repositories, importing code
at runtime from one repository into the other, or expanding T1/T2 themselves
into a dependency upgrade. The npm work should remain a separately reviewable
issue.

## Current-state anchors

The following facts control the recommendations:

- T1 already requires one held ZIP stream, `Get-FileHash -InputStream`, rewind,
  one `ZipArchive`, and deterministic disposal. The criticism's old description
  of T1 as using a weaker archive sequence is no longer true.
- T1 already requires an exact ownership journal, one named production cleanup
  function, a full pre-delete validation pass, and direct deterministic testing
  of that exact cleanup function.
- T1 already requires same-child assertions for Windows PowerShell 5.1 and
  PowerShell 7, real link/reparse coverage on Ubuntu and Windows, and the
  helper harness in all four Windows pull-request cells.
- T1's only explicit cross-repository design paragraph governs the archive
  helper and harness. Its generator sections specify correct serialization
  behavior but do not record which generator algorithms must converge with P1
  and which differences are intentional.
- TerraformStyleGuide currently installs `markdownlint-cli2@0.20.0` and
  `markdownlint@0.40.0`, both on a Node 20-compatible baseline. Its Markdown
  workflow explicitly selects Node 20.
- The currently proposed `markdownlint-cli2@0.23.2` upgrade requires Node
  `>=22`; its bundled `markdownlint@0.41.1` also requires Node `>=22`.
- TerraformStyleGuide's `.husky/pre-commit` checks for `npm` and the installed
  CLI but does not enforce a Node major. Unlike PSStyleGuide's staged script,
  it invokes the repository's full outer and nested npm lint commands rather
  than the `markdownlint-cli2` programmatic `main` API.
- TerraformStyleGuide has positive outer/nested Markdown samples but no tracked
  `samples/test-violations-recursive.md` negative fixture.
- A fresh TerraformStyleGuide audit on 2026-07-29 still reports seven affected
  package nodes: five high severity and two moderate severity. T1 records the
  same dated node/severity baseline accurately.
- T2 correctly treats T1 as its prerequisite and already carries forward T1's
  finalized held-stream, cleanup, PowerShell-identity, and link-coverage
  contracts.

## Recommendation-by-recommendation audit

### P1 recommendation 1: rebaseline the convergence matrix against final T1

**Decision: Confirmed.**

The criticism correctly observes that final T1 now uses the same-held-stream
archive sequence and the same narrow definition-only access to the production
cleanup function. Any P1 matrix that calls those P1-only strengths is stale.

**Effect on T1/T2:** Do not change T1's archive or cleanup design. T1 should,
however, require a reciprocal implementation-start comparison so the repository
implemented second records new shared invariants and intentional differences.
That check should extend to the generator, not only the archive helper.

### P1 recommendation 2: add a generator-specific convergence contract

**Decision: Confirmed and directly relevant to T1.**

The helper/workflow convergence material does not fully address the stated goal
of thoughtfully unifying the generator scripts. A generator-specific matrix is
the clearest way to distinguish shared algorithms from repository-specific
content.

**Effect on T1/T2:** This is the basis of finding T1-1 below. T1 should contain
the reciprocal contract. It should not make either repository a runtime or
release-order dependency of the other.

### P1 recommendation 3: make cleanup safety deterministic and test production cleanup

**Decision: Confirmed for the P1 text being discussed.**

The requested exact ownership journal, one named cleanup function, exhaustive
pre-delete proof, fail-closed retention, and deterministic ordinary-extra-entry
fixture are defensible controls. A copied cleanup implementation would not test
the production behavior.

**Effect on T1/T2:** Already satisfied. T1 contains the stronger contract and
T2's prerequisite summary accurately carries it forward. Preserve it; no new
Terraform issue change is required.

### P1 recommendation 4: verify local PowerShell identity inside each child

**Decision: Confirmed for P1.**

Resolving an executable name in a parent process is weaker evidence than
asserting `$PSVersionTable` in the same child that runs the target.

**Effect on T1/T2:** Already satisfied. T1 requires fixed `-Command`
same-process assertions for Desktop exactly 5.1 and Core major 7, and T2 cites
that invariant. Preserve it.

### P1 recommendation 5: close the link-fixture coverage loophole

**Decision: Confirmed for P1.**

A suite that permits every link/reparse case on an operating-system family to
skip does not prove the rejection behavior on that family.

**Effect on T1/T2:** Already satisfied. T1 requires at least one real
link/reparse rejection on Ubuntu and Windows and forbids a platform-wide skip
from counting as coverage. T2 preserves the requirement.

### P1 recommendation 6: align pull-request harness placement or document the difference

**Decision: Partially confirmed; this is a clarity choice, not a correctness defect.**

Running a helper suite once per PowerShell edition can be sufficient when
helper behavior is independent of fixture EOL. Running it in all four
edition-by-EOL cells supplies stronger and simpler evidence at additional CI
cost. Either policy can be technically defensible if the matrix states why.

**Effect on T1/T2:** T1 deliberately uses the stronger all-four-cells policy
and T2 records it. Do not weaken T1 merely for textual symmetry with P1.

### P2 recommendation 1: refresh the prerequisite snapshot

**Decision: Confirmed for P2.**

A sequential issue should describe the final prerequisite rather than an older
draft.

**Effect on T1/T2:** T2 already reflects T1's final held-stream, cleanup,
same-child identity, and link-coverage contracts. No update is needed for those
items. T2's linked-npm prerequisite should be refreshed only to reflect the
expanded contract in findings T1/T2-2 and T1/T2-3.

### P2 recommendation 2: assert Node 24 before local npm validation

**Decision: Confirmed for P2, but not directly transferable to T2.**

If P1 establishes Node 24 as PSStyleGuide's supported validation runtime, a P2
local block that silently uses any `node` on `PATH` cannot be claimed as Node
24 evidence.

**Effect on T1/T2:** T1 and T2 intentionally preserve TerraformStyleGuide's
current npm toolchain and do not claim that their local lint evidence runs under
Node 24. Adding a Node assertion to T2 alone would be an unexplained policy
change. The separate Terraform npm-remediation issue must instead select and
validate a coherent Node floor as described in finding T1/T2-2.

### P2 recommendation 3: remove the stale metadata snapshot

**Decision: Confirmed as a nonblocking editorial recommendation.**

A labeled example can still be copied after it becomes stale; the normative
algorithm is safer and sufficient.

**Effect on T1/T2:** The same defect exists in T2, which names an implementation
date of 2026-07-28 and resulting version `2.7.20260728.0`. See finding T2-1.

### P3 recommendation 1: resolve the Node-engine and staged-hook mismatch

**Decision: Confirmed.**

Installing dependencies that require Node `>=22` while repository guards admit
Node 20 creates an internally inconsistent supported-runtime contract.

**Effect on T1/T2:** The exact PSStyleGuide file set must not be copied because
the Terraform hook architecture differs. Nevertheless, T1's separate npm issue
contract must require a deliberate Terraform Node policy and include every
Terraform file affected by that decision. See finding T1/T2-2.

### P3 recommendation 2: exercise the staged-lint programmatic API

**Decision: Confirmed for PSStyleGuide; denied as a literal Terraform requirement.**

PSStyleGuide's script dynamically imports `markdownlint-cli2`, calls `main`,
and passes `nonFileContents`; ordinary npm lint does not exercise that surface.
TerraformStyleGuide has no equivalent programmatic staged-lint script. Its hook
runs full outer and nested lint commands.

**Effect on T1/T2:** The transferable principle is to test the integration that
contributors actually execute. The Terraform npm issue should test
`.husky/pre-commit` under the selected Node policy, including success,
lint-failure, and tooling/startup-failure classification. It should not invent a
`nonFileContents` test for code TerraformStyleGuide does not have.

### P3 recommendation 3: replace the nonexistent negative-fixture claim

**Decision: Confirmed.**

The named negative fixture does not exist in PSStyleGuide. The same filename is
also absent from TerraformStyleGuide, whose tracked samples are positive.
Expected-failure validation must use a real tracked fixture or create and remove
a deterministic temporary fixture.

**Effect on T1/T2:** T1's separate npm issue should explicitly choose tracked
or ephemeral outer and nested negative fixtures, distinguish lint exit 1 from
tool startup failure, and verify expected rule/file/depth diagnostics. See
finding T1/T2-3.

### P3 recommendation 4: define supersession of P1's intermediate governance gates

**Decision: Confirmed.**

An issue that adds an npm Dependabot entry cannot also leave an exact-one-entry
GitHub Actions-only assertion literally green. Likewise, a later issue cannot
satisfy an earlier implementation-time changed-path set after deliberately
changing other files.

**Effect on T1/T2:** The same issue exists in the proposed Terraform sequence.
The later npm issue needs an explicit supersession and rebaseline contract; it
must preserve nonsuperseded behavior rather than promise that every earlier
one-time scope assertion remains true. See finding T1/T2-3.

### P3 recommendation 5: structure residual-advisory dispositions

**Decision: Confirmed.**

An array of advisory URLs cannot mechanically prove owner, dependency path,
expiration, follow-up issue, uniqueness, or nonexpiration. Claims about those
fields require structured records and corresponding validation, or the issue
must accurately label the checks as manual.

**Effect on T1/T2:** T1 currently asks only for a “documented disposition.”
The linked Terraform npm issue should define the required record shape and
durable evidence. See finding T1/T2-3.

### P3 recommendation 6: retain the dated baseline but treat URLs as dynamic

**Decision: Confirmed.**

The seven-node severity baseline is a useful dated comparison, not a frozen
implementation oracle. A package node can carry more than one advisory, and
the registry's current result controls remediation.

**Effect on T1/T2:** Keep T1's accurate 2026-07-29 node/severity snapshot, but
make the linked issue capture every current advisory URL and dependency path at
implementation time. See finding T1/T2-3.

### Cross-slate coordination and order

**Decision: Confirmed, including the security-policy exception.**

T1 then T2 then a separate npm issue is coherent when repository policy permits
the dated advisory baseline to remain temporarily. If policy requires immediate
high-severity remediation, the npm issue must move first and both T1 and T2 must
be rebaselined after it merges. The repositories should coordinate algorithms
and evidence without a cross-repository runtime dependency.

## Findings and recommended corrections

### T1-1 — Add a reciprocal generator-convergence contract

**Severity: Medium — material planning omission, not an implementation defect.**

#### Evidence

T1 precisely defines its four serialization boundaries and briefly coordinates
the new archive helper/harness with PSStyleGuide. It does not say, in one
auditable place, which generator behaviors are intended to be the same in both
repositories. This makes it possible for two individually correct
implementations to diverge unnecessarily in helper shape, newline handling,
failure behavior, or validation.

#### Recommended correction

Add a generator-specific convergence matrix to T1, adjacent to the generator
changes or cross-repository coordination text. At minimum, it should state:

| Area | Shared target | Intentional difference |
| --- | --- | --- |
| Final serialization | Normalize the complete final payload with ``-replace "`r`n?", "`n"`` immediately before encoding; resolve the destination; use `UTF8Encoding($false)` and `WriteAllText`; add no implicit newline. | Payload variable names may differ. |
| Common artifacts | Keep equivalent Copilot, Chat, and Full artifact behavior and failure semantics. | Guide-specific Full transformations may differ. |
| Instructions artifact | Use the same serialization primitive and frontmatter-construction principles. | Function name, filename, `applyTo`, and description are guide-specific. |
| Frontmatter | Use an explicitly reviewed LF-joined array with exact spacing and final-LF checks. | T1 already has this representation; P1 migrates a here-string. |
| Abstraction level | If a private serialization helper is introduced, coordinate the same contract in both issues; otherwise both may keep equivalent inline boundaries. | Internal names need not match. |
| Script policy | Preserve `#Requires -Version 5.1` and the same `.NOTES` version-calculation policy. | Starting versions may differ. |
| Text policy | Treat producer correctness and LF checkout policy as complementary. | T1 adds `.gitattributes`; PSStyleGuide already has it. |
| Validation | Prove Desktop 5.1/Core 7 and LF/CRLF producer equivalence with raw-byte assertions. | Repository-specific artifact names and separately governed Node work remain explicit. |

Define “unified” as shared algorithms, invariants, and failure semantics—not
line-for-line identity. Require whichever implementation starts second to
reread the merged/current first issue and its evidence, then record any
remaining intentional difference before coding.

#### Completion test

A developer coming in cold should be able to classify every generator
difference as either required repository content or an explicitly accepted
design difference. T1 must remain independently implementable if P1 is delayed
or changed.

### T1/T2-2 — Expand the linked npm issue's runtime-policy and affected-file contract

**Severity: High — known compatibility and contributor-tooling risk.**

#### Evidence

T1 says the later issue owns dependency/lockfile changes, optional npm
Dependabot configuration, audit disposition, `npm ci`, and two lint commands.
It explicitly excludes Node changes from T1, which is correct, but it does not
require the later issue to own them.

That omission is no longer hypothetical. The current Terraform workflow uses
Node 20, while the named current upgrade line for
`markdownlint-cli2@0.23.2`/`markdownlint@0.41.1` requires Node `>=22`. The
Terraform pre-commit hook admits any environment with `npm` and the installed
CLI. Updating only `package.json` and `package-lock.json` could therefore leave
CI or contributors running an unsupported dependency tree.

#### Recommended correction

Keep the upgrade out of T1/T2, but expand the real linked issue's ownership
contract so it must:

1. Re-run package metadata, changelog, lockfile, `npm audit`, and repository
   usage discovery before choosing versions.
2. Select one coherent Node policy. Node 22 is the present package minimum;
   Node 24 is also defensible if the maintainer deliberately wants alignment
   with PSStyleGuide. Do not infer a project Node policy from the internal
   runtime used by a GitHub Action.
3. Update every file required by that choice, including at least
   `.github/workflows/package.json`, its lockfile,
   `.github/workflows/markdownlint.yml`, and `.husky/pre-commit` when their
   current contracts would otherwise disagree.
4. Add a matching `engines.node` declaration and use consistent version checks
   and messages in CI/local hook surfaces.
5. Prove the selected minimum and any separately claimed hosted baseline on
   Windows and Linux where the hook/workflow contract applies.
6. Recompute the exact affected-file set from the selected design rather than
   freezing the current two- or three-file guess.

T2's prerequisite should refer to this complete linked-issue contract. If the
npm issue runs before T1 for security-policy reasons, T1 and T2 must be
rebaselined against the merged Node/package state.

#### Completion test

No supported or explicitly admitted Node version may install or invoke a
dependency tree whose declared engine excludes that version. CI, package
metadata, and contributor-hook messaging must describe one deliberate policy.

### T1/T2-3 — Make the linked npm issue's evidence and supersession rules executable

**Severity: High — remediation could appear complete without testing the real integration or final governance state.**

#### Evidence

`npm ci` plus the two ordinary lint commands is necessary but incomplete:

- it does not prove the actual pre-commit hook's status classification;
- there is no existing tracked negative fixture matching the common stale
  filename;
- an expected lint failure can be confused with a tooling/import failure;
- “documented disposition” does not define mechanically verifiable residual
  approval records;
- a node-count snapshot does not enumerate all current advisory URLs and
  dependency paths; and
- adding an npm Dependabot entry intentionally invalidates T1's exact
  GitHub-Actions-only Dependabot assertion and earlier implementation-time
  changed-path sets.

#### Recommended correction

Expand the linked issue so a new implementer is required to:

1. Test the actual Terraform `.husky/pre-commit` integration, not
   PSStyleGuide's unrelated programmatic API. Cover no staged Markdown,
   compliant Markdown, a real Markdown violation, and a tooling/startup
   failure; require the intended exit classification and diagnostic.
2. Use either reviewed tracked negative fixtures or deterministic temporary
   outer and nested fixtures removed in `finally`. Prove the exact expected
   rule, file, and nested depth/context, and distinguish lint exit 1 from
   startup/configuration exit 2 or another unexpected failure.
3. Preserve positive outer and nested sample coverage.
4. Capture every current moderate/high/critical advisory URL and affected
   dependency path at implementation time. Keep T1's seven-node result only as
   a dated comparison baseline.
5. Require each accepted residual advisory to have a structured record:
   advisory URL, dependency path, named owner, invariant UTC expiration date,
   and real follow-up issue URL. Reject duplicates, blanks, expired records,
   mismatched sets, and approvals left after the audit becomes clean. If any
   field is reviewed manually, say so instead of claiming the script proves it.
6. Store the residual disposition in durable issue or pull-request evidence.
7. If npm Dependabot is selected, validate the final normalized configuration
   as exactly the intended weekly, review-only `github-actions` entry for `/`
   and npm entry for `/.github/workflows`, with no duplicates, extra
   ecosystems/directories, auto-approval, or auto-merge.
8. State that the later issue supersedes T1's exact-one-Dependabot-entry check
   and its T1/T2 implementation-time changed-path assertions. Require all
   nonsuperseded generator, helper, workflow, permission, action-pin,
   artifact, and Markdown behavior to remain green.

The linked issue may split runtime-policy work into a real prerequisite if the
maintainer wants separate review, but it must not knowingly install packages
whose engines exceed the admitted runtime while leaving the mismatch for an
unlinked future task.

#### Completion test

The final evidence must prove the selected dependency tree, real Terraform hook
integration, positive and negative lint behavior, complete current advisory
disposition, and exact final update-governance state. Earlier one-time scope
checks must be identified as superseded rather than inaccurately reported as
still green.

### T2-1 — Remove the stale illustrative version/date snapshot

**Severity: Low — copy-safety and editorial clarity.**

#### Evidence

T2 correctly requires rereading the current version, incrementing Minor, using
the UTC implementation date, resetting Revision, and updating metadata. It then
adds a conditional example based on implementation occurring on 2026-07-28:

```text
2.7.20260728.0
```

That date is already past. “Otherwise recompute” prevents the example from
being normative, but it does not prevent a hurried implementer from copying it.

#### Recommended correction

Delete the conditional dated example and the “Otherwise recompute” sentence.
Retain the six-step normative algorithm. If an example is considered necessary,
use symbolic components rather than a date that begins aging immediately.

#### Completion test

The issue contains one unambiguous version-calculation procedure and no literal
candidate version that can become stale before implementation.

## Strengths and no-change conclusions

The following should remain unchanged while applying the findings:

- Keep each GitHub issue title as the H1 in its issue description and continue
  using T1/T2 terminology.
- Keep T1 before T2 under the normal sequence.
- Keep all four complete-payload serialization boundaries, resolved paths,
  BOM-less UTF-8, `WriteAllText`, and the repository-wide
  `* text=auto eol=lf` policy.
- Keep the same-held-stream digest/ZIP contract and all full-component path,
  manifest, exact ownership, and fail-closed cleanup protections.
- Keep the exact production helper/harness relationship and deterministic
  cleanup fixture.
- Keep same-child PowerShell edition/version assertions, real Ubuntu/Windows
  link coverage, the four-cell Windows topology, read-only approval, and sole
  exact-lease writer.
- Keep T1's current full-SHA action pins subject to implementation-time
  reverification and its review-only GitHub Actions Dependabot entry.
- Keep the dependency migration outside T1 and T2.
- Keep T2's corrected AWS KMS reconciliation, precise S3 versioning
  prerequisite, guarded provider identifiers, no-clobber destinations,
  restrictive permissions, GCS modernization, HCP `set +x`-first subshell and
  synthetic inherited-xtrace proof, and sensitive-state handling.
- Keep T2's seven-file T1 non-goal list and six-file T2 scope.
- Do not copy Terraform state-recovery content into PSStyleGuide documentation.
- Do not create a shared cross-repository runtime module or action in these
  issues. If desired later, design it as a separately versioned,
  immutably-consumed follow-up.

## Recommended disposition and execution order

Before filing T1:

1. Add the reciprocal generator-convergence matrix and second-implementation
   recheck from T1-1.
2. Expand the linked npm issue contract with T1/T2-2 and T1/T2-3, while keeping
   the upgrade itself out of T1.

Before filing T2:

1. Refresh its npm-prerequisite sentence to reference the expanded contract.
2. Remove the stale version/date snapshot.

Then retain the planned order:

1. T1;
2. T2; and
3. the real, linked Terraform npm-remediation issue.

If repository policy disallows carrying the five high-severity affected nodes
through T1/T2, use the already-described exception: implement the expanded npm
issue first, then rebaseline T1 and T2 against the merged dependency, Node,
hook, workflow, and Dependabot state.

## References

- [T1 issue draft](../TerraformStyleGuide/03TerraformStyleGuideT1.md)
- [T2 issue draft](../TerraformStyleGuide/04TerraformStyleGuideT2.md)
- [Supplied PSStyleGuide slate criticism](../PSStyleGuide/slate-criticism.md)
- [Local npm advisory research](research-npm-advisories.md)
- [`markdownlint-cli2` v0.23.2 package metadata](https://github.com/DavidAnson/markdownlint-cli2/blob/v0.23.2/package.json)
- [`markdownlint` v0.41.1 package metadata](https://github.com/DavidAnson/markdownlint/blob/v0.41.1/package.json)
- [`markdownlint-cli2` changelog](https://github.com/DavidAnson/markdownlint-cli2/blob/v0.23.2/CHANGELOG.md)
- [`markdownlint-cli2` v0.23.2 programmatic source](https://github.com/DavidAnson/markdownlint-cli2/blob/v0.23.2/markdownlint-cli2.mjs)
- [npm audit command documentation](https://docs.npmjs.com/cli/v11/commands/npm-audit/)
- [npm package `engines` documentation](https://docs.npmjs.com/cli/v11/configuring-npm/package-json#engines)
- [GitHub Dependabot version-update configuration](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference)
