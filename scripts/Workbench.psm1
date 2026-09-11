#Requires -Version 7.4
Set-StrictMode -Version Latest

function Get-WorkbenchRoot {
    if ($IsWindows) { return Join-Path $env:LOCALAPPDATA 'SSMAccessWorkbench' }
    return Join-Path $HOME '.local/share/SSMAccessWorkbench'
}

function Read-WorkbenchValue {
    param([string]$Prompt, [string]$Default = '', [string]$Pattern = '.+')
    while ($true) {
        $label = if ($Default) { "$Prompt [$Default]" } else { $Prompt }
        $value = (Read-Host $label).Trim()
        if (-not $value) { $value = $Default }
        if ($value -cmatch $Pattern) { return $value }
        Write-Host 'That value is not valid. Check the format and try again.' -ForegroundColor Yellow
    }
}

function Assert-WorkbenchConfig {
    param([System.Collections.IDictionary]$Config)
    $patterns = @{
        Profile = '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'
        Region = '^(us|eu|ap|sa|ca|me|af|il|mx)-[a-z]+-[1-9][0-9]*$'
        AccountId = '^[0-9]{12}$'
        InstanceId = '^i-([0-9a-f]{8}|[0-9a-f]{17})$'
        DocumentName = '^[A-Za-z0-9][A-Za-z0-9_.-]{2,127}$'
        PermissionSetName = '^[A-Za-z0-9_+=,.@-]{1,32}$'
        LinuxUser = '^[a-z_][a-z0-9_-]{0,31}$'
    }
    foreach ($field in $patterns.Keys) {
        if (-not $Config.Contains($field) -or [string]$Config[$field] -cnotmatch $patterns[$field]) {
            throw "Invalid configuration field: $field. Run Initialize-Workbench.ps1 again."
        }
    }
    if ($Config.DocumentName -match '^(AWS|Amazon|SSM)-') { throw 'Use an account-owned custom document name, such as Workbench-SSHOnly.' }
    if ($Config.PermissionSetName -in @('AdministratorAccess', 'PowerUserAccess')) { throw 'Use the dedicated SSH permission set, not an administrative permission set.' }
    if ($Config.LinuxUser -eq 'root') { throw 'Use an individual non-root Linux account. Review sudo privileges separately.' }
    if (-not $Config.Contains('SchemaVersion') -or $Config.SchemaVersion -ne 1) { throw 'Unsupported configuration schema.' }
    if (-not $Config.Contains('LocalPort') -or $Config.LocalPort -isnot [long] -and $Config.LocalPort -isnot [int]) { throw 'LocalPort must be a JSON integer.' }
    if ($Config.LocalPort -lt 1024 -or $Config.LocalPort -gt 65535) { throw 'LocalPort must be between 1024 and 65535.' }
    if ($Config.Contains('ExpectedRole')) {
        $pattern = '^AWSReservedSSO_' + [regex]::Escape($Config.PermissionSetName) + '_[0-9a-f]{16}$'
        if ($Config.ExpectedRole -cnotmatch $pattern) { throw 'ExpectedRole does not match the dedicated permission set.' }
    }
}

function Get-WorkbenchConfig {
    param([string]$Path = (Join-Path (Get-WorkbenchRoot) 'connection.local.json'))
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Connection configuration is missing. Run Initialize-Workbench.ps1 first.' }
    $config = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    Assert-WorkbenchConfig $config
    if (-not $config.Contains('ExpectedRole')) { throw 'This is an example or incomplete configuration. Run Initialize-Workbench.ps1 to pin the verified role.' }
    return $config
}

function Write-WorkbenchJson {
    param([object]$Value, [string]$Path)
    # Do not overwrite an existing configuration or policy package.
    $fullPath = [IO.Path]::GetFullPath($Path)
    $parent = [IO.Path]::GetDirectoryName($fullPath)
    [void][IO.Directory]::CreateDirectory($parent)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Value | ConvertTo-Json -Depth 20) + "`n")
    $stream = [IO.File]::Open($fullPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    if (-not $IsWindows) { & chmod 600 -- $fullPath }
}

