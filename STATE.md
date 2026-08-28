# État — Echo

Résumé vivant, inter-sessions. Les décisions et leurs raisons sont dans
`ARCHITECTURE.md` ; ce qui reste à faire et ce qui demande un arbitrage sont
dans `TODO.md`.

Dernière mise à jour : **28/08/2026**, création du dépôt.

---

## En une phrase

Les deux apps sont assemblées, tout compile pour iOS, 334 tests verts, l'IPA
est produit et déposé sur le portable — et **rien n'a jamais tourné sur un
iPhone** : le pupitre, la veille qui tient le monde Machine, le relais de
localisation, sont calculés, pas constatés.

## Ce qui existe — 28/08/2026

| Pièce | État | Preuve |
|---|---|---|
| Module `Vigie` + `VigieNoyau` | copié de `vigie@8a0454e` (branche `relais-localisation`), sans son `@main` | compile iOS |
| Module `EchoHub` + `EchoHubNoyau` | copié de `echohub-mobile@7a583a2` (branche `extension-machine`), sans son `@main` | compile iOS |
| Module `Echo` | 4 fichiers : `EchoApp`, `Pupitre`, `SelecteurMonde`, `Monde` | compile iOS |
| `EchoHub.Coquille` | reçoit une politique de suspension de l'hôte (`suspendreEnArrierePlan`) | compile iOS |
| `Info.plist` | union des deux : modes de fond, permissions, réseau local, sombre | — |
| IPA | `xtool/Echo.ipa`, 28,2 Mo, 0 erreur | `sha256 0a5caeb4…aa72a`, identique sur le portable (`~/Echo.ipa`) |
| Tests | 156 (Vigie, swift-testing) + 178 (EchoHub, XCTest) | `swift test`, 0 échec |

`☠` Les deux branches d'origine sont **non fusionnées et non testées par
Chris** au moment de la copie. Echo est l'endroit où elles seront testées ; si
un défaut apparaît, il vient d'une des deux, pas de l'assemblage — sauf pour
ce que `Echo/` et la modification de `EchoHub.Coquille` ajoutent.

## Ce qui a été décidé, et par qui

- **Chris, 28/08** : deux apps au final — Sillon seule, et Echo = Vigie +
  EchoHub. Relevé et Under écartés. Le système de fond de tâche s'applique à
  toutes les features.
- **Chris, 28/08** : Sillon doit continuer à lire la musique pendant que le
  centre reste en veille. Réglé côté Vigie par le relais de localisation
  (`MaintienVieLocalisation`), jamais en touchant Sillon.
- **Moi** : pas de charte commune — deux modules entiers, un pupitre minimal
  peint avec la charte de Vigie. Raison mesurée dans `ARCHITECTURE.md`.
- **Moi** : bundle `com.echo.labs` (celui de Vigie). Installer Echo remplace
  Vigie.

## Chaîne de compilation

Swift 6.3.3 (swiftly), SDK Darwin, xtool 1.17.0 — sur la machine fixe et sur le
portable, mêmes versions. Détail : `README.md`.

`☠` `swift build` est vert et ne prouve rien pour `Echo/` : tout y est sous
`#if canImport(SwiftUI)`. La preuve est `xtool dev build`.

## Avertissements connus

`Sources/Vigie/Diagnostic/SondeChaine.swift:158-159` — `UIDevice.current`
depuis un contexte non isolé, six fois par build. Préexistant dans Vigie, hors
périmètre de la fusion, listé dans `TODO.md`.
