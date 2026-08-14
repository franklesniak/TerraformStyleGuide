#Requires -Version 5.1

<#
.SYNOPSIS
Generates copilot-instructions.md, terraform.instructions.md, STYLE_GUIDE_CHAT.md, and STYLE_GUIDE_FULL.md from STYLE_GUIDE.md (and STYLE_GUIDE_RATIONALE.md).

.DESCRIPTION
This script reads STYLE_GUIDE.md and creates four derived files:
- copilot-instructions.md: A direct copy of STYLE_GUIDE.md for use as GitHub Copilot custom instructions in Terraform-only repositories
- terraform.instructions.md: A version with YAML frontmatter for GitHub Copilot file-specific instructions in multi-language repositories
- STYLE_GUIDE_CHAT.md: A chat-ready version with escaped triple backticks wrapped in a markdown code fence
- STYLE_GUIDE_FULL.md: A merged version combining STYLE_GUIDE.md with rationale content from STYLE_GUIDE_RATIONALE.md, designed for human consumption

.EXAMPLE
.\Generate-StyleGuideArtifacts.ps1

.NOTES
This script generates Terraform style guide artifacts for this repository.
Version: 1.0.20260814.0
#>

$script:strRepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '../..'))
function Get-StyleGuideFileSha256 {
    # .SYNOPSIS
    # Computes the SHA-256 digest of one file.
    #
    # .DESCRIPTION
    # Opens the literal file path for shared reading, hashes its complete byte
    # sequence, and returns lowercase hexadecimal text with no separators. File,
    # hashing, formatting, disposal, and parameter-binding failures propagate.
    #
    # .PARAMETER LiteralPath
    # Literal path to the file to hash. The function does not expand wildcards.
    #
    # .EXAMPLE
    # Get-StyleGuideFileSha256 -LiteralPath '.\STYLE_GUIDE.md'
    # # Returns the lowercase SHA-256 digest of STYLE_GUIDE.md.
    #
    # .EXAMPLE
    # $strDigest = Get-StyleGuideFileSha256 '.\copilot-instructions.md'
    # # Uses the internal positional contract and assigns one System.String.
    #
    # .INPUTS
    # None. This function does not accept pipeline input.
    #
    # .OUTPUTS
    # System.String. A lowercase 64-character SHA-256 digest.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the public API
    # surface. Parameters, return shape, and positional contract may change
    # without notice.
    #
    # Version: 1.0.20260814.0
    #
    # This function supports positional parameters
    # (internal-caller contract only; subject to change):
    #
    #   Position 0: LiteralPath
    param (
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath
    )

    $objStream = $null
    $objSha256 = $null
    try {
        $objStream = New-Object System.IO.FileStream(
            $LiteralPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read
        )
        $objSha256 = [System.Security.Cryptography.SHA256]::Create()
        return ([System.BitConverter]::ToString($objSha256.ComputeHash($objStream))).Replace('-', '').ToLowerInvariant()
    } finally {
        if ($null -ne $objSha256) {
            $objSha256.Dispose()
        }
        if ($null -ne $objStream) {
            $objStream.Dispose()
        }
    }
}

