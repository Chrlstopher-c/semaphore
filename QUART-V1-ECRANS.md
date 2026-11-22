# Monde Quart v1 — écrans et composants

Référence : la partie Code de l'appli Claude iOS, relevée écran par écran sur 24 captures (mode sombre, iPhone XS).
Les captures et l'inventaire détaillé restent hors dépôt (`etalon/`, ignoré). Ce document dit ce qui est à faire et ce
qui est fait, sans contenu personnel. Mesures en points ; couleurs mesurées au pixel, posées dans
`Sources/Vigie/Charte/Charte.swift` (`Q`).

## Jetons
Fonds : liste #0B0B0B, fil et feuilles #151515, en-tête du fil et bande du composeur #232324, tiroir #111111, carte
#20201F (rayon 12 continu, marge 16), bulle #1F1F1E (rayon 22), rond #313131 (Ø 36). Encres : #F9F9F7, titres
#F0EFEC, secondaire #C3C2B7, tertiaire #97958D, méta #898781. Accent #2A78D6 (anneau, point non lu, jauges sur piste
#032042), coche #5598E7, liens #6DA7EC. Avertissement #FAB219 sur #412400. Diff : vert #32D74B sur #212E22, rouge
#FF2C56. Police : SF Pro (l'étalon a une police propriétaire), serif pour le mot-symbole.

## Écrans

| # | Écran | Fichier | État |
|---|---|---|---|
| E1 | Liste « Code » : en-tête trois traits / titre / filtre, appareils, sessions au pas de 75 pt (état, titre, méta, appareil, point non lu), loupe + capsule « Nouvelle session » | `Ecrans/Liste/` | fait, comparé |
| E2 | Tiroir 313 pt, contenu poussé et assombri, glissement depuis le bord | `Ecrans/Racine/` | fait, comparé |
| E3 | Session : en-tête deux lignes + anneau d'usage + « ··· », fil (réponses pleine largeur, bulles à droite, lignes d'actions résumées, texte en flux), « N tâches en cours » | `Ecrans/Session/` | fait, comparé |
| E3b | Composeur repos (capsule) / saisie (carte, pilule modèle, envoyer / arrêter) | `Session/Composeur.swift` | fait, comparé |
| E4 | Menu « ··· » : tâches de fond ; partager, renommer, épingler, archiver ; compacter, fermer / reprendre | `Session/SessionEcran.swift` | fait |
| E5 | Appui long : copier (message), épingler / renommer / non lue / archiver (ligne de liste) | `Liste/`, `Session/BlocVue.swift` | fait (menu système, pas d'aperçu flouté sur mesure) |
| E6 | Feuille « Choisir le modèle » → « Effort » (Recommandé, avertissement Max, Ultracode) → « Autres modèles » | `Feuilles/ModeleFeuille.swift` | fait, comparé |
| E7 | Feuille d'une suite d'actions (frise), détail commande / sortie, détail diff, sous-agent | `Feuilles/ActionsFeuille.swift`, `DetailOutilVue.swift` | fait, comparé |
| E8 | Feuille « Usage » : contexte dépliable, session 5 h, limites hebdomadaires | `Feuilles/UsageFeuille.swift` | fait, comparé |
| E9 | Feuille « Tâches de fond » : filtre, cartes, arrêt, détail | `Feuilles/TachesFeuille.swift` | fait, comparé |
| E10 | Réglages : nœud, Compte (usage, notifications), Appli (Claude Code : défauts), Se déconnecter | `Reglages/` | fait, comparé |
| E11 | Demande de permission / question à choix (pas dans les captures : grammaire de l'étalon) | `Session/DemandeVue.swift` | fait, non comparable |
| E12 | Nouvelle session : machine, dossier, modèle, première demande | `Feuilles/NouvelleSessionFeuille.swift` | fait, non comparable (pas de capture) |
| E13 | Appairage : adresse du nœud + code à usage unique (repli mot de passe) | `Connexion/` | fait, non comparable |
| E14 | États : liste vide, recherche vide, nœud injoignable, connexion, fil en chargement (gabarit), fil vide, session introuvable, lecture seule / fermée | partout | fait |

## Écarts assumés
- Libellés en français (l'étalon est en anglais) ; SF Pro au lieu de la police propriétaire.
- Absent car sans objet chez nous : projets, artefacts, planifiées, cadeau, comptes multiples, facturation, crédits,
  liens partagés, avis, connecteurs, apparence (Quart reste sombre, comme le pupitre), micro « maintenir pour parler »
  (la dictée du clavier iOS le remplace), pièces jointes du « + » (le « + » porte le mode de permission, la
  compaction, l'usage, les tâches).
- « Appareils » montre les machines du parc (réveiller, éteindre) à la place de « + Add device » ; « Machines » du
  tiroir ouvre l'accès à distance gardé de Vigie (fichiers, terminal).
- L'appui long sur un message ouvre le menu contextuel système, pas l'aperçu flouté sur mesure de l'étalon.

## Écarts relevés à la comparaison, encore ouverts
- E1 : une seule icône à droite de l'en-tête (filtre) ; l'horloge des tâches planifiées n'existe pas chez nous.
- E2 : pas d'icônes cadeau / recherche à côté du mot-symbole (la recherche est sur la liste).
- E3 : sous-titre de l'en-tête = « machine · projet » (l'étalon dit « Remote Control ») ; l'anneau montre l'usage
  hebdomadaire du compte, ou le remplissage du contexte si la machine n'a pas relevé d'usage.
- E7 : blocs de commande sans coloration syntaxique (l'étalon colore à la One Dark).
- E8 : pas de phrase de rythme (« On track… »), ni « Limit resets », ni crédits.
- E3/E5 : la lecture à voix haute utilise la synthèse d'iOS (fr-FR), pas la voix de l'appli.

## Vérification
Pas de simulateur ni d'aperçu sur la chaîne Linux : comparaison structurelle de chaque écran à l'inventaire (ordre,
mesures, couleurs, textes), `swift test` du noyau, `xtool dev build`. Le côte à côte en image se fait sur l'iPhone.
