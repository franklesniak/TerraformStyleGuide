import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { lintMarkdownFiles, normalizeLintStatus } from './lint-markdown.mjs';
import { runBounded } from './NpmTools.mjs';

const source = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const { lintOuterMarkdownContents, lintNestedMarkdownContents, validateMarkdownInput } = require('./lint-nested-markdown.js');
const clean = '# Example\n\nClean text.\n';
const invalid = '# Broken\ntext\n';
const nestedInvalid = '# Example\n\n```markdown\n# Broken\ntext\n```\n';

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'markdown-tool-test-'));
  const tools = path.join(root, '.github/workflows');
  fs.mkdirSync(tools, { recursive: true });
  for (const name of ['lint-markdown.mjs', 'lint-nested-markdown.js', 'lint-staged-markdown.mjs', 'NpmTools.mjs', '.markdownlint.jsonc', 'package.json']) {
    fs.copyFileSync(path.join(source, name), path.join(tools, name));
  }
  fs.symlinkSync(path.join(source, 'node_modules'), path.join(tools, 'node_modules'), process.platform === 'win32' ? 'junction' : 'dir');
  fs.writeFileSync(path.join(root, 'package.json'), JSON.stringify({ engines: { node: process.versions.node } }));
  fs.writeFileSync(path.join(root, '.gitignore'), 'node_modules/\n');
  return root;
}
function remove(root) {
  assert.equal(fs.realpathSync(path.dirname(root)), fs.realpathSync(os.tmpdir()));
  assert.ok(path.basename(root).startsWith('markdown-tool-test-'));
  fs.rmSync(root, { recursive: true });
}
function write(root, name, content) {
  const file = path.join(root, name); fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, content); return file;
}
function run(root, name = 'lint-markdown.mjs', environment = process.env) {
  return runBounded(process.execPath, [path.join(root, '.github/workflows', name)], { cwd: root, env: environment });
}
function git(root, ...args) {
  const result = runBounded('git', args, { cwd: root }); assert.equal(result.status, 0, result.stderr.toString()); return result;
}
function expect(result, status, pattern) {
  const output = result.stdout.toString() + result.stderr.toString(); assert.equal(result.status, status, output);
  if (pattern) assert.match(output, pattern); return output;
}

test('bounded outer API covers hidden Unicode MDC and literal metachar/option names; excludes dependencies', () => {
  const root = fixture();
  try {
    for (const name of ['normal.md', '.hidden/space ü.mdc', '[{literal}].md', '--config=other.md']) write(root, name, clean);
    for (const name of ['node_modules/ignored.md', '.venv/ignored.mdc', '.git/ignored.md']) write(root, name, invalid);
    expect(run(root), 0);
    write(root, '.hidden/space ü.mdc', invalid);
    expect(run(root), 1, /MD022/u);
  } finally { remove(root); }
});

test('empty discovery deliberately succeeds through the actual outer child', () => {
  const root = fixture();
  try { expect(run(root), 0, /Found 0 Markdown file/u); }
  finally { remove(root); }
});

for (const [order, contents] of [['invalid then clean', [invalid, clean]], ['clean then invalid', [clean, invalid]]]) {
  test(`outer API rejects conflicting repeated labels: ${order}`, async t => {
    const root = fixture(), diagnostics = [];
    t.mock.method(console, 'error', (...args) => diagnostics.push(args.join(' ')));
    try {
      await assert.rejects(lintOuterMarkdownContents(root, contents.map(content => ({ filePath: 'same.md', content }))), error => {
        assert.match(error.message, /Conflicting outer Markdown inputs/u);
        assert.ok(error.message.includes('same.md'));
        return true;
      });
      assert.deepEqual(diagnostics, []);
    } finally { remove(root); }
  });
}

for (const [name, content, status] of [['clean', clean, 0], ['invalid', invalid, 1]]) {
  test(`outer API preserves lint results for identical repeated labels: ${name}`, async t => {
    const root = fixture(), diagnostics = [];
    t.mock.method(console, 'error', (...args) => diagnostics.push(args.join(' ')));
    try {
      assert.equal(await lintOuterMarkdownContents(root, [{ filePath: 'same.md', content }, { filePath: 'same.md', content }]), status);
      if (status === 1) assert.match(diagnostics.join('\n'), /same\.md:.*MD022/u);
      else assert.deepEqual(diagnostics, []);
    } finally { remove(root); }
  });
}

