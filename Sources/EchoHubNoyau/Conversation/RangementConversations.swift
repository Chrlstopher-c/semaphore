import Foundation

/// Rangement de la liste des conversations, comme la colonne du web (`groupes-conversations.ts`) :
/// d'abord les projets, chacun avec ses sessions, puis les conversations libres par période.
public struct RangementConversations: Sendable, Equatable {
    public struct Groupe: Sendable, Equatable, Identifiable {
        public let libelle: String
        public let conversations: [ResumeConversation]
        public var id: String { libelle }
    }

    /// Projets dans l'ordre de leur session la plus récente (la liste arrive triée par mise à jour).
    public let projets: [Groupe]
    public let periodes: [Groupe]

    static let ordrePeriodes = ["Aujourd'hui", "Hier", "Cette semaine", "Plus ancien"]

    public init(_ conversations: [ResumeConversation], maintenant: Date = .now, calendrier: Calendar = .current) {
        var projets: [(String, [ResumeConversation])] = []
        var libres: [String: [ResumeConversation]] = [:]
        let minuit = calendrier.startOfDay(for: maintenant)
        for conversation in conversations {
            if let projet = conversation.projet, !projet.isEmpty {
                if let rang = projets.firstIndex(where: { $0.0 == projet }) {
                    projets[rang].1.append(conversation)
                } else {
                    projets.append((projet, [conversation]))
                }
            } else {
                libres[Self.periode(conversation.majLe, minuit: minuit), default: []].append(conversation)
            }
        }
        self.projets = projets.map { Groupe(libelle: $0.0, conversations: $0.1) }
        periodes = Self.ordrePeriodes.compactMap { libelle in
            libres[libelle].map { Groupe(libelle: libelle, conversations: $0) }
        }
    }

    public var estVide: Bool { projets.isEmpty && periodes.isEmpty }

    static func periode(_ date: Date, minuit: Date) -> String {
        let ecart = minuit.timeIntervalSince(date)
        if ecart <= 0 { return "Aujourd'hui" }
        if ecart <= 86_400 { return "Hier" }
        return ecart <= 7 * 86_400 ? "Cette semaine" : "Plus ancien"
    }

    /// Filtre sur le titre et le projet, insensible à la casse et aux accents.
    public static func filtrer(_ conversations: [ResumeConversation], _ requete: String) -> [ResumeConversation] {
        let cible = normaliser(requete.trimmingCharacters(in: .whitespaces))
        guard !cible.isEmpty else { return conversations }
        return conversations.filter { normaliser("\($0.titre) \($0.projet ?? "")").contains(cible) }
    }

    private static func normaliser(_ texte: String) -> String {
        texte.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
