# Operations Runbook

Day-to-day operation, recovery, rollback, and backup management.

## Normal day-to-day flow

After setup, normal operation requires no user intervention. The automations handle everything:

- **Hourly:** Full HA-hosted reconcile (`git_sync.sh`) runs automatically.
- **On UI-backed config change:** Lovelace updates plus UI-initiated YAML reloads trigger a debounced publish (3-minute quiet window).
- **On external GitHub push to `main`:** Webhook triggers a pull to HA.
- **Nightly at 03:00:** Backup tag created (`backup/nightly-YYYY-MM-DD`).
- **Weekly on Sunday at 02:30:** Tar.gz snapshot with immutable tag.

To check status manually:

```bash
bash scripts/git_status.sh
```

To publish local HA changes on demand:

```bash
bash scripts/git_push.sh
```

After each successful merge on the HA box, the installed `post-merge` hook runs
`scripts/ha_apply_changes.sh` to reload Home Assistant configuration or request
a full restart when the merged files require it.

## Recovery after failed sync job

1. Check what went wrong:

```bash
git status
git branch --show-current
git log --oneline -10
```

2. Run the individual steps separately to isolate the failure:

```bash
bash scripts/git_pull.sh     # fetch + merge only
bash scripts/git_push.sh     # commit + reconcile + PR + merge
```

3. If both fail, check network connectivity and credentials first.

## Conflict resolution

Conflicts are resolved automatically by sync scripts (`-X ours` = local wins). If you need to manually resolve:

1. Identify conflict files: `git status`
2. Edit each file to resolve.
3. Stage and commit: `git add -A && git commit -m "HA manual conflict resolution"`
4. Publish again from the HA host: `bash scripts/git_push.sh`

## Safe rollback

1. Find a known-good point:
   ```bash
   git log --oneline -20              # recent commits
   git tag -l "backup/nightly-*"      # nightly backup tags
   git tag -l "snapshot/weekly-*"     # weekly snapshot tags
   ```
2. Restore a specific file:
   ```bash
   git checkout <commit-hash> -- path/to/file.yaml
   ```
3. Or restore everything from a backup tag:
   ```bash
   git checkout backup/nightly-2026-03-15 -- .
   ```
4. Validate HA config, then commit and push the restoration.

## Backup and retention

| Backup type | Schedule | Retention | Tag format |
|---|---|---|---|
| Nightly tag | Daily at 03:00 | 30 days (configurable) | `backup/nightly-YYYY-MM-DD` |
| Weekly snapshot | Sunday at 02:30 | Permanent (immutable) | `snapshot/weekly-YYYY.WW` |

- Nightly tags are pruned by `git_cleanup_backups.sh` (default: keep last 30 days).
- Weekly snapshot tags are **never** auto-deleted.
- Snapshots contain config YAML only (database, media, and add-on data are excluded).

To manually prune old backup tags (keep last 14 days):

```bash
bash scripts/git_cleanup_backups.sh 14
```

## Operational guardrails

- Sync lock prevents concurrent git operations (auto-releases after 10 minutes if stale).
- Git hooks block empty/placeholder commit messages and accidental interactive pushes to `main`.
- All sync scripts use `set -euo pipefail` — any command failure stops execution immediately.
- HA-hosted publishes use a reusable `ha-sync/<host>` branch and wait for GitHub checks before merging to `main`.
- Optional GitHub Actions workflows require `.enabled` files to activate.
- Branch protection should require status checks before merge.
