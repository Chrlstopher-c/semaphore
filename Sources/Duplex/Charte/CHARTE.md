# La charte de Duplex — « La pièce d'à côté »

La direction artistique du monde Duplex, l'écoute sur l'iPhone du son qui sort
du PC. Ce document dit **pourquoi** chaque jeton existe ; le code de la charte
dit **quelle valeur** il porte. Les deux ne doivent jamais diverger.

## Le parti pris

On entend le PC comme à travers un mur : le son de la pièce d'à côté, qui se
mêle à ce qu'on écoute déjà sans le remplacer. La DA porte ce geste — **calme,
nocturne, presque sans couleur**. On ne « lance un flux », on ouvre une porte.

Trois partis, dans cet ordre :

1. **L'écran d'écoute est fait pour durer.** Une heure, une soirée : on le
   regarde longtemps et peu souvent. Il ne contient donc qu'un objet — l'anneau
   — et trois mesures en petit, éteintes. La liste des PC disparaît pendant
   l'écoute ; rien ne clignote, rien ne défile. L'anneau respire sur quatre
   secondes, en opacité seulement, et reste immobile sous « Réduire les
   animations ».

2. **L'accent vit sur une seule chose par écran.** La framboise `#F2589B` dit
   deux choses et rien d'autre : « voilà le geste » (l'anneau au repos, le
   bouton Valider, la cellule de code courante) et « le son coule » (l'anneau
   en écoute). Deux éléments framboise sur un même écran n'en désignent plus
   aucun. Corollaire : un écran calme est un écran graphite.

3. **Le même objet porte les deux états.** L'anneau est à la fois le bouton
   Écouter et le témoin d'écoute : le passage à l'écoute est une transformation
   de ce qu'on regarde déjà, jamais un remplacement d'écran. Le mouvement sert
   cette lecture — et rien d'autre.

## Ce qui vient du socle, et ce qui n'en vient pas

Duplex est né sur le socle `Systeme` : les écrans écrivent `Neutre`, `Voix`,
`Grille`, `Rayon`, `Mouvement` et `Toucher` **directement**. Aucun alias local
(`Teinte.fond`, `Typo.corps`) — chez Saily ces alias sont des noms historiques ;
ici ils seraient des jetons sans emploi.

Ce que la charte ajoute, et pourquoi :

- **`Teinte`** — l'accent, l'accent enfoncé (dérivé), l'encre sur accent.
- **`Ton`** — actif · ok · alerte · panne · neutre, et son voile à 15 %. Pas
  d'`Ambiance` ni de `Palier` : Duplex n'emboîte jamais une carte dans une carte.
- **`Voix.code`** et **`Voix.nomPoste`** — deux voix sans équivalent socle : le
  chiffre qu'on recopie d'un écran à l'autre, et le nom du PC qu'on lit de loin.
- **`Trame`** — uniquement des tailles de composant (anneau, cellule, jauge).
  La grille de 4 pt gouverne les distances, pas la taille d'un anneau.
- **`Allures`** — `appui`, `engage`, `Lisere`, `Fronton`, `Panneau`, `Sceau`,
  `Bandeau`, `EtatCalme`. Le retour d'appui vient toujours de
  `configuration.isPressed`.

## Les états, et eux seuls

| État réel (`Duplexeur`) | Ce qu'on montre |
|---|---|
| aucun PC | état calme « Aucun PC en vue », veilleuse de recherche |
| PC découverts | rangées sobres, sceau d'étape sur le PC choisi |
| code attendu | feuille : six cellules, cellule courante liserée d'accent |
| jumelé, silencieux | salle : nom du PC, source, anneau graphite « Écouter » |
| en écoute | salle seule : anneau framboise qui respire, tampon, trous, coupures |

Rien n'est affiché que le noyau ne fournisse. Le compteur de coupures se teinte
en `alerte` dès qu'il n'est plus à zéro — c'est la seule couleur que l'écran
d'écoute admet en dehors de l'anneau.
