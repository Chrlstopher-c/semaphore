# TODO — Echo

## À constater sur l'appareil — Chris

- [ ] **Le pupitre existe-t-il visuellement ?** Le sélecteur de monde en tête,
      au-dessus de chaque coquille. Jamais vu à l'œil : calculé, pas constaté.
- [ ] **La veille tient-elle le monde Machine ?** Lancer une génération longue
      dans EchoHub, éteindre l'écran, revenir : la réponse doit avoir continué.
      C'est LA promesse du centre, et elle n'est prouvée nulle part.
- [ ] **Le relais de localisation pendant Sillon.** Écouter de la musique,
      revenir sur l'écran du canal : « veille par localisation » doit y figurer.
- [ ] **Le badge et les notifications de Vigie** arrivent-ils encore ? Le
      délégué est le même, le bundle est le même — mais l'app est nouvelle.

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

## Écarté — décisions de Chris, 28/08/2026

- **Relevé** et **Under** ne rejoignent pas le centre.
- **Sillon** reste une app à part — elle a besoin de l'audio en exclusif pour
  l'écran verrouillé, et c'est incompatible avec la veille par audio.
- **Les moteurs** (`/api/engines/*`) ne sont pas exposés dans EchoHub Mobile.
