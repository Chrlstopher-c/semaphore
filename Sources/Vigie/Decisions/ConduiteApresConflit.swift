// Ce qu'on affiche quand le serveur refuse un geste, et surtout : ce qu'il faut
// faire ensuite.
//
// `☠` LE MESSAGE DU SERVEUR EST REPRIS MOT POUR MOT. Il nomme le projet, la
// machine, l'état, la mission — il est écrit pour être lu par un humain devant
// l'écran. Le remplacer par « une erreur est survenue » a déjà coûté des heures
// sur ce produit. Ce qu'on AJOUTE, c'est la conduite : le refus dit ce qui s'est
// passé, jamais où aller.
//
// `☠` ET LES QUATRE 409 NE SE PRÉSENTENT PAS DE LA MÊME FAÇON. Un mandat déjà
// tranché quitte la file et se tamponne — le clic suivant échouerait exactement
// pareil (mesuré en prod le 01/08 : carte périmée, clic 16 s trop tard). Un
// projet occupé reste en attente et se réessaie une fois l'autre équipe
// terminée. Les fondre ferait proposer « réessayer » là où le geste est arrivé
// trop tard, et « déjà autorisé » sur une équipe qui n'est jamais partie.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

public struct ConduiteApresConflit: Sendable, Identifiable, Equatable {
    /// L'identifiant de la décision concernée (`Decision.id`), pas celui du refus.
    public let id: String
    /// Ce qui s'est passé, en trois mots.
    public let titre: String
    /// Le texte du serveur, INTACT.
    public let motifServeur: String
    /// Ce que Chris doit faire ensuite, formulé à l'impératif.
    public let conduite: String
    public let etat: EtatSemantique
    /// La décision disparaît-elle de la file ? Vrai seulement quand le serveur a
    /// affirmé qu'elle n'existe plus.
    public let quitteLaFile: Bool
    /// Le tampon posé sur la carte quand elle quitte la file.
    public let sceau: String?
    /// Les boutons redeviennent-ils cliquables ? Faux quand rejouer le geste
    /// échouerait à l'identique.
    public let reArmable: Bool
}

extension ConduiteApresConflit {

    /// Traduit un refus en conduite. Le point d'entrée unique du domaine.
    public static func pour(_ erreur: ErreurApi, _ decision: Decision) -> ConduiteApresConflit {
        switch erreur.genre {
        case .conflit(let metier): return conflit(metier, erreur, decision)
        case .transport: return transport(erreur, decision)
        case .authentification: return authentification(erreur, decision)
        case .harnessInjoignable: return harnessMuet(erreur, decision)
        case .nonCable: return nonCable(erreur, decision)
        case .introuvable: return introuvable(erreur, decision)
        case .interne: return interne(erreur, decision)
        default: return generique(erreur, decision)
        }
    }

    // MARK: - Les quatre 409 de /propositions/{id}/approve

    private static func conflit(
        _ metier: ConflitMetier,
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        switch metier {
        case .mandatDejaTranche: return mandatDejaTranche(erreur, decision)
        case .projetOccupe: return projetOccupe(erreur, decision)
        case .projetAbsentDeLaMachine: return projetAbsent(erreur, decision)
        case .routageMachine: return routageMachine(erreur, decision)
        case .rallongeDejaTranchee: return rallongeDejaTranchee(erreur, decision)
        case .inspection: return arbitrageDejaTranche(erreur, decision)
        case .rappelIncompatible, .indetermine: return generique(erreur, decision)
        }
    }

