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
import { existsSync, lstatSync, readdirSync, readFileSync, readlinkSync, realpathSync, statSync } from 'node:fs';
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
// it printed a COMMIT hash where the record holds a BLOB id, so a reader
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
//
// Round 9, reported and confirmed, and the most serious of that round. npm has
// its OWN `umask` config, separate from the process umask the guard below
// checks, and it was absent from this list. npm documents it as additive rather
// than a replacement -- "npm does not circumvent this, but rather adds the
// `--umask` config to it" -- with a default of 0, and it is not deprecated.
//
// Measured, two real `npm ci` installs from the identical lockfile with the
// process umask at 0022 in BOTH:
//   npm umask 0   (default) -> {"644":2157,"755":20}            the recorded digest
//   npm umask 077           -> {"600":2156,"700":12,"755":8,"644":1}   a different one
// The second run then emitted `freezeRecord: true` with an empty
// notFreezeRecordBecause, matchesReviewedManifest true and `umask 0022` printed
// in its own toolchain block -- a complete, unqualified freeze record over a
// tree that is not the reviewed one. The process-umask guard looked straight at
// it and was satisfied, because it reads a different umask.
//
// `npm config list --json` does report the key (63 under NPM_CONFIG_UMASK=077),
// so this guard could always have seen it and simply never asked. That is the
// same "an install-shaping setting the config guard could see and didn't"
// defect as bin-links in round 2, package-lock-only in round 3 and the registry
// in round 5. The permission histogram is the backstop here for the same reason
// it is for the process umask: it records the observed modes rather than a
// predicate over them, so a tree installed under either umask names its own
// cause even when neither guard was watching at install time.
const REVIEWED_NPM_CONFIG = Object.freeze({
  'bin-links': true,
  omit: [],
  include: [],
  'install-strategy': 'hoisted',
  'legacy-peer-deps': false,
  'package-lock': true,
  'package-lock-only': false,
  umask: 0,
  // Round 11, reported and confirmed. npm applies this option when it CREATES
  // lockfiles, and that includes the hidden `node_modules/.package-lock.json`
  // the fold hashes. npm documents it as producing lockfiles without registry
  // `resolved` keys, default false.
  //
  // Measured with a real `npm ci` from the identical lockfile: the hidden
  // lockfile came back with 0 `resolved` keys against the reviewed tree's 125,
  // moving the installed-tree digest while the census still
  // reported the recorded 2177/8/336 and nothing refused. The package payloads
  // were byte-identical; only npm's own bookkeeping file changed.
  //
  // Excluding `.package-lock.json` from the fold was considered and rejected:
  // that removes real coverage of a file npm writes and tools read, to dodge a
  // configuration problem the guard should simply catch.
  'omit-lockfile-registry-resolved': false,
});

// Transport and trust, checked ONLY when an audit will run.
//
// Round 19, reported: pinning the registry URL pins where the request is
// ADDRESSED, not where it goes or who it trusts. npm honours `proxy`,
// `https-proxy` and the standard proxy environment variables for outgoing HTTPS,
// and `ca`, `cafile` and `strict-ssl` decide which certificates count -- so a
// TLS-intercepting proxy with a trusted custom CA can return a filtered,
// schema-valid audit while this script records the posture as public-registry.
//
// Round 20, reported: putting them in the table above made them unconditional,
// which broke `--no-audit` behind a proxy with exit 6. That is precisely the
// false failure the registry guard was placed on the audit path to avoid in
// round 5 -- the installed tree is pinned by lockfile integrity hashes and is
// not exposed to any of this. Separated so the install-shaping checks stay
// unconditional and these do not.
const REVIEWED_NPM_TRANSPORT = Object.freeze({
  proxy: null,
  'https-proxy': null,
  noproxy: [],
  ca: null,
  cafile: null,
  'strict-ssl': true,
});

// Round 20, reported. Validating the six once did not bind them: the audit runs
// in a separate process that reloads configuration, so an .npmrc rewritten in
// between reinstated a proxy the check had just cleared. Derived from the
// reviewed values themselves, so the values compared and the values used cannot
// diverge.
// A null reviewed value cannot be expressed as a flag: measured, `--proxy=`
// makes npm warn `invalid config proxy=""` and `--ca=` breaks the TLS handshake
// outright, because an empty string is not the same as unset. Only non-null
// values become flags; the null ones are bound by scrubbing them from the
// child's environment instead.
function transportFlags() {
  return Object.entries(REVIEWED_NPM_TRANSPORT)
    .filter(([, objValue]) => objValue !== null)
    .map(([strKey, objValue]) =>
      `--${strKey}=${Array.isArray(objValue) ? objValue.join(',') : objValue}`);
}

// The environment half of the same binding. npm reads npm_config_* and the
// standard proxy variables; both are fixed when this process starts and were
// covered by the pre-audit check, but removing them from the child makes the
// binding explicit rather than inherited.
function transportEnvironment() {
  const objEnv = { ...process.env };
  // Round 21, reported. NODE_EXTRA_CA_CERTS is a Node-level trust root, invisible
  // to `npm config list` -- which keeps reporting ca: null and strict-ssl: true --
  // so an interceptor whose certificate chains to it could return a filtered,
  // schema-valid report attributed to the public registry. Checking npm's trust
  // settings and inheriting Node's was a gap the previous round's fix left open.
  // Round 22, reported. NODE_EXTRA_CA_CERTS was one of several Node-level trust
  // overrides. NODE_USE_SYSTEM_CA, and --use-system-ca / --use-openssl-ca passed
  // through NODE_OPTIONS, redirect Node at the system or OpenSSL store, where an
  // enterprise or interceptor CA can authenticate a filtered response while npm
  // still reports ca: null and strict-ssl: true. SSL_CERT_FILE and SSL_CERT_DIR
  // are the OpenSSL half of the same thing.
  delete objEnv.NODE_EXTRA_CA_CERTS;
  delete objEnv.NODE_USE_SYSTEM_CA;
  delete objEnv.SSL_CERT_FILE;
  delete objEnv.SSL_CERT_DIR;
  if (typeof objEnv.NODE_OPTIONS === 'string') {
    const strScrubbed = objEnv.NODE_OPTIONS
      .split(/\s+/u)
      .filter((strOption) => strOption !== '--use-system-ca' && strOption !== '--use-openssl-ca')
      .join(' ')
      .trim();
    if (strScrubbed) objEnv.NODE_OPTIONS = strScrubbed;
    else delete objEnv.NODE_OPTIONS;
  }
  for (const strKey of Object.keys(objEnv)) {
    const strLower = strKey.toLowerCase();
    if (strLower === 'http_proxy' || strLower === 'https_proxy' || strLower === 'no_proxy'
      || Object.keys(REVIEWED_NPM_TRANSPORT).some(
        (strConfig) => strLower === `npm_config_${strConfig.replace(/-/gu, '_')}`)) {
      if (REVIEWED_NPM_TRANSPORT[strLower.replace(/^npm_config_/u, '').replace(/_/gu, '-')] === null
        || strLower.endsWith('_proxy')) delete objEnv[strKey];
    }
  }
  return objEnv;
}

