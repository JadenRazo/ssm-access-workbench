# ADR 001: Preserve SSH behind a scoped Session Manager tunnel

**Status:** Accepted for this reference implementation

**Scope:** Authorized Windows operators who require MobaXterm SSH/SFTP access to a Linux EC2 instance

**Date:** 2026-09-11

## Context and acceptance criteria

The existing workflow depends on MobaXterm's terminal and SFTP browser. The requirement is to make AWS authorization necessary for establishing the access path, restrict it to one managed node, and make workstation onboarding repeatable. The operator also needs to understand the configuration through the AWS console. This is a requirement specific to the project; direct SSH with protected keys and a source-IP restriction is a valid alternative when it meets an organization's access policy.

A successful implementation has a clear AWS authorization boundary, preserves host-key verification, avoids embedded credentials, detects a wrongly selected account or administrative role, and documents negative tests and recovery before removing direct SSH. Public claims must match the verification ledger.

## Options considered

| Approach | Advantages | Failure mode or tradeoff |
| :--- | :--- | :--- |
| Direct SSH restricted to a source IP | Requires both approved network access and SSH authentication; existing tools work; fewer service dependencies | Does not require AWS authorization; shared egress is not individual identity; changing addresses and host credentials need administration |
| Native Session Manager shell | Can avoid SSH keys and inbound SSH; supports configured session output logging | Changes the terminal/file-transfer workflow; default host privileges need scrutiny; logging must actually be configured and validated |
| SSH through a scoped SSM tunnel | Keeps MobaXterm and SFTP; adds centralized AWS authorization; supports closing inbound SSH | Retains SSH credentials; adds identity/service/agent dependencies; does not automatically retain a source-IP restriction; SSM cannot record the encrypted SSH contents |
| SSH certificates or a dedicated access platform | Can provide short-lived host credentials and stronger identity-to-host integration | Adds issuer/service operation, enrollment, recovery, and client compatibility work beyond this small reference project |

## Decision

Use the third approach for these requirements. This is an architectural choice for authorized users who need SSH tooling, not a claim of absolute best practice. Generate a custom `Port` Session document with fixed remote port 22 and an agreed local port. Assign a narrow Identity Center permission set through a group. Keep authentication inside the official AWS CLI wizard and key handling inside the SSH client. Provide console instructions instead of an automatic cloud bootstrap that hides the IAM decisions.

The workstation launcher checks the intended account, permission-set name, and pinned generated SSO role. These checks address the actual wrong-role incident. They are deliberately described as mistake prevention: an operator can bypass a local script, so IAM must enforce the same target restriction independently.

## Consequences

- Direct SSH is retired only after positive, negative, and recovery checks.
- The reference policy permits authorized tunnel requests from other networks. An approved-egress requirement needs additional controls and tests; an Identity Center assignment is not a device or network attestation.
- Removing the direct route makes normal access depend on the identity provider, SSM service connectivity, and agent health. Recovery must account for those dependencies.
- The instance profile, Linux user, sudo policy, and alternate AWS roles remain separate privilege surfaces.
- Command recording is an explicit unmet requirement of this access pattern. Organizations that require it should evaluate a different pattern or independently managed host audit controls.
- A role recreated by Identity Center requires re-verifying and updating the local role pin.
- This is a single-target reference implementation. Multi-account enrollment, certificates, and policy deployment automation are future design work, not shipped capabilities.

The tradeoff is supported by [AWS's SSH-over-SSM documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html). The [case study](../case-study.md) records the actual learning sequence.
