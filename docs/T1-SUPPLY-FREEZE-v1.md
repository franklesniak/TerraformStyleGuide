# T1-SUPPLY-FREEZE-v1

## Status

**Active.** Recorded against the T1 merge commit
[`143f54e52075a1ae1e999a6e242073e3d8d4a46b`](https://github.com/franklesniak/TerraformStyleGuide/commit/143f54e52075a1ae1e999a6e242073e3d8d4a46b).

This record supersedes the copy held in pull request #26's description. Two of that copy's
fields were unverifiable and are replaced here; the reasoning is in
[Why this record exists](#why-this-record-exists) below.

## Purpose

Issue #20 §4a requires a frozen record of the supply inputs, re-checked immediately before
merge. Issue #22 consumes it and requires "exact equality of every recorded field" at its own
implementation start and again immediately before its merge.

That requirement is only meaningful if every field can actually be recomputed. This document
records the values and points at the committed script that derives them.

## Why this record exists

The original freeze record listed two fields as "normalized SHA-256":

| Field as originally recorded | Value |
| --- | --- |
| Installed tree: normalized `npm ls --all --json` | `9635bdbfd9ed52159c3287b42656e939bd33e3dae5c6814e82d735532a03230d` |
| Audit: normalized `npm audit --json` | `a0fbab21fdd1e07218e79ca38b078fe6f4d0134f82934c6f3af1d04d8642e49b` |

Both commands emit output that varies between runs, so something normalized that output before
hashing it. **That normalization procedure was never committed.** Only its two outputs were,
in a pull request description.

A digest whose derivation is unrecorded proves nothing. A reader who computes a different
number cannot tell whether the inputs changed or whether they normalized differently, so the
value is unfalsifiable and #22's equality requirement could not be discharged by anyone.

**The two values above are therefore retired rather than reproduced.** Their recipe is unknown
and cannot be recovered. What replaces them is derived by
`.github/workflows/Get-SupplyFreezeDigest.mjs`, which is committed, so every value below can be
recomputed by anyone.

No dependency actually changed. That was confirmed independently of the retired digests: both
package blob identities are byte-identical to the original freeze, and the advisory set is the
same seven packages at the same severities.

## The record

Run on the reviewed toolchain against the merge commit.

| Field | Value |
| --- | --- |
| Reviewed head that merged | `a308c860e078b661de0dd663be35f018fc60fdcc` |
| Merge commit | `143f54e52075a1ae1e999a6e242073e3d8d4a46b` |
| Merged tree | `8c6e0573e2c87b37ce8a6833e6cc74edfaa370a2` |
| Node | `v24.18.1` |
| npm | `11.16.0` |
| `package.json` | blob `2b88a0ac85d3a8b7286040e6b1f6c4ddb4d3bce1` |
| `package.json` SHA-256 | `e206cdb3562f0397e8eed7fb2c2586269a1f5335cdff2906da8d5e070426321e` |
| `package-lock.json` | blob `5c376ce2364e06c3ac4bc3ab8e3570e86b35f6ca` |
| `package-lock.json` SHA-256 | `277f7168ab3a4f1f7a2565de13191d64b1572e7cb92b67b0972b3242bd4de062` |
| Install producer argv | `npm ci --ignore-scripts --no-audit --no-fund` |
| Installed tree SHA-256 | `32a914d9f49a84d4066c3fb235acb8381ca8e9b910f7882cabf84af4661d11ac` |
| Installed tree size | 2177 files, 8 symlinks |
| Advisory posture SHA-256 | `ea559555c8c18bd2488219d977a994fabc868c2d46efb05bbaf92405c53488e1` |
| Advisory counts | 0 critical, 5 high, 2 moderate, 0 low, 0 info |
| Policy decision | `T1-ADVISORY-DISPOSITION-v1`, bounded through issue #24 |

### Advisory detail

| Package | Severity | Advisories |
| --- | --- | --- |
| `brace-expansion` | high | GHSA-3jxr-9vmj-r5cp, GHSA-f886-m6hf-6m8v, GHSA-mh99-v99m-4gvg |
| `js-yaml` | high | GHSA-52cp-r559-cp3m, GHSA-h67p-54hq-rp68 |
| `linkify-it` | high | GHSA-22p9-wv53-3rq4, GHSA-v245-v573-v5vm |
| `markdown-it` | moderate | GHSA-38c4-r59v-3vqw, GHSA-6v5v-wf23-fmfq |
| `markdownlint-cli2` | moderate | inherited through dependencies |
| `minimatch` | high | GHSA-23c5-xmqv-rm74, GHSA-3ppc-4f35-3m26, GHSA-7r86-cg39-jmmj |
| `picomatch` | high | GHSA-3v7f-55p6-f55p, GHSA-c2c7-rcm5-vvqj |

## How to reproduce

From a clean clone of the recorded commit:

```bash
cd .github/workflows
npm ci --ignore-scripts --no-audit --no-fund
node Get-SupplyFreezeDigest.mjs
```

The script refuses to report on any toolchain other than Node `v24.18.1` with npm `11.16.0`,
because a digest taken on a different pair is not this record. Pass `--json` for machine-
readable output, `--no-audit` to skip the network-dependent half, and `--any-toolchain` to
compute anyway — the last of which produces a number that is explicitly not a freeze record.

## What each digest does and does not prove

### Installed tree

Folds the bytes actually present under `node_modules`: every file's path, length and content,
and every symlink's target, in sorted order.

**Reproducible from the lockfile alone.** Three independent `npm ci` installs in three
different absolute paths produce the identical digest, which also demonstrates that no
machine-specific path leaks into the hashed bytes.

An earlier version of this script digested a normalized `npm ls --all --json` instead, because
that is what the retired field was named after. **That would have been close to worthless**,
and the negative control is what showed it: editing `node_modules/glob/package.json` to version
`9.9.9` and re-running left the digest completely unchanged, because `npm ls` reports the
resolved graph the lockfile determines rather than the bytes on disk. Since the lockfile's own
SHA-256 is already recorded above, that digest restated an existing field while appearing to
measure a new one.

The fold is verified to move for each of these, and to return exactly to baseline afterwards:

| Mutation | Digest moves |
| --- | --- |
| A package's `package.json` version edited | yes |
| A package directory removed | yes, and `treeSatisfiesLockfile` reports false |
| A `.bin` symlink redirected to another target | yes |
| A file truncated to empty | yes |
| An unexpected file added anywhere under `node_modules` | yes |

### Advisory posture

Folds the identity of each advisory — package, severity, GHSA identifier, CWE list, CVSS score
and vector, affected range — plus the overall counts.

Deliberately excluded: advisory **titles**, because GitHub rewords them without the advisory
changing identity; **`fixAvailable`**, because it changes the day a fix ships upstream, which is
news but not a change to what this repository installs; and **`effects`/`nodes`**, because they
are derivable from the installed tree, and one change should not move two numbers.

**This digest is not reproducible from the lockfile alone, and is not meant to be.** It is a
snapshot of a published advisory database that changes over time. Drift here means the
published advisories moved, which calls for a policy re-decision under `T1-ADVISORY-DISPOSITION-v1`
— not a failed build. Any consumer treating it as a lockfile-derived invariant will get a false
failure the first time an advisory is published.

## Consumers

Issue #22 consumes this record. Its equality requirement is discharged by re-running the script
above and comparing against the table, with the caveat on the advisory posture noted directly
above.
