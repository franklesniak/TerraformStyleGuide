# Research — same-process PowerShell edition validation

Retrieved and checked 2026-07-29.

## Edition identity

Primary source:

- <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_editions>

Durable facts:

- In PowerShell 5.1 and later, `$PSVersionTable.PSEdition` identifies the
  running edition.
- Expected values are `Desktop` for Windows PowerShell 5.1 and `Core` for
  PowerShell 7.
- `$PSVersionTable.PSVersion` provides the running semantic version components.

## Child command execution

Primary sources:

- <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pwsh>
- <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_exe?view=powershell-5.1>

Durable facts:

- Both CLIs support `-NoProfile` and `-Command`.
- When PowerShell launches `pwsh`, `-Command` can receive a `ScriptBlock`
  object from the parent PowerShell host.
- A terminating error in `-Command` returns failure; preserving a specific
  nested script/native exit code requires an explicit `exit $LASTEXITCODE`.
- `-EncodedCommand` is available in both and uses Base64 over UTF-16LE command
  text when complex quoting makes it preferable.
- `-CommandWithArgs` is newer and is not a Windows PowerShell 5.1
  common-denominator mechanism.

## Design consequence

The local T1 validation should put its edition/version assertion and target
script invocation in the same `-Command` child. A separate version probe is
only indirect evidence. The child must explicitly propagate failures and the
parent must inspect `$LASTEXITCODE` immediately.
