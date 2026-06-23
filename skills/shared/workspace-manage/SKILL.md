---
name: workspace-manage
description: >-
  Manage the three-layer dotfiles setup (dotfiles-shared, liangjuf/dotfiles chezmoi,
  lfeng/dotfiles devspace). Use when editing shell config, packages, templates, bumping
  the shared submodule, first-time host setup, chezmoi apply/update, devspace install.sh,
  or syncing changes across work-mac, personal-mac, personal-ec2, and Coder devspaces.
---

# Dotfiles management (S + P + W)

Three repos, one shared submodule. Edit the **lowest layer that owns the concern**, push, bump submodule in consumers, then sync each host.

## Repos

| Layer | Repo | Remote | Hosts | Entry point |
|-------|------|--------|-------|-------------|
| **S** Shared | `dotfiles-shared` | `https://github.com/liangjuf/dotfiles-shared` (public) | all | direct git |
| **P** Personal | `liangjuf/dotfiles` | `https://github.com/liangjuf/dotfiles` (private) | work-mac, personal-mac, personal-ec2 | `chezmoi` |
| **W** Work | `lfeng/dotfiles` | `https://github.rbx.com/lfeng/dotfiles` (GHE) | Coder devspaces | `install.sh` |

Submodule path in P and W: `shared/` → S.

### What lives where

| Content | S | P | W |
|---------|---|---|---|
| `zsh/*.zsh`, `p10k.zsh`, `tmux.conf` | ✓ | | |
| `packages.toml`, `ensure-packages.sh`, `init-omz.sh` | ✓ | | |
| `overlays/{work-mac,personal-mac,personal-ec2}.zsh` | ✓ | | |
| `agents/AGENTS.md`, `skills/shared/` | ✓ | | |
| chezmoi templates (`dot_*`, `run_onchange_*`) | | ✓ | |
| `packages/{role}.toml`, `bootstrap.sh`, cloud-init | | ✓ | |
| `skills/personal/`, Claude/Codex templates | | ✓ | |
| `install.sh`, `packages/work-devspace.toml` | | | ✓ |
| `skills/devspace/`, work scripts, `.claude/settings.json` | | | ✓ |
| Secrets, Roblox-internal URLs | never S | personal only | work only |

**Rule:** S must stay public (devspaces clone without credentials). No secrets in S.

### Typical local paths

| Repo | Common path |
|------|-------------|
| P (chezmoi source) | `~/.local/share/chezmoi` |
| S (standalone clone) | `~/git/dotfiles-shared` |
| W (work dotfiles) | `~/Roblox/dotfiles` or devspace `~/.config/coderv2/dotfiles` |

---

## Roles and hosts

| Role | Host | Manager | Overlay | Extra packages |
|------|------|---------|---------|----------------|
| `work-mac` | Work MacBook | chezmoi (P) | `shared/overlays/work-mac.zsh` | shared only (no Claude/Codex CLI) |
| `personal-mac` | Mac Mini | chezmoi (P) | `shared/overlays/personal-mac.zsh` | node, claude, codex, pass, gpg |
| `personal-ec2` | EC2 fleet | chezmoi (P) | `shared/overlays/personal-ec2.zsh` | node, claude, codex |
| `work-devspace` | Coder Linux | W `install.sh` | `zsh/work-devspace.zsh` | `packages/work-devspace.toml` |

Chezmoi role is set in `~/.config/chezmoi/chezmoi.toml` (`[data].role`, `name`, `email`). Copy from `chezmoi.toml.example` in P. The template default in `.chezmoi.toml.tmpl` is `personal-mac` — override on work-mac.

---

## Bootstrap tiers (chezmoi hosts)

| Tier | What | Trigger |
|------|------|---------|
| 0 | Homebrew (Mac) or apt + chezmoi (EC2) | manual / cloud-init |
| 1 | Templates → `$HOME` | `chezmoi apply` |
| 2 | brew, packages, OMZ, agents, tmux plugins | `run_onchange_bootstrap.sh.tmpl` → `bootstrap.sh` |

`bootstrap.sh` runs: `ensure-brew.sh` → `ensure-packages.sh` (shared + role manifest) → `init-omz.sh` → `ensure-agents.sh` → `ensure-tmux-plugins.sh`.

