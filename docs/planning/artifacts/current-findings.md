# Current findings

## Review scope

- `docs/planning/TerraformStyleGuide/03TerraformStyleGuideT1.md`
- `docs/planning/TerraformStyleGuide/04TerraformStyleGuideT2.md`
- Current `TerraformStyleGuide` implementation
- The parallel P1/P2 slate and current `PSStyleGuide` implementation where they inform cross-repository alignment

P1/P2 were treated as contextual material for the T1/T2 review. The closing section records the requested feedback to their drafter without importing Terraform-specific provider guidance into PSStyleGuide.

## Verified baseline

- T1 and T2 are correctly ordered: T1 is the implementation and workflow prerequisite for T2.
- TerraformStyleGuide currently lacks a root `.gitattributes` file.
- The current Terraform generator declares PowerShell 5.1 support and still uses four edition-sensitive `Set-Content -Encoding UTF8 -NoNewline` writes.
- The current Terraform build workflow remains path-filtered, grants workflow-level write permission, and uses unpinned major-version action tags.
- The current Terraform generator already constructs its frontmatter with an LF-joined array; T1 correctly preserves that repository-specific implementation.
- The current PSStyleGuide repository already has exactly `* text=auto eol=lf` in `.gitattributes`; P1 correctly does not recreate or broaden that change.
- The revised T1 has incorporated the major earlier corrections:
  - one versioned archive-validation helper shared by all executing push consumers;
  - explicit candidate-directory lifecycle;
  - precise directory and archive-metadata handling;
  - an independently testable propagated upload digest;
  - static/source evidence instead of an infeasible native digest-corruption drill;
  - deterministic malformed-archive fixtures;
  - an actual four-cell edition × EOL matrix;
  - per-edition local verification before another edition overwrites outputs.
- T2 correctly keeps provider discovery separate from recovery, avoids automatic version selection, uses guarded identifiers, and treats recovered state as sensitive.
- The exact pinned artifact-action implementations support the proposed retained-archive flow:
  - the upload action exposes the artifact digest and supports the proposed archive behavior;
  - the download action accepts an immutable artifact ID, supports `skip-decompress`, and can make a digest mismatch fatal.
- The current AWS, Azure, GCS, and HCP Terraform primary documentation supports T2's provider commands and its deliberate AWS KMS scope reconciliation.

## Findings affecting T1

### High: the writer's PowerShell remote-preflight example references the wrong variable

T1 currently prescribes:

```powershell
git ls-remote --exit-code --refs origin "$GITHUB_REF"
```

Inside PowerShell, GitHub environment variables are read through the `Env:` drive. The command must use `$env:GITHUB_REF`, or preferably the already-defined `$env:TARGET_REF` consistently through preflight, lease, and refspec construction. As written, `$GITHUB_REF` is an unrelated ordinary PowerShell variable and can be unset.

P1 already uses `$env:GITHUB_REF` correctly. Preserve that form there and carry the correction into T1.

### High: the new helper is not explicitly exercised before merge

The helper is new, security-sensitive production code, but the permanent suite is currently required only of push consumers. A pull request can therefore change or break the helper and pass pre-merge verification; the first execution of the helper can be the post-merge push.

Run the exact helper and its permanent suite in the pull-request topology as well:

- under `powershell` in the Windows PowerShell 5.1 cells;
- under `pwsh` in the PowerShell 7 Windows cells;
- under `pwsh` in the Ubuntu pull-request job.

Keep the push-consumer self-tests too: pre-merge coverage catches defects before merge, while use-time coverage protects the production transport path.

### High: helper execution is not unambiguously bound to each matrix cell's assigned edition

The matrix names `shell: powershell` for Desktop, `shell: pwsh` for Core, and also permits `pwsh` for edition-neutral fixture work. The steps requiring the selected shell are not explicit enough. An implementation could build fixtures and invoke the helper in `pwsh` in every cell while running only the generator under the assigned edition.

State that fixture construction and byte inspection may use `pwsh`, but every self-test call into the production helper and every production helper invocation must run under the cell's assigned shell. Add that statement to the topology, validation evidence, and acceptance criteria.

### Medium: the helper's checkout boundary and exhaustive enumeration need an implementation contract

The helper accepts three parameters but must prove that its input and destination are outside the checkout. T1 should identify the trusted checkout root used for that proof—for example, a fourth mandatory `CheckoutRoot` parameter or a root derived deterministically from the tracked helper's fixed location. Do not leave the root implicit in the current directory.

Also require exhaustive, literal enumeration for every “exactly” assertion. `Get-ChildItem` omits hidden entries unless `-Force` is used. Either prescribe `Get-ChildItem -LiteralPath ... -Force` or a compatible `.NET` filesystem-entry enumeration. The same enumeration must detect any existing destination leaf, including a dangling link or reparse-point entry, rather than relying only on an existence API that follows links.

