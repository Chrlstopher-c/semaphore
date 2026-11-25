#!/usr/bin/env bash
# Installe le pont relais → ntfy sur CETTE machine (la tour, où tourne le nœud Lanterne). Idempotent.
# Prérequis : nœud Lanterne en service (~/.config/lanterne-noeud/noeud.env) ; secrets ntfy dans le coffre echo-vault :
# ntfy-serveur, ntfy-sujet, ntfy-jeton-publication. Retour arrière : systemctl --user disable --now pont-ntfy
set -euo pipefail
cd "$(dirname "$0")"
die() { printf '\033[31m✗\033[0m %s\n' "$1" >&2; exit 1; }
[ -f "$HOME/.config/lanterne-noeud/noeud.env" ] || die "nœud Lanterne absent (noeud.env introuvable)"
for s in ntfy-serveur ntfy-sujet ntfy-jeton-publication; do echo-vault get "$s" >/dev/null 2>&1 || die "secret $s absent du coffre"; done
mkdir -p ~/.config/pont-ntfy ~/.local/opt/pont-ntfy ~/.config/systemd/user
umask 077
printf 'NTFY_URL=%s\nNTFY_SUJET=%s\nNTFY_JETON=%s\n' "$(echo-vault get ntfy-serveur)" "$(echo-vault get ntfy-sujet)" \
    "$(echo-vault get ntfy-jeton-publication)" > ~/.config/pont-ntfy/ntfy.env
umask 022
cp pont_ntfy.py ~/.local/opt/pont-ntfy/; cp pont-ntfy.service ~/.config/systemd/user/
systemctl --user daemon-reload && systemctl --user enable --now pont-ntfy.service
sleep 3; systemctl --user is-active pont-ntfy
