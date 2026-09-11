# Troubleshoot the failing layer

[← Project overview](../README.md)

Start with the layer that produced the error. A successful AWS sign-in does not prove Session Manager authorization, and an open tunnel does not prove Linux authentication.

| Symptom | Likely layer | Check / next action |
| :--- | :--- | :--- |
| `pwsh` not found | Workstation | Install PowerShell 7, reopen the terminal, verify PATH |
| Script blocked | Windows trust policy | Inspect `Get-ExecutionPolicy -List`: `Restricted` prohibits scripts; `AllSigned` needs signing; `RemoteSigned` may need review and unblocking. Follow the [setup guide](windows-setup.md#1-install-the-workstation-tools). |
| `aws` or plugin not found | Workstation | Install official tools and reopen PowerShell; MobaXterm's local terminal may have another PATH |
| `NoRegion` | AWS CLI configuration | Supply the EC2 Region in the toolkit; SSO Region is a separate setting |
| Browser authentication fails | Identity provider / sign-in authorization | Confirm the right portal, individual user, device, and time synchronization; ask the identity administrator to inspect authorization rather than repeatedly resetting a valid MFA device |
| Profile does not match intended SSO account | AWS profile | Inspect `sso_account_id`, `sso_role_name`, and `sso_session`; use a new dedicated profile if the existing one is wrong |
| STS shows `AdministratorAccess` or another account | AWS identity | Stop. Re-run the official SSO wizard for a new dedicated profile and select the correct account and permission set |
| SSO role pin changed | Identity Center provisioning | Have the administrator confirm role recreation or assignment changes; create a new local configuration after verification |
| STS fails even after browser login | Connectivity or credentials | Check proxy/network access, AWS service availability, profile configuration, and assignment; a login retry does not repair a network failure |
| `AccessDeniedException` from `StartSession` | IAM | Check exact target/document ARNs, account/Region, provisioning status, effective role grants and explicit denies |
| `TargetNotConnected` | Managed node | Administrator checks SSM agent, instance role, outbound HTTPS, DNS, and VPC endpoints in the target Region |
| Invalid document / parameter | Session document | Use a Session document of type `Port`; do not pass destination parameters to this fixed document |
| Port already in use | Workstation | Identify the listener. Do not kill an unknown process or assume it is the right tunnel |
| MobaXterm connection refused | Local tunnel or sshd | Wait for the port-open message; match the configured local port; have the host administrator verify sshd on TCP 22 |
| `Permission denied (publickey)` | Linux SSH | Use the Linux username and its authorized key; an SSO username or successful MFA is not an SSH credential |
| SSH host-key warning | Host identity | Verify the fingerprint through an independent trusted path; check whether another instance reused this local port |
| SSH works, SFTP does not | Linux subsystem / permissions | Inspect SFTP subsystem and home-directory permissions with the host administrator |
| `TerminateSession` denied | Session ownership / IAM | Confirm the same federated principal and target; use the administrator's incident procedure if necessary, then test the ownership conditions |

## Safe identity inspection

Replace only the profile and Region with your local values:

```powershell
aws configure get sso_account_id --profile workbench-sso
aws configure get sso_role_name --profile workbench-sso
aws configure get sso_session --profile workbench-sso
aws sts get-caller-identity --profile workbench-sso --region us-east-1 --query Arn --output text
```

Expected shape, with fictional values:

```text
arn:aws:sts::111122223333:assumed-role/AWSReservedSSO_WorkbenchSSH_0123456789abcdef/alex
```

The profile's friendly name is not evidence of the active role. Never publish the actual output without sanitizing it. [AWS STS reference](https://docs.aws.amazon.com/cli/latest/reference/sts/get-caller-identity.html)

## Inspect an occupied local port

In Windows PowerShell, this read-only command shows listeners and their process IDs:

```powershell
Get-NetTCPConnection -State Listen -LocalPort 2222 |
    Select-Object LocalAddress, LocalPort, OwningProcess
```

Inspect the reported process in Task Manager. If it is your previous tunnel, close that session intentionally before starting another. The toolkit neither attaches to an existing listener nor terminates it. [Microsoft TCP diagnostics](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-nettcpconnection)

## Keep error reports private by default

Do not paste `--debug` output, AWS credential files, SSO cache files, plugin session tokens, private keys, or raw session logs into a public issue. Report the failing layer, sanitized error name, tool versions, and a minimal reproduction. See [SECURITY.md](../SECURITY.md) for vulnerabilities.
