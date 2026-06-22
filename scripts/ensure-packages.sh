#!/usr/bin/env bash
# ensure-packages.sh — idempotent install from a TOML manifest ([[package]] entries).
# Usage: ensure-packages.sh /path/to/packages.toml

set -euo pipefail

# Unattended bootstrap — no installer prompts (callers: install.sh, bootstrap.sh)
export NONINTERACTIVE=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
mkdir -p "$LOCAL_BIN"

log() { echo "[ensure-packages] $*"; }

pkg_field() {
    local block="$1" key="$2"
    echo "$block" | awk -v k="$key" '
        $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
            sub(/^[^=]*=[[:space:]]*/, "", $0)
            gsub(/^["'\''"]|["'\''"]$/, "", $0)
            print $0
            exit
        }'
}

already_installed() {
    local check="$1"
    [ -n "$check" ] && eval "$check" &>/dev/null
}

install_brew() {
    local name="$1"
    brew list "$name" &>/dev/null 2>&1 && return 0
    log "brew install $name"
    brew install "$name"
}

install_apt() {
    local name="$1"
    dpkg -s "$name" &>/dev/null 2>&1 && return 0
    log "apt install $name"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$name"
}

install_archive() {
    local url="$1" bin="$2"
    local tmp dir file
    tmp="$(mktemp -d)"
    file="$tmp/$(basename "$url")"
    curl -fsSL "$url" -o "$file"
    dir="$tmp/extract"
    mkdir -p "$dir"
    tar -xf "$file" -C "$dir"
    install -m 0755 -D "$(find "$dir" -type f -name "$bin" -print -quit)" "$LOCAL_BIN/$bin"
    rm -rf "$tmp"
}

install_curl() {
    local name="$1" version="$2" url="$3"
    if [ -n "$version" ]; then
        url="${url//\{version\}/$version}"
        log "curl install $name ($version)"
    else
        log "curl install $name (latest)"
    fi
    curl --proto '=https' --tlsv1.2 -LsSf "$url" | sh
}

install_git_install() {
    local repo_url="$1" install_script="${2:-install.sh}"
    local tmp
    tmp="$(mktemp -d)"
    log "git-install $repo_url ($install_script)"
    git clone --depth 1 "$repo_url" "$tmp"
    bash "$tmp/$install_script"
    rm -rf "$tmp"
}

install_one() {
    local block="$1"
    local name method check os apt_name url version installer_url archive_bin repo_url install_script
    name="$(pkg_field "$block" name)"
    method="$(pkg_field "$block" method)"
    check="$(pkg_field "$block" check)"
    os_filter="$(pkg_field "$block" os)"

    [ -n "$name" ] || return 0
    [ -z "$os_filter" ] || [ "$(uname -s | tr '[:upper:]' '[:lower:]')" = "$os_filter" ] || return 0

    case "$method" in
        brew)
            if command -v brew &>/dev/null && brew list "$name" &>/dev/null 2>&1; then
                log "skip $name (already installed)"
                return 0
            fi
            command -v brew &>/dev/null || return 0
            install_brew "$name"
            ;;
        apt)
            apt_name="$(pkg_field "$block" apt)"
            apt_name="${apt_name:-$name}"
            if dpkg -s "$apt_name" &>/dev/null 2>&1; then
                log "skip $name (already installed)"
                return 0
            fi
            command -v apt-get &>/dev/null || return 0
            install_apt "$apt_name"
            ;;
        archive)
            if already_installed "$check"; then
                log "skip $name (already installed)"
                return 0
            fi
            url="$(pkg_field "$block" url)"
            archive_bin="$(pkg_field "$block" archive_bin)"
            install_archive "$url" "$archive_bin"
            ;;
        curl)
            if already_installed "$check"; then
                log "skip $name (already installed)"
                return 0
            fi
            version="$(pkg_field "$block" version)"
            installer_url="$(pkg_field "$block" installer_url)"
            install_curl "$name" "$version" "$installer_url"
            ;;
        npm)
            if already_installed "$check"; then
                log "skip $name (already installed)"
                return 0
            fi
            local npm_pkg
            npm_pkg="$(pkg_field "$block" package)"
            npm_pkg="${npm_pkg:-$name}"
            log "npm install -g $npm_pkg"
            npm install -g --yes "$npm_pkg"
            ;;
        binary)
            if already_installed "$check"; then
                log "skip $name (already installed)"
                return 0
            fi
            url="$(pkg_field "$block" url)"
            log "binary install $name"
            curl -fsSL "$url" -o "$LOCAL_BIN/$name"
            chmod +x "$LOCAL_BIN/$name"
            ;;
        git-install)
            if already_installed "$check"; then
                log "skip $name (already installed)"
                return 0
            fi
            repo_url="$(pkg_field "$block" repo_url)"
            install_script="$(pkg_field "$block" install_script)"
            install_git_install "$repo_url" "${install_script:-install.sh}"
            ;;
        *) log "unknown method '$method' for $name" ;;
    esac
}

main() {
    local manifest="${1:?usage: ensure-packages.sh MANIFEST.toml}"
    [ -f "$manifest" ] || { log "missing manifest: $manifest"; exit 1; }

    local block=""
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == "[[package]]" ]]; then
            [ -n "$block" ] && install_one "$block"
            block=""
        else
            block+="$line"$'\n'
        fi
    done < "$manifest"
    [ -n "$block" ] && install_one "$block"
}

main "$@"
