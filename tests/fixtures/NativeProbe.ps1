#Requires -Version 7.4
param([string]$Text, [int]$Code = 0, [string]$ReportPath, [switch]$ReadInput, [int]$WaitSeconds = 0)
$data = @{ Text = $Text; IgnoreEndpoints = $env:AWS_IGNORE_CONFIGURED_ENDPOINT_URLS; OutputRedirected = [Console]::IsOutputRedirected; ProcessId = $PID }
if ($ReadInput) { $data['Input'] = Read-Host 'Enter the test marker' }
if ($ReportPath) { $data | ConvertTo-Json -Compress | Set-Content -LiteralPath $ReportPath }
if ($WaitSeconds -gt 0) { Write-Host "Probe waiting in process $PID"; Start-Sleep -Seconds $WaitSeconds }
$data | ConvertTo-Json -Compress
exit $Code