    /// 1 — Le mandat a été tranché entre l'affichage de la carte et le clic.
    /// Auto-approbation, ou décision prise depuis un autre écran.
    private static func mandatDejaTranche(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Ce mandat était déjà tranché",
            motifServeur: erreur.message,
            conduite: "Rien à refaire ici : le geste est arrivé trop tard, pas au mauvais endroit. "
                + "Si l'équipe est partie, elle est dans le Parc — c'est là qu'on la suit et qu'on "
                + "l'arrête. Ce mandat, lui, ne se rejoue pas.",
            etat: .neutre,
            quitteLaFile: true,
            sceau: "Déjà tranché — voir le Parc",
            reArmable: false
        )
    }

    /// 2 — H-56 : une équipe est déjà active sur un projet non-git. L'attente est
    /// LÉGITIME et la décision reste ouverte : c'est le seul des quatre où
    /// réessayer plus tard a un sens.
    private static func projetOccupe(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Le projet est occupé (H-56)",
            motifServeur: erreur.message,
            conduite: "Le projet n'est pas un dépôt git : faute d'isolation par worktree, une seule "
                + "équipe peut y travailler. Termine l'équipe active depuis le Parc, puis reviens "
                + "autoriser ici. Le mandat reste en attente, rien n'est perdu.",
            etat: .vigilance,
            quitteLaFile: false,
            sceau: nil,
            reArmable: true
        )
    }

    /// 3 — Le projet visé n'existe pas sur la machine choisie pour ce fil.
    /// Rejouer le geste tel quel échouera à l'identique : quelque chose doit
    /// changer AVANT, et les boutons ne se réarment donc pas.
    private static func projetAbsent(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Le projet n'est pas sur cette machine",
            motifServeur: erreur.message,
            conduite: "Le message ci-dessus nomme la machine et le chemin cherché. Change la machine "
                + "du fil depuis l'écran Fil, ou refuse ce mandat pour que l'orchestrateur en "
                + "repropose un qui vise la bonne. Réessayer tel quel échouera exactement pareil.",
            etat: .danger,
            quitteLaFile: false,
            sceau: nil,
            reArmable: false
        )
    }

    /// 4 — Machine hors ligne, inconnue, ou fil rattaché à aucune. Réessayer a
    /// un sens dès que la machine répond.
    private static func routageMachine(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Aucune machine ne peut prendre ce mandat",
            motifServeur: erreur.message,
            conduite: "Le message dit laquelle et pourquoi. Réveille la machine depuis l'écran "
                + "Machines, ou rattache le fil à une machine en ligne, puis réessaie. "
                + "Aucune équipe n'a été créée.",
            etat: .danger,
            quitteLaFile: false,
            sceau: nil,
            reArmable: true
        )
    }

    // MARK: - Les autres circuits

    private static func rallongeDejaTranchee(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Demande déjà tranchée ailleurs",
            motifServeur: erreur.message,
            conduite: "Elle a été accordée ou refusée depuis un autre écran. Le plafond du fil est "
                + "celui que montre l'écran Fil — c'est lui qui fait foi.",
            etat: .neutre,
            quitteLaFile: true,
            sceau: "Déjà tranchée ailleurs",
            reArmable: false
        )
    }

    private static func arbitrageDejaTranche(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Ce verdict n'attend plus rien",
            motifServeur: erreur.message,
            conduite: "L'équipe a été arrêtée, relancée, ou le juge a rendu un nouveau verdict "
                + "entre-temps. Ouvre le Parc pour voir son état réel.",
            etat: .neutre,
            quitteLaFile: true,
            sceau: "Déjà arbitré",
            reArmable: false
        )
    }

    // MARK: - Pannes, et le 500 qui devrait être un 409

    /// `☠` LE CAS LE PLUS DANGEREUX. La session d'écriture attend 135 s ; un
    /// délai dépassé ne veut PAS dire que rien n'est parti — le control plane a
    /// pu dispatcher l'équipe et perdre sa réponse dans le tunnel. Annoncer
    /// « rien n'a été décidé » ferait recliquer, et dispatcher deux fois.
    private static func transport(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Aucune réponse n'est revenue",
            motifServeur: erreur.message,
            conduite: "Le geste est peut-être passé quand même : la réponse s'est perdue, pas "
                + "forcément la demande. Vérifie le Parc avant de réessayer — recliquer à l'aveugle "
                + "peut lancer une seconde équipe.",
            etat: .danger,
            quitteLaFile: false,
            sceau: nil,
            reArmable: true
        )
    }

    private static func authentification(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Session expirée",
            motifServeur: erreur.message,
            conduite: "Ressaisis le mot de passe : l'écran de connexion s'ouvre tout seul. "
                + "Rien n'a été transmis, la file est intacte.",
            etat: .vigilance,
            quitteLaFile: false,
            sceau: nil,
            reArmable: true
        )
    }

    private static func harnessMuet(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Le control plane ne tourne plus",
            motifServeur: erreur.message,
            conduite: "Le Pi répond, mais le harness qu'il héberge est mort. Ce n'est PAS le PC de "
                + "travail qui est éteint : c'est le service du Pi qu'il faut relancer.",
            etat: .danger,
            quitteLaFile: false,
            sceau: nil,
            reArmable: true
        )
    }

    private static func nonCable(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Ce geste n'est pas câblé sur ce Pi",
            motifServeur: erreur.message,
            conduite: "La route existe mais rien n'est branché derrière — l'inspection est "
                + "optionnelle côté serveur. Il n'y a rien à réessayer depuis le téléphone.",
            etat: .neutre,
            quitteLaFile: false,
            sceau: nil,
            reArmable: false
        )
    }

    private static func introuvable(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Introuvable côté serveur",
            motifServeur: erreur.message,
            conduite: "Le registre ne connaît plus cet identifiant. Tire la file vers le bas pour "
                + "la relever : ce que tu vois date d'avant.",
            etat: .neutre,
            quitteLaFile: true,
            sceau: "Disparue du registre",
            reArmable: false
        )
    }

    /// `☠` DÉFAUT SERVEUR CONNU. `ErreurPlafondEquipesProjetAtteint` n'est
    /// rattrapée nulle part dans `serveur-api.ts` : elle sort en 500 « erreur
    /// interne » alors que c'est un refus métier parfaitement lisible. On la
    /// reconnaît au texte pour ne pas envoyer chercher une panne là où il n'y a
    /// qu'un plafond. À retirer le jour où ccremote la rattrape en 409.
    private static func interne(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        let normalise = ClassementErreur.normaliser(erreur.message)
        guard normalise.contains("plafond") && normalise.contains("equipe") else {
            return generique(erreur, decision)
        }
        return ConduiteApresConflit(
            id: decision.id,
            titre: "Plafond d'équipes atteint sur ce projet",
            motifServeur: erreur.message,
            conduite: "Ce n'est pas une panne, malgré le code d'erreur : le serveur rend ce refus en "
                + "500 au lieu de 409, c'est un défaut connu de ccremote. Termine une équipe du "
                + "projet depuis le Parc, puis réessaie.",
            etat: .vigilance,
            quitteLaFile: false,
            sceau: nil,
            reArmable: true
        )
    }

    private static func generique(
        _ erreur: ErreurApi,
        _ decision: Decision
    ) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Refusé par le serveur",
            motifServeur: erreur.message,
            conduite: "Le message ci-dessus vient du control plane et n'a pas été reformulé. "
                + "Si rien n'y renvoie à une action, la file se relève en tirant vers le bas.",
            etat: .danger,
            quitteLaFile: false,
            sceau: nil,
            reArmable: true
        )
    }

    /// Face ID a dit non. Ce n'est pas un refus serveur : rien n'est parti.
    public static func gardeRefusee(_ motif: String, _ decision: Decision) -> ConduiteApresConflit {
        ConduiteApresConflit(
            id: decision.id,
            titre: "Authentification refusée",
            motifServeur: motif,
            conduite: "Rien n'a été transmis. Reprends le geste quand tu veux : c'est une garde "
                + "d'interface, elle ne bloque rien côté serveur.",
            etat: .vigilance,
            quitteLaFile: false,
            sceau: nil,
            reArmable: true
        )
    }
}
#endif