Shell: `dot_zshrc.tmpl` sources `shared/zsh/*.zsh`, then `shared/overlays/<role>.zsh`.

Manual re-run: `~/.local/share/chezmoi/executable_scripts/bootstrap.sh <role>`

Devspace (W): Coder runs `install.sh` on **every workspace start** (git pull + submodule update first). Steps must stay idempotent.

---

## First-time setup

### work-mac or personal-mac (chezmoi)

1. Install Homebrew + chezmoi (not in package manifests — chicken-and-egg):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon; /usr/local on Intel
brew install chezmoi
```

2. Write `~/.config/chezmoi/chezmoi.toml` with the correct role block from `chezmoi.toml.example`.

3. Init and apply:

```bash
chezmoi init github.com/liangjuf/dotfiles    # skip if source already exists
git -C ~/.local/share/chezmoi submodule update --init --recursive
chezmoi apply
```

4. Role-specific one-time (see P `README.md`):
   - **work-mac:** SSH key for `github.rbx.com`; `atuin login`
   - **personal-mac:** `atuin login`; GPG + `pass init`; Claude/Codex auth; EC2 SSH config
   - **personal-ec2:** cloud-init or manual apt + chezmoi; `atuin login`; agent auth

### personal-ec2 (cloud-init path)

Bake `cloud-init/ec2-user-data.yaml` with role/name/email, or follow manual Linux setup in P `README.md`. Chezmoi installs before Linuxbrew; `ensure-brew.sh` runs on first `chezmoi apply`.

### Coder devspace (W)

1. Push W repo to GHE (`lfeng/dotfiles`).
2. Coder → Settings → Dotfiles → GHE fork URL.
3. Workspace create/start runs `install.sh` automatically.
4. Manual: `cd ~/.config/coderv2/dotfiles && ./install.sh`

---

## Day-to-day by host

### Chezmoi hosts (work-mac, personal-mac, personal-ec2)

```bash
chezmoi update                    # git pull P + submodule + apply (+ bootstrap if hashes changed)
chezmoi cd                        # edit P source (~/.local/share/chezmoi)
chezmoi diff                      # preview pending apply
chezmoi apply                     # apply local edits without pulling
chezmoi apply --force ~/.p10k.zsh   # force single file (if local drift)
exec zsh                          # reload shell after zsh changes
```

Edit flow: `chezmoi cd` → edit → `git add/commit/push` → `chezmoi apply` on this machine → `chezmoi update` on others.

### Devspace (W)

No chezmoi. Changes propagate on next workspace **start** (or run `install.sh` manually):

```bash
cd ~/.config/coderv2/dotfiles
git pull --ff-only
git submodule update --init --recursive
./install.sh
```

Stop/start workspace to pick up pushed W or S changes (install.sh pulls at start).

---

## Change propagation (critical)

### Edit shared config (zsh, tmux, p10k, packages.toml, scripts)

```
1. Edit + push S (dotfiles-shared main)
2. Bump shared/ submodule in P → commit + push P
3. Bump shared/ submodule in W → commit + push W (if devspaces need it)
4. Sync hosts:
   - chezmoi: chezmoi update
   - devspace: stop/start workspace (or ./install.sh)
