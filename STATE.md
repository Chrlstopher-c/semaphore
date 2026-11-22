# État — Echo

Résumé vivant, inter-sessions. Les décisions et leurs raisons sont dans
`ARCHITECTURE.md` ; ce qui reste à faire et ce qui demande un arbitrage sont
dans `TODO.md`.

Dernière mise à jour : **22/11/2026** — **Quart** : texte en direct, étincelle de travail et dictée qui défile (voir
ci-dessous) ; monde Quart v1 refait à l'identique de la partie Code de l'appli Claude iOS (branche `dev`).

---

## 22/11/2026 — Quart : mode vocal (branche `dev`)

- Bouton rond « waveform » à droite du champ de la session → panneau vocal à la place du composeur. Écoute continue
  (dictée française sur l'iPhone), envoi automatique après 1,3 s de silence, réponse lue pendant qu'elle s'écrit
  (premier morceau à la première virgule, puis phrase par phrase), « Passer », coupure de la voix quand Chris dit au
  moins deux vrais mots (l'écho de la phrase lue ne compte pas), annonces « [Mode vocal activé : …] » devant le premier
  message et « [Mode vocal terminé] » devant le premier message tapé après.
- Voix : route `/api/voix` du nœud (Quart) → service `lanterne-voix` de la tour (synthèse de Reflet, voix clonée
  « baddie ») ; un nœud sans voix relaie à ses pairs. Repli : voix française de l'iPhone (30 s avant de réessayer).
  Micro et voix sur UN moteur avec le traitement de la voix d'iOS (annulation d'écho), reconstruit s'il s'arrête.
- **Prouvé sur banc réel** (aiguilleur + nœud + client Swift Linux + vraie voix, `leModeVocalRecoitLaVoixPhraseParPhrase`) :
  premier son reçu 1,5 s après le premier mot écrit ; puis ~1 s de blanc entre deux phrases (synthèse d'une phrase
  ≈ 2,6 s pour 5 s d'audio, demandée après la précédente). **Seulement codé** : tout l'audio iPhone (à constater).

## 22/11/2026 — Quart : direct, étincelle, dictée (branche `dev`)

- **Direct — cause trouvée** : le nœud envoyait ses messages de FÉDÉRATION (instantané des sessions, confirmations)
  à tous les canaux ouverts, iPhone compris ; l'iPhone, ne les connaissant pas, fermait son canal. Comme la fiche de
  la session change sans cesse pendant un tour, le flux en direct mourait à chaque réponse et l'appli retombait sur
  l'interrogation (réponse d'un bloc, secondes après le PC). Corrigé des deux côtés : le nœud n'envoie plus la
  fédération qu'aux nœuds (Quart), et l'iPhone écarte un message inconnu sans fermer son canal — ce qui suffit avec le
  moteur actuel du portable, même non mis à jour.
- **Prouvé sur banc réel** (aiguilleur + nœud de banc + client Swift sous Linux, `leDirectArriveAuFilDeLEau`, fiche
  de session modifiée pendant la rafale) : ancien client → canal fermé après 2 deltas ; nouveau client, contre le
  moteur actuel (6 instantanés écartés) comme contre le corrigé : 60/60 deltas, 31 paquets étalés sur 1,84 s, retard
  médian 32 ms, max 65 ms.
- Autour : ré-abonnement acquitté par le nœud ; flux tenu pour vivant dès le premier message ; direct cumulé par bloc ;
  relecture qui voit la fin du tour éteint le direct ; journal `flux` / `aiguilleur` (abonnement, fermetures de canal
  et de lien avec leur cause) lisible dans `idevicesyslog`.
- **Rendu comme l'appli Claude** : étincelle orange qui respire dès l'envoi et jusqu'à la fin du tour, libellé en reflet
  (« Claude travaille… », « Réflexion… ») ; texte révélé mot à mot à 30 pas/s (`RythmeDirect`, noyau testé), fin du
  dernier paragraphe en fondu (`FonduQueue`, TextRenderer iOS 18) ; la réponse finale prend la place du direct sans
  clignoter.
- **Dictée** : la zone dictée grandit jusqu'à 8 lignes puis défile et suit la fin à chaque mot (avant : texte tronqué
  en « … »).
