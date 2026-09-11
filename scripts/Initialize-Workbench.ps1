#Requires -Version 7.4
<#
.SYNOPSIS
Interactively configure a Windows workstation for an existing Identity Center assignment.
.DESCRIPTION
Uses the official AWS SSO wizard for authentication. Does not create cloud resources,
collect secrets, change existing profiles, install software, or change execution policy.
#>
[CmdletBinding()]
param([string]$ConfigPath)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Workbench.psm1') -Force
try {
    if (-not $IsWindows) { throw 'Workstation setup supports Windows. Template generation and tests also run on PowerShell for Linux.' }
    if (-not $ConfigPath) { $ConfigPath = Join-Path (Get-WorkbenchRoot) 'connection.local.json' }
    if (Test-Path -LiteralPath $ConfigPath) { throw 'Configuration already exists. Use it, or supply a new -ConfigPath; existing files are never overwritten.' }
    Assert-WorkbenchPrerequisites
    $config = Read-WorkbenchConfig
    $profiles = Invoke-WorkbenchAws @('configure', 'list-profiles', '--no-cli-pager', '--no-cli-auto-prompt')
    if ($profiles.ExitCode -ne 0) { throw 'Unable to list AWS profiles. Check your AWS CLI installation and configuration.' }
    $exists = ($profiles.Text -split '\r?\n') -ccontains $config.Profile
    if ($exists) {
        $answer = Read-WorkbenchValue "Profile $($config.Profile) already exists. Inspect and reuse it without editing? (y/n)" 'n' '^[yYnN]$'
        if ($answer -notmatch '^[yY]$') { throw 'Setup stopped. Rerun and choose a different profile name.' }
    } else {
        Write-Host "The AWS wizard will now create profile $($config.Profile)."
        Write-Host "Choose account $($config.AccountId) and permission set $($config.PermissionSetName)."
        Write-Host 'Use a new SSO session name, your administrator-provided portal URL and SSO Region, and scope sso:account:access.'
        Write-Host 'The SSO Region may differ from the EC2 Region. Do not select AdministratorAccess.'
        $result = Invoke-WorkbenchAws @('configure', 'sso', '--profile', $config.Profile, '--no-cli-pager', '--no-cli-auto-prompt') -Interactive
        if ($result.ExitCode -ne 0) { throw 'AWS SSO wizard did not complete. Inspect any partial profile before retrying.' }
    }
    Assert-WorkbenchProfile $config
    $verified = Get-WorkbenchIdentity $config -AllowLogin
    $config['ExpectedRole'] = $verified.Role
    Write-WorkbenchJson $config $ConfigPath
    Write-Host "Saved local configuration: $ConfigPath" -ForegroundColor Green
    Write-Host "MobaXterm: host 127.0.0.1, port $($config.LocalPort), Linux user $($config.LinuxUser)."
    Write-Host 'Configure your SSH key in MobaXterm and verify the host fingerprint using docs/windows-setup.md.'
    $shortcut = Read-WorkbenchValue 'Create a desktop shortcut for the tunnel? (y/n)' 'y' '^[yYnN]$'
    if ($shortcut -match '^[yY]$') {
        & (Join-Path $PSScriptRoot 'New-WorkbenchShortcut.ps1') -ConfigPath $ConfigPath
    }
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