test('outer API preserves distinct case-sensitive labels and their diagnostics', async t => {
  const root = fixture(), diagnostics = [];
  t.mock.method(console, 'error', (...args) => diagnostics.push(args.join(' ')));
  try {
    assert.equal(await lintOuterMarkdownContents(root, [{ filePath: 'same.md', content: invalid }, { filePath: 'SAME.md', content: clean }]), 1);
    assert.match(diagnostics.join('\n'), /same\.md:.*MD022/u);
    assert.ok(diagnostics.every(message => !message.startsWith('SAME.md:')));
    diagnostics.length = 0;
    assert.equal(await lintOuterMarkdownContents(root, [{ filePath: 'same.md', content: clean }, { filePath: 'SAME.md', content: clean }]), 0);
    assert.deepEqual(diagnostics, []);
  } finally { remove(root); }
});

test('JSONC strings/comments, configured rules and JSON fallback agree in child and API', async () => {
  const root = fixture();
  try {
    write(root, 'example.md', clean);
    write(root, '.github/workflows/.markdownlint.jsonc', '{ // actual JSONC\n"default":false,"MD013":{"line_length":3},"MD044":{"names":["https://example.invalid/*text*/"]}}');
    expect(run(root), 1, /MD013/u);
    assert.equal(await lintOuterMarkdownContents(root, [{ filePath: 'example.md', content: clean }]), 1);
    fs.unlinkSync(path.join(root, '.github/workflows/.markdownlint.jsonc'));
    write(root, '.github/workflows/.markdownlint.json', '{"default":false}');
    expect(run(root), 0);
    assert.equal(await lintOuterMarkdownContents(root, [{ filePath: 'example.md', content: invalid }]), 0);
    fs.unlinkSync(path.join(root, '.github/workflows/.markdownlint.json'));
    fs.copyFileSync(path.join(source, '.markdownlint.jsonc'), path.join(root, '.github/workflows/.markdownlint.jsonc'));
    write(root, 'example.md', '<!-- markdownlint-disable MD022 -->\n' + invalid);
    expect(run(root), 0);
    write(root, 'example.md', invalid);
    expect(run(root), 1, /MD022/u);
  } finally { remove(root); }
});

test('missing, malformed, nonobject and extending rules are tooling failures', () => {
  const root = fixture();
  try {
    write(root, 'example.md', clean);
    for (const config of ['{bad}', '[]', '{"extends":"../../outside.json"}']) {
      write(root, '.github/workflows/.markdownlint.jsonc', config);
      expect(run(root), 2, /(?:Invalid|Unsupported) Markdown lint configuration/u);
    }
    fs.unlinkSync(path.join(root, '.github/workflows/.markdownlint.jsonc'));
    expect(run(root), 2, /requires.*markdownlint/u);
  } finally { remove(root); }
});

test('actual alternate configs/ignore/hostile CLI2 patterns are refused in all three callers', () => {
  const root = fixture();
  try {
    git(root, 'init', '--quiet'); write(root, 'example.md', clean); git(root, 'add', '--', 'example.md');
    for (const [name, content] of [['.markdownlintignore', '**'], ['.markdownlint.json', '{"default":false}'],
      ['sub/.markdownlint-cli2.jsonc', JSON.stringify({ globs: ['{'.repeat(10000) + 'x' + '}'.repeat(10000)] })]]) {
      const file = write(root, name, content);
      for (const caller of ['lint-markdown.mjs', 'lint-staged-markdown.mjs', 'lint-nested-markdown.js']) {
        expect(run(root, caller), 2, /Unsupported Markdown lint configuration/u);
      }
      fs.unlinkSync(file);
    }
  } finally { remove(root); }
});

test('ambient readable rc/env cannot suppress explicit API rules', () => {
  const root = fixture();
  try {
    write(root, 'example.md', invalid);
    const home = path.join(root, 'private-home');
    fs.mkdirSync(path.join(home, '.config/markdownlint'), { recursive: true });
    const environment = { ...process.env, HOME: home, USERPROFILE: home };
    expect(run(root, 'lint-markdown.mjs', environment), 1, /MD022/u);
    const rc = write(root, 'private-home/.config/markdownlint/config', '{"default":false}');
    expect(run(root, 'lint-markdown.mjs', environment), 1, /MD022/u); fs.unlinkSync(rc);
    expect(run(root, 'lint-markdown.mjs', { ...environment, MARKDOWNLINT_default: 'false' }), 1, /MD022/u);
  } finally { remove(root); }
});

