import Foundation

/// Un fil qu'on a quitté pendant qu'il générait, et dont on attend la réponse.
///
/// Le titre voyage avec l'identifiant : l'alerte doit nommer le fil, et le bus
/// qui la pose peut tourner alors qu'aucun écran n'a jamais été ouvert — après
/// un réveil de fond, il n'y a personne pour aller chercher le nom.
public struct FilAttendu: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let titre: String
    /// `majA` du fil à l'instant où on l'a quitté. C'est la borne qui distingue
    /// « la réponse est arrivée » de « la génération a été coupée sans rien
    /// produire » : sans elle, une interruption sonnerait comme une réponse.
    public let majAuDepart: Int
    /// Epoch ms du départ. Borne la mémoire — voir `peremptionMs`.
    public let depuis: Int

    public init(id: String, titre: String, majAuDepart: Int, depuis: Int) {
        self.id = id
        self.titre = titre
        self.majAuDepart = majAuDepart
        self.depuis = depuis
    }
}

/// Les fils dont on attend la réponse, et la règle qui décide quand sonner.
///
/// `☠` Cette attente est la SEULE raison pour laquelle le bus a le droit de
/// lire la liste des fils en arrière-plan. Vide, il ne la lit pas : une requête
/// de plus toutes les vingt-cinq secondes, toute la nuit, pour un écran que
/// personne ne regarde, c'est exactement la dérive qu'on corrige ailleurs.
public struct AttenteFils: Codable, Sendable, Equatable {
    private var attendus: [String: FilAttendu]

    /// Au-delà, on cesse d'attendre sans rien annoncer. Un fil qui n'a pas
    /// répondu en deux heures ne répondra pas : l'orchestrateur est tombé, ou la
    /// session a été coupée côté machine. Sonner à ce stade annoncerait une
    /// réponse qui n'existe pas.
    static let peremptionMs = 2 * 60 * 60 * 1000

    public init() {
        attendus = [:]
    }

    public var vide: Bool { attendus.isEmpty }
    public var taille: Int { attendus.count }

    /// Note qu'on quitte ce fil en pleine génération. Réécrit une attente
    /// existante : la borne la plus récente est la bonne.
    public mutating func attendre(
        id: String,
        titre: String,
        majA: Int,
        maintenant: Int
    ) {
        attendus[id] = FilAttendu(id: id, titre: titre, majAuDepart: majA, depuis: maintenant)
    }

    /// On rouvre le fil : plus rien à annoncer, on le lit en direct.
    public mutating func oublier(_ identifiant: String) {
        attendus.removeValue(forKey: identifiant)
    }

    /// Confronte l'attente à un relevé de la liste des fils.
    ///
    /// Trois issues par fil attendu, et les trois comptent :
    ///  - il a fini ET son horodatage a bougé ⇒ la réponse est là, on sonne ;
    ///  - il a fini sans rien produire, il a disparu de la liste, ou l'attente
    ///    est périmée ⇒ on oublie EN SILENCE ;
    ///  - il génère encore ⇒ on continue d'attendre.
    ///
    /// Effet de bord assumé : tout ce qui est rendu est retiré de l'attente,
    /// donc un même fil ne sonne qu'une fois.
    public mutating func repondus(_ fils: [FilApi], maintenant: Int) -> [FilAttendu] {
        guard !attendus.isEmpty else { return [] }
        let parId = Dictionary(fils.map { ($0.id, $0) }, uniquingKeysWith: { premier, _ in premier })
        var aSonner: [FilAttendu] = []
        for (identifiant, attendu) in attendus {
            switch verdict(attendu, fil: parId[identifiant], maintenant: maintenant) {
            case .patiente:
                continue
            case .sonne:
                aSonner.append(attendu)
                attendus.removeValue(forKey: identifiant)
            case .abandonne:
                attendus.removeValue(forKey: identifiant)
            }
        }
        return aSonner.sorted { $0.depuis < $1.depuis }
    }

    private enum Verdict {
        case patiente
        case sonne
        case abandonne
    }

    private func verdict(_ attendu: FilAttendu, fil: FilApi?, maintenant: Int) -> Verdict {
        // Le fil a disparu de la liste : archivé, ou supprimé côté serveur.
        guard let fil else { return .abandonne }
        if maintenant - attendu.depuis > Self.peremptionMs { return .abandonne }
        guard !fil.active else { return .patiente }
        return fil.majA > attendu.majAuDepart ? .sonne : .abandonne
    }
}
