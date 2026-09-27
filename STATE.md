# État — Echo

Résumé vivant, inter-sessions. Les décisions et leurs raisons sont dans
`ARCHITECTURE.md` ; ce qui reste à faire et ce qui demande un arbitrage sont
dans `TODO.md`.

Dernière mise à jour : **18/09/2026** — Movix retiré, monde **Duplex** ajouté
(branche `feat/duplex`). Rien de Duplex n'a encore tourné sur l'appareil.

---

## 27/09/2026 — monde Tamis + nouvelle barre (branche `tamis`)

- **Tamis** : tri de la photothèque pour alléger iCloud (~100 Go). Quatre
  onglets — Strates (poids par année/mois, tamisage par période), Tri (glisser
  gauche/droite), Pistes (doublons, similaires, rafales, vidéos lourdes,
  captures, documents, ratées, vidéos accidentelles), Panier (suppression).
- **Barre du pupitre refaite** : monde actif seul + grille de mondes.
- Preuve : `swift test --filter TamisNoyauTests` vert (20), `./build.sh` vert
  sur le **portable** (xtool n'est plus sur la tour depuis sa réinstallation).
  **Rien n'a encore tourné sur l'appareil.**

---

## En une phrase

Echo est **installée et utilisée sur l'iPhone de Chris**. Le pupitre, les deux
mondes et l'onglet Machine (chargement de modèles, génération) sont constatés à
l'œil ; ce qui touche l'arrière-plan (veille, notifications, relais de
localisation) et la nouvelle balise de compaction reste à constater.

## Ce qui est confirmé SUR L'APPAREIL — 28/08/2026

Contrairement à l'état précédent (« rien n'a jamais tourné sur un iPhone »),
Echo a réellement tourné. Constaté par Chris, captures à l'appui :

- **Le pupitre et le sélecteur de monde** — `Quart` / `Machine` en tête, la
  bascule fonctionne.
- **Le monde Machine** — chargement de modèles depuis l'onglet, conversations,
  génération en flux, panneau d'occupation du contexte, blocs de raisonnement
  repliés.
- **Le correctif « Machine injoignable »** — le faux message
  « Relecture impossible — Relais injoignable — cancelled » (une annulation
  locale prise pour une panne) **ne réapparaît plus**. Confirmé par Chris :
  « le message n'apparaît plus, c'est nickel ».
- **Le relais EchoHub** joignable depuis le téléphone (adresse + jeton posés
  dans les réglages Machine).

## Ce qui RESTE à constater sur l'appareil

- **La balise de compaction** (ci-dessous) — compile et décodage testé, jamais
  vue à l'écran : lisibilité en registre `note`, position au-dessus du bon
  message, repli en direct pendant qu'une réponse s'écrit.
- **La veille tient-elle le monde Machine ?** Génération longue, écran éteint,
  retour : la réponse doit avoir continué. C'est LA promesse du centre.
- **Le relais de localisation pendant Sillon** — « veille par localisation »
  doit figurer à l'écran du canal Vigie quand une autre app prend l'audio.
- **Le badge et les notifications de Vigie** — même délégué, même bundle, app
  nouvelle : à vérifier qu'ils arrivent encore.

## Compaction du contexte — 28/08/2026 (branche `compaction-balise`)

Le backend EchoHub v2 auto-compacte le contexte à 90 % de la fenêtre (résumé
côté moteur, historique intact — non destructif). L'app affiche la balise,
comme le web.

- **Noyau** : `InfoCompaction` (contrat figé, `Codable`/`Sendable`/`Hashable`),
  `MessageChat.compaction: InfoCompaction?` (rechargement), cas
  `EvenementFlux.compaction` + décodage de `EvenementCompaction` (direct).
- **Vues** : `BaliseCompaction` — bloc repliable, registre `note`, calqué sur
  `BlocReplie` ; rendu au-dessus du message assistant désigné, en direct
  (`Salon.compactionEnCours`, posée par l'événement) comme au rechargement
  (`MessageChat.compaction`).
- **Preuve** : `swift test` au vert (193 EchoHub/XCTest dont 4 de compaction,
  156 Vigie/swift-testing), `xtool dev build` vert. Rendu visuel jamais vu.

## État des branches — 28/08/2026

`master` porte l'assemblage (`f1ae087`) et le correctif « Machine injoignable »
(`c26289a`). **Deux branches non encore fusionnées, en attente du test de Chris :**

| Branche | Contenu | IPA |
|---|---|---|
| `master` | pupitre + correctif injoignable | — |
| `compaction-balise` | balise de compaction (noyau + vues) | `~/Echo.ipa` sur le portable, `sha256 88478b3b…96b2e`, 28,5 Mo |

L'IPA courante sur le portable inclut `compaction-balise`. Fusion dans `master`
à faire une fois le rendu validé sur l'appareil.

## Ce qui existe — modules

| Module | Rôle | Origine |
|---|---|---|
| `VigieNoyau` / `Vigie` | monde Quart (ccremote) | `vigie@8a0454e` (branche `relais-localisation`) |
| `EchoHubNoyau` / `EchoHub` | monde Machine (modèle local) | `echohub-mobile@7a583a2` (branche `extension-machine`) |
| `Echo` | pupitre : `EchoApp`, `Pupitre`, `SelecteurMonde`, `Monde` | écrit pour la fusion |

`EchoHub.Coquille` reçoit de l'hôte une politique de suspension
(`suspendreEnArrierePlan`) : la veille de Vigie tient le processus, la
génération n'est plus coupée à l'écran éteint.

## Le monde Saily — « La Besace » (28/08)

Troisième monde : le client iOS de l'inbox de capture Saily (serveur en prod,
`https://saily.example.com`). Découpage identique aux deux autres —
`SailyNoyau` (pur, testable Linux) + `Saily` (SwiftUI, charte propre).