- **Non vérifié** : rendu et fluidité sur l'iPhone, direct en 4G réelle (moteur du portable et aiguilleur du Pi non
  touchés).

---

## 22/11/2026 — monde Quart v1 (branche `dev`)

- **Pourquoi** : piloter toutes les sessions Claude Code du parc depuis l'iPhone, avec l'interface de la partie Code de
  l'appli Claude iOS (cadrage : `QUART-V1.md` ; écrans, jetons et écarts : `QUART-V1-ECRANS.md`). Étalon : 24 captures
  de Chris dans `etalon/` (ignoré), inventaire mesuré au pixel dans `etalon/INVENTAIRE.md` (ignoré).
- **Modules gardés** : `Vigie` / `VigieNoyau` (renommer aurait touché le pupitre et la veille pour rien) ; le monde
  s'appelle Quart à l'écran. Plomberie de Vigie conservée : veille, notifications natives, trousseau, accès à distance
  (fichiers, terminal, ouvert depuis le tiroir « Machines »).
- **Noyau** : contrat du nœud (sessions étendues, 20 genres d'événements, messages du WebSocket `/api/flux`, panneau,
  comptes, corps, routes), décodage tolérant (un champ inconnu ne casse jamais le fil), logique de présentation (dates
  relatives, lignes de la liste, résumés d'actions repris de Lanterne, blocs du fil, détail d'outil, catalogue des
  modèles). Tests sur les 5315 événements réels anonymisés (`QUART_FIL_REEL=<chemin>`, jamais copiés).
- **Lien** : WebSocket `/api/flux` (Bearer, ping 25 s, reprise 2 → 30 s, rattrapage des fils, repli long-poll après 3
  échecs), appairage par code (`/api/appareils/appairer`, clé au trousseau), texte en cours d'écriture en direct.
- **Écrans** : liste Code, tiroir, session (fil, composeur, demandes de permission / questions), feuilles modèle /
  effort, usage, tâches de fond, suite d'actions et détail (commande, sortie, diff), nouvelle session, réglages,
  appairage. Toujours sombre (le pupitre aussi).
- **Vérifié** : `swift test --filter VigieNoyauTests`, `xtool dev build`, comparaison structurelle écran par écran.
  **Non vérifié** : rendu sur l'iPhone, connexion à un vrai nœud (l'aiguilleur et le tunnel, étape 5 de
  `lanterne/recherche/RESEAU.md`, ne sont pas livrés).

---

## 28/09/2026 nuit — monde Lueur (branche `dev`)

- **Lueur** : le ruban de LED de la chambre (contrôleur Bluetooth ELK-BLEDOM) piloté par le serveur Lueur du Pi
  (dépôt local `~/lueur`, API HTTP, adresse dans `.env.local` → `ECHO_ADRESSE_LUEUR`). Roue chromatique HSV exacte,
  interrupteur au cœur, intensité, préréglages + favoris, animations du contrôleur avec interrupteur « Animation » et
  vitesse. File d'envoi « la dernière gagne » par famille de commande (noyau `LueurNoyau`, 8 tests).
- **Vérifié** : noyau (`swift test`), compilation iOS sans avertissement, et **sur l'iPhone** par Chris le 29/09
  (« tout fonctionne », après correction côté serveur du Pi : trames BLE de 9 octets).

---

## 28/09/2026 soir — Vigie : accès à distance (branche `dev`)

- Nouvel onglet **Accès** : chaque appareil du parc → Fichiers (parcourir, image zoomable, texte/code éditable et
  enregistré, Markdown mis en forme, PDF/vidéo/son/documents par QuickLook, partage, dépôt de fichiers et de photos,
  renommer, supprimer, nouveau dossier, fichiers cachés), Terminal (shell, ou « Terminal ici » depuis un dossier),
  Sessions Claude (fil, terminal attaché à la session tmux, nouvelle session sur cette machine).
