# .SYNOPSIS
# Verifies Codex capacity and shared Claude/Codex instruction capabilities.
#
# .DESCRIPTION
# Confirms that AGENTS.md fits the configured Codex read limit with reserve,
# that trusted project configuration enables the preferred GitHub plugin, that both
# entry points retain portable review, placement, and deferral contracts, and
# that platform safety markers remain present. Optional self-tests prove that
# representative mutations fail closed.
#
# .PARAMETER SelfTest
# Runs in-memory negative tests after the repository files pass validation.
#
# .PARAMETER RequireStagedInputMatch
# Requires each staged validator input to match the worktree content that the
# validator reads. Use this mode from pre-commit.
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
# .PARAMETER RangeComparisonMode
# Selects merge-base comparison for pull requests and synthetic ranges, or
# authenticated published-endpoint comparison for an existing direct push.
#
# .PARAMETER AutomatedMergeSourceRevision
# The authenticated pull-request head for a one-parent automated merge result.
# The empty default disables that narrowly proved transition mode.
#
# .PARAMETER TrustedFinalizationTimestamp
# The authenticated publication or finalization time for event-range validation.
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
# Version: 1.3.20260912.3

[CmdletBinding(PositionalBinding = $false)]
[OutputType([string])]
param(
    [Parameter()]
    [switch] $SelfTest,

    [Parameter()]
    [switch] $RequireStagedInputMatch,

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
    [switch] $RangeIsNewRef,

    [Parameter()]
    [ValidateSet('MergeBase', 'PublishedEndpoints')]
    [string] $RangeComparisonMode = 'MergeBase',

    [Parameter()]
    [AllowEmptyString()]
    [string] $AutomatedMergeSourceRevision = '',

    [Parameter()]
    [AllowEmptyString()]
    [string] $TrustedFinalizationTimestamp = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$intAgentsMaximumInputBytes = 65536
$intClaudeMaximumInputBytes = 131072
$intCodexConfigMaximumInputBytes = 65536
$intDocumentClassificationMaximumInputBytes = 32768
$intDocsInstructionsMaximumInputBytes = 131072
$intInstructionDocumentMaximumInputBytes = 131072
$intValidatorMaximumInputBytes = 786432
$intMetadataMaximumParents = 64
$strMetadataRangePolicyMarker = 'metadata-range-transition-policy-v1'
$script:objValidationUtcNow = [DateTimeOffset]::UtcNow
$script:strMaximumMetadataUtcDate = $script:objValidationUtcNow.ToString('yyyy-MM-dd')
$script:objMaximumCommitUtcTimestamp = $script:objValidationUtcNow.AddMinutes(5)
$script:objPython312CommandContext = $null
$script:objNodeApplicationContext = $null
$script:hashtableReviewedAgentSetupSha256 = @{
    '.github/workflows/copilot-setup-steps.yml' =
        'ef89f6f6265371880caad3eeb126ca33698923e8c7bc46c49ca754e6313df226'
    '.github/workflows/package.json' =
        'c6db6befda88e58aa5568f52f44ca934af5751e545dba0644297b9fb15577e0d'
    '.github/workflows/package-lock.json' =
        '84cbe61e33e4c66b653efd2bfbe3f80b0061368a64ad80ef0de4898da28d887d'
    '.husky/pre-commit' =
        '8989ab5075c077599a6dea88e656ac2837af4800e0bb5daef364514f00255467'
    '.github/workflows/lint-staged-markdown.mjs' =
        '6e8ac89afb17dd36f1edcf9b59ddfb066706fc6686be22e007c540ae20c810c2'
    '.pre-commit-config.yaml' =
        '0e9da6a7c4bd0d89c83fd3041e67921e3bc08d159f4b6cd36b1b2e9f0b63a37b'
}
$script:strWorkflowPolicyCommandPrefix =
    'node .github/workflows/Validate-WorkflowPolicy.mjs'

if ($RequireStagedInputMatch -and (
        -not [string]::IsNullOrEmpty($InputRevision) -or
        -not [string]::IsNullOrEmpty($RangeBaseRevision) -or
        -not [string]::IsNullOrEmpty($RangeHeadRevision) -or
        $RangeIsNewRef -or
        $RangeComparisonMode -ne 'MergeBase' -or
        -not [string]::IsNullOrEmpty($AutomatedMergeSourceRevision) -or
        -not [string]::IsNullOrEmpty($TrustedFinalizationTimestamp)
    )) {
    throw 'Staged-input matching cannot be combined with event-range validation.'
}
$script:strWorkflowPolicyCommand = $script:strWorkflowPolicyCommandPrefix +
    ' .github/workflows/build.yml .github/workflows/markdownlint.yml'
$script:hashtableLegacyMetadataParentSha256 = @{
    'CLAUDE.md' = '28e77152391d51aed5ba93c59ed79af7f5c516d5ee0f1af2ce13cd4842e26387'
    '.claude/commands/review-loop.md' =
        '0deae99c3c8ced1fded917af0c71f4ab2125dcc713088fa4c104f74c7867131a'
    '.github/workflows/MARKDOWN-LINTING-IMPLEMENTATION.md' =
        'fae26a5d050b70311594d51b175f73d01b355f2c1f082a7c646fdb2f018c49d0'
    '.github/workflows/scripts-README.md' =
        '9cfd7038a8d4aaa540f33860e8a3dfd356fbafaef8117c470a1702c21a5a76a2'
    'STYLE_GUIDE_RATIONALE.md' =
        'cbd625dc72a051d814abbb1cd0cb4ad34634ad3611069db242e7c1950dbba1d5'
    'docs/ISSUE_EVALUATION_PROMPT.md' =
        '86f765d6a185b1aad93b6cefee4b211233e36197fca822c2734be2b27a260703'
    'docs/T1-SUPPLY-FREEZE-v1.md' =
        '28ef3ea522c676a9fe3f8522331a1d82dd1d0fd38a6a6569332544fa5d6365a1'
    'docs/decisions/0001-accept-generated-artifact-lint-lag.md' =
        '5978df44197fe113ca91166d18f2b393a956e7dc46681aa1e078e4382114e35a'
    'docs/decisions/0002-accept-repository-code-in-the-write-enabled-job.md' =
        'a23525f4b5aebba2a73c25abd2fe231916ec43feb6f49d512e095c3b1b05ed50'
    'docs/decisions/0003-accept-required-check-workflow-edit-residual.md' =
        'c4ac1757ef081ff085f2e5c112682181b97d3d202acd9418253ac63c1d492f97'
}
$script:strLegacyProcessParentRevision =
    '497e8fb655e10a3e4fd43b6ad543b48f11e9f0ad'
$script:arrAllowedMetadataStatuses = @(
    'Draft', 'Proposed', 'Active', 'Accepted', 'Superseded', 'Deprecated'
)
$script:arrAllowedDecisionRecordStatuses = @(
    'Proposed', 'Accepted', 'Superseded', 'Deprecated'
)
$script:arrCheckoutAttributePaths = @(
    '.gitattributes',
    '.github/.gitattributes',
    '.github/workflows/.gitattributes'
)
$script:arrTrustRootPaths = @(
    $script:arrCheckoutAttributePaths
    '.github/workflows/Resolve-AgentInstructionFinalizationTime.mjs',
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

function Get-StagedInputMatchFailure {
    # .SYNOPSIS
    # Finds a staged-input content mismatch.
    #
    # .DESCRIPTION
    # Compares the exact decoded worktree and Git index content when a staged
    # input is part of the candidate commit.
    #
    # .PARAMETER DisplayName
    # The input name to include in a failure record.
    #
    # .PARAMETER RequireMatch
    # Indicates that the input has a staged candidate that must match.
    #
    # .PARAMETER WorktreeContent
    # The strict UTF-8 content read from the worktree.
    #
    # .PARAMETER IndexContent
    # The strict UTF-8 content read from the stage-0 Git index blob.
    #
    # .EXAMPLE
    # Get-StagedInputMatchFailure -DisplayName 'AGENTS.md' -RequireMatch `
    #     -WorktreeContent $strWorktree -IndexContent $strIndex
    #
    # # Writes one failure when the staged and worktree content differ.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] A staged-input mismatch record.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260912.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $DisplayName,

        [Parameter()]
        [switch] $RequireMatch,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $WorktreeContent,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $IndexContent
    )

    if ($RequireMatch -and -not [string]::Equals(
            $WorktreeContent,
            $IndexContent,
            [System.StringComparison]::Ordinal
        )) {
        Write-Output (
            "$DisplayName worktree content must match its staged Git index blob."
        )
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
    #     -MaximumBytes 65536 -DisplayName 'AGENTS.md')
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
    # .PARAMETER RequireIndexContentMatch
    # Requires the worktree content to equal the stage-0 Git index blob.
    #
    # .EXAMPLE
    # $arrBytes = @(Read-RepositoryInputData -Path $strPath `
    #     -RepositoryRootPath $strRoot -RepositoryRelativePath 'AGENTS.md' `
    #     -DisplayName 'AGENTS.md' -MaximumBytes 65536)
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
    # Version: 1.2.20260912.0
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
        [int] $MaximumBytes,

        [Parameter()]
        [switch] $RequireIndexContentMatch
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

    $strResolvedRepositoryRootPath = [System.IO.Path]::GetFullPath(
        $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
            $RepositoryRootPath
        )
    )
    $strResolvedInputPath = [System.IO.Path]::GetFullPath(
        $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    )
    $objPathComparison = if ([System.OperatingSystem]::IsWindows()) {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }
    $strRepositoryBoundary = $strResolvedRepositoryRootPath
    if (-not $strRepositoryBoundary.EndsWith(
            [System.IO.Path]::DirectorySeparatorChar
        ) -and
        -not $strRepositoryBoundary.EndsWith(
            [System.IO.Path]::AltDirectorySeparatorChar
        )) {
        $strRepositoryBoundary += [System.IO.Path]::DirectorySeparatorChar
    }
    $strExpectedInputPath = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine(
            $strResolvedRepositoryRootPath,
            $RepositoryRelativePath.Replace(
                [System.IO.Path]::AltDirectorySeparatorChar,
                [System.IO.Path]::DirectorySeparatorChar
            )
        )
    )
    if ([System.IO.Path]::IsPathRooted($RepositoryRelativePath) -or
        $RepositoryRelativePath -match '(^|[\\/])\.{1,2}([\\/]|$)' -or
        -not $strExpectedInputPath.StartsWith(
            $strRepositoryBoundary,
            $objPathComparison
        ) -or
        -not $strExpectedInputPath.Equals(
            $strResolvedInputPath,
            $objPathComparison
        )) {
        throw "Repository input is unsafe:`n- $DisplayName must resolve below the repository root."
    }
    $strCurrentAncestorPath = [System.IO.Path]::GetDirectoryName(
        $strExpectedInputPath
    )
    while (-not [string]::IsNullOrEmpty($strCurrentAncestorPath) -and
        -not $strCurrentAncestorPath.Equals(
            $strResolvedRepositoryRootPath,
            $objPathComparison
        )) {
        if (-not $strCurrentAncestorPath.StartsWith(
                $strRepositoryBoundary,
                $objPathComparison
            )) {
            throw "Repository input is unsafe:`n- $DisplayName must resolve below the repository root."
        }
        $objAncestorItem = Get-Item -Force -LiteralPath $strCurrentAncestorPath
        $objAncestorLinkTypeProperty =
            $objAncestorItem.PSObject.Properties['LinkType']
        $strAncestorLinkType = if ($null -eq $objAncestorLinkTypeProperty) {
            ''
        }
        else {
            [string] $objAncestorLinkTypeProperty.Value
        }
        if ($objAncestorItem -isnot [System.IO.DirectoryInfo] -or
            ($objAncestorItem.Attributes -band
                [System.IO.FileAttributes]::ReparsePoint) -ne 0 -or
            -not [string]::IsNullOrEmpty($strAncestorLinkType)) {
            $strUnsafeAncestor = [System.IO.Path]::GetRelativePath(
                $strResolvedRepositoryRootPath,
                $strCurrentAncestorPath
            ).Replace([System.IO.Path]::DirectorySeparatorChar, '/')
            throw (
                "Repository input is unsafe:`n- $DisplayName must not traverse " +
                "a symbolic link or reparse point: $strUnsafeAncestor."
            )
        }
        $strParentAncestorPath = [System.IO.Path]::GetDirectoryName(
            $strCurrentAncestorPath
        )
        if ([string]::IsNullOrEmpty($strParentAncestorPath) -or
            $strParentAncestorPath.Equals(
                $strCurrentAncestorPath,
                $objPathComparison
            )) {
            throw "Repository input is unsafe:`n- $DisplayName has an invalid parent path."
        }
        $strCurrentAncestorPath = $strParentAncestorPath
    }
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
        [byte[]] $arrInputData = @(Read-BoundedStreamData `
            -Stream $objInputStream `
            -MaximumBytes $MaximumBytes `
            -DisplayName $DisplayName)
    }
    finally {
        $objInputStream.Dispose()
    }

    if ($RequireIndexContentMatch) {
        $strWorktreeContent = ConvertFrom-StrictUtf8Data `
            -Bytes $arrInputData `
            -DisplayName $DisplayName
        $strIndexContent = Read-GitRevisionText `
            -RepositoryRootPath $RepositoryRootPath `
            -Revision '' `
            -RepositoryRelativePath $RepositoryRelativePath `
            -MaximumBytes $MaximumBytes
        $arrStagedInputFailures = @(Get-StagedInputMatchFailure `
                -DisplayName $DisplayName `
                -RequireMatch `
                -WorktreeContent $strWorktreeContent `
                -IndexContent $strIndexContent)
        if ($arrStagedInputFailures.Count -gt 0) {
            throw (
                "Repository input is unsafe:`n- " +
                ($arrStagedInputFailures -join "`n- ")
            )
        }
    }

    return $arrInputData
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
    # The commit or tree revision that contains the file. An empty value selects
    # the stage-0 Git index entry when RequireRegularFile is not set.
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
    #     -RepositoryRelativePath 'AGENTS.md' -MaximumBytes 65536
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
    # Version: 1.2.20260912.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $RepositoryRootPath,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Revision,

        [Parameter(Mandatory)]
        [string] $RepositoryRelativePath,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483646)]
        [int] $MaximumBytes,

        [Parameter()]
        [switch] $RequireRegularFile
    )

    if ($RequireRegularFile -and [string]::IsNullOrEmpty($Revision)) {
        throw 'A regular-file revision lookup requires a commit or tree.'
    }
    if ($RequireRegularFile) {
        $objTreeEntry = Get-GitRevisionTreeEntryContext `
            -RepositoryRootPath $RepositoryRootPath `
            -Revision $Revision `
            -RepositoryRelativePath $RepositoryRelativePath
        if ($null -eq $objTreeEntry -or
            $objTreeEntry.Mode -cne '100644' -or
            $objTreeEntry.Type -cne 'blob' -or
            $objTreeEntry.Path -cne $RepositoryRelativePath) {
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

function Invoke-GitNulRecordQuery {
    # .SYNOPSIS
    # Reads one bounded list of NUL-delimited UTF-8 records from Git.
    #
    # .DESCRIPTION
    # Invokes Git without a shell, bounds standard output, requires a trailing
    # NUL terminator, and returns strict UTF-8 records without pathname quoting.
    # The supplied Git arguments must select a NUL-delimited output mode.
    #
    # .PARAMETER RepositoryRootPath
    # The absolute repository root path used by Git.
    #
    # .PARAMETER Argument
    # The Git arguments after the repository-root selection.
    #
    # .PARAMETER DisplayName
    # The operation name used in bounded-output and failure messages.
    #
    # .PARAMETER MaximumBytes
    # The largest accepted standard-output byte count.
    #
    # .EXAMPLE
    # Invoke-GitNulRecordQuery -RepositoryRootPath $strRoot `
    #     -Argument @('ls-files', '--cached', '-z') -DisplayName 'tracked paths'
    #
    # # Returns each tracked path without Git pathname quoting.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string[]] The decoded records, without NUL terminators.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260910.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string] $RepositoryRootPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Argument,

        [Parameter(Mandatory)]
        [string] $DisplayName,

        [Parameter()]
        [ValidateRange(1, 2147483646)]
        [int] $MaximumBytes = 16777216
    )

    $objStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $objStartInfo.FileName = 'git'
    $objStartInfo.UseShellExecute = $false
    $objStartInfo.CreateNoWindow = $true
    $objStartInfo.RedirectStandardOutput = $true
    $objStartInfo.RedirectStandardError = $true
    foreach ($strArgument in @('-C', $RepositoryRootPath) + $Argument) {
        $objStartInfo.ArgumentList.Add($strArgument)
    }

    $objGitProcess = [System.Diagnostics.Process]::new()
    $objGitProcess.StartInfo = $objStartInfo
    try {
        if (-not $objGitProcess.Start()) {
            throw "Could not start Git to enumerate $DisplayName."
        }
        $objStandardErrorTask = $objGitProcess.StandardError.ReadToEndAsync()
        $arrOutputBytes = Read-BoundedStreamData `
            -Stream $objGitProcess.StandardOutput.BaseStream `
            -MaximumBytes $MaximumBytes `
            -DisplayName $DisplayName
        if (-not $objGitProcess.WaitForExit(10000)) {
            $objGitProcess.Kill($true)
            [void]$objGitProcess.WaitForExit(1000)
            throw "Git timed out while enumerating $DisplayName."
        }
        [void]$objStandardErrorTask.GetAwaiter().GetResult()
        if ($objGitProcess.ExitCode -ne 0) {
            throw "Could not enumerate $DisplayName with Git."
        }
        if ($null -eq $arrOutputBytes -or $arrOutputBytes.Count -eq 0) {
            return [string[]] @()
        }
        if ($arrOutputBytes[$arrOutputBytes.Count - 1] -ne 0) {
            throw "Git returned a non-NUL-terminated $DisplayName stream."
        }

        $strOutput = ConvertFrom-StrictUtf8Data `
            -Bytes $arrOutputBytes `
            -DisplayName $DisplayName
        $arrRecordsWithTerminator = @($strOutput.Split([char] 0))
        if ($arrRecordsWithTerminator.Count -lt 2 -or
            $arrRecordsWithTerminator[-1] -cne '') {
            throw "Git returned a malformed $DisplayName stream."
        }
        $arrRecords = @($arrRecordsWithTerminator[0..($arrRecordsWithTerminator.Count - 2)])
        if (@($arrRecords | Where-Object { [string]::IsNullOrEmpty([string] $_) }).Count -gt 0) {
            throw "Git returned an empty record in the $DisplayName stream."
        }
        return [string[]] $arrRecords
    }
    finally {
        $objGitProcess.Dispose()
    }
}

function Get-GitRevisionTreeEntryContext {
    # .SYNOPSIS
    # Gets one exact, unquoted Git tree entry.
    #
    # .DESCRIPTION
    # Uses bounded NUL-delimited Git output so that pathnames retain their exact
    # UTF-8 text. Returns null when the path is absent. Malformed or duplicate
    # records fail closed.
    #
    # .PARAMETER RepositoryRootPath
    # The absolute repository root path used by Git.
    #
    # .PARAMETER Revision
    # The commit or tree revision to inspect.
    #
    # .PARAMETER RepositoryRelativePath
    # The exact repository-relative path to inspect.
    #
    # .EXAMPLE
    # Get-GitRevisionTreeEntryContext -RepositoryRootPath $strRoot `
    #     -Revision 'HEAD' -RepositoryRelativePath 'module/AGENTS.md'
    #
    # # Returns the exact mode, type, object ID, and unquoted path.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] The exact tree entry, or null when the path is absent.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260911.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $RepositoryRootPath,

        [Parameter(Mandatory)]
        [string] $Revision,

        [Parameter(Mandatory)]
        [string] $RepositoryRelativePath
    )

    $arrTreeRecords = @(
        Invoke-GitNulRecordQuery `
            -RepositoryRootPath $RepositoryRootPath `
            -Argument @(
                'ls-tree', '--full-tree', '-z',
                $Revision, '--', $RepositoryRelativePath
            ) `
            -DisplayName "$Revision`:$RepositoryRelativePath tree entry"
    )
    if ($arrTreeRecords.Count -eq 0) {
        return
    }
    if ($arrTreeRecords.Count -ne 1) {
        throw "Git returned multiple tree entries for $Revision`:$RepositoryRelativePath."
    }

    $objTreeEntryMatch = [regex]::Match(
        [string] $arrTreeRecords[0],
        '\A(?<Mode>[0-9]{6}) (?<Type>[a-z]+) ' +
            '(?<ObjectId>(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64}))\t' +
            '(?<Path>(?s:.*))\z'
    )
    if (-not $objTreeEntryMatch.Success) {
        throw "Git returned a malformed tree entry for $Revision`:$RepositoryRelativePath."
    }

    return [pscustomobject]@{
        Mode = $objTreeEntryMatch.Groups['Mode'].Value
        Type = $objTreeEntryMatch.Groups['Type'].Value
        ObjectId = $objTreeEntryMatch.Groups['ObjectId'].Value
        Path = $objTreeEntryMatch.Groups['Path'].Value
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
    #     -MaximumBytes 65536 -Literal 'metadata-range-transition-policy-v1'
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

function Get-GovernedDocumentParentContext {
    # .SYNOPSIS
    # Gets the comparison context for one governed document.
    #
    # .DESCRIPTION
    # Selects the worktree comparison source or the first parent of an explicit
    # input revision and derives the applicable UTC metadata date. A local
    # worktree baseline is the direct parent for both clean and dirty snapshots.
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
    # .PARAMETER LocalBaselineRevision
    # The verified checked-out commit used for local no-range validation.
    #
    # .EXAMPLE
    # Get-GovernedDocumentParentContext -RepositoryRootPath $strRoot `
    #     -RepositoryRelativePath 'AGENTS.md' -MaximumBytes 65536
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
    # Version: 1.4.20260911.0
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
        [string] $LocalBaselineRevision = ''
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
            UsesLocalBaseline = $false
        }
    }

    if (-not [string]::IsNullOrEmpty($LocalBaselineRevision)) {
        if ($LocalBaselineRevision -notmatch
            '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
            throw "The local baseline commit is invalid: $LocalBaselineRevision"
        }
        & git -C $RepositoryRootPath cat-file -e `
            "$LocalBaselineRevision`^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "The local baseline commit is unavailable: $LocalBaselineRevision"
        }
        & git -C $RepositoryRootPath diff --quiet HEAD -- $RepositoryRelativePath
        $intDiffExitCode = $LASTEXITCODE
        if ($intDiffExitCode -notin @(0, 1)) {
            throw "Could not compare $RepositoryRelativePath with HEAD."
        }
        $strParentRevision = $LocalBaselineRevision
        $strExpectedUtcDate = if ($intDiffExitCode -eq 1) {
            $script:strMaximumMetadataUtcDate
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
            UsesLocalBaseline = $true
        }
    }

    & git -C $RepositoryRootPath diff --quiet HEAD -- $RepositoryRelativePath
    $intDiffExitCode = $LASTEXITCODE
    if ($intDiffExitCode -notin @(0, 1)) {
        throw "Could not compare $RepositoryRelativePath with HEAD."
    }

    if ($intDiffExitCode -eq 1) {
        $strParentRevision = 'HEAD'
        $strExpectedUtcDate = $script:strMaximumMetadataUtcDate
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
        UsesLocalBaseline = $false
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
    # .PARAMETER WorkflowPackageLockContent
    # The workflow-local package-lock.json text installed before hook activation.
    #
    # .PARAMETER HookContent
    # The `.husky/pre-commit` text that contains the staged-file guard.
    #
    # .PARAMETER CopilotSetupContent
    # The Copilot setup workflow text that activates the retained hook.
    #
    # .PARAMETER PreCommitConfigContent
    # The pre-commit configuration text executed by the setup workflow.
    #
    # .PARAMETER StagedMarkdownHelperContent
    # The staged-Markdown helper text executed by the retained hook.
    #
    # .EXAMPLE
    # Get-HuskySetupContractFailure -RootPackageContent $strRootPackage `
    #     -WorkflowPackageContent $strWorkflowPackage `
    #     -WorkflowPackageLockContent $strWorkflowLock -HookContent $strHook `
    #     -CopilotSetupContent $strCopilotSetup `
    #     -PreCommitConfigContent $strPreCommitConfig `
    #     -StagedMarkdownHelperContent $strStagedMarkdownHelper
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
    # Version: 1.15.20260911.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $RootPackageContent,

        [Parameter(Mandatory)]
        [string] $WorkflowPackageContent,

        [Parameter(Mandatory)]
        [string] $WorkflowPackageLockContent,

        [Parameter(Mandatory)]
        [string] $HookContent,

        [Parameter(Mandatory)]
        [string] $CopilotSetupContent,

        [Parameter(Mandatory)]
        [string] $PreCommitConfigContent,

        [Parameter(Mandatory)]
        [string] $StagedMarkdownHelperContent
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
    $strExpectedRootOuterLint = 'npm --prefix .github/workflows run lint:md'
    if ([string]$objRootPackage.scripts.'lint:md' -cne $strExpectedRootOuterLint) {
        Write-Output 'Root lint:md must delegate to the workflow-local lint:md script.'
    }
    $strExpectedRootNestedLint = 'npm --prefix .github/workflows run lint:md:nested'
    if ([string]$objRootPackage.scripts.'lint:md:nested' -cne $strExpectedRootNestedLint) {
        Write-Output 'Root lint:md:nested must delegate to the workflow-local lint:md:nested script.'
    }
    $strExpectedWorkflowOuterLint =
        'cd ../.. && node .github/workflows/lint-nested-markdown.js --outer'
    if ([string]$objWorkflowPackage.scripts.'lint:md' -cne
        $strExpectedWorkflowOuterLint) {
        Write-Output (
            'Workflow lint:md must run only the reviewed outer Markdown lint phase.'
        )
    }
    $strExpectedRootAgentTest =
        'pwsh -NoLogo -NoProfile -NonInteractive -File ' +
        '.github/workflows/Test-AgentInstructions.ps1 -SelfTest'
    if ([string]$objRootPackage.scripts.'test:agent-instructions' -cne
        $strExpectedRootAgentTest) {
        Write-Output (
            'Root test:agent-instructions must invoke the reviewed agent validator.'
        )
    }
    foreach ($strForbiddenRootLintDependency in @('markdownlint', 'markdownlint-cli2')) {
        if ($null -ne $objRootPackage.devDependencies.PSObject.Properties[
                $strForbiddenRootLintDependency
            ]) {
            Write-Output (
                "Root package must not declare direct $strForbiddenRootLintDependency " +
                'because the workflow-local package owns Markdown linting.'
            )
        }
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
    $strExpectedStagedMarkdownSelector =
        '        files: ^(\.github/workflows/lint-staged-markdown\.mjs|.*\.(md|mdc))$'
    if ([regex]::Matches(
            $PreCommitConfigContent,
            '(?m)^' + [regex]::Escape($strExpectedStagedMarkdownSelector) + '\r?$'
        ).Count -ne 1) {
        Write-Output 'The staged-Markdown hook must select Markdown and helper-only changes.'
    }
    $strExpectedStagedInputEntry =
        '          .github/workflows/Test-AgentInstructions.ps1 -SelfTest ' +
        '-RequireStagedInputMatch'
    if ([regex]::Matches(
            $PreCommitConfigContent,
            '(?m)^' + [regex]::Escape($strExpectedStagedInputEntry) + '\r?$'
        ).Count -ne 1) {
        Write-Output (
            'The agent-instruction hook must require staged input matching.'
        )
    }
    $strExpectedYamlSelector = '        files: ^.*\.ya?ml$'
    foreach ($strYamlHookId in @('check-yaml', 'yamllint')) {
        $objYamlHook = [regex]::Match(
            $PreCommitConfigContent,
            "(?ms)^      - id: $([regex]::Escape($strYamlHookId))\r?\n" +
            '(?<Body>.*?)(?=^      - id:|^  - repo:|\z)'
        )
        if (-not $objYamlHook.Success -or
            [regex]::Matches(
                $objYamlHook.Groups['Body'].Value,
                '(?m)^' + [regex]::Escape($strExpectedYamlSelector) + '\r?$'
            ).Count -ne 1) {
            Write-Output "The $strYamlHookId hook must select all repository YAML files."
        }
    }
    $strClassificationSelector =
        '            \.github/document-metadata-classification\.json'
    foreach ($strClassificationHookId in @(
            'check-json',
            'end-of-file-fixer',
            'trailing-whitespace'
        )) {
        $objClassificationHook = [regex]::Match(
            $PreCommitConfigContent,
            "(?ms)^      - id: $([regex]::Escape($strClassificationHookId))\r?\n" +
            '(?<Body>.*?)(?=^      - id:|^  - repo:|\z)'
        )
        if (-not $objClassificationHook.Success -or
            [regex]::Matches(
                $objClassificationHook.Groups['Body'].Value,
                '(?m)^' + [regex]::Escape($strClassificationSelector) + '\r?$'
            ).Count -ne 1) {
            Write-Output (
                "The $strClassificationHookId hook must select " +
                '.github/document-metadata-classification.json.'
            )
        }
    }
    $arrRepositoryBlocks = @([regex]::Matches(
            $PreCommitConfigContent,
            '(?ms)^  - repo: (?<Repository>[^\r\n]+)\r?\n' +
            '(?<Body>.*?)(?=^  - repo:|\z)'
        ))
    $arrLocalRepositoryBlocks = @($arrRepositoryBlocks | Where-Object {
            $_.Groups['Repository'].Value -ceq 'local'
        })
    $arrRemoteRepositoryBlocks = @($arrRepositoryBlocks | Where-Object {
            $_.Groups['Repository'].Value -cne 'local'
        })
    if ($arrRepositoryBlocks.Count -ne 3 -or
        $arrLocalRepositoryBlocks.Count -ne 2 -or
        $arrRemoteRepositoryBlocks.Count -ne 1) {
        Write-Output (
            'Pre-commit must use two local hook groups and only one reviewed ' +
            'remote hook repository.'
        )
    }
    $strExpectedActionlintRepository = 'https://github.com/rhysd/actionlint'
    $strExpectedActionlintRevision = '011a6d15e749bb3f2d771eed9c7aa0e7e3e10ee7'
    if ($arrRemoteRepositoryBlocks.Count -ne 1 -or
        $arrRemoteRepositoryBlocks[0].Groups['Repository'].Value -cne
            $strExpectedActionlintRepository -or
        [regex]::Matches(
            $arrRemoteRepositoryBlocks[0].Groups['Body'].Value,
            '(?m)^    rev: "' + [regex]::Escape($strExpectedActionlintRevision) +
            '"(?: # [^\r\n]+)?\r?$'
        ).Count -ne 1 -or
        [regex]::Matches(
            $arrRemoteRepositoryBlocks[0].Groups['Body'].Value,
            '(?m)^      - id: actionlint\r?$'
        ).Count -ne 1 -or
        [regex]::Matches(
            $arrRemoteRepositoryBlocks[0].Groups['Body'].Value,
            '(?m)^      - id:'
        ).Count -ne 1) {
        Write-Output (
            "Pre-commit hook repository $strExpectedActionlintRepository must " +
            "use reviewed full commit $strExpectedActionlintRevision and contain " +
            'only actionlint.'
        )
    }
    if ([regex]::Matches(
            $PreCommitConfigContent,
            '(?m)^        (?:language: python|additional_dependencies:)\r?$'
        ).Count -ne 0) {
        Write-Output 'Python pre-commit hooks must not resolve separate environments.'
    }
    $hashtableExpectedLockedPythonHookModule = [ordered]@{
        'check-json' = 'pre_commit_hooks.check_json'
        'check-yaml' = 'pre_commit_hooks.check_yaml'
        'end-of-file-fixer' = 'pre_commit_hooks.end_of_file_fixer'
        'trailing-whitespace' = 'pre_commit_hooks.trailing_whitespace_fixer'
        yamllint = 'yamllint'
        'check-dependabot' = 'check_jsonschema'
        'check-github-workflows' = 'check_jsonschema'
    }
    foreach ($objLockedPythonHook in
        $hashtableExpectedLockedPythonHookModule.GetEnumerator()) {
        $arrLockedPythonHook = @([regex]::Matches(
                $PreCommitConfigContent,
                "(?ms)^      - id: $([regex]::Escape($objLockedPythonHook.Key))\r?\n" +
                '(?<Body>.*?)(?=^      - id:|^  - repo:|\z)'
            ))
        if ($arrLockedPythonHook.Count -ne 1 -or
            [regex]::Matches(
                $arrLockedPythonHook[0].Groups['Body'].Value,
                '(?m)^          \.github/workflows/Invoke-LockedPythonHook\.ps1\r?$'
            ).Count -ne 1 -or
            [regex]::Matches(
                $arrLockedPythonHook[0].Groups['Body'].Value,
                '(?m)^          -Module ' +
                [regex]::Escape($objLockedPythonHook.Value) + '\r?$'
            ).Count -ne 1 -or
            [regex]::Matches(
                $arrLockedPythonHook[0].Groups['Body'].Value,
                '(?m)^        language: system\r?$'
            ).Count -ne 1) {
            Write-Output (
                "The $($objLockedPythonHook.Key) hook must run module " +
                "$($objLockedPythonHook.Value) from the locked local system environment."
            )
        }
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
    $arrStagedMarkdownExitContractLiterals = @(
        'const normalizeMarkdownlintExitCode = (value) =>',
        '  value === exitStatus.success || value === exitStatus.lintFailure',
        '    : exitStatus.toolingFailure;',
        '  exitCode = normalizeMarkdownlintExitCode(markdownlintExitCode);',
        'if (exitCode === exitStatus.lintFailure) {',
        '} else if (exitCode === exitStatus.success) {'
    )
    foreach ($strStagedMarkdownExitContractLiteral in
        $arrStagedMarkdownExitContractLiterals) {
        if ([regex]::Matches(
                $StagedMarkdownHelperContent,
                '(?m)^' + [regex]::Escape($strStagedMarkdownExitContractLiteral) +
                '\r?$'
            ).Count -ne 1) {
            Write-Output (
                'The staged-Markdown helper must normalize every dependency result ' +
                'to exit status 0, 1, or 2.'
            )
            break
        }
    }

    $hashtableReviewedSetupContent = @{
        '.github/workflows/copilot-setup-steps.yml' = $CopilotSetupContent
        '.github/workflows/package.json' = $WorkflowPackageContent
        '.github/workflows/package-lock.json' = $WorkflowPackageLockContent
        '.husky/pre-commit' = $HookContent
        '.github/workflows/lint-staged-markdown.mjs' = $StagedMarkdownHelperContent
        '.pre-commit-config.yaml' = $PreCommitConfigContent
    }
    $objSha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        foreach ($objReviewedSetupContentEntry in
            $hashtableReviewedSetupContent.GetEnumerator()) {
            $arrReviewedHashBytes = $objSha256.ComputeHash(
                [System.Text.UTF8Encoding]::new($false).GetBytes(
                    $objReviewedSetupContentEntry.Value
                )
            )
            $strReviewedSha256 = [System.BitConverter]::ToString(
                $arrReviewedHashBytes
            ).Replace('-', '').ToLowerInvariant()
            if ($strReviewedSha256 -cne
                $script:hashtableReviewedAgentSetupSha256[
                    $objReviewedSetupContentEntry.Key
                ]) {
                Write-Output (
                    "$($objReviewedSetupContentEntry.Key) text must match the " +
                    'reviewed SHA-256 digest.'
                )
            }
        }
    }
    finally {
        $objSha256.Dispose()
    }

    $hashtableExpectedActionLineCount = @{
        '        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1' = 1
        '        uses: actions/setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97 # v7.0.0' = 1
        '        uses: actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0' = 1
    }
    $arrActionLines = @([regex]::Matches(
            $CopilotSetupContent,
            '(?m)^\s+uses:\s+[^\r\n]+\r?$'
        ))
    if ($arrActionLines.Count -ne 3) {
        Write-Output 'Copilot setup must contain exactly three reviewed action executions.'
    }
    foreach ($objExpectedActionLineCount in
        $hashtableExpectedActionLineCount.GetEnumerator()) {
        if ([regex]::Matches(
                $CopilotSetupContent,
                '(?m)^' + [regex]::Escape($objExpectedActionLineCount.Key) + '\r?$'
            ).Count -ne $objExpectedActionLineCount.Value) {
            Write-Output (
                'Copilot setup must contain the reviewed action line exactly ' +
                "$($objExpectedActionLineCount.Value) time(s): " +
                $objExpectedActionLineCount.Key
            )
        }
    }

    $hashtableExpectedRootInputDigestLine = @{
        'package.json' =
            '            ["${root_manifest}"]=' +
            "'ca77a11a7bd4ae55842ef0f1b8c4b9c0d32e3d6b8fa202455a12e354bf2d696b'"
        'package-lock.json' =
            '            ["${root_lock}"]=' +
            "'e07939c3791be364486aedc928da532870f6d9f29ec2a6a4733be2cc143f5009'"
    }
    foreach ($objRootInputDigestLine in
        $hashtableExpectedRootInputDigestLine.GetEnumerator()) {
        if ([regex]::Matches(
                $CopilotSetupContent,
                '(?m)^' + [regex]::Escape($objRootInputDigestLine.Value) + '\r?$'
            ).Count -ne 1) {
            Write-Output (
                'Copilot setup must authenticate root npm input before installation: ' +
                $objRootInputDigestLine.Key
            )
        }
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

    $strSetupPythonLine =
        '        uses: actions/setup-python@' +
        '5fda3b95a4ea91299a34e894583c3862153e4b97 # v7.0.0'
    if ([regex]::Matches(
            $CopilotSetupContent,
            '(?m)^' + [regex]::Escape($strSetupPythonLine) + '\r?$'
        ).Count -ne 1) {
        Write-Output 'Copilot setup must use the reviewed setup-python v7.0.0 commit once.'
    }
    $arrRequiredPythonSetupLines = @(
        '      # See: https://github.com/actions/setup-python/releases/latest',
        '          python-version: "3.12"',
        '          cache: pip',
        '          cache-dependency-path: requirements-dev.txt',
        '          if [[ ! -f requirements-dev.txt || -L requirements-dev.txt ]]; then',
        '          python -m pip install --requirement requirements-dev.txt',
        '          test "$(python -m pre_commit --version)" = ''pre-commit 4.6.2''',
        '          python -m pip check'
    )
    foreach ($strRequiredPythonSetupLine in $arrRequiredPythonSetupLines) {
        if ([regex]::Matches(
                $CopilotSetupContent,
                '(?m)^' + [regex]::Escape($strRequiredPythonSetupLine) + '\r?$'
            ).Count -ne 1) {
            Write-Output (
                'Copilot setup must contain this locked Python setup line once: ' +
                $strRequiredPythonSetupLine
            )
        }
    }
    $strExpectedPythonInstallSequence = @'
          reviewed_requirements_sha256='f9aaac5456d8c076becff82222a49a3a16ef1267de93d347ebcac0fe3a3f5652'
          test "$(sha256sum requirements-dev.txt | cut -d ' ' -f 1)" \
            = "${reviewed_requirements_sha256}"
          python -m pip install --requirement requirements-dev.txt
'@.TrimEnd()
    if ([regex]::Matches(
            $CopilotSetupContent,
            [regex]::Escape($strExpectedPythonInstallSequence)
        ).Count -ne 1) {
        Write-Output 'Copilot must authenticate requirements before pip installs them.'
    }
    if ([regex]::Matches(
            $CopilotSetupContent,
            '(?m)^            requirements-dev\.txt\r?$'
        ).Count -ne 1) {
        Write-Output (
            'Copilot setup must protect requirements-dev.txt in the immutable-input list.'
        )
    }

    $arrStepHeaders = @([regex]::Matches(
            $CopilotSetupContent,
            '(?m)^      - name: (?<Name>[^\r\n]+)\r?$'
        ))
    $intVerificationStepIndex = -1
    $intActivationStepIndex = -1
    $intPreCommitRunStepIndex = -1
    $intPythonSetupStepIndex = -1
    $intPythonInstallStepIndex = -1
    for ($intStep = 0; $intStep -lt $arrStepHeaders.Count; $intStep++) {
        if ($arrStepHeaders[$intStep].Groups['Name'].Value -ceq
            'Set up Python 3.12') {
            $intPythonSetupStepIndex = $intStep
        }
        if ($arrStepHeaders[$intStep].Groups['Name'].Value -ceq
            'Install locked Python validation tools') {
            $intPythonInstallStepIndex = $intStep
        }
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
        if ($arrStepHeaders[$intStep].Groups['Name'].Value -ceq
            'Run complete repository validation hook set') {
            $intPreCommitRunStepIndex = $intStep
        }
    }
    if ($intVerificationStepIndex -lt 0 -or
        $intActivationStepIndex -ne ($intVerificationStepIndex + 1)) {
        Write-Output 'Copilot hook activation must occur once directly after dependency verification.'
    }
    if ($intPythonSetupStepIndex -lt 0 -or
        $intPythonInstallStepIndex -ne ($intPythonSetupStepIndex + 1)) {
        Write-Output 'Copilot must install locked Python tools directly after Python setup.'
    }
    if ($intPreCommitRunStepIndex -ne ($intActivationStepIndex + 1) -or
        [regex]::Matches(
            $CopilotSetupContent,
            '(?m)^          python -m pre_commit run --all-files\r?$'
        ).Count -ne 1) {
        Write-Output 'Copilot must run the complete pre-commit gate directly after activation.'
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
    # Requires one complete, hash-checked binary-only Python tool lock, an exact
    # PowerShell 7 preflight, and exact interpreter-qualified Windows and POSIX
    # install and run commands in both agent entry points and the workflow script
    # index.
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
    # The requirements-dev.txt text that locks the pre-commit runner closure.
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
    # Version: 1.3.20260911.0
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

    $strNormalizedRequirements = $RequirementsContent.Replace("`r`n", "`n").Replace(
        "`r",
        "`n"
    )
    $hashtableExpectedPythonPackage = [ordered]@{
        attrs = [pscustomobject]@{ Version = '26.1.0'; HashCount = 1 }
        certifi = [pscustomobject]@{ Version = '2026.7.22'; HashCount = 1 }
        cfgv = [pscustomobject]@{ Version = '3.5.0'; HashCount = 1 }
        'charset-normalizer' = [pscustomobject]@{ Version = '3.5.1'; HashCount = 9 }
        'check-jsonschema' = [pscustomobject]@{ Version = '0.37.4'; HashCount = 1 }
        click = [pscustomobject]@{ Version = '8.5.0'; HashCount = 1 }
        distlib = [pscustomobject]@{ Version = '0.4.3'; HashCount = 1 }
        filelock = [pscustomobject]@{ Version = '3.32.6'; HashCount = 1 }
        identify = [pscustomobject]@{ Version = '2.6.19'; HashCount = 1 }
        idna = [pscustomobject]@{ Version = '3.19'; HashCount = 1 }
        jsonschema = [pscustomobject]@{ Version = '4.26.0'; HashCount = 1 }
        'jsonschema-specifications' =
            [pscustomobject]@{ Version = '2025.9.1'; HashCount = 1 }
        nodeenv = [pscustomobject]@{ Version = '1.10.0'; HashCount = 1 }
        pathspec = [pscustomobject]@{ Version = '1.1.1'; HashCount = 1 }
        platformdirs = [pscustomobject]@{ Version = '4.11.8'; HashCount = 1 }
        'pre-commit' = [pscustomobject]@{ Version = '4.6.2'; HashCount = 1 }
        'pre-commit-hooks' = [pscustomobject]@{ Version = '6.0.0'; HashCount = 1 }
        'python-discovery' = [pscustomobject]@{ Version = '1.6.0'; HashCount = 1 }
        pyyaml = [pscustomobject]@{ Version = '6.0.3'; HashCount = 10 }
        referencing = [pscustomobject]@{ Version = '0.37.0'; HashCount = 1 }
        regress = [pscustomobject]@{ Version = '2026.9.1'; HashCount = 10 }
        requests = [pscustomobject]@{ Version = '2.34.2'; HashCount = 1 }
        'rpds-py' = [pscustomobject]@{ Version = '2026.6.3'; HashCount = 10 }
        'ruamel-yaml' = [pscustomobject]@{ Version = '0.19.1'; HashCount = 1 }
        'typing-extensions' = [pscustomobject]@{ Version = '4.16.0'; HashCount = 1 }
        urllib3 = [pscustomobject]@{ Version = '2.7.0'; HashCount = 1 }
        virtualenv = [pscustomobject]@{ Version = '21.7.9'; HashCount = 1 }
        yamllint = [pscustomobject]@{ Version = '1.38.0'; HashCount = 1 }
    }
    $strLockPreamble = "--only-binary=:all:`n--require-hashes`n`n"
    $boolRequirementsLockValid = $strNormalizedRequirements.StartsWith(
        $strLockPreamble,
        [System.StringComparison]::Ordinal
    )
    $strRequirementBody = if ($boolRequirementsLockValid) {
        $strNormalizedRequirements.Substring($strLockPreamble.Length)
    }
    else {
        $strNormalizedRequirements
    }
    $arrRequirementMatches = @([regex]::Matches(
            $strRequirementBody,
            '(?ms)^(?<Name>[a-z][a-z0-9-]*)==(?<Version>[^\s\\]+) \\\n' +
            '(?<Hashes>    --hash=sha256:[0-9a-f]{64}' +
            '(?: \\\n    --hash=sha256:[0-9a-f]{64})*)\n'
        ))
    $strUnparsedRequirementBody = $strRequirementBody
    foreach ($objRequirementMatch in $arrRequirementMatches) {
        $strUnparsedRequirementBody = $strUnparsedRequirementBody.Replace(
            $objRequirementMatch.Value,
            ''
        )
    }
    if ($strUnparsedRequirementBody.Length -ne 0 -or
        $arrRequirementMatches.Count -ne $hashtableExpectedPythonPackage.Count) {
        $boolRequirementsLockValid = $false
    }
    foreach ($objExpectedPackage in $hashtableExpectedPythonPackage.GetEnumerator()) {
        $arrMatchingPackages = @($arrRequirementMatches | Where-Object {
                $_.Groups['Name'].Value -ceq $objExpectedPackage.Key
            })
        if ($arrMatchingPackages.Count -ne 1 -or
            $arrMatchingPackages[0].Groups['Version'].Value -cne
                $objExpectedPackage.Value.Version -or
            [regex]::Matches(
                $arrMatchingPackages[0].Groups['Hashes'].Value,
                '--hash=sha256:[0-9a-f]{64}'
            ).Count -ne $objExpectedPackage.Value.HashCount) {
            $boolRequirementsLockValid = $false
        }
    }
    if (-not $boolRequirementsLockValid) {
        Write-Output (
            'requirements-dev.txt must contain the complete reviewed binary-only ' +
            'Python 3.12 tool closure with SHA-256 hashes.'
        )
    }

    $arrRequiredCommands = @(
        "pwsh -NoProfile -Command 'if (`$PSVersionTable.PSVersion.Major -lt 7) { exit 1 }'",
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
    # Version: 1.3.20260910.0
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
        if ($strLine -match ' {2,}$' -or $strLine -match '\\[ \t]*$') {
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

function Get-GovernedDecisionDocumentPath {
    # .SYNOPSIS
    # Selects Markdown decision records from candidate Git paths.
    #
    # .DESCRIPTION
    # Returns a deterministic, duplicate-free inventory for Markdown below the
    # repository's configured `docs/decisions/` decision-record root.
    #
    # .PARAMETER CandidatePath
    # Repository-relative paths found in the candidate state or event range.
    #
    # .EXAMPLE
    # Get-GovernedDecisionDocumentPath -CandidatePath @(
    #     'docs/user/decisions/provider-selection.md',
    #     'docs/decisions/archive/0003-old.md'
    # )
    #
    # # Returns only the formal decision record.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One repository-relative decision-record path.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.3.20260911.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $CandidatePath
    )

    return @(
        $CandidatePath |
            Where-Object {
                [string]$_ -cmatch '^docs/decisions/(?:[^/]+/)*[^/]+\.md$'
            } |
            Sort-Object -CaseSensitive -Unique
    )
}

function Get-DecisionRecordContractFailure {
    # .SYNOPSIS
    # Finds structural contract failures in one decision record.
    #
    # .DESCRIPTION
    # Requires the canonical numbered leaf name, one real Date metadata item,
    # and one operative level-two heading for each required decision section.
    # Numeric heading prefixes are permitted.
    #
    # .PARAMETER Name
    # The repository-relative decision-record path.
    #
    # .PARAMETER Content
    # The validated decision-record Markdown text.
    #
    # .PARAMETER MetadataContext
    # The validated document metadata context.
    #
    # .EXAMPLE
    # Get-DecisionRecordContractFailure -Name 'docs/decisions/0001-example.md' `
    #     -Content $strContent -MetadataContext $objMetadata
    #
    # # Returns one failure for each missing or malformed contract element.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each decision-record contract failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260911.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Content,

        [Parameter(Mandatory)]
        [pscustomobject] $MetadataContext
    )

    $strLeafName = ($Name -split '/')[-1]
    if ($strLeafName -cnotmatch '^[0-9]{4}-[a-z0-9]+(?:-[a-z0-9]+)*\.md$') {
        Write-Output "$Name must use the decision-record leaf name NNNN-short-title.md."
    }
    if (-not ($script:arrAllowedDecisionRecordStatuses -ccontains
            $MetadataContext.Status)) {
        Write-Output (
            "$Name Status must be one of " +
            ($script:arrAllowedDecisionRecordStatuses -join ', ') +
            ' for a governed decision record.'
        )
    }

    $objMarkdownContext = Get-OperativeMarkdownContext -Content $Content
    foreach ($strRequiredHeading in @(
            'Context',
            'Decision',
            'Consequences',
            'Alternatives Considered'
        )) {
        $arrMatchingHeadings = @(
            $objMarkdownContext.LevelTwoHeadings |
                Where-Object {
                    [regex]::Replace(
                        [string]$_.Text,
                        '^\d+\.\s+',
                        ''
                    ) -ceq $strRequiredHeading
                }
        )
        if ($arrMatchingHeadings.Count -ne 1) {
            Write-Output (
                "$Name must contain one operative level-two " +
                "$strRequiredHeading heading."
            )
        }
    }

    $arrContentLines = [regex]::Split($Content, '\r\n|\r|\n')
    $objParseContext = Get-MarkdownParseContext `
        -Content $Content `
        -LineCount $arrContentLines.Count
    $arrDateRecords = @(
        $objParseContext.TopLevelListItems |
            Where-Object {
                $_.Text -is [string] -and
                $_.Text.StartsWith(
                    'Date:',
                    [System.StringComparison]::Ordinal
                ) -and
                $_.Start -gt $MetadataContext.MetadataContentStart -and
                $_.Start -lt $MetadataContext.MetadataContentEnd
            }
    )
    $strDateFailure = "$Name must contain one exact Date: YYYY-MM-DD list item in Metadata."
    $boolDateHasContinuation = $false
    if ($arrDateRecords.Count -eq 1) {
        for ($intLine = $arrDateRecords[0].Start + 1;
            $intLine -lt $arrDateRecords[0].End;
            $intLine++) {
            if (-not [string]::IsNullOrWhiteSpace(
                    $arrContentLines[$intLine]
                )) {
                $boolDateHasContinuation = $true
                break
            }
        }
    }
    if ($arrDateRecords.Count -ne 1 -or $boolDateHasContinuation) {
        Write-Output $strDateFailure
        return
    }
    $objDateMatch = [regex]::Match(
        $arrContentLines[$arrDateRecords[0].Start],
        '^- \*\*Date:\*\* (?<Date>\d{4}-\d{2}-\d{2})$'
    )
    if (-not $objDateMatch.Success -or
        -not (Test-MetadataCalendarDate `
            -Date $objDateMatch.Groups['Date'].Value)) {
        Write-Output $strDateFailure
    }
}

function Get-DocumentMetadataClassificationContext {
    # .SYNOPSIS
    # Parses the inert Markdown classification manifest.
    #
    # .DESCRIPTION
    # Requires a strict, bounded JSON object with one schema version and sorted
    # exact-path arrays for Tier 2, generated, and future authorized exemptions.
    # Active exemptions must be safe tracked Markdown paths. Authorization paths
    # are inert until they exist in a trusted published baseline.
    #
    # .PARAMETER Content
    # The strict JSON manifest text.
    #
    # .PARAMETER TrackedPath
    # The complete tracked repository path inventory at the validation revision.
    #
    # .EXAMPLE
    # Get-DocumentMetadataClassificationContext `
    #     -Content '{"schemaVersion":2,"authorizedExemptionPaths":[],"tier2Paths":[],"generatedPaths":[]}' `
    #     -TrackedPath @()
    #
    # # Returns an empty, valid exemption set.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [pscustomobject] The failure, active exemptions, and authorization paths.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.1.20260911.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Content,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $TrackedPath
    )

    $scriptBlockFailure = {
        param([string] $Message)

        return [pscustomobject]@{
            Failure = $Message
            ExemptPaths = [string[]]@()
            AuthorizedExemptionPaths = [string[]]@()
        }
    }
    $objJsonOptions = [System.Text.Json.JsonDocumentOptions]@{
        AllowTrailingCommas = $false
        CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
        MaxDepth = 8
    }
    $objJsonDocument = $null
    try {
        $objJsonDocument = [System.Text.Json.JsonDocument]::Parse(
            $Content,
            $objJsonOptions
        )
        $objRoot = $objJsonDocument.RootElement
        if ($objRoot.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            return & $scriptBlockFailure `
                -Message 'The document classification manifest root must be an object.'
        }

        $dictionaryProperties =
            [System.Collections.Generic.Dictionary[
                string,
                System.Text.Json.JsonElement
            ]]::new([System.StringComparer]::Ordinal)
        $arrAllowedProperties = @(
            'schemaVersion',
            'authorizedExemptionPaths',
            'tier2Paths',
            'generatedPaths'
        )
        foreach ($objProperty in $objRoot.EnumerateObject()) {
            if ($arrAllowedProperties -cnotcontains $objProperty.Name) {
                return & $scriptBlockFailure -Message (
                    'The document classification manifest contains an unknown property: ' +
                    $objProperty.Name
                )
            }
            if ($dictionaryProperties.ContainsKey($objProperty.Name)) {
                return & $scriptBlockFailure -Message (
                    'The document classification manifest contains a duplicate property: ' +
                    $objProperty.Name
                )
            }
            $dictionaryProperties.Add($objProperty.Name, $objProperty.Value.Clone())
        }
        foreach ($strRequiredProperty in $arrAllowedProperties) {
            if (-not $dictionaryProperties.ContainsKey($strRequiredProperty)) {
                return & $scriptBlockFailure -Message (
                    'The document classification manifest is missing property: ' +
                    $strRequiredProperty
                )
            }
        }

        $intSchemaVersion = 0
        if (-not $dictionaryProperties['schemaVersion'].TryGetInt32(
                [ref]$intSchemaVersion
            ) -or $intSchemaVersion -ne 2) {
            return & $scriptBlockFailure `
                -Message 'The document classification schemaVersion must be integer 2.'
        }

        $setTrackedPaths = [System.Collections.Generic.HashSet[string]]::new(
            $TrackedPath,
            [System.StringComparer]::Ordinal
        )
        $setExemptPaths = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::Ordinal
        )
        $listExemptPaths = [System.Collections.Generic.List[string]]::new()
        foreach ($strArrayProperty in @('tier2Paths', 'generatedPaths')) {
            $objArray = $dictionaryProperties[$strArrayProperty]
            if ($objArray.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) {
                return & $scriptBlockFailure -Message (
                    "The document classification $strArrayProperty value must be an array."
                )
            }
            $strPreviousPath = $null
            foreach ($objPathValue in $objArray.EnumerateArray()) {
                if ($objPathValue.ValueKind -ne [System.Text.Json.JsonValueKind]::String) {
                    return & $scriptBlockFailure -Message (
                        "The document classification $strArrayProperty entries must be strings."
                    )
                }
                $strPath = $objPathValue.GetString()
                if ([string]::IsNullOrWhiteSpace($strPath) -or
                    [System.IO.Path]::IsPathRooted($strPath) -or
                    $strPath.Contains('\', [System.StringComparison]::Ordinal) -or
                    $strPath -match '(?:^|/)\.\.(?:/|$)' -or
                    $strPath -match '[\x00-\x1f\x7f]' -or
                    $strPath -cnotmatch '\.(?:md|mdc)$') {
                    return & $scriptBlockFailure -Message (
                        "The document classification contains an unsafe path: $strPath"
                    )
                }
                if ($null -ne $strPreviousPath -and
                    [string]::CompareOrdinal($strPreviousPath, $strPath) -ge 0) {
                    return & $scriptBlockFailure -Message (
                        "The document classification $strArrayProperty array must be " +
                        'strictly ordinal-sorted and duplicate-free.'
                    )
                }
                if (-not $setExemptPaths.Add($strPath)) {
                    return & $scriptBlockFailure -Message (
                        "The document classification repeats a path: $strPath"
                    )
                }
                if (-not $setTrackedPaths.Contains($strPath)) {
                    return & $scriptBlockFailure -Message (
                        "The document classification path is not tracked: $strPath"
                    )
                }
                $listExemptPaths.Add($strPath)
                $strPreviousPath = $strPath
            }
        }

        $objAuthorizationArray = $dictionaryProperties['authorizedExemptionPaths']
        if ($objAuthorizationArray.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) {
            return & $scriptBlockFailure -Message (
                'The document classification authorizedExemptionPaths value must be an array.'
            )
        }
        $listAuthorizedExemptionPaths = [System.Collections.Generic.List[string]]::new()
        $strPreviousAuthorizationPath = $null
        foreach ($objPathValue in $objAuthorizationArray.EnumerateArray()) {
            if ($objPathValue.ValueKind -ne [System.Text.Json.JsonValueKind]::String) {
                return & $scriptBlockFailure -Message (
                    'The document classification authorizedExemptionPaths entries must be strings.'
                )
            }
            $strPath = $objPathValue.GetString()
            if ([string]::IsNullOrWhiteSpace($strPath) -or
                [System.IO.Path]::IsPathRooted($strPath) -or
                $strPath.Contains('\', [System.StringComparison]::Ordinal) -or
                $strPath -match '(?:^|/)\.\.(?:/|$)' -or
                $strPath -match '[\x00-\x1f\x7f]' -or
                $strPath -cnotmatch '\.(?:md|mdc)$') {
                return & $scriptBlockFailure -Message (
                    "The document classification contains an unsafe path: $strPath"
                )
            }
            if ($null -ne $strPreviousAuthorizationPath -and
                [string]::CompareOrdinal(
                    $strPreviousAuthorizationPath,
                    $strPath
                ) -ge 0) {
                return & $scriptBlockFailure -Message (
                    'The document classification authorizedExemptionPaths array must be ' +
                    'strictly ordinal-sorted and duplicate-free.'
                )
            }
            if ($setExemptPaths.Contains($strPath) -or
                $listAuthorizedExemptionPaths.Contains($strPath)) {
                return & $scriptBlockFailure -Message (
                    "The document classification repeats a path: $strPath"
                )
            }
            $listAuthorizedExemptionPaths.Add($strPath)
            $strPreviousAuthorizationPath = $strPath
        }

        return [pscustomobject]@{
            Failure = $null
            ExemptPaths = [string[]]$listExemptPaths.ToArray()
            AuthorizedExemptionPaths =
                [string[]]$listAuthorizedExemptionPaths.ToArray()
        }
    }
    catch [System.Text.Json.JsonException] {
        return & $scriptBlockFailure `
            -Message 'The document classification manifest is not strict JSON.'
    }
    finally {
        if ($null -ne $objJsonDocument) {
            $objJsonDocument.Dispose()
        }
    }
}

function Get-DocumentMetadataClassificationExpansionFailure {
    # .SYNOPSIS
    # Rejects candidate-only Markdown metadata exemptions.
    #
    # .DESCRIPTION
    # Compares the parsed candidate exemption set with an authenticated baseline.
    # A new active exemption must already be active or authorized in the trusted
    # published baseline. Candidate-only authorizations are inert. A missing
    # baseline manifest is permitted only for the one-time manifest bootstrap.
    # Removals are permitted because they strengthen metadata validation.
    #
    # .PARAMETER HasTrustedBaselineManifest
    # Indicates that the authenticated baseline contains the manifest.
    #
    # .PARAMETER TrustedBaselineExemptPath
    # Parsed exact exemptions in the authenticated baseline.
    #
    # .PARAMETER TrustedBaselineAuthorizedExemptionPath
    # Parsed exact future exemptions authorized in the authenticated baseline.
    #
    # .PARAMETER CandidateExemptPath
    # Parsed exact exemptions in the candidate revision.
    #
    # .EXAMPLE
    # Get-DocumentMetadataClassificationExpansionFailure `
    #     -HasTrustedBaselineManifest $true `
    #     -TrustedBaselineExemptPath @('README.md') `
    #     -TrustedBaselineAuthorizedExemptionPath @('docs/guide.md') `
    #     -CandidateExemptPath @('README.md', 'docs/RUNBOOK.md')
    #
    # # Reports docs/RUNBOOK.md as an unauthenticated exemption addition.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One failure for each candidate-only exemption path.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.1.20260911.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [bool] $HasTrustedBaselineManifest,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $TrustedBaselineExemptPath,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $TrustedBaselineAuthorizedExemptionPath,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $CandidateExemptPath
    )

    if (-not $HasTrustedBaselineManifest) {
        return
    }
    $setTrustedBaselineExemptPaths =
        [System.Collections.Generic.HashSet[string]]::new(
            $TrustedBaselineExemptPath,
            [System.StringComparer]::Ordinal
        )
    $setTrustedBaselineAuthorizedExemptionPaths =
        [System.Collections.Generic.HashSet[string]]::new(
            $TrustedBaselineAuthorizedExemptionPath,
            [System.StringComparer]::Ordinal
        )
    foreach ($strCandidateExemptPath in
        ($CandidateExemptPath | Sort-Object -CaseSensitive -Unique)) {
        if ($setTrustedBaselineExemptPaths.Contains($strCandidateExemptPath) -or
            $setTrustedBaselineAuthorizedExemptionPaths.Contains(
                $strCandidateExemptPath
            )) {
            continue
        }
        Write-Output (
            'The document classification adds an unauthenticated metadata ' +
            "exemption: $strCandidateExemptPath. Add the exact path to " +
            'authorizedExemptionPaths in a separate change and publish that ' +
            'authorization before activating the exemption.'
        )
    }
}

function Get-DiscoveredGovernedMarkdownDocumentPath {
    # .SYNOPSIS
    # Selects tracked Markdown that is not already classified.
    #
    # .DESCRIPTION
    # Partitions every tracked Markdown or Cursor Markdown path between the
    # reviewed governed catalog, a bounded Tier 2/generated exception list, and
    # a fail-closed Tier 1 default. Rejects ambiguous or unsafe path inventories.
    #
    # .PARAMETER CandidatePath
    # The complete tracked repository path inventory at the validation revision.
    #
    # .PARAMETER KnownGovernedPath
    # Paths already present in the reviewed governed-document catalog.
    #
    # .PARAMETER ExemptPath
    # Exact reviewed Tier 2 or generated-document paths that do not require
    # document-level metadata validation.
    #
    # .EXAMPLE
    # Get-DiscoveredGovernedMarkdownDocumentPath `
    #     -CandidatePath @('README.md', 'docs/RELEASE-RUNBOOK.md') `
    #     -KnownGovernedPath @() -ExemptPath @('README.md')
    #
    # # Returns docs/RELEASE-RUNBOOK.md for Tier 1 metadata validation.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One newly discovered governed Markdown path.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260910.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $CandidatePath,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $KnownGovernedPath,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $ExemptPath
    )

    $scriptBlockAssertSafeMarkdownPath = {
        param(
            [string] $Path,
            [string] $InventoryName
        )

        if ([string]::IsNullOrWhiteSpace($Path) -or
            [System.IO.Path]::IsPathRooted($Path) -or
            $Path.Contains('\', [System.StringComparison]::Ordinal) -or
            $Path -match '(?:^|/)\.\.(?:/|$)' -or
            $Path -match '[\x00-\x1f\x7f]' -or
            $Path -cnotmatch '\.(?:md|mdc)$') {
            throw "$InventoryName contains an unsafe Markdown path: $Path"
        }
    }

    $setCandidates = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($strCandidatePath in $CandidatePath) {
        if ($strCandidatePath -cnotmatch '\.(?:md|mdc)$') {
            continue
        }
        & $scriptBlockAssertSafeMarkdownPath `
            -Path $strCandidatePath `
            -InventoryName 'The tracked document inventory'
        if (-not $setCandidates.Add($strCandidatePath)) {
            throw "The tracked document inventory contains a duplicate path: $strCandidatePath"
        }
    }

    $setKnownGoverned = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($strKnownGovernedPath in $KnownGovernedPath) {
        & $scriptBlockAssertSafeMarkdownPath `
            -Path $strKnownGovernedPath `
            -InventoryName 'The governed document catalog'
        if (-not $setKnownGoverned.Add($strKnownGovernedPath)) {
            throw "The governed document catalog contains a duplicate path: $strKnownGovernedPath"
        }
    }

    $setExempt = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($strExemptPath in $ExemptPath) {
        & $scriptBlockAssertSafeMarkdownPath `
            -Path $strExemptPath `
            -InventoryName 'The Tier 2/generated exception catalog'
        if (-not $setExempt.Add($strExemptPath)) {
            throw "The Tier 2/generated exception catalog contains a duplicate path: $strExemptPath"
        }
        if ($setKnownGoverned.Contains($strExemptPath)) {
            throw "A Markdown path is both governed and exempt: $strExemptPath"
        }
        if (-not $setCandidates.Contains($strExemptPath)) {
            throw "A Tier 2/generated exception is not tracked: $strExemptPath"
        }
    }

    return @(
        $setCandidates |
            Where-Object {
                -not $setKnownGoverned.Contains($_) -and
                -not $setExempt.Contains($_)
            } |
            Sort-Object -CaseSensitive
    )
}

function Get-ProhibitedTrackedClaudeLocalFailure {
    # .SYNOPSIS
    # Finds tracked personal Claude project-memory files.
    #
    # .DESCRIPTION
    # Rejects the exact CLAUDE.local.md name at the repository root or below a
    # tracked repository directory. Similar names remain permitted.
    #
    # .PARAMETER TrackedPaths
    # The complete tracked repository-relative path inventory.
    #
    # .EXAMPLE
    # Get-ProhibitedTrackedClaudeLocalFailure `
    #     -TrackedPaths @('CLAUDE.local.md', 'module/CLAUDE.local.md')
    #
    # # Reports both prohibited paths.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each prohibited tracked path.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260909.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $TrackedPaths
    )

    foreach ($strTrackedPath in $TrackedPaths) {
        if ($strTrackedPath -cmatch '(?:^|/)CLAUDE\.local\.md$') {
            Write-Output (
                'Tracked personal Claude project memory is prohibited: ' +
                $strTrackedPath
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
    # Version: 1.6.20260910.0
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

    $arrMetadataHeadingIndices = @(
        $listH2Indices |
        Where-Object { $arrTopLevelBlocks[$_].Text -ceq 'Metadata' }
    )
    $boolHasMetadataHeading = $arrMetadataHeadingIndices.Count -gt 0
    $intMetadataContentStart = -1
    $intMetadataContentEnd = -1
    $strMetadataContainerName = 'metadata header block'
    if ($boolHasMetadataHeading) {
        $intMetadataIndex = $arrMetadataHeadingIndices[0]
        $objMetadataBlock = $arrTopLevelBlocks[$intMetadataIndex]
        if ($arrMetadataHeadingIndices.Count -ne 1 -or
            $intMetadataIndex -ne $intExpectedMetadataIndex -or
            ($objMetadataBlock.Start - $intBodyStart) -ge 30) {
            return [pscustomobject]@{
                Failure = 'must place Metadata as the first level-two heading immediately after the H1 or optional Version and within the first 30 body lines.'
                VersionDate = $null
                UpdatedDate = $null
                Revision = $null
            }
        }

        $intMetadataContentStart = $objMetadataBlock.Start
        $intMetadataContentEnd = $arrLines.Count
        $strMetadataContainerName = 'Metadata section'
        foreach ($intH2Index in $listH2Indices) {
            if ($intH2Index -gt $intMetadataIndex) {
                $intMetadataContentEnd = $arrTopLevelBlocks[$intH2Index].Start
                break
            }
        }
    }
    else {
        if ($intExpectedMetadataIndex -ge $arrTopLevelBlocks.Count) {
            return [pscustomobject]@{
                Failure = 'must place the metadata header block immediately after the H1 or optional Version and within the first 30 body lines.'
                VersionDate = $null
                UpdatedDate = $null
                Revision = $null
            }
        }

        $objMetadataBlock = $arrTopLevelBlocks[$intExpectedMetadataIndex]
        if ($objMetadataBlock.Type -cne 'bullet_list_open' -or
            $objMetadataBlock.Tag -cne 'ul' -or
            ($objMetadataBlock.Start - $intBodyStart) -ge 30) {
            return [pscustomobject]@{
                Failure = 'must place the metadata header block immediately after the H1 or optional Version and within the first 30 body lines.'
                VersionDate = $null
                UpdatedDate = $null
                Revision = $null
            }
        }

        $intMetadataContentStart = $objMetadataBlock.Start - 1
        $intMetadataContentEnd = $objMetadataBlock.End
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
                    $_.Start -gt $intMetadataContentStart -and
                    $_.Start -lt $intMetadataContentEnd -and
                    ($_.Start - $intBodyStart) -lt 30
                }
        )
        $strFieldFailure = "must contain one exact top-level $($objField.Name) " +
            "list item in the $strMetadataContainerName and within the first 30 body lines."
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
        Status = $hashtableFieldMatches['Status'].Groups['Value'].Value
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
        MetadataContentStart = $intMetadataContentStart
        MetadataContentEnd = $intMetadataContentEnd
    }
}

function Test-DocumentMetadataHeaderIntent {
    # .SYNOPSIS
    # Tests whether a Markdown document intentionally carries metadata.
    #
    # .DESCRIPTION
    # Uses the locked Markdown parser to distinguish an operative document header
    # from fenced, quoted, deleted, nested, or otherwise non-operative examples.
    # A Metadata heading near the top of the body or an operative top-level
    # metadata field identifies an optional metadata header that must be validated.
    #
    # .PARAMETER Content
    # The Markdown document text.
    #
    # .EXAMPLE
    # Test-DocumentMetadataHeaderIntent -Content $strReadmeContent
    #
    # # Returns true when README.md intentionally carries document metadata.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [bool] True when the document carries an operative metadata-header signal.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.0.20260912.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $strMetadataSignalPattern =
        '(?m)^(?:## Metadata|- \*\*(?:Status|Owner|Last Updated|Scope):\*\*)'
    if ($Content -cnotmatch $strMetadataSignalPattern) {
        return $false
    }

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
            return $true
        }
        for ($intLine = 0; $intLine -le $intFrontMatterEnd; $intLine++) {
            $arrParserLines[$intLine] = ''
        }
        $intBodyStart = $intFrontMatterEnd + 1
    }

    $objParseContext = Get-MarkdownParseContext `
        -Content ($arrParserLines -join "`n") `
        -LineCount $arrLines.Count
    foreach ($objBlock in @($objParseContext.TopLevelBlocks)) {
        if ($objBlock.Type -ceq 'heading_open' -and
            $objBlock.Tag -ceq 'h2' -and
            $objBlock.Text -ceq 'Metadata' -and
            ($objBlock.Start - $intBodyStart) -lt 30) {
            return $true
        }
    }
    foreach ($objListItem in @($objParseContext.TopLevelListItems)) {
        if ($objListItem.Text -is [string] -and
            $objListItem.Text -cmatch '^(?:Status|Owner|Last Updated|Scope):') {
            return $true
        }
    }
    return $false
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
    # .PARAMETER MetadataRequired
    # Indicates that the current document must carry metadata. When false, a
    # document without metadata passes and a document with metadata receives the
    # complete shape and transition validation.
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
    # Version: 1.8.20260912.0
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
        [bool] $RequirePublishedRevisionConvention = $true,

        [Parameter()]
        [bool] $MetadataRequired = $true
    )

    if (-not $MetadataRequired -and
        -not (Test-DocumentMetadataHeaderIntent -Content $CurrentContent)) {
        return
    }

    $objParentMetadata = $null
    if (-not $MetadataRequired -and
        -not [string]::IsNullOrEmpty($ParentContent)) {
        if (-not (Test-DocumentMetadataHeaderIntent -Content $ParentContent)) {
            $ParentContent = $null
            $IsNewDocumentTransition = $true
        }
        else {
            $objParentMetadata = Get-DocumentMetadataContext -Content $ParentContent
            if ($null -ne $objParentMetadata.Failure) {
                $ParentContent = $null
                $IsNewDocumentTransition = $true
                $objParentMetadata = $null
            }
        }
    }

    $objCurrentMetadata = Get-DocumentMetadataContext -Content $CurrentContent
    if ($null -ne $objCurrentMetadata.Failure) {
        Write-Output "$Name $($objCurrentMetadata.Failure)"
        return
    }
    if (@(Get-GovernedDecisionDocumentPath -CandidatePath @($Name)).Count -eq 1) {
        $arrDecisionRecordFailures = @(
            Get-DecisionRecordContractFailure `
                -Name $Name `
                -Content $CurrentContent `
                -MetadataContext $objCurrentMetadata
        )
        if ($arrDecisionRecordFailures.Count -gt 0) {
            Write-Output $arrDecisionRecordFailures
            return
        }
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

    if ($null -eq $objParentMetadata) {
        $objParentMetadata = Get-DocumentMetadataContext -Content $ParentContent
    }
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
    if ((-not $objCurrentMetadata.HasVersion -or
            -not $objParentMetadata.HasVersion) -and
        [string]::CompareOrdinal(
            $strCurrentUpdatedDate,
            $strParentUpdatedDate
        ) -lt 0) {
        Write-Output (
            "$Name Last Updated must not move backward from " +
            "$strParentUpdatedDate to $strCurrentUpdatedDate."
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

    if ($RequirePublishedRevisionConvention -and
        $objCurrentMetadata.HasVersion -and
        $objParentMetadata.HasVersion -and
        -not $boolSameVersionIdentity -and
        $intCurrentRevision -ne 0) {
        Write-Output (
            "$Name Version revision must be 0 when major, minor, or date changes; " +
            "current revision is $intCurrentRevision."
        )
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
    # .PARAMETER MetadataRequired
    # Indicates whether each current document must carry metadata. When false,
    # metadata is optional but receives full validation when present.
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
    # Version: 1.2.20260912.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [pscustomobject[]] $TransitionContext,

        [Parameter()]
        [bool] $MetadataRequired = $true
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
                -RequirePublishedRevisionConvention $boolRequirePublishedRevision `
                -MetadataRequired $MetadataRequired)
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
    # Compares exact paths from the one authenticated merge base to the proposed
    # head without reading proposed file bytes. Topic-branch changes, invalid
    # revisions, ambiguous ancestry, and indeterminate results fail closed.
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
    # Version: 1.1.20260910.0
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

    $arrMergeBaseRevisions = @(
        & git -C $RepositoryRootPath merge-base --all `
            $BaseRevision $HeadRevision 2>$null
    )
    if ($LASTEXITCODE -ne 0 -or $arrMergeBaseRevisions.Count -ne 1) {
        throw 'The trusted validation range must have exactly one merge base.'
    }
    $strMergeBaseRevision = [string]$arrMergeBaseRevisions[0]
    $strMergeBaseRevision = $strMergeBaseRevision.Trim()
    if ($strMergeBaseRevision -notmatch $strObjectIdPattern) {
        throw 'The trusted validation range merge base is invalid.'
    }
    & git -C $RepositoryRootPath cat-file -e `
        "$strMergeBaseRevision`^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'The trusted validation range merge base is unavailable.'
    }

    $arrChangedPaths = @(
        & git -C $RepositoryRootPath diff --name-only --no-renames `
            --no-ext-diff --no-textconv $strMergeBaseRevision $HeadRevision -- `
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
    # Indicates that visible document metadata is required after Git safety checks.
    # When false, metadata is optional but receives full validation when present.
    #
    # .PARAMETER TrustedFinalizationTimestamp
    # The authenticated workflow-run creation time for the published transition.
    #
    # .EXAMPLE
    # Get-GovernedDocumentCommitTransitionFailure -Name 'AGENTS.md' `
    #     -RepositoryRootPath $strRoot -RepositoryRelativePath 'AGENTS.md' `
    #     -MaximumBytes 65536 -CommitRevision $strCommit
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
    # Version: 1.3.20260912.0
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

    return Get-DocumentMetadataRangeTransitionFailure `
        -Name $Name `
        -TransitionContext $listTransitions.ToArray() `
        -MetadataRequired $RequireMetadataTransition
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
    # .PARAMETER AutomatedMergeSourceRevision
    # The authenticated pull-request head for a one-parent automated merge.
    # A matching document blob uses that commit's date as the finalization date.
    #
    # .PARAMETER IsNewRefRange
    # Indicates that the event created a ref and supplied an all-zero base.
    #
    # .PARAMETER RangeComparisonMode
    # Uses the unique merge base for pull requests and synthetic ranges. Uses
    # the authenticated event endpoints for an existing direct push.
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
    # Indicates that visible document metadata is required after Git safety checks.
    # When false, metadata is optional but receives full validation when present.
    #
    # .EXAMPLE
    # Get-GovernedDocumentRangeTransitionFailure -Name 'AGENTS.md' `
    #     -RepositoryRootPath $strRoot -RepositoryRelativePath 'AGENTS.md' `
    #     -MaximumBytes 65536 -BaseRevision $strBase -HeadRevision $strHead `
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
    # Version: 1.12.20260912.0
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

        [Parameter()]
        [AllowEmptyString()]
        [string] $AutomatedMergeSourceRevision = '',

        [Parameter(Mandatory)]
        [bool] $IsNewRefRange,

        [Parameter()]
        [ValidateSet('MergeBase', 'PublishedEndpoints')]
        [string] $RangeComparisonMode = 'MergeBase',

        [Parameter(Mandatory)]
        [string] $PolicyRepositoryRelativePath,

        [Parameter(Mandatory)]
        [ValidateRange(1, 2147483646)]
        [int] $PolicyMaximumBytes,

        [Parameter(Mandatory)]
        [string] $PolicyMarker,

        [Parameter()]
        [bool] $RequireMetadataTransition = $true,

        [Parameter()]
        [AllowEmptyString()]
        [string] $TrustedFinalizationTimestamp = ''
    )

    $strTrustedFinalizationUtcDate = ''
    if (-not [string]::IsNullOrEmpty($TrustedFinalizationTimestamp)) {
        $objTrustedFinalizationTimestamp = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParseExact(
                $TrustedFinalizationTimestamp,
                "yyyy-MM-dd'T'HH:mm:ss'Z'",
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AssumeUniversal,
                [ref] $objTrustedFinalizationTimestamp
            )) {
            throw 'The trusted finalization timestamp is invalid.'
        }
        if ($objTrustedFinalizationTimestamp -gt $script:objMaximumCommitUtcTimestamp) {
            throw 'The trusted finalization timestamp is later than trusted UTC.'
        }
        $strTrustedFinalizationUtcDate =
            $objTrustedFinalizationTimestamp.UtcDateTime.ToString('yyyy-MM-dd')
    }

    if ([string]::IsNullOrEmpty($BaseRevision) -and
        [string]::IsNullOrEmpty($HeadRevision)) {
        if ($IsNewRefRange) {
            throw 'A new-ref metadata event range must supply base and head revisions.'
        }
        if ($RangeComparisonMode -eq 'PublishedEndpoints') {
            throw 'Published-endpoint comparison requires a metadata event range.'
        }
        if (-not [string]::IsNullOrEmpty($AutomatedMergeSourceRevision)) {
            throw 'An automated merge source requires a metadata event range.'
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
    if ($RangeComparisonMode -eq 'PublishedEndpoints' -and $IsNewRefRange) {
        throw 'Published-endpoint comparison cannot validate a new-ref range.'
    }
    if (-not [string]::IsNullOrEmpty($AutomatedMergeSourceRevision)) {
        if ($IsNewRefRange) {
            throw 'A new-ref metadata event range cannot use an automated merge source.'
        }
        if ($AutomatedMergeSourceRevision -notmatch $strObjectIdPattern -or
            $AutomatedMergeSourceRevision -match $strZeroObjectIdPattern) {
            throw 'The automated merge source revision is invalid.'
        }
        if ([string]::Equals(
                $AutomatedMergeSourceRevision,
                $HeadRevision,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -or
            [string]::Equals(
                $AutomatedMergeSourceRevision,
                $BaseRevision,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
            throw 'The automated merge source must differ from the event endpoints.'
        }
        & git -C $RepositoryRootPath cat-file -e `
            "$AutomatedMergeSourceRevision`^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw 'The automated merge source commit is unavailable.'
        }
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

    $strPublishedComparisonRevision = ''
    if (-not [string]::IsNullOrEmpty($strEffectiveBaseRevision)) {
        if ($RangeComparisonMode -eq 'PublishedEndpoints') {
            $strPublishedComparisonRevision = $strEffectiveBaseRevision
        }
        else {
            $arrPublishedMergeBaseRevisions = @(
                & git -C $RepositoryRootPath merge-base --all `
                    $strEffectiveBaseRevision $HeadRevision 2>$null
            )
            if ($LASTEXITCODE -ne 0 -or $arrPublishedMergeBaseRevisions.Count -ne 1) {
                throw 'The published metadata range must have exactly one merge base.'
            }
            $strPublishedComparisonRevision =
                ([string]$arrPublishedMergeBaseRevisions[0]).Trim()
        }
        if ($strPublishedComparisonRevision -notmatch $strObjectIdPattern) {
            throw 'The published metadata comparison revision is invalid.'
        }
        & git -C $RepositoryRootPath cat-file -e `
            "$strPublishedComparisonRevision`^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw 'The published metadata comparison revision is unavailable.'
        }
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

    $setValidatedRangeBlobIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $strHeadTimestamp = ''
    $intHeadParentCount = 0
    $boolHeadInheritsParentPath = $false
    $boolHeadMatchesAutomatedMergeSourcePath = $false
    if (-not [string]::IsNullOrEmpty($AutomatedMergeSourceRevision)) {
        $strSourceTimestamp = [string] (
            & git -C $RepositoryRootPath show -s --format=%cI `
                $AutomatedMergeSourceRevision
        )
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not read the automated merge source timestamp.'
        }
        $objSourceTimestamp = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse(
                $strSourceTimestamp.Trim(),
                [ref] $objSourceTimestamp
            )) {
            throw 'The automated merge source has an invalid timestamp.'
        }
        if ($objSourceTimestamp -gt $script:objMaximumCommitUtcTimestamp) {
            throw 'The automated merge source timestamp is later than trusted UTC.'
        }
    }
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

        $objRangePathEntry = Get-GitRevisionTreeEntryContext `
            -RepositoryRootPath $RepositoryRootPath `
            -Revision $strRangeCommit `
            -RepositoryRelativePath $RepositoryRelativePath
        if ($null -eq $objRangePathEntry) {
            $boolDirectParentContainsPath = $false
            if ($intParentCount -gt 0) {
                foreach ($strParentRevision in $arrCommitAndParents[1..$intParentCount]) {
                    $objParentPathEntry = Get-GitRevisionTreeEntryContext `
                        -RepositoryRootPath $RepositoryRootPath `
                        -Revision $strParentRevision `
                        -RepositoryRelativePath $RepositoryRelativePath
                    if ($null -ne $objParentPathEntry) {
                        $boolDirectParentContainsPath = $true
                        break
                    }
                }
            }
            if ($boolDirectParentContainsPath) {
                throw (
                    "Metadata range commit $strRangeCommit is missing governed path " +
                    "$RepositoryRelativePath that exists in a direct parent."
                )
            }
        }
        else {
            if ($objRangePathEntry.Mode -cne '100644' -or
                $objRangePathEntry.Type -cne 'blob' -or
                $objRangePathEntry.Path -cne $RepositoryRelativePath) {
                throw (
                    "Metadata range commit $strRangeCommit does not contain exactly one " +
                    "regular 100644 blob at $RepositoryRelativePath."
                )
            }
            $strRangeBlobId = $objRangePathEntry.ObjectId
            if ($setValidatedRangeBlobIds.Add($strRangeBlobId)) {
                [void](Read-GitRevisionText `
                        -RepositoryRootPath $RepositoryRootPath `
                        -Revision $strRangeCommit `
                        -RepositoryRelativePath $RepositoryRelativePath `
                        -MaximumBytes $MaximumBytes `
                        -RequireRegularFile)
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

    if (-not [string]::IsNullOrEmpty($AutomatedMergeSourceRevision)) {
        if ($intHeadParentCount -ne 1) {
            throw 'An automated merge source requires a one-parent event-range head.'
        }
        & git -C $RepositoryRootPath cat-file -e `
            "$AutomatedMergeSourceRevision`:$RepositoryRelativePath" 2>$null
        if ($LASTEXITCODE -eq 0) {
            & git -C $RepositoryRootPath diff --quiet --no-ext-diff --no-textconv `
                $AutomatedMergeSourceRevision $HeadRevision -- $RepositoryRelativePath
            $intSourceDiffExitCode = $LASTEXITCODE
            if ($intSourceDiffExitCode -eq 0) {
                $boolHeadMatchesAutomatedMergeSourcePath = $true
            }
            elseif ($intSourceDiffExitCode -ne 1) {
                throw (
                    'Could not compare the automated merge source for ' +
                    $RepositoryRelativePath + '.'
                )
            }
        }
    }

    if (-not [string]::IsNullOrEmpty($strEffectiveBaseRevision)) {
        & git -C $RepositoryRootPath diff --quiet --no-ext-diff --no-textconv `
            $strPublishedComparisonRevision $HeadRevision -- $RepositoryRelativePath
        $intPublishedDiffExitCode = $LASTEXITCODE
        if ($intPublishedDiffExitCode -eq 0) {
            return [string[]] @()
        }
        if ($intPublishedDiffExitCode -ne 1) {
            throw "Could not compare the proposed metadata change for $RepositoryRelativePath."
        }
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

    $boolHeadInheritsMergeParentPath =
        $intHeadParentCount -gt 1 -and $boolHeadInheritsParentPath
    $boolHeadInheritsAutomatedMergeSourcePath =
        $intHeadParentCount -eq 1 -and $boolHeadMatchesAutomatedMergeSourcePath
    $boolHeadInheritsPublishedContent = $boolHeadInheritsMergeParentPath -or
        $boolHeadInheritsAutomatedMergeSourcePath
    $strFinalizationTimestamp = if (-not [string]::IsNullOrEmpty(
            $strTrustedFinalizationUtcDate
        )) {
        $strTrustedFinalizationUtcDate
    }
    else {
        $strHeadTimestamp
    }
    $objPublishedTransition = [pscustomobject]@{
        CurrentContent = $strCurrentContent
        ParentContent = $strParentContent
        ExpectedUtcDate = $strFinalizationTimestamp
        CurrentRevision = $HeadRevision
        ParentRevision = $strParentRevisionLabel
        RequireExpectedUtcDateForRenderedChange = -not $boolHeadInheritsPublishedContent
        RequirePublishedRevisionConvention = -not $boolHeadInheritsPublishedContent
    }
    return Get-DocumentMetadataRangeTransitionFailure `
        -Name $Name `
        -TransitionContext @($objPublishedTransition) `
        -MetadataRequired $RequireMetadataTransition
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
    # Validates the workflow step that acquires an existing push range base.
    #
    # .DESCRIPTION
    # Parses the named workflow step as inert text. Confirms that only an
    # existing, non-deleted branch push runs the step, that the
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
    # Version: 1.2.20260911.0
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

function Get-AutomatedMergeSourceWorkflowContractFailure {
    # .SYNOPSIS
    # Validates trusted run-time and one-parent merge-source workflow contracts.
    #
    # .DESCRIPTION
    # Requires the tested finalization-time resolver, exact default-branch push
    # scoping, associated-PR lookup, merge identity filters, non-force PR-head
    # acquisition, SHA readback, event-specific range comparison, and validator
    # handoff.
    #
    # .PARAMETER WorkflowContent
    # The complete agent-instruction workflow YAML text to inspect.
    #
    # .EXAMPLE
    # Get-AutomatedMergeSourceWorkflowContractFailure -WorkflowContent $strWorkflow
    #
    # # Returns no output when the one-parent merge-source contract is intact.
    #
    # .INPUTS
    # None. You can't pipe objects to this function.
    #
    # .OUTPUTS
    # [string] One record for each workflow-contract failure.
    #
    # .NOTES
    # PRIVATE/INTERNAL HELPER - This function is not part of the
    # public API surface. Parameters, return shape, and positional
    # contract may change without notice.
    #
    # This function does not support positional parameters.
    # Version: 1.4.20260910.0
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $WorkflowContent
    )

    $arrExactLiterals = @(
        '  pull_request_target:',
        '    types:',
        '      - opened',
        '      - synchronize',
        '      - reopened',
        '      - edited',
        '  actions: read',
        '  pull-requests: read',
        '      - name: Resolve trusted workflow-run finalization time',
        '        id: resolve_run_time',
        "          RUN_HEAD_REVISION: `${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.sha || github.sha }}",
        "          RUN_BASE_REVISION: `${{ github.event_name == 'push' && github.event.before || '' }}",
        "          RUN_HEAD_REF_NAME: `${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.ref || github.ref_name }}",
        "          RUN_HEAD_REF: `${{ github.event_name == 'pull_request_target' && format('refs/heads/{0}', github.event.pull_request.head.ref) || github.ref }}",
        "          RUN_HEAD_REPOSITORY: `${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.repo.full_name || github.repository }}",
        '        run: node .github/workflows/Resolve-AgentInstructionFinalizationTime.mjs',
        '      - name: Resolve authenticated one-parent merge source',
        '          if (( ${#head_and_parents[@]} != 2 )); then',
        "          const apiRoot = apiUrl.replace(/\/+$/u, '');",
        '              `${apiRoot}/repos/${repository}/commits/${head}/pulls?per_page=100&page=${page}`',
        "            pull?.state === 'closed' &&",
        '            pull?.base?.repo?.full_name === repository &&',
        '            pull?.base?.ref === defaultBranch &&',
        '            pull?.merge_commit_sha === head &&',
        '            pull.head.sha !== head,',
        "              throw new Error('Associated pull-request pagination exceeded 20 pages.');",
        "            throw new Error('More than one exact automated merge source matched the pushed head.');",
        '      - name: Fetch authenticated one-parent merge source as data',
        "        if: steps.resolve_automated_merge_source.outputs.source_revision != ''",
        '              "refs/pull/${PR_NUMBER}/head:${source_ref}"',
        '          test "${fetched_source}" = "${SOURCE_REVISION}"',
        '          AGENT_INSTRUCTION_AUTOMATED_MERGE_SOURCE: >-',
        "            `${{ steps.resolve_automated_merge_source.outputs.source_revision || '' }}",
        '          AGENT_INSTRUCTION_RANGE_COMPARISON_MODE: >-',
        '          -RangeComparisonMode',
        '          $env:AGENT_INSTRUCTION_RANGE_COMPARISON_MODE',
        '          -AutomatedMergeSourceRevision',
        '          $env:AGENT_INSTRUCTION_AUTOMATED_MERGE_SOURCE',
        '          AGENT_INSTRUCTION_TRUSTED_FINALIZATION_TIMESTAMP: >-',
        "            `${{ steps.resolve_run_time.outputs.timestamp }}",
        '          -TrustedFinalizationTimestamp',
        '          $env:AGENT_INSTRUCTION_TRUSTED_FINALIZATION_TIMESTAMP'
    )
    foreach ($strExactLiteral in $arrExactLiterals) {
        if ([regex]::Matches(
                $WorkflowContent,
                [regex]::Escape($strExactLiteral)
            ).Count -ne 1) {
            Write-Output (
                'The automated merge-source workflow contract must contain exactly once: ' +
                $strExactLiteral
            )
        }
    }

    $strResolveCondition = @"
        if: >-
          github.event_name == 'push' &&
          github.ref_name == github.event.repository.default_branch &&
          !github.event.created &&
          !github.event.deleted
"@.TrimEnd()
    if (-not $WorkflowContent.Contains(
            $strResolveCondition,
            [System.StringComparison]::Ordinal
        )) {
        Write-Output 'The automated merge-source resolver condition is not exact.'
    }

    $strRangeComparisonModeHandoff = @'
          AGENT_INSTRUCTION_RANGE_COMPARISON_MODE: >-
            ${{ github.event_name == 'push' &&
              !github.event.created && 'PublishedEndpoints' || 'MergeBase' }}
'@.TrimEnd()
    if (-not $WorkflowContent.Contains(
            $strRangeComparisonModeHandoff,
            [System.StringComparison]::Ordinal
        )) {
        Write-Output 'The event-range comparison-mode selector is not exact.'
    }

    $arrUnsafeResolverPatterns = @(
        '(?m)^\s*continue-on-error:\s*true\s*$',
        '(?m)^\s*git fetch .*--force(?:\s|$)',
        '(?m)^\s*git fetch .+"\+refs/pull/'
    )
    foreach ($strUnsafeResolverPattern in $arrUnsafeResolverPatterns) {
        if ($WorkflowContent -match $strUnsafeResolverPattern) {
            Write-Output (
                'The automated merge-source workflow contains an unsafe fallback: ' +
                $strUnsafeResolverPattern
            )
        }
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
$strDocumentClassificationPath = Join-Path `
    -Path $strRepositoryRootPath `
    -ChildPath '.github/document-metadata-classification.json'
$strDocsInstructionsPath = Join-Path `
    -Path $strRepositoryRootPath `
    -ChildPath '.github/instructions/docs.instructions.md'
$arrAgentSetupInputSpecs = @(
    [pscustomobject]@{ Path = 'package.json'; MaximumBytes = 16384 }
    [pscustomobject]@{ Path = '.github/workflows/package.json'; MaximumBytes = 16384 }
    [pscustomobject]@{
        Path = '.github/workflows/package-lock.json'
        MaximumBytes = 131072
    }
    [pscustomobject]@{
        Path = '.github/workflows/copilot-setup-steps.yml'
        MaximumBytes = 32768
    }
    [pscustomobject]@{
        Path = '.github/workflows/lint-staged-markdown.mjs'
        MaximumBytes = 32768
    }
    [pscustomobject]@{ Path = '.husky/pre-commit'; MaximumBytes = 16384 }
    [pscustomobject]@{ Path = '.pre-commit-config.yaml'; MaximumBytes = 16384 }
    [pscustomobject]@{
        Path = '.github/workflows/scripts-README.md'
        MaximumBytes = 32768
    }
    [pscustomobject]@{ Path = 'requirements-dev.txt'; MaximumBytes = 16384 }
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
$arrGovernedNonInstructionDocuments = @(
    [pscustomobject]@{
        Path = '.github/workflows/MARKDOWN-LINTING-IMPLEMENTATION.md'
        MaximumBytes = 32768
        RequiresMetadata = $true
    },
    [pscustomobject]@{
        Path = '.github/workflows/scripts-README.md'
        MaximumBytes = 32768
        RequiresMetadata = $true
    },
    [pscustomobject]@{
        Path = '.claude/commands/review-loop.md'
        MaximumBytes = 16384
        RequiresMetadata = $true
    },
    [pscustomobject]@{
        Path = 'STYLE_GUIDE.md'
        MaximumBytes = 262144
        RequiresMetadata = $true
    },
    [pscustomobject]@{
        Path = 'STYLE_GUIDE_RATIONALE.md'
        MaximumBytes = 131072
        RequiresMetadata = $true
    },
    [pscustomobject]@{
        Path = 'docs/ISSUE_EVALUATION_PROMPT.md'
        MaximumBytes = 16384
        RequiresMetadata = $true
    },
    [pscustomobject]@{
        Path = 'docs/T1-SUPPLY-FREEZE-v1.md'
        MaximumBytes = 131072
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
$setStagedInputPaths = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
)
if ($RequireStagedInputMatch) {
    $arrStagedInputPaths = @(
        Invoke-GitNulRecordQuery `
            -RepositoryRootPath $strRepositoryRootPath `
            -Argument @(
                'diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z',
                '--'
            ) `
            -DisplayName 'staged validator inputs'
    )
    foreach ($strStagedInputPath in $arrStagedInputPaths) {
        [void]$setStagedInputPaths.Add($strStagedInputPath)
    }
}
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

$strLocalWorktreeBaselineRevision = ''
if ([string]::IsNullOrEmpty($strValidatedInputRevision) -and
    [string]::IsNullOrEmpty($RangeBaseRevision) -and
    [string]::IsNullOrEmpty($RangeHeadRevision)) {
    $strLocalWorktreeBaselineRevision = $strCheckedOutRevision
}

if ([string]::IsNullOrEmpty($strValidatedInputRevision)) {
    $arrTrackedRepositoryPaths = @(
        Invoke-GitNulRecordQuery `
            -RepositoryRootPath $strRepositoryRootPath `
            -Argument @('ls-files', '--cached', '-z') `
            -DisplayName 'tracked repository paths'
    )
}
else {
    $arrTrackedRepositoryPaths = @(
        Invoke-GitNulRecordQuery `
            -RepositoryRootPath $strRepositoryRootPath `
            -Argument @(
                'ls-tree', '-r', '--name-only', '-z',
                $strValidatedInputRevision
            ) `
            -DisplayName 'revision repository paths'
    )
}
$strDocumentClassificationContent = if (
    [string]::IsNullOrEmpty($strValidatedInputRevision)
) {
    ConvertFrom-StrictUtf8Data `
        -Bytes (Read-RepositoryInputData `
            -Path $strDocumentClassificationPath `
            -RepositoryRootPath $strRepositoryRootPath `
            -RepositoryRelativePath '.github/document-metadata-classification.json' `
            -DisplayName '.github/document-metadata-classification.json' `
            -MaximumBytes $intDocumentClassificationMaximumInputBytes `
            -RequireIndexContentMatch:($RequireStagedInputMatch -and
                $setStagedInputPaths.Contains(
                    '.github/document-metadata-classification.json'
                ))) `
        -DisplayName '.github/document-metadata-classification.json'
}
else {
    Read-GitRevisionText `
        -RepositoryRootPath $strRepositoryRootPath `
        -Revision $strValidatedInputRevision `
        -RepositoryRelativePath '.github/document-metadata-classification.json' `
        -MaximumBytes $intDocumentClassificationMaximumInputBytes `
        -RequireRegularFile
}
$objDocumentClassificationContext = Get-DocumentMetadataClassificationContext `
    -Content $strDocumentClassificationContent `
    -TrackedPath $arrTrackedRepositoryPaths
if ($null -ne $objDocumentClassificationContext.Failure) {
    throw $objDocumentClassificationContext.Failure
}
$strDocumentClassificationBaselineRevision = if (
    -not [string]::IsNullOrEmpty($strLocalWorktreeBaselineRevision)
) {
    $strLocalWorktreeBaselineRevision
}
else {
    $RangeBaseRevision
}
$boolHasTrustedBaselineClassificationManifest = $false
$arrTrustedBaselineClassificationExemptPaths = @()
$arrTrustedBaselineClassificationAuthorizedExemptionPaths = @()
if (-not [string]::IsNullOrEmpty($strDocumentClassificationBaselineRevision) -and
    $strDocumentClassificationBaselineRevision -notmatch '^(?:0{40}|0{64})$') {
    if ($strDocumentClassificationBaselineRevision -notmatch
        '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
        throw 'The document classification baseline revision is invalid.'
    }
    & git -C $strRepositoryRootPath cat-file -e `
        "$strDocumentClassificationBaselineRevision`^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'The document classification baseline commit is unavailable.'
    }
    $arrBaselineClassificationEntries = @(
        & git -C $strRepositoryRootPath ls-tree `
            $strDocumentClassificationBaselineRevision -- `
            '.github/document-metadata-classification.json'
    )
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not inspect the document classification baseline.'
    }
    if ($arrBaselineClassificationEntries.Count -gt 0) {
        $arrBaselineTrackedRepositoryPaths = @(
            Invoke-GitNulRecordQuery `
                -RepositoryRootPath $strRepositoryRootPath `
                -Argument @(
                    'ls-tree', '-r', '--name-only', '-z',
                    $strDocumentClassificationBaselineRevision
                ) `
                -DisplayName 'document classification baseline paths'
        )
        $strBaselineDocumentClassificationContent = Read-GitRevisionText `
            -RepositoryRootPath $strRepositoryRootPath `
            -Revision $strDocumentClassificationBaselineRevision `
            -RepositoryRelativePath '.github/document-metadata-classification.json' `
            -MaximumBytes $intDocumentClassificationMaximumInputBytes `
            -RequireRegularFile
        $objBaselineDocumentClassificationContext =
            Get-DocumentMetadataClassificationContext `
                -Content $strBaselineDocumentClassificationContent `
                -TrackedPath $arrBaselineTrackedRepositoryPaths
        if ($null -ne $objBaselineDocumentClassificationContext.Failure) {
            throw (
                'The trusted baseline document classification is invalid: ' +
                $objBaselineDocumentClassificationContext.Failure
            )
        }
        $boolHasTrustedBaselineClassificationManifest = $true
        $arrTrustedBaselineClassificationExemptPaths = @(
            $objBaselineDocumentClassificationContext.ExemptPaths
        )
        $arrTrustedBaselineClassificationAuthorizedExemptionPaths = @(
            $objBaselineDocumentClassificationContext.AuthorizedExemptionPaths
        )
    }
}
$arrDocumentClassificationExpansionFailures = @(
    Get-DocumentMetadataClassificationExpansionFailure `
        -HasTrustedBaselineManifest `
            $boolHasTrustedBaselineClassificationManifest `
        -TrustedBaselineExemptPath `
            $arrTrustedBaselineClassificationExemptPaths `
        -TrustedBaselineAuthorizedExemptionPath `
            $arrTrustedBaselineClassificationAuthorizedExemptionPaths `
        -CandidateExemptPath $objDocumentClassificationContext.ExemptPaths
)
if ($arrDocumentClassificationExpansionFailures.Count -gt 0) {
    throw (
        'Document classification expansion failed:' +
        [Environment]::NewLine + '- ' +
        ($arrDocumentClassificationExpansionFailures -join
            ([Environment]::NewLine + '- '))
    )
}
$arrMetadataExemptMarkdownDocuments = @(
    $objDocumentClassificationContext.ExemptPaths
)
$listGovernedDecisionCandidatePaths = [System.Collections.Generic.List[string]]::new()
foreach ($strTrackedRepositoryPath in $arrTrackedRepositoryPaths) {
    $listGovernedDecisionCandidatePaths.Add([string]$strTrackedRepositoryPath)
}
$strDecisionInventoryBaseRevision = if (
    -not [string]::IsNullOrEmpty($strLocalWorktreeBaselineRevision)
) {
    $strLocalWorktreeBaselineRevision
}
else {
    $RangeBaseRevision
}
$strDecisionInventoryHeadRevision = if (
    -not [string]::IsNullOrEmpty($strLocalWorktreeBaselineRevision)
) {
    $strCheckedOutRevision
}
else {
    $RangeHeadRevision
}
if (-not [string]::IsNullOrEmpty($strDecisionInventoryBaseRevision) -and
    -not [string]::IsNullOrEmpty($strDecisionInventoryHeadRevision)) {
    $strDecisionObjectIdPattern = '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$'
    $strDecisionZeroObjectIdPattern = '^(?:0{40}|0{64})$'
    if ($strDecisionInventoryBaseRevision -notmatch $strDecisionObjectIdPattern -or
        $strDecisionInventoryHeadRevision -notmatch $strDecisionObjectIdPattern -or
        $strDecisionInventoryHeadRevision -match $strDecisionZeroObjectIdPattern) {
        throw 'The decision-record inventory range contains an invalid object ID.'
    }
    $boolDecisionInventoryBaseIsZero =
        $strDecisionInventoryBaseRevision -match $strDecisionZeroObjectIdPattern
    if (-not $boolDecisionInventoryBaseIsZero) {
        $arrBaselineDecisionPaths = @(
            Invoke-GitNulRecordQuery `
                -RepositoryRootPath $strRepositoryRootPath `
                -Argument @(
                    'ls-tree', '-r', '--name-only', '-z',
                    $strDecisionInventoryBaseRevision
                ) `
                -DisplayName 'published-baseline decision records'
        )
        foreach ($strBaselineDecisionPath in $arrBaselineDecisionPaths) {
            $listGovernedDecisionCandidatePaths.Add([string]$strBaselineDecisionPath)
        }
    }
    $strDecisionInventoryRange = if ($boolDecisionInventoryBaseIsZero) {
        $strDecisionInventoryHeadRevision
    }
    else {
        "$strDecisionInventoryBaseRevision..$strDecisionInventoryHeadRevision"
    }
    $arrRangeDecisionPaths = @(
        Invoke-GitNulRecordQuery `
            -RepositoryRootPath $strRepositoryRootPath `
            -Argument @(
                'log', '--format=', '--name-only', '-z', '--no-renames',
                $strDecisionInventoryRange, '--',
                ':(glob)docs/decisions/**/*.md'
            ) `
            -DisplayName 'decision records in the validation range'
    )
    foreach ($strRangeDecisionPath in $arrRangeDecisionPaths) {
        $listGovernedDecisionCandidatePaths.Add([string]$strRangeDecisionPath)
    }
}
$arrGovernedDecisionPaths = @(
    Get-GovernedDecisionDocumentPath `
        -CandidatePath $listGovernedDecisionCandidatePaths.ToArray()
)
foreach ($strGovernedDecisionPath in $arrGovernedDecisionPaths) {
    $arrGovernedNonInstructionDocuments += [pscustomobject]@{
        Path = $strGovernedDecisionPath
        MaximumBytes = 32768
        RequiresMetadata = $true
    }
}
$arrDiscoveredGovernedMarkdownPaths = @(
    Get-DiscoveredGovernedMarkdownDocumentPath `
        -CandidatePath $arrTrackedRepositoryPaths `
        -KnownGovernedPath @(
            @($arrGovernedInstructionDocuments.Path) +
            @($arrGovernedNonInstructionDocuments.Path)
        ) `
        -ExemptPath $arrMetadataExemptMarkdownDocuments
)
foreach ($strDiscoveredGovernedMarkdownPath in
    $arrDiscoveredGovernedMarkdownPaths) {
    $arrGovernedNonInstructionDocuments += [pscustomobject]@{
        Path = $strDiscoveredGovernedMarkdownPath
        MaximumBytes = $intInstructionDocumentMaximumInputBytes
        RequiresMetadata = $true
    }
}
foreach ($strMetadataOptionalMarkdownDocument in
    $arrMetadataExemptMarkdownDocuments) {
    $arrGovernedNonInstructionDocuments += [pscustomobject]@{
        Path = $strMetadataOptionalMarkdownDocument
        MaximumBytes = $intValidatorMaximumInputBytes
        RequiresMetadata = $false
    }
}
$arrGovernedMetadataDocuments = @(
    $arrGovernedInstructionDocuments
    $arrGovernedNonInstructionDocuments
)
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
            $strTrackedPath -cmatch '(?:^|/)AGENTS\.md$' -or
            $strTrackedPath -cmatch `
                '^\.github/instructions/(?:[^/]+/)*[^/]+\.instructions\.md$' -or
            $strTrackedPath -cmatch '^\.cursor/rules/(?:[^/]+/)*[^/]+\.mdc$'
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
    $arrRequiredPaths = @(
        $strCodexConfigPath,
        $strDocumentClassificationPath
    )
    $arrRequiredPaths += @(
        $arrGovernedMetadataDocuments |
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
            -MaximumBytes $intAgentsMaximumInputBytes `
            -RequireIndexContentMatch:($RequireStagedInputMatch -and
                $setStagedInputPaths.Contains('AGENTS.md'))) `
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
            -MaximumBytes $intClaudeMaximumInputBytes `
            -RequireIndexContentMatch:($RequireStagedInputMatch -and
                $setStagedInputPaths.Contains('CLAUDE.md'))) `
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
            -MaximumBytes $intCodexConfigMaximumInputBytes `
            -RequireIndexContentMatch:($RequireStagedInputMatch -and
                $setStagedInputPaths.Contains('.codex/config.toml'))) `
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
            -MaximumBytes $intDocsInstructionsMaximumInputBytes `
            -RequireIndexContentMatch:($RequireStagedInputMatch -and
                $setStagedInputPaths.Contains(
                    '.github/instructions/docs.instructions.md'
                ))) `
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
                -MaximumBytes $objAgentSetupInputSpec.MaximumBytes `
                -RequireIndexContentMatch:($RequireStagedInputMatch -and
                    $setStagedInputPaths.Contains(
                        $objAgentSetupInputSpec.Path
                    ))) `
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
$hashtableGovernedDocumentContent = @{
    'AGENTS.md' = $strAgentsContent
    'CLAUDE.md' = $strClaudeContent
    '.github/instructions/docs.instructions.md' = $strDocsInstructionsContent
}
foreach ($objDocumentSpec in $arrGovernedMetadataDocuments) {
    if ($hashtableGovernedDocumentContent.ContainsKey($objDocumentSpec.Path)) {
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
                -MaximumBytes $objDocumentSpec.MaximumBytes `
                -RequireIndexContentMatch:($RequireStagedInputMatch -and
                    $setStagedInputPaths.Contains($objDocumentSpec.Path))) `
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
    $hashtableGovernedDocumentContent[$objDocumentSpec.Path] = $strDocumentContent
}

$listGovernedDocumentContexts = [System.Collections.Generic.List[pscustomobject]]::new()
foreach ($objDocumentSpec in $arrGovernedMetadataDocuments) {
    $objParentContext = Get-GovernedDocumentParentContext `
        -RepositoryRootPath $strRepositoryRootPath `
        -RepositoryRelativePath $objDocumentSpec.Path `
        -MaximumBytes $objDocumentSpec.MaximumBytes `
        -Revision $strValidatedInputRevision `
        -LocalBaselineRevision $strLocalWorktreeBaselineRevision
    $listGovernedDocumentContexts.Add([pscustomobject]@{
            Path = $objDocumentSpec.Path
            MaximumBytes = $objDocumentSpec.MaximumBytes
            RequiresMetadata = $objDocumentSpec.RequiresMetadata
            Content = $hashtableGovernedDocumentContent[$objDocumentSpec.Path]
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
$boolUseLocalWorktreeRange = -not [string]::IsNullOrEmpty(
    $strLocalWorktreeBaselineRevision
)
$boolHasExplicitEventRange = -not [string]::IsNullOrEmpty($RangeBaseRevision) -or
    -not [string]::IsNullOrEmpty($RangeHeadRevision)
if ($boolHasExplicitEventRange -and
    [string]::IsNullOrEmpty($TrustedFinalizationTimestamp)) {
    throw 'An event-range validation requires a trusted finalization timestamp.'
}
if ($RangeComparisonMode -eq 'PublishedEndpoints') {
    if (-not $boolHasExplicitEventRange) {
        throw 'Published-endpoint comparison requires an explicit event range.'
    }
    if ($RangeIsNewRef) {
        throw 'Published-endpoint comparison cannot validate a new-ref event.'
    }
}
$strEffectiveRangeBaseRevision = if ($boolUseLocalWorktreeRange) {
    $strLocalWorktreeBaselineRevision
}
else {
    $RangeBaseRevision
}
$strEffectiveRangeHeadRevision = if ($boolUseLocalWorktreeRange) {
    $strCheckedOutRevision
}
else {
    $RangeHeadRevision
}
$boolEffectiveRangeIsNewRef = if ($boolUseLocalWorktreeRange) {
    $false
}
else {
    [bool]$RangeIsNewRef
}

$arrRepositoryFailures = @(Get-AgentInstructionFailure `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent)
$arrRepositoryFailures += @(Get-ProhibitedTrackedClaudeLocalFailure `
        -TrackedPaths $arrTrackedRepositoryPaths)
$arrRepositoryFailures += @(Get-HuskySetupContractFailure `
        -RootPackageContent $hashtableAgentSetupInputContent['package.json'] `
        -WorkflowPackageContent `
            $hashtableAgentSetupInputContent['.github/workflows/package.json'] `
        -WorkflowPackageLockContent `
            $hashtableAgentSetupInputContent['.github/workflows/package-lock.json'] `
        -HookContent $hashtableAgentSetupInputContent['.husky/pre-commit'] `
        -CopilotSetupContent `
            $hashtableAgentSetupInputContent['.github/workflows/copilot-setup-steps.yml'] `
        -PreCommitConfigContent `
            $hashtableAgentSetupInputContent['.pre-commit-config.yaml'] `
        -StagedMarkdownHelperContent `
            $hashtableAgentSetupInputContent['.github/workflows/lint-staged-markdown.mjs'])
$arrRepositoryFailures += @(Get-PreCommitBootstrapContractFailure `
        -AgentsContent $strAgentsContent `
        -ClaudeContent $strClaudeContent `
        -ScriptIndexContent `
            $hashtableAgentSetupInputContent['.github/workflows/scripts-README.md'] `
        -RequirementsContent $hashtableAgentSetupInputContent['requirements-dev.txt'])
foreach ($objDocumentContext in $listGovernedDocumentContexts) {
    if ([string]::IsNullOrEmpty($RangeBaseRevision) -and
        [string]::IsNullOrEmpty($RangeHeadRevision)) {
        if ($boolUseLocalWorktreeRange) {
            if ($objDocumentContext.IsWorktreeTransition) {
                $arrRepositoryFailures += @(Get-DocumentMetadataTransitionFailure `
                        -Name $objDocumentContext.Path `
                        -CurrentContent $objDocumentContext.Content `
                        -ParentContent $objDocumentContext.ParentContent `
                        -ExpectedUtcDate $objDocumentContext.ExpectedUtcDate `
                        -IsNewDocumentTransition (
                            $null -eq $objDocumentContext.ParentContent
                        ) `
                        -MetadataRequired $objDocumentContext.RequiresMetadata)
            }
        }
        elseif ($objDocumentContext.IsWorktreeTransition -or
            -not $boolNoRangeCommitHasParent) {
            $arrRepositoryFailures += @(Get-DocumentMetadataTransitionFailure `
                    -Name $objDocumentContext.Path `
                    -CurrentContent $objDocumentContext.Content `
                    -ParentContent $objDocumentContext.ParentContent `
                    -ExpectedUtcDate $objDocumentContext.ExpectedUtcDate `
                    -IsNewDocumentTransition (
                        $null -eq $objDocumentContext.ParentContent -and
                        -not [string]::IsNullOrEmpty($objDocumentContext.ExpectedUtcDate)
                    ) `
                    -MetadataRequired $objDocumentContext.RequiresMetadata)
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
        $boolUseLocalWorktreeRange -and $objDocumentContext.IsWorktreeTransition
    if (-not $boolWorktreeReplacesLocalRange) {
        $arrRepositoryFailures += @(Get-GovernedDocumentRangeTransitionFailure `
                -Name $objDocumentContext.Path `
                -RepositoryRootPath $strRepositoryRootPath `
                -RepositoryRelativePath $objDocumentContext.Path `
                -MaximumBytes $objDocumentContext.MaximumBytes `
                -BaseRevision $strEffectiveRangeBaseRevision `
                -HeadRevision $strEffectiveRangeHeadRevision `
                -InputRevision $strValidatedInputRevision `
                -AutomatedMergeSourceRevision $AutomatedMergeSourceRevision `
                -IsNewRefRange $boolEffectiveRangeIsNewRef `
                -RangeComparisonMode $RangeComparisonMode `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes $intValidatorMaximumInputBytes `
                -PolicyMarker $strMetadataRangePolicyMarker `
                -RequireMetadataTransition $objDocumentContext.RequiresMetadata `
                -TrustedFinalizationTimestamp $TrustedFinalizationTimestamp)
    }
}
if ($arrRepositoryFailures.Count -gt 0) {
    throw "Agent-instruction contract failed:`n- $($arrRepositoryFailures -join "`n- ")"
}

Write-Output 'Agent-instruction contract passed.'

#endregion Repository validation

if ($SelfTest) {
    #region Mutation self-tests

    $strLockedPythonHookPath = Join-Path `
        -Path $strRepositoryRootPath `
        -ChildPath '.github/workflows/Invoke-LockedPythonHook.ps1'
    $scriptblockInvokeLockedPythonHookFixture = {
        param([string] $PathValue)

        $objStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $objStartInfo.FileName = [Environment]::ProcessPath
        $objStartInfo.WorkingDirectory = $strRepositoryRootPath
        $objStartInfo.UseShellExecute = $false
        $objStartInfo.CreateNoWindow = $true
        $objStartInfo.RedirectStandardOutput = $true
        $objStartInfo.RedirectStandardError = $true
        $objStartInfo.StandardOutputEncoding =
            [System.Text.UTF8Encoding]::new($false)
        $objStartInfo.StandardErrorEncoding =
            [System.Text.UTF8Encoding]::new($false)
        $objStartInfo.Environment['PATH'] = $PathValue
        foreach ($strArgument in @(
                '-NoLogo',
                '-NoProfile',
                '-NonInteractive',
                '-File',
                $strLockedPythonHookPath,
                '-Module',
                'pre_commit_hooks.check_json',
                'package.json'
            )) {
            $objStartInfo.ArgumentList.Add($strArgument)
        }

        $objProcess = [System.Diagnostics.Process]::new()
        $objProcess.StartInfo = $objStartInfo
        try {
            if (-not $objProcess.Start()) {
                throw 'Could not start a locked Python hook fixture.'
            }
            $objStandardOutputTask = $objProcess.StandardOutput.ReadToEndAsync()
            $objStandardErrorTask = $objProcess.StandardError.ReadToEndAsync()
            $objProcess.WaitForExit()
            return [pscustomobject]@{
                ExitCode = $objProcess.ExitCode
                StandardOutput = $objStandardOutputTask.GetAwaiter().GetResult()
                StandardError = $objStandardErrorTask.GetAwaiter().GetResult()
            }
        }
        finally {
            $objProcess.Dispose()
        }
    }

    $objMissingRuntimeResult = & $scriptblockInvokeLockedPythonHookFixture `
        -PathValue ''
    $strExpectedLockedPythonHookError =
        'Python 3.12 is required to run the locked pre-commit hook.'
    if ($objMissingRuntimeResult.ExitCode -ne 2 -or
        -not [string]::IsNullOrEmpty($objMissingRuntimeResult.StandardOutput) -or
        $objMissingRuntimeResult.StandardError.TrimEnd([char[]] "`r`n") -cne
            $strExpectedLockedPythonHookError) {
        throw (
            'The locked Python hook missing-runtime fixture must exit 2, ' +
            'write no stdout, and write only its required stderr diagnostic.'
        )
    }

    $objLiveLauncherPython = Get-Python312CommandContext `
        -WindowsPlatform ([bool]$IsWindows)
    if ($null -eq $objLiveLauncherPython) {
        throw 'The locked Python launcher flag fixture requires Python 3.12.'
    }
    $arrLiveLauncherFlagOutput = @(
        & $objLiveLauncherPython.Path `
            @($objLiveLauncherPython.PrefixArgument) `
            -E -P -c `
            'import sys; print(int(sys.flags.ignore_environment), int(sys.flags.safe_path), int(sys.flags.no_user_site), int(sys.flags.isolated))'
    )
    $intLiveLauncherFlagExitCode = $LASTEXITCODE
    if ($intLiveLauncherFlagExitCode -ne 0 -or
        $arrLiveLauncherFlagOutput.Count -ne 1 -or
        $arrLiveLauncherFlagOutput[0] -cne '1 1 0 0') {
        throw (
            'The locked Python launcher flags must ignore Python environment ' +
            'variables and unsafe paths without disabling the user site.'
        )
    }

    $objPythonSelectionFixtureDirectory =
        [System.IO.Directory]::CreateTempSubdirectory(
            'terraform-style-guide-python-selection-'
        )
    try {
        if ($IsWindows) {
            [System.IO.File]::WriteAllText(
                (Join-Path $objPythonSelectionFixtureDirectory.FullName 'py.cmd'),
                (@(
                        '@echo off'
                        'if "%~1"=="-3.12" if "%~2"=="-E" if "%~3"=="-P" if "%~4"=="-c" ('
                        '  if "%~6"=="" ('
                        '    echo 3.12'
                        '    exit /b 0'
                        '  )'
                        '  exit /b 1'
                        ')'
                        'exit /b 97'
                    ) -join "`r`n") + "`r`n",
                [System.Text.UTF8Encoding]::new($false)
            )
            [System.IO.File]::WriteAllText(
                (Join-Path `
                        $objPythonSelectionFixtureDirectory.FullName `
                        'python3.12.cmd'),
                (@(
                        '@echo off'
                        'if "%~1"=="-E" if "%~2"=="-P" if "%~3"=="-c" ('
                        '  if "%~5"=="" echo 3.12'
                        '  exit /b 0'
                        ')'
                        'if "%~1"=="-E" if "%~2"=="-P" if "%~3"=="-m" ('
                        '  echo selected-equivalent'
                        '  exit /b 0'
                        ')'
                        'exit /b 98'
                    ) -join "`r`n") + "`r`n",
                [System.Text.UTF8Encoding]::new($false)
            )
        }
        else {
            $strMissingModuleApplicationPath = Join-Path `
                $objPythonSelectionFixtureDirectory.FullName `
                'python3.12'
            $strValidEquivalentApplicationPath = Join-Path `
                $objPythonSelectionFixtureDirectory.FullName `
                'python3'
            [System.IO.File]::WriteAllText(
                $strMissingModuleApplicationPath,
                (@(
                        '#!/bin/sh'
                        'if [ "$1" = "-E" ] && [ "$2" = "-P" ] && [ "$3" = "-c" ] && [ "$#" -eq 4 ]; then'
                        '  printf "3.12\n"'
                        '  exit 0'
                        'fi'
                        'if [ "$1" = "-E" ] && [ "$2" = "-P" ] && [ "$3" = "-c" ] && [ "$#" -eq 5 ]; then'
                        '  exit 1'
                        'fi'
                        'exit 97'
                    ) -join "`n") + "`n",
                [System.Text.UTF8Encoding]::new($false)
            )
            [System.IO.File]::WriteAllText(
                $strValidEquivalentApplicationPath,
                (@(
                        '#!/bin/sh'
                        'if [ "$1" = "-E" ] && [ "$2" = "-P" ] && [ "$3" = "-c" ]; then'
                        '  if [ "$#" -eq 4 ]; then printf "3.12\n"; fi'
                        '  exit 0'
                        'fi'
                        'if [ "$1" = "-E" ] && [ "$2" = "-P" ] && [ "$3" = "-m" ]; then'
                        '  printf "selected-equivalent\n"'
                        '  exit 0'
                        'fi'
                        'exit 98'
                    ) -join "`n") + "`n",
                [System.Text.UTF8Encoding]::new($false)
            )
            $objExecutableMode =
                [System.IO.UnixFileMode]::UserRead -bor
                [System.IO.UnixFileMode]::UserWrite -bor
                [System.IO.UnixFileMode]::UserExecute
            [System.IO.File]::SetUnixFileMode(
                $strMissingModuleApplicationPath,
                $objExecutableMode
            )
            [System.IO.File]::SetUnixFileMode(
                $strValidEquivalentApplicationPath,
                $objExecutableMode
            )
        }

        $objPythonSelectionResult = & $scriptblockInvokeLockedPythonHookFixture `
            -PathValue $objPythonSelectionFixtureDirectory.FullName
        if ($objPythonSelectionResult.ExitCode -ne 0 -or
            $objPythonSelectionResult.StandardOutput.TrimEnd([char[]] "`r`n") -cne
                'selected-equivalent' -or
            -not [string]::IsNullOrEmpty($objPythonSelectionResult.StandardError)) {
            throw (
                'The locked Python hook must skip an exact Python 3.12 without ' +
                'the requested module and run the valid equivalent interpreter.'
            )
        }
    }
    finally {
        $strPythonSelectionFixturePath =
            $objPythonSelectionFixtureDirectory.FullName
        $strTemporaryDirectoryPath = [System.IO.Path]::GetFullPath(
            [System.IO.Path]::GetTempPath()
        )
        if (-not $strPythonSelectionFixturePath.StartsWith(
                $strTemporaryDirectoryPath,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
            throw 'The Python selection fixture cleanup path is outside the temporary directory.'
        }
        [System.IO.Directory]::Delete($strPythonSelectionFixturePath, $true)
    }

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
    $strWorkflowPackageLockContent =
        $hashtableAgentSetupInputContent['.github/workflows/package-lock.json']
    $strCopilotSetupContent =
        $hashtableAgentSetupInputContent['.github/workflows/copilot-setup-steps.yml']
    $strHuskyHookContent = $hashtableAgentSetupInputContent['.husky/pre-commit']
    $strPreCommitConfigContent =
        $hashtableAgentSetupInputContent['.pre-commit-config.yaml']
    $strStagedMarkdownHelperContent =
        $hashtableAgentSetupInputContent['.github/workflows/lint-staged-markdown.mjs']
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
    $hashtableMutablePreCommitRevision = [ordered]@{
        '011a6d15e749bb3f2d771eed9c7aa0e7e3e10ee7' = 'v1.7.12'
    }
    foreach ($objMutableRevision in $hashtableMutablePreCommitRevision.GetEnumerator()) {
        $strMutableRevisionConfig = $strPreCommitConfigContent.Replace(
            'rev: "' + $objMutableRevision.Key + '"',
            'rev: "' + $objMutableRevision.Value + '"'
        )
        if ($strMutableRevisionConfig -ceq $strPreCommitConfigContent) {
            throw "Could not create the $($objMutableRevision.Value) revision mutation."
        }
        $arrMutableRevisionFailures = @(Get-HuskySetupContractFailure `
                -RootPackageContent $strRootPackageContent `
                -WorkflowPackageContent $strWorkflowPackageContent `
                -WorkflowPackageLockContent $strWorkflowPackageLockContent `
                -HookContent $strHuskyHookContent `
                -CopilotSetupContent $strCopilotSetupContent `
                -PreCommitConfigContent $strMutableRevisionConfig `
                -StagedMarkdownHelperContent $strStagedMarkdownHelperContent)
        if (-not ($arrMutableRevisionFailures -match
                'must use reviewed full commit')) {
            throw "Mutable pre-commit revision $($objMutableRevision.Value) did not fail closed."
        }
    }
    $strRemotePythonHookMutation = $strPreCommitConfigContent.Replace(
        "  - repo: local`n    hooks:`n      - id: check-json",
        "  - repo: https://github.com/pre-commit/pre-commit-hooks`n" +
            "    rev: `"v6.0.0`"`n    hooks:`n      - id: check-json"
    )
    if ($strRemotePythonHookMutation -ceq $strPreCommitConfigContent) {
        throw 'Could not create the remote Python hook mutation.'
    }
    $arrRemotePythonHookFailures = @(Get-HuskySetupContractFailure `
            -RootPackageContent $strRootPackageContent `
            -WorkflowPackageContent $strWorkflowPackageContent `
            -WorkflowPackageLockContent $strWorkflowPackageLockContent `
            -HookContent $strHuskyHookContent `
            -CopilotSetupContent $strCopilotSetupContent `
            -PreCommitConfigContent $strRemotePythonHookMutation `
            -StagedMarkdownHelperContent $strStagedMarkdownHelperContent)
    if ($arrRemotePythonHookFailures -cnotcontains
        'Pre-commit must use two local hook groups and only one reviewed remote hook repository.') {
        throw 'The remote Python hook mutation did not fail closed.'
    }
    $strSeparatePythonEnvironmentMutation = $strPreCommitConfigContent.Replace(
        '          -Module pre_commit_hooks.check_json' + "`n" +
            '        language: system',
        '          -Module pre_commit_hooks.check_json' + "`n" +
            '        language: python'
    )
    if ($strSeparatePythonEnvironmentMutation -ceq $strPreCommitConfigContent) {
        throw 'Could not create the separate Python environment mutation.'
    }
    $arrSeparatePythonEnvironmentFailures = @(Get-HuskySetupContractFailure `
            -RootPackageContent $strRootPackageContent `
            -WorkflowPackageContent $strWorkflowPackageContent `
            -WorkflowPackageLockContent $strWorkflowPackageLockContent `
            -HookContent $strHuskyHookContent `
            -CopilotSetupContent $strCopilotSetupContent `
            -PreCommitConfigContent $strSeparatePythonEnvironmentMutation `
            -StagedMarkdownHelperContent $strStagedMarkdownHelperContent)
    if ($arrSeparatePythonEnvironmentFailures -cnotcontains
        'Python pre-commit hooks must not resolve separate environments.') {
        throw 'The separate Python environment mutation did not fail closed.'
    }
    foreach ($strYamlHookId in @('check-yaml', 'yamllint')) {
        $objYamlSelectorPattern = [regex]::new(
            "(?ms)(^      - id: $([regex]::Escape($strYamlHookId))\r?\n" +
            '.*?^        files: )\^\.\*\\\.ya\?ml\$$'
        )
        $strYamlSelectorMutation = $objYamlSelectorPattern.Replace(
            $strPreCommitConfigContent,
            '${1}^\.github/.*\.ya?ml$',
            1
        )
        if ($strYamlSelectorMutation -ceq $strPreCommitConfigContent) {
            throw "Could not create the $strYamlHookId selector mutation."
        }
        $arrYamlSelectorFailures = @(Get-HuskySetupContractFailure `
                -RootPackageContent $strRootPackageContent `
                -WorkflowPackageContent $strWorkflowPackageContent `
                -WorkflowPackageLockContent $strWorkflowPackageLockContent `
                -HookContent $strHuskyHookContent `
                -CopilotSetupContent $strCopilotSetupContent `
                -PreCommitConfigContent $strYamlSelectorMutation `
                -StagedMarkdownHelperContent $strStagedMarkdownHelperContent)
        if ($arrYamlSelectorFailures -cnotcontains
            "The $strYamlHookId hook must select all repository YAML files.") {
            throw "$strYamlHookId selector mutation did not fail closed."
        }
    }
    foreach ($strClassificationHookId in @(
            'check-json',
            'end-of-file-fixer',
            'trailing-whitespace'
        )) {
        $objClassificationSelectorPattern = [regex]::new(
            "(?ms)(^      - id: $([regex]::Escape($strClassificationHookId))\r?\n" +
            '.*?)(^            \\.github/document-metadata-classification' +
            '\\.json\r?\n)'
        )
        $strClassificationSelectorMutation =
            $objClassificationSelectorPattern.Replace(
                $strPreCommitConfigContent,
                '${1}',
                1
            )
        if ($strClassificationSelectorMutation -ceq $strPreCommitConfigContent) {
            throw (
                "Could not create the $strClassificationHookId document " +
                'classification selector mutation.'
            )
        }
        $arrClassificationSelectorFailures = @(Get-HuskySetupContractFailure `
                -RootPackageContent $strRootPackageContent `
                -WorkflowPackageContent $strWorkflowPackageContent `
                -WorkflowPackageLockContent $strWorkflowPackageLockContent `
                -HookContent $strHuskyHookContent `
                -CopilotSetupContent $strCopilotSetupContent `
                -PreCommitConfigContent $strClassificationSelectorMutation `
                -StagedMarkdownHelperContent $strStagedMarkdownHelperContent)
        $strExpectedClassificationFailure =
            "The $strClassificationHookId hook must select " +
            '.github/document-metadata-classification.json.'
        if ($arrClassificationSelectorFailures -cnotcontains
            $strExpectedClassificationFailure) {
            throw (
                "$strClassificationHookId document classification selector " +
                'mutation did not fail closed.'
            )
        }
    }
    $strPowerShell7Preflight =
        "pwsh -NoProfile -Command 'if (`$PSVersionTable." +
        "PSVersion.Major -lt 7) { exit 1 }'"
    $strWeakenedPowerShellPreflight = $strPowerShell7Preflight.Replace(
        '-lt 7',
        '-lt 6'
    )
    $arrPreCommitBootstrapMutations = @(
        [pscustomobject]@{
            Name = 'runner pin changed'
            Agents = $strAgentsContent
            Claude = $strClaudeContent
            ScriptIndex = $strScriptIndexContent
            Requirements = $strRequirementsContent.Replace('4.6.2', '4.6.1')
            Failure = 'complete reviewed binary-only Python 3.12 tool closure'
        },
        [pscustomobject]@{
            Name = 'hash enforcement removed'
            Agents = $strAgentsContent
            Claude = $strClaudeContent
            ScriptIndex = $strScriptIndexContent
            Requirements = $strRequirementsContent.Replace("--require-hashes`n", '')
            Failure = 'complete reviewed binary-only Python 3.12 tool closure'
        },
        [pscustomobject]@{
            Name = 'binary-only enforcement removed'
            Agents = $strAgentsContent
            Claude = $strClaudeContent
            ScriptIndex = $strScriptIndexContent
            Requirements = $strRequirementsContent.Replace("--only-binary=:all:`n", '')
            Failure = 'complete reviewed binary-only Python 3.12 tool closure'
        },
        [pscustomobject]@{
            Name = 'locked artifact hash removed'
            Agents = $strAgentsContent
            Claude = $strClaudeContent
            ScriptIndex = $strScriptIndexContent
            Requirements = $strRequirementsContent.Replace(
                '    --hash=sha256:a8dc6b26ad22ff227d2634a65cb388215ce6cc96bbcc5cfde7641ae87e8dacc0' +
                "`n",
                ''
            )
            Failure = 'complete reviewed binary-only Python 3.12 tool closure'
        },
        [pscustomobject]@{
            Name = 'unreviewed package added'
            Agents = $strAgentsContent
            Claude = $strClaudeContent
            ScriptIndex = $strScriptIndexContent
            Requirements = $strRequirementsContent +
                "pip==26.0.1 \\`n" +
                '    --hash=sha256:0000000000000000000000000000000000000000000000000000000000000000' +
                "`n"
            Failure = 'complete reviewed binary-only Python 3.12 tool closure'
        },
        [pscustomobject]@{
            Name = 'locked hook package removed'
            Agents = $strAgentsContent
            Claude = $strClaudeContent
            ScriptIndex = $strScriptIndexContent
            Requirements = [regex]::Replace(
                $strRequirementsContent,
                '(?m)^check-jsonschema==0\.37\.4 \\\r?\n' +
                    '    --hash=sha256:[0-9a-f]{64}\r?\n',
                '',
                1
            )
            Failure = 'complete reviewed binary-only Python 3.12 tool closure'
        },
        [pscustomobject]@{
            Name = 'AGENTS PowerShell preflight weakened'
            Agents = $strAgentsContent.Replace(
                $strPowerShell7Preflight,
                $strWeakenedPowerShellPreflight
            )
            Claude = $strClaudeContent
            ScriptIndex = $strScriptIndexContent
            Requirements = $strRequirementsContent
            Failure = 'AGENTS.md must contain this setup command exactly once'
        },
        [pscustomobject]@{
            Name = 'CLAUDE PowerShell preflight weakened'
            Agents = $strAgentsContent
            Claude = $strClaudeContent.Replace(
                $strPowerShell7Preflight,
                $strWeakenedPowerShellPreflight
            )
            ScriptIndex = $strScriptIndexContent
            Requirements = $strRequirementsContent
            Failure = 'CLAUDE.md must contain this setup command exactly once'
        },
        [pscustomobject]@{
            Name = 'script index PowerShell preflight weakened'
            Agents = $strAgentsContent
            Claude = $strClaudeContent
            ScriptIndex = $strScriptIndexContent.Replace(
                $strPowerShell7Preflight,
                $strWeakenedPowerShellPreflight
            )
            Requirements = $strRequirementsContent
            Failure = '.github/workflows/scripts-README.md must contain this setup command exactly once'
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

    $objRootOuterLintMutation = $strRootPackageContent | ConvertFrom-Json
    $objRootOuterLintMutation.scripts.'lint:md' = 'markdownlint-cli2 "**/*.md"'
    $strRootOuterLintMutation = $objRootOuterLintMutation | ConvertTo-Json -Depth 10

    $objRootNestedLintMutation = $strRootPackageContent | ConvertFrom-Json
    $objRootNestedLintMutation.scripts.'lint:md:nested' =
        'node .github/workflows/lint-nested-markdown.js'
    $strRootNestedLintMutation = $objRootNestedLintMutation | ConvertTo-Json -Depth 10

    $objWorkflowOuterLintMutation = $strWorkflowPackageContent | ConvertFrom-Json
    $objWorkflowOuterLintMutation.scripts.'lint:md' =
        'cd ../.. && markdownlint-cli2 "**/*.md" "**/*.mdc" ' +
        '"#node_modules"'
    $strWorkflowOuterLintMutation =
        $objWorkflowOuterLintMutation | ConvertTo-Json -Depth 10

    $objRootAgentTestMutation = $strRootPackageContent | ConvertFrom-Json
    $objRootAgentTestMutation.scripts.'test:agent-instructions' = 'true'
    $strRootAgentTestMutation = $objRootAgentTestMutation | ConvertTo-Json -Depth 10

    $objRootMarkdownlintDependencyMutation = $strRootPackageContent | ConvertFrom-Json
    $objRootMarkdownlintDependencyMutation.devDependencies | Add-Member `
        -NotePropertyName 'markdownlint' `
        -NotePropertyValue '0.41.0'
    $strRootMarkdownlintDependencyMutation =
        $objRootMarkdownlintDependencyMutation | ConvertTo-Json -Depth 10

    $objRootMarkdownlintCliDependencyMutation = $strRootPackageContent | ConvertFrom-Json
    $objRootMarkdownlintCliDependencyMutation.devDependencies | Add-Member `
        -NotePropertyName 'markdownlint-cli2' `
        -NotePropertyValue '0.23.2'
    $strRootMarkdownlintCliDependencyMutation =
        $objRootMarkdownlintCliDependencyMutation | ConvertTo-Json -Depth 10

    $arrHuskyMutations = @(
        ,@(
            'root outer lint stops delegating'
            $strRootOuterLintMutation
            $strWorkflowPackageContent
            $strHuskyHookContent
            'Root lint:md must delegate'
        )
        ,@(
            'root nested lint stops delegating'
            $strRootNestedLintMutation
            $strWorkflowPackageContent
            $strHuskyHookContent
            'Root lint:md:nested must delegate'
        )
        ,@(
            'workflow outer lint drifts from the reviewed command'
            $strRootPackageContent
            $strWorkflowOuterLintMutation
            $strHuskyHookContent
            'Workflow lint:md must run only the reviewed outer Markdown lint phase'
        )
        ,@(
            'root agent test becomes a no-op'
            $strRootAgentTestMutation
            $strWorkflowPackageContent
            $strHuskyHookContent
            'Root test:agent-instructions must invoke'
        )
        ,@(
            'root adds direct markdownlint dependency'
            $strRootMarkdownlintDependencyMutation
            $strWorkflowPackageContent
            $strHuskyHookContent
            'must not declare direct markdownlint because'
        )
        ,@(
            'root adds direct markdownlint-cli2 dependency'
            $strRootMarkdownlintCliDependencyMutation
            $strWorkflowPackageContent
            $strHuskyHookContent
            'must not declare direct markdownlint-cli2 because'
        )
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
                -WorkflowPackageLockContent $strWorkflowPackageLockContent `
                -HookContent $arrHuskyMutation[3] `
                -CopilotSetupContent $strCopilotSetupContent `
                -PreCommitConfigContent $strPreCommitConfigContent `
                -StagedMarkdownHelperContent $strStagedMarkdownHelperContent)
        if (-not ($arrHuskyMutationFailures -match [regex]::Escape(
                    $arrHuskyMutation[4]
                ))) {
            throw "Husky mutation '$($arrHuskyMutation[0])' did not fail closed."
        }
    }

    $strStagedInputEntryMutation = $strPreCommitConfigContent.Replace(
        ' -RequireStagedInputMatch',
        ''
    )
    if ($strStagedInputEntryMutation -ceq $strPreCommitConfigContent) {
        throw 'Could not construct the staged-input hook mutation.'
    }
    $arrStagedInputEntryMutationFailures = @(Get-HuskySetupContractFailure `
            -RootPackageContent $strRootPackageContent `
            -WorkflowPackageContent $strWorkflowPackageContent `
            -WorkflowPackageLockContent $strWorkflowPackageLockContent `
            -HookContent $strHuskyHookContent `
            -CopilotSetupContent $strCopilotSetupContent `
            -PreCommitConfigContent $strStagedInputEntryMutation `
            -StagedMarkdownHelperContent $strStagedMarkdownHelperContent)
    if ($arrStagedInputEntryMutationFailures -cnotcontains
        'The agent-instruction hook must require staged input matching.') {
        throw 'Removal of staged-input matching did not fail closed.'
    }

    $arrReviewedSetupInputMutations = @(
        [pscustomobject]@{
            Name = 'workflow package changes semantic whitespace'
            WorkflowPackage = $strWorkflowPackageContent + "`n"
            WorkflowLock = $strWorkflowPackageLockContent
            PreCommitConfig = $strPreCommitConfigContent
            Path = '.github/workflows/package.json'
        },
        [pscustomobject]@{
            Name = 'workflow lock changes bytes'
            WorkflowPackage = $strWorkflowPackageContent
            WorkflowLock = $strWorkflowPackageLockContent + "`n"
            PreCommitConfig = $strPreCommitConfigContent
            Path = '.github/workflows/package-lock.json'
        },
        [pscustomobject]@{
            Name = 'pre-commit configuration changes bytes'
            WorkflowPackage = $strWorkflowPackageContent
            WorkflowLock = $strWorkflowPackageLockContent
            PreCommitConfig = $strPreCommitConfigContent + "`n# mutation"
            Path = '.pre-commit-config.yaml'
        }
    )
    foreach ($objReviewedSetupInputMutation in $arrReviewedSetupInputMutations) {
        $arrReviewedSetupInputFailures = @(Get-HuskySetupContractFailure `
                -RootPackageContent $strRootPackageContent `
                -WorkflowPackageContent $objReviewedSetupInputMutation.WorkflowPackage `
                -WorkflowPackageLockContent $objReviewedSetupInputMutation.WorkflowLock `
                -HookContent $strHuskyHookContent `
                -CopilotSetupContent $strCopilotSetupContent `
                -PreCommitConfigContent $objReviewedSetupInputMutation.PreCommitConfig `
                -StagedMarkdownHelperContent $strStagedMarkdownHelperContent)
        $strExpectedReviewedSetupInputFailure =
            "$($objReviewedSetupInputMutation.Path) text must match the reviewed SHA-256 digest."
        if (-not ($arrReviewedSetupInputFailures -ccontains
                $strExpectedReviewedSetupInputFailure)) {
            throw (
                "Reviewed setup input mutation '$($objReviewedSetupInputMutation.Name)' " +
                'did not fail closed.'
            )
        }
    }

    $arrStagedMarkdownHelperMutationFailures = @(Get-HuskySetupContractFailure `
            -RootPackageContent $strRootPackageContent `
            -WorkflowPackageContent $strWorkflowPackageContent `
            -WorkflowPackageLockContent $strWorkflowPackageLockContent `
            -HookContent $strHuskyHookContent `
            -CopilotSetupContent $strCopilotSetupContent `
            -PreCommitConfigContent $strPreCommitConfigContent `
            -StagedMarkdownHelperContent ($strStagedMarkdownHelperContent + "`n"))
    if ($arrStagedMarkdownHelperMutationFailures -cnotcontains
        '.github/workflows/lint-staged-markdown.mjs text must match the reviewed SHA-256 digest.') {
        throw 'The staged-Markdown helper digest mutation did not fail closed.'
    }
    $strStagedMarkdownExitNormalizationMutation =
        $strStagedMarkdownHelperContent.Replace(
            '    : exitStatus.toolingFailure;',
            '    : value;'
        )
    if ($strStagedMarkdownExitNormalizationMutation -ceq
        $strStagedMarkdownHelperContent) {
        throw 'Could not create the staged-Markdown exit-normalization mutation.'
    }
    $arrStagedMarkdownExitNormalizationFailures = @(
        Get-HuskySetupContractFailure `
            -RootPackageContent $strRootPackageContent `
            -WorkflowPackageContent $strWorkflowPackageContent `
            -WorkflowPackageLockContent $strWorkflowPackageLockContent `
            -HookContent $strHuskyHookContent `
            -CopilotSetupContent $strCopilotSetupContent `
            -PreCommitConfigContent $strPreCommitConfigContent `
            -StagedMarkdownHelperContent $strStagedMarkdownExitNormalizationMutation
    )
    if ($arrStagedMarkdownExitNormalizationFailures -cnotcontains
        'The staged-Markdown helper must normalize every dependency result to exit status 0, 1, or 2.') {
        throw 'The staged-Markdown exit-normalization mutation did not fail closed.'
    }
    $arrStagedMarkdownSelectorMutationFailures = @(Get-HuskySetupContractFailure `
            -RootPackageContent $strRootPackageContent `
            -WorkflowPackageContent $strWorkflowPackageContent `
            -WorkflowPackageLockContent $strWorkflowPackageLockContent `
            -HookContent $strHuskyHookContent `
            -CopilotSetupContent $strCopilotSetupContent `
            -PreCommitConfigContent $strPreCommitConfigContent.Replace(
                '^(\.github/workflows/lint-staged-markdown\.mjs|.*\.(md|mdc))$',
                '\.(md|mdc)$'
            ) `
            -StagedMarkdownHelperContent $strStagedMarkdownHelperContent)
    if ($arrStagedMarkdownSelectorMutationFailures -cnotcontains
        'The staged-Markdown hook must select Markdown and helper-only changes.') {
        throw 'The staged-Markdown helper selector mutation did not fail closed.'
    }

    $arrCopilotSetupMutations = @(
        [pscustomobject]@{
            Name = 'reviewed root lock digest drifts'
            Content = $strCopilotSetupContent.Replace(
                'e07939c3791be364486aedc928da532870f6d9f29ec2a6a4733be2cc143f5009',
                ('0' * 64)
            )
            Failure = 'authenticate root npm input before installation: package-lock.json'
        },
        [pscustomobject]@{
            Name = 'history fetch depth drifts'
            Content = $strCopilotSetupContent.Replace(
                '          fetch-depth: 0',
                '          fetch-depth: 1'
            )
            Failure = '.github/workflows/copilot-setup-steps.yml text must match'
        },
        [pscustomobject]@{
            Name = 'published baseline setup is removed'
            Content = $strCopilotSetupContent.Replace(
                '          git remote set-head origin --auto' + "`n",
                ''
            )
            Failure = '.github/workflows/copilot-setup-steps.yml text must match'
        },
        [pscustomobject]@{
            Name = 'checkout action commit drifts'
            Content = $strCopilotSetupContent.Replace(
                '3d3c42e5aac5ba805825da76410c181273ba90b1',
                '0000000000000000000000000000000000000000'
            )
            Failure = '.github/workflows/copilot-setup-steps.yml text must match'
        },
        [pscustomobject]@{
            Name = 'setup-node action commit drifts'
            Content = $strCopilotSetupContent.Replace(
                '820762786026740c76f36085b0efc47a31fe5020',
                '0000000000000000000000000000000000000000'
            )
            Failure = '.github/workflows/copilot-setup-steps.yml text must match'
        },
        [pscustomobject]@{
            Name = 'job timeout drifts'
            Content = $strCopilotSetupContent.Replace(
                '    timeout-minutes: 30',
                '    timeout-minutes: 31'
            )
            Failure = '.github/workflows/copilot-setup-steps.yml text must match'
        },
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
        },
        [pscustomobject]@{
            Name = 'setup-python commit drifts'
            Content = $strCopilotSetupContent.Replace(
                '5fda3b95a4ea91299a34e894583c3862153e4b97',
                '0000000000000000000000000000000000000000'
            )
            Failure = 'reviewed setup-python v7.0.0 commit once'
        },
        [pscustomobject]@{
            Name = 'Python selector drifts'
            Content = $strCopilotSetupContent.Replace(
                '          python-version: "3.12"',
                '          python-version: "3.11"'
            )
            Failure = 'locked Python setup line once'
        },
        [pscustomobject]@{
            Name = 'Python requirements cache input is removed'
            Content = $strCopilotSetupContent.Replace(
                '          cache-dependency-path: requirements-dev.txt' + "`n",
                ''
            )
            Failure = 'locked Python setup line once'
        },
        [pscustomobject]@{
            Name = 'Python install bypasses the requirements file'
            Content = $strCopilotSetupContent.Replace(
                '          python -m pip install --requirement requirements-dev.txt',
                '          python -m pip install pre-commit'
            )
            Failure = 'authenticate requirements before pip installs them'
        },
        [pscustomobject]@{
            Name = 'reviewed Python requirements digest drifts'
            Content = $strCopilotSetupContent.Replace(
                'f9aaac5456d8c076becff82222a49a3a16ef1267de93d347ebcac0fe3a3f5652',
                ('0' * 64)
            )
            Failure = 'authenticate requirements before pip installs them'
        },
        [pscustomobject]@{
            Name = 'Python dependency verification is removed'
            Content = $strCopilotSetupContent.Replace(
                '          python -m pip check' + "`n",
                ''
            )
            Failure = 'locked Python setup line once'
        },
        [pscustomobject]@{
            Name = 'complete pre-commit gate is removed'
            Content = $strCopilotSetupContent.Replace(
                '          python -m pre_commit run --all-files' + "`n",
                ''
            )
            Failure = 'complete pre-commit gate directly after activation'
        },
        [pscustomobject]@{
            Name = 'requirements file is removed from immutable inputs'
            Content = $strCopilotSetupContent.Replace(
                '            requirements-dev.txt' + "`n",
                ''
            )
            Failure = 'protect requirements-dev.txt in the immutable-input list'
        }
    )
    foreach ($objCopilotSetupMutation in $arrCopilotSetupMutations) {
        $arrCopilotSetupFailures = @(Get-HuskySetupContractFailure `
                -RootPackageContent $strRootPackageContent `
                -WorkflowPackageContent $strWorkflowPackageContent `
                -WorkflowPackageLockContent $strWorkflowPackageLockContent `
                -HookContent $strHuskyHookContent `
                -CopilotSetupContent $objCopilotSetupMutation.Content `
                -PreCommitConfigContent $strPreCommitConfigContent `
                -StagedMarkdownHelperContent $strStagedMarkdownHelperContent)
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

    $strOptionalUpdatedDate = $script:strMaximumMetadataUtcDate
    $strOptionalVersionDate = $strOptionalUpdatedDate.Replace('-', '')
    $strOptionalNoMetadata = @(
        '# Optional metadata fixture'
        ''
        'Body.'
    ) -join "`n"
    $strOptionalValidMetadata = @(
        '# Optional metadata fixture'
        ''
        "**Version:** 1.0.$strOptionalVersionDate.0"
        ''
        '## Metadata'
        ''
        '- **Status:** Active'
        '- **Owner:** Repository Maintainers'
        "- **Last Updated:** $strOptionalUpdatedDate"
        '- **Scope:** Optional metadata transition fixture.'
        ''
        'Body.'
    ) -join "`n"
    $strOptionalFencedExample = @(
        '# Optional metadata fixture'
        ''
        '```markdown'
        '## Metadata'
        ''
        '- **Status:** Invalid'
        '- **Owner:** Example'
        '- **Last Updated:** 2000-01-01'
        '- **Scope:** Example only.'
        '```'
    ) -join "`n"
    foreach ($objOptionalMetadataAbsenceFixture in @(
            [pscustomobject]@{
                Name = 'document without metadata'
                Content = $strOptionalNoMetadata
            }
            [pscustomobject]@{
                Name = 'fenced metadata example'
                Content = $strOptionalFencedExample
            }
        )) {
        if (Test-DocumentMetadataHeaderIntent `
                -Content $objOptionalMetadataAbsenceFixture.Content) {
            throw (
                'Optional metadata intent was detected in a ' +
                "$($objOptionalMetadataAbsenceFixture.Name)."
            )
        }
        $arrOptionalMetadataAbsenceFailures = @(
            Get-DocumentMetadataTransitionFailure `
                -Name 'README.md' `
                -CurrentContent $objOptionalMetadataAbsenceFixture.Content `
                -ParentContent $strOptionalValidMetadata `
                -ExpectedUtcDate $strOptionalUpdatedDate `
                -IsNewDocumentTransition $false `
                -MetadataRequired $false
        )
        if ($arrOptionalMetadataAbsenceFailures.Count -ne 0) {
            throw (
                'A valid metadata-optional absence fixture failed: ' +
                $objOptionalMetadataAbsenceFixture.Name
            )
        }
    }
    if (-not (Test-DocumentMetadataHeaderIntent `
            -Content $strOptionalValidMetadata)) {
        throw 'An operative optional metadata header was not detected.'
    }
    $arrOptionalAdoptionFailures = @(
        Get-DocumentMetadataTransitionFailure `
            -Name 'README.md' `
            -CurrentContent $strOptionalValidMetadata `
            -ParentContent $strOptionalNoMetadata `
            -ExpectedUtcDate $strOptionalUpdatedDate `
            -IsNewDocumentTransition $false `
            -MetadataRequired $false
    )
    if ($arrOptionalAdoptionFailures.Count -ne 0) {
        throw 'A valid optional metadata adoption failed.'
    }
    $strOptionalInvalidStatus = $strOptionalValidMetadata.Replace(
        '- **Status:** Active',
        '- **Status:** Invalid'
    )
    $strOptionalMissingScope = $strOptionalValidMetadata.Replace(
        "- **Scope:** Optional metadata transition fixture.`n",
        ''
    )
    $strOptionalMismatchedVersion = $strOptionalValidMetadata.Replace(
        "**Version:** 1.0.$strOptionalVersionDate.0",
        '**Version:** 1.0.20000101.0'
    )
    foreach ($objInvalidOptionalMetadataFixture in @(
            [pscustomobject]@{
                Name = 'invalid status'
                Content = $strOptionalInvalidStatus
                Failure = 'Status'
            }
            [pscustomobject]@{
                Name = 'missing Scope'
                Content = $strOptionalMissingScope
                Failure = 'Scope'
            }
            [pscustomobject]@{
                Name = 'unsynchronized Version'
                Content = $strOptionalMismatchedVersion
                Failure = 'Version and Last Updated'
            }
        )) {
        $arrInvalidOptionalMetadataFailures = @(
            Get-DocumentMetadataTransitionFailure `
                -Name 'README.md' `
                -CurrentContent $objInvalidOptionalMetadataFixture.Content `
                -ParentContent $strOptionalNoMetadata `
                -ExpectedUtcDate $strOptionalUpdatedDate `
                -IsNewDocumentTransition $false `
                -MetadataRequired $false
        )
        if (-not ($arrInvalidOptionalMetadataFailures -match
                [regex]::Escape($objInvalidOptionalMetadataFixture.Failure))) {
            throw (
                'An invalid optional metadata fixture did not fail closed: ' +
                $objInvalidOptionalMetadataFixture.Name
            )
        }
    }
    $strOptionalPastUpdatedDate =
        $script:objValidationUtcNow.AddDays(-1).ToString('yyyy-MM-dd')
    $strOptionalPastVersionDate = $strOptionalPastUpdatedDate.Replace('-', '')
    $strOptionalPastMetadata = $strOptionalValidMetadata.Replace(
        $strOptionalVersionDate,
        $strOptionalPastVersionDate
    ).Replace(
        $strOptionalUpdatedDate,
        $strOptionalPastUpdatedDate
    )
    $arrOptionalStaleTransitionFailures = @(
        Get-DocumentMetadataTransitionFailure `
            -Name 'README.md' `
            -CurrentContent ($strOptionalPastMetadata + "`n`nChanged body.") `
            -ParentContent $strOptionalPastMetadata `
            -ExpectedUtcDate $strOptionalUpdatedDate `
            -IsNewDocumentTransition $false `
            -MetadataRequired $false
    )
    if (-not ($arrOptionalStaleTransitionFailures -match
            'Last Updated must be')) {
        throw 'An optional metadata transition with a stale date was accepted.'
    }
    $arrOptionalRemovalFailures = @(
        Get-DocumentMetadataTransitionFailure `
            -Name 'README.md' `
            -CurrentContent $strOptionalNoMetadata `
            -ParentContent $strOptionalValidMetadata `
            -ExpectedUtcDate $strOptionalUpdatedDate `
            -IsNewDocumentTransition $false `
            -MetadataRequired $false
    )
    if ($arrOptionalRemovalFailures.Count -ne 0) {
        throw 'A valid removal of optional metadata failed.'
    }
    $arrOptionalLegacyRepairFailures = @(
        Get-DocumentMetadataTransitionFailure `
            -Name 'README.md' `
            -CurrentContent $strOptionalValidMetadata `
            -ParentContent $strOptionalInvalidStatus `
            -ExpectedUtcDate $strOptionalUpdatedDate `
            -IsNewDocumentTransition $false `
            -MetadataRequired $false
    )
    if ($arrOptionalLegacyRepairFailures.Count -ne 0) {
        throw 'A valid repair of malformed optional metadata failed.'
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

    $arrLegacyProcessPaths = @(
        '.github/workflows/MARKDOWN-LINTING-IMPLEMENTATION.md'
        '.github/workflows/scripts-README.md'
    )
    foreach ($strLegacyProcessPath in $arrLegacyProcessPaths) {
        $objLegacyProcessContext = $listGovernedDocumentContexts |
            Where-Object { $_.Path -ceq $strLegacyProcessPath }
        if ($null -eq $objLegacyProcessContext) {
            throw "Could not locate legacy process context: $strLegacyProcessPath"
        }
        $objLegacyProcessMetadataContext = Get-DocumentMetadataContext `
            -Content $objLegacyProcessContext.Content
        if ($null -ne $objLegacyProcessMetadataContext.Failure) {
            throw "Could not parse legacy process metadata: $strLegacyProcessPath"
        }
        $strLegacyProcessParentContent = Read-GitRevisionText `
            -RepositoryRootPath $strRepositoryRootPath `
            -Revision $script:strLegacyProcessParentRevision `
            -RepositoryRelativePath $strLegacyProcessPath `
            -MaximumBytes $objLegacyProcessContext.MaximumBytes `
            -RequireRegularFile
        if (-not (Test-LegacyMetadataParentContent `
                -Name $strLegacyProcessPath `
                -Content $strLegacyProcessParentContent)) {
            throw "The exact legacy process parent was not accepted: $strLegacyProcessPath"
        }
        if (Test-LegacyMetadataParentContent `
                -Name $strLegacyProcessPath `
                -Content ($strLegacyProcessParentContent + ' ')) {
            throw "A changed legacy process parent was accepted: $strLegacyProcessPath"
        }
        $strOtherLegacyProcessPath = @(
            $arrLegacyProcessPaths |
                Where-Object { $_ -cne $strLegacyProcessPath }
        )[0]
        if (Test-LegacyMetadataParentContent `
                -Name $strOtherLegacyProcessPath `
                -Content $strLegacyProcessParentContent) {
            throw "A legacy process parent matched the wrong path: $strLegacyProcessPath"
        }
        $objLegacyProcessExpectedDate = [DateTime]::ParseExact(
            $objLegacyProcessMetadataContext.UpdatedDate,
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $strLegacyProcessStaleDate = $objLegacyProcessExpectedDate.AddDays(-1).ToString(
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $strLegacyProcessStaleCurrent = $objLegacyProcessContext.Content.Replace(
            "- **Last Updated:** $($objLegacyProcessMetadataContext.UpdatedDate)",
            "- **Last Updated:** $strLegacyProcessStaleDate"
        )
        $arrLegacyProcessStaleFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name $strLegacyProcessPath `
                -CurrentContent $strLegacyProcessStaleCurrent `
                -ParentContent $strLegacyProcessParentContent `
                -ExpectedUtcDate $objLegacyProcessMetadataContext.UpdatedDate `
                -IsNewDocumentTransition $false)
        if (-not ($arrLegacyProcessStaleFailures -match 'Last Updated must be')) {
            throw "A legacy process transition accepted a stale date: $strLegacyProcessPath"
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
        '.github/instructions/yaml.instructions.md',
        'STYLE_GUIDE.md'
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

    $arrNewlyCoveredUnversionedPaths = @(
        '.claude/commands/review-loop.md',
        'STYLE_GUIDE_RATIONALE.md',
        'docs/ISSUE_EVALUATION_PROMPT.md',
        'docs/T1-SUPPLY-FREEZE-v1.md'
    )
    $arrNewlyCoveredUnversionedPaths += $arrGovernedDecisionPaths
    foreach ($strNewlyCoveredPath in $arrNewlyCoveredUnversionedPaths) {
        $objDocumentContext = $listGovernedDocumentContexts |
            Where-Object { $_.Path -ceq $strNewlyCoveredPath }
        if ($null -eq $objDocumentContext) {
            throw "Could not locate newly covered metadata input: $strNewlyCoveredPath"
        }
        $objMetadataContext = Get-DocumentMetadataContext `
            -Content $objDocumentContext.Content
        if ($null -ne $objMetadataContext.Failure -or
            $objMetadataContext.HasVersion) {
            throw "Could not parse unversioned metadata input: $strNewlyCoveredPath"
        }
        $objUpdatedDate = [DateTime]::ParseExact(
            $objMetadataContext.UpdatedDate,
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $strStaleUpdatedDate = $objUpdatedDate.AddDays(-1).ToString(
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $strMetadataOnlyRollbackMutation = $objDocumentContext.Content.Replace(
            "- **Last Updated:** $($objMetadataContext.UpdatedDate)",
            "- **Last Updated:** $strStaleUpdatedDate"
        )
        $strExpectedRollbackFailure =
            "$strNewlyCoveredPath Last Updated must not move backward from " +
            "$($objMetadataContext.UpdatedDate) to $strStaleUpdatedDate."
        $arrMetadataOnlyRollbackFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name $strNewlyCoveredPath `
                -CurrentContent $strMetadataOnlyRollbackMutation `
                -ParentContent $objDocumentContext.Content `
                -ExpectedUtcDate $objMetadataContext.UpdatedDate `
                -IsNewDocumentTransition $false)
        if ($arrMetadataOnlyRollbackFailures -cnotcontains $strExpectedRollbackFailure) {
            throw "$strNewlyCoveredPath metadata-only date rollback did not fail closed."
        }
        $strStaleMetadataMutation = $strMetadataOnlyRollbackMutation +
            [Environment]::NewLine + [Environment]::NewLine +
            'Rendered governed-document metadata mutation.'
        $arrStaleMetadataFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name $strNewlyCoveredPath `
                -CurrentContent $strStaleMetadataMutation `
                -ParentContent $objDocumentContext.Content `
                -ExpectedUtcDate $objMetadataContext.UpdatedDate `
                -IsNewDocumentTransition $false)
        if ($arrStaleMetadataFailures -cnotcontains $strExpectedRollbackFailure) {
            throw "$strNewlyCoveredPath stale-metadata mutation did not fail closed."
        }
    }

    foreach ($strFutureInstructionPath in @(
            '.github/instructions/future.instructions.md',
            '.github/instructions/terraform/naming.instructions.md',
            'module/nested/AGENTS.md',
            '.cursor/rules/terraform/naming.mdc'
        )) {
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
            throw (
                'The governed-instruction inventory mutation did not fail closed: ' +
                $strFutureInstructionPath
            )
        }
    }

    $arrDecisionInventoryFixture = @(Get-GovernedDecisionDocumentPath `
            -CandidatePath @(
                '.github/decisions/0006-workflow.md',
                'architecture/decisions/0005-design.md',
                'docs/decisions/0004-future-record.md',
                'docs/decisions/archive/0003-old-record.md',
                'docs/user/decisions/provider-selection.md',
                'docs/decisions/0005-not-markdown.txt',
                'docs/decisions/0004-future-record.md'
            ))
    if ($arrDecisionInventoryFixture.Count -ne 2 -or
        $arrDecisionInventoryFixture[0] -cne
        'docs/decisions/0004-future-record.md' -or
        $arrDecisionInventoryFixture[1] -cne
        'docs/decisions/archive/0003-old-record.md') {
        throw 'The decision inventory did not select only the configured recursive root.'
    }
    $strOrdinaryDecisionsPath = 'docs/user/decisions/provider-selection.md'
    $arrOrdinaryDecisionsSelection = @(Get-GovernedDecisionDocumentPath `
            -CandidatePath @($strOrdinaryDecisionsPath))
    $arrOrdinaryDecisionsDiscovery = @(
        Get-DiscoveredGovernedMarkdownDocumentPath `
            -CandidatePath @($strOrdinaryDecisionsPath) `
            -KnownGovernedPath $arrOrdinaryDecisionsSelection `
            -ExemptPath @($strOrdinaryDecisionsPath)
    )
    if ($arrOrdinaryDecisionsSelection.Count -ne 0 -or
        $arrOrdinaryDecisionsDiscovery.Count -ne 0) {
        throw 'An ordinary Tier 2 decisions-directory document was promoted.'
    }

    $arrDiscoveredMarkdownFixture = @(
        Get-DiscoveredGovernedMarkdownDocumentPath `
            -CandidatePath @(
                'README.md',
                'AGENTS.md',
                '.hidden/policy.mdc',
                'docs/RELEASE-RUNBOOK.md',
                'src/module.ps1'
            ) `
            -KnownGovernedPath @('AGENTS.md') `
            -ExemptPath @('README.md')
    )
    if ($arrDiscoveredMarkdownFixture.Count -ne 2 -or
        $arrDiscoveredMarkdownFixture[0] -cne '.hidden/policy.mdc' -or
        $arrDiscoveredMarkdownFixture[1] -cne 'docs/RELEASE-RUNBOOK.md') {
        throw 'The Markdown inventory did not discover nested Tier 1 candidates.'
    }
    $objClassificationFixture = Get-DocumentMetadataClassificationContext `
        -Content $strDocumentClassificationContent `
        -TrackedPath $arrTrackedRepositoryPaths
    if ($null -ne $objClassificationFixture.Failure -or
        $objClassificationFixture.ExemptPaths.Count -ne 9 -or
        $objClassificationFixture.AuthorizedExemptionPaths.Count -ne 0) {
        throw 'The repository document classification manifest is not canonical.'
    }
    $strClassificationNewLine = if ($strDocumentClassificationContent.Contains(
            "`r`n",
            [System.StringComparison]::Ordinal
        )) {
        "`r`n"
    }
    else {
        "`n"
    }
    $arrClassificationMutations = @(
        [pscustomobject]@{
            Name = 'wrong schema version'
            Content = $strDocumentClassificationContent.Replace(
                '"schemaVersion": 2',
                '"schemaVersion": 3'
            )
            Expected = 'schemaVersion must be integer 2'
        },
        [pscustomobject]@{
            Name = 'unknown property'
            Content = $strDocumentClassificationContent.Replace(
                '"schemaVersion": 2,',
                '"unknown": true, "schemaVersion": 2,'
            )
            Expected = 'unknown property'
        },
        [pscustomobject]@{
            Name = 'duplicate property'
            Content = $strDocumentClassificationContent.Replace(
                '"schemaVersion": 2,',
                '"schemaVersion": 2, "schemaVersion": 2,'
            )
            Expected = 'duplicate property'
        },
        [pscustomobject]@{
            Name = 'non-string path'
            Content = $strDocumentClassificationContent.Replace(
                '"ACKNOWLEDGMENTS.md"',
                '1'
            )
            Expected = 'entries must be strings'
        },
        [pscustomobject]@{
            Name = 'unsafe path'
            Content = $strDocumentClassificationContent.Replace(
                '"ACKNOWLEDGMENTS.md"',
                '"../unsafe.md"'
            )
            Expected = 'unsafe path'
        },
        [pscustomobject]@{
            Name = 'untracked path'
            Content = $strDocumentClassificationContent.Replace(
                '"ACKNOWLEDGMENTS.md"',
                '"AAA-UNTRACKED.md"'
            )
            Expected = 'path is not tracked'
        },
        [pscustomobject]@{
            Name = 'unsorted paths'
            Content = $strDocumentClassificationContent.Replace(
                '"ACKNOWLEDGMENTS.md",' + $strClassificationNewLine +
                    '    "CONTRIBUTING.md"',
                '"CONTRIBUTING.md",' + $strClassificationNewLine +
                    '    "ACKNOWLEDGMENTS.md"'
            )
            Expected = 'strictly ordinal-sorted'
        },
        [pscustomobject]@{
            Name = 'cross-category duplicate'
            Content = $strDocumentClassificationContent.Replace(
                '"generatedPaths": [',
                '"generatedPaths": [' + $strClassificationNewLine +
                    '    "README.md",'
            )
            Expected = 'repeats a path'
        },
        [pscustomobject]@{
            Name = 'active authorization overlap'
            Content = $strDocumentClassificationContent.Replace(
                '"authorizedExemptionPaths": []',
                '"authorizedExemptionPaths": ["README.md"]'
            )
            Expected = 'repeats a path'
        },
        [pscustomobject]@{
            Name = 'unsafe authorization path'
            Content = $strDocumentClassificationContent.Replace(
                '"authorizedExemptionPaths": []',
                '"authorizedExemptionPaths": ["../future.md"]'
            )
            Expected = 'unsafe path'
        },
        [pscustomobject]@{
            Name = 'trailing comma'
            Content = $strDocumentClassificationContent.Replace(
                '"terraform.instructions.md"',
                '"terraform.instructions.md",'
            )
            Expected = 'not strict JSON'
        }
    )
    foreach ($objClassificationMutation in $arrClassificationMutations) {
        if ($objClassificationMutation.Content -ceq
            $strDocumentClassificationContent) {
            throw (
                'The document classification mutation fixture is unavailable: ' +
                $objClassificationMutation.Name
            )
        }
        $objMutatedClassificationContext =
            Get-DocumentMetadataClassificationContext `
                -Content $objClassificationMutation.Content `
                -TrackedPath $arrTrackedRepositoryPaths
        if ($null -eq $objMutatedClassificationContext.Failure -or
            -not $objMutatedClassificationContext.Failure.Contains(
                $objClassificationMutation.Expected,
                [System.StringComparison]::Ordinal
            )) {
            throw (
                'The document classification mutation did not fail closed: ' +
                $objClassificationMutation.Name
            )
        }
    }
    $strUntrackedAuthorizationPath = 'docs/future-end-user-guide.md'
    $strAuthorizationFixtureContent = $strDocumentClassificationContent.Replace(
        '"authorizedExemptionPaths": []',
        '"authorizedExemptionPaths": ["' +
            $strUntrackedAuthorizationPath + '"]'
    )
    $objAuthorizationFixture = Get-DocumentMetadataClassificationContext `
        -Content $strAuthorizationFixtureContent `
        -TrackedPath $arrTrackedRepositoryPaths
    if ($null -ne $objAuthorizationFixture.Failure -or
        $objAuthorizationFixture.AuthorizedExemptionPaths.Count -ne 1 -or
        $objAuthorizationFixture.AuthorizedExemptionPaths[0] -cne
            $strUntrackedAuthorizationPath) {
        throw 'An inert future exemption authorization was rejected.'
    }
    $arrClassificationExpansionBaseline = @('README.md', 'templates/README.md')
    $arrUnchangedClassificationExpansionFailures = @(
        Get-DocumentMetadataClassificationExpansionFailure `
            -HasTrustedBaselineManifest $true `
            -TrustedBaselineExemptPath $arrClassificationExpansionBaseline `
            -TrustedBaselineAuthorizedExemptionPath @() `
            -CandidateExemptPath $arrClassificationExpansionBaseline
    )
    if ($arrUnchangedClassificationExpansionFailures.Count -ne 0) {
        throw 'An unchanged document classification was treated as an expansion.'
    }
    $arrClassificationRemovalFailures = @(
        Get-DocumentMetadataClassificationExpansionFailure `
            -HasTrustedBaselineManifest $true `
            -TrustedBaselineExemptPath $arrClassificationExpansionBaseline `
            -TrustedBaselineAuthorizedExemptionPath @() `
            -CandidateExemptPath @('README.md')
    )
    if ($arrClassificationRemovalFailures.Count -ne 0) {
        throw 'A document classification exemption removal was rejected.'
    }
    $arrClassificationAdditionFailures = @(
        Get-DocumentMetadataClassificationExpansionFailure `
            -HasTrustedBaselineManifest $true `
            -TrustedBaselineExemptPath $arrClassificationExpansionBaseline `
            -TrustedBaselineAuthorizedExemptionPath @() `
            -CandidateExemptPath @(
                'README.md',
                'docs/RELEASE-RUNBOOK.md',
                'templates/README.md'
            )
    )
    if ($arrClassificationAdditionFailures.Count -ne 1 -or
        $arrClassificationAdditionFailures[0] -cne
            ('The document classification adds an unauthenticated metadata ' +
             'exemption: docs/RELEASE-RUNBOOK.md. Add the exact path to ' +
             'authorizedExemptionPaths in a separate change and publish that ' +
             'authorization before activating the exemption.')) {
        throw 'A document classification exemption addition did not fail closed.'
    }
    $arrAuthorizedClassificationAdditionFailures = @(
        Get-DocumentMetadataClassificationExpansionFailure `
            -HasTrustedBaselineManifest $true `
            -TrustedBaselineExemptPath $arrClassificationExpansionBaseline `
            -TrustedBaselineAuthorizedExemptionPath @(
                'docs/RELEASE-RUNBOOK.md'
            ) `
            -CandidateExemptPath @(
                'README.md',
                'docs/RELEASE-RUNBOOK.md',
                'templates/README.md'
            )
    )
    if ($arrAuthorizedClassificationAdditionFailures.Count -ne 0) {
        throw 'A published exemption authorization was not consumable.'
    }
    $arrClassificationBootstrapFailures = @(
        Get-DocumentMetadataClassificationExpansionFailure `
            -HasTrustedBaselineManifest $false `
            -TrustedBaselineExemptPath @() `
            -TrustedBaselineAuthorizedExemptionPath @() `
            -CandidateExemptPath @('README.md', 'docs/RELEASE-RUNBOOK.md')
    )
    if ($arrClassificationBootstrapFailures.Count -ne 0) {
        throw 'The one-time document classification bootstrap was rejected.'
    }
    foreach ($objUnsafeMarkdownInventoryFixture in @(
            [pscustomobject]@{
                Name = 'newline path'
                Candidate = @("docs/unsafe`nname.md")
                Known = @()
                Exempt = @()
                Expected = 'unsafe Markdown path'
            },
            [pscustomobject]@{
                Name = 'duplicate candidate'
                Candidate = @('docs/repeated.md', 'docs/repeated.md')
                Known = @()
                Exempt = @()
                Expected = 'duplicate path'
            },
            [pscustomobject]@{
                Name = 'stale exemption'
                Candidate = @('docs/active.md')
                Known = @()
                Exempt = @('README.md')
                Expected = 'exception is not tracked'
            },
            [pscustomobject]@{
                Name = 'overlapping classification'
                Candidate = @('README.md')
                Known = @('README.md')
                Exempt = @('README.md')
                Expected = 'both governed and exempt'
            }
        )) {
        $boolInventoryFixtureRejected = $false
        try {
            Get-DiscoveredGovernedMarkdownDocumentPath `
                -CandidatePath $objUnsafeMarkdownInventoryFixture.Candidate `
                -KnownGovernedPath $objUnsafeMarkdownInventoryFixture.Known `
                -ExemptPath $objUnsafeMarkdownInventoryFixture.Exempt
        }
        catch {
            $boolInventoryFixtureRejected = $_.Exception.Message.Contains(
                $objUnsafeMarkdownInventoryFixture.Expected,
                [System.StringComparison]::Ordinal
            )
        }
        if (-not $boolInventoryFixtureRejected) {
            throw (
                'The Markdown inventory mutation did not fail closed: ' +
                $objUnsafeMarkdownInventoryFixture.Name
            )
        }
    }

    $strValidDiscoveredMetadata = @'
# Release Runbook

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-09-10
- **Scope:** Covers release operations.
'@
    if ($null -ne (
            Get-DocumentMetadataContext -Content $strValidDiscoveredMetadata
        ).Failure) {
        throw 'A discovered Tier 1 document with valid metadata was rejected.'
    }
    foreach ($objInvalidDiscoveredMetadataFixture in @(
            [pscustomobject]@{
                Name = 'missing metadata'
                Content = "# Release Runbook`n`nRelease steps."
            },
            [pscustomobject]@{
                Name = 'fenced fake metadata'
                Content = @'
# Release Runbook

```markdown
- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-09-10
- **Scope:** Covers release operations.
```
'@
            }
        )) {
        if ($null -eq (
                Get-DocumentMetadataContext `
                    -Content $objInvalidDiscoveredMetadataFixture.Content
            ).Failure) {
            throw (
                'The discovered Tier 1 metadata fixture was accepted: ' +
                $objInvalidDiscoveredMetadataFixture.Name
            )
        }
    }
    $strRepresentativeDecisionPath = @($arrGovernedDecisionPaths)[0]
    $objRepresentativeDecision = $listGovernedDocumentContexts |
        Where-Object { $_.Path -ceq $strRepresentativeDecisionPath }
    if ($null -eq $objRepresentativeDecision) {
        throw 'Could not locate a representative governed decision record.'
    }
    $objRepresentativeDecisionMetadata = Get-DocumentMetadataContext `
        -Content $objRepresentativeDecision.Content
    if ($null -ne $objRepresentativeDecisionMetadata.Failure) {
        throw 'Could not parse the representative governed decision record.'
    }
    $strRepresentativeDecisionStatusLine = [regex]::Match(
        $objRepresentativeDecision.Content,
        '(?m)^- \*\*Status:\*\* [^\r\n]+$'
    ).Value
    $strRepresentativeDecisionDateLine = [regex]::Match(
        $objRepresentativeDecision.Content,
        '(?m)^- \*\*Date:\*\* [^\r\n]+$'
    ).Value
    if ([string]::IsNullOrEmpty($strRepresentativeDecisionDateLine)) {
        throw 'The representative decision record has no Date fixture.'
    }
    foreach ($strAllowedDecisionStatus in $script:arrAllowedDecisionRecordStatuses) {
        $strAllowedDecisionContent = $objRepresentativeDecision.Content.Replace(
            $strRepresentativeDecisionStatusLine,
            "- **Status:** $strAllowedDecisionStatus"
        )
        $arrAllowedDecisionFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name $strRepresentativeDecisionPath `
                -CurrentContent $strAllowedDecisionContent `
                -ParentContent $objRepresentativeDecision.Content `
                -ExpectedUtcDate $objRepresentativeDecisionMetadata.UpdatedDate `
                -IsNewDocumentTransition $false)
        if ($arrAllowedDecisionFailures.Count -ne 0) {
            throw "Governed decision status failed: $strAllowedDecisionStatus"
        }
    }
    foreach ($strRejectedDecisionStatus in @('Draft', 'Active')) {
        $strRejectedDecisionContent = $objRepresentativeDecision.Content.Replace(
            $strRepresentativeDecisionStatusLine,
            "- **Status:** $strRejectedDecisionStatus"
        )
        $arrRejectedDecisionFailures = @(Get-DocumentMetadataTransitionFailure `
                -Name $strRepresentativeDecisionPath `
                -CurrentContent $strRejectedDecisionContent `
                -ParentContent $objRepresentativeDecision.Content `
                -ExpectedUtcDate $objRepresentativeDecisionMetadata.UpdatedDate `
                -IsNewDocumentTransition $false)
        $strExpectedDecisionStatusFailure =
            "$strRepresentativeDecisionPath Status must be one of " +
            ($script:arrAllowedDecisionRecordStatuses -join ', ') +
            ' for a governed decision record.'
        if ($arrRejectedDecisionFailures -cnotcontains
            $strExpectedDecisionStatusFailure) {
            throw "Governed decision status passed: $strRejectedDecisionStatus"
        }
    }
    $strNestedDecisionPath = 'docs/decisions/archive/0003-old-record.md'
    $strNestedDecisionDraftContent = $objRepresentativeDecision.Content.Replace(
        $strRepresentativeDecisionStatusLine,
        '- **Status:** Draft'
    )
    $arrNestedDecisionDraftFailures = @(Get-DocumentMetadataTransitionFailure `
            -Name $strNestedDecisionPath `
            -CurrentContent $strNestedDecisionDraftContent `
            -ParentContent $objRepresentativeDecision.Content `
            -ExpectedUtcDate $objRepresentativeDecisionMetadata.UpdatedDate `
            -IsNewDocumentTransition $false)
    $strExpectedNestedDecisionStatusFailure =
        "$strNestedDecisionPath Status must be one of " +
        ($script:arrAllowedDecisionRecordStatuses -join ', ') +
        ' for a governed decision record.'
    if ($arrNestedDecisionDraftFailures -cnotcontains
        $strExpectedNestedDecisionStatusFailure) {
        throw 'A nested governed decision record accepted a non-decision status.'
    }

    $arrValidDecisionContractFailures = @(
        Get-DecisionRecordContractFailure `
            -Name $strRepresentativeDecisionPath `
            -Content $objRepresentativeDecision.Content `
            -MetadataContext $objRepresentativeDecisionMetadata
    )
    if ($arrValidDecisionContractFailures.Count -ne 0) {
        throw 'A valid decision-record contract was rejected.'
    }
    $strBareDecisionMetadataContent = [regex]::Replace(
        $objRepresentativeDecision.Content,
        '(?m)^## Metadata\r?\n',
        '',
        1
    )
    $objBareDecisionMetadataContext = Get-DocumentMetadataContext `
        -Content $strBareDecisionMetadataContent
    if ($null -ne $objBareDecisionMetadataContext.Failure -or
        @(Get-DecisionRecordContractFailure `
                -Name $strRepresentativeDecisionPath `
                -Content $strBareDecisionMetadataContent `
                -MetadataContext $objBareDecisionMetadataContext).Count -ne 0) {
        throw 'A valid bare-list decision metadata header was rejected.'
    }
    $arrInvalidDecisionContractFixtures = @(
        [pscustomobject]@{
            Name = 'invalid leaf name'
            Path = 'docs/decisions/example.md'
            Content = $objRepresentativeDecision.Content
            Expected = 'must use the decision-record leaf name NNNN-short-title.md.'
        },
        [pscustomobject]@{
            Name = 'missing Date'
            Path = $strRepresentativeDecisionPath
            Content = $objRepresentativeDecision.Content.Replace(
                $strRepresentativeDecisionDateLine,
                ''
            )
            Expected = 'must contain one exact Date: YYYY-MM-DD list item in Metadata.'
        },
        [pscustomobject]@{
            Name = 'impossible Date'
            Path = $strRepresentativeDecisionPath
            Content = $objRepresentativeDecision.Content.Replace(
                $strRepresentativeDecisionDateLine,
                '- **Date:** 2026-02-30'
            )
            Expected = 'must contain one exact Date: YYYY-MM-DD list item in Metadata.'
        },
        [pscustomobject]@{
            Name = 'fenced Date'
            Path = $strRepresentativeDecisionPath
            Content = $objRepresentativeDecision.Content.Replace(
                $strRepresentativeDecisionDateLine,
                (@(
                        '```markdown'
                        $strRepresentativeDecisionDateLine
                        '```'
                    ) -join [Environment]::NewLine)
            )
            Expected = 'must contain one exact Date: YYYY-MM-DD list item in Metadata.'
        },
        [pscustomobject]@{
            Name = 'Date outside Metadata'
            Path = $strRepresentativeDecisionPath
            Content = $objRepresentativeDecision.Content.Replace(
                $strRepresentativeDecisionDateLine,
                ''
            ) + [Environment]::NewLine + $strRepresentativeDecisionDateLine
            Expected = 'must contain one exact Date: YYYY-MM-DD list item in Metadata.'
        },
        [pscustomobject]@{
            Name = 'missing Context heading'
            Path = $strRepresentativeDecisionPath
            Content = [regex]::Replace(
                $objRepresentativeDecision.Content,
                '(?m)^## (?:(?:\d+)\. )?Context$',
                '### Context',
                1
            )
            Expected = 'must contain one operative level-two Context heading.'
        },
        [pscustomobject]@{
            Name = 'duplicate Decision heading'
            Path = $strRepresentativeDecisionPath
            Content = $objRepresentativeDecision.Content +
                [Environment]::NewLine + '## Decision' +
                [Environment]::NewLine + [Environment]::NewLine +
                'Duplicate decision fixture.'
            Expected = 'must contain one operative level-two Decision heading.'
        },
        [pscustomobject]@{
            Name = 'comment-hidden Consequences heading'
            Path = $strRepresentativeDecisionPath
            Content = [regex]::Replace(
                $objRepresentativeDecision.Content,
                '(?m)^## (?:(?:\d+)\. )?Consequences$',
                '<!-- ## Consequences -->',
                1
            )
            Expected = 'must contain one operative level-two Consequences heading.'
        },
        [pscustomobject]@{
            Name = 'raw-HTML-hidden Decision heading'
            Path = $strRepresentativeDecisionPath
            Content = [regex]::Replace(
                $objRepresentativeDecision.Content,
                '(?m)^## (?:(?:\d+)\. )?Decision$',
                (@(
                        '<div>'
                        '## Decision'
                        '</div>'
                    ) -join [Environment]::NewLine),
                1
            )
            Expected = 'must contain one operative level-two Decision heading.'
        },
        [pscustomobject]@{
            Name = 'fenced Alternatives heading'
            Path = $strRepresentativeDecisionPath
            Content = [regex]::Replace(
                $objRepresentativeDecision.Content,
                '(?m)^## (?:(?:\d+)\. )?Alternatives Considered$',
                (@(
                        '```markdown'
                        '## Alternatives Considered'
                        '```'
                    ) -join [Environment]::NewLine),
                1
            )
            Expected = 'must contain one operative level-two Alternatives Considered heading.'
        }
    )
    foreach ($objInvalidDecisionContractFixture in
        $arrInvalidDecisionContractFixtures) {
        if ($objInvalidDecisionContractFixture.Content -ceq
            $objRepresentativeDecision.Content -and
            $objInvalidDecisionContractFixture.Path -ceq
            $strRepresentativeDecisionPath) {
            throw (
                'A decision-record contract mutation fixture was unavailable: ' +
                $objInvalidDecisionContractFixture.Name
            )
        }
        $arrInvalidDecisionContractFailures = @(
            Get-DecisionRecordContractFailure `
                -Name $objInvalidDecisionContractFixture.Path `
                -Content $objInvalidDecisionContractFixture.Content `
                -MetadataContext $objRepresentativeDecisionMetadata
        )
        if (-not ($arrInvalidDecisionContractFailures -match
                [regex]::Escape($objInvalidDecisionContractFixture.Expected))) {
            throw (
                'The decision-record contract mutation did not fail closed: ' +
                $objInvalidDecisionContractFixture.Name
            )
        }
    }

    $arrAcceptedClaudeLocalInventoryFailures = @(
        Get-ProhibitedTrackedClaudeLocalFailure -TrackedPaths @(
            'CLAUDE-local.md',
            'CLAUDE.local.MD',
            'module/CLAUDE.md',
            'module/CLAUDE.local.md.bak'
        )
    )
    if ($arrAcceptedClaudeLocalInventoryFailures.Count -ne 0) {
        throw 'A similar non-prohibited Claude path failed validation.'
    }
    $arrRejectedClaudeLocalInventoryFailures = @(
        Get-ProhibitedTrackedClaudeLocalFailure -TrackedPaths @(
            'CLAUDE.local.md',
            'module/CLAUDE.local.md',
            'module/nested/CLAUDE.local.md'
        )
    )
    $arrExpectedClaudeLocalInventoryFailures = @(
        'Tracked personal Claude project memory is prohibited: CLAUDE.local.md',
        'Tracked personal Claude project memory is prohibited: module/CLAUDE.local.md',
        'Tracked personal Claude project memory is prohibited: module/nested/CLAUDE.local.md'
    )
    if ($arrRejectedClaudeLocalInventoryFailures.Count -ne
        $arrExpectedClaudeLocalInventoryFailures.Count) {
        throw 'The Claude local-memory inventory mutation count was not exact.'
    }
    foreach ($strExpectedClaudeLocalInventoryFailure in
        $arrExpectedClaudeLocalInventoryFailures) {
        if ($arrRejectedClaudeLocalInventoryFailures -cnotcontains
            $strExpectedClaudeLocalInventoryFailure) {
            throw (
                'The Claude local-memory inventory mutation did not fail closed: ' +
                $strExpectedClaudeLocalInventoryFailure
            )
        }
    }

    $arrMetadataOptionalContexts = @(
        $listGovernedDocumentContexts |
            Where-Object { -not $_.RequiresMetadata }
    )
    $arrExpectedMetadataOptionalPaths = @(
        '.github/copilot-instructions.md'
        $arrMetadataExemptMarkdownDocuments
    ) | Select-Object -Unique
    if ($arrMetadataOptionalContexts.Count -ne
        $arrExpectedMetadataOptionalPaths.Count) {
        throw 'The governed metadata-optional document count is not exact.'
    }
    foreach ($strExpectedMetadataOptionalPath in
        $arrExpectedMetadataOptionalPaths) {
        if (@(
                $arrMetadataOptionalContexts |
                    Where-Object { $_.Path -ceq $strExpectedMetadataOptionalPath }
            ).Count -ne 1) {
            throw (
                'A governed metadata-optional document is missing or duplicated: ' +
                $strExpectedMetadataOptionalPath
            )
        }
    }
    $arrUnexpectedMetadataRequirements = @(
        $listGovernedDocumentContexts |
            Where-Object {
                $arrExpectedMetadataOptionalPaths -cnotcontains $_.Path -and
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
    $objMetadataHeadingPattern = [regex]::new(
        '(?m)^## Metadata\r?\n(?:\r?\n)?'
    )
    $strBareMetadataListMutation = $objMetadataHeadingPattern.Replace(
        $objRepresentativeDocument.Content,
        '',
        1
    )
    if ([string]::Equals(
            $strBareMetadataListMutation,
            $objRepresentativeDocument.Content,
            [System.StringComparison]::Ordinal
        )) {
        throw 'Could not construct the bare metadata-list mutation.'
    }
    $objBareMetadataListContext = Get-DocumentMetadataContext `
        -Content $strBareMetadataListMutation
    if ($null -ne $objBareMetadataListContext.Failure) {
        throw (
            'A documented direct metadata list failed validation: ' +
            $objBareMetadataListContext.Failure
        )
    }
    $strInterveningMetadataListMutation = $objMetadataHeadingPattern.Replace(
        $objRepresentativeDocument.Content,
        "Intervening paragraph.`n`n",
        1
    )
    $objInterveningMetadataListContext = Get-DocumentMetadataContext `
        -Content $strInterveningMetadataListMutation
    if ($objInterveningMetadataListContext.Failure -notmatch
        'must place the metadata header block') {
        throw 'An intervening paragraph before a direct metadata list did not fail closed.'
    }
    $strMixedMetadataLayoutMutation = $objMetadataHeadingPattern.Replace(
        $objRepresentativeDocument.Content,
        "- **Status:** Active`n`n## Metadata`n`n",
        1
    )
    $objMixedMetadataLayoutContext = Get-DocumentMetadataContext `
        -Content $strMixedMetadataLayoutMutation
    if ($objMixedMetadataLayoutContext.Failure -notmatch
        'must place Metadata as the first level-two heading') {
        throw 'A mixed direct-list and Metadata-heading layout did not fail closed.'
    }
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

    $arrDisabledStagedMatchFailures = @(Get-StagedInputMatchFailure `
            -DisplayName 'disabled staged fixture' `
            -WorktreeContent 'worktree bytes' `
            -IndexContent 'index bytes')
    if ($arrDisabledStagedMatchFailures.Count -ne 0) {
        throw 'A disabled staged-input match produced a failure.'
    }
    $arrEqualStagedMatchFailures = @(Get-StagedInputMatchFailure `
            -DisplayName 'equal staged fixture' `
            -RequireMatch `
            -WorktreeContent 'same bytes' `
            -IndexContent 'same bytes')
    if ($arrEqualStagedMatchFailures.Count -ne 0) {
        throw 'Equal staged and worktree content produced a failure.'
    }
    $arrDivergentStagedMatchFailures = @(Get-StagedInputMatchFailure `
            -DisplayName 'divergent staged fixture' `
            -RequireMatch `
            -WorktreeContent 'valid worktree bytes' `
            -IndexContent 'invalid staged bytes')
    $strExpectedStagedMatchFailure =
        'divergent staged fixture worktree content must match its staged Git index blob.'
    if ($arrDivergentStagedMatchFailures.Count -ne 1 -or
        $arrDivergentStagedMatchFailures[0] -cne $strExpectedStagedMatchFailure) {
        throw 'Divergent staged and worktree content did not fail closed.'
    }

    $strAncestorLinkFixtureRoot = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine(
            [System.IO.Path]::GetTempPath(),
            'agent-instruction-ancestor-link-' + [guid]::NewGuid().ToString('N')
        )
    )
    $strAncestorLinkSystemTempRoot = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::GetTempPath()
    )
    if (-not $strAncestorLinkFixtureRoot.StartsWith(
            $strAncestorLinkSystemTempRoot,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'The ancestor-link fixture root escaped the system temporary directory.'
    }
    $strAncestorLinkRepositoryRoot = Join-Path `
        -Path $strAncestorLinkFixtureRoot `
        -ChildPath 'repository'
    $strAncestorLinkExternalRoot = Join-Path `
        -Path $strAncestorLinkFixtureRoot `
        -ChildPath 'external'
    $strAncestorLinkPath = Join-Path `
        -Path $strAncestorLinkRepositoryRoot `
        -ChildPath 'docs'
    $strAncestorLinkTrackedPath = Join-Path `
        -Path $strAncestorLinkPath `
        -ChildPath 'input.md'
    $strAncestorLinkExternalPath = Join-Path `
        -Path $strAncestorLinkExternalRoot `
        -ChildPath 'input.md'
    try {
        [void][System.IO.Directory]::CreateDirectory($strAncestorLinkPath)
        [void][System.IO.Directory]::CreateDirectory($strAncestorLinkExternalRoot)
        [System.IO.File]::WriteAllText(
            $strAncestorLinkTrackedPath,
            'tracked bytes',
            [System.Text.UTF8Encoding]::new($false)
        )
        & git -C $strAncestorLinkRepositoryRoot init --quiet
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not initialize the ancestor-link fixture repository.'
        }
        & git -C $strAncestorLinkRepositoryRoot add -- docs/input.md
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not stage the ancestor-link fixture input.'
        }
        [System.IO.File]::Delete($strAncestorLinkTrackedPath)
        [System.IO.Directory]::Delete($strAncestorLinkPath)
        [System.IO.File]::WriteAllText(
            $strAncestorLinkExternalPath,
            'external bytes',
            [System.Text.UTF8Encoding]::new($false)
        )
        if ([System.OperatingSystem]::IsWindows()) {
            [void](New-Item `
                    -ItemType Junction `
                    -Path $strAncestorLinkPath `
                    -Target $strAncestorLinkExternalRoot)
        }
        else {
            [void](New-Item `
                    -ItemType SymbolicLink `
                    -Path $strAncestorLinkPath `
                    -Target $strAncestorLinkExternalRoot)
        }
        $boolAncestorLinkRejected = $false
        try {
            [void](Read-RepositoryInputData `
                    -Path $strAncestorLinkTrackedPath `
                    -RepositoryRootPath $strAncestorLinkRepositoryRoot `
                    -RepositoryRelativePath 'docs/input.md' `
                    -DisplayName 'ancestor-link fixture' `
                    -MaximumBytes 1024)
        }
        catch {
            $strExpectedAncestorLinkFailure =
                "Repository input is unsafe:`n- ancestor-link fixture must not " +
                'traverse a symbolic link or reparse point: docs.'
            if ($_.Exception.Message -cne $strExpectedAncestorLinkFailure) {
                throw (
                    'The ancestor-link fixture returned an unexpected failure: ' +
                    $_.Exception.Message
                )
            }
            $boolAncestorLinkRejected = $true
        }
        if (-not $boolAncestorLinkRejected) {
            throw 'The ancestor-link fixture was accepted.'
        }
    }
    finally {
        if (Test-Path -LiteralPath $strAncestorLinkPath) {
            Remove-Item -LiteralPath $strAncestorLinkPath -Force
        }
        if ([System.IO.Directory]::Exists($strAncestorLinkFixtureRoot) -and
            $strAncestorLinkFixtureRoot.StartsWith(
                $strAncestorLinkSystemTempRoot,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
            Remove-Item -LiteralPath $strAncestorLinkFixtureRoot -Recurse -Force
        }
    }

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
        $strMetadataOnlyHigherVersionReset = $strAgentsContent.Replace(
            $objAgentsVersionMatch.Value,
            $strHigherVersionStem + '0'
        )
        Assert-FixtureAccepted `
            -Name "metadata-only $($objHigherVersionFixture.Name) change resets revision" `
            -AgentsContent $strMetadataOnlyHigherVersionReset `
            -ClaudeContent $strClaudeContent `
            -CodexConfigContent $strCodexConfigContent `
            -ParentAgentsContent $strAgentsContent `
            -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value
        Assert-MutationRejected `
            -Name "metadata-only $($objHigherVersionFixture.Name) change retains nonzero revision" `
            -AgentsContent $strMetadataOnlyHigherVersionReset.Replace(
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
    $strMetadataOnlyNewDayReset = $strAgentsContent.Replace(
        $objAgentsVersionMatch.Value,
        $strAgentsVersionStem + '0'
    )
    Assert-FixtureAccepted `
        -Name 'metadata-only new-day zero revision' `
        -AgentsContent $strMetadataOnlyNewDayReset `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strPreviousDateParent `
        -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value
    Assert-MutationRejected `
        -Name 'metadata-only new-day nonzero revision' `
        -AgentsContent $strMetadataOnlyNewDayReset.Replace(
            $strAgentsVersionStem + '0',
            $strAgentsVersionStem + '1'
        ) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ParentAgentsContent $strPreviousDateParent `
        -AgentsExpectedUtcDate $objAgentsUpdatedMatch.Groups['Date'].Value `
        -ExpectedFailure (
            'AGENTS.md Version revision must be 0 when major, minor, or date changes'
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
    $strMissingRevisionInputFailure = ''
    try {
        [void](Read-GitRevisionText `
                -RepositoryRootPath $strRepositoryRootPath `
                -Revision $strNewRefTestHead `
                -RepositoryRelativePath '.missing-agent-instruction-input' `
                -MaximumBytes 128 `
                -RequireRegularFile)
    }
    catch {
        $strMissingRevisionInputFailure = $_.Exception.Message
        $boolMissingRevisionInputRejected = $_.Exception.Message.Contains(
            'not one regular 100644 blob',
            [System.StringComparison]::Ordinal
        )
    }
    if (-not $boolMissingRevisionInputRejected) {
        throw (
            'A missing revision input did not fail the regular-blob check. ' +
            "Actual failure: $strMissingRevisionInputFailure"
        )
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
        $objMergeFixtureHeaderMatch = [regex]::Match(
            $strAgentsContent,
            '(?ms)\A.*?^<!-- template-sync: end markdown-reference-only -->\r?$'
        )
        if (-not $objMergeFixtureHeaderMatch.Success) {
            throw 'Could not isolate the governed metadata header for merge fixtures.'
        }
        $strMergeFixtureSourceContent = $objMergeFixtureHeaderMatch.Value +
            [Environment]::NewLine + [Environment]::NewLine +
            'Merge-transition fixture content.' + [Environment]::NewLine
        $strMergeBaseVersion = '**Version:** ' +
            $objAgentsVersionMatch.Groups['Prefix'].Value +
            $strMergeHistoricalDate.Replace('-', '') + '.0'
        $strMergeBaseContent = $strMergeFixtureSourceContent.Replace(
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

        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not initialize the disconnected-push fixture index.'
        }
        $strDisconnectedPushVersion = '**Version:** ' +
            $objAgentsVersionMatch.Groups['Prefix'].Value +
            $strMergeHistoricalDate.Replace('-', '') + '.1'
        $strDisconnectedPushContent = $strMergeBaseContent.Replace(
            $strMergeBaseVersion,
            $strDisconnectedPushVersion
        ) + [Environment]::NewLine + 'Disconnected push fixture.'
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strDisconnectedPushContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
        $strDisconnectedPushTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0 -or
            $strDisconnectedPushTree -notmatch
                '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
            throw 'Could not create the disconnected-push fixture tree.'
        }
        $strDisconnectedPushCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strDisconnectedPushTree `
            -Parents @() `
            -Timestamp ($strMergeHistoricalDate + 'T09:00:00Z') `
            -Message 'disconnected direct push'
        $hashtableDisconnectedPushArguments = @{
            Name = 'AGENTS.md'
            RepositoryRootPath = $strMergeFixtureRoot
            RepositoryRelativePath = 'AGENTS.md'
            MaximumBytes = $intAgentsMaximumInputBytes
            BaseRevision = $strMergeBaseCommit
            HeadRevision = $strDisconnectedPushCommit
            InputRevision = $strDisconnectedPushCommit
            IsNewRefRange = $false
            RangeComparisonMode = 'PublishedEndpoints'
            PolicyRepositoryRelativePath = '.github/workflows/Test-AgentInstructions.ps1'
            PolicyMaximumBytes = 1024
            PolicyMarker = $strMetadataRangePolicyMarker
        }
        $arrDisconnectedPushFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                @hashtableDisconnectedPushArguments
        )
        if ($arrDisconnectedPushFailures.Count -ne 0) {
            throw (
                'A valid disconnected direct push failed endpoint validation: ' +
                ($arrDisconnectedPushFailures -join '; ')
            )
        }

        $hashtableDisconnectedPullRequestArguments = @{}
        foreach ($strDisconnectedPushArgumentName in
            $hashtableDisconnectedPushArguments.Keys) {
            $hashtableDisconnectedPullRequestArguments[
                $strDisconnectedPushArgumentName
            ] = $hashtableDisconnectedPushArguments[$strDisconnectedPushArgumentName]
        }
        $hashtableDisconnectedPullRequestArguments.RangeComparisonMode = 'MergeBase'
        $boolDisconnectedPullRequestRejected = $false
        try {
            [void](Get-GovernedDocumentRangeTransitionFailure `
                    @hashtableDisconnectedPullRequestArguments)
        }
        catch {
            $boolDisconnectedPullRequestRejected = $_.Exception.Message.Contains(
                'must have exactly one merge base',
                [System.StringComparison]::Ordinal
            )
        }
        if (-not $boolDisconnectedPullRequestRejected) {
            throw 'A disconnected pull-request range did not fail closed.'
        }

        $hashtableInvalidRangeComparisonArguments = @{}
        foreach ($strDisconnectedPushArgumentName in
            $hashtableDisconnectedPushArguments.Keys) {
            $hashtableInvalidRangeComparisonArguments[
                $strDisconnectedPushArgumentName
            ] = $hashtableDisconnectedPushArguments[$strDisconnectedPushArgumentName]
        }
        $hashtableInvalidRangeComparisonArguments.RangeComparisonMode = 'UntrustedMode'
        $boolInvalidRangeComparisonModeRejected = $false
        try {
            [void](Get-GovernedDocumentRangeTransitionFailure `
                    @hashtableInvalidRangeComparisonArguments)
        }
        catch {
            $boolInvalidRangeComparisonModeRejected = $_.Exception.Message.Contains(
                'RangeComparisonMode',
                [System.StringComparison]::OrdinalIgnoreCase
            )
        }
        if (-not $boolInvalidRangeComparisonModeRejected) {
            throw 'An invalid metadata range-comparison mode was accepted.'
        }

        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not reset the invalid disconnected-push fixture index.'
        }
        $strDisconnectedInvalidVersion = '**Version:** ' +
            $objAgentsVersionMatch.Groups['Prefix'].Value +
            $strMergeHistoricalDate.Replace('-', '') + '.2'
        $strDisconnectedInvalidContent = $strMergeBaseContent.Replace(
            $strMergeBaseVersion,
            $strDisconnectedInvalidVersion
        ) + [Environment]::NewLine + 'Invalid disconnected push fixture.'
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strDisconnectedInvalidContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
        $strDisconnectedInvalidTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the invalid disconnected-push fixture tree.'
        }
        $strDisconnectedInvalidCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strDisconnectedInvalidTree `
            -Parents @() `
            -Timestamp ($strMergeHistoricalDate + 'T09:05:00Z') `
            -Message 'invalid disconnected direct push'
        $hashtableDisconnectedPushArguments.HeadRevision =
            $strDisconnectedInvalidCommit
        $hashtableDisconnectedPushArguments.InputRevision =
            $strDisconnectedInvalidCommit
        $arrDisconnectedInvalidFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                @hashtableDisconnectedPushArguments
        )
        if (-not ($arrDisconnectedInvalidFailures -match
                'Version revision must be 1 after a content change')) {
            throw 'An invalid disconnected direct push passed metadata validation.'
        }

        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not restore the base tree after disconnected-push fixtures.'
        }

        $arrNewRefRangeFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strNewRefZeroRevision `
                -HeadRevision $strMergeBaseCommit `
                -InputRevision $strMergeBaseCommit `
                -IsNewRefRange $true `
                -PolicyRepositoryRelativePath `
                    '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker `
                -TrustedFinalizationTimestamp `
                    ($strMergeHistoricalDate + 'T08:00:00Z')
        )
        if ($arrNewRefRangeFailures.Count -ne 0) {
            throw (
                'Valid new-ref metadata range failed: ' +
                ($arrNewRefRangeFailures -join '; ')
            )
        }
        $arrNewRefWrongDateFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strNewRefZeroRevision `
                -HeadRevision $strMergeBaseCommit `
                -InputRevision $strMergeBaseCommit `
                -IsNewRefRange $true `
                -PolicyRepositoryRelativePath `
                    '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker `
                -TrustedFinalizationTimestamp `
                    ($strMergeCurrentDate + 'T08:00:00Z')
        )
        if (-not ($arrNewRefWrongDateFailures -join '; ').Contains(
                "AGENTS.md Last Updated must be $strMergeCurrentDate",
                [System.StringComparison]::Ordinal
            )) {
            throw 'A new-ref metadata range accepted the wrong finalization date.'
        }

        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        $strTrustRangeOrdinaryPath = [System.IO.Path]::Combine(
            $strMergeFixtureRoot,
            'ordinary.txt'
        )
        [System.IO.File]::WriteAllText(
            $strTrustRangeOrdinaryPath,
            'topic-only ordinary change',
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- 'ordinary.txt'
        $strTrustRangeTopicTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the trust-range topic tree.'
        }
        $strTrustRangeTopicCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strTrustRangeTopicTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T08:01:00Z') `
            -Message 'trust range topic change'

        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        [System.IO.File]::WriteAllText(
            $strMergePolicyPath,
            'base-only trust-root update',
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- `
            '.github/workflows/Test-AgentInstructions.ps1'
        $strTrustRangeUpdatedBaseTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the trust-range updated-base tree.'
        }
        $strTrustRangeUpdatedBaseCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strTrustRangeUpdatedBaseTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T08:02:00Z') `
            -Message 'trust range base-only update'
        $arrBaseOnlyTrustRangeFailures = @(Get-TrustRootRangeMutationFailure `
                -RepositoryRootPath $strMergeFixtureRoot `
                -BaseRevision $strTrustRangeUpdatedBaseCommit `
                -HeadRevision $strTrustRangeTopicCommit `
                -RepositoryRelativePath @(
                    '.github/workflows/Test-AgentInstructions.ps1'
                ))
        if ($arrBaseOnlyTrustRangeFailures.Count -ne 0) {
            throw 'A base-only trust-root update was attributed to the topic branch.'
        }

        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        $strBaseOnlyGovernedVersion = '**Version:** ' +
            $objAgentsVersionMatch.Groups['Prefix'].Value +
            $strMergeCurrentDate.Replace('-', '') + '.0'
        $strBaseOnlyGovernedContent = $strMergeBaseContent.Replace(
            $strMergeBaseVersion,
            $strBaseOnlyGovernedVersion
        ).Replace(
            "- **Last Updated:** $strMergeHistoricalDate",
            "- **Last Updated:** $strMergeCurrentDate"
        )
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strBaseOnlyGovernedContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- 'AGENTS.md'
        $strBaseOnlyGovernedTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the base-only governed-document tree.'
        }
        $strBaseOnlyGovernedCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strBaseOnlyGovernedTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeCurrentDate + 'T08:02:30Z') `
            -Message 'base-only governed-document update'
        $arrBaseOnlyGovernedFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strBaseOnlyGovernedCommit `
                -HeadRevision $strTrustRangeTopicCommit `
                -InputRevision $strTrustRangeTopicCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath `
                    '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker `
                -TrustedFinalizationTimestamp `
                    ($strMergeHistoricalDate + 'T08:01:00Z')
        )
        if ($arrBaseOnlyGovernedFailures.Count -ne 0) {
            throw (
                'A base-only governed-document update was attributed to the topic branch: ' +
                ($arrBaseOnlyGovernedFailures -join '; ')
            )
        }

        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        [System.IO.File]::WriteAllText(
            $strMergePolicyPath,
            'topic trust-root update',
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- `
            '.github/workflows/Test-AgentInstructions.ps1'
        $strTrustRangeMutatedTopicTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the trust-range mutated-topic tree.'
        }
        $strTrustRangeMutatedTopicCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strTrustRangeMutatedTopicTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T08:03:00Z') `
            -Message 'trust range topic trust-root update'
        $arrTopicTrustRangeFailures = @(Get-TrustRootRangeMutationFailure `
                -RepositoryRootPath $strMergeFixtureRoot `
                -BaseRevision $strTrustRangeUpdatedBaseCommit `
                -HeadRevision $strTrustRangeMutatedTopicCommit `
                -RepositoryRelativePath @(
                    '.github/workflows/Test-AgentInstructions.ps1'
                ))
        if ($arrTopicTrustRangeFailures.Count -ne 1 -or
            -not ($arrTopicTrustRangeFailures -match
                'changes trusted validation path')) {
            throw 'A topic trust-root update did not fail from the merge base.'
        }
        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        [System.IO.File]::WriteAllText(
            $strMergePolicyPath,
            $strMetadataRangePolicyMarker,
            $objUtf8WithoutBom
        )
        if ([System.IO.File]::Exists($strTrustRangeOrdinaryPath)) {
            Remove-Item -LiteralPath $strTrustRangeOrdinaryPath -Force
        }

        $strUnicodeDirectoryName = 'm' + [char] 0x00F3 + 'dulo'
        $strUnicodeDecisionFileName = 'revisi' + [char] 0x00F3 + 'n.md'
        $strUnicodeInstructionRepositoryPath =
            "$strUnicodeDirectoryName/AGENTS.md"
        $strUnicodeDecisionRepositoryPath =
            "docs/decisions/$strUnicodeDirectoryName/$strUnicodeDecisionFileName"
        foreach ($strUnicodeRepositoryPath in @(
                $strUnicodeInstructionRepositoryPath,
                $strUnicodeDecisionRepositoryPath
            )) {
            $strUnicodeWorktreePath = [System.IO.Path]::Combine(
                $strMergeFixtureRoot,
                $strUnicodeRepositoryPath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            )
            [void][System.IO.Directory]::CreateDirectory(
                [System.IO.Path]::GetDirectoryName($strUnicodeWorktreePath)
            )
            [System.IO.File]::WriteAllText(
                $strUnicodeWorktreePath,
                $strMergeBaseContent,
                $objUtf8WithoutBom
            )
        }
        & git -C $strMergeFixtureRoot add -- `
            $strUnicodeInstructionRepositoryPath $strUnicodeDecisionRepositoryPath
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not stage the non-ASCII path-inventory fixtures.'
        }
        $arrUnicodeIndexPaths = @(
            Invoke-GitNulRecordQuery `
                -RepositoryRootPath $strMergeFixtureRoot `
                -Argument @('ls-files', '--cached', '-z') `
                -DisplayName 'non-ASCII index paths'
        )
        if ($arrUnicodeIndexPaths -cnotcontains $strUnicodeInstructionRepositoryPath -or
            $arrUnicodeIndexPaths -cnotcontains $strUnicodeDecisionRepositoryPath) {
            throw 'NUL-delimited index enumeration omitted a non-ASCII governed path.'
        }
        $strUnicodeTree = ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the non-ASCII path-inventory tree.'
        }
        $strUnicodeCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strUnicodeTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T08:10:00Z') `
            -Message 'non-ASCII path inventory fixture'
        $arrQuotedUnicodeTreePaths = @(
            & git -C $strMergeFixtureRoot -c core.quotePath=true `
                ls-tree -r --name-only $strUnicodeCommit
        )
        if ($LASTEXITCODE -ne 0 -or
            $arrQuotedUnicodeTreePaths -ccontains $strUnicodeInstructionRepositoryPath) {
            throw 'The non-ASCII fixture did not exercise Git pathname quoting.'
        }
        $arrUnicodeTreePaths = @(
            Invoke-GitNulRecordQuery `
                -RepositoryRootPath $strMergeFixtureRoot `
                -Argument @('ls-tree', '-r', '--name-only', '-z', $strUnicodeCommit) `
                -DisplayName 'non-ASCII tree paths'
        )
        if ($arrUnicodeTreePaths -cnotcontains $strUnicodeInstructionRepositoryPath) {
            throw 'NUL-delimited tree enumeration omitted a non-ASCII governed path.'
        }
        $strUnicodeRevisionContent = Read-GitRevisionText `
            -RepositoryRootPath $strMergeFixtureRoot `
            -Revision $strUnicodeCommit `
            -RepositoryRelativePath $strUnicodeInstructionRepositoryPath `
            -MaximumBytes $intAgentsMaximumInputBytes `
            -RequireRegularFile
        if ($strUnicodeRevisionContent -cne $strMergeBaseContent) {
            throw 'The shared revision reader changed non-ASCII path content.'
        }
        $arrUnicodeMetadataRangeFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                -Name $strUnicodeInstructionRepositoryPath `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath $strUnicodeInstructionRepositoryPath `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strMergeBaseCommit `
                -HeadRevision $strUnicodeCommit `
                -InputRevision $strUnicodeCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker
        )
        if ($arrUnicodeMetadataRangeFailures.Count -ne 0) {
            throw (
                'A valid non-ASCII governed-path range failed: ' +
                ($arrUnicodeMetadataRangeFailures -join '; ')
            )
        }
        $arrUnicodeRangePaths = @(
            Invoke-GitNulRecordQuery `
                -RepositoryRootPath $strMergeFixtureRoot `
                -Argument @(
                    'log', '--format=', '--name-only', '-z', '--no-renames',
                    "$strMergeBaseCommit..$strUnicodeCommit", '--',
                    ':(glob)docs/decisions/**/*.md'
                ) `
                -DisplayName 'non-ASCII range decision paths'
        )
        if ($arrUnicodeRangePaths -cnotcontains $strUnicodeDecisionRepositoryPath) {
            throw 'NUL-delimited range enumeration omitted a non-ASCII decision record.'
        }

        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not restore the base tree after non-ASCII path fixtures.'
        }
        $strSiblingInstructionRepositoryPath = 'nested/AGENTS.md'
        $strSiblingInstructionWorktreePath = [System.IO.Path]::Combine(
            $strMergeFixtureRoot,
            'nested',
            'AGENTS.md'
        )
        [void][System.IO.Directory]::CreateDirectory(
            [System.IO.Path]::GetDirectoryName($strSiblingInstructionWorktreePath)
        )
        [System.IO.File]::WriteAllText(
            $strSiblingInstructionWorktreePath,
            $strMergeBaseContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- $strSiblingInstructionRepositoryPath
        $strSiblingAdditionTree = ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the sibling-path addition tree.'
        }
        $strSiblingAdditionCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strSiblingAdditionTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T08:20:00Z') `
            -Message 'add governed path on first sibling'
        $strSiblingAbsentCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeBaseTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T08:30:00Z') `
            -Message 'retain absence on second sibling'
        $strSiblingMergeCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strSiblingAdditionTree `
            -Parents @($strSiblingAdditionCommit, $strSiblingAbsentCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T08:40:00Z') `
            -Message 'merge sibling governed-path histories'
        $arrSiblingRangeCommits = @(
            & git -C $strMergeFixtureRoot rev-list --reverse --topo-order `
                "$strMergeBaseCommit..$strSiblingMergeCommit"
        )
        if ($LASTEXITCODE -ne 0 -or
            [array]::IndexOf($arrSiblingRangeCommits, $strSiblingAdditionCommit) -gt
            [array]::IndexOf($arrSiblingRangeCommits, $strSiblingAbsentCommit)) {
            throw 'The sibling-history fixture did not reproduce the traversal-order hazard.'
        }
        $arrSiblingRangeFailures = @(Get-GovernedDocumentRangeTransitionFailure `
                -Name $strSiblingInstructionRepositoryPath `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath $strSiblingInstructionRepositoryPath `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strMergeBaseCommit `
                -HeadRevision $strSiblingMergeCommit `
                -InputRevision $strSiblingMergeCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker)
        if ($arrSiblingRangeFailures.Count -ne 0) {
            throw (
                'A valid sibling path history was treated as a deletion: ' +
                ($arrSiblingRangeFailures -join '; ')
            )
        }

        & git -C $strMergeFixtureRoot read-tree $strMergeBaseTree
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not restore the base tree after sibling-path fixtures.'
        }
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
                'must place the metadata header block')) {
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
                'must place the metadata header block')) {
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
        [System.IO.File]::WriteAllText(
            $strMergeCopilotPath,
            $strOptionalInvalidStatus,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- '.github/copilot-instructions.md'
        $strMergeCopilotInvalidMetadataTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the invalid optional-metadata Copilot tree.'
        }
        $strMergeCopilotInvalidMetadataCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeCopilotInvalidMetadataTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeHistoricalDate + 'T08:35:00Z') `
            -Message 'invalid optional-metadata Copilot change'
        $hashtableInvalidCopilotTransitionArguments = @{}
        foreach ($strCopilotArgumentName in $hashtableCopilotTransitionArguments.Keys) {
            $hashtableInvalidCopilotTransitionArguments[$strCopilotArgumentName] =
                $hashtableCopilotTransitionArguments[$strCopilotArgumentName]
        }
        $hashtableInvalidCopilotTransitionArguments.HeadRevision =
            $strMergeCopilotInvalidMetadataCommit
        $hashtableInvalidCopilotTransitionArguments.InputRevision =
            $strMergeCopilotInvalidMetadataCommit
        $arrInvalidMetadataOptionalRangeFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                @hashtableInvalidCopilotTransitionArguments `
                -RequireMetadataTransition $false
        )
        if (-not ($arrInvalidMetadataOptionalRangeFailures -match 'Status')) {
            throw 'An invalid present metadata header passed the optional range gate.'
        }
        $arrInvalidMetadataOptionalCommitFailures = @(
            Get-GovernedDocumentCommitTransitionFailure `
                -Name '.github/copilot-instructions.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath '.github/copilot-instructions.md' `
                -MaximumBytes $intInstructionDocumentMaximumInputBytes `
                -CommitRevision $strMergeCopilotInvalidMetadataCommit `
                -RequireMetadataTransition $false
        )
        if (-not ($arrInvalidMetadataOptionalCommitFailures -match 'Status')) {
            throw 'An invalid present metadata header passed the optional commit gate.'
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
        $hashtableBackdatedFinalizationArguments = @{
            Name = 'AGENTS.md'
            RepositoryRootPath = $strMergeFixtureRoot
            RepositoryRelativePath = 'AGENTS.md'
            MaximumBytes = $intAgentsMaximumInputBytes
            BaseRevision = $strMergeBaseCommit
            HeadRevision = $strMergeTopicCommit
            InputRevision = $strMergeTopicCommit
            IsNewRefRange = $false
            PolicyRepositoryRelativePath = '.github/workflows/Test-AgentInstructions.ps1'
            PolicyMaximumBytes = 1024
            PolicyMarker = $strMetadataRangePolicyMarker
        }
        $arrBackdatedFinalizationFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                @hashtableBackdatedFinalizationArguments `
                -TrustedFinalizationTimestamp ($strMergeCurrentDate + 'T00:00:00Z')
        )
        if (-not ($arrBackdatedFinalizationFailures -match
                [regex]::Escape("Last Updated must be $strMergeCurrentDate"))) {
            throw 'A contributor-backdated finalization passed trusted run-time validation.'
        }
        $boolMalformedFinalizationTimeRejected = $false
        try {
            [void](Get-GovernedDocumentRangeTransitionFailure `
                    @hashtableBackdatedFinalizationArguments `
                    -TrustedFinalizationTimestamp '2026-09-09T00:00:00+00:00')
        }
        catch {
            $boolMalformedFinalizationTimeRejected = $_.Exception.Message.Contains(
                'trusted finalization timestamp is invalid',
                [System.StringComparison]::Ordinal
            )
        }
        if (-not $boolMalformedFinalizationTimeRejected) {
            throw 'A noncanonical trusted finalization timestamp was accepted.'
        }
        $strAutomatedSingleParentCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strMergeTopicTree `
            -Parents @($strMergeBaseCommit) `
            -Timestamp ($strMergeCurrentDate + 'T00:30:00Z') `
            -Message 'automated single-parent merge result'
        $hashtableAutomatedMergeArguments = @{
            Name = 'AGENTS.md'
            RepositoryRootPath = $strMergeFixtureRoot
            RepositoryRelativePath = 'AGENTS.md'
            MaximumBytes = $intAgentsMaximumInputBytes
            BaseRevision = $strMergeBaseCommit
            HeadRevision = $strAutomatedSingleParentCommit
            InputRevision = $strAutomatedSingleParentCommit
            IsNewRefRange = $false
            PolicyRepositoryRelativePath = '.github/workflows/Test-AgentInstructions.ps1'
            PolicyMaximumBytes = 1024
            PolicyMarker = $strMetadataRangePolicyMarker
        }
        $arrUnprovedAutomatedMergeFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                @hashtableAutomatedMergeArguments
        )
        if (-not ($arrUnprovedAutomatedMergeFailures -match
                [regex]::Escape("Last Updated must be $strMergeCurrentDate"))) {
            throw 'An unproved single-parent merge result received a date exemption.'
        }
        $arrProvedAutomatedMergeFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                @hashtableAutomatedMergeArguments `
                -AutomatedMergeSourceRevision $strMergeTopicCommit `
                -TrustedFinalizationTimestamp ($strMergeCurrentDate + 'T00:00:00Z')
        )
        if ($arrProvedAutomatedMergeFailures.Count -ne 0) {
            throw (
                'A proved single-parent merge result failed validation: ' +
                ($arrProvedAutomatedMergeFailures -join '; ')
            )
        }
        $arrMismatchedAutomatedMergeFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                @hashtableAutomatedMergeArguments `
                -AutomatedMergeSourceRevision $strMergeCopilotChangedCommit
        )
        if (-not ($arrMismatchedAutomatedMergeFailures -match
                [regex]::Escape("Last Updated must be $strMergeCurrentDate"))) {
            throw 'A mismatched automated merge source received a date exemption.'
        }
        $boolEndpointAutomatedMergeSourceRejected = $false
        try {
            [void](Get-GovernedDocumentRangeTransitionFailure `
                    @hashtableAutomatedMergeArguments `
                    -AutomatedMergeSourceRevision $strAutomatedSingleParentCommit)
        }
        catch {
            $boolEndpointAutomatedMergeSourceRejected = $_.Exception.Message.Contains(
                'must differ from the event endpoints',
                [System.StringComparison]::Ordinal
            )
        }
        if (-not $boolEndpointAutomatedMergeSourceRejected) {
            throw 'An event endpoint was accepted as its own automated merge source.'
        }
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
        & git -C $strMergeFixtureRoot read-tree $strMergeTopicTree
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not restore the topic tree for the later-push fixture.'
        }
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'later-push.txt'),
            'Unrelated later direct-push content.',
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot add -- 'later-push.txt'
        $strLaterUnrelatedTopicTree =
            ([string] (& git -C $strMergeFixtureRoot write-tree)).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the unrelated later-push tree.'
        }
        $strLaterUnrelatedTopicCommit = & $scriptBlockCreateMergeFixtureCommit `
            -Tree $strLaterUnrelatedTopicTree `
            -Parents @($strSecondTopicCommit) `
            -Timestamp ($strMergeCurrentDate + 'T13:00:00Z') `
            -Message 'unrelated later direct push'
        $hashtableLaterTopicPushArguments = @{
            Name = 'AGENTS.md'
            RepositoryRootPath = $strMergeFixtureRoot
            RepositoryRelativePath = 'AGENTS.md'
            MaximumBytes = $intAgentsMaximumInputBytes
            HeadRevision = $strLaterUnrelatedTopicCommit
            InputRevision = $strLaterUnrelatedTopicCommit
            IsNewRefRange = $false
            PolicyRepositoryRelativePath = '.github/workflows/Test-AgentInstructions.ps1'
            PolicyMaximumBytes = 1024
            PolicyMarker = $strMetadataRangePolicyMarker
            TrustedFinalizationTimestamp = $strMergeCurrentDate + 'T13:00:00Z'
        }
        $arrPriorTopicBaseFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                @hashtableLaterTopicPushArguments `
                -BaseRevision $strSecondTopicCommit
        )
        if ($arrPriorTopicBaseFailures.Count -ne 0) {
            throw (
                'An unrelated later topic push revalidated unchanged metadata: ' +
                ($arrPriorTopicBaseFailures -join '; ')
            )
        }
        $arrMovingDefaultBaseFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                @hashtableLaterTopicPushArguments `
                -BaseRevision $strMergeBaseCommit
        )
        if (-not ($arrMovingDefaultBaseFailures -join '; ').Contains(
                "Last Updated must be $strMergeCurrentDate",
                [System.StringComparison]::Ordinal
            )) {
            throw 'The later topic-push fixture did not expose the moving-base false failure.'
        }
        & git -C $strMergeFixtureRoot update-ref refs/heads/topic $strSecondTopicCommit
        & git -C $strMergeFixtureRoot symbolic-ref HEAD refs/heads/topic
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not configure the local worktree-baseline fixture ref.'
        }
        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strMergeTopicContent,
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot read-tree $strSecondTopicCommit
        & git -C $strMergeFixtureRoot diff --quiet HEAD -- 'AGENTS.md'
        if ($LASTEXITCODE -ne 0) {
            throw 'The clean worktree-baseline fixture is not clean.'
        }
        $strResolvedLocalBaseline = [string] (
            & git -C $strMergeFixtureRoot rev-parse --verify 'HEAD^{commit}'
        )
        if ($LASTEXITCODE -ne 0 -or
            $strResolvedLocalBaseline.Trim() -cne $strSecondTopicCommit) {
            throw 'Could not resolve the checked-out worktree baseline.'
        }
        $strResolvedLocalBaseline = $strResolvedLocalBaseline.Trim()
        $objCleanLocalContext = Get-GovernedDocumentParentContext `
            -RepositoryRootPath $strMergeFixtureRoot `
            -RepositoryRelativePath 'AGENTS.md' `
            -MaximumBytes $intAgentsMaximumInputBytes `
            -LocalBaselineRevision $strResolvedLocalBaseline
        if ($objCleanLocalContext.ParentRevision -cne $strSecondTopicCommit -or
            $objCleanLocalContext.ParentContent -cne $strMergeTopicContent -or
            $objCleanLocalContext.ExpectedUtcDate -cne '' -or
            $objCleanLocalContext.IsWorktreeTransition -or
            -not $objCleanLocalContext.UsesLocalBaseline) {
            throw (
                'A clean topic did not use checked-out HEAD as its worktree baseline.'
            )
        }
        $arrCleanLocalRangeFailures = @(
            Get-GovernedDocumentRangeTransitionFailure `
                -Name 'AGENTS.md' `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -BaseRevision $strResolvedLocalBaseline `
                -HeadRevision $strSecondTopicCommit `
                -InputRevision $strSecondTopicCommit `
                -IsNewRefRange $false `
                -PolicyRepositoryRelativePath `
                    '.github/workflows/Test-AgentInstructions.ps1' `
                -PolicyMaximumBytes 1024 `
                -PolicyMarker $strMetadataRangePolicyMarker
        )
        if ($arrCleanLocalRangeFailures.Count -ne 0) {
            throw (
                'A clean local HEAD range failed: ' +
                ($arrCleanLocalRangeFailures -join '; ')
            )
        }

        [System.IO.File]::WriteAllText(
            [System.IO.Path]::Combine($strMergeFixtureRoot, 'AGENTS.md'),
            $strMergeTopicContent + [Environment]::NewLine + 'Dirty final state.',
            $objUtf8WithoutBom
        )
        & git -C $strMergeFixtureRoot diff --quiet HEAD -- 'AGENTS.md'
        if ($LASTEXITCODE -ne 1) {
            throw 'The dirty worktree-baseline fixture did not become dirty.'
        }
        $strSavedMaximumMetadataUtcDate = $script:strMaximumMetadataUtcDate
        $strDirtyFixtureUtcDate = '2030-01-02'
        $script:strMaximumMetadataUtcDate = $strDirtyFixtureUtcDate
        try {
            $objDirtyLocalContext = Get-GovernedDocumentParentContext `
                -RepositoryRootPath $strMergeFixtureRoot `
                -RepositoryRelativePath 'AGENTS.md' `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -LocalBaselineRevision $strResolvedLocalBaseline
            if ($objDirtyLocalContext.ParentRevision -cne $strSecondTopicCommit -or
                $objDirtyLocalContext.ParentContent -cne $strMergeTopicContent -or
                $objDirtyLocalContext.ExpectedUtcDate -cne
                    $strDirtyFixtureUtcDate -or
                -not $objDirtyLocalContext.IsWorktreeTransition -or
                -not $objDirtyLocalContext.UsesLocalBaseline) {
                throw (
                    'A dirty topic did not use checked-out HEAD and the trusted UTC date.'
                )
            }
            $arrDirtyLocalFailures = @(Get-DocumentMetadataTransitionFailure `
                    -Name 'AGENTS.md' `
                    -CurrentContent (
                        $strMergeTopicContent + [Environment]::NewLine +
                        'Dirty final state.'
                    ) `
                    -ParentContent $objDirtyLocalContext.ParentContent `
                    -ExpectedUtcDate $objDirtyLocalContext.ExpectedUtcDate `
                    -IsNewDocumentTransition $false)
            if ($arrDirtyLocalFailures.Count -eq 0 -or
                -not ($arrDirtyLocalFailures -join '; ').Contains(
                    "Last Updated must be $strDirtyFixtureUtcDate",
                    [System.StringComparison]::Ordinal
                )) {
                throw 'Dirty local metadata did not require the trusted UTC date.'
            }
        }
        finally {
            $script:strMaximumMetadataUtcDate = $strSavedMaximumMetadataUtcDate
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
    $scriptBlockGetDeletedPushJobGuardFailures = {
        param([string] $WorkflowContent)

        $strNormalizedWorkflow = $WorkflowContent -replace '\r\n?', "`n"
        $strExpectedGuard = @(
            '  validate-agent-instructions:',
            '    if: >-',
            "      github.event_name != 'push' ||",
            '      !github.event.deleted',
            '    name: Validate agent instructions'
        ) -join "`n"
        if (-not $strNormalizedWorkflow.Contains(
                $strExpectedGuard,
                [System.StringComparison]::Ordinal
            )) {
            Write-Output 'The agent-validation job deletion guard is not exact.'
        }
    }
    $arrDeletedPushJobGuardFailures = @(
        & $scriptBlockGetDeletedPushJobGuardFailures `
            -WorkflowContent $strAgentWorkflowContent
    )
    if ($arrDeletedPushJobGuardFailures.Count -gt 0) {
        throw (
            'The deleted-push job guard contract failed: ' +
            ($arrDeletedPushJobGuardFailures -join '; ')
        )
    }
    $arrDeletedPushJobGuardMutations = @(
        [pscustomobject]@{
            Name = 'guard bypassed'
            From = "      github.event_name != 'push' ||"
            To = '      true ||'
        },
        [pscustomobject]@{
            Name = 'guard inverted'
            From = '      !github.event.deleted'
            To = '      github.event.deleted'
        },
        [pscustomobject]@{
            Name = 'event scope removed'
            From = "      github.event_name != 'push' ||"
            To = '      !github.event.deleted ||'
        },
        [pscustomobject]@{
            Name = 'creation substituted for deletion'
            From = '      !github.event.deleted'
            To = '      !github.event.created'
        }
    )
    foreach ($objDeletedPushJobGuardMutation in
        $arrDeletedPushJobGuardMutations) {
        if (-not $strAgentWorkflowContent.Contains(
                $objDeletedPushJobGuardMutation.From,
                [System.StringComparison]::Ordinal
            )) {
            throw (
                'The deleted-push job guard mutation fixture is unavailable: ' +
                $objDeletedPushJobGuardMutation.Name
            )
        }
        $strMutatedAgentWorkflowContent = $strAgentWorkflowContent.Replace(
            $objDeletedPushJobGuardMutation.From,
            $objDeletedPushJobGuardMutation.To
        )
        $arrMutatedDeletedPushJobGuardFailures = @(
            & $scriptBlockGetDeletedPushJobGuardFailures `
                -WorkflowContent $strMutatedAgentWorkflowContent
        )
        if ($arrMutatedDeletedPushJobGuardFailures.Count -eq 0) {
            throw (
                'The deleted-push job guard mutation was accepted: ' +
                $objDeletedPushJobGuardMutation.Name
            )
        }
    }
    $strFinalizationResolverPath = [System.IO.Path]::Combine(
        $PSScriptRoot,
        'Resolve-AgentInstructionFinalizationTime.mjs'
    )
    if (-not [System.IO.File]::Exists($strFinalizationResolverPath)) {
        throw 'The trusted finalization-time resolver is missing.'
    }
    $strFinalizationResolverContent = [System.IO.File]::ReadAllText(
        $strFinalizationResolverPath
    )
    $arrFinalizationResolverLiterals = @(
        "      !['push', 'pull_request_target', 'workflow_dispatch'].includes(eventName) ||",
        'function readNextActivityUrl(link, initialUrl) {',
        'async function readHeadPublicationWithRetry({',
        '      await waitImplementation(publicationRetryDelaysMilliseconds[attempt]);',
        'async function readHeadPublication({',
        '  initialUrl.searchParams.set(''ref'', headRef);',
        "  if (!['push', 'force_push', 'branch_creation'].includes(activity.activity_type)) {",
        "    'No exact head publication activity matches this revision and ref.',",
        '        `Repository-activity pagination exceeded ${maximumPageCount} pages.`,',
        '  return readHeadPublicationWithRetry({',
        "    headBaseRevision: eventName === 'push' ? runBaseRevision : null,",
        '    token: runHeadRepository === repository ? token : null,',
        '    return candidates[0].createdAt;',
        '  const timestamp = await resolveFinalizationTimestamp({',
        '    runHeadRef: process.env.RUN_HEAD_REF,',
        '    runBaseRevision: process.env.RUN_BASE_REVISION,',
        '  appendFileSync(output, `timestamp=${timestamp}\n`, ''utf8'');'
    )
    foreach ($strFinalizationResolverLiteral in $arrFinalizationResolverLiterals) {
        if ([regex]::Matches(
                $strFinalizationResolverContent,
                [regex]::Escape($strFinalizationResolverLiteral)
            ).Count -ne 1) {
            throw (
                'The finalization-time resolver must contain exactly once: ' +
                $strFinalizationResolverLiteral
            )
        }
    }
    foreach ($strProhibitedFinalizationResolverLiteral in @(
            'readHistoricalRuns',
            'pushCandidates',
            '/actions/workflows/',
            "url.searchParams.set('status', 'success')"
        )) {
        if ($strFinalizationResolverContent.Contains(
                $strProhibitedFinalizationResolverLiteral,
                [System.StringComparison]::Ordinal
            )) {
            throw (
                'The finalization-time resolver retains a prohibited workflow-' +
                'timing path: ' + $strProhibitedFinalizationResolverLiteral
            )
        }
    }
    foreach ($strSharedRunIdentityLiteral in @(
            '      run?.head_repository?.full_name !== expected.headRepository ||',
            '      run?.head_branch !== expected.runHeadRefName ||',
            '      run?.event !== expected.eventName ||'
        )) {
        if ([regex]::Matches(
                $strFinalizationResolverContent,
                [regex]::Escape($strSharedRunIdentityLiteral)
            ).Count -ne 1) {
            throw (
                'The finalization-time resolver must contain exactly once: ' +
                $strSharedRunIdentityLiteral
            )
        }
    }
    $arrFinalizationResolverSelfTestOutput = @(
        & node $strFinalizationResolverPath --self-test 2>&1
    )
    $intFinalizationResolverSelfTestExit = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    if ($intFinalizationResolverSelfTestExit -ne 0 -or
        $arrFinalizationResolverSelfTestOutput.Count -ne 1 -or
        [string]$arrFinalizationResolverSelfTestOutput[0] -cne
        'Finalization resolver self-tests passed: 35 fixtures.') {
        throw (
            'The finalization-time resolver self-test failed: ' +
            ($arrFinalizationResolverSelfTestOutput -join '; ')
        )
    }
    $arrAutomatedMergeWorkflowFailures = @(
        Get-AutomatedMergeSourceWorkflowContractFailure `
            -WorkflowContent $strAgentWorkflowContent
    )
    if ($arrAutomatedMergeWorkflowFailures.Count -gt 0) {
        throw (
            'The automated merge-source workflow contract failed: ' +
            ($arrAutomatedMergeWorkflowFailures -join '; ')
        )
    }
    $arrAutomatedMergeWorkflowMutations = @(
        [pscustomobject]@{
            Name = 'one-parent gate removed'
            From = '          if (( ${#head_and_parents[@]} != 2 )); then'
            To = '          if (( ${#head_and_parents[@]} != 3 )); then'
        },
        [pscustomobject]@{
            Name = 'merge head identity removed'
            From = '            pull?.merge_commit_sha === head &&'
            To = '            pull?.merge_commit_sha !== head &&'
        },
        [pscustomobject]@{
            Name = 'Enterprise API base prefix removed'
            From = '              `${apiRoot}/repos/${repository}/commits/${head}/pulls?per_page=100&page=${page}`'
            To = '              `/repos/${repository}/commits/${head}/pulls?per_page=100&page=${page}`'
        },
        [pscustomobject]@{
            Name = 'unchanged source identity accepted'
            From = '            pull.head.sha !== head,'
            To = '            pull.head.sha === head,'
        },
        [pscustomobject]@{
            Name = 'base repository identity removed'
            From = '            pull?.base?.repo?.full_name === repository &&'
            To = '            pull?.base?.repo?.full_name !== repository &&'
        },
        [pscustomobject]@{
            Name = 'ambiguous result accepted'
            From = "            throw new Error('More than one exact automated merge source matched the pushed head.');"
            To = '            matches.splice(1);'
        },
        [pscustomobject]@{
            Name = 'force fetch enabled'
            From = '            git fetch --no-tags --no-recurse-submodules origin \'
            To = '            git fetch --force --no-tags --no-recurse-submodules origin \'
        },
        [pscustomobject]@{
            Name = 'source SHA readback removed'
            From = '          test "${fetched_source}" = "${SOURCE_REVISION}"'
            To = '          test -n "${fetched_source}"'
        },
        [pscustomobject]@{
            Name = 'validator source handoff removed'
            From = '          -AutomatedMergeSourceRevision'
            To = '          -Verbose'
        },
        [pscustomobject]@{
            Name = 'published-endpoint selector removed'
            From = "              !github.event.created && 'PublishedEndpoints' || 'MergeBase' }}"
            To = "              github.event.created && 'PublishedEndpoints' || 'MergeBase' }}"
        },
        [pscustomobject]@{
            Name = 'range comparison-mode handoff removed'
            From = '          -RangeComparisonMode'
            To = '          -Verbose'
        },
        [pscustomobject]@{
            Name = 'Actions read permission removed'
            From = '  actions: read'
            To = '  actions: none'
        },
        [pscustomobject]@{
            Name = 'push base revision identity removed'
            From = "          RUN_BASE_REVISION: `${{ github.event_name == 'push' && github.event.before || '' }}"
            To = "          RUN_BASE_REVISION: ''"
        },
        [pscustomobject]@{
            Name = 'PR head revision identity removed'
            From = "          RUN_HEAD_REVISION: `${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.sha || github.sha }}"
            To = '          RUN_HEAD_REVISION: ${{ github.sha }}'
        },
        [pscustomobject]@{
            Name = 'PR head ref identity removed'
            From = "          RUN_HEAD_REF_NAME: `${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.ref || github.ref_name }}"
            To = '          RUN_HEAD_REF_NAME: ${{ github.ref_name }}'
        },
        [pscustomobject]@{
            Name = 'PR full head ref identity removed'
            From = "          RUN_HEAD_REF: `${{ github.event_name == 'pull_request_target' && format('refs/heads/{0}', github.event.pull_request.head.ref) || github.ref }}"
            To = '          RUN_HEAD_REF: ${{ github.ref }}'
        },
        [pscustomobject]@{
            Name = 'PR head repository identity removed'
            From = "          RUN_HEAD_REPOSITORY: `${{ github.event_name == 'pull_request_target' && github.event.pull_request.head.repo.full_name || github.repository }}"
            To = '          RUN_HEAD_REPOSITORY: ${{ github.repository }}'
        },
        [pscustomobject]@{
            Name = 'finalization resolver bypassed'
            From = '        run: node .github/workflows/Resolve-AgentInstructionFinalizationTime.mjs'
            To = '        run: printf ''timestamp=%s\n'' "${GITHUB_EVENT_CREATED_AT}"'
        },
        [pscustomobject]@{
            Name = 'trusted finalization handoff removed'
            From = '          -TrustedFinalizationTimestamp'
            To = '          -Verbose'
        }
    )
    foreach ($objAutomatedMergeWorkflowMutation in
        $arrAutomatedMergeWorkflowMutations) {
        if (-not $strAgentWorkflowContent.Contains(
                $objAutomatedMergeWorkflowMutation.From,
                [System.StringComparison]::Ordinal
            )) {
            throw (
                'The automated merge-source workflow mutation fixture is unavailable: ' +
                $objAutomatedMergeWorkflowMutation.Name
            )
        }
        $strMutatedAgentWorkflowContent = $strAgentWorkflowContent.Replace(
            $objAutomatedMergeWorkflowMutation.From,
            $objAutomatedMergeWorkflowMutation.To
        )
        $arrMutatedAutomatedMergeWorkflowFailures = @(
            Get-AutomatedMergeSourceWorkflowContractFailure `
                -WorkflowContent $strMutatedAgentWorkflowContent
        )
        if ($arrMutatedAutomatedMergeWorkflowFailures.Count -eq 0) {
            throw (
                'The automated merge-source workflow mutation was accepted: ' +
                $objAutomatedMergeWorkflowMutation.Name
            )
        }
    }
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
            Name = 'existing push narrowed to the default branch'
            From = '          !github.event.created &&'
            To = '          github.ref_name == github.event.repository.default_branch &&'
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
            '          github.event.created &&',
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
                'Manual and new non-default push runs must use the verified default-branch ' +
                'baseline output once.'
            )
        }
        $strExpectedRangeBase = @(
            '          AGENT_INSTRUCTION_RANGE_BASE: >-',
            "            `${{ github.event_name == 'pull_request_target' &&",
            '              github.event.pull_request.base.sha ||',
            "              github.event_name == 'push' &&",
            '              (!github.event.created ||',
            '              github.ref_name == github.event.repository.default_branch) &&',
            '              github.event.before ||',
            "              (github.event_name == 'push' &&",
            '              github.event.created &&',
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
            Name = 'new non-default push omitted'
            From = 'github.ref_name != github.event.repository.default_branch)'
            To = 'github.ref_name == github.event.repository.default_branch)'
        },
        [pscustomobject]@{
            Name = 'new-ref condition removed'
            From = '          github.event.created &&'
            To = '          !github.event.created &&'
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
            Name = 'new-ref baseline output replaced by nonexistent predecessor'
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
    $scriptBlockGetPushTriggerFailures = {
        param([string] $WorkflowContent)

        $objTriggerMatch = [regex]::Match(
            $WorkflowContent,
            '(?ms)^  push:\r?\n(?<Body>.*?)(?=^(?:\S| {2}\S)|\z)'
        )
        if (-not $objTriggerMatch.Success) {
            Write-Output 'Could not parse the push agent-validation trigger.'
            return
        }
        if ($objTriggerMatch.Groups['Body'].Value -cmatch
            '(?m)^    paths(?:-ignore)?:') {
            Write-Output (
                'The push agent-validation trigger must be unconditional ' +
                'and must not use a path filter.'
            )
        }
        $strExpectedPushBody =
            "    branches:`n" +
            '      - "**"'
        $strNormalizedPushBody =
            $objTriggerMatch.Groups['Body'].Value.Replace("`r`n", "`n").TrimEnd("`n")
        if ($strNormalizedPushBody -cne $strExpectedPushBody) {
            Write-Output (
                'The push agent-validation trigger must cover all branches, ' +
                'exclude tags, and contain no other filters.'
            )
        }
    }
    $scriptBlockGetPullRequestTargetFailures = {
        param([string] $WorkflowContent)

        $objTriggerMatch = [regex]::Match(
            $WorkflowContent,
            '(?ms)^  pull_request_target:\r?\n(?<Body>.*?)(?=^(?:\S| {2}\S)|\z)'
        )
        if (-not $objTriggerMatch.Success) {
            Write-Output 'Could not parse the pull_request_target agent-validation trigger.'
            return
        }
        if ($objTriggerMatch.Groups['Body'].Value -cmatch
            '(?m)^    paths(?:-ignore)?:') {
            Write-Output (
                'The pull_request_target agent-validation trigger must be unconditional ' +
                'and must not use a path filter.'
            )
        }
        $strExpectedPullRequestTargetBody =
            "    types:`n" +
            "      - opened`n" +
            "      - synchronize`n" +
            "      - reopened`n" +
            '      - edited'
        $strNormalizedPullRequestTargetBody =
            $objTriggerMatch.Groups['Body'].Value.Replace("`r`n", "`n").TrimEnd("`n")
        if ($strNormalizedPullRequestTargetBody -cne
            $strExpectedPullRequestTargetBody) {
            Write-Output (
                'The pull_request_target agent-validation trigger must subscribe ' +
                'exactly to opened, synchronize, reopened, and edited.'
            )
        }
    }

    $arrPushTriggerFailures = @(& $scriptBlockGetPushTriggerFailures `
            -WorkflowContent $strAgentWorkflowContent)
    if ($arrPushTriggerFailures.Count -gt 0) {
        throw $arrPushTriggerFailures[0]
    }
    $arrPullRequestTargetFailures = @(& $scriptBlockGetPullRequestTargetFailures `
            -WorkflowContent $strAgentWorkflowContent)
    if ($arrPullRequestTargetFailures.Count -gt 0) {
        throw $arrPullRequestTargetFailures[0]
    }
    foreach ($strAttributePath in $script:arrCheckoutAttributePaths) {
        if ($script:arrTrustRootPaths -cnotcontains $strAttributePath) {
            throw "The trust-root gate omits checkout attribute path $strAttributePath."
        }
    }

    $arrCopilotConsumedTriggerPaths = @(
        '"**/*.yaml"',
        '"**/*.yml"',
        'requirements-dev.txt',
        '.github/workflows/lint-staged-markdown.mjs'
    )
    foreach ($strTrigger in @('push', 'pull_request')) {
        $arrCopilotTriggerFailures = @(& $scriptBlockGetTriggerPathFailures `
                -WorkflowContent $strCopilotSetupContent `
                -Trigger $strTrigger `
                -RequiredPath $arrCopilotConsumedTriggerPaths)
        if ($arrCopilotTriggerFailures.Count -gt 0) {
            throw $arrCopilotTriggerFailures[0]
        }
        $objCopilotTriggerMatch = [regex]::Match(
            $strCopilotSetupContent,
            "(?ms)^  $strTrigger`:\r?\n(?<Body>.*?)(?=^(?:\S| {2}\S)|\z)"
        )
        foreach ($strCopilotConsumedTriggerPath in $arrCopilotConsumedTriggerPaths) {
            $objCopilotPathMatch = [regex]::Match(
                $objCopilotTriggerMatch.Groups['Body'].Value,
                "(?m)^      - $([regex]::Escape($strCopilotConsumedTriggerPath))\r?\n"
            )
            if (-not $objCopilotPathMatch.Success) {
                throw "Could not create the $strTrigger Copilot path-trigger mutation."
            }
            $intCopilotPathIndex =
                $objCopilotTriggerMatch.Groups['Body'].Index + $objCopilotPathMatch.Index
            $strMutatedCopilotSetupContent = $strCopilotSetupContent.Remove(
                $intCopilotPathIndex,
                $objCopilotPathMatch.Length
            )
            $arrMutatedCopilotTriggerFailures = @(
                & $scriptBlockGetTriggerPathFailures `
                    -WorkflowContent $strMutatedCopilotSetupContent `
                    -Trigger $strTrigger `
                    -RequiredPath $arrCopilotConsumedTriggerPaths
            )
            if (-not ($arrMutatedCopilotTriggerFailures -match [regex]::Escape(
                        "$strTrigger must cover consumed validation path " +
                        "$strCopilotConsumedTriggerPath once."
                    ))) {
                throw (
                    "$strTrigger Copilot path-trigger mutation was accepted: " +
                    $strCopilotConsumedTriggerPath
                )
            }
        }
    }
    $strPushBranchAnchor = '      - "**"' + "`n"
    foreach ($strPushPathFilter in @('paths', 'paths-ignore')) {
        $strFilteredPushWorkflow = $strAgentWorkflowContent.Replace(
            $strPushBranchAnchor,
            $strPushBranchAnchor + "    $strPushPathFilter`:`n      - AGENTS.md`n"
        )
        if ($strFilteredPushWorkflow -ceq $strAgentWorkflowContent) {
            throw "Could not create the push $strPushPathFilter mutation."
        }
        $arrFilteredPushFailures = @(& $scriptBlockGetPushTriggerFailures `
                -WorkflowContent $strFilteredPushWorkflow)
        if (-not ($arrFilteredPushFailures -match
                'must be unconditional and must not use a path filter')) {
            throw "The push $strPushPathFilter mutation did not fail closed."
        }
    }
    $strFilteredPullRequestTargetWorkflow = $strAgentWorkflowContent.Replace(
        "      - edited`n",
        "      - edited`n    paths:`n      - AGENTS.md`n"
    )
    if ($strFilteredPullRequestTargetWorkflow -ceq $strAgentWorkflowContent) {
        throw 'Could not create the pull_request_target path-filter mutation.'
    }
    $arrFilteredPullRequestTargetFailures = @(
        & $scriptBlockGetPullRequestTargetFailures `
            -WorkflowContent $strFilteredPullRequestTargetWorkflow
    )
    if (-not ($arrFilteredPullRequestTargetFailures -match
            'must be unconditional and must not use a path filter')) {
        throw 'The pull_request_target path-filter mutation did not fail closed.'
    }
    $strUnretargetedPullRequestTargetWorkflow = $strAgentWorkflowContent.Replace(
        "      - edited`n",
        ''
    )
    if ($strUnretargetedPullRequestTargetWorkflow -ceq $strAgentWorkflowContent) {
        throw 'Could not create the pull_request_target edited-removal mutation.'
    }
    $arrUnretargetedPullRequestTargetFailures = @(
        & $scriptBlockGetPullRequestTargetFailures `
            -WorkflowContent $strUnretargetedPullRequestTargetWorkflow
    )
    if (-not ($arrUnretargetedPullRequestTargetFailures -match
            'must subscribe exactly to opened, synchronize, reopened, and edited')) {
        throw 'The pull_request_target edited-removal mutation did not fail closed.'
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
    $strMetadataBackslashHardBreakBase =
        $strMetadataNormalizationBase.Replace('Body', 'Body\')
    foreach ($strMetadataBackslashHardBreakMutation in @(
            $strMetadataBackslashHardBreakBase.Replace('Body\', 'Body\ '),
            $strMetadataBackslashHardBreakBase.Replace('Body\', "Body\`t")
        )) {
        if ((ConvertTo-MetadataComparisonText `
                -Content $strMetadataBackslashHardBreakBase `
                -MetadataContext $objMetadataNormalizationContext) -ceq
            (ConvertTo-MetadataComparisonText `
                -Content $strMetadataBackslashHardBreakMutation `
                -MetadataContext $objMetadataNormalizationContext)) {
            throw 'Metadata normalization incorrectly exempted whitespace after a terminal backslash.'
        }
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
    $intMaximumBytes = [int64]$objMaximumBytesGroup.Value
    $intReserveBoundaryBytes = $intMaximumBytes - 16384
    $intAcceptedFillerLength = $intReserveBoundaryBytes - $intCurrentBytes
    if ($intAcceptedFillerLength -lt 0) {
        throw 'The current AGENTS.md already exceeds the configured reserve boundary.'
    }
    Assert-FixtureAccepted `
        -Name 'exact configured capacity reserve boundary' `
        -AgentsContent ($strAgentsContent + ('x' * $intAcceptedFillerLength)) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent

    Assert-MutationRejected `
        -Name 'configured capacity reserve exceeded by one byte' `
        -AgentsContent ($strAgentsContent + ('x' * ($intAcceptedFillerLength + 1))) `
        -ClaudeContent $strClaudeContent `
        -CodexConfigContent $strCodexConfigContent `
        -ExpectedFailure 'Configured AGENTS.md capacity must retain at least 16384 bytes of reserve.'

    $objAgentsBoundaryStream = [System.IO.MemoryStream]::new(
        [byte[]]::new($intAgentsMaximumInputBytes),
        $false
    )
    try {
        $arrAgentsBoundaryBytes = @(Read-BoundedStreamData `
                -Stream $objAgentsBoundaryStream `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -DisplayName 'AGENTS.md boundary fixture')
        if ($arrAgentsBoundaryBytes.Count -ne $intAgentsMaximumInputBytes) {
            throw 'The exact AGENTS.md read boundary did not preserve every byte.'
        }
    }
    finally {
        $objAgentsBoundaryStream.Dispose()
    }
    $objAgentsOversizedStream = [System.IO.MemoryStream]::new(
        [byte[]]::new($intAgentsMaximumInputBytes + 1),
        $false
    )
    try {
        [void](Read-BoundedStreamData `
                -Stream $objAgentsOversizedStream `
                -MaximumBytes $intAgentsMaximumInputBytes `
                -DisplayName 'AGENTS.md oversized fixture')
        throw 'The one-byte-oversized AGENTS.md read fixture was accepted.'
    }
    catch [System.IO.InvalidDataException] {
        $strExpectedAgentsOversizedFailure =
            "AGENTS.md oversized fixture must not exceed $intAgentsMaximumInputBytes bytes."
        if ($_.Exception.Message -cne $strExpectedAgentsOversizedFailure) {
            throw (
                'The one-byte-oversized AGENTS.md read fixture returned an ' +
                "unexpected failure: $($_.Exception.Message)"
            )
        }
    }
    finally {
        $objAgentsOversizedStream.Dispose()
    }

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
