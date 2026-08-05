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
| Freeze script SHA-256 | `488fdeec42bd76d5de5c7c8bced0a19a81bec99818f651f5c94deec1f1629088` | script `script.sha256` |
| Node | `v24.18.1` | script `toolchain.node` |
| npm | `11.16.0` | script `toolchain.npm` |
| npm installation SHA-256 | `f58556342f8abc9245e168904a6579b9b09e7dc10606df7a52fcd454ccec8231` | script `toolchain.npmTree` |
| Platform | `linux` | script `toolchain.platform` |
| Architecture | `x64` | script `toolchain.arch` |
| Install umask | `0022` | script `toolchain.umask` |
| `package.json` blob | `2b88a0ac85d3a8b7286040e6b1f6c4ddb4d3bce1` | script `manifestBlobs['package.json']` |
| `package.json` SHA-256 | `e206cdb3562f0397e8eed7fb2c2586269a1f5335cdff2906da8d5e070426321e` | script `manifest['package.json']` |
| `package-lock.json` blob | `5c376ce2364e06c3ac4bc3ab8e3570e86b35f6ca` | script `manifestBlobs['package-lock.json']` |
| `package-lock.json` SHA-256 | `277f7168ab3a4f1f7a2565de13191d64b1572e7cb92b67b0972b3242bd4de062` | script `manifest['package-lock.json']` |
| Installed tree SHA-256 | `6061b674c7dbdaaec16a2c7f7016c70cfcaea32c76490ddd7edf88341ce3c3ce` | script `installedTreeSha256` |
| Installed tree files | `2177` | script `installedTreeFiles` |
| Installed tree symlinks | `8` | script `installedTreeSymlinks` |
| Installed tree directories | `336` | script `installedTreeDirectories` |
| Installed tree special entries | `0` | script `installedTreeSpecials` |
| File permissions | `{"644":2157,"755":20}` | script `installedTreeModes` |
| Directory permissions | `{"755":336}` | script `installedTreeDirectoryModes` |
| `node_modules` root mode | `755` | script `installedTreeRootMode` |
| Advisory registry | `https://registry.npmjs.org/` | script `registry` |
| Advisory posture SHA-256 | `925751f8c4d131a9403a2d9ea6536c1d9c508a62d3a993c76b860375bac732ba` | script `auditSha256` |
| Advisory counts | `{"info":0,"low":0,"moderate":2,"high":5,"critical":0,"total":7}` | script `auditCounts` |

