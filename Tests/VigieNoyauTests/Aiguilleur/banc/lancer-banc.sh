#!/bin/bash
# Responsabilité : banc réel du client de l'aiguilleur. Lance un aiguilleur Quart (relais/bin.ts, mode aiguilleur) et
# un nœud de banc (banc-aiguilleur.ts) sur 127.0.0.1, puis lance le test Swift AiguilleurBancTests contre eux.
# Usage : lancer-banc.sh <racine du worktree Quart> <dossier de données jetable>
# Le script ne tue rien : il écrit les PID de ses processus dans <dossier>/pids ; c'est à l'appelant de les arrêter.
set -euo pipefail

QUART="${1:?racine Quart absente}"
DOSSIER="${2:?dossier de données absent}"
BANC="$(cd "$(dirname "$0")" && pwd)"
RACINE_SWIFT="$(cd "$BANC/../../../.." && pwd)"
BUN="$(command -v bun)"
PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
URL="http://127.0.0.1:$PORT"
mkdir -p "$DOSSIER"
DOSSIER="$(cd "$DOSSIER" && pwd)"
: > "$DOSSIER/pids"

(cd "$QUART" && env -i PATH="$PATH" HOME="$HOME" \
  LANTERNE_RELAIS_MODE=aiguilleur LANTERNE_RELAIS_ECOUTE="127.0.0.1:$PORT" LANTERNE_RELAIS_DONNEES="$DOSSIER" \
  CCREMOTE_JOURNAL="$DOSSIER/aiguilleur.log" \
  timeout 900 "$BUN" run relais/bin.ts >"$DOSSIER/aiguilleur.out" 2>"$DOSSIER/aiguilleur.err") &
echo "aiguilleur $!" >> "$DOSSIER/pids"

code=""
for _ in $(seq 1 200); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL/aiguilleur" || true)
  [ "$code" = "401" ] && break
  sleep 0.2
done
[ "$code" = "401" ] || { echo "aiguilleur muet sur $URL"; exit 1; }

codes() {
  (cd "$QUART" && env -i PATH="$PATH" HOME="$HOME" LANTERNE_RELAIS_DONNEES="$DOSSIER" \
    "$BUN" run relais/aiguilleur/commande.ts appairer banc | sed -n 1p)
}
CODE_NOEUD="$(codes)"
CODE_APPAREIL="$(codes)"
CODE_INTRUS="$(codes)"

SORTIE="$DOSSIER/banc.json"
rm -f "$SORTIE"
(cd "$QUART" && env -i PATH="$PATH" HOME="$HOME" TMPDIR="$DOSSIER" QUART_RACINE="$QUART" BANC_URL="$URL" \
  BANC_CODE_NOEUD="$CODE_NOEUD" BANC_CODE_APPAREIL="$CODE_APPAREIL" BANC_CODE_INTRUS="$CODE_INTRUS" \
  BANC_SORTIE="$SORTIE" timeout 900 "$BUN" run "$BANC/banc-aiguilleur.ts" \
  >"$DOSSIER/noeud.out" 2>"$DOSSIER/noeud.err") &
echo "noeud $!" >> "$DOSSIER/pids"

for _ in $(seq 1 300); do
  [ -s "$SORTIE" ] && break
  sleep 0.2
done
[ -s "$SORTIE" ] || { echo "nœud de banc non prêt : voir $DOSSIER/noeud.err"; exit 1; }

cd "$RACINE_SWIFT"
. ~/.local/share/swiftly/env.sh
export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
QUART_AIGUILLEUR_BANC="$SORTIE" systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0 \
  swift test --scratch-path ~/Downloads/quart-build-aig --filter AiguilleurBancTests
echo "test banc terminé ; PID à arrêter : $DOSSIER/pids"
