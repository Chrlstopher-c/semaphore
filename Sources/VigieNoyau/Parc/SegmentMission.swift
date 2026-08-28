import Foundation

/// Ce qu'un segment du fil montre.
public enum GenreSegment: Sendable, Hashable {
    /// Rafale d'appels d'outils. `delegation` isole les `Task`.
    case outils(delegation: Bool)
    case pensees
    case systeme
    /// Une instruction de Chris.
    case operateur
    case permission
    /// Une parole du lead.
    case parole
}

/// Une rafale de lignes consécutives, prête pour une liste SwiftUI.
///
/// `☠` `id` vient de la PREMIÈRE ligne, indexée par `FeedEventApi.indexer` :
/// c'est une clé qui survit au sondage suivant. Sans elle, SwiftUI change
/// l'identité des vues à chaque relevé — les blocs dépliés se referment, le
/// défilement est rejeté. C'est l'équivalent exact de la RÈGLE ABSOLUE du
/// contrat côté web.
public struct SegmentMission: Sendable, Hashable, Identifiable {
    public let id: String
    public let genre: GenreSegment
    public let elements: [EvenementFilMission]

    public var lignes: [FeedEventApi] { elements.map(\.evenement) }
    public var premiere: FeedEventApi { elements[0].evenement }
    public var derniere: FeedEventApi { elements[elements.count - 1].evenement }

    /// Instant d'arrivée du segment — c'est lui qu'on affiche en pied.
    public var fin: Int { elements.map(\.at).max() ?? premiere.at }

    /// `☠` Un segment d'UNE ligne n'a pas de durée : son début est sa fin. On
    /// rend `nil` plutôt que `0`, pour que le pied n'affiche rien du tout.
    ///
    /// `☠` Une rafale de TRANSITIONS n'en a pas non plus : entre « le lead a
    /// rendu la main » et « équipe terminée » il s'écoule une seconde de
    /// plomberie, et l'afficher donne à lire une mesure qui ne mesure rien.
    public var duree: Int? {
        guard genre != .systeme, elements.count > 1 else { return nil }
        let instants = elements.map(\.at)
        guard let debut = instants.min(), let fin = instants.max(), fin > debut else { return nil }
        return fin - debut
    }
}

public enum SegmentationMission {

    /// Regroupe le fil en segments affichables.
    ///
    /// `☠` Les rafales ne sont groupées que si elles sont CONSÉCUTIVES : une
    /// parole du lead au milieu coupe le groupe, sinon l'ordre réel du travail
    /// serait perdu.
    ///
    /// `☠` Une DÉLÉGATION ne se fond jamais dans la rafale d'outils voisine.
    /// Fondue, elle disparaît derrière « exécuté 7 commandes » : le seul endroit
    /// du fil où l'équipe grandit devient introuvable.
    public static func segmenter(_ fil: [FeedEventApi]) -> [SegmentMission] {
        var segments: [SegmentMission] = []
        var courant: [EvenementFilMission] = []
        var genreCourant: GenreSegment?

        func pousser() {
            guard let genre = genreCourant, !courant.isEmpty else { return }
            segments.append(SegmentMission(id: courant[0].id, genre: genre, elements: courant))
            courant = []
            genreCourant = nil
        }

        for element in FeedEventApi.indexer(fil) {
            let genre = genre(de: element.evenement)
            if groupable(genre), genre == genreCourant {
                courant.append(element)
                continue
            }
            pousser()
            genreCourant = genre
            courant = [element]
            if !groupable(genre) { pousser() }
        }
        pousser()
        return segments
    }

    /// Seules les rafales homogènes se groupent ; une parole, une instruction ou
    /// une autorisation portent chacune leur propre bloc.
    static func groupable(_ genre: GenreSegment) -> Bool {
        switch genre {
        case .outils, .pensees, .systeme: return true
        case .operateur, .permission, .parole: return false
        }
    }

    static func genre(de evenement: FeedEventApi) -> GenreSegment {
        if evenement.type == .activite, evenement.nature == .outil {
            return .outils(delegation: LibelleOutil.estDelegation(evenement))
        }
        if evenement.type == .activite, evenement.nature == .reflexion { return .pensees }
        if evenement.type == .systeme { return .systeme }
        if evenement.type == .instruction { return .operateur }
        if evenement.type == .permission { return .permission }
        return .parole
    }
}

/// Un message posté par le HARNESS lui-même.
///
/// `☠` Ce n'est ni une parole du lead, ni une instruction de Chris —
/// l'attribuer à l'un des deux est le mode de panne H-66. Il est marqué en clair
/// à la source ; on le reconnaît ici pour lui donner sa propre voix.
public enum MessageHarness {
    static let marque = "[HARNESS]"

    public static func detacher(_ texte: String) -> String? {
        let brut = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard brut.hasPrefix(marque) else { return nil }
        return String(brut.dropFirst(marque.count)).trimmingCharacters(in: .whitespaces)
    }
}
