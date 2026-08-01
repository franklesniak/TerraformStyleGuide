# Decision 0002: Accept repository-controlled code running in the write-enabled job

## Status

Accepted on 2026-08-01 by Frank Lesniak, TerraformStyleGuide repository owner.

Revised on 2026-08-01 after automated review found a bypass in the control this record
described as closed, and found the stated precondition overstated. Sections 2, 4, 5, 6 and 8
were rewritten and `build.yml` was hardened. The decision is unchanged. See section 9.

This records a deliberate, dated acceptance of a known security limitation. It is not a
statement that the limitation does not exist, and it is not a to-do item. If any of the
review triggers in the last section fire, this decision must be reopened.

This decision carries an obligation on issue #22 that the other accepted limitation in this
directory does not. Section 6 explains why, and section 7 states the required action.

## 1. The concern, and whether it is real

The `temporary-writer` job in `.github/workflows/build.yml` is the only job in this
repository holding `contents: write`. Within it, two things happen in order:

1. `prepare-generated-commit` runs `Generate-StyleGuideArtifacts.ps1` — code from the
   repository — and creates the artifact commit.
2. `push-generated` receives `${{ github.token }}` through a step-level `env:` mapping and
   pushes to `refs/heads/main`.

The runner applies whatever an earlier step wrote to the file named by `$GITHUB_ENV` to
every later step, and it does so **before launching that step's shell**. .NET reads
variables such as `DOTNET_STARTUP_HOOKS` during runtime initialisation. A startup hook
therefore executes inside the `pwsh` process that holds the push token, strictly before the
first line of `push-generated` runs.

The consequence is that the first two statements of that step cannot protect anything:

```powershell
$strToken = $env:STYLE_GUIDE_PUSH_TOKEN
Remove-Item Env:STYLE_GUIDE_PUSH_TOKEN -ErrorAction SilentlyContinue
```

The hook is already running in the same process by the time they execute.

The concern was raised by an automated reviewer during the review of pull request #26 and
is real. It invalidates the premise behind a series of containment measures added earlier
in that review — pinning the Git executable, clearing the child environment, authoring
`.git/config`, and restricting transports all assume the step's own process starts clean.

## 2. What an attacker actually gains, and what they do not

| Capability | Available? |
| --- | --- |
| Reach this job from a pull request | **No.** The job is gated on `github.event_name == 'push' && github.ref == 'refs/heads/main'`. It never runs on a pull request, from a fork or otherwise. |
| Reach this job without a merge | **Partly.** The generator must be on `main`, but nothing in this workflow requires it to have arrived there by a reviewed pull request. See below. |
| Capture the push token once the precondition holds | **Yes. This is the actual exposure.** |
| Push arbitrary content to this repository | Yes, with a captured token, for the token's lifetime. |
| Reach another repository | No. The job token is scoped to this repository. |
| Read repository secrets | No. The workflow consumes none. |

The precondition is the whole of the mitigation, so it must be stated exactly. An earlier
version of this record claimed the hostile generator must "survive review and land on
`main`." That overstates it. The writer fires on `github.event_name == 'push' && github.ref
== 'refs/heads/main'`, and a direct push to `main` satisfies that condition without any
pull request, review, or merge. What the workflow actually proves is that the generator is
**on `main`** — not that anyone looked at it.

Review is therefore a compensating control supplied by repository configuration, not by
this workflow, and at the time of writing no branch ruleset requiring pull requests is in
force: that task is separately authorized and sequenced before issue #22. Until it lands,
the honest precondition is "the owner pushed or merged a hostile generator to `main`,"
which for a single-maintainer repository means the residual is bounded by the owner's own
discipline rather than by an enforced gate.

Every containment measure on this job exists precisely for that case, which is why the
finding matters even though the precondition is demanding.

### What is hardened, and what is not

An earlier version of this record claimed the `$GITHUB_ENV` and `$GITHUB_PATH` channel was
**closed**. It is not. It is hardened, and the difference is material enough that the
original wording was a false assurance.

At the end of the generator step both files are asserted empty:

```powershell
$arrChannelPaths = @($env:GITHUB_ENV, $env:GITHUB_PATH)   # captured before the generator runs

