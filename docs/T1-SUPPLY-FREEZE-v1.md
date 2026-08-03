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

Every value here must match exactly. The **Derived by** column names what produces each
one — for script-derived rows, the exact key in `--json` output.

That column is not decoration. An earlier draft of this section said "every value here is
derived by the script from the inputs", which was **not true**: three of these rows come from
`git` and the script emits no field for them at all. A record that misstates where its own
values come from is the defect this document was written to retire, so the provenance is now
per-row rather than asserted in a sentence.

| Field | Value | Derived by |
| --- | --- | --- |
| Reviewed head that merged | `a308c860e078b661de0dd663be35f018fc60fdcc` | `git` — see below |
| Merge commit | `143f54e52075a1ae1e999a6e242073e3d8d4a46b` | `git` — see below |
| Merged tree | `8c6e0573e2c87b37ce8a6833e6cc74edfaa370a2` | `git` — see below |
| Freeze script | `.github/workflows/Get-SupplyFreezeDigest.mjs` SHA-256 `13c2954aa3240ce087d62bec3ec0345eeb28c05a88bea5f54e1b182938b339f8` | script `script.sha256` |
| Node | `v24.18.1` | script `toolchain.node` |
| npm | `11.16.0` | script `toolchain.npm` |
| Platform | `linux` / `x64` | script `toolchain.platform`, `toolchain.arch` |
| Install umask | `0022` | script `toolchain.umask` |
| `package.json` | blob `2b88a0ac85d3a8b7286040e6b1f6c4ddb4d3bce1` | script `manifestBlobs` |
| `package.json` SHA-256 | `e206cdb3562f0397e8eed7fb2c2586269a1f5335cdff2906da8d5e070426321e` | script `manifest` |
| `package-lock.json` | blob `5c376ce2364e06c3ac4bc3ab8e3570e86b35f6ca` | script `manifestBlobs` |
| `package-lock.json` SHA-256 | `277f7168ab3a4f1f7a2565de13191d64b1572e7cb92b67b0972b3242bd4de062` | script `manifest` |
| Installed tree SHA-256 | `16f42788850678b04361c87009be01eefa2354358d40a30d03d4a23b1298eb2a` | script `installedTreeSha256` |
| Installed tree size | 2177 files, 8 symlinks, 336 directories, 0 special entries | script `installedTreeFiles`, `installedTreeSymlinks`, `installedTreeDirectories`, `installedTreeSpecials` |
| Advisory registry | `https://registry.npmjs.org/` | script `registry` |
| Advisory posture SHA-256 | `ea559555c8c18bd2488219d977a994fabc868c2d46efb05bbaf92405c53488e1` | script `auditSha256` |
| Advisory counts | `{"info":0,"low":0,"moderate":2,"high":5,"critical":0,"total":7}` | script `auditCounts` |

The three `git` rows are derived from the repository, not from a run of the script, and this is
how:

```bash
git rev-parse a308c860e078b661de0dd663be35f018fc60fdcc   # reviewed head that merged
git rev-parse 143f54e52075a1ae1e999a6e242073e3d8d4a46b   # merge commit
git rev-parse 143f54e52075a1ae1e999a6e242073e3d8d4a46b^{tree}   # merged tree
```

**Advisory counts are recorded in the shape the script emits**, not as prose. An earlier draft
wrote them as `0 critical, 5 high, 2 moderate, 0 low, 0 info`, which omitted npm's own `total`
and asked a consumer to compare a sentence against a JSON object. Exact equality against prose
is not mechanically checkable, and a compared field has to be.

**The three advisory rows are compared, and a mismatch there is a genuine equality failure.** An
earlier draft said drift in them "calls for a policy re-decision rather than a failed build",
which read as though they were exempt from the check — having it both ways, since this section's
own rule is that compared fields must match exactly.

They are not exempt. What differs is the correct *response* to a mismatch, not whether the check
fails:

| Compared field | A mismatch means | The consumer should |
| --- | --- | --- |
| Everything except the three advisory rows | the supply inputs are not the reviewed ones | stop and investigate the tree |
| Advisory registry, advisory posture, **advisory counts** | the published advisory database has moved | re-decide the policy under `T1-ADVISORY-DISPOSITION-v1` |

