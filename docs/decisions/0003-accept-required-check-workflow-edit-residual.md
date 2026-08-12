# Decision 0003: Accept that workflow edits can satisfy required checks by skipping them

## Status

Accepted on 2026-08-10 by Frank Lesniak, TerraformStyleGuide repository owner.

This record accepts one limitation in the repository's main-branch ruleset and records a
second, related implementation constraint. It does not claim either limitation is closed.
Issue #28 contains the options analysis, scoring, administrator procedure, and retained
execution evidence for this decision.

## 1. The concern, and whether it is real

The ruleset requires the GitHub Actions check contexts `policy`, `markdownlint`, and
`verify`. Those checks provide useful prevention when a job fails or when a required job
is deleted or renamed:

- a failed required job reports failure and blocks the update; and
- a deleted or renamed required job does not report the required context, so the update
  remains blocked.

They do not prevent a pull request from editing the workflow files so that every required
job is skipped. GitHub treats a job skipped by a job-level conditional as successful for
required-check purposes. Because both workflow files are stored in this repository, one
pull request can change both and make all three required jobs skip.

The concern is therefore real. Required status checks protect against validator failure
and removal, but not against every modification of the mechanism that produces them.

## 2. Controls that are in force

Repository ruleset `20623677`, named `terraform-style-guide-main-protection`, is active.
Its target condition is exactly `~DEFAULT_BRANCH`, with no exclusion. The repository's
default branch was `main` when the rule was created.

Selecting the default branch rather than a literal `main` pattern is a deliberate owner
choice. Protection follows a future default-branch change. The corresponding cost is that
`main` would leave this ruleset if another branch became the default. Any default-branch
change is therefore a governance change that requires this decision and the live ruleset
to be revalidated.

The effective rules require:

- deletion restriction;
- non-fast-forward update restriction;
- a pull request with zero required approvals;
- resolution of every pull-request conversation;
- the `policy`, `markdownlint`, and `verify` check contexts, each sourced from GitHub
  Actions integration `15368`; and
- required checks against a branch current with the target branch.

The ruleset intentionally has no bypass actor. The repository owner confirmed the empty
bypass list in the GitHub settings UI. The unauthenticated public ruleset response omits
the bypass property, and GitHub's downloadable ruleset JSON also excludes bypass actors,
so neither is substituted for that UI observation.

The visible workflow diff, required pull request, required conversation resolution, and
three current required checks are compensating controls. They reduce the chance of an
unnoticed workflow bypass; they do not make the bypass impossible.

## 3. Why the bypass list is empty

Issue #20 section 13 and the original text of issue #28 assumed that the built-in GitHub
Actions app, public integration ID `15368`, could be selected as the sole ruleset bypass
actor. Live implementation disproved the necessary premise: the repository owner opened
the ruleset bypass picker, and GitHub Actions was not offered.

Resolving `GET /apps/github-actions` establishes that the public app is owned by `github`,
has slug `github-actions`, and has ID `15368`. It does not establish that the app is an
eligible bypass suggestion for this repository.

No substitute was added:

- adding the owner or Repository administrators would permit the human direct push this
  ruleset is intended to reject;
- a custom GitHub App would introduce a private key, installation-token lifecycle,
  permissions, rotation, and compromise-scope decision;
- a write-enabled deploy key would introduce a durable SSH credential and a new bypass
  surface; and
- an undocumented or API-only attempt to force the built-in app ID would violate the
  web-UI execution constraint and would still require a real bypass drill.

The current workflows do not push to `main`, so the empty bypass list does not break the
current workflow graph.

## 4. Options considered after the live finding

| Option | Decision |
| --- | --- |
| Protect the default branch now with an empty bypass; redesign the #22 writer later | Selected. It closes the current unprotected window without adding a credential or weakening the rule for humans. |
| Add the owner or Repository administrators | Rejected. It permits ordinary human bypass and does not cause `GITHUB_TOKEN` to authenticate as that actor. |
| Create a custom GitHub App now | Rejected for #28. Its credentials and permissions require a separate decision and drill. |
| Add a write-enabled deploy key now | Rejected for #28. Its durable credential and SSH transport require a separate decision and drill. |
| Delay all protection until #22 | Rejected. It leaves the current branch unprotected. |
| Force integration ID `15368` through an API-only path | Rejected. Eligibility and effective bypass are unproven, and the owner selected a web-UI-only settings procedure. |

## 5. Decision

Accept the workflow-edit residual and keep the interim bypass list empty.

The active, effective interim ruleset completes issue #28 and clears that issue as the
prerequisite that blocks issue #22. Merging this decision record is the final repository
record step for #28; the issue must not remain open waiting for a check that only #22 can
create.

Issue #22 must not introduce or activate its planned write-enabled direct-push job until a
separate decision selects and drills one of these shapes:

