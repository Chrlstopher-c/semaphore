# Charte de Vigie — « Quart de nuit »

Direction artistique de la refonte d'août 2026. Ce document est le contrat de la
forme : si un écran contredit une règle écrite ici, c'est l'écran qui a tort —
ou c'est ce document qu'il faut amender, jamais les deux à la fois.

## Le parti pris

Vigie est un poste de garde consulté la nuit, d'une main, pour cinq secondes.
La charte en tire quatre partis, dans cet ordre :

1. **Sombre, unique, assumé.** L'app est en thème sombre en permanence
   (`preferredColorScheme(.dark)` posé une fois par la coquille). Pas de
   variante claire : un écran consulté dans le noir à 3 h du matin ne doit
   jamais éblouir, et une seule apparence est une apparence qu'on peut régler
   au millimètre. Les neutres sont **chauds**, tirés vers la teinte de
   l'orange Badlands — un sombre de braise, pas un sombre d'écran de veille.

2. **L'orange veut dire « ta main est requise ». Rien d'autre.** `#D97757`
   est réservé à ce qui attend une décision ou un geste de Chris : la file du
   quart, le bouton qui engage, la pastille de compte. Un état qui informe
   sans réclamer n'a pas le droit à l'orange — sinon l'accent cesse d'être un
   signal. Corollaire : un écran calme est un écran presque sans couleur.

3. **Le calme est un état conçu, pas un vide.** « Rien à trancher » et
   « PC éteint » sont le régime des nuits. Ils se peignent en ardoise
   (`veille`), avec la lune, jamais en rouge ni en gris triste. Le rouge est
   réservé aux pannes réelles et aux gestes destructifs.

4. **La fraîcheur est une donnée de premier rang.** Chaque écran porte son
   âge en tête (« il y a 3 h »), qui se teinte quand il vieillit. Jamais de
   tourniquet quand une donnée datée existe : une silhouette d'attente ne
   s'affiche qu'au tout premier lancement.

## Palette

Neutres chauds (teinte ~20°), sémantiques désaturés pour la nuit.

| Jeton | Hex | Emploi |
|---|---|---|
| `fond` | `#171210` | fond de tout écran |
| `fondCreux` | `#100D0A` | zones en retrait (rails, encarts creusés) |
| `surface` | `#201A15` | panneaux, cartes |
| `surfaceHaute` | `#2B231C` | feuilles, bulles, éléments soulevés |
| `filet` | blanc 7 % | traits de séparation |
| `filetAppuye` | blanc 14 % | bordures de champs, contours actifs |
| `encre` | `#F2EAE3` | texte principal |
| `encreDouce` | `#B9ACA0` | texte secondaire |
| `encreTernie` | `#8A7D71` | légendes, métadonnées |
| `accent` | `#D97757` | **décision attendue, geste qui engage** |
| `encreSurAccent` | `#2B130A` | texte sur fond accent (contraste 5,6:1) |
| `sain` | `#8FBE7C` | mesuré bon, geste abouti |
| `vigilance` | `#E3AE4F` | données vieillissantes, seuils approchés |
| `danger` | `#E6404D` | panne réelle, destructif, écriture de fichiers |
| `veille` | `#92A7BD` | calme : PC éteint, pause, repos |

Règles d'emploi :
- Un **voile** est la couleur à 14 % d'opacité ; le texte posé dessus est la
  couleur elle-même (les sémantiques sont calibrées lisibles sur sombre).
- `danger` ≠ `accent` : le premier est un rouge framboise franc, le second un
  orange terreux. Un mandat en **écriture** porte du danger (il modifie des
  fichiers), un mandat en lecture porte du sain — l'accès réel colore la carte.
- Les boutons accent portent une **encre sombre**, pas du blanc : contraste
  réel et signature visuelle de la charte.

## Typographie

Trois voix, jamais plus :
- **New York (serif)** pour les titres d'écran — la voix du journal de quart.
  `Typo.grandTitre` (28 sb), `Typo.titreFeuille` (20 sb).
- **SF Pro** pour tout le corps. `texteFort` 15 sb · `texte` 15 · `note` 13 ·
  `legende` 11,5 · `rubrique` 12 sb majuscules espacées (têtes de section).
- **SF Mono** pour toute donnée : chiffres, heures, identifiants, terminal.
  `chiffre` 20 md · `mono` 13 · `monoPetit` 11,5 · `monoMinuscule` 10.

