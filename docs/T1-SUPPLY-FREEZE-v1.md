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

Issue #22 requires exact equality of every **compared** field. The two tables below say which
those are, because not every value worth recording is a value worth comparing — a field that
cannot be re-derived, or that tracks machine state, produces a false mismatch rather than a
finding.

### Compared fields

Every value here is derived by the script from the inputs, and must match exactly.

| Field | Value |
| --- | --- |
| Reviewed head that merged | `a308c860e078b661de0dd663be35f018fc60fdcc` |
| Merge commit | `143f54e52075a1ae1e999a6e242073e3d8d4a46b` |
| Merged tree | `8c6e0573e2c87b37ce8a6833e6cc74edfaa370a2` |
| Freeze script | `.github/workflows/Get-SupplyFreezeDigest.mjs` SHA-256 `66fd32bca7ebf8dc0f9359cf7d7bdf09f985a1fe9eb0df1b33b0b01ff94fb594` |
| Node | `v24.18.1` |
| npm | `11.16.0` |
| Platform | `linux` / `x64` |
| Install umask | `0022` |
| `package.json` | blob `2b88a0ac85d3a8b7286040e6b1f6c4ddb4d3bce1` |
| `package.json` SHA-256 | `e206cdb3562f0397e8eed7fb2c2586269a1f5335cdff2906da8d5e070426321e` |
| `package-lock.json` | blob `5c376ce2364e06c3ac4bc3ab8e3570e86b35f6ca` |
| `package-lock.json` SHA-256 | `277f7168ab3a4f1f7a2565de13191d64b1572e7cb92b67b0972b3242bd4de062` |
| Installed tree SHA-256 | `4cdc37a7269eb90a413fb3f26c031b81268f62fe9129c9939337106da12cc716` |
| Installed tree size | 2177 files, 8 symlinks, 336 directories |
| Advisory registry | `https://registry.npmjs.org/` |
| Advisory posture SHA-256 | `ea559555c8c18bd2488219d977a994fabc868c2d46efb05bbaf92405c53488e1` |
| Advisory counts | 0 critical, 5 high, 2 moderate, 0 low, 0 info |
| Policy decision | `T1-ADVISORY-DISPOSITION-v1`, bounded through issue #24 |

