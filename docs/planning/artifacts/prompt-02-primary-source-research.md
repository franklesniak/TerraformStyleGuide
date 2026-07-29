# Prompt 02 primary-source research

Research date: 2026-07-29.

## GitHub Actions reuse mechanisms

Primary sources:

- [GitHub Docs: Reusing workflow configurations](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations)
- [GitHub Docs: Reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
- [GitHub Docs: Metadata syntax for composite actions](https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax)

Durable findings:

- GitHub Actions supports YAML anchors and aliases, including reuse of mappings
  and complete job configurations.
- A reusable workflow is called at the job level, not as a step within an
  existing job. The calling job can use only the documented restricted keyword
  set, so it cannot simply insert a reusable workflow between preparation and
  production steps in the same job.
- A same-repository reusable workflow referenced with
  `./.github/workflows/<file>` comes from the same commit as the caller.
- A composite action groups steps and is invoked as one step, but requires
  action metadata and explicit shells for `run` steps. Its internal steps are
  less visible in the caller log than ordinary workflow steps.
- These mechanisms can reduce workflow duplication, but none is a better
  executable unit for a cross-platform, directly locally runnable PowerShell
  fixture suite than a tracked `.ps1` harness invoked by each required shell.

## GitHub Actions immutability and maintenance

Primary sources:

- [GitHub Docs: Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [GitHub Docs: Keeping actions up to date with Dependabot](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/auto-update-actions)
- [GitHub Docs: Dependabot-supported GitHub Actions references](https://docs.github.com/en/code-security/reference/supply-chain-security/supported-ecosystems-and-repositories#github-actions)
- [`actions/checkout` v6.1.0 release](https://github.com/actions/checkout/releases/tag/v6.1.0)
- [`actions/setup-node` v6.5.0 release](https://github.com/actions/setup-node/releases/tag/v6.5.0)
- [`actions/upload-artifact` v7.0.1 release](https://github.com/actions/upload-artifact/releases/tag/v7.0.1)
- [`actions/download-artifact` v8.0.1 release](https://github.com/actions/download-artifact/releases/tag/v8.0.1)

Durable findings:

- GitHub says a full-length commit SHA is the only immutable way to consume an
  action and recommends verifying that the SHA belongs to the upstream action
  repository.
- Current exact action-distribution refs verified with `git ls-remote` on
  2026-07-29:
  - `actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803`
    (`v6.1.0`);
  - `actions/setup-node@249970729cb0ef3589644e2896645e5dc5ba9c38`
    (`v6.5.0`);
  - `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`
    (`v7.0.1`); and
  - `actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c`
    (`v8.0.1`).
- Checkout v6 uses Node 24 and stores persisted credentials under
  `RUNNER_TEMP`; ordinary authenticated Git commands continue to work, subject
  to the documented runner compatibility requirement.
- Setup-node v6 uses Node 24. Its current README recommends an explicit Node
  version and documents automatic npm caching; the repository's markdown lint
  job should preserve its existing Node/config behavior unless a separately
  validated change is required.
- Dependabot version updates support GitHub Actions referenced by full commit
  SHA. An adjacent same-line version comment is updated with the reference.
  The minimum configuration uses `package-ecosystem: github-actions`,
  `directory: "/"`, and a schedule.
- Dependabot version updates create reviewable pull requests; they do not make
  mutable tags safe at execution time. SHA pinning remains the execution-time
  control.
- GitHub separately notes that vulnerability alerts for actions pinned only by
  SHA have limitations. Version-update pull requests plus human review of
  upstream release notes remain useful maintenance controls.

## Filesystem path and link handling

Primary sources:

- [Microsoft Learn: `Resolve-Path`](https://learn.microsoft.com/powershell/module/microsoft.powershell.management/resolve-path)
- [Microsoft Learn: `Path.GetFullPath`](https://learn.microsoft.com/dotnet/api/system.io.path.getfullpath)
- [Microsoft Learn: `FileAttributes`](https://learn.microsoft.com/dotnet/api/system.io.fileattributes)
- [Microsoft Learn: `FileSystemInfo.ResolveLinkTarget`](https://learn.microsoft.com/dotnet/api/system.io.filesysteminfo.resolvelinktarget)
- [GitHub Actions variables reference](https://docs.github.com/en/actions/reference/workflows-and-actions/variables)

Durable findings:

- `Resolve-Path` resolves PowerShell/provider paths and wildcards to existing
  path entries; its documented contract is not a physical canonicalization
  guarantee for every symbolic-link or reparse-point ancestor.
- `Path.GetFullPath` returns an absolute lexical path. The target does not need
  to exist, and the method's contract does not say it removes filesystem link
  indirection.
- `FileAttributes.ReparsePoint` is supported on Windows, Linux, and macOS.
  `File.GetAttributes` is available in .NET Framework versions used by Windows
  PowerShell 5.1, making component rejection portable across the required
  editions.
- Newer .NET exposes `ResolveLinkTarget`, including final-target traversal and
  junction/symlink support, but that API is not a safe common-denominator
  contract for Windows PowerShell 5.1.
- `RUNNER_TEMP` is a runner-provided temporary directory emptied at the
  beginning and end of each job, subject to permissions. The workflow should
  create a unique child for each helper/harness use rather than treating the
  ambient value alone as an already validated helper boundary.
- Rejecting every reparse/symbolic-link component in an absolute existing path
  makes separator-aware lexical containment meaningful for the supported
  runner model. Repeating the component checks narrows but cannot eliminate
  time-of-check/time-of-use races.
- The remaining race model must therefore be explicit: checkout and the unique
  trusted temporary root are job-owned, their parents are runner-controlled,
  and no competing process may replace entries during validation/extraction.