- **DA « La Besace »** : accent turquoise `#2AD4C6` (ni la pervenche d'EchoHub,
  ni le bleu de Vigie), neutres graphite chauds, SF Pro Rounded. `CHARTE.md`.
- **Noyau** : `Item`/`ItemInput`/messages sync miroirs de `contracts.ts`
  (horodatages ms `Int`, clés camelCase sans conversion) ; `ClientSaily` (REST +
  `urlSync`) ; `ConnexionSync` (WebSocket, reconnexion à backoff **borné** ≤
  30 s) ; `EtatBoite`, réducteur pur — snapshot, dédup par id/updatedAt,
  filtrage des pierres tombales, file offline bornée rejouée à la reconnexion.
- **Écrans** : inbox (épingles en tête, recherche, filtre par tag, aperçu blob
  authentifié), capture (note/lien auto-détecté, photo/vidéo, fichier → upload
  blob, tags), réglages (adresse prod par défaut + jeton + « tester » sur
  `/health`).
- **Intégration** : `Monde.saily` (`tray.full.fill`), monté dans `Pupitre`,
  `Package.swift`. Aucun fichier de Vigie/EchoHub touché.
- **Share Extension écartée** : xtool 1.17.0 ne construit qu'un produit
  `.library` en une seule app — pas de cible d'extension ni d'App Group (le
  projet s'interdit tout entitlement). Capture in-app livrée ; URL scheme custom
  laissé en repli possible (détail dans le rapport de session).
- **Preuves 28/08** : `swift build` 0 erreur ; `swift test` 37 tests Saily verts
  (226 XCTest + 156 swift-testing au total, 0 échec) ; `xtool dev build` →
  `Echo.app`, exit 0.

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

---

## Duplex — 18/09/2026 (branche `feat/duplex`)

**Movix est retiré** : cible, produit, cas d'énumération, teinte, plein écran du
pupitre, adresse de build. Plus aucune référence dans le code, les tests ou la
configuration — seules ces notes d'historique en gardent le nom.

**Le monde Duplex le remplace** : l'écoute sur l'iPhone du son qui sort du PC,
conforme à `/mnt/projects/duplex/PROTOCOLE.md` (fichier hors de ce dépôt, que
personne ne modifie seul).

### Ce qui est ÉPROUVÉ

- `swift test` : **303 tests XCTest + 156 swift-testing, 0 échec**, dont
  **77 nouveaux** sur `DuplexNoyau`.
- Le banc de dérive (`EcouteLongueTests`) simule 75 s d'écoute avec deux
  horloges désaccordées de 0,2 %, dans les deux sens. Chaque cas corrigé est
  doublé d'un **témoin à facteur figé qui doit échouer** ; vérifié en inversant
  le signe de la correction : le tampon part à 443 ms d'un côté, à 0,04 ms et
  deux famines de l'autre. Le banc sait donc échouer.
- `xtool dev build` : **compilation iOS complète réussie** (`xtool/Echo.app`
  produit). Elle a attrapé deux vrais défauts — une méthode appelée et jamais
  écrite, et une feuille de jumelage dont on ne pouvait pas sortir.

### Ce qui reste à CONSTATER sur l'appareil

Rien de ce qui suit n'a tourné sur un iPhone ni contre le vrai PC — la
compilation prouve que ça tient debout, pas que ça marche :

- La découverte mDNS trouve-t-elle le PC (l'invite « réseau local » d'iOS 18) ?
- Le jumelage complet : code à six chiffres, jeton conservé, retour sans code.
- **Le son sort-il, et se mêle-t-il à ce que le téléphone joue déjà ?**
- **Duplex ne prend PAS les contrôles de l'écran verrouillé** — Sillon en a
  besoin, c'est le point à vérifier en priorité.
- L'écoute longue : une heure, et vérifier au relevé que le tampon reste près
  de 100 ms et que « Coupures » ne monte pas.

### La direction artistique n'est pas faite

Les écrans de `Sources/Duplex/` sont volontairement sobres : jetons du socle
`Systeme` uniquement, aucun composant maison, aucune animation. Le seul jeton
propre au monde est son accent, dans `Sources/Duplex/Charte/Teinte.swift` —
rose framboise `#F2589B`, choisi pour ne ressembler à aucun des trois autres
mondes montrés côte à côte dans la barre du pupitre.