function Assert-StyleGuideOrdinaryPath {
    # .SYNOPSIS
    # Asserts that one path names an ordinary file or directory.
    #
    # .DESCRIPTION
    # Reads the path attributes and rejects a reparse point or link. The function
    # also requires the path type to equal the caller's File or Directory value.
    # It throws System.IO.IOException for an assertion failure. Attribute-read and
    # parameter-binding failures propagate.
    #
    # .PARAMETER LiteralPath
    # Literal path to inspect. The function does not expand wildcards.
    #
    # .PARAMETER ExpectedType
    # Required filesystem type. The accepted values are Directory and File.
    #
    # .EXAMPLE
    # Assert-StyleGuideOrdinaryPath -LiteralPath $script:strRepositoryRoot -ExpectedType 'Directory'
    # # Returns no success-stream object when the root is an ordinary directory.
    #
    # .EXAMPLE
    # Assert-StyleGuideOrdinaryPath '.\STYLE_GUIDE.md' 'File'
    # # Uses the internal positional contract and rejects a link or directory.
    #
    # .INPUTS
    # None. This function does not accept pipeline input.
    #
    # .OUTPUTS
    # None. A successful assertion writes no success-stream object.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the public API
    # surface. Parameters, return shape, and positional contract may change
    # without notice.
    #
    # Version: 1.0.20260814.0
    #
    # This function supports positional parameters
    # (internal-caller contract only; subject to change):
    #
    #   Position 0: LiteralPath
    #   Position 1: ExpectedType
    param (
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Directory', 'File')]
        [string]$ExpectedType
    )

    $objAttributes = [System.IO.File]::GetAttributes($LiteralPath)
    if (($objAttributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw [System.IO.IOException]::new('A link or reparse point is not permitted.')
    }

    $boolIsDirectory = (($objAttributes -band [System.IO.FileAttributes]::Directory) -ne 0)
    if (($ExpectedType -eq 'Directory' -and -not $boolIsDirectory) -or
        ($ExpectedType -eq 'File' -and $boolIsDirectory)) {
        throw [System.IO.IOException]::new('The path has an unexpected filesystem type.')
    }
}

function Assert-StyleGuideTrackedDestination {
    # .SYNOPSIS
    # Asserts that one destination leaf is the exact Git-tracked path.
    #
    # .DESCRIPTION
    # Resolves Git as an application and queries the repository index for the
    # destination leaf. The function requires native exit zero, one returned
    # record, and a case-sensitive path match. It throws System.IO.IOException
    # when the assertion fails. Resolution, invocation, and binding failures
    # propagate.
    #
    # .PARAMETER DestinationLeaf
    # Repository-root-relative leaf name of the destination artifact.
    #
    # .EXAMPLE
    # Assert-StyleGuideTrackedDestination -DestinationLeaf 'copilot-instructions.md'
    # # Returns no success-stream object when the exact path is index-tracked.
    #
    # .EXAMPLE
    # Assert-StyleGuideTrackedDestination 'STYLE_GUIDE_FULL.md'
    # # Uses the internal positional contract and rejects absence or case drift.
    #
    # .INPUTS
    # None. This function does not accept pipeline input.
    #
    # .OUTPUTS
    # None. A successful assertion writes no success-stream object.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the public API
    # surface. Parameters, return shape, and positional contract may change
    # without notice.
    #
    # Version: 1.0.20260814.0
    #
    # This function supports positional parameters
    # (internal-caller contract only; subject to change):
    #
    #   Position 0: DestinationLeaf
    param (
        [Parameter(Mandatory = $true)]
        [string]$DestinationLeaf
    )

    # Module-qualified. PowerShell resolves functions ahead of cmdlets, so an
    # unqualified Get-Command is itself interceptable by a function of that
    # name -- confirmed: with one defined, the unqualified call returned a
    # chosen path while the qualified call returned /usr/bin/git. CI is not
    # exposed, because the workflow starts this script with pwsh -NoProfile
    # -File in a fresh process, but a contributor running it inside an
    # existing session is. The workflow policy already refuses Get-Command in
    # the step that invokes this script, and the script it invokes should not
    # be doing what that rule forbids.
    $arrGitCommands = @(Microsoft.PowerShell.Core\Get-Command -Name 'git' -CommandType Application -ErrorAction Stop)
    if ($arrGitCommands.Count -eq 0) {
        throw [System.IO.IOException]::new('Git could not be resolved as an application.')
    }
    $strGitPath = $arrGitCommands[0].Source
    $arrTrackedPath = @(& $strGitPath --no-optional-locks -C $script:strRepositoryRoot ls-files --error-unmatch -- $DestinationLeaf 2>$null)
    $intGitExit = $LASTEXITCODE
    if ($intGitExit -ne 0 -or $arrTrackedPath.Count -ne 1 -or $arrTrackedPath[0] -cne $DestinationLeaf) {
        throw [System.IO.IOException]::new('The destination is not the one exact tracked path.')
    }
}

function Write-StyleGuideArtifact {
    # .SYNOPSIS
    # Publishes one complete style-guide artifact atomically.
    #
    # .DESCRIPTION
    # Binds the artifact identifier to one fixed destination, validates ordinary
    # paths and index tracking, creates a fresh sibling file, durably flushes the
    # complete BOM-less UTF-8 payload, and verifies its bytes and digest. It uses
    # File.Replace for an existing destination or non-overwriting File.Move for
    # an absent tracked destination. A pre-publication failure removes the sibling
    # when possible. The categorized exception reports cleanup failure or
    # replacement-state uncertainty when the closed result cannot be proved.
    #
    # .PARAMETER ArtifactId
    # Artifact identifier. Accepted values are copilot, terraform-instructions,
    # chat, and full.
    #
    # .PARAMETER DestinationPath
    # Fully qualified fixed destination path for the selected artifact.
    #
    # .PARAMETER Content
    # Complete text payload to encode and publish. Null is rejected; empty text is
    # accepted.
    #
    # .EXAMPLE
    # Write-StyleGuideArtifact -ArtifactId 'copilot' -DestinationPath $strCopilotFile -Content $strContent
    # # Publishes the complete Copilot payload and returns no success-stream object.
    #
    # .EXAMPLE
    # Write-StyleGuideArtifact 'chat' $strChatFile $strWrappedContent
    # # Uses the internal positional contract for the fixed chat destination.
    #
    # .INPUTS
    # None. This function does not accept pipeline input.
    #
    # .OUTPUTS
    # None. Success writes no success-stream object. Failure throws one
    # System.InvalidOperationException whose message identifies the artifact,
    # destination, phase, and one of access-denied, unsupported, invalid-input,
    # io-failure, cleanup-failure, replacement-state-uncertain, or
    # unexpected-failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the public API
    # surface. Parameters, return shape, and positional contract may change
    # without notice.
    #
    # Version: 1.0.20260814.0
    #
    # This function supports positional parameters
    # (internal-caller contract only; subject to change):
    #
    #   Position 0: ArtifactId
    #   Position 1: DestinationPath
    #   Position 2: Content
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('copilot', 'terraform-instructions', 'chat', 'full')]
        [string]$ArtifactId,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$DestinationPath,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Content
    )

    $hashtableArtifactLeaves = @{
        'copilot'                = 'copilot-instructions.md'
        'terraform-instructions' = 'terraform.instructions.md'
        'chat'                   = 'STYLE_GUIDE_CHAT.md'
        'full'                   = 'STYLE_GUIDE_FULL.md'
    }

    $strDestinationLeaf = $hashtableArtifactLeaves[$ArtifactId]
    $strExpectedPath = [System.IO.Path]::GetFullPath((Join-Path -Path $script:strRepositoryRoot -ChildPath $strDestinationLeaf))
    $strPhase = 'path-validation'
    $strTemporaryPath = $null
    $objTemporaryStream = $null
    $boolTemporaryCreated = $false
    $boolReplaceReturned = $false
    $boolDestinationExists = $false
    $intOriginalLength = $null
    $strOriginalSha256 = $null

    try {
        if ($null -eq $DestinationPath) {
            throw [System.ArgumentNullException]::new('DestinationPath')
        }
        if ($DestinationPath.Length -eq 0) {
            throw [System.ArgumentException]::new('The destination path is empty.')
        }
        if ($DestinationPath.Trim().Length -eq 0) {
            throw [System.ArgumentException]::new('The destination path is whitespace-only.')
        }
        foreach ($chrPath in $DestinationPath.ToCharArray()) {
            if ([char]::IsControl($chrPath) -or ([System.IO.Path]::GetInvalidPathChars() -contains $chrPath)) {
                throw [System.ArgumentException]::new('The destination path contains a control or malformed character.')
            }
        }
        if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($DestinationPath)) {
            throw [System.ArgumentException]::new('Wildcard syntax is not permitted.')
        }

        $boolIsWindows = ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
        $boolIsWindowsDrivePath = ($DestinationPath -match '^[A-Za-z]:[\\/]')
        if ($DestinationPath -match '^[^:]+::' -or
            (($DestinationPath -match '^[A-Za-z][A-Za-z0-9_-]*:') -and -not $boolIsWindowsDrivePath)) {
            throw [System.ArgumentException]::new('Provider-qualified syntax is not permitted.')
        }
        if (($boolIsWindows -and -not ($boolIsWindowsDrivePath -or $DestinationPath -match '^\\\\')) -or
            (-not $boolIsWindows -and -not $DestinationPath.StartsWith('/'))) {
            throw [System.ArgumentException]::new('The destination path is not fully qualified.')
        }

        $objProvider = $null
        $objDrive = $null
        $strResolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
            $DestinationPath,
            [ref]$objProvider,
            [ref]$objDrive
        )
        if ($null -eq $objProvider -or $objProvider.Name -cne 'FileSystem') {
            throw [System.ArgumentException]::new('Only the FileSystem provider is permitted.')
        }

        $strResolvedPath = [System.IO.Path]::GetFullPath($strResolvedPath)
        $objPathComparison = if ($boolIsWindows) {
            [System.StringComparison]::OrdinalIgnoreCase
        } else {
            [System.StringComparison]::Ordinal
        }
        if (-not [string]::Equals($strResolvedPath, $strExpectedPath, $objPathComparison)) {
            throw [System.ArgumentException]::new('The artifact ID and destination path do not match.')
        }
        if ($null -eq $Content) {
            throw [System.ArgumentNullException]::new('Content')
        }

        Assert-StyleGuideOrdinaryPath -LiteralPath $script:strRepositoryRoot -ExpectedType 'Directory'

        # A tracked artifact that has been deleted from the working tree is an
        # ordinary state -- a bad merge, a stray clean -- and the build
        # workflow's drift failure tells contributors to repair it by running
        # this generator. Asserting the destination is an existing ordinary file
        # before anything is written made that instruction unfollowable: the
        # run failed at path-validation and created nothing. So absence is now
        # a state this writer handles rather than a precondition it demands.
        #
        # Probed with GetAttributes, not FileInfo.LinkTarget. LinkTarget is
        # .NET 6 and later, while this script declares #Requires -Version 5.1,
        # and on Windows PowerShell 5.1 the property does not exist. That is
        # not a crash: this script sets no Set-StrictMode, and PowerShell
        # answers a missing property with $null rather than throwing --
        # confirmed on this runner -- so `$null -ne $objOriginalInfo.LinkTarget`
        # would have evaluated False for every path on 5.1 and skipped the link
        # rejection entirely. A guard that silently stops guarding on one
        # edition is worse than one that fails loudly.
        #
        # GetAttributes exists on every supported edition and separates the
        # three cases on its own -- also confirmed here: it throws
        # FileNotFoundException (or DirectoryNotFoundException, when a parent
        # is missing) for an absent path, and for a dangling symlink it
        # *returns* attributes carrying ReparsePoint rather than throwing. So a
        # link of either kind reaches Assert-StyleGuideOrdinaryPath below and is
        # refused there, and only genuine absence is treated as absence.
        $boolDestinationExists = $true
        try {
            [void][System.IO.File]::GetAttributes($strExpectedPath)
        } catch [System.IO.FileNotFoundException] {
            $boolDestinationExists = $false
        } catch [System.IO.DirectoryNotFoundException] {
            $boolDestinationExists = $false
        }
        $objOriginalInfo = $null
        if ($boolDestinationExists) {
            Assert-StyleGuideOrdinaryPath -LiteralPath $strExpectedPath -ExpectedType 'File'
            $objOriginalInfo = New-Object System.IO.FileInfo($strExpectedPath)
        }
        # Unconditional. git ls-files reads the index, not the working tree, so
        # a deleted artifact is still the one exact tracked path -- confirmed:
        # --error-unmatch exits 0 and returns the leaf for a deleted file. The
        # identity check the previous round added is therefore not weakened by
        # admitting absence; a path that was never tracked is still refused.
        Assert-StyleGuideTrackedDestination -DestinationLeaf $strDestinationLeaf
        $intOriginalLength = if ($boolDestinationExists) { $objOriginalInfo.Length } else { $null }
        $strOriginalSha256 = if ($boolDestinationExists) {
            Get-StyleGuideFileSha256 -LiteralPath $strExpectedPath
        } else {
            $null
        }

        $objUtf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $arrExpectedBytes = $objUtf8NoBom.GetBytes($Content)
        $objExpectedSha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $strExpectedSha256 = ([System.BitConverter]::ToString($objExpectedSha256.ComputeHash($arrExpectedBytes))).Replace('-', '').ToLowerInvariant()
        } finally {
            $objExpectedSha256.Dispose()
        }

        $strPhase = 'create'
        $intMaximumCreateAttempts = 16
        for ($intAttempt = 1; $intAttempt -le $intMaximumCreateAttempts; $intAttempt++) {
            $strRandomLeaf = '.style-guide-' + $ArtifactId + '-' + [System.IO.Path]::GetRandomFileName() + '.tmp'
            $strTemporaryPath = Join-Path -Path $script:strRepositoryRoot -ChildPath $strRandomLeaf
            try {
                $objTemporaryStream = New-Object System.IO.FileStream(
                    $strTemporaryPath,
                    [System.IO.FileMode]::CreateNew,
                    [System.IO.FileAccess]::Write,
                    [System.IO.FileShare]::None
                )
                $boolTemporaryCreated = $true
                break
            } catch [System.IO.IOException] {
                if (-not [System.IO.File]::Exists($strTemporaryPath) -or $intAttempt -eq $intMaximumCreateAttempts) {
                    throw
                }
                $strTemporaryPath = $null
            }
        }
        if ($null -eq $objTemporaryStream) {
            throw [System.IO.IOException]::new('Unable to reserve a temporary sibling.')
        }

        $strPhase = 'write-flush'
        try {
            $objTemporaryStream.Write($arrExpectedBytes, 0, $arrExpectedBytes.Length)
            $objTemporaryStream.Flush($true)
        } finally {
            $objTemporaryStream.Dispose()
            $objTemporaryStream = $null
        }

        $strPhase = 'verify'
        Assert-StyleGuideOrdinaryPath -LiteralPath $strTemporaryPath -ExpectedType 'File'
        $arrObservedBytes = [System.IO.File]::ReadAllBytes($strTemporaryPath)
        if ($arrObservedBytes.Length -ne $arrExpectedBytes.Length) {
            throw [System.IO.IOException]::new('The closed temporary file length does not match.')
        }
        for ($intByte = 0; $intByte -lt $arrExpectedBytes.Length; $intByte++) {
            if ($arrObservedBytes[$intByte] -ne $arrExpectedBytes[$intByte]) {
                throw [System.IO.IOException]::new('The closed temporary file bytes do not match.')
            }
        }
        if ($arrObservedBytes.Length -ge 3 -and
            $arrObservedBytes[0] -eq 0xEF -and
            $arrObservedBytes[1] -eq 0xBB -and
            $arrObservedBytes[2] -eq 0xBF) {
            throw [System.IO.IOException]::new('A UTF-8 byte-order mark is not permitted.')
        }
        if ($arrObservedBytes -contains 0x0D) {
            throw [System.IO.IOException]::new('A carriage-return byte is not permitted.')
        }
        $strObservedSha256 = Get-StyleGuideFileSha256 -LiteralPath $strTemporaryPath
        if ($strObservedSha256 -cne $strExpectedSha256) {
            throw [System.IO.IOException]::new('The closed temporary file digest does not match.')
        }

        Assert-StyleGuideOrdinaryPath -LiteralPath $script:strRepositoryRoot -ExpectedType 'Directory'
        if ($boolDestinationExists) {
            Assert-StyleGuideOrdinaryPath -LiteralPath $strExpectedPath -ExpectedType 'File'
        }
        Assert-StyleGuideOrdinaryPath -LiteralPath $strTemporaryPath -ExpectedType 'File'

        $strPhase = 'replace'
        if ($boolDestinationExists) {
            # NullString is the PowerShell 5.1-safe representation of a true null
            # reference for the optional File.Replace backup path.
            [System.IO.File]::Replace($strTemporaryPath, $strExpectedPath, [NullString]::Value)
        } else {
            # File.Replace requires an existing destination, so a first
            # appearance commits through Move instead. Move is the same
            # publish-by-rename and it refuses rather than overwrites when the
            # destination is occupied, so the interval between the absence test
            # far above and this call is closed by the call itself rather than
            # by a second check -- including against a dangling symlink, which
            # Move reports as already existing rather than writing through to
            # its target. Confirmed on this runner.
            [System.IO.File]::Move($strTemporaryPath, $strExpectedPath)
        }
        $boolReplaceReturned = $true
        $strTemporaryPath = $null
        return
    } catch {
        $objFailure = $_.Exception
        while ($null -ne $objFailure.InnerException -and
            $objFailure -is [System.Management.Automation.RuntimeException]) {
            $objFailure = $objFailure.InnerException
        }
        if ($boolReplaceReturned) {
            return
        }

        $strFailurePhase = $strPhase
        $strCategory = if ($objFailure -is [System.UnauthorizedAccessException]) {
            'access-denied'
        } elseif ($objFailure -is [System.NotSupportedException]) {
            'unsupported'
        } elseif ($objFailure -is [System.ArgumentException]) {
            'invalid-input'
        } elseif ($objFailure -is [System.IO.IOException]) {
            'io-failure'
        } else {
            'unexpected-failure'
        }

        if ($null -ne $objTemporaryStream) {
            try {
                $objTemporaryStream.Dispose()
            } catch {
                $strCategory = 'cleanup-failure'
            }
            $objTemporaryStream = $null
        }

        if ($boolTemporaryCreated -and $null -ne $strTemporaryPath -and [System.IO.File]::Exists($strTemporaryPath)) {
            try {
                Assert-StyleGuideOrdinaryPath -LiteralPath $strTemporaryPath -ExpectedType 'File'
                [System.IO.File]::Delete($strTemporaryPath)
                if ([System.IO.File]::Exists($strTemporaryPath)) {
                    throw [System.IO.IOException]::new('The temporary sibling remains after cleanup.')
                }
            } catch {
                $strCategory = 'cleanup-failure'
            }
        }

        if ($null -ne $strOriginalSha256 -and [System.IO.File]::Exists($strExpectedPath)) {
            try {
                $objCurrentInfo = New-Object System.IO.FileInfo($strExpectedPath)
                $strCurrentSha256 = Get-StyleGuideFileSha256 -LiteralPath $strExpectedPath
                if ($objCurrentInfo.Length -ne $intOriginalLength -or $strCurrentSha256 -cne $strOriginalSha256) {
                    $strCategory = 'replacement-state-uncertain'
                }
            } catch {
                $strCategory = 'replacement-state-uncertain'
            }
        } elseif ($null -ne $strOriginalSha256) {
            $strCategory = 'replacement-state-uncertain'
        }

        throw [System.InvalidOperationException]::new(
            "artifact=$ArtifactId; destination=$strDestinationLeaf; phase=$strFailurePhase; category=$strCategory"
        )
    }
}

