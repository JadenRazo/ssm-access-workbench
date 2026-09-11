#Requires -Version 7.4
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'scripts/Workbench.psm1') -Force
$script:passed = 0
$script:failed = 0
function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try { & $Body; $script:passed++; Write-Host "PASS  $Name" }
    catch { $script:failed++; Write-Host "FAIL  $Name -- $($_.Exception.Message)" -ForegroundColor Red }
}
function Assert-True {
    param([bool]$Value, [string]$Message = 'Expected true.')
    if (-not $Value) { throw $Message }
}
function Assert-Equal {
    param($Actual, $Expected)
    if (($Actual | ConvertTo-Json -Depth 20 -Compress) -cne ($Expected | ConvertTo-Json -Depth 20 -Compress)) {
        throw "Expected [$Expected], got [$Actual]."
    }
}
function Assert-Throws {
    param([scriptblock]$Body, [string]$Pattern = '.')
    $caught = $null
    try { & $Body | Out-Null } catch { $caught = $_.Exception.Message }
    if (-not $caught -or $caught -notmatch $Pattern) { throw "Expected failure matching '$Pattern'; got '$caught'." }
}
function New-TestConfig {
    return Get-Content (Join-Path $root 'examples/connection.example.json') -Raw | ConvertFrom-Json -AsHashtable
}
function New-TestIdentity {
    param([string]$Account = '111122223333', [string]$Role = 'AWSReservedSSO_WorkbenchSSH_0123456789abcdef')
    return [pscustomobject]@{ Account = $Account; Arn = "arn:aws:sts::${Account}:assumed-role/$Role/alex"; UserId = 'AROAEXAMPLE:alex' }
}

