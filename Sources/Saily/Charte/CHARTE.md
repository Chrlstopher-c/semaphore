# La charte de « La Besace »

La direction artistique du monde Saily, le client iOS de l'inbox de capture.
Ce document dit **pourquoi** chaque jeton existe ; le code de la charte dit
**quelle valeur** il porte. Les deux ne doivent jamais diverger.

> `☠` Règle unique qui gouverne tout le reste : **aucune couleur, aucune taille,
> aucun espacement nu dans un écran.** Tout passe par `Teinte`, `Typo`, `Trame`,
> `Ton` ou l'`Ambiance`. Un jeton sans emploi écrit n'existe pas. C'est ce qui
> empêche une charte de pourrir au fil des écrans.

## Le parti pris — « La Besace »

Saily est une **sacoche personnelle** : l'endroit où l'on jette tout ce qu'on
ramasse dans la journée — une note, un lien, une capture d'écran, un fichier —
pour le retrouver synchronisé sur l'autre appareil. La DA porte ce geste :
**décontractée, chaleureuse, immédiate.** On n'y range pas, on y **balance**.

Trois mondes cohabitent dans un seul bundle Echo, chacun avec sa charte propre
(`ARCHITECTURE.md`). La Besace doit se **distinguer au premier coup d'œil** de
ses voisins, sans jamais emprunter leurs jetons :

| Monde | DA | Accent | Neutres | Typo |
|---|---|---|---|---|
| Vigie | « Quart de nuit » | bleu | froids | SF Pro |
| EchoHub | « Le Fil » | pervenche `#8A7AFF` | froids | SF Pro |
| **Saily** | **« La Besace »** | **turquoise `#2AD4C6`** | **graphite chaud** | **SF Pro Rounded** |

Deux différenciateurs assumés, chacun vérifiable :

1. **L'accent turquoise `#2AD4C6`.** Ni la pervenche d'EchoHub, ni le bleu de
   Vigie : trois accents distincts pour trois mondes, sinon la cohabitation se
   lirait comme une incohérence. Le turquoise dit deux choses et rien d'autre —
   « ceci est interactif » et « la synchro est vivante ».
2. **Les neutres graphite CHAUDS + SF Pro Rounded.** EchoHub compose en neutres
   froids et grotesque neutre ; La Besace en graphite légèrement chaud
   (`#0E0D0C` → `#232019`) et en **rond** (`.rounded`). Le rond et la chaleur
   disent « personnel, léger », là où le froid et le neutre disent « machine ».
   Zéro police embarquée : `.rounded` est une face système, Dynamic Type reste
   intact, l'IPA ne gagne pas un octet.

Sombre **permanent** : la coquille pose `preferredColorScheme(.dark)` et
`UIUserInterfaceStyle = Dark` (Info.plist), pour que le clavier et les feuilles
système ne s'ouvrent jamais en clair.

## Teinte — les couleurs

`Teinte.swift`. Sombre permanent, neutres graphite chauds, un seul accent.