function New-StyleGuideCopilotVersion {
    # .SYNOPSIS
    # Creates the Copilot style-guide artifact.
    #
    # .DESCRIPTION
    # Reads the complete Terraform style guide, normalizes carriage-return line
    # endings to LF, and atomically publishes the fixed Copilot artifact. The
    # function writes a visible information record after publication. It writes a
    # categorized error and returns one when transformation or publication fails.
    #
    # .PARAMETER SourcePath
    # Path to the source STYLE_GUIDE.md file.
    #
    # .PARAMETER DestinationPath
    # Path to the destination copilot-instructions.md file.
    #
    # .EXAMPLE
    # $intResult = New-StyleGuideCopilotVersion -SourcePath $strSourceFile -DestinationPath $strCopilotFile
    # # Publishes the artifact and returns 0, or writes an error and returns 1.
    #
    # .EXAMPLE
    # New-StyleGuideCopilotVersion $strSourceFile $strCopilotFile -WhatIf
    # # Uses the internal positional contract and returns 0 without publication.
    #
    # .INPUTS
    # None. This function does not accept pipeline input.
    #
    # .OUTPUTS
    # System.Int32. Returns 0 after publication or a caller-declined ShouldProcess
    # operation. Returns 1 after a transformation or publication failure and
    # writes the closed artifact category to the error stream.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the public API
    # surface. Parameters, return shape, and positional contract may change
    # without notice.
    #
    # Version: 1.0.20260814.0
    #
    # This function supports positional parameters
    # (internal-caller contract only; subject to change):
    #
    #   Position 0: SourcePath
    #   Position 1: DestinationPath
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    try {
        $strContent = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
        $strNormalizedContent = $strContent -replace "`r`n?", "`n"
        if (-not $PSCmdlet.ShouldProcess($DestinationPath, 'Publish generated style-guide artifact')) {
            return 0
        }
        Write-StyleGuideArtifact -ArtifactId 'copilot' -DestinationPath $DestinationPath -Content $strNormalizedContent
        Write-Information "Successfully created $DestinationPath" -InformationAction Continue
        return 0
    } catch {
        $strFailure = if ($_.Exception.Message -match '^artifact=') {
            $_.Exception.Message
        } else {
            'artifact=copilot; destination=copilot-instructions.md; phase=transform; category=unexpected-failure'
        }
        Write-Error $strFailure
        return 1
    }
}


