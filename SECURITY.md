# Security Policy

## Supported versions

This project is maintained on a best-effort basis. Security fixes are typically applied to the default branch.

## Reporting a vulnerability

Please do not open public issues for sensitive security findings.

1. Open a private security advisory in GitHub Security for this repository.
2. Include impact, reproduction details, and affected files.
3. Include any proof-of-concept data with secrets redacted.

If private advisory is unavailable, contact the maintainer through repository contact channels in [SUPPORT.md](SUPPORT.md) and clearly mark the report as sensitive.

## Response targets

- Initial triage: within 7 days when possible.
- Resolution timeline: depends on severity and complexity.

## Scope

In scope:

- Credential exposure risks in scripts/workflows.
- Unsafe defaults that can lead to secret leakage.
- Branch protection or CI bypass vectors.

Out of scope:

- Generic dependency CVEs with no practical impact on this repository.
- Misconfigurations in downstream forks not reproducible here.
