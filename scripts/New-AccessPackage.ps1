#Requires -Version 7.4
<#
.SYNOPSIS
Generate IAM and Session document JSON for an administrator to review in the AWS console.
.DESCRIPTION
Local files only. No AWS calls. Does not overwrite an existing package.
#>
[CmdletBinding()]
param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Workbench.psm1') -Force
try {
    $config = Read-WorkbenchConfig
    if (-not $OutputDirectory) {
        $name = Read-WorkbenchValue 'Package folder name' 'workbench' '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'
        $OutputDirectory = Join-Path (Get-WorkbenchRoot) "packages/$name"
    }
    if (Test-Path -LiteralPath $OutputDirectory) { throw 'Choose a new output directory. Existing packages are never overwritten.' }
    Write-WorkbenchJson (New-WorkbenchPolicy $config) (Join-Path $OutputDirectory 'permission-set.json')
    Write-WorkbenchJson (New-WorkbenchDocument $config.LocalPort) (Join-Path $OutputDirectory 'session-document.json')
    Write-WorkbenchJson $config (Join-Path $OutputDirectory 'connection-inputs.local.json')
    Write-Host "Generated package: $OutputDirectory" -ForegroundColor Green
    Write-Host 'Review the two policy/document files, then follow docs/aws-console-setup.md.'
    Write-Host 'The inputs file is a worksheet, not an authenticated workstation configuration. Keep the package private.'
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
