# EchoHub — checklist de parité web → iPhone (relevé du 27/11/2026)

Référence : l'interface web d'EchoHub v2 (`echohub-v2/frontend/src`) en mode étroit (< 1024 px : colonnes en tiroirs,
onglets en barre basse). Chaque ligne = un écran à reproduire avec TOUTES ses actions. Cocher quand vérifié sur l'iPhone.

## Coque
- [ ] Onglets Sessions / Modèles / Système ; pastille d'état moteur (injoignable, aucun modèle, chargement, prêt, échec) + nom + tok/s ; Éjecter (`POST /inference/decharger`) ; thème clair/sombre ; bandeau de refus de cible.
- [ ] NOUVEAU mobile : état de la tour (hors ligne / allumée / EchoHub démarré), Allumer, Démarrer EchoHub.

## Sessions (chat)
- [ ] Liste : nouvelle session, filtre, groupes Projets puis Aujourd'hui/Hier/Semaine/Plus ancien, menu (ouvrir, renommer, archiver/désarchiver, copier le titre, supprimer), section Archivées ; resynchro 15 s + retour au premier plan.
- [ ] En-tête : conversations, fichiers du projet, outils, réglages, espace de travail, puce projet, interrupteur « Haiku écrit le code » (`…/hybride`), sélecteur de profil.
- [ ] Fil : défilement auto + « reprendre le fil », heure/modèle/interrompu/durée, erreur sous l'en-tête, fil vide.
- [ ] Flux : `debut`, `fragment` (texte EN DIRECT), `activite`, `compaction`, `fin`, `erreur`, `commande`, `commande_shell` ; reprise `GET …/flux` (204 = rien), relance après silence 20 s (120 s avant 1er octet).
- [ ] Actions message : copier, modifier (variante), rejouer, variantes n/N (`…/branche`), masquées pendant génération.
- [ ] Composeur : envoyer, arrêter, glisser une consigne (`…/consignes`), file d'attente, pièces jointes multiples + photo (`/conversations/{id}/fichiers`), désactivé sans modèle.
- [ ] Commandes slash : palette `/` (`GET /chat/commandes`), `/compact [instr]` (carte d'étapes, chrono), `/clear` (séparateur + Annuler : `…/effacements`).
- [ ] Activité en direct : bloc Réflexion repliable, lignes d'action dépliables (diff/détail), commande shell en direct (Passer en fond / Arrêter : `/commandes/{id}/fond|arreter`), vitesse/tokens.
- [ ] Markdown + blocs de code copiables.
- [ ] Réglages (feuille) : température, top-p, min-p, répétition, présence, top-k, plafond, graine, séquences d'arrêt, prompt système ; enregistrement différé + erreurs.
- [ ] Outils (feuille) : bascules par outil et par groupe, avertissements de paires.
- [ ] Profils : sélecteur, gestion (créer, éditer nom/comportement/outils/réglages, supprimer double confirmation, utiliser ici).
- [ ] Projet (feuille) : choisir, créer, retirer ; instantanés + Restaurer (double confirmation) ; aperçu (ports, actualiser, ouvrir).
- [ ] Fichiers du projet : arbre, lecture d'un fichier, Modifications + diff ; rafraîchi 4 s ; états vides/tronqués/binaires.
- [ ] Espace de travail : Agent (plan de tâches ○◐✓!–), Aperçu (WebView de l'app, ports, recharger, ouvrir), Terminal (commandes relues), Moteur (plan de chargement), Fenêtre de contexte (`…/contexte`).
- [ ] Artefacts : carte → panneau, versions, Aperçu/Code, agrandir ; types page/document/code/image/diagramme/texte (`GET /fichiers/{id}`).
- [ ] Retours : bonne/mauvaise (ou meilleure/pire variante), raisons, corriger la réponse (`/retours`).

## Modèles
- [ ] Plans éprouvés : charger/décharger d'un geste.
- [ ] Plan de chargement : contexte, cache KV, flash attention, graphes CUDA, justifications, charger/recharger, plus conservateur (`/inference/degrader`), chrono + journal de phases, barres VRAM/RAM.
- [ ] Découvrir (Hugging Face) : recherche, tri, filtres formats/capacités, pagination, faisabilité ; feuille Téléchargement (variantes + faisabilité).
- [ ] Sur le disque : synchroniser, favori, détail, charger, cohérence, oublier, supprimer du disque, dossiers non utilisables.
- [ ] Transferts : progression, annuler, reprendre, supprimer.
- [ ] Strata : charger.

## Système
- [ ] Profil machine (rafraîchir, cartes vivantes VRAM/RAM/courbes), services, moteurs llama.cpp/vLLM (sonder, installer/supprimer/annuler vLLM avec journal en direct), journal des chargements, détail matériel et contraintes.