Test-Case 'all PowerShell sources parse' {
    Get-ChildItem $root -Recurse -File | Where-Object Extension -In @('.ps1', '.psm1') | ForEach-Object {
        $tokens = $null; $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
        Assert-Equal @($errors).Count 0
    }
}
Test-Case 'valid configuration accepted' { Assert-WorkbenchConfig (New-TestConfig) }
$invalid = @(
    @('AccountId', '1111'), @('Profile', 'test; Write-Host bad'), @('Profile', '--debug'),
    @('Region', 'cn-north-1'), @('InstanceId', 'i-not-an-instance'), @('DocumentName', 'AWS-StartSSHSession'),
    @('DocumentName', '--endpoint-url'), @('LinuxUser', 'root'), @('PermissionSetName', 'AdministratorAccess'),
    @('PermissionSetName', 'PowerUserAccess'), @('LocalPort', 22), @('LocalPort', 65536),
    @('LocalPort', 2222.5), @('LocalPort', '2222'), @('SchemaVersion', 2), @('ExpectedRole', 'anything')
)
foreach ($pair in $invalid) {
    Test-Case "reject invalid $($pair[0]): $($pair[1])" {
        $c = New-TestConfig; $c[$pair[0]] = $pair[1]
        Assert-Throws { Assert-WorkbenchConfig $c }
    }
}
Test-Case 'correct account and pinned role accepted' {
    Assert-Equal (Assert-WorkbenchIdentity (New-TestConfig) (New-TestIdentity)) 'AWSReservedSSO_WorkbenchSSH_0123456789abcdef'
}
Test-Case 'administrator role in intended account rejected' {
    Assert-Throws { Assert-WorkbenchIdentity (New-TestConfig) (New-TestIdentity -Role 'AWSReservedSSO_AdministratorAccess_0123456789abcdef') } 'STOPPED'
}
Test-Case 'right role in wrong account rejected' {
    Assert-Throws { Assert-WorkbenchIdentity (New-TestConfig) (New-TestIdentity -Account '444455556666') } 'STOPPED'
}
Test-Case 'STS Account and ARN inconsistency rejected' {
    $identity = New-TestIdentity; $identity.Account = '444455556666'
    Assert-Throws { Assert-WorkbenchIdentity (New-TestConfig) $identity } 'STOPPED'
}
Test-Case 'role-name prefix collision rejected' {
    Assert-Throws { Assert-WorkbenchIdentity (New-TestConfig) (New-TestIdentity -Role 'AWSReservedSSO_WorkbenchSSHAdmin_0123456789abcdef') } 'STOPPED'
}
Test-Case 'recreated SSO role rejected until reverified' {
    Assert-Throws { Assert-WorkbenchIdentity (New-TestConfig) (New-TestIdentity -Role 'AWSReservedSSO_WorkbenchSSH_fedcba9876543210') } 'role changed'
}
Test-Case 'IAM user and root identity rejected' {
    foreach ($arn in @('arn:aws:iam::111122223333:user/alex', 'arn:aws:iam::111122223333:root')) {
        $identity = New-TestIdentity; $identity.Arn = $arn
        Assert-Throws { Assert-WorkbenchIdentity (New-TestConfig) $identity } 'STOPPED'
    }
}
Test-Case 'malformed STS identity rejected' { Assert-Throws { Assert-WorkbenchIdentity (New-TestConfig) ([pscustomobject]@{}) } 'incomplete' }
Test-Case 'permission-set regex punctuation is escaped' {
    $c = New-TestConfig; $c.PermissionSetName = 'WB.SSH+Ops'; $c.ExpectedRole = 'AWSReservedSSO_WB.SSH+Ops_0123456789abcdef'
    Assert-WorkbenchConfig $c
    Assert-Equal (Assert-WorkbenchIdentity $c (New-TestIdentity -Role $c.ExpectedRole)) $c.ExpectedRole
    Assert-Throws { Assert-WorkbenchIdentity $c (New-TestIdentity -Role 'AWSReservedSSO_WBxSSHHOps_0123456789abcdef') }
}
Test-Case 'generated policy matches independently committed example' {
    $actual = New-WorkbenchPolicy (New-TestConfig) | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
    $expected = Get-Content (Join-Path $root 'examples/permission-set.json') -Raw | ConvertFrom-Json -AsHashtable
    # Object key order is irrelevant; compare the relevant grant contract explicitly.
    Assert-Equal $actual.Version $expected.Version
    Assert-Equal $actual.Statement.Count 3
    for ($i = 0; $i -lt 3; $i++) {
        foreach ($field in @('Sid', 'Effect', 'Action', 'Resource')) { Assert-Equal $actual.Statement[$i][$field] $expected.Statement[$i][$field] }
    }
    Assert-Equal $actual.Statement[0].Condition.BoolIfExists['ssm:SessionDocumentAccessCheck'] 'true'
    Assert-Equal $actual.Statement[2].Condition.StringEquals['ssm:resourceTag/aws:ssmmessages:session-id'] '${aws:userid}'
    Assert-Equal $actual.Statement[2].Condition.StringEquals['ssm:resourceTag/aws:ssmmessages:target-id'] 'i-0123456789abcdef0'
}
Test-Case 'generated document fixes remote SSH without parameters' {
    $doc = New-WorkbenchDocument 3333
    Assert-Equal $doc.sessionType 'Port'
    Assert-Equal $doc.properties.portNumber '22'
    Assert-Equal $doc.properties.localPortNumber '3333'
    Assert-Equal $doc.properties.type 'LocalPortForwarding'
    Assert-True (-not $doc.Contains('parameters'))
    Assert-Throws { New-WorkbenchDocument 22 }
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('ssm-workbench-tests-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
try {
    Test-Case 'JSON creation preserves existing files and supports paths with spaces' {
        $path = Join-Path $temp 'folder with spaces/connection.local.json'
        $c = New-TestConfig
        Write-WorkbenchJson $c $path
        Assert-Equal (Get-WorkbenchConfig $path).AccountId $c.AccountId
        $before = [IO.File]::ReadAllBytes($path)
        Assert-Throws { Write-WorkbenchJson @{ changed = $true } $path }
        Assert-Equal ([Convert]::ToBase64String([IO.File]::ReadAllBytes($path))) ([Convert]::ToBase64String($before))
    }
    Test-Case 'configuration without verified role pin is refused' {
        $c = New-TestConfig; $c.Remove('ExpectedRole')
        $path = Join-Path $temp 'unverified.local.json'
        Write-WorkbenchJson $c $path
        Assert-Throws { Get-WorkbenchConfig $path } 'pin'
    }
    Test-Case 'interactive package generation writes a complete scoped review package' {
        $package = Join-Path $temp 'interactive package'
        $answers = @('workbench-sso', 'us-east-1', '111122223333', 'i-0123456789abcdef0', 'Workbench-SSHOnly', 'WorkbenchSSH', '2222', 'alex')
        $pwshPath = Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })
        $answers | & $pwshPath -NoProfile -File (Join-Path $root 'scripts/New-AccessPackage.ps1') -OutputDirectory $package | Out-Null
        Assert-Equal $LASTEXITCODE 0
        $policy = Get-Content (Join-Path $package 'permission-set.json') -Raw | ConvertFrom-Json
        $document = Get-Content (Join-Path $package 'session-document.json') -Raw | ConvertFrom-Json
        Assert-Equal $policy.Statement[0].Resource[0] 'arn:aws:ec2:us-east-1:111122223333:instance/i-0123456789abcdef0'
        Assert-Equal $document.properties.localPortNumber '2222'
        Assert-True (Test-Path (Join-Path $package 'connection-inputs.local.json'))
    }
    Test-Case 'occupied loopback port is detected without terminating listener' {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start()
        try {
            $port = $listener.LocalEndpoint.Port
            Assert-Throws { Assert-WorkbenchPort $port } 'already in use'
            Assert-True $listener.Server.IsBound
        } finally { $listener.Stop() }
        Assert-WorkbenchPort $port
    }

    # Mock only AWS and prerequisite adapters; execute actual authorization and connection orchestration.
    $module = Get-Module Workbench
    & $module {
        $script:OriginalAws = ${function:Invoke-WorkbenchAws}
        $script:OriginalPrerequisites = ${function:Assert-WorkbenchPrerequisites}
        function script:Assert-WorkbenchPrerequisites { }
        function script:Invoke-WorkbenchAws {
            param([string[]]$Arguments, [switch]$Interactive)
            $script:Calls.Add(($Arguments -join '|'))
            $text = ''; $code = 0
            switch ($Arguments[0]) {
                'configure' {
                    $values = @{ sso_account_id = '111122223333'; sso_role_name = 'WorkbenchSSH'; sso_session = 'workbench-identity' }
                    if ($script:Scenario -eq 'wrong-profile') { $values.sso_account_id = '444455556666' }
                    if ($script:Scenario -eq 'external-provider') { $values.credential_process = 'external-tool' }
                    if ($values.ContainsKey($Arguments[2])) { $text = $values[$Arguments[2]] } else { $code = 1 }
                }
                'sts' {
                    $script:StsCalls++
                    $role = 'AWSReservedSSO_WorkbenchSSH_0123456789abcdef'
                    if ($script:Scenario -eq 'admin') { $role = 'AWSReservedSSO_AdministratorAccess_0123456789abcdef' }
                    $text = @{ Account = '111122223333'; Arn = "arn:aws:sts::111122223333:assumed-role/$role/alex" } | ConvertTo-Json
                    if ($script:Scenario -in @('expired', 'login-failure') -and $script:StsCalls -eq 1 -or $script:Scenario -eq 'sts-unavailable') { $code = 255; $text = 'simulated unavailable credentials' }
                    if ($script:Scenario -eq 'bad-json') { $text = 'not JSON' }
                }
                'sso' { if ($script:Scenario -eq 'login-failure') { $code = 255 } }
                'ssm' { if ($script:Scenario -eq 'ssm-failure') { $code = 255 } }
                default { throw 'Unexpected mocked AWS command.' }
            }
            return [pscustomobject]@{ ExitCode = $code; Text = $text }
        }
    }
    function Set-Scenario {
        param([string]$Name)
        & $module { param($n) $script:Scenario = $n; $script:Calls = [Collections.Generic.List[string]]::new(); $script:StsCalls = 0 } $Name
    }
    function Get-Calls { return & $module { $script:Calls.ToArray() } }
    function Get-FreeTestConfig {
        $c = New-TestConfig
        $probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $probe.Start(); $c.LocalPort = $probe.LocalEndpoint.Port; $probe.Stop()
        return $c
    }
    Test-Case 'cached SSO credentials start exact target and document with no login' {
        Set-Scenario 'valid'; Connect-Workbench (Get-FreeTestConfig)
        $calls = @(Get-Calls)
        Assert-Equal @($calls | Where-Object { $_ -like 'sso|*' }).Count 0
        Assert-Equal @($calls | Where-Object { $_ -like 'ssm|*' }).Count 1
        Assert-Equal ($calls | Where-Object { $_ -like 'ssm|*' }) 'ssm|start-session|--target|i-0123456789abcdef0|--document-name|Workbench-SSHOnly|--profile|workbench-sso|--region|us-east-1|--no-cli-pager|--no-cli-auto-prompt'
    }
    Test-Case 'expired credentials trigger one login and a second identity check' {
        Set-Scenario 'expired'; Connect-Workbench (Get-FreeTestConfig)
        $calls = @(Get-Calls)
        Assert-Equal @($calls | Where-Object { $_ -like 'sso|login|*' }).Count 1
        Assert-Equal @($calls | Where-Object { $_ -like 'sts|*' }).Count 2
        Assert-Equal @($calls | Where-Object { $_ -like 'ssm|*' }).Count 1
    }
    foreach ($scenario in @('admin', 'wrong-profile', 'external-provider', 'login-failure', 'sts-unavailable', 'bad-json')) {
        Test-Case "$scenario cannot reach StartSession" {
            Set-Scenario $scenario
            $c = Get-FreeTestConfig
            Assert-Throws { Connect-Workbench $c }
            $calls = @(Get-Calls)
            Assert-Equal @($calls | Where-Object { $_ -like 'ssm|*' }).Count 0
            Assert-True (@($calls | Where-Object { $_ -like 'sso|*' }).Count -le 1)
        }
    }
    Test-Case 'diagnostic identity check does not auto-login' {
        Set-Scenario 'expired'
        Assert-Throws { Get-WorkbenchIdentity (New-TestConfig) }
        Assert-Equal @(Get-Calls | Where-Object { $_ -like 'sso|*' }).Count 0
    }
    Test-Case 'SSM failure is propagated without fallback or retry' {
        Set-Scenario 'ssm-failure'
        $c = Get-FreeTestConfig
        Assert-Throws { Connect-Workbench $c } 'exited with an error'
        Assert-Equal @(Get-Calls | Where-Object { $_ -like 'ssm|*' }).Count 1
    }

    # Restore the real native adapter and test it against a local child PowerShell process.
    & $module {
        Set-Item Function:script:Invoke-WorkbenchAws $script:OriginalAws
        $script:OriginalExecutable = ${function:Get-WorkbenchExecutable}
        function script:Get-WorkbenchExecutable { param([string]$Name) return Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }) }
    }
    Test-Case 'native adapter captures exit status, array arguments, and restores endpoint environment' {
        $old = [Environment]::GetEnvironmentVariable('AWS_IGNORE_CONFIGURED_ENDPOINT_URLS', 'Process')
        [Environment]::SetEnvironmentVariable('AWS_IGNORE_CONFIGURED_ENDPOINT_URLS', 'false', 'Process')
        try {
            $result = Invoke-WorkbenchAws @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'fixtures/NativeProbe.ps1'), '-Text', 'spaces and & metacharacters', '-Code', '7')
            Assert-Equal $result.ExitCode 7
            $data = $result.Text | ConvertFrom-Json
            Assert-Equal $data.Text 'spaces and & metacharacters'
            Assert-Equal $data.IgnoreEndpoints 'true'
            Assert-Equal $env:AWS_IGNORE_CONFIGURED_ENDPOINT_URLS 'false'
        } finally { [Environment]::SetEnvironmentVariable('AWS_IGNORE_CONFIGURED_ENDPOINT_URLS', $old, 'Process') }
    }
    Test-Case 'interactive native output does not corrupt returned result' {
        $report = Join-Path $temp 'console.json'
        $result = Invoke-WorkbenchAws @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'fixtures/NativeProbe.ps1'), '-Text', 'interactive probe', '-Code', '0', '-ReportPath', $report) -Interactive
        Assert-Equal @($result).Count 1
        Assert-Equal $result.ExitCode 0
        $child = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
        Assert-Equal $child.OutputRedirected ([Console]::IsOutputRedirected)
    }
    Test-Case 'interactive native failure preserves child exit code' {
        $result = Invoke-WorkbenchAws @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'fixtures/NativeProbe.ps1'), '-Text', 'expected failure', '-Code', '7') -Interactive
        Assert-Equal $result.ExitCode 7
    }
    Import-Module (Join-Path $root 'scripts/Workbench.psm1') -Force

    if ($IsWindows) {
        Test-Case 'Windows shortcut points to PowerShell and preserves a spaced configuration path' {
            $path = Join-Path $temp 'shortcut config/connection.local.json'
            Write-WorkbenchJson (New-TestConfig) $path
            $name = 'SSM Workbench Test ' + [guid]::NewGuid().ToString('N')
            $lnk = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) "$name.lnk"
            try {
                & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $root 'scripts/New-WorkbenchShortcut.ps1') -ConfigPath $path -Name $name
                Assert-Equal $LASTEXITCODE 0
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($lnk)
                Assert-True ($shortcut.TargetPath.EndsWith('pwsh.exe'))
                Assert-True ($shortcut.Arguments.Contains("-ConfigPath `"$path`""))
                Assert-True (-not $shortcut.Arguments.Contains('ExecutionPolicy'))
                # A second creation must refuse to overwrite the shortcut.
                & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File (Join-Path $root 'scripts/New-WorkbenchShortcut.ps1') -ConfigPath $path -Name $name
                Assert-Equal $LASTEXITCODE 1
            } finally { if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk } }
        }
    } else { Write-Host 'SKIP  Windows COM shortcut integration (Windows only)' }
} finally {
    # Only the unique test directory created by this invocation is removed.
    Remove-Item -LiteralPath $temp -Recurse -Force
    Import-Module (Join-Path $root 'scripts/Workbench.psm1') -Force
}

Write-Host "`n$script:passed passed; $script:failed failed. AWS calls in orchestration tests are mocked."
if ($script:failed -gt 0) { exit 1 }
exit 0