function Get-WorkbenchExecutable {
    param([string]$Name)
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { throw "$Name is missing from PATH. See docs/windows-setup.md, then reopen PowerShell." }
    return $command.Source
}

function Invoke-WorkbenchAws {
    param([string[]]$Arguments, [switch]$Interactive)
    $aws = Get-WorkbenchExecutable 'aws'
    # Ignore configured alternative endpoints. Never send SSO/API requests to a profile's custom endpoint.
    $previous = [Environment]::GetEnvironmentVariable('AWS_IGNORE_CONFIGURED_ENDPOINT_URLS', 'Process')
    [Environment]::SetEnvironmentVariable('AWS_IGNORE_CONFIGURED_ENDPOINT_URLS', 'true', 'Process')
    $PSNativeCommandUseErrorActionPreference = $false
    try {
        if ($Interactive) {
            # The SSO wizard needs a real console handle on Windows. A PowerShell
            # pipeline (including Out-Host) redirects stdout and can break its UI.
            $start = [Diagnostics.ProcessStartInfo]::new()
            $start.FileName = $aws
            $start.UseShellExecute = $false
            foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
            $process = [Diagnostics.Process]::Start($start)
            try {
                # Short waits let PowerShell respond to Ctrl+C. Standard handles
                # remain inherited; no input/output redirection or shell evaluation.
                while (-not $process.WaitForExit(200)) { }
                return [pscustomobject]@{ ExitCode = $process.ExitCode; Text = '' }
            } finally {
                # Clean up only the child process tree started by this invocation.
                # This is not proof of server-side SSM session termination.
                if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
                $process.Dispose()
            }
        }
        $output = & $aws @Arguments 2>&1
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Text = ($output | Out-String).Trim() }
    } finally {
        [Environment]::SetEnvironmentVariable('AWS_IGNORE_CONFIGURED_ENDPOINT_URLS', $previous, 'Process')
    }
}

function Get-WorkbenchAwsArguments {
    param([System.Collections.IDictionary]$Config)
    return @('--profile', $Config.Profile, '--region', $Config.Region, '--no-cli-pager', '--no-cli-auto-prompt')
}

function Assert-WorkbenchPrerequisites {
    $version = Invoke-WorkbenchAws @('--version')
    if ($version.ExitCode -ne 0 -or $version.Text -notmatch '^aws-cli/2\.') { throw 'AWS CLI v2 is required. See docs/windows-setup.md.' }
    $plugin = Get-WorkbenchExecutable 'session-manager-plugin'
    $PSNativeCommandUseErrorActionPreference = $false
    $pluginVersion = & $plugin --version 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Session Manager plugin failed its version check. Reinstall it from AWS.' }
    Write-Host "AWS CLI v2 and Session Manager plugin detected ($pluginVersion)."
}

function Assert-WorkbenchProfile {
    param([System.Collections.IDictionary]$Config)
    # SSO credentials must come from the named SSO profile, not a chained or external credential provider.
    $settings = @{}
    foreach ($key in @('sso_account_id', 'sso_role_name', 'sso_session', 'role_arn', 'credential_process', 'credential_source')) {
        $result = Invoke-WorkbenchAws (@('configure', 'get', $key) + (Get-WorkbenchAwsArguments $Config))
        if ($result.ExitCode -notin @(0, 1)) { throw "Unable to inspect AWS profile setting $key." }
        $settings[$key] = if ($result.ExitCode -eq 0) { $result.Text } else { '' }
    }
    if ($settings.sso_account_id -cne $Config.AccountId -or $settings.sso_role_name -cne $Config.PermissionSetName -or -not $settings.sso_session) {
        throw 'AWS profile does not match the intended SSO account and permission set. Review aws configure sso; no tunnel was opened.'
    }
    if ($settings.role_arn -or $settings.credential_process -or $settings.credential_source) { throw 'Chained roles and external credential providers are outside this SSO-only workflow.' }
}

