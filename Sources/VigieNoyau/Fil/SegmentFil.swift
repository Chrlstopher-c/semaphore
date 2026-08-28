import Foundation

/// Un appel d'outil, tel qu'il se lit dans le fil.
///
/// `☠` `resultat` à `nil` veut dire « l'outil n'a pas encore répondu », JAMAIS
/// « il a répondu du vide ». Le serveur renvoie le MÊME `seq` enrichi au tour
/// suivant : un appel se met à jour en place, il ne se reposte pas.
public struct AppelOutil: Sendable, Hashable, Identifiable {
    public let seq: Int
    /// Nom technique complet (`mcp__ccremote-controle__lister_equipes`).
    public let nom: String
    /// Paramètres, en JSON brut tel que le serveur les a servis.
    public let detail: String?
    public let resultat: String?
    public let at: Int

    public var id: Int { seq }

    public init(seq: Int, nom: String, detail: String?, resultat: String?, at: Int) {
        self.seq = seq
        self.nom = nom
        self.detail = detail
        self.resultat = resultat
        self.at = at
    }

    /// `☠` Le marqueur porte une apostrophe TYPOGRAPHIQUE côté serveur
    /// (`collecteur-conversation.ts`). Ne tester que l'apostroph droite ferait
    /// passer tous les échecs pour des succès — silencieusement.
    public var enEchec: Bool {
        guard let resultat else { return false }
        return resultat.hasPrefix("[ÉCHEC DE L\u{2019}OUTIL]") || resultat.hasPrefix("[ÉCHEC DE L'OUTIL]")
    }

    public var aRepondu: Bool { resultat != nil }
}

/// Une rafale d'appels d'outils CONSÉCUTIFS, repliée sous un seul résumé.
///
/// `☠` Le groupement est la seule chose qui rende un tour lisible : sur huit
/// appels, on lit une ligne au lieu de huit. Le groupe se ferme dès que
/// l'orchestrateur reprend la parole — les appels d'après ouvrent leur propre
/// carte, sinon le résumé d'un tour entier ne voudrait plus rien dire.
public struct GroupeOutils: Sendable, Hashable, Identifiable {
    public let appels: [AppelOutil]

    public var id: Int { appels.first?.seq ?? 0 }
    public var echecs: Int { appels.filter(\.enEchec).count }
    public var enAttente: Int { appels.filter { !$0.aRepondu }.count }

    public init(appels: [AppelOutil]) {
        self.appels = appels
    }
}

/// Un bloc à l'intérieur d'une prise de parole de l'orchestrateur.
public enum BlocAgent: Sendable, Hashable, Identifiable {
    /// Ce que l'orchestrateur DIT — la seule chose qu'on vient lire.
    case parole(seq: Int, texte: String, at: Int)
    /// Son raisonnement. Replié une fois le tour fini, déplié pendant la frappe.
    case reflexion(seq: Int, texte: String, at: Int)
    case outils(GroupeOutils)
    /// Un refus, une panne de transmission. Toujours visible.
    case echec(seq: Int, texte: String, at: Int)
    /// Un fait du harness remis dans le fil (H-66) : fin d'équipe, rappel.
    /// `☠` JAMAIS rendu comme une parole de Chris — en relisant le fil, on
    /// croirait qu'il a demandé ce que le harness a annoncé tout seul.
    case fait(seq: Int, texte: String, at: Int)
    /// Un contenu que l'orchestrateur produit lui-même — script ou page HTML —
    /// affiché comme une carte dédiée. `piece` à `nil` : le fichier a disparu
    /// du disque du Pi, même trou que le front web (`!piece.url`).
    case artefact(seq: Int, piece: PieceJointeApi?, at: Int)

    public var id: Int {
        switch self {
        case .parole(let seq, _, _), .reflexion(let seq, _, _),
             .echec(let seq, _, _), .fait(let seq, _, _),
             .artefact(let seq, _, _): return seq
        case .outils(let groupe): return groupe.id
        }
    }

    public var at: Int {
        switch self {
        case .parole(_, _, let at), .reflexion(_, _, let at),
             .echec(_, _, let at), .fait(_, _, let at),
             .artefact(_, _, let at): return at
        case .outils(let groupe): return groupe.appels.last?.at ?? 0
        }
    }
}

/// Une prise de parole complète de l'orchestrateur : sa réflexion, ses outils,
/// son texte, sous une seule attribution de modèle.
public struct TourAgent: Sendable, Hashable, Identifiable {
    public let blocs: [BlocAgent]
    /// `☠` Portés PAR ÉVÈNEMENT : relire un fil où l'on a changé de modèle doit
    /// montrer ce qui a réellement produit CHAQUE réponse, pas le dernier
    /// réglage en date.
    public let modele: String?
    public let effort: String?

    public var id: Int { blocs.first?.id ?? 0 }
    public var finA: Int { blocs.last?.at ?? 0 }

    public init(blocs: [BlocAgent], modele: String?, effort: String?) {
        self.blocs = blocs
        self.modele = modele
        self.effort = effort
    }
}

/// Un message de Chris, avec ses pièces jointes.
public struct MessageOperateur: Sendable, Hashable, Identifiable {
    public let seq: Int
    public let texte: String
    public let pieces: [PieceJointeApi]
    public let at: Int

    public var id: Int { seq }

    public init(seq: Int, texte: String, pieces: [PieceJointeApi], at: Int) {
        self.seq = seq
        self.texte = texte
        self.pieces = pieces
        self.at = at
    }
}

/// Le fil, découpé en ce que l'écran pose l'un sous l'autre.
public enum SegmentFil: Sendable, Hashable, Identifiable {
    case operateur(MessageOperateur)
    case tour(TourAgent)
    /// `☠` Le contenu de l'évènement est l'IDENTIFIANT de la proposition, pas un
    /// texte. La carte se remplit en croisant `/orchestrator/propositions`.
    case mandat(seq: Int, proposition: String, at: Int)
    case compaction(seq: Int, resume: String, at: Int)

    public var id: Int {
        switch self {
        case .operateur(let message): return message.id
        case .tour(let tour): return tour.id
        case .mandat(let seq, _, _), .compaction(let seq, _, _): return seq
        }
    }

    public var at: Int {
        switch self {
        case .operateur(let message): return message.at
        case .tour(let tour): return tour.finA
        case .mandat(_, _, let at), .compaction(_, _, let at): return at
        }
    }
}