// The process umask the recorded tree was installed under.
//
// Round 4, reported and confirmed. The fold records `mode & 0o111`, and an
// earlier reply to this PR argued that mask was umask-portable because "0o755
// under umask 077 is still 0o700, still executable". That is true about
// EXECUTABILITY and irrelevant to the RECORDED VALUE: 0o755 & 0o111 is 0o111,
// 0o700 & 0o111 is 0o100, so the two hash differently. Measured -- a full
// `npm ci` under umask 077 produced a digest that differs from the recorded
// one, a mismatch caused by nothing but the reader's umask.
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

// Round 15, reported. This was read three times -- once by the guard, once by
// its own failure message, and once by the record -- so the value refused and
// the value reported were separate observations of the same thing. Read once,
// formatted once, used everywhere.
const intObservedUmask = process.umask();
const strObservedUmask = `0${intObservedUmask.toString(8).padStart(3, '0')}`;

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

// Round 12, reported. The self-read used to sit AFTER the toolchain guard, and
// therefore after an `npm --version` subprocess -- tens of milliseconds during
// which this file could be replaced. The process would go on executing the
// source Node had already loaded while reporting the SHA-256 of a different
// file, so restoring the reviewed bytes over a modified version inside that
// window produced the authoritative script digest for a run that derived every
// other field with other code. Neither the final content checks nor the
// quiescence sweep looked at the script.
//
// Three changes, because no one of them is sufficient. The read is now the
// first thing this script does, so the window between Node's load and the read
// contains no code of ours. The bytes are kept and re-compared at the end. And
// the script's own inode-change time is checked against PROCESS START rather
// than against the later recording ceiling, so a replacement anywhere in the
// process lifetime is caught.
//
// The residual, stated rather than implied: Node reads and compiles this file
// before any statement here executes, so a replacement in THAT window is
// invisible to the script itself and can only be closed by a trusted launcher
// hashing the file before invoking node. That is outside what one read-only
// script can bootstrap, and the record says so.
//
// Round 13, reported. `import.meta.url` is NOT always the file Node compiled.
// Under `--preserve-symlinks-main` -- which an ambient NODE_OPTIONS can supply --
// it is the symlink that was invoked, and measured, lstat on it reports
// isSymbolicLink() true while the source Node actually loaded is the target.
// Every check here would then have described the link's inode: its content
// comparison reads through the link and its ctime never moves, so a target
// modified at compile time and restored before the self-read would emit the
// reviewed digest for code that was never reviewed.
//
// Resolving first makes every subsequent check -- the digest, the content
// re-comparison and the ctime ceiling -- describe the bytes that were compiled.
// That alone closes the attack, because restoring a modified target during the
// run moves the TARGET's ctime past process start.
const strInvokedPath = fileURLToPath(import.meta.url);
const strScriptPath = realpathSync(strInvokedPath);
const boolEntryPointIsLink = strInvokedPath !== strScriptPath;
const strScriptBefore = readFileSync(strScriptPath, 'utf8');
const strScriptSha256 = sha256(strScriptBefore);
// Round 18, reported. Math.round can round the uptime DOWN, which places the
// computed start LATER than the real one -- and anything changed inside that
// sliver carries a ctime below the ceiling and escapes the check. Math.ceil can
// only place the computed start earlier, which is the direction that fails safe:
// it can raise a false alarm, never miss a replacement.
const intProcessStartedAt = Date.now() - Math.ceil(process.uptime() * 1000);

// "A JSON object", as distinct from everything else `typeof x === 'object'`
// admits. Both `null` and an array answer 'object', and each of those has now
// been reported as a hole in the audit shape guard -- null in round 2, arrays
// in round 6. One predicate, used everywhere, rather than a conjunction
// rewritten at each call site and wrong in a different way each time.
// Severity order for the recorded counts AND for the shape guard below. One
// list drives both, so the field that is compared and the field that is
// validated cannot describe different shapes.
//
// Round 13, reported by Copilot. `counts` used to be npm's own object copied
// straight through, so its KEY ORDER came from npm's JSON emitter. The digest
// was never at risk -- canonicalize sorts keys -- but the record quotes the
// counts as a compared field, and a reader string-comparing that value would
// see a false mismatch if a future npm emitted the same numbers in a different
// order. Rebuilding in a fixed order makes the compared text depend on the
// values alone.
const SEVERITY_ORDER = Object.freeze(['info', 'low', 'moderate', 'high', 'critical', 'total']);

function orderedCounts(objCounts) {
  if (!objCounts || typeof objCounts !== 'object') return null;
  const objOrdered = {};
  for (const strSeverity of SEVERITY_ORDER) objOrdered[strSeverity] = objCounts[strSeverity];
  return objOrdered;
}

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

// Round 16, reported. Every manifest read after the first snapshot was a bare
// readFileSync, so a manifest deleted or made unreadable mid-run threw before
// the comparison it feeds could issue the documented exit 3 -- exit 1 and a raw
// node:fs trace instead. A read that cannot complete IS the input changing.
function readOrRefuse(strPath) {
  try {
    return readFileSync(strPath, 'utf8');
  } catch (objError) {
    process.stderr.write(
      'supply-freeze: a recorded input could not be re-read; refusing to report.\n' +
      `  error              ${objError.code ?? 'unknown'} at ${objError.path ?? strPath}\n` +
      '  it was readable when this run began, so it changed underneath the record.\n');
    process.exit(3);
  }
}

