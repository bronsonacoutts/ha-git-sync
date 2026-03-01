# Forum Launch Package

## Title options

1. **Home Assistant + GitHub Sync That Stays Safe by Default**
2. **I Built a Security-First Git Sync Template for Home Assistant Configs**
3. **Stop Config Drift in Home Assistant: GitHub-Backed Sync with Guardrails**

## Final post body

Hi everyone — I’m sharing **HA Git Sync**, a template-focused workflow to keep Home Assistant config reproducible, auditable, and easier to recover.

### What it does

- Bi-directional sync model between `/config` and GitHub.
- Optional GitHub Actions automations for upstream template sync and alias autocorrection PRs.
- Security-first defaults: optional features are off by default, and branch-protection-friendly checks are expected.

### Why I built it

I wanted a setup that reduces config drift and keeps recovery straightforward after bad edits or failed merges. This project aims to make that easy for first-time users while still being maintainable long-term.

### Start in about a minute

1. Use the template and clone to `/config`.
2. Configure Git auth (SSH or fine-grained token).
3. Merge the example HA snippets.
4. Run `bash scripts/git_sync.sh`.
5. Confirm checks pass in GitHub.

Docs:
- Quick start: `docs/quickstart.md`
- Security: `docs/security.md`
- Troubleshooting: `docs/troubleshooting.md`

Feedback is welcome — especially around edge cases in different Home Assistant installation modes.

## 60-second getting-started snippet

```bash
git clone git@github.com:<your-user>/<your-repo>.git /config
cd /config
bash scripts/install_git_hooks.sh
bash scripts/git_status.sh
bash scripts/git_sync.sh
```

## Known limitations and trade-offs

- Merge conflicts still require manual resolution.
- Quality of automation alias correction depends on your naming conventions.
- Workflow behavior relies on repository permissions and branch protection setup.

## Feedback request CTA

If you try this, please share:

- Your Home Assistant install type (OS/Container/Supervised/Core)
- Any setup steps that felt unclear
- Which guardrails you want enabled by default vs optional

## Suggested screenshots and captions

1. **Repository Actions overview** — “Optional sync and autocorrect workflows in one place.”
2. **PR with checks passing** — “Review-first flow with required checks.”
3. **Home Assistant terminal run** — “First safe sync job from `/config`.”
4. **Docs quick start section** — “Beginner-focused onboarding path.”