1. a supported, installed automation actor with a bounded credential and explicit bypass;
2. a write-enabled deploy key with an explicitly accepted credential lifecycle; or
3. a pull-request-based promotion design that needs no direct-push bypass.

The old assumption that the repository's `GITHUB_TOKEN` can bypass as public integration
ID `15368` is retired unless a future recorded capability test proves actor selection and
effective bypass on this repository. A user or administrator bypass must not be added just
to preserve the old writer design.

After issue #22 creates and successfully reports
`Build Style Guide Artifacts / approve`, that exact context must be added to the required
list following #22's temporary-ref drill and before #22 merges or activates its production
writer. That extension is a #22 implementation responsibility, not a #28 closure
criterion. The live effective rules and retained digest must then be updated.

## 6. Retained effective-rule evidence

Source:
`https://api.github.com/repos/franklesniak/TerraformStyleGuide/rules/branches/main`

The response was canonicalized with RFC 8785 JSON Canonicalization Scheme. The effective
response contains only I-JSON values; object keys were sorted by UTF-16 code units, array
order was preserved, and the canonical text was encoded as UTF-8 without a byte-order
mark.

SHA-256:

```text
d15bfb681d2cb7ba0ea6408225edc3be413547037246f5976d7d34817e26f826
```

Canonical effective-rule JSON:

```json
[{"ruleset_id":20623677,"ruleset_source":"franklesniak/TerraformStyleGuide","ruleset_source_type":"Repository","type":"deletion"},{"ruleset_id":20623677,"ruleset_source":"franklesniak/TerraformStyleGuide","ruleset_source_type":"Repository","type":"non_fast_forward"},{"parameters":{"allowed_merge_methods":["merge","squash","rebase"],"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_approving_review_count":0,"required_review_thread_resolution":true,"required_reviewers":[]},"ruleset_id":20623677,"ruleset_source":"franklesniak/TerraformStyleGuide","ruleset_source_type":"Repository","type":"pull_request"},{"parameters":{"do_not_enforce_on_create":false,"required_status_checks":[{"context":"markdownlint","integration_id":15368},{"context":"policy","integration_id":15368},{"context":"verify","integration_id":15368}],"strict_required_status_checks_policy":true},"ruleset_id":20623677,"ruleset_source":"franklesniak/TerraformStyleGuide","ruleset_source_type":"Repository","type":"required_status_checks"}]
```

The ruleset-detail response separately recorded:

- ruleset ID `20623677`;
- name `terraform-style-guide-main-protection`;
- target `branch`;
- enforcement `active`;
- inclusion `~DEFAULT_BRANCH`;
- no exclusion; and
- `main` reporting `protected: true` at commit
  `aae05282b57f093cec8b63e59138db72c982f10e`.

Issue #28 retains the pre-change empty-ruleset baseline and the direct-push rejection
evidence. The latter is operational evidence rather than part of the effective-rule JSON.

## 7. Consequences

Positive consequences:

- ordinary direct updates, deletions, and force pushes to the current default branch are
  rejected;
- three independent current checks must report before a pull request can merge;
- missing or renamed required jobs block rather than silently weakening the rule; and
- no human, role, deploy key, or unreviewed automation credential can bypass the rule.

Accepted negative consequences:

- a workflow-editing pull request can make required jobs skip successfully;
- an emergency direct fix cannot use an administrator bypass; the owner must edit or
  disable the ruleset;
- changing the default branch moves the protection away from `main`; and
- issue #22's old direct-writer design is blocked until its authentication and bypass
  design is replaced or separately authorized and proven.

## 8. When this decision must be revisited

Revisit this decision when any of the following occurs:

- the repository's default branch changes or is proposed to change;
- issue #22 begins authentication or write-enabled implementation work;
- GitHub makes the built-in Actions app selectable as a bypass actor for this repository;
- a custom GitHub App, deploy key, user, administrator, or repository role is proposed for
  bypass;
- the repository moves to an organization or gains an independent required-workflow
  mechanism;
- the repository gains another maintainer, making Code Owner review operationally viable;
- GitHub changes how skipped jobs satisfy required checks; or
- any required check is renamed, moved, conditionally skipped, or removed.

## References

1. [Issue #28](https://github.com/franklesniak/TerraformStyleGuide/issues/28) — options,
   administrator procedure, amendments, and execution evidence.
2. [Creating rulesets for a repository](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository)
   — target selection and bypass-actor UI.
3. [Troubleshooting required status checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks)
   — skipped-job and missing-check behavior.
4. [GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token) — the
   repository-scoped GitHub App installation token used by Actions workflows.
5. [REST API endpoints for rules](https://docs.github.com/en/rest/repos/rules) — ruleset
   details and effective rules for a branch.
