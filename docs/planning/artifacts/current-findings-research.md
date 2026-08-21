# TerraformStyleGuide current-finding research

## Local evidence

- T1A requested change 1 says an exact-cardinality enumeration stops after
  `N + 1` entries and does not materialize the directory.
- T1A candidate cleanup still says the `NotCreated` transition materializes
  the complete immediate-entry collection.
- T1A names two harness-only proof classes but does not name or enumerate their
  promised manifest.
- T3 and T4 are token-equivalent to the prior fixed-point versions after
  removal of whitespace and the new MD013 directive.

## Primary sources

### Streaming filesystem enumeration

- Source:
  [Microsoft Learn — Directory.GetFileSystemEntries remarks](https://learn.microsoft.com/en-us/dotnet/api/system.io.directory.getfilesystementries?view=netframework-4.8.1)
- Durable fact: `EnumerateFileSystemEntries` exposes results before the whole
  collection is returned. `GetFileSystemEntries` waits for and returns the
  complete array.
- Application: exact-cardinality checks can stop after `N + 1` results.
  Absence checks may need to consume the enumeration, but they do not need to
  retain every result.

### Deferred and bounded sequence consumption

- Source:
  [Microsoft Learn — Enumerable class](https://learn.microsoft.com/en-us/dotnet/api/system.linq.enumerable)
- Durable facts: sequence-returning LINQ operations use deferred execution, and
  `Take` returns a specified number of leading elements.
- Application: a proof must distinguish a lazily bounded consumer from a call
  that first converts the full filesystem sequence to an array or list.

### PowerShell syntax-tree inspection

- Source:
  [Microsoft Learn — Parser.ParseFile](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.language.parser.parsefile)
- Durable facts: `ParseFile` returns a `ScriptBlockAst`, tokens, and parse
  errors. Microsoft documents it for Windows PowerShell 5.1 and PowerShell 7.
- Application: the harness can bind its static proof to the exact supplied
  production script on every required edition. Runtime trace and mutant
  controls remain necessary because syntax presence alone does not prove that
  the guard executes.

## Verification boundary

No T1A implementation exists on this planning branch, so this pass cannot
execute the future production enumeration or race harness. The issue must
therefore freeze the proof contract and require the later implementation pull
request to record exact commands, runtime identities, results, and script
hashes.
