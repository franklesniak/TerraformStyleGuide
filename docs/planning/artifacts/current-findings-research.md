# Primary-source research for TerraformStyleGuide finding evaluation

Research date: 2026-07-29.

This artifact preserves the facts used to choose resolutions for
`current-findings-evaluation.md` and the six TerraformStyleGuide issue
descriptions. Quotations are deliberately avoided; the notes are paraphrases
of the linked primary sources.

## GitHub Actions job and matrix semantics

### Using jobs in a workflow

- Source: GitHub Docs, “Using jobs in a workflow”
- URL:
  <https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs>
- Preserved facts:
  - `jobs.<job_id>.needs` identifies prerequisite jobs in a workflow.
  - A failed or skipped prerequisite skips downstream jobs unless the
    downstream condition deliberately handles it.
  - `if: always()` can make a terminal aggregation job inspect failed or
    skipped dependencies.
- Design consequence:
  - A job in `build.yml` cannot use `needs` to depend on an independently
    triggered job in `markdownlint.yml`.
  - A reusable `workflow_call` invoked as a job in `build.yml` can participate
    in the caller's job graph.

### Contexts reference

- Source: GitHub Docs, “Contexts reference,” `needs` context
- URL:
  <https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#needs-context>
- Preserved facts:
  - `needs` contains direct dependency jobs and exposes each dependency's
    result and outputs.
  - Transitive dependencies do not appear automatically.
- Design consequence:
  - A terminal approval job must name every result/output it intends to
    inspect, directly or through an explicit aggregate.

### Workflow syntax: matrix job outputs

- Source: GitHub Docs, “Workflow syntax for GitHub Actions,” job outputs
- URL:
  <https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idoutputs>
- Preserved facts:
  - Matrix outputs are combined when the output names are unique.
  - GitHub does not guarantee matrix execution order.
  - Reusing an output name allows the last finishing matrix job to overwrite
    the earlier value.
  - Job outputs are limited to 1 MB per job and 50 MB per workflow run.
- Design consequence:
  - T1B needs four statically named matrix-cell evidence outputs; one shared
    result/digest output is not proof of four distinct cells.
  - Four SHA-256 strings and identifiers are far below the output limits.

### Reusable workflows

- Source: GitHub Docs, “Reuse workflows”
- URL:
  <https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows>
- Preserved facts:
  - A workflow in `.github/workflows` can expose `workflow_call` and be invoked
    by a caller job.
  - Called-workflow job outputs can be mapped to workflow outputs.
  - Matrix calls still have last-successful-output behavior, so unique output
    design remains necessary.
- Design consequence:
  - The selected T1B topology makes `markdownlint.yml` callable from
    `build.yml`, with its result in the caller's `needs` graph. It does not
    independently trigger a duplicate run.

## npm audit and Node policy

### npm audit

- Source: npm Docs, “npm-audit”
- URL: <https://docs.npmjs.com/cli/v11/commands/npm-audit/>
- Preserved facts:
  - npm submits dependency-tree information to the configured registry and can
    return detailed JSON.
  - Audit severity filtering changes failure behavior; it is not a replacement
    for explicit residual-risk governance.
  - The bulk advisory process reasons about package versions and vulnerable
    ranges.
- Local corroborating evidence:
  - `npm --prefix .github/workflows audit --package-lock-only --json` returned
    audit report version 2.
  - Each vulnerability object had package-level `nodes` and advisory objects
    or package relationships. The report did not contain a direct edge from
    each advisory URL to each node path.
- Design consequence:
  - T3 should approve `(Package, AdvisoryUrl)` findings and separately require
    exact package-keyed `AuditNodePaths`. It must not form an unproved Cartesian
    product of advisory URLs and installed paths.

### package.json engines

- Source: npm Docs, “package.json,” `engines`
- URL:
  <https://docs.npmjs.com/cli/v11/configuring-npm/package-json/#engines>
- Preserved facts:
  - `engines.node` accepts a semantic-version range.
  - Unless `engine-strict` is enabled, the package field is advisory when the
    package is installed as a dependency.
- Design consequence:
  - A bounded range in `package.json` is documentation and ecosystem metadata,
    while the real pre-commit hook and CI checks must enforce the policy.
  - Tests must cover rejected gaps and the first unreviewed future major.

## PowerShell and .NET byte/file behavior

### Windows PowerShell redirection

- Source: Microsoft Learn, “about_Redirection,” Windows PowerShell 5.1
- URL:
  <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection?view=powershell-5.1#redirecting-binary-data>
- Preserved facts:
  - Windows PowerShell does not preserve a native byte stream through ordinary
    redirection; it treats the data as strings.
- Design consequence:
  - T4 cannot describe `terraform state pull > file` or an `Out-File` pipeline
    as byte-preserving under Windows PowerShell 5.1.

### Current PowerShell redirection

- Source: Microsoft Learn, “about_Redirection,” PowerShell 7.5
- URL:
  <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection?view=powershell-7.5#redirecting-binary-data>
- Preserved facts:
  - Byte-preserving redirection of native stdout was introduced in PowerShell
    7.4.
- Design consequence:
  - A single cross-edition sample should use .NET process/stream APIs rather
    than branch between shell-redirection semantics.

### Redirected process stdout

- Sources:
  - Microsoft Learn, `ProcessStartInfo.RedirectStandardOutput`
  - Microsoft Learn, `Process.StandardOutput`
