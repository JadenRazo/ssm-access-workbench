#Requires -Version 7.4
<#
.SYNOPSIS
Create a Windows desktop shortcut pointing to this checkout and a verified configuration.
#>
[CmdletBinding()]
param([string]$ConfigPath, [string]$Name = 'SSM Access Workbench')
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Workbench.psm1') -Force
try {
    if (-not $IsWindows) { throw 'Desktop shortcuts require Windows.' }
    if ($Name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9 _-]{0,63}$') { throw 'Use letters, numbers, spaces, hyphens or underscores for the shortcut name.' }
    if (-not $ConfigPath) { $ConfigPath = Join-Path (Get-WorkbenchRoot) 'connection.local.json' }
    $config = Get-WorkbenchConfig $ConfigPath
    $configFull = (Resolve-Path -LiteralPath $ConfigPath).Path
    $scriptFull = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'Start-Workbench.ps1')).Path
    if ($configFull.Contains('"') -or $scriptFull.Contains('"')) { throw 'A path contains an unsupported quotation mark.' }
    $desktop = [Environment]::GetFolderPath('DesktopDirectory')
    if (-not $desktop) { throw 'Windows did not return a desktop directory.' }
    $destination = Join-Path $desktop "$Name.lnk"
    if (Test-Path -LiteralPath $destination) { throw 'Shortcut already exists. Use a different -Name; it will not be overwritten.' }
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($destination)
    $link.TargetPath = Join-Path $PSHOME 'pwsh.exe'
    $link.Arguments = "-NoProfile -NoExit -File `"$scriptFull`" -ConfigPath `"$configFull`""
    $link.WorkingDirectory = Split-Path $PSScriptRoot -Parent
    $link.Description = "Open the SSO-verified SSH tunnel for profile $($config.Profile)"
    $link.Save()
    Write-Host "Created $destination. Keep this repository at its current location."
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
