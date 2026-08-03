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
import { lstatSync, readdirSync, readFileSync, readlinkSync } from 'node:fs';
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
// 0, produced 0 symlinks instead of 8, and the script reported digest
// 89a19867... against the recorded ce95cd20... without a word of complaint.
//
// `npm config list --json` reports the EFFECTIVE configuration, including
// environment and .npmrc overrides, so these are checked rather than assumed.
const REVIEWED_NPM_CONFIG = Object.freeze({
  'bin-links': true,
  omit: [],
  include: [],
  'install-strategy': 'hoisted',
  'legacy-peer-deps': false,
  'package-lock': true,
});

const strWorkflowDirectory = dirname(fileURLToPath(import.meta.url));
const arrArguments = process.argv.slice(2);
const boolJson = arrArguments.includes('--json');
const boolAnyToolchain = arrArguments.includes('--any-toolchain');
const boolSkipAudit = arrArguments.includes('--no-audit');

function sha256(strText) {
  return createHash('sha256').update(strText, 'utf8').digest('hex');
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
        hashField(objHash, readlinkSync(strPath));
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
      // The NORMALIZED executable bit rather than the full mode, and that is a
      // measurement rather than a preference. All three reference installs
      // agree on the full mode here (0o644 x2157, 0o755 x20), but node-tar
      // applies the process umask when it extracts, so the non-execute bits are
      // a property of the extracting machine and would make the digest
      // irreproducible under a different umask. The execute bit survives the
      // umasks that occur in practice: 0o755 under umask 077 is still 0o700,
      // still executable. So exactly one bit of mode is recorded, the one that
      // decides whether the file can run.
      intFiles += 1;
      objHash.update('F', 'utf8');
      hashField(objHash, strChild);
      hashField(objHash, (lstatSync(strPath).mode & 0o111) === 0 ? '-' : 'x');
      hashField(objHash, readFileSync(strPath));
    }
  };
  walk(strRoot, '');
  return {
    sha256: objHash.digest('hex'),
    files: intFiles,
    symlinks: intSymbolicLinks,
    directories: intDirectories,
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
// is ambiguous unless the reader knows WHICH script. The framing correction in
// this same round moved the installed-tree digest from 32a914d9 to ce95cd20
// without any dependency changing, which is exactly the confusion a reader
// would hit -- a correct tree, a correct lockfile, and a number that does not
// match, with nothing in the record to explain why.
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

const objRecord = {
  script: { sha256: strScriptSha256 },
  toolchain: {
    node: strNodeVersion,
    npm: strNpmVersion,
    platform: process.platform,
    arch: process.arch,
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
try {
  runNpm(['ls', '--all', '--json']);
  objRecord.treeSatisfiesLockfile = true;
} catch {
  objRecord.treeSatisfiesLockfile = false;
}

const objTree = foldInstalledTree(join(strWorkflowDirectory, 'node_modules'));
objRecord.installedTreeSha256 = objTree.sha256;
objRecord.installedTreeFiles = objTree.files;
objRecord.installedTreeSymlinks = objTree.symlinks;
objRecord.installedTreeDirectories = objTree.directories;

if (boolSkipAudit) {
  objRecord.auditSha256 = null;
} else {
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
  const objCounts = objAudit.metadata?.vulnerabilities;
  const arrSeverities = ['info', 'low', 'moderate', 'high', 'critical', 'total'];
  if (!Number.isInteger(objAudit.auditReportVersion)
    || typeof objAudit.vulnerabilities !== 'object' || objAudit.vulnerabilities === null
    || typeof objCounts !== 'object' || objCounts === null
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

if (boolJson) {
  process.stdout.write(`${JSON.stringify(objRecord, null, 2)}\n`);
} else {
  process.stdout.write(
    'T1-SUPPLY-FREEZE-v1 digests\n' +
    `  script sha256        ${objRecord.script.sha256}\n` +
    `  Node                 ${objRecord.toolchain.node}\n` +
    `  npm                  ${objRecord.toolchain.npm}\n` +
    `  platform             ${objRecord.toolchain.platform}/${objRecord.toolchain.arch}\n` +
    `  package.json         ${objRecord.manifest['package.json']}\n` +
    `  package-lock.json    ${objRecord.manifest['package-lock.json']}\n` +
    `  matches reviewed     ${objRecord.matchesReviewedManifest}\n` +
    `  tree satisfies lock  ${objRecord.treeSatisfiesLockfile}\n` +
    `  installed tree       ${objRecord.installedTreeSha256}\n` +
    `    (${objRecord.installedTreeFiles} files, ${objRecord.installedTreeSymlinks} symlinks, ${objRecord.installedTreeDirectories} directories on disk)\n` +
    (objRecord.auditSha256
      ? `  advisory posture     ${objRecord.auditSha256}\n` +
        `  advisory counts      ${JSON.stringify(objRecord.auditCounts)}\n` +
        Object.entries(objRecord.auditPackages)
          .map(([strName, strValue]) => `    ${strName.padEnd(20)} ${strValue}\n`).join('')
      : '  advisory posture     (skipped)\n'));
}
