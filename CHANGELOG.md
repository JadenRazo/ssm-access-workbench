# Changelog

## Unreleased

- Clarify the intended audience and access requirements across the README, security model, console guide, decision record, and case study.
- Compare IP-restricted SSH and SSO/SSM fairly, including network controls, service dependencies, and credential exposure; update interview guidance and record the observed direct-route limitation.

## 0.1.0 — 2026-09-11

Initial reference implementation:

- Interactive generation of a fixed-port Session document and scoped Identity Center permission-set policy.
- Windows onboarding through the AWS SSO wizard, verified account/role configuration, and a desktop tunnel shortcut.
- Launcher checks for wrong identities, changed role pins, missing tools, unavailable credentials, and occupied ports.
- Console setup, MobaXterm configuration, least-privilege reasoning, offboarding, recovery, troubleshooting, and interview preparation.
- Original SVG diagrams, a recorded architecture decision, and an explicit verification ledger.
- Credential-free tests and Windows/Linux CI, including actual native-process and Windows shortcut checks.

Known scope: single-target commercial AWS accounts, PowerShell 7.4+, existing Linux SSH access. The live AWS wizard, plugin transport, MobaXterm UI, and full hardening matrix require manual workstation/lab verification; see [verification](docs/verification.md).
