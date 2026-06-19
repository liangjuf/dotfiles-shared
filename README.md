# dotfiles-shared

Cross-platform shell and tool configuration shared between:

- **Roblox dotfiles** (Coder devspaces) — git submodule at `shared/`
- **chezmoi source** (Mac Mini, work MacBook, EC2) — git submodule at `shared/`

## Layout

```
zsh/           # Sourced in order by each machine's .zshrc
config/        # Tool configs (atuin, git base)
overlays/      # Role-specific zsh snippets (work-mac, personal-ec2, …)
p10k.zsh       # Powerlevel10k prompt
Brewfile       # Homebrew packages (macOS + Linuxbrew)
```

## Usage

Each consumer repo sources shared zsh files, then its role overlay:

```zsh
# Example (paths vary by consumer)
for f in "$SHARED/zsh"/*.zsh(N); do source "$f"; done
source "$SHARED/overlays/${ROLE}.zsh"
```

## Sync workflow

1. Edit shared config here
2. Commit and push `dotfiles-shared`
3. In Roblox dotfiles: `git submodule update --remote shared && git commit -am "Bump shared"`
4. On Mac/EC2: `chezmoi update`
