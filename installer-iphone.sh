#!/usr/bin/env bash
# Signe et installe Echo.ipa sur l'iPhone, par le portable (usbmuxd + plumesign, compte déjà enregistré).
# Usage : ./installer-iphone.sh [--build] [--attendre[=MIN]] [--a-blanc]
#   --build        compile d'abord (./build.sh)
#   --attendre     attend le branchement de l'iPhone (10 min par défaut) au lieu d'échouer tout de suite
#   --a-blanc      vérifie tout (IPA, portable, compte, iPhone) sans signer ni installer
# Retour arrière : réinstaller l'IPA précédente (conservée en xtool/Echo.precedent.ipa).
set -euo pipefail
cd "$(dirname "$0")"

PORTABLE="${IPHONE_HOTE:-portable}"
DISTANT='projets/semaphore/xtool'   # dépôt de l'appli sur le portable ; le re-signeur lit Echo.ipa ici
PLUME='$HOME/.local/opt/plumesign'
IPA="xtool/Echo.ipa"
BUILD=0; ATTENTE=0; A_BLANC=0

log() { printf '\033[36m▸\033[0m %s\n' "$1"; }
warn() { printf '\033[33m!\033[0m %s\n' "$1"; }
die() { printf '\033[31m✗\033[0m %s\n' "$1" >&2; exit 1; }

for arg in "$@"; do
    case "$arg" in
        --build) BUILD=1 ;;
        --attendre) ATTENTE=600 ;;
        --attendre=*) ATTENTE=$(( ${arg#*=} * 60 )) ;;
        --a-blanc) A_BLANC=1 ;;
        *) die "option inconnue : $arg" ;;
    esac
done

[ "$BUILD" = 1 ] && { ./build.sh || die "compilation échouée"; }
[ -f "$IPA" ] || die "$IPA absente — lance ./build.sh ou --build"

ssh -o ConnectTimeout=8 -o BatchMode=yes "$PORTABLE" true 2>/dev/null \
    || die "portable injoignable (ssh $PORTABLE) — allume-le"
log "portable joignable"

ssh "$PORTABLE" "test -x $PLUME" || die "plumesign absent du portable (~/.local/opt/plumesign)"
ssh "$PORTABLE" "$PLUME account list 2>&1" | grep -q selected \
    || die "aucun compte Apple sélectionné dans plumesign (plumesign account login, une fois)"
log "compte Apple enregistré"

ssh "$PORTABLE" 'systemctl is-active --quiet usbmuxd || sudo -n systemctl start usbmuxd 2>/dev/null || true'

trouver_udid() { ssh "$PORTABLE" 'idevice_id -l 2>/dev/null | head -1'; }
fin=$(( $(date +%s) + ATTENTE ))
UDID="$(trouver_udid)"
while [ -z "$UDID" ] && [ "$(date +%s)" -lt "$fin" ]; do
    [ -n "${rappel:-}" ] || { warn "branche l'iPhone au portable (câble USB-C → Lightning) et déverrouille-le"; rappel=1; }
    sleep 3; UDID="$(trouver_udid)"
done
[ -n "$UDID" ] || die "aucun iPhone vu par le portable (câble de données ? iPhone déverrouillé ? « Faire confiance » ?)"
NOM="$(ssh "$PORTABLE" 'ideviceinfo -k DeviceName 2>/dev/null' || true)"
log "iPhone détecté : ${NOM:-?}"

[ "$A_BLANC" = 1 ] && { log "à blanc : tout est prêt, rien n'a été signé ni installé"; exit 0; }

ssh "$PORTABLE" "mkdir -p ~/$DISTANT && { [ -f ~/$DISTANT/Echo.ipa ] && cp -f ~/$DISTANT/Echo.ipa ~/$DISTANT/Echo.precedent.ipa; true; }"
scp -q "$IPA" "$PORTABLE:$DISTANT/Echo.ipa" || die "copie de l'IPA vers le portable échouée"
log "IPA copiée ($(du -h "$IPA" | cut -f1))"

log "signature (compte Apple)"
ssh "$PORTABLE" "cd ~/$DISTANT && rm -f Echo.signee.ipa && $PLUME sign --apple-id -p Echo.ipa -o Echo.signee.ipa >/tmp/plume-sign.log 2>&1" \
    || die "signature échouée (journal : $PORTABLE:/tmp/plume-sign.log)"

# `plumesign --udid` ne retrouve pas l'appareil (testé le 25/11) : sans lui l'outil choisit l'iPhone branché,
# mais son menu exige un vrai terminal → pty fourni par `script`, validation par une touche Entrée.
ssh "$PORTABLE" "rm -f /tmp/plume-install.log"
log "installation sur l'iPhone"
printf '\n\n' | ssh -tt "$PORTABLE" "cd ~/$DISTANT && script -qec \"$PLUME device -i Echo.signee.ipa\" /tmp/plume-install.log >/dev/null 2>&1" \
    >/dev/null 2>&1 || true
ssh "$PORTABLE" 'grep -q InstallComplete /tmp/plume-install.log' \
    || die "installation non confirmée par l'iPhone (journal : $PORTABLE:/tmp/plume-install.log)"
log "installé — ouvre Echo sur l'iPhone (réglages › Général › VPN et gestion de l'appareil si « développeur non approuvé »)"
