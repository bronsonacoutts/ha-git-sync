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

## 4b) Migrate existing automations (first-time install only)

If your existing `automations.yaml` or `automations/` files contain automations
without an `id` field, Home Assistant cannot edit them from the UI after the sync
is set up.  Run the migration script once to add stable, deterministic ids:

```bash
python3 scripts/migrate_automations.py /config
```

Or trigger it from the HA Developer Tools → Services after adding the
shell command from `configuration.yaml.example`:

```yaml
service: shell_command.migrate_automations
```

The script is idempotent — automations that already have an id are not changed.
Original files are backed up as `<filename>.bak` before any writes.
After running, verify with:

```bash
python3 scripts/validate_automations.py /config
```

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
