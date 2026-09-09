# .SYNOPSIS
# Verifies Codex capacity and shared Claude/Codex instruction capabilities.
#
# .DESCRIPTION
# Confirms that AGENTS.md fits the ordinary Codex limit, that trusted project
# configuration adds reserve and enables the preferred GitHub plugin, that both
# entry points retain portable review, placement, and deferral contracts, and
# that platform safety markers remain present. Optional self-tests prove that
# representative mutations fail closed.
#
# .PARAMETER SelfTest
# Runs in-memory negative tests after the repository files pass validation.
#
# .PARAMETER InputRevision
# The optional Git commit whose governed files are validation inputs. The
# validator and its executable dependencies still come from the checked-out
# trusted revision.
#
# .PARAMETER RangeBaseRevision
# The first excluded commit in an optional CI event range.
#
# .PARAMETER RangeHeadRevision
# The last included commit in an optional CI event range.
#
# .PARAMETER RangeIsNewRef
# Indicates that a push created the ref and RangeBaseRevision is Git's
# all-zero no-prior-ref sentinel.
#
# .EXAMPLE
# & ./.github/workflows/Test-AgentInstructions.ps1 -SelfTest
#
# # Validates the repository files and runs the mutation self-tests.
#
# .INPUTS
# None. You can't pipe objects to this script.
#
# .OUTPUTS
# [string] Success records for repository validation and optional self-tests.
#
# .NOTES
# This script does not support positional parameters.
# This validator keeps explicit backtick continuations so that large
# named-parameter mutation calls remain auditable one argument per line.
# Private helpers have focused examples. The -SelfTest suite covers edge cases.
# Version: 1.2.20260909.0

[CmdletBinding(PositionalBinding = $false)]
[OutputType([string])]
param(
    [Parameter()]
    [switch] $SelfTest,

    [Parameter()]
    [AllowEmptyString()]
    [string] $InputRevision = '',

    [Parameter()]
    [AllowEmptyString()]
    [string] $RangeBaseRevision = '',

    [Parameter()]
    [AllowEmptyString()]
    [string] $RangeHeadRevision = '',

    [Parameter()]
    [switch] $RangeIsNewRef
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$intAgentsMaximumInputBytes = 32768
$intClaudeMaximumInputBytes = 131072
$intCodexConfigMaximumInputBytes = 65536
$intDocsInstructionsMaximumInputBytes = 131072
$intInstructionDocumentMaximumInputBytes = 131072
$intValidatorMaximumInputBytes = 524288
$intMetadataMaximumParents = 64
$strMetadataRangePolicyMarker = 'metadata-range-transition-policy-v1'
$script:objValidationUtcNow = [DateTimeOffset]::UtcNow
$script:strMaximumMetadataUtcDate = $script:objValidationUtcNow.ToString('yyyy-MM-dd')
$script:objMaximumCommitUtcTimestamp = $script:objValidationUtcNow.AddMinutes(5)
$script:objPython312CommandContext = $null
$script:objNodeApplicationContext = $null
$script:strHuskyHookSha256 =
    '8989ab5075c077599a6dea88e656ac2837af4800e0bb5daef364514f00255467'
$script:strWorkflowPolicyCommandPrefix =
    'node .github/workflows/Validate-WorkflowPolicy.mjs'
$script:strWorkflowPolicyCommand = $script:strWorkflowPolicyCommandPrefix +
    ' .github/workflows/build.yml .github/workflows/markdownlint.yml'
$script:hashtableLegacyMetadataParentSha256 = @{
    'CLAUDE.md' = '28e77152391d51aed5ba93c59ed79af7f5c516d5ee0f1af2ce13cd4842e26387'
}
$script:arrAllowedMetadataStatuses = @(
    'Draft', 'Proposed', 'Active', 'Accepted', 'Superseded', 'Deprecated'
)
$script:arrCheckoutAttributePaths = @(
    '.gitattributes',
    '.github/.gitattributes',
    '.github/workflows/.gitattributes'
)
$script:arrTrustRootPaths = @(
    $script:arrCheckoutAttributePaths
    '.github/workflows/Test-AgentInstructions.ps1',
    '.github/workflows/Test-AgentInstructionParserManifest.mjs',
    '.github/workflows/agent-instructions.yml'
)
$script:strStandingPlacementAuthorization =
    'No additional per-round, per-session, or PR-specific direct-push authorization from the owner is required.'
$script:arrPlacementStructuralLiterals = @(
    '**Standing placement authorization.**',
    '**Outgoing-range audit.**'
)
$script:arrPlacementProseLiterals = @(
    'The agent MUST NOT ask the owner for that additional authorization.',
    'same repository',
    'non-destructive',
    'inspect the outgoing range',
    'each commit and changed path',
    'clean descendant',
    'higher-priority',
    'one authenticated readback',
    'Outside an active'
)
$script:arrSharedStructuralLiterals = @(
    '`reviewThreads`',
    '`isResolved == false`',
    '`commit_id == <round-head>`',
    'review:<review-id>:<section-label>:<ordinal>'
)
$script:arrSharedProseLiterals = @(
    '"generated N comment(s)"',
    'review-body-only finding',
    'accepted residual',
    'intentional deviation',
    'every review-submission body',
    'every PR-level comment',
    'weighted rubric',
    'ASD-STE100',
    'synthetic key',
    'GitHub Issue',
    'owner authorization',
    'current-head',
    'at least 60 seconds',
    'mutation-test',
    'PR body',
    'both reviewers',
    'one active task record',
    'one final validation record',
    'targeted remote readback',
    'Do not request another approval for an on-plan merge.'
)
$script:arrSafetyLimitContracts = @(
    [pscustomobject]@{
        DocumentName = 'AGENTS.md'
        StructuralLiteral = '- **Maximum rounds:** 8 review iterations per cycle invocation.'
        ProseLiteral = 'Maximum rounds: 8 review iterations per cycle invocation.'
        WeakStructuralLiteral = '- **Maximum rounds:** 80 review iterations per cycle invocation.'
        Failure = 'AGENTS.md is missing required Codex marker: **Maximum rounds:** 8'
    },
    [pscustomobject]@{
        DocumentName = 'AGENTS.md'
        StructuralLiteral = '- **Wall-clock timeout:** 6 hours from cycle start.'
        ProseLiteral = 'Wall-clock timeout: 6 hours from cycle start.'
        WeakStructuralLiteral = '- **Wall-clock timeout:** 60 hours from cycle start.'
        Failure = 'AGENTS.md is missing the 6-hour Codex wall-clock limit.'
    },
    [pscustomobject]@{
        DocumentName = 'CLAUDE.md'
        StructuralLiteral = '- **Maximum rounds:** 80 review iterations per loop invocation.'
        ProseLiteral = 'Maximum rounds: 80 review iterations per loop invocation.'
        WeakStructuralLiteral = '- **Maximum rounds:** 800 review iterations per loop invocation.'
        Failure = 'CLAUDE.md is missing the 80-round Claude limit.'
    },
    [pscustomobject]@{
        DocumentName = 'CLAUDE.md'
        StructuralLiteral = '- **Wall-clock timeout:** 6 hours from loop start.'
        ProseLiteral = 'Wall-clock timeout: 6 hours from loop start.'
        WeakStructuralLiteral = '- **Wall-clock timeout:** 60 hours from loop start.'
        Failure = 'CLAUDE.md is missing the 6-hour Claude wall-clock limit.'
    }
)
$script:arrObsoletePlacementLiterals = @(
    'Direct PR-head push (only with explicit user authorization)',
    'explicitly authorized direct PR-head pushes for this specific PR within the current Codex session'
)
$script:arrStyleGuideRoutingLiterals = @(
    'For an inline finding, post the prompt as a reply in the same review thread.',
    'For a review-body-only finding, post the prompt as a standalone PR-level comment that cites its synthetic key, source review, reviewed commit, and location when available.'
)
$script:arrAgentsTechnicalCodeSpans = @(
    'chatgpt-codex-connector[bot]',
    '@codex review',
    'Generated with Codex'
)
$script:arrClaudeTechnicalCodeSpans = @(
    '@codex review',
    '@claude resume review loop'
)
$script:strClaudeTechnicalProse = 'review-readiness gate'
$script:arrAgentsNormativeProseContracts = @(
    [pscustomobject]@{
        Literal = 'one at a time'
        OwnerKind = 'ProseBlock'
        OwnerPrefix = 'For each finding received from GitHub Copilot'
    },
    [pscustomobject]@{
        Literal = 'permutations'
        OwnerKind = 'ListItem'
        OwnerPrefix = 'List options. Enumerate'
    },
    [pscustomobject]@{
        Literal = 'Before posting, verify that all required artifacts are present.'
        OwnerKind = 'ListItem'
        OwnerPrefix = 'Post the evaluation. Reply to an inline thread.'
    }
)
$script:strOnlyGenuineDeferredWork = 'Only genuine deferred work requires a GitHub Issue.'
$script:arrObsoleteDeferralLiterals = @(
    'If this comment''s outcome is anything other than a fix **completed in this PR**'
)

#region Private helper functions

function ConvertFrom-StrictUtf8Data {
    # .SYNOPSIS
    # Decodes trusted bytes as strict UTF-8 without a byte-order mark.
    #
    # .DESCRIPTION
    # Rejects known byte-order marks and invalid UTF-8 byte sequences before it
    # returns decoded text.
    #
    # .PARAMETER Bytes
    # The bytes to validate and decode.
    #
    # .PARAMETER DisplayName
    # The input name to include in validation failures.
    #
    # .EXAMPLE
    # ConvertFrom-StrictUtf8Data -Bytes $arrBytes -DisplayName 'AGENTS.md'
    #
    # # Returns the decoded text or throws an invalid-data exception.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] The decoded UTF-8 text.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.1.20260820.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [byte[]] $Bytes,

        [Parameter(Mandatory)]
        [string] $DisplayName
    )

    $arrByteOrderMarks = @(
        [byte[]] @(0xEF, 0xBB, 0xBF),
        [byte[]] @(0xFF, 0xFE, 0x00, 0x00),
        [byte[]] @(0x00, 0x00, 0xFE, 0xFF),
        [byte[]] @(0xFF, 0xFE),
        [byte[]] @(0xFE, 0xFF)
    )
    foreach ($arrByteOrderMark in $arrByteOrderMarks) {
        if ($Bytes.Length -lt $arrByteOrderMark.Length) {
            continue
        }

        $boolHasByteOrderMark = $true
        for ($intByteIndex = 0; $intByteIndex -lt $arrByteOrderMark.Length; $intByteIndex++) {
            if ($Bytes[$intByteIndex] -ne $arrByteOrderMark[$intByteIndex]) {
                $boolHasByteOrderMark = $false
                break
            }
        }
        if ($boolHasByteOrderMark) {
            throw [System.IO.InvalidDataException]::new(
                "$DisplayName must contain valid UTF-8 without a BOM."
            )
        }
    }

    try {
        return [System.Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
    }
    catch [System.Text.DecoderFallbackException] {
        throw [System.IO.InvalidDataException]::new(
            "$DisplayName must contain valid UTF-8 without a BOM.",
            $_.Exception
        )
    }
}

function Assert-EncodingMutationRejected {
    # .SYNOPSIS
    # Confirms that an invalid encoding fixture fails closed.
    #
    # .DESCRIPTION
    # Decodes the supplied fixture and verifies the exact invalid-data failure.
    # The expected failure is handled and does not escape this helper.
    #
    # .PARAMETER Name
    # The fixture name to include in failure messages.
    #
    # .PARAMETER Bytes
    # The invalid encoded bytes to test.
    #
    # .EXAMPLE
    # Assert-EncodingMutationRejected -Name 'UTF-8 BOM' -Bytes $arrBytes
    #
    # # Returns no output when the fixture is rejected as expected.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # None.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [byte[]] $Bytes
    )

    try {
        [void](ConvertFrom-StrictUtf8Data -Bytes $Bytes -DisplayName $Name)
        throw "Self-test '$Name' was accepted."
    }
    catch [System.IO.InvalidDataException] {
        $strExpectedMessage = "$Name must contain valid UTF-8 without a BOM."
        if ($_.Exception.Message -cne $strExpectedMessage) {
            throw "Self-test '$Name' returned an unexpected failure: $($_.Exception.Message)"
        }
    }
}

function Get-RepositoryInputMetadataFailure {
    # .SYNOPSIS
    # Finds unsafe repository-input metadata.
    #
    # .DESCRIPTION
    # Validates the Git index and worktree metadata for one governed input and
    # writes one failure string for each unsafe condition.
    #
    # .PARAMETER DisplayName
    # The input name to include in failure records.
    #
    # .PARAMETER GitIndexEntryCount
    # The number of Git index entries for the input.
    #
    # .PARAMETER GitMode
    # The Git file mode, or null when it cannot be parsed.
    #
    # .PARAMETER GitStage
    # The Git index stage, or null when it cannot be parsed.
    #
    # .PARAMETER IsFileInfo
    # Indicates whether the worktree object is a regular file.
    #
    # .PARAMETER Attributes
    # The worktree file attributes.
    #
    # .PARAMETER LinkType
    # The PowerShell link type, when the provider exposes one.
    #
    # .PARAMETER UnixMode
    # The Unix mode string, when the provider exposes one.
    #
    # .EXAMPLE
    # Get-RepositoryInputMetadataFailure -DisplayName 'AGENTS.md' `
    #     -GitIndexEntryCount 1 -GitMode '100644' -GitStage '0' `
    #     -IsFileInfo $true -Attributes Normal
    #
    # # Writes no records for safe metadata.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each metadata failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $DisplayName,

        [Parameter(Mandatory)]
        [int] $GitIndexEntryCount,

        [Parameter()]
        [AllowNull()]
        [string] $GitMode,

        [Parameter()]
        [AllowNull()]
        [string] $GitStage,

        [Parameter(Mandatory)]
        [bool] $IsFileInfo,

        [Parameter(Mandatory)]
        [System.IO.FileAttributes] $Attributes,

        [Parameter()]
        [AllowEmptyString()]
        [string] $LinkType = '',

        [Parameter()]
        [AllowEmptyString()]
        [string] $UnixMode = ''
    )

    if ($GitIndexEntryCount -ne 1) {
        Write-Output "$DisplayName must have exactly one Git index entry."
    }
    elseif (($GitMode -cne '100644') -or ($GitStage -cne '0')) {
        Write-Output "$DisplayName must be a stage-0 regular file with Git mode 100644."
    }

    if (-not $IsFileInfo) {
        Write-Output "$DisplayName must be a regular worktree file."
    }
    if (($Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        Write-Output "$DisplayName must not be a symbolic link or reparse point."
    }
    if (-not [string]::IsNullOrEmpty($LinkType)) {
        Write-Output "$DisplayName must not have a link type."
    }
    if ((-not [string]::IsNullOrEmpty($UnixMode)) -and ($UnixMode[0] -cne '-')) {
        Write-Output "$DisplayName must have a regular Unix file type."
    }
}

function Assert-RepositoryInputMetadataMutationRejected {
    # .SYNOPSIS
    # Confirms that an unsafe metadata fixture fails closed.
    #
    # .DESCRIPTION
    # Evaluates one repository metadata fixture and verifies that it produces the
    # specified failure. The expected validation result does not escape.
    #
    # .PARAMETER Name
    # The fixture name and input display name.
    #
    # .PARAMETER GitIndexEntryCount
    # The simulated number of Git index entries.
    #
    # .PARAMETER GitMode
    # The simulated Git file mode.
    #
    # .PARAMETER GitStage
    # The simulated Git index stage.
    #
    # .PARAMETER IsFileInfo
    # Indicates whether the simulated worktree object is a regular file.
    #
    # .PARAMETER Attributes
    # The simulated worktree file attributes.
    #
    # .PARAMETER LinkType
    # The simulated PowerShell link type.
    #
    # .PARAMETER UnixMode
    # The simulated Unix mode string.
    #
    # .PARAMETER ExpectedFailure
    # The exact failure that the fixture must produce.
    #
    # .EXAMPLE
    # Assert-RepositoryInputMetadataMutationRejected -Name 'symlink' `
    #     -Attributes ReparsePoint `
    #     -ExpectedFailure 'symlink must not be a symbolic link or reparse point.'
    #
    # # Returns no output when the fixture is rejected as expected.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # None.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter()]
        [int] $GitIndexEntryCount = 1,

        [Parameter()]
        [AllowNull()]
        [string] $GitMode = '100644',

        [Parameter()]
        [AllowNull()]
        [string] $GitStage = '0',

        [Parameter()]
        [bool] $IsFileInfo = $true,

        [Parameter()]
        [System.IO.FileAttributes] $Attributes = [System.IO.FileAttributes]::Normal,

        [Parameter()]
        [AllowEmptyString()]
        [string] $LinkType = '',

        [Parameter()]
        [AllowEmptyString()]
        [string] $UnixMode = '',

        [Parameter(Mandatory)]
        [string] $ExpectedFailure
    )

    $arrFailures = @(Get-RepositoryInputMetadataFailure `
            -DisplayName $Name `
            -GitIndexEntryCount $GitIndexEntryCount `
            -GitMode $GitMode `
            -GitStage $GitStage `
            -IsFileInfo $IsFileInfo `
            -Attributes $Attributes `
            -LinkType $LinkType `
            -UnixMode $UnixMode)
    if ($arrFailures.Count -eq 0) {
        throw "Self-test '$Name' was accepted."
    }
    if (-not ($arrFailures -ccontains $ExpectedFailure)) {
        throw "Self-test '$Name' returned an unexpected failure: $($arrFailures -join '; ')"
    }
}

function Read-BoundedStreamData {
    # .SYNOPSIS
    # Reads a stream through a strict byte limit.
    #
    # .DESCRIPTION
    # Reads at most one byte beyond the configured limit so that oversized input
    # fails before the complete input is buffered.
    #
    # .PARAMETER Stream
    # The readable stream. The caller remains responsible for disposal.
    #
    # .PARAMETER MaximumBytes
    # The largest accepted byte count.
    #
    # .PARAMETER DisplayName
    # The input name to include in validation failures.
    #
    # .EXAMPLE
    # $arrBytes = @(Read-BoundedStreamData -Stream $objStream `
    #     -MaximumBytes 32768 -DisplayName 'AGENTS.md')
    #
    # # Collects the streamed bytes when the limit is not exceeded.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [byte] Each byte read from the stream.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([byte])]
    param(
        [Parameter(Mandatory)]
        [System.IO.Stream] $Stream,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483646)]
        [int] $MaximumBytes,

        [Parameter(Mandatory)]
        [string] $DisplayName
    )

    $arrBuffer = [byte[]]::new(8192)
    $objOutputStream = [System.IO.MemoryStream]::new()
    try {
        while ($objOutputStream.Length -le $MaximumBytes) {
            $intRemainingBytes = [int]([Math]::Min(
                    $arrBuffer.Length,
                    ($MaximumBytes + 1L) - $objOutputStream.Length
                ))
            $intReadBytes = $Stream.Read($arrBuffer, 0, $intRemainingBytes)
            if ($intReadBytes -eq 0) {
                break
            }
            $objOutputStream.Write($arrBuffer, 0, $intReadBytes)
        }

        if ($objOutputStream.Length -gt $MaximumBytes) {
            throw [System.IO.InvalidDataException]::new(
                "$DisplayName must not exceed $MaximumBytes bytes."
            )
        }

        return $objOutputStream.ToArray()
    }
    finally {
        $objOutputStream.Dispose()
    }
}

function Read-RepositoryInputData {
    # .SYNOPSIS
    # Reads one governed repository file safely.
    #
    # .DESCRIPTION
    # Resolves the provider path, validates Git and worktree metadata, and reads
    # the regular file through a strict byte limit.
    #
    # .PARAMETER Path
    # The PowerShell path of the worktree file.
    #
    # .PARAMETER RepositoryRootPath
    # The absolute repository root path used by Git.
    #
    # .PARAMETER RepositoryRelativePath
    # The repository-relative path used to inspect the Git index.
    #
    # .PARAMETER DisplayName
    # The input name to include in validation failures.
    #
    # .PARAMETER MaximumBytes
    # The largest accepted byte count.
    #
    # .EXAMPLE
    # $arrBytes = @(Read-RepositoryInputData -Path $strPath `
    #     -RepositoryRootPath $strRoot -RepositoryRelativePath 'AGENTS.md' `
    #     -DisplayName 'AGENTS.md' -MaximumBytes 32768)
    #
    # # Collects bytes from a safe regular repository file.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [byte] Each byte read from the repository file.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([byte])]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $RepositoryRootPath,

        [Parameter(Mandatory)]
        [string] $RepositoryRelativePath,

        [Parameter(Mandatory)]
        [string] $DisplayName,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483646)]
        [int] $MaximumBytes
    )

    $arrGitIndexEntries = @(& git -C $RepositoryRootPath ls-files --stage -- $RepositoryRelativePath 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not inspect the Git index entry for $DisplayName`: $($arrGitIndexEntries -join ' ')"
    }

    $strGitMode = $null
    $strGitStage = $null
    if ($arrGitIndexEntries.Count -eq 1) {
        $objGitIndexMatch = [regex]::Match(
            [string] $arrGitIndexEntries[0],
            '^(?<Mode>[0-7]{6}) [0-9a-f]+ (?<Stage>[0-3])\t'
        )
        if ($objGitIndexMatch.Success) {
            $strGitMode = $objGitIndexMatch.Groups['Mode'].Value
            $strGitStage = $objGitIndexMatch.Groups['Stage'].Value
        }
    }

    $strResolvedInputPath =
        $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $objInputItem = Get-Item -Force -LiteralPath $strResolvedInputPath
    $objLinkTypeProperty = $objInputItem.PSObject.Properties['LinkType']
    $strLinkType = if ($null -eq $objLinkTypeProperty) { '' } else { [string] $objLinkTypeProperty.Value }
    $objUnixModeProperty = $objInputItem.PSObject.Properties['UnixMode']
    $strUnixMode = if ($null -eq $objUnixModeProperty) { '' } else { [string] $objUnixModeProperty.Value }
    $arrMetadataFailures = @(Get-RepositoryInputMetadataFailure `
            -DisplayName $DisplayName `
            -GitIndexEntryCount $arrGitIndexEntries.Count `
            -GitMode $strGitMode `
            -GitStage $strGitStage `
            -IsFileInfo ($objInputItem -is [System.IO.FileInfo]) `
            -Attributes $objInputItem.Attributes `
            -LinkType $strLinkType `
            -UnixMode $strUnixMode)
    if ($arrMetadataFailures.Count -gt 0) {
        throw "Repository input is unsafe:`n- $($arrMetadataFailures -join "`n- ")"
    }

    $objInputStream = [System.IO.FileStream]::new(
        $strResolvedInputPath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read
    )
    try {
        return Read-BoundedStreamData `
            -Stream $objInputStream `
            -MaximumBytes $MaximumBytes `
            -DisplayName $DisplayName
    }
    finally {
        $objInputStream.Dispose()
    }
}

function Read-GitRevisionText {
    # .SYNOPSIS
    # Reads one bounded UTF-8 file from a Git revision.
    #
    # .DESCRIPTION
    # Invokes Git without a shell, bounds standard output, and decodes the blob as
    # strict UTF-8 without a byte-order mark.
    #
    # .PARAMETER RepositoryRootPath
    # The absolute repository root path used by Git.
    #
    # .PARAMETER Revision
    # The commit or tree revision that contains the file.
    #
    # .PARAMETER RepositoryRelativePath
    # The repository-relative blob path.
    #
    # .PARAMETER MaximumBytes
    # The largest accepted blob byte count.
    #
    # .PARAMETER RequireRegularFile
    # Requires the revision path to be one regular 100644 Git blob.
    #
    # .EXAMPLE
    # Read-GitRevisionText -RepositoryRootPath $strRoot -Revision 'HEAD^' `
    #     -RepositoryRelativePath 'AGENTS.md' -MaximumBytes 32768
    #
    # # Returns the decoded file text from the selected revision.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] The decoded revision text.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.1.20260820.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $RepositoryRootPath,

        [Parameter(Mandatory)]
        [string] $Revision,

        [Parameter(Mandatory)]
        [string] $RepositoryRelativePath,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483646)]
        [int] $MaximumBytes,

        [Parameter()]
        [switch] $RequireRegularFile
    )

    if ($RequireRegularFile) {
        $arrTreeEntries = @(& git -C $RepositoryRootPath ls-tree `
                $Revision -- $RepositoryRelativePath 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Could not inspect $Revision`:$RepositoryRelativePath in Git."
        }
        $strExpectedEntryPattern =
            '^100644 blob (?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})\t' +
            [regex]::Escape($RepositoryRelativePath) + '$'
        if ($arrTreeEntries.Count -ne 1 -or
            [string]$arrTreeEntries[0] -notmatch $strExpectedEntryPattern) {
            throw "Git revision input is not one regular 100644 blob: $Revision`:$RepositoryRelativePath"
        }
    }

    $objStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $objStartInfo.FileName = 'git'
    $objStartInfo.UseShellExecute = $false
    $objStartInfo.CreateNoWindow = $true
    $objStartInfo.RedirectStandardOutput = $true
    $objStartInfo.RedirectStandardError = $true
    foreach ($strArgument in @(
            '-C',
            $RepositoryRootPath,
            'cat-file',
            'blob',
            "${Revision}:$RepositoryRelativePath"
        )) {
        $objStartInfo.ArgumentList.Add($strArgument)
    }

    $objGitProcess = [System.Diagnostics.Process]::new()
    $objGitProcess.StartInfo = $objStartInfo
    try {
        if (-not $objGitProcess.Start()) {
            throw "Could not start Git to read $Revision`:$RepositoryRelativePath."
        }

        $objStandardErrorTask = $objGitProcess.StandardError.ReadToEndAsync()
        $arrRevisionBytes = Read-BoundedStreamData `
            -Stream $objGitProcess.StandardOutput.BaseStream `
            -MaximumBytes $MaximumBytes `
            -DisplayName "$Revision`:$RepositoryRelativePath"
        if (-not $objGitProcess.WaitForExit(10000)) {
            $objGitProcess.Kill($true)
            [void]$objGitProcess.WaitForExit(1000)
            throw "Git timed out while reading $Revision`:$RepositoryRelativePath."
        }

        [void]$objStandardErrorTask.GetAwaiter().GetResult()
        if ($objGitProcess.ExitCode -ne 0) {
            throw "Could not read $Revision`:$RepositoryRelativePath from Git."
        }

        return ConvertFrom-StrictUtf8Data `
            -Bytes $arrRevisionBytes `
            -DisplayName "$Revision`:$RepositoryRelativePath"
    }
    finally {
        $objGitProcess.Dispose()
    }
}

function Test-GitRevisionFileContainsLiteral {
    # .SYNOPSIS
    # Tests whether a revision file contains an ordinal literal.
    #
    # .DESCRIPTION
    # Returns false when the file does not exist. Otherwise, reads the bounded
    # revision text and performs an ordinal substring comparison.
    #
    # .PARAMETER RepositoryRootPath
    # The absolute repository root path used by Git.
    #
    # .PARAMETER Revision
    # The commit or tree revision to inspect.
    #
    # .PARAMETER RepositoryRelativePath
    # The repository-relative blob path.
    #
    # .PARAMETER MaximumBytes
    # The largest accepted blob byte count.
    #
    # .PARAMETER Literal
    # The case-sensitive literal to find.
    #
    # .EXAMPLE
    # Test-GitRevisionFileContainsLiteral -RepositoryRootPath $strRoot `
    #     -Revision 'HEAD' -RepositoryRelativePath 'AGENTS.md' `
    #     -MaximumBytes 32768 -Literal 'metadata-range-transition-policy-v1'
    #
    # # Returns true only when the revision file contains the literal.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [bool] True when the revision file contains the literal.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $RepositoryRootPath,

        [Parameter(Mandatory)]
        [string] $Revision,

        [Parameter(Mandatory)]
        [string] $RepositoryRelativePath,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483646)]
        [int] $MaximumBytes,

        [Parameter(Mandatory)]
        [string] $Literal
    )

    & git -C $RepositoryRootPath cat-file -e `
        "$Revision`:$RepositoryRelativePath" 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    $strRevisionContent = Read-GitRevisionText `
        -RepositoryRootPath $RepositoryRootPath `
        -Revision $Revision `
        -RepositoryRelativePath $RepositoryRelativePath `
        -MaximumBytes $MaximumBytes
    return $strRevisionContent.Contains($Literal, [System.StringComparison]::Ordinal)
}

function Get-LocalPublishedBaselineRevision {
    # .SYNOPSIS
    # Resolves the local remote-default commit used as a published baseline.
    #
    # .DESCRIPTION
    # Resolves `refs/remotes/origin/HEAD`, requires it to identify a valid remote
    # tracking branch, and returns its available commit object ID.
    #
    # .PARAMETER RepositoryRootPath
    # The absolute repository root whose origin tracking references are inspected.
    #
    # .EXAMPLE
    # Get-LocalPublishedBaselineRevision -RepositoryRootPath $strRoot
    #
    # # Returns the exact local commit tracked by origin's default branch.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] The verified published-baseline commit object ID.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260907.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $RepositoryRootPath
    )

    $strRemoteHeadReference = [string] (
        & git -C $RepositoryRootPath symbolic-ref --quiet `
            refs/remotes/origin/HEAD 2>$null
    )
    if ($LASTEXITCODE -ne 0 -or
        -not $strRemoteHeadReference.StartsWith(
            'refs/remotes/origin/',
            [System.StringComparison]::Ordinal
        ) -or
        $strRemoteHeadReference.Trim() -ceq 'refs/remotes/origin/HEAD') {
        throw (
            'The local published baseline is unavailable. Fetch origin and set its ' +
            'remote-default tracking reference.'
        )
    }
    $strRemoteHeadReference = $strRemoteHeadReference.Trim()
    & git -C $RepositoryRootPath check-ref-format $strRemoteHeadReference 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'The local published-baseline reference is malformed.'
    }
    $strBaselineRevision = [string] (
        & git -C $RepositoryRootPath rev-parse --verify `
            "$strRemoteHeadReference`^{commit}" 2>$null
    )
    if ($LASTEXITCODE -ne 0 -or
        $strBaselineRevision.Trim() -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
        throw 'The local published-baseline commit is unavailable.'
    }
    return $strBaselineRevision.Trim()
}

function Get-GovernedDocumentParentContext {
    # .SYNOPSIS
    # Gets the comparison context for one governed document.
    #
    # .DESCRIPTION
    # Selects the worktree comparison source or the first parent of an explicit
    # input revision and derives the applicable UTC metadata date. A local
    # published baseline is the direct parent for both clean and dirty topic
    # snapshots so that internal commits are not separate metadata transitions.
    #
    # .PARAMETER RepositoryRootPath
    # The absolute repository root path used by Git.
    #
    # .PARAMETER RepositoryRelativePath
    # The repository-relative governed document path.
    #
    # .PARAMETER MaximumBytes
    # The largest accepted parent blob byte count.
    #
    # .PARAMETER Revision
    # The optional commit whose first parent supplies the comparison content.
    #
    # .PARAMETER PublishedBaselineRevision
    # The verified remote-default commit used for local no-range validation.
    #
    # .EXAMPLE
    # Get-GovernedDocumentParentContext -RepositoryRootPath $strRoot `
    #     -RepositoryRelativePath 'AGENTS.md' -MaximumBytes 32768
    #
    # # Returns parent content, revision, and expected UTC date.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] The parent content, parent revision, and expected UTC date.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.2.20260908.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $RepositoryRootPath,

        [Parameter(Mandatory)]
        [string] $RepositoryRelativePath,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483646)]
        [int] $MaximumBytes,

        [Parameter()]
        [AllowEmptyString()]
        [string] $Revision = '',

        [Parameter()]
        [AllowEmptyString()]
        [string] $PublishedBaselineRevision = ''
    )

    if (-not [string]::IsNullOrEmpty($Revision)) {
        if ($Revision -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
            throw "The governed-document input revision is invalid: $Revision"
        }
        & git -C $RepositoryRootPath cat-file -e "$Revision`^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "The governed-document input commit is unavailable: $Revision"
        }
        $strParentRevision = "$Revision`^1"
        & git -C $RepositoryRootPath cat-file -e `
            "$strParentRevision`^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "The governed-document input commit has no first parent: $Revision"
        }
        $strCommitTimestamp = [string] (
            & git -C $RepositoryRootPath show -s --format=%cI $Revision
        )
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read the input commit timestamp: $Revision"
        }
        $objCommitTimestamp = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse(
                $strCommitTimestamp.Trim(),
                [ref] $objCommitTimestamp
            )) {
            throw "The input commit timestamp is invalid: $Revision"
        }
        & git -C $RepositoryRootPath cat-file -e `
            "$strParentRevision`:$RepositoryRelativePath" 2>$null
        $strParentContent = if ($LASTEXITCODE -eq 0) {
            Read-GitRevisionText `
                -RepositoryRootPath $RepositoryRootPath `
                -Revision $strParentRevision `
                -RepositoryRelativePath $RepositoryRelativePath `
                -MaximumBytes $MaximumBytes `
                -RequireRegularFile
        }
        else {
            $null
        }
        return [pscustomobject]@{
            ParentContent = $strParentContent
            ExpectedUtcDate = $objCommitTimestamp.UtcDateTime.ToString('yyyy-MM-dd')
            ParentRevision = $strParentRevision
            IsWorktreeTransition = $false
            UsesPublishedBaseline = $false
        }
    }

    if (-not [string]::IsNullOrEmpty($PublishedBaselineRevision)) {
        if ($PublishedBaselineRevision -notmatch
            '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
            throw "The local published-baseline commit is invalid: $PublishedBaselineRevision"
        }
        & git -C $RepositoryRootPath cat-file -e `
            "$PublishedBaselineRevision`^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "The local published-baseline commit is unavailable: $PublishedBaselineRevision"
        }
        & git -C $RepositoryRootPath diff --quiet HEAD -- $RepositoryRelativePath
        $intDiffExitCode = $LASTEXITCODE
        if ($intDiffExitCode -notin @(0, 1)) {
            throw "Could not compare $RepositoryRelativePath with HEAD."
        }
        $strParentRevision = $PublishedBaselineRevision
        $strExpectedUtcDate = if ($intDiffExitCode -eq 1) {
            [DateTimeOffset]::UtcNow.ToString('yyyy-MM-dd')
        }
        else {
            ''
        }
        & git -C $RepositoryRootPath cat-file -e `
            "$strParentRevision`:$RepositoryRelativePath" 2>$null
        $strParentContent = if ($LASTEXITCODE -eq 0) {
            Read-GitRevisionText `
                -RepositoryRootPath $RepositoryRootPath `
                -Revision $strParentRevision `
                -RepositoryRelativePath $RepositoryRelativePath `
                -MaximumBytes $MaximumBytes `
                -RequireRegularFile
        }
        else {
            $null
        }
        return [pscustomobject]@{
            ParentContent = $strParentContent
            ExpectedUtcDate = $strExpectedUtcDate
            ParentRevision = $strParentRevision
            IsWorktreeTransition = $intDiffExitCode -eq 1
            UsesPublishedBaseline = $true
        }
    }

    & git -C $RepositoryRootPath diff --quiet HEAD -- $RepositoryRelativePath
    $intDiffExitCode = $LASTEXITCODE
    if ($intDiffExitCode -notin @(0, 1)) {
        throw "Could not compare $RepositoryRelativePath with HEAD."
    }

    if ($intDiffExitCode -eq 1) {
        $strParentRevision = 'HEAD'
        $strExpectedUtcDate = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-dd')
    }
    else {
        $strParentRevision = 'HEAD^'
        $strCommitTimestamp = [string] (& git -C $RepositoryRootPath show -s --format=%cI HEAD)
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not read the HEAD committer timestamp.'
        }
        $objCommitTimestamp = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse($strCommitTimestamp.Trim(), [ref] $objCommitTimestamp)) {
            throw 'The HEAD committer timestamp is invalid.'
        }
        $strExpectedUtcDate = $objCommitTimestamp.UtcDateTime.ToString('yyyy-MM-dd')
    }

    & git -C $RepositoryRootPath cat-file -e `
        "$strParentRevision`:$RepositoryRelativePath" 2>$null
    $strParentContent = if ($LASTEXITCODE -eq 0) {
        Read-GitRevisionText `
            -RepositoryRootPath $RepositoryRootPath `
            -Revision $strParentRevision `
            -RepositoryRelativePath $RepositoryRelativePath `
            -MaximumBytes $MaximumBytes `
            -RequireRegularFile
    }
    else {
        $null
    }
    return [pscustomobject]@{
        ParentContent = $strParentContent
        ExpectedUtcDate = $strExpectedUtcDate
        ParentRevision = $strParentRevision
        IsWorktreeTransition = $intDiffExitCode -eq 1
        UsesPublishedBaseline = $false
    }
}

function Assert-OversizedStreamMutationRejected {
    # .SYNOPSIS
    # Confirms that an oversized stream fails closed.
    #
    # .DESCRIPTION
    # Runs the fixed oversized-stream fixture and verifies the exact invalid-data
    # failure. The expected failure is handled and does not escape.
    #
    # .EXAMPLE
    # Assert-OversizedStreamMutationRejected
    #
    # # Returns no output when the fixture is rejected as expected.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # None.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([void])]
    param()

    $objOversizedStream = [System.IO.MemoryStream]::new([byte[]] @(1, 2, 3, 4, 5))
    try {
        [void](Read-BoundedStreamData `
                -Stream $objOversizedStream `
                -MaximumBytes 4 `
                -DisplayName 'oversized stream mutation')
        throw "Self-test 'oversized stream mutation' was accepted."
    }
    catch [System.IO.InvalidDataException] {
        $strExpectedMessage = 'oversized stream mutation must not exceed 4 bytes.'
        if ($_.Exception.Message -cne $strExpectedMessage) {
            throw "Self-test 'oversized stream mutation' returned an unexpected failure: $($_.Exception.Message)"
        }
    }
    finally {
        $objOversizedStream.Dispose()
    }
}

function Get-HuskySetupContractFailure {
    # .SYNOPSIS
    # Finds failures in the locked Husky bootstrap and staged-Markdown contract.
    #
    # .DESCRIPTION
    # Parses both package manifests and checks the explicit prepare command,
    # exact `.md` and `.mdc` staged-file guard, staged-index lint phase, and
    # retained full-worktree phases in the Husky hook.
    #
    # .PARAMETER RootPackageContent
    # The root package.json text that defines the documented bootstrap command.
    #
    # .PARAMETER WorkflowPackageContent
    # The workflow-local package.json text that defines the prepare command.
    #
    # .PARAMETER HookContent
    # The `.husky/pre-commit` text that contains the staged-file guard.
    #
    # .PARAMETER CopilotSetupContent
    # The Copilot setup workflow text that activates the retained hook.
    #
    # .EXAMPLE
    # Get-HuskySetupContractFailure -RootPackageContent $strRootPackage `
    #     -WorkflowPackageContent $strWorkflowPackage -HookContent $strHook `
    #     -CopilotSetupContent $strCopilotSetup
    #
    # # Writes one string for each Husky setup-contract failure.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each Husky setup-contract failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.3.20260908.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $RootPackageContent,

        [Parameter(Mandatory)]
        [string] $WorkflowPackageContent,

        [Parameter(Mandatory)]
        [string] $HookContent,

        [Parameter(Mandatory)]
        [string] $CopilotSetupContent
    )

    try {
        $objRootPackage = $RootPackageContent | ConvertFrom-Json -ErrorAction Stop
        $objWorkflowPackage = $WorkflowPackageContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Output 'Husky package manifests must be valid JSON.'
        return
    }
    $strExpectedBootstrap =
        'npm ci --ignore-scripts --no-audit --fund=false --include=dev --package-lock=true ' +
        '&& npm --prefix .github/workflows ci --ignore-scripts --no-audit --fund=false ' +
        '--include=dev --package-lock=true && npm --prefix .github/workflows run prepare'
    if ([string]$objRootPackage.scripts.'bootstrap:agent-instructions' -cne
        $strExpectedBootstrap) {
        Write-Output 'Bootstrap needs two script-disabled locked installs, then workflow prepare.'
    }
    if ([string]$objWorkflowPackage.scripts.prepare -cne 'cd ../.. && husky') {
        Write-Output 'Workflow prepare must run Husky and expose failure.'
    }
    $strExpectedGuard =
        "if git diff --cached --quiet --diff-filter=ACMR -- '*.md' '*.mdc'; then"
    if ([regex]::Matches(
            $HookContent,
            '(?m)^' + [regex]::Escape($strExpectedGuard) + '$'
        ).Count -ne 1) {
        Write-Output 'Husky guard must cover ACMR .md and .mdc once.'
    }
    $arrRequiredLintCommands = @(
        'if node .github/workflows/lint-staged-markdown.mjs; then',
        'if npm --prefix .github/workflows run lint:md; then',
        'if npm --prefix .github/workflows run lint:md:nested; then'
    )
    foreach ($strRequiredLintCommand in $arrRequiredLintCommands) {
        if ([regex]::Matches(
                $HookContent,
                '(?m)^' + [regex]::Escape($strRequiredLintCommand) + '$'
            ).Count -ne 1) {
            Write-Output "Husky must run this lint command once: $strRequiredLintCommand"
        }
    }
    $intStagedLintIndex = $HookContent.IndexOf(
        $arrRequiredLintCommands[0],
        [System.StringComparison]::Ordinal
    )
    $intOuterLintIndex = $HookContent.IndexOf(
        $arrRequiredLintCommands[1],
        [System.StringComparison]::Ordinal
    )
    $intNestedLintIndex = $HookContent.IndexOf(
        $arrRequiredLintCommands[2],
        [System.StringComparison]::Ordinal
    )
    if ($intStagedLintIndex -lt 0 -or
        $intOuterLintIndex -lt 0 -or
        $intNestedLintIndex -lt 0 -or
        $intStagedLintIndex -gt $intOuterLintIndex -or
        $intOuterLintIndex -gt $intNestedLintIndex) {
        Write-Output 'Husky must lint the staged index before both retained worktree phases.'
    }

    $objSha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $arrHookHashBytes = $objSha256.ComputeHash(
            [System.Text.UTF8Encoding]::new($false).GetBytes($HookContent)
        )
    }
    finally {
        $objSha256.Dispose()
    }
    $strHookSha256 = [System.BitConverter]::ToString(
        $arrHookHashBytes
    ).Replace('-', '').ToLowerInvariant()
    if ($strHookSha256 -cne $script:strHuskyHookSha256) {
        Write-Output 'Husky hook text must match the reviewed SHA-256 digest.'
    }

    $arrInstallCommands = @([regex]::Matches(
            $CopilotSetupContent,
            '(?m)^\s+npm ci(?:\s|\\)'
        ))
    $arrScriptDisabledInstalls = @([regex]::Matches(
            $CopilotSetupContent,
            '(?m)^\s+npm ci --ignore-scripts(?:\s|\\)'
        ))
    if ($arrInstallCommands.Count -ne 2 -or
        $arrScriptDisabledInstalls.Count -ne 2) {
        Write-Output 'Copilot setup must keep both locked installs script-disabled.'
    }

    $arrStepHeaders = @([regex]::Matches(
            $CopilotSetupContent,
            '(?m)^      - name: (?<Name>[^\r\n]+)\r?$'
        ))
    $intVerificationStepIndex = -1
    $intActivationStepIndex = -1
    for ($intStep = 0; $intStep -lt $arrStepHeaders.Count; $intStep++) {
        if ($arrStepHeaders[$intStep].Groups['Name'].Value -ceq
            'Verify locked dependency trees and immutable manifests') {
            if ($intVerificationStepIndex -ne -1) {
                $intVerificationStepIndex = -2
                break
            }
            $intVerificationStepIndex = $intStep
        }
        if ($arrStepHeaders[$intStep].Groups['Name'].Value -ceq
            'Activate retained pre-commit hook') {
            if ($intActivationStepIndex -ne -1) {
                $intActivationStepIndex = -2
                break
            }
            $intActivationStepIndex = $intStep
        }
    }
    if ($intVerificationStepIndex -lt 0 -or
        $intActivationStepIndex -ne ($intVerificationStepIndex + 1)) {
        Write-Output 'Copilot hook activation must occur once directly after dependency verification.'
    }

    $strActivationPattern =
        '(?ms)^      - name: Activate retained pre-commit hook\r?\n' +
        '        shell: bash\r?\n' +
        '        run: \|\r?\n' +
        '          set -euo pipefail\r?\n' +
        '          npm --prefix \.github/workflows run prepare\r?\n' +
        '          test "\$\(git config --get core\.hooksPath\)" = ''\.husky/_''\r?\n' +
        '          test -x \.husky/_/pre-commit' +
        '(?=\r?\n(?:\r?\n)?      - name: |\r?\n?\z)'
    if ([regex]::Matches(
            $CopilotSetupContent,
            $strActivationPattern
        ).Count -ne 1) {
        Write-Output (
            'Copilot hook activation must run nested prepare, require exact .husky/_ ' +
            'hooksPath, and require its executable dispatcher.'
        )
    }
}

function Get-PreCommitBootstrapContractFailure {
    # .SYNOPSIS
    # Finds failures in the documented pre-commit runner bootstrap contract.
    #
    # .DESCRIPTION
    # Requires one exact pre-commit version pin and exact interpreter-qualified
    # Windows and POSIX install and run commands in both agent entry points and
    # the workflow script index.
    #
    # .PARAMETER AgentsContent
    # The AGENTS.md text that documents the shared validation workflow.
    #
    # .PARAMETER ClaudeContent
    # The CLAUDE.md text that documents the shared validation workflow.
    #
    # .PARAMETER ScriptIndexContent
    # The workflow script-index text that documents local setup.
    #
    # .PARAMETER RequirementsContent
    # The requirements-dev.txt text that pins the pre-commit runner.
    #
    # .EXAMPLE
    # Get-PreCommitBootstrapContractFailure -AgentsContent $strAgents `
    #     -ClaudeContent $strClaude -ScriptIndexContent $strScriptIndex `
    #     -RequirementsContent $strRequirements
    #
    # # Writes one string for each bootstrap-contract failure.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each bootstrap-contract failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260908.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $AgentsContent,

        [Parameter(Mandatory)]
        [string] $ClaudeContent,

        [Parameter(Mandatory)]
        [string] $ScriptIndexContent,

        [Parameter(Mandatory)]
        [string] $RequirementsContent
    )

    $strExpectedRequirement = "pre-commit==4.6.2`n"
    $strNormalizedRequirements = $RequirementsContent.Replace("`r`n", "`n").Replace(
        "`r",
        "`n"
    )
    if ($strNormalizedRequirements -cne $strExpectedRequirement) {
        Write-Output 'requirements-dev.txt must contain only the exact pre-commit 4.6.2 pin.'
    }

    $arrRequiredCommands = @(
        'py -3.12 -m pip install --requirement requirements-dev.txt',
        'python3.12 -m pip install --requirement requirements-dev.txt',
        'py -3.12 -m pre_commit run --all-files',
        'python3.12 -m pre_commit run --all-files'
    )
    foreach ($objDocument in @(
            [pscustomobject]@{ Name = 'AGENTS.md'; Content = $AgentsContent },
            [pscustomobject]@{ Name = 'CLAUDE.md'; Content = $ClaudeContent },
            [pscustomobject]@{
                Name = '.github/workflows/scripts-README.md'
                Content = $ScriptIndexContent
            }
        )) {
        $objMarkdownContext = Get-OperativeMarkdownContext -Content $objDocument.Content
        $arrCodeSpans = @($objMarkdownContext.ProseBlocks.Code)
        foreach ($strRequiredCommand in $arrRequiredCommands) {
            if (@($arrCodeSpans | Where-Object { $_ -ceq $strRequiredCommand }).Count -ne 1) {
                Write-Output (
                    "$($objDocument.Name) must contain this setup command exactly once: " +
                    $strRequiredCommand
                )
            }
        }
    }
}

function Test-Python312Application {
    # .SYNOPSIS
    # Tests whether one application invocation is Python 3.12.
    #
    # .DESCRIPTION
    # Starts the candidate without profile or site initialization and accepts it
    # only when it reports exactly Python 3.12 with no error output. Operational
    # failures return false instead of escaping this helper.
    #
    # .PARAMETER Path
    # The application path to invoke.
    #
    # .PARAMETER PrefixArgument
    # Arguments, such as `-3.12`, that must precede the isolated version probe.
    #
    # .EXAMPLE
    # Test-Python312Application -Path '/usr/bin/python3.12'
    #
    # # Returns true only when the application is an exact Python 3.12 runtime.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [bool] True for an exact Python 3.12 runtime; otherwise, false.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260907.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter()]
        [string[]] $PrefixArgument = @()
    )

    $objStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $objStartInfo.FileName = $Path
    $objStartInfo.UseShellExecute = $false
    $objStartInfo.CreateNoWindow = $true
    $objStartInfo.RedirectStandardOutput = $true
    $objStartInfo.RedirectStandardError = $true
    foreach ($strArgument in @(
            $PrefixArgument + @(
                '-I',
                '-S',
                '-c',
                'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
            )
        )) {
        $objStartInfo.ArgumentList.Add($strArgument)
    }

    $objProcess = [System.Diagnostics.Process]::new()
    $objProcess.StartInfo = $objStartInfo
    try {
        if (-not $objProcess.Start()) {
            return $false
        }
        $objOutputTask = $objProcess.StandardOutput.ReadToEndAsync()
        $objErrorTask = $objProcess.StandardError.ReadToEndAsync()
        if (-not $objProcess.WaitForExit(10000)) {
            $objProcess.Kill($true)
            [void]$objProcess.WaitForExit(1000)
            return $false
        }
        $strOutput = $objOutputTask.GetAwaiter().GetResult()
        $strError = $objErrorTask.GetAwaiter().GetResult()
        return $objProcess.ExitCode -eq 0 -and
            $strOutput.Trim() -ceq '3.12' -and
            [string]::IsNullOrEmpty($strError)
    }
    catch {
        return $false
    }
    finally {
        $objProcess.Dispose()
    }
}

function Get-Python312CommandContext {
    # .SYNOPSIS
    # Resolves a verified Python 3.12 application and its prefix arguments.
    #
    # .DESCRIPTION
    # Searches platform-appropriate command names in documented order, ignores
    # non-application commands, and returns the first exact Python 3.12 match.
    # Optional resolvers provide deterministic mutation fixtures.
    #
    # .PARAMETER WindowsPlatform
    # Indicates whether to use the Windows `py -3.12` resolution route.
    #
    # .PARAMETER CommandResolver
    # An optional command resolver used in place of `Get-Command`.
    #
    # .PARAMETER VersionProbe
    # An optional predicate used in place of the live Python version probe.
    #
    # .EXAMPLE
    # Get-Python312CommandContext -WindowsPlatform $IsWindows
    #
    # # Returns a verified path and any required launcher prefix argument.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] The application path and prefix arguments, or null when no
    # exact Python 3.12 application is available.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260907.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [bool] $WindowsPlatform,

        [Parameter()]
        [AllowNull()]
        [scriptblock] $CommandResolver,

        [Parameter()]
        [AllowNull()]
        [scriptblock] $VersionProbe
    )

    if ($null -eq $CommandResolver) {
        $CommandResolver = {
            param([string] $Name)
            @(Get-Command -Name $Name -CommandType Application -All `
                    -ErrorAction SilentlyContinue)
        }
    }
    if ($null -eq $VersionProbe) {
        $VersionProbe = {
            param([string] $Path, [string[]] $PrefixArgument)
            Test-Python312Application -Path $Path -PrefixArgument $PrefixArgument
        }
    }

    $arrCandidates = if ($WindowsPlatform) {
        @([pscustomobject]@{ Name = 'py'; PrefixArgument = [string[]] @('-3.12') })
    }
    else {
        @(
            [pscustomobject]@{ Name = 'python3.12'; PrefixArgument = [string[]] @() }
            [pscustomobject]@{ Name = 'python3'; PrefixArgument = [string[]] @() }
            [pscustomobject]@{ Name = 'python'; PrefixArgument = [string[]] @() }
        )
    }
    foreach ($objCandidate in $arrCandidates) {
        $objCommand = @(
            & $CommandResolver $objCandidate.Name |
                Where-Object {
                    $_.PSObject.Properties['CommandType'] -and
                    [string]$_.CommandType -ceq 'Application' -and
                    $_.PSObject.Properties['Path'] -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.Path)
                } |
                Select-Object -First 1
        )
        if ($objCommand.Count -ne 1) {
            continue
        }
        $strPath = [string]$objCommand[0].Path
        try {
            $boolIsPython312 = [bool](& $VersionProbe `
                    $strPath ([string[]]$objCandidate.PrefixArgument))
        }
        catch {
            $boolIsPython312 = $false
        }
        if ($boolIsPython312) {
            return [pscustomobject]@{
                Path = $strPath
                PrefixArgument = [string[]]$objCandidate.PrefixArgument
            }
        }
    }
    return $null
}

function Get-TomlParseContext {
    # .SYNOPSIS
    # Gets a safe typed TOML parse context.
    #
    # .DESCRIPTION
    # Runs the trusted Python 3.12 TOML parser once in isolated mode. It returns
    # a fixed JSON projection of the root capacity, GitHub plugin enablement,
    # and parser-confirmed identities of the first three semantic statements.
    # PowerShell validates that projection before returning typed values.
    #
    # .PARAMETER Content
    # The TOML text to validate.
    #
    # .EXAMPLE
    # Get-TomlParseContext -Content 'project_doc_max_bytes = 65536'
    #
    # # Returns typed capacity and plugin context for valid TOML.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] A failure and validated typed TOML context.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.2.20260820.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Content
    )

    $objContext = [ordered]@{
        Failure = ''
        CapacityPresent = $false
        CapacityType = 'missing'
        CapacityFitsInt64 = $false
        CapacityValue = [int64]0
        PluginTablePresent = $false
        PluginTableType = 'missing'
        PluginEnabledPresent = $false
        PluginEnabledType = 'missing'
        PluginEnabledValue = $false
        CapacityIsFirstStatement = $false
        PluginHeaderIsSecondStatement = $false
        PluginEnablementIsThirdStatement = $false
        PluginEnabledValueStatementOffset = -1
        PluginEnabledValueLength = 0
    }

    if ($null -eq $script:objPython312CommandContext) {
        $script:objPython312CommandContext = Get-Python312CommandContext `
            -WindowsPlatform ([bool]$IsWindows)
    }
    $objPythonCommand = $script:objPython312CommandContext
    if ($null -eq $objPythonCommand) {
        $objContext.Failure =
            'A trusted Python 3.12 interpreter is required to validate .codex/config.toml.'
        return [pscustomobject]$objContext
    }
    $strPythonPath = $objPythonCommand.Path

    $strPythonProgram = @(
        'import json, re, sys, tomllib'
        'content = sys.stdin.read()'
        'data = tomllib.loads(content)'
        'semantic_lines = []'
        'semantic_ends = []'
        'offset = 0'
        'for line in content.splitlines(keepends=True):'
        '    text = line[:-2] if line.endswith("\r\n") else line[:-1] if line.endswith("\n") else line'
        '    stripped = text.lstrip()'
        '    offset += len(line)'
        '    if stripped and not stripped.startswith("#"):'
        '        semantic_lines.append(text)'
        '        semantic_ends.append(offset)'
        'def parse_prefix(statement_count):'
        '    if len(semantic_ends) < statement_count:'
        '        return None'
        '    try:'
        '        return tomllib.loads(content[:semantic_ends[statement_count - 1]])'
        '    except tomllib.TOMLDecodeError:'
        '        return None'
        'prefix_one = parse_prefix(1)'
        'prefix_two = parse_prefix(2)'
        'prefix_three = parse_prefix(3)'
        'capacity_is_first = isinstance(prefix_one, dict) and set(prefix_one) == {"project_doc_max_bytes"}'
        'prefix_two_plugins = prefix_two.get("plugins") if isinstance(prefix_two, dict) else None'
        'prefix_two_plugin = prefix_two_plugins.get("github@openai-curated") if isinstance(prefix_two_plugins, dict) else None'
        'second_is_table_header = len(semantic_lines) > 1 and semantic_lines[1].lstrip().startswith("[") and not semantic_lines[1].lstrip().startswith("[[")'
        'plugin_header_is_second = capacity_is_first and second_is_table_header and isinstance(prefix_two, dict) and set(prefix_two) == {"project_doc_max_bytes", "plugins"} and isinstance(prefix_two_plugins, dict) and set(prefix_two_plugins) == {"github@openai-curated"} and prefix_two_plugin == {}'
        'prefix_three_plugins = prefix_three.get("plugins") if isinstance(prefix_three, dict) else None'
        'prefix_three_plugin = prefix_three_plugins.get("github@openai-curated") if isinstance(prefix_three_plugins, dict) else None'
        'third_is_assignment = len(semantic_lines) > 2 and not semantic_lines[2].lstrip().startswith("[")'
        'plugin_enablement_is_third = plugin_header_is_second and third_is_assignment and isinstance(prefix_three, dict) and set(prefix_three) == {"project_doc_max_bytes", "plugins"} and isinstance(prefix_three_plugins, dict) and set(prefix_three_plugins) == {"github@openai-curated"} and isinstance(prefix_three_plugin, dict) and set(prefix_three_plugin) == {"enabled"} and type(prefix_three_plugin.get("enabled")) is bool'
        'enabled_value_statement_offset = -1'
        'enabled_value_length = 0'
        'if plugin_enablement_is_third:'
        '    separator = semantic_lines[2].find("=")'
        '    value_match = re.fullmatch(r"\s*(true|false)\s*(?:#.*)?", semantic_lines[2][separator + 1:]) if separator >= 0 else None'
        '    if value_match is None:'
        '        plugin_enablement_is_third = False'
        '    else:'
        '        enabled_value_statement_offset = separator + 1 + value_match.start(1)'
        '        enabled_value_length = len(value_match.group(1))'
        'capacity_present = "project_doc_max_bytes" in data'
        'capacity = data.get("project_doc_max_bytes")'
        'plugins = data.get("plugins")'
        'plugin_table_present = isinstance(plugins, dict) and "github@openai-curated" in plugins'
        'plugin_table = plugins.get("github@openai-curated") if plugin_table_present else None'
        'plugin_enabled_present = isinstance(plugin_table, dict) and "enabled" in plugin_table'
        'plugin_enabled = plugin_table.get("enabled") if plugin_enabled_present else None'
        'context = {'
        '    "capacity_present": capacity_present,'
        '    "capacity_type": type(capacity).__name__ if capacity_present else "missing",'
        '    "capacity_value": str(capacity) if type(capacity) is int else None,'
        '    "plugin_table_present": plugin_table_present,'
        '    "plugin_table_type": type(plugin_table).__name__ if plugin_table_present else "missing",'
        '    "plugin_enabled_present": plugin_enabled_present,'
        '    "plugin_enabled_type": type(plugin_enabled).__name__ if plugin_enabled_present else "missing",'
        '    "plugin_enabled_value": plugin_enabled if type(plugin_enabled) is bool else None,'
        '    "capacity_is_first_statement": capacity_is_first,'
        '    "plugin_header_is_second_statement": plugin_header_is_second,'
        '    "plugin_enablement_is_third_statement": plugin_enablement_is_third,'
        '    "plugin_enabled_value_statement_offset": enabled_value_statement_offset,'
        '    "plugin_enabled_value_length": enabled_value_length,'
        '}'
        'print(json.dumps(context, separators=(",", ":"), sort_keys=True))'
    ) -join "`n"

    $arrPythonArguments = [System.Collections.Generic.List[string]]::new()
    foreach ($strPrefixArgument in $objPythonCommand.PrefixArgument) {
        $arrPythonArguments.Add($strPrefixArgument)
    }
    foreach ($strPythonArgument in @(
            '-I',
            '-S',
            '-c',
            $strPythonProgram
        )) {
        $arrPythonArguments.Add($strPythonArgument)
    }

    $objStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $objStartInfo.FileName = $strPythonPath
    $objStartInfo.UseShellExecute = $false
    $objStartInfo.CreateNoWindow = $true
    $objStartInfo.RedirectStandardInput = $true
    $objStartInfo.RedirectStandardOutput = $true
    $objStartInfo.RedirectStandardError = $true
    $objStartInfo.StandardInputEncoding = [System.Text.UTF8Encoding]::new($false)
    $objStartInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $objStartInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
    foreach ($strPythonArgument in $arrPythonArguments) {
        $objStartInfo.ArgumentList.Add($strPythonArgument)
    }

    $strParserOutput = ''
    $objParserProcess = [System.Diagnostics.Process]::new()
    $objParserProcess.StartInfo = $objStartInfo
    try {
        if (-not $objParserProcess.Start()) {
            $objContext.Failure =
                'A trusted Python 3.12 interpreter is required to validate .codex/config.toml.'
            return [pscustomobject]$objContext
        }

        $objStandardOutputTask = $objParserProcess.StandardOutput.ReadToEndAsync()
        $objStandardErrorTask = $objParserProcess.StandardError.ReadToEndAsync()
        $objParserProcess.StandardInput.Write($Content)
        $objParserProcess.StandardInput.Close()
        if (-not $objParserProcess.WaitForExit(10000)) {
            $objParserProcess.Kill($true)
            [void]$objParserProcess.WaitForExit(1000)
            $objContext.Failure = 'TOML validation must complete within 10 seconds.'
            return [pscustomobject]$objContext
        }

        $strParserOutput = $objStandardOutputTask.GetAwaiter().GetResult()
        $strParserError = $objStandardErrorTask.GetAwaiter().GetResult()
        if ($objParserProcess.ExitCode -ne 0) {
            $objContext.Failure = 'The project configuration must contain valid TOML.'
            return [pscustomobject]$objContext
        }
        if (-not [string]::IsNullOrEmpty($strParserError)) {
            $objContext.Failure = 'The trusted TOML parser returned unexpected error output.'
            return [pscustomobject]$objContext
        }
    }
    catch {
        $objContext.Failure =
            'A trusted Python 3.12 interpreter is required to validate .codex/config.toml.'
        return [pscustomobject]$objContext
    }
    finally {
        $objParserProcess.Dispose()
    }

    if ([System.Text.Encoding]::UTF8.GetByteCount($strParserOutput) -gt 4096) {
        $objContext.Failure = 'The trusted TOML parser returned oversized typed context.'
        return [pscustomobject]$objContext
    }

    try {
        $objParserContext = $strParserOutput | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $objContext.Failure = 'The trusted TOML parser returned invalid typed context.'
        return [pscustomobject]$objContext
    }

    $arrExpectedProperties = @(
        'capacity_present',
        'capacity_type',
        'capacity_value',
        'plugin_table_present',
        'plugin_table_type',
        'plugin_enabled_present',
        'plugin_enabled_type',
        'plugin_enabled_value',
        'capacity_is_first_statement',
        'plugin_header_is_second_statement',
        'plugin_enablement_is_third_statement',
        'plugin_enabled_value_statement_offset',
        'plugin_enabled_value_length'
    )
    $arrActualProperties = @($objParserContext.PSObject.Properties.Name)
    if ($arrActualProperties.Count -ne $arrExpectedProperties.Count -or
        @(Compare-Object $arrExpectedProperties $arrActualProperties).Count -ne 0 -or
        $objParserContext.capacity_present -isnot [bool] -or
        $objParserContext.capacity_type -isnot [string] -or
        ($null -ne $objParserContext.capacity_value -and
            $objParserContext.capacity_value -isnot [string]) -or
        $objParserContext.plugin_table_present -isnot [bool] -or
        $objParserContext.plugin_table_type -isnot [string] -or
        $objParserContext.plugin_enabled_present -isnot [bool] -or
        $objParserContext.plugin_enabled_type -isnot [string] -or
        ($null -ne $objParserContext.plugin_enabled_value -and
            $objParserContext.plugin_enabled_value -isnot [bool]) -or
        $objParserContext.capacity_is_first_statement -isnot [bool] -or
        $objParserContext.plugin_header_is_second_statement -isnot [bool] -or
        $objParserContext.plugin_enablement_is_third_statement -isnot [bool] -or
        $objParserContext.plugin_enabled_value_statement_offset -isnot [int64] -or
        $objParserContext.plugin_enabled_value_length -isnot [int64] -or
        $objParserContext.plugin_enabled_value_statement_offset -lt -1 -or
        $objParserContext.plugin_enabled_value_statement_offset -gt $Content.Length -or
        $objParserContext.plugin_enabled_value_length -lt 0 -or
        $objParserContext.plugin_enabled_value_length -gt 5 -or
        ($objParserContext.plugin_enablement_is_third_statement -and
            ($objParserContext.plugin_enabled_value_statement_offset -lt 0 -or
                $objParserContext.plugin_enabled_value_length -notin @(4, 5))) -or
        (-not $objParserContext.plugin_enablement_is_third_statement -and
            ($objParserContext.plugin_enabled_value_statement_offset -ne -1 -or
                $objParserContext.plugin_enabled_value_length -ne 0))) {
        $objContext.Failure = 'The trusted TOML parser returned invalid typed context.'
        return [pscustomobject]$objContext
    }

    $objContext.CapacityPresent = $objParserContext.capacity_present
    $objContext.CapacityType = $objParserContext.capacity_type
    if ($objParserContext.capacity_type -ceq 'int' -and
        $objParserContext.capacity_value -is [string]) {
        $intCapacityValue = [int64]0
        $objContext.CapacityFitsInt64 = [int64]::TryParse(
            $objParserContext.capacity_value,
            [System.Globalization.NumberStyles]::AllowLeadingSign,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref] $intCapacityValue
        )
        if ($objContext.CapacityFitsInt64) {
            $objContext.CapacityValue = $intCapacityValue
        }
    }
    $objContext.PluginTablePresent = $objParserContext.plugin_table_present
    $objContext.PluginTableType = $objParserContext.plugin_table_type
    $objContext.PluginEnabledPresent = $objParserContext.plugin_enabled_present
    $objContext.PluginEnabledType = $objParserContext.plugin_enabled_type
    if ($objParserContext.plugin_enabled_value -is [bool]) {
        $objContext.PluginEnabledValue = $objParserContext.plugin_enabled_value
    }
    $objContext.CapacityIsFirstStatement = $objParserContext.capacity_is_first_statement
    $objContext.PluginHeaderIsSecondStatement =
        $objParserContext.plugin_header_is_second_statement
    $objContext.PluginEnablementIsThirdStatement =
        $objParserContext.plugin_enablement_is_third_statement
    $objContext.PluginEnabledValueStatementOffset =
        [int]$objParserContext.plugin_enabled_value_statement_offset
    $objContext.PluginEnabledValueLength =
        [int]$objParserContext.plugin_enabled_value_length

    return [pscustomobject]$objContext
}

function Invoke-NodeRuntimeProbe {
    # .SYNOPSIS
    # Gets direct runtime identity from one Node command candidate.
    #
    # .DESCRIPTION
    # Runs a fixed `process.execPath` and version probe with preload environment
    # variables removed. Start, timeout, and process failures return a negative
    # result object instead of escaping this helper.
    #
    # .PARAMETER Path
    # The Node command candidate path to invoke.
    #
    # .EXAMPLE
    # Invoke-NodeRuntimeProbe -Path $strNodeCommandPath
    #
    # # Returns the exit code, bounded identity output, and error output.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] ExitCode is zero only for a completed probe; Output contains
    # runtime identity JSON; Error contains standard error.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260907.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $objStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $objStartInfo.FileName = $Path
    $objStartInfo.UseShellExecute = $false
    $objStartInfo.CreateNoWindow = $true
    $objStartInfo.RedirectStandardOutput = $true
    $objStartInfo.RedirectStandardError = $true
    $objStartInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $objStartInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
    [void]$objStartInfo.Environment.Remove('NODE_OPTIONS')
    [void]$objStartInfo.Environment.Remove('NODE_PATH')
    $objStartInfo.ArgumentList.Add('-p')
    $objStartInfo.ArgumentList.Add(
        'JSON.stringify({execPath:process.execPath,nodeVersion:process.versions.node})'
    )

    $objProcess = [System.Diagnostics.Process]::new()
    $objProcess.StartInfo = $objStartInfo
    try {
        if (-not $objProcess.Start()) {
            return [pscustomobject]@{ ExitCode = -1; Output = ''; Error = '' }
        }
        $objOutputTask = $objProcess.StandardOutput.ReadToEndAsync()
        $objErrorTask = $objProcess.StandardError.ReadToEndAsync()
        if (-not $objProcess.WaitForExit(10000)) {
            $objProcess.Kill($true)
            [void]$objProcess.WaitForExit(1000)
            return [pscustomobject]@{ ExitCode = -1; Output = ''; Error = '' }
        }
        return [pscustomobject]@{
            ExitCode = $objProcess.ExitCode
            Output = $objOutputTask.GetAwaiter().GetResult()
            Error = $objErrorTask.GetAwaiter().GetResult()
        }
    }
    catch {
        return [pscustomobject]@{ ExitCode = -1; Output = ''; Error = '' }
    }
    finally {
        $objProcess.Dispose()
    }
}

function Get-NodeApplicationContext {
    # .SYNOPSIS
    # Resolves the direct executable behind a supported Node command.
    #
    # .DESCRIPTION
    # Probes PATH application candidates for their direct `process.execPath`,
    # accepts Node 22 or later, verifies that the reported path is an application,
    # and caches live resolution. Optional resolvers support mutation fixtures.
    #
    # .PARAMETER CommandResolver
    # An optional resolver that returns Node command candidates.
    #
    # .PARAMETER RuntimeProbe
    # An optional probe that returns direct runtime identity for one candidate.
    #
    # .PARAMETER ApplicationResolver
    # An optional resolver that verifies the reported direct application path.
    #
    # .EXAMPLE
    # Get-NodeApplicationContext
    #
    # # Returns the direct Node executable behind a PATH shim or wrapper.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] The direct executable path and Node version, or null when no
    # supported verified runtime is available.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260907.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [AllowNull()]
        [scriptblock] $CommandResolver,

        [Parameter()]
        [AllowNull()]
        [scriptblock] $RuntimeProbe,

        [Parameter()]
        [AllowNull()]
        [scriptblock] $ApplicationResolver
    )

    $boolUseDefaultResolution = $null -eq $CommandResolver -and
        $null -eq $RuntimeProbe -and $null -eq $ApplicationResolver
    if ($boolUseDefaultResolution -and $null -ne $script:objNodeApplicationContext) {
        return $script:objNodeApplicationContext
    }
    if ($null -eq $CommandResolver) {
        $CommandResolver = {
            param([string] $Name)
            @(Get-Command -Name $Name -CommandType Application -All `
                    -ErrorAction SilentlyContinue)
        }
    }
    if ($null -eq $RuntimeProbe) {
        $RuntimeProbe = {
            param([string] $Path)
            Invoke-NodeRuntimeProbe -Path $Path
        }
    }
    if ($null -eq $ApplicationResolver) {
        $ApplicationResolver = {
            param([string] $Path)
            @(Get-Command -Name $Path -CommandType Application -All `
                    -ErrorAction SilentlyContinue)
        }
    }

    $arrCandidates = @(
        & $CommandResolver 'node' |
            Where-Object {
                $_.PSObject.Properties['CommandType'] -and
                [string]$_.CommandType -ceq 'Application' -and
                $_.PSObject.Properties['Path'] -and
                -not [string]::IsNullOrWhiteSpace([string]$_.Path)
            }
    )
    foreach ($objCandidate in $arrCandidates) {
        try {
            $objProbe = & $RuntimeProbe ([string]$objCandidate.Path)
            if ($null -eq $objProbe -or
                $null -eq $objProbe.PSObject.Properties['ExitCode'] -or
                $null -eq $objProbe.PSObject.Properties['Output'] -or
                $null -eq $objProbe.PSObject.Properties['Error'] -or
                [int]$objProbe.ExitCode -ne 0 -or
                -not [string]::IsNullOrEmpty([string]$objProbe.Error) -or
                [System.Text.Encoding]::UTF8.GetByteCount([string]$objProbe.Output) -gt 4096) {
                continue
            }
            $objRuntime = [string]$objProbe.Output |
                ConvertFrom-Json -ErrorAction Stop
            if ($null -eq $objRuntime -or
                $objRuntime.execPath -isnot [string] -or
                $objRuntime.nodeVersion -isnot [string] -or
                -not [System.IO.Path]::IsPathFullyQualified($objRuntime.execPath)) {
                continue
            }
            $objVersionMatch = [regex]::Match(
                $objRuntime.nodeVersion,
                '^(?<Major>[0-9]+)\.[0-9]+\.[0-9]+$'
            )
            $intNodeMajorVersion = 0
            if (-not $objVersionMatch.Success -or
                -not [int]::TryParse(
                    $objVersionMatch.Groups['Major'].Value,
                    [ref]$intNodeMajorVersion
                ) -or
                $intNodeMajorVersion -lt 22) {
                continue
            }
            $strReportedPath = [System.IO.Path]::GetFullPath($objRuntime.execPath)
            $objPathComparison = if ($IsWindows) {
                [System.StringComparison]::OrdinalIgnoreCase
            }
            else {
                [System.StringComparison]::Ordinal
            }
            $arrApplications = @(
                & $ApplicationResolver $strReportedPath |
                    Where-Object {
                        $_.PSObject.Properties['CommandType'] -and
                        [string]$_.CommandType -ceq 'Application' -and
                        $_.PSObject.Properties['Path'] -and
                        -not [string]::IsNullOrWhiteSpace([string]$_.Path)
                    }
            )
            $objApplication = $arrApplications |
                Where-Object {
                    $strApplicationPath = [System.IO.Path]::GetFullPath(
                        [string]$_.Path
                    )
                    $strApplicationPath.Equals(
                        $strReportedPath,
                        $objPathComparison
                    )
                } |
                Select-Object -First 1
            if ($null -eq $objApplication) {
                continue
            }
            $objContext = [pscustomobject]@{
                Path = $strReportedPath
                Version = $objRuntime.nodeVersion
            }
            if ($boolUseDefaultResolution) {
                $script:objNodeApplicationContext = $objContext
            }
            return $objContext
        }
        catch {
            continue
        }
    }
    return $null
}

function Get-MarkdownParseContext {
    # .SYNOPSIS
    # Parses Markdown into trusted structural context.
    #
    # .DESCRIPTION
    # Uses the repository-locked markdown-it package to identify code-block ranges,
    # prose blocks with operative code spans, top-level blocks, top-level list
    # items, and level-two headings.
    # It validates all parser output before returning it.
    #
    # .PARAMETER Content
    # The Markdown text to parse.
    #
    # .PARAMETER LineCount
    # The source line count used to bound parser ranges.
    #
    # .EXAMPLE
    # Get-MarkdownParseContext -Content $strMarkdown -LineCount $arrLines.Count
    #
    # # Returns validated Markdown block, list-item, and prose context.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] The validated Markdown parse context.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.2.20260820.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483647)]
        [int] $LineCount
    )

    $strRepositoryRootPath = [System.IO.Path]::GetDirectoryName(
        [System.IO.Path]::GetDirectoryName($PSScriptRoot)
    )
    $strMarkdownParserPath = Join-Path `
        -Path $strRepositoryRootPath `
        -ChildPath 'node_modules/markdown-it/package.json'
    if (-not (Test-Path -LiteralPath $strMarkdownParserPath -PathType Leaf)) {
        throw 'The locked markdown-it package is required to validate operative Markdown.'
    }

    $objNodeCommand = Get-NodeApplicationContext
    if ($null -eq $objNodeCommand) {
        throw 'A trusted Node.js 22 or later runtime is required to validate operative Markdown.'
    }

    $strNodeProgram = @(
        'const fs = require("node:fs");'
        'const MarkdownIt = require("markdown-it");'
        'const input = fs.readFileSync(0, "utf8");'
        'const tokens = new MarkdownIt({ html: true }).parse(input, {});'
        'const inlineHtmlTagPattern = /^<\s*(\/?)\s*([A-Za-z][A-Za-z0-9:-]*)(?=[\s/>])/;'
        'const voidHtmlTags = new Set(["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"]);'
        'const getOperativeInlineContext = (children) => {'
        '  const deletionStack = [];'
        '  const htmlContainerStack = [];'
        '  const output = [];'
        '  const code = [];'
        '  for (const child of children) {'
        '    if (child.type === "s_open" || child.type === "s_close") {'
        '      const isOpening = child.type === "s_open";'
        '      if (child.tag !== "s" || child.nesting !== (isOpening ? 1 : -1)) throw new Error("Invalid Markdown deletion token.");'
        '      if (isOpening) deletionStack.push("s");'
        '      else if (deletionStack.pop() !== "s") throw new Error("Unbalanced Markdown deletion token.");'
        '      continue;'
        '    }'
        '    if (child.type === "html_inline") {'
        '      const htmlTag = inlineHtmlTagPattern.exec(child.content);'
        '      if (htmlTag) {'
        '        const tagName = htmlTag[2].toLowerCase();'
        '        const isClosing = htmlTag[1] === "/";'
        '        if (voidHtmlTags.has(tagName)) {'
        '          if (isClosing) throw new Error("Invalid closing HTML void tag.");'
        '        } else if (!isClosing) {'
        '          htmlContainerStack.push(tagName);'
        '        } else if (htmlContainerStack.pop() !== tagName) {'
        '          throw new Error("Unbalanced inline HTML container.");'
        '        }'
        '        continue;'
        '      }'
        '    }'
        '    if (deletionStack.length > 0 || htmlContainerStack.length > 0) continue;'
        '    if (child.type === "text" || child.type === "text_special") output.push(child.content);'
        '    else if (child.type === "softbreak" || child.type === "hardbreak") output.push("\n");'
        '    else if (child.type === "code_inline") code.push(child.content);'
        '  }'
        '  if (deletionStack.length > 0) throw new Error("Unclosed deletion container.");'
        '  if (htmlContainerStack.length > 0) throw new Error("Unclosed inline HTML container.");'
        '  return { text: output.join(""), code };'
        '};'
        'const codeBlockRanges = tokens.filter((token) => token.type === "fence" || token.type === "code_block").map((token) => token.map);'
        'const proseBlocks = tokens.filter((token) => token.type === "inline" && Array.isArray(token.map) && Array.isArray(token.children)).map((token) => ({ range: token.map, ...getOperativeInlineContext(token.children) }));'
        'const topLevelBlocks = tokens.flatMap((token, index) => {'
        '  if (token.level !== 0 || !Array.isArray(token.map) || (token.nesting !== 0 && token.nesting !== 1)) return [];'
        '  let text = null;'
        '  if (token.type === "heading_open" || token.type === "paragraph_open") {'
        '    const inlineToken = tokens[index + 1];'
        '    if (inlineToken?.type !== "inline" || !Array.isArray(inlineToken.children)) throw new Error("Invalid top-level inline container.");'
        '    text = getOperativeInlineContext(inlineToken.children).text;'
        '  }'
        '  return [{ type: token.type, tag: token.tag, range: token.map, text }];'
        '});'
        'const topLevelListItems = tokens.flatMap((token, index) => {'
        '  if (token.type !== "list_item_open" || token.tag !== "li" || token.level !== 1 || !Array.isArray(token.map)) return [];'
        '  const closeIndex = tokens.findIndex((candidate, candidateIndex) => candidateIndex > index && candidate.type === "list_item_close" && candidate.tag === "li" && candidate.level === 1);'
        '  if (closeIndex < 0) throw new Error("Unclosed top-level list item.");'
        '  const inlineToken = tokens.slice(index + 1, closeIndex).find((candidate) => candidate.type === "inline" && candidate.level === 3 && Array.isArray(candidate.children));'
        '  const context = inlineToken ? getOperativeInlineContext(inlineToken.children) : null;'
        '  return [{ range: token.map, text: context?.text ?? null, code: context?.code ?? [] }];'
        '});'
        'const levelTwoHeadings = tokens.flatMap((token, index) => {'
        '  if (token.type !== "heading_open" || token.tag !== "h2" || token.level !== 0) return [];'
        '  const inlineToken = tokens[index + 1];'
        '  return [{ range: token.map, text: inlineToken?.type === "inline" ? inlineToken.content : null }];'
        '});'
        'process.stdout.write(JSON.stringify({ codeBlockRanges, proseBlocks, topLevelBlocks, topLevelListItems, levelTwoHeadings }));'
    ) -join "`n"

    $objStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $objStartInfo.FileName = $objNodeCommand.Path
    $objStartInfo.WorkingDirectory = $strRepositoryRootPath
    $objStartInfo.UseShellExecute = $false
    $objStartInfo.CreateNoWindow = $true
    $objStartInfo.RedirectStandardInput = $true
    $objStartInfo.RedirectStandardOutput = $true
    $objStartInfo.RedirectStandardError = $true
    $objStartInfo.StandardInputEncoding = [System.Text.UTF8Encoding]::new($false)
    $objStartInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $objStartInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
    [void]$objStartInfo.Environment.Remove('NODE_OPTIONS')
    [void]$objStartInfo.Environment.Remove('NODE_PATH')
    $objStartInfo.ArgumentList.Add('-e')
    $objStartInfo.ArgumentList.Add($strNodeProgram)

    $objParserProcess = [System.Diagnostics.Process]::new()
    $objParserProcess.StartInfo = $objStartInfo
    try {
        if (-not $objParserProcess.Start()) {
            throw 'Could not start the locked Markdown parser.'
        }

        $objStandardOutputTask = $objParserProcess.StandardOutput.ReadToEndAsync()
        $objStandardErrorTask = $objParserProcess.StandardError.ReadToEndAsync()
        try {
            $objParserProcess.StandardInput.Write($Content)
            $objParserProcess.StandardInput.Close()
        }
        catch [System.IO.IOException] {
            if (-not $objParserProcess.HasExited) {
                $objParserProcess.Kill($true)
                [void]$objParserProcess.WaitForExit(1000)
            }
            [void]$objStandardOutputTask.GetAwaiter().GetResult()
            [void]$objStandardErrorTask.GetAwaiter().GetResult()
            throw 'The locked Markdown parser ended before it accepted the governed document.'
        }
        if (-not $objParserProcess.WaitForExit(10000)) {
            $objParserProcess.Kill($true)
            [void]$objParserProcess.WaitForExit(1000)
            throw 'Markdown block parsing must complete within 10 seconds.'
        }

        $strParserOutput = $objStandardOutputTask.GetAwaiter().GetResult()
        [void]$objStandardErrorTask.GetAwaiter().GetResult()
        if ($objParserProcess.ExitCode -ne 0) {
            throw 'The locked Markdown parser rejected a governed document.'
        }
    }
    finally {
        $objParserProcess.Dispose()
    }

    try {
        $objRawContext = $strParserOutput | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw [System.IO.InvalidDataException]::new(
            'The locked Markdown parser returned invalid context data.',
            $_.Exception
        )
    }
    if ($null -eq $objRawContext -or
        $null -eq $objRawContext.codeBlockRanges -or
        $null -eq $objRawContext.proseBlocks -or
        $null -eq $objRawContext.topLevelBlocks -or
        $null -eq $objRawContext.topLevelListItems -or
        $null -eq $objRawContext.levelTwoHeadings) {
        throw 'The locked Markdown parser returned incomplete context data.'
    }

    $listRanges = [System.Collections.Generic.List[pscustomobject]]::new()
    $intPreviousEnd = 0
    foreach ($arrRawRange in @($objRawContext.codeBlockRanges)) {
        if ($arrRawRange -isnot [array] -or $arrRawRange.Count -ne 2) {
            throw 'The locked Markdown parser returned a malformed range.'
        }

        $intStart = [int64] 0
        $intEnd = [int64] 0
        if (-not [int64]::TryParse([string]$arrRawRange[0], [ref]$intStart) -or
            -not [int64]::TryParse([string]$arrRawRange[1], [ref]$intEnd) -or
            $intStart -lt $intPreviousEnd -or
            $intStart -lt 0 -or
            $intEnd -le $intStart -or
            $intEnd -gt $LineCount) {
            throw 'The locked Markdown parser returned an invalid or overlapping range.'
        }

        $listRanges.Add([pscustomobject]@{
                Start = [int]$intStart
                End = [int]$intEnd
            })
        $intPreviousEnd = [int]$intEnd
    }

    $listProseBlocks = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($objRawProseBlock in @($objRawContext.proseBlocks)) {
        if ($null -eq $objRawProseBlock -or
            $objRawProseBlock.range -isnot [array] -or
            $objRawProseBlock.range.Count -ne 2 -or
            $null -eq $objRawProseBlock.text -or
            $objRawProseBlock.code -isnot [array] -or
            @($objRawProseBlock.code | Where-Object { $_ -isnot [string] }).Count -ne 0) {
            throw 'The locked Markdown parser returned a malformed prose block.'
        }

        $intStart = [int64] 0
        $intEnd = [int64] 0
        if (-not [int64]::TryParse([string]$objRawProseBlock.range[0], [ref]$intStart) -or
            -not [int64]::TryParse([string]$objRawProseBlock.range[1], [ref]$intEnd) -or
            $intStart -lt 0 -or
            $intEnd -le $intStart -or
            $intEnd -gt $LineCount) {
            throw 'The locked Markdown parser returned an invalid prose-block range.'
        }

        $listProseBlocks.Add([pscustomobject]@{
                Start = [int]$intStart
                End = [int]$intEnd
                Text = [string]$objRawProseBlock.text
                Code = [string[]]@($objRawProseBlock.code)
            })
    }

    $listTopLevelBlocks = [System.Collections.Generic.List[pscustomobject]]::new()
    $intPreviousTopLevelBlockEnd = 0
    foreach ($objRawBlock in @($objRawContext.topLevelBlocks)) {
        if ($null -eq $objRawBlock -or
            $objRawBlock.type -isnot [string] -or
            $objRawBlock.tag -isnot [string] -or
            $objRawBlock.range -isnot [array] -or
            $objRawBlock.range.Count -ne 2 -or
            ($null -ne $objRawBlock.text -and $objRawBlock.text -isnot [string])) {
            throw 'The locked Markdown parser returned a malformed top-level block.'
        }

        $intStart = [int64] 0
        $intEnd = [int64] 0
        if (-not [int64]::TryParse([string]$objRawBlock.range[0], [ref]$intStart) -or
            -not [int64]::TryParse([string]$objRawBlock.range[1], [ref]$intEnd) -or
            $intStart -lt $intPreviousTopLevelBlockEnd -or
            $intStart -lt 0 -or
            $intEnd -le $intStart -or
            $intEnd -gt $LineCount) {
            throw 'The locked Markdown parser returned an invalid top-level block range.'
        }

        $listTopLevelBlocks.Add([pscustomobject]@{
                Type = [string]$objRawBlock.type
                Tag = [string]$objRawBlock.tag
                Start = [int]$intStart
                End = [int]$intEnd
                Text = if ($null -eq $objRawBlock.text) {
                    $null
                }
                else {
                    [string]$objRawBlock.text
                }
            })
        $intPreviousTopLevelBlockEnd = [int]$intEnd
    }

    $listTopLevelListItems = [System.Collections.Generic.List[pscustomobject]]::new()
    $intPreviousTopLevelListItemEnd = 0
    foreach ($objRawListItem in @($objRawContext.topLevelListItems)) {
        if ($null -eq $objRawListItem -or
            $objRawListItem.range -isnot [array] -or
            $objRawListItem.range.Count -ne 2 -or
            ($null -ne $objRawListItem.text -and $objRawListItem.text -isnot [string]) -or
            $objRawListItem.code -isnot [array] -or
            @($objRawListItem.code | Where-Object { $_ -isnot [string] }).Count -ne 0) {
            throw 'The locked Markdown parser returned a malformed top-level list item.'
        }

        $intStart = [int64] 0
        $intEnd = [int64] 0
        if (-not [int64]::TryParse([string]$objRawListItem.range[0], [ref]$intStart) -or
            -not [int64]::TryParse([string]$objRawListItem.range[1], [ref]$intEnd) -or
            $intStart -lt $intPreviousTopLevelListItemEnd -or
            $intStart -lt 0 -or
            $intEnd -le $intStart -or
            $intEnd -gt $LineCount) {
            throw 'The locked Markdown parser returned an invalid top-level list-item range.'
        }

        $listTopLevelListItems.Add([pscustomobject]@{
                Start = [int]$intStart
                End = [int]$intEnd
                Text = if ($null -eq $objRawListItem.text) {
                    $null
                }
                else {
                    [string]$objRawListItem.text
                }
                Code = [string[]]@($objRawListItem.code)
            })
        $intPreviousTopLevelListItemEnd = [int]$intEnd
    }

    $listLevelTwoHeadings = [System.Collections.Generic.List[pscustomobject]]::new()
    $intPreviousHeadingEnd = 0
    foreach ($objRawHeading in @($objRawContext.levelTwoHeadings)) {
        if ($null -eq $objRawHeading -or
            $objRawHeading.range -isnot [array] -or
            $objRawHeading.range.Count -ne 2 -or
            $objRawHeading.text -isnot [string]) {
            throw 'The locked Markdown parser returned a malformed level-two heading.'
        }

        $intStart = [int64] 0
        $intEnd = [int64] 0
        if (-not [int64]::TryParse([string]$objRawHeading.range[0], [ref]$intStart) -or
            -not [int64]::TryParse([string]$objRawHeading.range[1], [ref]$intEnd) -or
            $intStart -lt $intPreviousHeadingEnd -or
            $intStart -lt 0 -or
            $intEnd -le $intStart -or
            $intEnd -gt $LineCount) {
            throw 'The locked Markdown parser returned an invalid level-two heading range.'
        }

        $listLevelTwoHeadings.Add([pscustomobject]@{
                Start = [int]$intStart
                End = [int]$intEnd
                Text = [string]$objRawHeading.text
            })
        $intPreviousHeadingEnd = [int]$intEnd
    }

    return [pscustomobject]@{
        CodeBlockRanges = [pscustomobject[]]$listRanges.ToArray()
        ProseBlocks = [pscustomobject[]]$listProseBlocks.ToArray()
        TopLevelBlocks = [pscustomobject[]]$listTopLevelBlocks.ToArray()
        TopLevelListItems = [pscustomobject[]]$listTopLevelListItems.ToArray()
        LevelTwoHeadings = [pscustomobject[]]$listLevelTwoHeadings.ToArray()
    }
}

function Get-OperativeMarkdownContext {
    # .SYNOPSIS
    # Gets the operative prose context from Markdown.
    #
    # .DESCRIPTION
    # Removes comments, excludes fenced and indented code blocks, and returns the
    # remaining text with source and prose metadata.
    #
    # .PARAMETER Content
    # The Markdown text to analyze.
    #
    # .EXAMPLE
    # Get-OperativeMarkdownContext -Content $strAgentsContent
    #
    # # Returns operative text and its source mapping.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] Operative Markdown text, prose, lines, and range metadata.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Content
    )

    $strWithoutComments = [regex]::Replace(
        $Content,
        '<!--(?s:.*?)-->|<!--(?s:.*)\z',
        ''
    )
    $arrLines = [regex]::Split($strWithoutComments, '\r\n|\r|\n')
    $arrCodeBlockLines = [bool[]]::new($arrLines.Count)
    $objParseContext = Get-MarkdownParseContext `
            -Content $strWithoutComments `
            -LineCount $arrLines.Count
    foreach ($objRange in $objParseContext.CodeBlockRanges) {
        for ($intLine = $objRange.Start; $intLine -lt $objRange.End; $intLine++) {
            $arrCodeBlockLines[$intLine] = $true
        }
    }

    $listOperativeLines = [System.Collections.Generic.List[string]]::new()
    for ($intLine = 0; $intLine -lt $arrLines.Count; $intLine++) {
        if (-not $arrCodeBlockLines[$intLine]) {
            $listOperativeLines.Add($arrLines[$intLine])
        }
    }

    return [pscustomobject]@{
        Text = $listOperativeLines -join "`n"
        ProseText = @($objParseContext.ProseBlocks.Text) -join "`n"
        SourceLines = [string[]]$arrLines
        CodeBlockLines = [bool[]]$arrCodeBlockLines
        ProseBlocks = [pscustomobject[]]$objParseContext.ProseBlocks
        TopLevelListItems = [pscustomobject[]]$objParseContext.TopLevelListItems
        LevelTwoHeadings = [pscustomobject[]]$objParseContext.LevelTwoHeadings
    }
}

function ConvertTo-OperativeMarkdownText {
    # .SYNOPSIS
    # Converts Markdown to operative non-code text.
    #
    # .DESCRIPTION
    # Returns the operative text from the full Markdown context helper.
    #
    # .PARAMETER Content
    # The Markdown text to convert.
    #
    # .EXAMPLE
    # ConvertTo-OperativeMarkdownText -Content $strMarkdown
    #
    # # Returns text with comments and code blocks excluded.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] The operative Markdown text.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Content
    )

    return (Get-OperativeMarkdownContext -Content $Content).Text
}

function Get-MarkdownLevelTwoSectionContext {
    # .SYNOPSIS
    # Gets one level-two Markdown section.
    #
    # .DESCRIPTION
    # Locates one exact top-level level-two heading from validated Markdown tokens
    # and returns its operative section text and prose. An absent or duplicate
    # heading returns an empty context.
    #
    # .PARAMETER MarkdownContext
    # The validated operative Markdown context.
    #
    # .PARAMETER Heading
    # The exact parsed level-two heading text, without Markdown heading markers.
    #
    # .EXAMPLE
    # Get-MarkdownLevelTwoSectionContext -MarkdownContext $objContext `
    #     -Heading 'Automated Review Loop'
    #
    # # Returns operative text and prose for the unique section.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] The section's text and parser-derived block context.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.1.20260820.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $MarkdownContext,

        [Parameter(Mandatory)]
        [string] $Heading
    )

    $arrMatchingHeadings = @(
        $MarkdownContext.LevelTwoHeadings |
            Where-Object Text -CEQ $Heading
    )
    if ($arrMatchingHeadings.Count -ne 1) {
        return [pscustomobject]@{
            Text = ''
            ProseText = ''
            ProseBlocks = [pscustomobject[]]@()
            TopLevelListItems = [pscustomobject[]]@()
        }
    }

    $intSectionStart = $arrMatchingHeadings[0].Start
    $intSectionEnd = $MarkdownContext.SourceLines.Count
    foreach ($objHeading in $MarkdownContext.LevelTwoHeadings) {
        if ($objHeading.Start -gt $intSectionStart) {
            $intSectionEnd = $objHeading.Start
            break
        }
    }

    $listSectionLines = [System.Collections.Generic.List[string]]::new()
    for ($intLine = $intSectionStart; $intLine -lt $intSectionEnd; $intLine++) {
        if (-not $MarkdownContext.CodeBlockLines[$intLine]) {
            $listSectionLines.Add($MarkdownContext.SourceLines[$intLine])
        }
    }

    $listSectionProse = [System.Collections.Generic.List[string]]::new()
    foreach ($objProseBlock in $MarkdownContext.ProseBlocks) {
        if ($objProseBlock.Start -ge $intSectionStart -and
            $objProseBlock.End -le $intSectionEnd) {
            $listSectionProse.Add($objProseBlock.Text)
        }
    }

    return [pscustomobject]@{
        Text = $listSectionLines -join "`n"
        ProseText = $listSectionProse -join "`n"
        ProseBlocks = [pscustomobject[]]@(
            $MarkdownContext.ProseBlocks |
                Where-Object {
                    $_.Start -ge $intSectionStart -and $_.End -le $intSectionEnd
                }
        )
        TopLevelListItems = [pscustomobject[]]@(
            $MarkdownContext.TopLevelListItems |
                Where-Object {
                    $_.Start -ge $intSectionStart -and $_.End -le $intSectionEnd
                }
        )
    }
}

function Test-MetadataCalendarDate {
    # .SYNOPSIS
    # Tests one metadata date as a real canonical calendar date.
    #
    # .DESCRIPTION
    # Parses one yyyy-MM-dd value with the invariant Gregorian calendar.
    #
    # .PARAMETER Date
    # The yyyy-MM-dd metadata date to validate.
    #
    # .EXAMPLE
    # Test-MetadataCalendarDate -Date '2024-02-29'
    #
    # # Returns true for the canonical leap-day value.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [bool] True when the string is one real canonical calendar date.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260908.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Date
    )

    $objParsedDate = [datetime]::MinValue
    return [datetime]::TryParseExact(
        $Date,
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref] $objParsedDate
    ) -and $objParsedDate.ToString(
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture
    ) -ceq $Date
}

function Test-MetadataCalendarDatePair {
    # .SYNOPSIS
    # Tests one Version date and Last Updated date as a matching calendar date.
    #
    # .DESCRIPTION
    # Parses the hyphenated date with the invariant Gregorian calendar and
    # confirms that its compact form equals the Version date.
    #
    # .PARAMETER VersionDate
    # The compact yyyyMMdd date from Version metadata.
    #
    # .PARAMETER UpdatedDate
    # The yyyy-MM-dd date from Last Updated metadata.
    #
    # .EXAMPLE
    # Test-MetadataCalendarDatePair -VersionDate '20240229' `
    #     -UpdatedDate '2024-02-29'
    #
    # # Returns true for the matching leap-day pair.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [bool] True when both strings represent the same real calendar date.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $VersionDate,

        [Parameter(Mandatory)]
        [string] $UpdatedDate
    )

    if (-not (Test-MetadataCalendarDate -Date $UpdatedDate)) {
        return $false
    }

    return $UpdatedDate.Replace('-', '') -ceq $VersionDate
}

function ConvertTo-MetadataComparisonText {
    # .SYNOPSIS
    # Normalizes governed text for metadata-only comparison.
    #
    # .DESCRIPTION
    # Masks validated metadata-value lines, then normalizes mechanical whitespace.
    #
    # .PARAMETER Content
    # The governed document text to normalize.
    #
    # .PARAMETER MetadataContext
    # The parser-validated document-level metadata context.
    #
    # .EXAMPLE
    # ConvertTo-MetadataComparisonText -Content $strContent -MetadataContext $objContext
    #
    # .INPUTS
    # None.
    #
    # .OUTPUTS
    # [string] Normalized comparison text.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.2.20260908.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Content,

        [Parameter(Mandatory)]
        [pscustomobject] $MetadataContext
    )

    $arrNormalizedLines = [regex]::Split($Content, '\r\n|\r|\n')
    $intUpdatedLineIndex = [int]$MetadataContext.UpdatedLineIndex
    if ($intUpdatedLineIndex -lt 0 -or
        $intUpdatedLineIndex -ge $arrNormalizedLines.Count -or
        $arrNormalizedLines[$intUpdatedLineIndex] -cnotmatch
        '^- \*\*Last Updated:\*\* \d{4}-\d{2}-\d{2}$') {
        throw 'The metadata comparison received an invalid header field index.'
    }
    if ($MetadataContext.HasVersion) {
        $intVersionLineIndex = [int]$MetadataContext.VersionLineIndex
        if ($intVersionLineIndex -lt 0 -or
            $intVersionLineIndex -ge $arrNormalizedLines.Count -or
            $arrNormalizedLines[$intVersionLineIndex] -cnotmatch
            '^\*\*Version:\*\* \d+\.\d+\.\d{8}\.\d+$') {
            throw 'The metadata comparison received an invalid Version field index.'
        }
        $arrNormalizedLines[$intVersionLineIndex] = '**Version:** <metadata-version>'
    }
    $arrNormalizedLines[$intUpdatedLineIndex] = '- **Last Updated:** <metadata-date>'

    $listNormalizedLines = [System.Collections.Generic.List[string]]::new()
    foreach ($strLine in $arrNormalizedLines) {
        if ($strLine -match ' {2,}$') {
            $listNormalizedLines.Add($strLine)
        }
        else {
            $listNormalizedLines.Add($strLine.TrimEnd([char[]] @(' ', "`t")))
        }
    }
    while ($listNormalizedLines.Count -gt 0 -and
        $listNormalizedLines[$listNormalizedLines.Count - 1].Length -eq 0) {
        $listNormalizedLines.RemoveAt($listNormalizedLines.Count - 1)
    }

    return $listNormalizedLines -join "`n"
}

function Get-GovernedInstructionInventoryFailure {
    # .SYNOPSIS
    # Finds drift between governed-instruction catalogs and tracked files.
    #
    # .DESCRIPTION
    # Compares two bounded repository-relative path sets with ordinal matching.
    # Duplicate, missing, and stale catalog entries fail closed.
    #
    # .PARAMETER CatalogPaths
    # The reviewed governed-instruction catalog paths.
    #
    # .PARAMETER TrackedPaths
    # The tracked paths in governed instruction-file families.
    #
    # .EXAMPLE
    # Get-GovernedInstructionInventoryFailure `
    #     -CatalogPaths @('AGENTS.md') -TrackedPaths @('AGENTS.md', 'CLAUDE.md')
    #
    # # Reports CLAUDE.md as missing from the reviewed catalog.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each inventory failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260820.1
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $CatalogPaths,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $TrackedPaths
    )

    $setCatalogPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($strCatalogPath in $CatalogPaths) {
        if ([string]::IsNullOrWhiteSpace($strCatalogPath) -or
            [System.IO.Path]::IsPathRooted($strCatalogPath) -or
            $strCatalogPath.Contains('\', [System.StringComparison]::Ordinal) -or
            $strCatalogPath -match '(?:^|/)\.\.(?:/|$)' -or
            $strCatalogPath.IndexOfAny([char[]] @("`0", "`r", "`n")) -ge 0) {
            Write-Output "The governed instruction catalog contains an unsafe path: $strCatalogPath"
            continue
        }
        if (-not $setCatalogPaths.Add($strCatalogPath)) {
            Write-Output "The governed instruction catalog contains a duplicate path: $strCatalogPath"
        }
    }

    $setTrackedPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($strTrackedPath in $TrackedPaths) {
        if (-not $setTrackedPaths.Add($strTrackedPath)) {
            Write-Output "The governed instruction inventory contains a duplicate path: $strTrackedPath"
        }
    }

    foreach ($strTrackedPath in $setTrackedPaths) {
        if (-not $setCatalogPaths.Contains($strTrackedPath)) {
            Write-Output (
                'Tracked governed instruction is missing from the catalog: ' +
                $strTrackedPath
            )
        }
    }
    foreach ($strCatalogPath in $setCatalogPaths) {
        if (-not $setTrackedPaths.Contains($strCatalogPath)) {
            Write-Output (
                'Governed instruction catalog path is not tracked at the validation ' +
                "revision: $strCatalogPath"
            )
        }
    }
}

function Get-DocumentMetadataContext {
    # .SYNOPSIS
    # Gets validated document-level metadata context.
    #
    # .DESCRIPTION
    # Locates optional Version and required Last Updated metadata in the parsed
    # document header.
    #
    # .PARAMETER Content
    # The governed Markdown document text.
    #
    # .EXAMPLE
    # Get-DocumentMetadataContext -Content $strAgentsContent
    #
    # # Returns validated optional Version and required Last Updated values.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] The metadata values and structural validation result.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.4.20260908.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Content
    )

    $arrLines = [regex]::Split($Content, '\r\n|\r|\n')
    $arrParserLines = [string[]]$arrLines.Clone()
    $intBodyStart = 0
    if ($arrLines.Count -gt 0 -and $arrLines[0] -ceq '---') {
        $intFrontMatterEnd = -1
        for ($intLine = 1; $intLine -lt $arrLines.Count; $intLine++) {
            if ($arrLines[$intLine] -ceq '---') {
                $intFrontMatterEnd = $intLine
                break
            }
        }
        if ($intFrontMatterEnd -lt 0) {
            return [pscustomobject]@{
                Failure = 'must close leading YAML front matter with an exact --- delimiter.'
                VersionDate = $null
                UpdatedDate = $null
                Revision = $null
            }
        }
        for ($intLine = 0; $intLine -le $intFrontMatterEnd; $intLine++) {
            $arrParserLines[$intLine] = ''
        }
        $intBodyStart = $intFrontMatterEnd + 1
    }
    $strParserContent = $arrParserLines -join "`n"
    $objParseContext = Get-MarkdownParseContext `
        -Content $strParserContent `
        -LineCount $arrLines.Count
    $arrTopLevelBlocks = @($objParseContext.TopLevelBlocks)
    $arrTopLevelListItems = @($objParseContext.TopLevelListItems)

    $listH1Indices = [System.Collections.Generic.List[int]]::new()
    $listH2Indices = [System.Collections.Generic.List[int]]::new()
    for ($intIndex = 0; $intIndex -lt $arrTopLevelBlocks.Count; $intIndex++) {
        $objBlock = $arrTopLevelBlocks[$intIndex]
        if ($objBlock.Type -ceq 'heading_open' -and $objBlock.Tag -ceq 'h1') {
            $listH1Indices.Add($intIndex)
        }
        elseif ($objBlock.Type -ceq 'heading_open' -and $objBlock.Tag -ceq 'h2') {
            $listH2Indices.Add($intIndex)
        }
    }

    if ($listH1Indices.Count -ne 1 -or
        ($arrTopLevelBlocks[$listH1Indices[0]].Start - $intBodyStart) -ge 30) {
        return [pscustomobject]@{
            Failure = 'must contain exactly one document-level H1 within the first 30 body lines.'
            VersionDate = $null
            UpdatedDate = $null
            Revision = $null
        }
    }

    $strVersionPattern = '^\*\*Version:\*\* (?<Major>\d+)\.(?<Minor>\d+)\.' +
        '(?<Date>\d{8})\.(?<Revision>\d+)$'
    $listVersionRecords = [System.Collections.Generic.List[pscustomobject]]::new()
    for ($intIndex = 0; $intIndex -lt $arrTopLevelBlocks.Count; $intIndex++) {
        $objBlock = $arrTopLevelBlocks[$intIndex]
        if ($objBlock.Type -cne 'paragraph_open' -or
            $objBlock.Text -isnot [string] -or
            -not $objBlock.Text.StartsWith('Version:', [System.StringComparison]::Ordinal)) {
            continue
        }

        $listVersionRecords.Add([pscustomobject]@{
                BlockIndex = $intIndex
                Block = $objBlock
            })
    }

    $intH1Index = $listH1Indices[0]
    if ($listVersionRecords.Count -gt 1) {
        return [pscustomobject]@{
            Failure = 'must contain at most one exact document-level Version paragraph immediately after the H1 and within the first 30 body lines.'
            VersionDate = $null
            UpdatedDate = $null
            Revision = $null
        }
    }
    $boolHasVersion = $listVersionRecords.Count -eq 1
    $objVersionMatch = $null
    $intExpectedMetadataIndex = $intH1Index + 1
    if ($boolHasVersion) {
        if ($listVersionRecords[0].BlockIndex -ne ($intH1Index + 1) -or
            $listVersionRecords[0].Block.End -ne
            ($listVersionRecords[0].Block.Start + 1) -or
            ($listVersionRecords[0].Block.Start - $intBodyStart) -ge 30) {
            return [pscustomobject]@{
                Failure = 'must contain at most one exact document-level Version paragraph immediately after the H1 and within the first 30 body lines.'
                VersionDate = $null
                UpdatedDate = $null
                Revision = $null
            }
        }
        $objVersionMatch = [regex]::Match(
            $arrLines[$listVersionRecords[0].Block.Start],
            $strVersionPattern
        )
        if (-not $objVersionMatch.Success) {
            return [pscustomobject]@{
                Failure = 'must contain at most one exact document-level Version paragraph immediately after the H1 and within the first 30 body lines.'
                VersionDate = $null
                UpdatedDate = $null
                Revision = $null
            }
        }
        $intExpectedMetadataIndex = $listVersionRecords[0].BlockIndex + 1
    }

    if ($listH2Indices.Count -eq 0) {
        return [pscustomobject]@{
            Failure = 'must place Metadata as the first level-two heading immediately after the H1 or optional Version and within the first 30 body lines.'
            VersionDate = $null
            UpdatedDate = $null
            Revision = $null
        }
    }

    $intMetadataIndex = $listH2Indices[0]
    $objMetadataBlock = $arrTopLevelBlocks[$intMetadataIndex]
    $intMetadataHeadingCount = @(
        $listH2Indices |
        Where-Object { $arrTopLevelBlocks[$_].Text -ceq 'Metadata' }
    ).Count
    if ($objMetadataBlock.Text -cne 'Metadata' -or
        $intMetadataHeadingCount -ne 1 -or
        $intMetadataIndex -ne $intExpectedMetadataIndex -or
        ($objMetadataBlock.Start - $intBodyStart) -ge 30) {
        return [pscustomobject]@{
            Failure = 'must place Metadata as the first level-two heading immediately after the H1 or optional Version and within the first 30 body lines.'
            VersionDate = $null
            UpdatedDate = $null
            Revision = $null
        }
    }

    $intMetadataSectionEnd = $arrLines.Count
    foreach ($intH2Index in $listH2Indices) {
        if ($intH2Index -gt $intMetadataIndex) {
            $intMetadataSectionEnd = $arrTopLevelBlocks[$intH2Index].Start
            break
        }
    }

    $arrRequiredFields = @(
        [pscustomobject]@{
            Name = 'Status'
            Pattern = '^- \*\*Status:\*\* (?<Value>' +
                (($script:arrAllowedMetadataStatuses |
                        ForEach-Object { [regex]::Escape($_) }) -join '|') + ')$'
        },
        [pscustomobject]@{
            Name = 'Owner'
            Pattern = '^- \*\*Owner:\*\* (?<Value>\S(?:.*\S)?)$'
        },
        [pscustomobject]@{
            Name = 'Last Updated'
            Pattern = '^- \*\*Last Updated:\*\* (?<Date>\d{4}-\d{2}-\d{2})$'
        },
        [pscustomobject]@{
            Name = 'Scope'
            Pattern = '^- \*\*Scope:\*\* (?<Value>\S(?:.*\S)?)$'
        }
    )
    $hashtableFieldMatches = @{}
    $hashtableFieldLineIndices = @{}
    foreach ($objField in $arrRequiredFields) {
        $arrFieldRecords = @(
            $arrTopLevelListItems |
                Where-Object {
                    $_.Text -is [string] -and
                    $_.Text.StartsWith(
                        "$($objField.Name):",
                        [System.StringComparison]::Ordinal
                    ) -and
                    $_.Start -gt $objMetadataBlock.Start -and
                    $_.Start -lt $intMetadataSectionEnd -and
                    ($_.Start - $intBodyStart) -lt 30
                }
        )
        $strFieldFailure = "must contain one exact top-level $($objField.Name) " +
            'list item in the Metadata section and within the first 30 body lines.'
        $boolFieldHasContinuation = $false
        if ($arrFieldRecords.Count -eq 1) {
            for ($intLine = $arrFieldRecords[0].Start + 1;
                $intLine -lt $arrFieldRecords[0].End;
                $intLine++) {
                if (-not [string]::IsNullOrWhiteSpace($arrLines[$intLine])) {
                    $boolFieldHasContinuation = $true
                    break
                }
            }
        }
        if ($arrFieldRecords.Count -ne 1 -or $boolFieldHasContinuation) {
            return [pscustomobject]@{
                Failure = $strFieldFailure
                VersionDate = $null
                UpdatedDate = $null
                Revision = $null
            }
        }
        $objFieldMatch = [regex]::Match(
            $arrLines[$arrFieldRecords[0].Start],
            $objField.Pattern
        )
        if (-not $objFieldMatch.Success) {
            return [pscustomobject]@{
                Failure = $strFieldFailure
                VersionDate = $null
                UpdatedDate = $null
                Revision = $null
            }
        }
        $hashtableFieldMatches[$objField.Name] = $objFieldMatch
        $hashtableFieldLineIndices[$objField.Name] = $arrFieldRecords[0].Start
    }
    $objUpdatedMatch = $hashtableFieldMatches['Last Updated']

    return [pscustomobject]@{
        Failure = $null
        HasVersion = $boolHasVersion
        Major = if ($boolHasVersion) { $objVersionMatch.Groups['Major'].Value } else { $null }
        Minor = if ($boolHasVersion) { $objVersionMatch.Groups['Minor'].Value } else { $null }
        VersionDate = if ($boolHasVersion) { $objVersionMatch.Groups['Date'].Value } else { $null }
        UpdatedDate = $objUpdatedMatch.Groups['Date'].Value
        Revision = if ($boolHasVersion) { $objVersionMatch.Groups['Revision'].Value } else { $null }
        VersionLineIndex = if ($boolHasVersion) {
            $listVersionRecords[0].Block.Start
        }
        else {
            -1
        }
        UpdatedLineIndex = $hashtableFieldLineIndices['Last Updated']
    }
}

function Test-LegacyMetadataParentContent {
    # .SYNOPSIS
    # Tests one exact pre-metadata repository document.
    #
    # .DESCRIPTION
    # Hashes one legacy document and accepts it only when its path and content
    # match the bounded one-time metadata migration allowlist.
    #
    # .PARAMETER Name
    # The governed repository-relative document path.
    #
    # .PARAMETER Content
    # The exact pre-metadata document text to authenticate.
    #
    # .EXAMPLE
    # Test-LegacyMetadataParentContent -Name 'CLAUDE.md' -Content $strParent
    #
    # # Returns true only for the exact allowlisted legacy parent.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [bool] True for an exact allowlisted legacy parent; otherwise, false.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260907.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Content
    )

    if (-not $script:hashtableLegacyMetadataParentSha256.ContainsKey($Name)) {
        return $false
    }

    $objSha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $arrContentHashBytes = $objSha256.ComputeHash(
            [System.Text.UTF8Encoding]::new($false).GetBytes($Content)
        )
    }
    finally {
        $objSha256.Dispose()
    }
    $strContentSha256 = [System.BitConverter]::ToString(
        $arrContentHashBytes
    ).Replace('-', '').ToLowerInvariant()
    return $strContentSha256 -ceq $script:hashtableLegacyMetadataParentSha256[$Name]
}

function Get-DocumentMetadataTransitionFailure {
    # .SYNOPSIS
    # Finds metadata-policy failures in one document transition.
    #
    # .DESCRIPTION
    # Compares current and parent metadata with squash-safe anti-rollback rules.
    #
    # .PARAMETER Name
    # The governed document name used in failure records.
    #
    # .PARAMETER CurrentContent
    # The document text at the current revision.
    #
    # .PARAMETER ParentContent
    # The document text at the parent revision, or null for no comparison.
    #
    # .PARAMETER ExpectedUtcDate
    # The required UTC date after a rendered-content change.
    #
    # .PARAMETER IsNewDocumentTransition
    # Indicates that an absent parent is a governed-document addition.
    #
    # .PARAMETER RequireExpectedUtcDateForRenderedChange
    # Indicates that changed content must use the transition commit's UTC date.
    #
    # .PARAMETER RequirePublishedRevisionConvention
    # Indicates that changed content must recompute its revision from the
    # published baseline. Inherited merge results disable only this computation.
    #
    # .EXAMPLE
    # Get-DocumentMetadataTransitionFailure -Name 'AGENTS.md' `
    #     -CurrentContent $strCurrent -ParentContent $strParent `
    #     -ExpectedUtcDate '2026-08-19' -IsNewDocumentTransition $false `
    #     -RequireExpectedUtcDateForRenderedChange $true
    #
    # # Writes one string for each metadata-policy failure.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each metadata-transition failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.6.20260909.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $CurrentContent,

        [Parameter()]
        [AllowNull()]
        [string] $ParentContent,

        [Parameter()]
        [AllowEmptyString()]
        [string] $ExpectedUtcDate = '',

        [Parameter(Mandatory)]
        [bool] $IsNewDocumentTransition,

        [Parameter()]
        [bool] $RequireExpectedUtcDateForRenderedChange = $true,

        [Parameter()]
        [bool] $RequirePublishedRevisionConvention = $true
    )

    $objCurrentMetadata = Get-DocumentMetadataContext -Content $CurrentContent
    if ($null -ne $objCurrentMetadata.Failure) {
        Write-Output "$Name $($objCurrentMetadata.Failure)"
        return
    }

    $strCurrentUpdatedDate = $objCurrentMetadata.UpdatedDate
    if (-not (Test-MetadataCalendarDate -Date $strCurrentUpdatedDate)) {
        Write-Output "$Name Last Updated must contain one real calendar date."
        return
    }
    if ($objCurrentMetadata.HasVersion -and
        -not (Test-MetadataCalendarDatePair `
            -VersionDate $objCurrentMetadata.VersionDate `
            -UpdatedDate $strCurrentUpdatedDate)) {
        Write-Output "$Name Version and Last Updated must contain one real matching calendar date."
        return
    }
    if ([string]::CompareOrdinal(
            $strCurrentUpdatedDate,
            $script:strMaximumMetadataUtcDate
        ) -gt 0) {
        Write-Output (
            "$Name Last Updated $strCurrentUpdatedDate must not be later than trusted UTC " +
            "date $script:strMaximumMetadataUtcDate."
        )
        return
    }

    if (-not [string]::IsNullOrEmpty($ParentContent) -and
        (Test-LegacyMetadataParentContent -Name $Name -Content $ParentContent)) {
        $ParentContent = $null
        $IsNewDocumentTransition = $true
    }

    if ([string]::IsNullOrEmpty($ParentContent)) {
        if (-not $IsNewDocumentTransition) {
            return
        }
        if ($objCurrentMetadata.HasVersion -and $RequirePublishedRevisionConvention) {
            $intNewDocumentRevision = [int64] 0
            if (-not [int64]::TryParse(
                    $objCurrentMetadata.Revision,
                    [ref] $intNewDocumentRevision
                )) {
                Write-Output "$Name Version revision must fit in a signed 64-bit integer."
                return
            }
            if ($intNewDocumentRevision -ne 0) {
                Write-Output "$Name Version revision must be 0 when no published baseline exists."
                return
            }
        }
        if (-not $RequireExpectedUtcDateForRenderedChange) {
            return
        }
        if ([string]::IsNullOrEmpty($ExpectedUtcDate) -or
            -not (Test-MetadataCalendarDate -Date $ExpectedUtcDate)) {
            Write-Output "The expected UTC date for $Name is unavailable or invalid."
            return
        }
        if ($strCurrentUpdatedDate -cne $ExpectedUtcDate) {
            Write-Output (
                "$Name Last Updated must be $ExpectedUtcDate after a rendered-content change."
            )
        }
        return
    }

    $objParentMetadata = Get-DocumentMetadataContext -Content $ParentContent
    if ($null -ne $objParentMetadata.Failure) {
        Write-Output "The parent of $Name $($objParentMetadata.Failure)"
        return
    }
    $strParentUpdatedDate = $objParentMetadata.UpdatedDate
    if (-not (Test-MetadataCalendarDate -Date $strParentUpdatedDate)) {
        Write-Output "The parent of $Name Last Updated must contain one real calendar date."
        return
    }
    if ($objParentMetadata.HasVersion -and
        -not (Test-MetadataCalendarDatePair `
            -VersionDate $objParentMetadata.VersionDate `
            -UpdatedDate $strParentUpdatedDate)) {
        Write-Output "The parent of $Name must contain one real matching calendar date."
        return
    }
    if ([string]::CompareOrdinal(
            $strParentUpdatedDate,
            $script:strMaximumMetadataUtcDate
        ) -gt 0) {
        Write-Output (
            "The parent of $Name Last Updated $strParentUpdatedDate must not be later than " +
            "trusted UTC date $script:strMaximumMetadataUtcDate."
        )
        return
    }

    $strCurrentComparison = ConvertTo-MetadataComparisonText `
        -Content $CurrentContent -MetadataContext $objCurrentMetadata
    $strParentComparison = ConvertTo-MetadataComparisonText `
        -Content $ParentContent -MetadataContext $objParentMetadata
    $boolRenderedContentChanged = $strCurrentComparison -cne $strParentComparison
    $intCurrentRevision = [int64] 0
    $intParentRevision = [int64] 0
    $boolSameVersionIdentity = $false
    if ($objCurrentMetadata.HasVersion) {
        if (-not [int64]::TryParse(
                $objCurrentMetadata.Revision,
                [ref] $intCurrentRevision
            )) {
            Write-Output "$Name Version revision must fit in a signed 64-bit integer."
            return
        }
        if ($objParentMetadata.HasVersion) {
            if (-not [int64]::TryParse(
                    $objParentMetadata.Revision,
                    [ref] $intParentRevision
                )) {
                Write-Output "$Name Version revision must fit in a signed 64-bit integer."
                return
            }
            $strCurrentVersionIdentity =
                "$($objCurrentMetadata.Major).$($objCurrentMetadata.Minor)." +
                $objCurrentMetadata.VersionDate
            $strParentVersionIdentity =
                "$($objParentMetadata.Major).$($objParentMetadata.Minor)." +
                $objParentMetadata.VersionDate
            $boolSameVersionIdentity =
                $strCurrentVersionIdentity -ceq $strParentVersionIdentity
            $intVersionDateComparison = [string]::CompareOrdinal(
                $objCurrentMetadata.VersionDate,
                $objParentMetadata.VersionDate
            )
            if ($intVersionDateComparison -lt 0) {
                Write-Output (
                    "$Name Version date must not move backward from " +
                    "$($objParentMetadata.VersionDate) to " +
                    "$($objCurrentMetadata.VersionDate)."
                )
            }
            elseif ($boolSameVersionIdentity -and
                $intCurrentRevision -lt $intParentRevision) {
                Write-Output (
                    "$Name Version revision must not decrease from " +
                    "$intParentRevision to $intCurrentRevision."
                )
            }
        }
        elseif ($RequirePublishedRevisionConvention -and $intCurrentRevision -ne 0) {
            Write-Output (
                "$Name Version revision must be 0 when Version is added to an " +
                "unversioned published baseline; current revision is $intCurrentRevision."
            )
        }
    }

    if (-not $boolRenderedContentChanged) {
        return
    }

    if ($RequireExpectedUtcDateForRenderedChange) {
        if ([string]::IsNullOrEmpty($ExpectedUtcDate) -or
            -not (Test-MetadataCalendarDate -Date $ExpectedUtcDate)) {
            Write-Output "The expected UTC date for $Name is unavailable or invalid."
            return
        }
        if ($strCurrentUpdatedDate -cne $ExpectedUtcDate) {
            Write-Output (
                "$Name Last Updated must be $ExpectedUtcDate after a rendered-content change."
            )
        }
    }

    if (-not $objCurrentMetadata.HasVersion -or
        -not $objParentMetadata.HasVersion) {
        return
    }
    if (-not $RequirePublishedRevisionConvention) {
        return
    }
    if ($boolSameVersionIdentity) {
        if ($intParentRevision -eq [int64]::MaxValue) {
            Write-Output "The parent $Name Version revision cannot be incremented safely."
        }
        else {
            $intExpectedRevision = $intParentRevision + 1
            if ($intCurrentRevision -ne $intExpectedRevision) {
                Write-Output (
                    "$Name Version revision must be $intExpectedRevision after a content " +
                    "change with unchanged major, minor, and date; baseline revision is " +
                    "$intParentRevision."
                )
            }
        }
    }
    elseif ($intCurrentRevision -ne 0) {
        Write-Output (
            "$Name Version revision must be 0 when major, minor, or date changes; " +
            "current revision is $intCurrentRevision."
        )
    }
}

function Get-DocumentMetadataRangeTransitionFailure {
    # .SYNOPSIS
    # Finds metadata-policy failures across document transitions.
    #
    # .DESCRIPTION
    # Evaluates each supplied parent-to-current transition and prefixes each
    # failure with the transition commit identities.
    #
    # .PARAMETER Name
    # The governed document name used in failure records.
    #
    # .PARAMETER TransitionContext
    # The ordered transition records to validate. Optional date and published-
    # revision requirements default to true when absent.
    #
    # .EXAMPLE
    # Get-DocumentMetadataRangeTransitionFailure -Name 'AGENTS.md' `
    #     -TransitionContext $arrTransitions
    #
    # # Writes one string for each range-transition failure.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One prefixed record for each metadata-transition failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.1.20260909.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [pscustomobject[]] $TransitionContext
    )

    foreach ($objTransition in $TransitionContext) {
        $objDateRequirementProperty =
            $objTransition.PSObject.Properties['RequireExpectedUtcDateForRenderedChange']
        $boolRequireExpectedUtcDate = if ($null -eq $objDateRequirementProperty) {
            $true
        }
        else {
            [bool] $objDateRequirementProperty.Value
        }
        $objRevisionRequirementProperty =
            $objTransition.PSObject.Properties['RequirePublishedRevisionConvention']
        $boolRequirePublishedRevision = if ($null -eq $objRevisionRequirementProperty) {
            $true
        }
        else {
            [bool] $objRevisionRequirementProperty.Value
        }
        $arrTransitionFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name $Name `
                -CurrentContent $objTransition.CurrentContent `
                -ParentContent $objTransition.ParentContent `
                -ExpectedUtcDate $objTransition.ExpectedUtcDate `
                -IsNewDocumentTransition ($null -eq $objTransition.ParentContent) `
                -RequireExpectedUtcDateForRenderedChange $boolRequireExpectedUtcDate `
                -RequirePublishedRevisionConvention $boolRequirePublishedRevision)
        foreach ($strFailure in $arrTransitionFailures) {
            Write-Output (
                "$Name transition $($objTransition.ParentRevision).." +
                "$($objTransition.CurrentRevision): $strFailure"
            )
        }
    }
}

function Get-MetadataRangePolicyEffectiveBaseRevision {
    # .SYNOPSIS
    # Selects the effective metadata-policy range base.
    #
    # .DESCRIPTION
    # Keeps a base that already contains the policy marker. Otherwise, selects the
    # first parent of the policy-introduction commit.
    #
    # .PARAMETER BaseRevision
    # The event-range base revision.
    #
    # .PARAMETER BaseHasPolicyMarker
    # Indicates whether the event-range base contains the policy marker.
    #
    # .PARAMETER PolicyIntroductionCommit
    # The commit that introduced the policy marker.
    #
    # .PARAMETER PolicyIntroductionParent
    # The first parent of the policy-introduction commit.
    #
    # .EXAMPLE
    # Get-MetadataRangePolicyEffectiveBaseRevision -BaseRevision $strBase `
    #     -BaseHasPolicyMarker $false -PolicyIntroductionCommit $strCommit `
    #     -PolicyIntroductionParent $strParent
    #
    # # Returns the policy-introduction parent revision.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] The effective base revision.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $BaseRevision,

        [Parameter(Mandatory)]
        [bool] $BaseHasPolicyMarker,

        [Parameter()]
        [AllowEmptyString()]
        [string] $PolicyIntroductionCommit = '',

        [Parameter()]
        [AllowEmptyString()]
        [string] $PolicyIntroductionParent = ''
    )

    if ($BaseHasPolicyMarker) {
        return $BaseRevision
    }
    if ([string]::IsNullOrEmpty($PolicyIntroductionCommit) -or
        [string]::IsNullOrEmpty($PolicyIntroductionParent)) {
        throw 'The metadata policy introduction and its first parent are required.'
    }

    return $PolicyIntroductionParent
}

function Get-TrustRootRangeMutationFailure {
    # .SYNOPSIS
    # Finds proposed changes to trusted validation files.
    #
    # .DESCRIPTION
    # Compares exact paths in two Git trees without reading proposed file bytes.
    # Changed paths, invalid revisions, and indeterminate results fail closed.
    #
    # .PARAMETER RepositoryRootPath
    # The absolute repository root used for Git comparisons.
    #
    # .PARAMETER BaseRevision
    # The exact base commit object ID for the proposed range.
    #
    # .PARAMETER HeadRevision
    # The exact head commit object ID for the proposed range.
    #
    # .PARAMETER RepositoryRelativePath
    # The exact protected validation paths that must remain unchanged.
    #
    # .EXAMPLE
    # Get-TrustRootRangeMutationFailure -RepositoryRootPath $strRoot `
    #     -BaseRevision $strBase -HeadRevision $strHead `
    #     -RepositoryRelativePath $arrTrustRoots
    #
    # # Writes one failure for each changed trust-root path.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each changed trust-root path.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260820.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $RepositoryRootPath,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $BaseRevision,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $HeadRevision,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $RepositoryRelativePath
    )

    $strObjectIdPattern = '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$'
    foreach ($strRevision in @($BaseRevision, $HeadRevision)) {
        if ($strRevision -notmatch $strObjectIdPattern) {
            throw "The trusted validation range contains an invalid object ID: $strRevision"
        }
        & git -C $RepositoryRootPath cat-file -e "$strRevision`^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "The trusted validation range commit is unavailable: $strRevision"
        }
    }

    $arrChangedPaths = @(
        & git -C $RepositoryRootPath diff --name-only --no-renames `
            --no-ext-diff --no-textconv $BaseRevision $HeadRevision -- `
            $RepositoryRelativePath
    )
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not compare the trusted validation paths.'
    }
    foreach ($strTrustPath in $RepositoryRelativePath) {
        if ($arrChangedPaths -cnotcontains $strTrustPath) {
            continue
        }
        Write-Output (
            "Pull request changes trusted validation path $strTrustPath. " +
            'Update this trust root only through an authorized trusted-base maintenance path.'
        )
    }
}

function Get-GovernedDocumentCommitTransitionFailure {
    # .SYNOPSIS
    # Finds metadata-policy failures for one commit and all its direct parents.
    #
    # .DESCRIPTION
    # Compares one governed Git blob with every direct parent. A merge can retain
    # the metadata date of an identical parent, but anti-rollback checks still
    # apply against every parent whose governed blob differs.
    #
    # .PARAMETER Name
    # The governed document name used in failure records.
    #
    # .PARAMETER RepositoryRootPath
    # The absolute repository root path used by Git.
    #
    # .PARAMETER RepositoryRelativePath
    # The repository-relative governed document path.
    #
    # .PARAMETER MaximumBytes
    # The largest accepted governed-document blob byte count.
    #
    # .PARAMETER CommitRevision
    # The exact commit whose direct transition is validated.
    #
    # .PARAMETER RequireMetadataTransition
    # Indicates that visible document metadata must be validated after Git safety checks.
    #
    # .EXAMPLE
    # Get-GovernedDocumentCommitTransitionFailure -Name 'AGENTS.md' `
    #     -RepositoryRootPath $strRoot -RepositoryRelativePath 'AGENTS.md' `
    #     -MaximumBytes 32768 -CommitRevision $strCommit
    #
    # # Writes one string for each direct-transition failure.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each governed direct-transition failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.2.20260909.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $RepositoryRootPath,

        [Parameter(Mandatory)]
        [string] $RepositoryRelativePath,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483646)]
        [int] $MaximumBytes,

        [Parameter(Mandatory)]
        [string] $CommitRevision,

        [Parameter()]
        [bool] $RequireMetadataTransition = $true
    )

    $strObjectIdPattern = '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$'
    if ($CommitRevision -notmatch $strObjectIdPattern) {
        throw "The governed direct-transition commit is invalid: $CommitRevision"
    }
    & git -C $RepositoryRootPath cat-file -e "$CommitRevision`^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "The governed direct-transition commit is unavailable: $CommitRevision"
    }

    $strParentLine = [string] (
        & git -C $RepositoryRootPath rev-list --parents -n 1 $CommitRevision
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Could not read the parents of metadata range commit $CommitRevision."
    }
    $arrCommitAndParents = @($strParentLine.Trim() -split '\s+')
    if ($arrCommitAndParents.Count -eq 0 -or
        $arrCommitAndParents[0] -notmatch $strObjectIdPattern -or
        -not [string]::Equals(
            $arrCommitAndParents[0],
            $CommitRevision,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Git returned an invalid identity for metadata range commit $CommitRevision."
    }
    if ($arrCommitAndParents.Count -eq 1) {
        return [string[]] @()
    }
    $intParentCount = $arrCommitAndParents.Count - 1
    if ($intParentCount -gt $intMetadataMaximumParents) {
        throw (
            "Metadata range commit $CommitRevision has $intParentCount parents; " +
            "the maximum is $intMetadataMaximumParents."
        )
    }

    $listChangedParents = [System.Collections.Generic.List[string]]::new()
    $boolInheritsParentPath = $false
    foreach ($strParentRevision in $arrCommitAndParents[1..$intParentCount]) {
        if ($strParentRevision -notmatch $strObjectIdPattern) {
            throw "Git returned an invalid parent for metadata range commit $CommitRevision."
        }
        & git -C $RepositoryRootPath cat-file -e `
            "$strParentRevision`^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Git returned an unavailable parent for metadata range commit $CommitRevision."
        }

        & git -C $RepositoryRootPath diff --quiet --no-ext-diff --no-textconv `
            $strParentRevision $CommitRevision -- $RepositoryRelativePath
        $intDiffExitCode = $LASTEXITCODE
        if ($intDiffExitCode -eq 0) {
            $boolInheritsParentPath = $true
            continue
        }
        if ($intDiffExitCode -ne 1) {
            throw (
                "Could not compare $RepositoryRelativePath for metadata range commit " +
                "$CommitRevision."
            )
        }
        $listChangedParents.Add($strParentRevision)
    }
    if ($listChangedParents.Count -eq 0) {
        return [string[]] @()
    }

    $strCommitTimestamp = [string] (
        & git -C $RepositoryRootPath show -s --format=%cI $CommitRevision
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Could not read the timestamp of metadata range commit $CommitRevision."
    }
    $objCommitTimestamp = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse(
            $strCommitTimestamp.Trim(),
            [ref] $objCommitTimestamp
        )) {
        throw "Metadata range commit $CommitRevision has an invalid timestamp."
    }
    if ($objCommitTimestamp -gt $script:objMaximumCommitUtcTimestamp) {
        Write-Output (
            "Metadata range commit $CommitRevision timestamp " +
            "$($objCommitTimestamp.ToUniversalTime().ToString('o')) must not be later than " +
            "trusted UTC $($script:objMaximumCommitUtcTimestamp.ToString('o'))."
        )
        return
    }

    $strCurrentContent = Read-GitRevisionText `
        -RepositoryRootPath $RepositoryRootPath `
        -Revision $CommitRevision `
        -RepositoryRelativePath $RepositoryRelativePath `
        -MaximumBytes $MaximumBytes `
        -RequireRegularFile
    $boolRequireExpectedUtcDate = -not (
        $intParentCount -gt 1 -and $boolInheritsParentPath
    )
    $listTransitions = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($strChangedParentRevision in $listChangedParents) {
        & git -C $RepositoryRootPath cat-file -e `
            "$strChangedParentRevision`:$RepositoryRelativePath" 2>$null
        $strParentContent = if ($LASTEXITCODE -eq 0) {
            Read-GitRevisionText `
                -RepositoryRootPath $RepositoryRootPath `
                -Revision $strChangedParentRevision `
                -RepositoryRelativePath $RepositoryRelativePath `
                -MaximumBytes $MaximumBytes `
                -RequireRegularFile
        }
        else {
            $null
        }
        $listTransitions.Add([pscustomobject]@{
                CurrentContent = $strCurrentContent
                ParentContent = $strParentContent
                ExpectedUtcDate = $objCommitTimestamp.UtcDateTime.ToString('yyyy-MM-dd')
                CurrentRevision = $CommitRevision
                ParentRevision = $strChangedParentRevision
                RequireExpectedUtcDateForRenderedChange = $boolRequireExpectedUtcDate
                RequirePublishedRevisionConvention = -not (
                    $intParentCount -gt 1 -and $boolInheritsParentPath
                )
            })
    }

    if (-not $RequireMetadataTransition) {
        return [string[]] @()
    }

    return Get-DocumentMetadataRangeTransitionFailure `
        -Name $Name `
        -TransitionContext $listTransitions.ToArray()
}

function Get-GovernedDocumentRangeTransitionFailure {
    # .SYNOPSIS
    # Finds metadata failures in a governed Git event range.
    #
    # .DESCRIPTION
    # Validates event-range identities, locates the policy introduction when
    # needed, and evaluates one published-base-to-final-head document transition.
    # Internal topic commits are inspected for safe governed blobs, not as
    # separate published metadata transitions. New-ref ranges accept only Git's
    # all-zero base sentinel.
    #
    # .PARAMETER Name
    # The governed document name used in failure records.
    #
    # .PARAMETER RepositoryRootPath
    # The absolute repository root path used by Git.
    #
    # .PARAMETER RepositoryRelativePath
    # The repository-relative governed document path.
    #
    # .PARAMETER MaximumBytes
    # The largest accepted governed-document blob byte count.
    #
    # .PARAMETER BaseRevision
    # The first excluded event-range revision or all-zero new-ref sentinel.
    #
    # .PARAMETER HeadRevision
    # The last included event-range commit.
    #
    # .PARAMETER InputRevision
    # The optional commit that supplies the current governed input state.
    #
    # .PARAMETER IsNewRefRange
    # Indicates that the event created a ref and supplied an all-zero base.
    #
    # .PARAMETER PolicyRepositoryRelativePath
    # The repository-relative file that contains the policy marker.
    #
    # .PARAMETER PolicyMaximumBytes
    # The largest accepted policy-file blob byte count.
    #
    # .PARAMETER PolicyMarker
    # The literal that identifies the policy introduction.
    #
    # .PARAMETER RequireMetadataTransition
    # Indicates that visible document metadata must be validated after Git safety checks.
    #
    # .EXAMPLE
    # Get-GovernedDocumentRangeTransitionFailure -Name 'AGENTS.md' `
    #     -RepositoryRootPath $strRoot -RepositoryRelativePath 'AGENTS.md' `
    #     -MaximumBytes 32768 -BaseRevision $strBase -HeadRevision $strHead `
    #     -IsNewRefRange $false `
    #     -PolicyRepositoryRelativePath $strPolicyPath `
    #     -PolicyMaximumBytes 262144 -PolicyMarker $strMarker
    #
    # # Writes one string for each governed range-transition failure.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each governed range-transition failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.6.20260909.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $RepositoryRootPath,

        [Parameter(Mandatory)]
        [string] $RepositoryRelativePath,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483646)]
        [int] $MaximumBytes,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $BaseRevision,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $HeadRevision,

        [Parameter()]
        [AllowEmptyString()]
        [string] $InputRevision = '',

        [Parameter(Mandatory)]
        [bool] $IsNewRefRange,

        [Parameter(Mandatory)]
        [string] $PolicyRepositoryRelativePath,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483646)]
        [int] $PolicyMaximumBytes,

        [Parameter(Mandatory)]
        [string] $PolicyMarker,

        [Parameter()]
        [bool] $RequireMetadataTransition = $true
    )

    if ([string]::IsNullOrEmpty($BaseRevision) -and
        [string]::IsNullOrEmpty($HeadRevision)) {
        if ($IsNewRefRange) {
            throw 'A new-ref metadata event range must supply base and head revisions.'
        }
        return [string[]] @()
    }
    if ([string]::IsNullOrEmpty($BaseRevision) -or
        [string]::IsNullOrEmpty($HeadRevision)) {
        throw 'The metadata event range must supply both base and head revisions.'
    }

    $strObjectIdPattern = '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$'
    $strZeroObjectIdPattern = '^(?:0{40}|0{64})$'
    $boolBaseIsZeroObjectId = $BaseRevision -match $strZeroObjectIdPattern
    if ($IsNewRefRange -and -not $boolBaseIsZeroObjectId) {
        throw 'A new-ref metadata event range requires an all-zero base revision.'
    }
    if (-not $IsNewRefRange -and $boolBaseIsZeroObjectId) {
        throw 'An all-zero metadata event-range base requires the new-ref flag.'
    }
    if ($HeadRevision -match $strZeroObjectIdPattern) {
        throw 'The metadata event-range head must not be an all-zero object ID.'
    }

    foreach ($strRevision in @($BaseRevision, $HeadRevision)) {
        if ($strRevision -notmatch $strObjectIdPattern) {
            throw "The metadata event range contains an invalid object ID: $strRevision"
        }
        if ($strRevision -eq $BaseRevision -and $boolBaseIsZeroObjectId) {
            continue
        }
        & git -C $RepositoryRootPath cat-file -e "$strRevision`^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "The metadata event-range commit is unavailable: $strRevision"
        }
    }

    $strValidationRevision = if ([string]::IsNullOrEmpty($InputRevision)) {
        'HEAD'
    }
    else {
        $InputRevision
    }
    $strCheckedOutHead = [string] (
        & git -C $RepositoryRootPath rev-parse --verify `
            "$strValidationRevision`^{commit}"
    )
    if ($LASTEXITCODE -ne 0 -or
        -not [string]::Equals(
            $strCheckedOutHead.Trim(),
            $HeadRevision,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw "The metadata event-range head does not match the validation revision: $HeadRevision"
    }
    if ([string]::Equals(
            $BaseRevision,
            $HeadRevision,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        return [string[]] @()
    }

    $boolHeadHasPolicyMarker = Test-GitRevisionFileContainsLiteral `
        -RepositoryRootPath $RepositoryRootPath `
        -Revision $HeadRevision `
        -RepositoryRelativePath $PolicyRepositoryRelativePath `
        -MaximumBytes $PolicyMaximumBytes `
        -Literal $PolicyMarker
    if (-not $boolHeadHasPolicyMarker) {
        throw "The metadata event-range head does not contain policy marker $PolicyMarker."
    }

    $boolBaseHasPolicyMarker = $false
    if (-not $IsNewRefRange) {
        $boolBaseHasPolicyMarker = Test-GitRevisionFileContainsLiteral `
            -RepositoryRootPath $RepositoryRootPath `
            -Revision $BaseRevision `
            -RepositoryRelativePath $PolicyRepositoryRelativePath `
            -MaximumBytes $PolicyMaximumBytes `
            -Literal $PolicyMarker
    }
    if (-not $boolBaseHasPolicyMarker) {
        if ($IsNewRefRange) {
            $arrPolicyPathCommits = @(
                & git -C $RepositoryRootPath log --reverse --topo-order `
                    --format=%H "-S$PolicyMarker" $HeadRevision -- `
                    $PolicyRepositoryRelativePath 2>&1
            )
        }
        else {
            $arrPolicyPathCommits = @(
                & git -C $RepositoryRootPath log --reverse --topo-order `
                    --format=%H "-S$PolicyMarker" "$BaseRevision..$HeadRevision" -- `
                    $PolicyRepositoryRelativePath 2>&1
            )
        }
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not enumerate metadata policy-marker changes.'
        }

        $strPolicyIntroductionCommit = ''
        foreach ($strPolicyCommitValue in $arrPolicyPathCommits) {
            $strPolicyCommit = ([string]$strPolicyCommitValue).Trim()
            if ($strPolicyCommit -notmatch $strObjectIdPattern) {
                throw "Git returned an invalid metadata policy commit: $strPolicyCommit"
            }
            if (Test-GitRevisionFileContainsLiteral `
                    -RepositoryRootPath $RepositoryRootPath `
                    -Revision $strPolicyCommit `
                    -RepositoryRelativePath $PolicyRepositoryRelativePath `
                    -MaximumBytes $PolicyMaximumBytes `
                    -Literal $PolicyMarker) {
                $strPolicyIntroductionCommit = $strPolicyCommit
                break
            }
        }
        if ([string]::IsNullOrEmpty($strPolicyIntroductionCommit)) {
            throw "Could not locate the introduction of metadata policy marker $PolicyMarker."
        }

        $strPolicyParentLine = [string] (
            & git -C $RepositoryRootPath rev-list --parents -n 1 `
                $strPolicyIntroductionCommit
        )
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not read the metadata policy-introduction parent.'
        }
        $arrPolicyCommitAndParents = @($strPolicyParentLine.Trim() -split ' ')
        if ($arrPolicyCommitAndParents.Count -eq 1 -and $IsNewRefRange) {
            $strEffectiveBaseRevision = ''
        }
        elseif ($arrPolicyCommitAndParents.Count -lt 2 -or
            $arrPolicyCommitAndParents[1] -notmatch $strObjectIdPattern) {
            throw 'The metadata policy-introduction commit must have a valid first parent.'
        }
        else {
            $strEffectiveBaseRevision = Get-MetadataRangePolicyEffectiveBaseRevision `
                -BaseRevision $BaseRevision `
                -BaseHasPolicyMarker $false `
                -PolicyIntroductionCommit $strPolicyIntroductionCommit `
                -PolicyIntroductionParent $arrPolicyCommitAndParents[1]
        }
    }
    else {
        $strEffectiveBaseRevision = Get-MetadataRangePolicyEffectiveBaseRevision `
            -BaseRevision $BaseRevision `
            -BaseHasPolicyMarker $true
    }

    if ([string]::IsNullOrEmpty($strEffectiveBaseRevision)) {
        $arrRangeCommits = @(
            & git -C $RepositoryRootPath rev-list --reverse --topo-order `
                $HeadRevision 2>&1
        )
    }
    else {
        $arrRangeCommits = @(
            & git -C $RepositoryRootPath rev-list --reverse --topo-order `
                "$strEffectiveBaseRevision..$HeadRevision" 2>&1
        )
    }
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not enumerate the metadata event range.'
    }

    $boolRangePathSeen = $false
    if (-not [string]::IsNullOrEmpty($strEffectiveBaseRevision)) {
        $arrEffectiveBasePathEntries = @(
            & git -C $RepositoryRootPath ls-tree --full-tree `
                $strEffectiveBaseRevision -- $RepositoryRelativePath 2>&1
        )
        if ($LASTEXITCODE -ne 0) {
            throw (
                "Could not inspect published baseline " +
                "$strEffectiveBaseRevision`:$RepositoryRelativePath in Git."
            )
        }
        $boolRangePathSeen = $arrEffectiveBasePathEntries.Count -gt 0
    }
    $setValidatedRangeBlobIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $strHeadTimestamp = ''
    $intHeadParentCount = 0
    $boolHeadInheritsParentPath = $false
    foreach ($strRangeCommitValue in $arrRangeCommits) {
        $strRangeCommit = ([string]$strRangeCommitValue).Trim()
        if ($strRangeCommit -notmatch $strObjectIdPattern) {
            throw "Git returned an invalid metadata range commit: $strRangeCommit"
        }
        & git -C $RepositoryRootPath cat-file -e `
            "$strRangeCommit`^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Git returned an unavailable metadata range commit: $strRangeCommit"
        }

        $arrRangePathEntries = @(
            & git -C $RepositoryRootPath ls-tree --full-tree `
                $strRangeCommit -- $RepositoryRelativePath 2>&1
        )
        if ($LASTEXITCODE -ne 0) {
            throw "Could not inspect $strRangeCommit`:$RepositoryRelativePath in Git."
        }
        if ($arrRangePathEntries.Count -eq 0) {
            if ($boolRangePathSeen) {
                throw (
                    "Metadata range commit $strRangeCommit is missing governed path " +
                    "$RepositoryRelativePath after that path first appeared."
                )
            }
        }
        else {
            $strExpectedRangeEntryPattern =
                '^100644 blob (?<ObjectId>(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64}))\t' +
                [regex]::Escape($RepositoryRelativePath) + '$'
            $objRangePathEntryMatch = if ($arrRangePathEntries.Count -eq 1) {
                [regex]::Match(
                    [string] $arrRangePathEntries[0],
                    $strExpectedRangeEntryPattern
                )
            }
            else {
                [System.Text.RegularExpressions.Match]::Empty
            }
            if (-not $objRangePathEntryMatch.Success) {
                throw (
                    "Metadata range commit $strRangeCommit does not contain exactly one " +
                    "regular 100644 blob at $RepositoryRelativePath."
                )
            }
            $boolRangePathSeen = $true
            $strRangeBlobId = $objRangePathEntryMatch.Groups['ObjectId'].Value
            if ($setValidatedRangeBlobIds.Add($strRangeBlobId)) {
                [void](Read-GitRevisionText `
                        -RepositoryRootPath $RepositoryRootPath `
                        -Revision $strRangeCommit `
                        -RepositoryRelativePath $RepositoryRelativePath `
                        -MaximumBytes $MaximumBytes `
                        -RequireRegularFile)
            }
        }

        $strParentLine = [string] (
            & git -C $RepositoryRootPath rev-list --parents -n 1 $strRangeCommit
        )
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read the parents of metadata range commit $strRangeCommit."
        }
        $arrCommitAndParents = @($strParentLine.Trim() -split '\s+')
        if ($arrCommitAndParents.Count -eq 0 -or
            $arrCommitAndParents[0] -notmatch $strObjectIdPattern -or
            -not [string]::Equals(
                $arrCommitAndParents[0],
                $strRangeCommit,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
            throw "Git returned an invalid identity for metadata range commit $strRangeCommit."
        }
        $intParentCount = $arrCommitAndParents.Count - 1
        if ($intParentCount -gt $intMetadataMaximumParents) {
            throw (
                "Metadata range commit $strRangeCommit has $intParentCount parents; " +
                "the maximum is $intMetadataMaximumParents."
            )
        }
        if ($intParentCount -gt 0) {
            foreach ($strParentRevision in $arrCommitAndParents[1..$intParentCount]) {
                if ($strParentRevision -notmatch $strObjectIdPattern) {
                    throw "Git returned an invalid parent for metadata range commit $strRangeCommit."
                }
                & git -C $RepositoryRootPath cat-file -e `
                    "$strParentRevision`^{commit}" 2>$null
                if ($LASTEXITCODE -ne 0) {
                    throw "Git returned an unavailable parent for metadata range commit $strRangeCommit."
                }
            }
        }

        $strCommitTimestamp = [string] (
            & git -C $RepositoryRootPath show -s --format=%cI $strRangeCommit
        )
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read the timestamp of metadata range commit $strRangeCommit."
        }
        $objCommitTimestamp = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse(
                $strCommitTimestamp.Trim(),
                [ref] $objCommitTimestamp
            )) {
            throw "Metadata range commit $strRangeCommit has an invalid timestamp."
        }
        if ($objCommitTimestamp -gt $script:objMaximumCommitUtcTimestamp) {
            Write-Output (
                "Metadata range commit $strRangeCommit timestamp " +
                "$($objCommitTimestamp.ToUniversalTime().ToString('o')) must not be later than " +
                "trusted UTC $($script:objMaximumCommitUtcTimestamp.ToString('o'))."
            )
            return
        }

        if ([string]::Equals(
                $strRangeCommit,
                $HeadRevision,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
            $strHeadTimestamp = $objCommitTimestamp.UtcDateTime.ToString('yyyy-MM-dd')
            $intHeadParentCount = $intParentCount
            if ($intParentCount -gt 1) {
                foreach ($strParentRevision in $arrCommitAndParents[1..$intParentCount]) {
                    & git -C $RepositoryRootPath diff --quiet --no-ext-diff --no-textconv `
                        $strParentRevision $HeadRevision -- $RepositoryRelativePath
                    $intDiffExitCode = $LASTEXITCODE
                    if ($intDiffExitCode -eq 0) {
                        $boolHeadInheritsParentPath = $true
                    }
                    elseif ($intDiffExitCode -ne 1) {
                        throw (
                            "Could not compare $RepositoryRelativePath for metadata range " +
                            "commit $HeadRevision."
                        )
                    }
                }
            }
        }
    }
    if ([string]::IsNullOrEmpty($strHeadTimestamp)) {
        throw 'The metadata event range did not contain its head commit.'
    }

    if (-not [string]::IsNullOrEmpty($strEffectiveBaseRevision)) {
        & git -C $RepositoryRootPath diff --quiet --no-ext-diff --no-textconv `
            $strEffectiveBaseRevision $HeadRevision -- $RepositoryRelativePath
        $intPublishedDiffExitCode = $LASTEXITCODE
        if ($intPublishedDiffExitCode -eq 0) {
            return [string[]] @()
        }
        if ($intPublishedDiffExitCode -ne 1) {
            throw "Could not compare the published metadata endpoints for $RepositoryRelativePath."
        }
    }

    if (-not $RequireMetadataTransition) {
        return [string[]] @()
    }

    $strCurrentContent = Read-GitRevisionText `
        -RepositoryRootPath $RepositoryRootPath `
        -Revision $HeadRevision `
        -RepositoryRelativePath $RepositoryRelativePath `
        -MaximumBytes $MaximumBytes `
        -RequireRegularFile
    $strParentContent = $null
    $strParentRevisionLabel = $BaseRevision
    if (-not [string]::IsNullOrEmpty($strEffectiveBaseRevision)) {
        $strParentRevisionLabel = $strEffectiveBaseRevision
        & git -C $RepositoryRootPath cat-file -e `
            "$strEffectiveBaseRevision`:$RepositoryRelativePath" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $strParentContent = Read-GitRevisionText `
                -RepositoryRootPath $RepositoryRootPath `
                -Revision $strEffectiveBaseRevision `
                -RepositoryRelativePath $RepositoryRelativePath `
                -MaximumBytes $MaximumBytes `
                -RequireRegularFile
        }
    }

    $objPublishedTransition = [pscustomobject]@{
        CurrentContent = $strCurrentContent
        ParentContent = $strParentContent
        ExpectedUtcDate = $strHeadTimestamp
        CurrentRevision = $HeadRevision
        ParentRevision = $strParentRevisionLabel
        RequireExpectedUtcDateForRenderedChange = -not (
            $intHeadParentCount -gt 1 -and $boolHeadInheritsParentPath
        )
        RequirePublishedRevisionConvention = -not (
            $intHeadParentCount -gt 1 -and $boolHeadInheritsParentPath
        )
    }
    return Get-DocumentMetadataRangeTransitionFailure `
        -Name $Name `
        -TransitionContext @($objPublishedTransition)
}

function Get-TomlSemanticStatementContext {
    # .SYNOPSIS
    # Gets semantic TOML statement locations.
    #
    # .DESCRIPTION
    # Scans physical lines and writes each nonblank, noncomment TOML statement
    # with its zero-based text offset.
    #
    # .PARAMETER Content
    # The TOML text to scan.
    #
    # .EXAMPLE
    # $arrStatements = @(Get-TomlSemanticStatementContext -Content $strToml)
    #
    # # Collects semantic statement text and source offsets.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] One semantic TOML statement and source offset.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $intLineStart = 0
    while ($intLineStart -lt $Content.Length) {
        $intLineEnd = $Content.IndexOfAny([char[]] "`r`n", $intLineStart)
        if ($intLineEnd -lt 0) {
            $intLineEnd = $Content.Length
        }

        $strLine = $Content.Substring($intLineStart, $intLineEnd - $intLineStart)
        $strTrimmedLine = $strLine.TrimStart()
        if ($strTrimmedLine.Length -gt 0 -and
            -not $strTrimmedLine.StartsWith('#', [System.StringComparison]::Ordinal)) {
            Write-Output ([pscustomobject]@{
                    Text = $strLine
                    Index = $intLineStart
                })
        }

        if ($intLineEnd -eq $Content.Length) {
            break
        }
        if ($Content[$intLineEnd] -eq "`r" -and
            ($intLineEnd + 1) -lt $Content.Length -and
            $Content[$intLineEnd + 1] -eq "`n") {
            $intLineStart = $intLineEnd + 2
        }
        else {
            $intLineStart = $intLineEnd + 1
        }
    }
}

function Get-GitHubPluginEnablementContext {
    # .SYNOPSIS
    # Gets GitHub plugin enablement locations from TOML.
    #
    # .DESCRIPTION
    # Uses parser-confirmed statement identities and returns the matching table
    # count, enablement count, value, and value location.
    #
    # .PARAMETER Content
    # The project TOML text to inspect.
    #
    # .EXAMPLE
    # Get-GitHubPluginEnablementContext -Content $strCodexConfigContent
    #
    # # Returns the table and enabled-value match context.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] Counts, value, and source location for plugin enablement.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.1.20260820.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Content
    )

    $objTomlContext = Get-TomlParseContext -Content $Content
    $arrStatements = @(Get-TomlSemanticStatementContext -Content $Content)
    $boolTableHeaderMatches = [string]::IsNullOrEmpty($objTomlContext.Failure) -and
        $objTomlContext.PluginHeaderIsSecondStatement
    $intEnablementMatchCount = 0
    $strEnabledValue = ''
    $intEnabledValueIndex = -1
    $intEnabledValueLength = 0
    if ($boolTableHeaderMatches -and
        $objTomlContext.PluginEnablementIsThirdStatement -and
        $arrStatements.Count -gt 2 -and
        $objTomlContext.PluginEnabledValueStatementOffset -ge 0 -and
        ($objTomlContext.PluginEnabledValueStatementOffset +
            $objTomlContext.PluginEnabledValueLength) -le $arrStatements[2].Text.Length) {
        $intEnablementMatchCount = 1
        $intEnabledValueLength = $objTomlContext.PluginEnabledValueLength
        $strEnabledValue = $arrStatements[2].Text.Substring(
            $objTomlContext.PluginEnabledValueStatementOffset,
            $intEnabledValueLength
        )
        $intEnabledValueIndex = $arrStatements[2].Index +
            $objTomlContext.PluginEnabledValueStatementOffset
    }

    return [pscustomobject]@{
        TableMatchCount = [int]$boolTableHeaderMatches
        EnablementMatchCount = $intEnablementMatchCount
        EnabledValue = $strEnabledValue
        EnabledValueIndex = $intEnabledValueIndex
        EnabledValueLength = $intEnabledValueLength
    }
}

function ConvertTo-DisabledGitHubPluginMutation {
    # .SYNOPSIS
    # Creates a disabled GitHub plugin mutation.
    #
    # .DESCRIPTION
    # Replaces the unique enabled value in valid project TOML with false. It
    # rejects ambiguous input and verifies that the mutation changes the text.
    #
    # .PARAMETER Content
    # The project TOML text to mutate.
    #
    # .EXAMPLE
    # ConvertTo-DisabledGitHubPluginMutation -Content $strCodexConfigContent
    #
    # # Returns TOML with the GitHub plugin disabled.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] The disabled-plugin TOML mutation.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260819.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Content
    )

    $objContext = Get-GitHubPluginEnablementContext -Content $Content
    if ($objContext.TableMatchCount -ne 1 -or
        $objContext.EnablementMatchCount -ne 1 -or
        $objContext.EnabledValue -cne 'true' -or
        $objContext.EnabledValueIndex -lt 0 -or
        $objContext.EnabledValueLength -ne 4) {
        throw 'Could not locate one enabled GitHub plugin value for the disabled mutation.'
    }

    $strMutation = $Content.Remove(
        $objContext.EnabledValueIndex,
        $objContext.EnabledValueLength
    ).Insert(
        $objContext.EnabledValueIndex,
        'false'
    )
    if ($strMutation -ceq $Content) {
        throw 'The disabled GitHub plugin mutation did not change the configuration.'
    }

    return $strMutation
}

function Get-AgentInstructionFailure {
    # .SYNOPSIS
    # Finds violations of the shared agent-instruction contract.
    #
    # .DESCRIPTION
    # Validates project TOML, capacity, operative Markdown capabilities, placement
    # safety, deferral policy, reviewer controls, and document metadata.
    #
    # .PARAMETER AgentsContent
    # The current AGENTS.md text.
    #
    # .PARAMETER ClaudeContent
    # The current CLAUDE.md text.
    #
    # .PARAMETER CodexConfigContent
    # The current .codex/config.toml text.
    #
    # .PARAMETER ParentAgentsContent
    # The parent AGENTS.md text, or null for no metadata comparison.
    #
    # .PARAMETER ParentClaudeContent
    # The parent CLAUDE.md text, or null for no metadata comparison.
    #
    # .PARAMETER AgentsExpectedUtcDate
    # The required AGENTS.md UTC metadata date after a content change.
    #
    # .PARAMETER ClaudeExpectedUtcDate
    # The required CLAUDE.md UTC metadata date after a content change.
    #
    # .EXAMPLE
    # Get-AgentInstructionFailure -AgentsContent $strAgents `
    #     -ClaudeContent $strClaude -CodexConfigContent $strConfig
    #
    # # Writes one string for each contract failure.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each agent-instruction contract failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.1.20260908.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $AgentsContent,

        [Parameter(Mandatory)]
        [string] $ClaudeContent,

        [Parameter(Mandatory)]
        [string] $CodexConfigContent,

        [Parameter()]
        [AllowNull()]
        [string] $ParentAgentsContent,

        [Parameter()]
        [AllowNull()]
        [string] $ParentClaudeContent,

        [Parameter()]
        [AllowEmptyString()]
        [string] $AgentsExpectedUtcDate = '',

        [Parameter()]
        [AllowEmptyString()]
        [string] $ClaudeExpectedUtcDate = ''
    )

    $objTomlParseContext = Get-TomlParseContext -Content $CodexConfigContent
    if (-not [string]::IsNullOrEmpty($objTomlParseContext.Failure)) {
        Write-Output $objTomlParseContext.Failure
        return
    }

    if (-not $objTomlParseContext.CapacityIsFirstStatement) {
        Write-Output 'project_doc_max_bytes must be the first semantic TOML statement.'
    }

    if (-not $objTomlParseContext.PluginHeaderIsSecondStatement) {
        Write-Output (
            'The github@openai-curated plugin table must be the second semantic TOML statement.'
        )
    }

    if (-not $objTomlParseContext.PluginEnablementIsThirdStatement) {
        Write-Output (
            'The github@openai-curated enabled value must be the third semantic TOML statement.'
        )
    }

    $intConfiguredMaximumBytes = [int64]0
    if (-not $objTomlParseContext.CapacityPresent -or
        $objTomlParseContext.CapacityType -cne 'int') {
        Write-Output 'project_doc_max_bytes must be an integer.'
    }
    elseif (-not $objTomlParseContext.CapacityFitsInt64) {
        Write-Output 'project_doc_max_bytes must fit in a signed 64-bit integer.'
    }
    else {
        $intConfiguredMaximumBytes = $objTomlParseContext.CapacityValue
        if ($intConfiguredMaximumBytes -lt 65536) {
            Write-Output 'project_doc_max_bytes must be at least 65536.'
        }
    }

    if (-not $objTomlParseContext.PluginTablePresent -or
        $objTomlParseContext.PluginTableType -cne 'dict') {
        Write-Output (
            'The project configuration must declare [plugins."github@openai-curated"] exactly once.'
        )
    }
    elseif (-not $objTomlParseContext.PluginEnabledPresent -or
        $objTomlParseContext.PluginEnabledType -cne 'bool' -or
        -not $objTomlParseContext.PluginEnabledValue) {
        Write-Output (
            'The github@openai-curated plugin table must declare enabled = true exactly once.'
        )
    }

    $intAgentsBytes = [System.Text.Encoding]::UTF8.GetByteCount($AgentsContent)
    if ($intAgentsBytes -gt 32768) {
        Write-Output 'AGENTS.md must not exceed the ordinary 32768-byte Codex limit.'
    }
    if (($intConfiguredMaximumBytes - $intAgentsBytes) -lt 16384) {
        Write-Output 'Configured AGENTS.md capacity must retain at least 16384 bytes of reserve.'
    }

    $objAgentsMarkdownContext = Get-OperativeMarkdownContext -Content $AgentsContent
    $objClaudeMarkdownContext = Get-OperativeMarkdownContext -Content $ClaudeContent
    $strAgentsOperativeContent = $objAgentsMarkdownContext.Text
    $strClaudeOperativeContent = $objClaudeMarkdownContext.Text
    $objAgentsPlacementContext = Get-MarkdownLevelTwoSectionContext `
        -MarkdownContext $objAgentsMarkdownContext `
        -Heading 'PR Review Workflow (Codex-adapted)'
    $objAgentsSafetyContext = Get-MarkdownLevelTwoSectionContext `
        -MarkdownContext $objAgentsMarkdownContext `
        -Heading 'Automated Review Loop (User-Initiated)'
    $objClaudeLoopContext = Get-MarkdownLevelTwoSectionContext `
        -MarkdownContext $objClaudeMarkdownContext `
        -Heading 'Automated Review Loop'
    $objClaudeReviewContext = Get-MarkdownLevelTwoSectionContext `
        -MarkdownContext $objClaudeMarkdownContext `
        -Heading 'Handling Code Review Comments'
    $arrDocuments = @(
        [pscustomobject]@{
            Name = 'AGENTS.md'
            RawContent = $AgentsContent
            Content = $strAgentsOperativeContent
            ProseContent = $objAgentsMarkdownContext.ProseText
            LevelTwoHeadings = $objAgentsMarkdownContext.LevelTwoHeadings
            ParentContent = $ParentAgentsContent
            ExpectedUtcDate = $AgentsExpectedUtcDate
            ReviewPolicyContext = $objAgentsPlacementContext
            InventoryPrefix = 'Inline threads. Enumerate'
            SyntheticPrefix = 'Key each review-body-only finding as'
            PlacementContent = $objAgentsPlacementContext.Text
            PlacementProseContent = $objAgentsPlacementContext.ProseText
            SafetyContent = $objAgentsSafetyContext.Text
            SafetyProseContent = $objAgentsSafetyContext.ProseText
            CodeSpans = [string[]]@($objAgentsMarkdownContext.ProseBlocks.Code)
        },
        [pscustomobject]@{
            Name = 'CLAUDE.md'
            RawContent = $ClaudeContent
            Content = $strClaudeOperativeContent
            ProseContent = $objClaudeMarkdownContext.ProseText
            LevelTwoHeadings = $objClaudeMarkdownContext.LevelTwoHeadings
            ParentContent = $ParentClaudeContent
            ExpectedUtcDate = $ClaudeExpectedUtcDate
            ReviewPolicyContext = $objClaudeReviewContext
            InventoryPrefix = 'Inline review comments and threads. Enumerate'
            SyntheticPrefix = 'Assign each review-body-only finding the stable synthetic key'
            PlacementContent = $objClaudeLoopContext.Text
            PlacementProseContent = $objClaudeLoopContext.ProseText
            SafetyContent = $objClaudeLoopContext.Text
            SafetyProseContent = $objClaudeLoopContext.ProseText
            CodeSpans = [string[]]@($objClaudeMarkdownContext.ProseBlocks.Code)
        }
    )

    foreach ($objDocument in $arrDocuments) {
        $arrWorkflowPolicyCommands = @(
            $objDocument.CodeSpans |
                Where-Object {
                    $_.StartsWith(
                        $script:strWorkflowPolicyCommandPrefix,
                        [System.StringComparison]::Ordinal
                    )
                }
        )
        if ($arrWorkflowPolicyCommands.Count -ne 1 -or
            $arrWorkflowPolicyCommands[0] -cne $script:strWorkflowPolicyCommand) {
            Write-Output (
                "$($objDocument.Name) must contain one exact workflow-policy command: " +
                $script:strWorkflowPolicyCommand
            )
        }

        $intDeferringWorkHeadingCount = @(
            $objDocument.LevelTwoHeadings |
                Where-Object Text -CEQ 'Deferring Work'
        ).Count
        if ($intDeferringWorkHeadingCount -ne 1) {
            Write-Output (
                "$($objDocument.Name) must contain one exact level-two " +
                'Deferring Work heading.'
            )
        }
        $arrInventoryOwners = @(
            $objDocument.ReviewPolicyContext.TopLevelListItems |
                Where-Object {
                    $null -ne $_.Text -and $_.Text.StartsWith(
                        $objDocument.InventoryPrefix,
                        [System.StringComparison]::Ordinal
                    )
                }
        )
        $arrSyntheticOwners = @(
            $objDocument.ReviewPolicyContext.ProseBlocks |
                Where-Object {
                    $_.Text.StartsWith(
                        $objDocument.SyntheticPrefix,
                        [System.StringComparison]::Ordinal
                    )
                }
        )
        for ($intMarker = 0; $intMarker -lt $script:arrSharedStructuralLiterals.Count; $intMarker++) {
            $strLiteral = $script:arrSharedStructuralLiterals[$intMarker]
            $arrOwners = @(
                if ($intMarker -lt 3) {
                    $arrInventoryOwners
                }
                else {
                    $arrSyntheticOwners
                }
            )
            $intLiteralCount = if ($arrOwners.Count -eq 1) {
                @(
                    $arrOwners[0].Code |
                        Where-Object { $_ -ceq $strLiteral.Trim([char]96) }
                ).Count
            }
            else {
                0
            }
            if ($intLiteralCount -ne 1) {
                Write-Output "$($objDocument.Name) is missing required capability marker: $strLiteral"
            }
        }
        foreach ($strLiteral in $script:arrSharedProseLiterals) {
            if (-not $objDocument.ProseContent.Contains(
                    $strLiteral,
                    [System.StringComparison]::Ordinal
                )) {
                Write-Output "$($objDocument.Name) is missing required capability marker: $strLiteral"
            }
        }

        $intStandingAuthorizationCount = [regex]::Matches(
            $objDocument.PlacementProseContent,
            [regex]::Escape($script:strStandingPlacementAuthorization)
        ).Count
        if ($intStandingAuthorizationCount -ne 1) {
            Write-Output (
                "$($objDocument.Name) must contain the standing direct-placement " +
                'authorization exactly once.'
            )
        }
        $strNoAdditionalAuthorizationRequest =
            'The agent MUST NOT ask the owner for that additional authorization.'
        if (-not $objDocument.PlacementProseContent.Contains(
                $strNoAdditionalAuthorizationRequest,
                [System.StringComparison]::Ordinal
            )) {
            Write-Output (
                "$($objDocument.Name) must contain the no-additional-authorization rule as prose."
            )
        }

        foreach ($strLiteral in $script:arrPlacementStructuralLiterals) {
            $strStructuralPattern = '(?m)^[\t ]*' +
                '(?:(?:>[\t ]*)|(?:(?:[-+*]|\d+[.)])[\t ]+))*' +
                [regex]::Escape($strLiteral) + '(?:\s|$)'
            if (-not [regex]::IsMatch(
                    $objDocument.PlacementContent,
                    $strStructuralPattern
                )) {
                Write-Output "$($objDocument.Name) is missing required direct-placement safety marker: $strLiteral"
            }
        }

        foreach ($strLiteral in $script:arrPlacementProseLiterals) {
            if (-not $objDocument.PlacementProseContent.Contains(
                    $strLiteral,
                    [System.StringComparison]::Ordinal
                )) {
                Write-Output "$($objDocument.Name) is missing required direct-placement safety marker: $strLiteral"
            }
        }

        foreach ($strLiteral in $script:arrObsoletePlacementLiterals) {
            if ($objDocument.Content.Contains($strLiteral, [System.StringComparison]::Ordinal)) {
                Write-Output (
                    "$($objDocument.Name) contains obsolete session-specific " +
                    "direct-placement authorization: $strLiteral"
                )
            }
        }

        foreach ($strLiteral in $script:arrStyleGuideRoutingLiterals) {
            $intRoutingLiteralCount = [regex]::Matches(
                $objDocument.ProseContent,
                [regex]::Escape($strLiteral)
            ).Count
            if ($intRoutingLiteralCount -ne 1) {
                Write-Output (
                    "$($objDocument.Name) must contain the style-guide routing marker " +
                    "exactly once: $strLiteral"
                )
            }
        }

        $intOnlyGenuineDeferredWorkCount = [regex]::Matches(
            $objDocument.ProseContent,
            [regex]::Escape($script:strOnlyGenuineDeferredWork)
        ).Count
        if ($intOnlyGenuineDeferredWorkCount -ne 1) {
            Write-Output (
                "$($objDocument.Name) must contain the genuine-deferral Issue rule exactly once."
            )
        }

        foreach ($strLiteral in $script:arrObsoleteDeferralLiterals) {
            if ($objDocument.Content.Contains($strLiteral, [System.StringComparison]::Ordinal)) {
                Write-Output "$($objDocument.Name) contains an obsolete blanket Issue rule: $strLiteral"
            }
        }
    }

    $arrAgentsLevelTwoHeadings = @(
        'Codex Execution Model and Interfaces',
        'Automated Review Loop (User-Initiated)'
    )
    foreach ($strHeading in $arrAgentsLevelTwoHeadings) {
        $intHeadingCount = @(
            $objAgentsMarkdownContext.LevelTwoHeadings |
                Where-Object Text -CEQ $strHeading
        ).Count
        if ($intHeadingCount -ne 1) {
            Write-Output "AGENTS.md must contain one exact level-two heading: $strHeading"
        }
    }
    $arrAgentsVisibleCodeSpans = [string[]]@(
        $objAgentsMarkdownContext.ProseBlocks.Code
    )
    foreach ($strLiteral in $script:arrAgentsTechnicalCodeSpans) {
        if (@($arrAgentsVisibleCodeSpans | Where-Object { $_ -ceq $strLiteral }).Count -eq 0) {
            Write-Output "AGENTS.md is missing required Codex marker: $strLiteral"
        }
    }
    foreach ($objContract in $script:arrAgentsNormativeProseContracts) {
        $arrCandidateOwners = if ($objContract.OwnerKind -ceq 'ListItem') {
            $objAgentsPlacementContext.TopLevelListItems
        }
        else {
            $objAgentsPlacementContext.ProseBlocks
        }
        $arrOwners = @(
            $arrCandidateOwners |
                Where-Object {
                    $null -ne $_.Text -and $_.Text.StartsWith(
                        $objContract.OwnerPrefix,
                        [System.StringComparison]::Ordinal
                    )
                }
        )
        if ($arrOwners.Count -ne 1 -or
            -not $arrOwners[0].Text.Contains(
                $objContract.Literal,
                [System.StringComparison]::Ordinal
            )) {
            Write-Output (
                'AGENTS.md must contain required policy as prose: ' +
                $objContract.Literal
            )
        }
    }
    $arrClaudeVisibleCodeSpans = [string[]]@(
        $objClaudeMarkdownContext.ProseBlocks.Code
    )
    foreach ($strLiteral in $script:arrClaudeTechnicalCodeSpans) {
        if (@($arrClaudeVisibleCodeSpans | Where-Object { $_ -ceq $strLiteral }).Count -eq 0) {
            Write-Output "CLAUDE.md is missing required Claude marker: $strLiteral"
        }
    }
    if (-not $objClaudeMarkdownContext.ProseText.Contains(
            $script:strClaudeTechnicalProse,
            [System.StringComparison]::Ordinal
        )) {
        Write-Output (
            'CLAUDE.md is missing required Claude marker: ' +
            $script:strClaudeTechnicalProse
        )
    }
    foreach ($objSafetyLimitContract in $script:arrSafetyLimitContracts) {
        $objSafetyDocument = $arrDocuments |
            Where-Object { $_.Name -ceq $objSafetyLimitContract.DocumentName }
        $strStructuralLimitPattern = '(?m)^' +
            [regex]::Escape($objSafetyLimitContract.StructuralLiteral)
        $strProseLimitPattern = '(?m)^' +
            [regex]::Escape($objSafetyLimitContract.ProseLiteral) + '(?:\s|$)'
        if ([regex]::Matches(
                $objSafetyDocument.SafetyContent,
                $strStructuralLimitPattern
            ).Count -ne 1 -or
            [regex]::Matches(
                $objSafetyDocument.SafetyProseContent,
                $strProseLimitPattern
            ).Count -ne 1) {
            Write-Output $objSafetyLimitContract.Failure
        }
    }

    foreach ($objDocument in $arrDocuments) {
        $arrMetadataFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name $objDocument.Name `
                -CurrentContent $objDocument.RawContent `
                -ParentContent $objDocument.ParentContent `
                -ExpectedUtcDate $objDocument.ExpectedUtcDate `
                -IsNewDocumentTransition (
                    $null -eq $objDocument.ParentContent -and
                    -not [string]::IsNullOrEmpty($objDocument.ExpectedUtcDate)
                ))
        foreach ($strMetadataFailure in $arrMetadataFailures) {
            Write-Output $strMetadataFailure
        }
    }
}

function Get-PushRangeBaseFetchContractFailure {
    # .SYNOPSIS
    # Validates the workflow step that acquires a default-branch push range base.
    #
    # .DESCRIPTION
    # Parses the named workflow step as inert text. Confirms that only an
    # existing, non-deleted default-branch push runs the step, that the
    # authenticated event's exact prior SHA is fetched without force or a local
    # destination, that the resolved commit matches, and that the operation
    # leaves tracked state clean.
    #
    # .PARAMETER WorkflowContent
    # The complete agent-instruction workflow YAML text to inspect.
    #
    # .EXAMPLE
    # Get-PushRangeBaseFetchContractFailure -WorkflowContent $strWorkflow
    #
    # # Returns no output when the acquisition step satisfies the contract.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each contract failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.1.20260908.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $WorkflowContent
    )

    $arrStepMatches = @([regex]::Matches(
        $WorkflowContent,
        '(?ms)^      - name: Fetch existing push range base as data\r?\n' +
            '(?<Body>.*?)(?=^      - name: |\z)'
    ))
    if ($arrStepMatches.Count -ne 1) {
        Write-Output 'The push range-base acquisition step must occur exactly once.'
        return
    }
    $objStepMatch = $arrStepMatches[0]
    $strStepBody = $objStepMatch.Groups['Body'].Value
    if ($strStepBody -notmatch
        '(?ms)^        if: >-\r?\n' +
            "          github\.event_name == 'push' &&\r?\n" +
            '          github\.ref_name == github\.event\.repository\.default_branch &&\r?\n' +
            '          !github\.event\.created &&\r?\n' +
            '          !github\.event\.deleted\r?$') {
        Write-Output 'The push range-base acquisition condition is not exact.'
    }
    if ($strStepBody -notmatch '(?m)^        shell: bash\r?$') {
        Write-Output 'The push range-base acquisition does not use bash.'
    }
    foreach ($objEnvironmentContract in @(
            [pscustomobject]@{
                Pattern = '(?m)^          GITHUB_TOKEN: \$\{\{ github\.token \}\}\r?$'
                Failure = 'The push range-base acquisition does not use the event token.'
            },
            [pscustomobject]@{
                Pattern = '(?m)^          RANGE_BASE_SHA: \$\{\{ github\.event\.before \}\}\r?$'
                Failure = 'The push range-base acquisition does not use the event before SHA.'
            }
        )) {
        if ($strStepBody -notmatch $objEnvironmentContract.Pattern) {
            Write-Output $objEnvironmentContract.Failure
        }
    }
    $objRunMatch = [regex]::Match(
        $strStepBody,
        '(?ms)^        run: \|\r?\n(?<Run>.*)\z'
    )
    if (-not $objRunMatch.Success) {
        Write-Output 'The push range-base acquisition script is missing.'
        return
    }
    $strRun = $objRunMatch.Groups['Run'].Value
    if ([regex]::Matches($strRun, '(?m)^\s+git fetch ').Count -ne 1) {
        Write-Output 'The push range-base acquisition must contain exactly one Git fetch.'
    }
    foreach ($strRequiredLiteral in @(
            '          set -euo pipefail',
            '          [[ "${RANGE_BASE_SHA}" =~ ^[0-9a-f]{40}$ ]]',
            '          test "${RANGE_BASE_SHA}" != "0000000000000000000000000000000000000000"',
            '          authorization="$(printf ''x-access-token:%s'' "${GITHUB_TOKEN}" | base64 -w 0)"',
            '          GIT_CONFIG_COUNT=1 \',
            '            GIT_CONFIG_KEY_0="http.${GITHUB_SERVER_URL}/.extraheader" \',
            '            GIT_CONFIG_VALUE_0="Authorization: Basic ${authorization}" \',
            '          unset authorization',
            '          fetched_base="$(git rev-parse --verify "${RANGE_BASE_SHA}^{commit}")"',
            '          test "${fetched_base}" = "${RANGE_BASE_SHA}"',
            '          git diff --quiet --no-ext-diff',
            '          git diff --cached --quiet --no-ext-diff'
        )) {
        if (-not $strRun.Contains(
                $strRequiredLiteral,
                [System.StringComparison]::Ordinal
            )) {
            Write-Output "The push range-base acquisition is missing: $strRequiredLiteral"
        }
    }
    $objFetchMatch = [regex]::Match(
        $strRun,
        '(?ms)^            git fetch (?<Command>.+?)^          unset authorization$'
    )
    if (-not $objFetchMatch.Success) {
        Write-Output 'Could not parse the push range-base fetch command.'
        return
    }
    $strFetchCommand = $objFetchMatch.Groups['Command'].Value
    if ($strFetchCommand -notmatch
        '(?m)^--no-tags --no-recurse-submodules origin "\$\{RANGE_BASE_SHA\}"\r?\n?$') {
        Write-Output 'The push range-base fetch does not request only the exact event SHA.'
    }
    if ($strFetchCommand -match '(?m)(^|\s)--force(\s|$)' -or
        $strFetchCommand -match '"\+\$\{RANGE_BASE_SHA\}') {
        Write-Output 'The push range-base fetch uses a force update.'
    }
}

function Assert-MutationRejected {
    # .SYNOPSIS
    # Confirms that an agent-instruction mutation fails closed.
    #
    # .DESCRIPTION
    # Evaluates one complete in-memory fixture and verifies that its failures
    # contain the required text. Expected validation failures do not escape.
    #
    # .PARAMETER Name
    # The mutation name used in self-test failures.
    #
    # .PARAMETER AgentsContent
    # The mutated or control AGENTS.md text.
    #
    # .PARAMETER ClaudeContent
    # The mutated or control CLAUDE.md text.
    #
    # .PARAMETER CodexConfigContent
    # The mutated or control project TOML text.
    #
    # .PARAMETER ExpectedFailure
    # The failure text that the validator must produce.
    #
    # .PARAMETER ParentAgentsContent
    # The parent AGENTS.md text, or null for no metadata comparison.
    #
    # .PARAMETER ParentClaudeContent
    # The parent CLAUDE.md text, or null for no metadata comparison.
    #
    # .PARAMETER AgentsExpectedUtcDate
    # The required AGENTS.md UTC metadata date after a content change.
    #
    # .PARAMETER ClaudeExpectedUtcDate
    # The required CLAUDE.md UTC metadata date after a content change.
    #
    # .EXAMPLE
    # Assert-MutationRejected -Name 'disabled plugin' `
    #     -AgentsContent $strAgents -ClaudeContent $strClaude `
    #     -CodexConfigContent $strMutation -ExpectedFailure 'enabled = true'
    #
    # # Returns no output when the mutation is rejected for the expected reason.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # None.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260820.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $AgentsContent,

        [Parameter(Mandatory)]
        [string] $ClaudeContent,

        [Parameter(Mandatory)]
        [string] $CodexConfigContent,

        [Parameter(Mandatory)]
        [string] $ExpectedFailure,

        [Parameter()]
        [AllowNull()]
        [string] $ParentAgentsContent,

        [Parameter()]
        [AllowNull()]
        [string] $ParentClaudeContent,

        [Parameter()]
        [AllowEmptyString()]
        [string] $AgentsExpectedUtcDate = '',

        [Parameter()]
        [AllowEmptyString()]
        [string] $ClaudeExpectedUtcDate = ''
    )

    Write-Verbose "Testing rejected mutation: $Name"
    $arrFailures = @(Get-AgentInstructionFailure `
            -AgentsContent $AgentsContent `
            -ClaudeContent $ClaudeContent `
            -CodexConfigContent $CodexConfigContent `
            -ParentAgentsContent $ParentAgentsContent `
            -ParentClaudeContent $ParentClaudeContent `
            -AgentsExpectedUtcDate $AgentsExpectedUtcDate `
            -ClaudeExpectedUtcDate $ClaudeExpectedUtcDate)
    if ($arrFailures.Count -eq 0) {
        throw "Mutation '$Name' did not fail closed."
    }
    if (-not ($arrFailures -match [regex]::Escape($ExpectedFailure))) {
        throw "Mutation '$Name' failed for the wrong reason. Failures: $($arrFailures -join '; ')"
    }
}

function Assert-FixtureAccepted {
    # .SYNOPSIS
    # Confirms that an agent-instruction fixture is accepted.
    #
    # .DESCRIPTION
    # Evaluates one complete in-memory fixture and throws if any contract failure
    # is returned.
    #
    # .PARAMETER Name
    # The fixture name used in self-test failures.
    #
    # .PARAMETER AgentsContent
    # The control AGENTS.md text.
    #
    # .PARAMETER ClaudeContent
    # The control CLAUDE.md text.
    #
    # .PARAMETER CodexConfigContent
    # The control project TOML text.
    #
    # .PARAMETER ParentAgentsContent
    # The parent AGENTS.md text, or null for no metadata comparison.
    #
    # .PARAMETER ParentClaudeContent
    # The parent CLAUDE.md text, or null for no metadata comparison.
    #
    # .PARAMETER AgentsExpectedUtcDate
    # The required AGENTS.md UTC metadata date after a content change.
    #
    # .PARAMETER ClaudeExpectedUtcDate
    # The required CLAUDE.md UTC metadata date after a content change.
    #
    # .EXAMPLE
    # Assert-FixtureAccepted -Name 'baseline' -AgentsContent $strAgents `
    #     -ClaudeContent $strClaude -CodexConfigContent $strConfig
    #
    # # Returns no output when the fixture passes the contract.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # None.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260820.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $AgentsContent,

        [Parameter(Mandatory)]
        [string] $ClaudeContent,

        [Parameter(Mandatory)]
        [string] $CodexConfigContent,

        [Parameter()]
        [AllowNull()]
        [string] $ParentAgentsContent,

        [Parameter()]
        [AllowNull()]
        [string] $ParentClaudeContent,

        [Parameter()]
        [AllowEmptyString()]
        [string] $AgentsExpectedUtcDate = '',

        [Parameter()]
        [AllowEmptyString()]
        [string] $ClaudeExpectedUtcDate = ''
    )

    Write-Verbose "Testing accepted fixture: $Name"
    $arrFailures = @(Get-AgentInstructionFailure `
            -AgentsContent $AgentsContent `
            -ClaudeContent $ClaudeContent `
            -CodexConfigContent $CodexConfigContent `
            -ParentAgentsContent $ParentAgentsContent `
            -ParentClaudeContent $ParentClaudeContent `
            -AgentsExpectedUtcDate $AgentsExpectedUtcDate `
            -ClaudeExpectedUtcDate $ClaudeExpectedUtcDate)
    if ($arrFailures.Count -gt 0) {
        throw "Accepted fixture '$Name' failed validation: $($arrFailures -join '; ')"
    }
}

#endregion Private helper functions

#region Repository validation

$strWorkflowsDirectoryPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PSScriptRoot)
$strGitHubDirectoryPath = [System.IO.Path]::GetDirectoryName($strWorkflowsDirectoryPath)
$strRepositoryRootPath = [System.IO.Path]::GetDirectoryName($strGitHubDirectoryPath)
$strAgentsPath = Join-Path -Path $strRepositoryRootPath -ChildPath 'AGENTS.md'
$strClaudePath = Join-Path -Path $strRepositoryRootPath -ChildPath 'CLAUDE.md'
$strCodexConfigPath = Join-Path -Path $strRepositoryRootPath -ChildPath '.codex/config.toml'
$strDocsInstructionsPath = Join-Path `
    -Path $strRepositoryRootPath `
    -ChildPath '.github/instructions/docs.instructions.md'
$arrAgentSetupInputSpecs = @(
    [pscustomobject]@{ Path = 'package.json'; MaximumBytes = 16384 }
    [pscustomobject]@{ Path = '.github/workflows/package.json'; MaximumBytes = 16384 }
    [pscustomobject]@{
        Path = '.github/workflows/copilot-setup-steps.yml'
        MaximumBytes = 32768
    }
    [pscustomobject]@{ Path = '.husky/pre-commit'; MaximumBytes = 16384 }
    [pscustomobject]@{
        Path = '.github/workflows/scripts-README.md'
        MaximumBytes = 32768
    }
    [pscustomobject]@{ Path = 'requirements-dev.txt'; MaximumBytes = 4096 }
)
$arrGovernedInstructionDocuments = @(
    [pscustomobject]@{
        Path = 'AGENTS.md'
        MaximumBytes = $intAgentsMaximumInputBytes
        RequiresMetadata = $true
    },
    [pscustomobject]@{
        Path = 'CLAUDE.md'
        MaximumBytes = $intClaudeMaximumInputBytes
        RequiresMetadata = $true
    },
    [pscustomobject]@{
        Path = '.github/copilot-instructions.md'
        MaximumBytes = $intInstructionDocumentMaximumInputBytes
        RequiresMetadata = $false
    },
    [pscustomobject]@{
        Path = '.github/instructions/docs.instructions.md'
        MaximumBytes = $intDocsInstructionsMaximumInputBytes
        RequiresMetadata = $true
    },
    [pscustomobject]@{
        Path = '.github/instructions/yaml.instructions.md'
        MaximumBytes = $intInstructionDocumentMaximumInputBytes
        RequiresMetadata = $true
    }
)
$strValidatedInputRevision = ''

if (-not [string]::IsNullOrEmpty($InputRevision)) {
    if ($InputRevision -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
        throw "The agent-instruction input revision is invalid: $InputRevision"
    }
    $strValidatedInputRevision = [string] (
        & git -C $strRepositoryRootPath rev-parse --verify `
            "$InputRevision`^{commit}"
    )
    if ($LASTEXITCODE -ne 0 -or
        -not [string]::Equals(
            $strValidatedInputRevision.Trim(),
            $InputRevision,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw "The agent-instruction input commit is unavailable: $InputRevision"
    }
    $strValidatedInputRevision = $strValidatedInputRevision.Trim()
    if (-not [string]::IsNullOrEmpty($RangeHeadRevision) -and
        -not [string]::Equals(
            $strValidatedInputRevision,
            $RangeHeadRevision,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'The input revision must match the metadata event-range head.'
    }
}

$strCheckedOutRevision = [string] (
    & git -C $strRepositoryRootPath rev-parse --verify 'HEAD^{commit}'
)
if ($LASTEXITCODE -ne 0 -or $strCheckedOutRevision.Trim() -notmatch '^[0-9a-fA-F]{40}$') {
    throw 'The checked-out trusted revision is unavailable.'
}
$strCheckedOutRevision = $strCheckedOutRevision.Trim()
if (-not [string]::IsNullOrEmpty($strValidatedInputRevision) -and
    -not [string]::Equals(
        $strValidatedInputRevision,
        $strCheckedOutRevision,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    $arrTrustRootFailures = @(Get-TrustRootRangeMutationFailure `
            -RepositoryRootPath $strRepositoryRootPath `
            -BaseRevision $RangeBaseRevision `
            -HeadRevision $RangeHeadRevision `
            -RepositoryRelativePath $script:arrTrustRootPaths)
    if ($arrTrustRootFailures.Count -gt 0) {
        throw (
            'Trusted validation root changed:' + [Environment]::NewLine + '- ' +
            ($arrTrustRootFailures -join ([Environment]::NewLine + '- '))
        )
    }
}

$strLocalPublishedBaselineRevision = ''
if ([string]::IsNullOrEmpty($strValidatedInputRevision) -and
    [string]::IsNullOrEmpty($RangeBaseRevision) -and
    [string]::IsNullOrEmpty($RangeHeadRevision)) {
    $strLocalPublishedBaselineRevision = Get-LocalPublishedBaselineRevision `
        -RepositoryRootPath $strRepositoryRootPath
}

if ([string]::IsNullOrEmpty($strValidatedInputRevision)) {
    $arrTrackedRepositoryPaths = @(
        & git -C $strRepositoryRootPath ls-files --cached
    )
}
else {
    $arrTrackedRepositoryPaths = @(
        & git -C $strRepositoryRootPath ls-tree -r --name-only `
            $strValidatedInputRevision
    )
}
if ($LASTEXITCODE -ne 0) {
    throw 'Could not enumerate tracked files for the governed instruction inventory.'
}
$arrGovernedRootPaths = @(
    'AGENTS.md',
    'CLAUDE.md',
    'GEMINI.md',
    '.hermes.md',
    '.github/copilot-instructions.md'
)
$arrTrackedGovernedInstructionPaths = @(
    $arrTrackedRepositoryPaths |
        Where-Object {
            $strTrackedPath = [string] $_
            $arrGovernedRootPaths -ccontains $strTrackedPath -or
            $strTrackedPath -cmatch `
                '^\.github/instructions/[^/]+\.instructions\.md$' -or
            $strTrackedPath -cmatch '^\.cursor/rules/[^/]+\.mdc$'
        }
)
$arrGovernedInstructionInventoryFailures = @(
    Get-GovernedInstructionInventoryFailure `
        -CatalogPaths @($arrGovernedInstructionDocuments.Path) `
        -TrackedPaths $arrTrackedGovernedInstructionPaths
)
if ($arrGovernedInstructionInventoryFailures.Count -gt 0) {
    throw (
        'Governed instruction inventory failed:' + [Environment]::NewLine + '- ' +
        ($arrGovernedInstructionInventoryFailures -join ([Environment]::NewLine + '- '))
    )
}

if ([string]::IsNullOrEmpty($strValidatedInputRevision)) {
    $arrRequiredPaths = @($strCodexConfigPath)
    $arrRequiredPaths += @(
        $arrGovernedInstructionDocuments |
            ForEach-Object {
                Join-Path -Path $strRepositoryRootPath -ChildPath $_.Path
            }
    )
    $arrRequiredPaths += @(
        $arrAgentSetupInputSpecs |
            ForEach-Object {
                Join-Path -Path $strRepositoryRootPath -ChildPath $_.Path
            }
    )
    foreach ($strRequiredPath in $arrRequiredPaths) {
        if (-not (Test-Path -LiteralPath $strRequiredPath -PathType Leaf)) {
            throw "Required agent-instruction input is missing: $strRequiredPath"
        }
    }
}

$strAgentsContent = if ([string]::IsNullOrEmpty($strValidatedInputRevision)) {
    ConvertFrom-StrictUtf8Data `
        -Bytes (Read-RepositoryInputData `
            -Path $strAgentsPath `
            -RepositoryRootPath $strRepositoryRootPath `
            -RepositoryRelativePath 'AGENTS.md' `
            -DisplayName 'AGENTS.md' `
            -MaximumBytes $intAgentsMaximumInputBytes) `
        -DisplayName 'AGENTS.md'
}
else {
    Read-GitRevisionText `
        -RepositoryRootPath $strRepositoryRootPath `
        -Revision $strValidatedInputRevision `
        -RepositoryRelativePath 'AGENTS.md' `
        -MaximumBytes $intAgentsMaximumInputBytes `
        -RequireRegularFile
}
$strClaudeContent = if ([string]::IsNullOrEmpty($strValidatedInputRevision)) {
    ConvertFrom-StrictUtf8Data `
        -Bytes (Read-RepositoryInputData `
            -Path $strClaudePath `
            -RepositoryRootPath $strRepositoryRootPath `
            -RepositoryRelativePath 'CLAUDE.md' `
            -DisplayName 'CLAUDE.md' `
            -MaximumBytes $intClaudeMaximumInputBytes) `
        -DisplayName 'CLAUDE.md'
}
else {
    Read-GitRevisionText `
        -RepositoryRootPath $strRepositoryRootPath `
        -Revision $strValidatedInputRevision `
        -RepositoryRelativePath 'CLAUDE.md' `
        -MaximumBytes $intClaudeMaximumInputBytes `
        -RequireRegularFile
}
$strCodexConfigContent = if ([string]::IsNullOrEmpty($strValidatedInputRevision)) {
    ConvertFrom-StrictUtf8Data `
        -Bytes (Read-RepositoryInputData `
            -Path $strCodexConfigPath `
            -RepositoryRootPath $strRepositoryRootPath `
            -RepositoryRelativePath '.codex/config.toml' `
            -DisplayName '.codex/config.toml' `
            -MaximumBytes $intCodexConfigMaximumInputBytes) `
        -DisplayName '.codex/config.toml'
}
else {
    Read-GitRevisionText `
        -RepositoryRootPath $strRepositoryRootPath `
        -Revision $strValidatedInputRevision `
        -RepositoryRelativePath '.codex/config.toml' `
        -MaximumBytes $intCodexConfigMaximumInputBytes `
        -RequireRegularFile
}
$strDocsInstructionsContent = if ([string]::IsNullOrEmpty($strValidatedInputRevision)) {
    ConvertFrom-StrictUtf8Data `
        -Bytes (Read-RepositoryInputData `
            -Path $strDocsInstructionsPath `
            -RepositoryRootPath $strRepositoryRootPath `
            -RepositoryRelativePath '.github/instructions/docs.instructions.md' `
            -DisplayName '.github/instructions/docs.instructions.md' `
            -MaximumBytes $intDocsInstructionsMaximumInputBytes) `
        -DisplayName '.github/instructions/docs.instructions.md'
}
else {
    Read-GitRevisionText `
        -RepositoryRootPath $strRepositoryRootPath `
        -Revision $strValidatedInputRevision `
        -RepositoryRelativePath '.github/instructions/docs.instructions.md' `
        -MaximumBytes $intDocsInstructionsMaximumInputBytes `
        -RequireRegularFile
}
$hashtableAgentSetupInputContent = @{}
foreach ($objAgentSetupInputSpec in $arrAgentSetupInputSpecs) {
    $strAgentSetupInputPath = Join-Path `
        -Path $strRepositoryRootPath `
        -ChildPath $objAgentSetupInputSpec.Path
    $strAgentSetupInputContent = if ([string]::IsNullOrEmpty($strValidatedInputRevision)) {
        ConvertFrom-StrictUtf8Data `
            -Bytes (Read-RepositoryInputData `
                -Path $strAgentSetupInputPath `
                -RepositoryRootPath $strRepositoryRootPath `
                -RepositoryRelativePath $objAgentSetupInputSpec.Path `
                -DisplayName $objAgentSetupInputSpec.Path `
                -MaximumBytes $objAgentSetupInputSpec.MaximumBytes) `
            -DisplayName $objAgentSetupInputSpec.Path
    }
    else {
        Read-GitRevisionText `
            -RepositoryRootPath $strRepositoryRootPath `
            -Revision $strValidatedInputRevision `
            -RepositoryRelativePath $objAgentSetupInputSpec.Path `
            -MaximumBytes $objAgentSetupInputSpec.MaximumBytes `
            -RequireRegularFile
    }
    $hashtableAgentSetupInputContent[$objAgentSetupInputSpec.Path] =
        $strAgentSetupInputContent
}
$hashtableGovernedInstructionContent = @{
    'AGENTS.md' = $strAgentsContent
    'CLAUDE.md' = $strClaudeContent
    '.github/instructions/docs.instructions.md' = $strDocsInstructionsContent
}
foreach ($objDocumentSpec in $arrGovernedInstructionDocuments) {
    if ($hashtableGovernedInstructionContent.ContainsKey($objDocumentSpec.Path)) {
        continue
    }
    $strDocumentPath = Join-Path `
        -Path $strRepositoryRootPath `
        -ChildPath $objDocumentSpec.Path
    $strDocumentContent = if ([string]::IsNullOrEmpty($strValidatedInputRevision)) {
        ConvertFrom-StrictUtf8Data `
            -Bytes (Read-RepositoryInputData `
                -Path $strDocumentPath `
                -RepositoryRootPath $strRepositoryRootPath `
                -RepositoryRelativePath $objDocumentSpec.Path `
                -DisplayName $objDocumentSpec.Path `
                -MaximumBytes $objDocumentSpec.MaximumBytes) `
            -DisplayName $objDocumentSpec.Path
    }
    else {
        Read-GitRevisionText `
            -RepositoryRootPath $strRepositoryRootPath `
            -Revision $strValidatedInputRevision `
            -RepositoryRelativePath $objDocumentSpec.Path `
            -MaximumBytes $objDocumentSpec.MaximumBytes `
            -RequireRegularFile
    }
    $hashtableGovernedInstructionContent[$objDocumentSpec.Path] = $strDocumentContent
}

$listGovernedDocumentContexts = [System.Collections.Generic.List[pscustomobject]]::new()
foreach ($objDocumentSpec in $arrGovernedInstructionDocuments) {
    $objParentContext = Get-GovernedDocumentParentContext `
        -RepositoryRootPath $strRepositoryRootPath `
        -RepositoryRelativePath $objDocumentSpec.Path `
        -MaximumBytes $objDocumentSpec.MaximumBytes `
        -Revision $strValidatedInputRevision `
        -PublishedBaselineRevision $strLocalPublishedBaselineRevision
    $listGovernedDocumentContexts.Add([pscustomobject]@{
            Path = $objDocumentSpec.Path
            MaximumBytes = $objDocumentSpec.MaximumBytes
            RequiresMetadata = $objDocumentSpec.RequiresMetadata
            Content = $hashtableGovernedInstructionContent[$objDocumentSpec.Path]
            ParentContent = $objParentContext.ParentContent
            ExpectedUtcDate = $objParentContext.ExpectedUtcDate
            IsWorktreeTransition = $objParentContext.IsWorktreeTransition
        })
}

$strNoRangeCommitRevision = ''
$boolNoRangeCommitHasParent = $false
if ([string]::IsNullOrEmpty($RangeBaseRevision) -and
    [string]::IsNullOrEmpty($RangeHeadRevision)) {
    $strNoRangeCommitRevision = if ([string]::IsNullOrEmpty($strValidatedInputRevision)) {
        $strCheckedOutRevision
    }
    else {
        $strValidatedInputRevision
    }
    $strNoRangeParentLine = [string] (
        & git -C $strRepositoryRootPath rev-list --parents -n 1 `
            $strNoRangeCommitRevision
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Could not read the no-range validation commit: $strNoRangeCommitRevision"
    }
    $arrNoRangeCommitAndParents = @($strNoRangeParentLine.Trim() -split '\s+')
    $boolNoRangeCommitHasParent = $arrNoRangeCommitAndParents.Count -gt 1
}
$boolUseLocalPublishedRange = -not [string]::IsNullOrEmpty(
    $strLocalPublishedBaselineRevision
)
$strEffectiveRangeBaseRevision = if ($boolUseLocalPublishedRange) {
    $strLocalPublishedBaselineRevision
}
else {
    $RangeBaseRevision
}
$strEffectiveRangeHeadRevision = if ($boolUseLocalPublishedRange) {
    $strCheckedOutRevision
}
else {
    $RangeHeadRevision
}
$boolEffectiveRangeIsNewRef = if ($boolUseLocalPublishedRange) {
    $false
}
else {
    [bool]$RangeIsNewRef
}

$arrRepositoryFailures = @(Get-AgentInstructionFailure `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent)
$arrRepositoryFailures += @(Get-HuskySetupContractFailure `
        -RootPackageContent $hashtableAgentSetupInputContent['package.json'] `
        -WorkflowPackageContent `
            $hashtableAgentSetupInputContent['.github/workflows/package.json'] `
        -HookContent $hashtableAgentSetupInputContent['.husky/pre-commit'] `
        -CopilotSetupContent `
            $hashtableAgentSetupInputContent['.github/workflows/copilot-setup-steps.yml'])
$arrRepositoryFailures += @(Get-PreCommitBootstrapContractFailure `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -ScriptIndexContent `
            $hashtableAgentSetupInputContent['.github/workflows/scripts-README.md'] `
        -RequirementsContent $hashtableAgentSetupInputContent['requirements-dev.txt'])
foreach ($objDocumentContext in $listGovernedDocumentContexts) {
    if ([string]::IsNullOrEmpty($RangeBaseRevision) -and
        [string]::IsNullOrEmpty($RangeHeadRevision)) {
        if ($boolUseLocalPublishedRange) {
            if ($objDocumentContext.RequiresMetadata -and
                $objDocumentContext.IsWorktreeTransition) {
                $arrRepositoryFailures += @(Get-DocumentMetadataTransitionFailure `
                        -Name $objDocumentContext.Path `
                        -CurrentContent $objDocumentContext.Content `
                        -ParentContent $objDocumentContext.ParentContent `
                        -ExpectedUtcDate $objDocumentContext.ExpectedUtcDate `
                        -IsNewDocumentTransition (
                            $null -eq $objDocumentContext.ParentContent
                        ))
            }
        }
        elseif ($objDocumentContext.RequiresMetadata -and
            ($objDocumentContext.IsWorktreeTransition -or
                -not $boolNoRangeCommitHasParent)) {
            $arrRepositoryFailures += @(Get-DocumentMetadataTransitionFailure `
                    -Name $objDocumentContext.Path `
                    -CurrentContent $objDocumentContext.Content `
                    -ParentContent $objDocumentContext.ParentContent `
                    -ExpectedUtcDate $objDocumentContext.ExpectedUtcDate `
                    -IsNewDocumentTransition (
                        $null -eq $objDocumentContext.ParentContent -and
                        -not [string]::IsNullOrEmpty($objDocumentContext.ExpectedUtcDate)
                    ))
        }
        else {
            $arrRepositoryFailures += @(Get-GovernedDocumentCommitTransitionFailure `
                    -Name $objDocumentContext.Path `
                    -RepositoryRootPath $strRepositoryRootPath `
                    -RepositoryRelativePath $objDocumentContext.Path `
                    -MaximumBytes $objDocumentContext.MaximumBytes `
                    -CommitRevision $strNoRangeCommitRevision `
                    -RequireMetadataTransition $objDocumentContext.RequiresMetadata)
        }
    }
    $boolWorktreeReplacesLocalRange =
        $boolUseLocalPublishedRange -and $objDocumentContext.IsWorktreeTransition
    if (-not $boolWorktreeReplacesLocalRange) {
        $arrRepositoryFailures += @(Get-GovernedDocumentRangeTransitionFailure `
                -Name $objDocumentContext.Path `
                -RepositoryRootPath $strRepositoryRootPath `
                -RepositoryRelativePath $objDocumentContext.Path `
                -MaximumBytes $objDocumentContext.MaximumBytes `
                -BaseRevision $strEffectiveRangeBaseRevision `
                -HeadRevision $strEffectiveRangeHeadRevision `
                -InputRevision $strValidatedInputRevision `
                -IsNewRefRange $boolEffectiveRangeIsNewRef `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes $intValidatorMaximumInputBytes `
                -PolicyMarker $strMetadataRangePolicyMarker `
                -RequireMetadataTransition $objDocumentContext.RequiresMetadata)
    }
}
if ($arrRepositoryFailures.Count -gt 0) {
    throw "Agent-instruction contract failed:`n- $($arrRepositoryFailures -join "`n- ")"
}

Write-Output 'Agent-instruction contract passed.'

#endregion Repository validation

if ($SelfTest) {
    #region Mutation self-tests

    $objValidatorBoundaryStream = [System.IO.MemoryStream]::new(
        [byte[]]::new($intValidatorMaximumInputBytes),
        $false
    )
    try {
        [byte[]] $arrValidatorBoundaryBytes = Read-BoundedStreamData `
            -Stream $objValidatorBoundaryStream `
            -MaximumBytes $intValidatorMaximumInputBytes `
            -DisplayName 'validator boundary control'
        if ($arrValidatorBoundaryBytes.Count -ne $intValidatorMaximumInputBytes) {
            throw 'The validator byte boundary rejected its exact maximum.'
        }
    }
    finally {
        $objValidatorBoundaryStream.Dispose()
    }
    $objValidatorOversizeStream = [System.IO.MemoryStream]::new(
        [byte[]]::new($intValidatorMaximumInputBytes + 1),
        $false
    )
    try {
        [void](Read-BoundedStreamData `
                -Stream $objValidatorOversizeStream `
                -MaximumBytes $intValidatorMaximumInputBytes `
                -DisplayName 'validator oversized mutation')
        throw 'The validator byte boundary accepted one excess byte.'
    }
    catch [System.IO.InvalidDataException] {
        $strExpectedValidatorOversizeFailure =
            "validator oversized mutation must not exceed " +
            "$intValidatorMaximumInputBytes bytes."
        if ($_.Exception.Message -cne $strExpectedValidatorOversizeFailure) {
            throw (
                'The validator oversized mutation returned an unexpected failure: ' +
                $_.Exception.Message
            )
        }
    }
    finally {
        $objValidatorOversizeStream.Dispose()
    }

    $strRootPackageContent = $hashtableAgentSetupInputContent['package.json']
    $strWorkflowPackageContent =
        $hashtableAgentSetupInputContent['.github/workflows/package.json']
    $strCopilotSetupContent =
        $hashtableAgentSetupInputContent['.github/workflows/copilot-setup-steps.yml']
    $strHuskyHookContent = $hashtableAgentSetupInputContent['.husky/pre-commit']
    $strScriptIndexContent =
        $hashtableAgentSetupInputContent['.github/workflows/scripts-README.md']
    $strRequirementsContent =
        $hashtableAgentSetupInputContent['requirements-dev.txt']

    $arrPreCommitBootstrapControlFailures = @(
        Get-PreCommitBootstrapContractFailure `
            -AgentsContent $strAgentsContent `
            -ClaudeContent $strClaudeContent `
            -ScriptIndexContent $strScriptIndexContent `
            -RequirementsContent $strRequirementsContent
    )
    if ($arrPreCommitBootstrapControlFailures.Count -ne 0) {
        throw (
            'The pre-commit bootstrap control fixture failed: ' +
            ($arrPreCommitBootstrapControlFailures -join '; ')
        )
    }
    $arrPreCommitBootstrapMutations = @(
        [pscustomobject]@{
            Name = 'runner pin changed'
            Agents = $strAgentsContent
            Claude = $strClaudeContent
            ScriptIndex = $strScriptIndexContent
            Requirements = $strRequirementsContent.Replace('4.6.2', '4.6.1')
            Failure = 'exact pre-commit 4.6.2 pin'
        },
        [pscustomobject]@{
            Name = 'AGENTS Windows install command changed'
            Agents = $strAgentsContent.Replace(
                'py -3.12 -m pip install --requirement requirements-dev.txt',
                'pip install pre-commit'
            )
            Claude = $strClaudeContent
            ScriptIndex = $strScriptIndexContent
            Requirements = $strRequirementsContent
            Failure = 'AGENTS.md must contain this setup command exactly once'
        },
        [pscustomobject]@{
            Name = 'CLAUDE POSIX install command changed'
            Agents = $strAgentsContent
            Claude = $strClaudeContent.Replace(
                'python3.12 -m pip install --requirement requirements-dev.txt',
                'pip install pre-commit'
            )
            ScriptIndex = $strScriptIndexContent
            Requirements = $strRequirementsContent
            Failure = 'CLAUDE.md must contain this setup command exactly once'
        },
        [pscustomobject]@{
            Name = 'script index Windows run command changed'
            Agents = $strAgentsContent
            Claude = $strClaudeContent
            ScriptIndex = $strScriptIndexContent.Replace(
                'py -3.12 -m pre_commit run --all-files',
                'pre-commit run --all-files'
            )
            Requirements = $strRequirementsContent
            Failure = '.github/workflows/scripts-README.md must contain this setup command exactly once'
        },
        [pscustomobject]@{
            Name = 'script index POSIX run command changed'
            Agents = $strAgentsContent
            Claude = $strClaudeContent
            ScriptIndex = $strScriptIndexContent.Replace(
                'python3.12 -m pre_commit run --all-files',
                'pre-commit run --all-files'
            )
            Requirements = $strRequirementsContent
            Failure = '.github/workflows/scripts-README.md must contain this setup command exactly once'
        }
    )
    foreach ($objPreCommitBootstrapMutation in $arrPreCommitBootstrapMutations) {
        $arrPreCommitBootstrapMutationFailures = @(
            Get-PreCommitBootstrapContractFailure `
                -AgentsContent $objPreCommitBootstrapMutation.Agents `
                -ClaudeContent $objPreCommitBootstrapMutation.Claude `
                -ScriptIndexContent $objPreCommitBootstrapMutation.ScriptIndex `
                -RequirementsContent $objPreCommitBootstrapMutation.Requirements
        )
        if (-not ($arrPreCommitBootstrapMutationFailures -match [regex]::Escape(
                    $objPreCommitBootstrapMutation.Failure
                ))) {
            throw (
                "Pre-commit bootstrap mutation '$($objPreCommitBootstrapMutation.Name)' " +
                'did not fail closed.'
            )
        }
    }

    $arrHuskyMutations = @(
        ,@(
            'bootstrap omits prepare'
            $strRootPackageContent.Replace(
                ' && npm --prefix .github/workflows run prepare',
                ''
            )
            $strWorkflowPackageContent
            $strHuskyHookContent
            'two script-disabled locked installs'
        )
        ,@(
            'prepare hides failure'
            $strRootPackageContent
            $strWorkflowPackageContent.Replace('cd ../.. && husky', 'cd ../.. && husky || true')
            $strHuskyHookContent
            'expose failure'
        )
        ,@(
            'hook omits mdc'
            $strRootPackageContent
            $strWorkflowPackageContent
            $strHuskyHookContent.Replace(" '*.mdc'", '')
            'ACMR .md and .mdc'
        )
        ,@(
            'hook omits rename'
            $strRootPackageContent
            $strWorkflowPackageContent
            $strHuskyHookContent.Replace(
                '--diff-filter=ACMR',
                '--diff-filter=ACM'
            )
            'ACMR .md and .mdc'
        )
        ,@(
            'hook omits staged-index lint'
            $strRootPackageContent
            $strWorkflowPackageContent
            $strHuskyHookContent.Replace(
                'if node .github/workflows/lint-staged-markdown.mjs; then',
                'if true; then'
            )
            'lint-staged-markdown.mjs'
        )
        ,@(
            'hook omits retained nested worktree lint'
            $strRootPackageContent
            $strWorkflowPackageContent
            $strHuskyHookContent.Replace(
                'if npm --prefix .github/workflows run lint:md:nested; then',
                'if true; then'
            )
            'lint:md:nested'
        )
        ,@(
            'hook exits before validation'
            $strRootPackageContent
            $strWorkflowPackageContent
            $strHuskyHookContent.Replace(
                "#!/bin/sh`n",
                "#!/bin/sh`nexit 0`n"
            )
            'reviewed SHA-256 digest'
        )
        ,@(
            'hook appends bypass control flow'
            $strRootPackageContent
            $strWorkflowPackageContent
            ($strHuskyHookContent + "`nexit 0`n")
            'reviewed SHA-256 digest'
        )
        ,@(
            'hook changes semantic whitespace'
            $strRootPackageContent
            $strWorkflowPackageContent
            $strHuskyHookContent.Replace(
                'echo "Running staged Markdown lint against the Git index..."',
                'echo  "Running staged Markdown lint against the Git index..."'
            )
            'reviewed SHA-256 digest'
        )
        ,@(
            'hook changes line endings'
            $strRootPackageContent
            $strWorkflowPackageContent
            ([regex]::Replace($strHuskyHookContent, '(?<!\r)\n', "`r`n"))
            'reviewed SHA-256 digest'
        )
    )
    foreach ($arrHuskyMutation in $arrHuskyMutations) {
        $arrHuskyMutationFailures = @(Get-HuskySetupContractFailure `
                -RootPackageContent $arrHuskyMutation[1] `
                -WorkflowPackageContent $arrHuskyMutation[2] `
                -HookContent $arrHuskyMutation[3] `
                -CopilotSetupContent $strCopilotSetupContent)
        if (-not ($arrHuskyMutationFailures -match [regex]::Escape(
                    $arrHuskyMutation[4]
                ))) {
            throw "Husky mutation '$($arrHuskyMutation[0])' did not fail closed."
        }
    }

    $arrCopilotSetupMutations = @(
        [pscustomobject]@{
            Name = 'locked install enables scripts'
            Content = $strCopilotSetupContent.Replace(
                'npm ci --ignore-scripts',
                'npm ci'
            )
            Failure = 'both locked installs script-disabled'
        },
        [pscustomobject]@{
            Name = 'hook activation omits prepare'
            Content = $strCopilotSetupContent.Replace(
                '          npm --prefix .github/workflows run prepare' +
                    "`n",
                ''
            )
            Failure = 'must run nested prepare'
        },
        [pscustomobject]@{
            Name = 'hook activation accepts another hooksPath'
            Content = $strCopilotSetupContent.Replace(
                "= '.husky/_'",
                "= '.husky'"
            )
            Failure = 'require exact .husky/_ hooksPath'
        },
        [pscustomobject]@{
            Name = 'hook activation omits executable dispatcher assertion'
            Content = $strCopilotSetupContent.Replace(
                '          test -x .husky/_/pre-commit' + "`n",
                ''
            )
            Failure = 'require its executable dispatcher'
        },
        [pscustomobject]@{
            Name = 'hook activation precedes dependency verification'
            Content = $strCopilotSetupContent.Replace(
                'Verify locked dependency trees and immutable manifests',
                'Verify dependencies after hook activation'
            )
            Failure = 'once directly after dependency verification'
        }
    )
    foreach ($objCopilotSetupMutation in $arrCopilotSetupMutations) {
        $arrCopilotSetupFailures = @(Get-HuskySetupContractFailure `
                -RootPackageContent $strRootPackageContent `
                -WorkflowPackageContent $strWorkflowPackageContent `
                -HookContent $strHuskyHookContent `
                -CopilotSetupContent $objCopilotSetupMutation.Content)
        if (-not ($arrCopilotSetupFailures -match [regex]::Escape(
                    $objCopilotSetupMutation.Failure
                ))) {
            throw (
                "Copilot setup mutation '$($objCopilotSetupMutation.Name)' " +
                'did not fail closed.'
            )
        }
    }

    $arrPythonFixtures = @(
        [pscustomobject]@{
            Name = 'valid first alias'; Windows = $false
            Commands = @{ 'python3.12' = @('Application', '/opt/python3.12') }
            Valid = @('/opt/python3.12'); Expected = '/opt/python3.12'
        }
        [pscustomobject]@{
            Name = 'older alias before valid alias'; Windows = $false
            Commands = @{
                python3 = @('Application', '/usr/bin/python3')
                python = @('Application', '/opt/python')
            }
            Valid = @('/opt/python'); Expected = '/opt/python'
        }
        [pscustomobject]@{
            Name = 'no candidates'; Windows = $false
            Commands = @{}; Valid = @(); Expected = ''
        }
        [pscustomobject]@{
            Name = 'wrong command type'; Windows = $false
            Commands = @{ 'python3.12' = @('Alias', '/opt/python3.12') }
            Valid = @('/opt/python3.12'); Expected = ''
        }
        [pscustomobject]@{
            Name = 'only wrong versions'; Windows = $false
            Commands = @{
                'python3.12' = @('Application', '/wrong/python3.12')
                python3 = @('Application', '/wrong/python3')
                python = @('Application', '/wrong/python')
            }
            Valid = @(); Expected = ''
        }
    )
    foreach ($objPythonFixture in $arrPythonFixtures) {
        $hashtableCommands = $objPythonFixture.Commands
        $arrValidPaths = @($objPythonFixture.Valid)
        $boolWindowsFixture = $objPythonFixture.Windows
        $scriptblockResolver = {
            param([string] $Name)
            if (-not $hashtableCommands.ContainsKey($Name)) { return @() }
            $arrCommand = $hashtableCommands[$Name]
            return [pscustomobject]@{ CommandType = $arrCommand[0]; Path = $arrCommand[1] }
        }.GetNewClosure()
        $scriptblockProbe = {
            param([string] $Path, [string[]] $PrefixArgument)
            $boolPrefixValid = -not $boolWindowsFixture -or
                ($PrefixArgument.Count -eq 1 -and $PrefixArgument[0] -ceq '-3.12')
            return $boolPrefixValid -and $arrValidPaths -ccontains $Path
        }.GetNewClosure()
        $objPythonResolution = Get-Python312CommandContext `
            -WindowsPlatform $objPythonFixture.Windows `
            -CommandResolver $scriptblockResolver `
            -VersionProbe $scriptblockProbe
        $strResolvedPath = if ($null -eq $objPythonResolution) {
            ''
        }
        else {
            $objPythonResolution.Path
        }
        if ($strResolvedPath -cne $objPythonFixture.Expected) {
            throw "Python fixture failed: $($objPythonFixture.Name)."
        }
    }

    $strNodeFixtureRoot = [System.IO.Path]::GetFullPath(
        (Join-Path -Path $PSScriptRoot -ChildPath 'node-runtime-fixture')
    )
    $strNodeDirectPath = Join-Path -Path $strNodeFixtureRoot -ChildPath 'node-direct'
    $strNodeWrapperPath = Join-Path -Path $strNodeFixtureRoot -ChildPath 'node-wrapper'
    $strNodeFallbackPath = Join-Path -Path $strNodeFixtureRoot -ChildPath 'node-fallback'
    $strMissingNodePath = Join-Path -Path $strNodeFixtureRoot -ChildPath 'node-missing'
    $arrNodeFixtures = @(
        [pscustomobject]@{
            Name = 'direct runtime'
            Candidates = @([pscustomobject]@{
                    CommandType = 'Application'; Path = $strNodeDirectPath
                })
            Probes = @{
                $strNodeDirectPath = [pscustomobject]@{
                    ExitCode = 0
                    Output = (@{
                            execPath = $strNodeDirectPath; nodeVersion = '24.18.0'
                        } | ConvertTo-Json -Compress)
                    Error = ''
                }
            }
            Applications = @{
                $strNodeDirectPath = @([pscustomobject]@{
                        CommandType = 'Application'; Path = $strNodeDirectPath
                    })
            }
            Expected = $strNodeDirectPath
        }
        [pscustomobject]@{
            Name = 'wrapper reports direct runtime'
            Candidates = @([pscustomobject]@{
                    CommandType = 'Application'; Path = $strNodeWrapperPath
                })
            Probes = @{
                $strNodeWrapperPath = [pscustomobject]@{
                    ExitCode = 0
                    Output = (@{
                            execPath = $strNodeDirectPath; nodeVersion = '24.18.0'
                        } | ConvertTo-Json -Compress)
                    Error = ''
                }
            }
            Applications = @{
                $strNodeDirectPath = @([pscustomobject]@{
                        CommandType = 'Application'; Path = $strNodeDirectPath
                    })
            }
            Expected = $strNodeDirectPath
        }
        [pscustomobject]@{
            Name = 'invalid probe output'
            Candidates = @([pscustomobject]@{
                    CommandType = 'Application'; Path = $strNodeWrapperPath
                })
            Probes = @{
                $strNodeWrapperPath = [pscustomobject]@{
                    ExitCode = 0; Output = 'not-json'; Error = ''
                }
            }
            Applications = @{}
            Expected = ''
        }
        [pscustomobject]@{
            Name = 'reported path is missing'
            Candidates = @([pscustomobject]@{
                    CommandType = 'Application'; Path = $strNodeWrapperPath
                })
            Probes = @{
                $strNodeWrapperPath = [pscustomobject]@{
                    ExitCode = 0
                    Output = (@{
                            execPath = $strMissingNodePath; nodeVersion = '24.18.0'
                        } | ConvertTo-Json -Compress)
                    Error = ''
                }
            }
            Applications = @{}
            Expected = ''
        }
        [pscustomobject]@{
            Name = 'reported path has wrong command type'
            Candidates = @([pscustomobject]@{
                    CommandType = 'Application'; Path = $strNodeWrapperPath
                })
            Probes = @{
                $strNodeWrapperPath = [pscustomobject]@{
                    ExitCode = 0
                    Output = (@{
                            execPath = $strNodeDirectPath; nodeVersion = '24.18.0'
                        } | ConvertTo-Json -Compress)
                    Error = ''
                }
            }
            Applications = @{
                $strNodeDirectPath = @([pscustomobject]@{
                        CommandType = 'Alias'; Path = $strNodeDirectPath
                    })
            }
            Expected = ''
        }
        [pscustomobject]@{
            Name = 'old runtime falls back to supported runtime'
            Candidates = @(
                [pscustomobject]@{
                    CommandType = 'Application'; Path = $strNodeWrapperPath
                }
                [pscustomobject]@{
                    CommandType = 'Application'; Path = $strNodeFallbackPath
                }
            )
            Probes = @{
                $strNodeWrapperPath = [pscustomobject]@{
                    ExitCode = 0
                    Output = (@{
                            execPath = $strNodeDirectPath; nodeVersion = '20.20.0'
                        } | ConvertTo-Json -Compress)
                    Error = ''
                }
                $strNodeFallbackPath = [pscustomobject]@{
                    ExitCode = 0
                    Output = (@{
                            execPath = $strNodeFallbackPath; nodeVersion = '24.18.0'
                        } | ConvertTo-Json -Compress)
                    Error = ''
                }
            }
            Applications = @{
                $strNodeFallbackPath = @([pscustomobject]@{
                        CommandType = 'Application'; Path = $strNodeFallbackPath
                    })
            }
            Expected = $strNodeFallbackPath
        }
    )
    foreach ($objNodeFixture in $arrNodeFixtures) {
        $arrFixtureCandidates = @($objNodeFixture.Candidates)
        $hashtableNodeProbes = $objNodeFixture.Probes
        $hashtableNodeApplications = $objNodeFixture.Applications
        $scriptblockNodeCommandResolver = {
            param([string] $Name)
            if ($Name -cne 'node') { return @() }
            return $arrFixtureCandidates
        }.GetNewClosure()
        $scriptblockNodeRuntimeProbe = {
            param([string] $Path)
            if (-not $hashtableNodeProbes.ContainsKey($Path)) {
                return [pscustomobject]@{ ExitCode = -1; Output = ''; Error = '' }
            }
            return $hashtableNodeProbes[$Path]
        }.GetNewClosure()
        $scriptblockNodeApplicationResolver = {
            param([string] $Path)
            if (-not $hashtableNodeApplications.ContainsKey($Path)) { return @() }
            return $hashtableNodeApplications[$Path]
        }.GetNewClosure()
        $objNodeResolution = Get-NodeApplicationContext `
            -CommandResolver $scriptblockNodeCommandResolver `
            -RuntimeProbe $scriptblockNodeRuntimeProbe `
            -ApplicationResolver $scriptblockNodeApplicationResolver
        $strResolvedNodePath = if ($null -eq $objNodeResolution) {
            ''
        }
        else {
            $objNodeResolution.Path
        }
        if ($strResolvedNodePath -cne $objNodeFixture.Expected) {
            throw "Node fixture failed: $($objNodeFixture.Name)."
        }
    }

    $strDocsStaleMetadataMutation = $strDocsInstructionsContent +
        [Environment]::NewLine + [Environment]::NewLine +
        'Rendered docs metadata transition mutation.'
    $objDocsMetadataContext = Get-DocumentMetadataContext `
        -Content $strDocsInstructionsContent
    if ($null -ne $objDocsMetadataContext.Failure) {
        throw 'Could not parse documentation instructions metadata for mutation tests.'
    }
    $objNewDocumentVersionMatch = [regex]::Match(
        $strDocsInstructionsContent,
        '(?m)^\*\*Version:\*\* (?<Prefix>\d+\.\d+\.\d{8}\.)\d+$'
    )
    if (-not $objNewDocumentVersionMatch.Success) {
        throw 'New-document Version fixture is missing.'
    }
    $strNewDocumentRevisionMutation = $strDocsInstructionsContent.Remove(
        $objNewDocumentVersionMatch.Index,
        $objNewDocumentVersionMatch.Length
    ).Insert(
        $objNewDocumentVersionMatch.Index,
        '**Version:** ' + $objNewDocumentVersionMatch.Groups['Prefix'].Value + '1'
    )
    $arrNewDocumentRevisionFailures = @(Get-DocumentMetadataTransitionFailure `
            -Name '.github/instructions/docs.instructions.md' `
            -CurrentContent $strNewDocumentRevisionMutation `
            -ParentContent $null `
            -ExpectedUtcDate $objDocsMetadataContext.UpdatedDate `
            -IsNewDocumentTransition $true)
    if (-not ($arrNewDocumentRevisionFailures -match [regex]::Escape(
                'Version revision must be 0 when no published baseline exists.'
            ))) {
        throw 'A nonzero initial revision was accepted.'
    }
    $objDocsExpectedUtcDate = [DateTime]::ParseExact(
        $objDocsMetadataContext.UpdatedDate,
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture
    )
    $arrNewDocumentMismatchDates = @(
        $objDocsExpectedUtcDate.AddDays(-1).ToString(
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $objDocsExpectedUtcDate.AddDays(-2).ToString(
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    )
    foreach ($strNewDocumentDate in $arrNewDocumentMismatchDates) {
        $strNewDocumentMutation = $strDocsInstructionsContent.Replace(
            $objDocsMetadataContext.VersionDate,
            $strNewDocumentDate.Replace('-', '')
        ).Replace(
            "- **Last Updated:** $($objDocsMetadataContext.UpdatedDate)",
            "- **Last Updated:** $strNewDocumentDate"
        )
        $arrNewDocumentFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name '.github/instructions/docs.instructions.md' `
                -CurrentContent $strNewDocumentMutation `
                -ParentContent $null `
                -ExpectedUtcDate $objDocsMetadataContext.UpdatedDate `
                -IsNewDocumentTransition $true)
        if (-not ($arrNewDocumentFailures -match 'Last Updated must be')) {
            throw "A new document with date $strNewDocumentDate did not fail closed."
        }
    }

    $objLegacyClaudeContext = $listGovernedDocumentContexts |
        Where-Object { $_.Path -ceq 'CLAUDE.md' }
    if ($null -eq $objLegacyClaudeContext) {
        throw 'Could not locate CLAUDE.md for legacy-parent mutation tests.'
    }
    $objLegacyClaudeMetadataContext = Get-DocumentMetadataContext `
        -Content $objLegacyClaudeContext.Content
    if ($null -ne $objLegacyClaudeMetadataContext.Failure) {
        throw 'Could not parse CLAUDE.md metadata for legacy-parent mutation tests.'
    }
    $strLegacyClaudeExpectedUtcDate = $objLegacyClaudeMetadataContext.UpdatedDate
    $strLegacyClaudeParentFixture = "# Legacy CLAUDE fixture`n"
    $objLegacyClaudeFixtureSha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $arrLegacyClaudeFixtureHashBytes = $objLegacyClaudeFixtureSha256.ComputeHash(
            [System.Text.UTF8Encoding]::new($false).GetBytes(
                $strLegacyClaudeParentFixture
            )
        )
    }
    finally {
        $objLegacyClaudeFixtureSha256.Dispose()
    }
    $strLegacyClaudeFixtureHash = [System.BitConverter]::ToString(
        $arrLegacyClaudeFixtureHashBytes
    ).Replace('-', '').ToLowerInvariant()
    $strOriginalLegacyClaudeHash =
        $script:hashtableLegacyMetadataParentSha256['CLAUDE.md']
    try {
        $script:hashtableLegacyMetadataParentSha256['CLAUDE.md'] =
            $strLegacyClaudeFixtureHash
        $arrLegacyClaudeControlFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name 'CLAUDE.md' `
                -CurrentContent $objLegacyClaudeContext.Content `
                -ParentContent $strLegacyClaudeParentFixture `
                -ExpectedUtcDate $strLegacyClaudeExpectedUtcDate `
                -IsNewDocumentTransition $false)
        if ($arrLegacyClaudeControlFailures.Count -ne 0) {
            throw 'The exact legacy CLAUDE.md parent did not pass its one-time transition.'
        }
        $arrLegacyClaudeMutationFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name 'CLAUDE.md' `
                -CurrentContent $objLegacyClaudeContext.Content `
                -ParentContent ($strLegacyClaudeParentFixture + ' ') `
                -ExpectedUtcDate $strLegacyClaudeExpectedUtcDate `
                -IsNewDocumentTransition $false)
        if (-not ($arrLegacyClaudeMutationFailures -match 'The parent of CLAUDE.md')) {
            throw 'A mutated legacy CLAUDE.md parent was accepted.'
        }
        $arrLegacyClaudeWrongNameFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name 'AGENTS.md' `
                -CurrentContent $objLegacyClaudeContext.Content `
                -ParentContent $strLegacyClaudeParentFixture `
                -ExpectedUtcDate $strLegacyClaudeExpectedUtcDate `
                -IsNewDocumentTransition $false)
        if (-not ($arrLegacyClaudeWrongNameFailures -match 'The parent of AGENTS.md')) {
            throw 'The legacy CLAUDE.md parent exception applied to a different path.'
        }
        $objLegacyClaudeExpectedDate = [DateTime]::ParseExact(
            $strLegacyClaudeExpectedUtcDate,
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $strLegacyClaudeStaleDate = $objLegacyClaudeExpectedDate.AddDays(-1).ToString(
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $strLegacyClaudeStaleCurrent = $objLegacyClaudeContext.Content.Replace(
            $strLegacyClaudeExpectedUtcDate.Replace('-', ''),
            $strLegacyClaudeStaleDate.Replace('-', '')
        ).Replace(
            "- **Last Updated:** $strLegacyClaudeExpectedUtcDate",
            "- **Last Updated:** $strLegacyClaudeStaleDate"
        )
        $arrLegacyClaudeStaleFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name 'CLAUDE.md' `
                -CurrentContent $strLegacyClaudeStaleCurrent `
                -ParentContent $strLegacyClaudeParentFixture `
                -ExpectedUtcDate $strLegacyClaudeExpectedUtcDate `
                -IsNewDocumentTransition $false)
        if (-not ($arrLegacyClaudeStaleFailures -match 'Last Updated must be')) {
            throw 'The legacy CLAUDE.md transition accepted a stale current date.'
        }
    }
    finally {
        $script:hashtableLegacyMetadataParentSha256['CLAUDE.md'] =
            $strOriginalLegacyClaudeHash
    }
    $arrDocsStaleMetadataFailures = @(Get-DocumentMetadataTransitionFailure `
            -Name '.github/instructions/docs.instructions.md' `
            -CurrentContent $strDocsStaleMetadataMutation `
            -ParentContent $strDocsInstructionsContent `
            -ExpectedUtcDate $objDocsMetadataContext.UpdatedDate `
            -IsNewDocumentTransition $false)
    if (-not ($arrDocsStaleMetadataFailures -match [regex]::Escape(
                '.github/instructions/docs.instructions.md Version revision must be'
            ))) {
        throw 'The docs-only stale-metadata mutation did not fail closed.'
    }

    $arrNewlyCoveredPaths = @(
        '.github/instructions/yaml.instructions.md'
    )
    foreach ($strNewlyCoveredPath in $arrNewlyCoveredPaths) {
        $objDocumentContext = $listGovernedDocumentContexts |
            Where-Object { $_.Path -ceq $strNewlyCoveredPath }
        if ($null -eq $objDocumentContext) {
            throw "Could not locate newly covered metadata input: $strNewlyCoveredPath"
        }
        $objMetadataContext = Get-DocumentMetadataContext `
            -Content $objDocumentContext.Content
        if ($null -ne $objMetadataContext.Failure) {
            throw "Could not parse newly covered metadata input: $strNewlyCoveredPath"
        }
        $strStaleMetadataMutation = $objDocumentContext.Content +
            [Environment]::NewLine + [Environment]::NewLine +
            'Rendered governed-instruction metadata mutation.'
        $arrStaleMetadataFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name $strNewlyCoveredPath `
                -CurrentContent $strStaleMetadataMutation `
                -ParentContent $objDocumentContext.Content `
                -ExpectedUtcDate $objMetadataContext.UpdatedDate `
                -IsNewDocumentTransition $false)
        $strExpectedFailure = "$strNewlyCoveredPath Version revision must be"
        if (-not ($arrStaleMetadataFailures -match [regex]::Escape(
                    $strExpectedFailure
                ))) {
            throw "$strNewlyCoveredPath stale-metadata mutation did not fail closed."
        }
    }

    $strFutureInstructionPath = '.github/instructions/future.instructions.md'
    $arrInventoryMutationFailures = @(
        Get-GovernedInstructionInventoryFailure `
            -CatalogPaths @($arrGovernedInstructionDocuments.Path) `
            -TrackedPaths @(
                $arrTrackedGovernedInstructionPaths + $strFutureInstructionPath
            )
    )
    $strExpectedInventoryFailure =
        "Tracked governed instruction is missing from the catalog: $strFutureInstructionPath"
    if (-not ($arrInventoryMutationFailures -ccontains $strExpectedInventoryFailure)) {
        throw 'The governed-instruction inventory mutation did not fail closed.'
    }

    $arrMetadataOptionalContexts = @(
        $listGovernedDocumentContexts |
            Where-Object { -not $_.RequiresMetadata }
    )
    if ($arrMetadataOptionalContexts.Count -ne 1 -or
        $arrMetadataOptionalContexts[0].Path -cne '.github/copilot-instructions.md') {
        throw 'Only the Copilot instruction document can omit visible metadata.'
    }
    $arrUnexpectedMetadataRequirements = @(
        $listGovernedDocumentContexts |
            Where-Object {
                $_.Path -cne '.github/copilot-instructions.md' -and
                -not $_.RequiresMetadata
            }
    )
    if ($arrUnexpectedMetadataRequirements.Count -ne 0) {
        throw 'A metadata-required governed document was marked optional.'
    }

    $listMetadataSelfTestContexts = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($objDocumentContext in @(
            $listGovernedDocumentContexts |
                Where-Object { $_.RequiresMetadata }
        )) {
        $objMetadataContext = Get-DocumentMetadataContext `
            -Content $objDocumentContext.Content
        if ($null -eq $objMetadataContext.Failure) {
            $listMetadataSelfTestContexts.Add($objDocumentContext)
        }
        elseif (-not (Test-LegacyMetadataParentContent `
                -Name $objDocumentContext.Path `
                -Content $objDocumentContext.Content)) {
            throw "Unexpected unversioned governed document: $($objDocumentContext.Path)"
        }
    }

    $arrRequiredFieldNames = @('Status', 'Owner', 'Scope')
    foreach ($objDocumentContext in $listMetadataSelfTestContexts) {
        foreach ($strFieldName in $arrRequiredFieldNames) {
            $objFieldLineMatch = [regex]::Match(
                $objDocumentContext.Content,
                "(?m)^- \*\*$([regex]::Escape($strFieldName)):\*\* [^\r\n]+$"
            )
            if (-not $objFieldLineMatch.Success) {
                throw "Could not locate $strFieldName in $($objDocumentContext.Path)."
            }
            $strFieldDeletion = $objDocumentContext.Content.Remove(
                $objFieldLineMatch.Index,
                $objFieldLineMatch.Length
            )
            $arrFieldFailures = @(Get-DocumentMetadataTransitionFailure `
                    -Name $objDocumentContext.Path `
                    -CurrentContent $strFieldDeletion `
                    -ParentContent $objDocumentContext.Content `
                    -ExpectedUtcDate $objDocumentContext.ExpectedUtcDate `
                    -IsNewDocumentTransition $false)
            $strExpectedFieldFailure = "$($objDocumentContext.Path) must contain " +
                "one exact top-level $strFieldName list item"
            if (-not ($arrFieldFailures -match [regex]::Escape(
                        $strExpectedFieldFailure
                    ))) {
                throw "$($objDocumentContext.Path) accepted deleted $strFieldName."
            }
        }
    }

    $objRepresentativeDocument = $listGovernedDocumentContexts[0]
    $strStatusLine = [regex]::Match(
        $objRepresentativeDocument.Content,
        '(?m)^- \*\*Status:\*\* [^\r\n]+$'
    ).Value
    foreach ($strAllowedStatus in $script:arrAllowedMetadataStatuses) {
        $strAllowedStatusContent = $objRepresentativeDocument.Content.Replace(
            $strStatusLine,
            "- **Status:** $strAllowedStatus"
        )
        $objAllowedStatusContext = Get-DocumentMetadataContext `
            -Content $strAllowedStatusContent
        if ($null -ne $objAllowedStatusContext.Failure) {
            throw "Status failed: $strAllowedStatus"
        }
    }
    foreach ($strInvalidStatusLine in @(
            '- **Status:** Complete',
            '- **Status:** active',
            '- **Status:**'
        )) {
        $objInvalidStatusContext = Get-DocumentMetadataContext `
            -Content $objRepresentativeDocument.Content.Replace(
                $strStatusLine,
                $strInvalidStatusLine
            )
        if ($null -eq $objInvalidStatusContext.Failure) {
            throw "Invalid Status passed: $strInvalidStatusLine"
        }
    }
    $arrRepresentativeFieldMutations = @(
        [pscustomobject]@{
            Field = 'Status'
            Replacement = '- **Status:** Complete'
        },
        [pscustomobject]@{
            Field = 'Owner'
            Replacement = '- **Owner:** '
        },
        [pscustomobject]@{
            Field = 'Scope'
            Replacement = '- **Scope:** '
        }
    )
    foreach ($objFieldMutation in $arrRepresentativeFieldMutations) {
        $objFieldLineMatch = [regex]::Match(
            $objRepresentativeDocument.Content,
            "(?m)^- \*\*$([regex]::Escape($objFieldMutation.Field)):\*\* [^\r\n]+$"
        )
        $strFieldMutation = $objRepresentativeDocument.Content.Remove(
            $objFieldLineMatch.Index,
            $objFieldLineMatch.Length
        ).Insert($objFieldLineMatch.Index, $objFieldMutation.Replacement)
        $arrFieldFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name $objRepresentativeDocument.Path `
                -CurrentContent $strFieldMutation `
                -ParentContent $objRepresentativeDocument.Content `
                -ExpectedUtcDate $objRepresentativeDocument.ExpectedUtcDate `
                -IsNewDocumentTransition $false)
        $strExpectedFieldFailure = "$($objRepresentativeDocument.Path) must contain " +
            "one exact top-level $($objFieldMutation.Field) list item"
        if (-not ($arrFieldFailures -match [regex]::Escape(
                    $strExpectedFieldFailure
                ))) {
            throw "Malformed $($objFieldMutation.Field) mutation was accepted."
        }
    }

    foreach ($strHiddenStatus in @(
            "<div>`n$strStatusLine`n</div>",
            "- Wrapper`n  $strStatusLine"
        )) {
        $strHiddenStatusMutation = $objRepresentativeDocument.Content.Replace(
            $strStatusLine,
            $strHiddenStatus
        )
        $arrFieldFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name $objRepresentativeDocument.Path `
                -CurrentContent $strHiddenStatusMutation `
                -ParentContent $objRepresentativeDocument.Content `
                -ExpectedUtcDate $objRepresentativeDocument.ExpectedUtcDate `
                -IsNewDocumentTransition $false)
        if (-not ($arrFieldFailures -match 'one exact top-level Status list item')) {
            throw 'A non-operative Status mutation was accepted.'
        }
    }

    Assert-RepositoryInputMetadataMutationRejected `
        -Name 'missing Git index entry mutation' `
        -GitIndexEntryCount 0 `
        -ExpectedFailure 'missing Git index entry mutation must have exactly one Git index entry.'

    Assert-RepositoryInputMetadataMutationRejected `
        -Name 'Git symlink mode mutation' `
        -GitMode '120000' `
        -ExpectedFailure 'Git symlink mode mutation must be a stage-0 regular file with Git mode 100644.'

    Assert-RepositoryInputMetadataMutationRejected `
        -Name 'nonzero Git stage mutation' `
        -GitStage '2' `
        -ExpectedFailure 'nonzero Git stage mutation must be a stage-0 regular file with Git mode 100644.'

    Assert-RepositoryInputMetadataMutationRejected `
        -Name 'non-file worktree item mutation' `
        -IsFileInfo $false `
        -ExpectedFailure 'non-file worktree item mutation must be a regular worktree file.'

    Assert-RepositoryInputMetadataMutationRejected `
        -Name 'reparse-point mutation' `
        -Attributes ([System.IO.FileAttributes]::Normal -bor [System.IO.FileAttributes]::ReparsePoint) `
        -ExpectedFailure 'reparse-point mutation must not be a symbolic link or reparse point.'

    Assert-RepositoryInputMetadataMutationRejected `
        -Name 'link-type mutation' `
        -LinkType 'SymbolicLink' `
        -ExpectedFailure 'link-type mutation must not have a link type.'

    Assert-RepositoryInputMetadataMutationRejected `
        -Name 'Unix device mutation' `
        -UnixMode 'crw-rw-rw-' `
        -ExpectedFailure 'Unix device mutation must have a regular Unix file type.'

    Assert-OversizedStreamMutationRejected

    Assert-EncodingMutationRejected `
        -Name 'malformed UTF-8 mutation' `
        -Bytes ([byte[]] @(0xC3, 0x28))

    Assert-EncodingMutationRejected `
        -Name 'UTF-8 BOM mutation' `
        -Bytes ([byte[]] @(0xEF, 0xBB, 0xBF, 0x41))

    Assert-EncodingMutationRejected `
        -Name 'UTF-16LE BOM mutation' `
        -Bytes ([byte[]] @(0xFF, 0xFE, 0x41, 0x00))

    Assert-MutationRejected `
        -Name 'malformed TOML suffix' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent ($strCodexConfigContent + [Environment]::NewLine +
            'invalid = [' + [Environment]::NewLine) `
        -ExpectedFailure 'The project configuration must contain valid TOML.'

    $strWorkflowPolicyCommandFailure =
        'must contain one exact workflow-policy command: ' +
        $script:strWorkflowPolicyCommand
    $strBareWorkflowPolicyCommand = $script:strWorkflowPolicyCommandPrefix +
        ' build.yml markdownlint.yml'
    foreach ($strDocumentName in @('AGENTS.md', 'CLAUDE.md')) {
        $strDocumentContent = if ($strDocumentName -ceq 'AGENTS.md') {
            $strAgentsContent
        }
        else {
            $strClaudeContent
        }
        $arrWorkflowPolicyCommandMutations = @(
            [pscustomobject]@{
                Name = 'removed'
                Content = $strDocumentContent.Replace(
                    $script:strWorkflowPolicyCommand,
                    'removed workflow-policy command'
                )
            },
            [pscustomobject]@{
                Name = 'uses bare workflow paths'
                Content = $strDocumentContent.Replace(
                    $script:strWorkflowPolicyCommand,
                    $strBareWorkflowPolicyCommand
                )
            },
            [pscustomobject]@{
                Name = 'duplicated'
                Content = $strDocumentContent + "`n`n" + [char]96 +
                    $script:strWorkflowPolicyCommand + [char]96
            }
        )
        foreach ($objMutation in $arrWorkflowPolicyCommandMutations) {
            if ($objMutation.Content -ceq $strDocumentContent) {
                throw (
                    "Could not create $strDocumentName workflow-policy command " +
                    "mutation: $($objMutation.Name)."
                )
            }
            if ($strDocumentName -ceq 'AGENTS.md') {
                Assert-MutationRejected `
                    -Name "AGENTS workflow-policy command $($objMutation.Name)" `
                    -AgentsContent $objMutation.Content `
                    -ClaudeContent $strClaudeContent `
                    -CodexConfigContent $strCodexConfigContent `
                    -ExpectedFailure "AGENTS.md $strWorkflowPolicyCommandFailure"
            }
            else {
                Assert-MutationRejected `
                    -Name "CLAUDE workflow-policy command $($objMutation.Name)" `
                    -AgentsContent $strAgentsContent `
                    -ClaudeContent $objMutation.Content `
                    -CodexConfigContent $strCodexConfigContent `
                    -ExpectedFailure "CLAUDE.md $strWorkflowPolicyCommandFailure"
            }
        }
    }

    $objAgentsVersionMatch = [regex]::Match(
        $strAgentsContent,
        '(?m)^\*\*Version:\*\* (?<Prefix>(?<Major>\d+)\.(?<Minor>\d+)\.)' +
            '(?<Date>\d{8})\.(?<Revision>\d+)$'
    )
    $objAgentsUpdatedMatch = [regex]::Match(
        $strAgentsContent,
        '(?m)^- \*\*Last Updated:\*\* (?<Date>\d{4}-\d{2}-\d{2})$'
    )
    if (-not $objAgentsVersionMatch.Success -or -not $objAgentsUpdatedMatch.Success) {
        throw 'Could not parse AGENTS metadata for transition mutation tests.'
    }
    $objClaudeVersionMatch = [regex]::Match(
        $strClaudeContent,
        '(?m)^\*\*Version:\*\* (?<Prefix>\d+\.\d+\.)' +
            '(?<Date>\d{8})\.(?<Revision>\d+)$'
    )
    $objClaudeUpdatedMatch = [regex]::Match(
        $strClaudeContent,
        '(?m)^- \*\*Last Updated:\*\* (?<Date>\d{4}-\d{2}-\d{2})$'
    )
    if (-not $objClaudeVersionMatch.Success -or -not $objClaudeUpdatedMatch.Success) {
        throw 'Could not parse CLAUDE metadata for structural mutation tests.'
    }

    $strUnversionedAgentsContent = $strAgentsContent.Remove(
        $objAgentsVersionMatch.Index,
        $objAgentsVersionMatch.Length
    )
    $arrOptionalVersionDirectFixtures = @(
        [pscustomobject]@{
            Name = 'versioned to versioned'
            Current = $strAgentsContent
            Parent = $strAgentsContent
            IsNew = $false
        },
        [pscustomobject]@{
            Name = 'unversioned to unversioned'
            Current = $strUnversionedAgentsContent
            Parent = $strUnversionedAgentsContent
            IsNew = $false
        },
        [pscustomobject]@{
            Name = 'unversioned to versioned revision zero'
            Current = $strAgentsContent
            Parent = $strUnversionedAgentsContent
            IsNew = $false
        },
        [pscustomobject]@{
            Name = 'versioned to unversioned'
            Current = $strUnversionedAgentsContent
            Parent = $strAgentsContent
            IsNew = $false
        },
        [pscustomobject]@{
            Name = 'new unversioned document'
            Current = $strUnversionedAgentsContent
            Parent = $null
            IsNew = $true
        }
    )
    foreach ($objOptionalVersionFixture in $arrOptionalVersionDirectFixtures) {
        $arrOptionalVersionFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name 'AGENTS.md' `
                -CurrentContent $objOptionalVersionFixture.Current `
                -ParentContent $objOptionalVersionFixture.Parent `
                -ExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
                -IsNewDocumentTransition $objOptionalVersionFixture.IsNew)
        if ($arrOptionalVersionFailures.Count -ne 0) {
            throw (
                "Optional-Version direct fixture '$($objOptionalVersionFixture.Name)' " +
                "failed: $($arrOptionalVersionFailures -join '; ')"
            )
        }
    }
    $strHistoricalVersionedAgentsContent = $strAgentsContent.Replace(
        $objAgentsVersionMatch.Value,
        '**Version:** ' + $objAgentsVersionMatch.Groups['Prefix'].Value +
            '20000101.' + $objAgentsVersionMatch.Groups['Revision'].Value
    ).Replace(
        $objAgentsUpdatedMatch.Value,
        '- **Last Updated:** 2000-01-01'
    )
    $objHistoricalVersionMatch = [regex]::Match(
        $strHistoricalVersionedAgentsContent,
        '(?m)^\*\*Version:\*\* [^\r\n]+$'
    )
    if (-not $objHistoricalVersionMatch.Success) {
        throw 'Could not create the historical optional-Version fixture.'
    }
    $strHistoricalUnversionedAgentsContent = $strHistoricalVersionedAgentsContent.Remove(
        $objHistoricalVersionMatch.Index,
        $objHistoricalVersionMatch.Length
    )
    $arrHistoricalUnversionedRenderedFailures = @(
        Get-DocumentMetadataTransitionFailure `
            -Name 'AGENTS.md' `
            -CurrentContent (
                $strHistoricalUnversionedAgentsContent +
                "`nRendered unversioned fixture."
            ) `
            -ParentContent $strHistoricalUnversionedAgentsContent `
            -ExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
            -IsNewDocumentTransition $false
    )
    if (-not ($arrHistoricalUnversionedRenderedFailures -match
            'Last Updated must be .* after a rendered-content change')) {
        throw 'A rendered unversioned change with stale Last Updated was accepted.'
    }
    $arrHistoricalVersionRemovalFailures = @(
        Get-DocumentMetadataTransitionFailure `
            -Name 'AGENTS.md' `
            -CurrentContent $strHistoricalUnversionedAgentsContent `
            -ParentContent $strHistoricalVersionedAgentsContent `
            -ExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
            -IsNewDocumentTransition $false
    )
    if (-not ($arrHistoricalVersionRemovalFailures -match
            'Last Updated must be .* after a rendered-content change')) {
        throw 'A Version removal with stale Last Updated was accepted.'
    }
    $strInvalidUnversionedUpdated = $strUnversionedAgentsContent.Replace(
        $objAgentsUpdatedMatch.Value,
        '- **Last Updated:** 9999-99-99'
    )
    $arrInvalidUnversionedUpdatedFailures = @(
        Get-DocumentMetadataTransitionFailure `
            -Name 'AGENTS.md' `
            -CurrentContent $strInvalidUnversionedUpdated `
            -ParentContent $strUnversionedAgentsContent `
            -ExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
            -IsNewDocumentTransition $false
    )
    if (-not ($arrInvalidUnversionedUpdatedFailures -match
            'Last Updated must contain one real calendar date')) {
        throw 'An unversioned document with an invalid Last Updated date was accepted.'
    }
    $strFutureUnversionedUpdated = $strUnversionedAgentsContent.Replace(
        $objAgentsUpdatedMatch.Value,
        '- **Last Updated:** 2099-12-31'
    )
    $arrFutureUnversionedUpdatedFailures = @(
        Get-DocumentMetadataTransitionFailure `
            -Name 'AGENTS.md' `
            -CurrentContent $strFutureUnversionedUpdated `
            -ParentContent $strUnversionedAgentsContent `
            -ExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
            -IsNewDocumentTransition $false
    )
    if (-not ($arrFutureUnversionedUpdatedFailures -match
            'Last Updated 2099-12-31 must not be later than trusted UTC date')) {
        throw 'An unversioned document with a future Last Updated date was accepted.'
    }
    $strIntroducedNonzeroVersion = $strAgentsContent.Replace(
        $objAgentsVersionMatch.Value,
        '**Version:** ' + $objAgentsVersionMatch.Groups['Prefix'].Value +
            $objAgentsVersionMatch.Groups['Date'].Value + '.1'
    )
    $arrIntroducedNonzeroFailures = @(Get-DocumentMetadataTransitionFailure `
            -Name 'AGENTS.md' `
            -CurrentContent $strIntroducedNonzeroVersion `
            -ParentContent $strUnversionedAgentsContent `
            -ExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
            -IsNewDocumentTransition $false)
    if (-not ($arrIntroducedNonzeroFailures -match
            'Version revision must be 0 when Version is added')) {
        throw 'An introduced Version with a nonzero revision was accepted.'
    }
    $strUnversionedMissingUpdated = $strUnversionedAgentsContent.Remove(
        $objAgentsUpdatedMatch.Index - $objAgentsVersionMatch.Length,
        $objAgentsUpdatedMatch.Length
    )
    $arrUnversionedMissingUpdatedFailures = @(
        Get-DocumentMetadataTransitionFailure `
            -Name 'AGENTS.md' `
            -CurrentContent $strUnversionedMissingUpdated `
            -ParentContent $strUnversionedAgentsContent `
            -ExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
            -IsNewDocumentTransition $false
    )
    if (-not ($arrUnversionedMissingUpdatedFailures -match
            'one exact top-level Last Updated list item')) {
        throw 'An unversioned document without Last Updated was accepted.'
    }

    $arrMetadataStructureDocuments = @(
        [pscustomobject]@{
            Name = 'AGENTS.md'
            Content = $strAgentsContent
            H1Line = [regex]::Match($strAgentsContent, '(?m)^# .+$').Value
            VersionLine = $objAgentsVersionMatch.Value
            UpdatedLine = $objAgentsUpdatedMatch.Value
        },
        [pscustomobject]@{
            Name = 'CLAUDE.md'
            Content = $strClaudeContent
            H1Line = [regex]::Match($strClaudeContent, '(?m)^# .+$').Value
            VersionLine = $objClaudeVersionMatch.Value
            UpdatedLine = $objClaudeUpdatedMatch.Value
        }
    )
    foreach ($objDocument in $arrMetadataStructureDocuments) {
        if ([string]::IsNullOrEmpty($objDocument.H1Line)) {
            throw "Could not locate the $($objDocument.Name) H1 for structural mutation tests."
        }
        $strCodeFence = '```'
        $strH1Failure = "$($objDocument.Name) must contain exactly one " +
            'document-level H1 within the first 30 body lines.'
        $strVersionFailure = "$($objDocument.Name) must contain at most one exact " +
            'document-level Version paragraph immediately after the H1 and within ' +
            'the first 30 body lines.'
        $strMetadataHeadingFailure = "$($objDocument.Name) must place Metadata as " +
            'the first level-two heading immediately after the H1 or optional Version and within the ' +
            'first 30 body lines.'
        $strUpdatedFailure = "$($objDocument.Name) must contain one exact top-level " +
            'Last Updated list item in the Metadata section and within the first 30 body lines.'
        $arrMetadataStructureMutations = @(
            [pscustomobject]@{
                Name = 'duplicate document-level H1'
                Content = $objDocument.Content.Replace(
                    $objDocument.H1Line,
                    "$($objDocument.H1Line)`n`n$($objDocument.H1Line)"
                )
                Failure = $strH1Failure
            },
            [pscustomobject]@{
                Name = 'H1 after first 30 lines'
                Content = $objDocument.Content.Replace(
                    $objDocument.H1Line,
                    (("`n" * 30) + $objDocument.H1Line)
                )
                Failure = $strH1Failure
            },
            [pscustomobject]@{
                Name = 'Version in fenced code'
                Content = $objDocument.Content.Replace(
                    $objDocument.VersionLine,
                    ($strCodeFence + "text`n" + $objDocument.VersionLine +
                        "`n" + $strCodeFence)
                )
                Failure = $strMetadataHeadingFailure
            },
            [pscustomobject]@{
                Name = 'Version in multiline HTML comment'
                Content = $objDocument.Content.Replace(
                    $objDocument.VersionLine,
                    "<!--`n$($objDocument.VersionLine)`n-->"
                )
                Failure = $strMetadataHeadingFailure
            },
            [pscustomobject]@{
                Name = 'Version in block quote'
                Content = $objDocument.Content.Replace(
                    $objDocument.VersionLine,
                    "> $($objDocument.VersionLine)"
                )
                Failure = $strMetadataHeadingFailure
            },
            [pscustomobject]@{
                Name = 'Version in raw HTML block'
                Content = $objDocument.Content.Replace(
                    $objDocument.VersionLine,
                    "<div>`n$($objDocument.VersionLine)`n</div>"
                )
                Failure = $strMetadataHeadingFailure
            },
            [pscustomobject]@{
                Name = 'intervening paragraph before Version'
                Content = $objDocument.Content.Replace(
                    $objDocument.VersionLine,
                    "Intervening paragraph.`n`n$($objDocument.VersionLine)"
                )
                Failure = $strVersionFailure
            },
            [pscustomobject]@{
                Name = 'duplicate document-level Version'
                Content = $objDocument.Content.Replace(
                    $objDocument.VersionLine,
                    "$($objDocument.VersionLine)`n`n$($objDocument.VersionLine)"
                )
                Failure = $strVersionFailure
            },
            [pscustomobject]@{
                Name = 'malformed document-level Version'
                Content = $objDocument.Content.Replace(
                    $objDocument.VersionLine,
                    '**Version:** malformed'
                )
                Failure = $strVersionFailure
            },
            [pscustomobject]@{
                Name = 'malformed duplicate document-level Version'
                Content = $objDocument.Content.Replace(
                    $objDocument.VersionLine,
                    "$($objDocument.VersionLine)`n`n**Version:** malformed"
                )
                Failure = $strVersionFailure
            },
            [pscustomobject]@{
                Name = 'earlier level-two section before Metadata'
                Content = $objDocument.Content.Replace(
                    '## Metadata',
                    "## Earlier Section`n`nEarlier text.`n`n## Metadata"
                )
                Failure = $strMetadataHeadingFailure
            },
            [pscustomobject]@{
                Name = 'duplicate Metadata section'
                Content = $objDocument.Content.Replace(
                    '## Metadata',
                    "## Metadata`n`n## Metadata"
                )
                Failure = $strMetadataHeadingFailure
            },
            [pscustomobject]@{
                Name = 'Last Updated in fenced code'
                Content = $objDocument.Content.Replace(
                    $objDocument.UpdatedLine,
                    ($strCodeFence + "text`n" + $objDocument.UpdatedLine +
                        "`n" + $strCodeFence)
                )
                Failure = $strUpdatedFailure
            },
            [pscustomobject]@{
                Name = 'Last Updated in multiline HTML comment'
                Content = $objDocument.Content.Replace(
                    $objDocument.UpdatedLine,
                    "<!--`n$($objDocument.UpdatedLine)`n-->"
                )
                Failure = $strUpdatedFailure
            },
            [pscustomobject]@{
                Name = 'Last Updated in block quote'
                Content = $objDocument.Content.Replace(
                    $objDocument.UpdatedLine,
                    "> $($objDocument.UpdatedLine)"
                )
                Failure = $strUpdatedFailure
            },
            [pscustomobject]@{
                Name = 'Last Updated in nested list'
                Content = $objDocument.Content.Replace(
                    $objDocument.UpdatedLine,
                    "- Wrapper`n  $($objDocument.UpdatedLine)"
                )
                Failure = $strUpdatedFailure
            },
            [pscustomobject]@{
                Name = 'Last Updated in raw HTML block'
                Content = $objDocument.Content.Replace(
                    $objDocument.UpdatedLine,
                    "<div>`n$($objDocument.UpdatedLine)`n</div>"
                )
                Failure = $strUpdatedFailure
            },
            [pscustomobject]@{
                Name = 'Last Updated in later section'
                Content = $objDocument.Content.Replace(
                    $objDocument.UpdatedLine,
                    ''
                ).Replace(
                    '## Canonical Instructions',
                    "## Canonical Instructions`n`n$($objDocument.UpdatedLine)"
                )
                Failure = $strUpdatedFailure
            },
            [pscustomobject]@{
                Name = 'Last Updated after first 30 lines'
                Content = $objDocument.Content.Replace(
                    $objDocument.UpdatedLine,
                    (("`n" * 25) + $objDocument.UpdatedLine)
                )
                Failure = $strUpdatedFailure
            },
            [pscustomobject]@{
                Name = 'duplicate top-level Last Updated'
                Content = $objDocument.Content.Replace(
                    $objDocument.UpdatedLine,
                    "$($objDocument.UpdatedLine)`n$($objDocument.UpdatedLine)"
                )
                Failure = $strUpdatedFailure
            },
            [pscustomobject]@{
                Name = 'malformed top-level Last Updated'
                Content = $objDocument.Content.Replace(
                    $objDocument.UpdatedLine,
                    '- **Last Updated:** someday'
                )
                Failure = $strUpdatedFailure
            },
            [pscustomobject]@{
                Name = 'malformed duplicate top-level Last Updated'
                Content = $objDocument.Content.Replace(
                    $objDocument.UpdatedLine,
                    "$($objDocument.UpdatedLine)`n- **Last Updated:** someday"
                )
                Failure = $strUpdatedFailure
            }
        )

        foreach ($objMutation in $arrMetadataStructureMutations) {
            Write-Verbose (
                "Testing metadata structure mutation: $($objDocument.Name) " +
                $objMutation.Name
            )
            $hashtableMutation = @{
                Name = "$($objDocument.Name) $($objMutation.Name)"
                AgentsContent = if ($objDocument.Name -ceq 'AGENTS.md') {
                    $objMutation.Content
                }
                else {
                    $strAgentsContent
                }
                ClaudeContent = if ($objDocument.Name -ceq 'CLAUDE.md') {
                    $objMutation.Content
                }
                else {
                    $strClaudeContent
                }
                CodexConfigContent = $strCodexConfigContent
                ExpectedFailure = $objMutation.Failure
            }
            Assert-MutationRejected @hashtableMutation
        }

        $strParentMutation = $objDocument.Content.Replace(
            $objDocument.VersionLine,
            ($strCodeFence + "text`n" + $objDocument.VersionLine +
                "`n" + $strCodeFence)
        )
        $hashtableParentMutation = @{
            Name = "$($objDocument.Name) parent Version in fenced code"
            AgentsContent = $strAgentsContent
            ClaudeContent = $strClaudeContent
            CodexConfigContent = $strCodexConfigContent
            ExpectedFailure = "The parent of $strMetadataHeadingFailure"
        }
        if ($objDocument.Name -ceq 'AGENTS.md') {
            $hashtableParentMutation.ParentAgentsContent = $strParentMutation
        }
        else {
            $hashtableParentMutation.ParentClaudeContent = $strParentMutation
        }
        Write-Verbose (
            "Testing metadata structure mutation: $($objDocument.Name) parent " +
            'Version in fenced code'
        )
        Assert-MutationRejected @hashtableParentMutation

        $strParentUpdatedMutation = $objDocument.Content.Replace(
            $objDocument.UpdatedLine,
            "<!--`n$($objDocument.UpdatedLine)`n-->"
        )
        $hashtableParentUpdatedMutation = @{
            Name = "$($objDocument.Name) parent Last Updated in HTML comment"
            AgentsContent = $strAgentsContent
            ClaudeContent = $strClaudeContent
            CodexConfigContent = $strCodexConfigContent
            ExpectedFailure = "The parent of $strUpdatedFailure"
        }
        if ($objDocument.Name -ceq 'AGENTS.md') {
            $hashtableParentUpdatedMutation.ParentAgentsContent = $strParentUpdatedMutation
        }
        else {
            $hashtableParentUpdatedMutation.ParentClaudeContent = $strParentUpdatedMutation
        }
        Write-Verbose (
            "Testing metadata structure mutation: $($objDocument.Name) parent " +
            'Last Updated in HTML comment'
        )
        Assert-MutationRejected @hashtableParentUpdatedMutation
    }

    $intAgentsRevision = [int64] $objAgentsVersionMatch.Groups['Revision'].Value
    if ($intAgentsRevision -gt ([int64]::MaxValue - 2)) {
        throw 'The AGENTS revision is too large for transition mutation tests.'
    }
    $intNextAgentsRevision = $intAgentsRevision + 1
    $intJumpedAgentsRevision = $intAgentsRevision + 2
    $strAgentsVersionStem = '**Version:** ' +
        $objAgentsVersionMatch.Groups['Prefix'].Value +
        $objAgentsVersionMatch.Groups['Date'].Value + '.'
    $strAgentsVersionPrefix = '**Version:** ' +
        $objAgentsVersionMatch.Groups['Prefix'].Value
    $strAgentsRevisionSuffix = '.' + $objAgentsVersionMatch.Groups['Revision'].Value
    $arrInvalidCurrentDateFixtures = @(
        [pscustomobject]@{
            Name = 'impossible metadata month'
            VersionDate = '99999999'
            UpdatedDate = '9999-99-99'
        },
        [pscustomobject]@{
            Name = 'impossible metadata day'
            VersionDate = '20260230'
            UpdatedDate = '2026-02-30'
        },
        [pscustomobject]@{
            Name = 'non-leap metadata day'
            VersionDate = '20250229'
            UpdatedDate = '2025-02-29'
        }
    )
    foreach ($objDateFixture in $arrInvalidCurrentDateFixtures) {
        $strInvalidDateContent = $strAgentsContent.Replace(
            $objAgentsVersionMatch.Value,
            $strAgentsVersionPrefix + $objDateFixture.VersionDate +
                $strAgentsRevisionSuffix
        ).Replace(
            $objAgentsUpdatedMatch.Value,
            '- **Last Updated:** ' + $objDateFixture.UpdatedDate
        )
        Assert-MutationRejected `
            -Name $objDateFixture.Name `
            -AgentsContent $strInvalidDateContent `
            -ClaudeContent $strClaudeContent `
            -CodexConfigContent $strCodexConfigContent `
            -ParentAgentsContent $strAgentsContent `
            -ExpectedFailure (
                'AGENTS.md Last Updated must contain one real calendar date.'
            )
    }

    $strFutureMetadataContent = $strAgentsContent.Replace(
        $objAgentsVersionMatch.Value,
        $strAgentsVersionPrefix + '20991231' + $strAgentsRevisionSuffix
    ).Replace(
        $objAgentsUpdatedMatch.Value,
        '- **Last Updated:** 2099-12-31'
    ) + [Environment]::NewLine + 'Future metadata fixture.'
    Assert-MutationRejected `
        -Name 'future current metadata date' `
        -AgentsContent $strFutureMetadataContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strAgentsContent `
        -ExpectedFailure (
            'AGENTS.md Last Updated 2099-12-31 must not be later than trusted UTC date'
        )
    Assert-MutationRejected `
        -Name 'future parent metadata recovery' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strFutureMetadataContent `
        -ExpectedFailure (
            'The parent of AGENTS.md Last Updated 2099-12-31 must not be later than trusted UTC date'
        )

    $strValidLeapDateContent = $strAgentsContent.Replace(
        $objAgentsVersionMatch.Value,
        $strAgentsVersionPrefix + '20240229' + $strAgentsRevisionSuffix
    ).Replace(
        $objAgentsUpdatedMatch.Value,
        '- **Last Updated:** 2024-02-29'
    )
    $strValidLeapDateParent = $strAgentsContent.Replace(
        $objAgentsVersionMatch.Value,
        $strAgentsVersionPrefix + '20000101' + $strAgentsRevisionSuffix
    ).Replace(
        $objAgentsUpdatedMatch.Value,
        '- **Last Updated:** 2000-01-01'
    )
    Assert-FixtureAccepted `
        -Name 'valid leap metadata day' `
        -AgentsContent $strValidLeapDateContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strValidLeapDateParent

    $strInvalidDateParent = $strAgentsContent.Replace(
        $objAgentsVersionMatch.Value,
        $strAgentsVersionPrefix + '99999999' + $strAgentsRevisionSuffix
    ).Replace(
        $objAgentsUpdatedMatch.Value,
        '- **Last Updated:** 9999-99-99'
    )
    Assert-MutationRejected `
        -Name 'impossible parent metadata date' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strInvalidDateParent `
        -ExpectedFailure 'The parent of AGENTS.md Last Updated must contain one real calendar date.'

    $strRenderedAgentsMutation = $strAgentsContent + [Environment]::NewLine +
        'A rendered governance note.' + [Environment]::NewLine
    Assert-MutationRejected `
        -Name 'impossible expected UTC date' `
        -AgentsContent $strRenderedAgentsMutation `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strAgentsContent `
        -AgentsExpectedUtcDate '9999-99-99' `
        -ExpectedFailure 'The expected UTC date for AGENTS.md is unavailable or invalid.'

    Assert-MutationRejected `
        -Name 'same-day rendered change with stale revision' `
        -AgentsContent $strRenderedAgentsMutation `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strAgentsContent `
        -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
        -ExpectedFailure ("AGENTS.md Version revision must be $intNextAgentsRevision after " +
            'a content change with unchanged major, minor, and date')

    $strExactNextRevisionContent = $strRenderedAgentsMutation.Replace(
        $objAgentsVersionMatch.Value,
        $strAgentsVersionStem + $intNextAgentsRevision
    )
    Assert-FixtureAccepted `
        -Name 'same-identity exact next revision' `
        -AgentsContent $strExactNextRevisionContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strAgentsContent `
        -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value

    $strHigherRevisionParent = $strAgentsContent.Replace(
        $objAgentsVersionMatch.Value,
        $strAgentsVersionStem + $intNextAgentsRevision
    )
    Assert-MutationRejected `
        -Name 'same-day rendered change with decreasing revision' `
        -AgentsContent $strRenderedAgentsMutation `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strHigherRevisionParent `
        -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
        -ExpectedFailure ("AGENTS.md Version revision must not decrease from " +
            "$intNextAgentsRevision to $intAgentsRevision.")

    Assert-MutationRejected `
        -Name 'metadata-only same-day revision rollback' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strHigherRevisionParent `
        -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
        -ExpectedFailure ("AGENTS.md Version revision must not decrease from " +
            "$intNextAgentsRevision to $intAgentsRevision.")

    Assert-FixtureAccepted `
        -Name 'normalized-equal metadata identity' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strAgentsContent

    $strMaximumRevisionContent = $strAgentsContent.Replace(
        $objAgentsVersionMatch.Value,
        $strAgentsVersionStem + [int64]::MaxValue
    )
    Assert-FixtureAccepted `
        -Name 'normalized-equal maximum revision' `
        -AgentsContent $strMaximumRevisionContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strMaximumRevisionContent

    $strSameDayRevisionJump = $strRenderedAgentsMutation.Replace(
        $objAgentsVersionMatch.Value,
        $strAgentsVersionStem + $intJumpedAgentsRevision
    )
    Assert-MutationRejected `
        -Name 'same-identity revision gap' `
        -AgentsContent $strSameDayRevisionJump `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strAgentsContent `
        -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
        -ExpectedFailure ("AGENTS.md Version revision must be $intNextAgentsRevision after " +
            'a content change with unchanged major, minor, and date')

    $strMaximumRevisionMutation = $strMaximumRevisionContent +
        [Environment]::NewLine + 'Maximum revision rendered mutation.'
    Assert-MutationRejected `
        -Name 'same-identity maximum revision cannot increment' `
        -AgentsContent $strMaximumRevisionMutation `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strMaximumRevisionContent `
        -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
        -ExpectedFailure 'The parent AGENTS.md Version revision cannot be incremented safely.'

    $intHigherMajor = [int64] $objAgentsVersionMatch.Groups['Major'].Value + 1
    $intHigherMinor = [int64] $objAgentsVersionMatch.Groups['Minor'].Value + 1
    $arrHigherVersionFixtures = @(
        [pscustomobject]@{
            Name = 'major'
            Prefix = "$intHigherMajor.0."
        },
        [pscustomobject]@{
            Name = 'minor'
            Prefix = "$($objAgentsVersionMatch.Groups['Major'].Value).$intHigherMinor."
        }
    )
    foreach ($objHigherVersionFixture in $arrHigherVersionFixtures) {
        $strHigherVersionStem = '**Version:** ' + $objHigherVersionFixture.Prefix +
            $objAgentsVersionMatch.Groups['Date'].Value + '.'
        $strHigherVersionReset = $strRenderedAgentsMutation.Replace(
            $objAgentsVersionMatch.Value,
            $strHigherVersionStem + '0'
        )
        Assert-FixtureAccepted `
            -Name "$($objHigherVersionFixture.Name) change resets revision" `
            -AgentsContent $strHigherVersionReset `
            -ClaudeContent $strClaudeContent `
            -CodexConfigContent $strCodexConfigContent `
            -ParentAgentsContent $strAgentsContent `
            -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value
        Assert-MutationRejected `
            -Name "$($objHigherVersionFixture.Name) change retains nonzero revision" `
            -AgentsContent $strHigherVersionReset.Replace(
                $strHigherVersionStem + '0',
                $strHigherVersionStem + '1'
            ) `
            -ClaudeContent $strClaudeContent `
            -CodexConfigContent $strCodexConfigContent `
            -ParentAgentsContent $strAgentsContent `
            -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
            -ExpectedFailure (
                'AGENTS.md Version revision must be 0 when major, minor, or date changes'
            )
    }

    Assert-MutationRejected `
        -Name 'rendered change with stale UTC date' `
        -AgentsContent $strRenderedAgentsMutation `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strAgentsContent `
        -AgentsExpectedUtcDate '2099-01-01' `
        -ExpectedFailure 'AGENTS.md Last Updated must be 2099-01-01 after a rendered-content change.'

    $strPreviousDateParent = $strAgentsContent.Replace(
        $objAgentsVersionMatch.Value,
        '**Version:** ' + $objAgentsVersionMatch.Groups['Prefix'].Value + '20000101.7'
    ).Replace(
        $objAgentsUpdatedMatch.Value,
        '- **Last Updated:** 2000-01-01'
    )
    Assert-FixtureAccepted `
        -Name 'new-day zero revision' `
        -AgentsContent $strRenderedAgentsMutation `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strPreviousDateParent `
        -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value

    $strNewDayNonzeroRevision = $strRenderedAgentsMutation.Replace(
        $objAgentsVersionMatch.Value,
        $strAgentsVersionStem + '1'
    )
    Assert-MutationRejected `
        -Name 'new-day nonzero revision' `
        -AgentsContent $strNewDayNonzeroRevision `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strPreviousDateParent `
        -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
        -ExpectedFailure (
            'AGENTS.md Version revision must be 0 when major, minor, or date changes'
        )

    $strNewDayReset = $strRenderedAgentsMutation.Replace(
        $objAgentsVersionMatch.Value,
        $strAgentsVersionStem + '0'
    )
    Assert-FixtureAccepted `
        -Name 'new-day revision reset' `
        -AgentsContent $strNewDayReset `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strPreviousDateParent `
        -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value

    $strMetadataForwardParent = $strAgentsContent.Replace(
        $objAgentsVersionMatch.Value,
        '**Version:** ' + $objAgentsVersionMatch.Groups['Prefix'].Value + '20000101.0'
    ).Replace(
        $objAgentsUpdatedMatch.Value,
        '- **Last Updated:** 2000-01-01'
    )
    Assert-FixtureAccepted `
        -Name 'metadata-only forward date with preserved revision' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strMetadataForwardParent

    $strRegressedDateContent = $strRenderedAgentsMutation.Replace(
        $objAgentsVersionMatch.Value,
        '**Version:** ' + $objAgentsVersionMatch.Groups['Prefix'].Value + '20000101.0'
    ).Replace(
        $objAgentsUpdatedMatch.Value,
        '- **Last Updated:** 2000-01-01'
    )
    Assert-MutationRejected `
        -Name 'rendered change with regressing metadata date' `
        -AgentsContent $strRegressedDateContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strAgentsContent `
        -AgentsExpectedUtcDate '2000-01-01' `
        -ExpectedFailure ("AGENTS.md Version date must not move backward from " +
            "$($objAgentsVersionMatch.Groups['Date'].Value) to 20000101.")

    $strMetadataOnlyRegressedDate = $strAgentsContent.Replace(
        $objAgentsVersionMatch.Value,
        '**Version:** ' + $objAgentsVersionMatch.Groups['Prefix'].Value + '20000101.0'
    ).Replace(
        $objAgentsUpdatedMatch.Value,
        '- **Last Updated:** 2000-01-01'
    )
    Assert-MutationRejected `
        -Name 'metadata-only date rollback' `
        -AgentsContent $strMetadataOnlyRegressedDate `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strAgentsContent `
        -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
        -ExpectedFailure ("AGENTS.md Version date must not move backward from " +
            "$($objAgentsVersionMatch.Groups['Date'].Value) to 20000101.")

    $strEarlierStaleMetadataContent = $strAgentsContent +
        [Environment]::NewLine + 'Earlier rendered change with stale metadata.'
    $arrMultiCommitTransitionContexts = @(
        [pscustomobject]@{
            CurrentContent = $strEarlierStaleMetadataContent
            ParentContent = $strAgentsContent
            ExpectedUtcDate = $objAgentsUpdatedMatch.Groups['Date'].Value
            CurrentRevision = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
            ParentRevision = '0000000000000000000000000000000000000000'
        },
        [pscustomobject]@{
            CurrentContent = $strEarlierStaleMetadataContent
            ParentContent = $strEarlierStaleMetadataContent
            ExpectedUtcDate = $objAgentsUpdatedMatch.Groups['Date'].Value
            CurrentRevision = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
            ParentRevision = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        }
    )
    $arrMultiCommitTransitionFailures = @(
        Get-DocumentMetadataRangeTransitionFailure `
            -Name 'AGENTS.md' `
            -TransitionContext $arrMultiCommitTransitionContexts
    )
    if ($arrMultiCommitTransitionFailures.Count -ne 1 -or
        -not $arrMultiCommitTransitionFailures[0].Contains(
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            [System.StringComparison]::Ordinal
        ) -or
        -not $arrMultiCommitTransitionFailures[0].Contains(
            'Version revision must be',
            [System.StringComparison]::Ordinal
        )) {
        throw 'Multi-commit metadata validation did not preserve an earlier invalid transition.'
    }

    $strPolicyBaseFixture = '1111111111111111111111111111111111111111'
    $strPolicyIntroductionFixture = '2222222222222222222222222222222222222222'
    $strPolicyParentFixture = '3333333333333333333333333333333333333333'
    $strExistingPolicyBase = Get-MetadataRangePolicyEffectiveBaseRevision `
        -BaseRevision $strPolicyBaseFixture `
        -BaseHasPolicyMarker $true
    if ($strExistingPolicyBase -cne $strPolicyBaseFixture) {
        throw 'Existing metadata range policy did not retain the event base.'
    }
    $strIntroducedPolicyBase = Get-MetadataRangePolicyEffectiveBaseRevision `
        -BaseRevision $strPolicyBaseFixture `
        -BaseHasPolicyMarker $false `
        -PolicyIntroductionCommit $strPolicyIntroductionFixture `
        -PolicyIntroductionParent $strPolicyParentFixture
    if ($strIntroducedPolicyBase -cne $strPolicyParentFixture) {
        throw 'Introduced metadata range policy did not select the introduction parent.'
    }
    $boolMissingPolicyIntroductionRejected = $false
    try {
        [void](Get-MetadataRangePolicyEffectiveBaseRevision `
                -BaseRevision $strPolicyBaseFixture `
                -BaseHasPolicyMarker $false)
    }
    catch {
        $boolMissingPolicyIntroductionRejected = $_.Exception.Message.Contains(
            'policy introduction',
            [System.StringComparison]::OrdinalIgnoreCase
        )
    }
    if (-not $boolMissingPolicyIntroductionRejected) {
        throw 'Missing metadata policy-introduction context did not fail closed.'
    }

    $strNewRefZeroRevision = '0' * 40
    $strNewRefTestHead = [string] (
        & git -C $strRepositoryRootPath rev-parse --verify HEAD
    )
    if ($LASTEXITCODE -ne 0 -or
        $strNewRefTestHead.Trim() -notmatch '^[0-9a-fA-F]{40}$') {
        throw 'Could not resolve the new-ref metadata self-test head.'
    }
    $strNewRefTestHead = $strNewRefTestHead.Trim()
    $strRevisionAgentsFixture = Read-GitRevisionText `
        -RepositoryRootPath $strRepositoryRootPath `
        -Revision $strNewRefTestHead `
        -RepositoryRelativePath 'AGENTS.md' `
        -MaximumBytes $intAgentsMaximumInputBytes `
        -RequireRegularFile
    if (-not [string]::Equals(
            $strRevisionAgentsFixture,
            (Read-GitRevisionText `
                -RepositoryRootPath $strRepositoryRootPath `
                -Revision $strNewRefTestHead `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes),
            [System.StringComparison]::Ordinal
        )) {
        throw 'Regular revision input validation changed the accepted blob content.'
    }
    $boolMissingRevisionInputRejected = $false
    try {
        [void](Read-GitRevisionText `
                -RepositoryRootPath $strRepositoryRootPath `
                -Revision $strNewRefTestHead `
                -RepositoryRelativePath '.missing-agent-instruction-input' `
                -MaximumBytes 128 `
                -RequireRegularFile)
    }
    catch {
        $boolMissingRevisionInputRejected = $_.Exception.Message.Contains(
            'not one regular 100644 blob',
            [System.StringComparison]::Ordinal
        )
    }
    if (-not $boolMissingRevisionInputRejected) {
        throw 'A missing revision input did not fail the regular-blob check.'
    }
    $objRevisionParentFixture = Get-GovernedDocumentParentContext `
        -RepositoryRootPath $strRepositoryRootPath `
        -RepositoryRelativePath 'AGENTS.md' `
        -MaximumBytes $intAgentsMaximumInputBytes `
        -Revision $strNewRefTestHead
    & git -C $strRepositoryRootPath cat-file -e `
        "$strNewRefTestHead`^1:AGENTS.md" 2>$null
    $boolAgentsParentExists = $LASTEXITCODE -eq 0
    $boolAgentsParentContentExists = -not [string]::IsNullOrEmpty(
        $objRevisionParentFixture.ParentContent
    )
    if ($objRevisionParentFixture.ParentRevision -cne "$strNewRefTestHead`^1" -or
        $boolAgentsParentContentExists -ne $boolAgentsParentExists) {
        throw 'The explicit AGENTS.md parent context does not match Git.'
    }
    $objExistingRevisionParentFixture = Get-GovernedDocumentParentContext `
        -RepositoryRootPath $strRepositoryRootPath `
        -RepositoryRelativePath 'CLAUDE.md' `
        -MaximumBytes $intClaudeMaximumInputBytes `
        -Revision $strNewRefTestHead
    if ($objExistingRevisionParentFixture.ParentRevision -cne "$strNewRefTestHead`^1" -or
        [string]::IsNullOrEmpty($objExistingRevisionParentFixture.ParentContent)) {
        throw 'The explicit existing-document parent context is invalid.'
    }
    $arrNewRefRangeFailures = @(
        if ([string]::Equals(
                $strRevisionAgentsFixture,
                $strAgentsContent,
                [System.StringComparison]::Ordinal
            )) {
            Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strRepositoryRootPath `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strNewRefZeroRevision `
                -HeadRevision $strNewRefTestHead `
                -IsNewRefRange $true `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes $intValidatorMaximumInputBytes `
                -PolicyMarker $strMetadataRangePolicyMarker
        }
        else {
            Get-DocumentMetadataTransitionFailure `
                -Name 'AGENTS.md' `
                -CurrentContent $strAgentsContent `
                -ParentContent $null `
                -ExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
                -IsNewDocumentTransition $true
        }
    )
    if ($arrNewRefRangeFailures.Count -ne 0) {
        throw "Valid new-ref metadata range failed: $($arrNewRefRangeFailures -join '; ')"
    }

    $boolUnflaggedZeroBaseRejected = $false
    try {
        [void](Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strRepositoryRootPath `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strNewRefZeroRevision `
                -HeadRevision $strNewRefTestHead `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes $intValidatorMaximumInputBytes `
                -PolicyMarker $strMetadataRangePolicyMarker)
    }
    catch {
        $boolUnflaggedZeroBaseRejected = $_.Exception.Message.Contains(
            'requires the new-ref flag',
            [System.StringComparison]::Ordinal
        )
    }
    if (-not $boolUnflaggedZeroBaseRejected) {
        throw 'An unflagged all-zero metadata range base did not fail closed.'
    }

    $boolFlaggedNonzeroBaseRejected = $false
    try {
        [void](Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strRepositoryRootPath `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strNewRefTestHead `
                -HeadRevision $strNewRefTestHead `
                -IsNewRefRange $true `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes $intValidatorMaximumInputBytes `
                -PolicyMarker $strMetadataRangePolicyMarker)
    }
    catch {
        $boolFlaggedNonzeroBaseRejected = $_.Exception.Message.Contains(
            'requires an all-zero base revision',
            [System.StringComparison]::Ordinal
        )
    }
    if (-not $boolFlaggedNonzeroBaseRejected) {
        throw 'A flagged nonzero metadata range base did not fail closed.'
    }

    $arrOrdinarySameHeadFailures = @(Get-GovernedDocumentRangeTransitionFailure `
            -Name 'AGENTS.md' `
            -RepositoryRootPath $strRepositoryRootPath `
            -RepositoryRelativePath 'AGENTS.md' `
            -MaximumBytes $intAgentsMaximumInputBytes `
            -BaseRevision $strNewRefTestHead `
            -HeadRevision $strNewRefTestHead `
            -InputRevision $strNewRefTestHead `
            -IsNewRefRange $false `
            -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
            -PolicyMaximumBytes $intValidatorMaximumInputBytes `
            -PolicyMarker $strMetadataRangePolicyMarker)
    if ($arrOrdinarySameHeadFailures.Count -ne 0) {
        throw 'An unchanged ordinary metadata range did not retain its prior behavior.'
    }

    $strMergeFixtureRoot = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine(
            [System.IO.Path]::GetTempPath(),
            'agent-instruction-merge-' + [guid]::NewGuid().ToString('N')
        )
    )
    $strSystemTempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if (-not $strMergeFixtureRoot.StartsWith(
            $strSystemTempRoot,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'The merge-transition fixture path escaped the system temporary directory.'
    }
    $boolHadAuthorDate = Test-Path -LiteralPath Env:GIT_AUTHOR_DATE
    $boolHadCommitterDate = Test-Path -LiteralPath Env:GIT_COMMITTER_DATE
    $strOriginalAuthorDate = if ($boolHadAuthorDate) { $env:GIT_AUTHOR_DATE } else { '' }
    $strOriginalCommitterDate = if ($boolHadCommitterDate) {
        $env:GIT_COMMITTER_DATE
    }
    else {
        ''
    }
    try {
        [void][System.IO.Directory]::CreateDirectory($strMergeFixtureRoot)
        & git -C $strMergeFixtureRoot init --quiet
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not initialize the merge-transition fixture repository.'
        }
        & git -C $strMergeFixtureRoot config core.autocrlf false
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not configure the merge-transition fixture repository.'
        }
        $strMergePolicyPath = [System.IO.Path]::Combine(
            $strMergeFixtureRoot,
            '.github',
            'workflows',
            'Test-AgentInstructions.ps1'
        )
        [void][System.IO.Directory]::CreateDirectory(
            [System.IO.Path]::GetDirectoryName($strMergePolicyPath)
        )
        $objUtf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
        $objMergeCurrentDate = [DateTime]::ParseExact(
            $objAgentsUpdatedMatch.Groups['Date'].Value,
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $strMergeCurrentDate = $objMergeCurrentDate.ToString(
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $strMergeHistoricalDate = $objMergeCurrentDate.AddDays(-1).ToString(
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $strMergeBaseVersion = '**Version:** ' +
            $objAgentsVersionMatch.Groups['Prefix'].Value +
            $strMergeHistoricalDate.Replace('-', '') + '.0'
        $strMergeBaseContent = $strAgentsContent.Replace(
            $objAgentsVersionMatch.Value,
            $strMergeBaseVersion
        ).Replace(
            $objAgentsUpdatedMatch.Value,
            "- **Last Updated:** $strMergeHistoricalDate"
        )
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strMergeBaseContent,
            $objUtf8WithoutBom
        )
        [System.IO.File]::WriteAllText(
            $strMergePolicyPath,
            $strMetadataRangePolicyMarker,
            $objUtf8WithoutBom
        )
        $strMergeCopilotPath = [System.IO.Path]::Combine(
            $strMergeFixtureRoot,
            '.github',
            'copilot-instructions.md'
        )
        $strMergeCopilotBaseContent = "# Copilot fixture`n`nBaseline instructions.`n"
        [System.IO.File]::WriteAllText(
            $strMergeCopilotPath,
            $strMergeCopilotBaseContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- `
            'AGENTS.md' '.github/copilot-instructions.md' `
            '.github/workflows/Test-AgentInstructions.ps1'
        $strMergeBaseTree = [string] (& git -C $strMergeFixtureRoot write-tree)
        if ($LASTEXITCODE -ne 0 -or
            $strMergeBaseTree.Trim() -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
            throw 'Could not create the merge-transition base tree.'
        }
        $strMergeBaseTree = $strMergeBaseTree.Trim()

        $scriptBlockCreateMergeFixtureCommit = {
            param(
                [string] $Tree,
                [string[]] $Parents,
                [string] $Timestamp,
                [string] $Message
            )

            $env:GIT_AUTHOR_DATE = $Timestamp
            $env:GIT_COMMITTER_DATE = $Timestamp
            $arrCommitArguments = @(
                '-C', $strMergeFixtureRoot,
                '-c', 'user.name=Agent Instruction Validator',
                '-c', 'user.email=validator@example.invalid',
                'commit-tree', $Tree
            )
            foreach ($strFixtureParent in $Parents) {
                $arrCommitArguments += @('-p', $strFixtureParent)
            }
            $arrCommitArguments += @('-m', $Message)
            $strFixtureCommit = [string] (& git @arrCommitArguments)
            if ($LASTEXITCODE -ne 0 -or
                $strFixtureCommit.Trim() -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
                throw "Could not create merge-transition fixture commit: $Message"
            }
            return $strFixtureCommit.Trim()
        }

        $strMergeBaseCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeBaseTree `
            -Parents @() `
            -Timestamp ($strMergeHistoricalDate + 'T08:00:00Z') `
            -Message 'merge fixture base'
        $strMergeCopilotChangedContent =
            $strMergeCopilotBaseContent + "Changed instructions.`n"
        [System.IO.File]::WriteAllText(
            $strMergeCopilotPath,
            $strMergeCopilotChangedContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- '.github/copilot-instructions.md'
        $strMergeCopilotChangedTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the metadata-optional Copilot tree.'
        }
        $strMergeCopilotChangedCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeCopilotChangedTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T08:30:00Z') `
            -Message 'metadata-optional Copilot change'
        $hashtableCopilotTransitionArguments = @{
            Name = '.github/copilot-instructions.md'
            RepositoryRootPath = $strMergeFixtureRoot
            RepositoryRelativePath = '.github/copilot-instructions.md'
            MaximumBytes = $intInstructionDocumentMaximumInputBytes
            BaseRevision = $strMergeBaseCommit
            HeadRevision = $strMergeCopilotChangedCommit
            InputRevision = $strMergeCopilotChangedCommit
            IsNewRefRange = $false
            PolicyRepositoryRelativePath = '.github/workflows/Test-AgentInstructions.ps1'
            PolicyMaximumBytes = 1024
            PolicyMarker = $strMetadataRangePolicyMarker
        }
        $arrMetadataOptionalRangeFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                @hashtableCopilotTransitionArguments `
                -RequireMetadataTransition $false
        )
        if ($arrMetadataOptionalRangeFailures.Count -ne 0) {
            throw (
                'A safe metadata-optional Copilot range change failed: ' +
                ($arrMetadataOptionalRangeFailures -join '; ')
            )
        }
        $arrMetadataRequiredRangeFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                @hashtableCopilotTransitionArguments `
                -RequireMetadataTransition $true
        )
        if (-not ($arrMetadataRequiredRangeFailures -match
                'must place Metadata as the first level-two heading')) {
            throw 'The same header-free Copilot range did not fail when metadata was required.'
        }
        $arrMetadataOptionalCommitFailures = @(
            Get-GovernedDocumentCommitTransitionFailure `
                -Name '.github/copilot-instructions.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath '.github/copilot-instructions.md' `
                -MaximumBytes $intInstructionDocumentMaximumInputBytes `
                -CommitRevision $strMergeCopilotChangedCommit `
                -RequireMetadataTransition $false
        )
        if ($arrMetadataOptionalCommitFailures.Count -ne 0) {
            throw 'A safe metadata-optional direct Copilot transition failed.'
        }
        $arrMetadataRequiredCommitFailures = @(
            Get-GovernedDocumentCommitTransitionFailure `
                -Name '.github/copilot-instructions.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath '.github/copilot-instructions.md' `
                -MaximumBytes $intInstructionDocumentMaximumInputBytes `
                -CommitRevision $strMergeCopilotChangedCommit `
                -RequireMetadataTransition $true
        )
        if (-not ($arrMetadataRequiredCommitFailures -match
                'must place Metadata as the first level-two heading')) {
            throw 'The same direct Copilot transition did not fail when metadata was required.'
        }
        $hashtableCopilotNewRefArguments = @{}
        foreach ($strCopilotArgumentName in $hashtableCopilotTransitionArguments.Keys) {
            $hashtableCopilotNewRefArguments[$strCopilotArgumentName] =
                $hashtableCopilotTransitionArguments[$strCopilotArgumentName]
        }
        $hashtableCopilotNewRefArguments.BaseRevision = '0' * 40
        $hashtableCopilotNewRefArguments.IsNewRefRange = $true
        $arrMetadataOptionalNewRefFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                @hashtableCopilotNewRefArguments `
                -RequireMetadataTransition $false
        )
        if ($arrMetadataOptionalNewRefFailures.Count -ne 0) {
            throw 'A safe metadata-optional new-ref Copilot range failed.'
        }
        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not restore the merge-transition fixture base tree.'
        }
        $strMergeTopicVersion = '**Version:** ' +
            $objAgentsVersionMatch.Groups['Prefix'].Value +
            $strMergeHistoricalDate.Replace('-', '') + '.1'
        $strMergeTopicContent = $strMergeBaseContent.Replace(
            $strMergeBaseVersion,
            $strMergeTopicVersion
        ) + [Environment]::NewLine + 'Inherited merge fixture.'
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strMergeTopicContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
        $strMergeTopicTree = ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the inherited merge-transition tree.'
        }
        $strMergeTopicCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeTopicTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T12:00:00Z') `
            -Message 'merge fixture topic'
        $intRangeFixtureMajor = [int64] $objAgentsVersionMatch.Groups['Major'].Value
        $intRangeFixtureMinor = [int64] $objAgentsVersionMatch.Groups['Minor'].Value
        $arrMetadataRangeFixtures = @(
            [pscustomobject]@{
                Name = 'same identity exact next revision'
                Prefix = $objAgentsVersionMatch.Groups['Prefix'].Value
                Date = $strMergeHistoricalDate
                Revision = '1'
                ExpectedFailure = ''
            },
            [pscustomobject]@{
                Name = 'same identity revision gap'
                Prefix = $objAgentsVersionMatch.Groups['Prefix'].Value
                Date = $strMergeHistoricalDate
                Revision = '2'
                ExpectedFailure = 'Version revision must be 1 after a content change'
            },
            [pscustomobject]@{
                Name = 'major change reset revision'
                Prefix = "$($intRangeFixtureMajor + 1).0."
                Date = $strMergeHistoricalDate
                Revision = '0'
                ExpectedFailure = ''
            },
            [pscustomobject]@{
                Name = 'major change nonzero revision'
                Prefix = "$($intRangeFixtureMajor + 1).0."
                Date = $strMergeHistoricalDate
                Revision = '1'
                ExpectedFailure = 'Version revision must be 0 when major, minor, or date changes'
            },
            [pscustomobject]@{
                Name = 'minor change reset revision'
                Prefix = "$intRangeFixtureMajor.$($intRangeFixtureMinor + 1)."
                Date = $strMergeHistoricalDate
                Revision = '0'
                ExpectedFailure = ''
            },
            [pscustomobject]@{
                Name = 'minor change nonzero revision'
                Prefix = "$intRangeFixtureMajor.$($intRangeFixtureMinor + 1)."
                Date = $strMergeHistoricalDate
                Revision = '1'
                ExpectedFailure = 'Version revision must be 0 when major, minor, or date changes'
            },
            [pscustomobject]@{
                Name = 'date change reset revision'
                Prefix = $objAgentsVersionMatch.Groups['Prefix'].Value
                Date = $strMergeCurrentDate
                Revision = '0'
                ExpectedFailure = ''
            },
            [pscustomobject]@{
                Name = 'date change nonzero revision'
                Prefix = $objAgentsVersionMatch.Groups['Prefix'].Value
                Date = $strMergeCurrentDate
                Revision = '1'
                ExpectedFailure = 'Version revision must be 0 when major, minor, or date changes'
            }
        )
        for ($intRangeFixture = 0;
            $intRangeFixture -lt $arrMetadataRangeFixtures.Count;
            $intRangeFixture++) {
            $objMetadataRangeFixture = $arrMetadataRangeFixtures[$intRangeFixture]
            & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
            if ($LASTEXITCODE -ne 0) {
                throw 'Could not reset the metadata range-transition fixture index.'
            }
            $strRangeFixtureVersion = '**Version:** ' +
                $objMetadataRangeFixture.Prefix +
                $objMetadataRangeFixture.Date.Replace('-', '') + '.' +
                $objMetadataRangeFixture.Revision
            $strRangeFixtureContent = $strMergeBaseContent.Replace(
                $strMergeBaseVersion,
                $strRangeFixtureVersion
            ).Replace(
                "- **Last Updated:** $strMergeHistoricalDate",
                "- **Last Updated:** $($objMetadataRangeFixture.Date)"
            ) + [Environment]::NewLine +
                "Range fixture: $($objMetadataRangeFixture.Name)."
            [System.IO.File]::WriteAllText(
                [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
                $strRangeFixtureContent,
                $objUtf8WithoutBom
            )
            & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
            $strRangeFixtureTree =
                ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
            if ($LASTEXITCODE -ne 0) {
                throw "Could not create range fixture tree: $($objMetadataRangeFixture.Name)"
            }
            $strRangeFixtureTimestamp = if (
                $objMetadataRangeFixture.Date -ceq $strMergeCurrentDate
            ) {
                $strMergeCurrentDate + 'T00:01:00Z'
            }
            else {
                $strMergeHistoricalDate +
                    "T13:$($intRangeFixture.ToString('00')):00Z"
            }
            $strRangeFixtureCommit = & $scriptBlockCreateMergeFixtureCommit `
                -Tree $strRangeFixtureTree `
                -Parents @($strMergeBaseCommit) `
                -Timestamp $strRangeFixtureTimestamp `
                -Message $objMetadataRangeFixture.Name
            $arrMetadataRangeFailures = @(
                Get-GovernedDocumentRangeTransitionFailure `
                    -Name 'AGENTS.md' `
                    -RepositoryRootPath $strMergeFixtureRoot `
                    -RepositoryRelativePath 'AGENTS.md' `
                    -MaximumBytes $intAgentsMaximumInputBytes `
                    -BaseRevision $strMergeBaseCommit `
                    -HeadRevision $strRangeFixtureCommit `
                    -InputRevision $strRangeFixtureCommit `
                    -IsNewRefRange $false `
                    -PolicyRepositoryRelativePath `
                        '.github/workflows/Test-AgentInstructions.ps1' `
                    -PolicyMaximumBytes 1024 `
                    -PolicyMarker $strMetadataRangePolicyMarker
            )
            if ([string]::IsNullOrEmpty($objMetadataRangeFixture.ExpectedFailure)) {
                if ($arrMetadataRangeFailures.Count -ne 0) {
                    throw (
                        "Safe $($objMetadataRangeFixture.Name) range failed: " +
                        ($arrMetadataRangeFailures -join '; ')
                    )
                }
            }
            elseif (-not ($arrMetadataRangeFailures -join '; ').Contains(
                    $objMetadataRangeFixture.ExpectedFailure,
                    [System.StringComparison]::Ordinal
                )) {
                throw "Unsafe $($objMetadataRangeFixture.Name) range passed."
            }
        }
        $strMergeUnversionedContent = $strMergeBaseContent.Replace(
            $strMergeBaseVersion,
            ''
        )
        $arrOptionalVersionRangeFixtures = @(
            [pscustomobject]@{
                Name = 'versioned to versioned optional-Version shape'
                ParentHasVersion = $true
                CurrentVersion = 'same-identity-next'
                ExpectedFailure = ''
            },
            [pscustomobject]@{
                Name = 'unversioned to unversioned optional-Version shape'
                ParentHasVersion = $false
                CurrentVersion = 'absent'
                ExpectedFailure = ''
            },
            [pscustomobject]@{
                Name = 'unversioned to versioned optional-Version shape'
                ParentHasVersion = $false
                CurrentVersion = 'initial'
                ExpectedFailure = ''
            },
            [pscustomobject]@{
                Name = 'versioned to unversioned optional-Version shape'
                ParentHasVersion = $true
                CurrentVersion = 'absent'
                ExpectedFailure = ''
            },
            [pscustomobject]@{
                Name = 'duplicate optional Version range mutation'
                ParentHasVersion = $true
                CurrentVersion = 'duplicate'
                ExpectedFailure = 'must contain at most one exact document-level Version'
            },
            [pscustomobject]@{
                Name = 'malformed optional Version range mutation'
                ParentHasVersion = $false
                CurrentVersion = 'malformed'
                ExpectedFailure = 'must contain at most one exact document-level Version'
            }
        )
        for ($intOptionalRangeFixture = 0;
            $intOptionalRangeFixture -lt $arrOptionalVersionRangeFixtures.Count;
            $intOptionalRangeFixture++) {
            $objOptionalRangeFixture =
                $arrOptionalVersionRangeFixtures[$intOptionalRangeFixture]
            & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
            if ($LASTEXITCODE -ne 0) {
                throw 'Could not reset the optional-Version range fixture index.'
            }
            $strOptionalRangeParentContent = if (
                $objOptionalRangeFixture.ParentHasVersion
            ) {
                $strMergeBaseContent
            }
            else {
                $strMergeUnversionedContent
            }
            [System.IO.File]::WriteAllText(
                [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
                $strOptionalRangeParentContent,
                $objUtf8WithoutBom
            )
            & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
            $strOptionalRangeParentTree =
                ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
            if ($LASTEXITCODE -ne 0) {
                throw 'Could not create the optional-Version parent tree.'
            }
            $strOptionalRangeParentCommit = & $scriptBlockCreateMergeFixtureCommit `
                -Tree $strOptionalRangeParentTree `
                -Parents @($strMergeBaseCommit) `
                -Timestamp (
                    $strMergeHistoricalDate +
                    "T14:$($intOptionalRangeFixture.ToString('00')):00Z"
                ) `
                -Message ($objOptionalRangeFixture.Name + ' parent')

            $strOptionalRangeCurrentContent = switch (
                $objOptionalRangeFixture.CurrentVersion
            ) {
                'same-identity-next' {
                    $strMergeBaseContent.Replace(
                        $strMergeBaseVersion,
                        '**Version:** ' +
                            $objAgentsVersionMatch.Groups['Prefix'].Value +
                            $strMergeHistoricalDate.Replace('-', '') + '.1'
                    )
                    break
                }
                'initial' {
                    $strMergeBaseContent
                    break
                }
                'absent' {
                    $strMergeUnversionedContent
                    break
                }
                'duplicate' {
                    $strMergeBaseContent.Replace(
                        $strMergeBaseVersion,
                        "$strMergeBaseVersion`n`n$strMergeBaseVersion"
                    )
                    break
                }
                'malformed' {
                    $strMergeBaseContent.Replace(
                        $strMergeBaseVersion,
                        '**Version:** malformed'
                    )
                    break
                }
                default {
                    throw 'The optional-Version range fixture kind is unsupported.'
                }
            }
            $strOptionalRangeCurrentContent += [Environment]::NewLine +
                "Optional-Version range fixture: $($objOptionalRangeFixture.Name)."
            [System.IO.File]::WriteAllText(
                [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
                $strOptionalRangeCurrentContent,
                $objUtf8WithoutBom
            )
            & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
            $strOptionalRangeCurrentTree =
                ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
            if ($LASTEXITCODE -ne 0) {
                throw 'Could not create the optional-Version current tree.'
            }
            $strOptionalRangeCurrentCommit = & $scriptBlockCreateMergeFixtureCommit `
                -Tree $strOptionalRangeCurrentTree `
                -Parents @($strOptionalRangeParentCommit) `
                -Timestamp (
                    $strMergeHistoricalDate +
                    "T15:$($intOptionalRangeFixture.ToString('00')):00Z"
                ) `
                -Message $objOptionalRangeFixture.Name
            $arrOptionalRangeFailures = @(
                Get-GovernedDocumentRangeTransitionFailure `
                    -Name 'AGENTS.md' `
                    -RepositoryRootPath $strMergeFixtureRoot `
                    -RepositoryRelativePath 'AGENTS.md' `
                    -MaximumBytes $intAgentsMaximumInputBytes `
                    -BaseRevision $strOptionalRangeParentCommit `
                    -HeadRevision $strOptionalRangeCurrentCommit `
                    -InputRevision $strOptionalRangeCurrentCommit `
                    -IsNewRefRange $false `
                    -PolicyRepositoryRelativePath `
                        '.github/workflows/Test-AgentInstructions.ps1' `
                    -PolicyMaximumBytes 1024 `
                    -PolicyMarker $strMetadataRangePolicyMarker
            )
            if ([string]::IsNullOrEmpty($objOptionalRangeFixture.ExpectedFailure)) {
                if ($arrOptionalRangeFailures.Count -ne 0) {
                    throw (
                        "Safe $($objOptionalRangeFixture.Name) range failed: " +
                        ($arrOptionalRangeFailures -join '; ')
                    )
                }
            }
            elseif (-not ($arrOptionalRangeFailures -join '; ').Contains(
                    $objOptionalRangeFixture.ExpectedFailure,
                    [System.StringComparison]::Ordinal
                )) {
                throw "Unsafe $($objOptionalRangeFixture.Name) range passed."
            }
        }
        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not restore the base tree after metadata range-transition fixtures.'
        }
        $strInvalidIntermediateContent = $strMergeBaseContent +
            [Environment]::NewLine + 'Invalid internal topic metadata fixture.'
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strInvalidIntermediateContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
        $strInvalidIntermediateTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the invalid intermediate metadata tree.'
        }
        $strInvalidIntermediateCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strInvalidIntermediateTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T09:00:00Z') `
            -Message 'invalid internal topic metadata'
        $strCorrectedFinalCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeTopicTree `
            -Parents @($strInvalidIntermediateCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T10:00:00Z') `
            -Message 'correct final published metadata'
        $arrCorrectedFinalFailures = @(Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strMergeBaseCommit `
                -HeadRevision $strCorrectedFinalCommit `
                -InputRevision $strCorrectedFinalCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker)
        if ($arrCorrectedFinalFailures.Count -ne 0) {
            throw (
                'Correct final metadata did not supersede an invalid internal state: ' +
                ($arrCorrectedFinalFailures -join '; ')
            )
        }

        $strRangeBlobInputPath = [System.IO.Path]::Combine(
            $strMergeFixtureRoot,
            '.range-blob-input'
        )
        $scriptBlockCreateGovernedBlobTree = {
            param(
                [AllowNull()]
                [byte[]] $ContentBytes,

                [AllowEmptyString()]
                [string] $Mode
            )

            & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
            if ($LASTEXITCODE -ne 0) {
                throw 'Could not reset the unsafe range-blob fixture index.'
            }
            if ($null -eq $ContentBytes) {
                & git -C $strMergeFixtureRoot update-index `
                    --force-remove -- AGENTS.md
            }
            else {
                [System.IO.File]::WriteAllBytes(
                    $strRangeBlobInputPath,
                    $ContentBytes
                )
                $strRangeBlobId = [string] (
                    & git -C $strMergeFixtureRoot hash-object -w -- `
                        $strRangeBlobInputPath
                )
                if ($LASTEXITCODE -ne 0 -or
                    $strRangeBlobId.Trim() -notmatch `
                        '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
                    throw 'Could not create the unsafe range-blob fixture object.'
                }
                & git -C $strMergeFixtureRoot update-index --add `
                    --cacheinfo "$Mode,$($strRangeBlobId.Trim()),AGENTS.md"
            }
            if ($LASTEXITCODE -ne 0) {
                throw 'Could not create the unsafe range-blob fixture entry.'
            }
            $strRangeBlobTree = [string] (
                & git -C $strMergeFixtureRoot write-tree
            )
            if ($LASTEXITCODE -ne 0 -or
                $strRangeBlobTree.Trim() -notmatch `
                    '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
                throw 'Could not create the unsafe range-blob fixture tree.'
            }
            return $strRangeBlobTree.Trim()
        }

        $scriptBlockAssertUnsafeCorrectedRangeRejected = {
            param(
                [string] $Name,
                [string] $InvalidTree,
                [string] $ExpectedFailure,
                [int] $FixtureIndex
            )

            $intInvalidMinute = 10 + ($FixtureIndex * 2)
            $strInvalidRangeCommit = & $scriptBlockCreateMergeFixtureCommit `
                -Tree $InvalidTree `
                -Parents @($strMergeBaseCommit) `
                -Timestamp (
                    $strMergeHistoricalDate +
                    "T09:$($intInvalidMinute.ToString('00')):00Z"
                ) `
                -Message "unsafe intermediate $Name"
            $strCorrectedRangeCommit = & $scriptBlockCreateMergeFixtureCommit `
                -Tree $strMergeTopicTree `
                -Parents @($strInvalidRangeCommit) `
                -Timestamp (
                    $strMergeHistoricalDate +
                    "T09:$((($intInvalidMinute + 1)).ToString('00')):00Z"
                ) `
                -Message "corrected final after $Name"
            foreach ($boolRequireMetadataTransition in @($true, $false)) {
                $boolExpectedFailureObserved = $false
                try {
                    $arrUnsafeRangeFailures = @(
                        Get-GovernedDocumentRangeTransitionFailure `
                            -Name 'AGENTS.md' `
                            -RepositoryRootPath $strMergeFixtureRoot `
                            -RepositoryRelativePath 'AGENTS.md' `
                            -MaximumBytes $intAgentsMaximumInputBytes `
                            -BaseRevision $strMergeBaseCommit `
                            -HeadRevision $strCorrectedRangeCommit `
                            -InputRevision $strCorrectedRangeCommit `
                            -IsNewRefRange $false `
                            -PolicyRepositoryRelativePath `
                                '.github/workflows/Test-AgentInstructions.ps1' `
                            -PolicyMaximumBytes 1024 `
                            -PolicyMarker $strMetadataRangePolicyMarker `
                            -RequireMetadataTransition $boolRequireMetadataTransition
                    )
                    $boolExpectedFailureObserved =
                        ($arrUnsafeRangeFailures -join '; ').Contains(
                            $ExpectedFailure,
                            [System.StringComparison]::Ordinal
                        )
                }
                catch {
                    $boolExpectedFailureObserved = $_.Exception.Message.Contains(
                        $ExpectedFailure,
                        [System.StringComparison]::Ordinal
                    )
                }
                if (-not $boolExpectedFailureObserved) {
                    throw (
                        "A corrected final state concealed an unsafe $Name " +
                        "intermediate governed path when RequireMetadataTransition was " +
                        "$boolRequireMetadataTransition."
                    )
                }
            }
        }

        $arrUnsafeRangeBlobFixtures = @(
            [pscustomobject]@{
                Name = 'missing-path'
                Tree = & $scriptBlockCreateGovernedBlobTree `
                    -ContentBytes $null `
                    -Mode ''
                ExpectedFailure = 'is missing governed path AGENTS.md'
            },
            [pscustomobject]@{
                Name = 'wrong-mode'
                Tree = & $scriptBlockCreateGovernedBlobTree `
                    -ContentBytes $objUtf8WithoutBom.GetBytes($strMergeBaseContent) `
                    -Mode '100755'
                ExpectedFailure = 'does not contain exactly one regular 100644 blob'
            },
            [pscustomobject]@{
                Name = 'symbolic-link'
                Tree = & $scriptBlockCreateGovernedBlobTree `
                    -ContentBytes $objUtf8WithoutBom.GetBytes('outside-target') `
                    -Mode '120000'
                ExpectedFailure = 'does not contain exactly one regular 100644 blob'
            },
            [pscustomobject]@{
                Name = 'oversized-blob'
                Tree = & $scriptBlockCreateGovernedBlobTree `
                    -ContentBytes ([byte[]]::new($intAgentsMaximumInputBytes + 1)) `
                    -Mode '100644'
                ExpectedFailure = "must not exceed $intAgentsMaximumInputBytes bytes"
            },
            [pscustomobject]@{
                Name = 'malformed-UTF-8'
                Tree = & $scriptBlockCreateGovernedBlobTree `
                    -ContentBytes ([byte[]] @(0xC3, 0x28)) `
                    -Mode '100644'
                ExpectedFailure = 'must contain valid UTF-8 without a BOM'
            },
            [pscustomobject]@{
                Name = 'UTF-8-BOM'
                Tree = & $scriptBlockCreateGovernedBlobTree `
                    -ContentBytes ([byte[]] @(0xEF, 0xBB, 0xBF, 0x41)) `
                    -Mode '100644'
                ExpectedFailure = 'must contain valid UTF-8 without a BOM'
            }
        )
        for ($intUnsafeFixture = 0;
            $intUnsafeFixture -lt $arrUnsafeRangeBlobFixtures.Count;
            $intUnsafeFixture++) {
            $objUnsafeRangeBlobFixture = $arrUnsafeRangeBlobFixtures[$intUnsafeFixture]
            & $scriptBlockAssertUnsafeCorrectedRangeRejected `
                -Name $objUnsafeRangeBlobFixture.Name `
                -InvalidTree $objUnsafeRangeBlobFixture.Tree `
                -ExpectedFailure $objUnsafeRangeBlobFixture.ExpectedFailure `
                -FixtureIndex $intUnsafeFixture
        }

        $arrInvalidFinalFailures = @(Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strMergeBaseCommit `
                -HeadRevision $strInvalidIntermediateCommit `
                -InputRevision $strInvalidIntermediateCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker)
        if (-not ($arrInvalidFinalFailures -join '; ').Contains(
                'Version revision must be',
                [System.StringComparison]::Ordinal
            )) {
            throw 'Invalid final metadata was accepted as an internal-only state.'
        }
        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not reset the advanced merge-base fixture index.'
        }
        $strAdvancedBaseContent = $strMergeBaseContent.Replace(
            $strMergeBaseVersion,
            $strMergeTopicVersion
        ) + [Environment]::NewLine + 'Advanced first-parent merge fixture.'
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strAdvancedBaseContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
        $strAdvancedBaseTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the advanced merge-base fixture tree.'
        }
        $strAdvancedBaseCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strAdvancedBaseTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T13:00:00Z') `
            -Message 'merge fixture advanced base'
        $strInheritedMergeCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeTopicTree `
            -Parents @($strAdvancedBaseCommit, $strMergeTopicCommit) `
            -Timestamp ($strMergeCurrentDate + 'T00:01:00Z') `
            -Message 'merge fixture inherited result'
        $arrInheritedMergeFailures = @(Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strAdvancedBaseCommit `
                -HeadRevision $strInheritedMergeCommit `
                -InputRevision $strInheritedMergeCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker)
        if ($arrInheritedMergeFailures.Count -ne 0) {
            throw (
                'A merge that inherited governed content from its non-first parent failed: ' +
                ($arrInheritedMergeFailures -join '; ')
            )
        }
        $arrDirectInheritedFailures = @(Get-GovernedDocumentCommitTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -CommitRevision $strInheritedMergeCommit)
        if ($arrDirectInheritedFailures.Count -ne 0) {
            throw (
                'Direct validation rejected content inherited from a non-first parent: ' +
                ($arrDirectInheritedFailures -join '; ')
            )
        }

        & git -C $strMergeFixtureRoot read-tree $strAdvancedBaseTree
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not reset the unique same-revision merge fixture index.'
        }
        $strUniqueSameRevisionContent = $strAdvancedBaseContent +
            [Environment]::NewLine + 'Merge-authored same-revision fixture.'
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strUniqueSameRevisionContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
        $strUniqueSameRevisionTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the unique same-revision merge fixture tree.'
        }
        $strUniqueSameRevisionCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strUniqueSameRevisionTree `
            -Parents @($strAdvancedBaseCommit, $strMergeTopicCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T14:00:00Z') `
            -Message 'merge fixture unique same revision'
        $arrUniqueSameRevisionFailures = @(Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strAdvancedBaseCommit `
                -HeadRevision $strUniqueSameRevisionCommit `
                -InputRevision $strUniqueSameRevisionCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker)
        if (-not ($arrUniqueSameRevisionFailures -join '; ').Contains(
                'Version revision must be 2 after a content change',
                [System.StringComparison]::Ordinal
            )) {
            throw 'A merge-authored same-revision result received the inheritance exemption.'
        }
        $arrDirectUniqueSameRevisionFailures = @(
            Get-GovernedDocumentCommitTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -CommitRevision $strUniqueSameRevisionCommit
        )
        if (-not ($arrDirectUniqueSameRevisionFailures -join '; ').Contains(
                'Version revision must be 2 after a content change',
                [System.StringComparison]::Ordinal
            )) {
            throw 'Direct validation exempted a merge-authored same-revision result.'
        }

        $strFutureTopicCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeTopicTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp '2099-12-31T12:00:00Z' `
            -Message 'merge fixture future topic'
        $arrFutureTopicFailures = @(Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strMergeBaseCommit `
                -HeadRevision $strFutureTopicCommit `
                -InputRevision $strFutureTopicCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker)
        if (-not ($arrFutureTopicFailures -join '; ').Contains(
                "Metadata range commit $strFutureTopicCommit timestamp",
                [System.StringComparison]::Ordinal
            )) {
            throw 'An ordinary future commit timestamp did not fail closed.'
        }
        $strFutureInheritedMergeCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeTopicTree `
            -Parents @($strAdvancedBaseCommit, $strFutureTopicCommit) `
            -Timestamp ($strMergeCurrentDate + 'T00:02:00Z') `
            -Message 'merge fixture future inherited result'
        $arrFutureInheritedFailures = @(Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strAdvancedBaseCommit `
                -HeadRevision $strFutureInheritedMergeCommit `
                -InputRevision $strFutureInheritedMergeCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker)
        if (-not ($arrFutureInheritedFailures -join '; ').Contains(
                "Metadata range commit $strFutureTopicCommit timestamp",
                [System.StringComparison]::Ordinal
            )) {
            throw 'A future inherited-source timestamp did not fail closed.'
        }

        $strUniqueMergeContent = $strMergeTopicContent +
            [Environment]::NewLine + 'Merge-authored content with stale metadata.'
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strUniqueMergeContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
        $strUniqueMergeTree = ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the unique merge-transition tree.'
        }
        $strUniqueMergeCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strUniqueMergeTree `
            -Parents @($strAdvancedBaseCommit, $strMergeTopicCommit) `
            -Timestamp ($strMergeCurrentDate + 'T00:02:00Z') `
            -Message 'merge fixture unique result'
        $arrUniqueMergeFailures = @(Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strAdvancedBaseCommit `
                -HeadRevision $strUniqueMergeCommit `
                -InputRevision $strUniqueMergeCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker)
        if ($arrUniqueMergeFailures.Count -eq 0 -or
            -not ($arrUniqueMergeFailures -join '; ').Contains(
                "Last Updated must be $strMergeCurrentDate",
                [System.StringComparison]::Ordinal
            )) {
            throw 'Merge-authored governed content with stale metadata did not fail closed.'
        }
        $arrDirectUniqueFailures = @(Get-GovernedDocumentCommitTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -CommitRevision $strUniqueMergeCommit)
        if ($arrDirectUniqueFailures.Count -eq 0 -or
            -not ($arrDirectUniqueFailures -join '; ').Contains(
                "Last Updated must be $strMergeCurrentDate",
                [System.StringComparison]::Ordinal
            )) {
            throw 'Direct validation accepted merge-authored stale metadata.'
        }

        $strNewerParentContent = $strAgentsContent +
            [Environment]::NewLine + 'Newer first-parent merge fixture.'
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strNewerParentContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
        $strNewerParentTree = ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the newer merge-parent tree.'
        }
        $strNewerParentCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strNewerParentTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeCurrentDate + 'T00:03:00Z') `
            -Message 'merge fixture newer parent'
        $strRegressingMergeCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeTopicTree `
            -Parents @($strNewerParentCommit, $strMergeTopicCommit) `
            -Timestamp ($strMergeCurrentDate + 'T00:04:00Z') `
            -Message 'merge fixture regressing inherited result'
        $arrRegressingMergeFailures = @(Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strNewerParentCommit `
                -HeadRevision $strRegressingMergeCommit `
                -InputRevision $strRegressingMergeCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker)
        if ($arrRegressingMergeFailures.Count -eq 0 -or
            -not ($arrRegressingMergeFailures -join '; ').Contains(
                'Version date must not move backward',
                [System.StringComparison]::Ordinal
            )) {
            throw 'An inherited merge metadata rollback did not fail closed.'
        }
        $arrDirectRegressingFailures = @(Get-GovernedDocumentCommitTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -CommitRevision $strRegressingMergeCommit)
        if ($arrDirectRegressingFailures.Count -eq 0 -or
            -not ($arrDirectRegressingFailures -join '; ').Contains(
                'Version date must not move backward',
                [System.StringComparison]::Ordinal
            )) {
            throw 'Direct validation accepted an inherited metadata rollback.'
        }

        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not reset the inherited revision-rollback fixture index.'
        }
        $strHigherRevisionParentVersion = '**Version:** ' +
            $objAgentsVersionMatch.Groups['Prefix'].Value +
            $strMergeHistoricalDate.Replace('-', '') + '.2'
        $strHigherRevisionParentContent = $strAdvancedBaseContent.Replace(
            $strMergeTopicVersion,
            $strHigherRevisionParentVersion
        )
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strHigherRevisionParentContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
        $strHigherRevisionParentTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the inherited revision-rollback parent tree.'
        }
        $strHigherRevisionParentCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strHigherRevisionParentTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T15:00:00Z') `
            -Message 'merge fixture higher revision parent'
        $strRevisionRegressingMergeCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeTopicTree `
            -Parents @($strHigherRevisionParentCommit, $strMergeTopicCommit) `
            -Timestamp ($strMergeCurrentDate + 'T00:05:00Z') `
            -Message 'merge fixture inherited revision rollback'
        $arrRevisionRegressingMergeFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strHigherRevisionParentCommit `
                -HeadRevision $strRevisionRegressingMergeCommit `
                -InputRevision $strRevisionRegressingMergeCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker
        )
        if (-not ($arrRevisionRegressingMergeFailures -join '; ').Contains(
                'Version revision must not decrease from 2 to 1',
                [System.StringComparison]::Ordinal
            )) {
            throw 'An inherited same-identity revision rollback did not fail closed.'
        }
        $arrDirectRevisionRegressingFailures = @(
            Get-GovernedDocumentCommitTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -CommitRevision $strRevisionRegressingMergeCommit
        )
        if (-not ($arrDirectRevisionRegressingFailures -join '; ').Contains(
                'Version revision must not decrease from 2 to 1',
                [System.StringComparison]::Ordinal
            )) {
            throw 'Direct validation accepted an inherited revision rollback.'
        }

        $listExcessParents = [System.Collections.Generic.List[string]]::new()
        foreach ($intFixtureParent in 1..($intMetadataMaximumParents + 1)) {
            $listExcessParents.Add((& $scriptBlockCreateMergeFixtureCommit `
                        -Tree $strMergeBaseTree `
                        -Parents @($strMergeBaseCommit) `
                        -Timestamp ($strMergeHistoricalDate + 'T12:00:00Z') `
                        -Message "merge fixture excess parent $intFixtureParent"))
        }
        $strExcessParentMerge = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeBaseTree `
            -Parents $listExcessParents.ToArray() `
            -Timestamp ($strMergeCurrentDate + 'T12:00:00Z') `
            -Message 'merge fixture excessive parent count'
        $boolExcessParentCountRejected = $false
        try {
            [void](Get-GovernedDocumentRangeTransitionFailure `
                    -Name 'AGENTS.md' `
                    -RepositoryRootPath $strMergeFixtureRoot `
                    -RepositoryRelativePath 'AGENTS.md' `
                    -MaximumBytes $intAgentsMaximumInputBytes `
                    -BaseRevision $strMergeBaseCommit `
                    -HeadRevision $strExcessParentMerge `
                    -InputRevision $strExcessParentMerge `
                    -IsNewRefRange $false `
                    -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                    -PolicyMaximumBytes 1024 `
                    -PolicyMarker $strMetadataRangePolicyMarker)
        }
        catch {
            $boolExcessParentCountRejected = $_.Exception.Message.Contains(
                "maximum is $intMetadataMaximumParents",
                [System.StringComparison]::Ordinal
            )
        }
        if (-not $boolExcessParentCountRejected) {
            throw 'An excessive metadata merge-parent count did not fail closed.'
        }

        $strSecondTopicCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeTopicTree `
            -Parents @($strMergeTopicCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T13:00:00Z') `
            -Message 'second internal topic iteration'
        & git -C $strMergeFixtureRoot update-ref `
            refs/remotes/origin/main $strMergeBaseCommit
        & git -C $strMergeFixtureRoot symbolic-ref `
            refs/remotes/origin/HEAD refs/remotes/origin/main
        & git -C $strMergeFixtureRoot update-ref refs/heads/topic $strSecondTopicCommit
        & git -C $strMergeFixtureRoot symbolic-ref HEAD refs/heads/topic
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not configure the local published-baseline fixture refs.'
        }
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strMergeTopicContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot read-tree $strSecondTopicCommit
        & git -C $strMergeFixtureRoot diff --quiet HEAD -- 'AGENTS.md'
        if ($LASTEXITCODE -ne 0) {
            throw 'The clean published-baseline fixture is not clean.'
        }
        $strResolvedPublishedBaseline = Get-LocalPublishedBaselineRevision `
            -RepositoryRootPath $strMergeFixtureRoot
        $objCleanPublishedContext = Get-GovernedDocumentParentContext `
            -RepositoryRootPath $strMergeFixtureRoot `
            -RepositoryRelativePath 'AGENTS.md' `
            -MaximumBytes $intAgentsMaximumInputBytes `
            -PublishedBaselineRevision $strResolvedPublishedBaseline
        if ($strResolvedPublishedBaseline -cne $strMergeBaseCommit -or
            $objCleanPublishedContext.ParentRevision -cne $strMergeBaseCommit -or
            $objCleanPublishedContext.ParentContent -cne $strMergeBaseContent -or
            $objCleanPublishedContext.ExpectedUtcDate -cne '' -or
            $objCleanPublishedContext.IsWorktreeTransition -or
            -not $objCleanPublishedContext.UsesPublishedBaseline) {
            throw (
                'A clean multi-commit topic did not use the remote published baseline ' +
                'without creating a direct worktree transition.'
            )
        }
        $arrCleanPublishedRangeFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strResolvedPublishedBaseline `
                -HeadRevision $strSecondTopicCommit `
                -InputRevision $strSecondTopicCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath `
                    '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker
        )
        if ($arrCleanPublishedRangeFailures.Count -ne 0) {
            throw (
                'A clean published range with an unrelated later commit failed: ' +
                ($arrCleanPublishedRangeFailures -join '; ')
            )
        }

        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strMergeTopicContent + [Environment]::NewLine + 'Dirty final state.',
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot diff --quiet HEAD -- 'AGENTS.md'
        if ($LASTEXITCODE -ne 1) {
            throw 'The dirty published-baseline fixture did not become dirty.'
        }
        $objDirtyPublishedContext = Get-GovernedDocumentParentContext `
            -RepositoryRootPath $strMergeFixtureRoot `
            -RepositoryRelativePath 'AGENTS.md' `
            -MaximumBytes $intAgentsMaximumInputBytes `
            -PublishedBaselineRevision $strResolvedPublishedBaseline
        if ($objDirtyPublishedContext.ParentRevision -cne $strMergeBaseCommit -or
            $objDirtyPublishedContext.ParentContent -cne $strMergeBaseContent -or
            $objDirtyPublishedContext.ExpectedUtcDate -cne
                $script:strMaximumMetadataUtcDate -or
            -not $objDirtyPublishedContext.IsWorktreeTransition) {
            throw (
                'A dirty multi-commit topic did not use HEAD and the current UTC date.'
            )
        }
        $arrDirtyPublishedFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name 'AGENTS.md' `
                -CurrentContent (
                    $strMergeTopicContent + [Environment]::NewLine +
                    'Dirty final state.'
                ) `
                -ParentContent $objDirtyPublishedContext.ParentContent `
                -ExpectedUtcDate $objDirtyPublishedContext.ExpectedUtcDate `
                -IsNewDocumentTransition $false)
        if ($arrDirtyPublishedFailures.Count -eq 0 -or
            -not ($arrDirtyPublishedFailures -join '; ').Contains(
                "Last Updated must be $script:strMaximumMetadataUtcDate",
                [System.StringComparison]::Ordinal
            )) {
            throw 'Dirty published-baseline metadata did not require the current UTC date.'
        }

        & git -C $strMergeFixtureRoot symbolic-ref --delete refs/remotes/origin/HEAD
        $boolMissingPublishedBaselineRejected = $false
        try {
            [void](Get-LocalPublishedBaselineRevision `
                    -RepositoryRootPath $strMergeFixtureRoot)
        }
        catch {
            $boolMissingPublishedBaselineRejected = $_.Exception.Message.Contains(
                'published baseline is unavailable',
                [System.StringComparison]::Ordinal
            )
        }
        if (-not $boolMissingPublishedBaselineRejected) {
            throw 'A missing remote-default published baseline was accepted.'
        }
        & git -C $strMergeFixtureRoot symbolic-ref `
            refs/remotes/origin/HEAD refs/heads/topic
        $boolMisScopedPublishedBaselineRejected = $false
        try {
            [void](Get-LocalPublishedBaselineRevision `
                    -RepositoryRootPath $strMergeFixtureRoot)
        }
        catch {
            $boolMisScopedPublishedBaselineRejected = $_.Exception.Message.Contains(
                'published baseline is unavailable',
                [System.StringComparison]::Ordinal
            )
        }
        if (-not $boolMisScopedPublishedBaselineRejected) {
            throw 'A mis-scoped remote-default published baseline was accepted.'
        }
    }
    finally {
        if ($boolHadAuthorDate) {
            $env:GIT_AUTHOR_DATE = $strOriginalAuthorDate
        }
        else {
            Remove-Item -LiteralPath Env:GIT_AUTHOR_DATE -ErrorAction SilentlyContinue
        }
        if ($boolHadCommitterDate) {
            $env:GIT_COMMITTER_DATE = $strOriginalCommitterDate
        }
        else {
            Remove-Item -LiteralPath Env:GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
        }
        if ([System.IO.Directory]::Exists($strMergeFixtureRoot) -and
            $strMergeFixtureRoot.StartsWith(
                $strSystemTempRoot,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
            Remove-Item -LiteralPath $strMergeFixtureRoot -Recurse -Force
        }
    }

    $strRevisionMismatchFixture = [string] (
        & git -C $strRepositoryRootPath rev-parse --verify HEAD^1
    )
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not resolve the revision-mismatch self-test fixture.'
    }
    $boolRevisionMismatchRejected = $false
    try {
        [void](Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strRepositoryRootPath `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strNewRefTestHead `
                -HeadRevision $strNewRefTestHead `
                -InputRevision $strRevisionMismatchFixture.Trim() `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes $intValidatorMaximumInputBytes `
                -PolicyMarker $strMetadataRangePolicyMarker)
    }
    catch {
        $boolRevisionMismatchRejected = $_.Exception.Message.Contains(
            'does not match the validation revision',
            [System.StringComparison]::Ordinal
        )
    }
    if (-not $boolRevisionMismatchRejected) {
        throw 'A mismatched explicit validation revision did not fail closed.'
    }

    $strAgentWorkflowContent = [System.IO.File]::ReadAllText(
        [System.IO.Path]::Combine($PSScriptRoot, 'agent-instructions.yml')
    )
    if ($strAgentWorkflowContent -notmatch
        "(?s)AGENT_INSTRUCTION_INPUT_REVISION:.+github.event_name == 'push' && github.sha") {
        throw 'The push workflow does not read governed input from the event commit.'
    }
    $objProposedHeadFetch = [regex]::Match(
        $strAgentWorkflowContent,
        '(?ms)^\s+git fetch (?<Command>.+?)^\s+unset authorization$'
    )
    if (-not $objProposedHeadFetch.Success) {
        throw 'Could not parse the proposed-head fetch command.'
    }
    if ($objProposedHeadFetch.Groups['Command'].Value -notmatch
        '"refs/pull/\$\{PR_NUMBER\}/head:refs/remotes/pull/\$\{PR_NUMBER\}/head"') {
        throw 'The proposed-head fetch does not use the required local destination.'
    }
    if ($objProposedHeadFetch.Groups['Command'].Value -match
            '"\+refs/pull/' -or
        $objProposedHeadFetch.Groups['Command'].Value -match
            '(?m)(^|\s)--force(\s|$)') {
        throw 'The proposed-head fetch force-updates its local destination.'
    }
    $arrPushRangeFetchFailures = @(Get-PushRangeBaseFetchContractFailure `
            -WorkflowContent $strAgentWorkflowContent)
    if ($arrPushRangeFetchFailures.Count -gt 0) {
        throw (
            'The push range-base acquisition contract failed: ' +
            ($arrPushRangeFetchFailures -join '; ')
        )
    }
    $arrPushRangeFetchMutations = @(
        [pscustomobject]@{
            Name = 'wrong event type'
            From = "github.event_name == 'push' &&"
            To = "github.event_name == 'workflow_dispatch' &&"
        },
        [pscustomobject]@{
            Name = 'non-default push uses its prior topic commit'
            From = 'github.ref_name == github.event.repository.default_branch &&'
            To = 'github.ref_name != github.event.repository.default_branch &&'
        },
        [pscustomobject]@{
            Name = 'created-ref guard inverted'
            From = '!github.event.created &&'
            To = 'github.event.created &&'
        },
        [pscustomobject]@{
            Name = 'deleted-ref guard inverted'
            From = '!github.event.deleted'
            To = 'github.event.deleted'
        },
        [pscustomobject]@{
            Name = 'event head substituted for event base'
            From = 'RANGE_BASE_SHA: ${{ github.event.before }}'
            To = 'RANGE_BASE_SHA: ${{ github.event.after }}'
        },
        [pscustomobject]@{
            Name = 'SHA shape check widened'
            From = '[[ "${RANGE_BASE_SHA}" =~ ^[0-9a-f]{40}$ ]]'
            To = '[[ "${RANGE_BASE_SHA}" =~ ^[0-9a-f]+$ ]]'
        },
        [pscustomobject]@{
            Name = 'new-ref sentinel accepted'
            From = 'test "${RANGE_BASE_SHA}" != "0000000000000000000000000000000000000000"'
            To = 'test -n "${RANGE_BASE_SHA}"'
        },
        [pscustomobject]@{
            Name = 'event base replaced by a moving ref'
            From = 'git fetch --no-tags --no-recurse-submodules origin "${RANGE_BASE_SHA}"'
            To = 'git fetch --no-tags --no-recurse-submodules origin main'
        },
        [pscustomobject]@{
            Name = 'force enabled for range-base fetch'
            From = 'git fetch --no-tags --no-recurse-submodules origin "${RANGE_BASE_SHA}"'
            To = 'git fetch --force --no-tags --no-recurse-submodules origin "${RANGE_BASE_SHA}"'
        },
        [pscustomobject]@{
            Name = 'resolved commit identity not compared'
            From = 'test "${fetched_base}" = "${RANGE_BASE_SHA}"'
            To = 'test -n "${fetched_base}"'
        },
        [pscustomobject]@{
            Name = 'index cleanliness check removed'
            From = 'git diff --cached --quiet --no-ext-diff'
            To = 'git status --short'
        }
    )
    foreach ($objPushRangeFetchMutation in $arrPushRangeFetchMutations) {
        if (-not $strAgentWorkflowContent.Contains(
                $objPushRangeFetchMutation.From,
                [System.StringComparison]::Ordinal
            )) {
            throw (
                "The push range-base mutation fixture is unavailable: " +
                $objPushRangeFetchMutation.Name
            )
        }
        $strMutatedAgentWorkflowContent = $strAgentWorkflowContent.Replace(
            $objPushRangeFetchMutation.From,
            $objPushRangeFetchMutation.To
        )
        $arrMutatedPushRangeFetchFailures = @(
            Get-PushRangeBaseFetchContractFailure `
                -WorkflowContent $strMutatedAgentWorkflowContent
        )
        if ($arrMutatedPushRangeFetchFailures.Count -eq 0) {
            throw (
                "The push range-base mutation was accepted: " +
                $objPushRangeFetchMutation.Name
            )
        }
    }
    $scriptBlockGetDefaultBaselineFailures = {
        param([string] $WorkflowContent)

        $arrDefaultStepMatches = @([regex]::Matches(
            $WorkflowContent,
            '(?ms)^      - name: Fetch default-branch published baseline as data\r?\n' +
                '(?<Body>.*?)(?=^      - name: |\z)'
        ))
        if ($arrDefaultStepMatches.Count -ne 1) {
            Write-Output 'The default-branch baseline acquisition step must occur exactly once.'
            return
        }
        $strDefaultStepBody = $arrDefaultStepMatches[0].Groups['Body'].Value
        $strNormalizedWorkflow = $WorkflowContent -replace '\r\n?', "`n"
        $strExpectedCondition = @(
            '        id: fetch_default_baseline',
            '        if: >-',
            "          github.event_name == 'workflow_dispatch' ||",
            "          (github.event_name == 'push' &&",
            '          github.ref_name != github.event.repository.default_branch)',
            '        shell: bash'
        ) -join "`n"
        if (-not $strNormalizedWorkflow.Contains(
                $strExpectedCondition,
                [System.StringComparison]::Ordinal
            )) {
            Write-Output 'The default-branch baseline acquisition condition is not exact.'
        }
        foreach ($strRequiredLiteral in @(
                '          GITHUB_TOKEN: ${{ github.token }}',
                '          DEFAULT_BRANCH: ${{ github.event.repository.default_branch }}',
                '          set -euo pipefail',
                '          default_ref="refs/heads/${DEFAULT_BRANCH}"',
                '          remote_ref="refs/remotes/origin/${DEFAULT_BRANCH}"',
                '          git check-ref-format "${default_ref}"',
                '          git check-ref-format "${remote_ref}"',
                '          authorization="$(printf ''x-access-token:%s'' "${GITHUB_TOKEN}" | base64 -w 0)"',
                '          GIT_CONFIG_COUNT=1 \',
                '            GIT_CONFIG_KEY_0="http.${GITHUB_SERVER_URL}/.extraheader" \',
                '            GIT_CONFIG_VALUE_0="Authorization: Basic ${authorization}" \',
                '            git fetch --no-tags --no-recurse-submodules origin \',
                '              "${default_ref}:${remote_ref}"',
                '          unset authorization',
                '          fetched_baseline="$(git rev-parse --verify "${remote_ref}^{commit}")"',
                '          [[ "${fetched_baseline}" =~ ^[0-9a-f]{40}$ ]]',
                '          printf ''revision=%s\n'' "${fetched_baseline}" >> "${GITHUB_OUTPUT}"',
                '          git diff --quiet --no-ext-diff',
                '          git diff --cached --quiet --no-ext-diff'
            )) {
            if (-not $strDefaultStepBody.Contains(
                    $strRequiredLiteral,
                    [System.StringComparison]::Ordinal
                )) {
                Write-Output "The default-branch baseline acquisition is missing: $strRequiredLiteral"
            }
        }
        if ([regex]::Matches(
                $strDefaultStepBody,
                '(?m)^\s+git fetch '
            ).Count -ne 1 -or
            $strDefaultStepBody -match '(?m)(^|\s)--force(\s|$)' -or
            $strDefaultStepBody -match '"\+\$\{default_ref\}') {
            Write-Output 'The default-branch baseline fetch must be exact and non-force.'
        }
        if ([regex]::Matches(
                $WorkflowContent,
                "github.event_name == 'workflow_dispatch' && github.sha"
            ).Count -ne 2) {
            Write-Output 'Manual runs must use github.sha for input and range head.'
        }
        if ([regex]::Matches(
                $WorkflowContent,
                'steps\.fetch_default_baseline\.outputs\.revision'
            ).Count -ne 1) {
            Write-Output (
                'Manual and non-default push runs must use the verified default-branch ' +
                'baseline output once.'
            )
        }
        $strExpectedRangeBase = @(
            '          AGENT_INSTRUCTION_RANGE_BASE: >-',
            "            `${{ github.event_name == 'pull_request_target' &&",
            '              github.event.pull_request.base.sha ||',
            "              github.event_name == 'push' &&",
            '              github.ref_name == github.event.repository.default_branch &&',
            '              github.event.before ||',
            "              (github.event_name == 'push' &&",
            '              github.ref_name != github.event.repository.default_branch ||',
            "              github.event_name == 'workflow_dispatch') &&",
            "              steps.fetch_default_baseline.outputs.revision || '' }}"
        ) -join "`n"
        if (-not $strNormalizedWorkflow.Contains(
                $strExpectedRangeBase,
                [System.StringComparison]::Ordinal
            )) {
            Write-Output 'The event-specific published-baseline selection is not exact.'
        }
        $strExpectedNewRef = @(
            '          AGENT_INSTRUCTION_RANGE_IS_NEW_REF: >-',
            "            `${{ github.event_name == 'push' &&",
            '              github.ref_name == github.event.repository.default_branch &&',
            '              github.event.created || false }}'
        ) -join "`n"
        if (-not $strNormalizedWorkflow.Contains(
                $strExpectedNewRef,
                [System.StringComparison]::Ordinal
            )) {
            Write-Output 'Only a new default branch may use new-ref range semantics.'
        }
    }
    $arrDefaultBaselineFailures = @(& $scriptBlockGetDefaultBaselineFailures `
            -WorkflowContent $strAgentWorkflowContent)
    if ($arrDefaultBaselineFailures.Count -gt 0) {
        throw (
            'The default-branch baseline acquisition contract failed: ' +
            ($arrDefaultBaselineFailures -join '; ')
        )
    }
    $arrDefaultBaselineMutations = @(
        [pscustomobject]@{
            Name = 'step removed'
            From = 'Fetch default-branch published baseline as data'
            To = 'Removed default-branch baseline acquisition'
        },
        [pscustomobject]@{
            Name = 'default branch replaced'
            From = 'DEFAULT_BRANCH: ${{ github.event.repository.default_branch }}'
            To = 'DEFAULT_BRANCH: main'
        },
        [pscustomobject]@{
            Name = 'non-default push omitted'
            From = 'github.ref_name != github.event.repository.default_branch)'
            To = 'github.ref_name == github.event.repository.default_branch)'
        },
        [pscustomobject]@{
            Name = 'ref validation removed'
            From = 'git check-ref-format "${default_ref}"'
            To = 'test -n "${default_ref}"'
        },
        [pscustomobject]@{
            Name = 'force enabled'
            From = 'git fetch --no-tags --no-recurse-submodules origin \'
            To = 'git fetch --force --no-tags --no-recurse-submodules origin \'
        },
        [pscustomobject]@{
            Name = 'resolved SHA not checked'
            From = '[[ "${fetched_baseline}" =~ ^[0-9a-f]{40}$ ]]'
            To = 'test -n "${fetched_baseline}"'
        },
        [pscustomobject]@{
            Name = 'input revision omitted'
            From = "github.event_name == 'workflow_dispatch' && github.sha"
            To = "github.event_name == 'workflow_dispatch' && ''"
        },
        [pscustomobject]@{
            Name = 'baseline output replaced by topic predecessor'
            From = 'steps.fetch_default_baseline.outputs.revision'
            To = 'github.event.before'
        },
        [pscustomobject]@{
            Name = 'topic push baseline condition inverted'
            From = 'github.ref_name != github.event.repository.default_branch ||'
            To = 'github.ref_name == github.event.repository.default_branch ||'
        },
        [pscustomobject]@{
            Name = 'topic branch allowed new-ref semantics'
            From = 'github.ref_name == github.event.repository.default_branch &&'
            To = 'github.ref_name != github.event.repository.default_branch &&'
        }
    )
    foreach ($objDefaultBaselineMutation in $arrDefaultBaselineMutations) {
        if (-not $strAgentWorkflowContent.Contains(
                $objDefaultBaselineMutation.From,
                [System.StringComparison]::Ordinal
            )) {
            throw (
                'The default-branch baseline mutation fixture is unavailable: ' +
                $objDefaultBaselineMutation.Name
            )
        }
        $strMutatedAgentWorkflowContent = $strAgentWorkflowContent.Replace(
            $objDefaultBaselineMutation.From,
            $objDefaultBaselineMutation.To
        )
        $arrMutatedDefaultBaselineFailures = @(
            & $scriptBlockGetDefaultBaselineFailures `
                -WorkflowContent $strMutatedAgentWorkflowContent
        )
        if ($arrMutatedDefaultBaselineFailures.Count -eq 0) {
            throw (
                'The default-branch baseline mutation was accepted: ' +
                $objDefaultBaselineMutation.Name
            )
        }
    }
    $scriptBlockGetTriggerPathFailures = {
        param(
            [string] $WorkflowContent,
            [string] $Trigger,
            [string[]] $RequiredPath
        )

        $objTriggerMatch = [regex]::Match(
            $WorkflowContent,
            "(?ms)^  $Trigger`:\r?\n(?<Body>.*?)(?=^(?:\S| {2}\S)|\z)"
        )
        if (-not $objTriggerMatch.Success) {
            Write-Output "Could not parse the $Trigger agent-validation trigger."
            return
        }
        $objPathFilterMatch = [regex]::Match(
            $objTriggerMatch.Groups['Body'].Value,
            '(?ms)^    paths:\r?\n(?<Paths>(?:      - [^\r\n]+\r?\n)+)'
        )
        if (-not $objPathFilterMatch.Success) {
            Write-Output "Could not parse the $Trigger agent-validation path filter."
            return
        }
        foreach ($strRequiredPath in $RequiredPath) {
            if ([regex]::Matches(
                    $objPathFilterMatch.Groups['Paths'].Value,
                    "(?m)^      - $([regex]::Escape($strRequiredPath))\r?$"
                ).Count -ne 1) {
                Write-Output "$Trigger must cover consumed validation path $strRequiredPath once."
            }
        }
    }

    $arrRequiredTriggerPaths = @(
        $script:arrCheckoutAttributePaths
        $arrAgentSetupInputSpecs | ForEach-Object { $_.Path }
    )
    foreach ($strTrigger in @('push', 'pull_request_target')) {
        $arrTriggerPathFailures = @(& $scriptBlockGetTriggerPathFailures `
                -WorkflowContent $strAgentWorkflowContent `
                -Trigger $strTrigger `
                -RequiredPath $arrRequiredTriggerPaths)
        if ($arrTriggerPathFailures.Count -gt 0) {
            throw $arrTriggerPathFailures[0]
        }
        if ($strTrigger -ceq 'push') {
            $objPushTriggerMatch = [regex]::Match(
                $strAgentWorkflowContent,
                '(?ms)^  push:\r?\n(?<Body>.*?)(?=^(?:\S| {2}\S)|\z)'
            )
            $objBranchFilterMatch = [regex]::Match(
                $objPushTriggerMatch.Groups['Body'].Value,
                '(?ms)^    branches:\r?\n(?<Branches>(?:      - [^\r\n]+\r?\n)+)'
            )
            if (-not $objBranchFilterMatch.Success -or
                $objBranchFilterMatch.Groups['Branches'].Value -cnotmatch
                    '^      - "\*\*"\r?\n$') {
                throw 'The push agent-validation trigger must cover all branches and exclude tags.'
            }
        }
        foreach ($strAttributePath in $script:arrCheckoutAttributePaths) {
            if ($script:arrTrustRootPaths -cnotcontains $strAttributePath) {
                throw "The trust-root gate omits checkout attribute path $strAttributePath."
            }
        }
    }
    foreach ($strTrigger in @('push', 'pull_request_target')) {
        $objTriggerMatch = [regex]::Match(
            $strAgentWorkflowContent,
            "(?ms)^  $strTrigger`:\r?\n(?<Body>.*?)(?=^(?:\S| {2}\S)|\z)"
        )
        foreach ($objAgentSetupInputSpec in $arrAgentSetupInputSpecs) {
            $objPathLineMatch = [regex]::Match(
                $objTriggerMatch.Groups['Body'].Value,
                "(?m)^      - $([regex]::Escape($objAgentSetupInputSpec.Path))\r?\n"
            )
            if (-not $objPathLineMatch.Success) {
                throw "Could not create the $strTrigger path-removal mutation."
            }
            $intPathLineIndex =
                $objTriggerMatch.Groups['Body'].Index + $objPathLineMatch.Index
            $strMutatedAgentWorkflowContent = $strAgentWorkflowContent.Remove(
                $intPathLineIndex,
                $objPathLineMatch.Length
            )
            $arrMutatedTriggerFailures = @(& $scriptBlockGetTriggerPathFailures `
                    -WorkflowContent $strMutatedAgentWorkflowContent `
                    -Trigger $strTrigger `
                    -RequiredPath $arrRequiredTriggerPaths)
            if (-not ($arrMutatedTriggerFailures -match [regex]::Escape(
                        "$strTrigger must cover consumed validation path " +
                        "$($objAgentSetupInputSpec.Path) once."
                    ))) {
                throw (
                    "$strTrigger path-removal mutation was accepted: " +
                    $objAgentSetupInputSpec.Path
                )
            }
        }
    }

    $arrUnchangedFailures = @(Get-TrustRootRangeMutationFailure `
            -RepositoryRootPath $strRepositoryRootPath `
            -BaseRevision $strNewRefTestHead `
            -HeadRevision $strNewRefTestHead `
            -RepositoryRelativePath $script:arrTrustRootPaths)
    if ($arrUnchangedFailures.Count -ne 0) {
        throw 'An unchanged trusted validation range did not pass.'
    }
    $strTrustRootBase = [string] (
        & git -C $strRepositoryRootPath rev-list --max-parents=0 HEAD |
            Select-Object -First 1
    )
    $arrTrustRootFailures = @(Get-TrustRootRangeMutationFailure `
            -RepositoryRootPath $strRepositoryRootPath `
            -BaseRevision $strTrustRootBase.Trim() `
            -HeadRevision $strNewRefTestHead `
            -RepositoryRelativePath $script:arrTrustRootPaths)
    if ($LASTEXITCODE -ne 0) {
        throw 'The trusted validation mutation query leaked a nonzero native status.'
    }
    $arrHistoricallyChangedTrustPaths = @(
        & git -C $strRepositoryRootPath diff --name-only --no-renames `
            --no-ext-diff --no-textconv $strTrustRootBase.Trim() `
            $strNewRefTestHead -- $script:arrTrustRootPaths
    )
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not inventory changed historical trust roots.'
    }
    foreach ($strTrustPath in $arrHistoricallyChangedTrustPaths) {
        if (-not ($arrTrustRootFailures -match
                [regex]::Escape("changes trusted validation path $strTrustPath."))) {
            throw "A changed trusted validation path did not fail closed: $strTrustPath"
        }
    }
    if ($arrTrustRootFailures.Count -ne $arrHistoricallyChangedTrustPaths.Count) {
        throw 'The trusted validation mutation test returned an unexpected failure count.'
    }
    $arrAttributeOnlyFailures = @(Get-TrustRootRangeMutationFailure `
            -RepositoryRootPath $strRepositoryRootPath `
            -BaseRevision $strTrustRootBase.Trim() `
            -HeadRevision $strNewRefTestHead `
            -RepositoryRelativePath @('.gitattributes'))
    if ($arrAttributeOnlyFailures.Count -ne 1 -or
        -not ($arrAttributeOnlyFailures -match
            [regex]::Escape('changes trusted validation path .gitattributes.'))) {
        throw 'An attribute-only trust-root query did not fail closed.'
    }

    $strMetadataNormalizationBase = @(
        '**Version:** 1.0.20260819.3'
        '- **Last Updated:** 2026-08-19'
        'Body'
    ) -join "`n"
    $strMetadataMechanicalMutation = @(
        '**Version:** 1.0.20260819.4'
        '- **Last Updated:** 2026-08-19'
        'Body '
        ''
    ) -join "`r`n"
    $objMetadataNormalizationContext = [pscustomobject]@{
        HasVersion = $true
        VersionLineIndex = 0
        UpdatedLineIndex = 1
    }
    if ((ConvertTo-MetadataComparisonText -Content $strMetadataNormalizationBase `
            -MetadataContext $objMetadataNormalizationContext) -cne
        (ConvertTo-MetadataComparisonText -Content $strMetadataMechanicalMutation `
            -MetadataContext $objMetadataNormalizationContext)) {
        throw 'Metadata normalization did not exempt mechanical line-ending, EOF, and trailing-space changes.'
    }
    $strMetadataHardBreakMutation = $strMetadataNormalizationBase.Replace('Body', 'Body  ')
    if ((ConvertTo-MetadataComparisonText -Content $strMetadataNormalizationBase `
            -MetadataContext $objMetadataNormalizationContext) -ceq
        (ConvertTo-MetadataComparisonText -Content $strMetadataHardBreakMutation `
            -MetadataContext $objMetadataNormalizationContext)) {
        throw 'Metadata normalization incorrectly exempted a Markdown hard-line-break change.'
    }
    $strMetadataExampleBase = @(
        $strMetadataNormalizationBase
        '```markdown'
        '**Version:** 9.9.20260101.1'
        '- **Last Updated:** 2026-01-01'
        '```'
    ) -join "`n"
    foreach ($strMetadataExampleMutation in @(
            $strMetadataExampleBase.Replace('9.9.20260101.1', '9.9.20260101.2'),
            $strMetadataExampleBase.Replace('2026-01-01', '2026-01-02')
        )) {
        if ((ConvertTo-MetadataComparisonText -Content $strMetadataExampleBase `
                -MetadataContext $objMetadataNormalizationContext) -ceq
            (ConvertTo-MetadataComparisonText -Content $strMetadataExampleMutation `
                -MetadataContext $objMetadataNormalizationContext)) {
            throw 'Metadata normalization incorrectly exempted a fenced metadata example change.'
        }
    }

    $strAgentsStandingParagraph = [regex]::Match(
        $strAgentsContent,
        '(?m)^[^\S\r\n]+\*\*Standing placement authorization\.\*\*.*$'
    ).Value
    if ([string]::IsNullOrEmpty($strAgentsStandingParagraph)) {
        throw 'Could not locate the AGENTS standing-placement paragraph for mutation tests.'
    }

    $strAgentsPlacementHeading = '## PR Review Workflow (Codex-adapted)'
    $strRawHtmlAgentsPlacementHeading = '<div>' + [Environment]::NewLine +
        $strAgentsPlacementHeading + [Environment]::NewLine + '</div>'
    Assert-MutationRejected `
        -Name 'AGENTS placement heading hidden in raw HTML' `
        -AgentsContent $strAgentsContent.Replace(
            $strAgentsPlacementHeading,
            $strRawHtmlAgentsPlacementHeading
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the standing direct-placement authorization exactly once.'

    $strClaudeLoopHeading = '## Automated Review Loop'
    $strRawHtmlClaudeLoopHeading = '<div>' + [Environment]::NewLine +
        $strClaudeLoopHeading + [Environment]::NewLine + '</div>'
    Assert-MutationRejected `
        -Name 'CLAUDE review-loop heading hidden in raw HTML' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent.Replace(
            $strClaudeLoopHeading,
            $strRawHtmlClaudeLoopHeading
        ) `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'CLAUDE.md must contain the standing direct-placement authorization exactly once.'

    $strRawHtmlBoundaryFixture = $strAgentsPlacementHeading +
        [Environment]::NewLine + [Environment]::NewLine + '<div>' +
        [Environment]::NewLine + '## Raw HTML Impostor Boundary' +
        [Environment]::NewLine + '</div>'
    Assert-FixtureAccepted `
        -Name 'raw HTML heading does not terminate a real section' `
        -AgentsContent $strAgentsContent.Replace(
            $strAgentsPlacementHeading,
            $strRawHtmlBoundaryFixture
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent

    Assert-MutationRejected `
        -Name 'duplicate parsed AGENTS placement heading' `
        -AgentsContent ($strAgentsContent + [Environment]::NewLine +
            $strAgentsPlacementHeading) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the standing direct-placement authorization exactly once.'

    $strContraryPlacementRule =
        'The agent must request a new owner approval before each direct PR-head push.'

    $strClaudeStandingParagraph = [regex]::Match(
        $strClaudeContent,
        '(?m)^[^\S\r\n]+\*\*Standing placement authorization\.\*\*.*$'
    ).Value
    if ([string]::IsNullOrEmpty($strClaudeStandingParagraph)) {
        throw 'Could not locate the CLAUDE standing-placement paragraph for mutation tests.'
    }

    $arrDeletionVariants = @(
        [pscustomobject]@{
            Name = 'Markdown strikethrough'
            Prefix = '~~'
            Suffix = '~~'
        },
        [pscustomobject]@{
            Name = 'nested Markdown strikethrough'
            Prefix = '~~**'
            Suffix = '**~~'
        },
        [pscustomobject]@{
            Name = 'raw HTML s'
            Prefix = '<s>'
            Suffix = '</s>'
        },
        [pscustomobject]@{
            Name = 'raw HTML del with attributes'
            Prefix = '<DEL data-reason="withdrawn">'
            Suffix = '</DEL>'
        },
        [pscustomobject]@{
            Name = 'raw HTML strike'
            Prefix = '<strike>'
            Suffix = '</strike>'
        }
    )
    $arrStandingDocuments = @(
        [pscustomobject]@{
            Name = 'AGENTS'
            Content = $strAgentsContent
            Paragraph = $strAgentsStandingParagraph
            Failure = 'AGENTS.md must contain the standing direct-placement authorization exactly once.'
        },
        [pscustomobject]@{
            Name = 'CLAUDE'
            Content = $strClaudeContent
            Paragraph = $strClaudeStandingParagraph
            Failure = 'CLAUDE.md must contain the standing direct-placement authorization exactly once.'
        }
    )
    foreach ($objDeletionVariant in $arrDeletionVariants) {
        $strDeletedAuthorization = $objDeletionVariant.Prefix +
            $script:strStandingPlacementAuthorization + $objDeletionVariant.Suffix
        foreach ($objStandingDocument in $arrStandingDocuments) {
            $strDeletedParagraph = $objStandingDocument.Paragraph.Replace(
                $script:strStandingPlacementAuthorization,
                $strDeletedAuthorization
            )
            $strDeletedContent = $objStandingDocument.Content.Replace(
                $objStandingDocument.Paragraph,
                $strDeletedParagraph + [Environment]::NewLine +
                    [Environment]::NewLine + '      ' + $strContraryPlacementRule
            )
            if ($objStandingDocument.Name -ceq 'AGENTS') {
                Assert-MutationRejected `
                    -Name "AGENTS standing placement hidden in $($objDeletionVariant.Name)" `
                    -AgentsContent $strDeletedContent `
                    -ClaudeContent $strClaudeContent `
                    -CodexConfigContent $strCodexConfigContent `
                    -ExpectedFailure $objStandingDocument.Failure
            }
            else {
                Assert-MutationRejected `
                    -Name "CLAUDE standing placement hidden in $($objDeletionVariant.Name)" `
                    -AgentsContent $strAgentsContent `
                    -ClaudeContent $strDeletedContent `
                    -CodexConfigContent $strCodexConfigContent `
                    -ExpectedFailure $objStandingDocument.Failure
            }
        }
    }

    $arrInlineHtmlContainerVariants = @(
        [pscustomobject]@{
            Name = 'hidden inline HTML span'
            Prefix = '<span hidden>'
            Suffix = '</span>'
        },
        [pscustomobject]@{
            Name = 'styled hidden inline HTML span'
            Prefix = '<span style="display: none">'
            Suffix = '</span>'
        },
        [pscustomobject]@{
            Name = 'visible inline HTML span'
            Prefix = '<span>'
            Suffix = '</span>'
        },
        [pscustomobject]@{
            Name = 'uppercase hidden inline HTML span'
            Prefix = '<SPAN HIDDEN>'
            Suffix = '</SPAN>'
        },
        [pscustomobject]@{
            Name = 'nested hidden inline HTML containers'
            Prefix = '<span hidden><em>'
            Suffix = '</em></span>'
        },
        [pscustomobject]@{
            Name = 'slash-suffixed hidden non-void HTML span'
            Prefix = '<span hidden />'
            Suffix = '</span>'
        }
    )
    foreach ($objHtmlVariant in $arrInlineHtmlContainerVariants) {
        $strHtmlWrappedAuthorization = $objHtmlVariant.Prefix +
            $script:strStandingPlacementAuthorization + $objHtmlVariant.Suffix
        foreach ($objStandingDocument in $arrStandingDocuments) {
            $strHtmlWrappedParagraph = $objStandingDocument.Paragraph.Replace(
                $script:strStandingPlacementAuthorization,
                $strHtmlWrappedAuthorization
            )
            $strHtmlWrappedContent = $objStandingDocument.Content.Replace(
                $objStandingDocument.Paragraph,
                $strHtmlWrappedParagraph + [Environment]::NewLine +
                    [Environment]::NewLine + '      ' + $strContraryPlacementRule
            )
            if ($objStandingDocument.Name -ceq 'AGENTS') {
                Assert-MutationRejected `
                    -Name "AGENTS standing placement hidden in $($objHtmlVariant.Name)" `
                    -AgentsContent $strHtmlWrappedContent `
                    -ClaudeContent $strClaudeContent `
                    -CodexConfigContent $strCodexConfigContent `
                    -ExpectedFailure $objStandingDocument.Failure
            }
            else {
                Assert-MutationRejected `
                    -Name "CLAUDE standing placement hidden in $($objHtmlVariant.Name)" `
                    -AgentsContent $strAgentsContent `
                    -ClaudeContent $strHtmlWrappedContent `
                    -CodexConfigContent $strCodexConfigContent `
                    -ExpectedFailure $objStandingDocument.Failure
            }
        }
    }

    $objVisibleEmphasisContext = Get-OperativeMarkdownContext `
        -Content 'Visible **operative** prose.'
    if (-not $objVisibleEmphasisContext.ProseText.Contains(
            'Visible operative prose.',
            [System.StringComparison]::Ordinal
        )) {
        throw 'Operative Markdown filtering removed ordinary emphasized prose.'
    }

    $objVoidHtmlContext = Get-OperativeMarkdownContext `
        -Content 'Visible<br> operative prose.'
    if (-not $objVoidHtmlContext.ProseText.Contains(
            'Visible operative prose.',
            [System.StringComparison]::Ordinal
        )) {
        throw 'Operative Markdown filtering removed prose adjacent to an HTML void element.'
    }

    $boolUnbalancedDeletionRejected = $false
    try {
        [void](Get-OperativeMarkdownContext -Content 'Visible </del> text.')
    }
    catch {
        $boolUnbalancedDeletionRejected = $_.Exception.Message.Contains(
            'locked Markdown parser rejected',
            [System.StringComparison]::OrdinalIgnoreCase
        )
    }
    if (-not $boolUnbalancedDeletionRejected) {
        throw 'Unbalanced inline deletion markup did not fail closed.'
    }

    $boolUnbalancedHtmlRejected = $false
    try {
        [void](Get-OperativeMarkdownContext -Content 'Visible </span> text.')
    }
    catch {
        $boolUnbalancedHtmlRejected = $_.Exception.Message.Contains(
            'locked Markdown parser rejected',
            [System.StringComparison]::OrdinalIgnoreCase
        )
    }
    if (-not $boolUnbalancedHtmlRejected) {
        throw 'Unbalanced inline HTML markup did not fail closed.'
    }

    Assert-MutationRejected `
        -Name 'standing placement hidden in HTML comment' `
        -AgentsContent $strAgentsContent.Replace(
            $strAgentsStandingParagraph,
            '<!--' + [Environment]::NewLine +
                $strAgentsStandingParagraph + [Environment]::NewLine +
                '-->' + [Environment]::NewLine + $strContraryPlacementRule
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the standing direct-placement authorization exactly once.'

    $strInlineCodeMutation = $strAgentsStandingParagraph.Replace(
        $strAgentsStandingParagraph.TrimStart(),
        [string][char]96 + $strAgentsStandingParagraph.TrimStart() + [string][char]96
    )
    Assert-MutationRejected `
        -Name 'standing placement hidden in inline code' `
        -AgentsContent $strAgentsContent.Replace(
            $strAgentsStandingParagraph,
            $strInlineCodeMutation + [Environment]::NewLine +
                [Environment]::NewLine + '      ' + $strContraryPlacementRule
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the standing direct-placement authorization exactly once.'

    $strTechnicalInlineFixture = 'Use `reviewThreads` to enumerate review threads.'
    $objTechnicalInlineContext = Get-OperativeMarkdownContext `
        -Content $strTechnicalInlineFixture
    if (@(
            $objTechnicalInlineContext.ProseBlocks.Code |
                Where-Object { $_ -ceq 'reviewThreads' }
        ).Count -ne 1 -or
        $objTechnicalInlineContext.ProseText.Contains(
            'reviewThreads',
            [System.StringComparison]::Ordinal
        )) {
        throw 'Inline Markdown parsing did not separate technical code from policy prose.'
    }

    $strMarkdownFence = [string]::new([char] 96, 3)
    $arrTechnicalCodeSpanContracts = @(
        [pscustomobject]@{
            Name = 'AGENTS'
            Content = $strAgentsContent
            Literals = $script:arrAgentsTechnicalCodeSpans
        },
        [pscustomobject]@{
            Name = 'CLAUDE'
            Content = $strClaudeContent
            Literals = $script:arrClaudeTechnicalCodeSpans
        }
    )
    foreach ($objContract in $arrTechnicalCodeSpanContracts) {
        foreach ($strLiteral in $objContract.Literals) {
            $strCodeSpan = [string][char]96 + $strLiteral + [string][char]96
            $strRemovedContent = $objContract.Content.Replace(
                $strCodeSpan,
                'removed technical marker'
            )
            $arrConcealmentMutations = @(
                [pscustomobject]@{
                    Name = 'raw block HTML'
                    Payload = '<div hidden>' + [Environment]::NewLine +
                        $strCodeSpan + [Environment]::NewLine + '</div>'
                },
                [pscustomobject]@{
                    Name = 'inline HTML'
                    Payload = '<span hidden>' + $strCodeSpan + '</span>'
                },
                [pscustomobject]@{
                    Name = 'HTML comment'
                    Payload = '<!-- ' + $strCodeSpan + ' -->'
                },
                [pscustomobject]@{
                    Name = 'deleted text'
                    Payload = '~~' + $strCodeSpan + '~~'
                },
                [pscustomobject]@{
                    Name = 'fenced code'
                    Payload = $strMarkdownFence + 'text' + [Environment]::NewLine +
                        $strCodeSpan + [Environment]::NewLine + $strMarkdownFence
                },
                [pscustomobject]@{
                    Name = 'indented code'
                    Payload = '    ' + $strCodeSpan
                },
                [pscustomobject]@{
                    Name = 'plain prose'
                    Payload = $strLiteral
                }
            )
            foreach ($objMutation in $arrConcealmentMutations) {
                $strMutation = $strRemovedContent + [Environment]::NewLine +
                    [Environment]::NewLine + $objMutation.Payload
                $strExpectedFailure = "$($objContract.Name).md is missing required " +
                    $(if ($objContract.Name -ceq 'AGENTS') {
                            'Codex'
                        }
                        else {
                            'Claude'
                        }) + " marker: $strLiteral"
                if ($objContract.Name -ceq 'AGENTS') {
                    Assert-MutationRejected `
                        -Name "AGENTS technical marker in $($objMutation.Name): $strLiteral" `
                        -AgentsContent $strMutation `
                        -ClaudeContent $strClaudeContent `
                        -CodexConfigContent $strCodexConfigContent `
                        -ExpectedFailure $strExpectedFailure
                }
                else {
                    Assert-MutationRejected `
                        -Name "CLAUDE technical marker in $($objMutation.Name): $strLiteral" `
                        -AgentsContent $strAgentsContent `
                        -ClaudeContent $strMutation `
                        -CodexConfigContent $strCodexConfigContent `
                        -ExpectedFailure $strExpectedFailure
                }
            }
        }
    }

    $strRemovedClaudeProse = $strClaudeContent.Replace(
        $script:strClaudeTechnicalProse,
        'removed readiness marker'
    )
    $arrClaudeProseMutations = @(
        '<div hidden>' + [Environment]::NewLine + $script:strClaudeTechnicalProse +
            [Environment]::NewLine + '</div>',
        '<span hidden>' + $script:strClaudeTechnicalProse + '</span>',
        '<!-- ' + $script:strClaudeTechnicalProse + ' -->',
        '~~' + $script:strClaudeTechnicalProse + '~~',
        $strMarkdownFence + 'text' + [Environment]::NewLine +
            $script:strClaudeTechnicalProse + [Environment]::NewLine + $strMarkdownFence,
        '    ' + $script:strClaudeTechnicalProse,
        [string][char]96 + $script:strClaudeTechnicalProse + [string][char]96
    )
    foreach ($strPayload in $arrClaudeProseMutations) {
        Assert-MutationRejected `
            -Name "Claude readiness marker on non-prose surface: $strPayload" `
            -AgentsContent $strAgentsContent `
            -ClaudeContent ($strRemovedClaudeProse + [Environment]::NewLine +
                [Environment]::NewLine + $strPayload) `
            -CodexConfigContent $strCodexConfigContent `
            -ExpectedFailure (
                'CLAUDE.md is missing required Claude marker: ' +
                $script:strClaudeTechnicalProse
            )
    }

    Assert-MutationRejected `
        -Name 'standing placement hidden in fenced example' `
        -AgentsContent $strAgentsContent.Replace(
            $strAgentsStandingParagraph,
            $strMarkdownFence + 'text' + [Environment]::NewLine +
                $strAgentsStandingParagraph + [Environment]::NewLine +
                $strMarkdownFence + [Environment]::NewLine + $strContraryPlacementRule
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the standing direct-placement authorization exactly once.'

    Assert-MutationRejected `
        -Name 'standing placement hidden in blockquoted fenced example' `
        -AgentsContent $strAgentsContent.Replace(
            $strAgentsStandingParagraph,
            '> ' + $strMarkdownFence + 'text' + [Environment]::NewLine +
                '> ' + $strAgentsStandingParagraph + [Environment]::NewLine +
                '> ' + $strMarkdownFence + [Environment]::NewLine +
                $strContraryPlacementRule
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the standing direct-placement authorization exactly once.'

    $strMarkdownTildeFence = '~~~'
    Assert-MutationRejected `
        -Name 'standing placement hidden in nested blockquoted tilde fence' `
        -AgentsContent $strAgentsContent.Replace(
            $strAgentsStandingParagraph,
            '> > ' + $strMarkdownTildeFence + 'text' + [Environment]::NewLine +
                '> > ' + $strAgentsStandingParagraph + [Environment]::NewLine +
                '> > ' + $strMarkdownTildeFence + [Environment]::NewLine +
                $strContraryPlacementRule
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the standing direct-placement authorization exactly once.'

    Assert-MutationRejected `
        -Name 'standing placement hidden in list-item fenced example' `
        -AgentsContent $strAgentsContent.Replace(
            $strAgentsStandingParagraph,
            '- ' + $strMarkdownFence + 'text' + [Environment]::NewLine +
                '  ' + $strAgentsStandingParagraph + [Environment]::NewLine +
                '  ' + $strMarkdownFence + [Environment]::NewLine +
                $strContraryPlacementRule
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the standing direct-placement authorization exactly once.'

    Assert-MutationRejected `
        -Name 'unclosed blockquoted fence does not swallow operative prose' `
        -AgentsContent $strAgentsContent.Replace(
            $strAgentsStandingParagraph,
            '> ' + $strMarkdownFence + 'text' + [Environment]::NewLine +
                '> ' + $strAgentsStandingParagraph + [Environment]::NewLine +
                $strContraryPlacementRule
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the standing direct-placement authorization exactly once.'

    Assert-FixtureAccepted `
        -Name 'ordinary blockquoted policy remains operative' `
        -AgentsContent $strAgentsContent.Replace(
            $strAgentsStandingParagraph,
            '    > ' + $strAgentsStandingParagraph.TrimStart()
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent

    Assert-MutationRejected `
        -Name 'standing placement hidden in list-item indented code block' `
        -AgentsContent $strAgentsContent.Replace(
            $strAgentsStandingParagraph,
            '    ' + $strAgentsStandingParagraph + [Environment]::NewLine +
                [Environment]::NewLine + '    ' + $strContraryPlacementRule
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the standing direct-placement authorization exactly once.'

    $arrIndentedCodeFixtures = @(
        [pscustomobject]@{
            Name = 'top-level indented code block'
            Content = "Before`n`n    HIDDEN-CODE`n`nAfter"
        },
        [pscustomobject]@{
            Name = 'blockquoted indented code block'
            Content = "> Before`n>`n>     HIDDEN-CODE`n>`n> After"
        },
        [pscustomobject]@{
            Name = 'tab-indented code block'
            Content = "Before`n`n`tHIDDEN-CODE`n`nAfter"
        }
    )
    foreach ($objFixture in $arrIndentedCodeFixtures) {
        $strOperativeFixture = ConvertTo-OperativeMarkdownText -Content $objFixture.Content
        if ($strOperativeFixture.Contains('HIDDEN-CODE', [System.StringComparison]::Ordinal) -or
            -not $strOperativeFixture.Contains('Before', [System.StringComparison]::Ordinal) -or
            -not $strOperativeFixture.Contains('After', [System.StringComparison]::Ordinal)) {
            throw "Operative Markdown filtering failed for $($objFixture.Name)."
        }
    }

    $strNestedListProse = @(
        '1. Parent'
        ''
        '    1. Child'
        ''
        '        OPERATIVE-NESTED-PROSE'
    ) -join "`n"
    $strNestedListOperativeText = ConvertTo-OperativeMarkdownText -Content $strNestedListProse
    if (-not $strNestedListOperativeText.Contains(
            'OPERATIVE-NESTED-PROSE',
            [System.StringComparison]::Ordinal
        )) {
        throw 'Operative Markdown filtering removed ordinary nested-list prose.'
    }

    $strAgentsAutomatedLoopHeading = '## Automated Review Loop (User-Initiated)'
    $strRelocatedStandingPlacement = $strAgentsContent.Replace(
        $strAgentsStandingParagraph,
        ''
    ).Replace(
        $strAgentsAutomatedLoopHeading,
        $strAgentsAutomatedLoopHeading + [Environment]::NewLine +
            $strAgentsStandingParagraph
    )
    Assert-MutationRejected `
        -Name 'standing placement moved to wrong section' `
        -AgentsContent $strRelocatedStandingPlacement `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the standing direct-placement authorization exactly once.'

    Assert-MutationRejected `
        -Name 'missing shared inventory marker' `
        -AgentsContent $strAgentsContent.Replace('`reviewThreads`', '`reviewThreadz`') `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md is missing required capability marker: `reviewThreads`'

    $arrSharedMarkerSource = @(
        $script:arrSharedStructuralLiterals |
            ForEach-Object {
                if ($_.StartsWith([string][char]96, [System.StringComparison]::Ordinal)) {
                    $_
                }
                else {
                    [char]96 + $_ + [char]96
                }
            }
    )
    $strSharedMarkerLines = $arrSharedMarkerSource -join [Environment]::NewLine
    $arrSharedMarkerConcealments = @(
        [pscustomobject]@{
            Name = 'raw HTML block'
            Suffix = '<div hidden>' + [Environment]::NewLine +
                $strSharedMarkerLines + [Environment]::NewLine + '</div>'
        },
        [pscustomobject]@{
            Name = 'fenced code block'
            Suffix = $strMarkdownFence + [Environment]::NewLine +
                $strSharedMarkerLines + [Environment]::NewLine + $strMarkdownFence
        },
        [pscustomobject]@{
            Name = 'inline HTML container'
            Suffix = '<span hidden>' + ($arrSharedMarkerSource -join ' ') + '</span>'
        },
        [pscustomobject]@{
            Name = 'unrelated visible paragraph'
            Suffix = 'Unrelated example: ' + ($arrSharedMarkerSource -join ' ')
        }
    )
    foreach ($strDocumentName in @('AGENTS.md', 'CLAUDE.md')) {
        $strDocumentContent = if ($strDocumentName -ceq 'AGENTS.md') {
            $strAgentsContent
        }
        else {
            $strClaudeContent
        }
        foreach ($strLiteral in $script:arrSharedStructuralLiterals) {
            $strDocumentContent = $strDocumentContent.Replace(
                $strLiteral,
                'removed shared structural marker'
            )
        }
        foreach ($objConcealment in $arrSharedMarkerConcealments) {
            $strMutation = $strDocumentContent + [Environment]::NewLine +
                [Environment]::NewLine + $objConcealment.Suffix
            $strExpectedFailure = $strDocumentName +
                ' is missing required capability marker: `reviewThreads`'
            if ($strDocumentName -ceq 'AGENTS.md') {
                Assert-MutationRejected `
                    -Name "AGENTS shared markers in $($objConcealment.Name)" `
                    -AgentsContent $strMutation `
                    -ClaudeContent $strClaudeContent `
                    -CodexConfigContent $strCodexConfigContent `
                    -ExpectedFailure $strExpectedFailure
            }
            else {
                Assert-MutationRejected `
                    -Name "CLAUDE shared markers in $($objConcealment.Name)" `
                    -AgentsContent $strAgentsContent `
                    -ClaudeContent $strMutation `
                    -CodexConfigContent $strCodexConfigContent `
                    -ExpectedFailure $strExpectedFailure
            }
        }
    }

    foreach ($strDocumentName in @('AGENTS.md', 'CLAUDE.md')) {
        $strDocumentContent = if ($strDocumentName -ceq 'AGENTS.md') {
            $strAgentsContent
        }
        else {
            $strClaudeContent
        }
        $strDeferringWorkHeading = '## Deferring Work'
        $arrDeferringWorkMutations = @(
            [pscustomobject]@{
                Name = 'hidden in raw HTML'
                Content = $strDocumentContent.Replace(
                    $strDeferringWorkHeading,
                    '<div>' + [Environment]::NewLine +
                        $strDeferringWorkHeading + [Environment]::NewLine +
                        '</div>'
                )
            },
            [pscustomobject]@{
                Name = 'demoted to level three'
                Content = $strDocumentContent.Replace(
                    $strDeferringWorkHeading,
                    '### Deferring Work'
                )
            },
            [pscustomobject]@{
                Name = 'duplicated'
                Content = $strDocumentContent.Replace(
                    $strDeferringWorkHeading,
                    $strDeferringWorkHeading + [Environment]::NewLine +
                        $strDeferringWorkHeading
                )
            }
        )
        foreach ($objMutation in $arrDeferringWorkMutations) {
            $strExpectedFailure =
                "$strDocumentName must contain one exact level-two Deferring Work heading."
            if ($strDocumentName -ceq 'AGENTS.md') {
                Assert-MutationRejected `
                    -Name "AGENTS Deferring Work heading $($objMutation.Name)" `
                    -AgentsContent $objMutation.Content `
                    -ClaudeContent $strClaudeContent `
                    -CodexConfigContent $strCodexConfigContent `
                    -ExpectedFailure $strExpectedFailure
            }
            else {
                Assert-MutationRejected `
                    -Name "CLAUDE Deferring Work heading $($objMutation.Name)" `
                    -AgentsContent $strAgentsContent `
                    -ClaudeContent $objMutation.Content `
                    -CodexConfigContent $strCodexConfigContent `
                    -ExpectedFailure $strExpectedFailure
            }
        }
    }

    foreach ($strLiteral in $script:arrSharedProseLiterals) {
        foreach ($strDocumentName in @('AGENTS.md', 'CLAUDE.md')) {
            $strDocumentContent = if ($strDocumentName -ceq 'AGENTS.md') {
                $strAgentsContent
            }
            else {
                $strClaudeContent
            }
            $strMutationToken = ($strLiteral -split ' ')[-1]
            $strRemovedMarkerContent = $strDocumentContent.Replace(
                $strMutationToken,
                'removed shared policy marker'
            )
            $objRemovedMarkerContext = Get-OperativeMarkdownContext `
                -Content $strRemovedMarkerContent
            if ($objRemovedMarkerContext.ProseText.Contains(
                    $strLiteral,
                    [System.StringComparison]::Ordinal
                )) {
                throw "Could not remove shared prose marker for mutation: $strLiteral"
            }
            $strInlineCodeMutation = $strRemovedMarkerContent +
                [Environment]::NewLine + '`' + $strLiteral + '`'
            $strRawHtmlMutation = $strRemovedMarkerContent +
                [Environment]::NewLine + '<pre>' + [Environment]::NewLine +
                $strLiteral + [Environment]::NewLine + '</pre>'
            foreach ($objMutation in @(
                    [pscustomobject]@{
                        Name = 'inline code'
                        Content = $strInlineCodeMutation
                    },
                    [pscustomobject]@{
                        Name = 'raw HTML'
                        Content = $strRawHtmlMutation
                    }
                )) {
                $strExpectedFailure =
                    "$strDocumentName is missing required capability marker: $strLiteral"
                if ($strDocumentName -ceq 'AGENTS.md') {
                    Assert-MutationRejected `
                        -Name "AGENTS shared marker hidden in $($objMutation.Name): $strLiteral" `
                        -AgentsContent $objMutation.Content `
                        -ClaudeContent $strClaudeContent `
                        -CodexConfigContent $strCodexConfigContent `
                        -ExpectedFailure $strExpectedFailure
                }
                else {
                    Assert-MutationRejected `
                        -Name "CLAUDE shared marker hidden in $($objMutation.Name): $strLiteral" `
                        -AgentsContent $strAgentsContent `
                        -ClaudeContent $objMutation.Content `
                        -CodexConfigContent $strCodexConfigContent `
                        -ExpectedFailure $strExpectedFailure
                }
            }
        }
    }

    foreach ($objContract in $script:arrAgentsNormativeProseContracts) {
        $strLiteral = $objContract.Literal
        $strRemovedMarkerContent = $strAgentsContent.Replace(
            $strLiteral,
            'removed agent-specific policy marker'
        )
        $objRemovedMarkerContext = Get-OperativeMarkdownContext `
            -Content $strRemovedMarkerContent
        if ($objRemovedMarkerContext.ProseText.Contains(
                $strLiteral,
                [System.StringComparison]::Ordinal
            )) {
            throw "Could not remove AGENTS normative prose marker for mutation: $strLiteral"
        }
        $strInlineCodeMutation = $strRemovedMarkerContent +
            [Environment]::NewLine + '`' + $strLiteral + '`'
        $strRawHtmlMutation = $strRemovedMarkerContent +
            [Environment]::NewLine + '<pre>' + [Environment]::NewLine +
            $strLiteral + [Environment]::NewLine + '</pre>'
        $strVisibleRelocation = $strRemovedMarkerContent +
            [Environment]::NewLine + [Environment]::NewLine +
            'Unrelated glossary entry: ' + $strLiteral
        foreach ($objMutation in @(
                [pscustomobject]@{
                    Name = 'inline code'
                    Content = $strInlineCodeMutation
                },
                [pscustomobject]@{
                    Name = 'raw HTML'
                    Content = $strRawHtmlMutation
                },
                [pscustomobject]@{
                    Name = 'unrelated visible paragraph'
                    Content = $strVisibleRelocation
                }
            )) {
            Assert-MutationRejected `
                -Name "AGENTS normative marker hidden in $($objMutation.Name): $strLiteral" `
                -AgentsContent $objMutation.Content `
                -ClaudeContent $strClaudeContent `
                -CodexConfigContent $strCodexConfigContent `
                -ExpectedFailure "AGENTS.md must contain required policy as prose: $strLiteral"
        }
    }

    Assert-MutationRejected `
        -Name 'missing Claude readiness marker' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent.Replace('review-readiness gate', 'review readiness gate') `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'CLAUDE.md is missing required Claude marker: review-readiness gate'

    Assert-MutationRejected `
        -Name 'missing AGENTS standing placement authorization' `
        -AgentsContent $strAgentsContent.Replace(
            $script:strStandingPlacementAuthorization,
            'An additional direct-push authorization from the owner is required.'
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the standing direct-placement authorization exactly once.'

    Assert-MutationRejected `
        -Name 'missing CLAUDE standing placement authorization' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent.Replace(
            $script:strStandingPlacementAuthorization,
            'An additional direct-push authorization from the owner is required.'
        ) `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'CLAUDE.md must contain the standing direct-placement authorization exactly once.'

    Assert-MutationRejected `
        -Name 'obsolete session-specific placement authorization' `
        -AgentsContent ($strAgentsContent + [Environment]::NewLine + $script:arrObsoletePlacementLiterals[0]) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md contains obsolete session-specific direct-placement authorization'

    foreach ($strLiteral in $script:arrPlacementStructuralLiterals) {
        $strInlineCodeLiteral = '`' + $strLiteral + '`'
        Assert-MutationRejected `
            -Name "AGENTS placement structure hidden in inline code: $strLiteral" `
            -AgentsContent $strAgentsContent.Replace($strLiteral, $strInlineCodeLiteral) `
            -ClaudeContent $strClaudeContent `
            -CodexConfigContent $strCodexConfigContent `
            -ExpectedFailure (
                'AGENTS.md is missing required direct-placement safety marker: ' +
                $strLiteral
            )
        Assert-MutationRejected `
            -Name "CLAUDE placement structure hidden in inline code: $strLiteral" `
            -AgentsContent $strAgentsContent `
            -ClaudeContent $strClaudeContent.Replace($strLiteral, $strInlineCodeLiteral) `
            -CodexConfigContent $strCodexConfigContent `
            -ExpectedFailure (
                'CLAUDE.md is missing required direct-placement safety marker: ' +
                $strLiteral
            )
    }

    foreach ($strLiteral in $script:arrPlacementProseLiterals) {
        $strInlineCodeLiteral = '`' + $strLiteral + '`'
        $strAgentsInlineCodeMutation = $strAgentsContent.Replace(
            $strLiteral,
            'removed direct-placement safety marker'
        ).Replace(
            '**Outgoing-range audit.**',
            '**Outgoing-range audit.** ' + $strInlineCodeLiteral
        )
        Assert-MutationRejected `
            -Name "AGENTS placement prose hidden in inline code: $strLiteral" `
            -AgentsContent $strAgentsInlineCodeMutation `
            -ClaudeContent $strClaudeContent `
            -CodexConfigContent $strCodexConfigContent `
            -ExpectedFailure (
                'AGENTS.md is missing required direct-placement safety marker: ' +
                $strLiteral
            )

        $strClaudeInlineCodeMutation = $strClaudeContent.Replace(
            $strLiteral,
            'removed direct-placement safety marker'
        ).Replace(
            '**Outgoing-range audit.**',
            '**Outgoing-range audit.** ' + $strInlineCodeLiteral
        )
        Assert-MutationRejected `
            -Name "CLAUDE placement prose hidden in inline code: $strLiteral" `
            -AgentsContent $strAgentsContent `
            -ClaudeContent $strClaudeInlineCodeMutation `
            -CodexConfigContent $strCodexConfigContent `
            -ExpectedFailure (
                'CLAUDE.md is missing required direct-placement safety marker: ' +
                $strLiteral
            )
    }

    Assert-MutationRejected `
        -Name 'missing AGENTS inline style-guide route' `
        -AgentsContent $strAgentsContent.Replace(
            $script:arrStyleGuideRoutingLiterals[0],
            'Post the prompt in the review discussion.'
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure (
            'AGENTS.md must contain the style-guide routing marker exactly once: ' +
            $script:arrStyleGuideRoutingLiterals[0]
        )

    Assert-MutationRejected `
        -Name 'missing CLAUDE body-only style-guide route' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent.Replace(
            $script:arrStyleGuideRoutingLiterals[1],
            'Post the prompt in the review discussion.'
        ) `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure (
            'CLAUDE.md must contain the style-guide routing marker exactly once: ' +
            $script:arrStyleGuideRoutingLiterals[1]
        )

    Assert-MutationRejected `
        -Name 'missing AGENTS genuine-deferral Issue rule' `
        -AgentsContent $strAgentsContent.Replace(
            $script:strOnlyGenuineDeferredWork,
            'Every non-fix outcome requires a GitHub Issue.'
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must contain the genuine-deferral Issue rule exactly once.'

    Assert-MutationRejected `
        -Name 'missing CLAUDE genuine-deferral Issue rule' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent.Replace(
            $script:strOnlyGenuineDeferredWork,
            'Every non-fix outcome requires a GitHub Issue.'
        ) `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'CLAUDE.md must contain the genuine-deferral Issue rule exactly once.'

    Assert-MutationRejected `
        -Name 'obsolete blanket Issue rule' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent ($strClaudeContent + [Environment]::NewLine + $script:arrObsoleteDeferralLiterals[0]) `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'CLAUDE.md contains an obsolete blanket Issue rule'

    $objMaximumMatch = [regex]::Match(
        $strCodexConfigContent,
        '(?m)^\s*project_doc_max_bytes\s*=\s*(?<MaximumBytes>\d+)\s*$'
    )
    $objMaximumBytesGroup = $objMaximumMatch.Groups['MaximumBytes']
    $strInsufficientCapacityConfig = $strCodexConfigContent.Remove(
        $objMaximumBytesGroup.Index,
        $objMaximumBytesGroup.Length
    )
    $strInsufficientCapacityConfig = $strInsufficientCapacityConfig.Insert(
        $objMaximumBytesGroup.Index,
        '32768'
    )
    Assert-MutationRejected `
        -Name 'insufficient configured capacity' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strInsufficientCapacityConfig `
        -ExpectedFailure 'project_doc_max_bytes must be at least 65536.'

    $arrAcceptedCapacityStatements = @(
        [pscustomobject]@{
            Name = 'decimal capacity with inline comment'
            Statement = 'project_doc_max_bytes = 65536 # reserve'
        },
        [pscustomobject]@{
            Name = 'decimal capacity with underscores'
            Statement = 'project_doc_max_bytes = 65_536'
        },
        [pscustomobject]@{
            Name = 'decimal capacity with explicit plus sign'
            Statement = 'project_doc_max_bytes = +65536'
        },
        [pscustomobject]@{
            Name = 'hexadecimal capacity'
            Statement = 'project_doc_max_bytes = 0x1_0000'
        },
        [pscustomobject]@{
            Name = 'octal capacity'
            Statement = 'project_doc_max_bytes = 0o200000'
        },
        [pscustomobject]@{
            Name = 'binary capacity'
            Statement = 'project_doc_max_bytes = 0b1_0000_0000_0000_0000'
        },
        [pscustomobject]@{
            Name = 'signed underscored capacity with inline comment'
            Statement = 'project_doc_max_bytes = +65_536 # reserve'
        },
        [pscustomobject]@{
            Name = 'basic-quoted capacity key'
            Statement = '"project_doc_max_bytes" = 65536'
        },
        [pscustomobject]@{
            Name = 'literal-quoted capacity key'
            Statement = "'project_doc_max_bytes' = 65536"
        },
        [pscustomobject]@{
            Name = 'escaped basic-quoted capacity key'
            Statement = '"project_doc_max_b\u0079tes" = 65536'
        }
    )
    foreach ($objAcceptedCapacityStatement in $arrAcceptedCapacityStatements) {
        Assert-FixtureAccepted `
            -Name $objAcceptedCapacityStatement.Name `
            -AgentsContent $strAgentsContent `
            -ClaudeContent $strClaudeContent `
            -CodexConfigContent $strCodexConfigContent.Replace(
                $objMaximumMatch.Value,
                $objAcceptedCapacityStatement.Statement
            )
    }

    foreach ($objInvalidCapacityStatement in @(
            [pscustomobject]@{
                Name = 'string capacity'
                Statement = 'project_doc_max_bytes = "65536"'
            },
            [pscustomobject]@{
                Name = 'Boolean capacity'
                Statement = 'project_doc_max_bytes = true'
            },
            [pscustomobject]@{
                Name = 'floating-point capacity'
                Statement = 'project_doc_max_bytes = 65536.0'
            },
            [pscustomobject]@{
                Name = 'array capacity'
                Statement = 'project_doc_max_bytes = [65536]'
            },
            [pscustomobject]@{
                Name = 'inline-table capacity'
                Statement = 'project_doc_max_bytes = { value = 65536 }'
            }
        )) {
        Assert-MutationRejected `
            -Name $objInvalidCapacityStatement.Name `
            -AgentsContent $strAgentsContent `
            -ClaudeContent $strClaudeContent `
            -CodexConfigContent $strCodexConfigContent.Replace(
                $objMaximumMatch.Value,
                $objInvalidCapacityStatement.Statement
            ) `
            -ExpectedFailure 'project_doc_max_bytes must be an integer.'
    }

    Assert-MutationRejected `
        -Name 'capacity exceeds signed 64-bit range' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent.Replace(
            $objMaximumMatch.Value,
            'project_doc_max_bytes = 9223372036854775808'
        ) `
        -ExpectedFailure 'project_doc_max_bytes must fit in a signed 64-bit integer.'

    Assert-MutationRejected `
        -Name 'hexadecimal capacity below minimum' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent.Replace(
            $objMaximumMatch.Value,
            'project_doc_max_bytes = 0x8000'
        ) `
        -ExpectedFailure 'project_doc_max_bytes must be at least 65536.'

    $strNestedMaximumConfig = @(
        '[codex_self_test]'
        $objMaximumMatch.Value
    ) -join [Environment]::NewLine
    Assert-MutationRejected `
        -Name 'nested configured capacity' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strNestedMaximumConfig `
        -ExpectedFailure 'project_doc_max_bytes must be the first semantic TOML statement.'

    $strMultilineBasicCapacityConfig = $strCodexConfigContent.Replace(
        $objMaximumMatch.Value,
        (@(
                'model = """'
                $objMaximumMatch.Value
                '"""'
            ) -join [Environment]::NewLine)
    )
    Assert-MutationRejected `
        -Name 'capacity assignment inside multiline basic string' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strMultilineBasicCapacityConfig `
        -ExpectedFailure 'project_doc_max_bytes must be the first semantic TOML statement.'

    $strMultilineLiteralCapacityConfig = $strCodexConfigContent.Replace(
        $objMaximumMatch.Value,
        (@(
                "model = '''"
                $objMaximumMatch.Value
                "'''"
            ) -join [Environment]::NewLine)
    )
    Assert-MutationRejected `
        -Name 'capacity assignment inside multiline literal string' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strMultilineLiteralCapacityConfig `
        -ExpectedFailure 'project_doc_max_bytes must be the first semantic TOML statement.'

    $strGitHubPluginTableHeader = '[plugins."github@openai-curated"]'
    $arrAcceptedPluginTableStatements = @(
        [pscustomobject]@{
            Name = 'canonical plugin table key'
            Statement = $strGitHubPluginTableHeader
        },
        [pscustomobject]@{
            Name = 'literal-quoted plugin table key'
            Statement = "[plugins.'github@openai-curated']"
        },
        [pscustomobject]@{
            Name = 'basic-quoted dotted plugin keys'
            Statement = '["plugins"."github@openai-curated"]'
        },
        [pscustomobject]@{
            Name = 'mixed quoted dotted plugin keys'
            Statement = "['plugins'.`"github@openai-curated`"]"
        },
        [pscustomobject]@{
            Name = 'escaped basic-quoted plugin table key'
            Statement = '[plugins."github\u0040openai-curated"]'
        },
        [pscustomobject]@{
            Name = 'spaced literal-quoted dotted plugin keys'
            Statement = "[ 'plugins' . 'github@openai-curated' ]"
        },
        [pscustomobject]@{
            Name = 'plugin table key with inline comment'
            Statement = '[plugins."github@openai-curated"] # required plugin'
        }
    )
    $arrAcceptedPluginEnablementStatements = @(
        [pscustomobject]@{
            Name = 'bare enabled key'
            Statement = 'enabled = true'
        },
        [pscustomobject]@{
            Name = 'basic-quoted enabled key'
            Statement = '"enabled" = true'
        },
        [pscustomobject]@{
            Name = 'literal-quoted enabled key'
            Statement = "'enabled' = true"
        },
        [pscustomobject]@{
            Name = 'escaped basic-quoted enabled key'
            Statement = '"en\u0061bled" = true'
        }
    )
    foreach ($objPluginTableStatement in $arrAcceptedPluginTableStatements) {
        foreach ($objPluginEnablementStatement in $arrAcceptedPluginEnablementStatements) {
            $strPluginKeyVariantConfig = $strCodexConfigContent.Replace(
                $strGitHubPluginTableHeader,
                $objPluginTableStatement.Statement
            ).Replace(
                'enabled = true',
                $objPluginEnablementStatement.Statement
            )
            $objPluginKeyVariantContext = Get-TomlParseContext `
                -Content $strPluginKeyVariantConfig
            if (-not [string]::IsNullOrEmpty($objPluginKeyVariantContext.Failure) -or
                -not $objPluginKeyVariantContext.CapacityIsFirstStatement -or
                -not $objPluginKeyVariantContext.PluginHeaderIsSecondStatement -or
                -not $objPluginKeyVariantContext.PluginEnablementIsThirdStatement -or
                -not $objPluginKeyVariantContext.PluginTablePresent -or
                -not $objPluginKeyVariantContext.PluginEnabledPresent -or
                $objPluginKeyVariantContext.PluginEnabledType -cne 'bool' -or
                -not $objPluginKeyVariantContext.PluginEnabledValue) {
                throw (
                    "Accepted plugin key permutation failed parser validation: " +
                    "$($objPluginTableStatement.Name) with " +
                    "$($objPluginEnablementStatement.Name)."
                )
            }
            $objPluginKeyVariantLocation = Get-GitHubPluginEnablementContext `
                -Content $strPluginKeyVariantConfig
            if ($objPluginKeyVariantLocation.TableMatchCount -ne 1 -or
                $objPluginKeyVariantLocation.EnablementMatchCount -ne 1 -or
                $objPluginKeyVariantLocation.EnabledValue -cne 'true' -or
                $objPluginKeyVariantLocation.EnabledValueIndex -lt 0 -or
                $objPluginKeyVariantLocation.EnabledValueLength -ne 4) {
                throw (
                    "Accepted plugin key permutation did not produce one source location: " +
                    "$($objPluginTableStatement.Name) with " +
                    "$($objPluginEnablementStatement.Name)."
                )
            }
        }
    }

    $strCombinedQuotedKeyConfig = $strCodexConfigContent.Replace(
        $objMaximumMatch.Value,
        '"project_doc_max_b\u0079tes" = 65536'
    ).Replace(
        $strGitHubPluginTableHeader,
        "[ 'plugins' . 'github@openai-curated' ]"
    ).Replace(
        'enabled = true',
        '"en\u0061bled" = true'
    )
    Assert-FixtureAccepted `
        -Name 'combined semantically equivalent quoted TOML keys' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCombinedQuotedKeyConfig
    Assert-MutationRejected `
        -Name 'disabled plugin with combined semantically equivalent quoted TOML keys' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent (ConvertTo-DisabledGitHubPluginMutation `
            -Content $strCombinedQuotedKeyConfig) `
        -ExpectedFailure 'The github@openai-curated plugin table must declare enabled = true exactly once.'

    foreach ($objNearMissPluginStatement in @(
            [pscustomobject]@{
                Name = 'different escaped plugin table key'
                Search = $strGitHubPluginTableHeader
                Replacement = '[plugins."github\u0041openai-curated"]'
                Failure =
                    'The github@openai-curated plugin table must be the second semantic TOML statement.'
            },
            [pscustomobject]@{
                Name = 'array-of-tables plugin declaration'
                Search = $strGitHubPluginTableHeader
                Replacement = '[[plugins."github@openai-curated"]]'
                Failure =
                    'The github@openai-curated plugin table must be the second semantic TOML statement.'
            },
            [pscustomobject]@{
                Name = 'nested enabled key'
                Search = 'enabled = true'
                Replacement = '"enabled".nested = true'
                Failure =
                    'The github@openai-curated enabled value must be the third semantic TOML statement.'
            },
            [pscustomobject]@{
                Name = 'different escaped enabled key'
                Search = 'enabled = true'
                Replacement = '"en\u0062bled" = true'
                Failure =
                    'The github@openai-curated enabled value must be the third semantic TOML statement.'
            }
        )) {
        Assert-MutationRejected `
            -Name $objNearMissPluginStatement.Name `
            -AgentsContent $strAgentsContent `
            -ClaudeContent $strClaudeContent `
            -CodexConfigContent $strCodexConfigContent.Replace(
                $objNearMissPluginStatement.Search,
                $objNearMissPluginStatement.Replacement
            ) `
            -ExpectedFailure $objNearMissPluginStatement.Failure
    }

    Assert-MutationRejected `
        -Name 'missing GitHub plugin declaration' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent.Replace(
            $strGitHubPluginTableHeader,
            '[plugins."github-disabled-for-self-test"]'
        ) `
        -ExpectedFailure 'The project configuration must declare [plugins."github@openai-curated"] exactly once.'

    $strDisabledGitHubPluginConfig = ConvertTo-DisabledGitHubPluginMutation `
        -Content $strCodexConfigContent
    Assert-MutationRejected `
        -Name 'disabled GitHub plugin declaration' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strDisabledGitHubPluginConfig `
        -ExpectedFailure 'The github@openai-curated plugin table must declare enabled = true exactly once.'

    foreach ($objInvalidPluginValue in @(
            [pscustomobject]@{
                Name = 'string GitHub plugin enablement'
                Statement = 'enabled = "true"'
            },
            [pscustomobject]@{
                Name = 'integer GitHub plugin enablement'
                Statement = 'enabled = 1'
            }
        )) {
        Assert-MutationRejected `
            -Name $objInvalidPluginValue.Name `
            -AgentsContent $strAgentsContent `
            -ClaudeContent $strClaudeContent `
            -CodexConfigContent $strCodexConfigContent.Replace(
                'enabled = true',
                $objInvalidPluginValue.Statement
            ) `
            -ExpectedFailure 'The github@openai-curated plugin table must declare enabled = true exactly once.'
    }

    $strConfigNewLine = if ($strCodexConfigContent.Contains("`r`n", [System.StringComparison]::Ordinal)) {
        "`r`n"
    }
    else {
        "`n"
    }
    $strCapacityStatement = $objMaximumMatch.Value.TrimEnd([char[]] "`r`n")
    $strCanonicalConfigPrefix = @(
        $strCapacityStatement
        ''
        $strGitHubPluginTableHeader
        'enabled = true'
    ) -join $strConfigNewLine
    $strReorderedConfigPrefix = @(
        $strGitHubPluginTableHeader
        'enabled = true'
        ''
        $strCapacityStatement
    ) -join $strConfigNewLine
    Assert-MutationRejected `
        -Name 'plugin table before capacity statement' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent.Replace(
            $strCanonicalConfigPrefix,
            $strReorderedConfigPrefix
        ) `
        -ExpectedFailure 'project_doc_max_bytes must be the first semantic TOML statement.'

    $objCanonicalPluginContext = Get-GitHubPluginEnablementContext `
        -Content $strCodexConfigContent
    $intEnablementLineStart = $strCodexConfigContent.LastIndexOf(
        "`n",
        $objCanonicalPluginContext.EnabledValueIndex
    ) + 1
    $strAlternativePluginFormattingConfig = $strCodexConfigContent.Insert(
        $intEnablementLineStart,
        "# accepted plugin separator$strConfigNewLine"
    )
    $objAlternativePluginContext = Get-GitHubPluginEnablementContext `
        -Content $strAlternativePluginFormattingConfig
    $strAlternativePluginFormattingConfig = $strAlternativePluginFormattingConfig.Insert(
        $objAlternativePluginContext.EnabledValueIndex,
        ' '
    )
    $arrAlternativePluginFailures = @(Get-AgentInstructionFailure `
            -AgentsContent $strAgentsContent `
            -ClaudeContent $strClaudeContent `
            -CodexConfigContent $strAlternativePluginFormattingConfig)
    if ($arrAlternativePluginFailures.Count -gt 0) {
        throw "Accepted plugin formatting failed validation: $($arrAlternativePluginFailures -join '; ')"
    }
    Assert-MutationRejected `
        -Name 'disabled GitHub plugin declaration with accepted formatting' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent (ConvertTo-DisabledGitHubPluginMutation `
            -Content $strAlternativePluginFormattingConfig) `
        -ExpectedFailure 'The github@openai-curated plugin table must declare enabled = true exactly once.'

    Assert-MutationRejected `
        -Name 'duplicate GitHub plugin declaration' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent ($strCodexConfigContent + [Environment]::NewLine +
            $strGitHubPluginTableHeader + [Environment]::NewLine + 'enabled = true') `
        -ExpectedFailure 'The project configuration must contain valid TOML.'

    Assert-MutationRejected `
        -Name 'nested GitHub plugin declaration' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent.Replace(
            $strGitHubPluginTableHeader,
            '[features.plugins."github@openai-curated"]'
        ) `
        -ExpectedFailure 'The project configuration must declare [plugins."github@openai-curated"] exactly once.'

    $strBasicStringPluginTableConfig = $strCodexConfigContent.Replace(
        $strGitHubPluginTableHeader,
        "model = `"`"`"$strConfigNewLine$strGitHubPluginTableHeader"
    ).Replace(
        'enabled = true',
        "enabled = true$strConfigNewLine`"`"`""
    )
    Assert-MutationRejected `
        -Name 'plugin table inside multiline basic string' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strBasicStringPluginTableConfig `
        -ExpectedFailure 'The github@openai-curated plugin table must be the second semantic TOML statement.'

    $strLiteralStringPluginTableConfig = $strCodexConfigContent.Replace(
        $strGitHubPluginTableHeader,
        "model = '''$strConfigNewLine$strGitHubPluginTableHeader"
    ).Replace(
        'enabled = true',
        "enabled = true$strConfigNewLine'''"
    )
    Assert-MutationRejected `
        -Name 'plugin table inside multiline literal string' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strLiteralStringPluginTableConfig `
        -ExpectedFailure 'The github@openai-curated plugin table must be the second semantic TOML statement.'

    $strBasicStringPluginEnabledConfig = $strCodexConfigContent.Replace(
        'enabled = true',
        "model = `"`"`"$strConfigNewLine" +
            "enabled = true$strConfigNewLine`"`"`""
    )
    Assert-MutationRejected `
        -Name 'plugin enabled value inside multiline basic string' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strBasicStringPluginEnabledConfig `
        -ExpectedFailure 'The github@openai-curated enabled value must be the third semantic TOML statement.'

    $strLiteralStringPluginEnabledConfig = $strCodexConfigContent.Replace(
        'enabled = true',
        "model = '''$strConfigNewLine" +
            "enabled = true$strConfigNewLine'''"
    )
    Assert-MutationRejected `
        -Name 'plugin enabled value inside multiline literal string' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strLiteralStringPluginEnabledConfig `
        -ExpectedFailure 'The github@openai-curated enabled value must be the third semantic TOML statement.'

    $strLaterBasicStringConfig = $strCodexConfigContent + $strConfigNewLine +
        (@(
                '[validator_basic_string_fixture]'
                'content = """'
                $objMaximumMatch.Value
                $strGitHubPluginTableHeader
                'enabled = false'
                '"""'
            ) -join $strConfigNewLine)
    Assert-FixtureAccepted `
        -Name 'later multiline basic string contains configuration-like lines' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strLaterBasicStringConfig
    Assert-MutationRejected `
        -Name 'disabled plugin with later multiline basic string' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent (ConvertTo-DisabledGitHubPluginMutation `
            -Content $strLaterBasicStringConfig) `
        -ExpectedFailure 'The github@openai-curated plugin table must declare enabled = true exactly once.'

    $strLaterLiteralStringConfig = $strCodexConfigContent + $strConfigNewLine +
        (@(
                '[validator_literal_string_fixture]'
                "content = '''"
                $objMaximumMatch.Value
                $strGitHubPluginTableHeader
                'enabled = false'
                "'''"
            ) -join $strConfigNewLine)
    Assert-FixtureAccepted `
        -Name 'later multiline literal string contains configuration-like lines' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strLaterLiteralStringConfig
    Assert-MutationRejected `
        -Name 'disabled plugin with later multiline literal string' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent (ConvertTo-DisabledGitHubPluginMutation `
            -Content $strLaterLiteralStringConfig) `
        -ExpectedFailure 'The github@openai-curated plugin table must declare enabled = true exactly once.'

    $intCurrentBytes = [System.Text.Encoding]::UTF8.GetByteCount($strAgentsContent)
    $intDefaultFillerLength = [Math]::Max(1, 32768 - $intCurrentBytes + 1)
    Assert-MutationRejected `
        -Name 'ordinary Codex limit exceeded' `
        -AgentsContent ($strAgentsContent + ('x' * $intDefaultFillerLength)) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md must not exceed the ordinary 32768-byte Codex limit.'

    $intMaximumBytes = [int64]$objMaximumBytesGroup.Value
    $intFillerLength = [Math]::Max(1, $intMaximumBytes - $intCurrentBytes - 16384 + 1)
    Assert-MutationRejected `
        -Name 'consumed capacity reserve' `
        -AgentsContent ($strAgentsContent + ('x' * $intFillerLength)) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'Configured AGENTS.md capacity must retain at least 16384 bytes of reserve.'

    foreach ($objSafetyLimitContract in $script:arrSafetyLimitContracts) {
        $strSafetyDocumentContent = if ($objSafetyLimitContract.DocumentName -ceq 'AGENTS.md') {
            $strAgentsContent
        }
        else {
            $strClaudeContent
        }
        $strHtmlOnlySafetyLimit = '<pre>' + [Environment]::NewLine +
            $objSafetyLimitContract.StructuralLiteral + [Environment]::NewLine +
            '</pre>' + [Environment]::NewLine +
            $objSafetyLimitContract.WeakStructuralLiteral
        $strSafetyLimitMutation = $strSafetyDocumentContent.Replace(
            $objSafetyLimitContract.StructuralLiteral,
            $strHtmlOnlySafetyLimit
        )
        if ($objSafetyLimitContract.DocumentName -ceq 'AGENTS.md') {
            Assert-MutationRejected `
                -Name "AGENTS safety limit hidden in raw HTML: $($objSafetyLimitContract.ProseLiteral)" `
                -AgentsContent $strSafetyLimitMutation `
                -ClaudeContent $strClaudeContent `
                -CodexConfigContent $strCodexConfigContent `
                -ExpectedFailure $objSafetyLimitContract.Failure
        }
        else {
            Assert-MutationRejected `
                -Name "CLAUDE safety limit hidden in raw HTML: $($objSafetyLimitContract.ProseLiteral)" `
                -AgentsContent $strAgentsContent `
                -ClaudeContent $strSafetyLimitMutation `
                -CodexConfigContent $strCodexConfigContent `
                -ExpectedFailure $objSafetyLimitContract.Failure
        }
    }

    Assert-MutationRejected `
        -Name 'weakened Codex round cap' `
        -AgentsContent $strAgentsContent.Replace('**Maximum rounds:** 8', '**Maximum rounds:** 80') `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md is missing required Codex marker: **Maximum rounds:** 8'

    Assert-MutationRejected `
        -Name 'weakened Claude round cap' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent.Replace('**Maximum rounds:** 80', '**Maximum rounds:** 800') `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'CLAUDE.md is missing the 80-round Claude limit.'

    Assert-MutationRejected `
        -Name 'punctuated Codex round cap' `
        -AgentsContent $strAgentsContent.Replace('**Maximum rounds:** 8', '**Maximum rounds:** 8,000') `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md is missing required Codex marker: **Maximum rounds:** 8'

    Assert-MutationRejected `
        -Name 'qualified Codex wall-clock limit' `
        -AgentsContent $strAgentsContent.Replace(
            '**Wall-clock timeout:** 6 hours from cycle start.',
            '**Wall-clock timeout:** 6 hours minimum from cycle start.'
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'AGENTS.md is missing the 6-hour Codex wall-clock limit.'

    Assert-MutationRejected `
        -Name 'punctuated Claude round cap' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent.Replace('**Maximum rounds:** 80', '**Maximum rounds:** 80,000') `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'CLAUDE.md is missing the 80-round Claude limit.'

    Assert-MutationRejected `
        -Name 'qualified Claude wall-clock limit' `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent.Replace(
            '**Wall-clock timeout:** 6 hours from loop start.',
            '**Wall-clock timeout:** 6 hours minimum from loop start.'
        ) `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'CLAUDE.md is missing the 6-hour Claude wall-clock limit.'

    Write-Output 'Agent-instruction mutation self-tests passed.'
    #endregion Mutation self-tests
}
