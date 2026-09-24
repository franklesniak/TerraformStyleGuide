#Requires -Version 5.1

<#
.SYNOPSIS
Validates and expands one style-guide candidate archive.

.DESCRIPTION
Validates raw caller claims, binds the digest and ZIP reader to one retained
archive stream, validates the complete manifest and limits before candidate
creation, and extracts only fresh ordinary files into a journaled context.

.PARAMETER CheckoutRoot
Specifies the raw repository checkout-root claim.

.PARAMETER TrustedTemporaryRoot
Specifies the raw trusted temporary-root claim.

.PARAMETER DownloadDirectory
Specifies the raw context-owned download-directory claim.

.PARAMETER CandidateDirectory
Specifies the raw context-owned candidate-directory claim.

.PARAMETER ExpectedDigest
Specifies the SHA-256 digest expected for the downloaded archive as exactly 64
hexadecimal characters matching '^[0-9A-Fa-f]{64}$'. Uppercase, lowercase, and
mixed-case hexadecimal are accepted, and the value is compared against the
computed digest without regard to case. The supplied value is never trimmed or
rewritten.

.PARAMETER ArtifactId
Specifies the raw workflow artifact identifier.

.PARAMETER RunId
Specifies the raw workflow run identifier.

.PARAMETER RunAttempt
Specifies the raw workflow run-attempt identifier.

.EXAMPLE
PS> $objCandidate = .\Expand-StyleGuideCandidateArtifact.ps1 @hashtableParameters

Validates and expands one candidate archive, returning its candidate ownership state.

.INPUTS
None. You can't pipe objects to this script.

.OUTPUTS
[pscustomobject] CandidatePaths contains the four normalized output paths;
CandidateOwnershipState contains the issued mutable ownership object.

.NOTES
Version: 1.0.20260924.0
#>

[CmdletBinding(PositionalBinding = $false)]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'The isolated executable-entry script block closes over the raw script parameters.'
)]
[OutputType([pscustomobject])]
param (
    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [object]$CheckoutRoot,

    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [object]$TrustedTemporaryRoot,

    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [object]$DownloadDirectory,

    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [object]$CandidateDirectory,

    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [object]$ExpectedDigest,

    [Parameter()]
    [AllowNull()]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [object]$ArtifactId,

    [Parameter()]
    [AllowNull()]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [object]$RunId,

    [Parameter()]
    [AllowNull()]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [object]$RunAttempt
)

