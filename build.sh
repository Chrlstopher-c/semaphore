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

# `Info.plist` est GÉNÉRÉ : le dépôt ne contient que le gabarit, sans adresse
# réelle. Les vraies valeurs vivent dans `.env.local`, jamais suivi par git.
# Sans ce fichier, on compile avec les exemples du gabarit et on le dit.
generer_plist() {
    local gabarit="Info.template.plist" sortie=".build/Info.plist"
    [ -f "$gabarit" ] || die "$gabarit introuvable"
    mkdir -p .build

    if [ -f .env.local ]; then
        set -a; . ./.env.local; set +a
        log "adresses lues dans .env.local"
    else
        log "pas de .env.local — compilation avec les adresses d'exemple (voir .env.example)"
    fi

    SAILY="${ECHO_ADRESSE_SAILY:-}" CCREMOTE="${ECHO_ADRESSE_CCREMOTE:-}" \
    CCREMOTE_LAN="${ECHO_ADRESSE_CCREMOTE_LAN:-}" ECHOHUB="${ECHO_ADRESSE_ECHOHUB:-}" \
    IRIS="${ECHO_ADRESSE_IRIS:-}" IRIS_CLE="${ECHO_CLE_IRIS:-}" LUEUR="${ECHO_ADRESSE_LUEUR:-}" \
    GABARIT="$gabarit" SORTIE="$sortie" python3 - <<'PY' || die "génération de $sortie impossible"
import os, re, sys

remplacements = {
    'EchoAdresseSaily': os.environ.get('SAILY', ''),
    'EchoAdresseCcremote': os.environ.get('CCREMOTE', ''),
    'EchoAdresseCcremoteLAN': os.environ.get('CCREMOTE_LAN', ''),
    'EchoAdresseEchoHub': os.environ.get('ECHOHUB', ''),
    'EchoAdresseIris': os.environ.get('IRIS', ''),
    'EchoCleIris': os.environ.get('IRIS_CLE', ''),
    'EchoAdresseLueur': os.environ.get('LUEUR', ''),
}
source = open(os.environ['GABARIT'], encoding='utf-8').read()
for cle, valeur in remplacements.items():
    if not valeur:
        continue
    motif = re.compile(r'(<key>' + re.escape(cle) + r'</key>\s*<string>)[^<]*(</string>)')
    source, n = motif.subn(lambda m: m.group(1) + valeur + m.group(2), source, count=1)
    if n != 1:
        sys.exit(f"clé {cle} absente du gabarit — substitution refusée")
open(os.environ['SORTIE'], 'w', encoding='utf-8').write(source)
PY
    log "Info.plist généré dans $sortie"
}

generer_plist

log "Compilation ($(swift --version 2>/dev/null | head -1))"
xtool dev build --ipa "$@" || die "échec de la compilation"

IPA="xtool/Echo.ipa"
[ -f "$IPA" ] || die "IPA non produit"
log "IPA prêt : $(pwd)/$IPA ($(du -h "$IPA" | cut -f1))"
