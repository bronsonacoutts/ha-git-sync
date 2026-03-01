# Git Sync Quick-Start — Add Automated Git Sync to Your HA Setup

This guide walks you through merging the automated git sync system into an
**existing** Home Assistant configuration in under 15 minutes.

> **What you get:**
> - 🔄 Auto-push to GitHub every hour and after every dashboard edit
> - 🔄 Auto-pull from GitHub every hour so HA stays in sync with `main`
> - 🌙 Nightly dated backup commits + recovery tags
> - 📸 Weekly tar.gz snapshot
> - 🪝 Git hooks that prevent accidental direct pushes to `main`

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Home Assistant OS, Container, or Supervised | Core may work but is untested |
| Terminal & SSH add-on (or shell access) | Required to run commands |
| A GitHub repository for your config | Public or private both work |
| Git configured on the HA host | Usually pre-installed on HA OS |

---

## Step 1 — Copy the Scripts

Copy the following directory into your `/config` folder:

```
scripts/
  git_push.sh
  git_pull.sh
  git_sync.sh
  git_status.sh
  git_nightly_backup.sh
  git_weekly_snapshot.sh
  git_cleanup_backups.sh
  install_git_hooks.sh
  fix_automation_aliases.sh
  fix_automation_aliases.py
  git_hooks/
    commit-msg
    pre-push
```

From the terminal on your HA host:

```bash
# If merging from a cloned copy of this repo:
cp -r /path/to/this-repo/scripts /config/scripts

# Make all scripts executable
chmod +x /config/scripts/*.sh
chmod +x /config/scripts/git_hooks/*
```

---

## Step 2 — Add Shell Commands to `configuration.yaml`

Add the following block to your `/config/configuration.yaml`:

```yaml
shell_command:
  git_pull: /bin/bash /config/scripts/git_pull.sh
  git_push: /bin/bash /config/scripts/git_push.sh
  git_status: /bin/bash /config/scripts/git_status.sh
  git_nightly_backup: /bin/bash /config/scripts/git_nightly_backup.sh
  git_weekly_snapshot: /bin/bash /config/scripts/git_weekly_snapshot.sh
  git_cleanup_backups: /bin/bash /config/scripts/git_cleanup_backups.sh
  install_git_hooks: /bin/bash /config/scripts/install_git_hooks.sh
  fix_automation_aliases: /bin/bash /config/scripts/fix_automation_aliases.sh
```

> If you already have a `shell_command:` block, add the keys inside it — do
> not create a second `shell_command:` block.

---

## Step 3 — Add Scripts to `scripts.yaml`

Add the following to your `/config/scripts.yaml` (create the file if it does
not exist, and ensure `script: !include scripts.yaml` is in
`configuration.yaml`):

```yaml
maintenance_git_sync_config:
  alias: "[Maintenance] Git Sync Config"
  description: "Pull upstream changes then push local changes to origin"
  sequence:
    - service: shell_command.git_pull
    - service: shell_command.git_push
  mode: single

maintenance_git_push_config:
  alias: "[Maintenance] Git Push Config"
  description: >-
    Debounced push: waits for a 3-minute quiet window after the last UI change
    before committing and pushing.
  sequence:
    - delay: "00:03:00"
    - service: shell_command.git_push
  mode: restart

maintenance_git_status:
  alias: "[Maintenance] Git Status"
  description: "Check git status of config directory"
  sequence:
    - service: shell_command.git_status
  mode: single

maintenance_fix_automation_aliases:
  alias: "[Maintenance] Fix Automation Aliases"
  description: "Optional: normalize automation aliases to [Area] Action (Trigger/Context) format"
  sequence:
    - service: shell_command.fix_automation_aliases
  mode: single
```

---

## Step 4 — Add Automations to `automations.yaml`

Append the following automations to your `/config/automations.yaml`.

> **Important:** every automation needs a unique `id`. The IDs below are safe
> to use as-is; change them only if they clash with IDs already in your file.

