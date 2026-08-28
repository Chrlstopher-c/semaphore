# Charte d'EchoHub Mobile — « Le fil »

Direction artistique fondatrice, août 2026. Ce document est le contrat de la
forme : si un écran contredit une règle écrite ici, c'est l'écran qui a tort —
ou c'est ce document qu'il faut amender, jamais les deux à la fois.

Cible unique et définitive : **iPhone XS, 375 × 812 pt, OLED, 60 Hz, iOS 18**.
Aucune valeur de cette charte n'est un compromis multi-tailles.

## Le parti pris

EchoHub v2, au bureau, est un **instrument de mesure** : 41 couches, 14,7 Go de
VRAM, 19,6 tok/s. C'est le bon parti pris devant un écran large où l'on arbitre.

Sur 375 pt de large, cet arbitrage n'a pas lieu — la machine est ailleurs, elle
tourne déjà, et ce qu'on tient dans la main n'est pas un tableau de bord : c'est
**un fil**. Un modèle parle, on lit. Le parti pris en découle :

> **L'application est la page, la réponse du modèle est l'encre.**

Trois principes, dans cet ordre.

1. **Un seul sujet par écran : ce que le modèle dit.** Pas de plan de
   chargement, pas de jauge de VRAM, pas de compteur de contexte. Ces
   informations existent et sont justes — elles se lisent devant la machine.
   Ici, elles voleraient la place au texte.

2. **Ce qui n'est pas la réponse recule.** Un modèle de raisonnement écrit
   davantage pour lui que pour Chris : le `<think>` est souvent plus long que la
   réponse. Il ne disparaît pas — c'est ce qu'on vient regarder quand une
   réponse surprend — mais il ne se dispute jamais l'œil avec elle. C'est la
   raison d'être du **registre** (ci-dessous), le système parent/enfant de cette
   charte.

3. **Le calme est un état conçu.** Aucune conversation, aucun modèle chargé,
   relais injoignable : trois écrans dessinés, jamais un écran nu ni un
   tourniquet muet. Un tourniquet dit « attends » ; un état conçu dit *quoi*.

**Archétype** : la page de lecture. Marges larges, une colonne, quasi
monochrome, aucune carte autour du texte du modèle.

**Signature** : le **glissement de registre**. Le passage de la pensée à la
réponse se voit — corps, couleur et famille de police changent ensemble — et
c'est le seul moment où l'app change de voix.

## Le registre — le système parent/enfant

C'est la question centrale d'une app qui affiche un modèle de raisonnement, et
elle se tranche par écrit, sinon elle se tranche par accident.

| Registre | Ce qu'il porte | Comment il se peint |
|---|---|---|
| `reponse` | ce que le modèle dit à Chris | `encre`, corps 17, SF Pro, interligne +4 |
| `note` | son cheminement : `<think>`, commentaires entre deux outils | `encreDouce`, 14, chasse fixe, interligne +2 |
| `machine` | ce qu'un outil a reçu et rendu : JSON, chemins, sorties brutes | `encreEteinte`, 12, chasse fixe, interligne 0 |

Le glissement de registre — la signature de l'app — change donc QUATRE choses
d'un coup : l'encre, le corps, la famille et la respiration. Jamais l'une sans
les autres : c'est `selonRegistre()` qui les lie.

**La règle qui gouverne tout le système** : un enfant peut **descendre** de
registre, **jamais remonter**. Un bloc de raisonnement pose `note` ; rien à
l'intérieur ne peut revenir en `reponse`, même par erreur d'appelant — c'est
`Registre.restreint(par:)` qui l'impose, en prenant le maximum de rusticité, pas
la politesse de la vue.

Le corollaire tenu partout : **la seule chose qui s'écrit en `encre` pleine, à
17 pt, est ce que le modèle répond.** Un titre d'écran plafonne à 26. Un bouton
est en `mention`. Rien ne monte au-dessus de la réponse.

## Palette

Neutres légèrement froids — la famille est celle d'EchoHub v2 au bureau, à la
lettre près (`--accent` `#8A7AFF`, `--text` `#ECECF1`) : c'est le même produit,
et deux pervenches différentes se remarqueraient immédiatement en passant d'un
écran à l'autre.

