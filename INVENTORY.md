# Dotfiles Inventory

Classification of config files across Roblox dotfiles (work/devspace) and chezmoi (Mac/EC2).

| File / path | Classification | Lives in |
|---|---|---|
| `zsh/00-env.zsh` | shared | dotfiles-shared |
| `zsh/10-history.zsh` | shared | dotfiles-shared |
| `zsh/20-omz.zsh` | shared | dotfiles-shared |
| `zsh/30-tools.zsh` | shared | dotfiles-shared |
| `zsh/40-completion.zsh` | shared | dotfiles-shared |
| `config/atuin/config.toml` | shared | dotfiles-shared |
| `config/git/gitconfig.shared` | shared | dotfiles-shared |
| `p10k.zsh` | shared | dotfiles-shared |
| `Brewfile` | shared | dotfiles-shared |
| `overlays/work-devspace.zsh` | work-only | dotfiles-shared (sourced by Roblox dotfiles) |
| `overlays/work-mac.zsh` | work-only | dotfiles-shared |
| `overlays/personal-mac.zsh` | personal-only | dotfiles-shared |
| `overlays/personal-ec2.zsh` | personal-only | dotfiles-shared |
| `.tmux.conf` | shared | dotfiles-shared |
| `install.sh` | work-only | Roblox dotfiles |
| `scripts/roblox-secrets.zsh` | work-only | Roblox dotfiles |
| `scripts/setup-gopass.sh` | work-only | Roblox dotfiles |
| `scripts/setup-pass.sh` | work-only | Roblox dotfiles |
| `scripts/populate-secrets.sh` | work-only | Roblox dotfiles |
| `bin/llm-gateway-key.sh` | work-only | Roblox dotfiles |
| `skills/` | work-only | Roblox dotfiles |
| `cursor-extensions.txt` | work-only | Roblox dotfiles |
| `.claude/settings.json` | work-only | Roblox dotfiles |
| `.codex/config.toml` | work-only | Roblox dotfiles |
| `.cursor/rules/` | work-only | Roblox dotfiles |
| `ssht.zsh`, `ssht_test.zsh` | work-only | Roblox dotfiles |
| `repos.code-workspace` | work-only | Roblox dotfiles |
| `.gnupg/gpg-agent.conf` | shared | dotfiles-shared |
| `AGENTS.md`, `CLAUDE.md` | work-only | Roblox dotfiles |
| `.local/bin/osc52_copy` | shared | dotfiles-shared |
| `.gitconfig` (full) | work overlay | chezmoi template / Roblox dotfiles |
| `executable_init_zsh.sh` | personal/chezmoi | chezmoi source |

## Shell stack decision

**Oh My Zsh + Powerlevel10k** — both Roblox dotfiles (`install.sh`) and chezmoi (`executable_init_zsh.sh`) already install OMZ. Antidote (`.zsh_plugins.txt`) is retired in favor of OMZ for a single stack.
