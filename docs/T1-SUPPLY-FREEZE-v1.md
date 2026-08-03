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
| Freeze script | `.github/workflows/Get-SupplyFreezeDigest.mjs` SHA-256 `32c1fed6f057ac2eb67e84721eb1a562b8cf7d517f03f5c3a4703804f1093c39` |
| Node | `v24.18.1` |
| npm | `11.16.0` |
| Platform | `linux` / `x64` |
| `package.json` | blob `2b88a0ac85d3a8b7286040e6b1f6c4ddb4d3bce1` |
| `package.json` SHA-256 | `e206cdb3562f0397e8eed7fb2c2586269a1f5335cdff2906da8d5e070426321e` |
| `package-lock.json` | blob `5c376ce2364e06c3ac4bc3ab8e3570e86b35f6ca` |
| `package-lock.json` SHA-256 | `277f7168ab3a4f1f7a2565de13191d64b1572e7cb92b67b0972b3242bd4de062` |
| Install producer argv | `npm ci --ignore-scripts --no-audit --no-fund` |
| Installed tree SHA-256 | `c77d611336230e8e0d520370431ace130d1a78023d4006ca075fba59af09680c` |
| Installed tree size | 2177 files, 8 symlinks, 336 directories |
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

The script is **not** present at the recorded T1 merge commit — it is added by the change that
introduces this document. Reproduce from a revision that contains it, which carries the same
`package.json` and `package-lock.json` blobs:

```bash
git checkout main            # or any revision containing Get-SupplyFreezeDigest.mjs
cd .github/workflows
git rev-parse HEAD:.github/workflows/package.json          # must equal the recorded blob
npm ci --ignore-scripts --no-audit --no-fund
node Get-SupplyFreezeDigest.mjs
```

**Ambient npm configuration changes what `npm ci` produces.** A `bin-links=false` or `omit=dev`
setting in an environment variable or a user/global `.npmrc` yields a different tree from the
same lockfile — measured, `bin-links=false` installs 0 symlinks where the record has 8. The
script reads the *effective* configuration and refuses to record when any install-shaping
setting differs from its reviewed value, so this fails loudly instead of producing a mismatch
the reader cannot explain.

That guard reads the configuration in effect **when the script runs**. A tree installed under
`bin-links=false` in a shell that no longer carries the setting still passes it, so the symlink
and file counts recorded above are the backstop for that case: 0 symlinks against a recorded 8
names the cause even where the guard cannot see it. To sidestep ambient configuration entirely:

```bash
npm ci --ignore-scripts --no-audit --no-fund \
  --userconfig=/dev/null --globalconfig=/dev/null
```

The script refuses to run against any manifest other than the reviewed one, so a revision whose
`package.json` or `package-lock.json` has moved will exit non-zero rather than report a
misleading digest.

**Check the script's own digest first.** The script reports its own SHA-256 on every run, and the
value is recorded in the table above. This matters because the digests below are a property of
*this* script: during review the installed-tree digest moved twice without any dependency
changing at all — once when the fold was made injective, and again when the executable bit was
added to it. A reader with a correct tree, a correct lockfile and a different script version
would otherwise see a mismatch with nothing to explain it.

```bash
sha256sum Get-SupplyFreezeDigest.mjs   # must equal the recorded value
```

The script refuses to report on any toolchain other than Node `v24.18.1` with npm `11.16.0` on
`linux`/`x64`, because a digest taken on a different combination is not this record. Pass `--json` for machine-
readable output, `--no-audit` to skip the network-dependent half, and `--any-toolchain` to
compute anyway — the last of which produces a number that is explicitly not a freeze record.

## What each digest does and does not prove

### Installed tree

Folds the bytes actually present under `node_modules`: every file's path, normalized executable
bit and content, every symlink's path and target, and every directory's path, in sorted order.

The **normalized executable bit** rather than the full mode, and that is a measurement rather
than a preference. All three reference installs agree on the full mode (`0o644` ×2157, `0o755`
×20), but node-tar applies the process umask when it extracts, so the non-execute bits are a
property of the extracting machine. The execute bit survives the umasks that occur in practice —
`0o755` under `umask 077` is still `0o700`, still executable — so exactly one bit of mode is
recorded: the one that decides whether the file can run.

Every variable-length field is **length-prefixed**, which makes the encoding injective. An
earlier draft used line-oriented framing, and that was not injective: a POSIX path or symlink
target may itself contain a newline, so two genuinely different trees hashed identically. Both
the symlink framing and the file framing were affected, and both were demonstrated with real
directories on disk before the fix and shown to differ after it.

**Reproducible from the lockfile and the reviewed platform.** Three independent `npm ci`
installs in three different absolute paths produce the identical digest, which also
demonstrates that no machine-specific path leaks into the hashed bytes.

It is **not** reproducible from the lockfile alone, and an earlier draft of this document
claimed otherwise. npm's `bin-links` writes `.cmd` and `.ps1` shims on Windows where POSIX
gets symlinks, so the same lockfile yields a genuinely different tree on a different platform.
The script therefore pins `linux`/`x64` alongside the Node and npm versions and refuses to
report elsewhere.

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
