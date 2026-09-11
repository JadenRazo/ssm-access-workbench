# Contributing

Changes should make this single-target reference workflow easier to inspect, reproduce, or verify. Keep cloud provisioning in the console guide unless a separate design decision introduces an automated deployment path.

## Development

Use PowerShell 7.4+ and Python 3.10+. No AWS credentials or third-party test framework are required.

```powershell
pwsh -NoProfile -File .\tests\Run-Tests.ps1
python .\tests\check_repository.py
```

Run the Windows job for shortcut changes and inspect the README and diagrams at narrow and desktop widths for documentation changes. The native-process tests execute a harmless local PowerShell fixture; connection tests replace the AWS adapter with deterministic responses. They must never fall back to an actual AWS session.

For a behavioral change, add a test for the failure it prevents. For an IAM change, document the authorization reasoning, validate the JSON with AWS tools in an authorized lab, and update the manual acceptance matrix. A local string assertion is not an IAM policy simulator.

## Pull requests

Explain the problem, resulting behavior, relevant validation, and remaining limitations. Use fictional identifiers from `examples/`. Never include credentials, deployment configuration, raw AWS debug output, personal SSO URLs, or private key material.

GitHub Actions is pinned to immutable action commits and has read-only repository permissions. Do not add AWS secrets or a production access role to this workflow.

Report security issues through the process in [SECURITY.md](SECURITY.md), not with a public exploit containing account details.
