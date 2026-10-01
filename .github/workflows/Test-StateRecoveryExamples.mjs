import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

// Provider substitutes and the test runner share this file; the executable
// examples are always extracted from the published normative source below.
const self = fileURLToPath(import.meta.url);
const state = JSON.stringify({ version: 4, serial: 7, lineage: 'fixture-lineage', resources: [], secret: 'STATE_SECRET_FIXTURE' });
const quote = value => `'${value.replaceAll("'", "'\\''")}'`;
const write = (file, value) => fs.writeFileSync(file, value, { mode: 0o600 });
const exists = file => { try { fs.lstatSync(file); return true; } catch (error) { if (['ENOENT', 'ENOTDIR'].includes(error.code)) return false; throw error; } };

async function stub() {
  const command = path.basename(process.argv[3]);
  const args = process.argv.slice(4), env = process.env, mode = env.SR_TEST_MODE;
  const option = name => args.find(value => value.startsWith(`${name}=`))?.slice(name.length + 1) ?? args[args.indexOf(name) + 1];
  const log = record => fs.appendFileSync(env.SR_TEST_LOG, `${JSON.stringify(record)}\n`, { mode: 0o600 });
  const real = name => `/usr/bin/${name}`;
  if (['ln', 'rm', 'mktemp'].includes(command)) {
    if (command === 'rm' && mode.includes('cleanup-failure')) process.exit(42);
    if (command === 'rm' && mode === 'repeat-signal') {
      process.kill(process.ppid, 'SIGTERM');
      process.kill(process.ppid, 'SIGHUP');
    }
    if (command === 'ln' && mode.startsWith('final-')) {
      const destination = args.at(-1);
      if (mode === 'final-file') write(destination, 'EXISTING');
      if (mode === 'final-link') fs.symlinkSync(env.SR_TEST_VICTIM, destination);
      if (mode === 'final-directory') fs.mkdirSync(destination, { mode: 0o700 });
    }
    const result = spawnSync(real(command), args, { encoding: 'utf8' });
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (command === 'mktemp' && result.status === 0 && mode.startsWith('temporary-')) {
      const directory = result.stdout.trim();
      if (mode === 'temporary-file') write(path.join(directory, 'data'), 'EXISTING');
      else fs.symlinkSync(env.SR_TEST_VICTIM, path.join(directory, 'data'));
    }
    if (command === 'ln' && result.status === 0 && mode === 'post-publication-failure') process.exit(31);
    process.exit(result.status ?? 99);
  }
  const call = { command, args, exportedToken: Object.hasOwn(env, 'token') };
  if (command === 'curl') {
    const header = fs.readFileSync(0, 'utf8');
    call.expectedHeader = header === 'Authorization: Bearer TOKEN_SECRET_FIXTURE\n';
  }
  log(call);
  let output, destination;
  if (command === 'aws' && args[0] === 's3api' && args[1] === 'list-object-versions') {
    output = JSON.stringify({ Versions: [{ Key: env.AWS_KEY, VersionId: env.AWS_VERSION_ID },
      { Key: `${env.AWS_KEY}.sibling`, VersionId: 'sibling' }], DeleteMarkers: [{ Key: env.AWS_KEY, VersionId: 'deleted' }] });
  } else if (command === 'aws' && args[0] === 's3api' && args[1] === 'get-object') {
    destination = args.at(-1); output = JSON.stringify({ VersionId: mode === 'wrong-version' ? 'wrong' : env.AWS_VERSION_ID });
  } else if (command === 'az' && args.slice(0, 3).join(' ') === 'storage blob list') {
    output = JSON.stringify([{ name: env.AZURE_BLOB, versionId: env.AZURE_VERSION_ID },
      { name: `${env.AZURE_BLOB}.sibling`, versionId: 'sibling' }]);
  } else if (command === 'az' && args.slice(0, 3).join(' ') === 'storage blob download') {
    assert.equal(option('--overwrite'), 'false'); assert.equal(option('--auth-mode'), 'login');
    destination = option('--file');
    if (exists(destination)) process.exit(19);
    output = JSON.stringify({ versionId: mode === 'wrong-version' ? 'wrong' : env.AZURE_VERSION_ID });
  } else if (command === 'gcloud' && args.slice(0, 2).join(' ') === 'storage ls') {
    output = `gs://${env.GCS_BUCKET}/${env.GCS_OBJECT}#${env.GCS_GENERATION}\n` +
      `gs://${env.GCS_BUCKET}/${env.GCS_OBJECT}.sibling#123\n`;
  } else if (command === 'gcloud' && args.slice(0, 3).join(' ') === 'storage objects describe') {
    output = JSON.stringify({ bucket: env.GCS_BUCKET, name: env.GCS_OBJECT,
      generation: mode === 'wrong-version' ? '123' : env.GCS_GENERATION });
  } else if (command === 'gcloud' && args.slice(0, 2).join(' ') === 'storage cp') {
    assert.ok(args.includes('--no-clobber')); assert.ok(args.includes('--do-not-decompress'));
    destination = args.at(-1);
    if (exists(destination) || mode === 'skip') process.exit(0);
    output = '';
  } else if (command === 'curl') {
    assert.equal(args.at(-1), 'https://app.terraform.io/api/v2/state-versions');
    assert.ok(args.includes('--get')); assert.ok(!args.includes('--location'));
    output = JSON.stringify({ data: [{ type: 'state-versions', id: 'sv-fixture',
      relationships: { workspace: { data: { id: mode === 'wrong-version' ? 'ws-wrong' : env.HCP_WORKSPACE_ID } } },
      attributes: { 'hosted-state-download-url': 'SIGNED_URL_SECRET_FIXTURE' } }], meta: { pagination: { 'next-page': 2 } } });
  } else throw new Error(`Unexpected provider operation: ${command}`);
  if (destination) {
    if (mode === 'payload-link') fs.symlinkSync(env.SR_TEST_VICTIM, destination);
    else write(destination, mode.startsWith('partial') ? 'PARTIAL_STATE_SECRET_FIXTURE' :
      mode === 'state-multiple' ? `${state}\n${state}` : mode === 'state-invalid-first' ? `{}\n${state}` : state);
  }
  if (mode === 'response-multiple' && output) output = `${output}\n${output}`;
  if (mode === 'response-invalid-first' && output) output = `{}\n${output}`;
  if (mode === 'malformed') output = '{malformed';
  if (mode === 'empty') output = '';
  if (mode.startsWith('partial')) {
    process.stdout.write('PARTIAL_RESPONSE_SECRET_FIXTURE');
    process.stderr.write('DIAGNOSTIC_SECRET_FIXTURE');
    process.exit(29);
  }
  if (output) process.stdout.write(output);
  if (mode === 'ownership-change') {
    const directory = path.join(env.SR_DEST, fs.readdirSync(env.SR_DEST).find(name => name.startsWith('.work.')));
    fs.renameSync(directory, `${directory}.retained`); fs.mkdirSync(directory, { mode: 0o700 });
  }
  if (mode.startsWith('signal-') || mode === 'repeat-signal') {
    // Signal the actual shell while it waits for this foreground command.
    process.kill(process.ppid, mode === 'repeat-signal' ? 'SIGINT' : mode.slice(7));
    await new Promise(resolve => setTimeout(resolve, 40));
  }
}

