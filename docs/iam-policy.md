# The least-privilege policy

[← Project overview](../README.md)

The [example policy](../examples/permission-set.json) is assigned to an Identity Center permission set. Generate your own values with `New-AccessPackage.ps1`; do not deploy the example account and instance identifiers.

## Action, resource, condition

| Statement | Authorization | Why it is shaped this way |
| :--- | :--- | :--- |
| `StartOnlyWorkbenchSSHTunnel` | `ssm:StartSession` on one EC2 ARN and one account-owned document ARN | Both the target and the requested Session document must be within the grant |
| `OpenSessionDataChannel` | `ssmmessages:OpenDataChannel` on `*` | The service does not support resource ARNs for this action |
| `TerminateOwnWorkbenchSessions` | `ssm:TerminateSession` on account/Region session ARNs, with both ownership and target conditions | Lets a federated caller clean up their sessions on the approved target |

The wildcard in the data-channel statement is a documented service limitation. Do not substitute a made-up session ARN restriction: it suggests a boundary the service cannot evaluate. It also does not grant `StartSession` on arbitrary targets. [Message Gateway Service authorization reference](https://docs.aws.amazon.com/service-authorization/latest/reference/list_ssmmessages.html)

## Require the intended document

`ssm:SessionDocumentAccessCheck` participates in checking access to the Session document. The policy uses AWS's `BoolIfExists` pattern with `true`. Keep the exact custom document ARN in the resource list and test a request that omits `--document-name`, as well as requests for shell and generic forwarding documents. Do not infer default-document denial just because the happy path works. [Default Session document access](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-default-session-document.html)

The document contains no operator-controlled destination parameter:

```json
{
  "schemaVersion": "1.0",
  "sessionType": "Port",
  "properties": {
    "portNumber": "22",
    "type": "LocalPortForwarding",
    "localPortNumber": "2222"
  }
}
```

Only an administrator should be able to change the document or its default version. A local port configured in MobaXterm or the launcher must match it. Session document schema version `1.0` and session type `Port` identify this as a forwarding document; it is not a `Standard_Stream` shell document. [Session document schema](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-schema.html)

## Federated session ownership

The cleanup statement compares AWS's system-supplied session owner tag with the literal IAM variable `${aws:userid}`, and also checks the target instance. For an assumed role, the user ID includes the role ID and caller session name. It is not necessarily the printable Session Manager session ID. Do not build federated ownership rules by guessing a username prefix in the session ARN. [AWS federated termination examples](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-examples.html#restrict-access-example-4)

The generator preserves `${aws:userid}` as a literal string; a test catches accidental PowerShell interpolation. `ResumeSession` is intentionally omitted: users open a new tunnel when needed. Test own-session termination and denial of another user's session in the lab before relying on cleanup during an incident.

## What is deliberately absent

The operator permission set has no EC2 administration, `ssm:SendCommand`, document editing, generic shell session grant, broad session discovery, `iam:PassRole`, or instance-role administration. STS `GetCallerIdentity` does not require an additional Allow in this policy. [STS API authorization](https://docs.aws.amazon.com/cli/latest/reference/sts/get-caller-identity.html)

The operator cannot necessarily browse the EC2 or Systems Manager consoles using this set. That is expected: console discovery needs additional read permissions, and is performed by the administrator in this walkthrough.

## Effective permissions matter

This Allow policy is not a universal restriction. Other grants on the selected role can expand access; other account/role assignments may offer an entirely separate route. A permissions boundary constrains possible grants but does not grant access by itself. Evaluate the provisioned role and relevant organization controls, not just the JSON shown in the permission-set editor. [IAM policy evaluation](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html)

Use IAM Access Analyzer's policy validation and the simulator as preliminary checks, then run the [real-cloud acceptance matrix](verification.md#manual-lab-acceptance). A syntactically valid policy is not proof that an authorization boundary works as intended.
