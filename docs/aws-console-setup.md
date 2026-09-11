# Build the access path in the AWS console

[← Project overview](../README.md) · [Next: Windows setup →](windows-setup.md)

Use a disposable Linux EC2 lab in a workload account. Keep organization management and routine host access separate. If an organization already manages identity, ask its administrator for the assignment; do not replace its identity source or create a parallel directory.

This guide assumes an authorized administrator can configure IAM Identity Center, IAM, Systems Manager, and the lab's EC2 settings. The eventual operator permission set intentionally cannot perform those administrative steps. Keep a tested recovery method available throughout the migration. Console labels can change; the resource names and checks below identify the intended settings.

## 1. Write down the scope

Use the following worksheet. Account ID, instance ID, portal URL, and configuration files stay private.

| Value | Where to find it | Example only |
| :--- | :--- | :--- |
| Workload account ID | Console account menu / Organizations account list | `111122223333` |
| EC2 Region | EC2 Region selector | `us-east-1` |
| Instance ID | EC2 → Instances → selected instance | `i-0123456789abcdef0` |
| Identity Center Region | IAM Identity Center → Settings | May differ from EC2 Region |
| AWS access portal URL | IAM Identity Center → Settings → Identity source | Use your organization's URL |
| Permission set / group | Names you will create | `WorkbenchSSH` / `WorkbenchSSHUsers` |
| Custom document | Name you will create | `Workbench-SSHOnly` |
| Local forwarding port | An available unprivileged Windows port | `2222` |
| Linux user | Host administrator | An existing individual non-root account |

On the workstation, run `pwsh -NoProfile -File .\scripts\New-AccessPackage.ps1`. Enter these values. It creates `permission-set.json`, `session-document.json`, and a private input worksheet. Inspect the two JSON files before pasting them into AWS. The examples under `examples/` are sanitized illustrations.

## 2. Prepare the managed node

**EC2 → Instances → select the lab instance → Security** shows its instance role and security groups.

1. In **IAM → Roles**, create or review an EC2 service role with an EC2 trust relationship. `AmazonSSMManagedInstanceCore` supplies the standard agent permissions for this lab. Review any other attached or inline policies; do not give the instance `AdministratorAccess` to make connectivity work.
2. In **EC2 → Instances → Actions → Security → Modify IAM role**, attach the intended role. If the instance already serves a workload, review that role's dependencies before replacing it.
3. Check **Systems Manager → Fleet Manager / Managed nodes** in the instance's Region. The node must appear online. Use a supported, current SSM agent and verify that sshd is running on TCP 22. Installing or repairing the agent and provisioning Linux users may require the image build or existing administrator access; those are host operations, not IAM console settings.
4. Ensure the node can reach the regional SSM services over outbound HTTPS. Use approved outbound connectivity or appropriately configured interface VPC endpoints. Private DNS, endpoint policies, and endpoint security groups must allow the traffic. Modern agents use `ssmmessages`; older agents/Regions may also require `ec2messages`. Review the current regional requirements instead of copying an old endpoint list.

[Instance-role setup](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-create-iam-instance-profile.html) · [Session Manager prerequisites](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-prerequisites.html) · [Endpoint requirements](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html)

**Checkpoint:** the intended instance is online as a managed node, with a reviewed instance role. This says nothing yet about the operator's permissions.

## 3. Create the fixed SSH document

1. Open **Systems Manager → Documents** in the **EC2 Region**.
2. Choose **Create document** and the **Session** document type. Use the worksheet's document name.
3. Choose the JSON content editor and paste the generated `session-document.json`.
4. Create the document. Inspect its content and default version: `sessionType` must be `Port`, remote `portNumber` must be `22`, and `localPortNumber` must match the worksheet. There must be no destination parameters.
5. Restrict document modification and default-version changes to administrators. If a later revision is made, review and explicitly select the intended default version.

Do not create a Command or Automation document with the same JSON. The Session Manager console's normal shell-connect screen is not the launcher for this `Port` document; the workstation CLI starts it. [Session document schema](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-schema.html)

## 4. Configure identity and MFA

In **IAM Identity Center**, confirm you are viewing the organization's existing instance and its correct Region.

