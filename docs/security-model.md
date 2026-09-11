# Security model

[← Project overview](../README.md)

This design reduces exposure by placing an AWS authorization decision in front of SSH and then closing the direct inbound route. It does not make the workstation or Linux host a trusted environment automatically.

## Threats and boundaries

| Scenario | Control in the target design | Residual risk / required action |
| :--- | :--- | :--- |
| Internet scanning or direct SSH attempts | No inbound TCP 22 in attached security groups | Confirm every attached group, IPv4/IPv6 route, bastion, VPN, and other reachable path |
| Stolen SSH private key | Separate AWS authorization required to start a new SSM tunnel | An alternate SSH route or existing local tunnel can still expose the host; revoke the key |
| Stolen AWS credentials or SSO session cache | Temporary credentials and a narrow permission set | Credentials can be used until invalidated or expired; an attacker may open the allowed tunnel |
| Wrong account or administrator role selected | Profile check and STS identity check before `StartSession` | Local checks are editable; remove unnecessary AWS assignments and validate effective IAM access |
| Operator requests a shell or another destination through SSM | Exact instance/document grant and fixed document properties | Other policies can add access; document administrators can change the route |
| Authenticated user forwards traffic through SSH | Host-level restrictions such as `AllowTcpForwarding` where compatible | An interactive shell can create other connections; network egress and host permissions matter |
| Operator obtains excessive AWS access from EC2 | Minimal workload instance role | Host processes can often obtain instance-profile credentials; a narrow human role does not neutralize a broad instance role |
| Another process on the Windows machine uses the tunnel | Short tunnel lifetime; trusted endpoint; SSH authentication | Loopback is shared by local processes, not isolated to MobaXterm or a Windows user |
| Host impersonation or wrong saved target | Independently verified SSH host key | The launcher does not inspect or pin MobaXterm's host-key store |
| Incident needs a command transcript | Explicit audit design decision | Session Manager cannot record SSH/port-forwarding contents; CloudTrail is not a terminal recorder |

AWS recommends federation, temporary credentials, MFA, and least privilege. Those are design principles, not a certification obtained by using SSM. [IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)

## Credential handling

The toolkit never asks for a password, TOTP value, AWS access key, or private key. Authentication happens in the AWS browser flow; AWS CLI manages its own local cache. The workstation configuration contains identifiers and a role pin, and is stored under the current user's application-data directory by default. It is not encrypted by this project and is not a vault. Keep Windows profile permissions, disk encryption, patching, and endpoint protection appropriate to your organization.

Protect the SSH private key with a passphrase and restrictive file permissions. Do not place keys in this checkout, shared folders, or screenshots. Existing SSH agents and MobaXterm credential caching change the exposure of an unlocked key; understand their settings before enabling them. The script does not audit them.

The native AWS executable is resolved from `PATH`, so installed tools and the local environment are trusted inputs. The AWS wrapper disables configured custom endpoint URLs during its own calls, and arguments are passed as an array without evaluating shell text. This does not defend against a compromised executable, proxy, local administrator, or altered script.

## MFA does not run inside SSH

MFA protects the Identity Center sign-in. A valid sign-in session can support subsequent AWS credential retrieval, and a valid tunnel can carry SSH connections without another browser prompt. This can be an acceptable operational policy, but it is not “MFA on every MobaXterm connection.” Prefer phishing-resistant FIDO2/WebAuthn where supported by the organization's identity setup, and choose session lifetimes and recovery methods deliberately. [MFA types](https://docs.aws.amazon.com/singlesignon/latest/userguide/mfa-types.html) · [Authentication sessions](https://docs.aws.amazon.com/singlesignon/latest/userguide/authconcept.html)

## Host permissions remain a separate project

Use individual non-root Linux accounts and deliberate sudo rules. An Identity Center group does not provision Linux users or bind an SSO identity to a particular `authorized_keys` entry. Native SSM Run As settings do not select the user for the SSH login inside this tunnel.

The reference instance role should provide the SSM agent's required permissions and only the workload access it actually needs. Attaching `AdministratorAccess` to EC2 creates a much larger exposure than the human tunnel policy suggests. IMDSv2 mitigates some metadata attack paths; it does not prevent an authorized local process from using instance credentials. [Instance-profile credentials](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-metadata-security-credentials.html)

## Audit and offboarding

Record AWS session lifecycle events centrally with the organization's CloudTrail configuration and retention controls. Collect host authentication, sudo, and other required audit events separately. These logs have different coverage; neither should be advertised as complete SSH command recording without an explicitly validated recording mechanism. [Session Manager auditing](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-auditing.html)

Removing a group assignment, signing out, and terminating an existing session are different operations. Use the [offboarding runbook](operations.md#offboarding-and-incident-response) and verify both denial of new access and closure of active transports.
