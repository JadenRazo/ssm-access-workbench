# ADR 001: Preserve SSH behind a scoped Session Manager tunnel

**Status:** Accepted for this reference implementation

**Scope:** Windows operators accessing a Linux EC2 instance with MobaXterm

**Date:** 2026-09-11

## Context and acceptance criteria

The existing workflow depends on MobaXterm's terminal and SFTP browser. Access should be attributable to an AWS identity, restricted to one managed node, and repeatable on a new workstation. The operator also needs to understand the configuration through the AWS console.

A successful implementation has a clear AWS authorization boundary, preserves host-key verification, avoids embedded credentials, detects a wrongly selected account or administrative role, and documents negative tests and recovery before removing direct SSH. Public claims must match the verification ledger.

## Options considered

| Approach | Advantages | Failure mode or tradeoff |
| :--- | :--- | :--- |
| Direct SSH restricted to a source IP | Simple; existing tools work immediately | No AWS authorization decision for each new connection; source addresses change; long-lived key and network access can survive AWS offboarding |
| Native Session Manager shell | Can avoid SSH keys and inbound SSH; supports configured session output logging | Changes the terminal/file-transfer workflow; default host privileges need scrutiny; logging must actually be configured and validated |
| SSH through a scoped SSM tunnel | Keeps MobaXterm and SFTP; adds AWS authorization; supports closing inbound SSH | Retains SSH credentials and host administration; SSM cannot record the encrypted SSH contents |
| SSH certificates or a dedicated access platform | Can provide short-lived host credentials and stronger identity-to-host integration | Adds issuer/service operation, enrollment, recovery, and client compatibility work beyond this small reference project |

## Decision

Use the third approach. Generate a custom `Port` Session document with fixed remote port 22 and an agreed local port. Assign a narrow Identity Center permission set through a group. Keep authentication inside the official AWS CLI wizard and key handling inside the SSH client. Provide console instructions instead of an automatic cloud bootstrap that hides the IAM decisions.

The workstation launcher checks the intended account, permission-set name, and pinned generated SSO role. These checks address the actual wrong-role incident. They are deliberately described as mistake prevention: an operator can bypass a local script, so IAM must enforce the same target restriction independently.

## Consequences

- Direct SSH is retired only after positive, negative, and recovery checks.
- The instance profile, Linux user, sudo policy, and alternate AWS roles remain separate privilege surfaces.
- Command recording is an explicit unmet requirement of this access pattern. Organizations that require it should evaluate a different pattern or independently managed host audit controls.
- A role recreated by Identity Center requires re-verifying and updating the local role pin.
- This is a single-target reference implementation. Multi-account enrollment, certificates, and policy deployment automation are future design work, not shipped capabilities.

The tradeoff is supported by [AWS's SSH-over-SSM documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html). The [case study](../case-study.md) records the actual learning sequence.
