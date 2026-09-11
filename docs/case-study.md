# From a saved SSH bookmark to a deliberate access model

[← Project overview](../README.md) · [Practice the explanation →](interview-prep.md)

## Starting point

The source lab used MobaXterm on Windows to reach a Linux EC2 instance with a private SSH key and a security-group rule restricted to the operator's public IP. Those were existing authentication and network controls. The operator wanted AWS identity to govern the access path while retaining the terminal and file browser. The investigation initially focused on whether Session Manager could replace the key, then became a review of the boundaries between AWS authentication, network access, and Linux authorization.

The useful result was both a working scoped SSO tunnel and a repeatable onboarding toolkit. The wider hardening work was not treated as complete just because a terminal opened.

## The engineering work

The design places an IAM-authorized Session Manager tunnel in front of SSH. An account-owned Session document fixes forwarding to port 22. An Identity Center group receives a dedicated permission set for one instance and document. The client verifies its account and role before requesting a session, while MobaXterm continues to authenticate against Linux with a protected SSH key.

The original working launcher had deployment-specific identifiers. This repository turns the workflow into interactive, reusable PowerShell scripts, sanitized templates, console instructions, and tests that deliberately exercise failures. The scripts generate reviewable files and use the official SSO wizard; they do not quietly provision cloud administration rights.

## Lessons that changed the design

**1. A permissions boundary is a ceiling, not a grant.** An early IAM-user sign-in troubleshooting step exposed a policy configured as a boundary without the necessary identity permission grant. Resetting a valid MFA device would not have fixed that authorization problem. The lesson was to inspect policy type and evaluation, not just the visible authentication error.

**2. A friendly profile name can hide the wrong account and role.** During Identity Center configuration, the CLI selected an administrator permission set in a different AWS account. `GetCallerIdentity` exposed the mismatch. That incident directly motivated the toolkit's profile, account, permission-set, and role-pin checks. Renaming a profile is not a security control.

**3. MFA and SSH operate at different layers.** Browser MFA authorizes the AWS sign-in. It does not replace the Linux key and does not run again for each SSH connection carried by an existing tunnel. Understanding cached credentials and session lifetimes was more useful than trying to force every connection into the same authentication story.

**4. Least privilege must include the route and the destination.** A successful `StartSession` required reviewing the EC2 ARN, document ARN, document access check, supported data-channel scope, and federated cleanup ownership. Missing `Resource` fields and misleading session-name assumptions became concrete policy review lessons.

**5. A secure transport does not prove a secure host.** The source lab still required verification of direct-SSH retirement, instance-role reduction, host privileges, durable audit controls, and recovery. Those controls are explicit acceptance work in this project. A narrow human policy cannot compensate for broad credentials exposed from the instance profile.

**6. Audit limitations are a design choice, not a footnote.** CloudTrail can help attribute session lifecycle events, but Session Manager cannot inspect the inner SSH stream. Keeping MobaXterm comes with that tradeoff. Requirements for command recording or short-lived host credentials would change the selected architecture.

**7. Choose controls against requirements.** A follow-up review found that the original public-IP SSH route still worked and was restricted to the operator's IP. That restriction was meaningful; the route nevertheless allowed access without AWS authorization. Requiring SSM would meet the project's identity requirement once the direct route was closed and verified. It would also add service and agent dependencies and, under the reference policy, allow authorized tunnel requests from other networks. The lesson was to explain that tradeoff accurately instead of calling one approach a universal enterprise standard.

## What was demonstrated

The source walkthrough verified the intended group/permission-set assignment and observed a live Session Manager tunnel owned by the intended Identity Center role. The operator reported connecting through MobaXterm. IAM policy validation returned no findings, and simulation checked the intended resource scope.

Those observations are a narrow lab result. There is no claim here of enterprise rollout, a completed penetration test, universal least privilege, or a measured security incident reduction. The [verification ledger](verification.md) separates inherited lab observations, automated toolkit checks, and remaining live acceptance work.

## Why package it this way?

A collection of console screenshots would explain one account at one moment. This repository instead preserves the decisions, failure modes, exact policy shape, and repeatable workstation behavior. Another operator can apply the pattern to their own lab without copying private identifiers, and a reviewer can ask how each claimed control is tested.

The next engineering steps would be completing the live denial/recovery matrix, independently reviewing workload permissions and host audit requirements, and deciding whether certificate-based SSH or native SSM better matches a larger organization's needs.