Règle : une heure, un montant, un pourcentage, un id — c'est du mono. Le mono
est ce qui distingue une **mesure** d'une phrase.

## Trame

Espacements : `fin` 4 · `serre` 8 · `element` 12 · `bloc` 16 · `ecran` 20 ·
`section` 28. Galbes : `encart` 10 · `bouton` 12 · `panneau` 14 · capsule
pour les sceaux. Trait : 1 pt. Cible tactile minimale : **44 pt**, boutons de
décision **50 pt** — la géométrie du pouce prime sur la densité.

## Mouvement

Un système, pas une collection. Trois ressorts (`Elan`) :

| Ressort | Paramètres | Emploi |
|---|---|---|
| `vif` | response 0,26 · damping 0,88 | retour d'appui, bascules, sélection |
| `pose` | response 0,40 · damping 0,86 | changements d'état, plis/déplis |
| `entree` | response 0,55 · damping 0,82 | arrivée d'un élément nouveau |

`cascade(rang)` = `entree` retardé de 45 ms × rang, plafonné à 6 rangs.

Ce qui bouge : l'arrivée d'un élément **nouveau**, un changement d'état
explicite, le retour d'appui. Ce qui ne bouge **jamais** : un rafraîchissement
périodique (identités stables, aucune animation de relevé), le texte en cours
de lecture, la position de défilement. `contentTransition(.numericText())`
sur les chiffres qui changent ; `symbolEffect(.bounce)` sur l'onglet choisi.
Pas de flous animés ni de rotations 3D : la puce A12 les paie en fluidité.

## Haptique

`Haptique` (via `sensoryFeedback`) : `contact` (appui léger) · `selection`
(bascule, onglet) · `reussite` (geste serveur abouti) · `garde` (armement,
seuil) · `alerte` (la file grossit). Un geste = un retour, jamais deux.

## Le piège gestuel (règle absolue)

Le retour d'appui d'un contrôle vient **toujours** de `configuration.isPressed`
dans un `ButtonStyle` (`Allures.swift`). Jamais de `onLongPressGesture` ni de
geste custom posé sur un `Button` ou un `NavigationLink` : le geste gagne la
course contre le contrôle, le toucher est avalé, et rien ne le signale.
`BoutonArme` (maintien pour l'irréversible) est un contrôle autonome — pas un
`Button` décoré.

## Navigation

Cinq onglets : **Quart · Fil · Parc · Machines · Terminal**.

- **Quart absorbe Décisions.** Le défaut fondateur de la webapp était une
  décision noyée ; la réponse est une seule pièce d'entrée où la file se
  tranche directement — pas un onglet d'accueil qui renvoie vers un onglet de
  décisions. Les trois circuits (mandats, rallonges, arbitrages) gardent
  leurs objets, libellés et routes ; seule la pièce est commune.
- **Réglages** est un portillon (roue dentée) dans l'en-tête du Quart : on y
  va une fois par semaine, il ne mérite pas un septième d'écran permanent.
- **Alerte** s'ouvre par la cloche de l'en-tête du Quart (badge = non-lues)
  et depuis les Réglages. Une notification touchée y mène directement.
- Chaque domaine garde sa pile de navigation vivante ; l'état de liaison vit
  dans l'en-tête de chaque écran (`EnTeteEcran`), pas dans un bandeau global —
  « PC éteint » s'y peint en ardoise avec la lune, calme.

## Composants

`Panneau` (carte, relief par `Ton`) · `Sceau` (capsule d'état) ·
`PointVeille` (point vital, ne respire que si vivant) · `JaugeFine` (jauge
1,5 pt à seuils) · `TuileChiffre` (mesure du pouls) · `LigneCle` (clé/valeur)
· `BandeauNote` (message sémantique en place) · `EtatCalme` (état vide conçu)
· `SilhouetteAttente` (squelette du premier lancement uniquement) ·
`MentionFraicheur` (l'âge, auto-rafraîchi) · `PastilleLiaison` (état du lien)
· `BoutonArme` (maintien 1,2 s pour l'irréversible) · `AvisFugace` (toast) ·
`ChampQuart` (saisie) · `EnTeteEcran` (titre serif + liaison + fraîcheur) ·
`RailAccent` (le rail coloré des cartes de décision).

Chaque état sémantique passe par `Ton` (`attention` = accent, `sain`,
`vigilance`, `danger`, `veille`, `neutre`) — jamais une couleur nue dans un
écran.
