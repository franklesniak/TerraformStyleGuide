# Primary-source research record

This file records the source propositions used while evaluating the TerraformStyleGuide findings. Retrieval date: 2026-07-28.

## Finding T1.1 — writer target-ref variable

### PowerShell environment-variable access

- Source: [Microsoft Learn — about_Environment_Variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables)
- Relevant proposition: PowerShell reads an environment variable with `$Env:<variable-name>`. Environment variables are distinct from ordinary PowerShell variables and are inherited by child processes.
- Application: GitHub's `GITHUB_REF` is `$env:GITHUB_REF` in a PowerShell `run:` block. `$GITHUB_REF` is an unrelated ordinary variable unless the script separately defines it.

### GitHub ref variables

- Source: [GitHub Docs — Variables reference](https://docs.github.com/en/actions/reference/workflows-and-actions/variables)
- Relevant propositions:
  - GitHub provides default environment variables to every workflow step.
  - `GITHUB_REF` corresponds to the `${{ github.ref }}` context property.
  - Default `GITHUB_*` variables cannot be overwritten.
- Application: a custom `TARGET_REF: ${{ github.ref }}` can be compared with the immutable default `$env:GITHUB_REF`, while one canonical value is then used for preflight, lease, and refspec construction.

### Remote-ref query

- Source: [Git — `git ls-remote`](https://git-scm.com/docs/git-ls-remote)
- Relevant propositions:
  - `--refs` omits pseudorefs and peeled tag lines.
  - `--exit-code` returns 2 when no matching ref is found.
  - Output is `<oid><TAB><ref><LF>`.
  - A full refname can be used as the match pattern.
- Application: the writer should require exit 0, exactly one tab-delimited line, the exact requested full ref, and the expected triggering object ID.

### Complete checkout object ID

- Source: [Git — `git rev-parse`](https://git-scm.com/docs/git-rev-parse)
- Relevant propositions:
  - `--verify` requires exactly one parameter that resolves to an object.
  - Appending `^{commit}` requires the object to resolve to a commit.
  - A resolved object name is emitted in the repository's native complete object-ID form.
- Application: compare the one successful `git rev-parse --verify "HEAD^{commit}"` result with `EXPECTED_SHA` and `GITHUB_SHA`. This proves a full commit ID without accepting an abbreviated input or hard-coding a SHA-1/SHA-256 length.

## Finding T1.2 — pre-merge helper execution

### GitHub matrix and explicit shells

- Source: [GitHub Docs — Workflow syntax for GitHub Actions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- Relevant propositions:
  - A matrix creates one job for every combination of its dimensions.
  - `fail-fast: false` prevents one matrix failure from cancelling the remaining cells.
  - On Windows, `shell: powershell` selects PowerShell Desktop and `shell: pwsh` selects PowerShell Core.
  - On Linux, `shell: pwsh` selects PowerShell Core.
- Application: the existing four-cell Windows PR matrix can exercise the exact helper under its assigned edition in every cell, while the Ubuntu PR job supplies the other supported OS family. The shell must be explicit on the step that invokes the helper.

### Step process boundary

- Source: [GitHub Docs — Workflow syntax, `jobs.<job_id>.steps`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idsteps)
- Relevant proposition: each step executes in its own process.
- Application: proving the generator's edition in one step does not prove that a helper invoked in a different step used the same shell. Each helper/self-test step needs its own explicit shell selection and runtime assertion.

## Finding T1.3 — bind helper calls to the assigned matrix edition

### Shell selection versus defaults

- Source: [GitHub Docs — Workflow syntax, `jobs.<job_id>.steps[*].shell`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsshell)
- Relevant propositions:
  - An individual `run` step can override the shell explicitly.
  - `powershell` means PowerShell Desktop on Windows.
  - `pwsh` means PowerShell Core.
  - Every `run` step is a separate process.
- Application: the strongest evidence is an edition-specific step with an explicit shell and an assertion of `$PSVersionTable.PSEdition` and version inside the same process that invokes the helper.

### Matrix context

- Source: [GitHub Docs — Contexts reference](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts)
- Relevant proposition: matrix properties vary per job and are available to steps in a matrix job.
- Application: two mutually exclusive steps can use `if: matrix.edition == 'desktop'` and `if: matrix.edition == 'core'`. This makes the shell choice reviewable without runtime shell-dispatch code.

## Finding T1.4 — checkout boundary and exhaustive filesystem enumeration

### Exhaustive entry enumeration

- Source: [.NET — `Directory.EnumerateFileSystemEntries`](https://learn.microsoft.com/en-us/dotnet/api/system.io.directory.enumeratefilesystementries)
- Relevant propositions:
  - The one-argument overload returns an enumerable of filesystem entry names in the specified directory.
  - Relative paths are interpreted against the current directory.
  - The returned enumeration is not cached.
- Application: the helper should first convert inputs to deterministic absolute filesystem paths, materialize the enumeration once, and use it for exact-count checks.

- Source: [Microsoft Learn — `Get-ChildItem`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-childitem)
- Relevant propositions:
  - `Get-ChildItem` does not return hidden items by default.
  - `-Force` includes hidden/system items.
  - `-LiteralPath` avoids wildcard interpretation.
- Application: if PowerShell enumeration is used anywhere in an “exactly” assertion, `-LiteralPath -Force` is mandatory. Plain `Get-ChildItem` is insufficient.

### Absolute path construction

- Source: [.NET — `Path.GetFullPath`](https://learn.microsoft.com/en-us/dotnet/api/system.io.path.getfullpath)
- Relevant propositions:
  - It produces a fully qualified path.
  - A relative path can depend on the mutable current directory.
  - Deterministic behavior requires a predetermined fully qualified base.
- Application: derive the checkout base from the tracked helper's fixed `$PSScriptRoot` location and resolve every caller path through the PowerShell filesystem provider before passing it to .NET.

### Reparse-point detection

- Source: [.NET — `FileAttributes`](https://learn.microsoft.com/en-us/dotnet/api/system.io.fileattributes)
- Relevant proposition: `ReparsePoint` is a defined file/directory attribute.
- Application: existing download entries, temporary parents, created destinations, and extracted files must be rejected when the reparse-point bit is present. Parent enumeration, rather than only `File.Exists`/`Directory.Exists`, is needed to notice a dangling final entry.

### Filesystem case behavior

- Source: [.NET Framework — `Directory.GetFileSystemEntries`](https://learn.microsoft.com/en-us/dotnet/api/system.io.directory.getfilesystementries?view=netframework-4.8.1)
- Relevant proposition: filesystem matching behavior can be case-insensitive on NTFS and case-sensitive on Linux.
- Application: containment and leaf-collision comparisons must use ordinal-ignore-case on Windows and ordinal on non-Windows; simple string prefix checks are insufficient without a directory-separator boundary.

## Finding T1.5 — classify both successful archive fixtures

### ZIP external attributes

- Source: [.NET — `ZipArchiveEntry.ExternalAttributes`](https://learn.microsoft.com/en-us/dotnet/api/system.io.compression.ziparchiveentry.externalattributes)
- Relevant propositions:
  - External attributes are OS- and application-specific.
  - Unix implementations commonly use the high-order portion for permissions/type information.
- Application: the helper must not restore these attributes. A fixture carrying symlink-like bits is a positive safety test: success proves the helper copies entry bytes into a newly created ordinary destination rather than recreating archive metadata.

### ZIP fixture construction

- Source: [.NET — `ZipArchive.CreateEntry`](https://learn.microsoft.com/en-us/dotnet/api/system.io.compression.ziparchive.createentry)
- Relevant proposition: `CreateEntry` rejects an empty entry name.
- Application: the empty-name negative case requires a reviewed fixed raw ZIP, while ordinary positive and negative cases can be constructed through the API.

### Entry stream behavior

- Source: [.NET — `ZipArchiveEntry.Open`](https://learn.microsoft.com/en-us/dotnet/api/system.io.compression.ziparchiveentry.open)
- Relevant proposition: `Open()` returns the entry content stream.
- Application: safe extraction consists of opening the permitted entry stream and copying bytes into a separately created `FileMode.CreateNew` destination; external attributes need not control destination type.

## Finding T2.1 — dangling final symlinks bypass `test -e`

### POSIX `test`

- Source: [The Open Group — `test`](https://pubs.opengroup.org/onlinepubs/9699919799.2016edition/utilities/test.html)
- Relevant propositions:
  - Except for `-h` and `-L`, pathname primaries resolve a symbolic link and test its target.
  - `-L pathname` is true when the final directory entry is a symbolic link and does not follow that final link.
  - `[` requires the closing bracket as a separate argument.
- Application: `[ -e "$path" ]` is false for a dangling final symlink, while `[ -L "$path" ]` detects the link entry. The uniform refusal test is `[ -e "$path" ] || [ -L "$path" ]`.

### Bash confirmation

- Source: [GNU Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html)
- Relevant propositions:
  - File-test primaries follow symbolic links unless otherwise specified.
  - `-L file` is true when the file is a symbolic link.
- Application: the POSIX behavior is also the behavior of the explicitly documented Bash execution environment for these examples.

### Provider no-clobber differences

- Source: [Azure CLI — `az storage blob download`](https://learn.microsoft.com/en-us/cli/azure/storage/blob#az-storage-blob-download)
- Relevant proposition: `--overwrite` defaults to true and accepts `false`.
- Source: [AWS CLI — `s3api get-object`](https://docs.aws.amazon.com/cli/latest/reference/s3api/get-object.html)
- Relevant proposition: the command requires an `outfile`; the documented interface has no native no-clobber flag.
- Application: provider-native flags are useful defense in depth but cannot replace a uniform final-link preflight across AWS, Azure, GCS, and the HCP response path.

## Finding T2.2 — exclusive creation of the HCP response path

### Bash noclobber redirection

- Source: [GNU Bash — Redirections](https://www.gnu.org/software/bash/manual/html_node/Redirections.html)
- Relevant propositions:
  - Ordinary `>` creates a missing file and truncates an existing file.
  - With the `noclobber` option (`set -C`), `>` fails rather than overwriting an existing regular file.
  - `>|` overrides noclobber and therefore must not be used.
- Application: open a dedicated file descriptor with `set -C; exec 3> "$TFC_RESPONSE_PATH"` before invoking curl, then send curl's stdout to descriptor 3. `umask 077` applies when the shell creates the file.

- Source: [The Open Group — Shell redirection rationale](https://pubs.opengroup.org/onlinepubs/9799919799/xrat/V4_xcu_chap01.html)
- Relevant propositions:
  - Modern noclobber creation uses exclusive-creation techniques and is designed to fail for an existing dangling symlink rather than create its target.
  - Reliable use still assumes that no competing process creates non-regular files or removes/replaces entries in the directory.
- Application: combine noclobber descriptor creation with the explicit `-e || -L` preflight and the already required protected-parent/no-competing-writer model. Do not claim protection from a writer that controls the parent directory.

### curl `--no-clobber`

- Source: [curl security advisory CVE-2022-27778](https://curl.se/docs/CVE-2022-27778.html)
- Relevant proposition: curl's `--no-clobber` appends a number and uses another unused filename when the requested name exists.
- Application: it does not satisfy an exact-path “create this file or fail” contract and must not be the selected fix.

### curl output and partial files

- Source: [curl manual](https://curl.se/docs/manpage.html)
- Relevant propositions:
  - Without an output-file option, the response body is written to stdout.
  - `--fail` makes HTTP 400-and-later responses fail.
  - `--silent --show-error` suppresses progress while retaining errors.
- Application: removing `--output` and redirecting stdout to an already exclusively opened descriptor preserves the current token-on-stdin configuration. A transfer failure can leave an empty or partial protected file; the example must report that fact and never treat it as a valid page.

## Finding T2.3 — no-drift evidence versus skipped writer

### Conditional jobs

- Source: [GitHub Docs — Using conditions to control job execution](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions)
- Relevant propositions:
  - `jobs.<job_id>.if` prevents a job from executing when the condition is false.
  - The UI marks that job as skipped.
  - A skipped job can report a successful status for check purposes, but its steps did not run.
- Application: when `has_changes=false` causes the synchronization job to skip, the run cannot be cited as evidence that its helper/self-test steps executed.

### Dependency result

- Source: [GitHub Docs — Contexts reference, `needs`](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#needs-context)
- Relevant proposition: a dependency result is one of `success`, `failure`, `cancelled`, or `skipped`.
- Application: post-merge evidence should explicitly require the expected `skipped` writer result on a no-drift T2 merge and separately cite T1's controlled write-path evidence for the writer implementation.