function New-StyleGuideTerraformInstructionsVersion {
    # .SYNOPSIS
    # Creates the scoped Terraform-instructions artifact.
    #
    # .DESCRIPTION
    # Reads the complete Terraform style guide, prepends the fixed GitHub Copilot
    # YAML frontmatter, normalizes carriage-return line endings to LF, and
    # atomically publishes the fixed instructions artifact. The function writes a
    # visible information record after publication. It writes a categorized error
    # and returns one when transformation or publication fails.
    #
    # .PARAMETER SourcePath
    # Path to the source STYLE_GUIDE.md file.
    #
    # .PARAMETER DestinationPath
    # Path to the destination terraform.instructions.md file.
    #
    # .EXAMPLE
    # $intResult = New-StyleGuideTerraformInstructionsVersion -SourcePath $strSourceFile -DestinationPath $strTerraformInstructionsFile
    # # Publishes the frontmatter and guide payload, then returns 0.
    #
    # .EXAMPLE
    # New-StyleGuideTerraformInstructionsVersion $strSourceFile $strTerraformInstructionsFile -WhatIf
    # # Uses the internal positional contract and returns 0 without publication.
    #
    # .INPUTS
    # None. This function does not accept pipeline input.
    #
    # .OUTPUTS
    # System.Int32. Returns 0 after publication or a caller-declined ShouldProcess
    # operation. Returns 1 after a transformation or publication failure and
    # writes the closed artifact category to the error stream.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the public API
    # surface. Parameters, return shape, and positional contract may change
    # without notice.
    #
    # Version: 1.0.20260814.0
    #
    # This function supports positional parameters
    # (internal-caller contract only; subject to change):
    #
    #   Position 0: SourcePath
    #   Position 1: DestinationPath
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    try {
        $strContent = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
        
        # Define the YAML frontmatter with LF newlines so regenerated files stay
        # stable across Windows and POSIX runners.
        $strFrontmatter = @(
            '---'
            'applyTo: "**/*.tf,**/*.tfvars,**/*.tftest.hcl,**/*.tf.json,**/*.tftpl,**/*.tfbackend"'
            'description: "Terraform coding standards: secure, modular, and well-documented infrastructure as code."'
            '---'
            ''
            ''
        ) -join "`n"
        
        # Prepend frontmatter to content
        $strFullContent = $strFrontmatter + $strContent
        
        $strNormalizedContent = $strFullContent -replace "`r`n?", "`n"
        if (-not $PSCmdlet.ShouldProcess($DestinationPath, 'Publish generated style-guide artifact')) {
            return 0
        }
        Write-StyleGuideArtifact -ArtifactId 'terraform-instructions' -DestinationPath $DestinationPath -Content $strNormalizedContent
        Write-Information "Successfully created $DestinationPath" -InformationAction Continue
        return 0
    } catch {
        $strFailure = if ($_.Exception.Message -match '^artifact=') {
            $_.Exception.Message
        } else {
            'artifact=terraform-instructions; destination=terraform.instructions.md; phase=transform; category=unexpected-failure'
        }
        Write-Error $strFailure
        return 1
    }
}