$boolCandidateHelperWasDotSourced = $MyInvocation.InvocationName -eq '.'
# Keep the private production blocks and issued-object register in one module.
# Normal script invocations and a previously imported cleanup callable must use
# the same state. No caller-owned object or same-named verifier is an authority.
$scriptBlockCandidateModuleDefinition = {
    $script:versionCandidateHelper = [System.Version]'1.0.20260924.0'
    $script:versionCandidateExpectedContext = [System.Version]'1.0.20260924.0'
    $script:strCandidateHelperContextTypeName = 'TerraformStyleGuide.PrivateCandidateEnvelope.v1'
    $script:strCandidateHelperRecordTypeName = 'TerraformStyleGuide.PrivateCandidateEvidence.v1'
    $script:strCandidateHelperCleanupTypeName = 'TerraformStyleGuide.PrivateCandidateCleanupResult.v1'
    $script:arrCandidateHelperExpectedName = [string[]]@(
        'copilot-instructions.md',
        'terraform.instructions.md',
        'STYLE_GUIDE_CHAT.md',
        'STYLE_GUIDE_FULL.md'
    )
    $script:uintCandidateHelperMaximumEntryByte = [uint64](8 * 1024 * 1024)
    $script:uintCandidateHelperMaximumTotalByte = [uint64](32 * 1024 * 1024)
    $script:uintCandidateHelperMaximumArchiveByte = [uint64](32 * 1024 * 1024)
    $script:intCandidateHelperBufferSize = 65536
    $script:arrCandidateHelperStatPath = [string[]]@(
        '/usr/bin/stat',
        '/bin/stat',
        '/usr/local/bin/stat'
    )
    # Native commands are resolved from a fixed absolute list, never from PATH.
    # Get-Command -CommandType Application closes command *precedence* -- an alias
    # or function can no longer shadow the name -- but it still searches PATH, in
    # PATH order, and PATH is not a trusted input here. On a GitHub-hosted runner
    # any earlier step, composite action, or third-party action makes itself first
    # in PATH by appending one line to $env:GITHUB_PATH, which is a documented
    # platform feature rather than a compromise: "Prepends a directory to the
    # system PATH variable and automatically makes it available to all subsequent
    # actions in the current job." So a benign action shipping its own bin
    # directory becomes this check's source of truth without anyone intending it.
    #
    # Resolving from a fixed list removes PATH from the decision. What it cannot
    # remove is the trust in the resolved file itself: an attacker who can write
    # /usr/bin/stat owns the runner, and nothing this script does would survive
    # that. That residual is named rather than implied.
    $script:scriptBlockResolveCandidateHelperNativePath = {
        param (
            [Parameter(Mandatory = $true)]
            [string[]]$CandidatePath
        )

        foreach ($strCandidatePath in $CandidatePath) {
            try {
                $objCommandAttributes = [System.IO.File]::GetAttributes($strCandidatePath)
            } catch {
                continue
            }
            # A directory at the name is not a program to run.
            if (($objCommandAttributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
                continue
            }
            return [string]$strCandidatePath
        }
        return ''
    }
    # The platform decides which comparison, path grammar, link primitive, and
    # filesystem-identity rules apply, so it must not be something a caller can
    # assert. The OS environment variable is ordinary and inheritable: exporting
    # it as Windows_NT to PowerShell 7 on Linux makes every one of those branches
    # take its Windows form, which silently disables mount and inode resolution
    # and switches path comparison to case-insensitive. OSVersion.Platform is a
    # runtime property with no environment input, and is available on both
    # Windows PowerShell 5.1 and PowerShell 7.
    $script:boolCandidateHelperIsWindows = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
    $script:objCandidateHelperPathComparison = if ($script:boolCandidateHelperIsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }
    $script:objCandidateHelperPathComparer = if ($script:boolCandidateHelperIsWindows) {
        [System.StringComparer]::OrdinalIgnoreCase
    } else {
        [System.StringComparer]::Ordinal
    }
    # No read here counts higher than an owned-file count plus one, and the manifest
    # fixes that at four. The ceiling exists so that a bound cannot be satisfied in
    # shape while being no bound at all.
    $script:intCandidateHelperMaximumEntryCeiling = 64
    # The documented label ceiling, and the longest path either platform can name.
    $script:intCandidateHelperMaximumLabelLength = 128
    $script:intCandidateHelperMaximumPathLength = 32767
    # The longest single path component either platform can name, which is what
    # a journaled leaf and an enumeration search leaf both are.
    $script:intCandidateHelperMaximumLeafLength = 255
    # Fixed buffer for bounded hashing, so the read never sizes itself from a file.
    $script:intCandidateHelperHashBuffer = 65536
    $script:chrCandidateHelperDirectorySeparator = [System.IO.Path]::DirectorySeparatorChar
    $script:chrCandidateHelperAlternateSeparator = [System.IO.Path]::AltDirectorySeparatorChar
    # A leaf used as an enumeration search pattern must be a literal, and only two
    # characters are not: '*' and '?' are the sole expanding forms in the
    # two-argument overload -- the only one available on .NET Framework 4.8 -- which
    # offers no escaping, so they are refused rather than quoted. The separators are
    # refused because they would move the search off the directory being read.
    #
    # Everything else is matched literally, measured on both runtimes: ':', '\',
    # '[', ']', '"', '<' and '>' each match their own file and nothing else. An
    # earlier revision refused those too, on the theory that one character set for
    # both platforms avoided divergence. It produced divergence instead: they are
    # legal in a Unix filename, the download leaf is the one journaled name this
    # code does not choose, and an ordinary artifact called 'release:linux.zip'
    # therefore expanded successfully and then failed cleanup, leaving the
    # invocation root on disk. The rule is per-platform because what a platform can
    # name is per-platform -- GetInvalidFileNameChars is the statement of that, and
    # a leaf obtained from an enumeration cannot contain any of it.
    #
    # What a journaled path may contain is a stricter and separate question,
    # answered once by the canonical stored-path check and applied where such a path
    # is adopted. Answering it a second time here, in a differently shaped guard,
    # is what went wrong.
    $script:arrCandidateHelperRejectedMatchCharacter = [char[]]@(
        [System.IO.Path]::GetInvalidFileNameChars() +
        [char[]]@(
            '*', '?',
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )
    )
    $script:scriptBlockNewCandidateHelperException = {
        param (
            [Parameter(Mandatory = $true)]
            # Round 66: production self-enforces the closed DiagnosticCode set so an
            # out-of-set value is refused at binding regardless of source (Codex
            # "refuse unresolved sources").
            [ValidateSet(
                'archive-invalid', 'cleanup-already-disposed', 'cleanup-candidate-owned',
                'cleanup-context-altered', 'cleanup-context-invalid',
                'cleanup-context-unissued', 'cleanup-delete-failed',
                'cleanup-owned-entry-uncertain', 'cleanup-succeeded',
                'cleanup-terminal-failure', 'containment-invalid',
                'context-create-collision-limit', 'context-create-composite-failure',
                'context-create-failed', 'context-create-verification',
                'destination-invalid', 'digest-invalid', 'digest-mismatch',
                'download-invalid', 'extraction-invalid', 'manifest-invalid', 'none',
                'parameter', 'parameter-invalid', 'post-extraction-invalid', 'root-invalid',
                'script-identity-invalid'
            )]
            [string]$Code,

            [Parameter(Mandatory = $true)]
            # Round 66: production self-enforces the closed Phase set so an
            # out-of-set value is refused at binding regardless of source (Codex
            # "refuse unresolved sources").
            [ValidateSet(
                'none', 'parameter', 'root', 'containment',
                'download', 'digest', 'archive', 'manifest',
                'destination', 'extraction', 'post-extraction', 'cleanup',
                'identity'
            )]
            [string]$Phase,

            [Parameter(Mandatory = $true)]
            # Round 66: production self-enforces the closed Subreason set so an
            # out-of-set value is refused at binding regardless of source (Codex
            # "refuse unresolved sources").
            [ValidateSet(
                'path-null', 'path-type', 'path-empty', 'path-whitespace',
                'path-malformed', 'path-wildcard', 'path-not-fully-qualified', 'path-provider',
                'label-null', 'label-not-scalar-string', 'label-empty', 'label-whitespace',
                'label-control', 'label-grammar', 'digest-null', 'digest-type',
                'digest-empty', 'digest-whitespace', 'digest-control',
                'OwnedPath-length', 'OwnedPath-normalization',
                'ArtifactId-control', 'ArtifactId-empty', 'ArtifactId-length',
                'ArtifactId-type', 'CandidateDirectory-control', 'CandidateDirectory-empty',
                'CandidateDirectory-length', 'CandidateDirectory-missing',
                'CandidateDirectory-normalization', 'CandidateDirectory-provider',
                'CandidateDirectory-relative', 'CandidateDirectory-type',
                'CandidateDirectory-wildcard', 'CheckoutRoot-control', 'CheckoutRoot-empty',
                'CheckoutRoot-length', 'CheckoutRoot-missing', 'CheckoutRoot-normalization',
                'CheckoutRoot-provider', 'CheckoutRoot-relative', 'CheckoutRoot-type',
                'CheckoutRoot-wildcard', 'Context-missing', 'Context-path-mismatch',
                'Context-schema', 'Context-state', 'DownloadDirectory-control',
                'DownloadDirectory-empty', 'DownloadDirectory-length',
                'DownloadDirectory-missing', 'DownloadDirectory-normalization',
                'DownloadDirectory-provider', 'DownloadDirectory-relative',
                'DownloadDirectory-type', 'DownloadDirectory-wildcard',
                'ExpectedDigest-control', 'ExpectedDigest-empty', 'ExpectedDigest-grammar',
                'ExpectedDigest-length', 'ExpectedDigest-missing', 'ExpectedDigest-type',
                'RunAttempt-control', 'RunAttempt-empty', 'RunAttempt-length',
                'RunAttempt-type', 'RunId-control', 'RunId-empty', 'RunId-length',
                'RunId-type', 'TrustedTemporaryRoot-control', 'TrustedTemporaryRoot-empty',
                'TrustedTemporaryRoot-length', 'TrustedTemporaryRoot-missing',
                'TrustedTemporaryRoot-normalization', 'TrustedTemporaryRoot-provider',
                'TrustedTemporaryRoot-relative', 'TrustedTemporaryRoot-type',
                'TrustedTemporaryRoot-wildcard', 'actual-declared-mismatch', 'actual-limit',
                'actual-overflow', 'already-disposed', 'archive-limit', 'archive-open',
                'attribute', 'bom', 'candidate-before-context', 'candidate-cardinality',
                'candidate-directory-present', 'candidate-entry', 'candidate-file-present',
                'candidate-identity', 'candidate-journal', 'candidate-record',
                'candidate-state', 'content-changed', 'context-conflict-stage',
                'context-head-absent', 'context-invalid', 'context-unissued',
                'context-link', 'context-manager-not-loaded', 'context-path-missing',
                'context-path-wildcard', 'context-provider-qualified-valid',
                'context-raw-object', 'context-unstaged-replacement',
                'context-wrong-tree-type', 'cr', 'declared-length',
                'destination-containment', 'download-already-journaled', 'duplicate-case',
                'duplicate-exact', 'entry-count', 'entry-limit', 'entry-name',
                'entry-read', 'enumeration', 'enumeration-bound', 'enumeration-filter',
                'failure', 'file-evidence', 'file-metadata',
                'download-outside', 'candidate-outside', 'case-sensitive-outside',
                'invalid-zip', 'truncated-zip', 'trailer-decoy', 'extra-entry',
                'archive-not-file', 'entry-unclassifiable',
                'git-hostile-literal-substitution', 'git-ls-files-malformed',
                'git-ls-tree-malformed', 'git-native-status-failure',
                'git-object-id-abbreviated', 'git-object-id-wrong-format', 'hash-shape',
                'helper-index-absent', 'helper-link', 'helper-nonfilesystem-provider',
                'helper-path-missing', 'helper-path-wildcard',
                'helper-provider-qualified-valid', 'helper-raw-array',
                'helper-staged-replacement', 'helper-untracked', 'helper-wrong-mode',
                'identity', 'journal-swapped', 'leaf-present', 'length',
                'mismatch', 'missing-entry', 'mount', 'none',
                'nonordinary', 'nonordinary-directory', 'overlap', 'primary-and-cleanup',
                'private-root-binding', 'private-root-unavailable', 'provider',
                'relationship', 'root-cardinality', 'sha256', 'stream',
                'succeeded', 'total-limit', 'zip-open', 'zip64-locator',
                'checkout-missing', 'checkout-not-directory', 'trusted-missing',
                'trusted-not-directory', 'directory-missing', 'not-directory',
                'parent-missing', 'parent-not-directory', 'root-reparse',
                'ancestor-reparse', 'component-reparse', 'negative-length',
                'inconsistent-length', 'pre-journal-populated', 'entry-unreadable',
                'archive-missing'
            )]
            [string]$Subreason
        )

        $strMessage = "TerraformStyleGuide.CandidateExpand.v1|phase=$Phase|code=$Code|subreason=$Subreason"
        $objException = New-Object System.InvalidOperationException($strMessage)
        $objException.Data['TerraformStyleGuideDiagnosticCode'] = $Code
        $objException.Data['TerraformStyleGuidePhase'] = $Phase
        $objException.Data['TerraformStyleGuideSubreason'] = $Subreason
        return $objException
    }

    $script:scriptBlockStopCandidateHelperOperation = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$Code,

            [Parameter(Mandatory = $true)]
            [string]$Phase,

            [Parameter(Mandatory = $true)]
            [string]$Subreason
        )

        throw (& $script:scriptBlockNewCandidateHelperException `
                -Code $Code `
                -Phase $Phase `
                -Subreason $Subreason)
    }

    $script:scriptBlockGetCandidateHelperFailureField = {
        param (
            [Parameter(Mandatory = $true)]
            [System.Management.Automation.ErrorRecord]$ErrorRecord,

            [Parameter(Mandatory = $true)]
            [string]$Key,

            [Parameter(Mandatory = $true)]
            [string]$Fallback
        )

        if ($null -ne $ErrorRecord.Exception -and
            $null -ne $ErrorRecord.Exception.Data -and
            $ErrorRecord.Exception.Data.Contains($Key)) {
            $objValue = $ErrorRecord.Exception.Data[$Key]
            if ($null -ne $objValue -and $objValue.GetType() -eq [System.String] -and
                $objValue.Length -gt 0 -and $objValue.Length -le 96 -and
                $objValue -match '^[A-Za-z0-9-]+$') {
                return [string]$objValue
            }
        }
        return $Fallback
    }

    $script:scriptBlockAssertCandidateHelperRawString = {
        param (
            [AllowNull()]
            [object]$Value,

            [Parameter(Mandatory = $true)]
            [string]$ParameterName,

            [Parameter(Mandatory = $true)]
            [bool]$IsLabel
        )

        $strKind = if ($IsLabel) { 'label' } elseif ($ParameterName -ceq 'ExpectedDigest') { 'digest' } else { 'path' }
        if ($null -eq $Value) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'parameter' -Phase 'parameter' -Subreason "$strKind-null"
        }
        if ($Value -isnot [System.String]) {
            $strTypeReason = if ($IsLabel) { 'label-not-scalar-string' } else { "$strKind-type" }
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'parameter' -Phase 'parameter' -Subreason $strTypeReason
        }
        $strValue = [string]$Value
        if ($strValue.Length -eq 0) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'parameter' -Phase 'parameter' -Subreason "$strKind-empty"
        }
        # Length is decided before anything walks the value, because everything
        # below is proportional to it and the verdict is not. ToCharArray copies the
        # whole string and the foreach boxes every character, so scanning first and
        # capping afterwards charged the run for a value the cap was always going to
        # refuse. Measured on .NET 8.0.10, a control-free oversized label:
        #
        #     1 MiB    463 ms /  18.72 MiB   ->     2 ms / 0.12 MiB
        #    16 MiB  4,640 ms / 163.58 MiB   ->     0 ms / 0.03 MiB
        #    64 MiB 19,358 ms / 398.13 MiB   ->     0 ms / 0.03 MiB
        #
        # The path parameters were the worse half of this and carried no cap at all:
        # the label at least had one to reach eventually. Their ceiling is the
        # longest path either platform can express -- Windows extended-length paths
        # stop at 32,767 characters and Linux PATH_MAX is far below it -- so it
        # refuses only values that no filesystem could have named, and a legitimate
        # path cannot collide with it.
        $intMaximumLength = if ($IsLabel) {
            $script:intCandidateHelperMaximumLabelLength
        } else {
            $script:intCandidateHelperMaximumPathLength
        }
        if ($strValue.Length -gt $intMaximumLength) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'parameter' -Phase 'parameter' -Subreason "$ParameterName-length"
        }
        if ([System.String]::IsNullOrWhiteSpace($strValue)) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'parameter' -Phase 'parameter' -Subreason "$strKind-whitespace"
        }
        foreach ($chrValue in $strValue.ToCharArray()) {
            if ([System.Char]::IsControl($chrValue)) {
                $strControlReason = if ($strKind -ceq 'path') { 'path-malformed' } else { "$strKind-control" }
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'parameter' -Phase 'parameter' -Subreason $strControlReason
            }
        }
        if ($IsLabel -and $strValue -cnotmatch '\A[1-9][0-9]{0,19}\z') {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'parameter' -Phase 'parameter' -Subreason 'label-grammar'
        }
        return $strValue
    }

    $script:scriptBlockAssertCandidateHelperExactProperty = {
        param (
            [Parameter(Mandatory = $true)]
            [object]$Value,

            [Parameter(Mandatory = $true)]
            [string[]]$ExpectedNames
        )

        $arrProperties = @($Value.PSObject.Properties)
        if ($arrProperties.Count -ne $ExpectedNames.Count) {
            throw 'context-invalid'
        }
        for ($intIndex = 0; $intIndex -lt $ExpectedNames.Count; $intIndex++) {
            if ($arrProperties[$intIndex].Name -cne $ExpectedNames[$intIndex] -or
                $arrProperties[$intIndex].MemberType -ne [System.Management.Automation.PSMemberTypes]::NoteProperty) {
                throw 'context-invalid'
            }
        }
    }

    $script:scriptBlockAssertCandidateHelperCanonicalStoredPath = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$Value
        )

        # Length first, because everything below is proportional to it and the
        # verdict is not. Round 23 capped the raw entry-point parameters and left
        # this validator uncapped, though it governs strings that are just as
        # untrusted: the four paths a caller-supplied context carries, and every
        # journaled path inside it. Measured on .NET 8.0.10, one 32 MiB path took
        # 7,940 ms and 135.11 MiB here -- and was ACCEPTED, so the cost bought the
        # caller a valid verdict rather than a refusal. A forged context carries
        # four of those plus a journal.
        #
        # The ceiling is the same one the parameter rule uses: the longest path
        # either platform can express, so it refuses only what no filesystem could
        # have named.
        if ($Value.Length -gt $script:intCandidateHelperMaximumPathLength) {
            throw 'context-invalid'
        }

        # This rule governs a path that is STORED, and a stored path is consumed
        # only by literal .NET APIs -- File.Delete, Directory.Delete, GetAttributes,
        # and ordinal comparison -- plus one enumeration search pattern. It used to
        # ask WildcardPattern.ContainsWildcardCharacters, which answers a different
        # question: that method reports '*', '?', '[' and ']', because those are
        # PowerShell wildcard syntax, and nothing downstream of a journaled path
        # parses PowerShell wildcards. Only the parameter rules do, and they call
        # that method themselves, before provider path resolution, where it belongs.
        #
        # The consequence of asking the wrong question was refusing 'build[1].zip',
        # an ordinary artifact name that both platforms can produce and that every
        # downstream operation would have handled literally. What must still be
        # refused is '*' and '?', and for a reason specific to this code rather than
        # to PowerShell: every journaled leaf is used as a literal search pattern
        # when cleanup proves that entry gone, and those two are the only characters
        # that expand there. Refusing them at the point a name is adopted is what
        # keeps a name that cannot be cleaned up from ever being recorded.
        if ($Value.Length -eq 0 -or
            $Value.IndexOfAny([char[]]@('*', '?')) -ge 0 -or
            $Value.IndexOf('::', [System.StringComparison]::Ordinal) -ge 0) {
            throw 'context-invalid'
        }
        foreach ($chrValue in $Value.ToCharArray()) {
            if ([System.Char]::IsControl($chrValue)) {
                throw 'context-invalid'
            }
        }

        if ($script:boolCandidateHelperIsWindows) {
            if ($Value.IndexOf([char]'/') -ge 0) {
                throw 'context-invalid'
            }
            $boolDriveRooted = $Value.Length -ge 3 -and
            [System.Char]::IsLetter($Value[0]) -and
            $Value[1] -eq [char]':' -and
            $Value[2] -eq [char]'\'
            $boolUncRooted = $Value.Length -ge 5 -and
            $Value[0] -eq [char]'\' -and $Value[1] -eq [char]'\'
            if (-not $boolDriveRooted -and -not $boolUncRooted) {
                throw 'context-invalid'
            }
            $strRemainder = if ($boolDriveRooted) {
                $Value.Substring(3)
            } else {
                $Value.Substring(2)
            }
            $arrComponents = @($strRemainder.Split([char]'\'))
            if ($boolUncRooted -and $arrComponents.Count -lt 2) {
                throw 'context-invalid'
            }
        } else {
            if ($Value[0] -ne [char]'/' -or $Value.IndexOf([char]0) -ge 0) {
                throw 'context-invalid'
            }
            $arrComponents = @($Value.Substring(1).Split([char]'/'))
        }

        for ($intIndex = 0; $intIndex -lt $arrComponents.Count; $intIndex++) {
            $strComponent = $arrComponents[$intIndex]
            $boolAllowedTrailingEmpty = $intIndex -eq ($arrComponents.Count - 1) -and
            $strComponent.Length -eq 0 -and
            (($script:boolCandidateHelperIsWindows -and $boolDriveRooted -and $Value.Length -eq 3) -or
            (-not $script:boolCandidateHelperIsWindows -and $Value.Length -eq 1))
            if (-not $boolAllowedTrailingEmpty -and
                ($strComponent.Length -eq 0 -or $strComponent -in @('.', '..'))) {
                throw 'context-invalid'
            }
        }
    }

    $script:scriptBlockAssertCandidateHelperContext = {
        param (
            [AllowNull()]
            [object]$ContextValue
        )

        if ($null -eq $ContextValue -or
            $ContextValue.GetType() -ne [System.Management.Automation.PSCustomObject] -or
            $ContextValue.PSObject.TypeNames.Count -eq 0 -or
            $ContextValue.PSObject.TypeNames[0] -cne $script:strCandidateHelperContextTypeName) {
            throw 'context-invalid'
        }
        [void](& $script:scriptBlockAssertCandidateHelperExactProperty `
                -Value $ContextValue `
                -ExpectedNames @(
                'SchemaVersion',
                'ContextScriptVersion',
                'InvocationId',
                'DiagnosticLabel',
                'TrustedParentPath',
                'InvocationRootPath',
                'DownloadDirectoryPath',
                'CandidatePath',
                'LifecycleState',
                'NextSequence',
                'OwnershipJournal'
            ))

        # Round 63 (Codex): bind the journal to a single read here. Every check
        # below, and the plan this assertion returns to its callers, reads THIS
        # captured reference rather than $ContextValue.OwnershipJournal again -- a
        # property a same-session holder can repoint between reads, so validating
        # one array and letting a later read (here, or in a caller that re-reads the
        # property after this returns) act on another is the exact swap the
        # journal-current guard exists to refuse. One read, one validated array,
        # returned so no caller has to read the property a second time.
        $objJournal = $ContextValue.OwnershipJournal

        if ($ContextValue.SchemaVersion.GetType() -ne [System.UInt32] -or
            $ContextValue.SchemaVersion -ne [uint32]1 -or
            $ContextValue.ContextScriptVersion.GetType() -ne [System.Version] -or
            $ContextValue.ContextScriptVersion -ne $script:versionCandidateExpectedContext -or
            $ContextValue.InvocationId.GetType() -ne [System.Guid] -or
            $ContextValue.InvocationId -eq [System.Guid]::Empty -or
            $ContextValue.DiagnosticLabel.GetType() -ne [System.String] -or
            $ContextValue.DiagnosticLabel.Length -eq 0 -or $ContextValue.DiagnosticLabel.Length -gt 128 -or
            [System.String]::IsNullOrWhiteSpace($ContextValue.DiagnosticLabel) -or
            $ContextValue.TrustedParentPath.GetType() -ne [System.String] -or
            $ContextValue.TrustedParentPath.Length -eq 0 -or
            $ContextValue.InvocationRootPath.GetType() -ne [System.String] -or
            $ContextValue.InvocationRootPath.Length -eq 0 -or
            $ContextValue.DownloadDirectoryPath.GetType() -ne [System.String] -or
            $ContextValue.DownloadDirectoryPath.Length -eq 0 -or
            $ContextValue.CandidatePath.GetType() -ne [System.String] -or
            $ContextValue.CandidatePath.Length -eq 0 -or
            $ContextValue.LifecycleState.GetType() -ne [System.String] -or
            $ContextValue.LifecycleState -cnotin @('Active', 'CleanupFailed', 'Disposed') -or
            $ContextValue.NextSequence.GetType() -ne [System.UInt32] -or
            $objJournal.GetType() -ne [System.Object[]] -or
            $ContextValue.NextSequence -ne [uint32]$objJournal.Count) {
            throw 'context-invalid'
        }

        foreach ($strContextPath in @(
                $ContextValue.TrustedParentPath,
                $ContextValue.InvocationRootPath,
                $ContextValue.DownloadDirectoryPath,
                $ContextValue.CandidatePath
            )) {
            [void](& $script:scriptBlockAssertCandidateHelperCanonicalStoredPath -Value $strContextPath)
        }

        # The label is scanned character by character, so its length is decided
        # first for the same reason the paths above are.
        if ($ContextValue.DiagnosticLabel.Length -gt $script:intCandidateHelperMaximumLabelLength) {
            throw 'context-invalid'
        }
        foreach ($chrLabel in $ContextValue.DiagnosticLabel.ToCharArray()) {
            if ([System.Char]::IsControl($chrLabel)) {
                throw 'context-invalid'
            }

        }

        $objPaths = New-Object 'System.Collections.Generic.HashSet[string]' `
        ($script:objCandidateHelperPathComparer)
        $hashtableCounts = @{
            InvocationRootDirectory = 0
            DownloadDirectory = 0
            DownloadFile = 0
            CandidateDirectory = 0
            CandidateFile = 0
        }

        # Bounded before the loop, not after it. The cardinality rules further down
        # reject a journal carrying more than one root, download directory,
        # candidate directory, or download file -- but only once every record has
        # been schema-checked, canonicalized, and added to the path set, and a
        # schema-shaped context is untrusted input. Measured on .NET 8 against the
        # context manager's identical loop: 20000 forged records cost 4960 ms and
        # 48.54 MiB, 200000 cost 60929 ms and 365.03 MiB, for a journal this schema
        # caps at eight.
        #
        # Derived rather than written down: one invocation root, one download
        # directory, one candidate directory, one download file, and one candidate
        # file per manifest name. Growing the manifest moves the cap on its own.
        $intMaximumJournalRecord = 4 + $script:arrCandidateHelperExpectedName.Count
        if ($objJournal.Count -gt $intMaximumJournalRecord) {
            throw 'context-invalid'
        }

        for ($intIndex = 0; $intIndex -lt $objJournal.Count; $intIndex++) {
            $objRecord = $objJournal[$intIndex]
            if ($null -eq $objRecord -or
                $objRecord.GetType() -ne [System.Management.Automation.PSCustomObject] -or
                $objRecord.PSObject.TypeNames.Count -eq 0 -or
                $objRecord.PSObject.TypeNames[0] -cne $script:strCandidateHelperRecordTypeName) {
                throw 'context-invalid'
            }
            [void](& $script:scriptBlockAssertCandidateHelperExactProperty `
                    -Value $objRecord `
                    -ExpectedNames @(
                    'SchemaVersion',
                    'Sequence',
                    'Kind',
                    'Path',
                    'ParentPath',
                    'LeafName',
                    'ExpectedEntryType',
                    'CreationPhase',
                    'EntryState',
                    'ContentLength',
                    'ContentSha256'
                ))
            if ($objRecord.SchemaVersion.GetType() -ne [System.UInt32] -or
                $objRecord.SchemaVersion -ne [uint32]1 -or
                $objRecord.Sequence.GetType() -ne [System.UInt32] -or
                $objRecord.Sequence -ne [uint32]$intIndex -or
                $objRecord.Kind.GetType() -ne [System.String] -or
                -not $hashtableCounts.ContainsKey($objRecord.Kind) -or
                $objRecord.Path.GetType() -ne [System.String] -or $objRecord.Path.Length -eq 0 -or
                $objRecord.ParentPath.GetType() -ne [System.String] -or $objRecord.ParentPath.Length -eq 0 -or
                $objRecord.LeafName.GetType() -ne [System.String] -or $objRecord.LeafName.Length -eq 0 -or
                $objRecord.LeafName.Length -gt $script:intCandidateHelperMaximumLeafLength -or
                $objRecord.LeafName -in @('.', '..') -or
                $objRecord.LeafName.IndexOf($script:chrCandidateHelperDirectorySeparator) -ge 0 -or
                $objRecord.LeafName.IndexOf($script:chrCandidateHelperAlternateSeparator) -ge 0 -or
                $objRecord.ExpectedEntryType.GetType() -ne [System.String] -or
                $objRecord.ExpectedEntryType -cnotin @('File', 'Directory') -or
                $objRecord.CreationPhase.GetType() -ne [System.String] -or
                $objRecord.CreationPhase -cnotin @('context', 'download', 'destination', 'extraction') -or
                $objRecord.EntryState.GetType() -ne [System.String] -or
                $objRecord.EntryState -cnotin @('ExpectedAbsent', 'Created', 'Deleted', 'RetainedUncertain')) {
                throw 'context-invalid'
            }


            [void](& $script:scriptBlockAssertCandidateHelperCanonicalStoredPath -Value $objRecord.Path)
            [void](& $script:scriptBlockAssertCandidateHelperCanonicalStoredPath -Value $objRecord.ParentPath)

            $strParentPrefix = $objRecord.ParentPath.TrimEnd(
                $script:chrCandidateHelperDirectorySeparator,
                $script:chrCandidateHelperAlternateSeparator
            ) + $script:chrCandidateHelperDirectorySeparator
            if (-not [System.String]::Equals(
                    $strParentPrefix + $objRecord.LeafName,
                    $objRecord.Path,
                    $script:objCandidateHelperPathComparison
                ) -or -not $objPaths.Add($objRecord.Path)) {
                throw 'context-invalid'
            }

            $hashtableCounts[$objRecord.Kind]++
            if ($objRecord.Kind -in @('InvocationRootDirectory', 'DownloadDirectory', 'CandidateDirectory')) {
                if ($objRecord.ExpectedEntryType -cne 'Directory' -or
                    $null -ne $objRecord.ContentLength -or $null -ne $objRecord.ContentSha256) {
                    throw 'context-invalid'
                }
            } else {
                # A record's ContentLength is caller-supplied and, until here,
                # unbounded: a forged journal could claim any 64-bit size. Cleanup
                # trusts that number to decide how much evidence to gather, so an
                # uncapped value is an instruction to read an arbitrarily large
                # file. The ceilings that already govern this manifest are the
                # right bound -- a download record can be as large as the archive
                # ceiling, a candidate file as large as one entry -- and nothing
                # legitimate reaches either.
                $uintRecordLengthCeiling = if ($objRecord.Kind -ceq 'DownloadFile') {
                    $script:uintCandidateHelperMaximumArchiveByte
                } else {
                    $script:uintCandidateHelperMaximumEntryByte
                }
                if ($objRecord.ExpectedEntryType -cne 'File' -or
                    $objRecord.EntryState -eq 'ExpectedAbsent' -or
                    $null -eq $objRecord.ContentLength -or
                    $objRecord.ContentLength.GetType() -ne [System.UInt64] -or
                    $objRecord.ContentLength -gt $uintRecordLengthCeiling -or
                    $null -eq $objRecord.ContentSha256 -or
                    $objRecord.ContentSha256.GetType() -ne [System.String] -or
                    $objRecord.ContentSha256 -cnotmatch '^[0-9a-f]{64}$') {
                    throw 'context-invalid'
                }
            }

            if ($objRecord.Kind -eq 'InvocationRootDirectory') {
                if ($objRecord.CreationPhase -cne 'context' -or
                    $objRecord.EntryState -eq 'ExpectedAbsent') {
                    throw 'context-invalid'
                }
            } elseif ($objRecord.Kind -eq 'DownloadDirectory') {
                # ExpectedAbsent is legitimate here and only here. Creation records
                # the invocation root, then creates the download directory, so a
                # failure between those steps leaves this record never created while
                # the root is already owned. Modelling that state lets the creation
                # failure path hand a valid context to cleanup, which skips
                # ExpectedAbsent records and still removes the root instead of
                # leaking it. The reverse - an owned download directory under a root
                # that was never created - remains invalid.
                if ($objRecord.CreationPhase -cne 'context') {
                    throw 'context-invalid'
                }
            } elseif ($objRecord.Kind -eq 'DownloadFile') {
                if ($objRecord.CreationPhase -cne 'download') {
                    throw 'context-invalid'
                }
            } elseif ($objRecord.Kind -eq 'CandidateDirectory') {
                if (($objRecord.EntryState -eq 'ExpectedAbsent' -and $objRecord.CreationPhase -cne 'context') -or
                    ($objRecord.EntryState -ne 'ExpectedAbsent' -and $objRecord.CreationPhase -cne 'destination')) {
                    throw 'context-invalid'
                }
            } elseif ($objRecord.CreationPhase -cne 'extraction') {
                throw 'context-invalid'
            }

            if ($objRecord.Kind -eq 'InvocationRootDirectory') {
                if (-not [System.String]::Equals(
                        $objRecord.Path,
                        $ContextValue.InvocationRootPath,
                        $script:objCandidateHelperPathComparison
                    ) -or -not [System.String]::Equals(
                        $objRecord.ParentPath,
                        ([System.IO.Path]::GetDirectoryName($ContextValue.InvocationRootPath)),
                        $script:objCandidateHelperPathComparison
                    )) {
                    throw 'context-invalid'
                }
            } elseif ($objRecord.Kind -eq 'DownloadDirectory') {
                if (-not [System.String]::Equals(
                        $objRecord.Path,
                        $ContextValue.DownloadDirectoryPath,
                        $script:objCandidateHelperPathComparison
                    ) -or -not [System.String]::Equals(
                        $objRecord.ParentPath,
                        ([System.IO.Path]::GetDirectoryName($ContextValue.DownloadDirectoryPath)),
                        $script:objCandidateHelperPathComparison
                    )) {
                    throw 'context-invalid'
                }
            } elseif ($objRecord.Kind -eq 'DownloadFile') {
                if (-not [System.String]::Equals(
                        $objRecord.ParentPath,
                        $ContextValue.DownloadDirectoryPath,
                        $script:objCandidateHelperPathComparison
                    )) {
                    throw 'context-invalid'
                }
            } elseif ($objRecord.Kind -eq 'CandidateDirectory') {
                if (-not [System.String]::Equals(
                        $objRecord.Path,
                        $ContextValue.CandidatePath,
                        $script:objCandidateHelperPathComparison
                    ) -or -not [System.String]::Equals(
                        $objRecord.ParentPath,
                        $ContextValue.InvocationRootPath,
                        $script:objCandidateHelperPathComparison
                    )) {
                    throw 'context-invalid'
                }
            } elseif (-not [System.String]::Equals(
                    $objRecord.ParentPath,
                    $ContextValue.CandidatePath,
                    $script:objCandidateHelperPathComparison
                )) {
                throw 'context-invalid'
            }
        }

        if ($hashtableCounts.InvocationRootDirectory -ne 1 -or
            $hashtableCounts.DownloadDirectory -ne 1 -or
            $hashtableCounts.CandidateDirectory -ne 1 -or
            $hashtableCounts.DownloadFile -gt 1) {
            throw 'context-invalid'
        }
        $objCandidateDirectoryRecord = @($objJournal | Where-Object {
                $_.Kind -eq 'CandidateDirectory'
            })[0]
        $arrCandidateFileRecords = @($objJournal | Where-Object {
                $_.Kind -eq 'CandidateFile'
            })
        if ($arrCandidateFileRecords.Count -gt 4 -or
            ($objCandidateDirectoryRecord.EntryState -eq 'ExpectedAbsent' -and
            $arrCandidateFileRecords.Count -ne 0) -or
            ($objCandidateDirectoryRecord.EntryState -eq 'Deleted' -and
            @($arrCandidateFileRecords | Where-Object { $_.EntryState -ne 'Deleted' }).Count -ne 0)) {
            throw 'context-invalid'
        }
        if ($ContextValue.LifecycleState -eq 'Active') {
            $objRootRecord = @($objJournal | Where-Object {
                    $_.Kind -eq 'InvocationRootDirectory'
                })[0]
            $objDownloadDirectoryRecord = @($objJournal | Where-Object {
                    $_.Kind -eq 'DownloadDirectory'
                })[0]
            # An ExpectedAbsent download directory is only ever produced by the
            # context manager's own creation-failure cleanup, which never hands a
            # context back. Everything reaching this script therefore had its
            # download directory created, and accepting the relaxed state here
            # would let a forged context journal an archive and candidate beneath a
            # directory its own record says was never created. Cleanup would then
            # exclude that directory, see it as an unexpected root entry, and reach
            # CleanupFailed after a successful expansion.
            # Which record states an Active context may carry at all is settled by
            # the admitted-state table below. What remains here is the part that
            # table cannot express: the states these two specific kinds must hold.
            if ($objRootRecord.EntryState -cne 'Created' -or
                $objDownloadDirectoryRecord.EntryState -cne 'Created') {
                throw 'context-invalid'
            }
        }

        # Each lifecycle state admits an exact set of record states, and one state
        # additionally demands a member. Stating the pairing as data rather than as
        # a block per lifecycle state keeps every combination classified: an
        # unlisted record state is refused because it was never admitted, not
        # because someone remembered to name it. A per-state deny list would let a
        # record state added later pass silently everywhere it was not yet listed.
        #
        # CleanupFailed is terminal and does no filesystem work, so it reports the
        # owned entries it could not resolve instead of removing them. A surviving
        # Created record would name an entry that is owned and present yet absent
        # from that report, so Created is not admitted here: the producing failure
        # path retypes every Created record before reaching this state.
        #
        # This table must stay identical to the context manager's. The two scripts
        # validate the same object and are reached by separate entry points, so a
        # state one admits and the other refuses would make acceptance depend on
        # which script the caller happened to call first.
        $hashtableAdmittedEntryState = @{
            'Active' = [string[]]@('ExpectedAbsent', 'Created', 'Deleted')
            'CleanupFailed' = [string[]]@('ExpectedAbsent', 'Deleted', 'RetainedUncertain')
            'Disposed' = [string[]]@('ExpectedAbsent', 'Deleted')
        }
        $hashtableRequiredEntryState = @{
            'CleanupFailed' = 'RetainedUncertain'
        }
        if (-not $hashtableAdmittedEntryState.ContainsKey($ContextValue.LifecycleState)) {
            throw 'context-invalid'
        }
        $arrAdmittedEntryState = [string[]]$hashtableAdmittedEntryState[$ContextValue.LifecycleState]
        foreach ($objRecord in $objJournal) {
            if ($objRecord.EntryState -cnotin $arrAdmittedEntryState) {
                throw 'context-invalid'
            }
        }
        if ($hashtableRequiredEntryState.ContainsKey($ContextValue.LifecycleState)) {
            $strRequiredEntryState = [string]$hashtableRequiredEntryState[$ContextValue.LifecycleState]
            $boolRequiredPresent = $false
            foreach ($objRecord in $objJournal) {
                if ($objRecord.EntryState -ceq $strRequiredEntryState) {
                    $boolRequiredPresent = $true
                }
            }
            if (-not $boolRequiredPresent) {
                throw 'context-invalid'
            }
        }

        # Round 63 (Codex): the validated journal, returned as the plan its callers
        # authenticate against. The unary comma keeps a single-element journal an
        # array rather than unrolling it to the bare record.
        return , $objJournal
    }

    $script:scriptBlockNewCandidateHelperRecord = {
        param (
            [Parameter(Mandatory = $true)]
            [uint32]$Sequence,

            [Parameter(Mandatory = $true)]
            [string]$Kind,

            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string]$ParentPath,

            [Parameter(Mandatory = $true)]
            [string]$LeafName,

            [Parameter(Mandatory = $true)]
            [string]$CreationPhase,

            [Parameter(Mandatory = $true)]
            [uint64]$ContentLength,

            [Parameter(Mandatory = $true)]
            [string]$ContentSha256
        )

        $objRecord = [pscustomobject][ordered]@{
            SchemaVersion = [uint32]1
            Sequence = [uint32]$Sequence
            Kind = [string]$Kind
            Path = [string]$Path
            ParentPath = [string]$ParentPath
            LeafName = [string]$LeafName
            ExpectedEntryType = [string]'File'
            CreationPhase = [string]$CreationPhase
            EntryState = [string]'Created'
            ContentLength = [uint64]$ContentLength
            ContentSha256 = [string]$ContentSha256
        }
        $objRecord.PSObject.TypeNames.Insert(0, $script:strCandidateHelperRecordTypeName)
        return $objRecord
    }

    $script:scriptBlockAssertCandidateHelperJournalCurrent = {
        param (
            [Parameter(Mandatory = $true)]
            [object]$ContextValue,

            [Parameter(Mandatory = $true)]
            [object]$JournalValue,

            [Parameter(Mandatory = $true)]
            [uint32]$NextSequenceValue,

            [Parameter(Mandatory = $true)]
            [string]$PhaseValue
        )

        # The caller's context must still hold the exact journal array this
        # expansion authenticated, at the sequence it authenticated. Reference
        # identity is the check, not equality: a structural clone is a different
        # journal. This is the guard the record append has enforced since round 52
        # (EE6/II1), factored out at round 61 so the DESTINATION create enforces
        # the same thing. Codex observed that the create ran with no such check
        # between the download append and the first file append: a same-session
        # swap in that window created the candidate directory while the live
        # context pointed at a decoy journal, and when the next append refused
        # 'journal-swapped', rollback validated the decoy, met the real directory
        # as an entry no journal described, and left the issued tree on disk. One
        # source of truth so neither site drifts from the other.
        if (-not [System.Object]::ReferenceEquals(
                $ContextValue.OwnershipJournal, $JournalValue)) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'parameter' -Phase $PhaseValue -Subreason 'journal-swapped'
        }
        if ([uint32]$ContextValue.NextSequence -ne $NextSequenceValue) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'parameter' -Phase $PhaseValue -Subreason 'journal-swapped'
        }
    }

    $script:scriptBlockAssertCandidateHelperRecordUnchanged = {
        param (
            [Parameter(Mandatory = $true)]
            [AllowNull()]
            [object]$Record,

            [Parameter(Mandatory = $true)]
            [object]$Snapshot,

            [Parameter(Mandatory = $true)]
            [string]$PhaseValue,

            # Round 71 (Codex P2): this guard was written for the candidate record
            # alone and hardcoded its Kind and fixed fields. It is generalised here so
            # the seq-0 root and seq-1 download records the context manager issued can
            # be re-proven with the same shape/fixed-field/caller-variable-path
            # discipline before the irreversible create. ExpectedKind replaces the
            # hardcoded 'CandidateDirectory'. ExpectedEntryState, when non-null,
            # additionally pins the record's EntryState against its only admitted
            # value -- 'Created' for the two pre-existing directories, which are on
            # disk before this expansion runs; the candidate record passes $null and
            # is exempt, because its EntryState is ExpectedAbsent here, proven
            # separately by the caller, and flipped to Created by the create itself.
            # The two parameters default to the candidate's prior behaviour so the
            # candidate call site and the round-64/65 harness unit probe are unchanged.
            [Parameter(Mandatory = $false)]
            [string]$ExpectedKind = 'CandidateDirectory',

            [Parameter(Mandatory = $false)]
            [AllowNull()]
            [object]$ExpectedEntryState = $null
        )

        # Round 64 (Codex): reference identity of the journal array says nothing
        # about a record's mutable fields, and the destination create marks this
        # record and hands it to the final context assertion. Every field that
        # assertion re-validates for a pre-create ExpectedAbsent CandidateDirectory
        # record is re-proven here -- the caller-variable paths against the snapshot
        # captured at authentication, the fixed fields against their only admitted
        # value and type -- so a same-session flip of any of them is refused before
        # the irreversible create rather than surfacing as a rollback the manager
        # rejects, which retains the issued tree. Round 63 re-proved Kind, Sequence
        # and Path only. Type as well as value: a field retyped to something that
        # stringises the same still fails the assertion that reads its type.
        #
        # Round 65 (Codex): the record's SHAPE as well, before its field values --
        # the type name and the exact NoteProperty set scriptBlockAssertCandidate-
        # HelperContext checks per record. A same-session holder that adds or removes
        # a property, retypes one off NoteProperty, or repoints PSObject.TypeNames
        # after authentication passes a value-only re-proof, so the create runs and
        # only the post-append assertion rejects the record, handing cleanup a
        # journal it refuses and retaining the issued tree. The same two proofs run
        # here so the pre-create guard and that assertion cannot drift.
        if ($null -eq $Record -or
            $Record.GetType() -ne [System.Management.Automation.PSCustomObject] -or
            $Record.PSObject.TypeNames.Count -eq 0 -or
            $Record.PSObject.TypeNames[0] -cne $script:strCandidateHelperRecordTypeName) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'destination-invalid' -Phase $PhaseValue -Subreason 'candidate-record'
        }
        $boolCandidateRecordPropertiesExact = $true
        try {
            [void](& $script:scriptBlockAssertCandidateHelperExactProperty `
                    -Value $Record `
                    -ExpectedNames @(
                    'SchemaVersion', 'Sequence', 'Kind', 'Path', 'ParentPath',
                    'LeafName', 'ExpectedEntryType', 'CreationPhase', 'EntryState',
                    'ContentLength', 'ContentSha256'
                ))
        } catch {
            $boolCandidateRecordPropertiesExact = $false
        }
        if (-not $boolCandidateRecordPropertiesExact) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'destination-invalid' -Phase $PhaseValue -Subreason 'candidate-record'
        }
        if ($null -eq $Record -or
            $Record.SchemaVersion -isnot [System.UInt32] -or
            $Record.SchemaVersion -ne [uint32]1 -or
            $Record.Sequence -isnot [System.UInt32] -or
            $Record.Sequence -ne [uint32]$Snapshot.Sequence -or
            $Record.Kind -isnot [System.String] -or
            $Record.Kind -cne $ExpectedKind -or
            $Record.ExpectedEntryType -isnot [System.String] -or
            $Record.ExpectedEntryType -cne 'Directory' -or
            $Record.CreationPhase -isnot [System.String] -or
            $Record.CreationPhase -cne 'context' -or
            $null -ne $Record.ContentLength -or
            $null -ne $Record.ContentSha256 -or
            $Record.Path -isnot [System.String] -or
            $Record.ParentPath -isnot [System.String] -or
            $Record.LeafName -isnot [System.String] -or
            -not [System.String]::Equals(
                [string]$Record.Path, [string]$Snapshot.Path,
                $script:objCandidateHelperPathComparison) -or
            -not [System.String]::Equals(
                [string]$Record.ParentPath, [string]$Snapshot.ParentPath,
                $script:objCandidateHelperPathComparison) -or
            -not [System.String]::Equals(
                [string]$Record.LeafName, [string]$Snapshot.LeafName,
                $script:objCandidateHelperPathComparison)) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'destination-invalid' -Phase $PhaseValue -Subreason 'candidate-record'
        }
        # Round 71 (Codex P2): when EntryState is a fixed field of this record kind --
        # the pre-existing root and download directories, on disk as 'Created' before
        # this expansion runs -- pin it against that value and its type. Type as well
        # as value, like the fixed fields above: a field retyped off [string] fails.
        # A same-session flip of a pre-existing record's EntryState (the reproduced
        # 'Created' -> 'Deleted' swap) is refused here, before the irreversible create,
        # instead of surfacing as the post-create context assertion's rejection, which
        # hands cleanup a journal it refuses and retains the issued tree. The candidate
        # record passes $null here and is exempt: its ExpectedAbsent state is proven by
        # the caller and flipped to Created by the create itself.
        if ($null -ne $ExpectedEntryState -and (
                $Record.EntryState -isnot [System.String] -or
                $Record.EntryState -cne [string]$ExpectedEntryState)) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'destination-invalid' -Phase $PhaseValue -Subreason 'candidate-record'
        }
    }

    $script:scriptBlockAddCandidateHelperRecord = {
        param (
            [Parameter(Mandatory = $true)]
            [object]$ContextValue,

            [Parameter(Mandatory = $true)]
            [object]$Record,

            [Parameter(Mandatory = $true)]
            [object]$JournalValue,

            [Parameter(Mandatory = $true)]
            [uint32]$NextSequenceValue,

            [Parameter(Mandatory = $true)]
            [string]$PhaseValue
        )

        # Round 43 captured the journal and the sequence this expansion had
        # authenticated, and then numbered records from the captured sequence
        # while still appending to whatever `$ContextValue.OwnershipJournal`
        # happened to be at the moment of the call. Half the capture was used.
        # Measured deterministically: with the journal swapped after
        # authentication, the download record lands in the swapped array and the
        # authenticated one is never touched --
        #
        #   authenticated journal length : 3
        #   context journal length       : 1
        #   record landed in the DECOY journal : True
        #
        # -- after which the context assertion fails and rollback is handed a
        # context the manager refuses, leaving the issued tree on disk. So the
        # append reads the journal it was given, and refuses outright if the
        # caller's context no longer holds that exact array. The check itself now
        # lives in scriptBlockAssertCandidateHelperJournalCurrent so the append and
        # the destination create share one definition of "still current" (round 61).
        & $script:scriptBlockAssertCandidateHelperJournalCurrent `
            -ContextValue $ContextValue `
            -JournalValue $JournalValue `
            -NextSequenceValue $NextSequenceValue `
            -PhaseValue $PhaseValue

        $arrJournal = New-Object object[] ($JournalValue.Count + 1)
        [System.Array]::Copy(
            $JournalValue,
            0,
            $arrJournal,
            0,
            $JournalValue.Count
        )
        $arrJournal[$arrJournal.Length - 1] = $Record
        $ContextValue.OwnershipJournal = [object[]]$arrJournal
        $ContextValue.NextSequence = [uint32]($NextSequenceValue + 1)
        # Returned so the caller's capture advances with the journal it just
        # committed, rather than re-reading the context to find out what happened.
        return , [object[]]$arrJournal
    }

    $script:scriptBlockGetCandidateHelperRetainedSequence = {
        param (
            [Parameter(Mandatory = $true)]
            [AllowNull()]
            [AllowEmptyCollection()]
            [object]$JournalValue
        )

        # Round 61 (Codex): the journal is passed in, not read back off a context.
        # The sole caller is the cleanup catch, which reaches here precisely when
        # the manager delegation threw -- and a rebound manager can replace
        # $Context.OwnershipJournal with an unbounded, attacker-shaped array before
        # throwing. Reading that live property here iterated 2,000,000 planted
        # records in 5.5 s on .NET 8 and returned attacker-chosen sequences, which
        # contradicts the bounded result the catch documents. The caller now passes
        # the journal it captured and authenticated at entry, whose length the
        # context assertion already bounds, so nothing the failed manager left on
        # the live object reaches this iteration.
        $listSequences = New-Object 'System.Collections.Generic.List[uint32]'
        foreach ($objRecord in $JournalValue) {
            if ($objRecord.EntryState -eq 'RetainedUncertain') {
                $listSequences.Add([uint32]$objRecord.Sequence)
            }
        }
        # The unary comma keeps an empty result an empty array. Returning it
        # bare would unroll to null and break the closed result schema.
        return , [uint32[]]$listSequences.ToArray()
    }

    $script:scriptBlockNewCandidateHelperCleanupResult = {
        param (
            [Parameter(Mandatory = $true)]
            [System.Guid]$InvocationId,

            [Parameter(Mandatory = $true)]
            [string]$PreviousState,

            [Parameter(Mandatory = $true)]
            [string]$FinalState,

            [Parameter(Mandatory = $true)]
            [bool]$Success,

            [Parameter(Mandatory = $true)]
            [string]$DiagnosticCode,

            [Parameter(Mandatory = $true)]
            [uint32]$ReferenceToFilesystemCallCount,

            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [uint32[]]$RetainedRecordSequences
        )

        $objResult = [pscustomobject][ordered]@{
            SchemaVersion = [uint32]1
            ContextScriptVersion = $script:versionCandidateExpectedContext
            InvocationId = $InvocationId
            PreviousState = [string]$PreviousState
            FinalState = [string]$FinalState
            Success = [bool]$Success
            DiagnosticCode = [string]$DiagnosticCode
            FilesystemCallCount = [uint32]$ReferenceToFilesystemCallCount
            RetainedRecordSequences = [uint32[]]@($RetainedRecordSequences)
        }
        $objResult.PSObject.TypeNames.Insert(0, $script:strCandidateHelperCleanupTypeName)
        return $objResult
    }

    $script:scriptBlockGetCandidateHelperEntry = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$LiteralPath,

            [Parameter(Mandatory = $true)]
            [string]$Phase,

            [int]$MaximumEntry,

            [string]$MatchPath,

            [ref]$ReferenceToFilesystemCallCount
        )

        # The caller supplies the phase. Enumeration runs during download,
        # destination, extraction, post-extraction, and cleanup, so hard-coding a
        # cleanup failure here would report an earlier phase's failure as a cleanup
        # failure and let it match the wrong oracle.
        $strFailureCode = if ($Phase -ceq 'cleanup') {
            'cleanup-owned-entry-uncertain'
        } else {
            "$Phase-invalid"
        }
        # A caller that only needs to know whether the entry count matches a fixed
        # expectation does not need every path. Materializing the whole listing to
        # answer "is this exactly one file?" makes a directory holding hundreds of
        # thousands of entries cost proportional managed memory before any archive
        # ceiling applies -- 200000 empty files measured 19.11 MiB against 0.16 MiB
        # for a bounded read, and no ceiling is in force at that point because no
        # archive has been opened. MaximumEntry stops the enumerator once that many
        # paths have been seen; a caller expecting N passes N + 1, so "exactly N"
        # and "more than N" stay distinguishable. Because the enumerator ends on
        # its own whenever fewer than MaximumEntry paths exist, a returned count
        # below the bound is still the complete listing, which is what the presence
        # checks downstream rely on. Callers proving a path ABSENT must not pass a
        # bound: absence cannot be concluded from a partial listing.
        #
        # That rule is true and was, on its own, read too far: it does not follow
        # that an absence proof must read EVERYTHING. Every absence proof here names
        # the one path it is disproving, and asking the filesystem about that one
        # name is what MatchPath does. The whole-parent read it replaces was work an
        # unrelated party could inflate simply by keeping files in the same shared
        # temporary directory -- 50000 unrelated entries measured 660 ms and
        # 15.87 MiB on .NET 8, 389 ms and 19.96 MiB on .NET 10, against 72 ms and
        # 0.05 MiB filtered, and the creation loop retries up to 16 times.
        #
        # Filtering must not become a weaker test, so it is a filter and nothing
        # more: the caller's exact full-path comparison is unchanged, and a search
        # pattern that matches extra names can therefore only be rejected by it. The
        # dangerous direction is matching too FEW, which a literal pattern cannot do
        # -- so a leaf carrying a wildcard metacharacter is refused rather than
        # pattern-matched. Existence APIs are not an option in its place: File.Exists
        # and Directory.Exists disagree with each other on a dangling symbolic link
        # (measured True and False on .NET 8 and .NET 10) and both report absent on
        # Windows, where the link is followed. Enumeration names entries without
        # following them, which is why it was chosen and why it stays.
        #
        # MaximumEntry uses an in-band sentinel: omitted means unbounded, and the
        # parameter defaults to zero, so the `-le 0` branch below is what serves the
        # absence proofs. That makes an explicit `-MaximumEntry 0` read as a bound
        # while meaning the opposite, which is how a cardinality check can be
        # neutered without looking neutered. Omission stays unbounded; an explicitly
        # supplied non-positive bound is a contradiction and is refused here, above
        # the try, so it is not reported as an enumeration failure and no filesystem
        # call is counted for a call that never happened. A bounded filtered read is
        # the same contradiction wearing the other hat -- it would reduce a named
        # absence proof to a partial listing again -- so the two are refused
        # together.
        # Exactly one of the two, always. There used to be a third shape -- neither,
        # meaning read everything -- and no call site has needed it since every read
        # became bounded or filtered. Keeping it meant an unbounded path existed for
        # a caller to reach, and reaching it did not require editing any call site:
        # parking the expected call under `if ($false)` so the source-order table
        # still counted it, then performing the live read through a variable holding
        # this same script block, left the suite green at 115 records and zero
        # failures with the whole parent materialized. Source cannot settle that,
        # because the indirection is unbounded in form; the mode is removed instead.
        #
        # The ceiling refuses the other half of the same trick. A bound is only a
        # bound if it is small: the largest legitimate one here is an owned-file
        # count plus one, and the manifest fixes that at four, so a value like
        # 999999 is a bound in shape and not in effect.
        if (($PSBoundParameters.ContainsKey('MaximumEntry') -eq
                $PSBoundParameters.ContainsKey('MatchPath')) -or
            ($PSBoundParameters.ContainsKey('MaximumEntry') -and
            ($MaximumEntry -le 0 -or
            $MaximumEntry -gt $script:intCandidateHelperMaximumEntryCeiling))) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code $strFailureCode -Phase $Phase -Subreason 'enumeration-bound'
        }
        $strMatchLeaf = ''
        if ($PSBoundParameters.ContainsKey('MatchPath')) {
            $strMatchLeaf = [System.IO.Path]::GetFileName($MatchPath)
            if ($strMatchLeaf.Length -eq 0 -or
                $strMatchLeaf.Length -gt $script:intCandidateHelperMaximumLeafLength -or
                $strMatchLeaf -ceq '.' -or
                $strMatchLeaf -ceq '..' -or
                $strMatchLeaf.IndexOfAny($script:arrCandidateHelperRejectedMatchCharacter) -ge 0) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code $strFailureCode -Phase $Phase -Subreason 'enumeration-filter'
            }
        }

        try {
            if ($null -ne $ReferenceToFilesystemCallCount) {
                $ReferenceToFilesystemCallCount.Value = [uint32]($ReferenceToFilesystemCallCount.Value + 1)
            }
            if ($strMatchLeaf.Length -ne 0) {
                return [string[]]@([System.IO.Directory]::EnumerateFileSystemEntries(
                        $LiteralPath, $strMatchLeaf))
            }
            $listEntry = New-Object 'System.Collections.Generic.List[string]'
            $objEnumerator = [System.IO.Directory]::EnumerateFileSystemEntries(
                $LiteralPath).GetEnumerator()
            try {
                while ($listEntry.Count -lt $MaximumEntry -and $objEnumerator.MoveNext()) {
                    $listEntry.Add([string]$objEnumerator.Current)
                }
            } finally {
                $objEnumerator.Dispose()
            }
            return [string[]]@($listEntry.ToArray())
        } catch {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code $strFailureCode -Phase $Phase -Subreason 'enumeration'
        }
    }

    $script:scriptBlockTestCandidateHelperEntryPresent = {
        param (
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [string[]]$EntryList,

            [Parameter(Mandatory = $true)]
            [string]$ExpectedPath
        )

        $intMatches = 0
        foreach ($strEntry in $EntryList) {
            if ([System.String]::Equals(
                    $strEntry,
                    $ExpectedPath,
                    $script:objCandidateHelperPathComparison
                )) {
                $intMatches++
            }
        }
        return $intMatches -eq 1
    }

    # The only way production obtains the download path. The rule it applies is the
    # same canonical stored-path rule the journal uses -- restating it here is what
    # went wrong once already -- but it is applied where the name is adopted, and it
    # is applied by producing the value rather than by inspecting one that already
    # exists. A caller cannot hold an unvalidated download path, because there is
    # nowhere else for one to come from.
    $script:scriptBlockGetCandidateHelperValidatedDownloadPath = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$Candidate
        )

        try {
            [void](& $script:scriptBlockAssertCandidateHelperCanonicalStoredPath -Value $Candidate)
        } catch {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'download-invalid' -Phase 'download' -Subreason 'entry-name'
        }
        return [string]$Candidate
    }

    # The only way production obtains a ZipArchive. The bound and the construction
    # used to be adjacent statements, and their order was the whole protection: the
    # End of Central Directory record carries the entry count, so an oversized
    # archive can be refused before ZipArchive parses anything, and ZipArchive.Entries
    # builds one object per central-directory record the moment it is touched --
    # measured at 150000 objects and 50.00 MiB of managed heap on .NET 8 and
    # 52.61 MiB on .NET 10, from an archive of 12.66 MiB, well inside the 32 MiB
    # ceiling.
    #
    # Adjacency is not a guarantee. Moving the bound to just after the first Entries
    # access left every assertion in the harness satisfied -- honest archive
    # accepted, poisoned copy rejected, hostile fixtures still refused by the guard
    # -- while the resource bound it exists to provide was gone, and the Zip64
    # trailer bypass it stops is live on .NET 10 today. So the two are folded: an
    # archive cannot be returned from here without having been bounded, and there is
    # no other constructor for callers to reach.
    $script:scriptBlockOpenCandidateHelperValidatedArchive = {
        param (
            [Parameter(Mandatory = $true)]
            [System.IO.Stream]$Buffer
        )

        [void](& $script:scriptBlockAssertCandidateHelperArchiveEntryCount -Stream $Buffer)

        $Buffer.Position = 0
        Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        } catch {
            if (-not ('System.IO.Compression.ZipArchive' -as [type])) {
                throw
            }
        }
        try {
            return (New-Object System.IO.Compression.ZipArchive(
                    $Buffer,
                    [System.IO.Compression.ZipArchiveMode]::Read,
                    $true
                ))
        } catch {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'archive-invalid' -Phase 'archive' -Subreason 'zip-open'
        }
    }

    $script:scriptBlockAssertCandidateHelperArchiveEntryCount = {
        param (
            [Parameter(Mandatory = $true)]
            [System.IO.Stream]$Stream
        )

        # Locate the End of Central Directory record by scanning backwards for its
        # signature, then read the total-entry field. The record is at most 22 bytes
        # plus a comment of at most 65535, so the search window is bounded and no
        # ZIP structure is materialized to do it. A Zip64 locator or an unreadable
        # record is refused rather than guessed at.
        $intMaximumTrailer = 22 + 65535
        $lngLength = $Stream.Length
        $intWindow = [int][System.Math]::Min([int64]$intMaximumTrailer, $lngLength)
        if ($intWindow -lt 22) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'archive-invalid' -Phase 'archive' -Subreason 'zip-open'
        }
        $Stream.Position = $lngLength - $intWindow
        $arrTrailer = New-Object byte[] $intWindow
        $intFilled = 0
        while ($intFilled -lt $intWindow) {
            $intRead = $Stream.Read($arrTrailer, $intFilled, $intWindow - $intFilled)
            if ($intRead -le 0) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'archive-invalid' -Phase 'archive' -Subreason 'zip-open'
            }
            $intFilled += $intRead
        }
        # The signature alone does not identify the trailer, and neither does the
        # comment length a candidate declares for itself: for any position in the
        # window a crafted comment can declare the one length that reaches the end
        # of the file, so filtering on it removes nothing an attacker would choose.
        # The only property that matters is agreeing with the reader that parses
        # this same stream a few lines later. System.IO.Compression seeks to 18
        # bytes before the end and takes the LAST occurrence of the signature at or
        # before length-22, searching at most 65539 further bytes, then commits to
        # it with no validation and no second attempt -- the same rule on .NET
        # Framework 4.8 and on .NET 8. So the trailer is that occurrence, and a
        # candidate that fails validation is refused rather than scanned past:
        # continuing would validate a record the reader is never going to read, and
        # a file whose highest signature is a decoy would pass this check while the
        # reader builds the directory the decoy points at.
        $intSignatureIndex = -1
        for ($intIndex = $intWindow - 22; $intIndex -ge 0; $intIndex--) {
            if ($arrTrailer[$intIndex] -eq 0x50 -and $arrTrailer[$intIndex + 1] -eq 0x4B -and
                $arrTrailer[$intIndex + 2] -eq 0x05 -and $arrTrailer[$intIndex + 3] -eq 0x06) {
                $intSignatureIndex = $intIndex
                break
            }
        }
        if ($intSignatureIndex -lt 0) {
            # A retained EOCD signature too close to EOF to hold its fixed fields
            # is positive evidence of truncation. Inspect only the already bounded
            # trailer buffer; never search past a chosen trailer for acceptance.
            $strTrailerReason = 'invalid-zip'
            for ($intIndex = $intWindow - 4; $intIndex -gt ($intWindow - 22); $intIndex--) {
                if ($arrTrailer[$intIndex] -eq 0x50 -and $arrTrailer[$intIndex + 1] -eq 0x4B -and
                    $arrTrailer[$intIndex + 2] -eq 0x05 -and $arrTrailer[$intIndex + 3] -eq 0x06) {
                    $strTrailerReason = 'truncated-zip'
                    break
                }
            }
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'archive-invalid' -Phase 'archive' -Subreason $strTrailerReason
        }
        # A trailer whose declared comment does not reach exactly the end of the
        # file is malformed. Refusing costs no conforming input: the reader takes
        # this same record and reads these same fields either way.
        $lngCommentLength = [int64]$arrTrailer[$intSignatureIndex + 20] -bor
        ([int64]$arrTrailer[$intSignatureIndex + 21] -shl 8)
        if (($intSignatureIndex + 22 + $lngCommentLength) -ne $intWindow) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'archive-invalid' -Phase 'archive' -Subreason 'trailer-decoy'
        }
        # Either disk field at its 16-bit maximum sends the reader looking for a
        # Zip64 locator in the twenty bytes immediately before this record, and a
        # locator found there replaces both the entry count and the directory
        # offset with 64-bit values read from somewhere else in the file. Twenty
        # bytes fit inside a central directory record's comment, so the walk below
        # can land exactly on the trailer while the reader goes on to build a
        # completely different directory. Single-disk archives declare zero in both
        # fields, so requiring that shuts the gate before it opens.
        $intDiskNumber = [int]$arrTrailer[$intSignatureIndex + 4] -bor
        ([int]$arrTrailer[$intSignatureIndex + 5] -shl 8)
        $intDirectoryDisk = [int]$arrTrailer[$intSignatureIndex + 6] -bor
        ([int]$arrTrailer[$intSignatureIndex + 7] -shl 8)
        # Its own subreason, not the shared entry-count one. The downstream record
        # walk also refuses this archive, so sharing a subreason made the catalog row
        # for this gate pass whether or not the gate existed -- coverage that proved
        # nothing. A distinct value is the only thing that separates "the Zip64 gate
        # refused it" from "something later refused it anyway".
        if ($intDiskNumber -ne 0 -or $intDirectoryDisk -ne 0) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'zip64-locator'
        }
        $intDiskEntries = [int]$arrTrailer[$intSignatureIndex + 8] -bor
        ([int]$arrTrailer[$intSignatureIndex + 9] -shl 8)
        $intTotalEntries = [int]$arrTrailer[$intSignatureIndex + 10] -bor
        ([int]$arrTrailer[$intSignatureIndex + 11] -shl 8)
        # The reader refuses a record whose two counts disagree, so a check here
        # keeps this function answering the question the reader will ask.
        if ($intDiskEntries -ne $intTotalEntries) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
        }
        # 0xFFFF means the real count lives in a Zip64 record. The manifest is
        # exactly four entries, so that is refused outright rather than parsed.
        if ($intTotalEntries -gt 4) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
        }

        # The count above is a declared field, and declaring it is free. Patching
        # both count fields to four leaves a central directory of any size intact:
        # the reader walks the records themselves, so it builds every one of them
        # and only then notices the mismatch, which is the whole amplification this
        # function exists to prevent. The count cannot be the bound.
        #
        # What cannot be declared is where the directory physically sits. The
        # trailer position was found by scanning for its signature, so the bytes
        # between the recorded directory start and that position are a real span,
        # and a four-entry directory cannot fill much of it. Bounding the span
        # bounds the work regardless of what any header claims.
        $lngTrailerPosition = $lngLength - $intWindow + $intSignatureIndex
        $lngDirectorySize = [int64]$arrTrailer[$intSignatureIndex + 12] -bor
        ([int64]$arrTrailer[$intSignatureIndex + 13] -shl 8) -bor
        ([int64]$arrTrailer[$intSignatureIndex + 14] -shl 16) -bor
        ([int64]$arrTrailer[$intSignatureIndex + 15] -shl 24)
        $lngDirectoryOffset = [int64]$arrTrailer[$intSignatureIndex + 16] -bor
        ([int64]$arrTrailer[$intSignatureIndex + 17] -shl 8) -bor
        ([int64]$arrTrailer[$intSignatureIndex + 18] -shl 16) -bor
        ([int64]$arrTrailer[$intSignatureIndex + 19] -shl 24)
        # Either field at its maximum is the Zip64 marker, refused here for the
        # same reason the count marker is: this manifest never needs Zip64.
        if ($lngDirectorySize -eq 0xFFFFFFFF -or $lngDirectoryOffset -eq 0xFFFFFFFF) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
        }
        # A directory that does not start before the trailer and end exactly at it
        # is not describing this archive.
        if ($lngDirectoryOffset -lt 0 -or $lngDirectorySize -lt 0 -or
            $lngDirectoryOffset -gt $lngTrailerPosition -or
            ($lngDirectoryOffset + $lngDirectorySize) -ne $lngTrailerPosition) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
        }
        # Count the records instead of capping the bytes they occupy. A byte cap is
        # a proxy for the count, and the wrong one: entry comments and extra fields
        # are legal and unbounded, so four entries carrying a kilobyte of comment
        # each fill more than four kilobytes of directory while still materializing
        # exactly four entries. Rejecting that is a rejection of valid input.
        #
        # Walking the records answers the real question and stays bounded while
        # doing it. Only the fixed 46-byte head of each record is read, five times
        # at most; the name, extra field, and comment are stepped over by moving
        # the stream position, never by reading them. A fifth record proves the
        # archive holds more than the manifest allows, whatever any field claims.
        $lngPosition = $lngDirectoryOffset
        $arrRecordHead = New-Object byte[] 46
        $intRecordCount = 0
        while ($lngPosition -lt $lngTrailerPosition -and $intRecordCount -le 4) {
            # A record head is 46 bytes, except the optional digital-signature
            # record, whose head is 6. Read what is available up to 46 so the short
            # record can be recognized, and require at least its 6 bytes.
            $lngAvailable = $lngTrailerPosition - $lngPosition
            if ($lngAvailable -lt 6) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
            }
            $intHeadWanted = [int][System.Math]::Min([int64]46, $lngAvailable)
            $Stream.Position = $lngPosition
            $intHeadFilled = 0
            while ($intHeadFilled -lt $intHeadWanted) {
                $intHeadRead = $Stream.Read(
                    $arrRecordHead, $intHeadFilled, $intHeadWanted - $intHeadFilled)
                if ($intHeadRead -le 0) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
                }
                $intHeadFilled += $intHeadRead
            }
            # A central directory may legally end with a digital-signature record.
            # It creates no entry and cannot weaken the four-entry bound, so
            # treating its signature as a fifth file header would reject an archive
            # that is valid and within the manifest. Skip it by its own declared
            # length, count nothing for it, and let the exact-landing check below
            # confirm it accounted for the rest of the span.
            if ($arrRecordHead[0] -eq 0x50 -and $arrRecordHead[1] -eq 0x4B -and
                $arrRecordHead[2] -eq 0x05 -and $arrRecordHead[3] -eq 0x05) {
                # There is one digital-signature record and it is the last thing in
                # the central directory, so skipping it must land on the trailer.
                # Requiring that is what bounds this loop. Counting nothing for the
                # record means the four-entry limit cannot end the walk, and a
                # header declaring a zero-length signature costs only six bytes, so
                # without this a directory packed with them buys an iteration per
                # six bytes -- an archive at the size ceiling would spend tens of
                # seconds here and still be accepted, since the walk lands exactly
                # where it should. Landing correctly bounds the answer, not the
                # work.
                $lngSignatureLength = [int64]$arrRecordHead[4] -bor
                ([int64]$arrRecordHead[5] -shl 8)
                if (($lngPosition + 6 + $lngSignatureLength) -ne $lngTrailerPosition) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
                }
                $lngPosition = $lngTrailerPosition
                continue
            }
            # Anything that is not the signature record must be a full file header.
            if ($intHeadWanted -lt 46) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
            }
            if ($arrRecordHead[0] -ne 0x50 -or $arrRecordHead[1] -ne 0x4B -or
                $arrRecordHead[2] -ne 0x01 -or $arrRecordHead[3] -ne 0x02) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
            }
            $intRecordCount++
            if ($intRecordCount -gt 4) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
            }
            $lngNameLength = [int64]$arrRecordHead[28] -bor ([int64]$arrRecordHead[29] -shl 8)
            $lngExtraLength = [int64]$arrRecordHead[30] -bor ([int64]$arrRecordHead[31] -shl 8)
            $lngCommentLength = [int64]$arrRecordHead[32] -bor ([int64]$arrRecordHead[33] -shl 8)
            $lngPosition = $lngPosition + 46 + $lngNameLength + $lngExtraLength + $lngCommentLength
        }
        # The walk must land exactly on the trailer. Stopping short means a record
        # was mis-sized; overshooting means one claimed more than the directory holds.
        if ($lngPosition -ne $lngTrailerPosition) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
        }
    }

    # This diagnostic classifier runs only after the existing bounded preflight
    # passed and the reader refused to materialize entries. It never admits an
    # archive or replaces that preflight. Ambiguous metadata keeps entry-count.
    $script:scriptBlockTestCandidateHelperNegativeZip64Length = {
        param ([byte[]]$ArchiveByte)

        if ($null -eq $ArchiveByte -or $ArchiveByte.Length -lt 22 -or
            [uint64]$ArchiveByte.Length -gt $script:uintCandidateHelperMaximumArchiveByte) { return $false }
        $intEnd = -1
        $intMinimum = if ($ArchiveByte.Length -gt 65557) { $ArchiveByte.Length - 65557 } else { 0 }
        for ($intIndex = $ArchiveByte.Length - 22; $intIndex -ge $intMinimum; $intIndex--) {
            if ($ArchiveByte[$intIndex] -eq 0x50 -and $ArchiveByte[$intIndex + 1] -eq 0x4B -and
                $ArchiveByte[$intIndex + 2] -eq 0x05 -and $ArchiveByte[$intIndex + 3] -eq 0x06) {
                $intEnd = $intIndex
                break
            }
        }
        if ($intEnd -lt 0 -or $ArchiveByte[$intEnd + 4] -ne 0 -or $ArchiveByte[$intEnd + 5] -ne 0 -or
            $ArchiveByte[$intEnd + 6] -ne 0 -or $ArchiveByte[$intEnd + 7] -ne 0 -or
            $ArchiveByte[$intEnd + 8] -ne 4 -or $ArchiveByte[$intEnd + 9] -ne 0 -or
            $ArchiveByte[$intEnd + 10] -ne 4 -or $ArchiveByte[$intEnd + 11] -ne 0) { return $false }
        $intComment = [int]$ArchiveByte[$intEnd + 20] -bor ([int]$ArchiveByte[$intEnd + 21] -shl 8)
        if (($intEnd + 22 + $intComment) -ne $ArchiveByte.Length) { return $false }
        $longCentral = [long]$ArchiveByte[$intEnd + 16] -bor ([long]$ArchiveByte[$intEnd + 17] -shl 8) -bor
            ([long]$ArchiveByte[$intEnd + 18] -shl 16) -bor ([long]$ArchiveByte[$intEnd + 19] -shl 24)
        $longSize = [long]$ArchiveByte[$intEnd + 12] -bor ([long]$ArchiveByte[$intEnd + 13] -shl 8) -bor
            ([long]$ArchiveByte[$intEnd + 14] -shl 16) -bor ([long]$ArchiveByte[$intEnd + 15] -shl 24)
        if ($longCentral -gt $intEnd -or ($longCentral + $longSize) -ne $intEnd) { return $false }
        $intCentral = [int]$longCentral
        $boolNegative = $false
        $objNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
        for ($intEntry = 0; $intEntry -lt 4; $intEntry++) {
            if ($intCentral -gt ($intEnd - 46) -or
                $ArchiveByte[$intCentral] -ne 0x50 -or $ArchiveByte[$intCentral + 1] -ne 0x4B -or
                $ArchiveByte[$intCentral + 2] -ne 0x01 -or $ArchiveByte[$intCentral + 3] -ne 0x02) { return $false }
            $intName = [int]$ArchiveByte[$intCentral + 28] -bor ([int]$ArchiveByte[$intCentral + 29] -shl 8)
            $intExtra = [int]$ArchiveByte[$intCentral + 30] -bor ([int]$ArchiveByte[$intCentral + 31] -shl 8)
            $intEntryComment = [int]$ArchiveByte[$intCentral + 32] -bor ([int]$ArchiveByte[$intCentral + 33] -shl 8)
            $intNext = $intCentral + 46 + $intName + $intExtra + $intEntryComment
            if ($intNext -gt $intEnd -or $intName -lt 1 -or $intName -gt 64) { return $false }
            $strName = $null
            foreach ($strExpectedName in $script:arrCandidateHelperExpectedName) {
                if ($intName -ne $strExpectedName.Length) { continue }
                $boolNameMatches = $true
                for ($intNameByte = 0; $intNameByte -lt $intName; $intNameByte++) {
                    if ($ArchiveByte[$intCentral + 46 + $intNameByte] -ne [int][char]$strExpectedName[$intNameByte]) {
                        $boolNameMatches = $false
                        break
                    }
                }
                if ($boolNameMatches) { $strName = $strExpectedName; break }
            }
            if ($null -eq $strName -or -not $objNames.Add($strName)) { return $false }
            $boolLengthMarker = $ArchiveByte[$intCentral + 24] -eq 255 -and $ArchiveByte[$intCentral + 25] -eq 255 -and
                $ArchiveByte[$intCentral + 26] -eq 255 -and $ArchiveByte[$intCentral + 27] -eq 255
            $intRequiredZip64 = if ($boolLengthMarker) { 8 } else { 0 }
            if ($ArchiveByte[$intCentral + 20] -eq 255 -and $ArchiveByte[$intCentral + 21] -eq 255 -and
                $ArchiveByte[$intCentral + 22] -eq 255 -and $ArchiveByte[$intCentral + 23] -eq 255) { $intRequiredZip64 += 8 }
            if ($ArchiveByte[$intCentral + 42] -eq 255 -and $ArchiveByte[$intCentral + 43] -eq 255 -and
                $ArchiveByte[$intCentral + 44] -eq 255 -and $ArchiveByte[$intCentral + 45] -eq 255) { $intRequiredZip64 += 8 }
            if ($ArchiveByte[$intCentral + 34] -eq 255 -and $ArchiveByte[$intCentral + 35] -eq 255) { $intRequiredZip64 += 4 }
            $intField = $intCentral + 46 + $intName
            $intExtraEnd = $intField + $intExtra
            $intZip64Count = 0
            # The uint16 extra span is at most 65535 bytes, and each iteration
            # consumes at least its four-byte field header. No payload is read.
            while ($intField -lt $intExtraEnd) {
                if ($intField -gt ($intExtraEnd - 4)) { return $false }
                $intFieldId = [int]$ArchiveByte[$intField] -bor ([int]$ArchiveByte[$intField + 1] -shl 8)
                $intFieldLength = [int]$ArchiveByte[$intField + 2] -bor ([int]$ArchiveByte[$intField + 3] -shl 8)
                $intData = $intField + 4
                if ($intFieldLength -gt ($intExtraEnd - $intData)) { return $false }
                if ($intFieldId -eq 1) {
                    $intZip64Count++
                    if ($intZip64Count -ne 1 -or $intRequiredZip64 -eq 0 -or $intFieldLength -ne $intRequiredZip64) { return $false }
                    if ($boolLengthMarker -and $ArchiveByte[$intData + 7] -ge 128) { $boolNegative = $true }
                }
                $intField = $intData + $intFieldLength
            }
            if ($intRequiredZip64 -gt 0 -and $intZip64Count -ne 1) { return $false }
            $intCentral = $intNext
        }
        return $boolNegative -and $intCentral -eq $intEnd
    }


    $script:scriptBlockExpandCandidateHelperMountField = {
        param (
            [Parameter(Mandatory = $true)]
            [AllowEmptyString()]
            [string]$Value
        )

        # mountinfo escapes space, tab, newline, and backslash as three octal
        # digits. Decoded in one pass so an already-decoded backslash cannot be
        # re-read as the start of another escape.
        $objBuilder = New-Object System.Text.StringBuilder
        for ($intIndex = 0; $intIndex -lt $Value.Length; $intIndex++) {
            if ($Value[$intIndex] -eq '\' -and ($intIndex + 3) -lt $Value.Length) {
                $strOctal = $Value.Substring($intIndex + 1, 3)
                if ($strOctal -cmatch '^[0-7]{3}$') {
                    [void]$objBuilder.Append([char][System.Convert]::ToInt32($strOctal, 8))
                    $intIndex += 3
                    continue
                }
            }
            [void]$objBuilder.Append($Value[$intIndex])
        }
        return $objBuilder.ToString()
    }

    $script:scriptBlockTestCandidateHelperPathPrefix = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$Prefix,

            [Parameter(Mandatory = $true)]
            [string]$Path
        )

        if ($Prefix -ceq '/') {
            return $true
        }
        if (-not $Path.StartsWith($Prefix, [System.StringComparison]::Ordinal)) {
            return $false
        }
        return ($Path.Length -eq $Prefix.Length -or $Path[$Prefix.Length] -eq '/')
    }

    $script:scriptBlockGetCandidateHelperMountResolvedPath = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$LiteralPath
        )

        # A bind mount makes lexical ancestry lie. With /b bound from /a/sub,
        # everything created below /b is physically inside /a, yet walking /b's
        # parents never reaches /a and the two directories have different inodes,
        # so neither the path text nor the identity chain can see the relationship.
        # Mount topology is the only place it is recorded, so each root is resolved
        # to the device and in-filesystem subtree it actually occupies.
        if ($script:boolCandidateHelperIsWindows) {
            return $null
        }
        try {
            $arrMountLines = [string[]]@(
                [System.IO.File]::ReadAllLines('/proc/self/mountinfo')
            )
        } catch {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'root-invalid' -Phase 'root' -Subreason 'mount'
        }
        # Parse first, decide second. Line order in mountinfo does not track
        # visibility: MS_MOVE can place the visible record before the one it
        # hides, so picking the later line can select a hidden filesystem root.
        $listCandidate = New-Object 'System.Collections.Generic.List[PSCustomObject]'
        $objParentIdentifiers = New-Object 'System.Collections.Generic.HashSet[string]' (
            [System.StringComparer]::Ordinal
        )
        foreach ($strLine in $arrMountLines) {
            $arrFields = $strLine.Split(' ')
            if ($arrFields.Count -lt 5) {
                continue
            }
            $strMountPoint = & $script:scriptBlockExpandCandidateHelperMountField -Value $arrFields[4]
            if (-not (& $script:scriptBlockTestCandidateHelperPathPrefix `
                        -Prefix $strMountPoint -Path $LiteralPath)) {
                continue
            }
            $listCandidate.Add([pscustomobject][ordered]@{
                    MountId = [string]$arrFields[0]
                    ParentId = [string]$arrFields[1]
                    Device = & $script:scriptBlockExpandCandidateHelperMountField -Value $arrFields[2]
                    FsRoot = & $script:scriptBlockExpandCandidateHelperMountField -Value $arrFields[3]
                    MountPoint = $strMountPoint
                })
        }
        $intLongest = -1
        foreach ($objCandidate in $listCandidate) {
            if ($objCandidate.MountPoint.Length -gt $intLongest) {
                $intLongest = $objCandidate.MountPoint.Length
            }
        }
        # Only the deepest mount point can govern this path. Within that group,
        # mounting B over A records B.ParentId as A.MountId, so the visible mount
        # is the one no sibling at the same point claims as its parent.
        foreach ($objCandidate in $listCandidate) {
            if ($objCandidate.MountPoint.Length -eq $intLongest) {
                [void]$objParentIdentifiers.Add($objCandidate.ParentId)
            }
        }
        $strBestMountPoint = $null
        $strBestDevice = $null
        $strBestFsRoot = $null
        $intVisibleCount = 0
        foreach ($objCandidate in $listCandidate) {
            if ($objCandidate.MountPoint.Length -ne $intLongest) {
                continue
            }
            if ($objParentIdentifiers.Contains($objCandidate.MountId)) {
                continue
            }
            $intVisibleCount++
            $strBestMountPoint = $objCandidate.MountPoint
            $strBestDevice = $objCandidate.Device
            $strBestFsRoot = $objCandidate.FsRoot
        }
        # Exactly one record in the group must be unclaimed. Anything else means
        # the topology was not understood, which fails closed rather than guessing.
        if ($intVisibleCount -ne 1) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'root-invalid' -Phase 'root' -Subreason 'mount'
        }
        if ($null -eq $strBestMountPoint) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'root-invalid' -Phase 'root' -Subreason 'mount'
        }
        $strRelative = if ($strBestMountPoint -ceq '/') {
            $LiteralPath
        } else {
            $LiteralPath.Substring($strBestMountPoint.Length)
        }
        $strTruePath = if ($strBestFsRoot -ceq '/') {
            $strRelative
        } else {
            $strBestFsRoot + $strRelative
        }
        if ($strTruePath.Length -eq 0) {
            $strTruePath = '/'
        }
        return [string[]]@($strBestDevice, $strTruePath)
    }

    $script:scriptBlockGetCandidateHelperIdentityChain = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$LiteralPath
        )

        # Lexical comparison cannot see two spellings that name the same directory,
        # such as a same-filesystem bind alias, and device alone cannot either
        # because an alias shares it. Inode is what separates them. The chain holds
        # every ancestor identity, so an alias of an ancestor is caught as well as
        # an alias of the path itself.
        #
        # The caller compares one chain against the head of the other, so what the
        # entries mean is this function's business alone: they only have to be
        # equal when, and only when, they name the same directory. Each platform
        # picks the strongest identity it can express.
        $listIdentity = New-Object 'System.Collections.Generic.List[string]'
        if ($script:boolCandidateHelperIsWindows) {
            # Windows has its own aliasing that carries no reparse point and no
            # tilde to look for: a volume with 8.3 names enabled answers to a short
            # alias for any component, so C:\work\REPOSI~1\temp and
            # C:\work\Repository\temp are the same directory spelled two ways and
            # every lexical test passes. Screening for the alias by shape is ruled
            # out at the source: GetLongPathName's documentation states that not
            # all file systems put a tilde in a short name, and that the call must
            # not be skipped on that basis.
            #
            # The identity used here is the canonical spelling. Each component is
            # resolved by asking its parent for the entry of that name; the
            # directory query matches a short alias and answers with the name as
            # stored, so both spellings converge on one string. This is the
            # component-by-component resolution the same documentation names as
            # the alternative where GetLongPathName is unavailable, and it needs no
            # P/Invoke, no compiler, and no elevation.
            #
            # The component read goes through the shared enumeration helper rather
            # than calling the framework directly. An earlier revision called
            # Directory.EnumerateDirectories here, which put the read outside every
            # bound this script maintains: the pinned site table matches calls to
            # the helper, so a static framework call is not merely unpinned but
            # invisible to it. Measured -- rewriting this read to list the whole
            # parent and post-filter in the pipeline left the suite green at 113
            # passes and zero failures, reinstating the unbounded per-ancestor read
            # that rounds 15 through 17 removed everywhere else.
            #
            # Routing it here buys the run-time guard as well as the static one. The
            # component is a search pattern, and only '*' and '?' expand in the
            # two-argument overload; a parent holding exactly one subdirectory
            # answers a '*' component with Count 1, so the check below passes and
            # the canonical spelling names a DIFFERENT directory than the one asked
            # about -- a wrong identity rather than a refusal. Every path parameter
            # reaching this function is wildcard-checked on the way in, so that is
            # unreachable today, but it was true only by a claim about callers. The
            # helper refuses the leaf itself, which is a property of this read.
            $listWindowsComponent = New-Object 'System.Collections.Generic.List[string]'
            $objWalk = New-Object System.IO.DirectoryInfo($LiteralPath)
            while ($null -ne $objWalk.Parent) {
                $listWindowsComponent.Add([string]$objWalk.Name)
                $objWalk = $objWalk.Parent
            }
            $strCanonical = [string]$objWalk.FullName
            for ($intComponent = $listWindowsComponent.Count - 1; $intComponent -ge 0; $intComponent--) {
                $strComponentName = [string]$listWindowsComponent[$intComponent]
                $arrMatch = @(& $script:scriptBlockGetCandidateHelperEntry `
                        -LiteralPath $strCanonical -Phase 'root' `
                        -MatchPath $strComponentName)
                if ($arrMatch.Count -ne 1) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'root-invalid' -Phase 'root' -Subreason 'identity'
                }
                $strCanonical = [string]$arrMatch[0]
            }
            # Deepest first, so entry zero is this path's own identity and the rest
            # are its ancestors, matching what the caller reads on every platform.
            $objEmit = New-Object System.IO.DirectoryInfo($strCanonical)
            while ($null -ne $objEmit) {
                $listIdentity.Add([string]$objEmit.FullName)
                $objEmit = $objEmit.Parent
            }
            return , [string[]]$listIdentity.ToArray()
        }
        $strStatPath = [string](& $script:scriptBlockResolveCandidateHelperNativePath `
                -CandidatePath $script:arrCandidateHelperStatPath)
        if ($strStatPath.Length -eq 0) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'root-invalid' -Phase 'root' -Subreason 'identity'
        }
        $objCurrent = New-Object System.IO.DirectoryInfo($LiteralPath)
        while ($null -ne $objCurrent) {
            $arrStatus = @(& $strStatPath '-Lc' '%d:%i' '--' $objCurrent.FullName 2>$null)
            if ($LASTEXITCODE -ne 0 -or $arrStatus.Count -ne 1 -or
                $arrStatus[0] -notmatch '^[0-9]+:[0-9]+$') {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'root-invalid' -Phase 'root' -Subreason 'identity'
            }
            $listIdentity.Add([string]$arrStatus[0])
            $objCurrent = $objCurrent.Parent
        }
        # The unary comma keeps a single-element chain an array.
        return , [string[]]$listIdentity.ToArray()
    }

    # One directory's own identity, without its ancestors. The chain helper above
    # answers a different and more expensive question: it walks to the volume root
    # so an aliased ANCESTOR is caught, which is what root separation needs. Asking
    # it repeatedly inside the extraction loop cost a stat process per component per
    # call and measured 376 ms to 643 ms per expansion on .NET 8 and 348 ms to
    # 648 ms on .NET 10 -- most of that spent re-answering a question already
    # settled before the loop began. What changes during extraction is the leaf
    # itself, so that is what is re-asked here, once per probe.
    #
    # Linux uses stat with -L deliberately: the flag follows the link, so a name
    # replaced by a symbolic link answers with the TARGET's device and inode and
    # therefore mismatches. Windows uses the canonical spelling of the leaf as
    # resolved by its parent, the same identity the chain helper uses per component.
    $script:scriptBlockGetCandidateHelperEntryIdentity = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$LiteralPath,

            [Parameter(Mandatory = $true)]
            [string]$Phase
        )

        # Link-ness first, and on both platforms, because on Windows the identity
        # below cannot express it. EnumerateDirectories lists a reparse point as an
        # ordinary directory entry and answers with the same stored path whether or
        # not the name is a link, so a canonical-spelling comparison returns an
        # identical string before and after a competing writer swaps the directory
        # for a symlink or junction -- and every path-based create then follows it.
        # An earlier revision replaced the per-write envelope check with that
        # comparison alone in the name of cost, which detected the swap on Linux,
        # where stat -L reports the target's inode, and detected nothing at all on
        # Windows. Measuring one platform and inferring the other is what made that
        # look finished.
        #
        # A candidate directory is never legitimately a link, so this refuses rather
        # than describes, and the attributes join the identity as well: a swap that
        # somehow preserved the spelling still changes the value being compared.
        try {
            $objIdentityAttributes = [System.IO.File]::GetAttributes($LiteralPath)
        } catch {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code "$Phase-invalid" -Phase $Phase -Subreason 'identity'
        }
        if (($objIdentityAttributes -band [System.IO.FileAttributes]::Directory) -eq 0 -or
            ($objIdentityAttributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code "$Phase-invalid" -Phase $Phase -Subreason 'nonordinary-directory'
        }
        $strIdentityAttributes = '|' + ([int]$objIdentityAttributes).ToString(
            [System.Globalization.CultureInfo]::InvariantCulture)

        if ($script:boolCandidateHelperIsWindows) {
            $objEntry = New-Object System.IO.DirectoryInfo($LiteralPath)
            if ($null -eq $objEntry.Parent) {
                return ([string]$objEntry.FullName + $strIdentityAttributes)
            }
            # Through the shared helper for the same reason the chain walk above is:
            # a direct framework call is outside the pinned site table and outside
            # the bounded-or-filtered rule the table encodes. The attribute read
            # above has already established that this leaf is an ordinary directory,
            # so listing entries rather than directories cannot widen what matches
            # -- a file and a directory of one name cannot share a parent -- and the
            # exact-count check below is unchanged.
            $strEntryParent = [string]$objEntry.Parent.FullName
            $strEntryName = [string]$objEntry.Name
            $arrMatch = @(& $script:scriptBlockGetCandidateHelperEntry `
                    -LiteralPath $strEntryParent -Phase $Phase `
                    -MatchPath $strEntryName)
            if ($arrMatch.Count -ne 1) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code "$Phase-invalid" -Phase $Phase -Subreason 'identity'
            }
            return ([string]$arrMatch[0] + $strIdentityAttributes)
        }
        $strStatPath = [string](& $script:scriptBlockResolveCandidateHelperNativePath `
                -CandidatePath $script:arrCandidateHelperStatPath)
        if ($strStatPath.Length -eq 0) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code "$Phase-invalid" -Phase $Phase -Subreason 'identity'
        }
        $arrStatus = @(& $strStatPath '-Lc' '%d:%i' '--' $LiteralPath 2>$null)
        if ($LASTEXITCODE -ne 0 -or $arrStatus.Count -ne 1 -or
            $arrStatus[0] -notmatch '^[0-9]+:[0-9]+$') {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code "$Phase-invalid" -Phase $Phase -Subreason 'identity'
        }
        return ([string]$arrStatus[0] + $strIdentityAttributes)
    }

    $script:scriptBlockAssertCandidateHelperDirectoryEnvelope = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$LiteralPath,

            [Parameter(Mandatory = $true)]
            [string]$Phase,

            [ref]$ReferenceToFilesystemCallCount,

            [ValidateSet('none', 'checkout', 'trusted', 'download', 'candidate-parent')]
            [string]$DiagnosticRole = 'none'
        )

        if ($null -ne $ReferenceToFilesystemCallCount) {
            $ReferenceToFilesystemCallCount.Value = [uint32](
                $ReferenceToFilesystemCallCount.Value + 1
            )
        }
        $strFailureCode = if ($Phase -ceq 'cleanup') {
            'cleanup-owned-entry-uncertain'
        } else {
            "$Phase-invalid"
        }
        $listComponents = New-Object 'System.Collections.Generic.List[string]'
        $objCurrent = New-Object System.IO.DirectoryInfo($LiteralPath)
        while ($null -ne $objCurrent) {
            $listComponents.Add($objCurrent.FullName)
            $objCurrent = $objCurrent.Parent
        }
        # Resolve stat as an Application once per envelope check, before the
        # component loop. A bare command name can bind to a function or alias, which
        # never sets $LASTEXITCODE, so the check would read a stale exit code from an
        # earlier native call and pass silently. The resolution is a local, not a
        # $script: cache: this file is both dot-sourced and invoked, so a script-scope
        # cache is not guaranteed to exist in the resolved scope and Set-StrictMode
        # makes reading an unset one throw. Hoisting it out of the loop keeps the
        # lookup off the per-component path.
        $strStatPath = $null
        if (-not $script:boolCandidateHelperIsWindows) {
            $strStatPath = [string](& $script:scriptBlockResolveCandidateHelperNativePath `
                    -CandidatePath $script:arrCandidateHelperStatPath)
            if ($strStatPath.Length -eq 0) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code $strFailureCode -Phase $Phase -Subreason 'identity'
            }
        }
        $strPreviousDevice = $null
        for ($intIndex = $listComponents.Count - 1; $intIndex -ge 0; $intIndex--) {
            $strComponent = $listComponents[$intIndex]
            try {
                $objAttributes = [System.IO.File]::GetAttributes($strComponent)
            } catch {
                $objUnderlyingFailure = $_.Exception.GetBaseException()
                if ($DiagnosticRole -cne 'none' -and
                    ($objUnderlyingFailure -is [System.IO.FileNotFoundException] -or
                    $objUnderlyingFailure -is [System.IO.DirectoryNotFoundException])) {
                    $strMissingPhase = switch ($DiagnosticRole) {
                        'download' { 'download' }
                        'candidate-parent' { 'destination' }
                        default { 'root' }
                    }
                    $strMissingReason = switch ($DiagnosticRole) {
                        'download' { 'directory-missing' }
                        'candidate-parent' { 'parent-missing' }
                        default { "$DiagnosticRole-missing" }
                    }
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code "$strMissingPhase-invalid" -Phase $strMissingPhase -Subreason $strMissingReason
                }
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code $strFailureCode -Phase $Phase -Subreason 'attribute'
            }
            if ($DiagnosticRole -cne 'none' -and
                ($objAttributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                $strReparsePhase = if ($DiagnosticRole -in @('checkout', 'trusted')) { 'root' } else { 'containment' }
                $strReparseReason = if ($strReparsePhase -ceq 'containment') {
                    'component-reparse'
                } elseif ($intIndex -eq 0) {
                    'root-reparse'
                } else {
                    'ancestor-reparse'
                }
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code "$strReparsePhase-invalid" -Phase $strReparsePhase -Subreason $strReparseReason
            }
            if ($DiagnosticRole -cne 'none' -and
                ($objAttributes -band [System.IO.FileAttributes]::Directory) -eq 0) {
                $strDirectoryPhase = switch ($DiagnosticRole) {
                    'download' { 'download' }
                    'candidate-parent' { 'destination' }
                    default { 'root' }
                }
                $strDirectoryReason = switch ($DiagnosticRole) {
                    'download' { 'not-directory' }
                    'candidate-parent' { 'parent-not-directory' }
                    default { "$DiagnosticRole-not-directory" }
                }
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code "$strDirectoryPhase-invalid" -Phase $strDirectoryPhase -Subreason $strDirectoryReason
            }
            if (($objAttributes -band [System.IO.FileAttributes]::Directory) -eq 0 -or
                ($objAttributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code $strFailureCode -Phase $Phase -Subreason 'nonordinary-directory'
            }
            if (-not $script:boolCandidateHelperIsWindows) {
                $arrFileSystemStatus = @(& $strStatPath '-Lc' '%d' '--' $strComponent 2>$null)
                $intFileSystemStatusExitCode = $LASTEXITCODE
                if ($intFileSystemStatusExitCode -ne 0 -or
                    $arrFileSystemStatus.Count -ne 1 -or
                    $arrFileSystemStatus[0] -notmatch '^[0-9]+$') {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code $strFailureCode -Phase $Phase -Subreason 'identity'
                }
                if ($null -ne $strPreviousDevice -and
                    $arrFileSystemStatus[0] -cne $strPreviousDevice) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code $strFailureCode -Phase $Phase -Subreason 'mount'
                }
                $strPreviousDevice = [string]$arrFileSystemStatus[0]
            }
        }
    }

    $script:scriptBlockGetCandidateHelperFileEvidence = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$LiteralPath,

            [Parameter(Mandatory = $true)]
            [string]$Phase,

            [Parameter(Mandatory = $true)]
            [uint64]$ExpectedLength,

            [ref]$ReferenceToFilesystemCallCount
        )

        $strFailureCode = if ($Phase -ceq 'cleanup') {
            'cleanup-owned-entry-uncertain'
        } else {
            "$Phase-invalid"
        }
        try {
            if ($null -ne $ReferenceToFilesystemCallCount) {
                $ReferenceToFilesystemCallCount.Value = [uint32]($ReferenceToFilesystemCallCount.Value + 1)
            }
            & $script:scriptBlockAssertCandidateHelperOrdinaryRegularFile `
                -LiteralPath $LiteralPath
            if ($null -ne $ReferenceToFilesystemCallCount) {
                $ReferenceToFilesystemCallCount.Value = [uint32]($ReferenceToFilesystemCallCount.Value + 1)
            }
            $objStream = New-Object System.IO.FileStream(
                $LiteralPath,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::Read
            )
            try {
                # The proof above is about a NAME; this is about the object that was
                # actually opened. A regular file is seekable and a pipe, socket or
                # device is not, so a non-regular object is refused explicitly here
                # rather than being noticed when Length happens to throw. An
                # incidental stop is not a stop -- the same lesson the archive
                # trailer guard already carries.
                #
                # This does not close the window between the proof and the open. A
                # name proven regular can be replaced first, and a FIFO put in its
                # place blocks the open before any check reaches it. Closing that
                # needs a non-blocking or no-follow open, which portable .NET does
                # not expose -- FileOptions offers WriteThrough, Asynchronous,
                # RandomAccess, DeleteOnClose, SequentialScan and Encrypted, none of
                # them O_NONBLOCK. Opening read-write does avoid the block, measured
                # at 5 ms against a FIFO, but it refuses a legitimate read-only
                # artifact: measured as an unprivileged user, a 0444 regular file
                # opened read-write threw where read-only succeeded. Trading a hang
                # for a false rejection is the round-19 defect, so it was not taken.
                #
                # The window needs a writer able to reach this path, and the
                # invocation root is created private to this process or not created
                # at all -- the context manager applies an owner-only mode on Unix
                # and an owner-only protected DACL on Windows, and refuses when it
                # can do neither. That excludes a different unprivileged user GIVEN
                # a parent they cannot write. Measured on Linux, a 0700 root under a
                # world-writable parent WITHOUT the sticky bit was renamed away by
                # another unprivileged user, who then put a FIFO at the original
                # path; the sticky bit refused the same rename. The parent is the
                # caller's TrustedTemporaryRoot and neither script reads its mode,
                # so that clause is a warranty rather than a finding. What remains
                # is the same user or root -- the competing untrusted writer #146
                # lists as a non-goal, and the same actor the extraction race is
                # documented against.
                if (-not $objStream.CanRead -or -not $objStream.CanSeek) {
                    throw 'nonordinary'
                }
                $uintLength = [uint64]$objStream.Length
                # The caller compares this length against the journal before it
                # looks at the digest, so a file whose length already disagrees is
                # refused whatever the hash says -- and hashing it first means
                # reading every byte of a file the journal has already failed to
                # describe. A forged record naming a very large file made that read
                # unbounded. The length is decided here instead, and the digest is
                # computed only for a file the journal still might match. The empty
                # string returned in the other case can never equal a 64-character
                # digest, so a caller that skipped the length comparison entirely
                # would still fail closed.
                if ($uintLength -ne $ExpectedLength) {
                    return [ordered]@{
                        Length = $uintLength
                        Sha256 = ''
                    }
                }
                # Exactly the validated number of bytes, and not one more.
                # ComputeHash reads a stream to EOF, and EOF is not where the
                # journal said the file ended -- it is wherever the file happens to
                # end when the read gets there. Measured: a file validated at 1,024
                # bytes, appended to by another writer, had ComputeHash consume
                # 201,327,616 bytes. Worse than the volume, a writer that keeps
                # ahead of the reader moves EOF for as long as it likes, so the read
                # need never finish at all.
                #
                # Hashing the validated prefix is also the more correct answer: the
                # journal describes that many bytes, so that is what the digest
                # should attest. This is the same defect the archive allocation had
                # a round earlier, in a second place, which is what comes of fixing
                # one instance of a class without sweeping for its siblings. The
                # bounded loop below is the idiom this file already uses in three
                # other places.
                $objSha256 = [System.Security.Cryptography.SHA256]::Create()
                try {
                    $arrHashBuffer = New-Object byte[] $script:intCandidateHelperHashBuffer
                    $uintHashRemaining = $uintLength
                    while ($uintHashRemaining -gt 0) {
                        $intHashWanted = if ($uintHashRemaining -lt [uint64]$arrHashBuffer.Length) {
                            [int]$uintHashRemaining
                        } else {
                            $arrHashBuffer.Length
                        }
                        $intHashRead = $objStream.Read($arrHashBuffer, 0, $intHashWanted)
                        if ($intHashRead -le 0) {
                            throw 'truncated'
                        }
                        [void]$objSha256.TransformBlock($arrHashBuffer, 0, $intHashRead, $null, 0)
                        $uintHashRemaining -= [uint64]$intHashRead
                    }
                    [void]$objSha256.TransformFinalBlock((New-Object byte[] 0), 0, 0)
                    # One byte past the validated end. A file that still has more to
                    # give is no longer the file the journal describes, and the
                    # empty digest is the shape the caller already treats as a
                    # mismatch, so no new failure path is needed.
                    if ($objStream.Read($arrHashBuffer, 0, 1) -gt 0) {
                        return [ordered]@{
                            Length = $uintLength
                            Sha256 = ''
                        }
                    }
                    $strSha256 = ([System.BitConverter]::ToString(
                            $objSha256.Hash
                        ) -replace '-', '').ToLowerInvariant()
                } finally {
                    $objSha256.Dispose()
                }
            } finally {
                $objStream.Dispose()
            }
            return [ordered]@{
                Length = $uintLength
                Sha256 = $strSha256
            }
        } catch {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code $strFailureCode -Phase $Phase -Subreason 'file-evidence'
        }
    }

    # Every path this script opens for reading must first be proven an ordinary
    # regular file, and this is the single place that decides it.
    #
    # The attribute test alone does not: measured on .NET 8.0.10 and .NET 10.0.10, a
    # FIFO created with mkfifo reports GetAttributes = Normal (128), carrying
    # neither Directory nor ReparsePoint, and the FileStream constructor then blocks
    # until a writer appears. An untrusted caller who hands back a schema-valid
    # context naming one hangs the run indefinitely.
    #
    # Length does not decide it either, and that is why the download path's rule
    # could not simply be reused here. That rule refuses a length of zero, which is
    # sound there because the ZIP end-of-central-directory record alone is
    # twenty-two bytes -- but an extracted candidate file may legitimately be empty.
    # Measured, both runtimes: a FIFO and a legitimate empty file both report
    # Length 0 without blocking, so length cannot separate them at the evidence
    # sites. Refusing zero there would reject valid input, which is the round-19
    # defect, and it left the invocation root on disk the last time it shipped.
    #
    # GetUnixFileMode looks like the portable answer and is not: measured, it
    # returns permissions only -- OtherRead, GroupRead, UserWrite, UserRead for the
    # FIFO and for the empty file alike -- and it does not exist on 5.1 at all.
    #
    # So the file TYPE is asked for directly, from the same stat this script already
    # resolves for identity. Windows needs no equivalent: named pipes live in the
    # \\.\pipe\ namespace rather than the filesystem, so a journaled path under the
    # invocation root cannot name one, and the attribute test carries that platform.
    $script:scriptBlockAssertCandidateHelperOrdinaryRegularFile = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$LiteralPath
        )

        $objAttributes = [System.IO.File]::GetAttributes($LiteralPath)
        if (($objAttributes -band [System.IO.FileAttributes]::Directory) -ne 0 -or
            ($objAttributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            $objFailure = New-Object System.InvalidOperationException('nonordinary')
            $objFailure.Data['CandidateEntryClassification'] = 'not-file'
            throw $objFailure
        }
        if ($script:boolCandidateHelperIsWindows) {
            return
        }
        $strStatPath = [string](& $script:scriptBlockResolveCandidateHelperNativePath `
                -CandidatePath $script:arrCandidateHelperStatPath)
        if ($strStatPath.Length -eq 0) {
            $objFailure = New-Object System.InvalidOperationException('nonordinary')
            $objFailure.Data['CandidateEntryClassification'] = 'unclassifiable'
            throw $objFailure
        }
        # %f is the raw mode in hex and %F is the file type as PROSE. GNU coreutils
        # translates its messages, so on a runner whose LC_MESSAGES selects an
        # installed translation %F stops equalling any English literal and every
        # valid cleanup is refused as uncertain. That is a false rejection of
        # legitimate input, which is the defect this code has shipped twice before.
        # The numeric form carries no message catalogue at all.
        #
        # Masking with S_IFMT also states the question better than a literal list
        # did: one test covers a regular file whether or not it is empty, where the
        # prose needed both 'regular file' and 'regular empty file' spelled out.
        # Measured on this image -- regular 0x81a4, empty 0x81a4, fifo 0x11a4,
        # symbolic link 0xa1ff, so 0x8000 after masking is exactly the regular case.
        $arrFileMode = @(& $strStatPath '-c' '%f' '--' $LiteralPath 2>$null)
        if ($LASTEXITCODE -ne 0 -or $arrFileMode.Count -ne 1 -or
            [string]$arrFileMode[0] -notmatch '^[0-9A-Fa-f]{1,8}$') {
            $objFailure = New-Object System.InvalidOperationException('nonordinary')
            $objFailure.Data['CandidateEntryClassification'] = 'unclassifiable'
            throw $objFailure
        }
        if (([System.Convert]::ToInt32([string]$arrFileMode[0], 16) -band 0xF000) -ne 0x8000) {
            $objFailure = New-Object System.InvalidOperationException('nonordinary')
            $objFailure.Data['CandidateEntryClassification'] = 'unclassifiable'
            throw $objFailure
        }
    }

    $script:scriptBlockAssertCandidateHelperOrdinaryFileMetadata = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$LiteralPath,

            [Parameter(Mandatory = $true)]
            [string]$Phase
        )

        try {
            & $script:scriptBlockAssertCandidateHelperOrdinaryRegularFile `
                -LiteralPath $LiteralPath
            $objFile = New-Object System.IO.FileInfo($LiteralPath)
            # A named pipe carries no Directory or ReparsePoint attribute and
            # reports a length of zero, so the checks above accept it as an
            # ordinary file -- and opening one for reading blocks until a writer
            # appears, which for an untrusted download entry means the workflow
            # hangs before any archive or resource ceiling is ever consulted.
            #
            # Refusing a zero length closes that without asking an external tool
            # what the entry is: pipes, sockets, and device nodes all report zero,
            # and a regular file of zero bytes cannot be an archive either, because
            # the end-of-central-directory record alone is twenty-two bytes. The
            # size floor already implied by the format is therefore applied here,
            # before the open rather than after it.
            if (-not $objFile.Exists -or $objFile.Length -le 0) {
                throw 'missing'
            }
            return [uint64]$objFile.Length
        } catch {
            $objMetadataFailure = $_.Exception.GetBaseException()
            $strMetadataReason = 'file-metadata'
            if ($Phase -ceq 'download') {
                if ($objMetadataFailure -is [System.IO.FileNotFoundException] -or
                    $objMetadataFailure -is [System.IO.DirectoryNotFoundException]) {
                    $strMetadataReason = 'archive-missing'
                } elseif ($objMetadataFailure.Data['CandidateEntryClassification'] -ceq 'not-file') {
                    $strMetadataReason = 'archive-not-file'
                } elseif ($objMetadataFailure.Data['CandidateEntryClassification'] -ceq 'unclassifiable') {
                    $strMetadataReason = 'entry-unclassifiable'
                }
            }
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code "$Phase-invalid" -Phase $Phase -Subreason $strMetadataReason
        }
    }

    # Issued references and snapshots stay in the private module, as the source
    # context manager's registers stay in captured closures. They are not public
    # object properties. Deliberate module-state reflection is not a process
    # privilege boundary; ordinary clones and mutable ownership claims are refused.
    $script:arrCandidateStateRegistration = New-Object 'System.Collections.Generic.List[pscustomobject]'
    $script:scriptBlockAssertCandidateOwnershipEnvelope = {
        param ([string]$TrustedRoot, [string]$CandidateParent, [string]$CandidatePath)

        # These are already normalized native paths captured at issuance. This
        # defensive relationship check performs no provider, path API or I/O call.
        $chrSeparator = if ($script:boolCandidateHelperIsWindows) { [char]'\' } else { [char]'/' }
        $strRootPrefix = $TrustedRoot.TrimEnd($chrSeparator) + $chrSeparator
        $strParentPrefix = $CandidateParent.TrimEnd($chrSeparator) + $chrSeparator
        if (-not $CandidateParent.StartsWith($strRootPrefix, $script:objCandidateHelperPathComparison) -or
            -not $CandidatePath.StartsWith($strParentPrefix, $script:objCandidateHelperPathComparison) -or
            $CandidatePath.Length -le $strParentPrefix.Length) {
            throw 'candidate-state-invalid'
        }
        $strLeaf = $CandidatePath.Substring($strParentPrefix.Length)
        if ($strLeaf.Contains([string]$chrSeparator) -or
            ($script:boolCandidateHelperIsWindows -and $strLeaf.Contains('/')) -or
            $strLeaf -in @('.', '..')) {
            throw 'candidate-state-invalid'
        }
    }

    $script:scriptBlockNewCandidateOwnershipState = {
        param (
            [string]$TrustedRoot,
            [string]$CandidateParent,
            [string]$CandidatePath
        )

        [void](& $script:scriptBlockAssertCandidateOwnershipEnvelope `
                -TrustedRoot $TrustedRoot -CandidateParent $CandidateParent -CandidatePath $CandidatePath)
        $guidCandidateId = [guid]::NewGuid()
        $arrJournal = [object[]]@()
        $objState = [pscustomobject][ordered]@{
            SchemaVersion = [uint32]1
            CandidateId = $guidCandidateId
            LifecycleState = [string]'NotCreated'
            TrustedTemporaryRootPath = [string]$TrustedRoot
            CandidateParentPath = [string]$CandidateParent
            CandidateDirectoryPath = [string]$CandidatePath
            OwnershipJournal = $arrJournal
            CleanupAttempt = [uint32]0
            CleanupSummary = $null
        }
        $objState.PSObject.TypeNames.Insert(0,
            'TerraformStyleGuide.StyleGuideCandidateOwnershipState.v1')
        $objRegistration = [pscustomobject]@{
            Object = $objState
            CandidateId = $guidCandidateId
            State = [string]'NotCreated'
            TrustedRoot = [string]$TrustedRoot
            CandidateParent = [string]$CandidateParent
            CandidatePath = [string]$CandidatePath
            Journal = $arrJournal
            Entries = [object[]]@()
            Attempt = [uint32]0
            Summary = $null
            SummaryValues = $null
            PrivateEnvelope = $null
        }
        [void]$script:arrCandidateStateRegistration.Add($objRegistration)
        return $objState
    }

    # These fixed CLR members inspect public capabilities without dispatch through
    # caller-added PowerShell methods or properties. No member name is supplied by
    # a caller. Exact PSNoteProperty type precedes its virtual metadata getters.
    $script:objCandidateExactTypeMethod = [System.Object].GetMethod('GetType')
    $script:objCandidateArrayLengthGetter = [System.Array].GetProperty('Length').GetGetMethod()
    $script:objCandidatePropertiesGetter = [System.Management.Automation.PSObject].GetProperty('Properties').GetGetMethod()
    $script:objCandidateTypeNamesGetter = [System.Management.Automation.PSObject].GetProperty('TypeNames').GetGetMethod()
    $script:objCandidateTypeNameCountGetter = [System.Collections.ObjectModel.Collection[string]].GetProperty('Count').GetGetMethod()
    $script:objCandidateTypeNameItemGetter = [System.Collections.ObjectModel.Collection[string]].GetProperty('Item').GetGetMethod()
    $script:objCandidateNoteNameGetter = [System.Management.Automation.PSMemberInfo].GetProperty('Name').GetGetMethod()
    $script:objCandidateNoteKindGetter = [System.Management.Automation.PSNoteProperty].GetProperty('MemberType').GetGetMethod()
    $script:objCandidateNoteValueGetter = [System.Management.Automation.PSNoteProperty].GetProperty('Value').GetGetMethod()
    $script:scriptBlockGetCandidateExactRuntimeType = {
        param ([AllowNull()][object]$Value)

        if ($null -eq $Value) { return $null }
        return $script:objCandidateExactTypeMethod.Invoke($Value.PSObject.BaseObject, $null)
    }
    $script:scriptBlockGetCandidatePublicArrayLength = {
        param ([object]$Value)

        if ($null -eq $Value -or $Value -isnot [System.Array]) { throw 'public-array-invalid' }
        return [int]$script:objCandidateArrayLengthGetter.Invoke($Value.PSObject.BaseObject, $null)
    }
    $script:scriptBlockTestCandidatePublicTypeName = {
        param ([object]$Value, [string]$ExpectedName)

        $objWrapper = [System.Management.Automation.PSObject]::AsPSObject($Value)
        $objNames = $script:objCandidateTypeNamesGetter.Invoke($objWrapper, $null)
        $intCount = [int]$script:objCandidateTypeNameCountGetter.Invoke($objNames.PSObject.BaseObject, $null)
        if ($intCount -eq 0) { return $false }
        $strFirst = $script:objCandidateTypeNameItemGetter.Invoke($objNames.PSObject.BaseObject, [object[]]@(0))
        return $strFirst -ceq $ExpectedName
    }
    $script:scriptBlockCaptureCandidatePublicProperties = {
        param ([object]$Value, [string[]]$ExpectedNames)

        if ((& $script:scriptBlockGetCandidateExactRuntimeType -Value $Value) -ne [System.Management.Automation.PSCustomObject]) {
            throw 'public-record-invalid'
        }
        $objWrapper = [System.Management.Automation.PSObject]::AsPSObject($Value)
        $arrProperties = @($script:objCandidatePropertiesGetter.Invoke($objWrapper, $null))
        if ($arrProperties.Count -ne $ExpectedNames.Count) { throw 'public-record-invalid' }
        $hashtableCapture = @{}
        for ($intIndex = 0; $intIndex -lt $ExpectedNames.Count; $intIndex++) {
            $objDescriptor = $arrProperties[$intIndex]
            if ((& $script:scriptBlockGetCandidateExactRuntimeType -Value $objDescriptor) -ne [System.Management.Automation.PSNoteProperty]) {
                throw 'public-record-invalid'
            }
            $objBaseDescriptor = $objDescriptor.PSObject.BaseObject
            $strName = $script:objCandidateNoteNameGetter.Invoke($objBaseDescriptor, $null)
            $objKind = $script:objCandidateNoteKindGetter.Invoke($objBaseDescriptor, $null)
            if ($strName -cne $ExpectedNames[$intIndex] -or $objKind -ne [System.Management.Automation.PSMemberTypes]::NoteProperty) {
                throw 'public-record-invalid'
            }
            $hashtableCapture[$ExpectedNames[$intIndex]] = $script:objCandidateNoteValueGetter.Invoke($objBaseDescriptor, $null)
        }
        return $hashtableCapture
    }

    $script:scriptBlockAssertCandidateOwnershipState = {
        param ([AllowNull()][object]$Value)

        if ($null -eq $Value -or
            (& $script:scriptBlockGetCandidateExactRuntimeType -Value $Value) -ne [System.Management.Automation.PSCustomObject] -or
            -not (& $script:scriptBlockTestCandidatePublicTypeName -Value $Value -ExpectedName 'TerraformStyleGuide.StyleGuideCandidateOwnershipState.v1')) {
            throw 'candidate-state-invalid'
        }
        $hashtableCapture = & $script:scriptBlockCaptureCandidatePublicProperties -Value $Value -ExpectedNames @(
            'SchemaVersion', 'CandidateId', 'LifecycleState',
            'TrustedTemporaryRootPath', 'CandidateParentPath', 'CandidateDirectoryPath',
            'OwnershipJournal', 'CleanupAttempt', 'CleanupSummary'
        )
        $objRegistration = $null
        foreach ($objIssued in $script:arrCandidateStateRegistration) {
            if ([object]::ReferenceEquals($objIssued.Object, $Value)) {
                $objRegistration = $objIssued
                break
            }
        }
        if ($null -eq $objRegistration) {
            throw 'candidate-state-unissued'
        }
        # Capture each claim once. Every later check reads this local capture.
        $objSchema = $hashtableCapture.SchemaVersion
        $objId = $hashtableCapture.CandidateId
        $objLifecycle = $hashtableCapture.LifecycleState
        $objTrustedRoot = $hashtableCapture.TrustedTemporaryRootPath
        $objParent = $hashtableCapture.CandidateParentPath
        $objPath = $hashtableCapture.CandidateDirectoryPath
        $objJournal = $hashtableCapture.OwnershipJournal
        $objAttempt = $hashtableCapture.CleanupAttempt
        $objSummary = $hashtableCapture.CleanupSummary
        if ($null -eq $objSchema -or (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objSchema) -ne [uint32] -or $objSchema -ne 1 -or
            $null -eq $objId -or (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objId) -ne [guid] -or $objId -ne $objRegistration.CandidateId -or
            $null -eq $objLifecycle -or (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objLifecycle) -ne [string] -or
            $objLifecycle -cne $objRegistration.State -or
            $null -eq $objTrustedRoot -or (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objTrustedRoot) -ne [string] -or
            $objTrustedRoot -cne $objRegistration.TrustedRoot -or
            $null -eq $objParent -or (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objParent) -ne [string] -or
            $objParent -cne $objRegistration.CandidateParent -or
            $null -eq $objPath -or (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objPath) -ne [string] -or
            $objPath -cne $objRegistration.CandidatePath -or
            $null -eq $objJournal -or (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objJournal) -ne [object[]] -or
            -not [object]::ReferenceEquals($objJournal, $objRegistration.Journal) -or
            $null -eq $objAttempt -or (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objAttempt) -ne [uint32] -or
            $objAttempt -ne $objRegistration.Attempt -or
            -not [object]::ReferenceEquals($objSummary, $objRegistration.Summary)) {
            throw 'candidate-state-altered'
        }
        if ((& $script:scriptBlockGetCandidatePublicArrayLength -Value $objJournal) -gt 5 -or (& $script:scriptBlockGetCandidatePublicArrayLength -Value $objJournal) -ne $objRegistration.Entries.Count) {
            throw 'candidate-state-altered'
        }
        for ($intIndex = 0; $intIndex -lt (& $script:scriptBlockGetCandidatePublicArrayLength -Value $objJournal); $intIndex++) {
            $objEntry = $objJournal[$intIndex]
            $objSnapshot = $objRegistration.Entries[$intIndex]
            if ($null -eq $objEntry -or
                (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objEntry) -ne [System.Management.Automation.PSCustomObject] -or
                -not (& $script:scriptBlockTestCandidatePublicTypeName -Value $objEntry -ExpectedName 'TerraformStyleGuide.StyleGuideCandidateOwnershipEntry.v1') -or
                -not [object]::ReferenceEquals($objEntry, $objSnapshot.Object)) {
                throw 'candidate-state-altered'
            }
            $hashtableEntryCapture = & $script:scriptBlockCaptureCandidatePublicProperties -Value $objEntry -ExpectedNames @(
                'Sequence', 'Kind', 'Path', 'Acquisition', 'Owned'
            )
            foreach ($strField in @('Sequence', 'Kind', 'Path', 'Acquisition', 'Owned')) {
                $objActual = $hashtableEntryCapture[$strField]
                $objExpected = $objSnapshot.PSObject.Properties[$strField].Value
                if ($null -eq $objActual -or (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objActual) -ne (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objExpected) -or
                    $objActual -cne $objExpected) {
                    throw 'candidate-state-altered'
                }
            }
        }
        if ($null -ne $objSummary) {
            if ((& $script:scriptBlockGetCandidateExactRuntimeType -Value $objSummary) -ne [System.Management.Automation.PSCustomObject] -or
                -not (& $script:scriptBlockTestCandidatePublicTypeName -Value $objSummary -ExpectedName 'TerraformStyleGuide.StyleGuideCandidateCleanupSummary.v1') -or
                $null -eq $objRegistration.SummaryValues) { throw 'candidate-state-altered' }
            $hashtableSummaryCapture = & $script:scriptBlockCaptureCandidatePublicProperties -Value $objSummary -ExpectedNames @(
                'CandidateId', 'PriorState', 'FinalState', 'Attempt', 'PrimaryFailure',
                'CleanupResult', 'RemovedPaths', 'RetainedPaths', 'LeafState'
            )
            foreach ($strField in @('CandidateId', 'PriorState', 'FinalState', 'Attempt', 'CleanupResult', 'LeafState')) {
                $objActual = $hashtableSummaryCapture[$strField]
                $objExpected = $objRegistration.SummaryValues.PSObject.Properties[$strField].Value
                if ($null -eq $objActual -or (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objActual) -ne (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objExpected) -or
                    $objActual -cne $objExpected) { throw 'candidate-state-altered' }
            }
            if (-not [object]::ReferenceEquals($hashtableSummaryCapture.PrimaryFailure,
                    $objRegistration.SummaryValues.PrimaryFailure)) { throw 'candidate-state-altered' }
            foreach ($strField in @('RemovedPaths', 'RetainedPaths')) {
                $objActual = $hashtableSummaryCapture[$strField]
                $objExpected = $objRegistration.SummaryValues.PSObject.Properties[$strField].Value
                if ($null -eq $objActual -or (& $script:scriptBlockGetCandidateExactRuntimeType -Value $objActual) -ne [string[]] -or
                    (& $script:scriptBlockGetCandidatePublicArrayLength -Value $objActual) -gt 5 -or (& $script:scriptBlockGetCandidatePublicArrayLength -Value $objActual) -ne $objExpected.Count) {
                    throw 'candidate-state-altered'
                }
                for ($intPath = 0; $intPath -lt (& $script:scriptBlockGetCandidatePublicArrayLength -Value $objActual); $intPath++) {
                    if ($objActual[$intPath] -cne $objExpected[$intPath]) { throw 'candidate-state-altered' }
                }
            }
        }
        return $objRegistration
    }

    $script:scriptBlockPublishCandidateOwnership = {
        param ([object]$Registration, [object]$PrivateEnvelope)

        $arrOwned = @($PrivateEnvelope.OwnershipJournal | Where-Object {
                $_.Kind -in @('CandidateDirectory', 'CandidateFile') -and $_.EntryState -eq 'Created'
            })
        if ($arrOwned.Count -gt 5) { throw 'candidate-journal-invalid' }
        $listEntries = New-Object 'System.Collections.Generic.List[pscustomobject]'
        $listSnapshots = New-Object 'System.Collections.Generic.List[pscustomobject]'
        for ($intIndex = 0; $intIndex -lt $arrOwned.Count; $intIndex++) {
            $objPrivate = $arrOwned[$intIndex]
            $strKind = if ($objPrivate.Kind -ceq 'CandidateDirectory') { 'Directory' } else { 'File' }
            $objEntry = [pscustomobject][ordered]@{
                Sequence = [uint32]$intIndex
                Kind = [string]$strKind
                Path = [string]$objPrivate.Path
                Acquisition = [string]$objPrivate.CreationPhase
                Owned = [bool]$true
            }
            $objEntry.PSObject.TypeNames.Insert(0, 'TerraformStyleGuide.StyleGuideCandidateOwnershipEntry.v1')
            $objSnapshot = [pscustomobject]@{
                Object = $objEntry
                Sequence = [uint32]$intIndex
                Kind = [string]$strKind
                Path = [string]$objPrivate.Path
                Acquisition = [string]$objPrivate.CreationPhase
                Owned = [bool]$true
                ContentLength = $objPrivate.ContentLength
                ContentSha256 = $objPrivate.ContentSha256
            }
            $listEntries.Add($objEntry)
            $listSnapshots.Add($objSnapshot)
        }
        $Registration.Journal = [object[]]@($listEntries.ToArray())
        $Registration.Entries = [object[]]@($listSnapshots.ToArray())
        $Registration.Object.OwnershipJournal = $Registration.Journal
        $Registration.PrivateEnvelope = $PrivateEnvelope
        if ($arrOwned.Count -gt 0) {
            $Registration.State = 'Active'
            $Registration.Object.LifecycleState = 'Active'
        }
    }

    $script:scriptBlockFinishCandidateCleanup = {
        param (
            [object]$Registration,
            [string]$PreviousState,
            [string]$FinalState,
            [AllowNull()][object]$PrimaryFailure,
            [string[]]$RemovedPaths,
            [string[]]$RetainedPaths,
            [string]$LeafState,
            [string]$Reason
        )

        $objSummary = [pscustomobject][ordered]@{
            CandidateId = $Registration.CandidateId
            PriorState = [string]$PreviousState
            FinalState = [string]$FinalState
            Attempt = [uint32]$Registration.Attempt
            PrimaryFailure = $PrimaryFailure
            CleanupResult = [string]$Reason
            RemovedPaths = [string[]]$RemovedPaths
            RetainedPaths = [string[]]$RetainedPaths
            LeafState = [string]$LeafState
        }
        $objSummary.PSObject.TypeNames.Insert(0, 'TerraformStyleGuide.StyleGuideCandidateCleanupSummary.v1')
        $Registration.State = $FinalState
        $Registration.Summary = $objSummary
        $Registration.SummaryValues = [pscustomobject]@{
            CandidateId = $Registration.CandidateId
            PriorState = [string]$PreviousState
            FinalState = [string]$FinalState
            Attempt = [uint32]$Registration.Attempt
            PrimaryFailure = $PrimaryFailure
            CleanupResult = [string]$Reason
            RemovedPaths = [string[]]$RemovedPaths.Clone()
            RetainedPaths = [string[]]$RetainedPaths.Clone()
            LeafState = [string]$LeafState
        }
        $Registration.Object.CleanupSummary = $objSummary
        $Registration.Object.LifecycleState = $FinalState
    }

    $script:scriptBlockAssertCandidateUncreatedLeafAbsent = {
        param ([string]$ParentPath, [string]$CandidatePath)

        # A NotCreated capability owns no entry. Inspect the parent's immediate
        # entries once, retaining no listing. Absence needs the entire sequence;
        # any matching or unclassifiable entry ends the proof without deletion.
        $objEnumerator = [System.IO.Directory]::EnumerateFileSystemEntries($ParentPath).GetEnumerator()
        try {
            while ($objEnumerator.MoveNext()) {
                $strEntry = [string]$objEnumerator.Current
                if ([string]::Equals($strEntry, $CandidatePath, $script:objCandidateHelperPathComparison)) {
                    throw 'candidate-leaf-present'
                }
                $objAttributes = [System.IO.File]::GetAttributes($strEntry)
                if (($objAttributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    throw 'candidate-parent-entry-unclassifiable'
                }
                if (($objAttributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
                    [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope -LiteralPath $strEntry -Phase 'cleanup')
                } else {
                    [void](& $script:scriptBlockAssertCandidateHelperOrdinaryRegularFile -LiteralPath $strEntry)
                }
            }
        } finally {
            $objEnumerator.Dispose()
        }
    }

    function Remove-StyleGuideCandidateInvocationState {
        # .SYNOPSIS
        # Removes only the ordinary entries acquired by one candidate capability.
        #
        # .DESCRIPTION
        # Authenticates the issued reference and immutable snapshots before any
        # filesystem operation. Reuses the source component, cardinality, file
        # evidence and nonrecursive deletion checks. A released candidate name is
        # outside this capability; a valid Disposed repeat makes no path, provider,
        # filesystem or native call and returns the identical object and summary.
        #
        # .PARAMETER CandidateOwnershipState
        # Specifies the exact candidate ownership object issued by this helper.
        #
        # .PARAMETER PrimaryFailure
        # Preserves an ErrorRecord, Exception or explicit null as the primary error.
        #
        # .EXAMPLE
        # $objState = Remove-StyleGuideCandidateInvocationState -CandidateOwnershipState $objState
        # # Removes only this candidate's proven ownership and returns the same state.
        #
        # .INPUTS
        # None. Pipeline input is not supported.
        #
        # .OUTPUTS
        # [pscustomobject] The same authenticated candidate ownership object.
        #
        # .NOTES
        # Version: 1.0.20260924.0
        # All parameters require names; positional binding is disabled.
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSUseShouldProcessForStateChangingFunctions', '',
            Justification = 'The closed public interface provides no ShouldProcess parameters.'
        )]
        [CmdletBinding(PositionalBinding = $false)]
        [OutputType([pscustomobject])]
        param (
            [Parameter(Mandatory = $true)]
            [AllowNull()][AllowEmptyString()][AllowEmptyCollection()]
            [object]$CandidateOwnershipState,

            [Parameter()]
            [AllowNull()]
            [object]$PrimaryFailure
        )

        Set-StrictMode -Version Latest
        if ($null -ne $PrimaryFailure -and
            $PrimaryFailure -isnot [System.Management.Automation.ErrorRecord] -and
            $PrimaryFailure -isnot [System.Exception]) {
            throw 'candidate-primary-failure-invalid'
        }
        try {
            $objRegistration = & $script:scriptBlockAssertCandidateOwnershipState -Value $CandidateOwnershipState
        } catch {
            # Malformed public claims have one stable refusal and no filesystem work.
            $objException = New-Object System.InvalidOperationException(
                'TerraformStyleGuide.Candidate.v1|phase=cleanup|subreason=candidate-state-invalid',
                $_.Exception)
            $objException.Data['TerraformStyleGuidePhase'] = 'cleanup'
            $objException.Data['TerraformStyleGuideSubreason'] = 'candidate-state-invalid'
            $objError = New-Object System.Management.Automation.ErrorRecord(
                $objException, 'candidate-state-invalid',
                [System.Management.Automation.ErrorCategory]::InvalidArgument, $null)
            $PSCmdlet.ThrowTerminatingError($objError)
        }
        $strPreviousState = [string]$objRegistration.State
        if ($strPreviousState -ceq 'Disposed') { return $CandidateOwnershipState }
        if ($strPreviousState -in @('CleanupInProgress', 'RetainedUncertain')) {
            $objException = New-Object System.InvalidOperationException(
                'TerraformStyleGuide.Candidate.v1|phase=cleanup|subreason=candidate-state-retained')
            $objException.Data['TerraformStyleGuidePhase'] = 'cleanup'
            $objException.Data['TerraformStyleGuideSubreason'] = 'candidate-state-retained'
            $objError = New-Object System.Management.Automation.ErrorRecord(
                $objException, 'candidate-state-retained',
                [System.Management.Automation.ErrorCategory]::InvalidOperation, $CandidateOwnershipState)
            $PSCmdlet.WriteObject($CandidateOwnershipState, $false)
            $PSCmdlet.WriteError($objError)
            return
        }
        if ($strPreviousState -cnotin @('NotCreated', 'Active') -or
            $objRegistration.Attempt -eq [uint32]::MaxValue) {
            throw 'candidate-state-invalid'
        }
        $listRemoved = New-Object 'System.Collections.Generic.List[string]'
        $listRetained = New-Object 'System.Collections.Generic.List[string]'
        $objCleanupFailure = $null
        try {
            [void](& $script:scriptBlockAssertCandidateOwnershipEnvelope `
                    -TrustedRoot $objRegistration.TrustedRoot `
                    -CandidateParent $objRegistration.CandidateParent `
                    -CandidatePath $objRegistration.CandidatePath)
            [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                    -LiteralPath $objRegistration.TrustedRoot -Phase 'cleanup')
            [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                    -LiteralPath $objRegistration.CandidateParent -Phase 'cleanup')
            if ($strPreviousState -ceq 'NotCreated') {
                if ($objRegistration.Entries.Count -ne 0) { throw 'candidate-journal-invalid' }
                $objRegistration.Attempt = [uint32]($objRegistration.Attempt + 1)
                $CandidateOwnershipState.CleanupAttempt = $objRegistration.Attempt
                $objRegistration.State = 'CleanupInProgress'
                $CandidateOwnershipState.LifecycleState = 'CleanupInProgress'
                [void](& $script:scriptBlockAssertCandidateUncreatedLeafAbsent `
                        -ParentPath $objRegistration.CandidateParent `
                        -CandidatePath $objRegistration.CandidatePath)
            } else {
                if ($objRegistration.Entries.Count -eq 0 -or
                    $objRegistration.Entries[0].Kind -cne 'Directory' -or
                    $objRegistration.Entries[0].Path -cne $objRegistration.CandidatePath) {
                    throw 'candidate-journal-invalid'
                }
                [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                        -LiteralPath $objRegistration.CandidatePath -Phase 'cleanup')
                $arrFiles = @($objRegistration.Entries | Where-Object { $_.Kind -ceq 'File' -and $_.Owned })
                $arrActual = [string[]]@(& $script:scriptBlockGetCandidateHelperEntry `
                        -LiteralPath $objRegistration.CandidatePath -Phase 'cleanup' -MaximumEntry ($arrFiles.Count + 1))
                if ($arrActual.Count -ne $arrFiles.Count) { throw 'candidate-cardinality' }
                foreach ($objEntry in $arrFiles) {
                    if (-not (& $script:scriptBlockTestCandidateHelperEntryPresent `
                                -EntryList $arrActual -ExpectedPath $objEntry.Path)) {
                        throw 'candidate-entry'
                    }
                    $objEvidence = & $script:scriptBlockGetCandidateHelperFileEvidence `
                        -LiteralPath $objEntry.Path -Phase 'cleanup' -ExpectedLength $objEntry.ContentLength
                    if ($objEvidence.Length -ne $objEntry.ContentLength -or
                        $objEvidence.Sha256 -cne $objEntry.ContentSha256) { throw 'candidate-identity' }
                }
                # Inspection cannot authorize any deletion until every entry passes.
                $objRegistration.Attempt = [uint32]($objRegistration.Attempt + 1)
                $CandidateOwnershipState.CleanupAttempt = $objRegistration.Attempt
                $objRegistration.State = 'CleanupInProgress'
                $CandidateOwnershipState.LifecycleState = 'CleanupInProgress'
                foreach ($objEntry in @($arrFiles | Sort-Object -Property Sequence -Descending)) {
                    [System.IO.File]::Delete($objEntry.Path)
                    [void](& $script:scriptBlockAssertCandidateHelperEntryAbsent `
                            -ParentPath $objRegistration.CandidatePath -ExpectedPath $objEntry.Path -Phase 'cleanup')
                    $objEntry.Owned = $false
                    $objEntry.Object.Owned = $false
                    $listRemoved.Add($objEntry.Path)
                }
                [System.IO.Directory]::Delete($objRegistration.CandidatePath, $false)
                [void](& $script:scriptBlockAssertCandidateHelperEntryAbsent `
                        -ParentPath $objRegistration.CandidateParent `
                        -ExpectedPath $objRegistration.CandidatePath -Phase 'cleanup')
                $objRegistration.Entries[0].Owned = $false
                $objRegistration.Entries[0].Object.Owned = $false
                $listRemoved.Add($objRegistration.CandidatePath)
            }
            & $script:scriptBlockFinishCandidateCleanup -Registration $objRegistration `
                -PreviousState $strPreviousState -FinalState 'Disposed' -PrimaryFailure $PrimaryFailure `
                -RemovedPaths $listRemoved.ToArray() -RetainedPaths ([string[]]@()) `
                -LeafState 'absent-at-release' -Reason 'candidate-disposed'
        } catch {
            $objCleanupFailure = $_
            foreach ($objEntry in $objRegistration.Entries) {
                if ($objEntry.Owned) { $listRetained.Add($objEntry.Path) }
            }
            if ($listRetained.Count -eq 0) { $listRetained.Add($objRegistration.CandidatePath) }
            & $script:scriptBlockFinishCandidateCleanup -Registration $objRegistration `
                -PreviousState $strPreviousState -FinalState 'RetainedUncertain' -PrimaryFailure $PrimaryFailure `
                -RemovedPaths $listRemoved.ToArray() -RetainedPaths $listRetained.ToArray() `
                -LeafState 'uncertain' -Reason 'candidate-state-retained'
        }
        $PSCmdlet.WriteObject($CandidateOwnershipState, $false)
        if ($null -ne $objCleanupFailure) {
            $objException = New-Object System.InvalidOperationException(
                'TerraformStyleGuide.Candidate.v1|phase=cleanup|subreason=candidate-state-retained',
                $objCleanupFailure.Exception)
            $objException.Data['TerraformStyleGuidePhase'] = 'cleanup'
            $objException.Data['TerraformStyleGuideSubreason'] = 'candidate-state-retained'
            $objError = New-Object System.Management.Automation.ErrorRecord(
                $objException, 'candidate-state-retained',
                [System.Management.Automation.ErrorCategory]::InvalidOperation, $CandidateOwnershipState)
            $PSCmdlet.WriteError($objError)
        }
    }

    $script:scriptBlockRemoveCandidateOwnershipState =
    ${function:Remove-StyleGuideCandidateInvocationState}

    $script:scriptBlockConvertToCandidateHelperNormalizedPath = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$Value,

            [Parameter(Mandatory = $true)]
            [string]$ParameterName
        )

        $strProviderPath = $Value
        $strProviderName = 'FileSystem'
        $intProviderSeparator = $Value.IndexOf('::', [System.StringComparison]::Ordinal)
        if ($intProviderSeparator -ge 0) {
            $strProviderName = $Value.Substring(0, $intProviderSeparator)
            $strProviderPath = $Value.Substring($intProviderSeparator + 2)
            if ($strProviderName.Length -eq 0 -or $strProviderPath.Contains('::') -or
                $strProviderName -cnotmatch '\A[A-Za-z][A-Za-z0-9.\\]*\z') {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'parameter' -Phase 'parameter' -Subreason 'path-malformed'
            }
        }
        $boolContainsWildcard = [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Value)
        if ($ParameterName -ceq 'OwnedPath') {
            # Only an explicitly supplied archive filename can contain literal
            # brackets. Parent components retain the ordinary raw path grammar;
            # star and question-mark are never admitted, even when escaped.
            $intLeafSeparator = $strProviderPath.LastIndexOfAny([char[]]@(
                    [System.IO.Path]::DirectorySeparatorChar,
                    [System.IO.Path]::AltDirectorySeparatorChar))
            $strParentClaim = if ($intLeafSeparator -ge 0) {
                $strProviderPath.Substring(0, $intLeafSeparator + 1)
            } else { '' }
            $boolContainsWildcard =
                [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($strParentClaim) -or
                $strProviderPath.IndexOfAny([char[]]@('*', '?')) -ge 0
        }
        if ($boolContainsWildcard) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'parameter' -Phase 'parameter' -Subreason 'path-wildcard'
        }
        $boolDriveRelative = $strProviderPath.Length -ge 2 -and
        [System.Char]::IsLetter($strProviderPath[0]) -and
        $strProviderPath[1] -eq ':' -and
        ($strProviderPath.Length -eq 2 -or
        ($strProviderPath[2] -ne [char]'\' -and $strProviderPath[2] -ne [char]'/'))
        $boolFullyQualified = if ($script:boolCandidateHelperIsWindows) {
            $strProviderPath -cmatch '\A(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+(?:[\\/]|\z))'
        } else {
            $strProviderPath.StartsWith('/', [System.StringComparison]::Ordinal)
        }
        if ($boolDriveRelative -or -not $boolFullyQualified) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'parameter' -Phase 'parameter' -Subreason 'path-not-fully-qualified'
        }
        if ($strProviderName -cne 'FileSystem') {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'parameter' -Phase 'parameter' -Subreason 'path-provider'
        }
        try {
            $objProvider = $null
            $objDrive = $null
            $strResolutionPath = $strProviderPath
            $strLiteralOwnedLeaf = $null
            if ($ParameterName -ceq 'OwnedPath' -and -not $script:boolCandidateHelperIsWindows) {
                $strNativeLeaf = [System.IO.Path]::GetFileName($strProviderPath)
                if ($strNativeLeaf.Contains('\')) {
                    # PowerShell treats backslash as a separator even on Unix;
                    # the native filesystem permits it in this literal filename.
                    # Resolve the parent through the same provider guard, then
                    # restore the native leaf without interpreting its characters.
                    $strLiteralOwnedLeaf = $strNativeLeaf
                    $strResolutionPath = [System.IO.Path]::GetDirectoryName($strProviderPath)
                }
            }
            $strNormalizedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
                $strResolutionPath, [ref]$objProvider, [ref]$objDrive)
            if ($null -eq $objProvider -or $objProvider.Name -cne 'FileSystem') {
                throw 'path-provider'
            }
            if ($script:boolCandidateHelperIsWindows -and $strProviderPath -cmatch '\A[A-Za-z]:') {
                $strNativeRoot = $strProviderPath.Substring(0, 2) + '\'
                if ($null -eq $objDrive -or -not [string]::Equals(
                        $objDrive.Root, $strNativeRoot, [StringComparison]::OrdinalIgnoreCase)) {
                    throw 'path-provider'
                }
            }
            if ($null -ne $strLiteralOwnedLeaf) {
                $strNormalizedPath = [System.IO.Path]::Combine($strNormalizedPath, $strLiteralOwnedLeaf)
            }
            $strNormalizedPath = [System.IO.Path]::GetFullPath($strNormalizedPath)
            if ($ParameterName -cin @('CheckoutRoot', 'TrustedTemporaryRoot', 'DownloadDirectory', 'CandidateDirectory')) {
                # Directory identities exclude redundant ending separators. Stop
                # at the native root so C:\ never becomes C: and / never becomes
                # empty; a UNC share root remains the same fully qualified share.
                # OwnedPath is a file boundary and deliberately does not use this.
                $intRootLength = [System.IO.Path]::GetPathRoot($strNormalizedPath).Length
                $intLength = $strNormalizedPath.Length
                while ($intLength -gt $intRootLength -and
                    ($strNormalizedPath[$intLength - 1] -eq [System.IO.Path]::DirectorySeparatorChar -or
                    $strNormalizedPath[$intLength - 1] -eq [System.IO.Path]::AltDirectorySeparatorChar)) {
                    $intLength--
                }
                $strNormalizedPath = $strNormalizedPath.Substring(0, $intLength)
            }
            return $strNormalizedPath
        } catch {
            if ($_.Exception.Message -ceq 'path-provider') {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'parameter' -Phase 'parameter' -Subreason 'path-provider'
            }
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'parameter' -Phase 'parameter' -Subreason "$ParameterName-normalization"
        }
    }

    $script:scriptBlockTestCandidateHelperPathContained = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [Parameter(Mandatory = $true)]
            [string]$Candidate
        )

        $strRootPrefix = $Root.TrimEnd(
            $script:chrCandidateHelperDirectorySeparator,
            $script:chrCandidateHelperAlternateSeparator
        ) + $script:chrCandidateHelperDirectorySeparator
        return $Candidate.StartsWith($strRootPrefix, $script:objCandidateHelperPathComparison)
    }

    $script:scriptBlockTestCandidateHelperRootsShareStorage = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$CheckoutPath,

            [Parameter(Mandatory = $true)]
            [string]$TrustedPath,

            [Parameter(Mandatory = $true)]
            [string]$SentinelDirectory
        )

        # This probe creates a file in SentinelDirectory and then walks upward from
        # it until it reaches TrustedPath, so it presumes that directory really is a
        # descendant of the trusted root and is not inside the checkout. Both facts
        # come from untrusted input, and the containment phase that establishes them
        # runs after this probe. Without the check below, a forged but
        # self-consistent context -- one whose supplied paths agree with each other
        # and with a real directory the caller chose -- gets a file created and
        # deleted in that directory before anything rejects the invocation, and the
        # upward walk runs to the filesystem root instead of terminating.
        #
        # Proving it here costs no filesystem call: containment is a string prefix
        # test. It is stated as the probe's own precondition rather than at the one
        # call site so that the write cannot be reached from anywhere without it.
        if (-not (& $script:scriptBlockTestCandidateHelperPathContained `
                    -Root $TrustedPath -Candidate $SentinelDirectory) -or
            (& $script:scriptBlockTestCandidateHelperPathContained `
                -Root $CheckoutPath -Candidate $SentinelDirectory)) {
            $strContainmentReason = 'download-outside'
            if (-not $script:boolCandidateHelperIsWindows -and
                $SentinelDirectory.StartsWith(
                    $TrustedPath.TrimEnd($script:chrCandidateHelperDirectorySeparator) + $script:chrCandidateHelperDirectorySeparator,
                    [System.StringComparison]::OrdinalIgnoreCase)) {
                $strContainmentReason = 'case-sensitive-outside'
            }
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'containment-invalid' -Phase 'containment' -Subreason $strContainmentReason
        }

        # Every check before this one reasons about names. Names are exactly what
        # aliasing breaks: a substituted drive letter, a directory junction, a
        # mapped network drive, and a short-name alias each give one directory two
        # spellings that share no text and no reparse point on the path itself.
        # Resolving them by name means resolving each mechanism, and the list of
        # mechanisms is not closed.
        #
        # Visibility is closed. If two spellings name one directory, a file created
        # through one is visible through the other, whatever made them equal. So
        # one uniquely named file is placed in the trusted root -- which this
        # invocation owns and is about to populate anyway -- and the two containment
        # questions are asked as questions about where that file can be seen.
        #
        # Nothing is written outside the trusted root, and the checkout is only ever
        # read, so a read-only checkout is unaffected.
        # The sentinel goes where this workflow already creates files. Neither the
        # caller's trusted parent nor the invocation root is such a place: files
        # are only ever written beneath the download and candidate directories, so
        # a Windows ACL granting create-folder and denying create-file on either of
        # the first two is a configuration the rest of the design supports, and a
        # probe writing there would turn it into a rejection of every valid
        # expansion. The download directory demands nothing this expansion does not
        # already demand.
        #
        # Testing from further down loses nothing. Candidate state is created
        # under the invocation root, so that is the position that matters, and the
        # directories above the sentinel are still covered because their leaves are
        # carried in the paths below.
        $strSentinelName = 'psstyleguide-root-probe-' +
        [System.Guid]::NewGuid().ToString('N') + '.tmp'
        $strSentinelPath = [System.IO.Path]::Combine($SentinelDirectory, $strSentinelName)
        # Leaves between the sentinel and the trusted parent, deepest first. Each
        # checkout ancestor is tested with every suffix of this chain, so an
        # ancestor equal to any directory on the path to the sentinel is caught.
        $listSentinelLeaf = New-Object 'System.Collections.Generic.List[string]'
        $objLeafWalk = New-Object System.IO.DirectoryInfo($SentinelDirectory)
        while ($null -ne $objLeafWalk -and
            -not [System.String]::Equals(
                $objLeafWalk.FullName,
                $TrustedPath,
                $script:objCandidateHelperPathComparison)) {
            $listSentinelLeaf.Add([string]$objLeafWalk.Name)
            $objLeafWalk = $objLeafWalk.Parent
        }
        $boolShared = $false
        # Prove the path to the sentinel is ordinary and link-free before writing
        # through it. The context recorded these directories at creation time, and
        # a directory replaced by a link since then would otherwise take this write
        # outside trusted storage -- which is precisely the guarantee the probe is
        # asserting, so it cannot be left until the later envelope check.
        [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                -LiteralPath $SentinelDirectory `
                -Phase 'root' -DiagnosticRole 'download')
        try {
            try {
                [System.IO.File]::WriteAllBytes($strSentinelPath, [byte[]]@())
            } catch {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'root-invalid' -Phase 'root' -Subreason 'identity'
            }
            # The probe is only evidence if the file it looks for exists. A silent
            # write failure would otherwise read as "not shared" everywhere.
            if (-not [System.IO.File]::Exists($strSentinelPath)) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'root-invalid' -Phase 'root' -Subreason 'identity'
            }

            # Is the checkout inside the trusted root? Then some ancestor of the
            # checkout is the trusted root under another spelling, and the sentinel
            # is visible directly beneath that ancestor.
            # Two candidates per ancestor: the ancestor may be the sentinel's own
            # directory, or the trusted parent one level above it.
            $objAncestor = New-Object System.IO.DirectoryInfo($CheckoutPath)
            while ($null -ne $objAncestor -and -not $boolShared) {
                $strSuffix = $strSentinelName
                if ([System.IO.File]::Exists(
                        [System.IO.Path]::Combine($objAncestor.FullName, $strSuffix))) {
                    $boolShared = $true
                    break
                }
                for ($intLeaf = 0; $intLeaf -lt $listSentinelLeaf.Count; $intLeaf++) {
                    $strSuffix = [System.IO.Path]::Combine($listSentinelLeaf[$intLeaf], $strSuffix)
                    if ([System.IO.File]::Exists(
                            [System.IO.Path]::Combine($objAncestor.FullName, $strSuffix))) {
                        $boolShared = $true
                        break
                    }
                }
                $objAncestor = $objAncestor.Parent
            }

            # Is the trusted root inside the checkout? Then some ancestor of the
            # trusted root is the checkout under another spelling. That ancestor is
            # a lexical prefix of the trusted root, so the remainder is known, and
            # appending it to the checkout reaches the sentinel if the two are one.
            if (-not $boolShared) {
                $objAncestor = New-Object System.IO.DirectoryInfo($SentinelDirectory)
                $strRelative = $strSentinelName
                while ($null -ne $objAncestor) {
                    if ([System.IO.File]::Exists(
                            [System.IO.Path]::Combine($CheckoutPath, $strRelative))) {
                        $boolShared = $true
                        break
                    }
                    $strRelative = [System.IO.Path]::Combine($objAncestor.Name, $strRelative)
                    $objAncestor = $objAncestor.Parent
                }
            }
        } finally {
            try {
                if ([System.IO.File]::Exists($strSentinelPath)) {
                    [System.IO.File]::Delete($strSentinelPath)
                }
            } catch {
                # Reported below rather than here: a delete failure must not mask
                # the answer the probe already reached.
                $boolShared = $boolShared
            }
        }
        if ([System.IO.File]::Exists($strSentinelPath)) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'root-invalid' -Phase 'root' -Subreason 'identity'
        }
        return $boolShared
    }

    $script:scriptBlockAssertCandidateHelperEntryAbsent = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$ParentPath,

            [Parameter(Mandatory = $true)]
            [string]$ExpectedPath,

            [Parameter(Mandatory = $true)]
            [string]$Phase,

            # The cleanup caller needs a code that already exists in the taxonomy
            # and says what actually happened, rather than a new "<phase>-invalid"
            # minted for one site. Empty keeps every existing caller unchanged.
            [string]$Code = ''
        )

        $arrEntries = [string[]]@(
            & $script:scriptBlockGetCandidateHelperEntry -LiteralPath $ParentPath -Phase $Phase `
                -MatchPath $ExpectedPath
        )
        foreach ($strEntry in $arrEntries) {
            if ([System.String]::Equals(
                    $strEntry,
                    $ExpectedPath,
                    $script:objCandidateHelperPathComparison
                )) {
                $strAbsenceCode = if ($Code.Length -eq 0) { "$Phase-invalid" } else { $Code }
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code $strAbsenceCode -Phase $Phase -Subreason 'leaf-present'
            }
        }
    }

    $script:scriptBlockReadCandidateHelperValidatedFile = {
        param (
            [Parameter(Mandatory = $true)]
            [string]$LiteralPath,

            [Parameter(Mandatory = $true)]
            [uint64]$ExpectedLength,

            [Parameter(Mandatory = $true)]
            [string]$ExpectedSha256
        )

        # Prove the path is an ordinary regular file before opening it. A named
        # pipe carries neither the Directory nor the ReparsePoint attribute, so
        # nothing above this line would refuse one, and opening a FIFO for reading
        # blocks until a writer appears -- which is an indefinite hang of the
        # runner, not a failed check.
        #
        # This is the THIRD site where this class has appeared. Round 23 closed it
        # at the download entry, round 25 centralised the proof, and this site was
        # missed both times because the sweeps looked for the shape of the previous
        # fix rather than for the property: a path opened for reading whose
        # ordinariness has not been proven immediately beforehand. The listing that
        # precedes this call establishes the entry existed then, not that it is
        # still an ordinary file now. Reported at round 57.
        try {
            & $script:scriptBlockAssertCandidateHelperOrdinaryRegularFile `
                -LiteralPath $LiteralPath
        } catch {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'post-extraction-invalid' -Phase 'post-extraction' -Subreason 'nonordinary'
        }

        $objStream = New-Object System.IO.FileStream(
            $LiteralPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read
        )
        try {
            if ([uint64]$objStream.Length -ne $ExpectedLength) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'post-extraction-invalid' -Phase 'post-extraction' -Subreason 'length'
            }
            # Exactly the validated count, and not to wherever the file now ends.
            # The length above is compared against the journal and then the read ran
            # to EOF, which is not the same number once a competing writer appends:
            # the ceiling bounded the check and not the work, and a writer that
            # stays ahead of the reader moves the end indefinitely.
            #
            # This is the third place this class appeared, after the archive
            # allocation and the cleanup hash. The sweep that followed those missed
            # it, because it searched for ComputeHash -- the mechanism of the
            # previous fix -- rather than for a filesystem read that ends where the
            # file ends. The idiom here was already the bounded one; only the bound
            # was absent.
            $objSha256 = [System.Security.Cryptography.SHA256]::Create()
            $arrBuffer = New-Object byte[] $script:intCandidateHelperBufferSize
            $listPrefix = New-Object 'System.Collections.Generic.List[byte]'
            try {
                $uintRemaining = $ExpectedLength
                while ($uintRemaining -gt 0) {
                    $intWanted = if ($uintRemaining -lt [uint64]$arrBuffer.Length) {
                        [int]$uintRemaining
                    } else {
                        $arrBuffer.Length
                    }
                    $intRead = $objStream.Read($arrBuffer, 0, $intWanted)
                    if ($intRead -le 0) {
                        & $script:scriptBlockStopCandidateHelperOperation `
                            -Code 'post-extraction-invalid' -Phase 'post-extraction' `
                            -Subreason 'length'
                    }
                    for ($intIndex = 0; $intIndex -lt $intRead; $intIndex++) {
                        if ($listPrefix.Count -lt 3) {
                            $listPrefix.Add($arrBuffer[$intIndex])
                        }
                        if ($arrBuffer[$intIndex] -eq 0x0D) {
                            & $script:scriptBlockStopCandidateHelperOperation `
                                -Code 'post-extraction-invalid' -Phase 'post-extraction' -Subreason 'cr'
                        }
                    }
                    [void]$objSha256.TransformBlock($arrBuffer, 0, $intRead, $null, 0)
                    $uintRemaining -= [uint64]$intRead
                }
                # One byte past the validated end: a file with more to give is not
                # the file that was extracted.
                if ($objStream.Read($arrBuffer, 0, 1) -gt 0) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'post-extraction-invalid' -Phase 'post-extraction' -Subreason 'length'
                }
                [void]$objSha256.TransformFinalBlock((New-Object byte[] 0), 0, 0)
                $strActualSha256 = (
                    [System.BitConverter]::ToString($objSha256.Hash) -replace '-', ''
                ).ToLowerInvariant()
            } finally {
                $objSha256.Dispose()
            }
            if ($listPrefix.Count -eq 3 -and
                $listPrefix[0] -eq 0xEF -and $listPrefix[1] -eq 0xBB -and $listPrefix[2] -eq 0xBF) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'post-extraction-invalid' -Phase 'post-extraction' -Subreason 'bom'
            }
            if ($strActualSha256 -cne $ExpectedSha256) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'post-extraction-invalid' -Phase 'post-extraction' -Subreason 'sha256'
            }
        } finally {
            $objStream.Dispose()
        }
    }

    $script:scriptBlockAddCandidateHelperDeclaredLength = {
        param (
            [Parameter(Mandatory = $true)]
            [uint64]$CurrentTotal,

            [Parameter(Mandatory = $true)]
            [long]$DeclaredLength
        )

        if ($DeclaredLength -lt 0) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'negative-length'
        }
        $uintDeclaredLength = [uint64]$DeclaredLength
        if ($CurrentTotal -gt ([uint64]::MaxValue - $uintDeclaredLength)) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'actual-overflow'
        }
        if ($uintDeclaredLength -gt $script:uintCandidateHelperMaximumTotalByte -or
            $CurrentTotal -gt ($script:uintCandidateHelperMaximumTotalByte - $uintDeclaredLength)) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'total-limit'
        }
        if ($uintDeclaredLength -gt $script:uintCandidateHelperMaximumEntryByte) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-limit'
        }
        return [uint64]($CurrentTotal + $uintDeclaredLength)
    }

    $script:scriptBlockAddCandidateHelperActualLength = {
        param (
            [Parameter(Mandatory = $true)]
            [uint64]$CurrentEntryLength,

            [Parameter(Mandatory = $true)]
            [uint64]$CurrentTotalLength,

            [Parameter(Mandatory = $true)]
            [uint64]$ReadLength,

            [Parameter(Mandatory = $true)]
            [uint64]$DeclaredEntryLength,

            [Parameter(Mandatory = $true)]
            [string]$Phase,

            [Parameter(Mandatory = $true)]
            [string]$DiagnosticCode
        )

        if ($CurrentEntryLength -gt ([uint64]::MaxValue - $ReadLength) -or
            $CurrentTotalLength -gt ([uint64]::MaxValue - $ReadLength)) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code $DiagnosticCode -Phase $Phase -Subreason 'actual-overflow'
        }
        $uintNewEntryLength = [uint64]($CurrentEntryLength + $ReadLength)
        $uintNewTotalLength = [uint64]($CurrentTotalLength + $ReadLength)
        if ($uintNewEntryLength -gt $DeclaredEntryLength -or
            $uintNewEntryLength -gt $script:uintCandidateHelperMaximumEntryByte -or
            $uintNewTotalLength -gt $script:uintCandidateHelperMaximumTotalByte) {
            & $script:scriptBlockStopCandidateHelperOperation `
                -Code $DiagnosticCode -Phase $Phase -Subreason 'actual-limit'
        }
        return [ordered]@{
            EntryLength = $uintNewEntryLength
            TotalLength = $uintNewTotalLength
        }
    }

    $script:scriptBlockInvokeCandidateArtifactExpansion = {
        param ([System.Collections.IDictionary]$RawParameters)

        # Snapshot presence and raw references per invocation. A second invocation
        # cannot replace values still in use by this invocation or its cleanup.
        $hashtableCandidateHelperBoundParameters = @{}
        foreach ($strParameterName in @(
                'CheckoutRoot', 'TrustedTemporaryRoot', 'DownloadDirectory',
                'CandidateDirectory', 'ExpectedDigest', 'ArtifactId', 'RunId', 'RunAttempt'
            )) {
            if ($RawParameters.ContainsKey($strParameterName)) {
                $hashtableCandidateHelperBoundParameters[$strParameterName] = $RawParameters[$strParameterName]
            }
        }
        $CheckoutRoot = $hashtableCandidateHelperBoundParameters['CheckoutRoot']
        $TrustedTemporaryRoot = $hashtableCandidateHelperBoundParameters['TrustedTemporaryRoot']
        $DownloadDirectory = $hashtableCandidateHelperBoundParameters['DownloadDirectory']
        $CandidateDirectory = $hashtableCandidateHelperBoundParameters['CandidateDirectory']
        $ExpectedDigest = $hashtableCandidateHelperBoundParameters['ExpectedDigest']
        $ArtifactId = $hashtableCandidateHelperBoundParameters['ArtifactId']
        $RunId = $hashtableCandidateHelperBoundParameters['RunId']
        $RunAttempt = $hashtableCandidateHelperBoundParameters['RunAttempt']
        Set-StrictMode -Version Latest

        $objArchiveStream = $null
        $objArchiveBuffer = $null
        $objZipArchive = $null
        $objPrimaryError = $null
        $objValidatedContext = $null
        $objCandidateState = $null
        $objCandidateRegistration = $null
        $strPhase = 'parameter'
        $hashtableDiagnostics = [ordered]@{
            CheckoutRoot = $null
            TrustedTemporaryRoot = $null
            DownloadDirectory = $null
            CandidateDirectory = $null
            ArchivePath = $null
            ExpectedDigest = $null
            ActualDigest = $null
            ArtifactId = 'unavailable'
            RunId = 'unavailable'
            RunAttempt = 'unavailable'
        }
        foreach ($strLabelName in @('ArtifactId', 'RunId', 'RunAttempt')) {
            if ($hashtableCandidateHelperBoundParameters.ContainsKey($strLabelName)) {
                $hashtableDiagnostics[$strLabelName] = 'invalid'
            }
        }

        try {
            foreach ($strRequiredParameter in @(
                    'CheckoutRoot',
                    'TrustedTemporaryRoot',
                    'DownloadDirectory',
                    'CandidateDirectory',
                    'ExpectedDigest'
                )) {
                if (-not $hashtableCandidateHelperBoundParameters.ContainsKey($strRequiredParameter)) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'parameter' -Phase 'parameter' -Subreason "$strRequiredParameter-missing"
                }
            }

            $strCheckoutRoot = & $script:scriptBlockAssertCandidateHelperRawString `
                -Value $CheckoutRoot -ParameterName 'CheckoutRoot' -IsLabel $false
            $strTrustedTemporaryRoot = & $script:scriptBlockAssertCandidateHelperRawString `
                -Value $TrustedTemporaryRoot -ParameterName 'TrustedTemporaryRoot' -IsLabel $false
            $strDownloadDirectory = & $script:scriptBlockAssertCandidateHelperRawString `
                -Value $DownloadDirectory -ParameterName 'DownloadDirectory' -IsLabel $false
            $strCandidateDirectory = & $script:scriptBlockAssertCandidateHelperRawString `
                -Value $CandidateDirectory -ParameterName 'CandidateDirectory' -IsLabel $false
            $strExpectedDigest = & $script:scriptBlockAssertCandidateHelperRawString `
                -Value $ExpectedDigest -ParameterName 'ExpectedDigest' -IsLabel $false
            if ($strExpectedDigest -cnotmatch '\A[0-9A-Fa-f]{64}\z') {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'parameter' -Phase 'parameter' -Subreason 'ExpectedDigest-grammar'
            }
            $hashtableDiagnostics.ExpectedDigest = $strExpectedDigest

            if ($hashtableCandidateHelperBoundParameters.ContainsKey('ArtifactId')) {
                $null = & $script:scriptBlockAssertCandidateHelperRawString `
                    -Value $ArtifactId -ParameterName 'ArtifactId' -IsLabel $true
                $hashtableDiagnostics.ArtifactId = $ArtifactId
            }
            if ($hashtableCandidateHelperBoundParameters.ContainsKey('RunId')) {
                $null = & $script:scriptBlockAssertCandidateHelperRawString `
                    -Value $RunId -ParameterName 'RunId' -IsLabel $true
                $hashtableDiagnostics.RunId = $RunId
            }
            if ($hashtableCandidateHelperBoundParameters.ContainsKey('RunAttempt')) {
                $null = & $script:scriptBlockAssertCandidateHelperRawString `
                    -Value $RunAttempt -ParameterName 'RunAttempt' -IsLabel $true
                $hashtableDiagnostics.RunAttempt = $RunAttempt
            }

            $strCheckoutPath = & $script:scriptBlockConvertToCandidateHelperNormalizedPath -Value $strCheckoutRoot -ParameterName 'CheckoutRoot'
            $strTrustedPath = & $script:scriptBlockConvertToCandidateHelperNormalizedPath -Value $strTrustedTemporaryRoot -ParameterName 'TrustedTemporaryRoot'
            $strDownloadPath = & $script:scriptBlockConvertToCandidateHelperNormalizedPath -Value $strDownloadDirectory -ParameterName 'DownloadDirectory'
            $strCandidatePath = & $script:scriptBlockConvertToCandidateHelperNormalizedPath -Value $strCandidateDirectory -ParameterName 'CandidateDirectory'
            $hashtableDiagnostics.CheckoutRoot = $strCheckoutPath
            $hashtableDiagnostics.TrustedTemporaryRoot = $strTrustedPath
            $hashtableDiagnostics.DownloadDirectory = $strDownloadPath
            $hashtableDiagnostics.CandidateDirectory = $strCandidatePath
            $strAuthenticatedRoot = [System.IO.Path]::GetDirectoryName($strCandidatePath)
            $strPhase = 'root'
            [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                    -LiteralPath $strCheckoutPath `
                    -Phase 'root' -DiagnosticRole 'checkout')
            [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                    -LiteralPath $strTrustedPath `
                    -Phase 'root' -DiagnosticRole 'trusted')
            $boolRootsEqual = [System.String]::Equals(
                $strCheckoutPath,
                $strTrustedPath,
                $script:objCandidateHelperPathComparison
            )
            $boolCheckoutContainsTrusted = & $script:scriptBlockTestCandidateHelperPathContained `
                -Root $strCheckoutPath `
                -Candidate $strTrustedPath
            $boolTrustedContainsCheckout = & $script:scriptBlockTestCandidateHelperPathContained `
                -Root $strTrustedPath `
                -Candidate $strCheckoutPath
            if ($boolRootsEqual -or $boolCheckoutContainsTrusted -or $boolTrustedContainsCheckout) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'root-invalid' -Phase 'root' -Subreason 'overlap'
            }

            # The checks above are string comparisons, so two different spellings of
            # the same directory pass them. Compare filesystem identity as well:
            # equal identity means the same directory, and finding one root's
            # identity anywhere in the other's ancestor chain means one contains the
            # other however it was spelled.
            $arrCheckoutIdentity = & $script:scriptBlockGetCandidateHelperIdentityChain `
                -LiteralPath $strCheckoutPath
            $arrTrustedIdentity = & $script:scriptBlockGetCandidateHelperIdentityChain `
                -LiteralPath $strTrustedPath
            if ($arrCheckoutIdentity.Count -gt 0 -and $arrTrustedIdentity.Count -gt 0 -and
                ($arrTrustedIdentity -ccontains $arrCheckoutIdentity[0] -or
                $arrCheckoutIdentity -ccontains $arrTrustedIdentity[0])) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'root-invalid' -Phase 'root' -Subreason 'overlap'
            }

            # Names and stored spellings are still names. Ask the filesystem where
            # the trusted root's contents can actually be seen, which settles every
            # aliasing mechanism at once and is the only one of these layers that
            # applies unchanged on both platforms.
            if (& $script:scriptBlockTestCandidateHelperRootsShareStorage `
                    -CheckoutPath $strCheckoutPath `
                    -TrustedPath $strTrustedPath `
                    -SentinelDirectory $strDownloadPath) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'root-invalid' -Phase 'root' -Subreason 'overlap'
            }

            # Identity comparison sees an alias of a root, but not an alias of a
            # directory below one: /b bound from /a/sub shares no inode with /a and
            # never lists /a as an ancestor. Resolving both roots through mount
            # topology exposes the subtree each one really occupies.
            $arrCheckoutMount = & $script:scriptBlockGetCandidateHelperMountResolvedPath `
                -LiteralPath $strCheckoutPath
            $arrTrustedMount = & $script:scriptBlockGetCandidateHelperMountResolvedPath `
                -LiteralPath $strTrustedPath
            if ($null -ne $arrCheckoutMount -and $null -ne $arrTrustedMount -and
                $arrCheckoutMount[0] -ceq $arrTrustedMount[0] -and
                ((& $script:scriptBlockTestCandidateHelperPathPrefix `
                        -Prefix $arrCheckoutMount[1] -Path $arrTrustedMount[1]) -or
                (& $script:scriptBlockTestCandidateHelperPathPrefix `
                    -Prefix $arrTrustedMount[1] -Path $arrCheckoutMount[1]))) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'root-invalid' -Phase 'root' -Subreason 'overlap'
            }

            $strPhase = 'containment'
            $boolTrustedContainsDownload = & $script:scriptBlockTestCandidateHelperPathContained `
                -Root $strTrustedPath `
                -Candidate $strDownloadPath
            $boolTrustedContainsCandidate = & $script:scriptBlockTestCandidateHelperPathContained `
                -Root $strTrustedPath `
                -Candidate $strCandidatePath
            $boolCheckoutContainsDownload = & $script:scriptBlockTestCandidateHelperPathContained `
                -Root $strCheckoutPath `
                -Candidate $strDownloadPath
            $boolCheckoutContainsCandidate = & $script:scriptBlockTestCandidateHelperPathContained `
                -Root $strCheckoutPath `
                -Candidate $strCandidatePath
            $boolTrustedContainsCandidateParent = & $script:scriptBlockTestCandidateHelperPathContained `
                -Root $strTrustedPath `
                -Candidate $strAuthenticatedRoot
            if (-not $boolTrustedContainsDownload -or
                -not $boolTrustedContainsCandidateParent -or
                -not $boolTrustedContainsCandidate -or
                $boolCheckoutContainsDownload -or
                $boolCheckoutContainsCandidate) {
                $strContainmentReason = 'relationship'
                $strOutsidePath = ''
                if (-not $boolTrustedContainsDownload) {
                    $strContainmentReason = 'download-outside'
                    $strOutsidePath = $strDownloadPath
                } elseif (-not $boolTrustedContainsCandidate) {
                    $strContainmentReason = 'candidate-outside'
                    $strOutsidePath = $strCandidatePath
                }
                if (-not $script:boolCandidateHelperIsWindows -and $strOutsidePath.Length -gt 0 -and
                    $strOutsidePath.StartsWith(
                        $strTrustedPath.TrimEnd($script:chrCandidateHelperDirectorySeparator) + $script:chrCandidateHelperDirectorySeparator,
                        [System.StringComparison]::OrdinalIgnoreCase)) {
                    $strContainmentReason = 'case-sensitive-outside'
                }
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'containment-invalid' -Phase 'containment' -Subreason $strContainmentReason
            }
            [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                    -LiteralPath $strAuthenticatedRoot `
                    -Phase 'containment' -DiagnosticRole 'candidate-parent')
            [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                    -LiteralPath $strDownloadPath `
                    -Phase 'containment' -DiagnosticRole 'download')

            # This private envelope preserves the source's captured evidence and
            # journal guards. Its root/download records describe observed paths;
            # they never authorize candidate cleanup to delete caller-owned paths.
            $listPrivateRecords = New-Object 'System.Collections.Generic.List[pscustomobject]'
            foreach ($hashtableRole in @(
                    @{ Kind = 'InvocationRootDirectory'; Path = $strAuthenticatedRoot; State = 'Created' },
                    @{ Kind = 'DownloadDirectory'; Path = $strDownloadPath; State = 'Created' },
                    @{ Kind = 'CandidateDirectory'; Path = $strCandidatePath; State = 'ExpectedAbsent' }
                )) {
                $objRecord = [pscustomobject][ordered]@{
                    SchemaVersion = [uint32]1
                    Sequence = [uint32]$listPrivateRecords.Count
                    Kind = [string]$hashtableRole.Kind
                    Path = [string]$hashtableRole.Path
                    ParentPath = [System.IO.Path]::GetDirectoryName($hashtableRole.Path)
                    LeafName = [System.IO.Path]::GetFileName($hashtableRole.Path)
                    ExpectedEntryType = [string]'Directory'
                    CreationPhase = [string]'context'
                    EntryState = [string]$hashtableRole.State
                    ContentLength = $null
                    ContentSha256 = $null
                }
                $objRecord.PSObject.TypeNames.Insert(0, $script:strCandidateHelperRecordTypeName)
                $listPrivateRecords.Add($objRecord)
            }
            $objCandidateState = & $script:scriptBlockNewCandidateOwnershipState -TrustedRoot $strTrustedPath -CandidateParent $strAuthenticatedRoot -CandidatePath $strCandidatePath
            $objCandidateRegistration = & $script:scriptBlockAssertCandidateOwnershipState -Value $objCandidateState
            $Context = [pscustomobject][ordered]@{
                SchemaVersion = [uint32]1
                ContextScriptVersion = $script:versionCandidateExpectedContext
                InvocationId = $objCandidateState.CandidateId
                DiagnosticLabel = [string]'unavailable'
                TrustedParentPath = [string]$strTrustedPath
                InvocationRootPath = [string]$strAuthenticatedRoot
                DownloadDirectoryPath = [string]$strDownloadPath
                CandidatePath = [string]$strCandidatePath
                LifecycleState = [string]'Active'
                NextSequence = [uint32]3
                OwnershipJournal = [object[]]@($listPrivateRecords.ToArray())
            }
            $Context.PSObject.TypeNames.Insert(0, $script:strCandidateHelperContextTypeName)
            $objCandidateRegistration.PrivateEnvelope = $Context
            $objValidatedContext = $Context
            $objAuthenticatedJournal = & $script:scriptBlockAssertCandidateHelperContext -ContextValue $Context
            $uintAuthenticatedSequence = [uint32]$objAuthenticatedJournal.Count
            $strAuthenticatedCandidateEntryState = 'ExpectedAbsent'
            $listSnapshots = New-Object 'System.Collections.Generic.List[pscustomobject]'
            foreach ($objRecord in $objAuthenticatedJournal) {
                $listSnapshots.Add([pscustomobject]@{
                        Sequence = [uint32]$objRecord.Sequence
                        Path = [string]$objRecord.Path
                        ParentPath = [string]$objRecord.ParentPath
                        LeafName = [string]$objRecord.LeafName
                    })
            }
            $objAuthenticatedRootSnapshot = $listSnapshots[0]
            $objAuthenticatedDownloadSnapshot = $listSnapshots[1]
            $objAuthenticatedCandidateSnapshot = $listSnapshots[2]

            $strPhase = 'download'
            # Round 64 (Codex): re-prove the authenticated journal is still installed
            # before any download work. The archive open and hash below can reach
            # cleanup, and until the download record append there is no journal-
            # current check -- a same-session swap in that window would let the
            # append refuse 'journal-swapped' with the archive already read and
            # unjournaled in the decoy, then rollback would validate the decoy, meet
            # the archive as an unexpected download-directory entry, and retain the
            # issued tree. The same guard the destination create, each file create,
            # and the append already run, at this phase boundary too.
            & $script:scriptBlockAssertCandidateHelperJournalCurrent `
                -ContextValue $Context `
                -JournalValue $objAuthenticatedJournal `
                -NextSequenceValue $uintAuthenticatedSequence `
                -PhaseValue $strPhase
            # Two is all this needs: one says conforming, two says refuse, and any
            # further path costs memory to reach the same verdict.
            $arrDownloadEntries = [string[]]@(
                & $script:scriptBlockGetCandidateHelperEntry -LiteralPath $strDownloadPath `
                    -Phase 'download' -MaximumEntry 2
            )
            if ($arrDownloadEntries.Count -ne 1) {
                $strEntryCountReason = if ($arrDownloadEntries.Count -gt 1) { 'extra-entry' } else { 'entry-count' }
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'download-invalid' -Phase 'download' -Subreason $strEntryCountReason
            }
            # This is the only path that ends up journaled without this code having
            # chosen its name: every other one is a fixed leaf or GetRandomFileName
            # output, and every caller-supplied root is checked at parameter
            # validation. It was adopted unchecked, and the journal's own rule about
            # what a stored path may contain was therefore first applied to it after
            # it had been recorded -- by which point cleanup had to consult a
            # journal holding a path it refuses. Measured on 'build[1].zip': refused
            # at journaling, correctly, and then cleanup unable to remove what it
            # had already created, reporting Invalid with retained=0 while the
            # invocation root stayed on disk.
            #
            # The validation is not a step that happens to come first. An earlier
            # revision made it one, and leaving an unreachable copy at the old
            # location while moving the real call after the metadata read satisfied
            # both the source-order pin and the behavioural probe -- 115 records,
            # zero failures, with the leaf touched before it was checked. So the
            # validated value is the only value: $strArchivePath is produced by the
            # validator and by nothing else, and every use below is therefore of a
            # path that has been through it.
            $strArchivePath = [string](& $script:scriptBlockGetCandidateHelperValidatedDownloadPath `
                    -Candidate $arrDownloadEntries[0])
            $hashtableDiagnostics.ArchivePath = $strArchivePath
            $uintArchiveMetadataLength = & $script:scriptBlockAssertCandidateHelperOrdinaryFileMetadata `
                -LiteralPath $strArchivePath `
                -Phase 'download'
            if ($uintArchiveMetadataLength -gt $script:uintCandidateHelperMaximumArchiveByte) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'download-invalid' -Phase 'download' -Subreason 'archive-limit'
            }
            [void](& $script:scriptBlockAssertCandidateHelperEntryAbsent `
                    -ParentPath $strAuthenticatedRoot `
                    -ExpectedPath $strCandidatePath `
                    -Phase 'destination')

            if (@($objAuthenticatedJournal | Where-Object { $_.Kind -eq 'DownloadFile' }).Count -ne 0) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'parameter' -Phase 'parameter' -Subreason 'download-already-journaled'
            }

            try {
                $objArchiveStream = New-Object System.IO.FileStream(
                    $strArchivePath,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::Read
                )
            } catch {
                $objOpenFailure = $_.Exception.GetBaseException()
                $strOpenReason = if ($objOpenFailure -is [System.IO.FileNotFoundException] -or
                    $objOpenFailure -is [System.IO.DirectoryNotFoundException]) {
                    'archive-missing'
                } elseif ($objOpenFailure -is [System.UnauthorizedAccessException] -or
                    $objOpenFailure -is [System.IO.IOException]) {
                    'entry-unreadable'
                } else { 'archive-open' }
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'download-invalid' -Phase 'download' -Subreason $strOpenReason
            }
            $strPhase = 'digest'
            # One read of Length, held. The ceiling below is worth nothing if the
            # allocation asks the stream again: on Unix the handle observes in-place
            # growth -- this file says so twenty lines down, and the code did not
            # honour it. Measured: a file admitted at 1,024 bytes, grown by another
            # writer through a second handle, reported 268,436,480 bytes at the
            # allocation and would have taken 256 MiB from a candidate that passed a
            # 32 MiB ceiling. Every later use is this variable, and the harness
            # refuses a second read of the stream's Length in this function.
            $uintArchiveByteCount = [uint64]$objArchiveStream.Length
            if (-not $objArchiveStream.CanRead -or -not $objArchiveStream.CanSeek -or
                $uintArchiveByteCount -ne $uintArchiveMetadataLength -or
                $uintArchiveByteCount -gt $script:uintCandidateHelperMaximumArchiveByte) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'archive-invalid' -Phase 'archive' -Subreason 'stream'
            }
            # Read the archive exactly once into a private buffer, then let the file
            # go. Holding the handle open across the hash and the parse was the
            # contract until issue #146 amendment 1, and it does not do what it
            # looks like it does: FileShare.Read is a Windows sharing concept that
            # .NET does not enforce on Unix, so the handle never froze the file.
            # Measured on Ubuntu: hash 20a7ec84..., an external dd conv=notrunc on
            # the same path, then f5a5fd42... re-read through that same handle. The
            # digest authenticated the original bytes while the directory walk and
            # every entry read saw the modified ones -- and because the evidence
            # pass and the extraction pass both read after the change, comparing
            # them to each other agreed too. Every check passed on a candidate that
            # was not what was authenticated.
            #
            # A private buffer cannot be edited by anyone else, so the bytes hashed
            # below and the bytes parsed afterwards are the same bytes by
            # construction rather than by assumption. The 32 MiB ceiling already
            # checked above is what makes this affordable.
            $arrArchiveByte = New-Object byte[] ([int]$uintArchiveByteCount)
            $intArchiveFilled = 0
            while ($intArchiveFilled -lt $arrArchiveByte.Length) {
                $intArchiveRead = $objArchiveStream.Read(
                    $arrArchiveByte,
                    $intArchiveFilled,
                    $arrArchiveByte.Length - $intArchiveFilled
                )
                if ($intArchiveRead -le 0) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'archive-invalid' -Phase 'archive' -Subreason 'stream'
                }
                $intArchiveFilled += $intArchiveRead
            }
            # The file has given up everything it is going to give up. Releasing it
            # here means no later phase can read the path a second time even by
            # accident, which is the property the amendment asks for.
            $objArchiveStream.Dispose()
            $objArchiveStream = $null
            $objArchiveBuffer = New-Object System.IO.MemoryStream(, $arrArchiveByte)
            $objArchiveSha256 = [System.Security.Cryptography.SHA256]::Create()
            try {
                $strActualDigest = ([System.BitConverter]::ToString(
                        $objArchiveSha256.ComputeHash($arrArchiveByte, 0, $arrArchiveByte.Length)
                    ) -replace '-', '').ToLowerInvariant()
            } finally {
                $objArchiveSha256.Dispose()
            }
            if ($strActualDigest -cnotmatch '^[0-9a-f]{64}$') {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'archive-invalid' -Phase 'digest' -Subreason 'hash-shape'
            }
            $hashtableDiagnostics.ActualDigest = $strActualDigest

            $objDownloadRecord = & $script:scriptBlockNewCandidateHelperRecord `
                -Sequence $uintAuthenticatedSequence `
                -Kind 'DownloadFile' `
                -Path $strArchivePath `
                -ParentPath $strDownloadPath `
                -LeafName ([System.IO.Path]::GetFileName($strArchivePath)) `
                -CreationPhase 'download' `
                -ContentLength ([uint64]$arrArchiveByte.Length) `
                -ContentSha256 $strActualDigest
            $objAuthenticatedJournal = & $script:scriptBlockAddCandidateHelperRecord `
                -ContextValue $Context `
                -Record $objDownloadRecord `
                -JournalValue $objAuthenticatedJournal `
                -NextSequenceValue $uintAuthenticatedSequence `
                -PhaseValue $strPhase
            # The captured counter advances with the journal it describes, so the
            # second record is numbered from the first rather than from a field
            # the caller could have moved in between.
            $uintAuthenticatedSequence = [uint32]($uintAuthenticatedSequence + 1)
            [void](& $script:scriptBlockAssertCandidateHelperContext -ContextValue $Context)

            if (-not [System.String]::Equals(
                    $strActualDigest,
                    $strExpectedDigest,
                    [System.StringComparison]::OrdinalIgnoreCase
                )) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'digest-mismatch' -Phase 'digest' -Subreason 'mismatch'
            }

            # The archive is obtained from a helper that cannot hand one back
            # without having bounded the central directory first, so the ordering
            # below is a data dependency rather than a convention someone has to
            # remember. It used to be three statements in a row, and the order was
            # load-bearing with nothing enforcing it.
            $strPhase = 'archive'
            $objZipArchive = & $script:scriptBlockOpenCandidateHelperValidatedArchive `
                -Buffer $objArchiveBuffer

            $strPhase = 'manifest'
            # This loop bounds nothing, and an earlier revision of this comment
            # claimed it did -- "the enumerator yields entries one at a time, so a
            # fifth entry stops the walk", called a second independent stop.
            # ZipArchive.Entries is a ReadOnlyCollection whose getter reads the
            # entire central directory before the first iteration runs, so breaking
            # at five saves nothing. Measured on a 150000-entry archive of 12.66 MiB,
            # comfortably inside the 32 MiB ceiling: 150000 objects and 50.00 MiB of
            # managed heap on .NET 8, 52.61 MiB on .NET 10, with the break in place.
            #
            # The bound that actually holds is the central-directory count read from
            # the trailer, which is why the archive can only be obtained from a
            # helper that applies it first. The break stays because taking five
            # references instead of 150000 is still worth having once the bytes are
            # already parsed; it is not a second line of defence, and calling it one
            # is what made the ordering above look optional.
            $listZipEntries = New-Object 'System.Collections.Generic.List[System.IO.Compression.ZipArchiveEntry]'
            try {
                # An explicit getter preserves the reader's exception. PowerShell
                # property access suppresses it and would masquerade as zero entries.
                $objMaterializedEntries = $objZipArchive.get_Entries()
            } catch {
                $objReaderError = $_.Exception
                $boolInvalidData = $false
                for ($intErrorDepth = 0; $intErrorDepth -lt 4 -and $null -ne $objReaderError; $intErrorDepth++) {
                    if ($objReaderError -is [System.IO.InvalidDataException]) { $boolInvalidData = $true; break }
                    $objReaderError = $objReaderError.InnerException
                }
                if ($boolInvalidData -and (& $script:scriptBlockTestCandidateHelperNegativeZip64Length -ArchiveByte $arrArchiveByte)) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'negative-length'
                }
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
            }
            foreach ($objZipEntry in $objMaterializedEntries) {
                $listZipEntries.Add($objZipEntry)
                if ($listZipEntries.Count -gt 4) {
                    break
                }
            }
            $arrZipEntries = [object[]]@($listZipEntries.ToArray())
            if ($arrZipEntries.Count -ne 4) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-count'
            }
            $objOrdinalNames = New-Object 'System.Collections.Generic.HashSet[string]' (
                [System.StringComparer]::Ordinal
            )
            $objIgnoreCaseNames = New-Object 'System.Collections.Generic.HashSet[string]' (
                [System.StringComparer]::OrdinalIgnoreCase
            )
            $hashtableEntryMap = @{}
            $uintDeclaredTotal = [uint64]0
            foreach ($objEntry in $arrZipEntries) {
                $strEntryName = [string]$objEntry.FullName
                if (-not $objOrdinalNames.Add($strEntryName)) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'duplicate-exact'
                }
                if (-not $objIgnoreCaseNames.Add($strEntryName)) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'duplicate-case'
                }
                if ($strEntryName.Length -eq 0 -or $strEntryName.IndexOf('/') -ge 0 -or
                    $strEntryName.IndexOf('\') -ge 0 -or $strEntryName -match '^[A-Za-z]:' -or
                    $objEntry.Name.Length -eq 0 -or
                    $strEntryName -cnotin $script:arrCandidateHelperExpectedName) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-name'
                }
                $longDeclaredLength = [long]$objEntry.Length
                $uintDeclaredTotal = & $script:scriptBlockAddCandidateHelperDeclaredLength `
                    -CurrentTotal $uintDeclaredTotal `
                    -DeclaredLength $longDeclaredLength
                $hashtableEntryMap[$strEntryName] = $objEntry
            }
            foreach ($strExpectedName in $script:arrCandidateHelperExpectedName) {
                if (-not $hashtableEntryMap.ContainsKey($strExpectedName)) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'missing-entry'
                }
            }

            # Acquire immutable content evidence while the one trusted archive stream
            # remains held. A candidate-file ownership record is not published until
            # both its exact length and SHA-256 are known.
            $hashtableEntryEvidence = @{}
            $uintEvidenceTotal = [uint64]0
            foreach ($strExpectedName in $script:arrCandidateHelperExpectedName) {
                $objEvidenceEntry = $hashtableEntryMap[$strExpectedName]
                $objEvidenceStream = $null
                $objEvidenceSha256 = $null
                try {
                    $objEvidenceStream = $objEvidenceEntry.Open()
                    $objEvidenceSha256 = [System.Security.Cryptography.SHA256]::Create()
                    $arrEvidenceBuffer = New-Object byte[] $script:intCandidateHelperBufferSize
                    $uintEvidenceLength = [uint64]0
                    while ($true) {
                        $intEvidenceRead = $objEvidenceStream.Read(
                            $arrEvidenceBuffer,
                            0,
                            $arrEvidenceBuffer.Length
                        )
                        if ($intEvidenceRead -eq 0) {
                            break
                        }
                        $uintEvidenceRead = [uint64]$intEvidenceRead
                        $hashtableNewEvidenceLength = & $script:scriptBlockAddCandidateHelperActualLength `
                            -CurrentEntryLength $uintEvidenceLength `
                            -CurrentTotalLength $uintEvidenceTotal `
                            -ReadLength $uintEvidenceRead `
                            -DeclaredEntryLength ([uint64]$objEvidenceEntry.Length) `
                            -Phase 'manifest' `
                            -DiagnosticCode 'manifest-invalid'
                        [void]$objEvidenceSha256.TransformBlock(
                            $arrEvidenceBuffer,
                            0,
                            $intEvidenceRead,
                            $null,
                            0
                        )
                        $uintEvidenceLength = $hashtableNewEvidenceLength.EntryLength
                        $uintEvidenceTotal = $hashtableNewEvidenceLength.TotalLength
                    }
                    if ($uintEvidenceLength -ne [uint64]$objEvidenceEntry.Length) {
                        & $script:scriptBlockStopCandidateHelperOperation `
                            -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'inconsistent-length'
                    }
                    [void]$objEvidenceSha256.TransformFinalBlock((New-Object byte[] 0), 0, 0)
                    $strEvidenceSha256 = ([System.BitConverter]::ToString(
                            $objEvidenceSha256.Hash
                        ) -replace '-', '').ToLowerInvariant()
                    $hashtableEntryEvidence[$strExpectedName] = [ordered]@{
                        Length = [uint64]$uintEvidenceLength
                        Sha256 = [string]$strEvidenceSha256
                    }
                } catch {
                    if ($_.Exception.Data.Contains('TerraformStyleGuideDiagnosticCode')) {
                        throw
                    }
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'manifest-invalid' -Phase 'manifest' -Subreason 'entry-read'
                } finally {
                    if ($null -ne $objEvidenceSha256) {
                        $objEvidenceSha256.Dispose()
                    }
                    if ($null -ne $objEvidenceStream) {
                        $objEvidenceStream.Dispose()
                    }
                }
            }

            $strPhase = 'destination'
            [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                    -LiteralPath $strCheckoutPath `
                    -Phase 'destination')
            [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                    -LiteralPath $strTrustedPath `
                    -Phase 'destination')
            [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                    -LiteralPath $strAuthenticatedRoot `
                    -Phase 'destination')
            [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                    -LiteralPath $strDownloadPath `
                    -Phase 'destination')
            [void](& $script:scriptBlockAssertCandidateHelperEntryAbsent `
                    -ParentPath $strAuthenticatedRoot `
                    -ExpectedPath $strCandidatePath `
                    -Phase 'destination')

            # Round 61 (Codex F2): re-prove the caller's context still holds the
            # authenticated journal, at the authenticated sequence, before the
            # irreversible create. The append helper has enforced this at every
            # record publication since round 52, but the destination create sat
            # between the download append and the first file append with no such
            # check -- a same-session swap in that window created the candidate
            # directory while the live context pointed at a decoy journal, and the
            # later append's refusal then handed rollback the decoy, which met the
            # real directory as an entry no journal described and left it on disk.
            & $script:scriptBlockAssertCandidateHelperJournalCurrent `
                -ContextValue $Context `
                -JournalValue $objAuthenticatedJournal `
                -NextSequenceValue $uintAuthenticatedSequence `
                -PhaseValue $strPhase
            # Round 54: the authenticated journal, not the caller's current one.
            # Fixing EE6 moved the ownership APPEND onto the capture; the record is
            # still selected here so the create can mark it, but the STATE that
            # gates the create is the string captured at authentication (round 61
            # F1 above), not this record's live field -- which a same-session writer
            # can flip after authentication to force the retention described there.
            # Round 63/64 (Codex): select the record by its authenticated sequence
            # and re-prove EVERY invariant field against the snapshot captured at
            # authentication before the create. Round 63 re-proved Kind, Sequence and
            # Path; a same-session writer that instead flipped ParentPath, LeafName,
            # ExpectedEntryType, CreationPhase, SchemaVersion or the content fields
            # slipped past that guard, so the create ran and the final context
            # assertion rejected the record, retaining the issued tree. The check is
            # factored into scriptBlockAssertCandidateHelperRecordUnchanged so its
            # field coverage is exercised in isolation by the harness.
            $objCandidateDirectoryRecord =
            $objAuthenticatedJournal[$objAuthenticatedCandidateSnapshot.Sequence]
            & $script:scriptBlockAssertCandidateHelperRecordUnchanged `
                -Record $objCandidateDirectoryRecord `
                -Snapshot $objAuthenticatedCandidateSnapshot `
                -PhaseValue 'destination'
            if ($strAuthenticatedCandidateEntryState -cne 'ExpectedAbsent') {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'destination-invalid' -Phase 'destination' -Subreason 'candidate-state'
            }
            # Round 71 (Codex P2): re-prove the two PRE-EXISTING records the manager
            # issued -- the seq-0 root and seq-1 download directories -- against the
            # snapshots captured at authentication, immediately before the create,
            # with the guard the candidate record uses (generalised above). Each is
            # selected by its authenticated sequence, its Kind pinned to its own value,
            # and its EntryState pinned to 'Created' -- both are on disk before this
            # expansion runs. Round 64 re-proved the candidate record only; a
            # same-session writer that instead flipped a pre-existing record after
            # authentication (EntryState 'Created' -> 'Deleted' is the reproduced
            # attack) slipped past every pre-create guard, the create ran, and only the
            # post-append context assertion rejected the record -- handing rollback a
            # journal the manager refuses and retaining the issued tree. Refused here,
            # before the irreversible create, in the same code/subreason class the
            # candidate record uses.
            $objRootDirectoryRecord =
            $objAuthenticatedJournal[$objAuthenticatedRootSnapshot.Sequence]
            & $script:scriptBlockAssertCandidateHelperRecordUnchanged `
                -Record $objRootDirectoryRecord `
                -Snapshot $objAuthenticatedRootSnapshot `
                -ExpectedKind 'InvocationRootDirectory' `
                -ExpectedEntryState 'Created' `
                -PhaseValue 'destination'
            $objDownloadDirectoryRecord =
            $objAuthenticatedJournal[$objAuthenticatedDownloadSnapshot.Sequence]
            & $script:scriptBlockAssertCandidateHelperRecordUnchanged `
                -Record $objDownloadDirectoryRecord `
                -Snapshot $objAuthenticatedDownloadSnapshot `
                -ExpectedKind 'DownloadDirectory' `
                -ExpectedEntryState 'Created' `
                -PhaseValue 'destination'
            $null = [System.IO.Directory]::CreateDirectory($strCandidatePath)
            $objCandidateDirectoryRecord.CreationPhase = 'destination'
            $objCandidateDirectoryRecord.EntryState = 'Created'
            & $script:scriptBlockPublishCandidateOwnership -Registration $objCandidateRegistration -PrivateEnvelope $Context
            [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                    -LiteralPath $strCandidatePath `
                    -Phase 'destination')
            # The absence check a few lines up proved this name was free, and
            # CreateDirectory should therefore have made it -- but it returns the
            # same thing either way, so an empty directory placed here in between
            # would be adopted silently and extracted into. Requiring it to be
            # empty is the same evidence the context manager uses for the roots it
            # creates: it cannot expose an empty squatter, and it does refuse a
            # directory that already holds anything, which extraction would
            # otherwise write alongside.
            $arrDestinationEntries = [string[]]@(
                & $script:scriptBlockGetCandidateHelperEntry -LiteralPath $strCandidatePath `
                    -Phase 'destination' -MaximumEntry 1
            )
            if ($arrDestinationEntries.Count -ne 0) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'destination-invalid' -Phase 'destination' -Subreason 'pre-journal-populated'
            }

            $strPhase = 'extraction'
            # Every output is created by PATH, and a path is resolved fresh by the
            # operating system on each call. The proof that this directory is
            # ordinary and link-free was made once, above, before any output
            # existed; four creates then followed it with nothing re-checked in
            # between. A competing writer that replaces the directory with a link
            # inside that window redirects all four, and FileMode.CreateNew does not
            # object -- it asks whether the leaf exists, not where the parent leads.
            # Reproduced by fault injection on both runtimes: four files created in
            # an attacker-named directory outside trusted storage, with the only
            # complaint arriving in the post-extraction phase, after every write.
            #
            # Closing this needs the create itself to be relative to a directory
            # handle opened with no-follow semantics, which portable .NET does not
            # expose and Windows PowerShell 5.1 cannot reach without P/Invoke. What
            # is available is to stop trusting one proof for four writes: the
            # identity of this directory is captured here, re-proven immediately
            # before each create, and compared immediately after it. The window
            # shrinks from four creates to one, and the first redirected file is the
            # last -- detected in the extraction phase, where the journal still
            # describes what happened, instead of after the fact.
            #
            # Identity rather than another envelope walk, and the leaf's identity
            # rather than the whole chain. An envelope check answers "is this a link
            # now" and not "is this the same directory it was", so renaming the
            # directory away and creating an ordinary one in its place would pass
            # it. The ancestors, meanwhile, were settled before the loop and re-
            # asking them per file cost a stat process per component: measured at
            # 376 ms to 643 ms per expansion on .NET 8 and 348 ms to 648 ms on
            # .NET 10, against a defect the contract's own non-goals exclude. What
            # changes here is the leaf, so the leaf is what is re-asked.
            #
            # The residual is stated rather than implied: an ancestor swapped inside
            # the loop is not caught by this, and the pre-loop envelope proof is what
            # stands behind those.
            $strCandidateIdentity = [string](
                & $script:scriptBlockGetCandidateHelperEntryIdentity `
                    -LiteralPath $strCandidatePath -Phase 'extraction'
            )
            $scriptBlockAssertCandidateStillSame = {
                if ([string](& $script:scriptBlockGetCandidateHelperEntryIdentity `
                            -LiteralPath $strCandidatePath -Phase 'extraction') -cne
                    $strCandidateIdentity) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'extraction-invalid' -Phase 'extraction' -Subreason 'identity'
                }
            }
            $uintActualTotal = [uint64]0
            foreach ($strExpectedName in $script:arrCandidateHelperExpectedName) {
                $objEntry = $hashtableEntryMap[$strExpectedName]
                $hashtableExpectedEvidence = $hashtableEntryEvidence[$strExpectedName]
                $strDestinationPath = [System.IO.Path]::GetFullPath(
                    [System.IO.Path]::Combine($strCandidatePath, $strExpectedName)
                )
                if (-not (& $script:scriptBlockTestCandidateHelperPathContained `
                            -Root $strCandidatePath `
                            -Candidate $strDestinationPath)) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'extraction-invalid' -Phase 'extraction' -Subreason 'destination-containment'
                }
                [void](& $script:scriptBlockAssertCandidateHelperEntryAbsent `
                        -ParentPath $strCandidatePath `
                        -ExpectedPath $strDestinationPath `
                        -Phase 'extraction')

                # Immediately before this create, and again immediately after it.
                # Neither placement is redundant: the first refuses a redirection
                # that is already in place, and the second catches one that lands in
                # the gap this cannot close, before the next output is written.
                & $scriptBlockAssertCandidateStillSame

                # Round 63 (Codex): re-prove the caller's context still holds the
                # authenticated journal at the authenticated sequence immediately
                # before the irreversible create -- the same guard the directory
                # create and the record append already run. Without it the file was
                # created first and the append's journal-current check refused only
                # afterward, so a same-session swap in this window left the file on
                # disk while the append refused 'journal-swapped' and rollback
                # validated the decoy: the directory case this file already fixed,
                # carried to the file create it was never applied to.
                & $script:scriptBlockAssertCandidateHelperJournalCurrent `
                    -ContextValue $Context `
                    -JournalValue $objAuthenticatedJournal `
                    -NextSequenceValue $uintAuthenticatedSequence `
                    -PhaseValue $strPhase

                $objDestinationStream = $null
                $objEntryStream = $null
                $objEntrySha256 = $null
                $objFileRecord = $null
                $uintEntryActual = [uint64]0
                $boolEntryHashFinalized = $false
                try {
                    $objDestinationStream = New-Object System.IO.FileStream(
                        $strDestinationPath,
                        [System.IO.FileMode]::CreateNew,
                        [System.IO.FileAccess]::Write,
                        [System.IO.FileShare]::None
                    )
                    # Journaled on the call that created it, before the check that
                    # can reject it. This file already exists by the time the
                    # identity re-proof runs, so a record written afterwards is
                    # written only when that proof passes -- and when it fails,
                    # which is exactly the case the proof exists for, the file is
                    # on disk with nothing describing it. Cleanup then meets an
                    # unexpected candidate entry it cannot account for, and a
                    # redirected file can be left outside the trusted tree while
                    # the comment above claims the journal describes what happened.
                    #
                    # This is the directory rule, applied to the file case it was
                    # never carried to: ownership is claimed on the call that may
                    # have created the entry, not after later checks approve of it.
                    # The reasoning is written out at the invocation-root creation
                    # in the context manager and was true here all along.
                    $objFileRecord = & $script:scriptBlockNewCandidateHelperRecord `
                        -Sequence $uintAuthenticatedSequence `
                        -Kind 'CandidateFile' `
                        -Path $strDestinationPath `
                        -ParentPath $strCandidatePath `
                        -LeafName $strExpectedName `
                        -CreationPhase 'extraction' `
                        -ContentLength ([uint64]0) `
                        -ContentSha256 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
                    $objAuthenticatedJournal = & $script:scriptBlockAddCandidateHelperRecord `
                        -ContextValue $Context `
                        -Record $objFileRecord `
                        -JournalValue $objAuthenticatedJournal `
                        -NextSequenceValue $uintAuthenticatedSequence `
                        -PhaseValue $strPhase
                    # The captured counter advances with the journal it describes, so the
                    # second record is numbered from the first rather than from a field
                    # the caller could have moved in between.
                    $uintAuthenticatedSequence = [uint32]($uintAuthenticatedSequence + 1)
                    & $script:scriptBlockPublishCandidateOwnership -Registration $objCandidateRegistration -PrivateEnvelope $Context
                    & $scriptBlockAssertCandidateStillSame

                    $objEntryStream = $objEntry.Open()
                    $objEntrySha256 = [System.Security.Cryptography.SHA256]::Create()
                    $arrBuffer = New-Object byte[] $script:intCandidateHelperBufferSize
                    while ($true) {
                        $intRead = $objEntryStream.Read($arrBuffer, 0, $arrBuffer.Length)
                        if ($intRead -eq 0) {
                            break
                        }
                        $uintRead = [uint64]$intRead
                        $hashtableNewActualLength = & $script:scriptBlockAddCandidateHelperActualLength `
                            -CurrentEntryLength $uintEntryActual `
                            -CurrentTotalLength $uintActualTotal `
                            -ReadLength $uintRead `
                            -DeclaredEntryLength ([uint64]$objEntry.Length) `
                            -Phase 'extraction' `
                            -DiagnosticCode 'extraction-invalid'
                        $objDestinationStream.Write($arrBuffer, 0, $intRead)
                        [void]$objEntrySha256.TransformBlock($arrBuffer, 0, $intRead, $null, 0)
                        $uintEntryActual = $hashtableNewActualLength.EntryLength
                        $uintActualTotal = $hashtableNewActualLength.TotalLength
                    }
                    if ($uintEntryActual -ne [uint64]$objEntry.Length -or
                        $uintEntryActual -ne [uint64]$hashtableExpectedEvidence.Length) {
                        & $script:scriptBlockStopCandidateHelperOperation `
                            -Code 'extraction-invalid' -Phase 'extraction' -Subreason 'actual-declared-mismatch'
                    }
                    [void]$objEntrySha256.TransformFinalBlock((New-Object byte[] 0), 0, 0)
                    $boolEntryHashFinalized = $true
                    $strEntrySha256 = (
                        [System.BitConverter]::ToString($objEntrySha256.Hash) -replace '-', ''
                    ).ToLowerInvariant()
                    if ($strEntrySha256 -cne [string]$hashtableExpectedEvidence.Sha256) {
                        & $script:scriptBlockStopCandidateHelperOperation `
                            -Code 'extraction-invalid' -Phase 'extraction' -Subreason 'content-changed'
                    }
                    $objDestinationStream.Flush($true)
                } catch {
                    if ($null -ne $objEntryStream) {
                        $objEntryStream.Dispose()
                        $objEntryStream = $null
                    }
                    if ($null -ne $objDestinationStream) {
                        $objDestinationStream.Dispose()
                        $objDestinationStream = $null
                    }
                    throw
                } finally {
                    if ($null -ne $objEntrySha256) {
                        # The private journal records bytes this invocation actually
                        # wrote. A safe partial file can then be proved and removed;
                        # an ambiguous write or external change fails that proof.
                        if (-not $boolEntryHashFinalized) {
                            [void]$objEntrySha256.TransformFinalBlock((New-Object byte[] 0), 0, 0)
                        }
                        if ($null -ne $objFileRecord) {
                            $objFileRecord.ContentLength = [uint64]$uintEntryActual
                            $objFileRecord.ContentSha256 = (
                                [System.BitConverter]::ToString($objEntrySha256.Hash) -replace '-', ''
                            ).ToLowerInvariant()
                        }
                        $objEntrySha256.Dispose()
                    }
                    if ($null -ne $objEntryStream) {
                        $objEntryStream.Dispose()
                    }
                    if ($null -ne $objDestinationStream) {
                        $objDestinationStream.Dispose()
                    }
                }
            }

            $strPhase = 'post-extraction'
            [void](& $script:scriptBlockAssertCandidateHelperDirectoryEnvelope `
                    -LiteralPath $strCandidatePath `
                    -Phase 'post-extraction')
            $arrCandidateEntries = [string[]]@(
                & $script:scriptBlockGetCandidateHelperEntry -LiteralPath $strCandidatePath `
                    -Phase 'post-extraction' -MaximumEntry 5
            )
            if ($arrCandidateEntries.Count -ne 4) {
                & $script:scriptBlockStopCandidateHelperOperation `
                    -Code 'post-extraction-invalid' -Phase 'post-extraction' -Subreason 'entry-count'
            }
            foreach ($strExpectedName in $script:arrCandidateHelperExpectedName) {
                $strDestinationPath = [System.IO.Path]::GetFullPath(
                    [System.IO.Path]::Combine($strCandidatePath, $strExpectedName)
                )
                if (-not (& $script:scriptBlockTestCandidateHelperEntryPresent `
                            -EntryList $arrCandidateEntries `
                            -ExpectedPath $strDestinationPath)) {
                    & $script:scriptBlockStopCandidateHelperOperation `
                        -Code 'post-extraction-invalid' -Phase 'post-extraction' -Subreason 'missing-entry'
                }
                # This site supplies the EXPECTED length and digest that the
                # extracted bytes are validated against, so whoever chooses those
                # two values decides what the check means.
                #
                # An earlier round moved this read off $Context.OwnershipJournal and
                # onto the authenticated array, and the comment here claimed the
                # swap was thereby closed. It was not. Authenticating the array
                # fixed WHICH ARRAY is read and left WHAT IS IN IT alone -- measured:
                #
                #   array reference authenticated        : True
                #   record[0] same object via both paths : True
                #   after a caller-side write, the field read through the
                #   AUTHENTICATED array shows the caller's value
                #   array reference check still passes    : True
                #
                # The records inside the authenticated array are the same objects
                # the caller still holds, so a write to ContentSha256 still chooses
                # what the output is compared against, and the reference-identity
                # check passes throughout because the array itself never changed.
                # Reference identity of a container says nothing about its contents.
                #
                # The expected values now come from the evidence this code built
                # from the archive it had already authenticated, which the caller
                # never holds a reference to.
                $hashtablePostEvidence = $hashtableEntryEvidence[$strExpectedName]
                [void](& $script:scriptBlockReadCandidateHelperValidatedFile `
                        -LiteralPath $strDestinationPath `
                        -ExpectedLength ([uint64]$hashtablePostEvidence.Length) `
                        -ExpectedSha256 ([string]$hashtablePostEvidence.Sha256))
            }

            [void](& $script:scriptBlockAssertCandidateHelperContext -ContextValue $Context)
        } catch {
            $objPrimaryError = $_
        } finally {
            if ($null -ne $objZipArchive) {
                $objZipArchive.Dispose()
            }
            if ($null -ne $objArchiveBuffer) {
                $objArchiveBuffer.Dispose()
            }
            if ($null -ne $objArchiveStream) {
                $objArchiveStream.Dispose()
            }
        }

        if ($null -ne $objCandidateRegistration) {
            & $script:scriptBlockPublishCandidateOwnership -Registration $objCandidateRegistration -PrivateEnvelope $Context
        }
        if ($null -ne $objPrimaryError) {
            $strPrimaryCode = & $script:scriptBlockGetCandidateHelperFailureField `
                -ErrorRecord $objPrimaryError `
                -Key 'TerraformStyleGuideDiagnosticCode' `
                -Fallback "$strPhase-invalid"
            $strPrimaryPhase = & $script:scriptBlockGetCandidateHelperFailureField `
                -ErrorRecord $objPrimaryError `
                -Key 'TerraformStyleGuidePhase' `
                -Fallback $strPhase
            $strPrimarySubreason = & $script:scriptBlockGetCandidateHelperFailureField `
                -ErrorRecord $objPrimaryError `
                -Key 'TerraformStyleGuideSubreason' `
                -Fallback 'failure'

            $objCleanupResult = $null
            if ($strPrimaryPhase -cne 'parameter' -and $null -ne $objValidatedContext) {
                $objCleanupResult = & $script:scriptBlockRemoveCandidateOwnershipState -CandidateOwnershipState $objCandidateState -PrimaryFailure $objPrimaryError -ErrorAction SilentlyContinue
            }
            $strCleanupCode = if ($null -eq $objCleanupResult) {
                'not-required'
            } else {
                $objCleanupResult.CleanupSummary.CleanupResult
            }
            $objCompositeException = & $script:scriptBlockNewCandidateHelperException `
                -Code $strPrimaryCode `
                -Phase $strPrimaryPhase `
                -Subreason $strPrimarySubreason
            $objCompositeException.Data['TerraformStyleGuideCleanupCode'] = $strCleanupCode
            $objCompositeException.Data['CandidateOwnershipState'] = $objCandidateState
            $objCompositeException.Data['PrimaryFailure'] = $objPrimaryError
            $objCompositeException.Data['Diagnostics'] = [pscustomobject]$hashtableDiagnostics
            throw $objCompositeException
        }

        $arrCandidatePaths = [string[]]@(
            foreach ($strName in $script:arrCandidateHelperExpectedName) {
                [System.IO.Path]::Combine($strCandidatePath, $strName)
            }
        )
        return [pscustomobject][ordered]@{
            CandidatePaths = $arrCandidatePaths
            CandidateOwnershipState = $objCandidateState
        }
    }


    Microsoft.PowerShell.Core\Export-ModuleMember -Function Remove-StyleGuideCandidateInvocationState
}
$strCandidateModuleName = 'TerraformStyleGuideCandidateArtifact_1_0_20260924_0'
$arrCandidateModules = @(Microsoft.PowerShell.Core\Get-Module -Name $strCandidateModuleName -All)
if ($arrCandidateModules.Count -gt 1) {
    throw 'candidate-module-ambiguous'
}
if ($arrCandidateModules.Count -eq 1) {
    $objCandidateModule = $arrCandidateModules[0]
    # Metadata and exported names alone do not authenticate executable code.
    # Require the complete loaded module definition to equal this exact script's
    # private definition. A fresh copy of the same definition issues no objects.
    if (-not [string]::Equals(
            $objCandidateModule.Definition,
            $scriptBlockCandidateModuleDefinition.Ast.Extent.Text,
            [System.StringComparison]::Ordinal)) {
        throw 'candidate-module-definition-mismatch'
    }
} else {
    $hashtableModuleParameters = @{
        Name = $strCandidateModuleName
        ScriptBlock = $scriptBlockCandidateModuleDefinition
    }
    $objCandidateModule = Microsoft.PowerShell.Core\New-Module @hashtableModuleParameters
}
Microsoft.PowerShell.Core\Import-Module -ModuleInfo $objCandidateModule -Global -Force
if ($boolCandidateHelperWasDotSourced) {
    return
}
& $objCandidateModule {
    param ([System.Collections.IDictionary]$RawParameters)

    & $script:scriptBlockInvokeCandidateArtifactExpansion -RawParameters $RawParameters
} $PSBoundParameters
