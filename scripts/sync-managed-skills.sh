#!/usr/bin/env bash
# Install/upgrade public npm skill packs, then normalize ~/.agents/skills.
# No company-internal taps (those belong in a work-layer overlay).
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SHARED="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SKILL_SYNC_LOG_FILE="${SKILL_SYNC_LOG_FILE:-$HOME/.dotfiles_skill_sync.log}"
LOCK_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/skill-sync.lock"

# shellcheck source=config/npm-skills.sh
source "$SHARED/config/npm-skills.sh"

mode="upgrade"
hook_mode=false
case "${1:-}" in
    "") ;;
    --install) mode="install" ;;
    --hook) hook_mode=true ;;
    *)
        echo "Usage: $0 [--install|--hook]" >&2
        exit 2
        ;;
esac

if $hook_mode; then
    exec 3>&1
    mkdir -p "$(dirname "$SKILL_SYNC_LOG_FILE")"
    exec >> "$SKILL_SYNC_LOG_FILE" 2>&1
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

failures=0

run_step() {
    local description="$1"
    shift
    log "$description"
    if "$@"; then
        return 0
    fi
    log "ERROR: $description failed"
    failures=1
    return 1
}

finish() {
    if [ "$failures" -eq 0 ]; then
        log "Managed skills are current"
        exit 0
    fi
    log "ERROR: One or more skill updates failed"
    if $hook_mode; then
        # Default: warn but do not block the session. Set SKILL_SYNC_STRICT=1 to stop.
        if [ "${SKILL_SYNC_STRICT:-0}" = "1" ]; then
            printf '%s\n' '{"continue":false,"stopReason":"Managed skill update failed. See ~/.dotfiles_skill_sync.log.","systemMessage":"Codex did not start because the managed skill update failed. See ~/.dotfiles_skill_sync.log."}' >&3
        else
            printf '%s\n' '{"continue":true,"systemMessage":"Managed skill update failed. See ~/.dotfiles_skill_sync.log."}' >&3
        fi
        exit 0
    fi
    exit 1
}

mkdir -p "$(dirname "$LOCK_FILE")"
if command -v flock >/dev/null 2>&1; then
    exec 9> "$LOCK_FILE"
    if ! flock -w 300 9; then
        log "ERROR: Timed out while another skill update was running"
        failures=1
        finish
    fi
else
    log "WARNING: flock is unavailable; continuing without a skill-update lock"
fi

install_npm_skills() {
    local entry pack skill_filter

    run_step "Remove unmanaged Matt Pocock skills" \
        npx -y skills@latest remove "${MATTPOCOCK_SKILLS_TO_UNINSTALL[@]}" -g -y
    run_step "Install Matt Pocock Engineering and Productivity skills" \
        npx -y skills@latest add mattpocock/skills -g \
        --agent "${NPM_SKILL_AGENTS[@]}" --skill "${MATTPOCOCK_SKILLS[@]}" -y

    for entry in "${NPM_SKILL_PACKS[@]}"; do
        pack="${entry%%:*}"
        skill_filter="${entry#*:}"
        run_step "Install public skill pack $pack ($skill_filter)" \
            npx -y skills@latest add "$pack" -g \
            --agent "${NPM_SKILL_AGENTS[@]}" --skill "$skill_filter" -y
    done

    for entry in "${NPM_CURSOR_CODEX_PACKS[@]}"; do
        pack="${entry%%:*}"
        skill_filter="${entry#*:}"
        run_step "Install public skill pack $pack ($skill_filter) for Cursor and Codex" \
            npx -y skills@latest add "$pack" -g \
            --agent cursor --agent codex --skill "$skill_filter" -y
    done
}

sync_npm_skills() {
    if ! command -v npx >/dev/null 2>&1; then
        log "ERROR: npx is unavailable"
        failures=1
        return
    fi

    if [ "$mode" = "install" ]; then
        install_npm_skills
    fi

    run_step "Update installed public skills" npx -y skills@latest update -g -y
}

log "Start managed skill synchronization ($mode mode)"
sync_npm_skills
run_step "Normalize shared skill sources" \
    bash "$SHARED/scripts/normalize-agent-skill-sources.sh"
finish