The two advisory rows are compared **at a point in time**. They snapshot a database that changes
as advisories are published; drift there calls for a policy re-decision rather than a failed
build, which is set out in
[Advisory posture](#advisory-posture).

### Diagnostic fields — recorded, not compared

Observed and reported so a reader can diagnose a mismatch. **Not** subject to exact equality.

| Field | Value | Why it is not compared |
| --- | --- | --- |
| File permissions | `{"644":2157,"755":20}` | full modes are machine state |

A harmless `0644` → `0664` leaves the installed-tree digest byte-identical — measured, still
`4cdc37a7…` — while moving the histogram to `{"644":2156,"664":1,"755":20}`. Comparing it for
exact equality would therefore reject a tree the digest says is correct, which is precisely the
machine-state drift the execute-bit normalization exists to avoid. An earlier draft listed it as
a recorded field while the prose called it "recorded, not enforced"; the table and the prose
disagreed, and #22's rule resolved that disagreement the wrong way.

### Not a recorded field: the install command

The tree was produced with:

```text
npm ci --ignore-scripts --no-audit --no-fund
```

This is the **prescribed** command, not an observed value, and it is deliberately outside both
tables above. The script captures no installation provenance whatsoever — it inspects a finished
tree — so an equivalent invocation with the same flags in a different order yields an identical
tree and identical output for every field the script emits. Listing it as a compared field would
have asked #22 to check something no reader could establish, which is the exact defect this
document was written to remove. It belongs in
[How to reproduce](#how-to-reproduce), and that is where it now lives.

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

# <rev>:<path> is always resolved from the repository root, never the current
# directory, so this runs before the cd and keeps the path unambiguous.
git rev-parse HEAD:.github/workflows/package.json          # must equal the recorded blob
git rev-parse HEAD:.github/workflows/package-lock.json     # must equal the recorded blob

cd .github/workflows
umask 0022                   # the recorded tree was installed under this
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
names the cause even where the guard cannot see it.

The **umask guard has the same shape and the same backstop.** It reads the umask of the
recording process, which catches the common case where one shell both installs and records, and
cannot see a tree built under a different umask earlier. The **file-permission histogram** is
the tell that survives into the tree itself, because it records the permission bits rather than
a predicate over them:

| Install umask | Histogram | Installed tree |
| --- | --- | --- |
| `022` — reviewed | `{"644":2157,"755":20}` | `4cdc37a7…` |
| `027` | `{"640":2157,"750":20}` | `62eddc28…` |
| `077` | `{"600":2157,"700":20}` | `0a215132…` |

The histogram is a **diagnostic hint, not a proof**. Any change to a file's mode moves it —
measured, a single `chmod g-r` under the reviewed umask turns `{"644":2157,"755":20}` into
`{"604":1,"644":2156,"755":20}`. A shape that differs from the record is therefore *consistent
with* a different install umask, and equally consistent with modes altered after the install;
it narrows the search rather than settling it.

An earlier draft counted **group-readable files** instead, and that was too weak to be a
backstop. `umask 027` clears `0o027`, which leaves group read set — `0o644` becomes `0o640` and
`0o755` becomes `0o750`, both still group-readable. Measured: a tree installed under `027` and
recorded under `022` moved the digest to `62eddc28…` while the census still reported the
recorded `2177 of 2177`, so it was blind to one of the umasks the guard itself rejects. The
histogram distinguishes all three.

The histogram is recorded and **not** folded into the digest. The full mode is machine state;
pinning it would reintroduce exactly the drift the execute-bit normalization exists to avoid.

To sidestep ambient configuration files:

```bash
: > /tmp/npm-user-empty; : > /tmp/npm-global-empty
export NPM_CONFIG_USERCONFIG=/tmp/npm-user-empty
export NPM_CONFIG_GLOBALCONFIG=/tmp/npm-global-empty
npm ci --ignore-scripts --no-audit --no-fund
node Get-SupplyFreezeDigest.mjs
```

**The isolation must cover the recorder, not just the install.** An earlier draft passed
`--userconfig` and `--globalconfig` as flags to `npm ci` alone. Those flags apply to that one
invocation, and the script then runs `npm config list --json` without them, reloads the ambient
files, and refuses with exit 6 — against a tree it had just installed correctly. Measured: with
`bin-links=false` in an ambient user `.npmrc`, the flag form installed the correct 8 symlinks
and the recorder still exited 6, so the documented workaround could not be completed. The
environment variables above are read by every npm invocation, which is why they are used
instead.

**The two paths must be different files.** An earlier draft pointed both options at `/dev/null`,
which does not run at all. npm de-duplicates configuration files by resolved path: it records
each file it loads against the layer that loaded it, and refuses to load one path as two
different layers. Passing the same path as both `user` and `global` therefore makes `npm ci`
exit 1 with `double-loading config "/dev/null" as "global", previously loaded as "user"` before
the install starts. Any single path used twice fails the same way — `/dev/null` is not special,
and the rule is about path identity rather than the file's contents.

**This isolates configuration files, not the environment.** Measured: with
`npm_config_bin_links=false` exported, the command above still installs 0 symlinks, because an
`npm_config_*` environment variable outranks the empty files. Scrub the environment as well when
that matters:

```bash
env -u npm_config_bin_links npm ci --ignore-scripts --no-audit --no-fund
```

The script's configuration guard is what catches both, and it is the reason this is a loud
failure rather than a silent one.

The script refuses to run against any manifest other than the reviewed one, so a revision whose
`package.json` or `package-lock.json` has moved will exit non-zero rather than report a
misleading digest. It also refuses when `node_modules` is absent or does not satisfy the
lockfile — `package-lock-only=true` makes `npm ci` a no-op that reports `up to date` while
reducing the tree to a single file, and a record must not be minted over that.

### Why a run was refused

Every refusal names the observed and reviewed values on stderr. `--any-toolchain` bypasses all
of them and marks the output as explicitly not a freeze record.

| Exit | Refusal | Usual cause |
| ---: | --- | --- |
| `2` | Unreviewed toolchain | different Node, npm, platform or architecture |
| `3` | Manifest changed mid-run | `package.json` or `package-lock.json` edited while `npm ls`/`npm audit` ran |
| `4` | Unreviewed manifest | `package.json` or `package-lock.json` has moved |
| `5` | Audit response is not a report | registry unreachable, or an endpoint error returned as JSON |
| `6` | Install-shaping npm configuration | `bin-links`, `omit`, `package-lock-only` … from an `.npmrc` or the environment |
| `7` | Tree is not the installed tree | `node_modules` absent, incomplete, or never installed |
| `8` | Unreviewed umask | recording shell is not at `0022` |
| `9` | Unreviewed advisory registry | `registry` points at a mirror or proxy |
| `10` | Installed tree changed while recording | something wrote to `node_modules` during the run |

Exit `10` is the counterpart to exit `3` for the tree rather than the manifests: the tree is
folded once before `npm audit` and again after it, and a mismatch between the two means the
bytes moved while the record was being taken. The audit is a network round trip — measured at
about 2.0s against a 0.1s fold — so that window is wide enough to matter, and re-folding
brackets it rather than merely narrowing it.

Exit `9` applies only when the audit runs. The registry does not shape the installed tree —
every package in the lockfile carries an `integrity` hash and `npm ci` verifies each tarball
against it, so substituted bytes fail the install outright. Only the advisory posture is
exposed, which is why `--no-audit` records the lockfile-derived fields from any registry.

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
`linux`/`x64`, because a digest taken on a different combination is not this record. Pass
`--json` for machine-readable output, `--no-audit` to skip the network-dependent half, and
`--any-toolchain` to compute anyway — the last of which produces a number that is explicitly
not a freeze record.

## What each digest does and does not prove

### Installed tree

Folds the bytes actually present under `node_modules`: every file's path, normalized execute
bits and content, every symlink's path and target, and every directory's path, in sorted order.

The **normalized execute bits** (`mode & 0o111`) rather than the full mode. node-tar applies the
process umask when it extracts, so the read and write bits are a property of the extracting
machine, and recording the full mode would make the digest drift for a reason that has nothing
to do with the package.

**The execute bits are not umask-independent either, and an earlier draft of this document
claimed they were.** It argued that `0o755` under `umask 077` is still `0o700` and still
executable by its owner. The file does remain executable; the *recorded value* does not survive
— `0o755 & 0o111` is `0o111`, `0o700 & 0o111` is `0o100`. Measured: a full `npm ci` under
`umask 077` produces `0a215132…` against the recorded `4cdc37a7…`, a mismatch caused by nothing
but the reader's umask. So the umask is **pinned at `0022` and checked**, making it the sixth
environmental input this record fixes, alongside Node, npm, platform, arch and npm
configuration. It is also the cheapest of the six to satisfy.

npm's own `umask` config is a separate setting that defaults to `0`, and it is what
`npm config list` reports; the process umask is invisible to that check, which is why it needed
its own guard rather than an extra entry in the configuration table.

All three execute classes are recorded, not a single boolean. An earlier draft collapsed them,
which made `0o755` and `0o655` hash identically. That is not a harmless normalization: POSIX
consults **only the owner bits** when the process euid owns the file, so a `0o655` file is not
executable by the user who installed it even though group and other still carry `+x`. Measured
with an owner-matched process — `Permission denied`, while the collapsed fold did not move.

Symlink targets are folded as **raw bytes**, not as decoded strings. A POSIX target is an
arbitrary byte string, and decoding it as UTF-8 first is lossy: targets of the single bytes
`0x80` and `0x81` both decode to U+FFFD and hashed identically — a real collision, measured on
ext4, in the very property this fold claims.

**Path components are the one exception, and are folded as UTF-8-decoded names.** Directory
entries come from `readdirSync`, which decodes names the same lossy way, so a filename holding
non-UTF-8 bytes would collide by the identical mechanism. It is left as it stands rather than
quietly fixed: reading entries as raw bytes changes how every path in the tree sorts and hashes,
which would move the recorded digest to guard a case npm cannot produce — package names are
constrained to a subset of ASCII, and all 2177 entries in the reviewed tree are ASCII. A symlink
target is different in kind, being an arbitrary string npm writes rather than a validated name,
which is why that one is byte-exact. Stated here so the fold's injectivity claim is read with
the boundary attached rather than as an unqualified guarantee.

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
| A `.bin` target's execute bit cleared (`0o755` → `0o644`) | yes |
| Only the owner's execute bit cleared (`0o755` → `0o655`) | yes |

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