test('actual bounded child nonzero, unexpected, timeout, output and API throw preserve tooling failure', async () => {
  const root = fixture();
  try {
    write(root, 'example.md', clean);
    const child = path.join(root, '.github/workflows/lint-nested-markdown.js');
    for (const native of [2, 7]) {
      fs.writeFileSync(child, `console.error('specific child cause'); process.exit(${native});`);
      expect(run(root), 2, new RegExp(`specific child cause[\\s\\S]*native exit ${native}`, 'u'));
    }
    fs.writeFileSync(child, 'setInterval(() => {}, 1000);');
    await assert.rejects(lintMarkdownFiles(root, (exe, args, options) => runBounded(exe, args, { ...options, timeout: 50 })), /timed out/u);
    fs.writeFileSync(child, "process.stdout.write('x'.repeat(100000));");
    await assert.rejects(lintMarkdownFiles(root, (exe, args, options) => runBounded(exe, args, { ...options, maxBuffer: 1024 })), /ENOBUFS/u);
    fs.unlinkSync(child);
    expect(run(root), 2, /ENOENT/u);
    fs.copyFileSync(path.join(source, 'lint-nested-markdown.js'), child);
    await assert.rejects(lintMarkdownFiles(root, (exe, args, options) => runBounded(path.join(root, 'missing-node'), args, options)), /ENOENT/u);
    fs.appendFileSync(child, '\nmodule.exports.lintOuterMarkdownContents = async () => { throw new Error("specific API cause"); };\n');
    git(root, 'init', '--quiet'); git(root, 'add', '--', 'example.md');
    expect(run(root, 'lint-staged-markdown.mjs'), 2, /specific API cause/u);
    assert.equal(normalizeLintStatus(7), 2);
    assert.equal(normalizeLintStatus(null), 2);
  } finally { remove(root); }
});

test('outer retains MD041/MD051 while nested snippets allow missing heading and external fragment', async () => {
  const root = fixture();
  try {
    const content = 'Text [fragment](#external-example).\n';
    assert.equal(await lintOuterMarkdownContents(root, [{ filePath: 'example.md', content }]), 1);
    const nested = lintNestedMarkdownContents([{ filePath: 'example.md', content: '# Example\n\n```markdown\n' + content + '```\n' }]);
    assert.equal(nested.allResults.length, 0); assert.equal(nested.totalBlocks, 1);
  } finally { remove(root); }
});

test('actual staged bytes survive worktree changes, nested phase, rename/delete and native shell hook', () => {
  const root = fixture();
  try {
    git(root, 'init', '--quiet');
    expect(run(root, 'lint-staged-markdown.mjs'), 0);
    const file = write(root, '.hidden/space ü.mdc', clean); git(root, 'add', '--', '.hidden/space ü.mdc');
    fs.writeFileSync(file, invalid); expect(run(root, 'lint-staged-markdown.mjs'), 0);
    fs.writeFileSync(file, nestedInvalid); git(root, 'add', '--', '.hidden/space ü.mdc'); fs.writeFileSync(file, clean);
    expect(run(root, 'lint-staged-markdown.mjs'), 1, /Nested Markdown lint failed/u);
    const hook = path.join(root, '.husky/pre-commit'); fs.mkdirSync(path.dirname(hook), { recursive: true });
    fs.copyFileSync(path.resolve(source, '../../.husky/pre-commit'), hook);
    const shell = process.platform === 'win32' ? 'C:/Program Files/Git/bin/bash.exe' : '/bin/sh';
    const env = { ...process.env, PATH: path.dirname(process.execPath) + path.delimiter + process.env.PATH };
    expect(runBounded(shell, [hook], { cwd: root, env }), 1, /Nested Markdown lint failed/u);
    fs.writeFileSync(file, clean); git(root, 'add', '--', '.hidden/space ü.mdc');
    expect(runBounded(shell, [hook], { cwd: root, env }), 0);
    const unrelated = write(root, 'unrelated.md', invalid);
    expect(runBounded(shell, [hook], { cwd: root, env }), 1, /Markdownlint reported errors/u);
    fs.writeFileSync(unrelated, nestedInvalid);
    expect(run(root), 0);
    expect(runBounded(shell, [hook], { cwd: root, env }), 1, /Nested Markdown lint did not pass/u);
    fs.unlinkSync(unrelated);
    git(root, '-c', 'user.name=Lint fixture', '-c', 'user.email=lint@example.invalid', 'commit', '--quiet', '-m', 'Private fixture baseline');
    git(root, 'mv', '--', '.hidden/space ü.mdc', '.hidden/renamed.md'); expect(run(root, 'lint-staged-markdown.mjs'), 0);
    git(root, 'reset', '--hard', '--quiet', 'HEAD'); git(root, 'rm', '--', '.hidden/space ü.mdc'); expect(run(root, 'lint-staged-markdown.mjs'), 0);
    git(root, 'reset', '--hard', '--quiet', 'HEAD'); fs.writeFileSync(file, clean + '\nChanged.\n'); git(root, 'add', '--', '.hidden/space ü.mdc');
    write(root, 'package.json', JSON.stringify({ engines: { node: '0.0.0' } }));
    expect(run(root, 'lint-staged-markdown.mjs'), 2, /is required/u);
    write(root, 'package.json', JSON.stringify({ engines: { node: process.versions.node } }));
    const helper = path.join(root, '.github/workflows/lint-nested-markdown.js');
    fs.appendFileSync(helper, '\nmodule.exports.lintOuterMarkdownContents = async () => 7;\n');
    expect(run(root, 'lint-staged-markdown.mjs'), 2, /unexpected exit status/u);
    fs.copyFileSync(path.join(source, 'lint-nested-markdown.js'), helper);
    fs.unlinkSync(path.join(root, '.github/workflows/node_modules'));
    expect(run(root, 'lint-staged-markdown.mjs'), 2, /tooling failed/u);
    expect(run(root), 2, /Markdown lint tooling/u);
  } finally { remove(root); }
});

