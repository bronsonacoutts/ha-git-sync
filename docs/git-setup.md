# Git Authentication Setup Guide

This guide explains how to configure Git authentication for Home Assistant to enable automated git sync operations.

## Overview

The Home Assistant configuration uses shell scripts for git operations (pull, push, sync). These operations require proper authentication to work. You have **two authentication options**:

1. **SSH Authentication** (Recommended) - More secure, better for automation
2. **HTTPS with Personal Access Token** - Simpler setup, less secure

Choose the method that works best for your setup.

---

## Prerequisites

Before starting, ensure you have:

- Terminal & SSH add-on installed and running
- Access to your GitHub account
- Permission to add deploy keys or create Personal Access Tokens (PATs)

---

## Option 1: SSH Authentication (Recommended)

SSH authentication is more secure and ideal for automated operations.

### Step 1: Generate SSH Key Pair

From the Terminal & SSH add-on:

```bash
# Create .ssh directory if it doesn't exist
mkdir -p /config/.ssh
chmod 700 /config/.ssh

# Generate SSH key (press Enter for all prompts to use defaults)
ssh-keygen -t ed25519 -C "homeassistant-git" -f /config/.ssh/id_ed25519 -N ""

# Set proper permissions
chmod 600 /config/.ssh/id_ed25519
chmod 644 /config/.ssh/id_ed25519.pub
```

### Step 2: Add Public Key to GitHub

```bash
# Display your public key
cat /config/.ssh/id_ed25519.pub
```

Copy the entire output, then:

1. Go to your GitHub repository: `https://github.com/yourusername/home-assistant-config`
2. Navigate to **Settings** → **Deploy keys**
3. Click **Add deploy key**
4. Title: `Home Assistant Config Sync`
5. Paste the public key
6. ✅ Check **Allow write access** (required for push operations)
7. Click **Add key**

### Step 3: Create SSH Config File

```bash
# Copy the example config
cp /config/.ssh/config.example /config/.ssh/config
chmod 600 /config/.ssh/config
```

Or create manually:

```bash
cat > /config/.ssh/config << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile /config/.ssh/id_ed25519
    StrictHostKeyChecking yes
    UserKnownHostsFile /config/.ssh/known_hosts
    IdentitiesOnly yes
    ConnectTimeout 10
EOF

# Add GitHub's host key to known_hosts (recommended)
ssh-keyscan -t ed25519 github.com >> /config/.ssh/known_hosts
chmod 644 /config/.ssh/known_hosts

chmod 600 /config/.ssh/config
```

### Step 4: Update Git Remote to Use SSH

```bash
cd /config

# Check current remote URL
git remote -v

# If using HTTPS, change to SSH
git remote set-url origin git@github.com:yourusername/home-assistant-config.git

# Verify the change
git remote -v
# Should show: git@github.com:yourusername/home-assistant-config.git
```

### Step 5: Configure Git User Information

```bash
# Copy the example config
cp /config/.gitconfig.example /config/.gitconfig

# Edit with your information
nano /config/.gitconfig
```

Update these fields in `.gitconfig`:
```ini
[user]
    name = Your Name
    email = your.email@example.com
```

Save the file (Ctrl+O, Enter, Ctrl+X in nano).

### Step 6: Test SSH Connection

```bash
# Test GitHub SSH connection
ssh -T git@github.com
```

Expected output:
```
Hi yourusername! You've successfully authenticated, but GitHub does not provide shell access.
```

### Step 7: Test Git Operations

```bash
cd /config

# Test pull
git pull origin main

# Test push (creates a test commit)
echo "# Test" >> /tmp/test.txt
git add /tmp/test.txt
git commit -m "Test git authentication"
git push origin main

# Clean up test file
git rm /tmp/test.txt
git commit -m "Remove test file"
git push origin main
```

✅ **If all commands succeed, SSH authentication is working!**

---

## Option 2: HTTPS Authentication with PAT

HTTPS with a Personal Access Token is simpler to set up but less secure.

### Step 1: Create Personal Access Token

1. Go to GitHub: **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token** → **Generate new token (classic)**
3. Token description: `Home Assistant Config Sync`
4. Expiration: Choose appropriate expiration (1 year recommended)
5. Select scopes:
   - ✅ `repo` (Full control of private repositories)
