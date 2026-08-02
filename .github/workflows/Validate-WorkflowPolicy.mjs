import { createHash } from 'node:crypto';
import { lstatSync, readFileSync, readdirSync, realpathSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  isAlias,
  isMap,
  isScalar,
  isSeq,
  parseAllDocuments,
} from 'yaml';

const ACTIONS = Object.freeze({
  checkout: Object.freeze({
    reference: 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1',
    release: 'v7.0.1',
  }),
  // Retained without a current use: no job runs this action now that the lint
  // job acquires its own Node distribution, but #20 still names the pin and
  // T1B reintroduces the role, so the reviewed identity stays under review
  // rather than being dropped and re-established later.
  setupNode: Object.freeze({
    reference: 'actions/setup-node@820762786026740c76f36085b0efc47a31fe5020',
    release: 'v7.0.0',
  }),
  uploadArtifact: Object.freeze({
    reference: 'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a',
    release: 'v7.0.1',
  }),
});

// Reviewed defaults are deliberately separate from authored inputs. Any pin
// update must review and replace this complete table atomically with the role
// policy and negative fixtures below.
export const REVIEWED_ACTION_DEFAULTS = Object.freeze({
  checkout: Object.freeze({
    manifestSha256: 'd59219cb79590abdb877deaa14e3b65a00c05318bf5a6f3b989b9162b5d08c35',
    runtime: 'node24',
    omitted: Object.freeze({
      'ssh-key': Object.freeze({ default: '', rationale: 'SSH authentication is prohibited; HTTPS token checkout is explicit.' }),
      'ssh-known-hosts': Object.freeze({ default: '', rationale: 'No SSH transport is used.' }),
      'ssh-strict': Object.freeze({ default: true, rationale: 'Reviewed but not applicable without SSH.' }),
      'ssh-user': Object.freeze({ default: 'git', rationale: 'Reviewed but not applicable without SSH.' }),
      path: Object.freeze({ default: '', rationale: 'Checkout remains at the repository workspace root.' }),
      filter: Object.freeze({ default: null, rationale: 'Partial clone is prohibited.' }),
      'sparse-checkout': Object.freeze({ default: null, rationale: 'Sparse checkout is prohibited.' }),
      'sparse-checkout-cone-mode': Object.freeze({ default: true, rationale: 'Reviewed but not applicable without sparse checkout.' }),
      'github-server-url': Object.freeze({ default: '${{ github.server_url }}', rationale: 'The repository context selects the server.' }),
    }),
  }),
  setupNode: Object.freeze({
    manifestSha256: '5d765941ab5d8bef27f08e81b0b041cdb2df2050ea0261dc925d157a2bafbd2b',
    runtime: 'node24',
    omitted: Object.freeze({
      'node-version-file': Object.freeze({ default: '', rationale: 'The exact Node patch is authored directly.' }),
      architecture: Object.freeze({ default: '', rationale: 'The hosted runner architecture is used.' }),
      'registry-url': Object.freeze({ default: '', rationale: 'No registry authentication file is created.' }),
      scope: Object.freeze({ default: '', rationale: 'No registry scope is configured.' }),
      cache: Object.freeze({ default: '', rationale: 'Dependency caching is prohibited for this frozen install.' }),
      'cache-dependency-path': Object.freeze({ default: '', rationale: 'Caching is disabled.' }),
      mirror: Object.freeze({ default: '', rationale: 'Only the official Node distribution source is permitted.' }),
      'mirror-token': Object.freeze({ default: '', rationale: 'No mirror is configured.' }),
    }),
  }),
  uploadArtifact: Object.freeze({
    manifestSha256: 'c5979822866a72362e609844b6ebe77d4b7e759af68cc1c2c425dcf51481fab4',
    runtime: 'node24',
    omitted: Object.freeze({
      archive: Object.freeze({ default: true, rationale: 'The reviewed default ZIP artifact representation is required.' }),
    }),
  }),
});

const CHECKOUT_INPUTS = Object.freeze({
  repository: '${{ github.repository }}',
  ref: '${{ github.sha }}',
  token: '${{ github.token }}',
  'persist-credentials': false,
  'fetch-depth': 1,
  'fetch-tags': false,
  'show-progress': false,
  lfs: false,
  submodules: false,
  clean: true,
  'set-safe-directory': true,
  'allow-unsafe-pr-checkout': false,
});

const UPLOAD_INPUTS = Object.freeze({
  name: 'style-guide-artifacts',
  path: 'copilot-instructions.md\nterraform.instructions.md\nSTYLE_GUIDE_CHAT.md\nSTYLE_GUIDE_FULL.md\n',
  'if-no-files-found': 'error',
  'retention-days': 7,
  'compression-level': 6,
  overwrite: false,
  'include-hidden-files': false,
});

const EXPECTED_TRIGGER = Object.freeze({
  push: Object.freeze({ branches: Object.freeze(['main']) }),
  pull_request: Object.freeze({ branches: Object.freeze(['main']) }),
});

// The Markdown workflow hashes package.json and package-lock.json only against
// themselves, which proves npm ci left them alone but establishes the files
// under review as their own baseline. A change that edits both together — for
// example redefining lint:md as a no-op or swapping the yaml parser — survives
// that check. These reviewed values are the independent baseline, so the
// scripts the workflow runs and the graph it installs are fixed at review time.
const REVIEWED_PACKAGE_DIGESTS = Object.freeze({
  'package.json': 'e206cdb3562f0397e8eed7fb2c2586269a1f5335cdff2906da8d5e070426321e',
  'package-lock.json': '277f7168ab3a4f1f7a2565de13191d64b1572e7cb92b67b0972b3242bd4de062',
});

const REVIEWED_SCRIPTS = Object.freeze({
  'lint:md': 'cd ../.. && markdownlint-cli2 "**/*.md" "#node_modules" "#.github/workflows/node_modules" --config .github/workflows/.markdownlint.jsonc',
  'lint:md:nested': 'node lint-nested-markdown.js',
  prepare: 'cd ../.. && husky || true',
});

const REVIEWED_DEV_DEPENDENCIES = Object.freeze({
  glob: '^10.3.10',
  husky: '^9.1.7',
  'markdown-it': '^14.0.0',
  markdownlint: '^0.40.0',
  'markdownlint-cli2': '^0.20.0',
  yaml: '2.9.0',
});

// The validator parses policy YAML with this exact package, so its resolved
// identity is part of the policy rather than an incidental transitive detail.
const REVIEWED_PARSER = Object.freeze({
  version: '2.9.0',
  resolved: 'https://registry.npmjs.org/yaml/-/yaml-2.9.0.tgz',
  integrity: 'sha512-2AvhNX3mb8zd6Zy7INTtSpl1F15HW6Wnqj0srWlkKLcpYl/gMIMJiyuGq2KeI2YFxUPjdlB+3Lc10seMLtL4cA==',
});

// Naming three cmdlets left every other client open, including Invoke-RestMethod
// and the .NET networking types. That gap was written when a step held a
// contents-write token; no step holds one now, but the reason to close it did
// not depend on the token -- the governed steps run repository-controlled code
// and none of them performs network I/O, so the denylist covers the client
// surface rather than a sample of it. Deliberately no /g flag: reused with test().
const NETWORK_CLIENT = /\b(?:curl|wget|Invoke-WebRequest|Invoke-RestMethod|iwr|irm|Start-BitsTransfer|Net\.WebClient|WebClient|HttpClient|WebRequest|TcpClient|UdpClient|HttpListener|Socket)\b|System\.Net\./iu;


// The Markdown validation step captures each phase status into a variable and
// defers the failure decision to a final check. The structural assertions below
// count direct "$intPolicyExit =" assignments, which a rewrite can satisfy while
// still zeroing the captured value -- Set-Variable -Name intPolicyExit -Value 0
// changes the variable without matching the assignment syntax being counted.
// Enumerating the indirect writers (Set-Variable, New-Variable, the Variable:
// provider, [ref] handles) is the same losing shape, so the whole reviewed
// script is pinned instead: any edit at all changes this digest.
const REVIEWED_VALIDATION_STEP_DIGEST = 'd5880b7ecb20dcfa4fc115bfadec92cd8b76129ffd4f4550dc9f785ac61651b7';

// The credential-cleanup step's assertions all test for the presence of a
// sequence, and presence is not execution: an inserted early exit satisfies
// every one of them while returning before either credential check runs. This
// pins the whole script for the same reason the other two substantive steps
// are pinned. It is a backstop and not a substitute: the assertions it stands
// behind are named individually so a re-baseline cannot quietly drop them.
const REVIEWED_CREDENTIAL_STEP_DIGEST = 'cec60ee92660f500987f0b14926e85add62b9879c041bc3e87939472fd1471f5';

// The verify step runs repository-controlled code and then draws a conclusion
// from Git probes. Its required fragments and their ordering are asserted
// individually below, but an inserted early exit satisfies every one of them
// while skipping the probes entirely. The same backstop the Markdown step and
// the former push step carry applies here for the same reason.
const REVIEWED_VERIFY_STEP_DIGEST = '238b85b3f36cc5bc4a4b8a023342617be23c60cdc36060f083541c7b02f6a360';

// Both jobs that run repository-controlled code now acquire their own revision
// instead of using an action to do it, so neither contains a process holding
// ACTIONS_RUNTIME_TOKEN. Each acquire step is held to the standard the action
// it replaced was held to: substantive assertions named individually, and the
// whole script pinned behind them.
const BUILD_ACQUIRE = Object.freeze({
  name: 'Acquire triggering revision without an action',
  classifiedStatuses: 5,
  networkClients: 0,
  digest: '0eb96c20d7d2adfd724248f504b2fc5eb1b9306b8f51640ed7a0bafacdc5ff8c',
});

// The Markdown job additionally brings the Node distribution setup-node used to
// supply. The archive and its digest are reviewed constants rather than
// whatever the server returns, which is a stronger supply assertion than the
// action carried: nothing in this repository ever verified what setup-node
// downloaded. The linux-x64 archive digest below was checked against the
// published SHASUMS256.txt for v24.18.1.
const REVIEWED_NODE_ARCHIVE_SHA256 = 'D6C664DF3F3F61458E8C277585571328522D705166723A7C7823A9253A4D15A0';
const MARKDOWN_ACQUIRE = Object.freeze({
  name: 'Acquire triggering revision and pinned toolchain without an action',
  classifiedStatuses: 7,
  digest: '8416025cdcf74b9157bff09d4e931710f904c67c1321235a5e3398c18e6270b6',
  networkClients: 1,
  extraSequences: Object.freeze([
    ['the exact reviewed Node archive',
      "$strNodeUrl = 'https://nodejs.org/dist/v24.18.1/node-v24.18.1-linux-x64.tar.xz'"],
    ['the reviewed Node archive digest',
      `$strReviewedNodeSha256 = '${REVIEWED_NODE_ARCHIVE_SHA256}'`],
    // One contiguous block rather than three separate presence checks. Naming
    // the download, the comparison, and the extraction individually says each
    // is present and says nothing about what sits between them -- and what
    // sits between them is the whole question, because a statement inserted
    // after the comparison and before the extraction replaces the archive that
    // was just verified, and one inserted after the extraction replaces the
    // binaries that came out of it. Requiring the region to be exactly this
    // leaves no position for either.
    ['the download, its verification, and the extraction as one uninterrupted block',
      '& curl --silent --show-error --fail --location --proto \'=https\' --tlsv1.2 --output $strArchivePath $strNodeUrl\nif ($LASTEXITCODE -ne 0) { throw "acquire: node download exited $LASTEXITCODE" }\n$strObservedNodeSha256 = (Get-FileHash -LiteralPath $strArchivePath -Algorithm SHA256).Hash\nif ($strObservedNodeSha256 -cne $strReviewedNodeSha256) {\n    throw \'acquire: the Node archive does not match the reviewed digest\'\n}\n[void][System.IO.Directory]::CreateDirectory($strNodeRoot)\n& tar -xJf $strArchivePath -C $strNodeRoot --strip-components=1\nif ($LASTEXITCODE -ne 0) { throw "acquire: node extraction exited $LASTEXITCODE" }\nWrite-Host "acquire: revision $strSha and the reviewed Node distribution"'],
  ]),
  // And the block is the end of the step, so nothing follows the extraction
  // at all. Without this the region above could sit anywhere and a later
  // statement could still overwrite the extracted tree from the checkout,
  // which needs no network and so is not caught by the count below.
  tail: '& curl --silent --show-error --fail --location --proto \'=https\' --tlsv1.2 --output $strArchivePath $strNodeUrl\nif ($LASTEXITCODE -ne 0) { throw "acquire: node download exited $LASTEXITCODE" }\n$strObservedNodeSha256 = (Get-FileHash -LiteralPath $strArchivePath -Algorithm SHA256).Hash\nif ($strObservedNodeSha256 -cne $strReviewedNodeSha256) {\n    throw \'acquire: the Node archive does not match the reviewed digest\'\n}\n[void][System.IO.Directory]::CreateDirectory($strNodeRoot)\n& tar -xJf $strArchivePath -C $strNodeRoot --strip-components=1\nif ($LASTEXITCODE -ne 0) { throw "acquire: node extraction exited $LASTEXITCODE" }\nWrite-Host "acquire: revision $strSha and the reviewed Node distribution"',
});

// The generator is repository-controlled code that the verify job executes. Its
// version marker is fixed, but a version marker constrains a string, not
// behaviour: the body can be rewritten completely while the marker stays put.
// Pinning the bytes makes any change to it a visible policy failure rather than
// a silent one. This is a review signal rather than a runtime gate -- build.yml
// does not run this validator, so what actually contains the generator at run
// time is the process boundary and the byte comparison in that step.
const REVIEWED_GENERATOR_DIGEST = 'bb8ba306acb130f8f7b5fcc75153f3c6bc69735ac5de4faffa6d38055535783f';

// The lint phases execute these two files out of the checkout. The rule
// configuration decides which rules run at all, and the nested-fence helper is
// the entirety of the second phase, yet the reviewed package digests cover only
// what npm installs. Editing either leaves every command string, captured
// status, and digest intact while both phases report zero errors over nothing,
// so what the lint does is pinned alongside what it runs.
const REVIEWED_LINT_DIGESTS = Object.freeze({
  '.markdownlint.jsonc': '5eb07bf7f30829e0091e82f235a96fdba21be1ef1160ca1e22cdbe8d82da5300',
  'lint-nested-markdown.js': '4eefec7afba1c79809d916365b2eb3e2ea17aa482593338492a10d6dda5e2031',
});

const EXPECTED_VERSION = '1.0.20260731.0';
const MAXIMUM_YAML_BYTES = 1024 * 1024;
const MAXIMUM_NODE_COUNT = 10000;
const MAXIMUM_DEPTH = 64;

class PolicyError extends Error {
  constructor(category, message) {
    super(`${category}: ${message}`);
    this.name = 'PolicyError';
    this.category = category;
  }
}

function reject(category, message) {
  throw new PolicyError(category, message);
}

function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stable(value[key])]));
  }
  return value;
}

function equal(actual, expected) {
  return JSON.stringify(stable(actual)) === JSON.stringify(stable(expected));
}

function assertEqual(actual, expected, label) {
  if (!equal(actual, expected)) reject('policy', `${label} differs from the locked policy`);
}

function assertKeys(value, expected, label) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    reject('schema', `${label} must be a mapping`);
  }
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (!equal(actual, wanted)) reject('schema', `${label} has missing or extra keys`);
}

function inspectYamlNode(node, depth, state) {
  if (node === null || node === undefined) return;
  state.count += 1;
  if (state.count > MAXIMUM_NODE_COUNT) reject('yaml-limit', 'node count exceeds the bound');
  if (depth > MAXIMUM_DEPTH) reject('yaml-limit', 'nesting depth exceeds the bound');
  if (node.anchor) reject('yaml-syntax', 'anchors are prohibited');
  if (node.tag) reject('yaml-syntax', 'explicit or custom tags are prohibited');
  if (isAlias(node)) reject('yaml-syntax', 'aliases are prohibited');

  if (isMap(node)) {
    for (const pair of node.items) {
      // Keys carry anchors, tags, and aliases exactly as values do, so they are
      // inspected through the same path before the key-shape assertions below.
      inspectYamlNode(pair.key, depth + 1, state);
      if (!isScalar(pair.key) || typeof pair.key.value !== 'string') {
        reject('yaml-syntax', 'mapping keys must be unique strings');
      }
      if (pair.key.value === '<<') reject('yaml-syntax', 'merge keys are prohibited');
      inspectYamlNode(pair.value, depth + 1, state);
    }
    return;
  }
  if (isSeq(node)) {
    for (const item of node.items) inspectYamlNode(item, depth + 1, state);
    return;
  }
  if (isScalar(node)) {
    const value = node.value;
    if (value !== null && !['string', 'number', 'boolean'].includes(typeof value)) {
      reject('yaml-syntax', 'only JSON-like scalar values are permitted');
    }
    if (typeof value === 'number' && !Number.isFinite(value)) {
      reject('yaml-syntax', 'non-finite numbers are prohibited');
    }
    return;
  }
  reject('yaml-syntax', 'unknown YAML node type');
}