test('real leaf/ancestor escape and nonregular paths are refused before reads', async () => {
  const root = fixture();
  const outside = fs.mkdtempSync(path.join(os.tmpdir(), 'markdown-outside-'));
  try {
    write(root, 'valid.md', clean);
    const outsideFile = write(outside, 'outside.md', clean);
    assert.throws(() => validateMarkdownInput(root, outsideFile), /outside the repository/u);
    assert.throws(() => validateMarkdownInput(root, path.join(root, '.github')), /regular file/u);
    fs.symlinkSync(outside, path.join(root, 'escape'), process.platform === 'win32' ? 'junction' : 'dir');
    assert.throws(() => validateMarkdownInput(root, path.join(root, 'escape/outside.md')), /outside the repository/u);
    if (process.platform !== 'win32') {
      fs.symlinkSync(outsideFile, path.join(root, 'leaf.md'));
      expect(run(root), 2, /non-symlink regular file/u);
    }
  } finally { remove(root); fs.rmSync(outside, { recursive: true }); }
});

for (const kind of ['regular', 'leaf-inside', 'leaf-outside', 'directory', 'missing', 'broken-link', 'ancestor-outside', 'ancestor-inside', 'root-alias']) {
  test(`actual outer child execution boundary: ${kind}`, async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'markdown-tool-test-'));
    fs.mkdirSync(path.join(root, '.github/workflows'), { recursive: true });
    write(root, 'package.json', JSON.stringify({ engines: { node: process.versions.node } }));
    const outside = `${root}-outside`, alias = `${root}-alias`;
    const directoryLink = process.platform === 'win32' ? 'junction' : 'dir';
    const marker = path.join(root, 'child-executed');
    let suppliedRoot = root;
    fs.mkdirSync(outside);
    try {
      const child = path.join(root, '.github/workflows/lint-nested-markdown.js');
      fs.writeFileSync(child, `require('node:fs').writeFileSync(${JSON.stringify(marker)}, 'executed');`);
      if (kind.startsWith('leaf-')) {
        const target = path.join(kind === 'leaf-inside' ? root : outside, 'child.cjs');
        fs.renameSync(child, target); fs.symlinkSync(target, child, 'file');
      } else if (kind === 'directory' || kind === 'missing' || kind === 'broken-link') {
        fs.unlinkSync(child);
        if (kind === 'directory') fs.mkdirSync(child);
        if (kind === 'broken-link') fs.symlinkSync(path.join(outside, 'absent.cjs'), child, 'file');
      } else if (kind.startsWith('ancestor-')) {
        const destination = path.join(kind === 'ancestor-inside' ? root : outside, 'relocated-workflows');
        fs.renameSync(path.dirname(child), destination);
        fs.symlinkSync(destination, path.dirname(child), directoryLink);
      } else if (kind === 'root-alias') {
        fs.symlinkSync(root, alias, directoryLink); suppliedRoot = alias;
      }
      const accepted = ['regular', 'ancestor-inside', 'root-alias'].includes(kind);
      if (accepted) {
        assert.equal(await lintMarkdownFiles(suppliedRoot), 0);
        assert.equal(fs.readFileSync(marker, 'utf8'), 'executed');
      } else {
        const failure = ['missing', 'broken-link'].includes(kind) ? /ENOENT|regular outer child/u : kind === 'ancestor-outside' ? /outside the repository/u : /regular outer child/u;
        const error = await lintMarkdownFiles(suppliedRoot).then(() => null, failure => failure);
        assert.equal(fs.existsSync(marker), false, 'Rejected child must not execute.');
        assert.ok(error instanceof Error, 'Invalid child must report a tooling error.');
        assert.match(error.message, failure);
      }
    } finally {
      if (fs.existsSync(alias)) fs.unlinkSync(alias);
      remove(root);
      fs.rmSync(outside, { recursive: true });
    }
  });
}