- **Fonds** : `fond #0E0D0C` (la page, noir chaud jamais pur — le noir vrai
  traîne au défilement OLED), `surface #1A1815` (cartes d'item, rangées),
  `surfaceHaute #232019` (posé sur une surface : composeur, feuille).
- **Traits et lumière** : sur fond sombre, une ombre ne se voit pas. Le volume
  vient d'un liseré d'un point, clair en haut (`lumiereHaute`), éteint en bas
  (`lumiereBasse`). La lumière vient toujours du haut.
- **Encres** : une par rôle. `encre #F2EEE7` (note, titres — blanc cassé chaud),
  `encreDouce #A39C8E` (légendes, méta, tags au repos), `encreEteinte #6C6459`
  (placeholders, désactivé, glyphes d'état vide).
- **Accent** : `accent #2AD4C6` (interactif + synchro vivante), `accentPresse`
  **dérivé** (`accent` × noir 22 %), jamais saisi à la main. Le fond voilé d'un
  accent n'a pas de jeton : il passe par `Ton.actif.voile`, l'unique porte des
  fonds voilés.
- **États** : `ok #8CC96B` (synchronisé, joignable — vert JAUNE, écarté du
  turquoise pour ne pas confondre « ok » et accent), `alerte #E3B34E` (hors
  ligne, capture en attente, téléversement lent), `panne #E5644E` (échec,
  suppression — le seul rouge).

## Typo — les voix

`Typo.swift`. Échelle d'Apple ; la signature, c'est le **dessin arrondi** pour
tout ce qui s'adresse à Chris.

- **SF Pro Rounded** (`.rounded`) : `titreEcran` 28 gras, `titreSection` 19,
  `corps` 16 (le texte d'une note), `entete`, `mention`, `note`, `legende`.
- **SF Mono** : `brut` — un lien affiché tel quel, un nom de blob, une URL. De
  la donnée brute, qui se lit comme telle.
- **Mesure** : chiffres à chasse fixe (`monospacedDigit`) — compteurs,
  horodatage relatif. Une largeur qui tremble pendant qu'un compteur bouge est
  insupportable.
- **Interligne** : `interligneNote` +3 sur le corps 16 — le régime d'une note
  qu'on relit. Valeur typographique, **hors** de la grille `Trame`.

## Trame — la grille

`Trame.swift`. Grille de **4 pt**. Sous 4 il n'y a rien ; 2, 3, 5, 6 n'existent
pas. `fin 4 · serre 8 · element 12 · bloc 16 · ecran 20 · groupe 24 · section
32 · souffle 48`. Cibles : `cible 44` (plancher tapable), `rangee 64`,
`vignette 56`. **Galbes continus** (`Galbe`) : `controle 10`, `carte 18`,
`feuille 26` — deux arrondis imbriqués gardent au moins 8 pt d'écart.

## Elan — le mouvement

`Elan.swift`. Trois ressorts (`micro` 0,2 s · `normal` 0,35 s sans rebond ·
`surface` 0,45 s), `bounce` à 0 partout. Seuls `transform` et `opacity`
s'animent. Retour haptique fixe (`Retour`) : `contact` (appui), `engage`
(capture aboutie), `bascule` (onglet), `butee` (geste refusé — jamais
facultatif).

> `☠` Une inbox est une **liste qui bouge** : un item capturé apparaît, un item
> supprimé part, une épingle réordonne. Ces mouvements passent par des
> identités **stables** (`Item.id`) et la transition `.item` — jamais par la
> reconstruction d'une liste dont les identifiants changeraient à chaque relevé,
> qui rejouerait toutes les entrées et ferait clignoter l'écran.

## Ambiance — le système parent/enfant

`Ambiance.swift`. Une `Ambiance` descend par l'environnement SwiftUI : un
conteneur la pose, ses descendants en héritent, un enfant peut **restreindre**
ce que le parent accorde, jamais l'élargir. Deux propriétés — le **Palier**
(profondeur : `page → surface → releve`, incrémenté au seul endroit qui se
peint, `Panneau`) et le **Ton**.

> `☠` Saily n'a **pas** de « registre » comme EchoHub (reponse/note/machine) :
> ce monde n'affiche pas un modèle qui raisonne, il affiche des choses
> capturées. Copier ce jeton ici serait un jeton sans emploi, ce que la charte
> interdit. L'ambiance porte donc deux propriétés, pas trois.

## Allures — les composants

`Allures.swift`. Le retour d'appui vient **toujours** de
`configuration.isPressed` dans un `ButtonStyle` (`appui`, `engage`), jamais
d'un geste posé sur un contrôle. Composants communs : `Lisere` (la lumière qui
fait exister une surface), `Fronton` (titre d'écran rond gras dessiné maison),
`Panneau` (carte, seul point de montée de palier), `Sceau` (capsule d'état,
lit le ton hérité), `Etiquette` (tag filtrable), `EtatCalme` (état vide conçu —
dit **quoi**, jamais un tourniquet muet).