if (process.argv[2] === '--stub') {
  await stub();
} else {
  assert.equal(process.platform, 'linux', 'Recovery examples require Linux; a skip is not a passing result.');
  assert.ok(Number(process.versions.node.split('.')[0]) >= 22, 'Node 22 or newer is required.');
  const root = path.resolve(path.dirname(self), '../..');
  const guidePath = path.join(root, 'STYLE_GUIDE.md');
  const guide = fs.readFileSync(guidePath, 'utf8');
  const identifiers = ['SR-AWS-DISCOVERY', 'SR-AWS-RECOVERY', 'SR-AZURE-DISCOVERY', 'SR-AZURE-RECOVERY',
    'SR-GCS-DISCOVERY', 'SR-GCS-RECOVERY', 'SR-HCP-DISCOVERY'];
  function extract(identifier) {
    const marker = `<!-- ${identifier} -->`;
    assert.equal(guide.split(marker).length, 2, `${identifier}: exactly one published marker`);
    const match = guide.slice(guide.indexOf(marker) + marker.length).match(/^\r?\n```bash\r?\n([\s\S]*?)\r?\n```/u);
    assert.ok(match, `${identifier}: adjacent Bash fence`);
    return match[1].replaceAll('\r\n', '\n');
  }
  const setup = extract('SR-SETUP'), snippets = new Map(identifiers.map(id => [id, extract(id)]));
  const originalGuide = fs.readFileSync(guidePath), originalSelf = fs.readFileSync(self);
  const home = os.homedir();
  const fixtureRoot = fs.mkdtempSync(path.join(home, '.state-recovery-test-'));
  fs.chmodSync(fixtureRoot, 0o700);
  const binary = path.join(fixtureRoot, 'bin'); fs.mkdirSync(binary, { mode: 0o700 });
  const jq = process.env.STATE_RECOVERY_TEST_JQ ?? spawnSync('which', ['jq'], { encoding: 'utf8' }).stdout.trim();
  assert.ok(path.isAbsolute(jq) && fs.existsSync(jq), 'jq is required; missing jq cannot skip the tests.');
  fs.symlinkSync(jq, path.join(binary, 'jq'));
  for (const command of ['aws', 'az', 'gcloud', 'curl', 'ln', 'rm', 'mktemp']) {
    fs.writeFileSync(path.join(binary, command), `#!/bin/sh\nexec ${quote(process.execPath)} ${quote(self)} --stub "$0" "$@"\n`, { mode: 0o700 });
  }
  let count = 0;
  const defaultInputs = {
    AWS_BUCKET: 'state-bucket', AWS_KEY: 'env/prod state+$quote.tfstate', AWS_VERSION_ID: '-opaque+/=.version',
    AZURE_ACCOUNT: 'examplestate', AZURE_CONTAINER: 'tf-state', AZURE_BLOB: 'env/prod state+$quote.tfstate',
    AZURE_VERSION_ID: '2026-09-30T01:02:03.1234567Z',
    GCS_BUCKET: 'state_bucket', GCS_OBJECT: 'env/prod state+$quote.tfstate', GCS_GENERATION: '9007199254740993',
    HCP_HOST: 'app.terraform.io', HCP_ORGANIZATION: 'Example Organization', HCP_WORKSPACE: 'Production Workspace',
    HCP_WORKSPACE_ID: 'ws-Fixture123', HCP_PAGE: '2', HCP_PAGE_SIZE: '20',
  };
  function run(id, mode = '', inputs = {}, change = value => value, includeSetup = true) {
    const directory = path.join(fixtureRoot, `case-${++count}`); fs.mkdirSync(directory, { mode: 0o700 });
    const destination = path.join(directory, 'result'), log = path.join(directory, 'calls'), victim = path.join(directory, 'victim');
    write(victim, state);
    const env = { ...process.env, ...defaultInputs, ...inputs, PATH: `${binary}:/usr/bin:/bin`,
      SR_DEST: destination, SR_TEST_MODE: mode, SR_TEST_LOG: log, SR_TEST_VICTIM: victim,
      AWS_EC2_METADATA_DISABLED: 'true', BASH_ENV: '/dev/null', ENV: '/dev/null' };
    delete env.NODE_OPTIONS; delete env.SHELLOPTS; delete env.BASHOPTS;
    if (mode === 'existing-directory') fs.mkdirSync(destination, { mode: 0o700 });
    if (mode === 'existing-file') write(destination, 'EXISTING');
    if (mode === 'existing-link') fs.symlinkSync(victim, destination);
    if (mode === 'git-parent') write(path.join(directory, '.git'), 'gitdir: fixture');
    if (mode === 'readable-parent') fs.chmodSync(directory, 0o755);
    const script = path.join(directory, 'example.bash');
    write(script, change(`${includeSetup ? setup : ''}\n${snippets.get(id)}\n`));
    const result = spawnSync('/usr/bin/bash', ['--noprofile', '--norc', script], {
      env, encoding: 'utf8', input: 'TOKEN_SECRET_FIXTURE\n', timeout: 15000,
    });
    assert.equal(result.error, undefined, `${id}/${mode}: process error ${result.error}`);
    assert.equal(result.signal, null, `${id}/${mode}: unexpected shell termination ${result.signal}`);
    for (const secret of ['TOKEN_SECRET_FIXTURE', 'STATE_SECRET_FIXTURE', 'SIGNED_URL_SECRET_FIXTURE', 'DIAGNOSTIC_SECRET_FIXTURE']) {
      assert.ok(!`${result.stdout}${result.stderr}`.includes(secret), `${id}/${mode}: secret in console output`);
    }
    const calls = exists(log) ? fs.readFileSync(log, 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse) : [];
    const output = path.join(destination, id.endsWith('RECOVERY') ? 'recovered.tfstate' : 'versions.json');
    return { ...result, directory, destination, output, calls, victim, env };
  }
  function success(result) {
    assert.equal(result.status, 0, result.stderr);
    assert.ok(exists(result.output));
    assert.equal(fs.statSync(result.output).mode & 0o777, 0o600);
    assert.equal(fs.statSync(result.destination).mode & 0o777, 0o700);
    assert.equal(fs.statSync(result.output).nlink, 1);
    assert.equal(fs.readdirSync(result.destination).length, 1, 'successful cleanup removes work storage');
  }
  function failure(result, status) {
    assert.notEqual(result.status, 0, 'failure must not pass');
    if (status !== undefined) assert.equal(result.status, status, result.stderr);
    assert.ok(!exists(result.output), 'pre-publication failure must not create final output');
  }
  try {
    for (const id of identifiers) {
      const result = run(id); success(result);
      assert.ok(result.calls.length > 0, `${id}: actual provider wiring`);
      const content = fs.readFileSync(result.output, 'utf8');
      if (id.endsWith('DISCOVERY')) assert.ok(!content.includes('sibling'), `${id}: exact filtering`);
      else assert.equal(content, state, `${id}: retrieval bytes unchanged`);
      for (const call of result.calls) {
        const { command, args } = call;
        if (command === 'aws') {
          assert.ok(args.includes(`--bucket=${defaultInputs.AWS_BUCKET}`));
          assert.ok(args.includes(`${id.endsWith('RECOVERY') ? '--key' : '--prefix'}=${defaultInputs.AWS_KEY}`));
          if (id.endsWith('RECOVERY')) assert.ok(args.includes(`--version-id=${defaultInputs.AWS_VERSION_ID}`));
        }
        if (command === 'az') {
          assert.ok(args.includes(`--account-name=${defaultInputs.AZURE_ACCOUNT}`));
          assert.ok(args.includes(`--container-name=${defaultInputs.AZURE_CONTAINER}`));
          assert.ok(args.includes(`${id.endsWith('RECOVERY') ? '--name' : '--prefix'}=${defaultInputs.AZURE_BLOB}`));
          if (id.endsWith('RECOVERY')) assert.ok(args.includes(`--version-id=${defaultInputs.AZURE_VERSION_ID}`));
          else assert.ok(args.includes('*'));
        }
        if (command === 'gcloud') assert.ok(args.includes(`gs://${defaultInputs.GCS_BUCKET}/${defaultInputs.GCS_OBJECT}${id.endsWith('RECOVERY') ? `#${defaultInputs.GCS_GENERATION}` : ''}`));
        if (command === 'curl') {
          assert.ok(call.expectedHeader); assert.equal(call.exportedToken, false);
          assert.ok(args.includes(`filter[organization][name]=${defaultInputs.HCP_ORGANIZATION}`));
          assert.ok(args.includes(`filter[workspace][name]=${defaultInputs.HCP_WORKSPACE}`));
          assert.ok(args.includes('page[number]=2')); assert.ok(args.includes('page[size]=20'));
        }
      }
      const missing = run(id, '', {}, value => value, false); failure(missing, 64); assert.equal(missing.calls.length, 0);
      for (const mode of ['partial', 'malformed', 'empty']) failure(run(id, mode));
      if (id !== 'SR-GCS-DISCOVERY') {
        for (const mode of ['response-multiple', 'response-invalid-first']) failure(run(id, mode));
      }
      if (id.endsWith('RECOVERY')) {
        for (const mode of ['state-multiple', 'state-invalid-first']) failure(run(id, mode));
      }
      if (id.endsWith('RECOVERY') || id.startsWith('SR-HCP')) failure(run(id, 'wrong-version'));
    }
    const first = 'SR-AWS-DISCOVERY';
    for (const mode of ['existing-directory', 'existing-file', 'existing-link', 'git-parent', 'readable-parent']) {
      const result = run(first, mode); failure(result, 64); assert.equal(result.calls.length, 0);
      assert.equal(fs.readFileSync(result.victim, 'utf8'), state);
      if (mode === 'existing-file') assert.equal(fs.readFileSync(result.destination, 'utf8'), 'EXISTING');
    }
    for (const mode of ['temporary-file', 'temporary-link']) {
      const result = run(first, mode); failure(result, 73); assert.equal(result.calls.length, 0);
      const work = fs.readdirSync(result.destination).find(name => name.startsWith('.work.'));
      assert.ok(exists(path.join(result.destination, work, 'data')), 'unclaimed temporary data retained');
    }
    for (const mode of ['final-file', 'final-link', 'final-directory']) {
      const result = run(first, mode); assert.notEqual(result.status, 0); assert.ok(exists(result.output));
      if (mode === 'final-file') assert.equal(fs.readFileSync(result.output, 'utf8'), 'EXISTING');
      if (mode === 'final-link') assert.ok(fs.lstatSync(result.output).isSymbolicLink());
      if (mode === 'final-directory') assert.ok(fs.statSync(result.output).isDirectory());
      assert.equal(fs.readFileSync(result.victim, 'utf8'), state);
    }
    for (const id of ['SR-AWS-RECOVERY', 'SR-AZURE-RECOVERY', 'SR-GCS-RECOVERY']) {
      const result = run(id, 'payload-link'); failure(result); assert.equal(fs.readFileSync(result.victim, 'utf8'), state);
    }
    failure(run('SR-GCS-RECOVERY', 'skip'));
    for (const mode of ['ownership-change', 'partial-cleanup-failure']) {
      const result = run(first, mode); failure(result, mode.startsWith('partial') ? 29 : undefined);
      assert.ok(fs.readdirSync(result.destination).some(name => name.startsWith('.work.')));
    }
    for (const [mode, status] of [['cleanup-failure', 74], ['post-publication-failure', 31]]) {
      const result = run('SR-AWS-RECOVERY', mode); assert.equal(result.status, status, result.stderr);
      assert.equal(fs.readFileSync(result.output, 'utf8'), state, 'published output survives later failure');
    }
    for (const [signal, status] of [['SIGHUP', 129], ['SIGINT', 130], ['SIGTERM', 143]]) failure(run(first, `signal-${signal}`), status);
    failure(run(first, 'repeat-signal'), 130);
    const inherited = run('SR-HCP-DISCOVERY', '', { token: 'INHERITED_SECRET_FIXTURE' }); success(inherited);
    assert.ok(inherited.calls.every(call => !call.exportedToken));
    const allexport = run('SR-HCP-DISCOVERY', '', { token: 'INHERITED_SECRET_FIXTURE' }, value =>
      `set -a\n${value}\nexample_status=$?\n[[ $- == *a* ]] || exit 77\nexit "$example_status"\n`);
    success(allexport);
    assert.ok(allexport.calls.every(call => !call.exportedToken), 'allexport and inherited token cannot export the prompted token to provider children');
    for (const [id, inputs] of [
      ['SR-AWS-DISCOVERY', { AWS_KEY: '' }], ['SR-AWS-RECOVERY', { AWS_VERSION_ID: 'null' }],
      ['SR-AWS-DISCOVERY', { AWS_BUCKET: 'unsupported--x-s3' }],
      ['SR-AZURE-DISCOVERY', { AZURE_CONTAINER: 'bad--name' }], ['SR-AZURE-RECOVERY', { AZURE_VERSION_ID: 'bad\nversion' }],
      ['SR-GCS-DISCOVERY', { GCS_OBJECT: 'state*' }], ['SR-GCS-RECOVERY', { GCS_GENERATION: 'latest' }],
      ['SR-HCP-DISCOVERY', { HCP_HOST: 'untrusted.example' }], ['SR-HCP-DISCOVERY', { HCP_PAGE_SIZE: '101' }],
      ['SR-AWS-DISCOVERY', { AWS_KEY: 'REPLACE_ME' }],
      ['SR-AWS-DISCOVERY', { AWS_BUCKET: 'a'.repeat(64) }], ['SR-AWS-DISCOVERY', { AWS_KEY: 'é'.repeat(513) }],
      ['SR-AWS-RECOVERY', { AWS_VERSION_ID: 'v'.repeat(1025) }],
      ['SR-AZURE-DISCOVERY', { AZURE_ACCOUNT: 'a'.repeat(25) }],
      ['SR-AZURE-DISCOVERY', { AZURE_CONTAINER: 'a'.repeat(64) }],
      ['SR-AZURE-DISCOVERY', { AZURE_BLOB: 'é'.repeat(513) }],
      ['SR-GCS-DISCOVERY', { GCS_BUCKET: 'a'.repeat(64) }], ['SR-GCS-DISCOVERY', { GCS_OBJECT: 'é'.repeat(513) }],
      ['SR-GCS-RECOVERY', { GCS_GENERATION: '1'.repeat(21) }],
      ['SR-HCP-DISCOVERY', { HCP_ORGANIZATION: 'é'.repeat(128) }], ['SR-HCP-DISCOVERY', { HCP_PAGE: '0' }],
    ]) { const result = run(id, '', inputs); failure(result, 64); assert.equal(result.calls.length, 0); assert.ok(!exists(result.destination)); }
    // Representative boundaries exercise shared byte-count validation without
    // multiplying every shared refusal across all seven provider actions.
    for (const [id, inputs, expectedArguments] of [
      ['SR-AWS-RECOVERY', { AWS_BUCKET: 'abc', AWS_KEY: 'é'.repeat(512), AWS_VERSION_ID: '-+/='.repeat(256) },
        ['--bucket=abc', `--key=${'é'.repeat(512)}`, `--version-id=${'-+/='.repeat(256)}`]],
      ['SR-AWS-DISCOVERY', { AWS_BUCKET: 'a'.repeat(63), AWS_KEY: 'x' }, [`--bucket=${'a'.repeat(63)}`, '--prefix=x']],
      ['SR-AZURE-DISCOVERY', { AZURE_ACCOUNT: 'abc', AZURE_CONTAINER: 'abc', AZURE_BLOB: 'x' },
        ['--account-name=abc', '--container-name=abc', '--prefix=x']],
      ['SR-AZURE-RECOVERY', { AZURE_ACCOUNT: 'a'.repeat(24), AZURE_CONTAINER: 'a'.repeat(63), AZURE_BLOB: 'é'.repeat(512) },
        [`--account-name=${'a'.repeat(24)}`, `--container-name=${'a'.repeat(63)}`, `--name=${'é'.repeat(512)}`]],
      ['SR-GCS-DISCOVERY', { GCS_BUCKET: 'abc', GCS_OBJECT: 'x' }, ['gs://abc/x']],
      ['SR-GCS-RECOVERY', { GCS_BUCKET: 'a'.repeat(63), GCS_OBJECT: 'é'.repeat(512), GCS_GENERATION: '1'.repeat(20) },
        [`gs://${'a'.repeat(63)}/${'é'.repeat(512)}#${'1'.repeat(20)}`]],
      ['SR-HCP-DISCOVERY', { HCP_ORGANIZATION: `${'é'.repeat(127)}x`, HCP_WORKSPACE: 'space + & é', HCP_PAGE: '1', HCP_PAGE_SIZE: '100' },
        [`filter[organization][name]=${'é'.repeat(127)}x`, 'filter[workspace][name]=space + & é', 'page[number]=1', 'page[size]=100']],
    ]) {
      const result = run(id, '', inputs); success(result);
      for (const argument of expectedArguments) assert.ok(result.calls.some(call => call.args.includes(argument)), 'boundary input bytes reach the provider unchanged');
    }
    // Mutate actual block text only in an ephemeral script. These prove that
    // the important assertions detect lost exact filtering/version checks.
    const unfiltered = run(first, '', {}, value => value.replaceAll('select(.Key == $key)', 'select(true)'));
    assert.equal(unfiltered.status, 0); assert.ok(fs.readFileSync(unfiltered.output, 'utf8').includes('sibling'));
    const unchecked = run('SR-AWS-RECOVERY', 'wrong-version', {}, value => value.replace('.VersionId == $version', 'true'));
    assert.equal(unchecked.status, 0, 'wrong-version negative case changes outcome if its actual guard is removed');
    const overwritten = run(first, 'final-file', {}, value => value.replace('ln -T --', 'ln -fT --'));
    assert.equal(overwritten.status, 0, 'publication failure changes outcome when force replaces exclusive creation');
    assert.notEqual(fs.readFileSync(overwritten.output, 'utf8'), 'EXISTING', 'no-clobber assertion detects the overwritten existing file');
    assert.deepEqual(fs.readFileSync(guidePath), originalGuide, 'source remains unchanged');
    assert.deepEqual(fs.readFileSync(self), originalSelf, 'harness remains unchanged');
    console.log(`state-recovery: ${count} network-free cases passed; all seven published actions executed`);
  } finally {
    // The harness owns this exclusive fixture tree; product cleanup never uses recursive removal.
    fs.rmSync(fixtureRoot, { recursive: true, force: true });
  }
}
