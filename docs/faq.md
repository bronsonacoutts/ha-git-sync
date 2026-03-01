# FAQ

## Is this safe, or can it overwrite my configuration?

The sync job can merge and commit tracked changes. Use branch protection, review diffs, and validate Home Assistant before broad rollout.

## Can I use a private repository?

Yes. Private repositories are recommended for most users.

## Does this work if I make changes from the Home Assistant UI?

Usually yes. UI changes that are persisted to `/config` files are captured by sync jobs.

## Can I use this with multiple Home Assistant instances?

Yes, but use separate repositories or clearly isolated branch strategies per instance.

## Do I need both optional workflows enabled?

No. Both are optional and disabled by default. Enable only what you need.

## What happens if upstream template updates conflict with my setup?

The optional upstream sync workflow reports conflict and stops PR creation. Resolve manually, then rerun.

## Is this intended for beginners?

Yes. Start with [quickstart.md](quickstart.md), then use [operations.md](operations.md) as your runbook.

## How do I report a bug vs ask a question?

- Bug: open a GitHub issue using the bug template.
- Question/support: use Discussions per [../SUPPORT.md](../SUPPORT.md).
