// Derives the T1-SUPPLY-FREEZE-v1 digests reproducibly.
//
// Why this file exists. The original freeze record carried two fields recorded
// as "normalized SHA-256" -- one over `npm ls --all --json`, one over
// `npm audit --json`. The procedure that produced those two numbers was never
// committed; only its outputs were, in a pull request description. A digest
// whose derivation is unrecorded proves nothing, because a reader who computes
// a different value cannot tell whether the inputs changed or whether they
// normalized differently. Issue #22 requires "exact equality of every recorded
// field" against that record, which for those two fields no one could discharge.
//
// So the derivation lives here, in the repository, and the record quotes what
// this file produces. The two superseded values are NOT reproduced by this
// script and cannot be: their recipe is unknown. See docs/T1-SUPPLY-FREEZE-v1.md.
//
// This script is read-only. It runs no install, writes no file, and asserts the
// manifest and lockfile are byte-identical after it finishes.

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { existsSync, lstatSync, readdirSync, readFileSync, readlinkSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REVIEWED_NODE = 'v24.18.1';
const REVIEWED_NPM = '11.16.0';

// Reported and confirmed: the toolchain guard originally checked Node and npm
// and not the platform, so a reader on Windows passed the guard and then could
// not match the recorded tree digest however correct their lockfile was. npm's
// bin-links writes `.cmd` and `.ps1` shims on Windows where POSIX gets symlinks,
// so the two trees genuinely differ on disk. The digest is reproducible from the
// lockfile AND this platform, never from the lockfile alone, and saying only the
// latter was an overclaim in the record rather than a defect in the fold.
const REVIEWED_PLATFORM = 'linux';
const REVIEWED_ARCH = 'x64';

// The manifest and lockfile digests the workflow policy already pins. Repeated
// here so this script fails loudly rather than reporting digests for a tree
// that is not the reviewed one.
const REVIEWED_PACKAGE_SHA256 = 'e206cdb3562f0397e8eed7fb2c2586269a1f5335cdff2906da8d5e070426321e';
const REVIEWED_LOCK_SHA256 = '277f7168ab3a4f1f7a2565de13191d64b1572e7cb92b67b0972b3242bd4de062';

// The same two files as Git blob identities, which is what the record's blob
// column holds. Round 2, reported by Copilot: the documented way to check those
// was `git log -1 --format=%H -- <path>`, which prints a COMMIT hash. Measured,
// it printed 79ecff1d... where the record says 2b88a0ac..., so a reader
// following the instructions compared two different kinds of hash and would
// have concluded the record was wrong.
//
// Computing them here goes past the reported fix. A documented git incantation
// is a manual step a reader can mistype or skip; deriving the blob identity in
// the script makes it a checked field like every other value in the record.
const REVIEWED_PACKAGE_BLOB = '2b88a0ac85d3a8b7286040e6b1f6c4ddb4d3bce1';
const REVIEWED_LOCK_BLOB = '5c376ce2364e06c3ac4bc3ab8e3570e86b35f6ca';

// Install-shaping npm configuration, with the values the recorded tree was
// produced under. Round 2, reported: a reader with `bin-links=false` or
// `omit=dev` in a user or global .npmrc gets a different tree from the same
// lockfile, and the toolchain guard accepted them because Node, npm and the
// platform were all correct. Measured -- under `bin-links=false` npm ci exited
// 0 and produced 0 symlinks instead of the recorded 8, and the script reported
// a mismatched digest without a word of complaint.
//
// `npm config list --json` reports the EFFECTIVE configuration, including
// environment and .npmrc overrides, so these are checked rather than assumed.
//
// Round 3, reported: `package-lock-only` has to be listed explicitly. npm
// defines it as "only use the package-lock.json, ignoring node_modules", and it
// force-sets package-lock=true, so the entry below it cannot catch it
// indirectly. Measured -- `npm ci` under package-lock-only=true exits 0 saying
// "up to date" while reducing node_modules to a single .package-lock.json file.
const REVIEWED_NPM_CONFIG = Object.freeze({
  'bin-links': true,
  omit: [],
  include: [],
  'install-strategy': 'hoisted',
  'legacy-peer-deps': false,
  'package-lock': true,
  'package-lock-only': false,
});

// The process umask the recorded tree was installed under.
//
// Round 4, reported and confirmed. The fold records `mode & 0o111`, and an
// earlier reply to this PR argued that mask was umask-portable because "0o755
// under umask 077 is still 0o700, still executable". That is true about
// EXECUTABILITY and irrelevant to the RECORDED VALUE: 0o755 & 0o111 is 0o111,
// 0o700 & 0o111 is 0o100, so the two hash differently. Measured -- a full
// `npm ci` under umask 077 produced digest 0a215132... against the recorded
// 4cdc37a7..., a mismatch caused by nothing but the reader's umask.
//
// npm documents that folders and executables are masked by both npm's
// configured umask and the underlying system umask. npm's own `umask` config
// defaults to 0 and is reported by `npm config list`, so the config guard above
// sees nothing wrong; the process umask is a separate input it never looked at.
//
// So it is pinned rather than assumed away. This is the sixth environmental
// input the record pins, alongside Node, npm, platform, arch and npm config,
// and it is the cheapest of them for a reader to satisfy.
const REVIEWED_UMASK = 0o022;

// The registry the recorded advisory posture was snapshotted from. Checked only
// on the audit path -- see the comment at its use for why the installed tree is
// not exposed to this and a --no-audit run therefore is not refused.
const REVIEWED_REGISTRY = 'https://registry.npmjs.org/';

const strWorkflowDirectory = dirname(fileURLToPath(import.meta.url));
const arrArguments = process.argv.slice(2);
const boolJson = arrArguments.includes('--json');
const boolAnyToolchain = arrArguments.includes('--any-toolchain');
const boolSkipAudit = arrArguments.includes('--no-audit');

function sha256(strText) {
  return createHash('sha256').update(strText, 'utf8').digest('hex');
}

// "A JSON object", as distinct from everything else `typeof x === 'object'`
// admits. Both `null` and an array answer 'object', and each of those has now
// been reported as a hole in the audit shape guard -- null in round 2, arrays
// in round 6. One predicate, used everywhere, rather than a conjunction
// rewritten at each call site and wrong in a different way each time.
function isPlainObject(objValue) {
  return typeof objValue === 'object' && objValue !== null && !Array.isArray(objValue);
}

// A Git blob identity is SHA-1 over `blob <byteLength>\0<content>`. Implemented
// rather than shelled out to `git`, so the check works in an exported tree with
// no repository and cannot be confused by the working directory.
function gitBlobId(strText) {
  const objBytes = Buffer.from(strText, 'utf8');
  return createHash('sha1')
    .update(`blob ${objBytes.length}\0`, 'utf8')
    .update(objBytes)
    .digest('hex');
}

// One canonical serialization for the advisory record: keys in sorted order, no
// insignificant whitespace. Two readers who agree on the field selection below
// therefore agree on the bytes.
function canonicalize(objValue) {
  if (Array.isArray(objValue)) return `[${objValue.map(canonicalize).join(',')}]`;
  if (objValue && typeof objValue === 'object') {
    return `{${Object.keys(objValue).sort()
      .map((strKey) => `${JSON.stringify(strKey)}:${canonicalize(objValue[strKey])}`)
      .join(',')}}`;
  }
  return JSON.stringify(objValue ?? null);
}

function runNpm(arrNpmArguments) {
  return execFileSync('npm', arrNpmArguments, {
    cwd: strWorkflowDirectory,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function runNpmAllowingFailure(arrNpmArguments) {
  try {
    return runNpm(arrNpmArguments);
  } catch (objError) {
    // `npm audit` uses exit 1 to mean "advisories found", not "command failed".
    if (typeof objError.stdout === 'string' && objError.stdout.trim().startsWith('{')) {
      return objError.stdout;
    }
    throw objError;
  }
}

// The installed tree, folded from the bytes actually on disk.
//
// The first version of this script digested a normalized `npm ls --all --json`,
// because that is what the original record's field was named after. Attacking
// it before shipping showed the field would have been close to worthless:
// editing `node_modules/glob/package.json` to version 9.9.9 and re-running left
// the digest completely unchanged, because `npm ls` reports the resolved graph
// that the LOCKFILE determines, not the bytes present on disk. The lockfile's
// own SHA-256 is already a recorded field, so that digest restated an existing
// one while appearing to measure something new.
//
// This measures the stated intent instead -- what is actually installed, which
// is what actually runs. It is the same shape as the parser-tree fold the
// workflow policy already performs over node_modules/yaml, widened to the whole
// tree. Path and length are folded in alongside content so that renaming or
// truncating a file moves the digest, and symlink targets are folded in so a
// redirected `.bin` entry does too.
//
// Reproducibility is measured, not assumed: three independent `npm ci` installs
// in three different absolute paths produce identical digests, which also proves
// no machine-specific path leaks into the hashed bytes.
//
// Every variable-length field is length-prefixed, and that is load-bearing
// rather than tidiness. Reported and confirmed: the first framing wrote
// `L <path> -> <target>\n`, which is not injective, because a POSIX path or
// symlink target may itself contain a newline. Two genuinely different trees
// hashed identically --
//
//   tree one:  a -> "T\nL b -> U",  c -> "V"
//   tree two:  a -> "T",            b -> "U\nL c -> V"
//
// both feed `L a -> T\nL b -> U\nL c -> V\n`. Measured, not argued: the two
// directories produced the same digest.
//
// The same defect was in the FILE framing and was not reported; carrying the
// finding across found it. `F <path>:<length>\n<content>` collides just as
// readily -- one file named `a:2\nXYF b` containing `ZW` hashes exactly like two
// files `a` and `b` containing `XY` and `ZW`. Also measured.
//
// Length-prefixing makes the encoding prefix-free: a reader takes the tag, then
// digits up to the separator, then exactly that many bytes, with no ambiguity
// about where a field ends. Directories are recorded too, so a stray empty one
// cannot hide in a tree whose files are all accounted for.
function hashField(objHash, objField) {
  const objBytes = Buffer.isBuffer(objField) ? objField : Buffer.from(objField, 'utf8');
  objHash.update(`${objBytes.length}:`, 'utf8');
  objHash.update(objBytes);
}

function foldInstalledTree(strRoot) {
  const objHash = createHash('sha256');
  let intFiles = 0;
  let intSymbolicLinks = 0;
  let intDirectories = 0;
  // Round 4 backstop, corrected in round 5. The umask guard reads the RECORDING
  // process, so it cannot see a tree installed under a different umask in an
  // earlier shell. The tree's own permission bits are the tell that survives.
  //
  // Round 5, reported: the first version of this counted GROUP-READABLE files,
  // which distinguishes umask 077 (no group read) from 022 and nothing else.
  // umask 027 clears 0o027, leaving group read set -- 0o644 becomes 0o640 and
  // 0o755 becomes 0o750, both still group-readable. Measured: a tree installed
  // under 027 and recorded under 022 moved the digest to 62eddc28... while the
  // census still reported the recorded 2177 of 2177. A backstop blind to one of
  // the umasks the guard explicitly rejects is not a backstop.
  //
  // A histogram over the full permission bits distinguishes every umask, because
  // it records the bits themselves rather than a predicate over them:
  //   umask 022 -> {"644":2157,"755":20}
  //   umask 027 -> {"640":2157,"750":20}
  //   umask 077 -> {"600":2157,"700":20}
  // Recorded, not enforced, and deliberately NOT folded into the digest: the
  // full mode is machine state, and pinning it would reintroduce exactly the
  // drift the execute-bit normalization exists to avoid.
  const objModeHistogram = new Map();
  const walk = (strDirectory, strRelative) => {
    const arrEntries = [...readdirSync(strDirectory, { withFileTypes: true })]
      .sort((objLeft, objRight) => (objLeft.name < objRight.name ? -1 : objLeft.name > objRight.name ? 1 : 0));
    for (const objEntry of arrEntries) {
      const strPath = join(strDirectory, objEntry.name);
      const strChild = strRelative ? `${strRelative}/${objEntry.name}` : objEntry.name;
      if (objEntry.isSymbolicLink()) {
        intSymbolicLinks += 1;
        objHash.update('L', 'utf8');
        hashField(objHash, strChild);
        // Round 3, reported. readlinkSync's default string encoding decodes the
        // target as UTF-8, and a POSIX target is arbitrary bytes. Two distinct
        // targets therefore collided: raw 0x80 and raw 0x81 both decode to the
        // single replacement character U+FFFD and hashed identically -- measured
        // on ext4. Requesting a Buffer hashes the bytes the kernel actually
        // stored, which is what "injective" has to mean here.
        hashField(objHash, readlinkSync(strPath, { encoding: 'buffer' }));
        continue;
      }
      if (objEntry.isDirectory()) {
        intDirectories += 1;
        objHash.update('D', 'utf8');
        hashField(objHash, strChild);
        walk(strPath, strChild);
        continue;
      }
      if (!objEntry.isFile()) {
        // A socket, device or FIFO under node_modules is not something an
        // install produces. Recorded rather than skipped so it cannot hide.
        objHash.update('?', 'utf8');
        hashField(objHash, strChild);
        continue;
      }
      // Round 2, reported. The fold hashed path and content and ignored the
      // mode entirely, so `chmod -x` on a package binary left the digest
      // byte-identical while breaking the CLI with EACCES -- measured, the
      // digest did not move at all. A tree that cannot run is not the tree
      // this record claims to have measured.
      //
      // The NORMALIZED execute bits rather than the full mode. node-tar applies
      // the process umask when it extracts, so the read and write bits are a
      // property of the extracting machine; recording the full mode would make
      // the digest drift for a reason that has nothing to do with the package.
      //
      // Round 4 correction, and it matters because the original reasoning here
      // was wrong. This comment used to claim the execute bits "survive the
      // umasks that occur in practice: 0o755 under umask 077 is still 0o700,
      // still executable by its owner." The file does remain executable, but
      // the RECORDED VALUE moves -- 0o111 becomes 0o100 -- so the mask is no
      // more umask-portable than the full mode was, only less obviously so.
      // The umask is therefore pinned and checked; see REVIEWED_UMASK.
      //
      // Round 3, reported. An earlier version collapsed all three execute
      // classes to a single boolean, which meant 0o755 and 0o655 hashed
      // identically. That is not a harmless normalization: POSIX consults only
      // the OWNER bits when the process euid owns the file, so 0o655 is not
      // executable by the user who installed it. Measured with an owner-matched
      // process -- a 0o655 file owned by that user gives "Permission denied"
      // while group and other still carry +x. All three classes are recorded.
      intFiles += 1;
      const intMode = lstatSync(strPath).mode;
      const strPermissions = (intMode & 0o777).toString(8).padStart(3, '0');
      objModeHistogram.set(strPermissions, (objModeHistogram.get(strPermissions) ?? 0) + 1);
      objHash.update('F', 'utf8');
      hashField(objHash, strChild);
      hashField(objHash, (intMode & 0o111).toString(8).padStart(3, '0'));
      hashField(objHash, readFileSync(strPath));
    }
  };
  walk(strRoot, '');
  return {
    sha256: objHash.digest('hex'),
    files: intFiles,
    symlinks: intSymbolicLinks,
    directories: intDirectories,
    modes: Object.fromEntries([...objModeHistogram.entries()].sort(
      (objLeft, objRight) => (objLeft[0] < objRight[0] ? -1 : 1))),
  };
}

// The advisory posture, reduced to what a policy decision actually turns on.
//
// Kept: which package is affected, its resolved severity, whether it is direct,
// and per advisory the stable GitHub Security Advisory identifier, its severity,
// CWE list, CVSS score and vector, and affected range.
//
// Dropped, deliberately:
//   * `title` -- prose. GitHub rewords advisory titles without the advisory
//     changing identity, so a title in the digest produces drift that means
//     nothing. The GHSA id is the identity.
//   * `fixAvailable` -- changes the day a fix ships upstream. That is news, but
//     it is not a change in what this repository installs.
//   * `effects` and `nodes` -- derivable from the tree fold above, so including
//     them would make one change move two numbers.
//
// Unlike the tree fold, this digest is NOT reproducible from the lockfile alone
// and is not meant to be: it is a snapshot of an advisory database that changes
// as new advisories are published. Drift here means "the published advisories
// moved", which calls for a policy re-decision, not a failed build.
function normalizeAudit(objAudit) {
  const objVulnerabilities = objAudit.vulnerabilities ?? {};
  const objOutput = {
    auditReportVersion: objAudit.auditReportVersion ?? null,
    counts: objAudit.metadata?.vulnerabilities ?? null,
    packages: {},
  };
  for (const strName of Object.keys(objVulnerabilities).sort()) {
    const objVulnerability = objVulnerabilities[strName];
    const arrAdvisories = [];
    for (const objVia of objVulnerability.via ?? []) {
      // A `via` entry that is a bare string names another package in the chain
      // rather than an advisory; the chain is already covered by the tree.
      if (typeof objVia !== 'object' || objVia === null) continue;
      const strUrl = typeof objVia.url === 'string' ? objVia.url : '';
      const objMatch = strUrl.match(/GHSA-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}/u);
      arrAdvisories.push({
        id: objMatch ? objMatch[0] : `npm-source-${objVia.source ?? 'unknown'}`,
        severity: objVia.severity ?? null,
        cwe: [...(objVia.cwe ?? [])].sort(),
        cvssScore: objVia.cvss?.score ?? null,
        cvssVector: objVia.cvss?.vectorString ?? null,
        range: objVia.range ?? null,
      });
    }
    arrAdvisories.sort((objLeft, objRight) => (objLeft.id < objRight.id ? -1 : objLeft.id > objRight.id ? 1 : 0));
    objOutput.packages[strName] = {
      severity: objVulnerability.severity ?? null,
      isDirect: objVulnerability.isDirect ?? null,
      range: objVulnerability.range ?? null,
      advisories: arrAdvisories,
    };
  }
  return objOutput;
}

const strPackagePath = join(strWorkflowDirectory, 'package.json');
const strLockPath = join(strWorkflowDirectory, 'package-lock.json');
const strPackageBefore = readFileSync(strPackagePath, 'utf8');
const strLockBefore = readFileSync(strLockPath, 'utf8');

const strNodeVersion = process.version;
const strNpmVersion = runNpm(['--version']).trim();

if (!boolAnyToolchain && (strNodeVersion !== REVIEWED_NODE || strNpmVersion !== REVIEWED_NPM
  || process.platform !== REVIEWED_PLATFORM || process.arch !== REVIEWED_ARCH)) {
  process.stderr.write(
    'supply-freeze: refusing to record digests on an unreviewed toolchain.\n' +
    `  observed Node ${strNodeVersion}, npm ${strNpmVersion}, ${process.platform}/${process.arch}\n` +
    `  reviewed Node ${REVIEWED_NODE}, npm ${REVIEWED_NPM}, ${REVIEWED_PLATFORM}/${REVIEWED_ARCH}\n` +
    '  pass --any-toolchain to compute anyway; the result is then not a freeze record.\n');
  process.exit(2);
}

// This script's own digest, reported alongside the values it derives.
//
// Raised while answering the reproduction-steps finding, and it is the reason
// that finding is more than a documentation fix: "run the script and compare"
// is ambiguous unless the reader knows WHICH script. Review has moved the
// installed-tree digest several times without any dependency changing -- making
// the fold injective, then recording execute bits, then hashing symlink targets
// as raw bytes. That is exactly the confusion a reader would hit: a correct
// tree, a correct lockfile, and a number that does not match, with nothing in
// the record to explain why. Specific digests are deliberately not quoted here;
// a number in a comment has nothing deriving it and goes stale silently.
//
// No circularity: the digest is computed over the file and never stored in it.
const strScriptSha256 = sha256(readFileSync(fileURLToPath(import.meta.url), 'utf8'));

// Install-shaping configuration, checked before anything is measured. See
// REVIEWED_NPM_CONFIG above for why: the toolchain guard passes a reader whose
// ambient npm configuration silently produced a different tree.
if (!boolAnyToolchain) {
  const objEffective = JSON.parse(runNpm(['config', 'list', '--json']));
  const arrDrift = Object.entries(REVIEWED_NPM_CONFIG)
    .filter(([strKey, objExpected]) =>
      canonicalize(objEffective[strKey] ?? null) !== canonicalize(objExpected))
    .map(([strKey, objExpected]) =>
      `  ${strKey.padEnd(18)} observed ${JSON.stringify(objEffective[strKey] ?? null)}, reviewed ${JSON.stringify(objExpected)}`);
  if (arrDrift.length > 0) {
    process.stderr.write(
      'supply-freeze: npm configuration would shape the install away from the reviewed tree.\n' +
      `${arrDrift.join('\n')}\n` +
      '  these come from the environment or a user/global .npmrc and change what npm ci produces.\n' +
      '  re-install with them at their reviewed values before recording a freeze.\n');
    process.exit(6);
  }
}

// The process umask, which npm's own config does not report. See REVIEWED_UMASK.
//
// This reads the umask of the RECORDING process, which is a proxy for the one
// the install ran under -- the same install-time/measure-time gap the
// package-lock-only guard has. It catches the common case, where one shell does
// both. For the case where it cannot see the cause, the permission-bit
// histogram recorded below is the backstop: it records the observed modes
// themselves, so umask 022 (644/755), 027 (640/750) and 077 (600/700) are all
// distinguishable from the record alone -- as is any other umask, which a
// predicate over a single chosen bit could not manage.
if (!boolAnyToolchain && process.umask() !== REVIEWED_UMASK) {
  process.stderr.write(
    'supply-freeze: refusing to record digests under an unreviewed umask.\n' +
    `  umask              observed 0${process.umask().toString(8).padStart(3, '0')}, `
      + `reviewed 0${REVIEWED_UMASK.toString(8).padStart(3, '0')}\n` +
    '  npm applies the process umask when it extracts, so this changes the recorded\n' +
    '  execute bits and therefore the installed-tree digest.\n' +
    '  re-install and re-record under the reviewed umask:\n' +
    `    (umask 0${REVIEWED_UMASK.toString(8).padStart(3, '0')}; `
      + 'npm ci --ignore-scripts --no-audit --no-fund)\n');
  process.exit(8);
}

const objRecord = {
  script: { sha256: strScriptSha256 },
  toolchain: {
    node: strNodeVersion,
    npm: strNpmVersion,
    platform: process.platform,
    arch: process.arch,
    umask: `0${process.umask().toString(8).padStart(3, '0')}`,
  },
  manifest: {
    'package.json': sha256(strPackageBefore),
    'package-lock.json': sha256(strLockBefore),
  },
  manifestBlobs: {
    'package.json': gitBlobId(strPackageBefore),
    'package-lock.json': gitBlobId(strLockBefore),
  },
  matchesReviewedManifest:
    sha256(strPackageBefore) === REVIEWED_PACKAGE_SHA256 &&
    sha256(strLockBefore) === REVIEWED_LOCK_SHA256 &&
    gitBlobId(strPackageBefore) === REVIEWED_PACKAGE_BLOB &&
    gitBlobId(strLockBefore) === REVIEWED_LOCK_BLOB,
};

// Reported and confirmed: this used to record `matchesReviewedManifest: false`
// and then print a full record and exit 0, which contradicted the comment on the
// pinned constants above and let an automated caller reading the process status
// accept digests taken over supply inputs nobody reviewed. Refusing here, before
// node_modules is even opened, is what that comment already claimed.
if (!boolAnyToolchain && !objRecord.matchesReviewedManifest) {
  process.stderr.write(
    'supply-freeze: refusing to record digests for an unreviewed manifest.\n' +
    `  package.json       observed ${objRecord.manifest['package.json']}\n` +
    `                     reviewed ${REVIEWED_PACKAGE_SHA256}\n` +
    `  package-lock.json  observed ${objRecord.manifest['package-lock.json']}\n` +
    `                     reviewed ${REVIEWED_LOCK_SHA256}\n` +
    `  package.json       blob     ${gitBlobId(strPackageBefore)}\n` +
    `                     reviewed ${REVIEWED_PACKAGE_BLOB}\n` +
    '  a changed manifest needs a new reviewed freeze, not a digest against this one.\n');
  process.exit(4);
}

// `npm ls` is kept, but as a consistency assertion rather than a digest source:
// it exits non-zero when the installed tree does not satisfy the lockfile, which
// is the one question it answers that the byte fold cannot.
const strTreeRoot = join(strWorkflowDirectory, 'node_modules');
try {
  runNpm(['ls', '--all', '--json']);
  objRecord.treeSatisfiesLockfile = true;
} catch {
  objRecord.treeSatisfiesLockfile = false;
}

// Round 3. Carried across from the package-lock-only finding rather than
// reported directly, because it is the same defect the manifest guard above
// already fixed, left standing one field over: `treeSatisfiesLockfile` was
// RECORDED and never ENFORCED. Measured -- a tree with one package directory
// deleted, and a tree reduced by `package-lock-only=true` to a single
// .package-lock.json file, both exited 0 and printed a full freeze record.
//
// A missing node_modules used to reach readdirSync and abort with a raw ENOENT
// stack trace, which tells a reader nothing about what this script wanted.
if (!boolAnyToolchain && (!existsSync(strTreeRoot) || !objRecord.treeSatisfiesLockfile)) {
  process.stderr.write(
    'supply-freeze: refusing to record digests for a tree that is not the installed tree.\n' +
    `  node_modules       ${existsSync(strTreeRoot) ? 'present' : 'MISSING'}\n` +
    `  satisfies lockfile ${objRecord.treeSatisfiesLockfile}\n` +
    '  install first with the documented command, then record:\n' +
    '    npm ci --ignore-scripts --no-audit --no-fund\n' +
    '  note that package-lock-only=true makes npm ci a no-op that reports success.\n');
  process.exit(7);
}

const objTree = foldInstalledTree(strTreeRoot);
objRecord.installedTreeSha256 = objTree.sha256;
objRecord.installedTreeFiles = objTree.files;
objRecord.installedTreeSymlinks = objTree.symlinks;
objRecord.installedTreeDirectories = objTree.directories;
objRecord.installedTreeModes = objTree.modes;

if (boolSkipAudit) {
  objRecord.auditSha256 = null;
} else {
  // The advisory posture is a snapshot of whatever registry answers the audit
  // request, and nothing else in this script constrains which one that is.
  //
  // Round 5, reported. npm posts the audit to the configured registry, so a
  // reader behind an enterprise proxy or a private mirror gets a posture digest
  // computed from THAT registry's advisory view. A mirror that filters
  // advisories, or simply has none, returns a schema-valid report -- so the
  // round-1 shape guard passes it -- and the script records a confident-looking
  // clean posture at exit 0. That is the same class of defect as the endpoint
  // error the shape guard was added for, arriving from a source that looks
  // healthy.
  //
  // Checked HERE rather than in REVIEWED_NPM_CONFIG, and that placement is the
  // point. The registry does not shape the installed tree: every one of the 125
  // packages in the lockfile carries an `integrity` hash, and `npm ci` verifies
  // each tarball against it, so a substituted registry cannot change the bytes
  // on disk without failing the install outright. Only the advisory half is
  // exposed. Refusing a `--no-audit` run on a mirror would be a false failure
  // for a reader whose tree is provably byte-identical.
  const strRegistry = runNpm(['config', 'get', 'registry']).trim();
  if (!boolAnyToolchain && strRegistry !== REVIEWED_REGISTRY) {
    process.stderr.write(
      'supply-freeze: refusing to record an advisory posture from an unreviewed registry.\n' +
      `  registry           observed ${strRegistry}\n` +
      `                     reviewed ${REVIEWED_REGISTRY}\n` +
      '  npm posts the audit request to the configured registry, and a mirror that\n' +
      '  filters or lacks advisories returns a schema-valid but misleadingly clean report.\n' +
      '  the installed tree is unaffected -- lockfile integrity hashes pin those bytes --\n' +
      '  so --no-audit records the lockfile-derived fields from any registry.\n');
    process.exit(9);
  }
  objRecord.registry = strRegistry;
  const objAudit = JSON.parse(runNpmAllowingFailure(['audit', '--json']));
  // Reported and confirmed, and the most serious of the round. `npm audit`
  // exits nonzero for two completely different reasons: advisories were found,
  // and the audit endpoint failed. Under --json it prints a JSON object either
  // way, so the old "stdout starts with a brace" test accepted an endpoint
  // error as a report. Measured against a dead registry: npm emitted
  // {"message":"... ECONNREFUSED ...","error":{...}}, normalizeAudit saw zero
  // packages, and the script printed a confident posture digest over an empty
  // set and exited 0. A network blip would have silently rewritten the record.
  //
  // The shape is checked rather than the exit status, because the exit status
  // is what conflates the two cases in the first place.
  // Round 2, reported by Copilot: `typeof null === 'object'`, so the original
  // metadata test accepted `metadata.vulnerabilities: null` and the counts then
  // recorded as null -- the exact endpoint-failure shape the guard exists to
  // refuse, readmitted through a JavaScript quirk. The null test was present on
  // `vulnerabilities` and absent on `metadata.vulnerabilities`; asymmetry in a
  // guard is a defect even when both halves look alike.
  //
  // Strengthened past the reported fix: the severity counts must each be an
  // integer. That refuses null, an empty object, and a shape change, rather
  // than only the one value that was reported.
  //
  // Round 6, reported by Copilot: that strengthening still was not the class.
  // `typeof [] === 'object'` too, so an ARRAY passed both tests -- measured,
  // `vulnerabilities: []` and an array-shaped `metadata.vulnerabilities` were
  // both accepted. Round 2 closed `null` and left `[]` open, which is the same
  // "fixed the reported value, not the predicate" mistake one step over.
  //
  // Both tests now route through isPlainObject rather than repeating a
  // hand-written conjunction, so the two halves cannot drift apart again --
  // that asymmetry is what admitted `null` in the first place.
  const objCounts = objAudit.metadata?.vulnerabilities;
  const arrSeverities = ['info', 'low', 'moderate', 'high', 'critical', 'total'];
  if (!Number.isInteger(objAudit.auditReportVersion)
    || !isPlainObject(objAudit.vulnerabilities)
    || !isPlainObject(objCounts)
    || !arrSeverities.every((strSeverity) => Number.isInteger(objCounts[strSeverity]))) {
    process.stderr.write(
      'supply-freeze: npm audit did not return an audit report.\n' +
      `  npm said: ${typeof objAudit.message === 'string' ? objAudit.message : JSON.stringify(objAudit).slice(0, 300)}\n` +
      '  this is an endpoint or format failure, not an advisory posture; nothing is recorded.\n' +
      '  pass --no-audit to record the lockfile-derived fields alone.\n');
    process.exit(5);
  }
  const objNormalizedAudit = normalizeAudit(objAudit);
  objRecord.auditSha256 = sha256(canonicalize(objNormalizedAudit));
  objRecord.auditCounts = objNormalizedAudit.counts;
  objRecord.auditPackages = Object.fromEntries(
    Object.entries(objNormalizedAudit.packages).map(([strName, objValue]) => [
      strName,
      // An empty advisory list is not a missing entry: the package is reached
      // only through a vulnerable dependency, so its `via` names packages
      // rather than advisories. Saying so beats printing empty parentheses.
      objValue.advisories.length > 0
        ? `${objValue.severity} (${objValue.advisories.map((objAdvisory) => objAdvisory.id).join(', ')})`
        : `${objValue.severity} (inherited through dependencies)`,
    ]));
}

// Read-only is an assertion, not a claim. `npm ls` and `npm audit` are supposed
// to leave both files alone; this proves they did rather than trusting them.
if (readFileSync(strPackagePath, 'utf8') !== strPackageBefore
  || readFileSync(strLockPath, 'utf8') !== strLockBefore) {
  process.stderr.write('supply-freeze: package metadata changed while reading it; refusing to report\n');
  process.exit(3);
}

// Round 7, reported. `--any-toolchain` promised output that is "explicitly not
// a freeze record", and then emitted the identical heading and the identical
// JSON schema as a reviewed run -- measured under umask 077, the bypassed run
// printed the same `T1-SUPPLY-FREEZE-v1 digests` banner with
// `matchesReviewedManifest: true` and no key distinguishing it. A consumer
// reading saved output could not tell the two apart without independently
// re-deriving every pinned value, which is the work the record exists to save.
//
// The promise was in the help text and the document; it was not in the output.
// It is now a field, so it survives being piped to a file.
//
// --no-audit is tracked separately rather than lumped in: it produces a
// legitimately partial record whose missing half is visible as a null digest,
// which is a different thing from a record whose guards did not run.
const arrNotFreezeBecause = [];
if (boolAnyToolchain) arrNotFreezeBecause.push('guards bypassed with --any-toolchain');
if (boolSkipAudit) arrNotFreezeBecause.push('advisory posture not recorded (--no-audit)');
objRecord.freezeRecord = arrNotFreezeBecause.length === 0;
objRecord.notFreezeRecordBecause = arrNotFreezeBecause;

if (boolJson) {
  process.stdout.write(`${JSON.stringify(objRecord, null, 2)}\n`);
} else {
  process.stdout.write(
    (objRecord.freezeRecord
      ? 'T1-SUPPLY-FREEZE-v1 digests\n'
      : `T1-SUPPLY-FREEZE-v1 digests -- NOT A FREEZE RECORD\n${
        arrNotFreezeBecause.map((strReason) => `  !! ${strReason}\n`).join('')}`) +
    `  script sha256        ${objRecord.script.sha256}\n` +
    `  Node                 ${objRecord.toolchain.node}\n` +
    `  npm                  ${objRecord.toolchain.npm}\n` +
    `  platform             ${objRecord.toolchain.platform}/${objRecord.toolchain.arch}\n` +
    `  umask                ${objRecord.toolchain.umask}\n` +
    `  package.json         ${objRecord.manifest['package.json']}\n` +
    `  package-lock.json    ${objRecord.manifest['package-lock.json']}\n` +
    `  matches reviewed     ${objRecord.matchesReviewedManifest}\n` +
    `  tree satisfies lock  ${objRecord.treeSatisfiesLockfile}\n` +
    `  installed tree       ${objRecord.installedTreeSha256}\n` +
    `    (${objRecord.installedTreeFiles} files, ${objRecord.installedTreeSymlinks} symlinks, ${objRecord.installedTreeDirectories} directories on disk)\n` +
    `    (file permissions ${JSON.stringify(objRecord.installedTreeModes)}; a different shape is consistent with a different install umask, or with modes changed after install)\n` +
    (objRecord.auditSha256
      ? `  registry             ${objRecord.registry}\n` +
        `  advisory posture     ${objRecord.auditSha256}\n` +
        `  advisory counts      ${JSON.stringify(objRecord.auditCounts)}\n` +
        Object.entries(objRecord.auditPackages)
          .map(([strName, strValue]) => `    ${strName.padEnd(20)} ${strValue}\n`).join('')
      : '  advisory posture     (skipped)\n'));
}
