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

const SETUP_NODE_INPUTS = Object.freeze({
  'node-version': '24.18.1',
  'check-latest': false,
  'package-manager-cache': false,
  token: '${{ github.token }}',
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
const REVIEWED_VALIDATION_STEP_DIGEST = 'e4157f6e13dc2863b2339ba16b8fbe73a380d6c2edb0f418c6604aef66aa1c01';

// The verify step runs repository-controlled code and then draws a conclusion
// from Git probes. Its required fragments and their ordering are asserted
// individually below, but an inserted early exit satisfies every one of them
// while skipping the probes entirely, and the upload action then publishes
// artifacts labelled verified. The same backstop the Markdown step and the
// former push step carry applies here for the same reason.
const REVIEWED_VERIFY_STEP_DIGEST = '238b85b3f36cc5bc4a4b8a023342617be23c60cdc36060f083541c7b02f6a360';

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

export function validateBuildPolicy(workflow, source) {
  assertKeys(workflow, ['name', 'on', 'permissions', 'jobs'], 'build root');
  if (workflow.name !== 'Build Style Guide Artifacts') reject('policy', 'build workflow name is not locked');
  assertEqual(workflow.on, EXPECTED_TRIGGER, 'build triggers');
  assertEqual(workflow.permissions, { contents: 'read' }, 'build workflow permissions');
  assertKeys(workflow.jobs, ['verify', 'publish'], 'build jobs');

  const verify = workflow.jobs.verify;
  assertKeys(verify, ['runs-on', 'permissions', 'steps'], 'build.verify');
  if (verify['runs-on'] !== 'ubuntu-latest') reject('policy', 'build.verify runner changed');
  // No scopes, not contents: read. This is the job that runs the generator, and
  // actions/checkout registers an always-running post action that receives the
  // job token as an input -- a descendant can poison that process through the
  // step communication files after every in-step assertion has run. The write
  // cannot be prevented from inside the step, so the token it would capture is
  // given nothing to capture.
  assertEqual(verify.permissions, {}, 'build.verify permissions');
  const verifyIds = verify.steps.map((step) => step?.id);
  // generate-and-verify is last on purpose. Anything appended after it runs
  // with whatever the generator's surviving descendants left behind, including
  // values they appended to the runner's step communication files once the
  // in-step emptiness assertion could no longer observe them.
  assertEqual(verifyIds, ['checkout', 'verify-checkout-credentials', 'generate-and-verify'], 'build.verify step order');
  assertActionStep(findStep(verify, 'checkout', 'build.verify'), 'build.verify.checkout', ACTIONS.checkout, CHECKOUT_INPUTS);
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
    // Scan the whole step, not just run or env values: a credential reaches the
    // script through any step key just as effectively as through script text.
    const serialized = JSON.stringify(step);
    if (/secrets\./u.test(serialized) || /GITHUB_TOKEN/u.test(serialized) || /github\.token/iu.test(run)) {
      reject('credential-policy', `${jobId}.${id} expands an unapproved credential`);
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
  if (!generateStep.run.includes('& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1')) {
    reject('side-effect-policy', 'the generator no longer runs across a process boundary');
  }
  if (/^\s*& \.\/\.github\/workflows\/Generate-StyleGuideArtifacts\.ps1\s*$/mu.test(generateStep.run)) {
    reject('side-effect-policy', 'the generator is invoked in-session');
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
  if (generateStep.run.indexOf('New-Variable -Name strGitPath') > generateStep.run.indexOf('& pwsh -NoProfile')) {
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
      generateStep.run.indexOf('$strControlSurfaceBefore = Get-GitControlSurfaceDigest') > generateStep.run.indexOf('& pwsh -NoProfile') ||
      generateStep.run.indexOf('git-state: the generator changed repository Git configuration or hooks') < generateStep.run.indexOf('& pwsh -NoProfile')) {
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
      generateStep.run.indexOf('$objWorktreeBefore = Get-WorktreeFileDigests') > generateStep.run.indexOf('& pwsh -NoProfile') ||
      generateStep.run.indexOf('$objWorktreeAfter = Get-WorktreeFileDigests') < generateStep.run.indexOf('& pwsh -NoProfile')) {
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
      generateStep.run.indexOf('New-Variable -Name arrChannelPaths') > generateStep.run.indexOf('& pwsh -NoProfile') ||
      generateStep.run.indexOf('runner-state: the generator wrote to a runner step communication file') < generateStep.run.indexOf('& pwsh -NoProfile')) {
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
  // Closing backstop, mirroring the Markdown validation step. The assertions
  // above name what changed; this pins everything they do not model.
  if (createHash('sha256').update(generateStep.run, 'utf8').digest('hex') !== REVIEWED_VERIFY_STEP_DIGEST) {
    reject('side-effect-policy', 'build.verify script does not match its reviewed digest');
  }
  // Redirected stdout and stderr must be drained concurrently. Reading either to
  // completion before the other deadlocks once the child fills the unread pipe,
  // which hangs the step until the Actions timeout instead of failing.
  if (!generateStep.run.includes('$objProcess.StandardOutput.BaseStream.CopyToAsync($objOutput)') ||
      !generateStep.run.includes('$objProcess.StandardError.ReadToEndAsync()')) {
    reject('git-policy', 'build.verify no longer drains both Git streams concurrently');
  }

  // Two checkouts, one per job: verify checks out to run the generator against
  // the triggering revision, publish checks out to read that revision's bytes
  // without the generator ever having run on that machine. Counting them is
  // what keeps a third, unreviewed action from appearing.
  validateActionMultiset(source, [ACTIONS.checkout, ACTIONS.checkout, ACTIONS.uploadArtifact]);
}

function validateCredentialCleanupStep(step, label) {
  assertKeys(step, ['name', 'id', 'shell', 'run'], label);
  if (step.name !== 'Verify checkout credential cleanup' || step.shell !== 'pwsh') {
    reject('credential-policy', `${label} execution contract changed`);
  }
  const requiredSequences = [
    // Both accepted absent-key statuses below are only reachable when native
    // commands are not mapped onto $ErrorActionPreference.
    'if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {\n' +
      '    $PSNativeCommandUseErrorActionPreference = $false\n' +
      '}',
    '$arrHelpers = @(& git config --local --get-all credential.helper)\n' +
      '$intHelperExit = $LASTEXITCODE\n' +
      '$global:LASTEXITCODE = 0\n' +
      'if (($intHelperExit -ne 0 -and $intHelperExit -ne 1) -or $arrHelpers.Count -ne 0)',
    "$arrAuthorizationKeys = @(& git config --local --name-only --get-regexp '^http\\..*\\.extraheader$')\n" +
      '$intAuthorizationExit = $LASTEXITCODE\n' +
      '$global:LASTEXITCODE = 0\n' +
      'if (($intAuthorizationExit -ne 0 -and $intAuthorizationExit -ne 1) -or $arrAuthorizationKeys.Count -ne 0)',
  ];
  for (const sequence of requiredSequences) {
    if (!step.run.includes(sequence)) {
      reject('credential-policy', `${label} no longer normalizes an accepted absent-setting status`);
    }
  }
  const normalizationCount = step.run.match(/^\$global:LASTEXITCODE = 0$/gmu)?.length ?? 0;
  if (normalizationCount !== 2) {
    reject('credential-policy', `${label} native-status normalization count changed`);
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
  assertEqual(job.permissions, { contents: 'read' }, 'Markdown job permissions');
  assertEqual(job.steps.map((step) => step?.id), ['checkout', 'setup-node', 'validate-and-lint'], 'Markdown step order');
  assertActionStep(findStep(job, 'checkout', 'markdown.markdownlint'), 'markdown.checkout', ACTIONS.checkout, CHECKOUT_INPUTS);
  assertActionStep(findStep(job, 'setup-node', 'markdown.markdownlint'), 'markdown.setup-node', ACTIONS.setupNode, SETUP_NODE_INPUTS);

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
  if (/continue-on-error|secrets\./iu.test(source) || NETWORK_CLIENT.test(source)) {
    reject('markdown-policy', 'Markdown workflow weakens failure, credential, or network policy');
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

  validateActionMultiset(source, [ACTIONS.checkout, ACTIONS.setupNode]);
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
  ['T1-YAML-004', 'alias', 'yaml', 'a: &x 1\nb: *x\n'],
  ['T1-YAML-005', 'merge key', 'yaml', 'a: &x { b: 1 }\nc: { <<: *x }\n'],
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
  ['T1-BUILD-041', 'native-command error mapping guard removed', 'build', (source) => replaceOnce(source, '          if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {\n              $PSNativeCommandUseErrorActionPreference = $false\n          }\n', '')],
  ['T1-BUILD-050', 'sequential Git stream reads restored', 'build', (source) => replaceOnce(source, '                  $objCopyTask = $objProcess.StandardOutput.BaseStream.CopyToAsync($objOutput)\n                  $objErrorTask = $objProcess.StandardError.ReadToEndAsync()\n                  $objCopyTask.GetAwaiter().GetResult()\n                  $strError = $objErrorTask.GetAwaiter().GetResult()\n', '                  $objProcess.StandardOutput.BaseStream.CopyTo($objOutput)\n                  $strError = $objProcess.StandardError.ReadToEnd()\n')],
  ['T1-BUILD-053', 'credentialed executable resolved through PATH', 'build', (source) => replaceOnce(source, '              $objStartInfo.FileName = $strGitPath\n', '              $arrGitCommands = @(Get-Command git -CommandType Application -ErrorAction Stop)\n              $objStartInfo.FileName = $arrGitCommands[0].Source\n')],
  ['T1-BUILD-054', 'trusted Git path list widened', 'build', (source) => replaceOnce(source, "@('/usr/bin/git', '/bin/git')", "@($env:RUNNER_TEMP + '/git', '/usr/bin/git')")],
  ['T1-BUILD-061', 'PATH lookup reintroduced beside the pinned path', 'build', (source) => replaceOnce(source, '              $objStartInfo.FileName = $strGitPath\n', '              $arrFallback = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue)\n              $objStartInfo.FileName = $strGitPath\n')],
  ['T1-MARKDOWN-001', 'floating Node major', 'markdown', (source) => replaceOnce(source, "          node-version: '24.18.1'", "          node-version: '24'")],
  ['T1-MARKDOWN-002', 'latest Node', 'markdown', (source) => replaceOnce(source, "          node-version: '24.18.1'", "          node-version: 'latest'")],
  ['T1-MARKDOWN-003', 'setup cache enabled', 'markdown', (source) => replaceOnce(source, '          package-manager-cache: false', '          package-manager-cache: true')],
  ['T1-MARKDOWN-004', 'setup input added', 'markdown', (source) => replaceOnce(source, '          check-latest: false', '          check-latest: false\n          cache: npm')],
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
  ['T1-MARKDOWN-014', 'native-command error mapping guard removed', 'markdown', (source) => replaceOnce(source, '          if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {\n              $PSNativeCommandUseErrorActionPreference = $false\n          }\n', '')],
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

function runNegativeFixtures(buildSource, markdownSource, packageSource, lockSource, generatorSource) {
  const ids = new Set();
  for (const [id, description, kind, fixture] of FIXTURE_INVENTORY) {
    if (ids.has(id)) reject('fixture-harness', `duplicate fixture ID ${id}`);
    ids.add(id);
    let rejected = false;
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
      if (error instanceof PolicyError && error.category !== 'fixture-harness') rejected = true;
      else throw error;
    }
    if (!rejected) reject('fixture-harness', `${id} (${description}) was not rejected`);
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
