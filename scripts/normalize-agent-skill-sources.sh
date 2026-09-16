#!/bin/bash

set -euo pipefail

shared_skills_dir="$HOME/.agents/skills"
codex_skills_dir="$HOME/.codex/skills"
claude_skills_dir="$HOME/.claude/skills"
cursor_skills_dir="$HOME/.cursor/skills"
rbx_snapshot_root="$HOME/.local/share/rbx-skills/snapshots"
skip_claude_skills=(
    show-me
)

mkdir -p \
    "$shared_skills_dir" \
    "$codex_skills_dir" \
    "$claude_skills_dir" \
    "$cursor_skills_dir"

same_skill() {
    local left="$1"
    local right="$2"
    local left_target right_target

    left_target="$(readlink -f "$left" 2>/dev/null || true)"
    right_target="$(readlink -f "$right" 2>/dev/null || true)"
    if [ -n "$left_target" ] && [ "$left_target" = "$right_target" ]; then
        return 0
    fi

    diff -qr -- "$left" "$right" >/dev/null 2>&1
}

declare -A rbx_targets=()
declare -A rbx_conflicts=()
for agent_dir in "$codex_skills_dir" "$cursor_skills_dir" "$claude_skills_dir"; do
    for link in "$agent_dir"/*; do
        [ -L "$link" ] || continue

        raw_target="$(readlink "$link")"
        case "$raw_target" in
            *".agents/skills/"*) continue ;;
        esac

        target="$(readlink -f "$link" 2>/dev/null || true)"
        case "$target" in
            "$rbx_snapshot_root"/*) ;;
            *) continue ;;
        esac

        name="$(basename "$link")"
        [ -z "${rbx_conflicts[$name]:-}" ] || continue
        if [ -n "${rbx_targets[$name]:-}" ] && [ "${rbx_targets[$name]}" != "$target" ]; then
            echo "WARNING: RBX skill '$name' has different snapshot targets; left unchanged" >&2
            unset 'rbx_targets[$name]'
            rbx_conflicts[$name]=1
            continue
        fi
        rbx_targets[$name]="$target"
    done
done

for name in "${!rbx_targets[@]}"; do
    target="${rbx_targets[$name]}"
    shared_path="$shared_skills_dir/$name"

    if [ -e "$shared_path" ] || [ -L "$shared_path" ]; then
        if [ ! -L "$shared_path" ]; then
            echo "WARNING: Shared skill '$name' is not an RBX symlink; left unchanged" >&2
            continue
        fi
        current_target="$(readlink -f "$shared_path" 2>/dev/null || true)"
        case "$current_target" in
            "$rbx_snapshot_root"/*) ;;
            *)
                echo "WARNING: Shared skill '$name' is not managed by RBX; left unchanged" >&2
                continue
                ;;
        esac
        ln -sfn "$target" "$shared_path"
    else
        ln -s "$target" "$shared_path"
    fi
done

for shared_path in "$shared_skills_dir"/*; do
    [ -L "$shared_path" ] || continue
    raw_target="$(readlink "$shared_path")"
    case "$raw_target" in
        "$rbx_snapshot_root"/*) ;;
        *) continue ;;
    esac
    [ -e "$shared_path" ] && continue

    name="$(basename "$shared_path")"
    rm -f -- "$shared_path"
    claude_path="$claude_skills_dir/$name"
    if [ -L "$claude_path" ] && [ "$(readlink "$claude_path")" = "../../.agents/skills/$name" ]; then
        rm -f -- "$claude_path"
    fi
done

for shared_path in "$shared_skills_dir"/*; do
    [ -e "$shared_path" ] || [ -L "$shared_path" ] || continue
    name="$(basename "$shared_path")"

    for agent_dir in "$codex_skills_dir" "$cursor_skills_dir"; do
        agent_path="$agent_dir/$name"
        if [ ! -e "$agent_path" ] && [ ! -L "$agent_path" ]; then
            continue
        fi
        if same_skill "$agent_path" "$shared_path"; then
            rm -rf -- "$agent_path"
        else
            echo "WARNING: Agent-specific skill '$agent_path' differs from the shared skill; left unchanged" >&2
        fi
    done

    skip_claude=false
    for skip_name in "${skip_claude_skills[@]}"; do
        if [ "$name" = "$skip_name" ]; then
            skip_claude=true
            break
        fi
    done

    claude_path="$claude_skills_dir/$name"
    if $skip_claude; then
        if [ -L "$claude_path" ] && [ "$(readlink "$claude_path")" = "../../.agents/skills/$name" ]; then
            rm -f -- "$claude_path"
        fi
        continue
    fi
    if [ -e "$claude_path" ] || [ -L "$claude_path" ]; then
        if same_skill "$claude_path" "$shared_path"; then
            rm -rf -- "$claude_path"
        else
            echo "WARNING: Claude skill '$claude_path' differs from the shared skill; left unchanged" >&2
            continue
        fi
    fi
    ln -s "../../.agents/skills/$name" "$claude_path"
done
