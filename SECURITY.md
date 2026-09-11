# Security policy

This is a reference toolkit and documented lab, not a managed access service or a security certification. Review the [security model](docs/security-model.md) and [verification limits](docs/verification.md) before adapting it to a real environment.

Security fixes are maintained on `main`. There is no promised response SLA or support for modified deployments.

## Report a vulnerability

Use GitHub's **Security → Report a vulnerability** for a private report:

[Open a private security report](https://github.com/JadenRazo/ssm-access-workbench/security/advisories/new)

Include the affected commit, PowerShell/OS versions, a sanitized reproduction, expected behavior, and impact. Do not send AWS credentials, SSO tokens, private keys, or actual account/session identifiers. If private reporting is unavailable, open a public issue asking for a private contact method without disclosing exploit details or sensitive data.

## Before sharing diagnostics

- Remove deployment identifiers and personal portal URLs.
- Exclude AWS config/credential files and SSO caches.
- Exclude plugin tokens and `--debug` output.
- Use the fictional values in `examples/` for a reproduction.

The toolkit does not bypass execution policy, store SSH credentials, silently elevate, or automatically widen AWS permissions. These are invariants for contributions.
