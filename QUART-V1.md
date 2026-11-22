# Monde Quart v1 — cadrage (22/11/2026)

## Pourquoi, pour qui
Chris pilote depuis son iPhone toutes ses sessions Claude Code du parc (tour, portable, Pi), où qu'il soit, par le
réseau Lanterne (aiguilleur sur le Pi, voir `lanterne/recherche/RESEAU.md`). Usage personnel.

## Référence (étalon)
**La partie Claude Code de l'appli Claude sur iPhone**, refaite à l'identique pour notre usage : écrans, navigation,
détails, réglages, gestes, états vides et d'erreur. C'est le même ADN que Lanterne (qui refait Claude Desktop). Pas de
logo ni de marque Anthropic dans l'appli (usage personnel, notre propre nom et icône).
Par-dessus, les exigences iOS de Chris (mémoire « Design iOS : ce que Chris attend ») seulement là où l'étalon ne dit
rien : fluidité avant tout, retour par glissement partout, aucune trace de l'ancienne charte de Vigie.
Méthode de comparaison : captures de chaque écran de l'étalon (fournies par Chris) posées côte à côte avec les nôtres,
écran par écran, avant de déclarer un écran fait.

## Décisions (Chris, 22/11)
- Refaire la partie Claude Code de l'appli Claude iOS, réglages compris, « tout parfait ».
- Notifications : on garde le système actuel de Sémaphore (pas de compte développeur payant).
- v1 sans duo, modules ni artefacts ; on les ajoute une fois la base solide.

## Voie
- SwiftUI compilé sur la tour (xtool, chaîne existante de Sémaphore), installation sur l'iPhone depuis le portable.
- Le monde Vigie actuel (52 fichiers, API Quart v2 de septembre, jamais vu à l'écran) est remplacé ; on garde sa
  plomberie éprouvée (veille, notifications natives, trousseau, rattrapage).
- Données : API clients du nœud Lanterne (sessions, fil, envoyer, interrompre, accords, créer), d'abord par le VPN sur
  un nœud de banc, puis par l'aiguilleur et le tunnel quand l'étape 5 de RESEAU.md est livrée.
- Design et rendu par un agent Opus (il garde tout le visuel), code d'accès et logique par des agents Haiku qu'il
  orchestre.

## Plan (v1)
1. **Inventaire de l'étalon** — chaque écran de la partie Claude Code de l'appli Claude iOS : liste des sessions,
   session (fil, outils dépliables, sous-agents, diff), saisie (pièces jointes, modèle, mode), demandes de permission,
   nouvelle session (choix de l'environnement/machine, dossier), réglages, états vides/erreurs. Fait quand : un
   document liste chaque écran avec sa capture et ses éléments.
2. **Socle** — client réseau du nœud Lanterne (authentification par clé d'appareil, flux d'événements), modèle des
   sessions et du fil, tests. Fait quand : les tests de décodage passent sur des événements réels anonymisés.
3. **Liste des sessions et fil** — à l'identique de l'étalon, en direct. Fait quand : capture côte à côte validée.
4. **Agir** — envoyer, interrompre, accords de permission, créer une session sur une machine du parc.
5. **Réglages et finitions** — réglages de l'étalon qui ont un sens chez nous, états vides, erreurs, hors ligne,
   gestes, notifications branchées sur la plomberie existante.

## Hors v1
Duo, modules, artefacts, synchronisation des favoris sur demande (étape 6 de RESEAU.md).