function Assert-WorkbenchIdentity {
    param([System.Collections.IDictionary]$Config, [object]$Identity)
    if (-not $Identity -or -not $Identity.PSObject.Properties['Account'] -or -not $Identity.PSObject.Properties['Arn']) { throw 'STS returned an incomplete identity.' }
    $pattern = '^arn:aws:sts::' + [regex]::Escape($Config.AccountId) + ':assumed-role/(AWSReservedSSO_' + [regex]::Escape($Config.PermissionSetName) + '_[0-9a-f]{16})/[^/]+$'
    if ($Identity.Account -cne $Config.AccountId -or $Identity.Arn -cnotmatch $pattern) {
        throw 'STOPPED: caller identity is not the approved account and SSH permission set. No tunnel was opened.'
    }
    $role = $Matches[1]
    if ($Config.Contains('ExpectedRole') -and $Config.ExpectedRole -cne $role) { throw 'The SSO role changed. Ask the administrator to confirm the change, then repeat setup with a new configuration file.' }
    return $role
}

function Get-WorkbenchIdentity {
    param([System.Collections.IDictionary]$Config, [switch]$AllowLogin)
    $arguments = @('sts', 'get-caller-identity', '--output', 'json') + (Get-WorkbenchAwsArguments $Config)
    $result = Invoke-WorkbenchAws $arguments
    if ($result.ExitCode -ne 0 -and $AllowLogin) {
        Write-Host 'Credentials could not be used. Trying one browser SSO sign-in; network failures may also cause this.'
        $login = Invoke-WorkbenchAws (@('sso', 'login') + (Get-WorkbenchAwsArguments $Config)) -Interactive
        if ($login.ExitCode -ne 0) { throw 'SSO sign-in failed. Check your browser, network, and account assignment.' }
        $result = Invoke-WorkbenchAws $arguments
    }
    if ($result.ExitCode -ne 0) { throw 'STS identity check failed. Check sign-in and connectivity; run Test-Workbench.ps1 for guidance.' }
    try { $identity = $result.Text | ConvertFrom-Json -ErrorAction Stop } catch { throw 'STS did not return valid JSON. No tunnel was opened.' }
    $role = Assert-WorkbenchIdentity $Config $identity
    return [pscustomobject]@{ Identity = $identity; Role = $role }
}

function Assert-WorkbenchPort {
    param([int]$Port)
    # Inspect all TCP listeners, including IPv6. Never trust or terminate an existing listener.
    $listeners = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
    if (@($listeners | Where-Object Port -EQ $Port).Count -gt 0) { throw "Local TCP port $Port is already in use. Inspect the listener or stop your previous tunnel before retrying." }
}

function Connect-Workbench {
    param([System.Collections.IDictionary]$Config)
    Assert-WorkbenchConfig $Config
    if (-not $Config.Contains('ExpectedRole')) { throw 'Run Initialize-Workbench.ps1 to pin the verified SSO role first.' }
    Assert-WorkbenchPrerequisites
    Assert-WorkbenchProfile $Config
    Assert-WorkbenchPort $Config.LocalPort
    $verified = Get-WorkbenchIdentity $Config -AllowLogin
    Write-Host "Verified account $($Config.AccountId), role $($verified.Role)." -ForegroundColor Green
    Write-Host "Starting $($Config.DocumentName) on $($Config.InstanceId)."
    Write-Host "Wait for the plugin to report port $($Config.LocalPort) open, then open MobaXterm at 127.0.0.1:$($Config.LocalPort)."
    Write-Host 'Keep this window open. Press Ctrl+C to stop; verify session termination when access must end.'
    # No port parameters: the administrator-owned document fixes both ports.
    $result = Invoke-WorkbenchAws (@('ssm', 'start-session', '--target', $Config.InstanceId, '--document-name', $Config.DocumentName) + (Get-WorkbenchAwsArguments $Config)) -Interactive
    if ($result.ExitCode -ne 0) { throw 'Session Manager exited with an error. See docs/troubleshooting.md; permissions were not broadened.' }
}