```

**Bump submodule in P:**

```bash
cd ~/.local/share/chezmoi
git -C shared fetch origin && git -C shared checkout origin/main
git add shared && git commit -m "Bump dotfiles-shared: <reason>" && git push
```

**Bump submodule in W:**

```bash
cd ~/Roblox/dotfiles    # or devspace path
bash scripts/bump-shared.sh
git commit -m "Bump dotfiles-shared: <reason>" && git push
```

Order matters: **always push S first**, then bump consumers. Never bump submodule to a SHA not on `origin/main` unless intentional.

### Edit chezmoi-only (P)

Templates, role manifests (`packages/work-mac.toml`), `bootstrap.sh`, cloud-init, personal skills.

Push P → `chezmoi update` on each chezmoi host. W/devspace unaffected unless you also changed S.

### Edit devspace-only (W)

`install.sh`, `packages/work-devspace.toml`, `skills/devspace/`, work `.claude/settings.json`, `zsh/work-devspace.zsh`.

Push W → devspace picks up on next start. Chezmoi hosts unaffected.

### Edit both S and P/W in one feature

1. Push S
2. Make dependent changes in P and/or W (submodule bump + any wiring)
3. Push P and/or W
4. Sync all hosts

---

## Common change patterns

### Add a zsh script for all Macs

1. Add `shared/zsh/35-foo.zsh` in S → push S
2. Bump `shared/` in P → push P
3. `chezmoi update` on work-mac and personal-mac

### Add a brew package for all platforms

1. Add entry to `shared/packages.toml` in S → push S
2. Bump submodule in P and W
3. `chezmoi update` / devspace restart

### Add a package for one chezmoi role only

1. Edit `packages/<role>.toml` in P (e.g. `packages/personal-mac.toml`)
2. Push P → `chezmoi update` on that role's hosts

### Add a devspace-only package

1. Edit `packages/work-devspace.toml` in W → push W
2. Restart devspace

### Change tmux / p10k / gitconfig

Edit in S (`shared/tmux.conf`, `shared/p10k.zsh`, `shared/config/git/gitconfig.shared`). Bump + sync. Chezmoi may symlink or template these — check P templates if apply conflicts.

### Add an agent skill

| Tier | Location | Linked to |
|------|----------|-----------|
| shared | `shared/skills/shared/` in S | all agents, all hosts |
| personal | `skills/personal/` in P | personal-mac, personal-ec2 |
| devspace | `skills/devspace/` in W | devspace agents |

After adding: push repo → sync host → `ensure-agents.sh` / bootstrap re-runs link step.

---

## Agent workflow checklist

When helping the user manage dotfiles:

1. **Identify layer** — shared vs P vs W (use table above).
2. **Identify host/role** — determines which consumer to bump and sync command.
3. **Edit S first** if the change is cross-cutting.
4. **Bump submodules** in P and/or W after S push; commit submodule SHA.
5. **Push all touched repos** before telling user to sync.
6. **Verify** with `chezmoi diff` / `git status` / `git submodule status`.
7. **Tell user sync command** per host: `chezmoi update` vs devspace restart.

Do not put secrets in S. Do not commit credentials. Submodule bump commits are normal — include reason in message.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Packages missing after apply | `executable_scripts/bootstrap.sh <role>` or fix `ensure-packages.sh` in S |
| brew not found (Linux) | `chezmoi apply` (runs `ensure-brew.sh`) |
| Empty `shared/` | `git -C ~/.local/share/chezmoi submodule update --init --recursive` |
| Wrong overlay sourced | Check `~/.config/chezmoi/chezmoi.toml` `[data].role`; `chezmoi apply` |
| `chezmoi apply` conflict (`.p10k.zsh`, etc.) | Port local edits into S, or `chezmoi apply --force <file>` |
| `map has no entry for key "role"` | Set `role` in `~/.config/chezmoi/chezmoi.toml` |
| Bootstrap didn't re-run | `run_onchange_bootstrap.sh.tmpl` hashes inputs; bump changes or run bootstrap manually |
| Devspace stale after push | Stop/start workspace (install.sh pulls at start) |
| `git pull` conflict on devspace | `git restore` local drift (`.zshrc`, `.p10k.zsh`, `.tmux.conf` may be old direct copies) |
| P10k instant-prompt warning | Console I/O during zsh init (missing file, ssh auto-connect, etc.); fix source, don't suppress unless asked |
| brew cleanup fails intermittently | `HOMEBREW_NO_INSTALL_CLEANUP=1` in `ensure-packages.sh` (S) |

Logs: devspace `~/.dotfiles_install.log`; bootstrap prints `[bootstrap]` lines.

---

## Quick reference

```bash
# P — edit source
chezmoi cd && chezmoi diff && chezmoi apply && chezmoi update

# Submodule (from P or W root)
git -C shared fetch origin && git -C shared checkout origin/main && git add shared

# W — local devspace test
cd ~/.config/coderv2/dotfiles && git pull && git submodule update --init --recursive && ./install.sh

# Validate EC2 cloud-init
cloud-init schema --config-file cloud-init/ec2-user-data.yaml
```

Further detail: P repo `README.md`, `docs/plan.md`, `docs/MIGRATION.md`; W repo `README.md`; S repo `README.md`.
