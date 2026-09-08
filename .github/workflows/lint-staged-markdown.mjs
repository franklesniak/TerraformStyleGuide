import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const workflowsDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(workflowsDir, '../..');
const rootPackagePath = resolve(repoRoot, 'package.json');
const exactSemanticVersionPattern = /^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$/u;

let rootPackage;

try {
  rootPackage = JSON.parse(readFileSync(rootPackagePath, 'utf8'));
} catch {
  console.error('pre-commit: Failed to read the root package.json Node.js selector.');
  process.exit(2);
}

const requiredNodeVersion = rootPackage?.engines?.node;
const currentNodeVersion = process.versions.node;

if (typeof requiredNodeVersion !== 'string' || !exactSemanticVersionPattern.test(requiredNodeVersion)) {
  console.error('pre-commit: Root package.json must declare engines.node as one exact semantic version.');
  process.exit(2);
}

if (currentNodeVersion !== requiredNodeVersion) {
  console.error(`pre-commit: Node.js ${requiredNodeVersion} is required to lint staged Markdown.`);
  console.error(`Current version: ${process.version || 'unknown'}`);
  console.error('If you use a Node version manager with a GUI Git client, add its initialization to');
  console.error('~/.config/husky/init.sh, which Husky sources before running hooks.');
  console.error('To bypass this one commit only, use: git commit --no-verify');
  process.exit(1);
}

const maxBuffer = 100 * 1024 * 1024;

const runGit = (args) => {
  const result = spawnSync('git', args, {
    cwd: repoRoot,
    encoding: 'utf8',
    maxBuffer,
    windowsHide: true
  });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    throw new Error((result.stderr || '').trim() || `git ${args[0]} failed with exit code ${result.status}`);
  }

  return result.stdout;
};

const parseNulDelimitedPaths = (value) => value.split('\0').filter(Boolean);
const toAbsolutePosixPath = (repoRelativePath) => resolve(repoRoot, repoRelativePath).split(sep).join('/');

const stagedMarkdownPathspecs = Object.freeze(['*.md', '*.mdc']);
let stagedMarkdownPaths;

try {
  // Git pathspec wildcards match across directory separators, unlike shell globs,
  // so these pathspecs select staged Markdown and Cursor rules in every
  // subdirectory (including hidden .cursor/rules paths), not just the root.
  // See https://git-scm.com/docs/gitglossary (def_pathspec).
  stagedMarkdownPaths = parseNulDelimitedPaths(
    runGit([
      'diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z', '--',
      ...stagedMarkdownPathspecs
    ])
  );
} catch (error) {
  console.error(error);
  console.error('pre-commit: Failed to inspect staged Markdown files.');
  process.exit(2);
}

if (stagedMarkdownPaths.length === 0) {
  process.exit(0);
}

const stagedMarkdownByAbsolutePosixPath = {};
const stagedMarkdownInputs = [];

try {
  for (const repoRelativePath of stagedMarkdownPaths) {
    const content = runGit(['show', `:${repoRelativePath}`]);
    stagedMarkdownByAbsolutePosixPath[toAbsolutePosixPath(repoRelativePath)] = content;
    stagedMarkdownInputs.push({ filePath: repoRelativePath, content });
  }
} catch (error) {
  console.error(error);
  console.error('pre-commit: Failed to read staged Markdown content from Git.');
  process.exit(2);
}

let exitCode;

try {
  const { main: markdownlintCli2 } = await import('markdownlint-cli2');
  exitCode = await markdownlintCli2({
    directory: repoRoot,
    argv: ['--config', '.github/workflows/.markdownlint.jsonc'],
    nonFileContents: stagedMarkdownByAbsolutePosixPath,
    logMessage: console.log,
    logError: console.error
  });
} catch (error) {
  console.error(error);
  console.error('pre-commit: Markdown lint tooling failed to run.');
  console.error('Try reinstalling dev dependencies: npm --prefix .github/workflows ci');
  process.exit(2);
}

if (exitCode !== 0) {
  console.error('');
  console.error('pre-commit: Markdown lint failed for staged Markdown.');
  console.error('To check all Markdown files, run: npm --prefix .github/workflows run lint:md');
} else {
  try {
    const require = createRequire(import.meta.url);
    const {
      displayResults,
      lintNestedMarkdownContents
    } = require('./lint-nested-markdown.js');
    const { totalBlocks, allResults } = lintNestedMarkdownContents(
      stagedMarkdownInputs,
      undefined,
      console.log
    );
    console.log(`\nTotal nested Markdown blocks found: ${totalBlocks}\n`);
    if (displayResults(allResults)) {
      console.error('pre-commit: Nested Markdown lint failed for staged Markdown.');
      console.error('To check all Markdown files, run: npm --prefix .github/workflows run lint:md:nested');
      exitCode = 1;
    }
  } catch (error) {
    console.error(error);
    console.error('pre-commit: Nested Markdown lint tooling failed to run.');
    console.error('Try reinstalling dev dependencies: npm --prefix .github/workflows ci');
    exitCode = 2;
  }
}

process.exitCode = exitCode;