6. Click **Generate token**
7. **Copy the token immediately** (you won't see it again!)

### Step 2: Configure Git Credential Storage

Choose **ONE** method:

#### Method A: Credential Helper (More Secure)

```bash
cd /config

# Copy example config
cp /config/.gitconfig.example /config/.gitconfig

# Edit the config
nano /config/.gitconfig
```

Uncomment and configure the credential helper:
```ini
[user]
    name = Your Name
    email = your.email@example.com

[credential]
    helper = store
```

Save the file, then create credentials file:

```bash
# Replace <username> and <PAT> with your GitHub username and token
cat > /config/.git-credentials << 'EOF'
https://<username>:<PAT>@github.com
EOF

chmod 600 /config/.git-credentials
```

#### Method B: Embed Token in Remote URL (Less Secure, Easier)

```bash
cd /config

# Replace <username>, <PAT>, and repository name
git remote set-url origin https://<username>:<PAT>@github.com/<username>/home-assistant-config.git
```

⚠️ **Warning**: The token is stored in `.git/config` which may be readable.

### Step 3: Configure Git User Information

If not already done:

```bash
cp /config/.gitconfig.example /config/.gitconfig
nano /config/.gitconfig
```

Update user information:
```ini
[user]
    name = Your Name
    email = your.email@example.com

[safe]
    directory = /config
```

### Step 4: Test HTTPS Authentication

```bash
cd /config

# Test pull
git pull origin main

# Test push
git push origin main
```

✅ **If commands succeed, HTTPS authentication is working!**

---

## Verification Checklist

After setting up authentication, verify everything works:

- [ ] `git remote -v` shows correct remote URL (SSH or HTTPS)
- [ ] `git config user.name` shows your name
- [ ] `git config user.email` shows your email  
- [ ] `git pull origin main` succeeds without errors
- [ ] `git push origin main` succeeds without errors
- [ ] Home Assistant shell commands work:
  - [ ] `shell_command.git_status` shows current status
  - [ ] `shell_command.git_pull` completes successfully
  - [ ] `shell_command.git_push` completes successfully

---

## Troubleshooting

### Error: "Permission denied (publickey)"

**Cause**: SSH key not configured or not added to GitHub.

**Fix**:
1. Verify SSH key exists: `ls -la /config/.ssh/id_ed25519`
2. Check public key is added to GitHub Deploy Keys
3. Test SSH: `ssh -T git@github.com`
4. Verify SSH config: `cat /config/.ssh/config`

### Error: "Authentication failed" (HTTPS)

**Cause**: Invalid or expired Personal Access Token.

**Fix**:
1. Check token has not expired in GitHub settings
2. Verify token has `repo` scope
3. Re-generate token if needed
4. Update credentials file or remote URL with new token

### Error: "remote: Repository not found"

**Cause**: Wrong repository URL or insufficient permissions.

**Fix**:
1. Verify repository name: `git remote -v`
2. Check you have access to the repository on GitHub
3. Correct the remote URL if needed

### Error: "fatal: detected dubious ownership"

**Cause**: Git safe directory not configured.

**Fix**:
```bash
# Add to .gitconfig
git config --global --add safe.directory /config
```

Or verify `/config/.gitconfig` contains:
```ini
[safe]
    directory = /config
```

### Shell Commands Fail but Manual Git Works

**Cause**: Different environment or missing configuration files.

**Fix**:
1. Verify scripts have execute permissions:
   ```bash
   chmod +x /config/scripts/*.sh
   ```
2. Check script paths in `configuration.yaml`:
   ```yaml
   shell_command:
     git_pull: /bin/bash /config/scripts/git_pull.sh
     git_push: /bin/bash /config/scripts/git_push.sh
   ```
3. Test scripts directly:
   ```bash
   /bin/bash /config/scripts/git_pull.sh
   ```

---

## Security Best Practices

### For SSH Authentication

- ✅ **DO**: Use deploy keys with minimal required permissions
- ✅ **DO**: Enable "Allow write access" only if pushing is needed
- ✅ **DO**: Use separate keys for different purposes
- ❌ **DON'T**: Share private keys or commit them to git
- ❌ **DON'T**: Use your personal SSH key (use dedicated deploy key)

### For HTTPS Authentication

- ✅ **DO**: Use Personal Access Tokens, never passwords
- ✅ **DO**: Set token expiration (rotate annually)
- ✅ **DO**: Use minimal required scopes (just `repo`)
- ✅ **DO**: Store tokens in credential helper, not plaintext scripts
- ❌ **DON'T**: Commit tokens to git
- ❌ **DON'T**: Share tokens between different services

### General

- ✅ **DO**: Ensure `.gitconfig` and `.git-credentials` are in `.gitignore`
- ✅ **DO**: Set restrictive file permissions (600 for configs, 700 for .ssh)
- ✅ **DO**: Regularly review deploy keys and tokens in GitHub
- ❌ **DON'T**: Commit `secrets.yaml` or authentication files
- ❌ **DON'T**: Use root account for git operations

---

## Files Reference

### Configuration Files (should exist in /config)

- `/config/.gitconfig` - Git user and global settings
- `/config/.ssh/config` - SSH client configuration
- `/config/.ssh/id_ed25519` - SSH private key (if using SSH)
- `/config/.ssh/id_ed25519.pub` - SSH public key (if using SSH)
- `/config/.git-credentials` - Stored HTTPS credentials (if using HTTPS)

### Example Files (templates in repository)

- `/config/.gitconfig.example` - Template for .gitconfig
- `/config/.ssh/config.example` - Template for SSH config

### Should Be in .gitignore

```gitignore
.gitconfig
.git-credentials
.ssh/id_*
.ssh/known_hosts
.ssh/config
```

These files contain secrets and should **never** be committed to the repository.

---

## Automated Git Sync

> **No add-on required.** This setup uses shell scripts only — the Git Pull add-on is **not** used.

### How sync works in each direction

| Direction | Mechanism | Frequency |
|-----------|-----------|-----------|
| **HA → GitHub** | `shell_command.git_push` stages all local changes, commits, and pushes | Every hour + after any UI change + nightly at 03:00 |
| **GitHub → HA** | `shell_command.git_pull` fetches `origin/main` and merges (local wins on conflicts) before a subsequent push | Every hour |

Upstream changes from GitHub are merged into Home Assistant only during syncs that run `shell_command.git_pull` before `shell_command.git_push` (for example, the hourly sync). UI-change-triggered syncs are **push-only** and do not fetch or merge upstream changes.

### Automation schedule

| Automation | Trigger | Action |
|-----------|---------|--------|
| **Push After UI Changes** | `lovelace_updated` event | Debounced `shell_command.git_push` (push-only) — see below |
| **Git Sync Hourly** | Every hour at :00 | `shell_command.git_pull` (fetch/merge from GitHub) then `shell_command.git_push` |
| **Git Sync Before Major Changes** | `input_boolean.maintenance_major_changes` turns ON | Run the same pull-then-push sequence so you start from a clean state |
| **Nightly Config Backup** | Daily at 03:00 | Commit with dated message, then `shell_command.git_pull` + `shell_command.git_push` |
| **Weekly Config Snapshot** | Sunday at 02:30 | Create `backups/config-snapshot-*.tar.gz` then `shell_command.git_push` |
| **Reload After Sync** | `script.maintenance_git_sync_config` finishes | Reload automations so new YAML takes effect |

### Rate-limiting and debounce for UI changes

When you edit the dashboard, `lovelace_updated` can fire many times in quick succession (e.g. resizing cards, reordering, colour-picker adjustments). To avoid hammering the system with a git operation per event, the push script uses a **3-minute quiet-window debounce**:

```
Event fires → script.maintenance_git_push_config starts 3-min timer
Event fires again (30 s later) → script RESTARTS, timer resets to 3 min
Event fires again (1 min later) → script RESTARTS, timer resets to 3 min
No more events for 3 min → timer expires → git push runs ONCE
```

This is implemented using `mode: restart` on the push script (`scripts.yaml`). Each call to `script.turn_on` on a `mode: restart` script that is already waiting will restart it from the top, resetting the delay. Only after a full quiet window does the actual `shell_command.git_push` execute. The result is that a burst of fifty UI changes produces exactly **one** git commit and push.

Scheduled syncs (`maintenance_git_sync_config`) use `mode: single` and run immediately — they are intentional operations, not event-driven bursts, and should never be deferred.

### Conflict resolution

`git merge --no-edit -X ours origin/main` is used throughout. The `-X ours` flag means that when the **same line** has been changed both locally and in GitHub, the **local (HA box) copy wins**. Changes pushed to GitHub that do not conflict with any local edits are always accepted cleanly. Review the HA logs after a sync if you need to see what was auto-resolved.

You can also trigger manually:

### Via Home Assistant UI

Go to Developer Tools → Actions, then run:
- `script.maintenance_git_sync_config` — Pull, merge, and push (full sync with remote)
- `script.maintenance_git_push_config` — Commit and push local changes only (no pull/merge)
- `script.maintenance_git_status` — Check status only

### Via Shell

```bash
/bin/bash /config/scripts/git_sync.sh
/bin/bash /config/scripts/git_status.sh
```

---

## Migration Guide

### Switching from HTTPS to SSH

```bash
cd /config

# 1. Set up SSH (follow SSH setup steps above)

# 2. Change remote URL
git remote set-url origin git@github.com:yourusername/home-assistant-config.git

# 3. Test
git pull origin main

# 4. (Optional) Remove HTTPS credentials
rm /config/.git-credentials
```

### Switching from SSH to HTTPS

```bash
cd /config

# 1. Set up HTTPS (follow HTTPS setup steps above)

# 2. Change remote URL
git remote set-url origin https://github.com/yourusername/home-assistant-config.git

# 3. Configure credentials (credential helper or embed PAT)

# 4. Test
git pull origin main
```

---

## Additional Resources

- [GitHub Deploy Keys Documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys)
- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- [Git Credential Storage](https://git-scm.com/docs/git-credential-store)
- [Home Assistant Terminal & SSH Add-on](https://github.com/home-assistant/addons/tree/master/ssh)

---

## Getting Help

If you continue to have issues:

1. Check the [Quick Fixes Guide](quick-fixes.md#git-sync-issues)
2. Review [Add-on Troubleshooting](addon-troubleshooting.md#git-sync-configuration)
3. Check Home Assistant logs for error messages
4. Verify all configuration files are present and have correct permissions
5. Test git operations manually before using shell commands

---

**Last Updated**: 2026-02-28
