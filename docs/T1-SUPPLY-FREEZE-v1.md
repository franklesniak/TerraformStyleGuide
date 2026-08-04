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
records the values and, for each one, what derives it: mostly the committed script
`.github/workflows/Get-SupplyFreezeDigest.mjs`, and for three repository facts a `git` command.
The [Compared fields](#compared-fields) table names the derivation per row, which is the
authoritative statement — an earlier draft asserted that the script derived everything, and it
did not.

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
| Freeze script SHA-256 | `198807ec584c787b98acdb08f64add2a19a0de607226fd93e36b8016434ba5f7` | script `script.sha256` |
| Node | `v24.18.1` | script `toolchain.node` |
| npm | `11.16.0` | script `toolchain.npm` |
| Platform | `linux` | script `toolchain.platform` |
| Architecture | `x64` | script `toolchain.arch` |
| Install umask | `0022` | script `toolchain.umask` |
| `package.json` | blob `2b88a0ac85d3a8b7286040e6b1f6c4ddb4d3bce1` | script `manifestBlobs` |
| `package.json` SHA-256 | `e206cdb3562f0397e8eed7fb2c2586269a1f5335cdff2906da8d5e070426321e` | script `manifest` |
| `package-lock.json` | blob `5c376ce2364e06c3ac4bc3ab8e3570e86b35f6ca` | script `manifestBlobs` |
| `package-lock.json` SHA-256 | `277f7168ab3a4f1f7a2565de13191d64b1572e7cb92b67b0972b3242bd4de062` | script `manifest` |
| Installed tree SHA-256 | `6061b674c7dbdaaec16a2c7f7016c70cfcaea32c76490ddd7edf88341ce3c3ce` | script `installedTreeSha256` |
| Installed tree files | `2177` | script `installedTreeFiles` |
| Installed tree symlinks | `8` | script `installedTreeSymlinks` |
| Installed tree directories | `336` | script `installedTreeDirectories` |
| Installed tree special entries | `0` | script `installedTreeSpecials` |
| Advisory registry | `https://registry.npmjs.org/` | script `registry` |
| Advisory posture SHA-256 | `ea559555c8c18bd2488219d977a994fabc868c2d46efb05bbaf92405c53488e1` | script `auditSha256` |
| Advisory counts | `{"info":0,"low":0,"moderate":2,"high":5,"critical":0,"total":7}` | script `auditCounts` |

> **One compared row cannot be discharged as recorded.** `Advisory posture SHA-256` was taken under
> the advisory normalization that preceded round 47, and the committed script does not reproduce it
> from any report, including a byte-identical one. The row is still compared and a mismatch is still
> an equality failure — but the check cannot pass until the value is re-taken on a networked run.
> A consumer reaching this row today should treat it as **blocked pending re-record**, not as
> passing and not as waived. The full reasoning, and what does *not* follow from it for the
> lockfile-derived rows around it, is in [Advisory posture](#advisory-posture).

The three `git` rows are derived from the repository, not from a run of the script, and this is
how. Note the **`^2`**: an earlier draft wrote `git rev-parse <the recorded head>`, which takes
the value being checked as its own input and resolves it back to itself — it proved nothing. The
second parent of the named merge is what actually establishes which reviewed head that merge
incorporated, so the check no longer depends on the value it is meant to verify.

```bash
git rev-parse 143f54e52075a1ae1e999a6e242073e3d8d4a46b^2  # reviewed head that merged
git rev-parse 143f54e52075a1ae1e999a6e242073e3d8d4a46b   # merge commit
git rev-parse 143f54e52075a1ae1e999a6e242073e3d8d4a46b^{tree}   # merged tree
```

**The installed-tree digest was re-taken when directory read bits were folded in.** The recipe
changed in the same commit as the value: directories and the `node_modules` root now fold
`mode & 0o555` rather than `mode & 0o111`, matching what files have folded since the read bits
were added to them. The previously recorded `16f42788…` was taken under the old mask and this
script no longer reproduces it from the same tree. Unlike the [advisory
posture](#advisory-posture), this row is a pure function of the bytes and modes on disk, so it
was recomputed directly from the reviewed tree rather than left open: the same 2177 files, 8
symlinks and 336 directories fold to the value above, and every other tree row is unchanged. A
consumer holding the old digest should expect it to differ and compare against the new one.

**Advisory counts are recorded in the shape the script emits**, not as prose. An earlier draft
wrote them as `0 critical, 5 high, 2 moderate, 0 low, 0 info`, which omitted npm's own `total`
and asked a consumer to compare a sentence against a JSON object. Exact equality against prose
is not mechanically checkable, and a compared field has to be.

**One row holds one value from one key**, and two rows had to be split to satisfy that. The rule
above was written for the advisory counts and then left violated twice in the same table: the
installed-tree census read `2177 files, 8 symlinks, 336 directories, 0 special entries` — a
sentence a consumer had to parse — and the platform row packed `linux` and `x64` into one
slash-separated cell. Both are now one row per emitted key, matching every other script-derived
row.

Encoding the census as a single JSON object was the reported suggestion and was **not** taken.
The script emits four separate keys and no combined object, so such a row would document a value
no `--json` key produces, leaving a consumer to assemble it by hand from a shape this document
invented. That is the unverifiable-derivation defect this record exists to retire, reproduced in
the fix for a different one.

**That fix was applied to this table and stopped there, which is the same mistake one level up.**
The rule is a rule about every table in this document, and the round after it was written a
reviewer found it still violated in [Recorded, not compared](#recorded-not-compared) — a
directory-permissions cell holding two values from two keys. Re-sweeping every table then turned
up a third instance still sitting *here*: the freeze-script row put the path and the label
`SHA-256` in the value cell alongside the hash, so the one field a consumer must compare
byte-for-byte was wrapped in prose. The path is stated throughout this document and belongs in the
field name, not in the value. Fixing the instance that was reported, and calling it the class,
is the specific habit this record keeps having to correct.

Two tables are deliberately exempt, because they record no comparable values: the entry-kind
legend under [What is folded, per entry kind](#what-is-folded-per-entry-kind), whose rows group four
special-file kinds that share one treatment, and the detection-evidence table below it, whose
value column holds measured answers rather than recorded fields.

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
exact equality. Every row below carries a value. One field the script emits has none for this
record, and it is described in [A field this record does not carry](#a-field-this-record-does-not-carry)
rather than given a row here.

| Field | Value | Derived by | Why it is not compared |
| --- | --- | --- | --- |
| File permissions | `{"644":2157,"755":20}` | script `installedTreeModes` | full modes are machine state |
| Directory permissions | `{"755":336}` | script `installedTreeDirectoryModes` | full modes are machine state |
| `node_modules` root mode | `755` | script `installedTreeRootMode` | full modes are machine state |
| Policy decision | `T1-ADVISORY-DISPOSITION-v1` | this document | no artifact exists to compare against; bounded through issue #24 |

### A field this record does not carry

`auditEnvironmentScrubbed` is emitted by the current script but has no value in this record, so it
has no row in the table above.

**It had one for four rounds, and that was the defect.** The row sat in a table of recorded values
holding no value, and reviewers read the contradiction rather than the four paragraphs answering
it: the cell said the field was not captured, then that it had no value, then that it was not
recorded in this freeze — three wordings, each reported in turn. Rewording a row that should not
have been in that table is answering the shape shown, which is the habit this document keeps
finding in its own script. The row is gone; what it was trying to say is below.

An earlier draft filled its Value column with the key name and
two hypotheticals — the key name, then `[]` or `["NODE_OPTIONS"]` offered as examples — which
records nothing: a reader learns what the field is called and what it might have said, not what it
did say. The obvious repair is to write `[]`, and that is **not** what happened here, because it
would be untrue for this record.

*Not recorded* is not the same as *no value*, and the distinction is the one this script enforces
in code. An empty list is a value: it asserts that the scrub ran and removed nothing. This record
cannot assert that, so calling it "no value" would blur absence into emptiness — the same
conflation the advisory guard refuses when it rejects a missing `via` key that an earlier version
quietly turned into `[]`.

The current script does always emit the key — `[]` under `--no-audit`, a sorted list otherwise —
and two independent reviewers read that as contradicting this record. It does not, and the reason
is checkable rather than asserted: the field was added to the script *after* these digests were
taken. The commit that recorded the advisory posture above (`8905ba3`) is an ancestor of the
commit that introduced `auditEnvironmentScrubbed` (`bdbfb81`), which `git merge-base --is-ancestor`
confirms, so the run that minted this record could not have emitted the field and no observed
value exists. A later reviewer asked for the value observed in the same run that produced the
recorded `auditSha256` — there is no such observation to record. Writing a plausible-looking `[]` would be a value invented to fill a
column — the same fabrication the advisory-identity guard was tightened to refuse, committed in
the record instead of in the code.

The field is per-run in any case: it describes the environment of whoever executes the script, so
a reader's own run reports their own list, not this one. On a clean environment that list is `[]`.
That is what a reader should expect to see; it is not a value this record can claim was observed.

**`auditEnvironmentScrubbed` lists names only, never values.** A `NODE_EXTRA_CA_CERTS` path or a
proxy URL can carry a hostname, a username, or a token, and this record is published. An empty
list is the ordinary result. A non-empty one is not an error: it says the ambient environment
carried something that could have steered the audit at a trust boundary, and that the answer
recorded below was taken with that variable removed rather than under it. It is deliberately not
folded into `auditSha256` — the advisory posture is a statement about what the registry said,
while this is a statement about the machine that asked.

The candidates are the inputs that can redirect or disable TLS trust for the process that asks:
`NODE_EXTRA_CA_CERTS`, `NODE_USE_SYSTEM_CA`, `NODE_TLS_REJECT_UNAUTHORIZED`, `SSL_CERT_FILE`,
`SSL_CERT_DIR`, `OPENSSL_CONF`, `OPENSSL_MODULES`, `OPENSSL_ENGINES`, the proxy variables, any
`npm_config_*` naming a transport setting pinned to null — and `NODE_OPTIONS`, which is removed
**whole** rather than filtered.

The three `OPENSSL_*` names were swept for rather than reported, and are listed with their
evidence rather than beyond it. Node **does** read `OPENSSL_CONF` — measured, a malformed file
makes it exit with `node: OpenSSL configuration error` before any script runs — and OpenSSL finds
providers and engines through the other two, an activated provider being able to supply the
primitives that verify signatures. What was **not** demonstrated is that the file can steer this
process's TLS: a config setting `MinProtocol` to `TLSv1.3` left a TLSv1.2 handshake negotiating
TLSv1.2 unchanged, through both the `system_default` and `nodejs_conf` sections, because Node
sets its TLS parameters programmatically and those take precedence. Loading a hostile provider
was not attempted. They are scrubbed anyway because removing them costs three lines, and the
alternative is depending on Node continuing to override a file it demonstrably parses. Earlier revisions
stripped named CA flags out of it and were incomplete twice running; `--use-system-ca=true` and
four other accepted spellings survived a filter written for `--use-system-ca`. The deeper reason
to drop it is that no list of trust flags could have been sufficient, because `--require` and
`--import` preload arbitrary code into the very process that produces the audit answer. The cost
is that an ambient `--max-old-space-size` does not reach the audit child; when that happens the
name appears in this field rather than passing silently. This applies to the audit child only —
a run under `--any-toolchain` uses its own transport and says so in `notFreezeRecordBecause`.

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
env -u NODE_OPTIONS node Get-SupplyFreezeDigest.mjs
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
strIsolationDirectory="$(mktemp -d)"
: > "$strIsolationDirectory/npm-user-empty"
: > "$strIsolationDirectory/npm-global-empty"
export NPM_CONFIG_USERCONFIG="$strIsolationDirectory/npm-user-empty"
export NPM_CONFIG_GLOBALCONFIG="$strIsolationDirectory/npm-global-empty"
npm ci --ignore-scripts --no-audit --no-fund
env -u NODE_OPTIONS node Get-SupplyFreezeDigest.mjs
```

**The isolation must cover the recorder, not just the install.** An earlier draft passed
`--userconfig` and `--globalconfig` as flags to `npm ci` alone. Those flags apply to that one
invocation, and the script then runs `npm config list --json` without them, reloads the ambient
files, and refuses with exit 6 — against a tree it had just installed correctly. Measured: with
`bin-links=false` in an ambient user `.npmrc`, the flag form installed the correct 8 symlinks
and the recorder still exited 6, so the documented workaround could not be completed. The
environment variables above are read by every npm invocation, which is why they are used
instead.

**Use `mktemp -d`, not fixed paths in `/tmp`.** An earlier draft of these instructions named
`/tmp/npm-user-empty` and `/tmp/npm-global-empty` outright. On a shared host any other user can
pre-create those names as symlinks pointing at a file the reader can write, and `: >` follows a
symlink — so running the documented command would truncate that target with the reader's
permissions. `mktemp -d` creates a fresh directory with a name the attacker cannot predict and
permissions only the owner holds, so the two files inside it cannot be pre-empted. Remove it with
`rm -rf "$strIsolationDirectory"` once the record is taken.

**The two paths must be different files.** An earlier draft pointed both options at `/dev/null`,
and `npm ci` then exits 1 before the install starts — not because `/dev/null` is unusable as a
config file, but because the same *path* was given for two different layers. npm de-duplicates
configuration files by resolved path: it records
each file it loads against the layer that loaded it, and refuses to load one path as two
different layers. Passing the same path as both `user` and `global` therefore makes `npm ci`
exit 1 with `double-loading config "/dev/null" as "global", previously loaded as "user"` before
the install starts. Any single path used twice fails the same way — `/dev/null` is not special,
and the rule is about path identity rather than the file's contents.

**Both spellings must be unset.** Environment variable names are case-sensitive on POSIX, npm
reads either casing, and tooling commonly exports the upper-case form — so clearing only
`npm_config_bin_links` leaves `NPM_CONFIG_BIN_LINKS` in force while looking as though the
environment were clean.

**This isolates configuration files, not the environment.** Measured: with
`npm_config_bin_links=false` exported, the command above still installs 0 symlinks, because an
`npm_config_*` environment variable outranks the empty files. Scrub the environment as well when
that matters:

```bash
env -u npm_config_bin_links -u NPM_CONFIG_BIN_LINKS npm ci --ignore-scripts --no-audit --no-fund
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
| `2` | Unreviewed toolchain | yes | different Node, npm, platform or architecture; a symlinked entry point; or `NODE_OPTIONS` set — see [What this script cannot check about itself](#what-this-script-cannot-check-about-itself) |
| `2` | Unrecognized invocation | **no** | an argument the script does not support; `--any-toolchain --bogus` still exits `2` |
| `3` | Recorded input changed mid-run | **no** | `package.json`, `package-lock.json` or the script itself edited while the run was in progress |
| `4` | Unreviewed manifest | yes | `package.json` or `package-lock.json` has moved |
| `5` | Audit response is not a report | **no** | registry unreachable, an endpoint error returned as JSON, or a document that is not shaped like an audit report — including a report version that is not a positive safe integer, or a severity count that is not a nonnegative safe integer, since past 2^53-1 two different reported numbers stop being distinguishable. Advisory fields are refused the same way when their type or range cannot be compared — a `cvss.score` must be a finite number in the CVSS range 0–10, because a non-finite score serializes as `null` and would record as an absent one |
| `5` | Advisory posture contradicts itself | **no** | a severity outside npm's five recognized levels, or counts whose buckets do not sum to `total` — a posture whose own arithmetic disagrees cannot be compared exactly |
| `5` | Normalization did not cover every reported package | **no** | the normalized package map holds fewer entries than the report had vulnerability records, so the digest would be taken over a shorter set than the counts describe |
| `5` | Advisory has no usable identity | **no** | an advisory record carrying neither a GHSA url nor a positive safe-integer source id. An id past 2^53-1 is refused here too: two different reported ids stop being distinguishable at that size, so both would be recorded as one identity |
| `6` | Install- or trust-shaping npm configuration | yes | `bin-links`, `omit`, `package-lock-only`, `umask`, `omit-lockfile-registry-resolved`, and the transport settings `proxy`, `https-proxy`, `noproxy`, `ca`, `cafile`, `strict-ssl` … from an `.npmrc` or the environment. Also raised, self-diagnosing, if the transport scrub itself failed to bind the audit environment |
| `7` | Root missing or not a directory | **no** | `node_modules` absent, or present as a file or a symlink to one |
| `7` | Root is a symlink to a directory | yes | `node_modules` replaced by a symlink whose target is a real directory, which redirects where every installed module loads from while the contents behind it stay byte-identical. Refused by `lstat` before the tree is walked, so an arbitrarily large target is not scanned first. Under `--any-toolchain` the target is folded instead, with the **target's** normalized bits recorded as the root mode |
| `7` | Tree does not satisfy the lockfile | yes | `node_modules` incomplete or never installed; or `npm ls` answered about a tree other than this one. The refusal names which |
| `8` | Unreviewed process umask | yes | recording shell is not at `0022` |
| `9` | Unreviewed advisory registry | yes | `registry` points at a mirror or proxy |
| `10` | Recorded inputs changed while recording | **no** | something wrote to `node_modules` or a manifest during the run |
| `11` | Tree contains special files | yes | a FIFO, socket or device node under `node_modules` |
| `11` | Tree contains links that leave it | yes | a symlink under `node_modules` resolving outside it — typically a package directory replaced by a link to an external tree |
| `11` | Tree contains links it cannot resolve | yes | a symlink under `node_modules` whose resolution fails for any reason, so containment is unproven rather than satisfied |
| `12` | Tree contains an undecodable entry name | **no** | an entry under `node_modules` whose name is not valid UTF-8. Such a name decodes to U+FFFD, so a sibling named U+FFFD shares the decoded name and both resolve to one file — the other is never read and never reaches the digest. Refused rather than folded, because the alternative is a digest over a tree the script did not measure. The check is a byte round trip, so a file legitimately named U+FFFD still folds |

A bypassed run marks its own output as explicitly not a freeze record — `freezeRecord: false`
with the reasons listed — in both output formats.

Exit `10` is the counterpart to exit `3` for the tree rather than the manifests, and it has two
independent detectors:

1. **The tree is folded twice**, once before `npm audit` and again after it, and **every field
   the fold returns is compared, not the digest alone**. That distinction is load-bearing: the
   digest folds `mode & 0o555`, so the write and setuid/setgid/sticky bits sit outside it by
   design, and the mode histograms are therefore not derivable from it. Measured, `0644` and
   `0664` both fold to `444` while landing in different histogram buckets — so a group write bit
   added between the folds moves `modes` and leaves both digests equal, and comparing only the
   digest would emit the first fold's histogram for a tree it no longer described. The audit is a
   network round trip — measured at about 2.0s against a 0.1s fold — so that window is wide
   enough to matter, and the pair of folds brackets it.
2. **A stat-only quiescence sweep** runs after the second fold and refuses if any entry's inode
   change time *differs* from that same entry's own baseline reading, taken from the same
   filesystem before recording began — or if an entry appeared or disappeared between the two
   sweeps. The predicate is inequality, not lateness: a stamp that moves *backward*, which a
   clock-skewed or backdated filesystem can produce, is refused on the same footing as one that
   moves forward. That is the whole reason the comparison is per entry rather than against a
   single newest-ctime ceiling, since a ceiling can only ask whether a stamp is later than it.

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

**Both sides of that comparison come from the filesystem**, and an earlier version compared one
side against `Date.now()` instead. Linux stamps inode times from the coarse clock and truncates
them to the filesystem's granularity, while `Date.now()` reads the fine one, so the stamp was
systematically backdated relative to the ceiling it was tested against. Measured on ext2/ext3,
writing 2000 files each strictly *after* capturing the ceiling: **2000 of 2000 landed below it**,
by up to 4.13 ms. Every write inside that window was missed.

Rounding the ceiling down to cover the gap was measured and rejected — it breaks the documented
`npm ci && node ./Get-SupplyFreezeDigest.mjs` sequence, because the install that just finished
then trips the refusal. Comparing a filesystem stamp against a filesystem baseline needs no
margin and no assumption about granularity.

**A residual remains, and no ctime comparison can close it.** Any such check is blind below the
filesystem's timestamp granularity: an entry written once before the baseline and again after the
second fold, both within one tick, carries the same stamp on both reads. On ext3 a tick is a
full second. The double fold is what covers that case, by comparing bytes rather than times. The
two detectors are complements, not redundancy, and neither substitutes for the other.

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

### What this script cannot check about itself

**One window remains and cannot be closed from inside.** Node reads and compiles this file before
any statement in it executes. A replacement in *that* window is invisible to the script itself
and can only be closed by a trusted launcher that hashes the file before invoking `node`. That is
outside what a single read-only script can bootstrap, and it is stated here rather than implied
away.

**`NODE_OPTIONS` is the same window, reachable without touching the file at all**, and it is the
reason the documented command now begins `env -u NODE_OPTIONS`. A preload named by that variable
runs before the first statement here, so it can replace every answer before it is computed.
Measured: a preload that patches `child_process.execFileSync`, calls
`module.syncBuiltinESMExports()` and redefines `process.version` turned a run that correctly
refuses with exit `2` on an unreviewed Node into a complete record reporting
`freezeRecord: true`, an empty `notFreezeRecordBecause`, `treeSatisfiesLockfile: true`,
`matchesReviewedManifest: true`, and an advisory posture of all zeros — erasing the seven real
advisories. Nothing downstream could have caught it, because the forgery is upstream of
everything.

The script refuses when it sees `NODE_OPTIONS` set, and **that refusal is hygiene, not a security
boundary.** Code that runs first wins: a preload whose last line is
`delete process.env.NODE_OPTIONS` leaves the check reading `undefined`, which was measured
alongside the forgery above. What the refusal is worth is the accidental case — a runner or shell
that exports `NODE_OPTIONS` for unrelated reasons no longer quietly shapes a freeze record. What
actually closes the hole is clearing the variable *before* `node` starts, which only the caller
can do.

**The audit child's transport is bound against three of npm's four configuration sources, not
four.** npm takes settings from the command line, the environment, and project, user and global
`npmrc` files, in that precedence order. The command line outranks everything, so the settings
that have a non-null reviewed value — `noproxy` and `strict-ssl` — are passed as flags and cannot
be overridden by any file. The four with a null reviewed value — `proxy`, `https-proxy`, `ca` and
`cafile` — have no flag available: measured, `--proxy=` does not clear a proxy but is *inert*, npm
warns `invalid config` and keeps the value the file supplied. Those four are bound instead by
removing the matching variables from the child's environment and by pointing `--userconfig` and
`--globalconfig` at two sources that cannot carry settings, which closes the environment, user and
global sources.

Those two substitutes are `/dev/null` and a path *beneath* `/dev/null`. The second is not a path
merely assumed to be absent — an earlier version used `/nonexistent/supply-freeze-globalconfig`
and that was a defect, because npm reads the file if it happens to exist and the assumption is
weakest exactly where this script runs: measured in the verification container, the process is
uid 0 and `mkdir /nonexistent` succeeds. `/dev/null` is a character device, so every path beneath
it is `ENOTDIR` for every user including root — measured, both `mkdir` and `touch` refuse — which
makes the source empty by construction rather than by assumption. Two distinct paths are required
because npm rejects the same config file twice with `double-loading config`, and it compares
*resolved* paths: `/dev/../dev/null` collides with `/dev/null`.

**The project `npmrc` is the fourth, and it is not closed by construction.** It is read from the
directory the audit child runs in, and npm offers no flag that relocates that source. What covers
it is a check rather than a construction: the transport comparison runs `npm config list --json`
in the same directory, so a committed `.github/workflows/.npmrc` is visible to it — measured, a
proxy set there appears in that output — and the run refuses with exit `6`. What remains is a
project `npmrc` **created in the window between that check and the audit invocation**, which
requires writing into the repository working directory mid-run. That is the same residual class as
the preload above: an actor who can do it already runs code on the host, and the check is worth
what it is worth against the accidental case.

**A symlink under `node_modules` may not resolve outside it.** The fold hashes a link's target
*text*, never the bytes behind it, which is right for the eight `.bin` shims a normal install
creates — they point back into the tree, so the bytes they reach are folded at their real location
and editing them does move the digest. A target *outside* the tree is different in kind: those
bytes are never read, so the digest is silent about code that actually loads. Measured, with
`node_modules/eastasianwidth` replaced by a link to an external directory holding a minimal
`{"name","version","main"}` manifest: `npm ls --all` exits `0`, `treeSatisfiesLockfile` comes back
`true` so the exit-`7` refusal never fires, a digest is recorded at exit `0` — and rewriting the
code behind that link afterwards leaves the digest byte-identical. Such a tree is now refused with
exit `11`.

The boundary is *where the link reaches*, not that it is a link, and it is checked against the
fully resolved root so that a chain leaving in two hops is caught and a legitimately symlinked
`node_modules` root is not mistaken for an escape.

The refusal names the link's in-tree path and **not** its resolved target. The target is chosen by
whoever wrote the link, is unbounded in length, and can carry a username, an internal directory
layout or a path-borne token into a CI log that outlives the run — the same names-only rule this
document states for the trust variables and the advisory registry. The target is dropped where it
is *collected* rather than where it is printed, so no later edit to the refusal can reintroduce it.
An operator with access to the tree recovers the target with `ls -l` on the name reported.

**A symlink under `node_modules` whose resolution fails is refused, not skipped.** Containment is
the claim the rule above makes, and a link that cannot be resolved is one whose containment was
never established; an unproven claim is refused rather than assumed. This is deliberately *any*
failure and not only a missing target, because the defect it replaces was precisely the assumption
that one error class was harmless. Measured, with a nested link pointing at an absent external
path: `npm ls` reports the lockfile satisfied — the link is nested, so the top-level dependency set
still matches — both folds complete, and the run recorded a digest at exit `0` with no refusal. The
target could then be created for exactly as long as the code needed to load and removed again, and
a second run agreed at exit `0` with a byte-identical digest, because a link's *text* does not
change when the thing it points at appears and disappears. The `lstat`-based quiescence sweep
cannot see this: `lstat` reports the link's own inode and never the target's. Both such links are
now refused with exit `11`, reporting the in-tree name and the `errno` code only.

**The symlinked-entry-point refusal names neither the invoked path nor its target.** Whoever
creates that link chooses its name as well as where it points, so both strings are attacker-chosen;
a link named `USER_token-SUPPLYSECRET.mjs` put that string verbatim into the refusal, and CI
retains logs. Neither is printed now. Nothing is lost by it: whoever ran the command already knows
the path they typed, and the target is this file.

**The normalized advisory map is built with a null prototype, and its size is checked.** A package
named `__proto__` assigned into an ordinary object invokes the prototype *setter* instead of
creating an own property, so the record vanished while the raw report still carried `__proto__` as
an own key — the count cross-check therefore agreed with `total: 1` and the run exited `0` over a
digest that omitted the only package. Measured by varying `range`, a field the counts do not depend
on: with the name `__proto__` the digest was `5438d3f5…` for both `<1.0.0` and `<9.9.9`, identical,
while an ordinary name moved it. A null prototype removes this for every inherited name rather than
the one that was reported, and `JSON.stringify` treats such an object identically, so the recorded
`auditSha256` for a real report does not move — verified by running the same report through both
versions and comparing.

The size check is the half that generalizes. It refuses when the normalized map holds fewer entries
than the report had records, whatever the cause, so a future edit that drops a package fails closed
instead of silently shortening the set the digest is taken over.

**The quiescence sweep follows a manifest's whole symlink chain, but not symlinked directory
components.** Where a manifest resolves through several links — `package.json` → `mid` → `real` —
every hop is stat'd individually, because collapsing the chain with `realpathSync` left the middle
of it unwatched: measured, repointing `mid` alone changed the bytes read through `package.json`
while the outer link's `lstat` ctime and the original target's `stat` ctime both stayed put, so the
swap moved no value the sweep collected. Each hop now appears in a refusal by name, as
`package.json (link hop 1)`.

What is still outside it is a symlinked *directory* component of the path. Closing that would mean
stat'ing every parent directory up to `/`, whose change times move for reasons that have nothing to
do with this record — a check that refuses correct runs is not a stricter check, so the boundary is
drawn at the leaf's own chain and stated here instead.

**The permission fold measures POSIX mode bits, and nothing else.** A tree can be made unloadable
by mechanisms `stat` does not report: POSIX ACLs — a named-user entry denying read leaves `0644`
and the bytes untouched — and equally SELinux or AppArmor labels, a `noexec` mount, or
`chattr +i`. None of these move the installed-tree digest or the permission histograms.

This is stated rather than fixed, and the reason is that the available fix is worse than the
statement. Node exposes no ACL or extended-attribute API, so detection means shelling out to
`getfacl`, which is not universally installed — measured absent on the container these
verifications were run in. A guard that silently does nothing wherever the `acl` package is
missing would let a reader believe extended ACLs were checked when on many hosts nothing looked,
which converts an honest blind spot into a false assurance. ACLs are also only one member of the
set above, so the useful boundary is to say what the fold measures rather than to chase one
mechanism and leave its siblings unmentioned.

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

Folds the bytes actually present under `node_modules`: every file's path, normalized **read and
execute** bits and content; every symlink's path and raw target; every directory's path and
normalized **read and execute** bits; every special file's path, kind and device number; and the
root's own **read and execute** bits — in sorted order. The table below is the exact definition;
this sentence is a summary of it and has three times been left behind when the fold changed.

### What is folded, per entry kind

This table is the authoritative definition. A reimplementer should be able to reproduce the
recorded digest from it without reading the script; the script is the reference implementation,
not the specification, and an earlier draft let the two drift — the file mask changed and this
description did not follow.

#### The byte encoding

Without this, "length-prefixed" admits several incompatible encodings that all satisfy the prose
and produce different digests. The hash is SHA-256 over a single byte stream built as follows.

* A **tag** is one ASCII character, written with no separator around it.
* A **length-prefixed field** is the field's byte length in ASCII decimal, then a single `:`
  (`0x3A`), then exactly that many bytes. Nothing separates one field from the next.
* **Paths** are the entry's path relative to `node_modules`, `/`-separated, with no leading
  slash, encoded UTF-8.
* **Permission masks** are the masked mode as a three-character, zero-padded, lower-case octal
  ASCII string — `0o755 & 0o555` is written `555`, `0o644 & 0o555` is written `444` — and that
  string is then length-prefixed like any other field.
* **Device numbers** are the raw `rdev` integer in ASCII decimal, length-prefixed.
* **Symlink targets** are the raw bytes the kernel stored, never a decoded string.
* **File content** is the file's bytes, length-prefixed.

Directory entries are emitted in ascending order of name, compared as JavaScript strings — that
is, by UTF-16 code unit — and a directory's own record is written before the records of the
entries beneath it.

Entries are walked in sorted order by name. Every variable-length field is length-prefixed, which
is what makes the encoding injective.

| Entry kind | Tag | Fields folded, in order |
| --- | --- | --- |
| The `node_modules` root | `R` | the normalized **read and execute** bits (`mode & 0o555`) of the directory **the walk actually traverses**, resolved through a symlink if the root is one; then, **only if the root itself is not a directory**, tag `K`, the kind letter, and for a symlink its raw target bytes |
| File | `F` | relative path, normalized **read and execute** bits (`mode & 0o555`), content |
| Directory | `D` | relative path, normalized **read and execute** bits (`mode & 0o555`), then its entries |
| Symlink | `L` | relative path, raw target bytes |
| FIFO / socket / char device / block device | `P` / `S` / `C` / `B` | relative path, device number (`rdev`) |
| Any other entry kind | `?` | relative path, device number |

**Files, directories and the root all carry read and execute bits.** For a file, read permission
is what determines whether a class can load it. For a directory the two bits are different
powers: execute is traverse-to-a-known-name, and read is permission to *list*.

This document previously said the asymmetry was deliberate — "directories carry only execute
bits… read permission only controls listing, which does not affect whether code beneath it
loads" — and that reasoning was wrong on its own terms. Listing is how package discovery works.
Measured on `node_modules/glob`, `0755` → `0711` left the digest and every compared field
unchanged while a non-owner got `EACCES` from `readdir` on it and could still read a known path
through it: the tree stayed loadable by exact path and stopped being enumerable, so any
glob-based discovery breaks for that class while the record still certifies the freeze. The
`node_modules` root is the same defect at full scale — at `0711` no other class can list *any*
package. Both now fold `mode & 0o555`, the same mask as files, for the same "can each permission
class still use this" property.

**Write bits are folded for nothing.** They do not affect loadability and are the most
machine-variable of the three.

**The root's bits are read through the symlink, not off it.** A reviewed run never reaches this
case — a symlinked root refuses with exit `7` — but `--any-toolchain` folds one anyway, and the
measurement it produces has to be honest. Taking the mode off the link records `0777`, which is
what every symlink on Linux carries, so the traversed directory's permissions went unmeasured:
changing the target from `0755` to `0700`, locking every other user out of the whole tree, left
the digest and both histograms byte-identical. Resolving first fixes that and cannot move the
frozen digest, because for a root that is an ordinary directory the two reads return the same
mode.

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

**Their read bits followed a round later, and the gap had the same shape.** Adding execute bits
to directories closed traverse and left *listing* open: measured, `0755` → `0711` on a package
directory moved nothing compared, while a non-owner got `EACCES` from `readdir` and could still
read a known path through it. Directories and the root now fold `mode & 0o555` like files. This
moved the recorded digest a second time, and the reasoning for that re-take is recorded with
the [compared fields](#compared-fields).

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

**Path components are folded as UTF-8-decoded names, and a name that does not survive that
decode is refused rather than folded.** Directory entries would otherwise come back from
`readdirSync` decoded the same lossy way, so a filename holding non-UTF-8 bytes would collide by
the identical mechanism — a sibling genuinely named U+FFFD would share the decoded name, both
would resolve to one file, and the other would never be read or reach the digest.

An earlier version of this paragraph said that case was **knowingly left to collide**, on the
reasoning that reading entries as raw bytes would move the recorded digest to guard something npm
cannot produce. That is no longer what the script does, and the paragraph outlived the change: both
walkers now enumerate entries as raw buffers and refuse with exit `12` when a name fails a **byte
round trip** — decode to UTF-8, re-encode, compare against the original bytes. The check is the
round trip rather than a U+FFFD search, so a file *legitimately* named U+FFFD re-encodes to its own
bytes and still folds; only names that lose information are refused. See the exit `12` row in
[Why a run was refused](#why-a-run-was-refused) and the corresponding mutation-table row, which
describe the same refusal.

A symlink target remains different in kind, being an arbitrary byte string npm writes rather than a
validated name, which is why that one is folded byte-exact instead of being refused. The fold's
injectivity claim can therefore be read without a decoding caveat attached: a tree whose names
cannot be decoded unambiguously is not folded at all.

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

**Reproducible from the lockfile and every pinned environmental input**, which means all six:
the Node and npm versions, the platform and architecture, the npm configuration, and the process
umask. An earlier draft of this sentence named only the lockfile and the platform, which
contradicted both the guards and this document's own measured examples — a different npm version,
an `npm_config_umask`, a `bin-links=false`, or a different process umask each move the digest on
an otherwise identical lockfile and platform. Four independent `npm ci`
installs in four different absolute paths produce the identical digest, which also
demonstrates that no machine-specific path leaks into the hashed bytes.

The four paths differ in length and in shape — `alpha`, `bb`, `c-c-c`,
`dddd-longer-path` — so a leaked path would have to collide across all four to go unnoticed. This
said "three" while the pull request description said "four", and the reported fix was to write
"multiple" so that neither could be wrong. The count is the evidence, so the disagreement was
settled by re-running the experiment instead: four installs, four paths, one digest.

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

**`npm ls` is still run, and its exit code alone is not trusted.** It answers one question the
byte fold cannot — whether the tree on disk satisfies the lockfile — but *which* tree it answers
about is steered by ambient configuration, and four separate settings have been found doing
exactly that. `omit` made it pass against a tree that was missing entirely; `package-lock-only`
made it read the lockfile's virtual tree instead of the disk; `depth=0` made it check direct
dependencies only; and `global` and `link` respectively pointed it at the host's global tree and
reduced it to the root alone. Each was found only after the previous one was closed, so naming
flags is treated as necessary and not sufficient. All of them are pinned on the command line, and
then the **answer** is checked: `--long` makes npm report the absolute path of the tree it walked,
which must resolve to this directory, and the top-level dependency names it reports must equal
the set `package.json` declares. A future setting that redirects the tree fails the first check;
one that empties it fails the second; and `treeSatisfiesLockfile` is only ever recorded as true
when both hold.

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
| A directory's **read** bit cleared for group and other (`0755` → `0711`) | yes — measured `6061b674…` → `2ba573b2…`; before the read bits were folded this moved nothing compared |
| The `node_modules` root's own **read** bits cleared (`0755` → `0711`) | yes — measured `6061b674…` → `01cf16f0…` |
| A file's read bit cleared for group and other (`0644` → `0600`) | yes |
| An entry whose name is not valid UTF-8, beside a sibling named U+FFFD | refused with exit `12`; both names decode alike, so one file would be folded twice and the other never read |
| `node_modules` replaced by a symlink to a byte-identical tree | yes, and a reviewed run refuses with exit `7` |
| The `node_modules` root's own execute bits changed | yes |
| `node_modules` is a symlink and the **target directory's** execute bits change (`0755` → `0700`) | yes — measured `59799ca3…` → `48dac79b…` under `--any-toolchain` |

### Advisory posture

Folds the identity of each advisory — package, severity, GHSA identifier, CWE list, CVSS score
and vector, affected range — plus the names a report gives as the packages a vulnerability is
inherited *through*, plus the overall counts.

Deliberately excluded: advisory **titles**, because GitHub rewords them without the advisory
changing identity; **`fixAvailable`**, because it changes the day a fix ships upstream, which is
news but not a change to what this repository installs; and **`effects`/`nodes`**, because they
are derivable from the installed tree, and one change should not move two numbers.

**The inherited-through names were excluded on that same reasoning until round 47, and the
reasoning was wrong for them.** The installed tree records which packages *depend on* which; this
field records which package the *registry declared vulnerable*. A tree edge is not an advisory
claim, so the tree cannot supply this name — and when a report names a package that has no
vulnerability record of its own, nothing else in the record names it either. Measured before the
fix: three reports differing only in that name folded to one posture digest, and printed one
identical `inherited through dependencies` line. Distinct claims about causation must not become
one record.

**The recorded digest above predates this change.** It was taken under the normalization that
dropped those names, so the current script does not reproduce it even from a byte-identical
report. That holds for **every** report, not only ones carrying an inherited package: the field is
emitted for each package whether or not the report supplied any names, because an empty list is a
value — it asserts the report named nothing — and a key present only sometimes would blur absence
into emptiness, the same conflation refused for a missing `via` key and for
`auditEnvironmentScrubbed`. Measured on a fixture with no string `via` entries at all, the posture
moved from `b169ecf8…` to `e1009b90…`.

This is stated rather than papered over: a value whose recipe has moved is the failure this whole
record exists to prevent, and inventing a recomputed number without the registry response that
produced it would be the fabrication the advisory-identity guard was tightened to refuse. The row
must be re-taken on a networked run, under `T1-ADVISORY-DISPOSITION-v1`.

**An earlier version of this paragraph ended by calling it "a policy re-decision row rather than a
compared one", and that clause was false in two directions at once.** The
[compared fields](#compared-fields) table lists this row as compared, and the paragraph below
states that a mismatch *is* an equality failure — so the document asserted, in three places, that
the row both is and is not subject to exact equality. What is a policy re-decision is the
**response** to a mismatch, never the question of whether the check applies. That distinction is
made two paragraphs down and this clause contradicted it.

The row's real status is narrower and worse than "not compared", and is stated plainly rather than
softened: **it is a compared row whose recorded value the current script cannot reproduce, so the
equality check cannot pass today even against an unchanged advisory database.** That is not a
property of the advisory database drifting; it is this record carrying a value taken under a
normalization the committed script no longer implements. Until the row is re-taken, a consumer
cannot discharge it, and no wording here can change that — which is precisely why it is flagged
instead of being left for a reader to discover at check time.

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

Issue #22 consumes this record. Its equality requirement is discharged by **all three** of the
following, with the caveat on the advisory posture noted directly above:

1. Re-running the script and confirming its `--json` output has `freezeRecord: true` with an empty
   `notFreezeRecordBecause`.
2. Comparing that output against every script-derived row.
3. Running the three `git rev-parse` commands in [Compared fields](#compared-fields) and comparing
   their output against the three `git`-derived rows.

**Step 1 is a gate on the other two, not a fourth row to check.** Without it the procedure can
report itself satisfied over output the script has explicitly disowned: `--any-toolchain` waives
the reviewed-environment and reviewed-input guards — the `Bypassed` column in
[Why a run was refused](#why-a-run-was-refused) says which, per row — so a run with the reviewed
files, tree, toolchain and umask but an ambient `bin-links=false`, which a normal run refuses at
the configuration guard with exit `6`, emits every script-derived row in the table unchanged and
sets `freezeRecord: false`. Comparing only the listed rows accepts it. The script already states
its own standing in the artifact; the procedure has to read it.

**It does not waive every refusal, and this paragraph said it did.** That is the same sentence
[Why a run was refused](#why-a-run-was-refused) already corrects for itself, left standing here —
a correction applied at the site that was reported and not swept to its sibling. A bypassed run
still exits `2` on an unrecognized argument or an npm it cannot run, `5` on an audit response that
is not a report, `3` if a recorded input changes mid-run, `7` on a missing or non-walkable
`node_modules`, and `12` on an entry name that is not valid UTF-8. All measured, not inferred.
Those exits mean **no record was produced at all**,
which is a different outcome from a record the script produced and disowned, and a consumer who
expects the bypass to always yield a comparable artifact will misdiagnose the difference.

**Step 3 is not optional either, and an earlier draft of this section omitted it.** It said the
requirement was discharged "by re-running the script above and comparing against the table", which
a consumer could follow literally and completely — while leaving the reviewed head, the merge
commit and the merged tree unchecked, because the script emits no field for any of them. Three
compared rows would have gone unverified by a procedure that reported itself satisfied.

That omission and the missing gate above are the same defect twice: a procedure that lists what to
compare, and is read as complete because it is specific. Both were found by review rather than by
anything structural, which is why the list is now stated as a conjunction with the gate first.

That is the same defect this document was written to retire, in the instructions rather than in
the values: the [Compared fields](#compared-fields) table was corrected to stop claiming the
script derived everything, and this section was left asserting it one heading later.
