# Research — held-stream digest and ZIP identity

Retrieved and checked 2026-07-29.

## PowerShell `Get-FileHash`

Primary source:

- <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash?view=powershell-5.1>

Facts retained for later issue editing:

- Windows PowerShell 5.1 documents a `Stream` parameter set:
  `Get-FileHash -InputStream <Stream> [-Algorithm <String>]`.
- `InputStream` is mandatory in that parameter set and accepts
  `System.IO.Stream`.
- SHA-256 is supported and is the default.
- Microsoft demonstrates resetting a `MemoryStream` to position zero before
  hashing. The same seek/reset principle applies when the stream will be
  consumed again after hashing.

## .NET file opening and sharing

Primary sources:

- <https://learn.microsoft.com/en-us/dotnet/api/system.io.file.open>
- <https://learn.microsoft.com/en-us/dotnet/api/system.io.fileshare>

Facts retained for later issue editing:

- `File.Open(String, FileMode, FileAccess, FileShare)` returns one
  `FileStream` with an explicit mode, access, and sharing contract.
- `FileShare.Read` permits subsequent read opens but does not grant subsequent
  write access. It is suitable for allowing benign readers while the helper
  keeps the exact archive stream alive.
- `FileShare.None` denies all sharing and is stronger operational exclusion,
  but can introduce avoidable contention with benign readers.
- Sharing behavior is part of the file-open contract; it is not a substitute
  for path containment, component validation, or the protected
  no-competing-writer model.

## Design consequence

The strongest portable T1 contract available through APIs supported by both
target PowerShell editions is:

1. validate the path envelope;
2. open once with `FileMode.Open`, `FileAccess.Read`, `FileShare.Read`;
3. hash that stream;
4. rewind that same stream;
5. construct one read-mode `ZipArchive` over it; and
6. keep it continuously alive until archive processing is complete.

Path hashing followed by a later path open does not establish that both
operations saw the same filesystem object.
