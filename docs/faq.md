# FAQ

## Is this safe, or can it overwrite my configuration?

Sync scripts use `git merge -X ours`, which means your local Home Assistant edits always win over remote changes on line-level conflicts. Non-conflicting remote changes merge cleanly. The scripts never force-push to `main` and never discard local uncommitted work (they commit first, then merge).

## Can I use a private repository?

Yes. Private repositories are recommended for most users since Home Assistant configs can contain hostnames, network details, and entity names you may not want public.

## How does this relate to hass-autosync-lint?

`ha-git-sync` is the canonical public core — shell scripts, automations, and configuration examples for Git-backed sync. `hass-autosync-lint` is the companion HACS integration layer that wraps this sync model with Home Assistant-native setup, status, and repair UI.

## Does this work if I make changes from the Home Assistant UI?

Yes, with two requirements:
1. Your `configuration.yaml` must include `automation: !include_dir_merge_list automations/` so HA reads from and writes back to the same files tracked in Git.
2. Every automation must have a unique `id` field. Without one, HA will refuse to show it in the UI editor.

The built-in push-on-UI-change automation detects `lovelace_updated` events and triggers a debounced sync after a 3-minute quiet window.

## Can I use this with multiple Home Assistant instances?

Yes. Use a separate repository for each instance. Do not point multiple HA instances at the same repo/branch — this will cause conflicting writes.

## Do I need both optional workflows enabled?

No. Both are disabled by default (they require `.enabled` files to activate). Enable only what you need:
- Upstream sync PRs: useful if you forked the template and want to pull in updates.
- Alias autocorrect: normalizes automation alias formatting.

## What happens if upstream core updates conflict with my setup?

The optional upstream sync workflow creates a PR with the changes. If there are conflicts, it reports them in the PR and stops. You resolve manually, then merge.

## Is this intended for beginners?

Yes. Start with [quickstart.md](quickstart.md), follow the step-by-step setup, then the automations handle everything. The [operations.md](operations.md) runbook covers day-to-day operation and recovery.

## How do I report a bug vs ask a question?

- **Bug:** Open a GitHub issue with your HA version, install type, exact error output (redacted), and steps to reproduce.
- **Question/help:** Use GitHub Discussions per [../SUPPORT.md](../SUPPORT.md).

## Does this back up my entire Home Assistant installation?

No. This backs up **tracked config files** (YAML automations, scripts, configuration). The HA database (`home-assistant_v2.db`), add-on data, media, and cloud state are excluded. Use HA's built-in backup system for full disaster recovery.

## What happens if my SSH key or token expires?

Sync jobs will fail with an authentication error and (if configured) send a notification to HA. You must manually renew the credential and update the HA host. There is no automatic credential rotation.

## Can I customize the sync schedule?

Yes. Edit the trigger in `automations/meta_git.yaml`. For example, change the hourly sync to every 15 minutes:

```yaml
trigger:
- platform: time_pattern
  minutes: "/15"
```
