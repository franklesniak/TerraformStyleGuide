# TerraformStyleGuide current findings

## Scope and method

Re-reviewed T1, T1A, T1B, T2, T3, and T4 in their required sequence against:

- the synchronized PSStyleGuide issue contracts;
- `docs/planning/TerraformStyleGuide/slate-criticism.md`;
- every prior finding and implemented resolution;
- the post-fixed-point commits through `e30e8fd`; and
- the retained and newly refreshed primary-source research.

The incoming criticism correctly reports that the earlier findings were closed
at the prior fixed point. T1, T1B, T2, T3, and T4 do not reopen one. T3 and T4
only add an MD013 directive and reflow existing text after whitespace
normalization.

The later T1A edits introduce the following two open findings.

## F01 — T1A retains a whole-directory materialization instruction

**Validity: confirmed.** Requested change 1 now requires bounded streaming for
every exact-cardinality enumeration and prohibits materializing the directory.
Candidate cleanup still directs the `NotCreated` transition to “materialize
its immediate entries once.” Both instructions govern the same production
enumeration behavior and cannot be implemented together.

The `NotCreated` absence proof can stream the parent exactly once. It can stop
on a matching or unclassifiable entry. It must consume the stream to prove
absence, but it does not need to retain the complete result set. The issue must
state that distinction and apply it to Active cleanup too.

## F02 — T1A does not freeze its new harness-only proof manifest

**Validity: confirmed.** T1A adds resource-only and race-window proof classes
outside `T1A-CASES-v1`. It says a versioned, count-checked manifest governs
them, but it supplies no manifest identifier, schema, literal count, IDs,
runtime applicability, control, perturbation, result cardinality, or
postcondition.

This omission delegates the proof inventory to the implementer and prevents a
structural validator from detecting a deleted or weakened proof. The issue must
publish a closed two-row harness-proof manifest and require one result for each
applicable runtime.

## Non-findings

- The two `*-shortened.md` files are alternate renderings, not additional
  sequential GitHub Issues. They do not change the six-file issue slate or its
  order.
- T1A's bounded enumeration change is directionally correct. The finding is
  the remaining contradictory materialization instruction, not the use of
  streaming enumeration.
- No issue file needs to be added, deleted, renamed, or reordered.
