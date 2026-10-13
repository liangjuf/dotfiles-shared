#!/usr/bin/env bash
# An installer reading stdin must not consume the remaining package manifest.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"

cat > "$fixture/bin/brew" <<'BREW'
#!/usr/bin/env bash
case "$1" in
    shellenv) ;;
    list) exit 1 ;;
    install)
        cat >/dev/null
        printf "%s\n" "$2" >> "$PACKAGE_TEST_LOG"
        ;;
    *) exit 1 ;;
esac
BREW
chmod +x "$fixture/bin/brew"

for name in first second third; do
    printf '[[package]]\nname = "%s"\nmethod = "brew"\n\n' "$name"
done > "$fixture/packages.toml"

PATH="$fixture/bin:/usr/bin:/bin" \
LOCAL_BIN="$fixture/local-bin" \
PACKAGE_TEST_LOG="$fixture/installed" \
    /bin/bash "$ROOT/scripts/ensure-packages.sh" "$fixture/packages.toml"

printf "first\nsecond\nthird\n" > "$fixture/expected"
diff -u "$fixture/expected" "$fixture/installed"
echo "PASS: stdin-consuming installers leave every package available"
