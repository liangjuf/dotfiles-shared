---
name: workspace-manage
description: >-
  Manage the two-layer dotfiles setup (dotfiles-shared + liangjuf/dotfiles chezmoi),
  plus an optional work Linux/Coder repo for a future company GHE. Use when editing
  shell config, packages, templates, bumping the shared submodule, first-time host
  setup, chezmoi apply/update, or syncing work-mac and personal-mac.
---

# Dotfiles management (S + P, optional W)

Two repos you keep after leaving any one employer. Edit the **lowest layer that owns the concern**, push, bump the submodule in P, then sync each host.

A third **W** repo is only a Coder/`install.sh` overlay for whatever company GHE you have *at the time*. It must not contain the only copy of anything you still want on a laptop.

## Repos

| Layer | Repo | Remote | Hosts | Entry point |
|-------|------|--------|-------|-------------|
| **S** Shared | `dotfiles-shared` | `https://github.com/liangjuf/dotfiles-shared` (public) | all | direct git |
| **P** Personal | `liangjuf/dotfiles` | `https://github.com/liangjuf/dotfiles` (private) | work-mac, personal-mac | `chezmoi` |
| **W** Work Linux | company GHE fork (optional) | private GHE | Coder / work Linux | `install.sh` |

Submodule path in P (and W if you have one): `shared/` → S.

### What lives where

| Content | S | P | W (optional) |
|---------|---|---|---|
| `zsh/*.zsh`, `p10k.zsh`, `tmux.conf` | ✓ | | |
| `packages.toml`, `ensure-packages.sh`, `init-omz.sh` | ✓ | | |
| `overlays/{work-mac,personal-mac}.zsh` | ✓ | | |
| `agents/AGENTS.md`, `skills/shared/` | ✓ | | |
| `config/npm-skills.sh`, `sync-managed-skills.sh`, `normalize-agent-skill-sources.sh` | ✓ | | |
| chezmoi templates (`dot_*`, `run_onchange_*`) | | ✓ | |
| `packages/{work-mac,personal-mac}.toml`, `bootstrap.sh` | | ✓ | |
| `skills/personal/` | | ✓ | |
| Coder `install.sh`, company packages, company overlay | | | ✓ |
| Company-internal URLs, SSO, secret stores | never S | never (use local secrets) | work only |

**Rule:** S must stay public. No secrets, no employer hostnames, no internal skill taps.

`personal-ec2` is **deprecated**. Use `personal-mac` (or copy that role if you stand up a personal Linux host later).

### Typical local paths

| Repo | Common path |
|------|-------------|
| P (chezmoi source) | `~/.local/share/chezmoi` |
| S (standalone clone) | `~/git/dotfiles-shared` |
| W | company clone or `~/.config/coderv2/dotfiles` |

---

## Roles and hosts

| Role | Host | Manager | Overlay | Extra packages |
|------|------|---------|---------|----------------|
| `work-mac` | Work MacBook | chezmoi (P) | `shared/overlays/work-mac.zsh` | node, claude, codex |
| `personal-mac` | Personal Mac | chezmoi (P) | `shared/overlays/personal-mac.zsh` | node, claude, codex, pass, gpg |

Chezmoi role is set in `~/.config/chezmoi/chezmoi.toml` (`[data].role`, `name`, `email`). Optional `[data].ghe_host` (e.g. `github.company.com`) wires git credential helper + SSH — leave it unset until the new company GHE exists.

The template default in `.chezmoi.toml.tmpl` is `personal-mac`.

`work-mac` is **company-agnostic**: same agent CLIs and public skill packs as personal-mac. Do not put employer LLM gateways, GHE hostnames, or internal taps in S or in unconditional work-mac templates.

---

## Bootstrap tiers (chezmoi hosts)

| Tier | What | Trigger |
|------|------|---------|
| 0 | Homebrew + chezmoi | manual |
| 1 | Templates → `$HOME` | `chezmoi apply` |
| 2 | brew, packages, OMZ, agents, tmux plugins | `run_onchange_bootstrap.sh.tmpl` → `bootstrap.sh` |

`bootstrap.sh` runs: `ensure-brew.sh` → `ensure-packages.sh` (shared + role manifest) → `init-omz.sh` → `ensure-agents.sh` → `ensure-tmux-plugins.sh`.

`ensure-agents.sh` (P): link `AGENTS.md` → `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`; link `skills/shared/` (and `skills/personal/` on personal-mac) into `~/.agents/skills` plus agent dirs; `sync-managed-skills.sh --install`; `normalize-agent-skill-sources.sh`.

