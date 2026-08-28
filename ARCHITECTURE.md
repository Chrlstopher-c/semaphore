# Architecture d'Echo

Le centre de contrôle iOS de Chris : **Vigie** (le client de ccremote) et
**EchoHub Mobile** (le client du modèle local) dans une seule app, un seul
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
| `VigieNoyau` | logique pure de Vigie : contrat ccremote, miroir, veille, markdown. Testable sur Linux. | — |
| `Vigie` | les écrans de Vigie, sa charte, **et le système de veille** (`Alerte/`). | `VigieNoyau` |
| `EchoHubNoyau` | logique pure d'EchoHub Mobile : relais, conversations, modèles, flux SSE, markdown. Testable sur Linux. | — |
| `EchoHub` | les écrans d'EchoHub Mobile et sa charte. | `EchoHubNoyau` |
| `Echo` | **le pupitre** : point d'entrée, délégué d'application, sélecteur de monde. Quatre fichiers. | `Vigie`, `EchoHub`, `VigieNoyau` |

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

Le sélecteur (`SelecteurMonde`) est peint avec la charte de Vigie : le centre
de contrôle **est** le Quart, la Machine y est un monde invité. Chaque monde
garde sa barre en bas — les deux directions artistiques ne se mélangent pas.

## Le bundle

`com.echo.labs`, celui de Vigie. Trois raisons : c'est un App ID déjà enregistré
sur le compte gratuit (quota de dix par semaine) ; `BGTaskSchedulerPermittedIdentifiers`
le porte en préfixe ; et installer Echo **remplace** Vigie sur l'appareil,
ce qui est le but. EchoHub Mobile (`com.echo.echohub`) reste installable à
côté tant qu'on veut comparer.

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
