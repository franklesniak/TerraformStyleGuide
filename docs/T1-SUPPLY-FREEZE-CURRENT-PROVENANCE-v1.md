<!-- markdownlint-disable MD013 -->
# T1 current supply profile and provenance

## Metadata

- **Status:** Active
- **Owner:** TerraformStyleGuide Repository Maintainers
- **Last Updated:** 2026-09-21
- **Scope:** Defines current-profile observations, field provenance, Linux preparation, separate Git verification, refusals and validation. Historical T1 assertions remain in the linked original record.
- **Related:** [Historical T1 record](T1-SUPPLY-FREEZE-v1.md), [Issue 52](https://github.com/franklesniak/TerraformStyleGuide/issues/52), [policy contract](../.github/workflows/workflow-policy-contract.json), [recorder](../.github/workflows/Get-SupplyFreezeDigest.mjs), [focused tests](../.github/workflows/Get-SupplyFreezeDigest.test.mjs)

This companion keeps the complete current method together within the repository's governed-document size limit. The [historical record](T1-SUPPLY-FREEZE-v1.md) retains all original compared and recorded-only assertions, recorder identity and advisory status.

## Meaning of a current run

The recorder copies the existing `supplyFreeze` object without changing its `TerraformStyleGuide.FrozenSupplyProfile.v1` schema, field names, values, or types. It emits new measurements under `currentObservation`. The profile's producer purpose is `reviewed-runtime-requirement-not-historical-lock-production`. It is a reviewed runtime requirement, not evidence that the historical lock or T1 record was produced by the current runtime. The historical T1 record remains separate and retains its documented digest recipe.

`currentObservation.complete: true` means that the current measurement passed the recorder's toolchain, manifest, installed-tree, configuration, live-audit, and consistency guards. It does **not** verify every historical assertion, approve an advisory, replace historical measurements, or resolve issues 22 and 24. The output states that policy authorization was not evaluated. The profile's `historicalRecordIsCurrentGraphMeasurement` and `advisoryDispositionGranted` remain false. A consumer must separately verify the historical evidence it needs and obtain an applicable advisory disposition.

`--no-audit` and `--any-toolchain` produce explicitly incomplete observations. Neither bypasses the cache boundary, authenticated npm-installation digest and census, installed/npm-tree safety refusals, or during-run consistency checks. `--any-toolchain` relaxes only the listed runtime/version/configuration/manifest/tree comparison guards; it never authorizes executing different npm bytes. Unsupported hosts refuse; there is no Windows emulation claim or BSD claim. The Windows refusal test proves that boundary, not a Windows supply measurement.

The recorder runs no install, Git command, lifecycle script, or workflow. It writes only stdout and stderr itself. Its npm children can write cache and diagnostic files in a caller-created private external directory. The caller must direct stdout outside the repository. Creating that directory, acquiring Git objects, and installing dependencies are separate preparation steps, outside the read-only measurement interval.

## Immutable source and adaptation

The canonical common-behavior source is [PSStyleGuide commit 5a6f22f](https://github.com/franklesniak/PSStyleGuide/tree/5a6f22f10dd244e5d4f0b0b9448ccaeeb18daaf0), tree `2d503710c73debdcf07ef78447281d1b4a191d4a`, delivered by [PR 203](https://github.com/franklesniak/PSStyleGuide/pull/203). The focused Terraform baseline is commit `71202772d69689ffc0336bd3532e711b27e633bf`, tree `67e023c32a44d31629d9f60984a4ce4ac758ff35`.

| Role | Immutable input |
| --- | --- |
| Common recorder | PS `.github/workflows/Get-SupplyFreezeDigest.mjs`, blob `9409232e8cff938c3295d7a519e87d462246289f`, SHA-256 `3401930cf9fc04a520b85425a131c487bf3facf6267e4150e20c9660407c7d0d` |
| Common focused tests | PS `.github/workflows/Get-SupplyFreezeDigest.test.mjs`, blob `5c322d31988d053ed10c81a848ee96a73bc25fb7`, SHA-256 `53df783d2509f7d25a7bc9f8f758e6733f7c6f4fe2defd495da0c66a2f4d03a3` |
| Common method | PS `docs/P1-SUPPLY-FREEZE-v1.md`, blob `2151cb3f31b88fa96dc058bc1be94b6c58403e42`, SHA-256 `70a76a77b0975445853912d89074758eb547125a1a72e41cd645fe4b20c28052` |
| Current TF contract input | `.github/workflows/workflow-policy-contract.json`, blob `3bd17eb91ccb5c40aa38594128ebf52c9d1c8af2`, SHA-256 `b2585b0d890b6a81059418b440c9a06f4a942909754ac2a362349ecb860dba7c` |
| Historical recorder and method | TF original PR 27 commit `aae05282b57f093cec8b63e59138db72c982f10e`, recorder blob `05778c0eda0273a9217f7dc953795c2240473a14`, method blob `36010d2dac98631845d8e880689f7c315ccbcdb7` |

The current adaptation retains the source's common safety code, canonical JSON, parsers, installed-byte fold, advisory normalization, child outcomes, external housekeeping authority, confidentiality projections, root guards and owning-domain exception translators. Repository-specific substitutions bind the four current manifest identities, the exact current profile tuple, diagnostic labels, method path and output provenance. The focused tests use the same production functions and callers with corresponding TF data assertions. The separate Git verifier checks the current-profile baseline and the retained historical T1 package pair with the same closed child environment and byte/native-status rules; it prints success only after all required objects pass.

The current profile is pinned by SHA-256 of recursive sorted-key JSON, without insignificant whitespace: `ba5d7bf8891c6342dae3a0022fd4291926732fc10c3e690206a6a05e74b4e0b9`. Changing an assertion requires a reviewed recorder change. Other contract fields can change without changing that profile tuple; the complete raw contract identity is still reported and checked for changes during the run. The source's historical P1 producer and fields absent from TF are not copied into this profile. Terraform's historical installed-tree and normalized advisory recipes remain in [the historical record](T1-SUPPLY-FREEZE-v1.md#what-each-digest-does-and-does-not-prove).

## Field provenance and output types

The JSON envelope has three objects: `supplyFreeze`, `provenance`, and `currentObservation`. It is not a replacement policy schema. In the table, **asserted** means copied from the pinned contract; **derived** means computed during this run; **external** means that the recorder does not perform the verification.

| Field or complete field family | Type | Provenance and verification |
| --- | --- | --- |
| `supplyFreeze.schema` | string | Asserted, exactly `TerraformStyleGuide.FrozenSupplyProfile.v1`. |
| `supplyFreeze.reviewedCommit` | 40-character hexadecimal string | Asserted current-profile baseline commit `e5064a672c10f4fad90f36e82af33ff8fc230b5f`. External Git procedure verifies its type and both path relationships. It is not today's HEAD or the T1 merge. |
| `supplyFreeze.baseline.packageJson` and `.packageLockJson`: `blob`, `length`, `sha256` | string, nonnegative integer, string | Asserted current-profile raw Git blobs. External procedure verifies object ID, byte length, SHA-256, and commit/path membership. Working-tree line endings are not an input. |
| `supplyFreeze.reviewedWorkingBytes.packageJson` and `.packageLockJson`: `length`, `sha256` | nonnegative integer, string | Pinned assertions matched against actual current files in a strict run. The fixed SHA-256 and Git blob guards identify their exact bytes. A bypassed mismatch leaves `verifiedCurrentBytes` empty. |
| `supplyFreeze.producer`: `profilePurpose`, `nodeVersion`, `npmVersion`, `linuxArchive`, `linuxArchiveSha256` | strings | Asserted reviewed runtime requirement. Purpose is exactly `reviewed-runtime-requirement-not-historical-lock-production`; Node `24.18.1` and npm `11.16.0`. External archive verification establishes distribution bytes, not historical lock production. |
| `supplyFreeze.yaml`: `version`, `tarball`, `integrity`, `enginesNode` | strings | Asserted current YAML package provenance. Tarball bytes require external verification; current installed payload bytes are measured separately. |
| `supplyFreeze.dependencyPolicy`: `scripts`, `devDependencies`, `overrides`, `securityPatch` | objects with string-valued leaves | Asserted current dependency policy. Complete profile equality preserves every field and type. Manifest and lock bytes are measured; the separate workflow-policy validator enforces policy semantics. |
| `supplyFreeze.provenance`: `historicalRecord`, `historicalRecordIsCurrentGraphMeasurement`, `advisoryDispositionGranted`, `unresolvedAdvisoryConsumerIssues` | string, boolean, boolean, integer array | Asserted separation from this retained T1 record; both flags are false and issue numbers remain `[22,24]`. No advisory acceptance is added. |
| `provenance.reviewedAssertions`, `.verifiedCurrentBytes`, `.externalVerificationRequired` | string arrays | Explicit scope labels. They do not turn an asserted field into a measurement. |
| `provenance.historicalRecordStatus` | string | States that retained T1 assertions remain separate and were not remeasured by this observation. The historical recipe remains in [the original record](T1-SUPPLY-FREEZE-v1.md#what-each-digest-does-and-does-not-prove). |
| `provenance.contractSha256`, `.contractBlob` | hexadecimal strings | Derived from complete raw contract bytes, with before/after bytes, inode, and change-time checks. |
| `currentObservation.complete`, `.incompleteBecause`, `.policyAuthorization` | boolean, string array, string | Current measurement standing, reasons for incompleteness, and explicit absence of policy authorization. |
| `currentObservation.script.sha256` | hexadecimal string | Self-observed script bytes. Requires external verification before execution; it cannot authenticate itself. |
| `currentObservation.toolchain`: `node`, `npm`, `npmTree`, `platform`, `arch`, `umask` | strings | Observed runtime and authenticated npm-content fold. The npm tree digest and 1,916-file census are required in every mode. The raw npm version response is retained only for the strict equality check; the public `npm` field is the bounded numeric core plus fixed labels for withheld prerelease/build metadata, or a fixed length-only description for unrecognized output. Node itself must be authenticated externally. Strict host is Linux/x64, Node `v24.18.1`, npm `11.16.0`, umask `0022`. |
| `currentObservation.manifest`, `.manifestBlobs` | objects with `package.json` and `package-lock.json` string properties | Derived SHA-256 and Git blob IDs of current raw files. No Git subprocess is used. |
| `currentObservation.matchesReviewedManifest`, `.treeSatisfiesLockfile` | booleans | Exact current-file guard and actual `npm ls` result, including root path and complete declared top-level dependency set. |
| `currentObservation.installedTreeSha256`, `installedTreeFiles`, `installedTreeSymlinks`, `installedTreeDirectories`, `installedTreeSpecials`, `installedTreeModes`, `installedTreeDirectoryModes`, `installedTreeRootMode` | string, four integers, two mode-count objects, string | Derived from the entire installed tree, including ignored files. Two folds compare every returned field. These fields use the upstream byte recipe, the same documented T1 byte recipe; current inputs are distinct from historical inputs. |
| `currentObservation.registry`, `.auditSha256`, `.auditEnvironmentScrubbed`, `.auditCounts`, `.auditPackages` | string/null, string/null, array, counts object/null, fixed summary object/null | Public registry projection and normalized advisory recipe. Only the exact reviewed registry retains its authority; other HTTP(S) values retain a fixed scheme category, and other parseable or malformed values expose no caller-controlled protocol, authority, port, path, query, or fragment. The raw checked value is bound to each audit child through one canonical `NPM_CONFIG_REGISTRY` setting after all case-insensitive aliases are removed; it is not placed in argv. Package keys, advisory identities, and inherited `via` names remain inputs to the published normalized digest. The public `auditPackages.directAdvisory` and `.inheritedOnly` objects each contain only integer `info`, `low`, `moderate`, `high`, `critical`, and `unclassified` counts; direct-advisory means the normalized record has advisory entries, not npm's separate `isDirect` project-dependency flag. An intentionally skipped audit emits explicit null values and an empty scrub list. The historical T1 advisory digest uses the same normalized recipe over distinct historical response data; a new audit does not reproduce that response. |
| `currentObservation.npmProcesses[]`: `operation`, `nativeExit`, `signal`, `stderrLength` | string, integer, null, integer | Actual child outcomes in a successful complete observation; only audit may have native status 1 there. An incomplete diagnostic observation can retain the documented npm-ls native failure. Every semantic stdout byte stream is exact-decoded before parsing or comparison. Stderr remains diagnostic-only: its length counts decoded child characters and public diagnostics expose fixed categories and lengths, not child text or raw bytes. |

Audit counts use nonnegative safe integers for `info`, `low`, `moderate`, `high`, `critical`, and `total`; the buckets must sum to total. The complete upstream method specifies the byte-fold framing and advisory normalization. In brief: SHA-256 over sorted entries with single-byte kind tags and ASCII-decimal-length-prefixed UTF-8 paths, permission masks, raw link targets, and file bytes. The root, directories, and files include `mode & 0o555`; complete `mode & 0o777` histograms are separately compared. Link targets must resolve within the measured tree; undecodable names, special metadata, and mutable input shapes refuse under the documented guards.

## Prepare and record on Linux/x64

Use a trusted private checkout and verified Git/Node tools. Exclude concurrent changes by the same user to the checkout, Node distribution, cache directory, or their parents. Before starting any Node process, clear `NODE_OPTIONS`, `NODE_COMPILE_CACHE`, `NODE_V8_COVERAGE`, `NODE_REDIRECT_WARNINGS`, `NODE_DEBUG`, and `NODE_DEBUG_NATIVE`, and set `NODE_DISABLE_COMPILE_CACHE=1`. Node can configure output before the first JavaScript statement and write it at exit; a JavaScript refusal cannot undo those effects. This caller protocol applies independently to the recorder, test runner, and historical verifier. Bare invocation under arbitrary startup settings is not a read-only claim. The script cannot defend against code injected before its first statement, a hostile runtime, filesystem snapshots that are not atomic, permissions available to privileged actors or the same UID, ACL models not represented by POSIX mode bits, or a hostile parent of the checkout. It creates no claim of physical fault injection or Windows PowerShell execution.

After its earliest self-snapshot and before it reads project inputs or starts npm, the recorder admits the repository root, `.github`, and `.github/workflows` as real directories only when each is owned by root or the recording UID. A group- or other-writable repository root or `.github` must be sticky and its existing next component must have a trusted owner. The direct `.github/workflows` directory must grant no group or other write bits, even when sticky, because another UID could otherwise create an absent project input such as `.npmrc`. This admission stops at the repository root and retains the external-parent, same-UID, privileged-actor, non-POSIX ACL, and non-atomicity limits in [the historical trust-boundary explanation](T1-SUPPLY-FREEZE-v1.md#what-this-script-cannot-check-about-itself).

Obtain the official Node `24.18.1` Linux/x64 archive and verify its SHA-256 **before extraction**. This binary recipe supports GNU/Linux x64 with kernel 4.18 or newer, glibc 2.28 or newer, and libstdc++ `GLIBCXX_3.4.25` or newer. It does not claim support for musl-based systems or vendor releases outside Node's supported binary platforms. The recipe requires Bash, `curl`, GNU Coreutils `env`, `id`, `mkdir`, `mktemp`, `sha256sum`, and `stat`, plus GNU `tar` with `xz` support. The separate historical procedure also requires a trusted Git executable. The pinned archive digest is `d6c664df3f3f61458e8c277585571328522d705166723a7c7823a9253a4d15a0`. The authenticated bundled npm tree must contain 1,916 files and have digest `f58556342f8abc9245e168904a6579b9b09e7dc10606df7a52fcd454ccec8231`; the recorder checks both. The archive checksum establishes the selected distribution bytes; signed release verification is separate provenance work when required.

The following commands run from the repository root in Bash. Set `strExpectedRecorder` to the exact SHA-256 from the independently reviewed candidate or its permanent handoff. A value copied from the script's own output is not independent verification. `SUPPLY_FREEZE_TEMP_BASE` can select an existing external base; otherwise the recipe checks `TMPDIR`, then `/tmp`. The selected base and every physical ancestor must be owned by root or the recording UID, and every group- or other-writable component must have the sticky bit. An unsafe selected value refuses rather than falling back. Physical checkout or base paths containing carriage returns or line feeds refuse before any file creation because the checksum-file syntax used below cannot represent those names safely. Save the final JSON outside the checkout.

```bash
set -eu
unset NODE_OPTIONS NODE_COMPILE_CACHE NODE_V8_COVERAGE NODE_REDIRECT_WARNINGS NODE_DEBUG NODE_DEBUG_NATIVE
export NODE_DISABLE_COMPILE_CACHE=1
strExpectedRecorder='PASTE_THE_INDEPENDENTLY_REVIEWED_RECORDER_SHA256'
for strCommand in curl env id mkdir mktemp sha256sum stat tar xz; do
  command -v "$strCommand" >/dev/null 2>&1 || {
    printf 'Required command is unavailable: %s\n' "$strCommand" >&2
    exit 1
  }
done
strCanonicalSuffix=$'\n.'
strCheckoutTagged="$(pwd -P && printf '.')" || {
  printf 'Checkout path could not be resolved physically.\n' >&2
  exit 1
}
case "$strCheckoutTagged" in
  *"$strCanonicalSuffix") strCheckout="${strCheckoutTagged%"$strCanonicalSuffix"}" ;;
  *) printf 'Checkout path could not be captured losslessly.\n' >&2; exit 1 ;;
esac
case "$strCheckout" in
  *$'\n'*|*$'\r'*) printf 'Checkout path contains an unsupported line break.\n' >&2; exit 1 ;;
esac
strSelectedBase="${SUPPLY_FREEZE_TEMP_BASE:-${TMPDIR:-/tmp}}"
case "$strSelectedBase" in
  /*) ;;
  *) printf 'Temporary base must be an absolute existing directory.\n' >&2; exit 1 ;;
esac
strExternalBaseTagged="$(cd -P -- "$strSelectedBase" 2>/dev/null && pwd -P && printf '.')" || {
  printf 'Temporary base must be an accessible existing directory.\n' >&2
  exit 1
}
case "$strExternalBaseTagged" in
  *"$strCanonicalSuffix") strExternalBase="${strExternalBaseTagged%"$strCanonicalSuffix"}" ;;
  *) printf 'Temporary base could not be captured losslessly.\n' >&2; exit 1 ;;
esac
case "$strExternalBase" in
  *$'\n'*|*$'\r'*) printf 'Temporary base contains an unsupported line break.\n' >&2; exit 1 ;;
esac
strCheckoutPrefix="${strCheckout%/}/"
case "$strExternalBase/" in
  "$strCheckoutPrefix"*) printf 'Temporary base must be outside the checkout.\n' >&2; exit 1 ;;
esac
strUid="$(id -u)"
strAt="$strExternalBase"
while :; do
  strStat="$(stat -Lc '%u %a' -- "$strAt")" || {
    printf 'Temporary base ancestry could not be inspected.\n' >&2
    exit 1
  }
  read -r strOwner strMode <<< "$strStat"
  intMode=$((8#$strMode))
  if { [ "$strOwner" != 0 ] && [ "$strOwner" != "$strUid" ]; } \
    || { (( (intMode & 0022) != 0 )) && (( (intMode & 01000) == 0 )); }; then
    printf 'Temporary base has an unsafe physical ancestor.\n' >&2
    exit 1
  fi
  [ "$strAt" = / ] && break
  strAt="${strAt%/*}"
  [ -n "$strAt" ] || strAt=/
done
umask 0022
strTools="$(mktemp -d "$strExternalBase/supply-freeze-tools.XXXXXXXXXX")"
curl -fsSLo "$strTools/node.tar.xz" \
  https://nodejs.org/dist/v24.18.1/node-v24.18.1-linux-x64.tar.xz
printf '%s  %s\n' \
  d6c664df3f3f61458e8c277585571328522d705166723a7c7823a9253a4d15a0 \
  "$strTools/node.tar.xz" | sha256sum -c -
mkdir "$strTools/node"
tar -xJf "$strTools/node.tar.xz" -C "$strTools/node" --strip-components=1
strNode="$strTools/node/bin/node"
strNpm="$strTools/node/bin/npm"
printf '%s  %s\n' "$strExpectedRecorder" \
  .github/workflows/Get-SupplyFreezeDigest.mjs | sha256sum -c -
# Preparation only: installs locked dependencies, with lifecycle scripts disabled.
# Run from a clean environment; user/global workspace or install settings can refuse.
env -u NPM_CONFIG_WORKSPACE -u npm_config_workspace \
  "$strNode" "$strNpm" --prefix .github/workflows ci \
  --ignore-scripts --no-audit --no-fund --workspaces=false
# The caller creates a fresh mode-0700 directory; do not reuse a populated one.
strCache="$(mktemp -d "$strExternalBase/supply-freeze-cache.XXXXXXXXXX")"
strOutput="$(mktemp "$strExternalBase/supply-freeze-observation.XXXXXXXXXX")"
env -u NODE_OPTIONS -u NODE_COMPILE_CACHE -u NODE_V8_COVERAGE \
  -u NODE_REDIRECT_WARNINGS -u NODE_DEBUG -u NODE_DEBUG_NATIVE \
  NODE_DISABLE_COMPILE_CACHE=1 "$strNode" .github/workflows/Get-SupplyFreezeDigest.mjs \
  --json "--cache-directory=$strCache" > "$strOutput"
"$strNode" --input-type=module - "$strOutput" <<'NODE'
import { readFileSync } from 'node:fs';
const result = JSON.parse(readFileSync(process.argv[2]));
if (result.currentObservation.complete !== true) process.exit(1);
console.log('Complete current observation; historical verification remains separate.');
NODE
printf 'Observation saved outside the repository: %s\n' "$strOutput"
```

The recorder's external cache directory must be absolute, canonical, empty, owned by the recording UID, and mode `0700`. Symlink cache aliases and repository/toolchain overlap refuse. Both the measured checkout and the physical recorder source repository are excluded, including diagnostic invocation through a script alias. Ancestors must be owned by root or the recording UID; writable ancestors require the sticky bit. The caller must prevent same-UID interference during the run. The complete initial installed-tree fold and its root, special-entry, and link checks run before the first npm subprocess; both installed-tree folds refuse special entries unconditionally. npm cache and logs are forced beneath that directory before every npm subprocess, including version and configuration probes; timing and update notification are disabled. Ambient repository-local cache/log paths cannot override these flags. Each npm child also removes all six Node startup variables listed above and forces `NODE_DISABLE_COMPILE_CACHE=1`; warnings remain visible as fixed categories and decoded-character lengths, while arbitrary child stderr text is withheld from public recorder diagnostics. Each audit receives a fresh environment that removes every case-insensitive registry alias and binds the already-checked value as canonical `NPM_CONFIG_REGISTRY`; npm's environment precedence keeps that value above project, user, and global configuration without publishing it in the process argument vector. Wrapper failures name only a fixed allowlisted operation and withhold all arguments. Strict `npm ls` problem diagnostics expose only safe native status plus fixed `missing`, `invalid`, `extraneous`, and `other` counts; package identifiers, versions, paths, unknown kinds, and other problem payload text are withheld. Observable active compile-cache, coverage, warning-redirection, or Node debug settings refuse with exit 2 before npm, but this check cannot undo runtime effects before module entry. Strict mode also refuses when `NODE_OPTIONS` is present, including an empty value; `--any-toolchain` bypasses that observable hygiene check and marks the output as not a freeze record. The caller protocol above remains mandatory in every mode because pre-entry code can erase the variable before this check. Empty values of the five output/debug variables are inactive; compile caching is inactive when its disable flag is `1`. No existing directory permissions are changed. npm's private log files can still contain sensitive data; retain and inspect that caller-owned external directory accordingly.

## Verify historical Git provenance separately

Object acquisition is explicit preparation and writes the Git object database. From the expected Terraform clone, if either reviewed or historical commit is absent, fetch the exact commits from the canonical repository before starting the read-only interval:

```bash
git fetch --no-tags https://github.com/franklesniak/TerraformStyleGuide.git \
  e5064a672c10f4fad90f36e82af33ff8fc230b5f \
  143f54e52075a1ae1e999a6e242073e3d8d4a46b
```

The following independent procedure uses the verified `strNode` from above and a trusted Git executable on PATH. Every Git child receives a closed environment containing only that trusted PATH, the `C` locale, the fixed no-lazy-fetch/no-replacement/no-optional-lock settings, disabled system/global configuration, and disabled Trace2 targets. This prevents inherited object-routing or trace destinations from writing outside the measured repository during verification. Missing objects, a failed native command, an unexpected commit/path blob, or any length/hash mismatch terminate without a successful verification message. Only after both current-profile baseline objects and both historical T1 package objects pass does it print one fixed all-input verification marker. It hashes raw stdout buffers, never a shell text pipeline or checkout conversion. It does not install, fetch, or update an index.

The pinned [Node 24.18.1 environment-variable reference](https://nodejs.org/download/release/v24.18.1/docs/api/cli.html#environment-variables) and [module compile-cache reference](https://nodejs.org/download/release/v24.18.1/docs/api/module.html#module-compile-cache) describe these startup output controls. The [Git environment-variable reference](https://git-scm.com/docs/git#_environment_variables) and [Trace2 target reference](https://git-scm.com/docs/api-trace2) define the Git controls. The [npm configuration reference](https://docs.npmjs.com/cli/v11/using-npm/config/) defines the separate cache, logs-dir, and timing settings. The pinned [npm 11.16.0 audit exit-code implementation](https://github.com/npm/cli/blob/v11.16.0/node_modules/npm-audit-report/lib/exit-code.js) returns 0 or 1; valid-looking stdout does not authorize another native outcome.

```bash
env -u NODE_OPTIONS -u NODE_COMPILE_CACHE -u NODE_V8_COVERAGE \
  -u NODE_REDIRECT_WARNINGS -u NODE_DEBUG -u NODE_DEBUG_NATIVE \
  NODE_DISABLE_COMPILE_CACHE=1 \
  GIT_NO_LAZY_FETCH=1 GIT_OPTIONAL_LOCKS=0 \
  GIT_NO_REPLACE_OBJECTS=1 "$strNode" --input-type=module <<'NODE'
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
const freeze = JSON.parse(readFileSync('.github/workflows/workflow-policy-contract.json')).supplyFreeze;
assert.equal(freeze.reviewedCommit, 'e5064a672c10f4fad90f36e82af33ff8fc230b5f');
assert.equal(typeof process.env.PATH, 'string');
const gitEnvironment = {
  PATH: process.env.PATH,
  LC_ALL: 'C',
  GIT_NO_LAZY_FETCH: '1',
  GIT_NO_REPLACE_OBJECTS: '1',
  GIT_OPTIONAL_LOCKS: '0',
  GIT_CONFIG_NOSYSTEM: '1',
  GIT_CONFIG_SYSTEM: '/dev/null',
  GIT_CONFIG_GLOBAL: '/dev/null',
  GIT_TRACE2: '0',
  GIT_TRACE2_EVENT: '0',
  GIT_TRACE2_PERF: '0',
};
const git = (...args) => execFileSync('git', ['--no-replace-objects', ...args],
  { encoding: 'buffer', maxBuffer: 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'],
    env: gitEnvironment });
assert.equal(git('cat-file', '-t', freeze.reviewedCommit).toString().trim(), 'commit');
for (const [key, path, blob] of [
  ['packageJson', '.github/workflows/package.json', '103075d0d14f61b49d29cf2ed8dc8a7804fe092e'],
  ['packageLockJson', '.github/workflows/package-lock.json', '92a2f83a2d2d6904521800108ad0e1b1436909e2'],
]) {
  const expected = freeze.baseline[key];
  assert.equal(expected.blob, blob);
  assert.equal(git('rev-parse', `${freeze.reviewedCommit}:${path}`).toString().trim(), blob);
  const bytes = git('cat-file', 'blob', blob);
  assert.equal(bytes.length, expected.length);
  assert.equal(createHash('sha256').update(bytes).digest('hex'), expected.sha256);
}
const historicalCommit = '143f54e52075a1ae1e999a6e242073e3d8d4a46b';
assert.equal(git('cat-file', '-t', historicalCommit).toString().trim(), 'commit');
for (const [path, blob, length, digest] of [
  [".github/workflows/package.json", "2b88a0ac85d3a8b7286040e6b1f6c4ddb4d3bce1", 1068, "e206cdb3562f0397e8eed7fb2c2586269a1f5335cdff2906da8d5e070426321e"],
  [".github/workflows/package-lock.json", "5c376ce2364e06c3ac4bc3ab8e3570e86b35f6ca", 65121, "277f7168ab3a4f1f7a2565de13191d64b1572e7cb92b67b0972b3242bd4de062"],
]) {
  assert.equal(git('rev-parse', `${historicalCommit}:${path}`).toString().trim(), blob);
  const bytes = git('cat-file', 'blob', blob);
  assert.equal(bytes.length, length);
  assert.equal(createHash('sha256').update(bytes).digest('hex'), digest);
}
console.log('Current-profile and historical T1 package blob, path, length, and SHA-256 verification completed.');
NODE
```

This verifies current-profile baseline and historical T1 package consistency and commit/path membership. It does not verify historical execution, producer signatures, installed-tree measurements, original audit bytes, or policy authorization. The recorder and offline workflow-policy validator remain Git-free. The historical T1 byte recipe remains documented in [What each digest proves](T1-SUPPLY-FREEZE-v1.md#what-each-digest-does-and-does-not-prove).

## Invocation and refusal contract

Arguments are `--json`, `--no-audit`, `--any-toolchain`, and one required `--cache-directory=<path>`. There are no positional arguments or `--help` option. Unknown arguments refuse without publishing any token bytes; the diagnostic gives each unsupported token's original argv position and Unicode code-point length plus the fixed supported list. `--json` is required for complete field consumption; the default text format is a summary of the current observation and explicitly states that historical assertions need separate verification.

| Exit | Meaning |
| --- | --- |
| 0 | A complete or explicitly incomplete observation was emitted. Check `currentObservation.complete`; status alone is insufficient. |
| 2 | Unsupported invocation, observable active startup-output/debug environment, host, toolchain (including failed Node-distribution resolution), npm identity (including the unconditional npm-tree digest/census), special npm-installation entry, subprocess launch failure, or bounded npm-version response overflow. |
| 3 | Initial script resolution/read/type failure, or script, manifest, or contract change during measurement. |
| 4 | Missing, unreadable, or invalid-UTF-8 current manifest; also an unreviewed current manifest in strict mode. |
| 5 | Malformed/inconsistent, invalid-UTF-8, or over-limit audit response, or audit native status outside 0/1, signal, or launch failure reaching the audit adapter. |
| 6 | Unreviewed npm install/transport configuration, including an invalid-UTF-8 or over-limit configuration response. |
| 7 | Missing, invalid, redirected, or incomplete installed tree, including an invalid-UTF-8 or over-limit npm-ls response. |
| 8 | Unreviewed process umask. |
| 9 | Unreviewed advisory registry, including an over-limit registry response. |
| 10 | During-run tree, npm, or watched-path consistency failure. npm-distribution consistency failures can use 2. |
| 11 | Special entry, escaping link, or unresolved link in the installed tree. Special-entry and link-containment refusals are never bypassed by `--any-toolchain`. |
| 12 | Undecodable filename. |
| 13 | Nonregular project npm configuration. |
| 14 | Unsafe installed-entry ownership, hard links, non-owner write bits, or special mode bits. |
| 15 | Nonregular or multiply writable manifest/configuration input, including non-owner write bits or an unsafe repository-internal containing directory. |
| 16 | Missing, repeated, unsafe, nonprivate, populated, or overlapping external cache directory. Never bypassed. |
| 17 | Initial TF profile contract missing, unreadable, nonregular, multiply writable, non-owner writable, invalid UTF-8, malformed, or different from the reviewed profile tuple. Never bypassed. |

The immutable upstream method gives the original per-guard diagnostic-bypass distinctions for exits 2–15. This method's explicit tighter overrides apply: installed-tree special entries and escaping/unresolved links, npm-installation identity/link/special checks, cache safety, contract validation, exact UTF-8 decoding and bounded-response enforcement for semantic npm stdout, input UTF-8 validation, repository-internal input-directory admission, and non-owner write-mode checks are unconditional. The strict comparison against the reviewed current-manifest constants remains bypassable for a diagnostic record. Every refusal emits no JSON record. The internal directory guard stops at the repository root; the external parent-of-checkout, same-UID, privileged, and non-POSIX ACL exclusions in [the historical trust-boundary explanation](T1-SUPPLY-FREEZE-v1.md#what-this-script-cannot-check-about-itself) remain. A sequential userspace walk is not an atomic filesystem snapshot; the two content folds and inode/change-time sweep have the upstream timestamp-granularity and concurrent-write limitations. The new contract snapshot has the same sequential-read limitation.

## Validation and scope

Run the tests under the pinned Node distribution with the same startup protocol:

```bash
env -u NODE_OPTIONS -u NODE_COMPILE_CACHE -u NODE_V8_COVERAGE \
  -u NODE_REDIRECT_WARNINGS -u NODE_DEBUG -u NODE_DEBUG_NATIVE \
  NODE_DISABLE_COMPILE_CACHE=1 \
  "$strNode" --test .github/workflows/Get-SupplyFreezeDigest.test.mjs
```

Linux tests execute the complete recorder against real installed bytes and a live audit; Windows tests execute the unsupported-host refusal. Production audit-adapter fixtures exercise accepted 0/1 outcomes and refusal of status 2, signal termination, spawn error, and non-JSON failure. ARGUMENT-PRIVACY executes the complete recorder and verifies original argv positions and lengths without token disclosure, including a cache argument before the unsupported tokens. FILESYSTEM-DIAGNOSTIC-PRIVACY exercises the production errno formatter, a nonregular project `.npmrc`, and a missing adjacent npm launcher in a secret-bearing disposable path; diagnostics retain only fixed roles and safe categories. DESCRIPTOR-FAILURE executes the production reader with bounded injected open/fstat/read/close outcomes for manifest exit 4, during-run exit 3, and initial-contract exit 17; it also verifies a single close attempt, first-failure preservation, and unchanged intentional symlink/type/ownership/mode refusals. INITIAL-SELF-SNAPSHOT exercises production resolution/refusal wiring and the actual nonblocking descriptor reader, including a Linux FIFO, while preserving the first-observation position and script exit 3. INPUT-DIRECTORY-CONTROL verifies root/current-UID ownership, protective sticky internal ancestors, strict direct-workflow-directory permissions, fixed diagnostics, and whole-process no-record refusals. JSON-RESPONSE-PRIVACY executes the production shared parsers and audit shape/normalization adapters, verifying fixed categories and response lengths without parser excerpts, duplicate keys, endpoint fields, or contract content. RECURSIVE-COMPARISON-REFUSAL executes the unchanged production canonicalizer, the two owning-domain translators, and both strict configuration call sites; it covers deep array/object comparison, the recursive diagnostic formatter through a controlled getter fixture, shallow and extra-field controls, and strict/diagnostic whole-process contract refusals at exit 17. The getter is synthetic branch evidence, not a claim that authenticated npm emits a nested configuration value. UTF8-INPUT and whole-process manifest/contract cases verify valid Unicode and unconditional invalid-byte refusal. NPM-STDOUT-UTF8 drives the production npm adapter with valid, empty, invalid, missing, launch-failure, and bounded-response-overflow outcomes across the owning phase exits; semantic stdout uses the supplied phase exit while partial stderr on failure retains its fixed category and character count. NPM-REGISTRY-TRANSPORT executes the production audit-call construction in strict and diagnostic modes, verifies case-insensitive alias removal and one canonical checked child setting, proves the registry is absent from argv, and exercises both wrapper diagnostics with fake private arguments. NODE-DISTRIBUTION-RESOLUTION, the production-fold fixture, and a Linux instrumented-copy process case exercise all three observation formulas, including the npm fold inside its general scan caller; injected native failures reach fixed exit 2 without a path or stack. AUDIT-PUBLIC-SUMMARY executes production normalization, canonicalization, fixed summary construction, and the text row renderer; raw package/`via` changes move the published normalized digest but never enter JSON or text display, absent/null advisory URLs remain compatible, and present non-string URLs reach the fixed normalization refusal. TREE-CHECK-PRIVACY drives production npm-ls validation categories with private path/name sentinels. LS-PROBLEM-PRIVACY verifies fixed categories with fake problem-version and path payloads; a whole-process case removes a transitive dependency in a disposable fake-path checkout and verifies exit 7, fixed counts, and no raw npm problem text. NODE-CHILD-ENV and whole-process fake debug settings verify child scrubbing and fixed startup refusal without retaining raw debug output. NPM-VERSION-PRIVACY verifies the production projection. A disposable copied npm installation with modified bytes now proves that `--any-toolchain` refuses before its controlled child marker; its observed private fold is admitted only in a separate test fixture to preserve the earlier first-child FIFO-order property. URL-PRIVACY verifies the production redactor, exact reviewed-registry exception, top-level initialization order, a strict whole-process registry refusal, and fixed custom-scheme handling. NPM-LINK-CONTAINMENT executes the production npm fold over a contained chain, a direct escape, an outside hop that returns inside, and a dangling target; its process-exit stub observes refusal 2 for the negative cases, while direct resolver cases also cover hop exhaustion, invalid UTF-8, and non-owner write modes. The same production-fold fixture verifies that a FIFO receives the fixed special-entry refusal without exposing its name; this is branch coverage, not a claim that a special-file payload was executed. A package-manifest FIFO in the complete Linux fixture proves strict and bypassed exit 11 before npm can open it, and the shared refusal is applied after both folds. Removing either npm enforcement branch or an installed-tree special refusal makes its focused expectation fail. HISTORICAL-VERIFICATION executes the authored JavaScript block with explicit Node startup controls and a closed per-Git-child environment; inherited trace destinations, config-defined Trace2 targets, and object redirections have no effect, normal completion after both current and historical pairs emits one marker, while a late second-blob length or hash mismatch and an injected later native Git failure emit none. The whole-process Linux fixture also proves that `--any-toolchain` cannot bypass installed-tree containment and that non-owner write bits refuse across manifests, the contract, project configuration, installed files/directories/root, and the npm fold. Production-function fixtures prove bounded control flow; the Linux process cases prove no-record refusals. The Linux success case starts with polluted parent startup settings, applies the documented launch protocol, and checks a complete live observation, absent runtime output targets, and unchanged checkout bytes. Injected descriptor and executable-resolution failures are not claims of physical filesystem fault injection or an atomic snapshot. A platform-specific skipped case is not a passing runtime cell.

For the read-only proof, capture before and after hashes and sizes of the manifest, lockfile, complete contract, and all four generated outputs; a deterministic digest and census of **every** installed-tree entry including ignored files; raw Git porcelain; and the raw staged-path set. Run `git status` with `GIT_OPTIONAL_LOCKS=0`. Keep the transcript, output, and snapshots outside the repository. All pairs must match. Record the recorder's exact Git blob and SHA-256, Node/npm identity, source commit, and observation digest in the permanent candidate handoff.

The reduced reciprocal matrix below maps each of the 16 catalog rows exactly once. Source and destination pins are listed above. The [accepted comparison and full decisions](https://github.com/franklesniak/TerraformStyleGuide/issues/31#issuecomment-5763962101) found eight blockers, two same rows and six inapplicable rows; the final candidate handoff must bind destination tests and exact bytes before these repairs can close. Unchanged generator/workflow foundation closure is not reopened.

| Row | Status | Normative/implementation locator, observed behavior, and applicability proof |
| --- | --- | --- |
| GF-PARAMETERS | Same | Invocation contract and argument/cache guards; same supported flags, complete token withholding and checked registry environment. ARGUMENT-PRIVACY and NPM-REGISTRY-TRANSPORT. |
| GF-DESTINATION | Same | Fixed recorder root, `validateCacheDirectory`, physical/measured root exclusions and external private housekeeping authority. INPUT-DIRECTORY-CONTROL and Linux alias cases. |
| GF-CONTENT | Intentional difference | TF current-profile envelope and field/type map; retained historical T1 rows. Different identity/provenance data; identical bounded public projections and complete/incomplete semantics. |
| GF-SERIALIZATION | Same | `canonicalize`, `hashField`, installed/advisory framing and UTF-8/LF renderer retain common bytes. Different input graphs do not imply equal digests. |
| GF-WRITE | Inapplicable | Manual stdout recorder; no generator writer, candidate publication, replace or move. npm housekeeping is covered by NODE-LOCK. |
| GF-FAILURE | Same | Owning-phase wrappers, descriptor lifecycle, root guards, recursive-comparison refusal, bounded response and confidentiality checks. Focused failure suites exercise actual destination code. |
| GF-HOSTS | Same | Current Linux/x64 Node24.18.1/npm11.16.0/umask0022 requirement. HOST proves Windows refusal only; no Windows or BSD supply measurement. |
| GF-VERSION | Inapplicable | No PowerShell script/version-marker change. Exact JavaScript bytes identify this recorder. |
| GF-NODE-LOCK | Intentional difference | TF manifest SHA/blob constants and current profile tuple; identical npm authentication, child isolation, installed-tree admission and cache behavior. |
| GF-YAML | Inapplicable | No YAML package/API/parser or payload change; manifests and contract stay immutable validation inputs. |
| GF-ACTION-PINS | Inapplicable | No action pin, role or manifest change. |
| GF-ACTION-INPUTS | Inapplicable | No action input/default change. |
| GF-GIT | Intentional difference | External verifier binds TF current and historical object pairs with unchanged closed Git environment and native/byte checks; one marker follows all required verification. No Git in the recorder. |
| GF-GRAPH | Inapplicable | No workflow trigger, permissions, needs, writer or publisher change. |
| GF-CREDENTIALS | Same | Closed checked registry setting, operation-only npm wrappers and fixed public projections; no GitHub token or new credential authority. |
| GF-EVIDENCE | Intentional difference | Destination-specific tests, causal mutations and exact-tree before/after proof. Source passes cannot establish a TF result. |

Repository-specific differences are limited to the pinned input identities, TF schema/provenance/diagnostic labels, repository and method paths, retained historical record, and the additional required historical object pair. Equal failure strength follows from unchanged common checks and production-bound TF controls; no common safeguard is omitted. The repository maintainer owns these differences. Reopen on changed source, profile, manifest/lock, toolchain/platform assumption, advisory decision, test evidence, or a proposed difference that cannot prove equal security and failure strength. A new material exception requires its own evaluated decision. No dependency upgrade, shared runtime, workflow integration, advisory acceptance, protected instruction edit or issue22/24 change is included.
