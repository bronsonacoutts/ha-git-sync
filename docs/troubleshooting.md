# Troubleshooting

Use this index by symptom. Each section lists likely cause and concrete fix steps.

## Sync job fails with auth error

**Symptoms**
- `Permission denied (publickey)`
- `Authentication failed`

**Fix**
1. Verify remote URL: `git remote -v`.
2. Confirm correct key/token is configured.
3. Re-test with `git fetch origin`.

## Optional workflow does not run

**Symptoms**
- No run in Actions tab.

**Fix**
1. Confirm Actions are enabled in repo settings.
2. Confirm `.github/upstream-sync.enabled` or `.github/automation-alias-autocorrect.enabled` exists.
3. Trigger manually with `workflow_dispatch`.

## Optional workflow runs but no PR is opened

**Symptoms**
- Workflow completes successfully, no PR.

**Fix**
- Review workflow summary: often means no changes were detected.

## Upstream sync reports merge conflicts

**Fix**
1. Pull upstream changes locally.
2. Resolve conflicts in your `main` branch.
3. Push resolved `main`.
4. Rerun workflow.

## Shell script exits immediately

**Symptoms**
- Script fails with minimal output.

**Fix**
1. Run with tracing: `bash -x scripts/git_sync.sh`.
2. Fix first failing command.
3. Re-run without `-x` after fix.

## Hooks are not enforced

**Fix**
1. Run `bash scripts/install_git_hooks.sh`.
2. Confirm `.git/hooks/commit-msg` and `.git/hooks/pre-push` exist and executable.

## Local branch is detached

**Fix**
1. `git checkout main`
2. `git pull --ff-only origin main`

## YAML breaks after merge

**Fix**
1. Validate YAML formatting.
2. Compare against last known-good commit.
3. Revert only the broken section if needed.

## Home Assistant fails after sync

**Fix**
1. Review Home Assistant logs.
2. Roll back to known-good commit/tag.
3. Restart Home Assistant and validate.

## Unexpected mass file changes

**Fix**
1. Run `git status` and inspect diff.
2. Check generated files, backup artifacts, and ignore rules.
3. Commit only intentional changes.

## Still stuck?

Use [../SUPPORT.md](../SUPPORT.md) for support paths and issue reporting expectations.
