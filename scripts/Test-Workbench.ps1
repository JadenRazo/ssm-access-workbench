#Requires -Version 7.4
<#
.SYNOPSIS
Check local prerequisites, SSO profile, caller identity, and port availability.
.DESCRIPTION
Does not sign in, open a tunnel, inspect cloud configuration, or print AWS credentials.
#>
[CmdletBinding()]
param([string]$ConfigPath)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Workbench.psm1') -Force
try {
    $config = if ($ConfigPath) { Get-WorkbenchConfig $ConfigPath } else { Get-WorkbenchConfig }
    Assert-WorkbenchPrerequisites
    Assert-WorkbenchProfile $config
    $verified = Get-WorkbenchIdentity $config
    Assert-WorkbenchPort $config.LocalPort
    Write-Host "PASS: profile $($config.Profile), account $($config.AccountId), role $($verified.Role), local port $($config.LocalPort) available." -ForegroundColor Green
    Write-Host 'This checks the workstation only. It does not prove IAM denial cases, agent health, document contents, security groups, SSH keys, or logging.'
    Write-Host 'Before sharing diagnostics, remove your account, instance, profile and role identifiers.'
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    [Console]::Error.WriteLine('See docs/troubleshooting.md. This check does not automatically sign in or modify configuration.')
    exit 1
}