export function parseStrictYaml(source, sourceName = '<fixture>') {
  if (typeof source !== 'string') reject('yaml-input', `${sourceName} is not text`);
  if (Buffer.byteLength(source, 'utf8') > MAXIMUM_YAML_BYTES) reject('yaml-limit', `${sourceName} is too large`);
  if (/^\s*%/mu.test(source)) reject('yaml-syntax', `${sourceName} contains a directive`);

  let documents;
  try {
    documents = parseAllDocuments(source, {
      intAsBigInt: false,
      keepSourceTokens: true,
      logLevel: 'silent',
      prettyErrors: false,
      schema: 'core',
      strict: true,
      uniqueKeys: true,
      version: '1.2',
    });
  } catch {
    reject('yaml-syntax', `${sourceName} could not be parsed`);
  }
  if (documents.length !== 1) reject('yaml-syntax', `${sourceName} must contain exactly one document`);
  const [document] = documents;
  if (document.errors.length !== 0 || document.warnings.length !== 0) {
    reject('yaml-syntax', `${sourceName} contains a parser error or warning`);
  }
  inspectYamlNode(document.contents, 0, { count: 0 });
  const value = document.toJS({ maxAliasCount: 0, mapAsMap: false });
  JSON.stringify(value);
  return value;
}

function actionAnnotations(source) {
  const annotations = [];
  for (const line of source.split(/\r?\n/u)) {
    if (!/^\s*uses:/u.test(line)) continue;
    const match = line.match(/^\s*uses:\s*([^\s#]+)\s+#\s+(v[0-9]+\.[0-9]+\.[0-9]+)\s*$/u);
    if (!match) reject('action-policy', 'every uses line needs one exact full pin and release annotation');
    annotations.push({ reference: match[1], release: match[2] });
  }
  return annotations;
}

function findStep(job, id, label) {
  if (!Array.isArray(job.steps)) reject('schema', `${label}.steps must be a sequence`);
  const matches = job.steps.filter((step) => step && step.id === id);
  if (matches.length !== 1) reject('role-policy', `${label} must contain role ${id} exactly once`);
  return matches[0];
}

function assertActionStep(step, role, action, inputs, condition = undefined) {
  const expectedKeys = condition === undefined
    ? ['name', 'id', 'uses', 'with']
    : ['name', 'id', 'if', 'uses', 'with'];
  assertKeys(step, expectedKeys, role);
  if (step.uses !== action.reference) reject('action-policy', `${role} uses the wrong action repository or SHA`);
  if (condition !== undefined && step.if !== condition) reject('condition-policy', `${role} has the wrong condition`);
  assertEqual(step.with, inputs, `${role}.with`);
}

// Script steps are key-asserted for the same reason action steps are: an
// unasserted mapping accepts additions such as env, which the role policy never
// reviewed.
function assertScriptStep(step, label, fragment, failure) {
  assertKeys(step, ['name', 'id', 'shell', 'run'], label);
  if (step.shell !== 'pwsh') reject('policy', `${label} execution contract changed`);
  if (!step.run.includes(fragment)) reject('git-policy', failure);
}

function validateActionMultiset(source, expected) {
  const actual = actionAnnotations(source).sort((a, b) => `${a.reference}|${a.release}`.localeCompare(`${b.reference}|${b.release}`));
  const wanted = [...expected].sort((a, b) => `${a.reference}|${a.release}`.localeCompare(`${b.reference}|${b.release}`));
  assertEqual(actual, wanted, 'external action multiset');
}

function allRunSteps(workflow) {
  const runs = [];
  for (const [jobId, job] of Object.entries(workflow.jobs)) {
    for (const step of job.steps ?? []) {
      if (typeof step.run === 'string') runs.push({ jobId, id: step.id, run: step.run, step });
    }
  }
  return runs;
}

// Answers one question about one offset: is this position executable code at
// the outermost level of the script? It returns the brace nesting depth there,
// or null when the offset falls inside a comment or a quoted span.
//
// This is deliberately not a PowerShell parser. It exists because every other
// assertion in this file matches text, and a text match cannot tell a statement
// from a mention of one: $null = { ... }, if ($false) { ... }, and a multi-line
// single-quoted string all carry an approved command that never runs, and each
// round of review has produced another member of that list. Rather than name
// them, the property they all violate is measured directly.
//
// Comments and quoted spans are skipped so a brace inside a message cannot move
// the depth. Here-strings and block comments are refused before this runs, so
// the remaining span kinds are '...' and "...", both terminated on their own
// quote, with the doubling escape ('' and "") and the double-quoted backtick
// escape handled.
function powerShellBraceDepthAt(text, offset) {
  let depth = 0;
  let index = 0;
  while (index < text.length) {
    if (index === offset) return depth;
    const character = text[index];
    // Outside a quoted span the backtick is PowerShell's escape character, so
    // the character after it is a literal rather than syntax. This is checked
    // before the comment and quote branches because a backtick escapes those
    // introducers too.
    //
    // Reproduced before fixing, because the obvious spelling does not work: a
    // bare "`{" in statement position is parsed as a command named { and fails.
    // In argument position it does work --
    //
    //   Write-Host `{
    //   return
    //   Write-Host `}
    //
    // -- prints a literal brace and then returns from the script. A scanner
    // that counted those two braces placed that return at depth one and let it
    // through, and the balanced pair left the generator assertion at depth zero
    // so nothing else objected either.
    //
    // Inside a single-quoted string the backtick is not an escape, which is why
    // this sits outside the quote handling rather than inside it: the quote
    // branch consumes those spans whole before this can see them.
    if (character === '`') { index += 2; continue; }
    if (character === '#') {
      const start = index;
      while (index < text.length && text[index] !== '\n') index += 1;
      if (offset > start && offset < index) return null;
      continue;
    }
    if (character === "'" || character === '"') {
      const start = index;
      index += 1;
      while (index < text.length) {
        if (character === '"' && text[index] === '`') { index += 2; continue; }
        if (text[index] === character) {
          if (text[index + 1] === character) { index += 2; continue; }
          index += 1;
          break;
        }
        index += 1;
      }
      if (offset > start && offset < index) return null;
      continue;
    }
    if (character === '{') depth += 1;
    else if (character === '}') depth -= 1;
    index += 1;
  }
  return offset === text.length ? depth : null;
}

export function validateBuildPolicy(workflow, source) {
  assertKeys(workflow, ['name', 'on', 'permissions', 'jobs'], 'build root');
  if (workflow.name !== 'Build Style Guide Artifacts') reject('policy', 'build workflow name is not locked');
  assertEqual(workflow.on, EXPECTED_TRIGGER, 'build triggers');
  assertEqual(workflow.permissions, { contents: 'read' }, 'build workflow permissions');
  assertKeys(workflow.jobs, ['verify', 'publish'], 'build jobs');

  const verify = workflow.jobs.verify;
  assertKeys(verify, ['runs-on', 'permissions', 'steps'], 'build.verify');
  if (verify['runs-on'] !== 'ubuntu-latest') reject('policy', 'build.verify runner changed');
  // No scopes, not contents: read. This is the job that runs the generator, so
  // the repository token it would otherwise carry is given nothing to carry.
  assertEqual(verify.permissions, {}, 'build.verify permissions');
  // And no actions, which the scopes above cannot substitute for. The runner
  // populates ACTIONS_RUNTIME_TOKEN from the job's system connection rather
  // than from the permissions map -- NodeScriptActionHandler assigns it before
  // it decides whether it is running the pre, main, or post script -- so any
  // JavaScript action here would put a credential this job cannot revoke into
  // a process that outlives the generator step. The mirror of the publish
  // rule below: that job runs no script, this job uses no action.
  for (const step of verify.steps) {
    if ('uses' in step) reject('isolation-policy', `build.verify.${step.id} uses an action`);
  }
  const verifyIds = verify.steps.map((step) => step?.id);
  // generate-and-verify is last on purpose. Anything appended after it runs
  // with whatever the generator's surviving descendants left behind, including
  // values they appended to the runner's step communication files once the
  // in-step emptiness assertion could no longer observe them.
  assertEqual(verifyIds, ['acquire', 'verify-checkout-credentials', 'generate-and-verify'], 'build.verify step order');
  validateAcquireStep(findStep(verify, 'acquire', 'build.verify'), 'build.verify.acquire', BUILD_ACQUIRE);
  validateCredentialCleanupStep(
    findStep(verify, 'verify-checkout-credentials', 'build.verify'),
    'build.verify.verify-checkout-credentials',
  );

  // The publishing job exists to be the one place that reads artifact bytes
  // without ever having run the code that produces them. That property is
  // structural -- it holds because no script runs here at all -- so it is
  // asserted structurally: exactly two pinned actions, and no run: key
  // anywhere in the job. A single added script step would put repository
  // code back in the same job as the upload, which is the arrangement this
  // separation exists to prevent.
  const publish = workflow.jobs.publish;
  assertKeys(publish, ['needs', 'runs-on', 'permissions', 'steps'], 'build.publish');
  if (publish.needs !== 'verify') reject('policy', 'build.publish does not depend on verify');
  if (publish['runs-on'] !== 'ubuntu-latest') reject('policy', 'build.publish runner changed');
  assertEqual(publish.permissions, { contents: 'read' }, 'build.publish permissions');
  const publishIds = publish.steps.map((step) => step?.id);
  assertEqual(publishIds, ['checkout', 'upload-generated'], 'build.publish step order');
  for (const step of publish.steps) {
    if ('run' in step) reject('isolation-policy', `build.publish.${step.id} runs a script`);
    if ('shell' in step) reject('isolation-policy', `build.publish.${step.id} declares a shell`);
    if ('env' in step) reject('isolation-policy', `build.publish.${step.id} sets step environment`);
  }
  assertActionStep(findStep(publish, 'checkout', 'build.publish'), 'build.publish.checkout', ACTIONS.checkout, CHECKOUT_INPUTS);
  assertActionStep(
    findStep(publish, 'upload-generated', 'build.publish'),
    'build.publish.upload-generated',
    ACTIONS.uploadArtifact,
    UPLOAD_INPUTS,
  );

  for (const { jobId, id, run, step } of allRunSteps(workflow)) {
    if ('continue-on-error' in step) reject('failure-policy', `${jobId}.${id} sets continue-on-error`);
    if (NETWORK_CLIENT.test(run)) reject('network-policy', `${jobId}.${id} adds a network client`);
    // Two checks, most specific first, over the whole serialized step rather
    // than over run alone -- a credential reaches the script through any step
    // key just as effectively as through script text.
    //
    // The named patterns come first so a recognised credential is reported as a
    // credential rather than as a generic expression, and because they catch
    // what the expression ban cannot: $env:GITHUB_TOKEN is a literal, not an
    // expression. All three are case-insensitive.
    //
    // The expression ban is what stops this predicate needing a fourth fix.
    // Three consecutive rounds found it one spelling short -- it scanned run
    // instead of the whole step, then matched case-sensitively, then knew only
    // the dot form and missed github['token'] -- and each fix added the
    // spelling just found. No governed script step contains an expression at
    // all, verified across all three, so the syntax itself is refused and the
    // spellings stop mattering.
    //
    // Action steps carry token: ${{ github.token }} legitimately and are never
    // scanned here: allRunSteps collects only steps with a run string.
    const serialized = JSON.stringify(step);
    if (/secrets\./iu.test(serialized) || /GITHUB_TOKEN/iu.test(serialized) || /github\.token/iu.test(serialized)) {
      reject('credential-policy', `${jobId}.${id} expands an unapproved credential`);
    }
    if (/\$\{\{/u.test(serialized)) {
      reject('credential-policy', `${jobId}.${id} contains a workflow expression`);
    }
    // Every assertion in this file matches text, so text that never executes can
    // satisfy one: a here-string or a block comment carrying an approved command
    // reads identically to the command itself. Neither governed script step uses
    // either construct, so both are refused and a match therefore means a
    // statement. Without this, anchoring the generator invocation to its own
    // line buys nothing -- here-string content sits at column zero too.
    if (/@['"]|<#/u.test(run)) {
      reject('side-effect-policy', `${jobId}.${id} uses a here-string or block comment`);
    }
    // A trap is registered for its entire scope, not for the text after it, so
    // one placed anywhere in a step disarms every throw in that step -- which
    // is every assertion these steps make. No governed step uses one, and no
    // position in a step is a safe place for one, so it is refused outright
    // rather than bounded to a region the way catch is.
    if (/\btrap\b/iu.test(run)) {
      reject('side-effect-policy', `${jobId}.${id} registers a script-wide error trap`);
    }
    // No job in this workflow holds contents: write, so there is no approved
    // push, commit, or staging path anywhere in it. These are flat refusals
    // rather than exemptions keyed to a step id.
    if (/ArgumentList\.Add\(['"]push['"]\)|\bgit\s+push\b/iu.test(run)) {
      reject('side-effect-policy', `${jobId}.${id} adds a push path to a read-only workflow`);
    }
    if (/\bgit\s+(?:add|commit)\b/iu.test(run)) {
      reject('side-effect-policy', `${jobId}.${id} adds a repository mutation to a read-only workflow`);
    }
  }

  const generateStep = findStep(verify, 'generate-and-verify', 'build.verify');
  assertScriptStep(
    generateStep,
    'build.verify.generate-and-verify',
    "'diff', '--no-ext-diff', '--no-textconv', '--quiet'",
    'verification no longer classifies native git diff status',
  );
  // The generator is repository-controlled code and every check in this step
  // runs after it. In-session it could shadow a cmdlet with a function, reassign
  // a variable in this scope through Set-Variable -Scope 1, or prepend a
  // directory to PATH -- each of which redirects the checks onto something it
  // chose. A process boundary removes the class instead of naming its members,
  // so the invocation form is policy rather than style.
  if (/^\s*& \.\/\.github\/workflows\/Generate-StyleGuideArtifacts\.ps1\s*$/mu.test(generateStep.run)) {
    reject('side-effect-policy', 'the generator is invoked in-session');
  }
  // Matched as a statement on its own line, not as a substring. A substring is
  // satisfied by text that never executes -- a comment, or a single-quoted
  // here-string containing the approved command -- and the positional checks
  // below anchor on the same match, so inert text would move the "after the
  // generator" region somewhere harmless while the generator never ran.
  const generatorStatement = /^& pwsh -NoProfile -NonInteractive -File \.\/\.github\/workflows\/Generate-StyleGuideArtifacts\.ps1$/mu;
  if ((generateStep.run.match(generatorStatement) ?? []).length !== 1) {
    reject('side-effect-policy', 'the generator is not invoked exactly once as a statement');
  }
  // One notion of where the generator is, computed once and used by every
  // positional check below. There used to be two: this anchored match, and a
  // bare indexOf of the invocation's leading substring. They disagree on any
  // spelling that is not exactly this statement -- an indented copy, a second
  // occurrence, a mention inside a string -- and where they disagree the
  // positional checks were deriving "after the generator" from a position the
  // statement match never approved.
  const generatorIndex = generateStep.run.search(generatorStatement);
  const afterGenerator = generateStep.run.slice(generatorIndex);
  // The statement must also be code. Everything in this file matches text, and
  // text inside a region that never executes reads exactly like text that does:
  // a here-string and a block comment are refused outright above, but those two
  // do not exhaust the ways to write inert PowerShell. $null = { ... } is one,
  // if ($false) { ... } is another, and there is no end to that list. So the
  // property is derived rather than enumerated: brace depth is tracked across
  // the script, ignoring comments and quoted spans, and the invocation is
  // required to sit at depth zero -- outside every block, whatever introduced
  // it. Depth zero is where the step's own statements live; every function in
  // the script is defined inside braces and none of them may contain this.
  if (powerShellBraceDepthAt(generateStep.run, generatorIndex) !== 0) {
    reject('side-effect-policy', 'the generator invocation is nested inside a block');
  }
  // Git is resolved from a fixed candidate list before the generator runs and
  // held in a constant. A PATH lookup or Get-Command call placed after the
  // generator would consult state that code can steer, and an ordinary variable
  // could be reassigned from the generator's child scope.
  if (!generateStep.run.includes("@('/usr/bin/git', '/bin/git')") ||
      !generateStep.run.includes('New-Variable -Name strGitPath -Value $strResolvedGit -Option Constant') ||
      !generateStep.run.includes('$objStartInfo.FileName = $strGitPath')) {
    reject('git-policy', 'build.verify does not pin the Git executable before repository code runs');
  }
  if (/Get-Command/u.test(generateStep.run)) {
    reject('git-policy', 'build.verify resolves Git through a shadowable command lookup');
  }
  if (generateStep.run.indexOf('New-Variable -Name strGitPath') > generatorIndex) {
    reject('git-policy', 'build.verify resolves Git after the generator runs');
  }
  // Pinning the executable does not pin what Git will do: repository-local
  // configuration is loaded on every invocation, and core.fsmonitor names a
  // program Git runs to decide which paths changed. A hostile value makes every
  // probe below report a clean tree over modified files. The repository's own
  // configuration and hook surface is therefore digested across the generator.
  if (!generateStep.run.includes('function Get-GitControlSurfaceDigest') ||
      !generateStep.run.includes('$strControlSurfaceBefore = Get-GitControlSurfaceDigest') ||
      !generateStep.run.includes('git-state: the generator changed repository Git configuration or hooks') ||
      generateStep.run.indexOf('$strControlSurfaceBefore = Get-GitControlSurfaceDigest') > generatorIndex ||
      generateStep.run.indexOf('git-state: the generator changed repository Git configuration or hooks') < generatorIndex) {
    reject('git-policy', 'build.verify does not bracket the generator with a Git control-surface digest');
  }
  // Every Git probe in this step reports on state the generator can move: it
  // can stage and commit its output, advancing HEAD and emptying the working,
  // cached, and untracked sets, or set the advisory assume-unchanged bit that
  // Git documents as not working as expected for this purpose. Either makes a
  // stale artifact look clean. The deciding gate is therefore a byte-level
  // before/after comparison of the working tree, which asks Git nothing and
  // covers both drift and blast radius in one assertion.
  if (!generateStep.run.includes('function Get-WorktreeFileDigests') ||
      !generateStep.run.includes('$objWorktreeBefore = Get-WorktreeFileDigests') ||
      !generateStep.run.includes('$objWorktreeAfter = Get-WorktreeFileDigests') ||
      !generateStep.run.includes('generated-artifacts: committed artifacts do not match generator output') ||
      !generateStep.run.includes('outside the four generated artifacts') ||
      generateStep.run.indexOf('$objWorktreeBefore = Get-WorktreeFileDigests') > generatorIndex ||
      generateStep.run.indexOf('$objWorktreeAfter = Get-WorktreeFileDigests') < generatorIndex) {
    reject('side-effect-policy', 'build.verify does not bracket the generator with a worktree byte comparison');
  }
  // How the walk reaches the files decides what it can be made to read.
  // EnumerateFiles with AllDirectories descends through a directory link and
  // reports only the files behind it, so the walk leaves the workspace with no
  // entry to refuse; holding the frontier explicitly is what makes the link
  // visible first. Refusing a link rather than skipping one keeps the signal:
  // a skipped link is absent from both maps, which reads exactly like a
  // generator that did nothing. Streaming bounds the cost of a large file, and
  // consulting Length before opening keeps a FIFO from blocking the step until
  // the job times out.
  if (!generateStep.run.includes('[System.IO.Directory]::EnumerateFileSystemEntries($objPending.Pop())') ||
      generateStep.run.includes('[System.IO.SearchOption]::AllDirectories') ||
      !generateStep.run.includes("throw 'worktree: the working tree contains a link'") ||
      !generateStep.run.includes('[System.IO.FileAttributes]::ReparsePoint') ||
      !generateStep.run.includes('$objSha.ComputeHash($objStream)') ||
      generateStep.run.includes('[System.IO.File]::ReadAllBytes($strEntry)')) {
    reject('side-effect-policy', 'build.verify worktree walk can follow a link or read a file whole');
  }
  // Both remaining branches of the walk are named here rather than left to the
  // closing digest, because the digest is re-baselined by design whenever a
  // reviewed edit lands: an invariant only that digest protects is an invariant
  // that a legitimate re-stamp silently drops.
  //
  // The exclusion must compare the path to .git itself. A prefix test on the
  // string ".git" also matches .github and .gitattributes, which would drop the
  // workflows and the text policy out of both maps -- the generator could then
  // rewrite them with the comparison reporting no change at all.
  if (!generateStep.run.includes('$objFile.Length -eq 0') ||
      !generateStep.run.includes('if ($strEntry -cne $strGitDirectory) { $objPending.Push($strEntry) }') ||
      generateStep.run.includes('$strGitPrefix')) {
    reject('side-effect-policy', 'build.verify worktree walk lost its FIFO guard or its exact .git exclusion');
  }
  // The digest is only meaningful if its encoding is injective. Concatenating
  // the components raw is not: renaming pre-commit.sample to pre-commit and
  // prepending '.sample' to its content yields the identical byte stream while
  // converting an inert sample into an active hook. Each component is therefore
  // length-prefixed, and the component count is written first.
  if (!generateStep.run.includes('$arrComponents = [System.Collections.Generic.List[byte[]]]::new()') ||
      !generateStep.run.includes('$arrLength = [System.BitConverter]::GetBytes([long]$arrComponent.Length)') ||
      !generateStep.run.includes('$arrCount = [System.BitConverter]::GetBytes([long]$arrComponents.Count)')) {
    reject('git-policy', 'the Git control-surface digest does not frame its components unambiguously');
  }
  // GitHub applies these files to every subsequent step in the job. There is
  // no subsequent step today -- the step-order assertion above is what makes
  // that true -- but the two controls answer different questions and neither
  // subsumes the other: the order assertion says nothing consumes a poisoned
  // environment, and this one says the environment was not poisoned while the
  // step could still see it. The generator runs in a child process, which
  // closes the in-session channels but not these: they are files, writable
  // from any process, including descendants that outlive the step.
  if (!generateStep.run.includes('New-Variable -Name arrChannelPaths -Value @($env:GITHUB_ENV, $env:GITHUB_PATH) -Option Constant') ||
      !generateStep.run.includes('runner-state: the generator wrote to a runner step communication file') ||
      generateStep.run.indexOf('New-Variable -Name arrChannelPaths') > generatorIndex ||
      generateStep.run.indexOf('runner-state: the generator wrote to a runner step communication file') < generatorIndex) {
    reject('side-effect-policy', 'build.verify does not assert the runner step communication files are empty');
  }
  // The control-surface digest covers repository-local configuration only.
  // Git also loads system and global configuration on every invocation, and a
  // generator that writes core.fsmonitor to ~/.gitconfig steers every probe
  // while .git/config stays byte-identical. Those two locations are removed
  // from the child rather than inspected, which together with the local digest
  // accounts for all three documented configuration sources.
  if (!generateStep.run.includes("$objStartInfo.Environment['GIT_CONFIG_GLOBAL'] = '/dev/null'") ||
      !generateStep.run.includes("$objStartInfo.Environment['GIT_CONFIG_NOSYSTEM'] = '1'")) {
    reject('git-policy', 'build.verify probes inherit system or global Git configuration');
  }
  // Recording drift and continuing was coherent while a promotion writer
  // existed to commit the regenerated bytes; failing here would have skipped
  // it. Nothing commits them now, so a tolerated exit status 1 leaves the
  // repository stale behind a green check that claims verification.
  if (!generateStep.run.includes('if ($objDiff.ExitCode -eq 1) {') ||
      !generateStep.run.includes('generated-artifacts: committed artifacts do not match generator output')) {
    reject('side-effect-policy', 'build.verify tolerates generated-artifact drift');
  }
  // An inserted early exit leaves every required fragment and ordering check
  // intact while skipping every probe below it, and the upload action then
  // publishes artifacts labelled verified that nothing verified. This script
  // defines functions, so the tokens are matched in statement position only.
  if (/^[ \t]*(?:exit|break|continue)\b|[;{][ \t]*(?:exit|break|continue)\b/imu.test(generateStep.run)) {
    reject('side-effect-policy', 'build.verify adds control flow that can bypass a required probe');
  }
  // return could not join that list: this script defines five functions and
  // every one of them ends in a return, so refusing the token outright would
  // refuse the script itself. Indentation cannot separate the two either --
  // PowerShell does not care where a statement sits, so a top-level return
  // could simply be indented to look nested.
  //
  // This was previously separated by position: refuse a return anywhere after
  // the generator, on the reasoning that every legitimate return is inside a
  // function defined before it. That reasoning was sound about where the
  // legitimate returns are and wrong about where a hostile one has to go. A
  // return placed one line *above* the generator ends the script before the
  // generator ever runs, and it satisfies every fragment, ordering, and depth
  // assertion here -- reproduced directly, and only the closing digest
  // objected, which is the arrangement lines 550-553 already call out as
  // insufficient on its own.
  //
  // Depth separates them exactly, and unlike position it does not care which
  // side of the generator the return sits on. Every legitimate return is
  // inside a function body, so at brace depth one or more; a return at depth
  // zero is a script-level return whatever it looks like and wherever it is.
  // A return inside a comment or a quoted span scans as null rather than zero
  // and is left alone, because it is not code.
  for (const returnToken of generateStep.run.matchAll(/\breturn\b/giu)) {
    if (powerShellBraceDepthAt(generateStep.run, returnToken.index) === 0) {
      reject('side-effect-policy', 'build.verify returns from the script at top level');
    }
  }
  // Every probe reports by throwing, so a handler around the governed region
  // turns each verdict into a no-op and the step succeeds having rejected
  // nothing. try/finally is used legitimately -- five of them, all disposing a
  // hash or a process -- but every one is inside a function defined before the
  // generator, so the same boundary that separates the returns separates these.
  //
  // trap used to be checked here alongside catch, and that was wrong: a trap
  // is registered for its whole scope rather than for the text that follows
  // it, so one written at the top of the script -- before the generator, in
  // the region this slice does not cover -- suppresses every throw below it
  // just the same. Position cannot separate a legitimate trap from a hostile
  // one because there is no legitimate one, in any governed step, so it is
  // refused everywhere instead.
  if (/\bcatch\b/iu.test(afterGenerator)) {
    reject('side-effect-policy', 'build.verify can suppress a probe failure after the generator runs');
  }
  // Redirected stdout and stderr must be drained concurrently. Reading either to
  // completion before the other deadlocks once the child fills the unread pipe,
  // which hangs the step until the Actions timeout instead of failing.
  //
  // This sits before the closing digest deliberately. Any edit to the step
  // changes the digest, so a digest placed first rejects every mutation and
  // the fixture for this assertion was passing on the digest's verdict rather
  // than on this one -- coverage the fixture count claimed and did not have.
  // Every named assertion must be reachable ahead of the backstop that would
  // otherwise answer for it.
  if (!generateStep.run.includes('$objProcess.StandardOutput.BaseStream.CopyToAsync($objOutput)') ||
      !generateStep.run.includes('$objProcess.StandardError.ReadToEndAsync()')) {
    reject('git-policy', 'build.verify no longer drains both Git streams concurrently');
  }
  // Closing backstop, mirroring the Markdown validation step, and last for the
  // reason above. The assertions before it name what changed; this pins
  // everything they do not model.
  if (createHash('sha256').update(generateStep.run, 'utf8').digest('hex') !== REVIEWED_VERIFY_STEP_DIGEST) {
    reject('side-effect-policy', 'build.verify script does not match its reviewed digest');
  }

  // One checkout, in the publishing job only. verify acquires the triggering
  // revision itself precisely so that it contains no action, and counting the
  // uses here is what keeps one from reappearing in either job: the per-step
  // rejection above says verify declares no uses key, and this says the file
  // as a whole contains exactly these two.
  validateActionMultiset(source, [ACTIONS.checkout, ACTIONS.uploadArtifact]);
}

// Shared by both jobs that run repository-controlled code, because both now
// acquire their own revision rather than using an action to do it. The two
// differ only in what else they have to bring: build.verify needs nothing but
// the tree, and markdown.markdownlint also needs the Node distribution that
// setup-node used to supply.
function validateAcquireStep(step, label, expected) {
  assertKeys(step, ['name', 'id', 'shell', 'run'], label);
  if (step.name !== expected.name || step.shell !== 'pwsh') {
    reject('acquire-policy', `${label} execution contract changed`);
  }
  // Named, not positional, and each with its own fixture -- the same correction
  // the credential-cleanup step needed. A single shared message would let a
  // fixture prove only that some requirement was missing.
  const requiredSequences = [
    // Absent-key and no-op statuses are classified explicitly below, which is
    // only reachable when native commands are not mapped onto the preference.
    ['native-command error mapping is disabled',
      'if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {\n' +
      '    $PSNativeCommandUseErrorActionPreference = $false\n' +
      '}'],
    ['the server the runner named',
      "if ($strServerUrl -cne 'https://github.com') {"],
    ['a plain owner/name repository',
      "if ($strRepository -cnotmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {"],
    // A ref resolves to whatever it points at when the fetch runs, which for a
    // push to a busy branch need not be the revision that triggered the run.
    ['a full commit hash rather than a ref',
      "if ($strSha -cnotmatch '^[0-9a-f]{40}$') {"],
    // Proven empty rather than cleaned: cleaning decides what to delete from
    // state that is already there, and an emptiness assertion has no such input.
    ['an empty workspace before fetching',
      'if (@([System.IO.Directory]::EnumerateFileSystemEntries($PWD.Path)).Count -ne 0) {'],
    ['a fetch of the commit itself',
      '& git fetch --depth 1 --no-tags --no-recurse-submodules origin $strSha'],
    // Without this the step would accept whatever FETCH_HEAD happened to be.
    ['that the checked out revision is the triggering revision',
      '$strHead = (& git rev-parse HEAD).Trim()\n' +
      'if ($LASTEXITCODE -ne 0 -or $strHead -cne $strSha) {'],
  ];
  for (const [requirement, sequence] of [...requiredSequences, ...(expected.extraSequences ?? [])]) {
    if (!step.run.includes(sequence)) {
      reject('acquire-policy', `${label} no longer asserts ${requirement}`);
    }
  }
  // The whole point of this step is that no credential exists to clean up, so
  // no mechanism for creating one may appear. checkout's own inputs are not
  // available here to be got wrong; what is available is a URL with a
  // credential in it, a helper, or an extraheader, and all three are refused.
  if (/@github\.com|credential\.helper|extraheader|GIT_ASKPASS|GITHUB_TOKEN/iu.test(step.run)) {
    reject('acquire-policy', `${label} introduces a credential into an anonymous fetch`);
  }
  // Every native status is classified. A missing classification is a step that
  // proceeds on a failed fetch and then digests whatever is on disk.
  const classifiedStatuses = step.run.match(/^if \(\$LASTEXITCODE -ne 0/gmu)?.length ?? 0;
  if (classifiedStatuses !== expected.classifiedStatuses) {
    reject('acquire-policy', `${label} native-status classification count changed`);
  }
  if (/\b(?:exit|break|continue|trap)\b/iu.test(step.run)) {
    reject('acquire-policy', `${label} adds control flow that can bypass a required assertion`);
  }
  // Counted, not merely permitted. The Markdown acquire step is allowed one
  // download and the build one is allowed none, and a second request is how a
  // re-baselined step would fetch something the reviewed digest never covered.
  const networkClients = step.run.match(new RegExp(NETWORK_CLIENT.source, 'giu'))?.length ?? 0;
  if (networkClients !== expected.networkClients) {
    reject('acquire-policy', `${label} network request count changed`);
  }
  if (expected.tail !== undefined && !step.run.trimEnd().endsWith(expected.tail)) {
    reject('acquire-policy', `${label} does not end at the verified extraction`);
  }
  if (createHash('sha256').update(step.run, 'utf8').digest('hex') !== expected.digest) {
    reject('acquire-policy', `${label} script does not match its reviewed digest`);
  }
}

function validateCredentialCleanupStep(step, label) {
  assertKeys(step, ['name', 'id', 'shell', 'run'], label);
  if (step.name !== 'Verify checkout credential cleanup' || step.shell !== 'pwsh') {
    reject('credential-policy', `${label} execution contract changed`);
  }
  const requiredSequences = [
    // The origin pair was covered only by the digest added alongside it, and a
    // digest is re-baselined by design on every reviewed edit -- so the one
    // control protecting them was the one guaranteed to be replaced. Both are
    // named here, ahead of that digest, with isolating fixtures. Cardinality
    // first: more than one origin URL means the checks below inspect one remote
    // while Git could use another. Then the shape: the URL must carry no
    // credential, which is what makes the absent helper and absent extraheader
    // below sufficient rather than merely consistent.
    ['exactly one origin URL',
      '$arrRemoteUrls = @(& git remote get-url --all origin)\n' +
      'if ($LASTEXITCODE -ne 0 -or $arrRemoteUrls.Count -ne 1) {'],
    ['a credential-free GitHub HTTPS origin',
      "if ($arrRemoteUrls[0] -notmatch '^https://github\\.com/[^/@]+/[^/@]+(?:\\.git)?$') {"],
    // Both accepted absent-key statuses below are only reachable when native
    // commands are not mapped onto $ErrorActionPreference.
    ['native-command error mapping is disabled',
      'if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {\n' +
      '    $PSNativeCommandUseErrorActionPreference = $false\n' +
      '}'],
    ['no local credential helper',
      '$arrHelpers = @(& git config --local --get-all credential.helper)\n' +
      '$intHelperExit = $LASTEXITCODE\n' +
      '$global:LASTEXITCODE = 0\n' +
      'if (($intHelperExit -ne 0 -and $intHelperExit -ne 1) -or $arrHelpers.Count -ne 0)'],
    ['no persisted HTTP authorization',
      "$arrAuthorizationKeys = @(& git config --local --name-only --get-regexp '^http\\..*\\.extraheader$')\n" +
      '$intAuthorizationExit = $LASTEXITCODE\n' +
      '$global:LASTEXITCODE = 0\n' +
      'if (($intAuthorizationExit -ne 0 -and $intAuthorizationExit -ne 1) -or $arrAuthorizationKeys.Count -ne 0)'],
  ];
  // Named rather than positional. One shared message for every sequence meant a
  // fixture could only prove that some required sequence was missing, not which
  // -- and telling those apart is the whole point of stating what a fixture
  // expects.
  for (const [requirement, sequence] of requiredSequences) {
    if (!step.run.includes(sequence)) {
      reject('credential-policy', `${label} no longer asserts ${requirement}`);
    }
  }
  const normalizationCount = step.run.match(/^\$global:LASTEXITCODE = 0$/gmu)?.length ?? 0;
  if (normalizationCount !== 2) {
    reject('credential-policy', `${label} native-status normalization count changed`);
  }
  // Every check above asks whether a sequence is present, and presence is not
  // execution. Prepending exit 0 leaves all of them satisfied while PowerShell
  // returns before either credential assertion runs, and this step had neither
  // of the two controls that answer that elsewhere: a control-flow rejection
  // and a complete-script digest. It has both now, for the same reason the
  // generate-and-verify step does. This script defines no functions, so the
  // tokens are matched anywhere rather than in statement position only.
  if (/\b(?:exit|break|continue)\b/iu.test(step.run)) {
    reject('credential-policy', `${label} adds control flow that can bypass a required assertion`);
  }
  if (createHash('sha256').update(step.run, 'utf8').digest('hex') !== REVIEWED_CREDENTIAL_STEP_DIGEST) {
    reject('credential-policy', `${label} script does not match its reviewed digest`);
  }
}

export function validateMarkdownPolicy(workflow, source) {
  assertKeys(workflow, ['name', 'on', 'permissions', 'jobs'], 'markdown root');
  if (workflow.name !== 'Markdown Lint') reject('policy', 'Markdown workflow name is not locked');
  assertEqual(workflow.on, EXPECTED_TRIGGER, 'Markdown triggers');
  assertEqual(workflow.permissions, { contents: 'read' }, 'Markdown workflow permissions');
  assertKeys(workflow.jobs, ['markdownlint'], 'Markdown jobs');

  const job = workflow.jobs.markdownlint;
  assertKeys(job, ['runs-on', 'permissions', 'steps'], 'markdown.markdownlint');
  if (job['runs-on'] !== 'ubuntu-latest') reject('policy', 'Markdown runner changed');
  // Same two rules as build.verify, and for the same reason in the same order.
  // No scopes, because this job runs repository-controlled code; and no
  // actions, because the scopes are not what the exposure runs on. A
  // JavaScript action receives ACTIONS_RUNTIME_TOKEN from the job's system
  // connection whatever the permissions map says, and its post step executes
  // after the lint phases have run repository code. Removing the actions is
  // what removes the credential from the job.
  assertEqual(job.permissions, {}, 'Markdown job permissions');
  for (const step of job.steps) {
    if ('uses' in step) reject('isolation-policy', `markdown.${step.id} uses an action`);
  }
  assertEqual(job.steps.map((step) => step?.id), ['acquire', 'validate-and-lint'], 'Markdown step order');
  validateAcquireStep(findStep(job, 'acquire', 'markdown.markdownlint'), 'markdown.acquire', MARKDOWN_ACQUIRE);

  const validation = findStep(job, 'validate-and-lint', 'markdown.markdownlint');
  assertKeys(validation, ['name', 'id', 'shell', 'working-directory', 'run'], 'markdown.validate-and-lint');
  if (validation.shell !== 'pwsh' || validation['working-directory'] !== '.github/workflows') {
    reject('policy', 'Markdown validation execution context changed');
  }
  const requiredFragments = [
    "-cne 'v24.18.1'",
    "-cne '11.16.0'",
    'if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {',
    'ci --ignore-scripts --no-audit --no-fund',
    './Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml',
    'run lint:md',
    'run lint:md:nested',
    'Get-FileHash -LiteralPath package.json -Algorithm SHA256',
    'Get-FileHash -LiteralPath package-lock.json -Algorithm SHA256',
    // Derived from the reviewed constants so the pre-install gate in the
    // workflow and the policy baseline here cannot drift apart silently.
    REVIEWED_PACKAGE_DIGESTS['package.json'].toUpperCase(),
    REVIEWED_PACKAGE_DIGESTS['package-lock.json'].toUpperCase(),
    'if ($strPackageBefore -cne $strReviewedPackageHash -or $strLockBefore -cne $strReviewedLockHash)',
    'supply: package metadata does not match the reviewed supply digest',
    // Neither reviewed digest covers .npmrc, and no governed YAML mentions it,
    // so script-shell there is a lint bypass that leaves every other check green.
    "@('.npmrc', '../.npmrc', '../../.npmrc')",
    'supply: repository-controlled npm configuration is present',
    // What the lint does, not only what it runs. Derived from the reviewed
    // constants so the gate and this baseline cannot drift apart silently.
    REVIEWED_LINT_DIGESTS['.markdownlint.jsonc'].toUpperCase(),
    REVIEWED_LINT_DIGESTS['lint-nested-markdown.js'].toUpperCase(),
    'Get-FileHash -LiteralPath .markdownlint.jsonc -Algorithm SHA256',
    'Get-FileHash -LiteralPath lint-nested-markdown.js -Algorithm SHA256',
    'supply: lint configuration or helper does not match the reviewed digest',
  ];
  for (const fragment of requiredFragments) {
    if (!validation.run.includes(fragment)) reject('markdown-policy', `required phase is missing: ${fragment}`);
  }
  // Token presence alone cannot prove a phase runs. An inserted early exit
  // leaves every required fragment in place while skipping the phases below it,
  // so the step would report success without linting or re-checking metadata.
  // This script defines no functions, so these tokens have no legitimate use.
  // Matched only in statement position — at the start of a line or directly
  // after ; or { — so the word "exit" inside a throw message is not a hit.
  if (/^[ \t]*(?:exit|return|break|continue)\b|[;{][ \t]*(?:exit|return|break|continue)\b/imu.test(validation.run)) {
    reject('markdown-policy', 'validation script adds control flow that can bypass a required phase');
  }
  // Presence is order-independent; the phases must also run in the reviewed
  // sequence, so a later phase cannot be hoisted above the gate that guards it.
  let cursor = -1;
  for (const phase of [
    'supply: package metadata does not match the reviewed supply digest',
    // Must precede installation: npm reads .npmrc before it runs any command.
    'supply: repository-controlled npm configuration is present',
    // Must precede the lint phases, which execute both of these files.
    'supply: lint configuration or helper does not match the reviewed digest',
    'ci --ignore-scripts --no-audit --no-fund',
    'npm-ci: package metadata changed during frozen installation',
    './Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml',
    'run lint:md\n',
    'run lint:md:nested',
    'validation: package metadata changed after installation or linting',
    'validation: one or more policy or lint phases failed',
  ]) {
    const at = validation.run.indexOf(phase, cursor + 1);
    if (at <= cursor) reject('markdown-policy', `required phases are out of order at: ${phase}`);
    cursor = at;
  }
  if ((validation.run.match(/^\s*& \$strNpmPath run lint:md\s*$/gmu) ?? []).length !== 1 ||
      (validation.run.match(/^\s*& \$strNpmPath run lint:md:nested\s*$/gmu) ?? []).length !== 1) {
    reject('markdown-policy', 'each locked lint script must run exactly once');
  }
  if (/continue-on-error/iu.test(source)) {
    reject('markdown-policy', 'Markdown workflow weakens failure policy');
  }
  // The network ban is per step rather than per file, and it always should
  // have been. Its stated rationale -- that no governed step performs network
  // I/O -- was already untrue: npm ci fetches the whole dependency tree in the
  // lint step. What the rule actually protects is that the step running
  // repository-controlled code has no client of its own, and that is asserted
  // where it is true. The acquire step is exempt because it downloads the Node
  // distribution, and the exemption is paired with a replacement rather than
  // left open: its URL and the expected archive digest are reviewed constants
  // asserted above, so what it may fetch is fixed and what it accepts back is
  // fixed. It also runs before any repository code, so nothing it could be
  // steered by has executed yet.
  if (NETWORK_CLIENT.test(validation.run)) {
    reject('markdown-policy', 'markdown.validate-and-lint adds a network client');
  }
  // The credential scan and the expression ban were added to build.yml's script
  // steps and not to this one, so the invariant "no governed script step
  // contains an expression" held in one file and not the other -- a fix applied
  // to the instance rather than the class, which is the mistake this pull
  // request has now made often enough to assert against.
  //
  // The step is scanned rather than the file: markdownlint.yml legitimately
  // carries token: ${{ github.token }} on setup-node, and an action step is not
  // what this rule governs.
  const validationSerialized = JSON.stringify(validation);
  if (/secrets\./iu.test(validationSerialized) ||
      /GITHUB_TOKEN/iu.test(validationSerialized) ||
      /github\.token/iu.test(validationSerialized)) {
    reject('markdown-policy', 'markdown.validate-and-lint expands an unapproved credential');
  }
  if (/\$\{\{/u.test(validationSerialized)) {
    reject('markdown-policy', 'markdown.validate-and-lint contains a workflow expression');
  }
  if (/@['"]|<#/u.test(validation.run)) {
    reject('markdown-policy', 'markdown.validate-and-lint uses a here-string or block comment');
  }
  // Every phase in this step reports by throwing, and the one try in it exists
  // to restore the caller's CI variable in finally, not to handle anything. A
  // catch anywhere here turns a failed supply digest, a failed frozen install,
  // or a failed lint into a step that succeeds having decided nothing, and a
  // trap does the same for the whole script from wherever it is written. The
  // verify step bounds catch by position because it has one legitimate catch;
  // this step has none, so both are refused outright.
  if (/\b(?:catch|trap)\b/iu.test(validation.run)) {
    reject('markdown-policy', 'markdown.validate-and-lint can suppress a phase failure');
  }
  // Each captured phase status must be assigned exactly once, from $LASTEXITCODE.
  // Otherwise a later reassignment such as "$intPolicyExit = 0" leaves every
  // fragment, ordering, and command count intact while the deferred final check
  // sees only zeros and reports success over a failed phase.
  for (const strName of ['intNodeVersionExit', 'intNpmVersionExit', 'intInstallExit', 'intPolicyExit', 'intOuterExit', 'intNestedExit']) {
    const arrAssignments = validation.run.match(new RegExp(`\\$${strName}\\s*=`, 'gu')) ?? [];
    if (arrAssignments.length !== 1) {
      reject('markdown-policy', `captured phase status ${strName} is not assigned exactly once`);
    }
    if (!validation.run.includes(`$${strName} = $LASTEXITCODE`)) {
      reject('markdown-policy', `captured phase status ${strName} is not taken from $LASTEXITCODE`);
    }
  }

  // Closing backstop, the same shape as the one on the verify step. The
  // assertions above are kept because they name what changed; this pins
  // everything they do not model -- an indirect write to a captured status
  // through Set-Variable,
  // New-Variable, the Variable: provider, or a [ref] handle, none of which
  // contain the assignment syntax counted above.
  if (createHash('sha256').update(validation.run, 'utf8').digest('hex') !== REVIEWED_VALIDATION_STEP_DIGEST) {
    reject('markdown-policy', 'Markdown validation script does not match its reviewed digest');
  }

  // Zero. This job runs repository code, so it contains no action at all --
  // the same structural rule build.yml's verify job carries, asserted the same
  // two ways: no uses key on any step, and no pinned action anywhere in the
  // file.
  validateActionMultiset(source, []);
}

export function validateDependabotPolicy(value) {
  assertEqual(value, {
    version: 2,
    updates: [{
      'package-ecosystem': 'github-actions',
      directory: '/',
      schedule: { interval: 'weekly' },
    }],
  }, 'Dependabot configuration');
}

// Semantic assertions run before the digest so that an edit to a modelled field
// fails with the reason it failed. The digest is the closing backstop for any
// byte change the assertions above do not model.
export function validatePackagePolicy(packageSource, lockSource) {
  let manifest;
  let lock;
  try {
    manifest = JSON.parse(packageSource);
    lock = JSON.parse(lockSource);
  } catch {
    reject('supply-policy', 'package metadata is not parseable JSON');
  }

  assertEqual(manifest.scripts, REVIEWED_SCRIPTS, 'package.json scripts');
  assertEqual(manifest.devDependencies, REVIEWED_DEV_DEPENDENCIES, 'package.json devDependencies');
  if (manifest.private !== true) reject('supply-policy', 'package.json is not marked private');
  if (manifest.dependencies !== undefined) reject('supply-policy', 'package.json declares runtime dependencies');

  if (lock.lockfileVersion !== 3) reject('supply-policy', 'lockfile version is not the reviewed value');
  assertEqual(lock.packages?.['']?.devDependencies, REVIEWED_DEV_DEPENDENCIES, 'lockfile root devDependencies');
  const parser = lock.packages?.['node_modules/yaml'];
  if (parser === null || typeof parser !== 'object' || Array.isArray(parser)) {
    reject('supply-policy', 'lockfile does not resolve the yaml parser');
  }
  for (const [field, expected] of Object.entries(REVIEWED_PARSER)) {
    if (parser[field] !== expected) reject('supply-policy', `resolved yaml parser ${field} is not the reviewed value`);
  }

  for (const [label, source] of [['package.json', packageSource], ['package-lock.json', lockSource]]) {
    const digest = createHash('sha256').update(source, 'utf8').digest('hex');
    if (digest !== REVIEWED_PACKAGE_DIGESTS[label]) {
      reject('supply-policy', `${label} does not match its reviewed digest`);
    }
  }
}

export function parseGeneratorVersion(source, expectedVersion = undefined) {
  const firstFunction = source.search(/^function\s+/mu);
  if (firstFunction < 0) reject('invalid-version', 'generator has no first function boundary');
  const header = source.slice(0, firstFunction);
  const allMarkers = [...source.matchAll(/^Version:\s*(.*)$/gmu)];
  const headerMarkers = [...header.matchAll(/^Version:\s*(.*)$/gmu)];
  if (allMarkers.length !== 1 || headerMarkers.length !== 1) {
    reject('invalid-version', 'exactly one marker must occur in script help before the first function');
  }
  const notesStart = header.indexOf('.NOTES');
  const helpEnd = header.indexOf('#>', notesStart);
  if (notesStart < 0 || helpEnd < 0 || headerMarkers[0].index < notesStart || headerMarkers[0].index > helpEnd) {
    reject('invalid-version', 'the marker is outside script-level .NOTES');
  }

  const raw = headerMarkers[0][1];
  const match = raw.match(/^([0-9]+)\.([0-9]+)\.([0-9]{8})\.([0-9]+)$/u);
  if (!match) reject('invalid-version', 'marker grammar is invalid');
  for (const component of match.slice(1)) {
    if (component.length > 1 && component.startsWith('0')) reject('invalid-version', 'a component has a leading zero');
    const value = Number(component);
    if (!Number.isSafeInteger(value) || value > 2147483647) reject('invalid-version', 'a component is out of range');
  }
  const year = Number(match[3].slice(0, 4));
  const month = Number(match[3].slice(4, 6));
  const day = Number(match[3].slice(6, 8));
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() + 1 !== month || date.getUTCDate() !== day) {
    reject('invalid-version', 'build is not a real Gregorian date');
  }
  const canonical = match.slice(1).map((component) => String(Number(component))).join('.');
  if (canonical !== raw) reject('invalid-version', 'version does not round-trip canonically');
  if (expectedVersion !== undefined && canonical !== expectedVersion) {
    reject('unexpected-version', 'valid generator version does not match the trusted reviewed version');
  }
  return canonical;
}

function replaceOnce(source, from, to) {
  if (!source.includes(from)) reject('fixture-harness', `fixture source token is absent: ${from}`);
  return source.replace(from, to);
}

// Append-only inventory: existing IDs and meanings must never be reused.
// IDs retired when the temporary writer was deleted are not reissued; gaps in
// the BUILD sequence are deliberate. T1-BUILD-025 and T1-BUILD-026 were retired
// with them when publishing moved to its own job: both asserted on the upload
// step's if: ${{ success() }} gate, and the gate is now needs: verify at the job
// level, which T1-BUILD-088 covers. They are not reissued either.
const FIXTURE_INVENTORY = Object.freeze([
  ['T1-YAML-001', 'duplicate key', 'yaml', 'a: 1\na: 2\n'],
  ['T1-YAML-002', 'directive', 'yaml', '%YAML 1.2\n---\na: 1\n'],
  ['T1-YAML-003', 'anchor', 'yaml', 'a: &x 1\n'],
  // This one cannot be made anchor-free the way T1-YAML-005 was, and the reason
  // is worth recording rather than working around: an alias must reference an
  // anchor, so any document containing one contains the anchor first, and the
  // anchor rule fires first. The isAlias branch is therefore unreachable while
  // anchors are refused -- it is there for the case where that rule is ever
  // relaxed. What this fixture actually proves is that the pair is rejected,
  // which is true and worth keeping; its expectation below says so honestly
  // rather than claiming coverage of the alias branch.
  ['T1-YAML-004', 'alias behind its required anchor', 'yaml', 'a: &x 1\nb: *x\n'],
  // Anchor-free on purpose. Written as "a: &x { b: 1 }\nc: { <<: *x }" this
  // fixture was rejected by the anchor check before traversal ever reached the
  // merge key, so it proved the anchor rule twice and the merge-key rule not at
  // all. A merge key does not need an anchor to exist; it only usually has one.
  ['T1-YAML-005', 'merge key', 'yaml', 'c: { <<: { b: 1 } }\n'],
  ['T1-YAML-006', 'explicit tag', 'yaml', 'a: !!str value\n'],
  ['T1-YAML-007', 'multiple documents', 'yaml', 'a: 1\n---\nb: 2\n'],
  ['T1-YAML-008', 'complex key', 'yaml', '? [a, b]\n: value\n'],
  ['T1-YAML-009', 'non-finite scalar', 'yaml', 'a: .nan\n'],
  ['T1-YAML-010', 'anchor on mapping key', 'yaml', '? &x a\n: 1\n'],
  ['T1-YAML-011', 'explicit tag on mapping key', 'yaml', '? !!str a\n: 1\n'],
  ['T1-YAML-012', 'explicit tag on an inline mapping key', 'yaml', '!!str a: 1\n'],
  ['T1-YAML-013', 'anchor on an inline mapping key', 'yaml', '&x a: 1\n'],
  ['T1-BUILD-001', 'mutable action tag', 'build', (source) => replaceOnce(source, ACTIONS.checkout.reference, 'actions/checkout@v7')],
  ['T1-BUILD-002', 'arbitrary action SHA', 'build', (source) => replaceOnce(source, ACTIONS.checkout.reference, 'actions/checkout@1111111111111111111111111111111111111111')],
  ['T1-BUILD-003', 'wrong action repository', 'build', (source) => replaceOnce(source, ACTIONS.checkout.reference, 'example/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1')],
  ['T1-BUILD-004', 'wrong release annotation', 'build', (source) => replaceOnce(source, '# v7.0.1', '# v7.0.0')],
  ['T1-BUILD-005', 'duplicate action use', 'build', (source) => replaceOnce(source, '      - name: Upload verified generated artifacts', `      - name: Duplicate checkout\n        id: duplicate-checkout\n        uses: ${ACTIONS.checkout.reference} # ${ACTIONS.checkout.release}\n        with:\n          repository: \${{ github.repository }}\n\n      - name: Upload verified generated artifacts`)],
  ['T1-BUILD-006', 'missing action use', 'build', (source) => replaceOnce(source, `        uses: ${ACTIONS.uploadArtifact.reference} # ${ACTIONS.uploadArtifact.release}\n`, '')],
  ['T1-BUILD-007', 'swapped action role', 'build', (source) => replaceOnce(source, ACTIONS.uploadArtifact.reference, ACTIONS.checkout.reference)],
  ['T1-BUILD-008', 'missing checkout input', 'build', (source) => replaceOnce(source, '          fetch-tags: false\n', '')],
  ['T1-BUILD-009', 'extra checkout input', 'build', (source) => replaceOnce(source, '          lfs: false\n', '          lfs: false\n          path: alternate\n')],
  ['T1-BUILD-010', 'credential persistence', 'build', (source) => replaceOnce(source, '          persist-credentials: false', '          persist-credentials: true')],
  ['T1-BUILD-011', 'workflow write permission', 'build', (source) => replaceOnce(source, 'permissions:\n  contents: read', 'permissions:\n  contents: write')],
  // Same meaning as when it was written -- verify must not hold a write scope.
  // Only the anchor moved, because verify now declares no scopes at all.
  ['T1-BUILD-012', 'verify write permission', 'build', (source) => replaceOnce(source, '  verify:\n    runs-on: ubuntu-latest\n    permissions: {}', '  verify:\n    runs-on: ubuntu-latest\n    permissions:\n      contents: write')],
  ['T1-BUILD-014', 'missing verify job', 'build', (source) => replaceOnce(source, '  verify:', '  renamed-verify:')],
  ['T1-BUILD-015', 'extra job', 'build', (source) => `${source}\n  extra:\n    runs-on: ubuntu-latest\n    steps: []\n`],
  ['T1-BUILD-016', 'matrix introduction', 'build', (source) => replaceOnce(source, '  verify:\n    runs-on:', '  verify:\n    strategy:\n      matrix: { os: [ubuntu-latest] }\n    runs-on:')],
  ['T1-BUILD-017', 'service introduction', 'build', (source) => replaceOnce(source, '  verify:\n    runs-on:', '  verify:\n    services: {}\n    runs-on:')],
  ['T1-BUILD-018', 'remote reusable workflow', 'build', (source) => replaceOnce(source, '  verify:\n    runs-on:', '  verify:\n    uses: example/workflows/.github/workflows/x.yml@main\n    runs-on:')],
  ['T1-BUILD-024', 'job output introduction', 'build', (source) => replaceOnce(source, '  verify:\n    runs-on:', '  verify:\n    outputs: { changed: value }\n    runs-on:')],
  ['T1-BUILD-090', 'publishing step allowed to continue on error', 'build', (source) => replaceOnce(source, '        id: upload-generated\n        uses:', '        id: upload-generated\n        continue-on-error: true\n        uses:')],
  ['T1-BUILD-027', 'upload path broadening', 'build', (source) => replaceOnce(source, '            copilot-instructions.md', '            *.md')],
  ['T1-BUILD-028', 'upload overwrite', 'build', (source) => replaceOnce(source, '          overwrite: false', '          overwrite: true')],
  ['T1-BUILD-029', 'upload step order', 'build', (source) => replaceOnce(source, '        id: upload-generated', '        id: early-upload')],
  ['T1-BUILD-031', 'secret expression', 'build', (source) => replaceOnce(source, '${{ github.token }}', '${{ secrets.PAT }}')],
  ['T1-BUILD-032', 'trigger branch mutation', 'build', (source) => replaceOnce(source, '    branches: [main]', '    branches: [dev]')],
  ['T1-BUILD-033', 'extra trigger', 'build', (source) => replaceOnce(source, 'on:\n', 'on:\n  workflow_dispatch:\n')],
  ['T1-BUILD-034', 'dynamic uses', 'build', (source) => replaceOnce(source, ACTIONS.checkout.reference, '${{ inputs.action }}')],
  ['T1-BUILD-035', 'unreviewed Docker action', 'build', (source) => replaceOnce(source, ACTIONS.checkout.reference, 'docker://alpine:latest')],
  ['T1-BUILD-036', 'credential-helper status normalization removed', 'build', (source) => replaceOnce(source, '          $intHelperExit = $LASTEXITCODE\n          $global:LASTEXITCODE = 0\n', '          $intHelperExit = $LASTEXITCODE\n')],
  ['T1-BUILD-037', 'authorization status normalization removed', 'build', (source) => replaceOnce(source, '          $intAuthorizationExit = $LASTEXITCODE\n          $global:LASTEXITCODE = 0\n', '          $intAuthorizationExit = $LASTEXITCODE\n')],
  ['T1-BUILD-038', 'secret in step env', 'build', (source) => replaceOnce(source, '        id: generate-and-verify\n        shell: pwsh', "        id: generate-and-verify\n        env:\n          TOKEN: '${{ secrets.PAT }}'\n        shell: pwsh")],
  ['T1-BUILD-040', 'unreviewed key on a script step', 'build', (source) => replaceOnce(source, '        id: generate-and-verify\n        shell: pwsh\n', '        id: generate-and-verify\n        shell: pwsh\n        working-directory: .\n')],
  // Anchored through the line that follows it, not on the guard alone. The
  // acquire step disables native-command error mapping for the same reason and
  // appears first, so a bare anchor silently retargeted this fixture at that
  // step's copy and left the credential step's assertion uncovered. The
  // expectation check is what surfaced it.
  ['T1-BUILD-041', 'native-command error mapping guard removed', 'build', (source) => replaceOnce(source, '          if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {\n              $PSNativeCommandUseErrorActionPreference = $false\n          }\n          $arrRemoteUrls = @(& git remote get-url --all origin)\n', '          $arrRemoteUrls = @(& git remote get-url --all origin)\n')],
  ['T1-BUILD-050', 'sequential Git stream reads restored', 'build', (source) => replaceOnce(source, '                  $objCopyTask = $objProcess.StandardOutput.BaseStream.CopyToAsync($objOutput)\n                  $objErrorTask = $objProcess.StandardError.ReadToEndAsync()\n                  $objCopyTask.GetAwaiter().GetResult()\n                  $strError = $objErrorTask.GetAwaiter().GetResult()\n', '                  $objProcess.StandardOutput.BaseStream.CopyTo($objOutput)\n                  $strError = $objProcess.StandardError.ReadToEnd()\n')],
  ['T1-BUILD-053', 'credentialed executable resolved through PATH', 'build', (source) => replaceOnce(source, '              $objStartInfo.FileName = $strGitPath\n', '              $arrGitCommands = @(Get-Command git -CommandType Application -ErrorAction Stop)\n              $objStartInfo.FileName = $arrGitCommands[0].Source\n')],
  ['T1-BUILD-054', 'trusted Git path list widened', 'build', (source) => replaceOnce(source, "@('/usr/bin/git', '/bin/git')", "@($env:RUNNER_TEMP + '/git', '/usr/bin/git')")],
  ['T1-BUILD-061', 'PATH lookup reintroduced beside the pinned path', 'build', (source) => replaceOnce(source, '              $objStartInfo.FileName = $strGitPath\n', '              $arrFallback = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue)\n              $objStartInfo.FileName = $strGitPath\n')],
  ['T1-MARKDOWN-005', 'install scripts enabled', 'markdown', (source) => replaceOnce(source, 'ci --ignore-scripts --no-audit --no-fund', 'ci --no-audit --no-fund')],
  ['T1-MARKDOWN-006', 'audit enabled during install', 'markdown', (source) => replaceOnce(source, 'ci --ignore-scripts --no-audit --no-fund', 'ci --ignore-scripts --no-fund')],
  ['T1-MARKDOWN-007', 'outer lint removed', 'markdown', (source) => replaceOnce(source, 'run lint:md\n', 'run lint:other\n')],
  ['T1-MARKDOWN-008', 'nested lint removed', 'markdown', (source) => replaceOnce(source, 'run lint:md:nested', 'run lint:other:nested')],
  ['T1-MARKDOWN-009', 'policy validator removed', 'markdown', (source) => replaceOnce(source, './Validate-WorkflowPolicy.mjs', './other-validator.mjs')],
  ['T1-MARKDOWN-010', 'failure continuation', 'markdown', (source) => replaceOnce(source, '        shell: pwsh\n        working-directory:', '        shell: pwsh\n        continue-on-error: true\n        working-directory:')],
  ['T1-MARKDOWN-011', 'reviewed package hash removed', 'markdown', (source) => replaceOnce(source, "'E206CDB3562F0397E8EED7FB2C2586269A1F5335CDFF2906DA8D5E070426321E'", "'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'")],
  ['T1-MARKDOWN-012', 'reviewed lock hash altered', 'markdown', (source) => replaceOnce(source, "'277F7168AB3A4F1F7A2565DE13191D64B1572E7CB92B67B0972B3242BD4DE062'", "'377F7168AB3A4F1F7A2565DE13191D64B1572E7CB92B67B0972B3242BD4DE062'")],
  ['T1-MARKDOWN-013', 'pre-install supply gate neutralized', 'markdown', (source) => replaceOnce(source, 'if ($strPackageBefore -cne $strReviewedPackageHash -or', 'if ($false -and $strPackageBefore -cne $strReviewedPackageHash -or')],
  ['T1-BUILD-042', 'workflow token referenced outside the approved push step', 'build', (source) => replaceOnce(source, "          $ErrorActionPreference = 'Stop'\n          $arrArtifacts", "          $ErrorActionPreference = 'Stop'\n          $strToken = '${{ github.token }}'\n          $arrArtifacts")],
  ['T1-MARKDOWN-015', 'early exit before the remaining required phases', 'markdown', (source) => replaceOnce(source, '          & $strNodePath ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml\n', '          & $strNodePath ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml\n          exit 0\n')],
  ['T1-MARKDOWN-016', 'required phases reordered', 'markdown', (source) => {
    const strValidator = '          & $strNodePath ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml\n';
    const strNested = '          & $strNpmPath run lint:md:nested\n';
    return replaceOnce(replaceOnce(source, strValidator, ''), strNested, strValidator + strNested);
  }],
  // Anchored through the comment that follows it in the lint step. The
  // acquire step opens with the identical guard and now comes first, so a
  // bare anchor silently retargeted this fixture at that step's copy.
  ['T1-MARKDOWN-014', 'native-command error mapping guard removed from the lint step', 'markdown', (source) => replaceOnce(source, '          if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {\n              $PSNativeCommandUseErrorActionPreference = $false\n          }\n\n          # Fixed paths into the distribution', '          # Fixed paths into the distribution')],
  ['T1-MARKDOWN-017', 'captured phase status reset before the final check', 'markdown', (source) => replaceOnce(source, '          $strPackageFinal = (Get-FileHash', '          $intPolicyExit = 0\n          $strPackageFinal = (Get-FileHash')],
  ['T1-DEPENDABOT-001', 'duplicate updates', 'dependabot', 'version: 2\nupdates:\n  - package-ecosystem: github-actions\n    directory: /\n    schedule: { interval: weekly }\n  - package-ecosystem: github-actions\n    directory: /\n    schedule: { interval: weekly }\n'],
  ['T1-DEPENDABOT-002', 'npm update introduced early', 'dependabot', 'version: 2\nupdates:\n  - package-ecosystem: npm\n    directory: /.github/workflows\n    schedule: { interval: weekly }\n'],
  ['T1-DEPENDABOT-003', 'auto-merge key', 'dependabot', 'version: 2\nupdates:\n  - package-ecosystem: github-actions\n    directory: /\n    schedule: { interval: weekly }\n    auto-merge: true\n'],
  ['T1-MARKDOWN-018', 'npm configuration gate removed', 'markdown', (source) => replaceOnce(source, "          foreach ($strNpmConfigPath in @('.npmrc', '../.npmrc', '../../.npmrc')) {\n              if (Test-Path -LiteralPath $strNpmConfigPath) {\n                  throw 'supply: repository-controlled npm configuration is present'\n              }\n          }\n", '')],
  ['T1-MARKDOWN-019', 'npm configuration gate moved after installation', 'markdown', (source) => {
    const gate = "          foreach ($strNpmConfigPath in @('.npmrc', '../.npmrc', '../../.npmrc')) {\n              if (Test-Path -LiteralPath $strNpmConfigPath) {\n                  throw 'supply: repository-controlled npm configuration is present'\n              }\n          }\n";
    return replaceOnce(
      replaceOnce(source, gate, ''),
      '          $strPackageAfterInstall = (Get-FileHash',
      `${gate}          $strPackageAfterInstall = (Get-FileHash`,
    );
  }],
  ['T1-GENERATOR-001', 'generator body rewritten under an unchanged version marker', 'generator', (source) => `${source}\nfunction Invoke-Unreviewed { Add-Content -Path $env:GITHUB_PATH -Value '/tmp/hijack' }\n`],
  ['T1-GENERATOR-002', 'generator truncated', 'generator', (source) => source.slice(0, Math.floor(source.length / 2))],
  ['T1-MARKDOWN-020', 'lint asset digest gate removed', 'markdown', (source) => replaceOnce(source, '          if ($strLintConfigHash -cne $strReviewedLintConfigHash -or $strLintHelperHash -cne $strReviewedLintHelperHash) {\n              throw \'supply: lint configuration or helper does not match the reviewed digest\'\n          }\n', '')],
  // The generator's descendants outlive the step, so the separation between the
  // job that runs the generator and the job that publishes bytes is load-bearing
  // rather than stylistic. Each of these is a way to put repository code back in
  // the same job as the upload, which is the arrangement the split prevents.
  ['T1-BUILD-086', 'upload returned to the job that runs the generator', 'build', (source) => replaceOnce(source, "          Write-Host 'generated-artifacts: committed bytes match generator output'\n", "          Write-Host 'generated-artifacts: committed bytes match generator output'\n\n      - name: Upload verified generated artifacts\n        id: upload-generated\n        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1\n        with:\n          name: style-guide-artifacts\n          path: |\n            copilot-instructions.md\n          if-no-files-found: error\n          retention-days: 7\n          compression-level: 6\n          overwrite: false\n          include-hidden-files: false\n")],
  ['T1-BUILD-087', 'script step added to the publishing job', 'build', (source) => replaceOnce(source, '      - name: Upload verified generated artifacts\n        id: upload-generated\n', '      - name: Stage\n        id: stage\n        shell: pwsh\n        run: |\n          Write-Host staged\n\n      - name: Upload verified generated artifacts\n        id: upload-generated\n')],
  ['T1-BUILD-088', 'publishing job no longer waits for verification', 'build', (source) => replaceOnce(source, '  publish:\n    needs: verify\n', '  publish:\n')],
  ['T1-BUILD-089', 'step appended after the verification step', 'build', (source) => replaceOnce(source, "          Write-Host 'generated-artifacts: committed bytes match generator output'\n", "          Write-Host 'generated-artifacts: committed bytes match generator output'\n\n      - name: Summarize\n        id: summarize\n        shell: pwsh\n        run: |\n          Write-Host done\n")],
  // The walk decides what the verification can be made to read, so each way of
  // loosening it is a fixture rather than a comment.
  // Every branch of the walk gets a fixture. The closing digest would catch all
  // of these today, but it is re-baselined whenever a reviewed edit lands, and
  // an invariant that only the digest defends is one a legitimate re-stamp
  // drops without anyone noticing.
  // Isolating by construction: the token goes in a key the step is allowed to
  // have, whose value no other assertion pins, so the credential scan is the
  // only check that can reject it. Verified to pass the validator before the
  // scan was widened from run to the serialized step.
  ['T1-BUILD-097', 'token expanded into a permitted but unpinned step key', 'build', (source) => replaceOnce(source, '      - name: Generate and verify committed artifacts\n', '      - name: Generate and verify ${{ github.token }} committed artifacts\n')],
  // Mixed case on purpose: the point is the casing, not the context name.
  ['T1-BUILD-098', 'secrets context expanded in a casing the scan did not match', 'build', (source) => replaceOnce(source, '      - name: Generate and verify committed artifacts\n', '      - name: Generate and verify ${{ SeCrEtS.DEPLOY_KEY }} committed artifacts\n')],
  // Index syntax reaches the same token as the dot form. Enumerating spellings
  // is what produced three rounds of findings, so the expression syntax itself
  // is refused and this fixture proves the bracket form is covered without the
  // scan having to know about it.
  ['T1-BUILD-100', 'credential reached through expression index syntax', 'build', (source) => replaceOnce(source, '      - name: Generate and verify committed artifacts\n', "      - name: Generate and verify ${{ github['token'] }} committed artifacts\n")],
  // A top-level return exits the script exactly as exit would, and every
  // fragment and ordering assertion still passes.
  ['T1-BUILD-101', 'top-level return inserted after the generator', 'build', (source) => replaceOnce(source, '          if ($LASTEXITCODE -ne 0) { throw "generator: native exit $LASTEXITCODE" }\n', '          if ($LASTEXITCODE -ne 0) { throw "generator: native exit $LASTEXITCODE" }\n          return\n')],
  // The case the position-based rule could not see. Textually one line earlier
  // than T1-BUILD-101 and far worse: the script ends before the generator runs
  // at all, so nothing is generated, nothing is compared, and the step still
  // exits zero.
  ['T1-BUILD-122', 'top-level return inserted before the generator', 'build', (source) => replaceOnce(source, '          & pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1\n', '          return\n          & pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1\n')],
  // Escaped braces are literals, not block delimiters. Confirmed against
  // PowerShell: this form prints a brace and then returns from the script,
  // while a scanner that counted the escaped braces read the return as
  // depth one and let it through.
  ['T1-BUILD-123', 'top-level return hidden behind escaped braces', 'build', (source) => replaceOnce(source, '          & pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1\n', '          Write-Host `{\n          return\n          Write-Host `}\n          & pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1\n')],
  // Inert text satisfies a substring match. This wraps the approved invocation
  // in a single-quoted here-string, so the command appears verbatim in the
  // script and never executes.
  ['T1-BUILD-104', 'generator invocation present only as inert text', 'build', (source) => replaceOnce(source, '          & pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1\n', "          $strInert = '& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1'\n          $global:LASTEXITCODE = 0\n")],
  ['T1-BUILD-106', 'here-string introduced into a governed script step', 'build', (source) => replaceOnce(source, '          & pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1\n', "          $strNote = @'\n          inert\n          '@\n          & pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1\n")],
  // Every probe reports by throwing, so an empty handler around them turns each
  // verdict into a no-op while the step still succeeds.
  ['T1-BUILD-105', 'probe failures suppressed by an empty handler', 'build', (source) => replaceOnce(source, '          if ($LASTEXITCODE -ne 0) { throw "generator: native exit $LASTEXITCODE" }\n', '          if ($LASTEXITCODE -ne 0) { throw "generator: native exit $LASTEXITCODE" }\n          try {\n          } catch {\n          }\n')],
  ['T1-BUILD-102', 'origin cardinality check removed from credential cleanup', 'build', (source) => replaceOnce(source, '          $arrRemoteUrls = @(& git remote get-url --all origin)\n          if ($LASTEXITCODE -ne 0 -or $arrRemoteUrls.Count -ne 1) {\n', '          $arrRemoteUrls = @(& git remote get-url --all origin)\n          if ($LASTEXITCODE -ne 0) {\n')],
  // The step order was previously covered only as a side effect of the fixture
  // that reintroduced the upload into verify; that fixture now trips the
  // no-actions rule instead, so the ordering gets a fixture of its own.
  ['T1-BUILD-107', 'authored step appended after the generator step', 'build', (source) => replaceOnce(source, "          Write-Host 'generated-artifacts: committed bytes match generator output'\n", "          Write-Host 'generated-artifacts: committed bytes match generator output'\n\n      - name: Summarize\n        id: summarize\n        shell: pwsh\n        run: |\n          Write-Host 'done'\n")],
  // Inert-by-construction, not inert by spelling: the statement is textually
  // identical to the approved one and sits on its own line at column zero, so
  // the anchored match and every substring check are satisfied while the
  // generator never runs. Only the brace depth distinguishes them.
  ['T1-BUILD-108', 'generator invocation nested inside an unevaluated script block', 'build', (source) => replaceOnce(source, '          & pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1\n', '          $null = {\n          & pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1\n          }\n')],
  // Written before the generator, where the region slice that catches a handler
  // does not look, and effective over the whole script regardless.
  ['T1-BUILD-109', 'script-wide error trap registered ahead of the generator', 'build', (source) => replaceOnce(source, '          $arrArtifacts = @(\n', '          trap { $null = $_ }\n          $arrArtifacts = @(\n')],
  ['T1-BUILD-110', 'acquire step no longer disables native-command error mapping', 'build', (source) => replaceOnce(source, '          if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {\n              $PSNativeCommandUseErrorActionPreference = $false\n          }\n', '')],
  ['T1-BUILD-111', 'acquire step accepts an unexpected server', 'build', (source) => replaceOnce(source, "          if ($strServerUrl -cne 'https://github.com') {\n", '          if ([string]::IsNullOrEmpty($strServerUrl)) {\n')],
  ['T1-BUILD-112', 'acquire step accepts an arbitrary repository name', 'build', (source) => replaceOnce(source, "          if ($strRepository -cnotmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {\n", '          if ([string]::IsNullOrEmpty($strRepository)) {\n')],
  ['T1-BUILD-113', 'acquire step accepts a ref in place of a commit', 'build', (source) => replaceOnce(source, "          if ($strSha -cnotmatch '^[0-9a-f]{40}$') {\n", '          if ([string]::IsNullOrEmpty($strSha)) {\n')],
  ['T1-BUILD-114', 'acquire step no longer requires an empty workspace', 'build', (source) => replaceOnce(source, '          if (@([System.IO.Directory]::EnumerateFileSystemEntries($PWD.Path)).Count -ne 0) {\n              throw \'acquire: the workspace is not empty\'\n          }\n', '')],
  ['T1-BUILD-115', 'acquire step fetches a ref rather than the commit', 'build', (source) => replaceOnce(source, '          & git fetch --depth 1 --no-tags --no-recurse-submodules origin $strSha\n', '          & git fetch --depth 1 --no-tags --no-recurse-submodules origin $env:GITHUB_REF\n')],
  ['T1-BUILD-116', 'acquire step no longer proves which revision it checked out', 'build', (source) => replaceOnce(source, '          $strHead = (& git rev-parse HEAD).Trim()\n          if ($LASTEXITCODE -ne 0 -or $strHead -cne $strSha) {\n', '          $strHead = (& git rev-parse HEAD).Trim()\n          if ([string]::IsNullOrEmpty($strHead)) {\n')],
  ['T1-BUILD-117', 'credential embedded in the anonymous fetch remote', 'build', (source) => replaceOnce(source, '          & git remote add origin "$strServerUrl/$strRepository"\n', '          & git remote add origin "https://x-access-token:$env:SUPPLIED@github.com/$strRepository"\n')],
  ['T1-BUILD-118', 'acquire step drops a native status classification', 'build', (source) => replaceOnce(source, '          if ($LASTEXITCODE -ne 0) { throw "acquire: git init exited $LASTEXITCODE" }\n', "          Write-Host 'acquire: initialized'\n")],
  ['T1-BUILD-119', 'early exit prepended to the acquire step', 'build', (source) => replaceOnce(source, "          $ErrorActionPreference = 'Stop'\n", "          $ErrorActionPreference = 'Stop'\n          exit 0\n")],
  // Satisfies every named acquire assertion and changes the bytes anyway, which
  // is the case the closing digest exists for.
  ['T1-BUILD-120', 'acquire step edited without re-review', 'build', (source) => replaceOnce(source, '          Write-Host "acquire: anonymous shallow checkout of $strSha"\n', '          Write-Host "acquire: checked out $strSha"\n')],
  ['T1-BUILD-103', 'credential-free origin URL shape no longer required', 'build', (source) => replaceOnce(source, "          if ($arrRemoteUrls[0] -notmatch '^https://github\\.com/[^/@]+/[^/@]+(?:\\.git)?$') {\n", "          if ($arrRemoteUrls[0] -notmatch '^https://') {\n")],
  // Every assertion on the credential step tests for presence, which an early
  // exit leaves untouched. The control-flow rejection is ordered ahead of that
  // step's digest so this fixture exercises it rather than the backstop.
  // Anchored through the comment that follows it, for the same reason as
  // T1-BUILD-041: the acquire step opens with the identical preference line and
  // now comes first in the file.
  ['T1-BUILD-099', 'early exit prepended to the credential cleanup step', 'build', (source) => replaceOnce(source, "          $ErrorActionPreference = 'Stop'\n          # git config exits 1", "          $ErrorActionPreference = 'Stop'\n          exit 0\n          # git config exits 1")],
  ['T1-BUILD-094', 'worktree walk loses its FIFO guard', 'build', (source) => replaceOnce(source, '                              if ($objFile.Length -eq 0) {', '                              if ($false) {')],
  ['T1-BUILD-095', 'git exclusion widened to a string prefix', 'build', (source) => replaceOnce(source, '                          if (($objAttributes -band [System.IO.FileAttributes]::Directory) -ne 0) {\n                              if ($strEntry -cne $strGitDirectory) { $objPending.Push($strEntry) }', '                          if (($objAttributes -band [System.IO.FileAttributes]::Directory) -ne 0) {\n                              if (-not $strEntry.StartsWith($strGitPrefix)) { $objPending.Push($strEntry) }')],
  ['T1-BUILD-096', 'generator job regains a token scope', 'build', (source) => replaceOnce(source, '  verify:\n    runs-on: ubuntu-latest\n    permissions: {}\n', '  verify:\n    runs-on: ubuntu-latest\n    permissions:\n      contents: read\n')],
  ['T1-BUILD-091', 'worktree walk follows links again', 'build', (source) => replaceOnce(source, "                          if (($objAttributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {\n                              throw 'worktree: the working tree contains a link'\n                          }\n", '')],
  ['T1-BUILD-092', 'worktree walk recurses with AllDirectories', 'build', (source) => replaceOnce(source, '[System.IO.Directory]::EnumerateFileSystemEntries($objPending.Pop())', '[System.IO.Directory]::EnumerateFiles($objPending.Pop(), \'*\', [System.IO.SearchOption]::AllDirectories)')],
  ['T1-BUILD-093', 'worktree walk loads each file whole', 'build', (source) => replaceOnce(source, '                                  $objMap[$strRelative] = [Convert]::ToBase64String($objSha.ComputeHash($objStream))\n', '                                  $objMap[$strRelative] = [Convert]::ToBase64String($objSha.ComputeHash([System.IO.File]::ReadAllBytes($strEntry)))\n')],
  ['T1-BUILD-084', 'worktree byte comparison removed', 'build', (source) => replaceOnce(source, '          $objWorktreeAfter = Get-WorktreeFileDigests\n', '')],
  ['T1-BUILD-085', 'worktree snapshot taken after the generator', 'build', (source) => replaceOnce(source, '          $objWorktreeBefore = Get-WorktreeFileDigests\n', '')],
  ['T1-BUILD-083', 'control-surface digest framing removed', 'build', (source) => replaceOnce(source, "                      $arrLength = [System.BitConverter]::GetBytes([long]$arrComponent.Length)\n", '')],
  ['T1-BUILD-082', 'runner communication file check absent from verify', 'build', (source) => replaceOnce(source, "          foreach ($strChannel in $arrChannelPaths) {\n              if ([string]::IsNullOrEmpty($strChannel)) { throw 'runner-state: a step communication file path is unset' }\n              if ([System.IO.FileInfo]::new($strChannel).Length -ne 0) {\n                  throw 'runner-state: the generator wrote to a runner step communication file'\n              }\n          }\n", '')],
  ['T1-BUILD-081', 'probes reinherit global Git configuration', 'build', (source) => replaceOnce(source, "              $objStartInfo.Environment['GIT_CONFIG_GLOBAL'] = '/dev/null'\n", '')],
  ['T1-BUILD-080', 'generated-artifact drift tolerated again', 'build', (source) => replaceOnce(source, "          if ($objDiff.ExitCode -eq 1) {\n              throw 'generated-artifacts: committed artifacts do not match generator output. Run ./.github/workflows/Generate-StyleGuideArtifacts.ps1 and commit the four regenerated files.'\n          }\n", '')],
  ['T1-BUILD-078', 'Git control-surface digest check removed', 'build', (source) => replaceOnce(source, "          if ((Get-GitControlSurfaceDigest) -cne $strControlSurfaceBefore) {\n              throw 'git-state: the generator changed repository Git configuration or hooks'\n          }\n", '')],
  ['T1-BUILD-079', 'early exit inserted after the generator', 'build', (source) => replaceOnce(source, '          if ($LASTEXITCODE -ne 0) { throw "generator: native exit $LASTEXITCODE" }\n', '          if ($LASTEXITCODE -ne 0) { throw "generator: native exit $LASTEXITCODE" }\n          exit 0\n')],
  ['T1-BUILD-073', 'generator returned to in-session invocation', 'build', (source) => replaceOnce(source, '          & pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1\n', '          & ./.github/workflows/Generate-StyleGuideArtifacts.ps1\n')],
  ['T1-BUILD-074', 'Git resolved through a shadowable command lookup', 'build', (source) => replaceOnce(source, '              $objStartInfo.FileName = $strGitPath\n', '              $objStartInfo.FileName = @(Get-Command git -CommandType Application -ErrorAction Stop)[0].Source\n')],
  ['T1-BUILD-075', 'pinned Git path downgraded to a mutable variable', 'build', (source) => replaceOnce(source, '          New-Variable -Name strGitPath -Value $strResolvedGit -Option Constant\n', '          $strGitPath = $strResolvedGit\n')],
  ['T1-BUILD-076', 'push path added to the read-only workflow', 'build', (source) => replaceOnce(source, "          $objWorking = Invoke-GitRaw @('diff'", "          & git push origin HEAD:refs/heads/main\n          $objWorking = Invoke-GitRaw @('diff'")],
  ['T1-BUILD-077', 'repository mutation added to the read-only workflow', 'build', (source) => replaceOnce(source, "          $objWorking = Invoke-GitRaw @('diff'", "          & git add -A\n          $objWorking = Invoke-GitRaw @('diff'")],
  ['T1-MARKDOWN-021', 'captured lint status reset indirectly through Set-Variable', 'markdown', (source) => replaceOnce(source, '          $intNestedExit = $LASTEXITCODE\n', '          $intNestedExit = $LASTEXITCODE\n          Set-Variable -Name intPolicyExit -Value 0\n')],
  // The lint job runs repository-controlled code and both of its actions have
  // post steps that outlive it, so it must hold no scopes for the same reason
  // build.verify holds none.
  // The expression ban must hold in both files, not just build.yml.
  ['T1-MARKDOWN-023', 'expression reaching a credential in the lint step name', 'markdown', (source) => replaceOnce(source, '      - name: Install, validate policy, and lint both Markdown surfaces\n', "      - name: Install, validate ${{ github['token'] }} policy, and lint both Markdown surfaces\n")],
  // The step's one try exists to restore the caller's CI variable in finally.
  // Adding a catch beside it leaves every required fragment, phase order, and
  // captured status intact while a failed supply digest, install, or lint stops
  // deciding anything.
  ['T1-MARKDOWN-024', 'phase failure suppressed by a handler in the lint step', 'markdown', (source) => replaceOnce(source, '          } finally {\n', '          } catch {\n          } finally {\n')],
  ['T1-MARKDOWN-025', 'script-wide error trap registered in the lint step', 'markdown', (source) => replaceOnce(source, "          $strNodeVersion = (& $strNodePath --version).Trim()\n", "          trap { $null = $_ }\n          $strNodeVersion = (& $strNodePath --version).Trim()\n")],
  ['T1-MARKDOWN-026', 'action reintroduced into the lint job', 'markdown', (source) => replaceOnce(source, '      - name: Install, validate policy, and lint both Markdown surfaces\n', '      - name: Set up hosted Node.js\n        id: setup-node\n        uses: actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0\n        with:\n          node-version: \'24.18.1\'\n\n      - name: Install, validate policy, and lint both Markdown surfaces\n')],
  ['T1-MARKDOWN-027', 'Node archive fetched from an unreviewed location', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org/dist/v24.18.1/node-v24.18.1-linux-x64.tar.xz'\n", "          $strNodeUrl = 'https://example.invalid/node-v24.18.1-linux-x64.tar.xz'\n")],
  ['T1-MARKDOWN-028', 'reviewed Node archive digest replaced', 'markdown', (source) => replaceOnce(source, "          $strReviewedNodeSha256 = 'D6C664DF3F3F61458E8C277585571328522D705166723A7C7823A9253A4D15A0'\n", "          $strReviewedNodeSha256 = '0000000000000000000000000000000000000000000000000000000000000000'\n")],
  // The download is only as good as the check on what comes back.
  ['T1-MARKDOWN-029', 'downloaded Node archive no longer verified before use', 'markdown', (source) => replaceOnce(source, '          $strObservedNodeSha256 = (Get-FileHash -LiteralPath $strArchivePath -Algorithm SHA256).Hash\n          if ($strObservedNodeSha256 -cne $strReviewedNodeSha256) {\n              throw \'acquire: the Node archive does not match the reviewed digest\'\n          }\n', '')],
  // The network ban moved from the file to the step that runs repository code.
  ['T1-MARKDOWN-030', 'network client added to the lint step', 'markdown', (source) => replaceOnce(source, '          & $strNpmPath run lint:md\n', '          $objExtra = Invoke-WebRequest -Uri https://example.invalid/rules\n          & $strNpmPath run lint:md\n')],
  // Mutates a line no named assertion covers, so it reaches the backstop
  // rather than being answered by one of the assertions in front of it.
  ['T1-MARKDOWN-031', 'acquire step edited without re-review', 'markdown', (source) => replaceOnce(source, '          & git init --quiet .\n', '          & git init .\n')],
  // A second request fetches bytes the reviewed archive digest never covered.
  ['T1-MARKDOWN-032', 'second download appended to the acquire step', 'markdown', (source) => replaceOnce(source, '          Write-Host "acquire: revision $strSha and the reviewed Node distribution"\n', '          Write-Host "acquire: revision $strSha and the reviewed Node distribution"\n          & curl --silent --output $strNodeRoot/bin/node https://example.invalid/node\n')],
  // And one that needs no network at all, because the checkout is already on
  // disk by the time the extraction finishes.
  ['T1-MARKDOWN-033', 'extracted toolchain overwritten from the checkout', 'markdown', (source) => replaceOnce(source, '          Write-Host "acquire: revision $strSha and the reviewed Node distribution"\n', '          Write-Host "acquire: revision $strSha and the reviewed Node distribution"\n          Copy-Item -LiteralPath ./tools/node -Destination $strNodeRoot/bin/node -Force\n')],
  ['T1-MARKDOWN-022', 'lint job regains a token scope', 'markdown', (source) => replaceOnce(source, '  markdownlint:\n    runs-on: ubuntu-latest\n    permissions: {}\n', '  markdownlint:\n    runs-on: ubuntu-latest\n    permissions:\n      contents: read\n')],
  ['T1-LINTASSET-001', 'all rules disabled in the lint configuration', 'lint-asset', {
    '.markdownlint.jsonc': '{ "default": false }\n',
    'lint-nested-markdown.js': '',
  }],
  ['T1-LINTASSET-002', 'nested-fence helper reduced to a successful no-op', 'lint-asset', {
    'lint-nested-markdown.js': 'process.exit(0);\n',
  }],
  ['T1-NPMRC-001', 'npm configuration beside the governed workflows', 'npm-config', {
    '/repo': [{ name: '.github', isDirectory: () => true }],
    '/repo/.github': [{ name: 'workflows', isDirectory: () => true }],
    '/repo/.github/workflows': [{ name: '.npmrc', isDirectory: () => false }],
  }],
  ['T1-NPMRC-002', 'npm configuration at the repository root', 'npm-config', {
    '/repo': [{ name: '.npmrc', isDirectory: () => false }],
  }],
  ['T1-VERSION-001', 'missing marker', 'version', '<#\n.NOTES\nnone\n#>\nfunction X {}\n'],
  ['T1-VERSION-002', 'duplicate marker', 'version', '<#\n.NOTES\nVersion: 1.0.20260731.0\nVersion: 1.0.20260731.0\n#>\nfunction X {}\n'],
  ['T1-VERSION-003', 'decoy marker', 'version', '<#\n.NOTES\nnone\n#>\nfunction X {}\nVersion: 1.0.20260731.0\n'],
  ['T1-VERSION-004', 'leading zero', 'version', '<#\n.NOTES\nVersion: 01.0.20260731.0\n#>\nfunction X {}\n'],
  ['T1-VERSION-005', 'overflow', 'version', '<#\n.NOTES\nVersion: 2147483648.0.20260731.0\n#>\nfunction X {}\n'],
  ['T1-VERSION-006', 'impossible date', 'version', '<#\n.NOTES\nVersion: 1.0.20260229.0\n#>\nfunction X {}\n'],
  ['T1-VERSION-007', 'future valid but unexpected', 'unexpected-version', '<#\n.NOTES\nVersion: 1.0.20991231.0\n#>\nfunction X {}\n'],
  ['T1-TEXT-001', 'truncated multi-byte sequence', 'text', Buffer.from([0x61, 0x3a, 0x20, 0xe2, 0x82, 0x0a])],
  ['T1-TEXT-002', 'lone continuation byte', 'text', Buffer.from([0x61, 0x3a, 0x20, 0xa1, 0x0a])],
  ['T1-TEXT-003', 'overlong encoding', 'text', Buffer.from([0x61, 0x3a, 0x20, 0xc0, 0xaf, 0x0a])],
  ['T1-TEXT-004', 'lone surrogate', 'text', Buffer.from([0x61, 0x3a, 0x20, 0xed, 0xa0, 0x80, 0x0a])],
  ['T1-TEXT-005', 'UTF-8 BOM', 'text', Buffer.from([0xef, 0xbb, 0xbf, 0x61, 0x3a, 0x20, 0x31, 0x0a])],
  ['T1-TEXT-006', 'carriage return', 'text', Buffer.from([0x61, 0x3a, 0x20, 0x31, 0x0d, 0x0a])],
  ['T1-PACKAGE-001', 'lint script redefined as a no-op', 'package', (pkg, lock) => {
    const parsed = JSON.parse(pkg);
    parsed.scripts['lint:md'] = 'true';
    return [JSON.stringify(parsed, null, 2), lock];
  }],
  ['T1-PACKAGE-002', 'yaml parser dependency loosened', 'package', (pkg, lock) => {
    const parsed = JSON.parse(pkg);
    parsed.devDependencies.yaml = '^2.9.0';
    return [JSON.stringify(parsed, null, 2), lock];
  }],
  ['T1-PACKAGE-003', 'additional script introduced', 'package', (pkg, lock) => {
    const parsed = JSON.parse(pkg);
    parsed.scripts.postinstall = 'node unreviewed.js';
    return [JSON.stringify(parsed, null, 2), lock];
  }],
  ['T1-PACKAGE-004', 'semantically equal but altered manifest bytes', 'package', (pkg, lock) => [`${pkg}\n`, lock]],
  ['T1-PACKAGE-005', 'resolved parser integrity changed', 'package', (pkg, lock) => {
    const parsed = JSON.parse(lock);
    parsed.packages['node_modules/yaml'].integrity = `sha512-${'A'.repeat(86)}==`;
    return [pkg, JSON.stringify(parsed, null, 2)];
  }],
  ['T1-PACKAGE-006', 'lockfile root dependency drift', 'package', (pkg, lock) => {
    const parsed = JSON.parse(lock);
    parsed.packages[''].devDependencies.yaml = '^2.9.0';
    return [pkg, JSON.stringify(parsed, null, 2)];
  }],
]);

// What each fixture must be rejected BY, not merely that it was rejected. A
// mutation that trips a broader check first -- a key-set assertion, a closing
// digest, the anchor rule ahead of the merge-key rule -- would otherwise be
// counted as coverage for an assertion that never ran. Every fixture must
// appear here; an unlisted one is a harness error rather than a silent pass.
const FIXTURE_EXPECTATIONS = Object.freeze({
  "T1-YAML-001": "yaml-syntax: T1-YAML-001 contains a parser error or warning",
  "T1-YAML-002": "yaml-syntax: T1-YAML-002 contains a directive",
  "T1-YAML-003": "yaml-syntax: anchors are prohibited",
  "T1-YAML-004": "yaml-syntax: anchors are prohibited",
  "T1-YAML-005": "yaml-syntax: merge keys are prohibited",
  "T1-YAML-006": "yaml-syntax: explicit or custom tags are prohibited",
  "T1-YAML-007": "yaml-syntax: T1-YAML-007 must contain exactly one document",
  "T1-YAML-008": "yaml-syntax: mapping keys must be unique strings",
  "T1-YAML-009": "yaml-syntax: non-finite numbers are prohibited",
  "T1-YAML-010": "yaml-syntax: anchors are prohibited",
  "T1-YAML-011": "yaml-syntax: explicit or custom tags are prohibited",
  "T1-YAML-012": "yaml-syntax: explicit or custom tags are prohibited",
  "T1-YAML-013": "yaml-syntax: anchors are prohibited",
  "T1-BUILD-001": "action-policy: build.publish.checkout uses the wrong action repository or SHA",
  "T1-BUILD-002": "action-policy: build.publish.checkout uses the wrong action repository or SHA",
  "T1-BUILD-003": "action-policy: build.publish.checkout uses the wrong action repository or SHA",
  "T1-BUILD-004": "policy: external action multiset differs from the locked policy",
  "T1-BUILD-005": "policy: build.publish step order differs from the locked policy",
  "T1-BUILD-006": "schema: build.publish.upload-generated has missing or extra keys",
  "T1-BUILD-007": "action-policy: build.publish.upload-generated uses the wrong action repository or SHA",
  "T1-BUILD-008": "policy: build.publish.checkout.with differs from the locked policy",
  "T1-BUILD-009": "policy: build.publish.checkout.with differs from the locked policy",
  "T1-BUILD-010": "policy: build.publish.checkout.with differs from the locked policy",
  "T1-BUILD-011": "policy: build workflow permissions differs from the locked policy",
  "T1-BUILD-012": "policy: build.verify permissions differs from the locked policy",
  "T1-BUILD-014": "schema: build jobs has missing or extra keys",
  "T1-BUILD-015": "schema: build jobs has missing or extra keys",
  "T1-BUILD-016": "schema: build.verify has missing or extra keys",
  "T1-BUILD-017": "schema: build.verify has missing or extra keys",
  "T1-BUILD-018": "schema: build.verify has missing or extra keys",
  "T1-BUILD-024": "schema: build.verify has missing or extra keys",
  "T1-BUILD-090": "schema: build.publish.upload-generated has missing or extra keys",
  "T1-BUILD-027": "policy: build.publish.upload-generated.with differs from the locked policy",
  "T1-BUILD-028": "policy: build.publish.upload-generated.with differs from the locked policy",
  "T1-BUILD-029": "policy: build.publish step order differs from the locked policy",
  "T1-BUILD-031": "policy: build.publish.checkout.with differs from the locked policy",
  "T1-BUILD-032": "policy: build triggers differs from the locked policy",
  "T1-BUILD-033": "policy: build triggers differs from the locked policy",
  "T1-BUILD-034": "action-policy: build.publish.checkout uses the wrong action repository or SHA",
  "T1-BUILD-035": "action-policy: build.publish.checkout uses the wrong action repository or SHA",
  "T1-BUILD-036": "credential-policy: build.verify.verify-checkout-credentials no longer asserts no local credential helper",
  "T1-BUILD-037": "credential-policy: build.verify.verify-checkout-credentials no longer asserts no persisted HTTP authorization",
  "T1-BUILD-038": "credential-policy: verify.generate-and-verify expands an unapproved credential",
  "T1-BUILD-040": "schema: build.verify.generate-and-verify has missing or extra keys",
  "T1-BUILD-041": "credential-policy: build.verify.verify-checkout-credentials no longer asserts native-command error mapping is disabled",
  "T1-BUILD-050": "git-policy: build.verify no longer drains both Git streams concurrently",
  "T1-BUILD-053": "git-policy: build.verify does not pin the Git executable before repository code runs",
  "T1-BUILD-054": "git-policy: build.verify does not pin the Git executable before repository code runs",
  "T1-BUILD-061": "git-policy: build.verify resolves Git through a shadowable command lookup",
  "T1-MARKDOWN-005": "markdown-policy: required phase is missing: ci --ignore-scripts --no-audit --no-fund",
  "T1-MARKDOWN-006": "markdown-policy: required phase is missing: ci --ignore-scripts --no-audit --no-fund",
  "T1-MARKDOWN-007": "markdown-policy: required phases are out of order at: run lint:md\n",
  "T1-MARKDOWN-008": "markdown-policy: required phase is missing: run lint:md:nested",
  "T1-MARKDOWN-009": "markdown-policy: required phase is missing: ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml",
  "T1-MARKDOWN-010": "schema: markdown.validate-and-lint has missing or extra keys",
  "T1-MARKDOWN-011": "markdown-policy: required phase is missing: E206CDB3562F0397E8EED7FB2C2586269A1F5335CDFF2906DA8D5E070426321E",
  "T1-MARKDOWN-012": "markdown-policy: required phase is missing: 277F7168AB3A4F1F7A2565DE13191D64B1572E7CB92B67B0972B3242BD4DE062",
  "T1-MARKDOWN-013": "markdown-policy: required phase is missing: if ($strPackageBefore -cne $strReviewedPackageHash -or $strLockBefore -cne $strReviewedLockHash)",
  "T1-BUILD-042": "credential-policy: verify.generate-and-verify expands an unapproved credential",
  "T1-MARKDOWN-015": "markdown-policy: validation script adds control flow that can bypass a required phase",
  "T1-MARKDOWN-016": "markdown-policy: required phases are out of order at: run lint:md\n",
  "T1-MARKDOWN-014": "markdown-policy: required phase is missing: if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {",
  "T1-MARKDOWN-017": "markdown-policy: captured phase status intPolicyExit is not assigned exactly once",
  "T1-DEPENDABOT-001": "policy: Dependabot configuration differs from the locked policy",
  "T1-DEPENDABOT-002": "policy: Dependabot configuration differs from the locked policy",
  "T1-DEPENDABOT-003": "policy: Dependabot configuration differs from the locked policy",
  "T1-MARKDOWN-018": "markdown-policy: required phase is missing: @('.npmrc', '../.npmrc', '../../.npmrc')",
  "T1-MARKDOWN-019": "markdown-policy: required phases are out of order at: supply: lint configuration or helper does not match the reviewed digest",
  "T1-GENERATOR-001": "supply-policy: generator does not match its reviewed digest",
  "T1-GENERATOR-002": "supply-policy: generator does not match its reviewed digest",
  "T1-MARKDOWN-020": "markdown-policy: required phase is missing: supply: lint configuration or helper does not match the reviewed digest",
  "T1-BUILD-086": "isolation-policy: build.verify.upload-generated uses an action",
  "T1-BUILD-087": "policy: build.publish step order differs from the locked policy",
  "T1-BUILD-088": "schema: build.publish has missing or extra keys",
  "T1-BUILD-089": "policy: build.verify step order differs from the locked policy",
  "T1-BUILD-097": "credential-policy: verify.generate-and-verify expands an unapproved credential",
  "T1-BUILD-098": "credential-policy: verify.generate-and-verify expands an unapproved credential",
  "T1-BUILD-100": "credential-policy: verify.generate-and-verify contains a workflow expression",
  "T1-BUILD-101": "side-effect-policy: build.verify returns from the script at top level",
  "T1-BUILD-122": "side-effect-policy: build.verify returns from the script at top level",
  "T1-BUILD-123": "side-effect-policy: build.verify returns from the script at top level",
  "T1-BUILD-104": "side-effect-policy: the generator is not invoked exactly once as a statement",
  "T1-BUILD-106": "side-effect-policy: verify.generate-and-verify uses a here-string or block comment",
  "T1-BUILD-105": "side-effect-policy: build.verify can suppress a probe failure after the generator runs",
  "T1-BUILD-102": "credential-policy: build.verify.verify-checkout-credentials no longer asserts exactly one origin URL",
  "T1-BUILD-103": "credential-policy: build.verify.verify-checkout-credentials no longer asserts a credential-free GitHub HTTPS origin",
  "T1-BUILD-099": "credential-policy: build.verify.verify-checkout-credentials adds control flow that can bypass a required assertion",
  "T1-BUILD-094": "side-effect-policy: build.verify worktree walk lost its FIFO guard or its exact .git exclusion",
  "T1-BUILD-095": "side-effect-policy: build.verify worktree walk lost its FIFO guard or its exact .git exclusion",
  "T1-BUILD-096": "policy: build.verify permissions differs from the locked policy",
  "T1-BUILD-091": "side-effect-policy: build.verify worktree walk can follow a link or read a file whole",
  "T1-BUILD-092": "side-effect-policy: build.verify worktree walk can follow a link or read a file whole",
  "T1-BUILD-093": "side-effect-policy: build.verify worktree walk can follow a link or read a file whole",
  "T1-BUILD-084": "side-effect-policy: build.verify does not bracket the generator with a worktree byte comparison",
  "T1-BUILD-085": "side-effect-policy: build.verify does not bracket the generator with a worktree byte comparison",
  "T1-BUILD-083": "git-policy: the Git control-surface digest does not frame its components unambiguously",
  "T1-BUILD-082": "side-effect-policy: build.verify does not assert the runner step communication files are empty",
  "T1-BUILD-081": "git-policy: build.verify probes inherit system or global Git configuration",
  "T1-BUILD-080": "side-effect-policy: build.verify tolerates generated-artifact drift",
  "T1-BUILD-078": "git-policy: build.verify does not bracket the generator with a Git control-surface digest",
  "T1-BUILD-079": "side-effect-policy: build.verify adds control flow that can bypass a required probe",
  "T1-BUILD-073": "side-effect-policy: the generator is invoked in-session",
  "T1-BUILD-074": "git-policy: build.verify does not pin the Git executable before repository code runs",
  "T1-BUILD-075": "git-policy: build.verify does not pin the Git executable before repository code runs",
  "T1-BUILD-076": "side-effect-policy: verify.generate-and-verify adds a push path to a read-only workflow",
  "T1-BUILD-077": "side-effect-policy: verify.generate-and-verify adds a repository mutation to a read-only workflow",
  "T1-MARKDOWN-021": "markdown-policy: Markdown validation script does not match its reviewed digest",
  "T1-MARKDOWN-023": "markdown-policy: markdown.validate-and-lint contains a workflow expression",
  "T1-MARKDOWN-022": "policy: Markdown job permissions differs from the locked policy",
  "T1-LINTASSET-001": "supply-policy: .markdownlint.jsonc does not match its reviewed digest",
  "T1-LINTASSET-002": "supply-policy: lint-nested-markdown.js does not match its reviewed digest",
  "T1-NPMRC-001": "supply-policy: repository-controlled npm configuration is present: .github/workflows/.npmrc",
  "T1-NPMRC-002": "supply-policy: repository-controlled npm configuration is present: .npmrc",
  "T1-VERSION-001": "invalid-version: exactly one marker must occur in script help before the first function",
  "T1-VERSION-002": "invalid-version: exactly one marker must occur in script help before the first function",
  "T1-VERSION-003": "invalid-version: exactly one marker must occur in script help before the first function",
  "T1-VERSION-004": "invalid-version: a component has a leading zero",
  "T1-VERSION-005": "invalid-version: a component is out of range",
  "T1-VERSION-006": "invalid-version: build is not a real Gregorian date",
  "T1-VERSION-007": "unexpected-version: valid generator version does not match the trusted reviewed version",
  "T1-TEXT-001": "text-policy: T1-TEXT-001 is not well-formed UTF-8",
  "T1-TEXT-002": "text-policy: T1-TEXT-002 is not well-formed UTF-8",
  "T1-TEXT-003": "text-policy: T1-TEXT-003 is not well-formed UTF-8",
  "T1-TEXT-004": "text-policy: T1-TEXT-004 is not well-formed UTF-8",
  "T1-TEXT-005": "text-policy: T1-TEXT-005 has a UTF-8 BOM",
  "T1-TEXT-006": "text-policy: T1-TEXT-006 contains a carriage return",
  "T1-PACKAGE-001": "policy: package.json scripts differs from the locked policy",
  "T1-PACKAGE-002": "policy: package.json devDependencies differs from the locked policy",
  "T1-PACKAGE-003": "policy: package.json scripts differs from the locked policy",
  "T1-PACKAGE-004": "supply-policy: package.json does not match its reviewed digest",
  "T1-BUILD-107": "policy: build.verify step order differs from the locked policy",
  "T1-BUILD-108": "side-effect-policy: the generator invocation is nested inside a block",
  "T1-BUILD-109": "side-effect-policy: verify.generate-and-verify registers a script-wide error trap",
  "T1-BUILD-110": "acquire-policy: build.verify.acquire no longer asserts native-command error mapping is disabled",
  "T1-BUILD-111": "acquire-policy: build.verify.acquire no longer asserts the server the runner named",
  "T1-BUILD-112": "acquire-policy: build.verify.acquire no longer asserts a plain owner/name repository",
  "T1-BUILD-113": "acquire-policy: build.verify.acquire no longer asserts a full commit hash rather than a ref",
  "T1-BUILD-114": "acquire-policy: build.verify.acquire no longer asserts an empty workspace before fetching",
  "T1-BUILD-115": "acquire-policy: build.verify.acquire no longer asserts a fetch of the commit itself",
  "T1-BUILD-116": "acquire-policy: build.verify.acquire no longer asserts that the checked out revision is the triggering revision",
  "T1-BUILD-117": "acquire-policy: build.verify.acquire introduces a credential into an anonymous fetch",
  "T1-BUILD-118": "acquire-policy: build.verify.acquire native-status classification count changed",
  "T1-BUILD-119": "acquire-policy: build.verify.acquire adds control flow that can bypass a required assertion",
  "T1-BUILD-120": "acquire-policy: build.verify.acquire script does not match its reviewed digest",
  "T1-MARKDOWN-024": "markdown-policy: markdown.validate-and-lint can suppress a phase failure",
  "T1-MARKDOWN-025": "markdown-policy: markdown.validate-and-lint can suppress a phase failure",
  "T1-MARKDOWN-026": "isolation-policy: markdown.setup-node uses an action",
  "T1-MARKDOWN-027": "acquire-policy: markdown.acquire no longer asserts the exact reviewed Node archive",
  "T1-MARKDOWN-028": "acquire-policy: markdown.acquire no longer asserts the reviewed Node archive digest",
  "T1-MARKDOWN-029": "acquire-policy: markdown.acquire no longer asserts the download, its verification, and the extraction as one uninterrupted block",
  "T1-MARKDOWN-030": "markdown-policy: markdown.validate-and-lint adds a network client",
  "T1-MARKDOWN-031": "acquire-policy: markdown.acquire script does not match its reviewed digest",
  "T1-MARKDOWN-032": "acquire-policy: markdown.acquire network request count changed",
  "T1-MARKDOWN-033": "acquire-policy: markdown.acquire does not end at the verified extraction",
  "T1-PACKAGE-005": "supply-policy: resolved yaml parser integrity is not the reviewed value",
  "T1-PACKAGE-006": "policy: lockfile root devDependencies differs from the locked policy",
});

function runNegativeFixtures(buildSource, markdownSource, packageSource, lockSource, generatorSource) {
  const ids = new Set();
  const consumed = new Set();
  for (const [id, description, kind, fixture] of FIXTURE_INVENTORY) {
    if (ids.has(id)) reject('fixture-harness', `duplicate fixture ID ${id}`);
    ids.add(id);
    let rejected = false;
    let message = '';
    try {
      if (kind === 'yaml') {
        parseStrictYaml(fixture, id);
      } else if (kind === 'build') {
        const source = fixture(buildSource);
        validateBuildPolicy(parseStrictYaml(source, id), source);
      } else if (kind === 'markdown') {
        const source = fixture(markdownSource);
        validateMarkdownPolicy(parseStrictYaml(source, id), source);
      } else if (kind === 'dependabot') {
        validateDependabotPolicy(parseStrictYaml(fixture, id));
      } else if (kind === 'version') {
        parseGeneratorVersion(fixture, EXPECTED_VERSION);
      } else if (kind === 'unexpected-version') {
        parseGeneratorVersion(fixture, EXPECTED_VERSION);
      } else if (kind === 'text') {
        decodeStrictText(fixture, id);
      } else if (kind === 'package') {
        validatePackagePolicy(...fixture(packageSource, lockSource));
      } else if (kind === 'generator') {
        validateGeneratorPolicy(fixture(generatorSource));
      } else if (kind === 'lint-asset') {
        validateLintAssetPolicy(fixture);
      } else if (kind === 'npm-config') {
        assertNoNpmConfiguration('/repo', '/repo', (directory) => fixture[directory] ?? []);
      } else {
        reject('fixture-harness', `unknown fixture kind for ${id}`);
      }
    } catch (error) {
      // A fixture-harness error means the mutation was never built — typically a
      // replaceOnce anchor gone stale after a refactor. Counting that as a
      // rejection would report full coverage for a fixture that tested nothing
      // and let the assertion it guards regress unnoticed, so it propagates.
      if (error instanceof PolicyError && error.category !== 'fixture-harness') {
        rejected = true;
        message = error.message;
      } else throw error;
    }
    if (!rejected) reject('fixture-harness', `${id} (${description}) was not rejected`);
    consumed.add(id);
    // Rejection alone proves nothing about which assertion did the rejecting. A
    // mutation that trips an earlier, broader check -- a key-set assertion, a
    // closing digest, the anchor rule ahead of the merge-key rule -- is counted
    // as coverage for an assertion that never ran, and the count then overstates
    // what the suite defends. Three fixtures were in that state when this was
    // added. Naming the expected rejection makes the claim checkable, and an
    // unlisted fixture is an error rather than a silent pass.
    const expected = FIXTURE_EXPECTATIONS[id];
    if (typeof expected !== 'string') {
      reject('fixture-harness', `${id} (${description}) declares no expected rejection`);
    }
    if (!message.includes(expected)) {
      reject('fixture-harness', `${id} (${description}) was rejected by the wrong assertion: ${message}`);
    }
  }
  // The lookup above only runs for fixtures that exist, so an expectation whose
  // fixture was deleted or renamed is never examined: coverage falls, the count
  // falls with it, and nothing objects -- the inventory's append-only contract
  // is a convention rather than something the harness can see. No fixed count
  // is enforced either, and pinning one would only move the problem, since the
  // number is meant to grow. Requiring the two sets to agree exactly is what
  // makes a lost fixture a failure: every expectation must be consumed, so an
  // orphan is as loud as a fixture with no expectation.
  for (const id of Object.keys(FIXTURE_EXPECTATIONS)) {
    if (!consumed.has(id)) {
      reject('fixture-harness', `expectation ${id} has no fixture; coverage was removed`);
    }
  }
  return ids.size;
}

// Buffer.prototype.toString('utf8') substitutes U+FFFD for malformed input, so
// the validated character stream could differ from the committed bytes that
// GitHub and PowerShell consume, and distinct malformed byte sequences could
// collapse to one policy digest. Decoding fatally keeps bytes and characters
// in exact correspondence.
export function decodeStrictText(bytes, label) {
  if (bytes.subarray(0, 3).equals(Buffer.from([0xef, 0xbb, 0xbf]))) reject('text-policy', `${label} has a UTF-8 BOM`);
  if (bytes.includes(0x0d)) reject('text-policy', `${label} contains a carriage return`);
  let text;
  try {
    text = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(bytes);
  } catch {
    reject('text-policy', `${label} is not well-formed UTF-8`);
  }
  if (!Buffer.from(text, 'utf8').equals(bytes)) reject('text-policy', `${label} does not round-trip its committed bytes`);
  return text;
}

function readOrdinaryText(path, label) {
  const stat = lstatSync(path);
  if (!stat.isFile() || stat.isSymbolicLink()) reject('filesystem-policy', `${label} is not an ordinary file`);
  if (realpathSync(path) !== resolve(path)) reject('filesystem-policy', `${label} resolves through an alias`);
  return decodeStrictText(readFileSync(path), label);
}

// Concatenating sources into one hash is ambiguous: moving a trailing byte from
// one file onto the front of the next can leave both files valid and produce an
// identical combined stream, so the digest would not move even though two
// committed inputs changed. Framing each contribution with its label and exact
// byte length makes the boundaries unambiguous.
// npm resolves its project configuration from .npmrc before it runs a command,
// and script-shell there replaces the interpreter for every npm run — so a lint
// script can be echoed to the log, exit zero, and never reach a linter. That
// file is covered by no reviewed digest and named by no governed workflow, which
// makes an absence rule the only form the policy can take. node_modules is not
// tracked and its packages may legitimately carry .npmrc, so it is skipped.
// The directory reader is a parameter so the walk is reachable from the fixture
// harness. Asserting an absence against the live checkout can only ever observe
// the passing case, which is no evidence that the rule fires.
export function assertNoNpmConfiguration(directory, repositoryRoot, readDirectory = readdirSync) {
  for (const entry of readDirectory(directory, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'node_modules') continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      assertNoNpmConfiguration(path, repositoryRoot, readDirectory);
    } else if (entry.name === '.npmrc') {
      reject('supply-policy', `repository-controlled npm configuration is present: ${path.slice(repositoryRoot.length + 1)}`);
    }
  }
}

export function validateLintAssetPolicy(assets) {
  for (const [label, source] of Object.entries(assets)) {
    if (createHash('sha256').update(source, 'utf8').digest('hex') !== REVIEWED_LINT_DIGESTS[label]) {
      reject('supply-policy', `${label} does not match its reviewed digest`);
    }
  }
}

// Version first, then bytes: an intentional edit that forgot the version bump
// should say so, rather than reporting only that a hash moved.
export function validateGeneratorPolicy(source) {
  parseGeneratorVersion(source, EXPECTED_VERSION);
  if (createHash('sha256').update(source, 'utf8').digest('hex') !== REVIEWED_GENERATOR_DIGEST) {
    reject('supply-policy', 'generator does not match its reviewed digest');
  }
}

function foldPolicyInput(hash, label, source) {
  const bytes = Buffer.from(source, 'utf8');
  hash.update(`${label}:${bytes.length}\n`, 'utf8');
  hash.update(bytes);
}

export function validateRepositoryPolicy(buildPath, markdownPath) {
  if (basename(buildPath) !== 'build.yml' || basename(markdownPath) !== 'markdownlint.yml') {
    reject('cli', 'arguments must be build.yml then markdownlint.yml');
  }
  const workflowDirectory = dirname(resolve(buildPath));
  if (dirname(resolve(markdownPath)) !== workflowDirectory) reject('cli', 'workflow arguments must share one directory');
  const workflowFiles = readdirSync(workflowDirectory)
    .filter((name) => /\.ya?ml$/u.test(name))
    .sort();
  assertEqual(workflowFiles, ['build.yml', 'markdownlint.yml'], 'tracked workflow file set');

  const buildSource = readOrdinaryText(resolve(buildPath), 'build.yml');
  const markdownSource = readOrdinaryText(resolve(markdownPath), 'markdownlint.yml');
  validateBuildPolicy(parseStrictYaml(buildSource, 'build.yml'), buildSource);
  validateMarkdownPolicy(parseStrictYaml(markdownSource, 'markdownlint.yml'), markdownSource);

  const githubDirectory = dirname(workflowDirectory);
  const repositoryRoot = dirname(githubDirectory);
  const dependabotSource = readOrdinaryText(join(githubDirectory, 'dependabot.yml'), 'dependabot.yml');
  validateDependabotPolicy(parseStrictYaml(dependabotSource, 'dependabot.yml'));
  const attributes = readOrdinaryText(join(repositoryRoot, '.gitattributes'), '.gitattributes');
  if (attributes !== '* text=auto eol=lf\n') reject('text-policy', '.gitattributes does not have exact content');
  const generatorSource = readOrdinaryText(join(workflowDirectory, 'Generate-StyleGuideArtifacts.ps1'), 'generator');
  validateGeneratorPolicy(generatorSource);
  const packageSource = readOrdinaryText(join(workflowDirectory, 'package.json'), 'package.json');
  const lockSource = readOrdinaryText(join(workflowDirectory, 'package-lock.json'), 'package-lock.json');
  validatePackagePolicy(packageSource, lockSource);
  assertNoNpmConfiguration(repositoryRoot, repositoryRoot);
  // The digest covered every governed input but not the implementation defining
  // what those inputs were checked against, so removing an assertion here left
  // the reported hash unchanged. Evidence for a policy run has to bind the rules
  // as well as the material.
  const lintAssets = Object.fromEntries(Object.keys(REVIEWED_LINT_DIGESTS).map(
    (name) => [name, readOrdinaryText(join(workflowDirectory, name), name)],
  ));
  validateLintAssetPolicy(lintAssets);
  const validatorSource = readOrdinaryText(join(workflowDirectory, 'Validate-WorkflowPolicy.mjs'), 'validator');

  const fixtureCount = runNegativeFixtures(buildSource, markdownSource, packageSource, lockSource, generatorSource);
  return Object.freeze({
    fixtureCount,
    generatorVersion: EXPECTED_VERSION,
    // Every input this function validates, folded in validation order, so the
    // reported digest is complete evidence for the policy that was checked. The
    // generator matters most here: its bytes can change substantially while its
    // version marker stays fixed, so omitting it left the digest unmoved by a
    // real change to validated content.
    policyDigest: (() => {
      const hash = createHash('sha256');
      for (const [label, source] of [
        ['build.yml', buildSource],
        ['markdownlint.yml', markdownSource],
        ['dependabot.yml', dependabotSource],
        ['.gitattributes', attributes],
        ['generator', generatorSource],
        ['package.json', packageSource],
        ['package-lock.json', lockSource],
        ...Object.entries(lintAssets),
        ['validator', validatorSource],
      ]) {
        foldPolicyInput(hash, label, source);
      }
      return hash.digest('hex');
    })(),
  });
}

function main(argv) {
  if (argv.length !== 2) reject('cli', 'expected exactly two workflow arguments');
  const result = validateRepositoryPolicy(argv[0], argv[1]);
  process.stdout.write(`workflow-policy: pass; fixtures=${result.fixtureCount}; version=${result.generatorVersion}; digest=${result.policyDigest}\n`);
}

if (import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    if (error instanceof PolicyError) {
      process.stderr.write(`${error.message}\n`);
      process.exitCode = 1;
    } else {
      process.stderr.write('workflow-policy: unexpected validator failure\n');
      process.exitCode = 1;
    }
  }
}
