#!/usr/bin/env bash
# Installe le re-signeur sur le portable : fichiers, sources IPA, unités systemd utilisateur. Idempotent.
# Retour arrière : ssh portable 'systemctl --user disable --now resigner.timer netmuxd.service' ; avahi : systemctl disable --now avahi-daemon.
# Prérequis portable (une fois, sudo) : /etc/tmpfiles.d/netmuxd-usbmuxd.conf = `L /run/usbmuxd - - - - /run/user/1000/netmuxd.sock` — plumesign ne parle QU’À /var/run/usbmuxd (chemin en dur, il ignore USBMUXD_SOCKET_ADDRESS) ; netmuxd sert donc cette socket.
set -euo pipefail
cd "$(dirname "$0")"
H="${IPHONE_HOTE:-portable}"
die() { printf '\033[31m✗\033[0m %s\n' "$1" >&2; exit 1; }
ssh -o ConnectTimeout=8 -o BatchMode=yes "$H" true || die "portable injoignable"
ssh "$H" 'mkdir -p ~/.local/opt/resigner ~/.config/systemd/user ~/.config/resigner ~/.local/share/resigner/signees ~/projets'
scp -q resigner.py "$H:.local/opt/resigner/resigner.py"
scp -q netmuxd.service resigner.service resigner.timer "$H:.config/systemd/user/"
[ -f apps.json ] && scp -q apps.json "$H:.config/resigner/apps.json"
ssh "$H" 'systemctl is-enabled --quiet avahi-daemon.service || echo "! avahi-daemon désactivé : sudo systemctl enable --now avahi-daemon"
  systemctl --user daemon-reload && systemctl --user enable --now netmuxd.service resigner.timer
  systemctl --user is-active netmuxd.service; systemctl --user list-timers resigner.timer --no-pager | head -3'
