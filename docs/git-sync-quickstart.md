# Git Sync Quick Start for Existing HA Repos

This guide shows how to add the current `ha-git-sync` flow to an existing Home
Assistant repository without copying outdated snippets by hand.

## What the current flow does

- `GitHub -> HA`: pull external changes to `origin/main` on webhook plus hourly.
- `HA -> GitHub`: after UI-backed config changes plus hourly, reconcile on the
  HA host, push a reusable `ha-sync/<host>` branch, open/update a PR, wait for
  CI and policy checks, merge to `origin/main`, then fast-forward the HA repo to
  the merge commit.
- Notifications: failures only.
- Hooks: local extension hooks can run before/after each direction.

## Files to copy into `/config`

Copy these paths from this repository into your HA config repo:

```text
scripts/
automations/meta_git.yaml
configuration.yaml.example
scripts.yaml.example
automations.yaml.example
hooks/
.gitconfig.example
.ssh/config.example
```

Make the shell scripts executable on the HA host:

```bash
chmod +x /config/scripts/*.sh
```

## Home Assistant configuration

Merge the examples into your live config:

- `configuration.yaml.example` for `automation:` and `shell_command:`
- `scripts.yaml.example` for the HA scripts
- `automations/meta_git.yaml` or `automations.yaml.example` for the automations

The important entities are:

- `script.maintenance_git_sync_config`
- `script.maintenance_git_pull_config`
- `script.maintenance_git_push_config`

`maintenance_git_push_config` is the debounced publisher. It waits three
minutes after the last UI-backed change, then runs the full reconcile flow.

## Credentials and tokens

You need two kinds of auth on the HA host:

1. Git transport auth so the HA repo can `fetch` and push `ha-sync/<host>`
   branches.
2. GitHub API auth so the HA host can create, monitor, and merge the sync PR.

Recommended setup:

- Git transport: SSH deploy key or fine-grained PAT, per [git-setup.md](git-setup.md)
- GitHub API: `GITHUB_API_TOKEN` or `GH_TOKEN` in the HA shell environment

If you do not want HA-hosted PR merges, set `GITHUB_SYNC_MODE=direct` and the
legacy direct-push path will be used instead.

## Webhook setup

For near-real-time `GitHub -> HA` sync:

1. Generate a webhook ID:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

2. Store it in `/config/secrets.yaml`:

```yaml
git_sync_webhook_id: "your-generated-secret-here"
```

3. Add `HA_WEBHOOK_URL` as a GitHub Actions secret:

```text
https://<your-ha-url>/api/webhook/<git_sync_webhook_id>
```

`notify-ha.yml` skips HA-originated sync merges by checking for the
`[ha-sync]` marker in the merge commit message, so the HA box does not pull back
the merge commit it just created.

## Hook directories

Local extension hooks live under `/config/hooks`:

- `pre-gh-to-ha.d/`
- `post-gh-to-ha.d/`
- `pre-ha-to-gh.d/`
- `post-ha-to-gh.d/`

Each executable file in those directories runs in lexical order. See
[../hooks/README.md](../hooks/README.md).

## First-run checklist

1. Install git hooks:

```bash
bash /config/scripts/install_git_hooks.sh
```

2. Validate automation IDs if you migrated existing automations:

```bash
python3 /config/scripts/validate_automations.py /config
```

3. Run a manual status check:

```bash
bash /config/scripts/git_status.sh
```

4. Run a manual full sync:

```bash
bash /config/scripts/git_sync.sh
```

5. Confirm the results:

- a `ha-sync/<host>` branch was pushed if HA had changes,
- a PR was opened or updated,
- CI ran on that PR,
- the PR merged,
- the HA working tree fast-forwarded to the merge commit,
- no success notification was emitted.

## Day-to-day behavior

- Hourly automation keeps HA and GitHub from drifting.
- UI-backed change automation batches edits behind a 3-minute quiet window.
- Webhook pulls only external `main` updates back into HA.
- Nightly and weekly backup jobs still run from the HA host.

## If the sync PR blocks

When `git_push.sh` or `git_sync.sh` fails waiting for the PR to merge:

1. Open the PR in GitHub.
2. Check required checks, required reviews, and branch rules.
3. Verify `CI` is configured for pull requests to `main`.
4. Confirm `GITHUB_API_TOKEN` on the HA host still has the needed repository permissions.

Use [operations.md](operations.md) for the recovery workflow and
[troubleshooting.md](troubleshooting.md) for common failure patterns.