| Jeton | Valeur | Emploi |
|---|---|---|
| `fond` | `#0B0B0E` | la page. Plus sombre que le `#0E0E11` du bureau : OLED |
| `surface` | `#16161A` | bulle de Chris, cartes, rangées |
| `surfaceHaute` | `#1D1D23` | posé sur une surface : composeur, bloc replié |
| `trait` | blanc 10 % | séparateurs |
| `lumiereHaute` / `lumiereBasse` | blanc 14 % / 5 % | le liseré directionnel qui remplace l'ombre |
| `encre` | `#ECECF1` | la réponse du modèle, les titres |
| `encreDouce` | `#9494A6` | le registre `note`, les métadonnées |
| `encreEteinte` | `#5C5C6B` | le registre `machine`, le désactivé, le texte fantôme |
| `accent` | `#8A7AFF` | interactif, et « ça génère en ce moment » |
| `accentPresse` | accent × noir 25 % | accent enfoncé — dérivé, jamais saisi |
| `ok` | `#4CC38A` | modèle prêt, relais joignable, outil abouti |
| `alerte` | `#E5B454` | dégradé, récupérable, interrompu |
| `panne` | `#E5644E` | échec réel, geste destructif — le seul rouge |

**Pourquoi le noir n'est pas pur.** `#0B0B0E` et non `#000` : le noir vrai
laisse une traînée au défilement sur cet OLED, et un fil de conversation défile
en permanence. Quatre pour cent de gris la suppriment sans se voir.

**Profondeur sans ombre.** Sur fond sombre une ombre est invisible. Une surface
s'élève par sa couleur (`surface` → `surfaceHaute`) et par un liseré d'un point,
clair en haut, éteint en bas. Aucune vue ne dessine d'ombre.

**Toute couleur est un mot du vocabulaire** — règle héritée du bureau et tenue
ici : si une couleur n'énonce pas un état, une ressource ou une action possible,
elle n'existe pas.

**Une seule porte pour les fonds voilés.** Le fond d'une capsule d'état
s'obtient par `Ton.voile` (la couleur du ton à 14 %) et par rien d'autre — il
n'existe pas de jeton `accentVoile` à côté : deux chemins vers la même valeur
finissent toujours par diverger.

## Typographie

Trois voix, et c'est le CONTRASTE entre elles qui est la signature — pas la
famille.

- **SF Pro** pour tout ce qui se lit : `titreEcran` 26 sb · `titreSection` 18 sb
  · `corps` 17 (la réponse) · `mention` 15 · `note` 13 · `legende` 12.
- **SF Mono** pour tout ce qui vient d'une machine : `pensee` 14 (le registre
  `note`) et `brut` 12 (le registre `machine`). Un raisonnement en chasse fixe
  se lit *comme du travail*, pas comme un propos — l'information est dans la
  forme avant d'être dans le mot.
- **Chiffres à chasse fixe** pour toute mesure : `mesure` 13 · `mesureFine` 12.
  Sans cela la largeur danse à chaque token généré.

**Écart déclaré à la doctrine iOS.** Le bureau utilise IBM Plex Sans/Mono,
auto-hébergée. L'embarquer ici coûterait cinq fichiers de police dans l'IPA,
ferait perdre Dynamic Type, et le skill iOS écarte les polices tierces pour du
corps de texte. SF Pro + SF Mono donnent le MÊME contraste de nature — une
grotesque d'ingénierie et sa compagne à chasse fixe — sans un octet de police.
La cohérence avec le bureau est portée par la palette et par le registre, pas
par le fichier de police.

`rubrique()` : capitales espacées 1,5, en `encreDouce` — une section s'annonce à
voix basse.