### Low: classify both successful fixture cases explicitly

The suite contains:

- a normal valid archive; and
- a valid archive whose entry has symlink-like external attributes but must be extracted as a new ordinary file.

The subsequent wording refers to “each invalid fixture” and singular “the valid fixture.” List expected outcomes by fixture so that both successful cases are required to extract and be inspected, while all rejection cases must fail before destination creation.

## Findings affecting T2

### High: every destination preflight misses a dangling final symlink

Each provider block uses only:

```sh
if [ -e "$RECOVERY_PATH" ]; then
```

and HCP Terraform uses the equivalent test for `TFC_RESPONSE_PATH`. POSIX `test` resolves symlinks for `-e`; a dangling final symlink therefore returns false. A subsequent provider command can follow that link and create or overwrite its target, bypassing the intended fresh-file contract.

Every final-leaf preflight must reject both an existing resolved object and a link entry:

```sh
if [ -e "$RECOVERY_PATH" ] || [ -L "$RECOVERY_PATH" ]; then
```

Apply the same correction to `TFC_RESPONSE_PATH`. This is distinct from parent-directory symlink topology, which T2 intentionally leaves to the operator.

### High: HCP response-file creation does not match the stated no-overwrite assurance

The HCP example performs a non-atomic `-e` preflight and then uses `curl --output`, which overwrites an existing file. Unlike the AWS section, the HCP section does not clearly disclose and bound that race.

Do not use curl's `--no-clobber` as a drop-in fix: curl can select a numbered alternate filename rather than fail on the requested path. Prefer exclusive creation of the exact response path—for example, Bash noclobber redirection in the protected subshell, with explicit failure/partial-file handling—or explicitly state the same protected-parent/no-competing-writer operating assumption and limit the guarantee accordingly. Exclusive exact-path creation is the better match for the issue's “fresh protected response file” language.

### Medium: post-merge evidence contradicts the no-drift writer skip

T2 says every push consumer runs the suite and helper, then says `has_changes=false` and the writer skips. The later explanatory paragraph correctly says that this no-drift run does not execute the writer.

Change the post-merge evidence to say every **Windows push cell** runs the suite and production helper. Then state separately that the writer's helper integration is inherited from T1's controlled write-path evidence and static inspection.

## Feedback to the P1/P2 drafter

The slate is fundamentally sound and should remain sequential. P1 correctly treats the existing PSStyleGuide `.gitattributes` rule as a prerequisite rather than re-adding it, preserves repository-specific frontmatter work, uses `$env:GITHUB_REF` correctly, and avoids making either repository operationally depend on the other. P2 is focused, generic to all adopters, and correctly commits sources and generated artifacts together so its post-merge writer should skip.

Before filing, make these targeted corrections:

1. Add pull-request execution of the exact P1 helper/self-test on Ubuntu and under both Windows editions.
2. Say explicitly that helper calls—not just generator calls—run under the assigned matrix edition.
3. Define how the helper obtains the trusted checkout root, require exhaustive hidden-inclusive enumeration, and reject a destination leaf even when it is a dangling link/reparse point.
4. Classify the external-attributes fixture as a second successful case.
5. Replace “every push consumer ... on every run” with precise execution semantics:
   - every push matrix cell runs the suite and helper;
   - the synchronization job runs them whenever `has_changes=true`;
   - P2's no-drift post-merge run skips the synchronization job and relies on P1's controlled writer evidence.
6. Keep the Terraform provider-recovery details, including T2's shell-path corrections, out of P2; they are not part of the PowerShell blank-line documentation issue.

## Primary references

- [PowerShell `Get-ChildItem`](https://learn.microsoft.com/powershell/module/microsoft.powershell.management/get-childitem)
- [.NET `Directory.EnumerateFileSystemEntries`](https://learn.microsoft.com/dotnet/api/system.io.directory.enumeratefilesystementries)
- [POSIX `test`](https://pubs.opengroup.org/onlinepubs/9699919799.2016edition/utilities/test.html)
- [curl command-line options](https://curl.se/docs/manpage.html)
- [curl `--no-clobber` behavior and numbered destinations](https://curl.se/docs/CVE-2022-27778.html)
- [HCP Terraform state versions API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/state-versions)
- [AWS CLI `s3api get-object`](https://docs.aws.amazon.com/cli/latest/reference/s3api/get-object.html)
- [Azure CLI `az storage blob`](https://learn.microsoft.com/cli/azure/storage/blob)
- [Google Cloud Storage object versioning](https://cloud.google.com/storage/docs/object-versioning)