**Advisory counts belong in the second row**, and an earlier draft of this table left them in the
first. They are derived from the same changing database as the posture digest — indeed they are
folded into it — so a counts mismatch has the same cause and the same remedy. Filing them under
"investigate the tree" would have sent a consumer looking for tampering that did not happen. The
three advisory rows are exactly those whose `Derived by` column reads `registry`, `auditSha256`
or `auditCounts`; every other compared row takes the first response.

Concretely, for the consumer named in [Consumers](#consumers): issue #22 must treat an advisory
mismatch as a **blocking check that needs a policy decision to clear**, not as evidence the
installed tree was tampered with, and not as something to wave through. The advisory rows
snapshot a database that changes as advisories are published, which is why the second row of
that table exists at all — the reasoning is in
[Advisory posture](#advisory-posture).

### Recorded, not compared

Recorded so a reader can diagnose a mismatch or understand the context. **Not** subject to
exact equality.

| Field | Value | Why it is not compared |
| --- | --- | --- |
| File permissions | `{"644":2157,"755":20}` | full modes are machine state |
| Directory permissions | `{"755":336}`, `node_modules` itself `755` | full modes are machine state |
| Policy decision | `T1-ADVISORY-DISPOSITION-v1`, bounded through issue #24 | no artifact exists to compare against |

**The policy decision was a compared field and should not have been.** `T1-ADVISORY-DISPOSITION-v1`
names a decision, not a value: no committed artifact carries that identifier, the recorder emits
no field for it, and a repository-wide search finds the string only in this document. A consumer
told to check it for exact equality has nothing to check it against, and no way to establish
whether it is still the applicable decision or what "bounded through issue #24" currently means.

That is the same defect as the install command, which the preceding revision moved out of the
compared table for being unobservable — and this row survived that same edit one line below it.
It is reclassified rather than deleted because the context is worth keeping, and rather than
invented as an artifact because minting a policy record is the repository owner's decision, not
a side effect of a change about digest reproducibility. The bound itself lives in issue #24.

A harmless `0644` → `0664` leaves the installed-tree digest byte-identical — measured — while
moving the histogram to `{"644":2156,"664":1,"755":20}`. Comparing it for
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
| `022` — reviewed | `{"644":2157,"755":20}` | the recorded digest |
| `027` | `{"640":2157,"750":20}` | differs |
| `077` | `{"600":2157,"700":20}` | differs |

The histogram is a **diagnostic hint, not a proof**. Any change to a file's mode moves it —
measured, a single `chmod g-r` under the reviewed umask turns `{"644":2157,"755":20}` into
`{"604":1,"644":2156,"755":20}`. A shape that differs from the record is therefore *consistent
with* a different install umask, and equally consistent with modes altered after the install;
it narrows the search rather than settling it.

An earlier draft counted **group-readable files** instead, and that was too weak to be a
backstop. `umask 027` clears `0o027`, which leaves group read set — `0o644` becomes `0o640` and
`0o755` becomes `0o750`, both still group-readable. Measured: a tree installed under `027` and
recorded under `022` moved the digest while the census still reported the recorded
`2177 of 2177`, so it was blind to one of the umasks the guard itself rejects. The
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

Every refusal names the observed and reviewed values on stderr.

**`--any-toolchain` does not bypass all of them, and this section said it did.** It waives the
*reviewed-environment and reviewed-input* guards — the ones asserting that this machine and these
files are the ones under review. It does **not** waive the *integrity-during-run* refusals, which
assert that nothing moved underneath the measurement while it was being taken. Those hold
regardless, because a bypassed run still emits a number, and a number taken over a tree that
changed mid-read is wrong under any flag. The `Bypassed` column below says which is which, per
row, rather than leaving it to a sentence that has already been wrong once.

| Exit | Refusal | Bypassed by `--any-toolchain` | Usual cause |
| ---: | --- | :---: | --- |
| `2` | Unreviewed toolchain or invocation | yes | different Node, npm, platform or architecture; or a symlinked entry point |
| `3` | Recorded input changed mid-run | **no** | `package.json`, `package-lock.json` or the script itself edited while the run was in progress |
| `4` | Unreviewed manifest | yes | `package.json` or `package-lock.json` has moved |
| `5` | Audit response is not a report | **no** | registry unreachable, or an endpoint error returned as JSON |
| `6` | Install-shaping npm configuration | yes | `bin-links`, `omit`, `package-lock-only`, `umask`, `omit-lockfile-registry-resolved` … from an `.npmrc` or the environment |
| `7` | Tree is not the installed tree | yes | `node_modules` absent, incomplete, or never installed |
| `8` | Unreviewed process umask | yes | recording shell is not at `0022` |
| `9` | Unreviewed advisory registry | yes | `registry` points at a mirror or proxy |
| `10` | Recorded inputs changed while recording | **no** | something wrote to `node_modules` or a manifest during the run |
| `11` | Tree contains special files | yes | a FIFO, socket or device node under `node_modules` |

A bypassed run marks its own output as explicitly not a freeze record — `freezeRecord: false`
with the reasons listed — in both output formats.

Exit `10` is the counterpart to exit `3` for the tree rather than the manifests, and it has two
independent detectors:

1. **The tree is folded twice**, once before `npm audit` and again after it. A mismatch means
   the bytes moved between the two reads. The audit is a network round trip — measured at about
   2.0s against a 0.1s fold — so that window is wide enough to matter, and the pair of folds
   brackets it.
2. **A stat-only quiescence sweep** runs after the second fold and refuses if any entry's inode
   change time is at or after the moment recording began.

The second detector exists because the first one has a hole, and an earlier draft of this
section did not admit it. Two folds detect a write that lands *between* their two reads of an
entry; a write that lands *after the second fold has already read* that entry leaves both folds
agreeing on bytes that are already stale. Measured, with the second fold paused just after it
read `node_modules/.package-lock.json`: writing to that file produced exit `0`, no refusal, and
the then-recorded digest reported for a tree whose file was 64829 bytes at emission against the
64794 bytes actually hashed.

The sweep uses inode change time rather than modification time deliberately. `utimes` lets any
caller set `mtime` to whatever they like, so `mtime` is forgeable; that same call moves `ctime`
*forward* to the moment of the attempt. Measured both ways.

**Neither detector makes this atomic, and none can.** A userspace sequential walk has no
snapshot to compare against, so a write landing after the sweep has passed a given entry is not
detected here. A filesystem-level snapshot closes it outright and is the right approach for a
reader whose host provides one; that is a property of the host rather than of this script.

Exit `11` refuses a tree containing a FIFO, socket or device node. `npm ci` creates only files,
directories and symlinks, so such an entry did not come from the install, and a freeze record
over it would describe something npm cannot have built. The fold distinguishes each kind and
folds the device number alongside, so the digest reported under `--any-toolchain` is honest even
though the refusal is bypassed there.

The audit is invoked with the validated registry passed on the command line, so the request
provably goes to the registry the record names. An earlier version read the registry in one npm
process and ran the audit in another, which left a window for a rewritten `.npmrc` to redirect
the audit while the record still named the reviewed registry.

Exit `9` applies only when the audit runs. The registry does not shape the installed tree —
every package in the lockfile carries an `integrity` hash and `npm ci` verifies each tarball
against it, so substituted bytes fail the install outright. Only the advisory posture is
exposed, which is why `--no-audit` records the lockfile-derived fields from any registry.

**The script's identity is bound to the run.** Its bytes are read as the first thing the script
does, re-compared after every other check, and its inode-change time is tested against process
start — so a replacement at any point during the run is refused rather than silently producing
the authoritative digest for code that did not derive these values.

**One window remains and cannot be closed from inside.** Node reads and compiles this file before
any statement in it executes. A replacement in *that* window is invisible to the script itself
and can only be closed by a trusted launcher that hashes the file before invoking `node`. That is
outside what a single read-only script can bootstrap, and it is stated here rather than implied
away.

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

### What is folded, per entry kind

This table is the authoritative definition. A reimplementer should be able to reproduce the
recorded digest from it without reading the script; the script is the reference implementation,
not the specification, and an earlier draft let the two drift — the file mask changed and this
description did not follow.

Entries are walked in sorted order by name. Every variable-length field is length-prefixed, which
is what makes the encoding injective.

| Entry kind | Tag | Fields folded, in order |
| --- | --- | --- |
| The `node_modules` root | `R` | its normalized execute bits (`mode & 0o111`); then, **only if it is not a directory**, tag `K`, the kind letter, and for a symlink its raw target bytes |
| File | `F` | relative path, normalized **read and execute** bits (`mode & 0o555`), content |
| Directory | `D` | relative path, normalized execute bits (`mode & 0o111`), then its entries |
| Symlink | `L` | relative path, raw target bytes |
| FIFO / socket / char device / block device | `P` / `S` / `C` / `B` | relative path, device number (`rdev`) |
| Any other entry kind | `?` | relative path, device number |

**Files carry read bits; directories carry only execute bits.** That asymmetry is deliberate. For
a file, read permission is what determines whether a class can load it, so it belongs in the
digest. For a directory, the execute bit is the traverse permission and read permission only
controls listing, which does not affect whether code beneath it loads.

**Write bits are folded for nothing.** They do not affect loadability and are the most
machine-variable of the three.

The **normalized permission bits** rather than the full mode. node-tar applies the
process umask when it extracts, so the read and write bits are a property of the extracting
machine, and recording the full mode would make the digest drift for a reason that has nothing
to do with the package.

**The execute bits are not umask-independent either, and an earlier draft of this document
claimed they were.** It argued that `0o755` under `umask 077` is still `0o700` and still
executable by its owner. The file does remain executable; the *recorded value* does not survive
— `0o755 & 0o111` is `0o111`, `0o700 & 0o111` is `0o100`. Measured: a full `npm ci` under
`umask 077` produces a different digest from the recorded one, a mismatch caused by nothing but
the reader's umask. So the **process** umask is **pinned at `0022` and checked**, making it
the sixth environmental input this record fixes, alongside Node, npm, platform, arch and npm
configuration. It is also the cheapest of the six to satisfy. npm's own `umask` config is a
seventh knob that lands on the same bits and is checked as part of npm configuration; the
paragraph below sets out why the two are not interchangeable.

**There are two umasks, they are independent, and both shape the tree.** The process umask is
invisible to `npm config list`, which is why it needs its own guard rather than an entry in the
configuration table. npm's own `umask` config is the other one; it defaults to `0` and npm
documents it as additive rather than a replacement — *"npm does not circumvent this, but rather
adds the `--umask` config to it."*

An earlier draft checked only the first and described the second as merely "a separate setting",
which read as though it were harmless. It is not. Measured, two real `npm ci` installs from the
identical lockfile with the process umask at `0022` in **both**:

| `npm config umask` | Histogram | Installed tree |
| --- | --- | --- |
| `0` — reviewed | `{"644":2157,"755":20}` | the recorded digest |
| `077` | `{"600":2156,"700":12,"755":8,"644":1}` | differs |

The second run then emitted a complete freeze record — `freezeRecord: true`, an empty
`notFreezeRecordBecause`, `matchesReviewedManifest: true`, and `umask 0022` printed in its own
toolchain block. The process-umask guard looked straight at it and was satisfied, because it
reads the other umask. `umask` is therefore now a checked entry in the configuration table, and
a run carrying `npm_config_umask=077` refuses with exit `6`.

**The install-time gap applies here too**, exactly as it does for `bin-links`. A tree installed
under `npm_config_umask=077` and recorded from a shell that no longer carries the setting passes
both umask guards — measured, exit `0` — because each reads the configuration in effect when the
script runs. The permission histogram is the backstop for that case, and the digest mismatch is
the alarm: `{"600":2156,"700":12,"755":8,"644":1}` against a recorded `{"644":2157,"755":20}`
names its own cause.

**Directories carry their normalized execute bits too, and for one round they did not.** A
directory's execute bit is its *traverse* permission, so clearing it for group or other makes
everything beneath unreachable for those classes while the packages themselves stay byte-perfect.
Measured before the fix: `0755` → `0745` → `0700` on a package directory left the digest and the
counts completely unchanged. The `node_modules` root is folded as well — the walk starts inside
it, so it was the one directory the fold could never have noticed, and clearing its traverse bit
locks out the whole tree at once. This is the same argument that put execute bits on files, one
entry kind over, and it moved the recorded digest.

**Read permission is folded alongside execute, and for one round it was not.** The fold masked
`mode & 0o111`, so `0644` → `0600` on an installed module was invisible: the owner running the
recorder can still read it and `npm ls` still passes, but a group or other user can no longer
load it. The histogram moves, but it is a *non-compared* diagnostic, so every compared field
stayed equal and a reviewed run would have emitted `freezeRecord: true` for a tree those users
cannot use. The mask is now `mode & 0o555` — read and execute together are exactly the "can each
permission class still load this" property. **Write bits stay out**: they do not affect
loadability and are the most machine-variable of the three.

**A symlinked `node_modules` root is refused.** `npm ci` creates the root as a real directory; a
symlink redirects where every installed module loads from while the contents behind it can be
byte-identical. The root's entry kind and link target are folded when it is not a directory, so
the number reported under `--any-toolchain` is honest, and a reviewed run refuses with exit `7`.
Measured here, `npm ls --all --json` already exits non-zero on a symlinked root, so that refusal
is defence in depth rather than the only thing standing between a reader and a wrong record —
but incidental protection that depends on an npm version is not what this record rests on.

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

**Special files were a second unstated exception, and are no longer one.** Entries that are
neither file, directory nor symlink used to fold to a bare tag and a path, so every such entry
at a given path hashed identically. Measured, all five of these at one path folded to a
single identical digest, and each now folds distinctly:

| Entry at `node_modules/__special` | Before | After |
| --- | --- | --- |
| FIFO | all five identical | five distinct digests |
| Unix socket | ″ | ″ |
| Character device `(1,3)` | ″ | ″ |
| Character device `(1,5)` | ″ | ″ |
| Block device `(7,0)` | ″ | ″ |

The two character devices differ only in minor number, which is the `/dev/null`-versus-
`/dev/zero` distinction, so the collision was not even confined to type. The census was blind to
all five as well, reporting the recorded 2177 files, 8 symlinks and 336 directories in every
case. The fold now records the kind and the device number, and a reviewed run refuses outright
with exit `11`; the count is reported as `installedTreeSpecials` so a bypassed run still names
the cause.

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
| A FIFO, socket or device node added under `node_modules` | yes, differently for each kind, and a reviewed run refuses with exit `11` |
| A directory's execute bit cleared for group or other (`0755` → `0745`) | yes |
| A file's read bit cleared for group and other (`0644` → `0600`) | yes |
| `node_modules` replaced by a symlink to a byte-identical tree | yes, and a reviewed run refuses with exit `7` |
| The `node_modules` root's own execute bits changed | yes |

### Advisory posture

Folds the identity of each advisory — package, severity, GHSA identifier, CWE list, CVSS score
and vector, affected range — plus the overall counts.

Deliberately excluded: advisory **titles**, because GitHub rewords them without the advisory
changing identity; **`fixAvailable`**, because it changes the day a fix ships upstream, which is
news but not a change to what this repository installs; and **`effects`/`nodes`**, because they
are derivable from the installed tree, and one change should not move two numbers.

**This digest is not reproducible from the lockfile alone, and is not meant to be.** It is a
snapshot of a published advisory database that changes over time. Drift here means the published
advisories moved.

**A mismatch is still an equality failure**, and this paragraph said otherwise until it was
corrected. It read "— not a failed build", which invited a consumer to wave the mismatch through;
the [compared fields](#compared-fields) section requires the opposite. The check fails; what
differs is the **response**, which is a policy re-decision under `T1-ADVISORY-DISPOSITION-v1`
rather than an investigation of the installed tree. A consumer treating this digest as a
*lockfile-derived* invariant will misdiagnose the cause — it is not evidence the tree moved — but
it must not therefore be treated as non-blocking.

## Consumers

Issue #22 consumes this record. Its equality requirement is discharged by re-running the script
above and comparing against the table, with the caveat on the advisory posture noted directly
above.
