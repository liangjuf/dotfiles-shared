# dotfiles-shared

Public cross-platform shell, tools, and **coding-agent** configuration.

**Consumers** (git submodule at `shared/`):

- [liangjuf/dotfiles](https://github.com/liangjuf/dotfiles) — chezmoi (`work-mac`, `personal-mac`)
- Optional company GHE Coder repo — `install.sh` overlay only

`personal-ec2` is deprecated.

## Layout

```
agents/AGENTS.md
config/
  atuin/config.toml
  git/gitconfig.shared
  npm-skills.sh              # curated public skill packs
overlays/
  work-mac.zsh
  personal-mac.zsh
packages.toml
scripts/
  ensure-packages.sh
  init-omz.sh
  link-skills.sh
  link-agent-guidelines.sh
  sync-managed-skills.sh     # npm packs + normalize
  normalize-agent-skill-sources.sh
skills/shared/               # linked to ~/.agents/skills (all hosts)
  workspace-manage
  using-uv-run
  use-worktree-to-develop-feature
  use-repo-clone-to-develop-feature
  reviewing-prs-with-worktrees
  pull-git-repos
zsh/
p10k.zsh
tmux.conf
```

S stays public: no secrets, no employer hostnames, no internal skill taps.

## Sync

1. Edit and push this repo.
2. Bump `shared/` in chezmoi (`~/.local/share/chezmoi`) and in any company Coder repo.
3. `chezmoi update` on each Mac.

```bash
cd ~/.local/share/chezmoi
git fetch origin
git submodule update --remote shared
git add shared
git commit -m "Bump shared submodule"
git push
```