function New-StyleGuideChatVersion {
    # .SYNOPSIS
    # Creates the chat-ready Terraform style-guide artifact.
    #
    # .DESCRIPTION
    # Reads the complete Terraform style guide, finds its longest backtick run,
    # and wraps the guide in a longer CommonMark fence with a minimum length of
    # four. It normalizes carriage-return line endings to LF and atomically
    # publishes the fixed chat artifact. The function writes a visible information
    # record after publication. It writes a categorized error and returns one when
    # transformation or publication fails.
    #
    # .PARAMETER SourcePath
    # Path to the source STYLE_GUIDE.md file.
    #
    # .PARAMETER DestinationPath
    # Path to the destination STYLE_GUIDE_CHAT.md file.
    #
    # .EXAMPLE
    # $intResult = New-StyleGuideChatVersion -SourcePath $strSourceFile -DestinationPath $strChatFile
    # # Publishes the fenced payload and returns 0, or returns 1 after failure.
    #
    # .EXAMPLE
    # New-StyleGuideChatVersion $strSourceFile $strChatFile -WhatIf
    # # Uses the internal positional contract and returns 0 without publication.
    #
    # .INPUTS
    # None. This function does not accept pipeline input.
    #
    # .OUTPUTS
    # System.Int32. Returns 0 after publication or a caller-declined ShouldProcess
    # operation. Returns 1 after a transformation or publication failure and
    # writes the closed artifact category to the error stream.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the public API
    # surface. Parameters, return shape, and positional contract may change
    # without notice.
    #
    # Version: 1.0.20260814.0
    #
    # This function supports positional parameters
    # (internal-caller contract only; subject to change):
    #
    #   Position 0: SourcePath
    #   Position 1: DestinationPath
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    try {
        $strContent = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
        
        # Trim trailing blank line from content before adding closing fence
        # This ensures the closing fence appears immediately after the last line of content
        $strContent = $strContent -replace '\r?\n$', ''
        
        # Find the maximum number of consecutive backticks in the content
        # The pattern '``+' matches one or more backticks (escaped as `` in PowerShell strings)
        $strBacktickPattern = '``+'
        $arrMatches = [regex]::Matches($strContent, $strBacktickPattern)
        $intMaxBackticks = 0
        if ($arrMatches.Count -gt 0) {
            $objMeasurement = $arrMatches | Measure-Object -Property Length -Maximum
            $intMaxBackticks = $objMeasurement.Maximum
        }
        
        # Use one more backtick than the maximum found to ensure the outer fence is longer
        # than any inner fence (per CommonMark spec). Minimum of 4 for readability and to
        # ensure proper nesting even if the content only has single or double backticks.
        $intOuterFenceLength = [Math]::Max(4, $intMaxBackticks + 1)
        $strOuterFence = '`' * $intOuterFenceLength
        
        # Wrap in markdown code fence with a heading and proper trailing newline
        # Add a top-level heading to satisfy MD041 (first-line-heading)
        # Add trailing newline after closing fence to satisfy MD047 (single-trailing-newline)
        $strWrappedContent = "# Terraform Writing Style Guide - Formatted for Copy-Paste Into LLM Chat`n`n$strOuterFence" + "markdown`n$strContent`n$strOuterFence`n"
        
        $strNormalizedContent = $strWrappedContent -replace "`r`n?", "`n"
        if (-not $PSCmdlet.ShouldProcess($DestinationPath, 'Publish generated style-guide artifact')) {
            return 0
        }
        Write-StyleGuideArtifact -ArtifactId 'chat' -DestinationPath $DestinationPath -Content $strNormalizedContent
        Write-Information "Successfully created $DestinationPath (using $intOuterFenceLength backticks for outer fence)" -InformationAction Continue
        return 0
    } catch {
        $strFailure = if ($_.Exception.Message -match '^artifact=') {
            $_.Exception.Message
        } else {
            'artifact=chat; destination=STYLE_GUIDE_CHAT.md; phase=transform; category=unexpected-failure'
        }
        Write-Error $strFailure
        return 1
    }
}