```yaml
- id: '1767772677262'
  alias: '[Maintenance] Reload Automations After Git Sync'
  description: 'Reload automations whenever a git sync completes'
  trigger:
  - entity_id: script.maintenance_git_sync_config
    from: 'on'
    to: 'off'
    trigger: state
  condition: []
  action:
  - data: {}
    action: automation.reload
  mode: single

- id: '1767772690727'
  alias: '[Maintenance] Git Sync Hourly'
  description: 'Pull from GitHub then push local changes every hour'
  trigger:
  - hours: '*'
    minutes: 0
    trigger: time_pattern
  condition: []
  action:
  - target:
      entity_id: script.maintenance_git_sync_config
    action: script.turn_on
  mode: single

- id: '1767773315131'
  alias: '[Maintenance] Push Git Config After UI Changes (lovelace_updated)'
  description: 'Debounced push whenever the Lovelace dashboard is saved'
  trigger:
  - event_type: lovelace_updated
    trigger: event
  condition: []
  action:
  - target:
      entity_id: script.maintenance_git_push_config
    action: script.turn_on
  mode: single

- id: '1772117850002'
  alias: '[Maintenance] Nightly Config Backup'
  description: 'Commit with dated message and push at 03:00 every night'
  trigger:
  - at: '03:00:00'
    trigger: time
  condition: []
  action:
  - action: shell_command.git_nightly_backup
  mode: single

- id: '1772117850003'
  alias: '[Maintenance] Weekly Config Snapshot'
  description: 'Create a tar.gz snapshot every Sunday at 02:30'
  trigger:
  - at: '02:30:00'
    trigger: time
  condition:
  - condition: time
    weekday:
    - sun
  action:
  - action: shell_command.git_weekly_snapshot
  mode: single

- id: '1772117850004'
  alias: '[Maintenance] Monthly Backup Tag Cleanup'
  description: 'Prune backup/nightly-* tags older than 30 days on the 1st'
  trigger:
  - at: '04:00:00'
    trigger: time
  condition:
  - condition: template
    value_template: "{{ now().day == 1 }}"
  action:
  - action: shell_command.git_cleanup_backups
  mode: single

- id: '1772117850005'
  alias: '[Maintenance] Install Git Hooks On Startup'
  description: 'Ensure commit-msg and pre-push hooks are active after every HA restart'
  trigger:
  - trigger: homeassistant
    event: start
  condition: []
  action:
  - action: shell_command.install_git_hooks
  mode: single

- id: '1772117850006'
  alias: '[Maintenance] Optional Alias Auto-Correction Weekly'
  description: 'Optional: normalize automation aliases weekly before backup'
  trigger:
  - at: '01:45:00'
    trigger: time
  condition:
  - condition: time
    weekday:
    - sun
  action:
  - target:
      entity_id: script.maintenance_fix_automation_aliases
    action: script.turn_on
  mode: single
```

---

## Step 5 — Set Up Git Authentication

The scripts need credentials to push to GitHub. Follow the
[Git Authentication Setup Guide](git-setup.md) to configure either:

- **SSH with a deploy key** (recommended — no token expiry, scoped to one repo)
- **HTTPS with a Personal Access Token** (simpler to start with)

The quick version for SSH:

```bash
# On your HA host
mkdir -p /config/.ssh && chmod 700 /config/.ssh
ssh-keygen -t ed25519 -C "homeassistant-git" -f /config/.ssh/id_ed25519 -N ""

# Copy the public key and add it to GitHub:
# Repository → Settings → Deploy keys → Add deploy key (Allow write access ✅)
cat /config/.ssh/id_ed25519.pub

# Copy the example SSH config
cp /config/.ssh/config.example /config/.ssh/config
chmod 600 /config/.ssh/config
ssh-keyscan -t ed25519 github.com >> /config/.ssh/known_hosts
chmod 644 /config/.ssh/known_hosts

# Switch remote to SSH
cd /config
git remote set-url origin git@github.com:<your-username>/<your-repo>.git
```

Then copy `.gitconfig.example` to `.gitconfig` and fill in your name and
email:

