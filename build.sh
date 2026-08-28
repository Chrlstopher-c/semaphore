#!/usr/bin/env bash
# Compile Echo et produit xtool/Echo.ipa (non signé).
set -euo pipefail

cd "$(dirname "$0")"

. "$HOME/.local/share/swiftly/env.sh"
export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
export PATH="$HOME/.local/bin:$PATH"

log() { printf '\033[36m▸\033[0m %s\n' "$1"; }
die() { printf '\033[31m✗\033[0m %s\n' "$1" >&2; exit 1; }

command -v xtool >/dev/null || die "xtool introuvable dans le PATH"
swift sdk list 2>/dev/null | grep -q darwin || die "SDK Darwin non installé — voir README"

log "Compilation ($(swift --version 2>/dev/null | head -1))"
xtool dev build --ipa "$@" || die "échec de la compilation"

IPA="xtool/Echo.ipa"
[ -f "$IPA" ] || die "IPA non produit"
log "IPA prêt : $(pwd)/$IPA ($(du -h "$IPA" | cut -f1))"