- Tout passe par le relais ccremote (`/api/machines/:id/fichier(s)`, WebSocket `/api/terminal`, jeton en Bearer) :
  marche en 4G. Terminal : SwiftTerm 1.20.0 copié dans `Vendor/SwiftTerm` (son manifeste retire les sources Apple dès
  que l'hôte de compilation est Linux ; fichiers Apple/iOS gardés `canImport(UIKit)` pour `swift test`, rendu Metal
  retiré). Session URL dédiée sans délai d'inactivité + ping 25 s.
- **Vérifié** : noyau (tests `AppareilTests`), compilation iOS, et les mêmes requêtes que l'iPhone rejouées depuis le
  VPS (dépôt/relecture/suppression, terminal par jeton en en-tête — ce qui a révélé et fait corriger un plantage du
  relais). **Non vérifié** : sur l'iPhone lui-même.

---

## 28/09/2026 — monde Iris (branche `dev`)

- **Iris** : la caméra de l'iPhone devient la webcam « iPhone (Iris) » (`/dev/video10`) du portable et de la tour,
  les deux à la fois. Capture AVFoundation, H.264 matériel encodé UNE fois, envoyé en TCP direct à chaque PC
  (port 8798) ; le relais du Pi (adresse dans `.env.local`) ne fait que présenter les PC. Un PC ne reçoit l'image que
  si une application lit sa webcam. Récepteurs et relais : dépôt `~/iris`.
- Clé partagée dans `.env.local` (`ECHO_CLE_IRIS`), injectée par `build.sh` ; `NSCameraUsageDescription` ajoutée.
- **Vérifié** : noyau (15 tests `swift test`), compilation iOS, chaîne récepteur H.264/TCP → v4l2loopback (émetteur
  simulé). **Non vérifié** : sur l'iPhone (capture, rotation, encodeur, liaison).

---

## 28/09/2026 — Vigie v2 (branche `dev`)

- **Pourquoi** : ccremote a été refondu (plus d'orchestrateur ni de mandats ; des sessions Claude Code persistantes
  dans tmux, pilotées depuis le relais du Pi). L'ancienne Vigie (18 500 lignes, conversation avec l'orchestrateur,
  décisions, équipes) parlait à une API qui n'existe plus.
- **Nouvelle Vigie** : onglets Sessions (fil détaillé : outils dépliables avec leur entrée, sous-agents suivis outil par
  outil, jalons étape / objectif / question), Parc (mesures, réveil, extinction), Alertes, Réglages. Ouvrir une session
  sur n'importe quelle machine (projet d'une autre machine compris), lui parler, l'interrompre, la compacter, la reprendre,
  basculer son autonomie.
- **iOS natif Apple** (refonte du 28/09, choix de Chris : « ça fait trop webapp ») : listes groupées, balayage
  Interrompre / Fermer, menus contextuels, menu « … » de session, fil façon Messages, outils en `DisclosureGroup`,
  compositeur sur la matière `.bar`, formulaires système. Typo et couleurs du système ; la teinte Echo Agency
  (brand-600 clair / brand-400 night) est le seul accent. **Le pupitre ne force plus le sombre quand Vigie est au
  premier plan** : elle suit le mode de l'iPhone avec tout le natif (barres, barre d'état, listes).
- **Veille conservée** (maintien en vie audio / localisation, réveils de fond, alarme de silence, échéance de
  signature) ; le centre d'alerte lit maintenant `/api/attente` du relais. **Répondre à une question de Claude depuis la
  notification** (action à saisie de texte, écran verrouillé).
- **Premier plan** : un seul long-poll en vol (`/api/attente`), rendu par le relais dès qu'une session, un fil ou une
  notification change ; le fil de la session affichée est suivi en direct.
- **À vérifier sur l'iPhone** (non fait, Chris dormait) : connexion, rendu clair/sombre, polices, notification
  « Répondre ».

---

## 27/09/2026 — monde Tamis + nouvelle barre (branche `tamis`, `8f0d55b`)

