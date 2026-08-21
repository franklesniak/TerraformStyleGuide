# TerraformStyleGuide open-finding evaluations

## Evaluation method

Each finding uses a distinct weighted rubric. Criterion scores are 1–5.
Weighted totals are normalized to 100. Correctness, resource safety, proof
validity, and executable evidence outweigh churn.

## F01 — Whole-directory materialization conflicts with bounded enumeration

### Options

- **A:** Keep both instructions and let the implementer choose.
- **B:** Restore whole-directory materialization for every exact check.
- **C:** Stream once, stop after `N + 1` for cardinality checks, and consume
  an absence proof to completion with constant retained state.
- **D:** Replace absence enumeration with `File.Exists` and
  `Directory.Exists`.
- **E:** Keep materialization but reject a parent above a new entry ceiling.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Resource-bound correctness | 30 | Hostile entry counts must not set memory use. |
| Entry-classification safety | 25 | Dangling or unclassifiable entries must fail closed. |
| Cross-platform determinism | 20 | Windows and Ubuntu must use one clear contract. |
| Proof quality | 15 | The harness must distinguish bounded from eager behavior. |
| Churn | 10 | Lower priority than the production contract. |

### Scores

| Option | Resource | Safety | Platforms | Proof | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 2 | 2 | 1 | 5 | 37 |
| B | 1 | 5 | 5 | 4 | 3 | 69 |
| C | 5 | 5 | 5 | 5 | 4 | **98** |
| D | 5 | 1 | 3 | 4 | 4 | 67 |
| E | 4 | 4 | 4 | 4 | 2 | 76 |

### Selected resolution

Select **C**. Remove the materialization instruction. Every exact-count check
will retain no more than `N + 1` entries. An absence check will stream the
directory once to completion without collecting it. A matching,
unclassifiable, or unreadable entry will stop the scan and retain uncertain
state. The harness-proof manifest will test the bounded command path and a
mutant that removes the guard.

## F02 — Harness-only proof manifest is not literal

### Options

- **A:** Leave the manifest details to implementation.
- **B:** Force resource and race proofs into `T1A-CASES-v1`.
- **C:** Add one closed, versioned, two-row harness-proof manifest beside the
  141-row functional catalog.
- **D:** Remove the resource and race proofs.
- **E:** Defer the two proof classes to a later GitHub Issue.

### Rubric

| Criterion | Weight | Purpose |
| --- | ---: | --- |
| Authority completeness | 30 | The issue must freeze every proof identity and oracle. |
| Proof validity and controls | 25 | Static, mutant, trace, and race claims need controls. |
| Mutation detection | 20 | Missing or weakened proofs must fail structurally. |
| Cold-reader usability | 15 | A new implementer must have no inventory choice. |
| Churn | 10 | Lower priority than evidence integrity. |

### Scores

| Option | Authority | Proof | Mutation | Usability | Churn | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 1 | 3 | 1 | 1 | 5 | 38 |
| B | 4 | 2 | 4 | 3 | 2 | 63 |
| C | 5 | 5 | 5 | 5 | 4 | **98** |
| D | 5 | 1 | 4 | 4 | 5 | 73 |
| E | 4 | 4 | 4 | 2 | 1 | 68 |

### Selected resolution

Select **C**. Add `T1A-HARNESS-PROOFS-v1` with exactly two rows:
`T1A-H-01` for bounded enumeration and `T1A-H-02` for the pre-journal
population race. Freeze the row schema, all three runtime cells, the exact
control and perturbation, one result per applicable runtime, and fail-closed
postconditions. Reject a missing, duplicate, unknown, skipped, or multiply
emitted proof result. Keep these proof rows separate from the 141 functional
oracles because they establish implementation properties rather than a
different public output.

## Integration trace

| Finding | Issue integration |
| --- | --- |
| F01 | T1A requested change 1 and candidate-cleanup transitions |
| F02 | T1A atomic catalog section, validation, and acceptance criteria |

Neither resolution adds, deletes, renames, or reorders an issue draft.