function New-StyleGuideFullVersion {
    # .SYNOPSIS
    # Creates the combined Terraform style-guide artifact.
    #
    # .DESCRIPTION
    # Reads the normative guide and rationale, indexes rationale sections by
    # Markdown anchor, and inserts matching rationale below each guide heading.
    # It removes cross-reference blockquotes, converts guide links to internal
    # anchors, normalizes the final payload to LF with one final newline, and
    # atomically publishes the fixed full artifact. The function writes a visible
    # information record after publication. It writes a categorized error and
    # returns one when transformation or publication fails.
    #
    # .PARAMETER SourcePath
    # Path to the source STYLE_GUIDE.md file.
    #
    # .PARAMETER RationalePath
    # Path to the source STYLE_GUIDE_RATIONALE.md file.
    #
    # .PARAMETER DestinationPath
    # Path to the destination STYLE_GUIDE_FULL.md file.
    #
    # .EXAMPLE
    # $intResult = New-StyleGuideFullVersion -SourcePath $strSourceFile -RationalePath $strRationaleFile -DestinationPath $strFullFile
    # # Publishes the combined guide and returns 0, or returns 1 after failure.
    #
    # .EXAMPLE
    # New-StyleGuideFullVersion $strSourceFile $strRationaleFile $strFullFile -WhatIf
    # # Uses the internal positional contract and returns 0 without publication.
    #
    # .INPUTS
    # None. This function does not accept pipeline input.
    #
    # .OUTPUTS
    # System.Int32. Returns 0 after publication or a caller-declined ShouldProcess
    # operation. Returns 1 after a transformation or publication failure and
    # writes the closed artifact category to the error stream.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the public API
    # surface. Parameters, return shape, and positional contract may change
    # without notice.
    #
    # Version: 1.0.20260814.0
    #
    # This function supports positional parameters
    # (internal-caller contract only; subject to change):
    #
    #   Position 0: SourcePath
    #   Position 1: RationalePath
    #   Position 2: DestinationPath
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$RationalePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    try {
        $strGuideContent = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
        $strRationaleContent = Get-Content -LiteralPath $RationalePath -Raw -Encoding UTF8

        # Parse rationale file into sections keyed by markdown anchor.
        # Only ### headings are collected (these are the leaf sections that map to
        # headings in STYLE_GUIDE.md). ## headings in the rationale file are grouping
        # headers (e.g., "## Naming Rationale") that do not exist in the main guide.
        $arrRationaleLines = $strRationaleContent -split '\r?\n'
        $hashtableSections = @{}
        $strCurrentAnchor = $null
        $intCurrentLevel = 0
        $listCurrentBody = [System.Collections.Generic.List[string]]::new()

        foreach ($strLine in $arrRationaleLines) {
            if ($strLine -match '^(#{2,4}) (.+)$') {
                $intLevel = $Matches[1].Length
                $strHeadingText = $Matches[2]

                # Save previous section if it was a ### heading
                if ($null -ne $strCurrentAnchor -and $intCurrentLevel -eq 3) {
                    $hashtableSections[$strCurrentAnchor] = $listCurrentBody.ToArray()
                }

                # Compute anchor for this heading
                $strAnchor = $strHeadingText.ToLower() -replace '[^a-z0-9 -]', '' -replace ' ', '-'
                $strAnchor = $strAnchor -replace '-+', '-' -replace '^-|-$', ''

                if ($intLevel -eq 3) {
                    # This is a leaf section -- collect its body
                    $strCurrentAnchor = $strAnchor
                    $intCurrentLevel = 3
                    $listCurrentBody = [System.Collections.Generic.List[string]]::new()
                } elseif ($intLevel -eq 2) {
                    # Grouping header -- reset tracking but do not collect
                    $strCurrentAnchor = $null
                    $intCurrentLevel = 2
                } else {
                    # #### sub-heading inside a ### section -- include as body content
                    if ($null -ne $strCurrentAnchor -and $intCurrentLevel -eq 3) {
                        $listCurrentBody.Add($strLine)
                    }
                }
            } elseif ($null -ne $strCurrentAnchor -and $intCurrentLevel -eq 3) {
                $listCurrentBody.Add($strLine)
            }
        }
        # Save final section if it was a ### heading
        if ($null -ne $strCurrentAnchor -and $intCurrentLevel -eq 3) {
            $hashtableSections[$strCurrentAnchor] = $listCurrentBody.ToArray()
        }

        # Also handle the ## Executive Summary: Author Profile which is a ## heading
        # but maps to a ## heading in the main guide. Parse it separately.
        $strCurrentAnchor = $null
        $intCurrentLevel = 0
        $listCurrentBody = [System.Collections.Generic.List[string]]::new()
        $boolInExecutiveSummary = $false

        foreach ($strLine in $arrRationaleLines) {
            if ($strLine -match '^## Executive Summary: Terraform Philosophy') {
                $boolInExecutiveSummary = $true
                $listCurrentBody = [System.Collections.Generic.List[string]]::new()
            } elseif ($boolInExecutiveSummary -and $strLine -match '^## ') {
                # Hit the next ## heading, stop collecting
                $hashtableSections['executive-summary-terraform-philosophy'] = $listCurrentBody.ToArray()
                $boolInExecutiveSummary = $false
            } elseif ($boolInExecutiveSummary) {
                $listCurrentBody.Add($strLine)
            }
        }
        if ($boolInExecutiveSummary) {
            $hashtableSections['executive-summary-terraform-philosophy'] = $listCurrentBody.ToArray()
        }

        # Clean each section body:
        # - Remove blockquote lines that link back to STYLE_GUIDE.md (cross-refs)
        # - Convert STYLE_GUIDE.md#anchor links to #anchor (internal)
        # - Trim leading and trailing blank lines
        $hashtableCleanSections = @{}
        foreach ($strKey in $hashtableSections.Keys) {
            $arrLines = $hashtableSections[$strKey]

            # Filter out cross-reference blockquotes pointing back to main guide.
            # Only remove "For ... see ... (STYLE_GUIDE.md#..." lines; preserve other
            # blockquotes (e.g., "> **Note:** ...") that happen to link to the main guide.
            $arrFiltered = @($arrLines | Where-Object {
                -not ($_ -match '^> For .+\(STYLE_GUIDE\.md#')
            })

            # Convert relative links to main guide into internal anchors
            $arrConverted = @($arrFiltered | ForEach-Object {
                $_ -replace 'STYLE_GUIDE\.md#', '#' -replace '\[([^\]]+)\]\(STYLE_GUIDE\.md\)', '[$1](#terraform-writing-style)'
            })

            # Trim leading and trailing blank lines and trailing horizontal rules
            $intStart = 0
            while ($intStart -lt $arrConverted.Count -and $arrConverted[$intStart].Trim() -eq '') {
                $intStart++
            }
            $intEnd = $arrConverted.Count - 1
            while ($intEnd -ge 0 -and ($arrConverted[$intEnd].Trim() -eq '' -or $arrConverted[$intEnd].Trim() -eq '---')) {
                $intEnd--
            }
            if ($intStart -le $intEnd) {
                $hashtableCleanSections[$strKey] = $arrConverted[$intStart..$intEnd]
            }
        }

        # Process the guide line by line, replacing RATIONALE markers with content
        # from the rationale document. Markers use the format:
        #   <!-- RATIONALE: anchor-key -->
        # where anchor-key matches the computed anchor of a ### heading in the
        # rationale file. Also remove placeholder lines that mark intentionally
        # blank sections, since the full version will have the actual rationale
        # content re-inserted by the merge.
        $strPlaceholder = '*This section intentionally left blank.*'
        $strMarkerPattern = '^\s*<!-- RATIONALE: (.+?) -->\s*$'
        $arrGuideLines = $strGuideContent -split '\r?\n'
        $listOutputLines = [System.Collections.Generic.List[string]]::new()

        for ($intIndex = 0; $intIndex -lt $arrGuideLines.Count; $intIndex++) {
            $strLine = $arrGuideLines[$intIndex]

            # Skip placeholder lines -- the rationale content replaces them
            if ($strLine.Trim() -eq $strPlaceholder) {
                continue
            }

            # Replace RATIONALE markers with corresponding rationale content
            if ($strLine -match $strMarkerPattern) {
                $strMarkerKey = $Matches[1]
                if ($hashtableCleanSections.ContainsKey($strMarkerKey)) {
                    $arrRationaleBody = $hashtableCleanSections[$strMarkerKey]
                    foreach ($strRatLine in $arrRationaleBody) {
                        $listOutputLines.Add($strRatLine)
                    }
                } else {
                    Write-Warning "No rationale section found for marker: $strMarkerKey"
                }
                continue
            }

            # Insert the executive summary TOC entry before the Terraform Version
            # Requirements TOC entry when the slim guide no longer contains it.
            if ($strLine -match '^\- \[Terraform Version Requirements\]' -and
                    $hashtableCleanSections.ContainsKey('executive-summary-terraform-philosophy')) {
                $boolTocAlreadyPresent = $false
                foreach ($strPrevLine in $listOutputLines) {
                    if ($strPrevLine -match 'Executive Summary: Terraform Philosophy') {
                        $boolTocAlreadyPresent = $true
                        break
                    }
                }
                if (-not $boolTocAlreadyPresent) {
                    $listOutputLines.Add('- [Executive Summary: Terraform Philosophy](#executive-summary-terraform-philosophy)')
                }
            }

            # Insert the executive summary section before Terraform Version
            # Requirements when the slim guide no longer contains the placeholder.
            # The heading and rationale body are injected so that STYLE_GUIDE_FULL.md
            # still includes the executive summary for human readers.
            if ($strLine -match '^## Terraform Version Requirements' -and
                    $hashtableCleanSections.ContainsKey('executive-summary-terraform-philosophy')) {
                # Only insert if the executive summary was not already emitted via a
                # RATIONALE marker (i.e., the slim guide no longer has the placeholder).
                $boolAlreadyEmitted = $false
                foreach ($strPrevLine in $listOutputLines) {
                    if ($strPrevLine -match '^## Executive Summary: Terraform Philosophy') {
                        $boolAlreadyEmitted = $true
                        break
                    }
                }
                if (-not $boolAlreadyEmitted) {
                    # Remove any trailing horizontal rule and surrounding blank
                    # lines that the slim guide placed before this heading. The
                    # executive summary will supply its own trailing rule, so
                    # keeping the pre-existing one would create a duplicate.
                    while ($listOutputLines.Count -gt 0 -and
                            ($listOutputLines[$listOutputLines.Count - 1].Trim() -eq '' -or
                             $listOutputLines[$listOutputLines.Count - 1].Trim() -eq '---')) {
                        $listOutputLines.RemoveAt($listOutputLines.Count - 1)
                    }
                    $listOutputLines.Add('')
                    $listOutputLines.Add('## Executive Summary: Terraform Philosophy')
                    $listOutputLines.Add('')
                    $arrRationaleBody = $hashtableCleanSections['executive-summary-terraform-philosophy']
                    foreach ($strRatLine in $arrRationaleBody) {
                        $listOutputLines.Add($strRatLine)
                    }
                    $listOutputLines.Add('')
                    $listOutputLines.Add('---')
                    $listOutputLines.Add('')
                }
            }

            $listOutputLines.Add($strLine)
        }

        # Append standalone ## sections from STYLE_GUIDE_RATIONALE.md that were
        # relocated from STYLE_GUIDE.md for token efficiency. These sections are
        # not injected via <!-- RATIONALE: ... --> markers because they are
        # top-level content (not rationale/justification for existing rules).
        # Skip: Table of Contents, Executive Summary (already injected above),
        # and "...Rationale" grouping headers (whose ### children are injected
        # via markers).
        $listStandaloneSections = [System.Collections.Generic.List[object]]::new()
        $strCurrentHeading = $null
        $listSectionLines = [System.Collections.Generic.List[string]]::new()

        foreach ($strLine in $arrRationaleLines) {
            if ($strLine -match '^## (.+)$') {
                # Save previous section if it was standalone
                if ($null -ne $strCurrentHeading) {
                    $listStandaloneSections.Add(@{
                        Heading = $strCurrentHeading
                        Lines   = $listSectionLines.ToArray()
                    })
                }
                $strCurrentHeading = $Matches[1]
                $listSectionLines = [System.Collections.Generic.List[string]]::new()
            } elseif ($null -ne $strCurrentHeading) {
                $listSectionLines.Add($strLine)
            }
        }
        if ($null -ne $strCurrentHeading) {
            $listStandaloneSections.Add(@{
                Heading = $strCurrentHeading
                Lines   = $listSectionLines.ToArray()
            })
        }

        # Determine which ## headings already exist in the output
        $arrExistingHeadings = @($listOutputLines | Where-Object {
            $_ -match '^## '
        } | ForEach-Object {
            ($_ -replace '^## ', '').Trim()
        })

        foreach ($objSection in $listStandaloneSections) {
            $strHeading = $objSection.Heading

            # Skip Table of Contents (rationale-specific navigation)
            if ($strHeading -eq 'Table of Contents') { continue }

            # Skip Executive Summary (already injected above)
            if ($strHeading -match '^Executive Summary') { continue }

            # Skip rationale grouping headers (their ### children are
            # injected via <!-- RATIONALE: ... --> markers)
            if ($strHeading -match 'Rationale$') { continue }

            # Skip if a ## heading with the same text already exists
            if ($arrExistingHeadings -contains $strHeading) { continue }

            # Append this standalone section
            $listOutputLines.Add('')
            $listOutputLines.Add("## $strHeading")

            # Apply the same filter/convert logic used for injected ### sections
            # so that STYLE_GUIDE_FULL.md remains self-contained with no cross-file links.
            $arrBody = $objSection.Lines

            # Filter out cross-reference blockquotes pointing back to main guide
            $arrBody = @($arrBody | Where-Object {
                -not ($_ -match '^> For .+\(STYLE_GUIDE\.md#')
            })

            # Convert relative links to main guide into internal anchors
            $arrBody = @($arrBody | ForEach-Object {
                $_ -replace 'STYLE_GUIDE\.md#', '#' -replace '\[([^\]]+)\]\(STYLE_GUIDE\.md\)', '[$1](#terraform-writing-style)'
            })

            # Trim leading blank lines from section body
            $intBodyStart = 0
            while ($intBodyStart -lt $arrBody.Count -and $arrBody[$intBodyStart].Trim() -eq '') {
                $intBodyStart++
            }
            # Trim trailing blank lines and horizontal rules
            $intBodyEnd = $arrBody.Count - 1
            while ($intBodyEnd -ge 0 -and ($arrBody[$intBodyEnd].Trim() -eq '' -or $arrBody[$intBodyEnd].Trim() -eq '---')) {
                $intBodyEnd--
            }
            if ($intBodyStart -le $intBodyEnd) {
                $listOutputLines.Add('')
                for ($intBodyLineIndex = $intBodyStart; $intBodyLineIndex -le $intBodyEnd; $intBodyLineIndex++) {
                    $listOutputLines.Add($arrBody[$intBodyLineIndex])
                }
            }
        }

        $strOutput = ($listOutputLines -join "`n")

        # Collapse runs of two or more consecutive blank lines to exactly one blank line.
        # In the joined string, one blank line = \n\n (end of previous line + empty line + 
        # start of next line is actually three \n). Two blank lines = \n\n\n.
        # We want to collapse \n\n\n (2+ blank lines) down to \n\n (1 blank line).
        while ($strOutput -match '\n\n\n') {
            $strOutput = $strOutput -replace '\n\n\n', "`n`n"
        }

        # Ensure single trailing newline
        $strOutput = $strOutput.TrimEnd("`n") + "`n"

        $strNormalizedContent = $strOutput -replace "`r`n?", "`n"
        if (-not $PSCmdlet.ShouldProcess($DestinationPath, 'Publish generated style-guide artifact')) {
            return 0
        }
        Write-StyleGuideArtifact -ArtifactId 'full' -DestinationPath $DestinationPath -Content $strNormalizedContent
        Write-Information "Successfully created $DestinationPath" -InformationAction Continue
        return 0
    } catch {
        $strFailure = if ($_.Exception.Message -match '^artifact=') {
            $_.Exception.Message
        } else {
            'artifact=full; destination=STYLE_GUIDE_FULL.md; phase=transform; category=unexpected-failure'
        }
        Write-Error $strFailure
        return 1
    }
}


