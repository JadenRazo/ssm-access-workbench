# Set up a Windows operator

[← Project overview](../README.md) · [AWS administrator setup](aws-console-setup.md)

The operator needs an assigned Identity Center permission set, the administrator's worksheet, an existing individual Linux account, its SSH key, and an independently verified SSH host fingerprint. A new AWS user does not automatically become a Linux user.

## 1. Install the workstation tools

Use your organization's software catalog or the official installers. This project checks prerequisites; it does not silently install software or request elevation.

| Tool | Installation source | Check in a newly opened PowerShell window |
| :--- | :--- | :--- |
| PowerShell 7.4 or newer | [Microsoft installation guide](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows) | `pwsh --version` |
| AWS CLI v2 | [AWS installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | `aws --version` |
| Session Manager plugin | [AWS Windows installer](https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-windows.html) | `session-manager-plugin --version` |
| MobaXterm | [Mobatek download page](https://mobaxterm.mobatek.net/download.html) | Open the application; check its About dialog |

Use **PowerShell 7**, not the built-in Windows PowerShell 5.1. MobaXterm's bundled Unix-like terminal can have a different PATH and AWS environment; run the toolkit in Windows PowerShell 7 as documented.

Choose a permanent, user-owned checkout folder such as `C:\Users\you\Projects\ssm-access-workbench`. Download the repository ZIP from GitHub's **Code** menu or clone it with Git. Review the scripts before running them.

These source scripts are unsigned. Check the current policy in PowerShell 7:

```powershell
Get-ExecutionPolicy -List
Get-ExecutionPolicy
```

| Effective policy | Appropriate setup |
| :--- | :--- |
| `RemoteSigned` | Review the source. If Windows blocks the reviewed download's Internet-zone mark, use **Properties → Unblock** or `Unblock-File` on the specific reviewed files where permitted. |
| `AllSigned` | Obtain an approved signed distribution. Unblocking does not sign the scripts. |
| `Restricted` | Scripts cannot run, even if signed or unblocked. Ask the workstation administrator for an approved execution policy. |

For an **unmanaged personal workstation you administer**, where no organizational policy applies, you may deliberately allow local scripts for your own Windows user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

This affects that user's script execution generally, not just this repository. Review the confirmation and recheck the effective policy. Organization-enforced `MachinePolicy` or `UserPolicy` takes precedence; do not try to bypass it. The toolkit never changes execution policy, and the shortcut contains no bypass flag. [Microsoft execution policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies) · [Review before unblocking](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file?view=powershell-7.6)

## 2. Create the local SSO configuration

In PowerShell 7, change into the checkout and run:

```powershell
pwsh -NoProfile -File .\scripts\Initialize-Workbench.ps1
```

The prompts collect the dedicated CLI profile, EC2 Region, workload account ID, instance ID, document name, permission-set name, local port, and Linux username. Use the administrator's values. The default names are `workbench-sso`, `Workbench-SSHOnly`, and `WorkbenchSSH`; all are configurable.

If the profile exists, the script asks to inspect and reuse it without editing it. Otherwise, the official `aws configure sso` wizard opens:

| Wizard prompt | Enter |
| :--- | :--- |
| SSO session name | A new descriptive name, such as `workbench-identity`; avoid unintentionally changing a session shared by other profiles |
| SSO start URL | Your administrator's AWS access portal or supported issuer URL |
| SSO Region | The Identity Center Region; it may differ from the EC2 Region |
| Registration scopes | `sso:account:access` |
| Account | The worksheet's exact workload account ID |
| Role / permission set | `WorkbenchSSH`, or the exact dedicated name |
| Default client Region | The target EC2 Region |
| Output format | `json` |

Complete authentication in your browser. The toolkit never receives your password or MFA code. The wizard may skip account or role selection when only one is available. [AWS CLI SSO configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)

After the wizard, the script checks the profile fields and calls STS. It saves configuration only if the identity belongs to the intended account and SSO permission set, then pins the generated role name. Selecting an administrator role or a different account stops setup.

Default configuration location:

```text
%LOCALAPPDATA%\SSMAccessWorkbench\connection.local.json
```

The file stores connection identifiers and a role name, not credentials. Existing files are preserved. To create another connection, use `-ConfigPath` with a different `*.local.json` path and later pass that same path to the launcher and shortcut tool. Keep files private even though they contain no secrets.

## 3. Save the MobaXterm session

In MobaXterm:

1. Choose **Session → SSH**.
2. Set **Remote host** to `127.0.0.1`.
3. Enable **Specify username** and enter the **Linux** account name. An Identity Center display name is not the SSH username.
4. Set **Port** to the custom document's local port, usually `2222`.
5. Under **Advanced SSH settings**, enable **Use private key** and select the protected key already authorized for that Linux account. Keep the passphrase and private key out of the toolkit configuration.
6. Save with a descriptive name such as **Workbench via SSO**. Keep host-key verification enabled. Leave SSH agent forwarding disabled unless you have a reviewed need for it.

Start the tunnel before opening this bookmark. On first connection, compare the presented host fingerprint with one obtained independently from the host administrator or an already trusted management path. An administrator can inspect an existing host public key on Linux, for example:

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256
```

Compare the same key algorithm. Do not accept a changed key merely because the host field is `127.0.0.1`. That address belongs to the tunnel, while the SSH host key belongs to the EC2 instance. If your server uses another host-key algorithm, obtain and compare that algorithm's fingerprint.

The SSH file browser uses the host's SFTP subsystem and your Linux permissions. Test it with a non-sensitive file in your home directory. A working terminal does not prove that SFTP or sudo is configured correctly. [MobaXterm documentation](https://mobaxterm.mobatek.net/documentation.html)

## 4. Make daily use a desktop workflow

Setup offers to create **SSM Access Workbench** on your desktop. You can also run:

```powershell
pwsh -NoProfile -File .\scripts\New-WorkbenchShortcut.ps1
```

Right-click the saved MobaXterm session and use **Create a desktop shortcut** if available in your version. The two shortcuts keep the tunnel's status visible and avoid timing the SSH client against an unready listener.

1. Double-click **SSM Access Workbench**.
2. If cached AWS credentials cannot be used, complete the browser sign-in. The launcher tries one sign-in, then rechecks STS.
3. Wait for the Session Manager plugin to report the local port open.
4. Open **Workbench via SSO** in MobaXterm and authenticate with the SSH key.
5. Close SSH when finished, then press **Ctrl+C** in the tunnel window. For offboarding or incidents, verify explicit server-side termination using the [operations runbook](operations.md).

The shortcut points to this checkout, so moving or deleting it breaks the shortcut. The terminal remains open to show errors. No AWS credentials or SSH secrets are stored in the `.lnk` file.

## 5. Diagnose before changing permissions

```powershell
pwsh -NoProfile -File .\scripts\Test-Workbench.ps1
```

This does not log in or start a session. If the tunnel is already open, the local-port check will report that it is occupied. Review [troubleshooting](troubleshooting.md) before widening a policy or opening an inbound port.