```bash
cp /config/.gitconfig.example /config/.gitconfig
# Edit name and email fields in /config/.gitconfig
```

---

## Step 6 — Reload and Verify

1. **Reload configuration** — Developer Tools → YAML, then run **Reload all YAML**  
   (or restart Home Assistant)

2. **Check scripts exist** — Developer Tools → States, search
   `script.maintenance_git`

3. **Run a manual sync** — Developer Tools → Actions, run
   `script.maintenance_git_sync_config`

4. **Check the result** — go to your GitHub repository and confirm a new
   commit appears

5. **Install hooks** — Developer Tools → Actions, run
  `shell_command.install_git_hooks` once to install
   the pre-push hook immediately (the startup automation will keep it active
   after restarts)

---

## How It Works

### Push (HA → GitHub)

```
Local change saved
      │
      ▼
lovelace_updated event fired
      │
      ▼
script.maintenance_git_push_config starts 3-min timer
      │   (mode: restart → any new event resets the timer)
      ▼
Timer expires (quiet for 3 min)
      │
      ▼
git add -A  →  git commit  →  git push origin main
```

The hourly sync (`maintenance_git_sync_config`) also pushes at the top of
every hour, so no change is ever more than ~60 minutes behind.

### Pull (GitHub → HA)

```
Every hour at :00
      │
      ▼
git fetch origin main
      │
      ▼
git merge --no-edit -X ours origin/main
      │  (local HA copy wins any line-level conflict)
      ▼
git push origin main  (publishes merged result)
      │
      ▼
automation.reload  (new YAML is picked up immediately)
```

### Conflict Resolution

`-X ours` means that if the **same line** was edited both on HA and on GitHub,
the HA copy wins. Changes on GitHub that do not touch the same lines are always
accepted cleanly.

---

## Customisation

| What to change | Where |
|----------------|-------|
| Sync frequency (default: hourly) | `time_pattern` trigger in the hourly automation |
| Push debounce window (default: 3 min) | `delay` in `maintenance_git_push_config` |
| Nightly backup time (default: 03:00) | `at` trigger in the nightly backup automation |
| Weekly snapshot day/time | `at` + `weekday` in the weekly snapshot automation |
| Backup tag retention (default: 30 days) | `scripts/git_cleanup_backups.sh` |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Script not found in HA | Reload YAML (`automation.reload` + `script.reload`) |
| `Permission denied` on push | Re-check SSH key is added to GitHub deploy keys with write access |
| `fatal: detected dubious ownership` | Add `safe.directory = /config` to `/config/.gitconfig` |
| Push fails repeatedly | Run `shell_command.git_status` and check HA logs for error detail |
| Hooks not installed | Developer Tools → Actions, run `shell_command.install_git_hooks` manually |
| Alias correction does nothing | Install `pyyaml` in your HA shell Python environment, then re-run `shell_command.fix_automation_aliases` |

For detailed authentication troubleshooting see [git-setup.md](git-setup.md).

---

## Files Added by This Template

```
scripts/
├── git_push.sh               # Commit + push to origin
├── git_pull.sh               # Fetch + merge from origin
├── git_sync.sh               # Full bidirectional sync
├── git_status.sh             # Print status
├── git_nightly_backup.sh     # Nightly backup commit + tag
├── git_weekly_snapshot.sh    # Weekly tar.gz snapshot
├── git_cleanup_backups.sh    # Prune old backup tags
├── install_git_hooks.sh      # Install git hooks
├── fix_automation_aliases.sh  # Optional alias correction shell wrapper
├── fix_automation_aliases.py  # Optional alias correction engine
└── git_hooks/
    ├── commit-msg            # Enforce commit message format
    └── pre-push              # Block direct pushes to main
.gitconfig.example            # Template for /config/.gitconfig
.ssh/config.example           # Template for /config/.ssh/config
docs/
└── git-setup.md              # Full authentication setup guide
```

---

**Next steps:** Read the full [git-setup.md](git-setup.md) for authentication
options, security best practices, and migration guides.
