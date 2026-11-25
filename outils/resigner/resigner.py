"""Re-signe et réinstalle par Wi-Fi les applis iOS installées en free provisioning, avant l'expiration de leur profil.

Tourne sur le portable (usbmuxd, plumesign, compte Apple). Applis et IPA non signées : ~/.config/resigner/apps.json ({"Nom": "~/projets/<dépôt>/xtool/<Nom>.ipa"}).
Un appel = un contrôle : rien à faire si aucun profil n'expire dans moins de SEUIL_HEURES.
"""
import fcntl
import json
import logging
import os
import plistlib
import re
import subprocess
import sys
import zipfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

SEUIL_HEURES = 48
RACINE = Path.home() / ".local/share/resigner"
CONFIG = Path.home() / ".config/resigner/apps.json"
SIGNEES = RACINE / "signees"
ETAT = RACINE / "etat.json"
PLUMESIGN = Path.home() / ".local/opt/plumesign"
MUX = os.environ.get("USBMUXD_SOCKET_ADDRESS", "127.0.0.1:27015")
DELAI_INSTALLATION_S = 900
JOURNAL = Path.home() / ".local/state/resigner/journal.log"

log = logging.getLogger("resigner")


def expiration_profil(ipa: Path) -> datetime:
    """Date d'expiration du profil embarqué dans une IPA signée."""
    with zipfile.ZipFile(ipa) as z:
        nom = next(n for n in z.namelist() if re.fullmatch(r"Payload/[^/]+\.app/embedded\.mobileprovision", n))
        brut = z.read(nom)
    xml = brut[brut.index(b"<?xml"): brut.index(b"</plist>") + len(b"</plist>")]
    return plistlib.loads(xml)["ExpirationDate"].replace(tzinfo=timezone.utc)


def charger_apps() -> dict[str, Path]:
    """Applis à entretenir : nom → IPA non signée (dans le dépôt de l'appli, sous xtool/)."""
    try:
        brut = json.loads(CONFIG.read_text())
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        log.error("configuration illisible (%s) : %s", CONFIG, exc)
        return {}
    return {nom: Path(chemin).expanduser() for nom, chemin in brut.items()}


def lire_etat() -> dict[str, str]:
    try:
        return json.loads(ETAT.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def ecrire_etat(etat: dict[str, str]) -> None:
    ETAT.write_text(json.dumps(etat, indent=2))


def a_renouveler(expiration: str | None) -> bool:
    if expiration is None:
        return True
    limite = datetime.now(timezone.utc) + timedelta(hours=SEUIL_HEURES)
    return datetime.fromisoformat(expiration) <= limite


def iphone_joignable() -> bool:
    """Vrai si netmuxd voit l'iPhone ; la découverte mDNS peut prendre quelques secondes après son démarrage."""
    env = {**os.environ, "USBMUXD_SOCKET_ADDRESS": MUX}
    for _ in range(6):
        try:
            sortie = subprocess.run(["idevice_id", "-n"], env=env, capture_output=True, text=True, timeout=20)
        except (subprocess.TimeoutExpired, OSError) as exc:
            log.error("détection de l'iPhone impossible : %s", exc)
            return False
        if sortie.stdout.strip():
            return True
        time.sleep(10)
    return False


def signer(source: Path, sortie: Path) -> None:
    sortie.unlink(missing_ok=True)
    cmd = [str(PLUMESIGN), "sign", "--apple-id", "-p", str(source), "-o", str(sortie)]
    res = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    if res.returncode != 0 or not sortie.exists():
        raise RuntimeError(f"signature échouée : {res.stderr[-300:]}")


def installer(signee: Path) -> None:
    """`plumesign device` demande un terminal pour choisir l'appareil : pty fourni par `script`, Entrée validée."""
    journal = RACINE / "installation.log"
    journal.unlink(missing_ok=True)
    env = {**os.environ, "USBMUXD_SOCKET_ADDRESS": MUX}
    cmd = ["script", "-qec", f"{PLUMESIGN} device -i {signee}", str(journal)]
    subprocess.run(cmd, input=b"\n\n", env=env, capture_output=True, timeout=DELAI_INSTALLATION_S)
    if "InstallComplete" not in journal.read_text(errors="replace"):
        raise RuntimeError(f"installation non confirmée (voir {journal})")


def renouveler(nom: str, source: Path) -> str:
    signee = SIGNEES / f"{nom}.ipa"
    signer(source, signee)
    installer(signee)
    return expiration_profil(signee).isoformat()


def main() -> int:
    for dossier in (SIGNEES, JOURNAL.parent):
        dossier.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(filename=JOURNAL, level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    verrou = open(RACINE / "verrou", "w")
    try:
        fcntl.flock(verrou, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return 0
    etat = lire_etat()
    en_echec = 0
    for nom, source in sorted(charger_apps().items()):
        if not source.exists():
            log.error("%s : IPA introuvable (%s)", nom, source)
            en_echec += 1
            continue
        if not a_renouveler(etat.get(nom)):
            log.info("%s : profil valable jusqu'au %s, rien à faire", nom, etat[nom])
            continue
        if not iphone_joignable():
            log.warning("%s : à renouveler mais l'iPhone n'est pas joignable en Wi-Fi, nouvel essai à la prochaine passe", nom)
            continue
        try:
            etat[nom] = renouveler(nom, source)
            ecrire_etat(etat)
            log.info("%s : renouvelé, expire le %s", nom, etat[nom])
        except (RuntimeError, subprocess.SubprocessError, OSError, KeyError, ValueError) as exc:
            log.error("%s : renouvellement échoué : %s", nom, exc)
            en_echec += 1
    return 1 if en_echec else 0


if __name__ == "__main__":
    sys.exit(main())
