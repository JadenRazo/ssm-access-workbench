# Working on SSM Access Workbench

Help authorized Windows operators use a scoped SSH/SFTP path to EC2 through
centrally managed AWS access. This is a standalone public reference project,
not a production infrastructure repository.

Read `README.md`, `docs/decisions/001-access-pattern.md`, and the verification
ledger (`docs/verification.md`) before changing behavior. For a prose correction,
read the affected guide and its evidence. Use `docs/security-model.md` and
`docs/iam-policy.md` for access changes, `scripts/Workbench.psm1` for orchestration,
and `CONTRIBUTING.md` plus `.github/workflows/verify.yml` for validation.

- Keep AWS provisioning in the console runbook; scripts configure the local
  workstation and generate reviewable JSON. Real-cloud exercises stay manual
  and scoped to an authorized isolated lab, with current account, cost, session
  ownership and recovery understood. Never turn a negative authorization test
  into an unreviewed production operation.
- Never commit deployment identifiers, SSO URLs, private keys, credentials,
  session tokens, personal configuration or unsanitized logs. Preserve existing
  workstation settings and refuse unintended overwrites; use fictional examples.
- Caller identity checks prevent accidents. IAM, network controls and sshd
  enforce authorization. Local assertions do not simulate effective IAM policy.
- Do not claim SSH command recording, per-connection MFA, keyless SSH or
  completed live hardening without evidence. Compare IP-restricted SSH fairly;
  this pattern is not a universal enterprise standard. Keep historical test
  results dated and separate from live workstation/cloud acceptance.
- Keep PowerShell 7.4+ support and credential-free tests. No execution-policy
  bypass, downloaded-code execution or automatic elevation. Connection tests
  must never fall back from doubles to a real AWS session. CI retains read-only
  repository permissions and immutable Actions, without AWS secrets/access roles.

For behavior changes, run `pwsh -NoProfile -File tests/Run-Tests.ps1` and
`python3 tests/check_repository.py`; add a regression for the prevented failure.
For prose-only edits, run the repository check and inspect relevant links and
claims; the PowerShell suite is unnecessary unless executable examples or
behavior contracts change. Shortcut changes need the Windows job; Linux skips
COM integration. Inspect changed diagrams/README at narrow and desktop widths.
IAM changes also need the documented manual acceptance matrix in an authorized
lab; report separately what mocks, local processes and live checks establish.

Write docs for the operator's next action. Lead PRs with the problem and resulting
behavior, then actual validation and limits; preserve the PR template. Link
evidence instead of repeating logs. Follow existing commit conventions, otherwise
use `type: concrete change` (preferably under 72 characters). State local edits,
push/PR effects and publication accurately; passing CI is not live hardening.
