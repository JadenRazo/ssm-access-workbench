# Explain the project under technical questioning

[← Project overview](../README.md) · [Evidence ledger](verification.md)

Use this as a study guide, not as a substitute for evidence. Say what you built and observed, and distinguish the target design from controls not yet verified in the lab. Do not add scale, cost savings, employers, or production impact that this project did not establish.

## A 60-second explanation

> I built a PowerShell onboarding and access toolkit for Windows operators who want to keep MobaXterm while placing AWS identity in front of SSH. The design uses IAM Identity Center, a narrowly scoped Session Manager permission set, and a custom document that forwards only to SSH on the approved EC2 instance. The client checks the actual AWS account and role before opening the tunnel, because I encountered a case where an SSO profile selected an administrator role in the wrong account. MobaXterm still authenticates a Linux account with its SSH key. I documented the tradeoffs, including the lack of SSH command recording in SSM, and separated the working tunnel evidence from the remaining network, host, and recovery acceptance checks.

Practice the explanation in your own words. Be ready to point to the implementation and test that support each sentence.

## Walk through a request in five steps

1. The operator starts the shortcut. The script loads a private configuration and checks the CLI, plugin, profile, and local port.
2. It checks STS. If credentials cannot be used, it attempts one browser SSO login and checks again. It rejects the wrong account, permission set, or pinned role.
3. It requests `StartSession` for the approved instance and custom document. IAM makes the authorization decision.
4. The plugin exposes the local listener, and the agent carries traffic to sshd on the instance. Both client and agent use outbound AWS service connectivity.
5. MobaXterm verifies the host key and authenticates the Linux user. Linux permissions determine what that session can do.

## Questions an engineer may ask

| Question | A defensible answer |
| :--- | :--- |
| Why is this better than an IP-restricted SSH rule? | It adds centralized AWS authorization for establishing the route and permits removal of direct inbound SSH. The comparison depends on actually closing alternate routes and protecting both credential layers. |
| Does it eliminate SSH keys? | No. The tunnel carries SSH. Native SSM or an SSH certificate design would change the host authentication model. |
| Can someone with my key still connect? | They still need a reachable SSH path. A new SSM tunnel needs AWS authorization, but a direct route, VPN, compromised endpoint, or existing local listener may provide reachability. |
| Is MFA required every time? | It is enforced at AWS sign-in according to identity policy. Cached sessions and an existing tunnel have separate lifetimes. |
| Why does one policy resource use `*`? | `ssmmessages:OpenDataChannel` does not support resource-level ARNs. The instance and document restrictions belong to `StartSession`; session cleanup has its own conditions. |
| Why both an instance and document ARN? | Restricting the node alone can leave unintended session types. The document fixes the approved entry point; negative tests include other documents and omitting the document. |
| Can the launcher stop a malicious operator? | No. It prevents mistakes. IAM must enforce restrictions even when the operator calls AWS directly. |
| Does fixed port 22 prevent lateral movement? | No. An authenticated shell can initiate traffic and SSH may support forwarding. Host privileges, egress, and instance credentials need separate controls. |
| Where are commands recorded? | Not by SSM for this SSH tunnel. Lifecycle events and host logs provide different evidence; complete recording requires a separately selected and validated mechanism. |
| What happens when a person leaves? | Remove identity assignments, address issued credentials, terminate active sessions, revoke host credentials, and verify denial of new access. One logout command is not enough. |
| What did you actually test? | Explain the source lab observations, the automated credential-free tests, and the outstanding manual matrix from the verification ledger. Never describe a mocked call as a real AWS test. |
| What would you change for a larger team? | Evaluate individual host identities, certificates or a dedicated access platform, managed endpoint distribution/signing, centralized audit, policy deployment automation, and independent recovery. Start with their requirements. |

## Rehearse the failure, not just the diagram

Explain the wrong-role incident using **expected behavior → observation → diagnosis → prevention → limitation**:

- **Expected:** the dedicated profile would use the SSH permission set in the workload account.
- **Observed:** STS returned an administrator role from another account.
- **Diagnosis:** account/role selection in the SSO wizard was wrong; the profile label did not reveal it.
- **Prevention:** the toolkit compares expected profile fields and actual STS identity and pins the generated role before opening the tunnel.
- **Limitation:** local validation does not replace IAM or remove other account assignments.

## Portfolio wording you can stand behind

“Built an interactive PowerShell toolkit and console runbooks for MobaXterm access to Linux EC2 through IAM Identity Center and a scoped Session Manager tunnel; added account/role validation, fixed-port policy generation, failure-path tests, and documented audit and offboarding tradeoffs.”

Avoid describing it as “implemented enterprise zero-trust access,” “eliminated all SSH risk,” or “fully audited production access.” Those claims exceed the demonstrated scope.