Codex SessionStart runs `sync-managed-skills.sh --hook` (upgrade only; does not block the session unless `SKILL_SYNC_STRICT=1`).

Shell: `dot_zshrc.tmpl` sources `shared/zsh/*.zsh`, then `shared/overlays/<role>.zsh`.

Manual re-run: `~/.local/share/chezmoi/executable_scripts/bootstrap.sh <role>`

Optional W: Coder runs `install.sh` on workspace start. Keep that script idempotent. Do not make it the source of truth for laptop skills.

---

## First-time setup

### work-mac or personal-mac

1. Install Homebrew + chezmoi:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon; /usr/local on Intel
brew install chezmoi
```

2. Write `~/.config/chezmoi/chezmoi.toml` from `chezmoi.toml.example`. On work-mac, set `ghe_host` only when the company GHE hostname is known.

3. Init and apply:

```bash
chezmoi init github.com/liangjuf/dotfiles
git -C ~/.local/share/chezmoi submodule update --init --recursive
chezmoi apply
```

4. One-time: `atuin login`; Claude/Codex auth; on work-mac, SSH key for the company GHE if `ghe_host` is set.

### Future company Coder / GHE (W)

1. Copy a generic `install.sh` consumer (submodule → S). Do not revive employer-specific packages, secret scripts, or LLM-gateway helpers from a previous job.
2. Point Coder Dotfiles at the new GHE fork.
3. Put company-internal skills/taps only in that W overlay.

---

## Day-to-day

```bash
chezmoi update                    # git pull P + submodule + apply
chezmoi cd                        # edit P source
chezmoi diff && chezmoi apply
exec zsh
```

Edit flow: `chezmoi cd` → edit → commit/push P → `chezmoi apply` here → `chezmoi update` on the other Mac.

---

## Change propagation

### Shared config (zsh, tmux, p10k, packages.toml, public skills, npm skill list)

```
1. Edit + push S
2. Bump shared/ in P → commit + push P
3. Bump shared/ in W if a work Linux repo exists
4. chezmoi update / restart Coder workspace
```

**Bump submodule in P:**

```bash
cd ~/.local/share/chezmoi
git -C shared fetch origin && git -C shared checkout origin/main
git add shared && git commit -m "Bump dotfiles-shared: <reason>" && git push
```

### Chezmoi-only (P)

Templates, `packages/work-mac.toml`, `packages/personal-mac.toml`, `bootstrap.sh`, `skills/personal/`.

Push P → `chezmoi update` on each Mac.

### Work Linux only (W)

`install.sh`, company package manifest, company overlay, company skills. Never the only copy of a skill you still want on a Mac.

---

## Agent skills

| Tier | Location | Linked to |
|------|----------|-----------|
| shared / public | `skills/shared/` in S + npm packs in `config/npm-skills.sh` | all agents, all hosts |
| personal | `skills/personal/` in P | personal-mac |
| company | W overlay only | that company's Linux/Coder |

Canonical skill dir: `~/.agents/skills`. Claude also gets links under `~/.claude/skills` (`show-me` stays off Claude). Cursor and Codex read the shared root after normalize.

Do **not** put employer rbx-style taps in S. A new company tap list belongs in W.

---

## Agent workflow checklist

1. Identify layer — S vs P vs optional W.
2. Identify host — `work-mac` vs `personal-mac`.
3. Edit S first if the change is cross-cutting.
4. Bump `shared/` in P after S push.
5. Push all touched repos before telling the user to sync.
6. Verify with `chezmoi diff` / `git submodule status`.
7. Sync command: `chezmoi update` (Coder restart only if W exists).

Do not put secrets in S. Do not commit credentials.

---

## Troubleshooting

| Symptom | Fix |
|---------|---|
| Packages missing after apply | `executable_scripts/bootstrap.sh <role>` |
| Empty `shared/` | `git -C ~/.local/share/chezmoi submodule update --init --recursive` |
| Wrong overlay | Check `~/.config/chezmoi/chezmoi.toml` `[data].role` |
| `map has no entry for key "role"` | Set `role` in chezmoi.toml |
| Skill sync failed | `~/.dotfiles_skill_sync.log`; re-run `shared/scripts/sync-managed-skills.sh --install` |
| Stale company MCP / internal skills | Unlink `~/.local/share/rbx-skills` (or equivalent) snapshots; they will not update without that git host |

---

## Quick reference

```bash
chezmoi cd && chezmoi diff && chezmoi apply && chezmoi update

git -C shared fetch origin && git -C shared checkout origin/main && git add shared

bash ~/.local/share/chezmoi/shared/scripts/sync-managed-skills.sh --install
```
