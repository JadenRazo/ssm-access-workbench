#Requires -Version 7.4
<#
.SYNOPSIS
Verify the configured SSO identity and open the fixed-port Session Manager tunnel.
#>
[CmdletBinding()]
param([string]$ConfigPath)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Workbench.psm1') -Force
try {
    $config = if ($ConfigPath) { Get-WorkbenchConfig $ConfigPath } else { Get-WorkbenchConfig }
    Connect-Workbench $config
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