> **This row is blocked pending an advisory disposition, and re-taking the digest did not clear
> it.** The value above is correct and reproducible — it was re-taken on the reviewed toolchain
> against the public registry. But it folds **`GHSA-rgw5-rvv9-x895`**, published after the original
> freeze and **not covered by any decision recorded under `T1-ADVISORY-DISPOSITION-v1`**.
>
> Comparing against this baseline would therefore *pass* while a vulnerability nobody has ruled on
> sits inside it — the exact opposite of what the advisory rows exist to do. Per
> [Compared fields](#compared-fields), issue #22 must treat advisory drift as a blocking check that
> a policy decision clears; **re-baselining a digest is not a substitute for deciding about what the
> digest now contains**, and an earlier revision of this record made precisely that mistake by
> replacing the value and removing the block in one step.
>
> A consumer must treat this row as **not yet dischargeable** until a disposition covering
> `GHSA-rgw5-rvv9-x895` is recorded. The clearing condition is tracked in issue #24.

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

**And a fourth instance survived that sweep, in the two rows the sweep was standing next to.** The
manifest blob rows read `blob 2b88a0ac…`, while `manifestBlobs['package.json']` emits the
hexadecimal object id alone — so a consumer following [Consumers](#consumers) and comparing each
script-derived row exactly would have failed on both rows, on every valid run, forever. That is
worse than the three instances above it: those made a value awkward to compare, this one made two
values impossible to compare, and a check that can never pass is indistinguishable from a check
nobody runs. The word `blob` is now part of the field name, and the value cell holds exactly what
the key emits.

**The npm installation is compared, and the npm version row alone is not enough.** `toolchain.npm`
is the string npm prints when asked its version, which is written by the program being identified
and therefore cannot identify it. Measured: the reviewed `node` binary is world-readable, so it can
be *copied* — no write access to the toolchain required — and a nine-line shell script named `npm`
placed beside the copy answers `11.16.0`, supplies the configuration, asserts the tree satisfies the
lockfile, and returns an advisory report with all seven advisories deleted. The run emitted
`freezeRecord: true` with an empty `notFreezeRecordBecause`.

`toolchain.npmTree` is the digest of the whole npm installation that backs the executable which will
actually run: the script resolves `npm` through its symlink, requires the resolved file to sit
inside `lib/node_modules/npm`, folds that tree, and refuses unless it matches. The reviewed value
was derived from `lib/node_modules/npm` inside `node-v24.18.1-linux-x64.tar.xz`, whose SHA-256 was
checked against the archive digest the workflows already pin before the archive was opened — so it
describes the bytes CI extracts rather than any particular developer's machine.

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
exact equality. Every row below carries a value, including `auditEnvironmentScrubbed`, which
gained one when the advisory posture was re-taken — it had correctly carried none before, and
[How `auditEnvironmentScrubbed` came to have a value](#how-auditenvironmentscrubbed-came-to-have-a-value)
is the history of why.

| Field | Value | Derived by | Why it is not compared |
| --- | --- | --- | --- |
| Policy decision | `T1-ADVISORY-DISPOSITION-v1` | this document | no artifact exists to compare against; bounded through issue #24 |
| Audit environment scrubbed | `[]` | script `auditEnvironmentScrubbed` | describes the recording machine, not the supply inputs; a reader's own run reports their own list |

### How `auditEnvironmentScrubbed` came to have a value

**This field now has an observed value, and the row above carries it.** The advisory-posture
re-take was performed with the current script, which emits `auditEnvironmentScrubbed` on every
successful audited run — so the same run that produced the recorded `auditSha256` necessarily
produced a value for this field too. It observed `[]`: the recording environment carried no
trust-relevant variable that had to be removed before the audit ran.

The history below is kept because the *reasoning* still governs how this row must be read, and
because an earlier revision of this section survived the re-take while asserting the opposite —
that no observation existed. That was true of the original freeze and false the moment the posture
was replaced.

**A row stood here for four rounds before this one, and the defect was not the row but the
emptiness in it.** It sat in a table of recorded values holding no value, and reviewers read the
contradiction rather than the four paragraphs answering it: the cell said the field was not
captured, then that it had no value, then that it was not recorded in this freeze — three
wordings, each reported in turn. Rewording a row that had nothing to record is answering the shape
shown, which is the habit this document keeps finding in its own script. That row was removed, and
the row above is not its return: the difference between them is that a run produced this one.

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
and two independent reviewers once read that as contradicting this record. At the time it did not,
and the reason was checkable rather than asserted: the field was added to the script *after* the
original digests were taken. The commit that recorded the *original* advisory posture (`8905ba3`) is an ancestor of the commit
that introduced `auditEnvironmentScrubbed` (`bdbfb81`), which `git merge-base --is-ancestor`
confirms, so the run that minted that posture could not have emitted the field. Writing a
plausible-looking `[]` at that point would have been a value invented to fill a column — the same
fabrication the advisory-identity guard was tightened to refuse, committed in the record instead
of in the code. That refusal was correct then and is why the row was absent rather than guessed.

**What changed is that the posture was re-taken, not that the standard was relaxed.** The value in
the row above is `[]` because a run of the current script observed `[]`, in the same run that
produced the recorded `auditSha256` — which is exactly the evidence a reviewer had asked for and
that did not exist until the re-take supplied it.

The field remains per-run: it describes the environment of whoever executes the script, so a
reader's own run reports their own list rather than this one. That is why it is recorded and not
compared — a reader on a machine carrying a proxy variable will see a non-empty list without
anything being wrong with the supply inputs.

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

**The three permission rows were here until they were measured, and the measurement reversed the
argument.** This section used to say that a `0644` → `0664` is harmless, leaves the installed-tree
digest byte-identical while moving the histogram to `{"644":2156,"664":1,"755":20}`, and that
comparing the histogram for exact equality would therefore reject a tree the digest says is
correct.

Every clause of that is true except the first, and the first is the one the conclusion rested on.
`0644` → `0664` is the **exact signature of a POSIX ACL granting write to an additional
principal**: the ACL mask replaces the group permission bits, so `setfacl -m u:someone:rw-` on a
`0644` file reports `0664` from `stat` while the bytes and the compared fold are untouched. Far
from harmless, it is the one ACL shape that silently makes a *frozen* tree mutable by someone the
record never accounted for. The evidence is in
[What this script cannot check about itself](#what-this-script-cannot-check-about-itself).

So the rows moved into [Compared fields](#compared-fields). The "machine state" objection does not
survive its own document either: the process umask is a compared field with its own refusal
(exit `8`), so a run under a different umask is rejected before the histogram is ever consulted,
and under the pinned umask the reviewed tree is uniformly `644`/`755` with no group-write bucket
at all. There is no drift left for the exemption to protect.

The write bits stay outside the *digest* for the reason the fold's own comment gives — it measures
loadability, and write permission does not affect whether a module loads. That reasoning is sound
for a digest and was silently borrowed to excuse not comparing the histogram, where it does not
apply: a freeze record is about mutability as well as loadability, and the histogram is where
mutability was visible all along.

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
| `brace-expansion` | high | GHSA-3jxr-9vmj-r5cp, GHSA-f886-m6hf-6m8v, GHSA-mh99-v99m-4gvg, GHSA-rgw5-rvv9-x895 |
| `js-yaml` | high | GHSA-52cp-r559-cp3m, GHSA-h67p-54hq-rp68 |
| `linkify-it` | high | GHSA-22p9-wv53-3rq4, GHSA-v245-v573-v5vm |
| `markdown-it` | moderate | GHSA-38c4-r59v-3vqw, GHSA-6v5v-wf23-fmfq |
| `markdownlint-cli2` | moderate | inherited through `js-yaml`, `markdown-it` |
| `minimatch` | high | GHSA-23c5-xmqv-rm74, GHSA-3ppc-4f35-3m26, GHSA-7r86-cg39-jmmj |
| `picomatch` | high | GHSA-3v7f-55p6-f55p, GHSA-c2c7-rcm5-vvqj |

## Trust boundary

**Everything this script verifies, it verifies using Node — so it cannot verify Node.**

The recorder authenticates a great deal: it folds its own bytes, folds the npm installation and
compares it against the digest of the npm shipped inside the reviewed Node archive, refuses an
npm that resolves outside that installation, and refuses install-shaping or transport
configuration that differs from the reviewed values. Every one of those checks is performed by
calling `node:fs`, `node:crypto` and `node:child_process`.

A Node executable that has been modified supplies those modules. It can report `v24.18.1` from
`process.version`, return whatever bytes it likes from `readFileSync`, produce whatever digest it
likes from `createHash`, and answer every `execFileSync` itself without launching anything. Under
such a Node the script's self-hash, the npm-installation digest, both installed-tree folds and
the advisory posture are all forgeable, and **no check that could be added to this file would
detect it**, because the check would run under the same modified runtime. Hashing the `node`
binary from inside that binary is not an exception — it is the clearest case of the same problem.

Note what this is *not*. It is not the round-56 finding, where the reviewed Node binary was
**copied** unmodified and a fake `npm` was placed beside it: that required no change to Node, and
it is refused now because npm is authenticated by its bytes. This is the strictly harder attack of
modifying Node itself, and it is outside what a script can close about its own interpreter.

**The anchor is therefore external, and it already exists.** Both workflows fetch
`node-v24.18.1-linux-x64.tar.xz` from `nodejs.org`, compare its SHA-256 against a reviewed
constant *before* extracting it, and then invoke the extracted binary by absolute path. The trust
in a CI-produced record rests on that step, not on anything the script says about itself.

**One further precondition, corrected here because an earlier revision justified it wrongly.** The
recorder folds every directory from the Node distribution root down to the npm installation and
the launcher, and stops there. A previous revision defended stopping on the grounds that anyone
able to rewrite the directory *containing* the distribution could replace `node` itself — which is
false in the way that matters: replacing `node` **on disk does not replace the running process**.
The active interpreter stays the authenticated one while the npm subprocess is redirected, so that
argument did not cover the interval it claimed to.

What actually holds is narrower and is a precondition rather than a check: **the distribution must
live where it cannot be renamed during the run.** A rename of the distribution aside and back
leaves the folded root and every descendant with their inodes and change times intact, and only the
containing directory records it — and that directory cannot be folded without refusing ordinary
runs, since in CI it is the runner's temporary directory, which other work writes to throughout.
The recorder narrows the exposure by re-checking the npm command line's inode immediately before
every invocation, which reduces the window from the whole run to the gap between that check and the
`exec`; it does not eliminate it. CI satisfies the precondition because the extraction directory is
job-private.

A manual run must do the same, which is why [How to reproduce](#how-to-reproduce) below obtains
the distribution by digest and invokes it by absolute path. Running `node Get-SupplyFreezeDigest.mjs`
with a bare `node` resolves through the ambient `PATH` and **does not** satisfy this: the
environment chooses the interpreter, and the record has no way to say which one answered.

## How to reproduce

The script is **not** present at the recorded T1 merge commit — it is added by the change that
introduces this document. Reproduce from a revision that contains it, which carries the same
`package.json` and `package-lock.json` blobs:

```bash
git checkout main            # or any revision containing Get-SupplyFreezeDigest.mjs

# <rev>:<path> is always resolved from the repository root, never the current
# directory, so this runs before the cd and keeps the path unambiguous.
#
# `git rev-parse` PRINTS a blob id and exits 0 whatever that id turns out to be,
# so a bare invocation with "must equal the recorded blob" beside it is a check
# that cannot fail -- the same defect as `sha256sum` without `-c` below. There is
# no `-c` for rev-parse, so the comparison is made explicit and `&&`-chained, and
# a mismatch stops the procedure here rather than at a digest much further down.
#
# Paste the two blob rows from Compared fields above; they are deliberately not
# repeated here, for the reason given at the script digest below.
strReviewedPackageBlob='PASTE the `package.json` blob row here'
strReviewedLockBlob='PASTE the `package-lock.json` blob row here'
# The preflight is chained into the download and extraction that follow it, not
# left as a statement beside them. Unchained it satisfied nothing the comment
# above promises: both `test`s returned non-zero on a bad blob, printed nothing,
# and the reader carried on to install and record against manifests this check
# had already rejected. A guard whose failure does not stop what it guards is
# decoration.
#
# Obtain the toolchain by digest rather than by name. `node` on PATH is chosen by
# the environment, and the script cannot check what it is -- see Trust boundary.
# mktemp -d, not a fixed /tmp path: on a shared host another user can
# pre-create /tmp/node24.tar.xz as a symlink and `curl -o` will follow it and
# truncate the target, or pre-create /tmp/node24 as a directory symlink and
# `tar -C` will extract through it -- both before any digest is checked.
test "$(git rev-parse HEAD:.github/workflows/package.json)" = "$strReviewedPackageBlob" \
  && test "$(git rev-parse HEAD:.github/workflows/package-lock.json)" = "$strReviewedLockBlob" \
  && strWork="$(mktemp -d)" \
  && curl -fsSLo "$strWork/node24.tar.xz" \
    https://nodejs.org/dist/v24.18.1/node-v24.18.1-linux-x64.tar.xz
# sha256sum without -c only PRINTS; it cannot fail, so an unverified archive
# would still be extracted by the next line and a tampered Node would then be
# the runtime every later check runs under -- see Trust boundary.
# strNode is cleared FIRST so a failure below cannot leave it pointing at a
# node24/ directory some earlier run extracted -- an unset variable breaks the
# next command loudly, a stale one runs the wrong Node silently.
unset strNode
echo 'd6c664df3f3f61458e8c277585571328522d705166723a7c7823a9253a4d15a0  '"$strWork/node24.tar.xz" \
  | sha256sum -c - \
  && mkdir "$strWork/node24" \
  && tar -xJf "$strWork/node24.tar.xz" -C "$strWork/node24" --strip-components=1 \
  && strNode="$strWork/node24/bin/node"   # absolute, and npm is the one beside it

cd .github/workflows
umask 0022                   # the recorded tree was installed under this
# Verify the recorder BEFORE running it. The script reports its own SHA-256, but
# that is the script telling you about itself -- worthless if the file has been
# modified. This checks it from outside, and `&&`-chains the run behind it so a
# mismatch stops the procedure instead of executing unreviewed JavaScript.
#
# Paste the "Freeze script SHA-256" value from Compared fields above. It is
# deliberately NOT repeated here: this document holds every digest exactly once,
# because a hand-copied digest has nothing deriving it and rots silently -- which
# has already happened twice in this pull request's own description.
strReviewedScript='PASTE the Freeze script SHA-256 row here'

# `npm ci` is the FIRST link of the chain, not a separate statement before it.
# Standing alone it was the one command in this block whose failure did not stop
# the procedure: an install that fails over an older node_modules leaves that
# tree on disk, and the recorder then folds it and prints a confident digest --
# a failed reproduction reporting success over stale bytes. Every step from the
# install to the record is now one `&&` sequence, so the first failure ends it.
env -u NODE_OPTIONS "$strNode" "$strWork/node24/bin/npm" ci --ignore-scripts --no-audit --no-fund \
  && echo "$strReviewedScript  Get-SupplyFreezeDigest.mjs" \
    | sha256sum -c - \
  && env -u NODE_OPTIONS "$strNode" Get-SupplyFreezeDigest.mjs --json
```

**The order of those last two commands is the point.** An earlier revision of this block ran the
recorder first and left the script's digest to be compared afterwards, from
[Check the script's own digest first](#what-this-script-cannot-check-about-itself) further down.
That is backwards: a reader who checks out a revision carrying a modified recorder has already
executed it by the time they reach the comparison, and a recorder modified to lie about its own
identity will also lie about that. The check has to happen outside the program and before it runs,
which is the same reasoning as the archive digest above — and the same defect, one file over, that
round 62 fixed for `sha256sum` without `-c`.

This is a *precondition of the procedure*, not a control the script provides. Nothing the recorder
prints can establish it; see [Trust boundary](#trust-boundary).

**`--json` is not optional here.** The default renderer is a human summary and does not print
every compared field — `toolchain.npmTree`, which authenticates npm's bytes, and the two
`manifestBlobs` object ids are all absent from it. A reader following this procedure without
`--json` cannot supply the values [Consumers](#consumers) requires comparing, which is the shape
the procedure exists to produce.

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

The histogram is compared for exact equality, but it **does not by itself say why it differs**.
Any change to a file's mode moves it — measured, a single `chmod g-r` under the reviewed umask
turns `{"644":2157,"755":20}` into `{"604":1,"644":2156,"755":20}`. A shape that differs from the
record is therefore *consistent with* a different install umask, and equally consistent with
modes altered after the install, or with an ACL mask widening the group bits. It fails the
comparison in every one of those cases; what it narrows rather than settles is the diagnosis.
Read it together with the umask row, which is separately compared and separately refused.

An earlier draft counted **group-readable files** instead, and that was too weak to be a
backstop. `umask 027` clears `0o027`, which leaves group read set — `0o644` becomes `0o640` and
`0o755` becomes `0o750`, both still group-readable. Measured: a tree installed under `027` and
recorded under `022` moved the digest while the census still reported the recorded
`2177 of 2177`, so it was blind to one of the umasks the guard itself rejects. The
histogram distinguishes all three.

The histogram is recorded and **not** folded into the digest, because the digest measures
loadability and write bits do not affect it. It *is* a compared field — see
[Compared fields](#compared-fields) and the ACL evidence in
[What this script cannot check about itself](#what-this-script-cannot-check-about-itself) for why
the earlier "full modes are machine state" exemption did not survive being measured.

To sidestep ambient configuration files:

```bash
strIsolationDirectory="$(mktemp -d)"
: > "$strIsolationDirectory/npm-user-empty"
: > "$strIsolationDirectory/npm-global-empty"
# Both casings, or the ambient lowercase wins and the isolation does nothing.
unset npm_config_userconfig npm_config_globalconfig
export NPM_CONFIG_USERCONFIG="$strIsolationDirectory/npm-user-empty"
export NPM_CONFIG_GLOBALCONFIG="$strIsolationDirectory/npm-global-empty"
# `&&`, for the same reason the main reproduction block gives: npm ci is the FIRST
# LINK of the chain, not a separate statement before it. Unchained, an install that
# fails before replacing an old node_modules leaves the recorder to run anyway and
# record the stale tree from a prior run -- the isolation workaround then appears to
# succeed while describing a tree this recipe never installed.
env -u NODE_OPTIONS "$strNode" "$strWork/node24/bin/npm" ci --ignore-scripts --no-audit --no-fund \
  && env -u NODE_OPTIONS "$strNode" Get-SupplyFreezeDigest.mjs --json
```

**Both casings must be handled, and setting only the upper one is not isolation.** npm's
configuration documentation states that `npm_config_*` environment variables are case-insensitive
and that the lower-case spelling is preferred, so a caller who already exports
`npm_config_userconfig` keeps their own `.npmrc` in force while this block looks as though it had
replaced it. The failure is quiet in the direction that matters: the install picks up the ambient
file, and the recorder either builds a different tree or refuses at exit `6` against a tree the
reader believes was installed in isolation. This is the same case-sensitivity defect the
`bin-links` scrub carried, fixed there in round 61 and left standing here.

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
env -u NODE_OPTIONS -u npm_config_bin_links -u NPM_CONFIG_BIN_LINKS \
  "$strNode" "$strWork/node24/bin/npm" ci --ignore-scripts --no-audit --no-fund \
  && env -u NODE_OPTIONS -u npm_config_bin_links -u NPM_CONFIG_BIN_LINKS \
    "$strNode" Get-SupplyFreezeDigest.mjs --json
```

**Both commands carry the scrub, and an earlier revision showed it on only the first.** The
recorder reads the same `npm_config_*` environment the installer does — it is the input the exit-6
configuration guard inspects — so a reader who scrubbed the variable for `npm ci` alone installed
the correct tree and then watched the recorder refuse it at exit `6`, with the documented
workaround unable to complete. The setting has to be absent from both processes or from neither;
scrubbing it for one is the shape of a fix rather than a fix.

**The unsets are added to the reviewed invocation, not substituted for it.** An earlier revision
of this example wrote a bare `npm` and dropped the `NODE_OPTIONS` unset, so a reader copying it
built the tree with whatever npm their `PATH` offered, under whatever preload their environment
carried — and then chased a digest mismatch caused by the example itself. The script cannot check
which runtime it is executing under once it has started (see
[Trust boundary](#trust-boundary)), so every install command in this document uses the
digest-verified `$strNode` and the npm beside it.

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

**There is no longer an exception, and the history is kept here because it is the point.** This
section used to record one: the check that the npm installation did not change *while it was being
used* sat behind `if (!boolAnyToolchain)`, so a bypassed run skipped it. That was an
integrity-during-run refusal being waived, which the paragraph above says does not happen. The
note ended by declining to fix it — "changing a guard is not a documentation fix, and the run it
affects already declares `freezeRecord: false`."

Round 71 closed it, because that reasoning was wrong twice over. The before/after comparison needs
no reviewed value, so nothing about `--any-toolchain` ever made it inapplicable; and the fold that
produces the baseline ran unconditionally anyway, so the value was being computed and discarded.
`npmTree` is emitted for bypassed runs, so the record could pair one installation's hash with
another installation's version, `ls` and audit answers. `freezeRecord: false` marks a record as
unblessed, not as permitted to be internally inconsistent.

The rule therefore holds without exception: **`--any-toolchain` waives comparisons against
`REVIEWED_*` constants, and nothing else. Self-consistency checks run in every mode.**

| Exit | Refusal | Bypassed by `--any-toolchain` | Usual cause |
| ---: | --- | :---: | --- |
| `2` | Unreviewed toolchain | yes | different Node, npm, platform or architecture; a symlinked entry point; `NODE_OPTIONS` set; or an npm installation whose digest is not the reviewed one — see [What this script cannot check about itself](#what-this-script-cannot-check-about-itself) |
| `2` | npm installation changed while it was being used | **no** | the npm tree was rewritten, or its inode change times moved, between the fold taken before the first subprocess and the recheck after the last one. Compares the run's own before value against its own after value, so it needs no reviewed digest and `--any-toolchain` does not waive it. Measured: touching a file inside the installation mid-run under `--any-toolchain --no-audit` exits `2`, reporting an identical `sha256` with a differing change-time hash, while the unperturbed bypassed run exits `0`. Bypassed until round 71 — see the note above the table |
| `2` | npm installation cannot be located, read or authenticated | **no** | the launcher beside `node` is missing; npm resolves outside this Node installation or outside `lib/node_modules/npm`; the installation cannot be read; the command line is no longer the file that was authenticated; or npm cannot be spawned at all. These establish *which program answered*, which `--any-toolchain` does not waive — it relaxes **which** toolchain is acceptable, never whether the one present can be identified. Measured: a `node` copied away from its distribution exits `2` under `--any-toolchain --no-audit` exactly as it does without the flag, while the genuine reviewed toolchain under the same flag exits `0` |
| `2` | Unrecognized invocation | **no** | an argument the script does not support; `--any-toolchain --bogus` still exits `2` |
| `3` | Recorded input changed mid-run | **no** | `package.json`, `package-lock.json` or the script itself edited while the run was in progress |
| `4` | Manifest missing or unreadable | **no** | `package.json` or `package-lock.json` absent or unreadable. A manifest that is *present* but not a regular file refuses at exit `15`, not here — see that row. `snapshotOrRefuse()` takes the snapshot before the gated comparison against the reviewed digests, so there is nothing to compare and nothing to disown. Measured: a copy of the recorder with no manifests exits `4` under `--any-toolchain --no-audit`, reporting `package.json could not be read` |
| `4` | Unreviewed manifest | yes | `package.json` or `package-lock.json` is present and readable but does not match the reviewed digest — it has moved. This is the only half of exit `4` the flag waives |
| `5` | Audit response is not a report | **no** | registry unreachable, an endpoint error returned as JSON, or a document that is not shaped like an audit report — including a report version that is not a positive safe integer, or a severity count that is not a nonnegative safe integer, since past 2^53-1 two different reported numbers stop being distinguishable. Advisory fields are refused the same way when their type or range cannot be compared — a `cvss.score` must be a finite number in the CVSS range 0–10, because a non-finite score serializes as `null` and would record as an absent one |
| `5` | Advisory posture contradicts itself | **no** | a severity outside npm's five recognized levels, or counts whose buckets do not sum to `total` — a posture whose own arithmetic disagrees cannot be compared exactly |
| `5` | Normalization did not cover every reported package | **no** | the normalized package map holds fewer entries than the report had vulnerability records, so the digest would be taken over a shorter set than the counts describe |
| `5` | Advisory has no usable identity | **no** | an advisory record carrying neither a GHSA url nor a positive safe-integer source id. An id past 2^53-1 is refused here too: two different reported ids stop being distinguishable at that size, so both would be recorded as one identity |
| `6` | Install- or trust-shaping npm configuration | yes | `bin-links`, `omit`, `package-lock-only`, `umask`, `omit-lockfile-registry-resolved`, and the transport settings `proxy`, `https-proxy`, `noproxy`, `ca`, `cafile`, `strict-ssl` … from an `.npmrc` or the environment. Also raised, self-diagnosing, if the transport scrub itself failed to bind the audit environment |
| `7` | Root missing or not a directory | **no** | `node_modules` absent, or present as a file or a symlink to one |
| `7` | Root is a symlink to a directory | yes | `node_modules` replaced by a symlink whose target is a real directory, which redirects where every installed module loads from while the contents behind it stay byte-identical. Refused by `lstat` before the tree is walked, so an arbitrarily large target is not scanned first. Under `--any-toolchain` the target is folded instead, with the **target's** normalized bits recorded as the root mode — but only when that target resolves *inside* the workflow directory; see the row below |
| `7` | Root symlink leaves the watched boundary | **no** | `node_modules` is a symlink whose target resolves outside the workflow directory. The sweep follows the link and watches the target, but the directories **above** the target are not watched and cannot be: an external ancestor chain is unbounded, and its change times move for reasons unrelated to this run — the same argument that makes a manifest symlink a refusal (exit `15`) rather than a wider sweep. Unwatched, one of those ancestors can be renamed aside, a different tree put in place for `npm ls` and `npm audit`, and the original restored before the final sweep, with the link and target inode still comparing equal. A target *inside* the workflow directory has its ancestors swept instead, bounded because the chain terminates in the already-swept set; EVERY hop of a symlinked root is tested, not just its endpoint — a chain that leaves the boundary and returns (`node_modules` → external → in-boundary target) refuses, because the external hop's parent is unwatched and can be renamed aside mid-run; a chain deeper than 40 levels refuses at exit `10` rather than sweeping part of it, since this walk runs upward and a cap would drop the outermost ancestors — the ones a rename-aside would move. `--any-toolchain` does not waive this — it is a self-consistency check, not a comparison against a `REVIEWED_*` constant. Measured: an external symlink target exits `7`; an in-boundary one exits `0`; perturbing an in-boundary target's parent mid-run exits `10` |
| `7` | Tree does not satisfy the lockfile | yes | `node_modules` is present but incomplete, or `npm ls` answered about a tree other than this one. The refusal names which. A tree that was **never installed** is not this row: `node_modules` is then absent, which the root walkability check refuses first and unconditionally — measured, a checkout without `node_modules` exits `7` reporting `node_modules MISSING` under `--any-toolchain --no-audit --json`, with no record produced |
| `8` | Unreviewed process umask | yes | recording shell is not at `0022` |
| `9` | Unreviewed advisory registry | yes | `registry` points at a mirror or proxy |
| `10` | Recorded inputs changed while recording | **no** | a swept path — `node_modules`, a manifest, the workflow directory or an ancestor — was written, swapped or created during the run |
| `11` | Tree contains special files | yes | a FIFO, socket or device node under `node_modules` |
| `11` | Tree contains links that leave it | yes | a symlink under `node_modules` resolving outside it — typically a package directory replaced by a link to an external tree |
| `11` | Tree contains links it cannot resolve | yes | a symlink under `node_modules` whose resolution fails for any reason, so containment is unproven rather than satisfied |
| `12` | Tree contains an undecodable entry name | **no** | an entry under `node_modules` whose name is not valid UTF-8. Such a name decodes to U+FFFD, so a sibling named U+FFFD shares the decoded name and both resolve to one file — the other is never read and never reaches the digest. Refused rather than folded, because the alternative is a digest over a tree the script did not measure. The check is a byte round trip, so a file legitimately named U+FFFD still folds |
| `13` | Project npm configuration is not a regular file | **no** | `.github/workflows/.npmrc` present as a symlink, directory, FIFO, socket or device node. npm reads it as a configuration source, and only a regular file can be held still across the run — a link is opened through a target whose own parent can be swapped mid-run, and a link that does not resolve is indistinguishable from no file at all while its target can still be created for the audit and removed. Measured: `--any-toolchain --no-audit` exits `13` exactly as a plain run does |
| `14` | Tree entry the recorder does not solely control | **no** | an entry under `node_modules` carrying setuid, setgid or sticky bits; a regular file with more than one hard link, so a second path can rewrite the bytes; or an entry owned by a different uid than the recording process, whose owner can chmod and rewrite it after the final sweep. None of the three move the digest — it folds `mode & 0o555` and bytes, and the histograms mask to `0o777` — so they are refused rather than folded. `uid` and `gid` are deliberately **not** hashed: they are properties of the machine, and folding them would make two hosts that installed identical packages produce different digests. Measured: setuid and hard-link cases each exit `14`, and removing them returns the identical tree digest. The `node_modules` root itself is checked too, and when it is a **symlink** the check is applied to the resolved target — the directory the walk actually traverses — not to the link. Measured with only the top directory chowned, since chowning the children makes the per-entry checks fire instead and proves nothing about the root: a real root owned by another uid exits `14`, and a symlink to that same directory now exits `14` as well, where it previously emitted a record |
| `15` | Recorded manifest is not a regular file | **no** | `package.json` or `package-lock.json` present as a symlink, directory, FIFO, socket or device node — the same closed set exit `13` applies to `.npmrc`. The FIFO is the case that makes this a correctness rule rather than a tidiness one: its bytes are a stream supplied per open, so the snapshot reads the reviewed bytes and `npm ls`/`npm audit` then consume whatever is written next, while the quiescence sweep sees only an unchanged inode and change time. Both are opened *by name* by `npm ls` and `npm audit`, and a link's target sits in a directory outside the swept set, which can be renamed aside, replaced, and restored before the final sweep — leaving the link and its original target comparing equal while npm answered from other bytes. The same rule already applies to a project `.npmrc` (exit `13`); this closes the gap where the more load-bearing inputs, the ones whose hashes are compared, were held to the weaker rule. Measured: a symlinked `package.json` exits `15`, and restoring a regular file returns exit `0` |

**The swept set now includes the workflow directory's ancestors** — `.github` and the
repository root — because npm resolves its working directory by name while every earlier sweep
watched inodes. Renaming `.github` aside, standing a different `workflows` directory at the same
pathname for the audit child, and renaming the original back left every watched inode untouched.
A rename modifies the containing directory, so the repository root's change time moves, and
`rename(2)` moves the renamed inode's own change time as well. Measured: perturbing the
repository root mid-run now exits `10`, while the same perturbation applied to a directory
outside the swept set still exits `0`.

The chain stops at the repository root. Above the checkout the ancestors are shared with the
rest of the machine, and their change times move for reasons unrelated to this run, so sweeping
them would refuse healthy runs without closing anything this script can defend. **A checkout
whose parent directory is writable by an untrusted party is therefore outside the boundary, and
is a precondition rather than something this script detects.**

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

**Exit `13` refuses a project `.npmrc` that is not a regular file**, and it exists because
following the link was the wrong answer rather than an incomplete one. npm reads a per-project
`.npmrc` from the directory the audit child runs in, so that file is a live configuration source
and the sweep watches it. Round 62 made the sweep follow the link chain; round 63 showed two
holes that sweeping harder cannot reach.

The first is that a link's **target has its own parent**, and that parent decides which file npm
opens. With `.npmrc` a link to `<external>/dir/npmrc`, `dir` can be renamed aside, replaced by a
directory holding a hostile config for the audit, and restored — leaving the link, the original
target inode and the workflow directory all with unchanged change times. The second is that a
**dangling** link was indistinguishable from no file at all: the sweep recorded `-1` for both, so
a link pointing at a path that does not exist yet could have its target created for the audit and
removed before the final sweep. Measured, both cases: the two sweeps agreed and npm consumed
`registry=https://evil`.

Sweeping the target's ancestors would close the first and not the second, and would pull
arbitrary external directories — whose change times move for unrelated reasons — into a check
that must not refuse correct runs. So the shape is refused instead. This repository ships no
`.npmrc`, npm's project config is a plain per-directory file, and nothing legitimate needs that
path to be a link. A regular file has no link chain, no external ancestors and no dangling state,
which leaves exactly the rewrite-in-place case the sweep already detects. An **absent** `.npmrc`
is still recorded as `-1` and still runs normally; only a present-but-unsweepable shape refuses.

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
proxy set there appears in that output — and the run refuses with exit `6`.

**The mid-run window this section used to name as an open residual is closed, and the text saying
otherwise was stale.** A project `npmrc` written after that check and removed again before the end
was once invisible to everything downstream. Two sweeps now cover it, and neither subsumes the
other: the **workflow directory** is swept, so creating an entry and removing it is caught even
though the file is gone by the end — both operations move the directory's change time — and
`.npmrc` **itself** is swept as an optional path, so rewriting an existing file in place is caught
by the file's own change time, which the directory's does not record. Either refuses at exit `10`.
Measured both ways against a live run, including create-and-delete leaving nothing on disk.

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

**The permission fold measures POSIX mode bits, so it sees a POSIX ACL only where the ACL moves
those bits.** An earlier revision of this section said a tree can be made unloadable by
mechanisms `stat` does not report and that "none of these move the installed-tree digest or the
permission histograms". That sentence was **wrong in two of the six cases it covered**, and it
was wrong in the direction that matters: it understated what the fold catches while leaving the
case it misses undescribed. Measured, on ext4, by writing `system.posix_acl_access` directly and
reading back `st_mode`:

| ACL added to a `0644` file | `st_mode` | Compared fold (`& 0o555`) | Histogram (`& 0o777`) |
| --- | --- | --- | --- |
| *(control — no ACL)* | `644` | unchanged | unchanged |
| `u:1234:---` — deny that user | `644` | unchanged | unchanged |
| `u:1234:r--` — grant read | `644` | unchanged | unchanged |
| `u:1234:rw-` — grant write | `664` | unchanged | **moves** |
| `u:1234:r-x` — grant execute | `654` | **moves** | **moves** |
| `u:1234:rwx` — grant all | `674` | **moves** | **moves** |

The mechanism is the ACL mask. [`acl(5)`](https://man7.org/linux/man-pages/man5/acl.5.html) states
that when an ACL carries an `ACL_MASK` entry "the group permissions correspond to the permissions
of the `ACL_MASK` entry" — so any ACL that grants a permission the owning group lacks widens the
mask and writes itself into the group bits of `st_mode`. A grant is therefore partly visible; a
**denial** is not, because denying a named user contributes nothing to the mask.

Enforcement was verified, not assumed. Against a no-ACL control in the same directory, under
`setuid(1234)`: the control reads, `u:1234:---` gets `EACCES`, and `u:1234:rw-` both reads *and
writes*. An earlier run of this test showed every case denied, which was an artifact of an
untraversable parent — the control is what distinguishes the two.

Two consequences follow, and the second is the one this record cares about most:

* **A denying ACL is invisible here, and it is a denial.** It cannot substitute content; it makes
  a module unloadable for some user, which surfaces as a build failure rather than as a silently
  wrong tree.
* **A write-granting ACL is the dangerous shape, because it makes a "frozen" tree mutable by a
  principal the record never accounted for** — and it lands exactly on `0644` → `0664`, the delta
  a previous revision of this document dismissed as harmless while declining to compare the
  histograms. That is why the histograms are now compared fields.

Detection of the two invisible shapes is stated rather than fixed. Node exposes no ACL or
extended-attribute API — confirmed still absent from core as of Node 24, with xattr access
available only through third-party native modules such as
[`fs-xattr`](https://www.npmjs.com/package/fs-xattr) — so detection means shelling out. Both
candidates are rejected on the same principle rather than on effort: `getfacl` is not universally
installed (measured absent on the container these verifications were run in), and while `python3`
*is* present here and exposes `os.listxattr`, adding an unauthenticated external interpreter to a
script that spent seven review rounds authenticating the one external program it already runs
would open a wider hole than it closes. A guard that silently no-ops where its helper is missing
converts an honest blind spot into a false assurance.

The other mechanisms in this family — SELinux or AppArmor labels, a `noexec` mount, `chattr +i` —
remain outside every field this script derives, and no claim is made about them.

**What the walk already proves, and for whom.** The fold reads every file's bytes and traverses
every directory, so a completed run is positive evidence that the user who ran the recorder holds
read on every file and search on every directory. That is not a separate check; it is a
precondition of producing a digest at all. The residual is therefore narrower than "ACLs are
invisible": it is an access-control entry affecting *a user other than the one that ran the
recorder*. In the documented `npm ci && node ./Get-SupplyFreezeDigest.mjs` workflow those are the
same user.

**Check the script's own digest first.** The script reports its own SHA-256 on every run, and the
value is recorded in the table above. This matters because the digests below are a property of
*this* script: during review the installed-tree digest moved twice without any dependency
changing at all — once when the fold was made injective, and again when the executable bit was
added to it. A reader with a correct tree, a correct lockfile and a different script version
would otherwise see a mismatch with nothing to explain it.

```bash
# Paste the "Freeze script SHA-256" value from Compared fields above -- held once
# in this document, for the reason given beside the same check in Reproducing.
strReviewedScript='PASTE the Freeze script SHA-256 row here'
echo "$strReviewedScript  Get-SupplyFreezeDigest.mjs" | sha256sum -c -
```

`sha256sum` **without** `-c` only prints; it exits 0 whatever the digest turns out to be, so the
earlier form of this block — a bare `sha256sum` with `# must equal the recorded value` beside it —
was a check that could not fail. Reported by Copilot in round 68, and it was the third instance of
that shape in this document rather than the first: the two `git rev-parse` blob lines in
[How to reproduce](#how-to-reproduce) had it too and are fixed in the same commit.

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
load it. The histogram moved, but it was a *non-compared* diagnostic at the time, so every
compared field stayed equal and a reviewed run would have emitted `freezeRecord: true` for a tree
those users cannot use. The mask is now `mode & 0o555` — read and execute together are exactly the
"can each permission class still load this" property.

**Write bits stay out of the digest**, because they do not affect loadability. They are no longer
outside the *record*: the histograms became compared fields once a write-granting POSIX ACL was
measured to land on exactly the `0644` → `0664` delta their exemption had called harmless. The
digest answers "can this still be loaded"; the histogram answers "can this still be changed", and
a freeze record needs both.

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
| A project `.npmrc` that is a symlink, dangling symlink, directory, FIFO, socket or device node | refused with exit `13`; only a regular file can be held still across the run — see below |
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

**The recorded digest has been re-taken under this normalization, which discharges the
reproducibility problem and nothing else.** The row is still **not dischargeable**, for the
separate reason given at the [compared-fields table](#compared-fields): the re-taken value folds
`GHSA-rgw5-rvv9-x895`, which no recorded disposition covers. Two different obstacles sat on this
one row, they were never the same obstacle, and clearing the first is not clearing the second.
The previous value, `ea559555…`, was taken before the inherited-through names were recorded, so the
committed script could not reproduce it from any report — not only from ones carrying an inherited
package, because the field is emitted for every package whether or not the report supplied names.
An empty list is a value: it asserts the report named nothing, and a key present only sometimes
would blur absence into emptiness, the same conflation refused for a missing `via` key and for
`auditEnvironmentScrubbed`. Measured on a fixture with no string `via` entries at all, the posture
moved from `b169ecf8…` to `e1009b90…`.

For four rounds this document carried that value with the row marked as un-dischargeable, because
inventing a recomputed number without the registry response that produced it would have been the
fabrication the advisory-identity guard was tightened to refuse. The re-take was performed on the
reviewed toolchain against the public registry, unproxied, and produced `freezeRecord: true` with
an empty `notFreezeRecordBecause`. Every other recorded field re-derived byte-identically in the
same run — both manifest digests, both blob ids, the tree digest and the whole census — which is
what establishes that only the advisory normalization had moved.

**The re-take also moved two rows in [Advisory detail](#advisory-detail), and that is a real
change rather than a normalization artifact.** `brace-expansion` now carries a fourth advisory,
`GHSA-rgw5-rvv9-x895`, which was not published when the original freeze was taken; and
`markdownlint-cli2` now names the packages it inherits through rather than saying "dependencies",
which is the round-47 change working as intended. The package count and the severity counts are
unchanged at seven packages, two moderate and five high, so `auditCounts` did not move.

A newly published advisory is exactly the drift this row exists to surface, and it is a policy
matter rather than a tree matter: the disposition recorded under `T1-ADVISORY-DISPOSITION-v1` was
decided before `GHSA-rgw5-rvv9-x895` existed, so that decision has not been taken against it. That
is bounded through issue #24 and is called out here rather than absorbed silently into a re-taken
baseline.

**An earlier version of this section called the row "a policy re-decision row rather than a
compared one", and that clause was false in two directions at once.** The
[compared fields](#compared-fields) table lists this row as compared, and the paragraph below
states that a mismatch *is* an equality failure — so the document asserted, in three places, that
the row both is and is not subject to exact equality. What is a policy re-decision is the
**response** to a mismatch, never whether the check applies.

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

Issue #22 consumes this record. Its equality requirement is discharged by **all four** of the
following:

1. Re-running the script and confirming its `--json` output has `freezeRecord: true` with an empty
   `notFreezeRecordBecause`.
2. Comparing that output against every script-derived row.
3. Running the three `git rev-parse` commands in [Compared fields](#compared-fields) and comparing
   their output against the three `git`-derived rows.
4. **Confirming that a disposition recorded under `T1-ADVISORY-DISPOSITION-v1` covers every
   advisory folded into the recorded posture — today that means `GHSA-rgw5-rvv9-x895`, which no
   decision yet covers.** Until it does, this record **cannot** discharge #22, and steps 1 to 3
   passing does not change that.

**Step 4 exists because the first three cannot detect what it checks.** An earlier version of this
procedure listed only three and pointed at a caveat "directly above" describing how to respond to
an advisory *mismatch* — but after the posture was re-taken there is no mismatch, so nothing in
steps 1 to 3 fires, and a consumer following them to the letter would discharge #22 over a
vulnerability nobody has ruled on. A gate that only fires on drift is no gate at all once the
drift has been folded into the baseline.

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
