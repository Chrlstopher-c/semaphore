"""Pont relais → ntfy : publie vers ntfy les notifications « important » et « alerte » du nœud Lanterne de cette machine.

Suit `/api/attente` (attente longue, comme l'iPhone) avec un filigrane `seq` persistant : un fait n'est publié qu'une fois,
l'arriéré n'est jamais publié au premier lancement (ce n'est pas une nouvelle). Une publication ratée est retentée sans
avancer le filigrane. `--essai` publie une notification d'essai et sort.
Environnement : LANTERNE_MOTEUR_PORT_WEB, LANTERNE_MOTEUR_JETON (noeud.env), NTFY_URL, NTFY_SUJET, NTFY_JETON.
"""
import json
import logging
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ETAT = Path(os.environ.get("PONT_ETAT", Path.home() / ".local/state/pont-ntfy/filigrane.json"))
PRIORITE = {"important": 3, "alerte": 4}
ATTENTE_S = 25
log = logging.getLogger("pont-ntfy")


def requete(url: str, jeton: str, corps: dict[str, object] | None = None, delai: int = 40) -> dict[str, object]:
    donnees = json.dumps(corps).encode() if corps is not None else None
    req = urllib.request.Request(url, data=donnees, headers={"Authorization": f"Bearer {jeton}", "User-Agent": "pont-ntfy/1.0"})
    if donnees is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=delai) as rep:
        return json.loads(rep.read() or b"{}")


def lire_filigrane() -> int | None:
    try:
        return int(json.loads(ETAT.read_text())["seq"])
    except (FileNotFoundError, KeyError, ValueError):
        return None


def ecrire_filigrane(seq: int) -> None:
    ETAT.parent.mkdir(parents=True, exist_ok=True)
    ETAT.write_text(json.dumps({"seq": seq}))


def publier(notif: dict[str, object]) -> None:
    niveau = str(notif["niveau"])
    requete(os.environ["NTFY_URL"], os.environ["NTFY_JETON"], {
        "topic": os.environ["NTFY_SUJET"],
        "title": f"Sémaphore · {notif['titre']}",
        "message": str(notif["texte"]),
        "priority": PRIORITE.get(niveau, 3),
    })


def noeud(chemin: str) -> str:
    return f"http://127.0.0.1:{os.environ['LANTERNE_MOTEUR_PORT_WEB']}{chemin}"


def amorcer(jeton: str) -> int:
    """Premier lancement : on apprend le filigrane courant sans rien publier."""
    etat = requete(noeud("/api/etat"), jeton)
    seq = max((int(n["seq"]) for n in etat["notifications"]), default=0)
    ecrire_filigrane(seq)
    log.info("amorçage : filigrane %d, rien publié", seq)
    return seq


def tour(jeton: str, seq: int, version: int) -> tuple[int, int]:
    url = noeud(f"/api/attente?version={version}&notifications={seq}&attendre={ATTENTE_S}")
    rep = requete(url, jeton, delai=ATTENTE_S + 15)
    nouvelle_version = int(rep["version"])  # le relais redémarré repart de 0 : on adopte sa version, jamais plus haute
    for notif in sorted(rep["notifications"], key=lambda n: int(n["seq"])):
        if int(notif["seq"]) <= seq:
            continue
        if notif["niveau"] in PRIORITE:
            publier(notif)
            log.info("publié seq %s (%s) : %s", notif["seq"], notif["niveau"], notif["titre"])
        seq = int(notif["seq"])
        ecrire_filigrane(seq)
    return seq, nouvelle_version


def boucle() -> None:
    jeton = os.environ["LANTERNE_MOTEUR_JETON"]
    seq, version, echecs = lire_filigrane(), -1, 0
    if seq is None:
        seq = amorcer(jeton)
    while True:
        try:
            seq, version = tour(jeton, seq, version)
            echecs = 0
        except (urllib.error.URLError, OSError, ValueError, KeyError) as exc:
            echecs += 1
            pause = min(60, 2 ** min(echecs, 6))
            log.error("tour échoué (%d) : %s — nouvel essai dans %d s", echecs, exc, pause)
            time.sleep(pause)


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    if "--essai" in sys.argv:
        publier({"niveau": "important", "titre": "essai du pont", "texte": "Le pont relais → ntfy fonctionne."})
        return 0
    boucle()
    return 0


if __name__ == "__main__":
    sys.exit(main())
