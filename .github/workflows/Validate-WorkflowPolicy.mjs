import { createHash } from 'node:crypto';
import { lstatSync, readFileSync, readdirSync, realpathSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
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
  assertKeys(workflow.jobs, ['verify', 'temporary-writer'], 'build jobs');

  const verify = workflow.jobs.verify;
  assertKeys(verify, ['runs-on', 'permissions', 'steps'], 'build.verify');
  if (verify['runs-on'] !== 'ubuntu-latest') reject('policy', 'build.verify runner changed');
  assertEqual(verify.permissions, { contents: 'read' }, 'build.verify permissions');
  const verifyIds = verify.steps.map((step) => step?.id);
  assertEqual(verifyIds, ['checkout', 'verify-checkout-credentials', 'generate-and-verify', 'upload-generated'], 'build.verify step order');
  assertActionStep(findStep(verify, 'checkout', 'build.verify'), 'build.verify.checkout', ACTIONS.checkout, CHECKOUT_INPUTS);
  assertActionStep(
    findStep(verify, 'upload-generated', 'build.verify'),
    'build.verify.upload-generated',
    ACTIONS.uploadArtifact,
    UPLOAD_INPUTS,
    '${{ success() }}',
  );

  const writer = workflow.jobs['temporary-writer'];
  assertKeys(writer, ['needs', 'if', 'runs-on', 'permissions', 'steps'], 'build.temporary-writer');
  assertEqual(writer.needs, ['verify'], 'build.temporary-writer needs');
  if (writer.if !== "${{ github.event_name == 'push' && github.ref == 'refs/heads/main' && needs.verify.result == 'success' }}") {
    reject('condition-policy', 'temporary writer eligibility changed');
  }
  if (writer['runs-on'] !== 'ubuntu-latest') reject('policy', 'temporary writer runner changed');
  assertEqual(writer.permissions, { contents: 'write' }, 'temporary writer permissions');
  const writerIds = writer.steps.map((step) => step?.id);
  assertEqual(writerIds, ['checkout', 'verify-checkout-credentials', 'prepare-generated-commit', 'push-generated'], 'temporary writer step order');
  assertActionStep(findStep(writer, 'checkout', 'build.temporary-writer'), 'build.writer.checkout', ACTIONS.checkout, CHECKOUT_INPUTS);

  const pushStep = findStep(writer, 'push-generated', 'build.temporary-writer');
  assertKeys(pushStep, ['name', 'id', 'shell', 'env', 'run'], 'build.writer.push-generated');
  assertEqual(pushStep.env, {
    STYLE_GUIDE_PUSH_TOKEN: '${{ github.token }}',
    STYLE_GUIDE_TRIGGER_SHA: '${{ github.sha }}',
  }, 'build.writer.push-generated.env');
  if (!pushStep.run.includes("ArgumentList.Add('push')") ||
      !pushStep.run.includes('GIT_CONFIG_COUNT') ||
      !pushStep.run.includes('GIT_CONFIG_KEY_0') ||
      !pushStep.run.includes('GIT_CONFIG_VALUE_0') ||
      !pushStep.run.includes('--force-with-lease=refs/heads/main:')) {
    reject('side-effect-policy', 'temporary writer push containment changed');
  }

  for (const { jobId, id, run, step } of allRunSteps(workflow)) {
    if ('continue-on-error' in step) reject('failure-policy', `${jobId}.${id} sets continue-on-error`);
    if (/\b(?:curl|wget|Invoke-WebRequest)\b/iu.test(run)) reject('network-policy', `${jobId}.${id} adds a network client`);
    if (/secrets\./u.test(run) || /GITHUB_TOKEN/u.test(run)) reject('credential-policy', `${jobId}.${id} expands an unapproved credential`);
    if (id !== 'push-generated' && /ArgumentList\.Add\(['"]push['"]\)|\bgit\s+push\b/iu.test(run)) {
      reject('side-effect-policy', `${jobId}.${id} adds a second push path`);
    }
    if (id !== 'prepare-generated-commit' && /\bgit\s+(?:add|commit)\b/iu.test(run)) {
      reject('side-effect-policy', `${jobId}.${id} adds an unapproved repository mutation`);
    }
  }
  if (!findStep(verify, 'generate-and-verify', 'build.verify').run.includes("'diff', '--no-ext-diff', '--no-textconv', '--exit-code'")) {
    reject('git-policy', 'verification no longer classifies native git diff status');
  }
  if (!findStep(writer, 'prepare-generated-commit', 'build.temporary-writer').run.includes("'ls-files', '--others', '--exclude-standard', '-z'")) {
    reject('git-policy', 'writer no longer uses NUL-delimited untracked paths');
  }

  validateActionMultiset(source, [
    ACTIONS.checkout,
    ACTIONS.uploadArtifact,
    ACTIONS.checkout,
  ]);
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
    'ci --ignore-scripts --no-audit --no-fund',
    './Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml',
    'run lint:md',
    'run lint:md:nested',
    'Get-FileHash -LiteralPath package.json -Algorithm SHA256',
    'Get-FileHash -LiteralPath package-lock.json -Algorithm SHA256',
  ];
  for (const fragment of requiredFragments) {
    if (!validation.run.includes(fragment)) reject('markdown-policy', `required phase is missing: ${fragment}`);
  }
  if ((validation.run.match(/^\s*& \$strNpmPath run lint:md\s*$/gmu) ?? []).length !== 1 ||
      (validation.run.match(/^\s*& \$strNpmPath run lint:md:nested\s*$/gmu) ?? []).length !== 1) {
    reject('markdown-policy', 'each locked lint script must run exactly once');
  }
  if (/continue-on-error|secrets\.|\b(?:curl|wget|Invoke-WebRequest)\b/iu.test(source)) {
    reject('markdown-policy', 'Markdown workflow weakens failure, credential, or network policy');
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
  ['T1-BUILD-012', 'verify write permission', 'build', (source) => replaceOnce(source, '  verify:\n    runs-on: ubuntu-latest\n    permissions:\n      contents: read', '  verify:\n    runs-on: ubuntu-latest\n    permissions:\n      contents: write')],
  ['T1-BUILD-013', 'writer read permission', 'build', (source) => replaceOnce(source, '  temporary-writer:\n    needs: [verify]\n', '  temporary-writer:\n    needs: [verify]\n    outputs: {}\n')],
  ['T1-BUILD-014', 'missing verify job', 'build', (source) => replaceOnce(source, '  verify:', '  renamed-verify:')],
  ['T1-BUILD-015', 'extra job', 'build', (source) => `${source}\n  extra:\n    runs-on: ubuntu-latest\n    steps: []\n`],
  ['T1-BUILD-016', 'matrix introduction', 'build', (source) => replaceOnce(source, '  verify:\n    runs-on:', '  verify:\n    strategy:\n      matrix: { os: [ubuntu-latest] }\n    runs-on:')],
  ['T1-BUILD-017', 'service introduction', 'build', (source) => replaceOnce(source, '  verify:\n    runs-on:', '  verify:\n    services: {}\n    runs-on:')],
  ['T1-BUILD-018', 'remote reusable workflow', 'build', (source) => replaceOnce(source, '  verify:\n    runs-on:', '  verify:\n    uses: example/workflows/.github/workflows/x.yml@main\n    runs-on:')],
  ['T1-BUILD-019', 'needs mutation', 'build', (source) => replaceOnce(source, '    needs: [verify]', '    needs: []')],
  ['T1-BUILD-020', 'event condition mutation', 'build', (source) => replaceOnce(source, "github.event_name == 'push'", "github.event_name != 'pull_request'")],
  ['T1-BUILD-021', 'ref condition mutation', 'build', (source) => replaceOnce(source, "github.ref == 'refs/heads/main'", "github.ref != 'refs/heads/dev'")],
  ['T1-BUILD-022', 'needs-result mutation', 'build', (source) => replaceOnce(source, "needs.verify.result == 'success'", "needs.verify.result != 'failure'")],
  ['T1-BUILD-023', 'always widening', 'build', (source) => replaceOnce(source, "needs.verify.result == 'success'", 'always()')],
  ['T1-BUILD-024', 'job output introduction', 'build', (source) => replaceOnce(source, '  verify:\n    runs-on:', '  verify:\n    outputs: { changed: value }\n    runs-on:')],
  ['T1-BUILD-025', 'upload condition mutation', 'build', (source) => replaceOnce(source, '        if: ${{ success() }}', '        if: ${{ always() }}')],
  ['T1-BUILD-026', 'upload continuation', 'build', (source) => replaceOnce(source, '        if: ${{ success() }}\n        uses:', '        if: ${{ success() }}\n        continue-on-error: true\n        uses:')],
  ['T1-BUILD-027', 'upload path broadening', 'build', (source) => replaceOnce(source, '            copilot-instructions.md', '            *.md')],
  ['T1-BUILD-028', 'upload overwrite', 'build', (source) => replaceOnce(source, '          overwrite: false', '          overwrite: true')],
  ['T1-BUILD-029', 'upload step order', 'build', (source) => replaceOnce(source, '        id: upload-generated', '        id: early-upload')],
  ['T1-BUILD-030', 'second push side effect', 'build', (source) => replaceOnce(source, "          & ./.github/workflows/Generate-StyleGuideArtifacts.ps1", "          & git push\n          & ./.github/workflows/Generate-StyleGuideArtifacts.ps1")],
  ['T1-BUILD-031', 'secret expression', 'build', (source) => replaceOnce(source, '${{ github.token }}', '${{ secrets.PAT }}')],
  ['T1-BUILD-032', 'trigger branch mutation', 'build', (source) => replaceOnce(source, '    branches: [main]', '    branches: [dev]')],
  ['T1-BUILD-033', 'extra trigger', 'build', (source) => replaceOnce(source, 'on:\n', 'on:\n  workflow_dispatch:\n')],
  ['T1-BUILD-034', 'dynamic uses', 'build', (source) => replaceOnce(source, ACTIONS.checkout.reference, '${{ inputs.action }}')],
  ['T1-BUILD-035', 'unreviewed Docker action', 'build', (source) => replaceOnce(source, ACTIONS.checkout.reference, 'docker://alpine:latest')],
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
  ['T1-DEPENDABOT-001', 'duplicate updates', 'dependabot', 'version: 2\nupdates:\n  - package-ecosystem: github-actions\n    directory: /\n    schedule: { interval: weekly }\n  - package-ecosystem: github-actions\n    directory: /\n    schedule: { interval: weekly }\n'],
  ['T1-DEPENDABOT-002', 'npm update introduced early', 'dependabot', 'version: 2\nupdates:\n  - package-ecosystem: npm\n    directory: /.github/workflows\n    schedule: { interval: weekly }\n'],
  ['T1-DEPENDABOT-003', 'auto-merge key', 'dependabot', 'version: 2\nupdates:\n  - package-ecosystem: github-actions\n    directory: /\n    schedule: { interval: weekly }\n    auto-merge: true\n'],
  ['T1-VERSION-001', 'missing marker', 'version', '<#\n.NOTES\nnone\n#>\nfunction X {}\n'],
  ['T1-VERSION-002', 'duplicate marker', 'version', '<#\n.NOTES\nVersion: 1.0.20260731.0\nVersion: 1.0.20260731.0\n#>\nfunction X {}\n'],
  ['T1-VERSION-003', 'decoy marker', 'version', '<#\n.NOTES\nnone\n#>\nfunction X {}\nVersion: 1.0.20260731.0\n'],
  ['T1-VERSION-004', 'leading zero', 'version', '<#\n.NOTES\nVersion: 01.0.20260731.0\n#>\nfunction X {}\n'],
  ['T1-VERSION-005', 'overflow', 'version', '<#\n.NOTES\nVersion: 2147483648.0.20260731.0\n#>\nfunction X {}\n'],
  ['T1-VERSION-006', 'impossible date', 'version', '<#\n.NOTES\nVersion: 1.0.20260229.0\n#>\nfunction X {}\n'],
  ['T1-VERSION-007', 'future valid but unexpected', 'unexpected-version', '<#\n.NOTES\nVersion: 1.0.20991231.0\n#>\nfunction X {}\n'],
]);

function runNegativeFixtures(buildSource, markdownSource) {
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
      } else {
        reject('fixture-harness', `unknown fixture kind for ${id}`);
      }
    } catch (error) {
      if (error instanceof PolicyError) rejected = true;
      else throw error;
    }
    if (!rejected) reject('fixture-harness', `${id} (${description}) was not rejected`);
  }
  return ids.size;
}

function readOrdinaryText(path, label) {
  const stat = lstatSync(path);
  if (!stat.isFile() || stat.isSymbolicLink()) reject('filesystem-policy', `${label} is not an ordinary file`);
  if (realpathSync(path) !== resolve(path)) reject('filesystem-policy', `${label} resolves through an alias`);
  const bytes = readFileSync(path);
  if (bytes.subarray(0, 3).equals(Buffer.from([0xef, 0xbb, 0xbf]))) reject('text-policy', `${label} has a UTF-8 BOM`);
  if (bytes.includes(0x0d)) reject('text-policy', `${label} contains a carriage return`);
  return bytes.toString('utf8');
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
  parseGeneratorVersion(generatorSource, EXPECTED_VERSION);

  const fixtureCount = runNegativeFixtures(buildSource, markdownSource);
  return Object.freeze({
    fixtureCount,
    generatorVersion: EXPECTED_VERSION,
    policyDigest: createHash('sha256')
      .update(buildSource)
      .update(markdownSource)
      .update(dependabotSource)
      .digest('hex'),
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
