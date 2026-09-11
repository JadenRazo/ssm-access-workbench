# Working on SSM Access Workbench

This is a standalone public portfolio project, not a production infrastructure repository.
Read the README, architecture decision, and verification ledger before changing behavior.

- Keep AWS provisioning in the console runbook; scripts configure the local workstation and generate reviewable JSON.
- Never commit deployment identifiers, SSO URLs, private keys, credentials, session tokens, personal configuration, or unsanitized logs.
- Treat caller identity checks as accident prevention. IAM, network controls, and sshd enforce authorization.
- Do not claim SSH command recording, per-connection MFA, keyless SSH, or completed live hardening without evidence.
- Present this as a reference pattern for authorized operators who require SSH/SFTP and centrally managed AWS access. Compare IP-restricted SSH fairly; do not call this an absolute best practice or universal enterprise standard.
- Keep PowerShell 7.4+ support; tests must run without AWS credentials. No execution-policy bypass, downloaded-code execution, or automatic elevation.
- Run `pwsh -NoProfile -File tests/Run-Tests.ps1` and `python3 tests/check_repository.py` before publishing changes. Review rendered diagrams and README when visuals change.
- Keep real-cloud exercises manual and scoped to an isolated lab. Never turn a negative authorization test into an unreviewed production operation.
