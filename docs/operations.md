# Operations Runbook

This runbook focuses on predictable daily operation, recovery, and rollback.

## Normal day-to-day flow

1. Make config changes in Home Assistant.
2. Run or wait for scheduled sync job.
3. Confirm clean repository state:

```bash
bash scripts/git_status.sh
```

4. If changes are expected, push:

```bash
bash scripts/git_push.sh
```

## Recovery after failed sync job

1. Capture current state:

```bash
git status
git branch --show-current
git log --oneline -10
```

2. Run pull step separately:

```bash
bash scripts/git_pull.sh
```

3. Resolve any conflicts.
4. Run push step:

```bash
bash scripts/git_push.sh
```

## Conflict resolution flow

1. Identify conflict files with `git status`.
2. Resolve each file deliberately.
3. Validate Home Assistant config syntax.
4. Commit with clear message describing conflict context.
5. Push and verify CI checks.

## Safe rollback flow

1. Find a known-good commit or backup tag.
2. Test in a staging copy if available.
3. Apply rollback in `/config`.
4. Restart Home Assistant and confirm behavior.
5. Record rollback reason in commit message.

## Backup and retention routine

- Nightly backup script creates dated backup tags.
- Weekly snapshot stores archive artifacts.
- Cleanup script prunes older backup tags.

## Operational guardrails

- Keep optional automation behind `.enabled` files.
- Keep branch protections active.
- Require checks before merge to `main`.
