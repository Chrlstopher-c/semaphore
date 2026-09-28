# TODO — Echo

## Constaté sur l'appareil — 28/08/2026

- [x] **Le pupitre et le sélecteur de monde** — `Quart` / `Machine` vus, la
      bascule fonctionne. Constaté par Chris (captures).
- [x] **Le monde Machine** — chargement de modèles, conversations, génération en
      flux, panneau d'occupation : utilisés sur l'iPhone.
- [x] **Correctif « Machine injoignable »** — le faux message ne réapparaît
      plus. « Le message n'apparaît plus, c'est nickel » (Chris).

## À constater sur l'appareil — Chris

- [ ] **Vigie v2 sur l'iPhone** : poser l'IPA, se connecter, vérifier clair/sombre, polices, fil, et « Répondre »
      depuis une notification de question. Les anciennes entrées Vigie ci-dessous (badge, canal, SondeChaine) sont
      caduques depuis la refonte v2.
- [ ] **La veille tient-elle le monde Machine ?** Lancer une génération longue
      dans EchoHub, éteindre l'écran, revenir : la réponse doit avoir continué.
      C'est LA promesse du centre, et elle n'est prouvée nulle part.
- [ ] **Le relais de localisation pendant Sillon.** Écouter de la musique,
      revenir sur l'écran du canal : « veille par localisation » doit y figurer.
- [ ] **Le badge et les notifications de Vigie** arrivent-ils encore ? Le
      délégué est le même, le bundle est le même — mais l'app est nouvelle.
- [ ] **La balise de compaction s'affiche-t-elle correctement ?** Registre
      `note`, repliable, au-dessus du bon message assistant. En direct (longue
      génération qui franchit 90 % du contexte) ET au rechargement d'un fil
      compacté. Compile, jamais vu à l'œil.

## Tamis — à constater sur l'appareil

- [x] Accès photos, inventaire, pesée sur la vraie photothèque (13 590 éléments, 108,8 Go).
- [x] Analyse Vision complète : 9 050 photos en ~15 min, esthétique disponible sur le XS.
- [ ] **Piste « Documents et reçus » (52 % des photos)** : Chris regarde si ce
      sont surtout des papiers. Sinon, la resserrer — `utilitaire` ET score bas,
      ou ajout d'une détection de texte (`VNRecognizeTextRequest`).
- [ ] Seuils de similarité : juger quelques groupes au réglage « Proches » (0,92).
- [ ] Première suppression réelle : une seule confirmation iOS pour un gros panier ?
- [ ] Nouvelle barre : lisibilité de la grille des mondes.

## Tamis — dette

- [ ] `Journal` (Tamis, et Duplex/Saily sur le même modèle) écrit par `print` :
      sur l'appareil, stdout part dans le vide — rien n'apparaît dans
      `idevicesyslog`. Passer à `os.Logger` (subsystem `com.echo.labs`).

## Tamis — suite possible

- Archivage vers la tour avant suppression (originaux via
  `PHAssetResourceManager`, serveur sur le disque backup) : supprimer sans perdre.

## À faire — seul

- [ ] **L'écran du canal de Vigie** affiche l'état audio explicitement. Pendant
      une écoute, il dira « audio inactif » sans dire que le canal 2 a pris le
      relais. Le verdict global (`complet`) est juste, le détail est trompeur.
- [ ] **Un geste pour changer de monde** en plus du sélecteur — balayage à deux
      doigts, ou appui long sur la barre du bas. À décider devant l'appareil.
- [ ] **Les avertissements de `SondeChaine.swift`** (Vigie, `UIDevice.current`
      depuis un contexte non isolé). Préexistants, hors périmètre de la fusion,
      mais ils sortent à chaque build.
- [ ] `start.sh` / `stop.sh` / `restart.sh` : les projets iOS frères n'en ont
      pas (rien ne se lance sur cette machine). À trancher : convention à part
      entière, ou scripts vides pour la forme.

## Fusions en attente — après validation du test de Chris

- [ ] `compaction-balise` → `master` (echo-centre), une fois le rendu de la
      balise validé sur l'iPhone.
- [ ] Côté serveur (dépôt `echohub-v2`) : `auto-compact` → `main`, une fois
      l'auto-compact validé dans le web / l'app. Porte aussi le watchdog relevé
      à 900 s.

## Écarté — décisions de Chris, 28/08/2026

- **Relevé** et **Under** ne rejoignent pas le centre.
- **Sillon** reste une app à part — elle a besoin de l'audio en exclusif pour
  l'écran verrouillé, et c'est incompatible avec la veille par audio.
- **Les moteurs** (`/api/engines/*`) ne sont pas exposés dans EchoHub Mobile.
