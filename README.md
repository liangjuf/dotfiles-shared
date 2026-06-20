# dotfiles-shared

Public cross-platform shell and tool configuration for the multi-machine dotfiles setup.

**Consumers** (git submodule at `shared/`):

- [lfeng/dotfiles](https://github.rbx.com/lfeng/dotfiles) — Coder devspaces (`work-devspace`)
- [liangjuf/dotfiles](https://github.com/liangjuf/dotfiles) — chezmoi (`personal-mac`, `work-mac`, `personal-ec2`)

## Layout (phase 1)

```
config/
  atuin/config.toml
  git/gitconfig.shared    # delta, merge; no [user] email
zsh/
  00-env.zsh              # PATH, Homebrew, p10k instant prompt
  10-history.zsh          # HISTSIZE, share_history
  20-omz.zsh              # Oh My Zsh + Powerlevel10k
  30-tools.zsh            # zoxide, atuin, fzf, eza, aliases
  40-completion.zsh       # compinit, menu select
p10k.zsh
tmux.conf
```

## Usage

Source zsh files in numeric order, then the consumer's role overlay:

```zsh
SHARED="${SHARED:-$HOME/dotfiles/shared}"
for f in "$SHARED"/zsh/*.zsh(N); do source "$f"; done
source "$SHARED/overlays/${ROLE}.zsh"  # overlays added in a later phase
```

Symlink or template `p10k.zsh` → `~/.p10k.zsh`, `tmux.conf` → `~/.tmux.conf`.

## Sync workflow

1. Edit and push this repo.
2. Bump the `shared/` submodule SHA in the consumer repo.
3. Devspace: restart workspace (`install.sh` pulls on start).
4. Mac/EC2: `chezmoi update`.
