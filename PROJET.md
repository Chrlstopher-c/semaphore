# Monde EchoHub de Sémaphore — l'EchoHub de la tour, entier, dans la poche

## Pourquoi et pour qui
Chris pilote son agent local et ses modèles depuis la tour ou son portable. Hors de chez lui ou loin du PC, le monde
EchoHub de l'iPhone (figé au 31/08/2026) ne couvre qu'environ un tiers de l'app : pas d'agent, pas de projets, pas de
texte en direct, pas de plans éprouvés. Verdict de Chris (27/11/2026) : « absolument en retard, franchement insuffisant ».

## Ce que ça apporte
Tout ce que l'EchoHub web permet, depuis le téléphone, en 4G comme en Wi-Fi. Plus ce que le web ne peut pas faire :
voir si la tour est allumée, l'allumer, démarrer EchoHub.

## Référence visée
L'interface web d'EchoHub v2 en largeur étroite, écran par écran, adaptée au téléphone (choix de Chris, 27/11).
Checklist exhaustive : `docs/echohub-parite.md`. Finition : skill `ios-design`, charte du monde EchoHub.

## Voie retenue
- Accès hors réseau local : le relais existant du Pi (`echohub-relais`, tunnel Cloudflare, jeton Bearer) qui transmet
  déjà `/api/*` en streaming. On lui ajoute : état de la tour, réveil (paquet magique, code repris de `reflet-relais`),
  démarrage d'EchoHub (ssh Pi → tour, commande forcée), et le relais des aperçus d'app de l'agent.
- App : SwiftUI, modules `EchoHub` (vues) et `EchoHubNoyau` (logique testable sous Linux) réécrits/étendus ; contrats
  calqués sur `frontend/src/chat/api/contrats.ts`.

## Réussite
1. Chaque ligne de `docs/echohub-parite.md` cochée, vérifiée sur l'iPhone.
2. En 4G, tour éteinte : allumer → EchoHub prêt → modèle chargé → session projet → l'agent travaille, suivi en direct.
3. Téléphone verrouillé pendant une génération puis rouvert : la réponse en cours reprend, rien n'est perdu.

## Raté si
Un écran ou une action du web manque ; le texte n'arrive qu'à la fin ; l'app ne sert à rien hors du Wi-Fi.

## Hors périmètre
Notifications push de fin de génération (ntfy existe, à brancher plus tard si Chris le veut). Modification de l'EchoHub
web lui-même, sauf une route manquante pour le mobile.

## Décisions
- 27/11/2026 — Parité écran par écran avec le web adapté au mobile (Chris) — c'est l'app qu'il connaît.
- 27/11/2026 — Hors LAN par le relais du Pi existant, pas un nouveau tunnel — déjà en service, streaming éprouvé.
- 28/11/2026 — Couleurs et thèmes du web dans le monde EchoHub, exception au socle commun des mondes — c'est le même produit.
- 27/11/2026 — Réveil par le Pi (toujours allumé) — la tour éteinte ne peut rien faire elle-même.

## Plan
### E1 — La tour depuis le téléphone (socle hors LAN)
- [x] E1.S1 — Relais : `GET /tour` (tour joignable, EchoHub répond, modèle chargé) — VERIFY: `bun test` + curl par le tunnel avec jeton
- [x] E1.S2 — Relais : `POST /tour/reveiller` (paquet magique) et `POST /tour/echohub/demarrer` (ssh à commande forcée, idempotent) — VERIFY: tests + tour éteinte → allumée par la route
- [x] E1.S3 — Relais : aperçus d'app de l'agent (`/apercu/<port>/*`, WebSocket compris) — VERIFY: app d'essai ouverte par le tunnel
- [ ] E1.S4 — App : écran d'état de la tour (hors ligne / allumage / EchoHub prêt) avec Allumer et Démarrer — VERIFY: tests Noyau + essai iPhone en 4G
### E2 — Coque et sessions
- [ ] E2.S1 — Coque 3 onglets, pastille moteur, Éjecter, thème, couleurs du web — VERIFY: capture iPhone (sombre + clair) — codé 28/11, à vérifier sur l'iPhone
- [ ] E2.S2 — Liste des conversations complète (groupes, filtre, menu, archivées) — VERIFY: tests Noyau + parcours iPhone — codé 28/11, à vérifier sur l'iPhone
- [ ] E2.S3 — Flux en direct (8 événements) + reprise `…/flux` + relance après silence — VERIFY: tests Noyau sur trames réelles enregistrées + verrouillage iPhone — codé 28/11 (raccrochage, veille 20 s/120 s, changer de conversation ne coupe plus le PC), à vérifier sur l'iPhone
- [ ] E2.S4 — Composeur (pièces, photo, arrêter, consigne glissée, file) + commandes `/compact` `/clear` — VERIFY: tests + parcours — codé 28/11, à vérifier sur l'iPhone
- [ ] E2.S5 — Actions de message et variantes, Markdown et code — VERIFY: tests + parcours — codé 28/11, à vérifier sur l'iPhone
### E3 — Agent et projet
- [ ] E3.S1 — Activité en direct : réflexion, lignes d'action + diff, commande shell (fond / arrêter) — VERIFY: trames réelles d'une session agent rejouées — codé 28/11, à vérifier sur l'iPhone
- [ ] E3.S2 — Feuille Projet : choisir, créer, retirer, instantanés, restaurer — VERIFY: tests contre EchoHub réel — codé 28/11 (+ hybride, aperçu par port d'atelier via relais 7bff6cd), à vérifier sur l'iPhone
- [ ] E3.S3 — Fichiers du projet, modifications, diff — VERIFY: parcours iPhone — codé 28/11, à vérifier sur l'iPhone
- [ ] E3.S4 — Espace de travail : plan de l'agent, aperçu (WebView par le relais), terminal, contexte — VERIFY: parcours iPhone en 4G — codé 28/11, à vérifier sur l'iPhone
- [ ] E3.S5 — Artefacts (versions, aperçu/code) et interrupteur hybride — VERIFY: parcours — codé 28/11 (cartes dans le fil, versions, aperçu HTML/SVG/Markdown, fichiers présentés ; hybride dans la feuille Projet), à vérifier sur l'iPhone
### E4 — Réglages de conversation
- [ ] E4.S1 — Réglages (tous les curseurs, arrêt, prompt système) — VERIFY: tests PATCH — codé 28/11 (+ min-p, présence, séquences d'arrêt), à vérifier sur l'iPhone
- [ ] E4.S2 — Outils par conversation — VERIFY: tests — codé 28/11 (+ bascule par groupe), à vérifier sur l'iPhone
- [ ] E4.S3 — Profils (sélection et gestion) — VERIFY: tests + parcours — codé 28/11 (choix, profil des sessions neuves, création, modification, suppression), à vérifier sur l'iPhone
- [ ] E4.S4 — Retours (pouces, raisons, correction) — VERIFY: tests — codé 28/11 (meilleure/pire sur variantes, verdict de Claude affiché à part), à vérifier sur l'iPhone
### E5 — Modèles et système
- [ ] E5.S1 — Plans éprouvés + plan de chargement complet (contexte, KV, plus conservateur, journal, bandeau de refus de cible) — VERIFY: charger CyberTiel depuis l'iPhone
- [ ] E5.S2 — Découvrir (Hugging Face) + feuille Téléchargement — VERIFY: tests + parcours
- [ ] E5.S3 — Sur le disque + Transferts + Strata — VERIFY: tests + parcours
- [ ] E5.S4 — Système : profil machine, services, moteurs (installation vLLM en direct), journal — VERIFY: parcours