function runNpm(arrNpmArguments, objEnv) {
  return execFileSync('npm', arrNpmArguments, {
    cwd: strWorkflowDirectory,
    ...(objEnv ? { env: objEnv } : {}),
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function runNpmAllowingFailure(arrNpmArguments, objEnv) {
  try {
    return runNpm(arrNpmArguments, objEnv);
  } catch (objError) {
    // `npm audit` uses exit 1 to mean "advisories found", not "command failed".
    if (typeof objError.stdout === 'string' && objError.stdout.trim().startsWith('{')) {
      return objError.stdout;
    }
    // Round 19, reported. Anything else was rethrown, so an audit terminated or
    // failing before it wrote any JSON -- stderr only -- surfaced as exit 1 and a
    // stack trace, while the refusal table calls an unreachable registry exit 5.
    // Returning the failure text lets the parse guard classify it as what it is:
    // not an audit report.
    return typeof objError.stderr === 'string' && objError.stderr.trim()
      ? objError.stderr
      : `npm audit failed without output (${objError.code ?? 'unknown'})`;
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
  let intSpecials = 0;
  const arrSpecialPaths = [];
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
  // Directories are counted separately rather than folded into the histogram
  // above. Merging them would turn the recorded {"644":2157,"755":20} into a
  // shape where files and directories are indistinguishable, which is a worse
  // diagnostic than either alone.
  const objDirectoryModeHistogram = new Map();
  const walk = (strDirectory, strRelative) => {
    const arrEntries = [...readdirSync(strDirectory, { withFileTypes: true })]
      .sort((objLeft, objRight) => (objLeft.name < objRight.name ? -1 : objLeft.name > objRight.name ? 1 : 0));
    for (const objEntryHint of arrEntries) {
      const strPath = join(strDirectory, objEntryHint.name);
      const strChild = strRelative ? `${strRelative}/${objEntryHint.name}` : objEntryHint.name;
      // Round 8, reported. `readdir` may answer DT_UNKNOWN for an entry -- some
      // NFS and FUSE mounts do -- and a Dirent carrying that hint returns false
      // from isFile(), isDirectory() AND isSymbolicLink() alike. Every such
      // entry would fall through to the `?` branch below, which records a tag
      // and a path and NOTHING else: no content, no target, and no recursion
      // into a directory's children. A tree on such a filesystem would fold to
      // a digest that silently omits most of it while still reporting
      // freezeRecord: true.
      //
      // lstatSync answers from the inode rather than the directory hint, and
      // Stats exposes the same predicates as Dirent, so it substitutes cleanly.
      // It must be lstat rather than stat: stat would follow symlinks and
      // reclassify each of the 8 `.bin` entries as the file it points at.
      //
      // Only consulted when the hint is inconclusive, so the common path costs
      // nothing. Not reproducible here -- every filesystem on this host reports
      // real types, checked across /proc, /sys, /dev, /run and /tmp -- so the
      // trigger is taken from the readdir contract while the consequence is
      // measured: an entry that answers false to both predicates does take the
      // content-free `?` branch.
      const objEntry = (objEntryHint.isFile() || objEntryHint.isDirectory() || objEntryHint.isSymbolicLink())
        ? objEntryHint
        : lstatSync(strPath);
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
        // Round 11, reported and confirmed. This branch used to fold the tag
        // and the path and nothing else, so a directory's permission bits were
        // invisible to the digest AND to the census. Measured on
        // node_modules/glob: 0755 -> 0745 -> 0700 left the digest at
        // 4cdc37a7... and the counts at 2177/8/336 throughout.
        //
        // That is not cosmetic. A directory's execute bit is its traverse
        // permission, so clearing it for group or other makes everything
        // beneath unreachable for those classes while the packages themselves
        // are byte-perfect -- the same "a tree that cannot run is not the tree
        // this record claims to have measured" argument that put execute bits
        // on files in round 2, one entry kind over.
        //
        // Normalized execute bits, matching the file branch, for the same
        // reason: the read and write bits are a property of the extracting
        // machine, and folding the full mode would reintroduce umask drift.
        intDirectories += 1;
        const intDirectoryMode = lstatSync(strPath).mode;
        objDirectoryModeHistogram.set(
          (intDirectoryMode & 0o777).toString(8).padStart(3, '0'),
          (objDirectoryModeHistogram.get((intDirectoryMode & 0o777).toString(8).padStart(3, '0')) ?? 0) + 1);
        objHash.update('D', 'utf8');
        hashField(objHash, strChild);
        hashField(objHash, (intDirectoryMode & 0o111).toString(8).padStart(3, '0'));
        walk(strPath, strChild);
        continue;
      }
      if (!objEntry.isFile()) {
        // A socket, device or FIFO under node_modules is not something an
        // install produces. Recorded rather than skipped so it cannot hide.
        //
        // Round 9, reported by Copilot and confirmed WIDER than reported. The
        // branch used to fold a bare '?' tag and the path, so every special
        // entry at a given path hashed identically. Copilot said two different
        // TYPES would collide; measured, five distinct filesystem objects at
        // one path all folded identically -- FIFO, Unix socket, character
        // device (1,3), character device (1,5) and block device (7,0). The two
        // character devices differ only in minor number, which is the
        // /dev/null-versus-/dev/zero distinction, so the collision was not even
        // limited to type. The census was blind to all five: 2177/8/336 in
        // every case, identical to a tree with no special entry at all.
        //
        // The type tag and the device number are folded so the encoding is
        // injective here too. `rdev` lives on Stats and not on Dirent, so this
        // takes an lstat -- charged only to entries that reach this branch,
        // which in a real install is none of them.
        //
        // Folding this correctly matters independently of the exit-11 refusal
        // below, because --any-toolchain bypasses every guard and still runs
        // the fold. A digest whose injectivity depends on a guard is not
        // injective in exactly the runs where nothing else is checking.
        intSpecials += 1;
        arrSpecialPaths.push(strChild);
        const objSpecial = lstatSync(strPath);
        const strTag = objSpecial.isFIFO() ? 'P'
          : objSpecial.isSocket() ? 'S'
          : objSpecial.isCharacterDevice() ? 'C'
          : objSpecial.isBlockDevice() ? 'B'
          : '?';
        objHash.update(strTag, 'utf8');
        hashField(objHash, strChild);
        hashField(objHash, String(objSpecial.rdev));
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
      //
      // Round 12, reported and confirmed. This folded `mode & 0o111` alone, so
      // READ permission was invisible: measured, 0644 -> 0600 on an installed
      // .js file left the digest byte-identical. The owner running the recorder
      // can still read it and `npm ls` still passes, but a group or other user
      // can no longer load that module -- and the histogram that does move is
      // explicitly a non-compared diagnostic, so every compared field stayed
      // equal and a reviewed run would emit freezeRecord: true for a tree those
      // users cannot use.
      //
      // `mode & 0o555` is read AND execute, which together are exactly the
      // "can each permission class still load this" property. Write bits stay
      // out deliberately: they do not affect loadability and are the most
      // machine-variable of the three. Both halves are umask-dependent, which
      // is fine for the same reason the execute bits are -- the umask is
      // pinned and checked.
      intFiles += 1;
      const intMode = lstatSync(strPath).mode;
      const strPermissions = (intMode & 0o777).toString(8).padStart(3, '0');
      objModeHistogram.set(strPermissions, (objModeHistogram.get(strPermissions) ?? 0) + 1);
      objHash.update('F', 'utf8');
      hashField(objHash, strChild);
      hashField(objHash, (intMode & 0o555).toString(8).padStart(3, '0'));
      hashField(objHash, readFileSync(strPath));
    }
  };
  // The root itself, which the walk above never sees because it starts inside
  // it. Reported in the same round as the directory bits and for the same
  // reason: clearing traverse permission on `node_modules` locks every class
  // out of the entire tree at once, and that was the one directory the fold
  // could never have noticed. Tagged distinctly from a child directory so the
  // record for the root cannot be confused with an entry named after it.
  // It is reported as its own field rather than folded into the directory
  // histogram, so that histogram keeps summing to `directories` -- a census
  // whose total does not match the count beside it is a diagnostic that costs
  // the reader time to reconcile.
  const objRootStats = lstatSync(strRoot);
  const intRootMode = objRootStats.mode;
  objHash.update('R', 'utf8');
  hashField(objHash, (intRootMode & 0o111).toString(8).padStart(3, '0'));
  // Round 12, reported. lstat sees the root itself, but only its execute mask
  // was folded -- and a 0755 directory and a 0777 symlink both mask to 111, so
  // a `node_modules` that is a SYMLINK to a byte-identical tree elsewhere folded
  // to exactly the same digest and counts as the real thing. `walk` then follows
  // the link, so the redirect controlling where all installed code loads from
  // was the one thing the fold ignored. Measured: identical digest either way.
  //
  // The reporter added that `npm ls --all --json` exits 0 with a symlinked root,
  // which would let a full record be emitted. That did NOT reproduce here -- on
  // npm 10.9.7 it exits non-zero for both a relative symlink and an absolute one
  // to an external tree, so refusal 7 already fires. The fold is fixed anyway:
  // --any-toolchain bypasses that guard and still folds, and an incidental
  // protection that depends on npm's version is not one to rely on.
  //
  // Folded only when the root is NOT a directory, so the reviewed layout's
  // digest is unaffected. `R` is followed by a length prefix, which begins with
  // a digit, and `K` by a letter, so the two cannot be confused.
  const boolRootIsDirectory = objRootStats.isDirectory();
  if (!boolRootIsDirectory) {
    objHash.update('K', 'utf8');
    hashField(objHash, objRootStats.isSymbolicLink() ? 'L' : '?');
    if (objRootStats.isSymbolicLink()) {
      hashField(objHash, readlinkSync(strRoot, { encoding: 'buffer' }));
    }
  }
  walk(strRoot, '');
  const sortHistogram = (objMap) => Object.fromEntries([...objMap.entries()].sort(
    (objLeft, objRight) => (objLeft[0] < objRight[0] ? -1 : 1)));
  return {
    sha256: objHash.digest('hex'),
    files: intFiles,
    symlinks: intSymbolicLinks,
    directories: intDirectories,
    specials: intSpecials,
    specialPaths: arrSpecialPaths,
    modes: sortHistogram(objModeHistogram),
    directoryModes: sortHistogram(objDirectoryModeHistogram),
    rootMode: (intRootMode & 0o777).toString(8).padStart(3, '0'),
    rootIsDirectory: boolRootIsDirectory,
  };
}

// The newest inode-change time anywhere under the tree, with the path carrying
// it. Stat-only: no file is read, so this costs a fraction of a content fold.
//
// Round 9, reported by Codex and confirmed by construction. The two content
// folds detect a write that lands BETWEEN their two reads of the same entry.
// They cannot detect a write that lands after the SECOND fold has already read
// that entry, because nothing reads it again -- both folds then agree on bytes
// that are already stale. Measured with the second fold paused just after it
// read `.package-lock.json`: writing to that file gave exit 0, no exit-10
// refusal, and the then-recorded digest reported for a tree whose file
// was 64829 bytes at emission against the 64794 bytes actually hashed.
//
// This sweep tests a different predicate -- "was anything under this tree
// touched during the recording window" rather than "did two reads agree" -- and
// it catches that case precisely because it runs after the write.
//
// ctime rather than mtime, and that choice is load-bearing. `utimes` sets atime
// and mtime to any value a caller likes, so mtime is forgeable; the same call
// moves ctime FORWARD to the moment of the forgery. Measured: a write moved
// ctime, and the utimes attempt to restore the timestamps moved it again.
//
// This narrows the window; it does not make a userspace walk atomic, and
// nothing in this script can. See the comment at its use.
// Round 11: the manifests are swept too. They live one directory ABOVE
// node_modules, so the round-9 sweep did not reach them -- which is exactly the
// gap the manifest recheck below was reported for.
function newestChangeTime(strRoot, arrExtraPaths) {
  let intNewest = 0;
  let strNewestPath = '';
  const consider = (strPath, strLabel) => {
    const objStats = lstatSync(strPath);
    if (objStats.ctimeMs > intNewest) {
      intNewest = objStats.ctimeMs;
      strNewestPath = strLabel;
    }
    return objStats;
  };
  const walk = (strDirectory, strRelative) => {
    for (const objEntryHint of readdirSync(strDirectory, { withFileTypes: true })) {
      const strPath = join(strDirectory, objEntryHint.name);
      const strChild = strRelative ? `${strRelative}/${objEntryHint.name}` : objEntryHint.name;
      const objStats = consider(strPath, `node_modules/${strChild}`);
      if (objStats.isDirectory()) walk(strPath, strChild);
    }
  };
  consider(strRoot, 'node_modules');
  walk(strRoot, '');
  for (const strPath of arrExtraPaths) consider(strPath, strPath.split('/').pop());
  return { ctimeMs: intNewest, path: strNewestPath };
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
// as new advisories are published.
//
// Round 11 correction. This comment used to say drift here "calls for a policy
// re-decision, not a failed build", which reads as non-blocking and contradicts
// the record: the advisory fields ARE compared, so a mismatch IS an equality
// failure. What differs is the response -- re-decide the policy rather than
// investigate the tree -- not whether the check fails. The record was corrected
// one round earlier and this comment was left behind, which is the same partial
// fix the correction was about.
function parseAuditOrRefuse(strBody) {
  try {
    return JSON.parse(strBody);
  } catch (objError) {
    process.stderr.write(
      'supply-freeze: npm audit did not return an audit report.\n' +
      `  npm emitted output that is not valid JSON: ${objError.message}\n` +
      '  this is an endpoint or format failure, not an advisory posture; nothing is recorded.\n' +
      '  pass --no-audit to record the lockfile-derived fields alone.\n');
    process.exit(5);
  }
}

function normalizeAudit(objAudit) {
  const objVulnerabilities = objAudit.vulnerabilities ?? {};
  const objOutput = {
    auditReportVersion: objAudit.auditReportVersion ?? null,
    counts: orderedCounts(objAudit.metadata?.vulnerabilities),
    packages: {},
  };
  for (const strName of Object.keys(objVulnerabilities).sort()) {
    const objVulnerability = objVulnerabilities[strName];
    const arrAdvisories = [];
    // Round 22, reported. A string `via` is ITERABLE, so this loop walked it
    // character by character, matched no advisory in any character, and returned
    // zero advisories without throwing -- the digest lost the advisory identity
    // and the human output relabelled the package as inherited. The try/catch
    // added last round cannot help: nothing throws. Shapes that are wrong but
    // iterable need a type check, not an exception handler.
    if (!Array.isArray(objVulnerability.via ?? [])) {
      throw new TypeError(`vulnerability ${strName} has a non-array via`);
    }
    for (const objVia of objVulnerability.via ?? []) {
      // A `via` entry that is a bare string names another package in the chain
      // rather than an advisory; the chain is already covered by the tree.
      if (typeof objVia !== 'object' || objVia === null) continue;
      const strUrl = typeof objVia.url === 'string' ? objVia.url : '';
      const objMatch = strUrl.match(/GHSA-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}/u);
      arrAdvisories.push({
        id: objMatch ? objMatch[0] : `npm-source-${objVia.source ?? 'unknown'}`,
        severity: objVia.severity ?? null,
        cwe: (() => {
          if (!Array.isArray(objVia.cwe ?? [])) {
            throw new TypeError(`advisory in ${strName} has a non-array cwe`);
          }
          return [...(objVia.cwe ?? [])].sort();
        })(),
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
// Round 17, reported, and the previous round's fix caught half-done. The
// RE-reads were routed through a refusal; these initial snapshot reads were left
// bare, so a manifest missing or unreadable before the recorder starts threw an
// uncaught filesystem error and exited 1 -- ahead of the exit-4 guard that
// exists to name exactly this, and contradicting the record's claim that every
// refusal names its values on stderr.
function snapshotOrRefuse(strPath) {
  try {
    return readFileSync(strPath, 'utf8');
  } catch (objError) {
    process.stderr.write(
      'supply-freeze: refusing to record digests for an unreviewed manifest.\n' +
      `  ${strPath.split('/').pop().padEnd(18)} could not be read\n` +
      `  error              ${objError.code ?? 'unknown'} at ${objError.path ?? strPath}\n` +
      '  the reviewed manifest must be present and readable before anything is recorded.\n');
    process.exit(4);
  }
}

// Round 19, reported. This ceiling used to be captured after the snapshots and
// after `npm ls`, so a manifest replaced after the snapshot and restored before
// the ceiling escaped every check: the byte comparisons matched the restored
// file, the sweep ignored a ctime that predated the ceiling, and `npm ls` had
// validated the tree against the temporary lockfile in between. Captured before
// the first read of anything recorded, the window closes.
const intRecordingStartedAt = Date.now();

const strPackageBefore = snapshotOrRefuse(strPackagePath);
const strLockBefore = snapshotOrRefuse(strLockPath);

const strNodeVersion = process.version;
const strNpmVersion = runNpm(['--version']).trim();

// A symlinked entry point is not the reviewed invocation: the reviewed command
// runs this file directly. Refused alongside the toolchain because it is the
// same question -- is this the environment the record was made in -- rather than
// a twelfth exit number for a cause exit 2 already names.
if (!boolAnyToolchain && boolEntryPointIsLink) {
  process.stderr.write(
    'supply-freeze: refusing to record digests from a symlinked entry point.\n' +
    `  invoked as         ${strInvokedPath}\n` +
    `  resolves to        ${strScriptPath}\n` +
    '  under --preserve-symlinks-main the source Node compiles is the target, not\n' +
    '  the link. Run the file directly so the script identity is unambiguous.\n');
  process.exit(2);
}

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
// the record to explain why.
//
// No digest is quoted anywhere in this file's comments, and round 13 is when
// that finally became true. A comment claiming exactly this sat beside
// comments quoting the installed-tree digest -- which by then had moved twice
// and so were wrong, demonstrating the claim while contradicting it. A number
// in a comment has nothing deriving it and goes stale silently; the record
// holds the authoritative values and the script regenerates them.
//
// No circularity: the digest is computed over the file and never stored in it.
// The digest itself is computed at the very top of this file; see there for why.
// This comment stays here because it explains WHY the field exists at all.

// Install-shaping configuration, checked before anything is measured. See
// REVIEWED_NPM_CONFIG above for why: the toolchain guard passes a reader whose
// ambient npm configuration silently produced a different tree.
// npm serializes an unset `noproxy` as [''] rather than [] -- its config
// definition is `default: ''` with type [String, Array], so the empty string
// survives into the array form. Round 21, reported as P1: comparing against []
// therefore treated npm's own default as drift and exited 6 before the audit on
// an otherwise clean machine, which would have blocked the primary freeze record
// from ever being regenerated.
//
// Not reproducible on this host -- its npm reports a populated noproxy from
// configuration rather than the environment -- so this rests on the reporter's
// measurement across npm 10.9.8 and 11.4.2 plus npm's documented default. The
// normalization is correct either way: '', [] and [''] all mean "no exclusions".
function normalizeConfigValue(objValue) {
  const arrValue = Array.isArray(objValue) ? objValue : [objValue];
  const arrMeaningful = arrValue.filter(
    (objEntry) => objEntry !== '' && objEntry !== null && objEntry !== undefined);
  return Array.isArray(objValue) || objValue === '' ? arrMeaningful : objValue;
}

function configDrift(objReviewed, objEffective) {
  return Object.entries(objReviewed)
    .filter(([strKey, objExpected]) =>
      canonicalize(normalizeConfigValue(objEffective[strKey] ?? null))
        !== canonicalize(normalizeConfigValue(objExpected)))
    .map(([strKey, objExpected]) =>
      `  ${strKey.padEnd(18)} observed ${JSON.stringify(objEffective[strKey] ?? null)}, reviewed ${JSON.stringify(objExpected)}`);
}

if (!boolAnyToolchain) {
  const objEffective = JSON.parse(runNpm(['config', 'list', '--json']));
  const arrDrift = configDrift(REVIEWED_NPM_CONFIG, objEffective);
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
if (!boolAnyToolchain && intObservedUmask !== REVIEWED_UMASK) {
  process.stderr.write(
    'supply-freeze: refusing to record digests under an unreviewed umask.\n' +
    `  umask              observed ${strObservedUmask}, `
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
    umask: strObservedUmask,
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
  // Round 19, reported. This reloaded `omit` from whatever .npmrc exists when it
  // starts, and every root dependency here is a dev dependency -- so `omit=dev`
  // makes `npm ls` exit 0 against a tree that is missing entirely. Measured: no
  // node_modules exits 1 plain, 0 under omit=dev, and 1 again with the inclusion
  // named on the command line. Without this, an incomplete tree could be
  // recorded with treeSatisfiesLockfile true.
  // Round 20, reported. The inclusion flags did not bind the tree SELECTION:
  // `--package-lock-only` makes npm load the virtual tree from the lockfile
  // instead of the actual one on disk. Measured -- with no node_modules at all,
  // `npm ls --all --json --package-lock-only --include=...` exits 0 while the
  // same command with `--package-lock-only=false` exits 1.
  // Round 22, reported. `--all` does not survive an ambient `depth=0`: npm then
  // checks direct dependencies only and exits 0 with a transitive package
  // missing, recording treeSatisfiesLockfile true. Depth is pinned explicitly.
  runNpm(['ls', '--all', '--json', '--package-lock-only=false', '--depth=4294967295',
    '--include=dev', '--include=optional', '--include=peer']);
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
// Round 15, reported. A MISSING root is refused whatever the flags say. The
// bypass promises output that is "explicitly not a freeze record" -- but with no
// node_modules there is nothing to fold, so before this the bypassed run threw a
// raw ENOENT, and after the scan errors were caught it exited 10 blaming a tree
// that changed while recording. Nothing changed; the tree was never there.
//
// The bypass still applies to a tree that is PRESENT but does not satisfy the
// lockfile, which is a number a reader can legitimately want.
// Round 16, reported, and the same misdiagnosis one case over. The previous
// round made a MISSING root unconditional and stopped there; a root that exists
// but is a regular file, or a symlink to one, still reached the fold and came
// back as exit 10 "the recorded inputs changed" -- measured, ENOTDIR -- for a
// root that had been stable for the whole run. Walkability is checked with stat
// rather than lstat, so a symlink to a real directory stays foldable and is
// handled by the reviewed-run guard that already covers it.
const boolRootWalkable = existsSync(strTreeRoot) && (() => {
  try {
    return statSync(strTreeRoot).isDirectory();
  } catch {
    return false;
  }
})();

if (!boolRootWalkable) {
  process.stderr.write(
    'supply-freeze: refusing to record digests for a tree that is not the installed tree.\n' +
    `  node_modules       ${existsSync(strTreeRoot) ? 'present, but not a directory' : 'MISSING'}\n` +
    '  there is nothing to fold, so no digest exists to report -- with or without\n' +
    '  --any-toolchain. install first with the documented command:\n' +
    '    npm ci --ignore-scripts --no-audit --no-fund\n');
  process.exit(7);
}

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

// Round 15, reported and confirmed. Both scans read the tree entry by entry, so
// a concurrent delete between a readdir and the read that follows it raises
// ENOENT from inside the walk -- and nothing caught it. Measured, with the fold
// paused and `node_modules/glob` removed after the root readdir had already
// listed it: exit code 1 and a raw `node:fs` stack trace, where the record
// documents exit 10 and a message naming the cause.
//
// A scan that cannot complete has, by definition, failed to observe a tree that
// held still, so it is the same refusal -- the recorded inputs changed while
// recording. The errno and the path it failed on are reported, because "the
// tree moved" and "this file became unreadable" send a reader to different
// places.
//
// Deliberately NOT caught inside the walk to skip the entry: that would drop it
// from the digest silently, which is the defect round 8 found in the
// content-free `?` branch. A scan either completes over everything or refuses.
function scanOrRefuse(fnScan, strWhat) {
  try {
    return fnScan();
  } catch (objError) {
    process.stderr.write(
      'supply-freeze: the recorded inputs changed while recording; refusing to report.\n' +
      `  detected by        ${strWhat} could not complete\n` +
      `  error              ${objError.code ?? 'unknown'} at ${objError.path ?? '(path not reported)'}\n` +
      '  an entry vanished or became unreadable while it was being read, so no\n' +
      '  complete measurement of the tree exists. record against a quiescent tree.\n');
    process.exit(10);
  }
}

// Round 18, reported by Copilot. The symlinked-root refusal below read
// objTree.rootIsDirectory, which only exists AFTER the whole redirected tree had
// been walked and hashed -- so a reviewed run did the entire fold before
// refusing, and a root pointed at an arbitrarily large tree would be scanned in
// full before anything objected. lstat answers the same question before a single
// entry is read.
if (!boolAnyToolchain
  && !scanOrRefuse(() => lstatSync(strTreeRoot), 'the root type check').isDirectory()) {
  process.stderr.write(
    'supply-freeze: refusing to record digests for a tree that is not the installed tree.\n' +
    '  node_modules       present, but a symlink rather than a directory\n' +
    '  npm ci creates node_modules as a real directory. A symlinked root points the\n' +
    '  install somewhere this record does not describe, however identical its contents.\n');
  process.exit(7);
}

const objTree = scanOrRefuse(() => foldInstalledTree(strTreeRoot), 'the first fold');
objRecord.installedTreeSha256 = objTree.sha256;
objRecord.installedTreeFiles = objTree.files;
objRecord.installedTreeSymlinks = objTree.symlinks;
objRecord.installedTreeDirectories = objTree.directories;
objRecord.installedTreeSpecials = objTree.specials;
objRecord.installedTreeModes = objTree.modes;
objRecord.installedTreeDirectoryModes = objTree.directoryModes;
objRecord.installedTreeRootMode = objTree.rootMode;

// Round 9. A FIFO, socket or device node under node_modules means this is not
// an installed tree, which is the same thing refusal 7 asserts for a different
// cause -- so it gets the same treatment rather than a digest.
//
// The fold above now distinguishes these entries from one another, so the
// number reported under --any-toolchain is honest either way. This refusal is
// about what a REVIEWED run is allowed to mint: `npm ci` produces no such
// entry, so a record over a tree containing one would be a freeze record for
// something npm cannot have built.
// Round 12. `npm ci` creates node_modules as a real directory. A symlinked root
// redirects where every installed module loads from while the contents behind it
// can be byte-identical, so it is the same class as refusal 7 already covers --
// this is not the installed tree -- and it reuses that exit rather than adding
// an eleventh number for a tenth cause.
if (!boolAnyToolchain && !objTree.rootIsDirectory) {
  process.stderr.write(
    'supply-freeze: refusing to record digests for a tree that is not the installed tree.\n' +
    '  node_modules       present, but not a directory\n' +
    `  root mode          ${objTree.rootMode}\n` +
    '  npm ci creates node_modules as a real directory. A symlinked root points the\n' +
    '  install somewhere this record does not describe, however identical its contents.\n');
  process.exit(7);
}

if (!boolAnyToolchain && objTree.specials > 0) {
  process.stderr.write(
    'supply-freeze: refusing to record digests for a tree containing special files.\n' +
    `  special entries    ${objTree.specials} (expected 0)\n` +
    `${objTree.specialPaths.slice(0, 10).map((strPath) => `    node_modules/${strPath}\n`).join('')}` +
    (objTree.specialPaths.length > 10
      ? `    ... and ${objTree.specialPaths.length - 10} more\n` : '') +
    '  npm ci creates only files, directories and symlinks; a FIFO, socket or\n' +
    '  device node under node_modules did not come from the install.\n');
  process.exit(11);
}

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
  if (!boolAnyToolchain) {
    const arrTransportDrift = configDrift(
      REVIEWED_NPM_TRANSPORT, JSON.parse(runNpm(['config', 'list', '--json'])));
    if (arrTransportDrift.length > 0) {
      process.stderr.write(
        'supply-freeze: npm transport configuration would change where the audit goes.\n' +
        `${arrTransportDrift.join('\n')}\n` +
        '  a proxy or a custom trust store can return a schema-valid but filtered report.\n' +
        '  the installed tree is unaffected, so --no-audit records the lockfile-derived\n' +
        '  fields from any transport.\n');
      process.exit(6);
    }
  }
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
  // Round 11, reported. The registry was READ in one npm process and the audit
  // then ran in a SEPARATE one that reloaded configuration from scratch, so a
  // user or global .npmrc rewritten between the two would send the audit to a
  // different registry while objRecord.registry still named the validated one
  // -- a schema-valid answer from a mirror, recorded under the wrong source.
  //
  // Passing the validated value on the command line closes it by construction
  // rather than by a second check afterwards: npm gives command-line config the
  // highest precedence, so this invocation cannot be redirected by any file or
  // environment variable. The value passed is the one already compared against
  // REVIEWED_REGISTRY and the one recorded, so all three agree by construction.
  //
  // Round 12, reported, and this is the previous round's fix caught being
  // partial. Pinning the registry on this command line closed one input and
  // left the rest reloading: the audit subprocess still reads `omit` and
  // `include` from whatever .npmrc exists when it starts, and npm's own
  // `npm audit --help` lists `[--omit <dev|optional|peer> ...]`.
  //
  // Every one of the 125 packages in this lockfile is a dev dependency, so
  // `omit=dev` empties the audited set entirely. Measured: `npm audit --json
  // --omit=dev` returns a schema-valid report with total 0 against the true 7 --
  // it passes the shape guard and would be recorded as a clean posture,
  // attributed to the registry this script had just validated.
  //
  // `include` counteracts `omit` in npm's precedence, so naming all three
  // groups explicitly neutralises any ambient omission rather than checking for
  // it afterwards. Measured: under `omit=dev` this restores total 7, and on a
  // clean run it leaves total 7 unchanged.
  // Round 16, reported. A truncated or malformed body that still starts with `{`
  // is returned by runNpmAllowingFailure and then thrown on by JSON.parse as a
  // raw SyntaxError -- exit 1, before the shape guard below could call it what
  // it is. Unparseable output is exactly "not an audit report".
  const objAudit = parseAuditOrRefuse(runNpmAllowingFailure([
    'audit', '--json',
    `--registry=${strRegistry}`,
    '--include=dev', '--include=optional', '--include=peer',
    // Round 16, reported. npm's metavulnerability calculation loads packuments
    // through the cache, and npm documents prefer-offline as bypassing staleness
    // checks -- so an ambient prefer-offline lets inherited advisories be
    // computed from stale version data while the bulk advisory request still
    // goes to the validated registry. Forcing revalidation on this invocation
    // binds the whole posture to a current snapshot, not just its bulk half.
    '--prefer-offline=false', '--offline=false', '--prefer-online=true',
    ...transportFlags(),
    // Round 21, reported. The binding is applied only to reviewed runs. Under
    // --any-toolchain the configuration refusal is correctly bypassed, but
    // forcing the reviewed transport anyway made the audit fail with exit 5 on a
    // network that needs an ambient proxy -- denying the explicitly-marked
    // non-freeze output the flag promises. A bypassed run uses its own transport
    // and says so in notFreezeRecordBecause.
  ].filter((strArgument) => boolAnyToolchain
    ? !Object.keys(REVIEWED_NPM_TRANSPORT).some((strKey) => strArgument.startsWith(`--${strKey}=`))
    : true), boolAnyToolchain ? undefined : transportEnvironment()));
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
  // Round 19, reported. Valid JSON whose root is `null` reached this line and
  // threw before the shape refusal below could speak. The root is checked first
  // now, with the same predicate every other shape test uses.
  if (!isPlainObject(objAudit)) {
    process.stderr.write(
      'supply-freeze: npm audit did not return an audit report.\n' +
      `  the report root is ${objAudit === null ? 'null' : typeof objAudit}, not an object\n` +
      '  this is an endpoint or format failure, not an advisory posture; nothing is recorded.\n' +
      '  pass --no-audit to record the lockfile-derived fields alone.\n');
    process.exit(5);
  }
  const objCounts = objAudit.metadata?.vulnerabilities;
  if (!Number.isInteger(objAudit.auditReportVersion)
    || !isPlainObject(objAudit.vulnerabilities)
    || !isPlainObject(objCounts)
    || !SEVERITY_ORDER.every((strSeverity) => Number.isInteger(objCounts[strSeverity]))
    // Round 17, reported. The guard validated the top level and stopped there,
    // so `vulnerabilities: {"x": null}` with correct counts passed -- and
    // normalizeAudit then dereferenced that null and threw a TypeError, exit 1,
    // where exit 5 exists to say "not an audit report". Each entry is checked
    // here, and the normalization itself is wrapped below, because validating
    // the shapes I thought of and trusting the rest is the mistake this guard
    // has now been widened for four times.
    || !Object.values(objAudit.vulnerabilities).every(isPlainObject)) {
    process.stderr.write(
      'supply-freeze: npm audit did not return an audit report.\n' +
      `  npm said: ${typeof objAudit.message === 'string' ? objAudit.message : JSON.stringify(objAudit).slice(0, 300)}\n` +
      '  this is an endpoint or format failure, not an advisory posture; nothing is recorded.\n' +
      '  pass --no-audit to record the lockfile-derived fields alone.\n');
    process.exit(5);
  }
  let objNormalizedAudit;
  try {
    objNormalizedAudit = normalizeAudit(objAudit);
  } catch (objError) {
    process.stderr.write(
      'supply-freeze: npm audit did not return an audit report.\n' +
      `  the report could not be normalized: ${objError.message}\n` +
      '  this is a format failure, not an advisory posture; nothing is recorded.\n' +
      '  pass --no-audit to record the lockfile-derived fields alone.\n');
    process.exit(5);
  }
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
if (readOrRefuse(strPackagePath) !== strPackageBefore
  || readOrRefuse(strLockPath) !== strLockBefore) {
  process.stderr.write('supply-freeze: package metadata changed while reading it; refusing to report\n');
  process.exit(3);
}

// Round 8, reported. The assertion above covers the two manifest files and
// nothing else, so `node_modules` was read exactly once and never looked at
// again. Between that fold and this point sits `npm audit` -- a network round
// trip measured at ~2.0s against a ~0.1s fold -- and anything that edited an
// already-hashed file during that window left installedTreeSha256 describing a
// tree that no longer existed, under a freezeRecord: true heading.
//
// Re-folding brackets the audit rather than merely reordering around it:
// moving the audit earlier would have made the race less likely and still
// undetectable, and "less likely" is not a property a freeze record can rest
// on. The second fold is the same code over the same tree, so a mismatch means
// the bytes moved underneath it.
//
// Round 9 correction, and it is this comment's own argument turned around. An
// earlier version of this paragraph said re-folding brackets the slow operation
// "rather than narrowing the window", which claimed more than two sequential
// walks can deliver: a write landing after the second fold has read an entry
// leaves both folds agreeing on stale bytes, and that was demonstrated rather
// than argued. What brackets the audit is the PAIR of folds; the second fold's
// own duration is a window this comparison does not cover. The quiescence check
// after it covers that one, and the limit that remains is stated there.
//
// Done unconditionally, including under --no-audit where the window is only
// microseconds wide. A guarantee that holds except in the case nobody thought
// about is the defect this review found five times over; the cost is one extra
// pass at roughly 0.1s.
const objTreeAfter = scanOrRefuse(() => foldInstalledTree(strTreeRoot), 'the second fold');
if (objTreeAfter.sha256 !== objTree.sha256) {
  process.stderr.write(
    'supply-freeze: the installed tree changed while recording; refusing to report.\n' +
    `  first fold         ${objTree.sha256}\n` +
    `  second fold        ${objTreeAfter.sha256}\n` +
    `  counts             ${objTree.files}/${objTree.symlinks}/${objTree.directories}` +
      ` then ${objTreeAfter.files}/${objTreeAfter.symlinks}/${objTreeAfter.directories}` +
      ' (files/symlinks/directories)\n' +
    '  something wrote to node_modules while this ran. record against a quiescent tree.\n');
  process.exit(10);
}

// Round 9, reported by Codex. The comparison above answers "did two reads of
// the same entry agree", and a write that lands after the SECOND fold read an
// entry escapes it -- demonstrated, with the recorded digest emitted at exit 0
// for a file that had already grown by 35 bytes. See newestChangeTime.
//
// Same cause as the refusal above, so the same exit code: the installed tree
// changed while recording. A second exit number for one cause would inflate the
// table that the round-7 finding had to correct, and the message names which of
// the two detectors fired.
//
// What this does and does not promise, stated plainly because the round-8
// comment on the fold above overreached and this is the correction. Between
// them the two mechanisms detect any write that lands before this sweep reads
// the affected entry. Neither makes the walk atomic: a write landing after the
// sweep has passed an entry is not detected by anything here, and cannot be,
// because a userspace sequential scan has no atomic snapshot to compare against.
// A filesystem-level snapshot would close it outright and is the right answer
// for a reader who has one; that is a property of the host, not of this script.
const objNewestChange = scanOrRefuse(
  () => newestChangeTime(strTreeRoot, [strPackagePath, strLockPath]), 'the quiescence sweep');
if (objNewestChange.ctimeMs >= intRecordingStartedAt) {
  process.stderr.write(
    'supply-freeze: the recorded inputs changed while recording; refusing to report.\n' +
    '  detected by        inode change time, not by the fold comparison\n' +
    `  newest change      ${objNewestChange.path}\n` +
    `                     ctime ${new Date(objNewestChange.ctimeMs).toISOString()}\n` +
    `  recording began    ${new Date(intRecordingStartedAt).toISOString()}\n` +
    '  an entry was written after this run began, so the digest above describes\n' +
    '  bytes that are no longer on disk. record against a quiescent tree.\n');
  process.exit(10);
}

// Round 11, reported and confirmed. The manifest assertion above runs BEFORE
// the second fold and the sweep, and nothing read the manifests again after it,
// so a write landing in that interval was invisible: measured, editing
// package.json during the second fold gave exit 0 with the reviewed hash
// the reviewed manifest hash reported, matchesReviewedManifest: true, and
// different bytes actually on disk at emission.
//
// That is the identical late-write window the second fold was added to close
// for node_modules, left open one file over -- the same "fixed it here, not
// there" shape this review has now found several times. The content comparison
// is repeated here, after every scan and immediately before the record is
// emitted, so the hashes reported are the bytes last observed.
if (readOrRefuse(strPackagePath) !== strPackageBefore
  || readOrRefuse(strLockPath) !== strLockBefore) {
  process.stderr.write(
    'supply-freeze: package metadata changed after the tree was recorded; refusing to report\n' +
    '  the manifest hashes above would describe bytes that are no longer on disk.\n');
  process.exit(3);
}

// Round 12. The script's own bytes, re-compared after everything else. A
// replacement during the run would otherwise leave the reported script digest
// describing a file that is not the one that produced these numbers.
if (readOrRefuse(strScriptPath) !== strScriptBefore) {
  process.stderr.write(
    'supply-freeze: this script changed while it was running; refusing to report.\n' +
    `  reported digest    ${strScriptSha256}\n` +
    '  the file on disk no longer matches the source that derived these values.\n');
  process.exit(3);
}
// Round 18, reported, and the same defect round 15 fixed for the umask. The
// value compared and the value printed were two separate stat calls, so a
// message could quote a timestamp that was never the one refused.
// Round 22, reported. The read above is guarded and this stat was not, so the
// source vanishing between them exited 1 with a stack trace where the table says
// exit 3. Same transition, same refusal.
const intScriptChangedAt = (() => {
  try {
    return lstatSync(strScriptPath).ctimeMs;
  } catch (objError) {
    process.stderr.write(
      'supply-freeze: this script became unreadable during the run; refusing to report.\n' +
      `  error              ${objError.code ?? 'unknown'} at ${objError.path ?? strScriptPath}\n`);
    process.exit(3);
  }
})();
if (intScriptChangedAt >= intProcessStartedAt) {
  process.stderr.write(
    'supply-freeze: this script was replaced during the run; refusing to report.\n' +
    `  script ctime       ${new Date(intScriptChangedAt).toISOString()}\n` +
    `  process began      ${new Date(intProcessStartedAt).toISOString()}\n` +
    '  the bytes may have been restored, but the run is no longer attributable.\n');
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
    `    (${objRecord.installedTreeFiles} files, ${objRecord.installedTreeSymlinks} symlinks, ${objRecord.installedTreeDirectories} directories, ${objRecord.installedTreeSpecials} special entries on disk)\n` +
    `    (file permissions ${JSON.stringify(objRecord.installedTreeModes)}; a different shape is consistent with a different install umask, or with modes changed after install)\n` +
    `    (directory permissions ${JSON.stringify(objRecord.installedTreeDirectoryModes)}, node_modules itself ${objRecord.installedTreeRootMode})\n` +
    (objRecord.auditSha256
      ? `  registry             ${objRecord.registry}\n` +
        `  advisory posture     ${objRecord.auditSha256}\n` +
        `  advisory counts      ${JSON.stringify(objRecord.auditCounts)}\n` +
        Object.entries(objRecord.auditPackages)
          .map(([strName, strValue]) => `    ${strName.padEnd(20)} ${strValue}\n`).join('')
      : '  advisory posture     (skipped)\n'));
}
