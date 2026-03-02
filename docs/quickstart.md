# Quick Start

This guide gets a first-time Home Assistant user from template creation to a safe first sync job.

## 1) Prerequisites

- Home Assistant instance with shell access to `/config`.
- Git installed on the HA host.
- GitHub account and repository access.
- A private repository is strongly recommended.

## 2) Create your repository

1. Open this project on GitHub.
2. Select **Use this template**.
3. Create your new repository under your account.
4. Clone it to your Home Assistant host:

```bash
git clone git@github.com:<your-user>/<your-repo>.git /config
cd /config
```

## 3) Configure authentication

Follow [git-setup.md](git-setup.md) to configure SSH or token-based Git access.

## 4) Add Home Assistant snippets

Use the examples in repository root:

- `configuration.yaml.example`
- `scripts.yaml.example`
- `automations.yaml.example`

Merge them into your existing Home Assistant config (do not replace unrelated sections).

## 5) Install local guardrails

```bash
bash scripts/install_git_hooks.sh
```

This enables commit message validation and blocks direct pushes to protected branches from local scripts.

## 6) Optional GitHub Actions features

Enable by creating these files in your repo:

- `.github/upstream-sync.enabled` for upstream template sync PRs (`.github/workflows/upstream-sync-pr.yml`).
- `.github/automation-alias-autocorrect.enabled` for alias normalization PRs (`.github/workflows/automation-alias-autocorrect.yml`).

## 7) Run your first safe sync job

```bash
bash scripts/git_status.sh
bash scripts/git_sync.sh
```

## 8) Verify checks and status

In GitHub, verify these checks on your latest commit/PR:

- `CI / shellcheck`
- `CI / yamllint`
- `CodeQL`

## 9) Next steps

- Read [operations.md](operations.md) for day-to-day and recovery procedures.
- Read [security.md](security.md) before enabling broad automation.
- Use [troubleshooting.md](troubleshooting.md) when symptoms appear.
