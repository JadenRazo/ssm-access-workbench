# Operate, revoke, and recover

[← Project overview](../README.md)

This runbook separates normal operation from administrative response. Actions affecting AWS or Linux are performed by an authorized operator in the actual environment, not by the repository tests.

## Daily connection and disconnect

Use the tunnel shortcut, wait for the port-open message, and launch the saved MobaXterm bookmark. Close the SSH connection when finished and stop the tunnel with Ctrl+C. Record the session ID privately if required for your operating procedures.

Closing a client window is not sufficient evidence of server-side revocation. An administrator can inspect **Systems Manager → Session Manager → active sessions** and end a session. The scoped operator can explicitly terminate their own known session ID:

```powershell
aws ssm terminate-session --profile workbench-sso --region us-east-1 --session-id "YOUR-OWN-SESSION-ID"
```

Use the session ID shown when the plugin started. The operator policy intentionally does not grant broad session discovery. A disconnected terminal can leave detached processes or services running on Linux; connection termination is not process cleanup. [Ending sessions](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-end.html)

## Onboard another person

1. Provision an individual identity through the organization's identity source, require enrollment under its MFA policy, and assign the scoped group to the intended account.
2. Have the host administrator provision the appropriate individual Linux account, authorized public key, and sudo permissions. Never distribute a shared private key as an onboarding package.
3. Supply the private connection worksheet and host fingerprint over an approved channel.
4. Run the interactive Windows setup as that person, using their Windows profile and AWS sign-in. Verify STS and the manual connection tests.
5. Record ownership and access review dates in the organization's system of record, not in the public repository.

## Offboarding and incident response

Do not equate “removed from the group” with “all access is immediately gone.” Identity Center sessions, issued role credentials, SSM sessions, SSH keys, and host processes are separate concerns.

1. **Prevent new identity access.** Disable or unassign the user through the authoritative identity system and review all account/role assignments. Follow AWS's current procedure for revoking relevant active identity and role sessions; already-issued credentials need separate consideration.
2. **Close active transports.** An administrator identifies and terminates the person's SSM sessions. Check for other remote-access routes and active SSH connections.
3. **Remove host credentials.** Revoke the relevant public keys/certificates and Linux access. Rotate any credentials exposed to the user or to a compromised endpoint according to incident scope.
4. **Inspect host activity.** Review authentication, sudo, workload, and AWS lifecycle logs. Investigate persistent processes, scheduled tasks, services, and credential access as needed.
5. **Verify the result.** A new SSO/SSM connection must fail and the terminated session must no longer carry SSH traffic. Record the actual credential/session timelines privately.

[Identity Center session behavior](https://docs.aws.amazon.com/singlesignon/latest/userguide/authconcept.html) · [Revoking IAM role sessions](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_revoke-sessions.html)

Running `aws sso logout` on one workstation clears local cached SSO credentials and affects profiles sharing that sign-in cache. It is not an administrator's global revocation mechanism and does not remove SSH keys. [AWS SSO logout](https://docs.aws.amazon.com/cli/latest/reference/sso/logout.html)

## Recovery without a permanent public SSH rule

Before retiring direct SSH, document and test a recovery option suitable for the instance: an independently authorized native SSM administration path when the agent is healthy, EC2 Serial Console where supported and preconfigured, or an approved stopped-instance/EBS rescue workflow. A second SSM role does not recover a node whose agent or network path is broken.

Recovery should have a named owner, strong authentication, explicit scope, and an audit trail. Document the applicable AMI, boot, encryption, downtime, and OS-login prerequisites; do not assume a console button guarantees access.

If a temporary direct SSH exception is the approved incident action, make it specific to an authorized source, time-bound operationally, and independently checked after removal. Never leave broad inbound SSH open as the standing back door. [EC2 Serial Console prerequisites](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-serial-console-prerequisites.html)

## Changes that require re-verification

| Change | Recheck |
| :--- | :--- |
| Recreated Identity Center role | Confirm the new role, initialize a new configuration, and repeat authorization tests |
| Session document content/default version | Review the target port and parameters; test default/alternate document denial |
| Account, Region, target, or local port | Regenerate the administrator package, review assignments, update the client configuration and MobaXterm bookmark |
| Host replacement | Independently verify the new host key before updating the SSH client's trust record |
| Additional IAM or instance-role permissions | Re-evaluate effective access and metadata credential exposure |
| Session duration policy | Measure actual credential and transport lifetimes, including custom `Port` sessions |
| Agent, CLI, plugin, PowerShell, or MobaXterm upgrade | Run local tests and a real connection/termination exercise in the lab |
