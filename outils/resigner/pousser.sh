#!/usr/bin/env bash
# Dépose une nouvelle IPA non signée sur le portable et la fait installer tout de suite par Wi-Fi (ou USB si câblé).
# Usage : ./pousser.sh Sillon /mnt/projects/sillon/xtool/Sillon.ipa   |   ./pousser.sh Echo xtool/Echo.ipa
set -euo pipefail
H="${IPHONE_HOTE:-portable}"
[ $# -eq 2 ] && [ -f "$2" ] || { echo "usage : $0 <Echo|Sillon> <fichier.ipa>" >&2; exit 1; }
case "$1" in
    Echo) DEST='projets/semaphore/xtool/Echo.ipa' ;;
    Sillon) DEST='projets/sillon/xtool/Sillon.ipa' ;;
    *) echo "appli inconnue : $1 (voir apps.json)" >&2; exit 1 ;;
esac
scp -q "$2" "$H:$DEST"
ssh "$H" "python3 -I ~/.local/opt/resigner/resigner.py --forcer $1; tail -2 ~/.local/state/resigner/journal.log"