- **Tamis** : tri de la photothèque pour alléger iCloud. Quatre onglets —
  Strates (poids par année/mois, tamisage par période), Tri (glisser
  gauche/droite), Pistes (doublons, similaires, rafales, vidéos lourdes,
  captures, documents, ratées, vidéos accidentelles), Panier (suppression).
- **Barre du pupitre refaite** : monde actif seul + grille de mondes.
- **Constaté sur l'iPhone** (Chris) : l'app se lance, l'accès photos, la pesée
  et l'analyse Vision tournent. Premier IPA : crash au lancement
  (`No Observable object of type Atelier`) — `.environment` posé avant
  `.overlay`, corrigé dans `8f0d55b`.
- **Mesures réelles** (carnet lu sur l'iPhone) : 13 590 éléments, **108,8 Go** ;
  9 050 photos analysées en ~15 min (~10 photos/s sur A12), 10 illisibles ;
  l'esthétique Vision marche sur le XS. Paires similaires : 288 (≥ 0,95),
  635 (≥ 0,92), 1 933 (≥ 0,88). Ratées (< −0,25) : 876.
- **Suspect** : `isUtility` marque 4 744 photos sur 9 040 (52 %), avec une
  note esthétique médiane identique au reste — la piste « Documents et reçus »
  est probablement trop large. En attente du coup d'œil de Chris.
- **Rien n'a encore été supprimé** : panier vide.
- Le build iOS se fait sur le **portable** (`~/Downloads/echo-centre`, copie de
  travail) ; xtool n'est plus sur la tour. La tour reste la source et le git.

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


## Aiguilleur iPhone : chiffrement de bout en bout (22/11/2026)
- **Fait** : port Swift de `commun/chiffrement/` (X25519, Ed25519, HKDF-SHA256, AES-256-GCM, poignée signée, canal
  à compteurs) dans `Sources/VigieNoyau/Aiguilleur/`. Interopérable : les vecteurs produits par Quart
  (`commun/chiffrement/vecteurs-croises.ts`, graines fixées) sont reproduits octet pour octet, dans les deux sens.
  15 tests (vecteurs, rejeu, réordonnancement, troncature, altération, réflexion, usurpation, réponse rejouée,
  clé Ed25519 non canonique). `swift test` : 100 verts après rebase sur `dev`.
- **Dépendance** : `swift-crypto` seulement sous Linux (CryptoKit sur Apple, API identique). Le build iOS n'en dépend pas.
- **Pas fait** : client de l'aiguilleur (appairage `POST /api/membres/appairer`, lien `/aiguilleur`, identité de
  l'appareil dans le trousseau) ; côté nœud Quart, accepter un canal d'appareil et servir l'API clients dedans
  (`genre` dans la présentation et les pairs, routes en canal, `GET /api/etat` testé) ; réglage « Passer par
  l'aiguilleur » ; transport qui reprend l'interface du client HTTP/WS actuel.
- **CI** : le dépôt n'a pas de `.github/workflows/ci.yml` : à créer avant la première poussée sur `main`.
- **Canal d'appareil (22/11, suite)** : `Aiguilleur/CanalAppareil.swift` (appairage, poignée, trames, ordre des envois),
  `Aiguilleur/Protocole.swift` (messages miroirs de Quart, décodés depuis les exemples de vecteurs), `Aiguilleur/
  LienAiguilleur.swift` (appairage par code, WebSocket `/aiguilleur`, compilé sous Linux, pas encore essayé contre un
  aiguilleur réel), `Aiguilleur/ReglagesAiguilleur.swift` (réglage « Passer par l'aiguilleur », actif seulement si complet).
  Côté Quart : appareil accepté au nœud → API clients dans le canal (`relais/federation/appareils.ts`), testé de bout en bout.
- **Reste** : identité d'appareil dans le trousseau, hôte de l'appli (transport au choix du réglage), écran du réglage,
  essai réel Swift ↔ nœud Quart sur la tour.
- **CI** : `.github/workflows/ci.yml` (tests du noyau sur Linux, `swift test`).