foreach ($strChannel in $arrChannelPaths) {
    if ([string]::IsNullOrEmpty($strChannel)) { throw 'runner-state: a step communication file path is unset' }
    if ([System.IO.FileInfo]::new($strChannel).Length -ne 0) {
        throw 'runner-state: the generator wrote to a runner step communication file'
    }
}
```

Emptiness is asserted rather than the absence of particular variable names. Naming
`DOTNET_STARTUP_HOOKS`, `LD_PRELOAD`, `NODE_OPTIONS`, and `PSModulePath` would be a list to
outgrow, and three separate findings in this review were caused by exactly that shape of
reasoning. The check runs before the step's early return, so it holds on both paths, and a
failure fails the step, so `push-generated` never starts.

Two bypasses were identified in review and are now closed:

- **Command shadowing.** The check originally called `Get-Item`. PowerShell resolves
  functions ahead of cmdlets, and the generator runs in this same session, so a hostile
  generator could declare `function global:Get-Item` returning an object whose `Length` is
  `0` and walk straight past the assertion it is meant to trip. The check now uses the
  fully qualified type literal `[System.IO.FileInfo]`, which is not a command and cannot be
  shadowed by a function, and whose qualified name cannot be captured by a PowerShell class
  the generator declares.
- **Path redirection.** The channel paths are now captured *before* the generator runs. The
  generator can reassign `$env:GITHUB_ENV` in-process while the runner still reads the path
  it originally exported, so resolving the paths afterwards would have pointed the assertion
  at a file the generator never wrote while its real write stood.

Two classes remain open, and they are the substance of what is accepted here:

- **Deferred writes.** The assertion is a point-in-time check. A generator that registers an
  engine event, a `finally` block, or a background job can write to the channel file after
  the assertion has passed and before the runner reads it. Closing this requires an
  isolation boundary — a separate job, whose runner has none of this job's state — not a
  better check inside the same step.
- **State the generator leaves on disk.** The clearest example is PowerShell profiles: the
  runner's default for `shell: pwsh` carries no `-NoProfile`, so a profile written by the
  generator executes at the start of the push step for the same reason a startup hook would.
  That example is nameable; the class is not reliably enumerable, which is the reason this
  record exists rather than a fourth targeted check.

## 3. Options considered

- **A. Accept and document only.** Record the residual; change nothing further.
- **B. Accept, document, and require issue #22 to close it** by an explicit acceptance
  criterion, because #22 as currently written does not.
- **C. Split the writer into two jobs now.** Regenerate in one job; push in a second that
  consumes the uploaded artifact and never invokes the generator.
- **D. Add `-NoProfile` through a custom `shell:` string.**
- **E. Assert the runner communication files are empty, hardened against shadowing and path
  redirection** (already implemented; listed here so it can be scored against the
  alternatives).
- **F. Move the token from a step-level `env:` mapping to a job-level one.**

### How the perspectives differed

| Perspective | Position |
| --- | --- |
| Senior engineer | C is the correct shape. A job boundary is the only mechanism that is not an enumeration, because a fresh job is a fresh runner with none of the previous job's disk state. |
| New contributor | C also *simplifies*: the generator would stop running in a write-enabled job at all, which retires the premise behind most of this review's findings. |
| DevOps | C adds a job, an `actions/download-artifact` dependency, and makes the `verify` artifact load-bearing for promotion. None of it is testable in the review environment. |
| Documentation | The residual must be written down wherever the *next* implementer will look, which is issue #22, not only this repository. |
| Project management | The writer is deleted by #22. Rebuilding it now duplicates work that #22 must do properly anyway. |
| Security executive | Accepting is defensible; accepting *silently* is not. The acceptance must carry a forward obligation. |
| Security engineer | F is worse than useless: a job-level mapping exposes the token to the generator step directly. D closes one named example and nothing else. |
| Business stakeholder | The precondition is a malicious generator on `main` in a single-maintainer repository. Real, but not urgent enough to justify untested structural change. |

## 4. Evaluation rubric

Weights deliberately place technical correctness above effort. Churn, difficulty, and
scope adherence are weighted at half the value of the correctness and safety criteria.

| Criterion | Weight | What a 5 means |
| --- | --- | --- |
| Closes the environment channel | 1.0 | An earlier step cannot influence the token-bearing process through the runner. |
| Closes on-disk state | 1.0 | An earlier step cannot influence it through the filesystem either. |
| Completeness | 1.0 | Not an enumeration that a new interpreter feature can outgrow. |
| Avoids introducing a new vulnerability | 1.0 | No new attack surface created by the fix. |
| Verifiable before merge | 1.0 | Can be tested in the review environment rather than argued. |
| Survives into the successor design | 1.0 | The protection is not lost when #22 replaces this job. |
| Auditability | 1.0 | The residual and its owner are visible in the record. |
| Amount of churn | 0.5 | Few files touched. |
| Difficulty to implement | 0.5 | Little work, little expertise required. |
| Adherence to issue #20 scope | 0.5 | Does not disturb the authorized implementation paths. |

Seven criteria are weighted 1.0 and three are weighted 0.5, so the weights sum to 8.5 and
the maximum attainable weighted score is **42.5**.

## 5. Scoring

| Criterion | A | B | C | D | E | F |
| --- | --- | --- | --- | --- | --- | --- |
| Closes the environment channel | 1 | 4 | 5 | 1 | 4 | 1 |
| Closes on-disk state | 1 | 4 | 5 | 2 | 1 | 1 |
| Completeness | 1 | 4 | 5 | 1 | 3 | 1 |
| Avoids new vulnerability | 5 | 5 | 3 | 4 | 5 | 1 |
| Verifiable before merge | 5 | 5 | 1 | 3 | 4 | 3 |
| Survives into successor design | 1 | 5 | 2 | 1 | 2 | 1 |
| Auditability | 3 | 5 | 3 | 2 | 3 | 2 |
| Amount of churn | 5 | 5 | 1 | 4 | 5 | 5 |
| Difficulty to implement | 5 | 5 | 1 | 4 | 5 | 5 |
| Adherence to #20 scope | 5 | 4 | 2 | 3 | 5 | 4 |
| **Weighted total** | **24.5** | **39.0** | **26.0** | **19.5** | **29.5** | **17.0** |
| **Percentage** | **57.6** | **91.8** | **61.2** | **45.9** | **69.4** | **40.0** |

Options B and E score 4 rather than 5 on *closes the environment channel* because the
hardened assertion is still a point-in-time check: it defeats shadowing and path
redirection, but not a write deferred past it. Only C, which puts a runner boundary between
the generator and the token, earns a 5.

Option F is disqualified on its merits regardless of score: moving the token to a job-level
`env:` would expose it to the generator step itself, which is strictly worse than the
problem being solved.

Option C scores lower than its technical merit because of two full-weight criteria it
fails: it cannot be verified before merge in an environment with no PowerShell, and — on its
own — it does not survive into the successor design, since #22 would still be free to
reintroduce the arrangement.

## 6. Decision

**Option B is selected: accept the residual, document it here, and place an explicit
obligation on issue #22.**

The obligation is not bookkeeping. Issue #22 was written before this risk was identified,
and its writer job **reproduces the arrangement**. From its section 7, the writer:

```text
3. runs the exact permanent helper harness;
...
8. runs the generator from the expected commit in a separate controlled location and
   proves byte equality with the extracted candidate;
