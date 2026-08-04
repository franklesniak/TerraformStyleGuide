# Claude Code instructions

## The decision protocol

**Applies to every finding, review comment, bug report, or design decision** — anything where
there is more than one defensible way forward. Follow all six steps in order. Steps 2, 3 and 4
are hard gates: the required artifact must appear in your output before you move on.

### 1. Validate

Determine whether the feedback represents a material opportunity for improvement, and/or confirm
that the reported bug is real. Reproduce it where reproduction is possible.

Validation means *measuring*, not *reasoning*. If you find yourself writing "the mechanism is
real and I am not disputing it" without having run anything, stop and run something. If a
reproduction looks blocked, ask what else could produce the same condition before recording it as
unreproducible — the absence of the obvious tool is not the absence of a path.

**Always include a control.** A test with no control cannot distinguish the effect you are
looking for from an artifact of the setup, and a clean-looking result from a broken harness is
worse than no result.

### 2. List the options — GATE

Be exhaustive. Include permutations and combinations of options, not just the atomic ones. Take
the time to compile a comprehensive list.

Generate options from multiple perspectives, and say which perspective produced which argument:
senior software engineer, new developer, devops expert, documentation expert, project manager,
cybersecurity executive, cybersecurity technical expert, business stakeholder, and any other role
that fits the problem.

Do primary-source Internet research as needed to support the options and confirm correctness.
Link what you used and explain it — in a `References` section when writing a GitHub issue.

> **You must list the options before continuing.**

### 3. Build an evaluation rubric — GATE

Write a rubric specific to *this* finding. **Do not reuse a rubric across findings** — the
criteria that matter are a property of the problem, and a recycled rubric silently imports the
last problem's priorities.

Weight the criteria, and weight them honestly:

* **Weigh lower**: amount of churn, difficulty to implement, adherence to the original issue's
  scope.
* **Weigh higher**: technical correctness, legitimate usability considerations, whether the fix
  addresses the *class* rather than the reported instance.

Consider criteria and weights from the same range of perspectives used in step 2. State why each
criterion carries the weight it does.

> **You must describe the rubric in detail before continuing.**

### 4. Score the options — GATE

Apply the rubric to every option and show the results in a table: criteria as rows with their
weights, options as columns, and a weighted total per option.

> **You must show the scoring table before continuing.**

### 5. Select and specify

Use the table to select the best option. State the selection in detail, so that someone coming in
cold understands exactly what needs to be done and why. Include:

* relevant primary-source references;
* local testing information where applicable — environment details, the exact commands run, and
  the specific results, quoted rather than summarised;
* anything you could **not** verify, and why. An unverifiable claim stated as verified is worse
  than an admitted gap.

### 6. Implement

Implement the solution the analysis supports. Not a smaller one that was easier, and not a
different one that occurred to you while writing the code — if the analysis no longer fits, redo
the analysis.

## Anti-patterns this protocol exists to prevent

These are drawn from real failures in this repository, and each one passed casual inspection at
the time.

* **A fluent argument in place of a table.** Validation followed by well-written prose reads like
  diligence and produces no options, no rubric, and no scoring. It is the single most common way
  this protocol gets skipped, because the output looks thorough. If there is no table, the
  protocol did not run.
* **An unmeasured claim used as load-bearing justification.** A blanket statement covering N
  cases, written having checked none, that then becomes the stated reason for an exemption. When
  it is finally measured and turns out backwards, the exemption has been protecting the exact
  case it should have caught.
* **Fixing the reported instance rather than the class.** Ask whether the defect has siblings,
  sweep for them, and report the result of the sweep — including when the sweep finds nothing.
* **A check that cannot fail.** A command that prints where it should verify, an assertion with
  no assertion in it, a value with a "must equal" comment beside it. Ask of every check: *what
  makes this fail?*
* **Correct code with wrong prose attached.** After changing behaviour, re-read the comments,
  documentation, and refusal messages that describe it. Stale justification outlives the thing it
  justified.
* **Inconsistent examples.** An example can be locally correct and still wrong, by differing from
  its siblings in a way a reader must guess is load-bearing. Compare each example against the
  others of the same operation.

## Correcting your own earlier work

If you find that something you previously shipped or asserted was wrong, say so plainly and
correct it, including when nobody has challenged it. Re-open your own closed threads when the
analysis behind them turns out not to have been done. Never quietly restate a conclusion that new
measurement contradicts.

Never write an identifier — a commit SHA, comment ID, issue number, digest, or URL — that you
have not verified. If you need one and do not have it, look it up.

## PR review loops

See `.claude/commands/review-loop.md`, or invoke it as `/review-loop <pull-request-url>`.