function New-WorkbenchPolicy {
    param([System.Collections.IDictionary]$Config)
    Assert-WorkbenchConfig $Config
    return [ordered]@{
        Version = '2012-10-17'
        Statement = @(
            [ordered]@{
                Sid = 'StartOnlyWorkbenchSSHTunnel'; Effect = 'Allow'; Action = 'ssm:StartSession'
                Resource = @("arn:aws:ec2:$($Config.Region):$($Config.AccountId):instance/$($Config.InstanceId)", "arn:aws:ssm:$($Config.Region):$($Config.AccountId):document/$($Config.DocumentName)")
                Condition = @{ BoolIfExists = @{ 'ssm:SessionDocumentAccessCheck' = 'true' } }
            },
            [ordered]@{ Sid = 'OpenSessionDataChannel'; Effect = 'Allow'; Action = 'ssmmessages:OpenDataChannel'; Resource = '*' },
            [ordered]@{
                Sid = 'TerminateOwnWorkbenchSessions'; Effect = 'Allow'; Action = 'ssm:TerminateSession'
                Resource = "arn:aws:ssm:$($Config.Region):$($Config.AccountId):session/*"
                Condition = @{ StringEquals = @{
                    'ssm:resourceTag/aws:ssmmessages:session-id' = '${aws:userid}'
                    'ssm:resourceTag/aws:ssmmessages:target-id' = $Config.InstanceId
                } }
            }
        )
    }
}

function New-WorkbenchDocument {
    param([int]$LocalPort = 2222)
    if ($LocalPort -lt 1024 -or $LocalPort -gt 65535) { throw 'Choose a local port between 1024 and 65535.' }
    return [ordered]@{
        schemaVersion = '1.0'
        description = "Forward local TCP $LocalPort to SSH TCP 22 on the target managed node."
        sessionType = 'Port'
        properties = [ordered]@{ portNumber = '22'; type = 'LocalPortForwarding'; localPortNumber = [string]$LocalPort }
    }
}

function Read-WorkbenchConfig {
    Write-Host 'Use values supplied by your AWS administrator. Never enter passwords, MFA codes, or private key contents here.'
    $config = [ordered]@{
        SchemaVersion = 1
        Profile = Read-WorkbenchValue 'Dedicated AWS CLI profile name' 'workbench-sso' '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'
        Region = Read-WorkbenchValue 'EC2 / Systems Manager Region' 'us-east-1' '^(us|eu|ap|sa|ca|me|af|il|mx)-[a-z]+-[1-9][0-9]*$'
        AccountId = Read-WorkbenchValue 'Target AWS account ID (12 digits)' '' '^[0-9]{12}$'
        InstanceId = Read-WorkbenchValue 'Target EC2 instance ID' '' '^i-([0-9a-f]{8}|[0-9a-f]{17})$'
        DocumentName = Read-WorkbenchValue 'Custom Session document name' 'Workbench-SSHOnly' '^[A-Za-z0-9][A-Za-z0-9_.-]{2,127}$'
        PermissionSetName = Read-WorkbenchValue 'Dedicated Identity Center permission set' 'WorkbenchSSH' '^[A-Za-z0-9_+=,.@-]{1,32}$'
        LocalPort = [int](Read-WorkbenchValue 'Local port (must match the document)' '2222' '^[0-9]{4,5}$')
        LinuxUser = Read-WorkbenchValue 'Your existing non-root Linux username' '' '^[a-z_][a-z0-9_-]{0,31}$'
    }
    Assert-WorkbenchConfig $config
    return $config
}

Export-ModuleMember -Function Get-WorkbenchRoot, Read-WorkbenchValue, Assert-WorkbenchConfig, Get-WorkbenchConfig, Write-WorkbenchJson, Get-WorkbenchExecutable, Invoke-WorkbenchAws, Get-WorkbenchAwsArguments, Assert-WorkbenchPrerequisites, Assert-WorkbenchProfile, Assert-WorkbenchIdentity, Get-WorkbenchIdentity, Assert-WorkbenchPort, Connect-Workbench, New-WorkbenchPolicy, New-WorkbenchDocument, Read-WorkbenchConfig
