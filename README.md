# dotfiles-shared

Public cross-platform shell and tool configuration for the multi-machine dotfiles setup.

**Consumers** (git submodule at `shared/`):

- [lfeng/dotfiles](https://github.rbx.com/lfeng/dotfiles) — Coder devspaces (`work-devspace`)
- [liangjuf/dotfiles](https://github.com/liangjuf/dotfiles) — chezmoi (`personal-mac`, `work-mac`, `personal-ec2`)

## Layout (phase 1)

```
agents/AGENTS.md          # generic agent guidelines (public)
skills/shared/            # public agent skills (linked by link-skills.sh)
config/
  atuin/config.toml
  git/gitconfig.shared
overlays/                 # role snippets (chezmoi machines)
  work-mac.zsh
  personal-mac.zsh
  personal-ec2.zsh
packages.toml             # shared package manifest (TOML)
scripts/
  ensure-packages.sh      # install from packages.toml
  link-skills.sh              # symlink skills → ~/.claude/skills, ~/.codex/skills
  link-agent-guidelines.sh    # symlink AGENTS.md → ~/.claude, ~/.codex, ~/.cursor
zsh/                      # 00-env … 40-completion
p10k.zsh
tmux.conf
```

## Usage

Source zsh files in numeric order, then the consumer's role overlay:

```zsh
SHARED="${SHARED:-$HOME/dotfiles/shared}"
for f in "$SHARED"/zsh/*.zsh(N); do source "$f"; done
source "$SHARED/overlays/${ROLE}.zsh"
```

Symlink or template `p10k.zsh` → `~/.p10k.zsh`, `tmux.conf` → `~/.tmux.conf`.

## Sync workflow

1. Edit and push this repo.
2. Bump the `shared/` submodule SHA in each consumer repo (see below).
3. Devspace: restart workspace (`install.sh` pulls on start).
4. Mac/EC2: `chezmoi update`.

### Bump `shared/` in a consumer repo

After merging a change here, each repo that depends on `shared/` must record the new commit. Git stores that pointer in the parent repo — machines do not pick up shared edits until you bump and push.

**GHE dotfiles** (Coder devspaces):

```bash
cd ~/dotfiles   # or your clone of github.rbx.com/lfeng/dotfiles
git fetch origin
git submodule update --remote shared   # checkout latest dotfiles-shared on main
git add shared
git commit -m "Bump shared submodule"
git push
```

**GHC chezmoi source** (Mac / EC2):

```bash
cd ~/.local/share/chezmoi   # or your clone of github.com/liangjuf/dotfiles
git fetch origin
git submodule update --remote shared
git add shared
git commit -m "Bump shared submodule"
git push
```

To pin a **specific** shared commit instead of branch tip:

```bash
cd shared
git fetch origin
git checkout <sha-or-tag>
cd ..
git add shared
git commit -m "Bump shared submodule to <sha>"
```

What gets committed: only the submodule gitlink (the SHA under `shared/`), not the shared files themselves. After push, devspaces refresh on workspace restart; Mac/EC2 run `chezmoi update` to apply.
