# Security

This project is designed with safe defaults, but final security depends on your repository and Home Assistant environment.

## Security posture

- Least-privilege Git credentials.
- Human review before high-impact changes.
- Optional workflows disabled by default.
- Sync job behavior is explicit and script-based.

## Credential guidance

## Home Assistant side

- Store secrets in `secrets.yaml`.
- Keep SSH private keys outside tracked files where possible.
- Restrict filesystem permissions to Home Assistant runtime user.

## GitHub side

- Prefer `GITHUB_TOKEN` in workflows when possible.
- If using PATs, use fine-grained tokens scoped to one repository.
- Set expiration and rotate regularly.

## What must never be committed

- Private keys (`id_rsa`, `*.pem`, `*.key`).
- Access tokens and API credentials.
- Plaintext credentials in YAML, scripts, or docs.
- Full backups that include sensitive runtime secrets.

## Repository hardening checklist

- Protect `main` with PR-only merges.
- Require status checks: `CI / shellcheck`, `CI / yamllint`, `CodeQL`.
- Enable secret scanning and push protection.
- Enable Dependabot alerts and automated security updates.
- Restrict who can bypass branch protections.

## Incident response

If a secret is exposed:

1. Revoke and rotate the credential immediately.
2. Remove exposed value from code and history if required.
3. Review audit logs and security alerts.
4. Validate repository access and workflow permissions.
5. Resume sync jobs only after verification.

## Reporting a vulnerability

Please follow [../SECURITY.md](../SECURITY.md) for responsible disclosure steps.
