# Primary-source research for prompt 02 resolutions

Research began 2026-07-29. This artifact records the source facts used to
select resolutions in `current-findings-evaluation.md`. Source URLs and the
relevant behavior are retained so later issue editing does not depend on
retrieving the pages again.

## T1-01 and T1B-01 — GitHub Actions checkout/token lifecycle

### Pinned `actions/checkout` metadata and source

Reviewed commit:
`actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1`
(`v7.0.1` in the current issue slate).

Sources:

- [`action.yml`](https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/action.yml)
- [`src/input-helper.ts`](https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/src/input-helper.ts)
- [`src/git-source-provider.ts`](https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/src/git-source-provider.ts)
- [`src/git-auth-helper.ts`](https://raw.githubusercontent.com/actions/checkout/3d3c42e5aac5ba805825da76410c181273ba90b1/src/git-auth-helper.ts)

Retained facts:

1. `action.yml` lines 11–21 define `token` as the credential used to fetch the
   repository and default it to `${{ github.token }}`.
2. `action.yml` lines 47–49 define `persist-credentials` as controlling whether
   the token or SSH key remains configured in local Git config; its action
   default is `true`.
3. `input-helper.ts` line 145 reads `token` with
   `core.getInput('token', {required: true})`. An explicit empty token is not a
   supported way to make this checkout credential-free.
4. `git-source-provider.ts` lines 136–139 call `configureAuth()` before the
   fetch at lines 160–212.
5. When `persist-credentials` is false, the `finally` block at lines 291–300
   removes authentication after checkout work. It does not retroactively make
   fetch unauthenticated.
6. The REST fallback also receives `settings.authToken` at lines 70–93.

Conclusion: `persist-credentials: false` is an important post-checkout
containment control, but “checkout without credentials” and “the token exists
only at the push step” are false for this action/configuration.

### GitHub job-token availability and least privilege

Sources:

- [Use `GITHUB_TOKEN` for authentication in workflows](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token)
- [`GITHUB_TOKEN` concept](https://docs.github.com/en/actions/concepts/security/github_token)
- [Contexts reference](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts)
- [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)

Retained facts:

1. GitHub creates a unique `GITHUB_TOKEN` before each job begins; it expires
   when the job ends or reaches the applicable maximum lifetime.
2. `github.token` is available within execution steps.
3. GitHub explicitly warns that an action can access `github.token` even when
   the workflow does not pass `GITHUB_TOKEN` as an explicit action input.
4. GitHub's recommended control is therefore least-privilege job/workflow
   permissions, combined with careful action selection—not a claim that the
   token object is absent from all non-push steps.

Resolution consequence:

- distinguish token creation/availability at job scope from explicit expansion
  into an action input or step environment;
- explicitly pass each security-relevant action `token` input and set
  checkout's `persist-credentials: false`, so the reviewed YAML and policy
  validator have no hidden action-default dependency; the T1-06 audit found
  that pinned `setup-node` also defaults its distribution-download `token` to
  `github.token`, so its selected explicit value must also appear in the
  normative role table;
- restrict permissions per job and allow only reviewed actions/code in a
  write-capable job;
- state that checkout uses transient authentication for fetch and removes its
  Git configuration afterward; and
- reserve explicit push environment/header construction for the exact guarded
  push step without claiming the job token did not otherwise exist.

## T1-02 — PowerShell destination-path boundary

Sources:

- [`PathIntrinsics.GetUnresolvedProviderPathFromPSPath`](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.pathintrinsics.getunresolvedproviderpathfrompspath)
- [`WildcardPattern.ContainsWildcardCharacters`](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.wildcardpattern.containswildcardcharacters)
- [`Path.GetFullPath`](https://learn.microsoft.com/en-us/dotnet/api/system.io.path.getfullpath)
- [PowerShell path syntax](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_path_syntax)

Retained facts:

1. `GetUnresolvedProviderPathFromPSPath` returns one provider-internal string.
   It intentionally does not resolve wildcard characters. The overload with
   `ProviderInfo` and `PSDriveInfo` out parameters lets a caller prove that the
   selected provider is `FileSystem`.
2. The API accepts relative paths and provider-qualified paths. Therefore,
   merely calling it does not enforce a fully qualified, native-filesystem-only
   public grammar.
3. `WildcardPattern.ContainsWildcardCharacters` supports Windows PowerShell
   5.1 and PowerShell 7 and detects PowerShell's `*`, `?`, and `[` wildcard
   grammar.
4. `Path.GetFullPath(String)` depends on the current directory when its input is
   relative. A deterministic contract must reject relative input before this
   call or use a predetermined fully qualified base.
5. `GetUnresolvedProviderPathFromPSPath` does not produce multiple matches.
   Once wildcards are rejected, “multiple resolution” is not an applicable
   state for this API. The issue should prohibit a later switch to a resolving
   API rather than promise to count results that cannot occur here.

Repository-specific design consequence:

- compute the repository root from the generator's trusted `$PSScriptRoot`,
  not the caller's current directory;
- derive the four exact allowed destination paths from that root;
- require a nonempty, wildcard-free, fully qualified native filesystem input;
- use the out-parameter overload and require the `FileSystem` provider;
- normalize once and compare with the exact four-path allowlist using ordinal
  ignore-case on Windows and ordinal on Linux; and
- route all four payloads through one private helper so validation, newline
  normalization, encoding, failure handling, and write mechanics cannot drift.

## T1-03 — Parseable script-version convention

Primary source:

- [PSStyleGuide — Function and Script Versioning](https://github.com/franklesniak/PSStyleGuide/blob/main/STYLE_GUIDE.md#function-and-script-versioning)

Retained observable convention:

1. A script's comment-based-help `.NOTES` contains one line in the form
   `Version: Major.Minor.Build.Revision`.
2. The four numeric components are compatible with `[System.Version]`.
3. `Build` is the UTC modification date in `YYYYMMDD`.
4. `Major` changes for a breaking interface change; `Minor` changes for a
   non-breaking feature/capability change.
5. `Revision` is `0` when `Major`, `Minor`, or `Build` differs from the
   previously published version, and otherwise is the prior published
   revision plus one for another same-day published update.
6. A new script with no previously published version begins at
   `1.0.<implementation-UTC-YYYYMMDD>.0`.

TerraformStyleGuide baseline:

- `Generate-StyleGuideArtifacts.ps1` has a script-level `.NOTES` section but no
  version field.
- No repository-local parser or alternate script-version convention exists.
- T1A and T1B nevertheless refer to exact expected script versions.

Resolution consequence:

- adopt the same **observable** field and calculation rules directly in the
  Terraform issue text, so TerraformStyleGuide remains self-contained;
- treat the T1 generator as a new versioned script and assign
  `1.0.<actual implementation UTC date>.0`;
- parse exactly one field from the script-level `.NOTES`, validate the date as
  a real calendar date and the whole value as `[System.Version]`, and reject a
  missing, duplicate, malformed, stale, or unexpected field; and
- use both the parsed version and exact prerequisite merge commit in T1A/T1B.
  A version is human change metadata; a commit is immutable source identity.

## T1-04 — Transactional artifact replacement

Sources:

- [`File.Replace`](https://learn.microsoft.com/en-us/dotnet/api/system.io.file.replace)
- [`FileStream.Flush(Boolean)`](https://learn.microsoft.com/en-us/dotnet/api/system.io.filestream.flush)
- [.NET 6 Unix `File.Replace` exception alignment](https://learn.microsoft.com/en-us/dotnet/core/compatibility/core-libraries/6.0/file-replace-exceptions-on-unix)

Retained facts:

1. `File.Replace` replaces one existing destination with one source file,
   deletes the source, and optionally creates a backup. The source and
   destination can be placed in the same existing directory.
2. The API is present in .NET Framework used by Windows PowerShell 5.1 and in
   modern cross-platform .NET used by PowerShell 7. Microsoft's .NET 6
   compatibility note specifically documents its Unix behavior.
3. `FileStream.Flush(true)` is available in .NET Framework 4.0+ and modern .NET
   and flushes managed and intermediate file buffers.
4. T1's four generated destinations are tracked, pre-existing ordinary files.
   T1 can deliberately require that invariant rather than adding an
   absent-destination publication branch.

Selected transaction boundary for later issue editing:

1. create an unpredictable same-directory temporary file with
   `FileMode.CreateNew`, `FileAccess.Write`, and `FileShare.None`;
2. write the already encoded complete payload, flush to disk, and close;
3. verify the closed temporary file's length/hash;
4. call `File.Replace(temp, destination, $null)` as the sole commit point; and
5. delete a still-existing temporary file in `finally`.

The guarantee is process/filesystem scoped: before the commit point, any
failure leaves the destination byte-identical; a failed replacement must leave
the old destination and report failure; a successful replacement is success
and no later fallible validation may relabel it as a pre-commit failure.
Power-loss guarantees beyond the filesystem/API contract are not claimed.

## T1-05 — Reproducible semantic workflow validation

Current package evidence collected 2026-07-29:

- the existing lockfile happens to contain transitive `js-yaml@4.1.1` through
  `markdownlint-cli2`;
- it is not a direct dependency and no tracked workflow-policy validator exists;
- the current issue freezes `package.json`/`package-lock.json`, while T1B plans
  to add a permanent direct parser later.

Primary sources:

- [`yaml` package documentation](https://eemeli.org/yaml/)
- [`yaml@2.9.0` npm package](https://www.npmjs.com/package/yaml)

Retained facts for `yaml@2.9.0`:

1. The package has no runtime dependencies and requires Node `>=14.6`.
2. It supports `parseDocument`, exposes parse `errors` and `warnings`, checks
   unique keys by default, and supports strict YAML 1.2 parsing.
3. `schema: 'core'` selects the YAML 1.2 core schema.
4. `stringKeys: true` rejects non-string mapping keys.
5. `maxAliasCount: 0` on conversion disallows aliases. The validator should
   also walk the parsed node tree and reject alias/anchor/custom-tag/directive
   syntax before conversion, rather than rely on expansion limits alone.
6. The package version observed from the registry is `2.9.0`; its published
   integrity is
   `sha512-2AvhNX3mb8zd6Zy7INTtSpl1F15HW6Wnqj0srWlkKLcpYl/gMIMJiyuGq2KeI2YFxUPjdlB+3Lc10seMLtL4cA==`.

Design consequence:

- the policy owner and enforcement should merge together. T1 should add the
  exact direct parser, lockfile entry, tracked
  `Validate-WorkflowPolicy.mjs`, and fixtures when it first pins/allowlists
  actions;
- ordinary validation runs after `npm ci` and is offline;
- T1B extends the same validator and normative role table rather than creating
  a new enforcement mechanism later; and
- parser/version/action policy changes occur atomically and are reviewed like
  executable security policy.

## T1-06 and T1B-02/T1B-05 — Exact action inputs and Git path/status gates

Primary sources:

- [Pinned `actions/setup-node` metadata](https://raw.githubusercontent.com/actions/setup-node/820762786026740c76f36085b0efc47a31fe5020/action.yml)
- [Pinned `actions/upload-artifact` metadata](https://raw.githubusercontent.com/actions/upload-artifact/043fb46d1a93c77aae656e7c1c64a875d1fc6a0a/action.yml)
- [Git `status` documentation](https://git-scm.com/docs/git-status)
- [Git `diff` documentation](https://git-scm.com/docs/git-diff)

Retained action facts:

1. `setup-node` accepts both `node-version` and `node-version-file`;
   `check-latest` defaults false; its `token` default may resolve
   `github.token`; and `package-manager-cache` defaults true. A role that
   promises exact Node 24, no cache, and a reviewed token boundary must declare
   the relevant keys rather than rely on these defaults.
2. `upload-artifact` requires `path`, but defaults `name` to `artifact`,
   `if-no-files-found` to warning, `overwrite` to false,
   `include-hidden-files` to false, `compression-level` to 6, and `archive` to
   true. Exact immutable-candidate or failure-diagnostic roles need explicit
   names, paths, missing-file behavior, retention, overwrite, hidden-file,
   compression/archive choices as applicable.

Retained Git facts:

1. `git status --porcelain=v1 -z` is stable for scripts and terminates entries
   with NUL rather than newline.
2. `git diff --name-only -z` emits unmodified path bytes terminated by NUL;
   without `-z`, unusual pathnames are quoted/escaped.
3. `git diff --exit-code` returns `0` for no differences and `1` for
   differences. Other statuses are execution failures and must not be treated
   as the expected-difference state.

Additional T1B action source:

- [Pinned `actions/download-artifact` metadata](https://raw.githubusercontent.com/actions/download-artifact/3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c/action.yml)

Retained download facts:

1. If neither `artifact-ids` nor `name` is supplied, the action downloads all
   artifacts; exact consumers must explicitly provide `artifact-ids`.
2. `path` defaults to the workspace and supports tilde expansion; a protected
   invocation directory must be explicit.
3. `pattern` and `merge-multiple` enable multi-artifact selection/merging and
   must remain absent for the one-ID contract.
4. `repository` and `run-id` have context defaults and cross-run/repository
   behavior is activated with `github-token`; same-run consumers should keep
   those cross-boundary inputs absent.
5. `skip-decompress` defaults false, so the immutable ZIP/same-stream helper
   design requires explicit literal true.
6. `digest-mismatch` defaults error, but should be explicitly declared as
   `error` because it is a security-relevant failure policy.

Design consequence:

- one normative role table must define exact job, step, action/local target,
  condition, permissions, explicit input-key set, explicit values, and
  separately reviewed omitted defaults;
- the tracked validator compares the actual structure with that table rather
  than deriving expectations from observed YAML; and
- every affected-file/path equality gate parses NUL-delimited bytes and every
  native result captures `$LASTEXITCODE` immediately and classifies all
  permitted statuses.

## T1A-01 — PowerShell 5.1-compatible raw parameter grammar

Primary sources:

- [PowerShell advanced parameter validation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters)
- [`ValidateNotNullOrWhiteSpaceAttribute`](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.validatenotnullorwhitespaceattribute)
- [`ValidateScript` attribute](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/validatescript-attribute-declaration)

Retained facts:

1. Validation attributes run during parameter binding before the function body.
2. `ValidateNotNullOrWhiteSpace` expresses the desired null/empty/whitespace
   rule, but the documented class is from modern System.Management.Automation
   and is not a Windows PowerShell 5.1 common-denominator attribute.
3. `ValidateScript` is available, but a reusable script block in a parameter
   attribute is a poor place for ordered multi-phase filesystem/provider checks
   and stable case-specific diagnostics.
4. Strong `[string]` binding can convert caller values before the function can
   classify their original type/value. A mandatory `[object]` boundary followed
   immediately by exact scalar-string validation can distinguish null,
   non-string, empty, whitespace-only, wildcard/provider/path grammar, and
   malformed conversion states in both editions.

Design consequence:

- define one ordered raw path grammar for every public T1A path parameter;
- accept only an exact scalar `System.String`, then reject null, empty,
  whitespace-only, NUL/control, wildcard, relative/non-fully-qualified, and
  unsupported provider forms before filesystem work;
- retain the deliberate positive grammar for native fully qualified paths and
  `FileSystem::`-qualified absolute paths;
- use the same semantic resolver in each self-contained production script and
  the harness, with cross-script conformance fixtures rather than a shared
  cross-repository runtime; and
- assign stable status/phase/resource postconditions to every grammar case.

## T1B-03 — Disposable-branch writer proof

Primary sources:

- [GitHub Actions workflows](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows)
- [Events that trigger workflows — `push`](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#push)
- [Events that trigger workflows — `workflow_dispatch`](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch)
- [`GITHUB_TOKEN` event behavior](https://docs.github.com/en/actions/concepts/security/github_token#when-github_token-triggers-workflow-runs)

Retained facts:

1. GitHub finds workflow files in the commit SHA or Git ref associated with an
   event, and a workflow run uses the workflow version at that SHA/ref.
2. A `push` event runs workflows that have not been merged to the default
   branch and can be restricted to one literal branch through
   `on.push.branches`.
3. `workflow_dispatch` is unsuitable for introducing a temporary proof
   workflow solely on a disposable branch because the workflow must already
   exist on the default branch to receive that event.
4. A code push performed with the repository's `GITHUB_TOKEN` does not create
   another workflow run. A successful evidence writer can therefore advance
   the disposable ref without recursively invoking itself.

Selected proof consequence:

- create one unpredictable, fully recorded branch under
  `refs/heads/t1b-evidence/`, starting at the exact reviewed implementation
  commit;
- commit an evidence-only variant to that branch whose allowed delta manifest
  changes every production `main` trigger/approval/writer/target-policy literal
  to that one exact evidence ref, adds bounded test instrumentation and one
  source-guide fixture that guarantees a generated change, and changes no
  permissions, role, action pin/input, identity, candidate, staging, commit,
  credential, lease, or refspec rule;
- use `push`, not `workflow_dispatch`, so GitHub executes that branch-local
  workflow without putting a temporary dispatch surface on the default branch;
- require the real writer to update the exact evidence ref by one commit with
  the expected parent and only the four generated artifact changes;
- use evidence-only, hard-coded scenario commits for controlled negative
  drills, never a free-form runtime ref or command input;
- retain the implementation base commit, evidence commits, run IDs/URLs,
  target-ref observations, allowed-delta diff, and cleanup proof; and
- delete the remote evidence ref after the drills, prove it is absent, and
  prove the merge candidate is descended from the reviewed implementation base
  but contains none of the evidence-only commits, event/ref literals,
  instrumentation, fixtures, or policy allowances.

The evidence branch is deliberately outside the production branch-protection
boundary. If repository/environment rules must be adjusted to allow its writer,
record the exact before-state, apply only the evidence-ref-scoped temporary
change, restore the exact before-state in `finally`, and treat failed
restoration as a release blocker.

## T2-01 — Bash signal and `EXIT` cleanup semantics

Primary sources:

- [GNU Bash Reference Manual — Signals](https://www.gnu.org/software/bash/manual/html_node/Signals)
- [GNU Bash Reference Manual — Bourne Shell Builtins (`trap`)](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins)
- [POSIX shell command language — exit status and signals](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html)

Retained facts:

1. A trapped signal does not make `$?` inside its trap a portable
   `128 + signal-number` oracle. In particular, a signal can arrive after a
   successful shell operation and the trap body can observe `0`.
2. Bash reports a simple command terminated by signal `n` as `128+n`; POSIX
   requires a signal-terminated command status greater than 128 but does not
   standardize that exact arithmetic for every shell.
3. Bash runs an `EXIT` trap before the shell terminates. An explicit
   signal-specific handler can therefore call `exit` with a chosen nonzero
   value and let one `EXIT` handler own cleanup.
4. A trapped signal received while Bash waits for a foreground command may be
   handled only after that command completes; while Bash waits through the
   `wait` builtin, a trapped signal makes `wait` return greater than 128 before
   the trap runs. Tests need a deterministic stub/ready marker rather than
   assuming the trap executes at an arbitrary instruction immediately.

Selected consequence:

- install `cleanup_recovery` only for `EXIT`;
- install separate HUP/INT/TERM handlers which first ignore all three handled
  signals, then `exit 129`, `exit 130`, or `exit 143`;
- have the `EXIT` handler capture the supplied status before any command,
  disable its own trap, keep handled signals ignored during cleanup, perform
  cleanup exactly once, and preserve a nonzero primary status even when cleanup
  also fails;
- if the primary status is zero but cleanup fails, return one specified
  cleanup-failure status rather than success; and
- exercise every provider/signal at a harness synchronization point after the
  private root/partial exists, including an induced cleanup failure.

## T2-04 — Provider identifier grammars

Primary sources:

- [Amazon S3 general-purpose bucket naming rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html)
- [Amazon S3 object-key naming](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-keys.html)
- [Amazon S3 version IDs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/versioning-workflows.html#version-ids)
- [Azure storage-account overview](https://learn.microsoft.com/azure/storage/common/storage-account-overview#storage-account-name)
- [Azure container/blob naming](https://learn.microsoft.com/rest/api/storageservices/naming-and-referencing-containers--blobs--and-metadata)
- [Azure Blob versioning](https://learn.microsoft.com/azure/storage/blobs/versioning-overview#version-id)
- [Google Cloud Storage buckets](https://cloud.google.com/storage/docs/buckets#naming)
- [Google Cloud Storage objects](https://cloud.google.com/storage/docs/objects#naming)
- [HCP Terraform workspace API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/workspaces)

Retained facts:

1. S3 general-purpose bucket names have a detailed 3–63-character DNS-like
   grammar plus reserved prefixes/suffixes. S3 keys are case-sensitive UTF-8
   sequences up to 1,024 bytes and can legally contain characters—including
   controls—that are unsuitable for a copyable shell/log interface.
2. S3 version IDs are service-generated, opaque, URL-ready UTF-8 strings no
   longer than 1,024 bytes. The example value includes `+`; a validator must not
   assume an alphanumeric-only identifier or parse/normalize it.
3. Azure storage-account names are 3–24 lowercase alphanumeric characters.
   Containers are 3–63 lowercase alphanumeric/hyphen names with no consecutive
   hyphens and alphanumeric endpoints. Blob names can contain arbitrary
   characters and are 1–1,024 characters; Azure describes a blob version ID as
   an opaque `DateTime` value whose service value is a timestamp.
4. Cloud Storage permits broader bucket/object naming than the guide needs.
   Object names are Unicode, cannot contain literal CR/LF, and have additional
   tool-compatibility warnings for controls, `#`, and wildcard-like characters.
   The service assigns a generation number.
5. HCP Terraform workspace names allow letters, numbers, hyphen, and
   underscore. The issue already sends organization/workspace as
   `--data-urlencode` data rather than concatenating them into a URL path.

Resolution consequence:

- do not attempt to reproduce every mutable provider grammar in Bash;
- publish a clearly labeled, narrower ASCII grammar for this example's bucket,
  account, container, key/object, organization, workspace, and opaque selected
  version interfaces;
- retain provider-generated opaque version IDs byte-for-byte within a bounded
  printable-ASCII subset broad enough for documented values, and fail with an
  instruction to revise the example deliberately if an actual valid ID falls
  outside that subset;
- reject controls before confirmation, diagnostics, URI construction, or
  provider invocation and never echo rejected raw values; and
- retain primary provider links and require the chosen subset/source snapshot
  to be rechecked when the example is intentionally broadened.

## T3-01/T3-02 — Exact npm selection and Node engine floors

Implementation-planning snapshot taken 2026-07-29:

Primary sources:

- [`npm@12.0.2` registry metadata](https://registry.npmjs.org/npm/12.0.2)
- [`npm@12.0.2` package tarball](https://registry.npmjs.org/npm/-/npm-12.0.2.tgz)
- [Corepack project documentation](https://github.com/nodejs/corepack)
- [Node Corepack documentation](https://nodejs.org/api/corepack.html)

Retained facts:

1. The registry's `latest` npm release observed on the evidence date is
   `12.0.2`.
2. Its published engine is
   `^22.22.2 || ^24.15.0 || >=26.0.0`.
3. Its published tarball SRI is
   `sha512-uIXokLlBj6FpNUTQX1PmT5pz7BlIN9QlixX+zdaSNHsd0qUXsbDLr50xzY6Sw7cJVr0uzHKDOle0swmPW/p5Qw==`;
   the equivalent lowercase SHA-512 hex is
   `b885e890b9418fa1693544d05f53e64f9a73ec194837d4258b15fecdd692347b1dd2a517b1b0cbaf9d31cd8e92c3b70956bd2ecc72833a57b4b3098f5bfa7943`.
4. Corepack accepts `npm` in a `packageManager` descriptor with an exact version
   and optional integrity hash. Explicit `corepack npm` uses that selected
   manager; npm shims are not enabled by default, so merely adding
   `packageManager` while continuing to call ambient `npm` does not enforce it.
5. Corepack is bundled with Node releases from 14.19 through (but not including)
   Node 25. The selected repository runtime lines 22 and 24 therefore provide
   the explicit resolver, but its actual version/path must still be recorded.
6. Corepack can otherwise consult or update a “known good”/latest release.
   `COREPACK_DEFAULT_TO_LATEST=0`, an exact hashed project descriptor, strict
   project behavior, and an explicit version assertion are needed to prevent
   fallback from becoming policy.

Selected consequence:

- use exact `npm@12.0.2` through a hashed `packageManager` field and invoke it
  as `corepack npm` on every supported surface;
- reject disabling integrity/strict project selection and reject any reported
  npm version other than `12.0.2`;
- regenerate lockfile version 3 with that exact npm and use the same manager
  for install, list, lint scripts, hook, audit, fixtures, schedule, and local
  validation; and
- derive the reviewed Node-line floors from npm's exact engine:
  Node `22.22.2` and Node `24.15.0`, with no Node 20/26 line admitted merely
  because npm itself supports it.

Additional Node sources/snapshot:

- [Node.js release status](https://nodejs.org/en/about/previous-releases)
- [Node.js evolving release schedule](https://nodejs.org/en/blog/announcements/evolving-the-nodejs-release-schedule)
- [Node.js official distribution index](https://nodejs.org/dist/index.json)
- [Node.js Release Working Group schedule](https://github.com/nodejs/Release/blob/main/schedule.json)

Retained 2026-07-29 facts:

1. Node 22 is Maintenance LTS with scheduled end 2027-04-30; Node 24 is
   Active LTS with scheduled end 2028-04-30. Node 20 is EOL; Node 26 is Current.
2. The latest exact releases observed in the official distribution index are
   Node `22.23.2` and `24.18.1`.
3. Starting with Node 27, Node's announced annual schedule intends every major
   to become LTS. “Even major” is therefore neither a durable LTS predicate nor
   an authorization rule.
4. The repository's policy can admit the finite intervals
   `>=22.22.2 <23` and `>=24.15.0 <25` while using exact setup/evidence cells at
   both engine floors and current reviewed patches. Node 26 and future 27+
   remain rejected until an explicit policy/package-manager review.

## T3-03/T3-04 — npm audit report-v2 structure and baseline counts

Primary sources:

- [npm audit documentation](https://docs.npmjs.com/cli/v11/commands/npm-audit/)
- [`npm@12.0.2` exact registry package](https://registry.npmjs.org/npm/12.0.2)
- [`@npmcli/arborist` audit report source as bundled by the selected npm
  package](https://registry.npmjs.org/npm/-/npm-12.0.2.tgz)

Local dated observation (2026-07-29, pre-T3 baseline, Node 26.5.1/npm 11.7.0):

1. `npm audit --package-lock-only --json` returned native status `1` and a
   top-level object with exact properties `auditReportVersion`,
   `vulnerabilities`, and `metadata`; `auditReportVersion` was numeric `2`.
2. There were seven vulnerability **properties** keyed by package:
   `brace-expansion`, `js-yaml`, `linkify-it`, `markdown-it`,
   `markdownlint-cli2`, `minimatch`, and `picomatch`.
3. Their property severities were five high and two moderate, matching
   `metadata.vulnerabilities`; that metadata also had exact keys `info`, `low`,
   `moderate`, `high`, `critical`, and `total`.
4. Each vulnerability property had exact keys `name`, `severity`, `isDirect`,
   `via`, `effects`, `range`, `nodes`, and `fixAvailable`.
5. `via` contained both advisory objects and package-name strings. Advisory
   objects carried source/name/dependency/title/url/severity/CWE/CVSS/range
   data; string entries represented meta-vulnerability dependency edges.
6. `fixAvailable` appeared as booleans and objects with
   `name`, `version`, and `isSemVerMajor`.
7. The seven-property report contained more than seven advisory objects across
   advisory-object `via` entries, string `via` edges, and installed node paths.
   Those are different count domains and must not be labeled “seven affected
   package nodes.”
8. npm documents status `0` for no vulnerabilities. With the default
   `audit-level` (no threshold override), a vulnerability report is nonzero;
   registry/invalid-response/tool failures can also be nonzero. Report schema
   and native status therefore must be classified together rather than using
   either alone as “clean.”

Resolution consequence:

- freeze the exact report-v2 schema emitted by selected npm `12.0.2` after a
  clean implementation-time install and fail on any unsupported version/shape;
- separately validate/reconcile vulnerability-property severity counts,
  advisory objects, string graph edges, and package-keyed node paths;
- let a pure core classify strict raw report input plus supplied native process
  outcome and exception state;
- let orchestration own process launch, protected stdout/stderr capture,
  signal/start/timeout handling, and immediate native status; and
- label all implementation-time counts by their actual domain and date, never
  promote them to permanent acceptance constants.

## T3-05 — Husky installation and skip behavior

Primary sources:

- [Husky — How To](https://typicode.github.io/husky/how-to.html)
- [Husky — Get started](https://typicode.github.io/husky/get-started.html)
- [Husky — Troubleshoot](https://typicode.github.io/husky/troubleshoot.html)
- [Git hooks](https://git-scm.com/docs/githooks)

Retained facts:

1. Husky recommends a `prepare` script and configures Git through
   `core.hooksPath`; its troubleshooting guide expects the installed path to
   resolve to `.husky/_`.
2. Husky documents `HUSKY=0` as an intentional way to disable installation/
   execution in CI/Docker and illustrates a separate install script for an
   explicit production/CI skip.
3. The same documentation shows `husky || true` as a way to avoid a failure
   when devDependencies are absent, but that behavior is incompatible with this
   repository's promise that a full tooling install actually establishes and
   tests the hook.
4. A package located below the Git root needs an explicit directory change/
   target; Husky deliberately does not traverse arbitrary parents on its own.
5. Verifying only the `prepare` process status is insufficient: the actual
   local Git config, generated Husky shim, tracked hook, and a `git commit`
   pass/reject need to be observed in an owned repository.

Selected consequence:

- replace `husky || true` with a tracked, fail-closed installer which has an
  explicit `required` state and one tightly defined `skip` state;
- in required state, install at the independently resolved repository root and
  verify `core.hooksPath`, generated ordinary shim/launcher files, and tracked
  hook identity before success;
- in skip state, require explicit `HUSKY=0`, a closed reason, and proof that no
  hook/config mutation was expected or performed; and
- permanently test required success/failure, every skip near-miss, and actual
  `git commit` invocation in disposable repositories on both OS families.

## T3-06 — Follow-up issue syntax versus existence

Primary sources:

- [GitHub autolinked issue/PR URL forms](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/autolinked-references-and-urls)
- [GitHub REST issue response shape](https://docs.github.com/en/rest/issues/issues#get-an-issue)
- [GitHub Actions token permissions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions)

Retained facts:

1. A canonical repository issue URL has the recognizable form
   `https://github.com/OWNER/REPOSITORY/issues/NUMBER`, but parsing that string
   proves only syntax/selected repository/number.
2. GitHub's REST issue response carries repository/URL/number/state/database
   identities. The Issues API can also return pull requests; such responses
   include a `pull_request` property, so an existence check must reject that
   state when policy requires a filed issue.
3. A network lookup needs explicit authority and can fail independently of the
   pure audit/exception decision. GitHub Actions supports a job-scoped
   `issues: read` permission if an automated read is intentionally added;
   otherwise a maintainer can retain the lookup as approval evidence.

Selected consequence:

- the dependency-free pure core validates only a closed canonical URL grammar,
  exact `franklesniak/TerraformStyleGuide` repository, canonical positive issue
  number, and internal exception-field equality;
- exception approval/renewal separately retains an explicitly authorized GitHub
  read showing the issue exists, is an issue rather than a PR, remains open,
  and has a scope marker/hash matching the exact normalized residual findings;
- the external verification time/actor/immutable issue identities are recorded
  in reviewed evidence and referenced by the exception;
- ordinary offline validation does not claim it performed or can reproduce the
  network assertion; and
- the maximum 30-day exception renewal rechecks follow-up state/scope rather
  than treating one historical lookup as perpetual proof.

## T4-01/T4-05 — Windows ACL, reparse, and file identity

Primary sources:

- [.NET FileSystemSecurity](https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemsecurity?view=netframework-4.8.1)
- [.NET SetAccessRuleProtection](https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.objectsecurity.setaccessruleprotection?view=netframework-4.8.1)
- [CreateFile and `FILE_FLAG_OPEN_REPARSE_POINT`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilea)
- [GetFileInformationByHandleEx](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getfileinformationbyhandleex)
- [FILE_ID_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_id_info)
- [BY_HANDLE_FILE_INFORMATION](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/ns-fileapi-by_handle_file_information)
- [GetFinalPathNameByHandle](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfinalpathnamebyhandlea)
- [CreateHardLinkW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-createhardlinkw)

Retained facts:

1. `SetAccessRuleProtection(true,false)` protects a DACL and removes inherited
   rules; `AreAccessRulesProtected`, `AreAccessRulesCanonical`, `GetOwner`, and
   `GetAccessRules` expose the actual descriptor state for inspection.
2. `FILE_FLAG_OPEN_REPARSE_POINT` prevents normal reparse processing for the
   opened leaf; `FILE_FLAG_BACKUP_SEMANTICS` is required to obtain directory
   handles through `CreateFile`.
3. `FILE_ID_INFO` combines a volume serial number with a 128-bit file ID and
   explicitly documents that the pair can compare whether two open handles
   represent the same file.
4. The older `BY_HANDLE_FILE_INFORMATION` exposes link count and a 64-bit file
   ID; Microsoft notes the 64-bit ID is not guaranteed unique on ReFS, so the
   selected identity comparison uses `FILE_ID_INFO` and uses the older
   structure only for `nNumberOfLinks`.
5. `GetFinalPathNameByHandle` returns the final normalized path for an open
   handle, but neither it nor path-based .NET creation supplies a portable
   Windows `openat`-style adversarial namespace sandbox.
6. Microsoft documents `CreateHardLinkW` as NTFS-only, files-only, same-volume
   publication; its third parameter is reserved and must be null. It can hard
   link a symbolic-link entry, so the separate no-follow ordinary-file identity
   checks are mandatory.

Selected consequence:

- define a SID-based protected parent/file DACL and inspect the resulting
  descriptor rather than parsing localized command output;
- use one reviewed Win32 interop helper under PowerShell 5.1 and 7 for
  no-follow component checks, 128-bit file identity, link count, and exact
  hard-link publication;
- require NTFS for positive Windows publication and treat ReFS/unsupported
  filesystems as the explicit final-absent/validated-temp-retained failure;
- require the protected-parent/no-authorized-competitor premise explicitly and
  avoid claiming the handle checks defeat an authorized namespace racer; and
- fail closed when the filesystem or identity primitive is unavailable.

## T4-03 — Raw redirected-process streams

Primary source:

- [.NET Process.BeginErrorReadLine](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.beginerrorreadline)

Retained facts:

1. .NET requires a redirected stream to remain in either synchronous or
   asynchronous mode once reading starts.
2. Concurrent drainage is needed to avoid filling a child pipe while waiting
   for process completion; a retained-memory bound must not stop drainage at
   the boundary.

Selected consequence:

- drain stdout and stderr through independent raw-stream pumps;
- retain exactly 65,536 raw stderr bytes, treat byte 65,537 as overflow, and
  continue draining/discarding through EOF;
- fail overflow separately from the captured native outcome; and
- emit only bounded metadata, never captured diagnostic bytes.

## T4-04 — Strict BOM-less UTF-8

Primary sources:

- [.NET UTF8Encoding](https://learn.microsoft.com/en-us/dotnet/api/system.text.utf8encoding?view=netframework-4.8.1)
- [.NET UTF8Encoding(Boolean, Boolean)](https://learn.microsoft.com/en-us/dotnet/api/system.text.utf8encoding.-ctor)
- [.NET UTF8Encoding.GetPreamble](https://learn.microsoft.com/en-us/dotnet/api/system.text.utf8encoding.getpreamble)

Retained facts:

1. Microsoft explicitly recommends `UTF8Encoding(Boolean,Boolean)` with
   `throwOnInvalidBytes=true` for error detection/security.
2. The first constructor Boolean controls only what `GetPreamble` returns; it
   does not automatically add/remove a BOM during byte conversion.
3. UTF-8 BOM bytes are `EF BB BF`, so the issue needs an independent prefix
   rejection in addition to a throwing decoder.

Selected consequence:

- reject the BOM prefix on the original candidate bytes;
- validate the entire unchanged stream with
  `UTF8Encoding(false,true).GetDecoder()` and a final flush;
- place strict encoding validation before JSON/Terraform/metadata/publication;
  and
- permanently test every malformed sequence class and incremental-buffer
  boundary on both PowerShell editions.
