# Echo

Le centre de contrôle iOS : **Vigie** (client de ccremote — parc d'agents,
décisions, terminal) et **EchoHub Mobile** (client du modèle local — fil,
conversations, machine) dans une seule app. Swift 6 / SwiftUI, compilée depuis
Arch Linux par [xtool](https://github.com/xtool-org/xtool) — sans Xcode, sans
simulateur. Cible unique : **iPhone XS, iOS 18**.

Pourquoi une seule app : en provisioning gratuit, chaque app expire au bout de
sept jours et se réinstalle à la main. Deux bundles, c'est deux signatures par
semaine ; un seul, c'est une. Et le système de veille de Vigie — session audio,
relais de localisation, réveils de fond — tient désormais le processus entier :
une génération EchoHub survit à l'écran éteint.

Architecture et frontières : `ARCHITECTURE.md`. État : `STATE.md`.

## Compiler et poser sur l'iPhone

```bash
./build.sh     # produit xtool/Echo.ipa (non signé)
./deploy.sh    # compile puis ouvre Impactor — le glisser-déposer reste manuel
```

`☠` L'environnement doit être posé avant tout appel à `swift` — les scripts le
font ; en ligne de commande, sans ces lignes, `swift` échoue sur un message
sans rapport (`libncurses.so.6 introuvable`) :

```bash
. "$HOME/.local/share/swiftly/env.sh"
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
export PATH="$HOME/.local/bin:$PATH"
```

## Vérifier

```bash
swift test         # les deux noyaux, sur Linux — la seule preuve automatique
xtool dev build    # la compilation iOS réelle
```

`☠` `swift build` seul ne prouve rien pour les écrans : tout ce qui touche
SwiftUI est sous `#if canImport(SwiftUI)`, donc vidé sur Linux. Seul
`xtool dev build` compile les vues.

## Chaîne de compilation

| Outil | Version | Où |
|---|---|---|
| swiftly + Swift | 6.3.3 | `~/.local/share/swiftly` |
| SDK Darwin | installé | `swift sdk list` → `darwin` |
| xtool | 1.17.0 | `~/.local/bin/xtool` |
| Impactor | AppImage | `~/.local/opt/Impactor.AppImage` |

Présente sur la machine fixe et sur le portable. Mise en place détaillée :
`/mnt/projects/sillon/DEPOT.md`.

## Signature gratuite

Sept jours. À l'expiration, **réinstaller par-dessus** — ne jamais supprimer
l'app, le conteneur de données part avec elle. Bundle `com.echo.labs` : installer
Echo remplace Vigie sur l'appareil, c'est voulu.