**L'interligne est un jeton, pas un défaut subi.** L'interligne d'iOS est réglé
pour des libellés d'interface ; l'archétype de cette app est la page de lecture
et une réponse fait couramment trois écrans. La réponse et la bulle de Chris
prennent +4 (corps 17 → ligne ≈ 26, le régime d'un livre), le registre `note`
+2 (long lui aussi, mais il se scanne plus qu'il ne se lit), le registre
`machine` rien (un dump se lit compact, comme dans un terminal). Ces valeurs
sont typographiques, **hors de la grille `Trame`** : « sous 4 pt il n'y a
rien » gouverne la mise en page, pas la respiration interne d'un pavé de texte.

**Le titre d'écran est dessiné maison** (`Fronton`, 26 sb). La barre système en
mode `.large` compose à 34 pt gras — au-dessus de la réponse du modèle, ce que
le plafond de 26 existe précisément pour interdire. Les écrans à grand titre
masquent donc la barre de navigation et posent le fronton en tête de leur
défilement ; le fil, lui, garde la barre en mode `.inline` (17 pt), sous le
plafond.

## Trame

Grille de 4 pt, sans exception : `fin` 4 · `serre` 8 · `element` 12 · `bloc` 16
· `ecran` 20 · `groupe` 24 · `section` 32 · `souffle` 48. **Sous 4 pt il n'y a
rien.**

Galbes continus : `controle` 10 · `carte` 16 · `feuille` 24. Deux arrondis
imbriqués gardent 8 pt d'écart. Cible tactile 44 pt, rangée de liste 56 pt,
composeur 52 pt au repos.

Budget vertical, à poser avant tout écran : 812 − 44 (encoche) − 34 (indicateur)
= 734 pt ; moins 49 pt de barre d'onglets et 52 pt de composeur, il reste
**633 pt** au fil. Largeur utile 335 pt.

**L'espace avant le trait** — règle héritée du bureau : la séparation se fait
d'abord par l'espacement, ensuite par un changement de surface, en dernier
recours par une bordure.

## Mouvement

| Ressort | Valeur | Emploi |
|---|---|---|
| `micro` | `snappy(0.2)` | appui, bascule, sélection |
| `normal` | `spring(0.35, bounce: 0)` | apparitions, changements d'état |
| `surface` | `smooth(0.45)` | grandes surfaces, dépliage d'un bloc |
| `suivi` | `interactiveSpring(0.25)` | ce qui réagit pendant qu'un doigt guide |

`bounce` reste à 0 : un rebond sur un texte en train de s'écrire fait jouet.
**Seuls `transform` et `opacity` s'animent** — un flou ou une mise en page
animée rament visiblement à 60 Hz sur A12.

**Entrer et sortir — une seule paire, `AnyTransition.scene`.** On entre en se
levant de 6 pt dans un fondu, on sort en s'éteignant sur place. L'asymétrie est
le principe : un élément qui part ne doit pas attirer l'œil sur son départ.

**Ce qui ne bouge JAMAIS** : le texte déjà écrit par le modèle, et la position
de défilement quand Chris a remonté le fil lui-même. Un token qui arrive ne doit
jamais déplacer une ligne qu'il est en train de lire. C'est la règle la plus
facile à casser d'une app de chat, et la plus insupportable à l'usage.

**La seule animation liée à une donnée réelle** : le curseur de génération, qui
bat tant que des fragments arrivent et s'éteint au premier `fin`. Il ne simule
rien — hérité du refus explicite du bureau : *la progression affichée est la
progression réelle*.

## Haptique

`Retour` : `contact` (appui, sélection) · `engage` (message envoyé, réponse
terminée) · `bascule` (onglet) · `butee` (envoi refusé, relais injoignable).
Un geste = un retour, jamais deux, jamais de retour décoratif.

**La butée n'est pas facultative** : envoyer un message sans modèle chargé, ou
sans relais, doit se sentir. Sans retour, la main croit que l'app n'a pas senti
le doigt.

## Le piège gestuel (règle absolue)

Le retour d'appui vient **toujours** de `configuration.isPressed` dans un
`ButtonStyle`. Jamais d'`onLongPressGesture` ni de geste custom posé sur un
`Button` ou un `NavigationLink` : le geste gagne la course contre le contrôle,
le toucher est avalé, et rien ne le signale. Et rien ne se pose sur le bord
gauche — le retour arrière par glissement est sacré.

## Navigation

Trois onglets — **Fil · Conversations · Machine** — et rien d'autre.

- **Fil** : la conversation en cours. C'est l'écran où l'on vit.
- **Conversations** : l'historique, qui vit sur le PC. Toucher une ligne bascule
  le fil et revient au premier onglet.
- **Machine** : quel modèle est chargé, ce qu'il y a sur le disque du PC, et la
  carte d'entrée vers les réglages du relais. Pas un quatrième onglet pour les
  réglages : on y va deux fois par an.

## Les états qu'on dessine

Le principe 3 (« le calme est un état conçu ») n'est pas une intention, c'est
une liste. Chaque état ci-dessous est un écran ou un élément dessiné, avec sa
raison — jamais un écran nu, jamais un tourniquet muet.

| État | Ce qui se dessine, et pourquoi |
|---|---|
| Aucune conversation | `EtatCalme` + « Nouvelle conversation » : le premier geste est offert, pas cherché |
| Conversation neuve, fil vierge | `EtatCalme` calme (« Écris — c'est le même historique ») : un fil nu avec un composeur ressemble à un écran cassé, alors que tout est prêt |
| Fil, liste ou registre qui charge | `ChargementVue` : trois rangées fantômes qui respirent — la FORME de ce qui arrive, pas un vide |
| Relais ou historique injoignable | `EtatCalme` + « Réessayer » : la cause d'abord, la relance à un doigt |
| Machine pas prête (fil ouvert) | le **bandeau machine**, entre fil et composeur : le dire AVANT que Chris tape vaut mieux qu'un échec après l'envoi. Il ne bloque pas — c'est le serveur qui tranche |
| Machine silencieuse | ton neutre et libellé qui ne tranche pas (« Sans nouvelles ») : un statut absent couvre « jamais relevé » ET « relevé en échec », et un « injoignable » affiché pendant le premier relevé serait un mensonge d'une seconde à chaque lancement |
| Génération qui échoue | `EchecDeTour` sous le fil : une génération ratée n'efface jamais la conversation déjà lue |
| Génération interrompue | sceau `alerte` au pied de la réponse ; ce qui était écrit est gardé, jamais jeté |
| **Tour muet** | toute la réponse est restée en raisonnement : une ligne l'énonce (« Rien d'adressé… ») et le dernier bloc s'ouvre de lui-même — c'est la seule chose à lire, la laisser repliée ferait croire à un bug |
| Action de liste ratée | `EchecAction` sous le fronton : c'est l'action qui a raté, pas l'historique — la liste reste |
| Registre du PC en échec | la section garde sa place, avec sa relance : le statut au-dessus reste vrai, pas d'écran d'erreur à part |

**Le poids d'un bloc replié se lit sans le déplier** : le compte de mots, en
`mesureFine` éteinte, répond à « ça vaut le coup d'ouvrir ? ». Pendant la
génération il grimpe avec les fragments — une mesure réelle, pas une animation.

**Le seul rouge de l'app a son geste** : supprimer une conversation, par appui
long sur sa rangée, toujours derrière une confirmation qui dit la portée réelle
(« elle disparaîtra aussi du navigateur »). La conversation ouverte dans le fil
ne se supprime pas d'ici : le salon ne sait pas « fermer », et un fil pointant
vers une conversation détruite serait un écran menteur.

## Ce qui reste à confirmer à l'œil

Personne, dans l'équipe qui a écrit cette charte, n'a vu l'app tourner : ni
simulateur, ni appareil. Sont donc **calculés, pas constatés** : la lisibilité
de SF Mono à 14 pt sur 335 pt de large pour un raisonnement long, le contraste
réel de `encreDouce` sur `#0B0B0E`, la tenue du fil quand une réponse dépasse
trois écrans, le rythme du curseur de génération, la justesse des interlignes
(+4 / +2 / 0) sur du texte réel, et la tenue du fronton à 26 pt une fois la
barre système masquée. Ces points sont à juger sur l'iPhone, et à amender ici
si l'œil contredit le calcul.

---

# Amendement du 28/08/2026 — l'atelier

Cette charte écartait explicitement la gestion de la machine : « Pas de plan de
chargement, pas de jauge de VRAM, pas de compteur de contexte. Ces informations
existent et sont justes — elles se lisent devant la machine. » L'argument a
servi à écarter tout le bloc modèles d'`ARCHITECTURE.md`.

**Chris a renversé la décision.** Il a installé l'app, il s'en sert, et il veut
y chercher un modèle sur le Hub, le télécharger, le charger, le décharger, le
supprimer — sans marcher jusqu'au PC. La charte prescrit elle-même la marche à
suivre : « c'est l'écran qui a tort, ou c'est ce document qu'il faut amender,
jamais les deux à la fois. » C'est ce document qui est amendé.

## Ce qui change, et ce qui ne change pas

Le raisonnement d'origine reste juste — mais il portait sur **le fil**, et il a
été écrit comme s'il portait sur l'app entière. C'est là qu'était l'erreur.

> **Le fil est la page. L'atelier est l'établi.**
> Deux lieux, une seule encre.

Le principe 1 devient donc : **un seul sujet par écran ; et dans le fil, ce
sujet est toujours ce que le modèle dit.** Rien de la machine n'entre dans le
fil. Le bandeau machine reste le seul emprunt, et il est là pour une raison qui
n'a pas changé : dire avant l'envoi ce qui échouerait après.

Les principes 2 et 3 sont inchangés et gouvernent l'atelier comme le fil.

## Les quatre règles de l'atelier

1. **On y entre, on n'y arrive pas.** L'atelier est une enfilade d'écrans
   poussés depuis l'onglet Machine, un sujet par écran : le registre · un
   modèle · le plan · les transferts · le disque · le journal · les découvertes.
   Jamais un tableau de bord — six panneaux empilés sur 375 pt ne sont pas de la
   densité, c'est de l'illisible.

2. **La densité est permise ; la montée de registre ne l'est pas.** Un écran
   d'atelier a le droit d'aligner dix mesures. Elles se peignent en `note` et en
   `machine` — `mesure` et `mesureFine` pour les chiffres, `encreDouce` et
   `encreEteinte` pour l'encre. **Aucune mesure ne monte en `reponse`.** Le
   corollaire fondateur tient sans exception : *la seule chose qui s'écrit en
   encre pleine à 17 pt est ce que le modèle répond.* Un plan de chargement est
   du travail, pas un propos — et la charte a déjà écrit que ce qui vient d'une
   machine se lit en chasse fixe.

3. **Aucune mesure inventée.** Une progression affichée est une progression
   reçue. Sans total annoncé, on écrit les octets, jamais un pourcentage. Une
   métadonnée absente fait disparaître sa ligne au lieu d'afficher un `0` ou un
   tiret qui se liraient comme une mesure. C'est la règle d'EchoHub v2 —
   « la progression affichée est la progression réelle » — et l'atelier ne la
   relâche pas parce que l'écran est petit.

4. **Le rouge garde sa portée.** L'atelier ajoute deux gestes destructifs :
   effacer un dossier du disque du PC, et vider l'historique d'une conversation.
   Ils reçoivent le traitement de la suppression d'une conversation — `panne`,
   et une confirmation qui dit la portée **réelle** (« les octets partent du
   disque », « les variantes partent aussi »). *Oublier* un modèle du registre
   n'est PAS ce geste : les fichiers restent, la confirmation doit le dire.

## Les états qu'on dessine — les six de l'atelier

| État | Ce qui se dessine, et pourquoi |
|---|---|
| Aucun modèle sur le disque | `EtatCalme` + « Chercher sur le Hub » : le premier geste utile est offert, pas cherché |
| Recherche sans résultat | `EtatCalme` qui redit la requête : « rien » et « rien pour *ça* » ne se corrigent pas pareil |
| Transfert sans total annoncé | les octets reçus, sans barre : une barre à progression inconnue ment sur ce qu'elle sait |
| Plan calculé, VRAM juste | le plan tel quel, plus ses avertissements : c'est le serveur qui parle, on ne le réécrit pas |
| Chargement échoué | la cause **qualifiée** du serveur et « Dégrader » à un doigt — jamais « réessayer », qui relancerait le plan qui vient d'échouer |
| Modèle non planifiable | le refus **nommé** (ce qui manque à l'en-tête) et sa remédiation : un plan bâti sur du vide vaut moins qu'un refus qui explique |

## Ce qui reste interdit, et qui l'était déjà

- Aucune couleur, taille, espacement, galbe ni durée littéraux : tout par les
  jetons. Un écran dense est exactement celui où la tentation revient.
- Aucune animation hors `Elan`, et toujours `transform` et `opacity` seuls. Une
  barre de progression anime sa **largeur** : c'est une mise en page animée, et
  elle rame sur A12. Elle se dessine donc par un masque à l'échelle.
- Aucun tourniquet muet. `ChargementVue` et `EtatCalme` couvrent les trois états
  d'écran réseau ici comme ailleurs.
- Rien sur le bord gauche : le retour arrière par glissement reste sacré, et
  l'atelier est justement le lieu où l'on empile des écrans poussés.
