# Architecture d'Echo

Le centre de contrôle iOS de Chris : **Vigie** (le client de ccremote),
**EchoHub Mobile** (le client du modèle local), **Saily** (la besace de
capture) et **Duplex** (l'écoute du son du PC) dans une seule app, un seul
bundle, une seule signature hebdomadaire. Ce document dit quelles frontières
existent et pourquoi ; chaque monde garde sa propre charte et sa propre
architecture dans son dossier.

## Le parti pris — deux apps entières, pas une fusion

Les deux apps ont été écrites séparément, chacune avec une direction artistique
forte : « Quart de nuit » pour Vigie, « Le fil » pour EchoHub. Leurs chartes
portent les **mêmes noms de fichiers** (`Teinte`, `Typo`, `Trame`, `Elan`,
`Ton`) mais **pas les mêmes jetons** — relevé avant la fusion : sept couleurs
communes sur vingt-cinq, deux styles de texte sur vingt-quatre. Ce ne sont pas
deux thèmes d'un même système, ce sont deux systèmes.

Les fusionner en une seule charte reviendrait à refaire les deux apps. Donc :

> **Chaque app est un module Swift entier, charte comprise. La frontière de
> module est la seule chose qui les sépare, et c'est suffisant.**

Quinze types homonymes (`Coquille`, `Teinte`, `Typo`, `RenduMarkdown`,
`ValeurJSON`…) cohabitent sans qu'un seul ait été renommé, parce qu'aucun
fichier n'importe les deux modules — sauf `Echo`, qui qualifie tout ce qu'il
nomme (`Vigie.Coquille`, `EchoHub.Coquille`).

Ce que ça coûte, et qu'on assume : deux parseurs markdown, deux journaux
(`Trace` / `Journal`), deux clients HTTP. C'est de la duplication
**accidentelle** — ces codes changent pour des raisons différentes — et la
doctrine tolère celle-là. Mutualiser maintenant serait l'abstraction prématurée
qui couple deux domaines indépendants.

## Les modules

| Module | Ce que c'est | Dépend de |
|---|---|---|
| `VigieNoyau` | logique pure de Vigie : contrat ccremote v2, structure du fil, formats, veille (filigrane), markdown. Testable sur Linux. | — |
| `Vigie` | les écrans de Vigie (charte Echo Agency clair/night), le client du relais, **et le système de veille** (`Alerte/`). | `VigieNoyau` |
| `EchoHubNoyau` | logique pure d'EchoHub Mobile : relais, conversations, modèles, flux SSE, markdown. Testable sur Linux. | — |
| `EchoHub` | les écrans d'EchoHub Mobile et sa charte. | `EchoHubNoyau` |
| `SailyNoyau` | logique pure de Saily : état de la besace, contrat de synchro, file hors ligne. Testable sur Linux. | — |
| `Saily` | les écrans de la besace et sa charte. | `SailyNoyau`, `Systeme` |
| `DuplexNoyau` | logique pure de Duplex : en-tête de paquet, suivi de séquence, tampon audio, correction de dérive, machine à états du jumelage. Testable sur Linux. | — |
| `Duplex` | la découverte mDNS, le canal de contrôle, la réception UDP, la lecture audio et ses écrans. | `DuplexNoyau`, `Systeme` |
| `TamisNoyau` | logique pure de Tamis : fiche d'un cliché, tamisage par période et nature, strates, similarité (fenêtre glissante + union-find), élection de la meilleure photo, pistes, décisions et carnet persistés. Testable sur Linux. | — |
| `Tamis` | l'accès PhotoKit (inventaire, pesée, suppression), l'analyse Vision, les écrans et la charte. | `TamisNoyau`, `Systeme` |
| `Systeme` | le socle de design commun : neutres, sémantiques, typo, grille, galbes, motion. | — |
| `Echo` | **le pupitre** : point d'entrée, délégué d'application, sélecteur de monde. Cinq fichiers. | `Vigie`, `EchoHub`, `Saily`, `Duplex`, `Tamis`, `VigieNoyau`, `Systeme` |

`Echo` est volontairement minuscule. Tout ce qui ressemble à une fonctionnalité
appartient à un monde ; le pupitre ne fait que choisir lequel est devant et
tenir le processus en vie.

## Le système de veille tient le processus entier

C'est la raison d'être du centre. Vigie porte depuis août 2026 un système de
maintien en vie (`Sources/Vigie/Alerte/`) : session audio silencieuse, relais
par localisation quand une autre app prend l'audio, réveils de fond, centre de
notifications. Il tenait Vigie seule ; il tient maintenant **le processus**,
donc aussi EchoHub.

Conséquence concrète : une génération ou un téléchargement de modèle survit à
l'écran éteint. `EchoHub.Coquille` coupait sa génération à l'arrière-plan —
c'était juste pour une app seule, qu'iOS suspend en deux secondes. Hébergée,
elle reçoit de l'hôte une politique de suspension
(`suspendreEnArrierePlan: { !MaintienVie.partage.actif }`) et ne coupe plus
tant que la veille tient.

Le délégué d'application est celui de Vigie (`DelegueApplication`) : c'est lui
qui enregistre les tâches de fond au lancement — iOS refuse tout enregistrement
passé `didFinishLaunching` — et qui relaie les notifications.

## Le pupitre

`Pupitre` monte **les deux coquilles en permanence** dans un `ZStack`, et bascule
par opacité — exactement comme Vigie fait pour ses propres piles. Changer de
monde ne démonte rien : la génération EchoHub continue pendant qu'on tranche une
décision au Quart, et le Quart sonde le Pi pendant qu'on lit une réponse.

La barre (`SelecteurMonde`, refaite le 27/09/2026) ne montre que le monde
actif : glyphe à son accent, nom, chevron. La toucher déroule `GrilleMondes`,
une grille de tuiles à trois colonnes par-dessus le monde assombri. Raison : la
rangée de pilules ne tenait plus à cinq mondes sur 335 pt ; la grille en tient
dix sans changer de forme. Ajouter un monde = un cas à `Monde` (titre, rôle,
symbole), un à `TeinteEcho`, une `scene` au pupitre. Chaque monde garde sa barre
en bas.

## Le bundle

`com.echo.labs`, celui de Vigie. Trois raisons : c'est un App ID déjà enregistré
sur le compte gratuit (quota de dix par semaine) ; `BGTaskSchedulerPermittedIdentifiers`
le porte en préfixe ; et installer Echo **remplace** Vigie sur l'appareil,
ce qui est le but. EchoHub Mobile (`com.echo.echohub`) reste installable à
côté tant qu'on veut comparer.

## Contrats consommés du serveur — la compaction

Le monde Machine ne réimplémente rien du serveur EchoHub v2 : il consomme ses
contrats. La balise de compaction en est un exemple à garder en tête, parce que
sa forme est **fixée côté serveur** et ne doit pas diverger.

Le backend auto-compacte le contexte à 90 % de la fenêtre du modèle (résumé
côté moteur, historique intact) et le signale par une structure `InfoCompaction`
aux noms de champs **stables**, livrée par deux voies :

- **en direct**, événement SSE `type: "compaction"` (avant les fragments du tour
  qui l'a déclenchée) → décodé par `EvenementFlux.compaction`, posé dans
  `Salon.compactionEnCours` ;
- **au rechargement**, champ `MessageChat.compaction` sur le message assistant
  déclencheur.

`InfoCompaction` (`Sources/EchoHubNoyau/Conversation/`) reprend ces noms tels
quels — toute divergence casserait le décodage en silence. La source de vérité
du contrat est `backend/chat/modeles.py` du dépôt `echohub-v2` ; l'app le
consomme, ne le définit pas. Rendu : `BaliseCompaction`, bloc repliable en
registre `note`.

## Ce qui reste dans les dépôts d'origine

- `/mnt/projects/echohub-mobile/Relais/` — le relais Bun qui tourne sur le Pi.
  Il n'a rien à faire dans une app iOS.
- L'historique git des deux apps. Echo part de `vigie@8a0454e`
  (branche `relais-localisation`) et `echohub-mobile@7a583a2`
  (branche `extension-machine`). Les commits antérieurs se lisent là-bas.

## Règles de frontière

- Un fichier de `Vigie/` n'importe jamais `EchoHub`, et réciproquement.
- `Echo/` ne contient aucune logique métier. Si un fichier y dépasse cent
  lignes, quelque chose a été mis au mauvais endroit.
- Un jeton de charte ne traverse pas un module. Le sélecteur utilise ceux de
  Vigie, qualifiés — c'est l'unique exception, et elle est nommée.

## Duplex — un contrat réseau qu'on ne possède pas

Le monde Duplex parle à une application de bureau (Rust/Tauri, PC Arch) par un
protocole figé qui vit **hors de ce dépôt** : `/mnt/projects/duplex/PROTOCOLE.md`.
Les deux côtés s'y conforment, personne ne le modifie seul, et toute évolution
passe par ce fichier d'abord.

Ce qu'il impose, et qui ne se négocie pas dans le code : découverte mDNS
`_duplex._tcp`, contrôle WebSocket sur TCP 7651, audio UDP unicast en PCM brut
48 kHz stéréo 16 bits, en-tête de 12 octets, paquets de 5 ms, tampon cible
100 ms, correction de dérive plafonnée à ±0,3 %.

> **Tout ce qui est pur vit dans `DuplexNoyau` et rien d'autre.** L'analyse
> d'en-tête, la détection de trou, l'anneau audio, le calcul de dérive et la
> machine à états du jumelage n'importent ni `Network`, ni `AVFoundation`, ni
> SwiftUI. C'est ce qui les rend éprouvables par `swift test` sur Linux — et
> sans simulateur ni débogueur, c'est la seule preuve automatique du projet.

Deux points que le protocole laisse implicites, tranchés dans
`MachineJumelage` **sans inventer de message** : après `jumelage.accepte` on
enchaîne sur `bonjour` (seule voie définie vers `bienvenue`, donc vers le nom du
PC et ses sources) ; un `jumelage.refuse` reçu pendant l'authentification se lit
comme « ce jeton est mort » et relance un jumelage complet. Sans le second, un
PC réinstallé laisserait l'app coincée sur un jeton que personne ne reconnaît.

### La session audio ne prend pas l'écran verrouillé

`.playback` + `.mixWithOthers`, et rien d'autre. Avec `.mixWithOthers`, Duplex
ne devient jamais l'app « qui joue » aux yeux du système, donc il ne prend
**pas** les contrôles de l'écran verrouillé — Sillon en a besoin, et une
collision là-dessus serait un défaut grave. C'est aussi ce qui laisse le son du
PC se mêler à ce que le téléphone joue déjà.

### Le fil de rendu ne se bloque jamais

`TamponAudio` est un anneau à deux indices **atomiques**, un seul producteur (la
réception UDP) et un seul consommateur (le rappel de rendu). Pas de verrou : le
rappel d'`AVAudioEngine` tourne sur un fil temps réel, et s'y bloquer une
milliseconde produit exactement le trou qu'on cherche à éviter. Pour la même
raison, la correction de dérive est calculée **dans** le rappel, à partir du
remplissage lu au même instant — aucune valeur ne traverse deux fils.

## Tamis — la photothèque sans rien envoyer

- **Rien ne quitte l'iPhone.** Similarité et jugement esthétique par Vision
  (`VNGenerateImageFeaturePrintRequest`, `VNCalculateImageAestheticsScoresRequest`
  d'iOS 18), sur des vignettes locales de 360 px — aucun téléchargement iCloud.
- **Similarité en fenêtre glissante** : chaque photo n'est comparée qu'à ses
  voisines de moins de 15 min (32 au plus). Linéaire, et c'est là que vivent
  les quasi-doublons. Seules les paires au-dessus de 0,80 sont gardées (pas les
  vecteurs : 3 Ko × 35 000) ; le seuil affiché se règle après coup sans relancer.
- **Seuils Vision non étalonnés** (similaires 0,88–0,95, ratée < −0,25) : estimés,
  exposés à l'écran, à ajuster après les premiers essais réels.
- **Poids** : somme des `PHAssetResource` lue par KVC (`fileSize`, non public
  mais stable depuis iOS 10). Inconnu ≠ zéro.
- **Suppression** : seul le panier supprime ; iOS confirme ; les éléments
  passent 30 jours dans « Supprimés récemment » avant de quitter iCloud.
- **Persistance** : `Application Support/Tamis/decisions.json` (panier, gardés)
  et `carnet.json` (analyses, paires, poids), séparés parce qu'ils ne valent pas
  pareil.
- L'analyse se suspend en arrière-plan (Vision y échoue) et reprend au retour.
- Le monde ne démarre qu'à sa première visite : sinon la demande d'accès aux
  photos surgirait au lancement d'Echo.
