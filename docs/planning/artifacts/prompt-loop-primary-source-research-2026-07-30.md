# Prompt-loop primary-source research — 2026-07-30

## Baseline

- TerraformStyleGuide planning branch before T revision:
  `d6042f0`;
- copied revised P slate:
  `45df8ee86df8879eb8d597d1e048b551647151bc`;
- TerraformStyleGuide default `main`:
  `6ee3f57b2b71b885a5927b770dde47532944de62`; and
- revised PSStyleGuide P slate:
  `7d207482fcc4cfea20af450a73054aeac552abeb`.

## S3 general-purpose bucket names

Source:

- <https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html>

Official reserved prefixes:

```text
xn--
sthree-
amzn-s3-demo-
```

Official reserved suffixes:

```text
-s3alias
--ol-s3
.mrap
--x-s3
--table-s3
```

The documentation also states that a bucket can end in `-an` only for the
account-regional namespace, whose full suffix contains account ID and Region.
T2's copyable global general-purpose examples do not establish that namespace,
so the selected closed subset rejects `-an`.

## Terraform `state rm` options

Command-specific source:

- <https://developer.hashicorp.com/terraform/cli/commands/state/rm>

The command-specific page states:

- HCP Terraform CLI integration or the `remote` backend accepts
  `-ignore-remote-version`; and
- local state only accepts legacy `-state`, `-state-out`, and `-backup`.

General source:

- <https://developer.hashicorp.com/terraform/cli/commands/state>

The general state-command page says modifying state commands create local
backup files and describes `-backup` broadly. Because the command-specific
page narrows `state rm` and explicitly distinguishes local from HCP/remote, the
copyable `state rm` contract must follow the specific page.

Selected consequence:

- protected `terraform state pull` capture is universal pre-mutation recovery
  evidence;
- local mode may use the supported local-only legacy backup flag for the pinned
  Terraform version; and
- HCP/remote modes omit it by construction and never retry after an
  unknown-option destructive invocation.

## GitHub REST rate limits

Source:

- <https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api>

Material facts:

- primary exhaustion can return `403` or `429` with
  `x-ratelimit-remaining: 0` and an `x-ratelimit-reset` epoch;
- secondary limits can return `403` or `429`;
- `Retry-After`, when present, must be honored;
- otherwise clients must use rate-limit reset or bounded backoff; and
- a client must stop after a specific number of retries.

Selected consequence: T3's capture/live verifier must publish exact attempt,
header parsing, maximum wait, and terminal rules. It may choose a small cap and
fail closed rather than sleep until a distant reset.

## GitHub Actions events and rulesets

Sources:

- <https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows>
- <https://docs.github.com/en/actions/reference/workflows-and-actions/contexts>
- <https://docs.github.com/en/rest/repos/rules>

Material facts:

- `push.branches` uses short names;
- `github.ref` is a full ref;
- active rules applying to a branch are queryable; and
- ruleset bypasses distinguish Integration actor and `always` versus `exempt`.

T1/T1B already close these contracts. No new correction is required.

## npm descriptor

Registry SRI already recorded by P3/T3:

```text
sha512-uIXokLlBj6FpNUTQX1PmT5pz7BlIN9QlixX+zdaSNHsd0qUXsbDLr50xzY6Sw7cJVr0uzHKDOle0swmPW/p5Qw==
```

Its lowercase hex form is:

```text
b885e890b9418fa1693544d05f53e64f9a73ec194837d4258b15fecdd692347b1dd2a517b1b0cbaf9d31cd8e92c3b70956bd2ecc72833a57b4b3098f5bfa7943
```

This confirms the shared hash-qualified descriptor, subject to each issue's
fresh freeze-gate re-resolution.