- URLs:
  - <https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.redirectstandardoutput?view=netframework-4.8.1>
  - <https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.standardoutput?view=netframework-4.8.1>
- Preserved facts:
  - Redirected output requires `UseShellExecute = false` and
    `RedirectStandardOutput = true`.
  - `StandardOutput` is a `StreamReader`; its `BaseStream` exposes the
    underlying byte stream.
  - Reading redirected output before waiting avoids a full-buffer deadlock.
- Design consequence:
  - The selected T4 PowerShell sample copies
    `process.StandardOutput.BaseStream` into a create-new `FileStream`, drains
    stderr separately/asynchronously, then waits and checks the native exit
    code.

### FileMode.CreateNew and stream copying

- Sources:
  - Microsoft Learn, `FileMode`
  - Microsoft Learn, `Stream.CopyTo`
- URLs:
  - <https://learn.microsoft.com/en-us/dotnet/api/system.io.filemode>
  - <https://learn.microsoft.com/en-us/dotnet/api/system.io.stream.copyto>
- Preserved facts:
  - `FileMode.CreateNew` asks the operating system to create a new file and
    throws if the path already exists.
  - `Stream.CopyTo` copies bytes from the current source position to a
    destination stream.
- Design consequence:
  - T4 can acquire the temporary file without overwrite and preserve native
    stdout bytes without text decoding.

### PowerShell hard links

- Source: Microsoft Learn, `New-Item`, Windows PowerShell 5.1
- URL:
  <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-item?view=powershell-5.1>
- Preserved facts:
  - The filesystem provider supports `HardLink` as an item type.
  - `New-Item` path values are literal for this cmdlet.
- Design consequence:
  - The Windows sample can use `New-Item -ItemType HardLink` without `-Force`
    as the no-replace publication operation, but the issue must prove
    existing-target refusal and a competing-creator race on real filesystems.

## Terraform state behavior

### State storage and locking

- Source: HashiCorp Developer, “State Storage and Locking”
- URL:
  <https://developer.hashicorp.com/terraform/language/state/backends>
- Preserved facts:
  - `terraform state pull` sends remote state to stdout.
  - Manual `terraform state push` is extremely dangerous and can overwrite
    remote state.
  - Terraform checks lineage and higher remote serial unless the operator uses
    `-force`.
  - Backend state locking is optional and backend-specific.
- Design consequence:
  - T4's backup, lineage, serial, typed confirmation, and external-exclusion
    requirements are justified; a manual backend identifier remains an
    operator attestation unless a backend-specific derivation is defined.

### State push and lock timeout

- Sources:
  - HashiCorp Developer, `terraform state push`
  - HashiCorp Developer, “State: Locking”
  - HashiCorp Developer, “Terraform v1.x Compatibility Promises”
- URLs:
  - <https://developer.hashicorp.com/terraform/cli/commands/state/push>
  - <https://developer.hashicorp.com/terraform/language/state/locking>
  - <https://developer.hashicorp.com/terraform/language/v1-compatibility-promises>
- Preserved facts:
  - `state push` verifies input before writing and has lineage/serial safety
    checks.
  - State locking occurs automatically for writes when the backend supports it;
    disabling it is discouraged.
  - `state push` supports `-lock-timeout=DURATION` in the Terraform v1.x
    compatibility surface.
- Design consequence:
  - The selected recovery command keeps locking enabled, prohibits
    `-lock=false`, and uses `-lock-timeout=5m`. A backend without locking still
    requires documented external exclusion.

### State pull/show and sensitive values

- Sources:
  - HashiCorp Developer, `terraform state pull`
  - HashiCorp Developer, `terraform show`
- URLs:
  - <https://developer.hashicorp.com/terraform/cli/commands/state/pull>
  - <https://developer.hashicorp.com/terraform/cli/commands/show>
- Preserved facts:
  - State pull writes state to stdout and may upgrade it to a locally supported
    representation.
  - JSON state inspection can expose sensitive values in plain text.
- Design consequence:
  - T2/T4 must use fresh protected paths, stop on partial output, validate
    before use, and retain explicit sensitive-data cleanup guidance.

## GNU Bash-hosted filesystem primitives

### `ln` no-replace and no-target-directory behavior

- Source: GNU Coreutils manual, “`ln`: Make links between files”
- URL:
  <https://www.gnu.org/software/coreutils/manual/html_node/ln-invocation.html>
- Preserved facts:
  - GNU `ln` normally does not replace an existing destination unless an
    explicit replacement option such as `--force` is used.
  - A hard link and its source name share one inode and cannot cross filesystem
    boundaries.
  - Without `--no-target-directory`, an existing destination directory can be
    treated as a directory into which a new link is created.
- Design consequence:
  - T2/T4 Bash publication uses
    `ln --no-target-directory` without `--force` or `--backup`, so a raced-in
    destination directory cannot redirect creation into that directory.
  - The temporary file must be in the same protected parent/filesystem as the
    requested final name.

### Private invocation-directory creation

- Source: GNU Coreutils manual, “`mktemp`: Create temporary file or directory”
- URL:
  <https://www.gnu.org/software/coreutils/manual/html_node/mktemp-invocation.html>
- Preserved facts:
  - `mktemp -d` creates an unpredictable directory atomically from a template.
  - The created directory grants read/write/search only to the current user,
    further restricted by the caller's umask.
  - `mktemp -u` only generates a name and is inherently race-prone.
- Design consequence:
  - T2 recovery blocks use `mktemp -d` under the validated protected final
    parent and never use `mktemp -u`.
