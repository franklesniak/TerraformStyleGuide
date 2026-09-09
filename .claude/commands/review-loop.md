---
description: Run the automated dual-reviewer PR review loop (Copilot + Codex) to convergence
argument-hint: <pull-request-url>
---

<!-- markdownlint-disable MD013 -->
# PR review loop

## Metadata

- **Status:** Active
- **Owner:** TerraformStyleGuide Repository Maintainers
- **Last Updated:** 2026-09-09
- **Scope:** Defines the repository-local Claude command that runs the Copilot and Codex pull-request review loop.
- **Related:** [Claude agent instructions](../../CLAUDE.md)

Target pull request: **$ARGUMENTS**

If no pull request URL was supplied above, ask which one to work on before doing anything else.

## Setup

**The protocol is `CLAUDE.md` at the root of this repository.** Read it and follow it; it is
committed, reviewed, and changes only through a pull request here.

Do **not** fetch the protocol from a branch of an external repository. An earlier version of this
command began by reading
`https://raw.githubusercontent.com/franklesniak/copilot-repo-template/refs/heads/main/CLAUDE.md`,
which resolves to whatever that branch holds at the moment the command runs. That meant the gates,
the thread-handling rules and the termination condition for every `/review-loop` run could change —
or become unreachable — with no commit in this repository and no review by anyone here. Committing
the protocol locally and then loading it from an unpinned remote defeats the point of committing it.

If the upstream template is ever wanted as a *source*, port the change into the local `CLAUDE.md`
in a reviewed pull request, or cite it by immutable commit SHA rather than by branch.

**Include Codex in the review process alongside GitHub Copilot.** Process Codex review comments
identically to GitHub Copilot review comments — same protocol, same rigour, same thread hygiene.
Neither reviewer is advisory.

## Processing review comments

For every review comment from either reviewer, follow the decision protocol in `CLAUDE.md` at the
repository root — the complete numbered workflow, with the three gates (options, rubric, scoring
table) satisfied in your posted reply before you continue.

That protocol is not optional here and it is not a summary of what to do; it is the process. A
reply that validates a finding and then argues a conclusion in prose has **not** followed it, no
matter how sound the argument is.

## Per-round mechanics

1. **Process each finding** through the decision protocol, and implement the selected option.
2. **Run the deferral sweep** — check every review thread, round summary, the pull request
   description, and added code comment for deferred work that no issue tracks (see **Deferring
   work** in `CLAUDE.md`), including anything you are about to defer in a reply. Complete anything
   that belongs in this pull request, or file a tracking issue, before the gates below.
3. **Run the repository's gates** before pushing, and quote their real output.
4. **Commit and push** to the working branch.
5. **Verify CI** on the new head.
6. **Reply on each thread** with the full analysis — validation, options, rubric, scoring table,
   selected option, and the measured evidence, citing the pushed commit. Confirm the reply posted;
   oversized tool results can report an error for a reply that in fact succeeded, so check before
   re-posting rather than posting twice.
7. **Resolve each thread** once its reply is posted and the fix is pushed.
8. **Post a round summary** on the pull request: what was found, what changed, what the gates
   said, what the sweep found, and what remains open with the reason.
9. **Request the next round** from both reviewers.

## Threads you did not resolve

If a thread is left open deliberately, say precisely why, and make sure the reason is true. "Open
by design" and "awaiting a decision" are only accurate if someone was actually asked to decide —
name them. A thread left open because the analysis was never finished is not awaiting anyone; it
is unfinished, and should be finished.

## Termination

Continue until **either**:

- both reviewers return a clean review in the same round, **or**
- 80 rounds have been completed.

Report which condition ended the loop.
