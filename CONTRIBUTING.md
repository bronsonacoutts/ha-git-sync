# Contributing

Thanks for helping improve HA Git Sync. This project prioritizes safe defaults, predictable sync behavior, and practical docs for first-time Home Assistant users.

## First principles

- Keep pull requests small and focused.
- Preserve existing behavior unless fixing a confirmed bug.
- Prefer readability and operational safety over cleverness.
- Never commit secrets, credentials, or private keys.

## Before you start

1. Fork and clone your fork.
2. Create a branch from `main`.
3. Make the smallest change that solves the problem.

## Local quality checks

- Shell scripts: `shellcheck scripts/*.sh`
- YAML files: `yamllint .`

If a change affects behavior, include updated docs and a short rationale in the PR.

## Pull request expectations

- Use clear commit messages.
- Explain expected behavior before/after.
- Include reproduction and validation steps.
- Note any risk and rollback approach.

## AI-assisted development policy

AI assistance (including Copilot) is allowed, with guardrails:

- Human author remains accountable for correctness and security.
- Human review is required before merge.
- CI checks must pass before merge.
- Never paste secrets, tokens, private keys, or sensitive logs into AI tools.
- PRs should document non-obvious design decisions in human-written rationale.

## Reporting bugs

Open a bug issue and include:

- Home Assistant version and install type.
- Commands run and exact error output (redacted).
- Expected vs actual behavior.

## Feature requests

Open a feature request issue with:

- Problem statement.
- Proposed minimal solution.
- Security/safety impact.

## Support and security

- Support questions: use Discussions (see [SUPPORT.md](SUPPORT.md)).
- Security reports: follow [SECURITY.md](SECURITY.md).

## Community standards

Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