# Main execution
$strSourceFile = Join-Path -Path $script:strRepositoryRoot -ChildPath 'STYLE_GUIDE.md'
$strRationaleFile = Join-Path -Path $script:strRepositoryRoot -ChildPath 'STYLE_GUIDE_RATIONALE.md'
$strCopilotFile = Join-Path -Path $script:strRepositoryRoot -ChildPath 'copilot-instructions.md'
$strTerraformInstructionsFile = Join-Path -Path $script:strRepositoryRoot -ChildPath 'terraform.instructions.md'
$strChatFile = Join-Path -Path $script:strRepositoryRoot -ChildPath 'STYLE_GUIDE_CHAT.md'
$strFullFile = Join-Path -Path $script:strRepositoryRoot -ChildPath 'STYLE_GUIDE_FULL.md'

# Verify both fixed sources are ordinary files before any destination mutation.
try {
    foreach ($strRequiredSource in @($strSourceFile, $strRationaleFile)) {
        if (-not (Test-Path -LiteralPath $strRequiredSource -PathType Leaf)) {
            throw [System.IO.FileNotFoundException]::new('A required fixed source is absent.')
        }
        Assert-StyleGuideOrdinaryPath -LiteralPath $strRequiredSource -ExpectedType 'File'
    }
} catch {
    Write-Error 'artifact=all; destination=closed-map; phase=source-validation; category=invalid-source'
    exit 1
}

# Generate copilot-instructions.md
$intCopilotResult = New-StyleGuideCopilotVersion -SourcePath $strSourceFile -DestinationPath $strCopilotFile
if ($intCopilotResult -ne 0) {
    exit 1
}

# Generate terraform.instructions.md
$intTerraformInstructionsResult = New-StyleGuideTerraformInstructionsVersion -SourcePath $strSourceFile -DestinationPath $strTerraformInstructionsFile
if ($intTerraformInstructionsResult -ne 0) {
    exit 1
}

# Generate STYLE_GUIDE_CHAT.md
$intChatResult = New-StyleGuideChatVersion -SourcePath $strSourceFile -DestinationPath $strChatFile
if ($intChatResult -ne 0) {
    exit 1
}

# Generate STYLE_GUIDE_FULL.md
$intFullResult = New-StyleGuideFullVersion -SourcePath $strSourceFile -RationalePath $strRationaleFile -DestinationPath $strFullFile
if ($intFullResult -ne 0) {
    exit 1
}

Write-Information "All style guide artifacts generated successfully" -InformationAction Continue
exit 0