```

and from its section 9:

> Bind `github.token` as a masked environment secret only on the exact push step.

That is the same shape as the current job: repository-controlled code first, step-level
token binding second. Running the generator in the writer is a deliberate anti-tampering
control in #22's design, and a good one — but it reintroduces this exposure. Without an
explicit criterion, deferring this residual to #22 would not close it; it would transfer it.

The compensating controls recorded as the basis for acceptance are:

1. The job is unreachable from a pull request. It runs only on `push` to `refs/heads/main`.
2. The precondition is a malicious generator on `main`. Note that this is *not* the same as
   "reviewed and merged": absent a branch ruleset requiring pull requests, a direct push
   satisfies the trigger. Until the separately authorized ruleset task lands, this control
   rests on owner discipline rather than on an enforced gate.
3. The `$GITHUB_ENV` and `$GITHUB_PATH` channel is hardened — not closed — by an emptiness
   assertion that resists command shadowing and path redirection, and `T1-BUILD-072`
   prevents that check from being removed silently. Deferred writes remain possible.
4. The job token is scoped to this repository and the workflow consumes no secrets.
5. Issue #22 deletes this job entirely, and now carries an acceptance criterion requiring
   the successor not to reproduce the arrangement.

## 7. What to do about it, step by step

No repository setting change is required. One issue amendment is required, and it is the
substance of this decision rather than an administrative step.

1. Add the following acceptance criterion to issue #22:

   > - [ ] No repository-controlled code — generator, helper, harness, or hook — executes
   >   in the same job as the `contents: write` token. The regeneration and revalidation
   >   the writer performs today occur in a separate job whose result the writer consumes,
   >   or the writer is otherwise proven to start from state no earlier repository-controlled
   >   step can influence, including `$GITHUB_ENV`, `$GITHUB_PATH`, and on-disk state such
   >   as shell profiles.

2. Reconcile #22 section 7 with that criterion. Steps 3 and 8 currently place the harness
   and generator inside the writer job; they must move, or the writer must be split.
3. Update this record's Status section to **Superseded by #22** when that lands, naming the
   landed commit. Do not delete the record.

## 8. When this decision must be revisited

Reopen this decision if any of the following becomes true.

- Issue #22 is closed, deferred, or rescoped without the acceptance criterion in section 7
  being satisfied.
- The `temporary-writer` job stops being temporary.
- The writer job gains any additional repository-controlled execution, which widens the
  window this decision accepts.
- The writer job becomes reachable from any event other than `push` to `refs/heads/main`.
- The workflow gains a secret, a deployment credential, or a token scoped beyond this
  repository, all of which change the blast radius in section 2.
- The repository gains contributors other than the owner, which weakens compensating
  control 2.
- A branch ruleset requiring reviewed pull requests to `main` is adopted — or, having been
  adopted, is later relaxed. Compensating control 2 is currently unenforced, and this record
  should be re-read the moment that changes in either direction.
- A mechanism is found by which repository-controlled code influences the token-bearing
  process *despite* the hardened assertion, beyond the deferred-write and on-disk classes
  already named in section 2. Two such mechanisms were found during review and are recorded
  there; a third would suggest the enumeration is not converging and that option C should be
  reconsidered on its merits.

## 9. Revision history

- **2026-08-01, initial.** Stated that the `$GITHUB_ENV` / `$GITHUB_PATH` channel was
  *closed* by an emptiness assertion, and that the precondition for exploitation was a
  hostile generator that had "survived review and landed on `main`." Scored six options
  against a rubric whose stated maximum (36.5) did not match its own weights.
- **2026-08-01, revised.** Automated review established two bypasses of the assertion — a
  generator-declared `global:Get-Item` shadowing the cmdlet, and in-process reassignment of
  `$env:GITHUB_ENV` redirecting the check — and established that a direct push to `main`
  satisfies the writer's trigger with no review at all. `build.yml` was hardened against
  both bypasses; the record now says *hardened*, not *closed*, and names deferred writes as
  a third class it does not close. The precondition was restated as "on `main`" with the
  absence of an enforcing ruleset called out. The rubric arithmetic was recomputed from the
  published weights, and options B and E were rescored down on the environment-channel
  criterion to reflect that a point-in-time check cannot earn full marks. Option B remains
  selected.

## References

Each source was retrieved and confirmed to resolve on 2026-08-01 rather than cited from
memory.

1. [Workflow commands: setting an environment variable](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#setting-an-environment-variable)
   — establishes that values written to `$GITHUB_ENV` are applied to subsequent steps, which
   is the mechanism this decision accepts.
2. [Workflow commands: adding a system path](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#adding-a-system-path)
   — the companion `$GITHUB_PATH` channel, covered by the same assertion.
3. [.NET host startup hook](https://github.com/dotnet/runtime/blob/main/docs/design/features/host-startup-hook.md)
   — confirms that `DOTNET_STARTUP_HOOKS` is processed during runtime initialisation, before
   managed entry-point code runs.
4. [Workflow syntax: `jobs.<job_id>.permissions`](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions#permissions)
   — the job-scoped `contents: write` grant that defines the exposure.
5. [GITHUB_TOKEN reference](https://docs.github.com/en/actions/concepts/security/github_token)
   — confirms the job token is scoped to the repository that runs the workflow.
6. [about_Profiles](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles)
   — PowerShell profile loading at session start, the clearest remaining on-disk vector.
7. [about_Command_Precedence](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_command_precedence)
   — establishes that PowerShell resolves aliases and functions ahead of cmdlets, which is
   why the original `Get-Item` call could be shadowed by the generator and why the check now
   uses a fully qualified type literal.
