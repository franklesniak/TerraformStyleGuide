#Requires -Version 7.0

# .SYNOPSIS
# Runs one approved pre-commit module with the repository's Python 3.12 runtime.
#
# .DESCRIPTION
# Selects an exact Python 3.12 application and runs one approved module from the
# dependency closure installed through requirements-dev.txt. The script passes
# all remaining arguments to that module and returns the module's exit code.
#
# .PARAMETER Module
# The approved Python module to run.
#
# .PARAMETER Argument
# The arguments to pass to the selected Python module.
#
# .EXAMPLE
# & ./.github/workflows/Invoke-LockedPythonHook.ps1 `
#     -Module pre_commit_hooks.check_json package.json
#
# # Runs the locked JSON syntax hook against package.json.
#
# .INPUTS
# None. You can't pipe objects to this script.
#
# .OUTPUTS
# None. The selected module writes its own output.
#
# .NOTES
# This script does not support positional parameters.
# Version: 1.0.20260911.0

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory)]
    [ValidateSet(
        'check_jsonschema',
        'pre_commit_hooks.check_json',
        'pre_commit_hooks.check_yaml',
        'pre_commit_hooks.end_of_file_fixer',
        'pre_commit_hooks.trailing_whitespace_fixer',
        'yamllint'
    )]
    [string] $Module,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Argument = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$arrPythonCandidate = if ($IsWindows) {
    @(
        [pscustomobject]@{ Command = 'python'; PrefixArgument = @() }
        [pscustomobject]@{ Command = 'py'; PrefixArgument = @('-3.12') }
        [pscustomobject]@{ Command = 'python3.12'; PrefixArgument = @() }
    )
}
else {
    @(
        [pscustomobject]@{ Command = 'python'; PrefixArgument = @() }
        [pscustomobject]@{ Command = 'python3.12'; PrefixArgument = @() }
        [pscustomobject]@{ Command = 'python3'; PrefixArgument = @() }
    )
}

foreach ($objPythonCandidate in $arrPythonCandidate) {
    $objPythonApplication = Get-Command -Name $objPythonCandidate.Command `
        -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $objPythonApplication) {
        continue
    }

    $arrPrefixArgument = @($objPythonCandidate.PrefixArgument)
    $arrVersionOutput = @(
        & $objPythonApplication.Source @arrPrefixArgument -I -c `
            'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' `
            2>$null
    )
    $intVersionExitCode = $LASTEXITCODE
    if ($intVersionExitCode -ne 0 -or
        $arrVersionOutput.Count -ne 1 -or
        $arrVersionOutput[0] -cne '3.12') {
        continue
    }

    & $objPythonApplication.Source @arrPrefixArgument -I -m $Module @Argument
    exit $LASTEXITCODE
}

Write-Error 'Python 3.12 is required to run the locked pre-commit hook.'
exit 2
