#!/usr/bin/env bash
# Compile puis ouvre Impactor pour signer et installer sur l'iPhone.
set -euo pipefail

cd "$(dirname "$0")"

log() { printf '\033[36m▸\033[0m %s\n' "$1"; }
warn() { printf '\033[33m!\033[0m %s\n' "$1"; }
die() { printf '\033[31m✗\033[0m %s\n' "$1" >&2; exit 1; }

./build.sh || die "build échoué"

systemctl is-active --quiet usbmuxd || warn "usbmuxd inactif — sudo systemctl start usbmuxd"

DEVICE="$(idevice_id -l 2>/dev/null | head -1 || true)"
if [ -z "$DEVICE" ]; then
    warn "aucun iPhone détecté — branche-le et déverrouille-le"
else
    log "appareil : $DEVICE ($(ideviceinfo -k DeviceName 2>/dev/null || echo '?'))"
fi

IMPACTOR="$HOME/.local/opt/Impactor.AppImage"
if pgrep -af 'local/opt/Impactor' | grep -qv zsh; then
    log "Impactor déjà lancé (vérifie la zone de notification)"
else
    [ -x "$IMPACTOR" ] || die "Impactor introuvable : $IMPACTOR"
    log "lancement d'Impactor"
    setsid "$IMPACTOR" >/dev/null 2>&1 < /dev/null &
fi

log "Glisse dans Impactor : $(pwd)/xtool/Echo.ipa"
