---
description: Run the automated dual-reviewer PR review loop (Copilot + Codex) to convergence
argument-hint: <pull-request-url>
---

# PR review loop

Target pull request: **$1**

If no pull request URL was supplied above, ask which one to work before doing anything else.

## Setup

Read <https://raw.githubusercontent.com/franklesniak/copilot-repo-template/refs/heads/main/CLAUDE.md>
and begin the review loop described in that file, working on the pull request named above.

**Include Codex in the review process alongside GitHub Copilot.** Process Codex review comments
identically to GitHub Copilot review comments — same protocol, same rigour, same thread hygiene.
Neither reviewer is advisory.

## Processing review comments

For every review comment from either reviewer, follow the decision protocol in `CLAUDE.md` at the
repository root — all six steps, with the three gates (options, rubric, scoring table) satisfied
in your posted reply before you continue.

That protocol is not optional here and it is not a summary of what to do; it is the process. A
reply that validates a finding and then argues a conclusion in prose has **not** followed it, no
matter how sound the argument is.

## Per-round mechanics

1. **Process each finding** through the decision protocol, and implement the selected option.
2. **Reply on the thread** with the full analysis — validation, options, rubric, scoring table,
   selected option, and the measured evidence. Confirm the reply posted; oversized tool results
   can report an error for a reply that in fact succeeded, so check before re-posting rather than
   posting twice.
3. **Resolve the thread** once the reply is posted and the fix is pushed.
4. **Run the repository's gates** before pushing, and quote their real output.
5. **Commit and push** to the working branch.
6. **Verify CI** on the new head.
7. **Post a round summary** on the pull request: what was found, what changed, what the gates
   said, and what remains open with the reason.
8. **Request the next round** from both reviewers.

## Threads you did not resolve

If a thread is left open deliberately, say precisely why, and make sure the reason is true. "Open
by design" and "awaiting a decision" are only accurate if someone was actually asked to decide —
name them. A thread left open because the analysis was never finished is not awaiting anyone; it
is unfinished, and should be finished.

## Termination

Continue until **either**:

* both reviewers return a clean review in the same round, **or**
* 80 rounds have been completed.

Report which condition ended the loop.