1. Under **Users**, create an individual user if needed. With an external identity provider, provision the user and group through that provider's supported process instead.
2. Under **Groups**, create `WorkbenchSSHUsers` and add the intended user. Avoid shared identities.
3. Under **Settings → Authentication → Multi-factor authentication**, review the MFA types, sign-in requirement, and behavior for users without registered devices. Follow the organization's enrollment/recovery policy; avoid locking out the only administrator while changing enforcement.
4. Have the user register their MFA device in the access portal. Prefer phishing-resistant authenticators where supported; a TOTP authenticator is a different assurance level. Verify a fresh sign-in actually enforces the intended policy.

This step protects AWS sign-in. It does not configure PAM or add an MFA prompt to each SSH handshake. [Identity Center MFA](https://docs.aws.amazon.com/singlesignon/latest/userguide/mfa-getting-started.html) · [Supported MFA types](https://docs.aws.amazon.com/singlesignon/latest/userguide/mfa-types.html)

## 5. Create and assign the permission set

1. Open **Multi-account permissions → Permission sets → Create permission set**.
2. Choose a **custom permission set**. Add the generated `permission-set.json` as its **inline policy**. Do not add `AdministratorAccess`, `PowerUserAccess`, or broad SSM policies to this set.
3. Name it `WorkbenchSSH` (or the exact worksheet name). For this lab, choose a **1-hour role session duration** as an initial policy decision. This is not a guaranteed 1-hour tunnel timeout; test the actual session behavior separately.
4. Create the permission set. In **AWS accounts**, select the **workload account**, choose **Assign users or groups**, select `WorkbenchSSHUsers`, and assign `WorkbenchSSH`.
5. Wait for provisioning to complete successfully. If you edit the set later, update/reprovision it to the assigned account and check completion.
6. Review the user's other account assignments. A narrow new set does not remove an existing administrator assignment. Retain a deliberate administrative/recovery workflow and use the scoped set for daily access.

The group contains users; the permission set defines permissions; the account assignment joins them in a particular account. Creating only the group does not grant access. [Permission sets](https://docs.aws.amazon.com/singlesignon/latest/userguide/howtocreatepermissionset.html) · [Account assignments](https://docs.aws.amazon.com/singlesignon/latest/userguide/assignusers.html)

**Checkpoint:** the user sees the expected workload account and `WorkbenchSSH` in the portal. The provisioned role has only the intended tunnel permissions.

## 6. Connect and test before changing the network

Follow [Windows setup](windows-setup.md). Confirm the selected STS identity, connect through MobaXterm, and run the [manual acceptance matrix](verification.md#manual-lab-acceptance) in the lab. Use separate test identities for ownership checks.

Keep an established recovery path while testing. An existing SSH connection is useful during migration but is not a recovery strategy if the machine reboots or the agent fails.

## 7. Retire direct SSH deliberately

Only after the successful access and recovery checks:

1. Open **EC2 → Instances → Security** and inspect **every attached security group**. Record the exact rules and authorized rollback method privately.
2. In each relevant group, choose **Edit inbound rules** and remove the rules that permit direct TCP 22 to this instance. A rule in another attached group can still permit it. Review broader port ranges as well as rules named “SSH,” and both IPv4 and IPv6 sources.
3. From a separate client, test a **new** direct connection and confirm it fails. Reconnect through SSM and confirm it still succeeds. An already-established TCP connection may survive a rule change.
4. Consider private subnet placement and the wider network design separately. Removing an SSH rule does not require removing unrelated service rules or changing DNS.

Do not leave a temporary `0.0.0.0/0` or `::/0` SSH rule as a recovery plan. For an actual lockout, use the documented, authorized [recovery procedure](operations.md#recovery-without-a-permanent-public-ssh-rule).

## 8. Finish the operational controls

Review the instance profile, individual Linux users, sudo, SSH forwarding policy, protected keys, session durations, CloudTrail retention, and host logs. Record evidence and owners in your private copy of the acceptance matrix. If the requirement is a complete SSH command recording, select and validate an appropriate recording design; enabling Session Manager output logging cannot see inside this SSH tunnel.

VPC endpoints, NAT, EC2, log storage, and related services can incur charges. Use your organization's existing network and logging pattern where appropriate, and evaluate changes against [AWS pricing](https://aws.amazon.com/pricing/). This guide does not promise a free deployment.
