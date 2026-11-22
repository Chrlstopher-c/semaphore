// Titres de repli : une session que le relais nomme d'après son dossier prend le début de sa première demande, lu une
// fois (tout début du fil) puis gardé sur l'iPhone.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

extension ModeleRelais {
    private static let clePremiersMessages = "quart.premiersMessages"
    private static let limiteDebut = 20

    static func premiersMessagesGardes() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: clePremiersMessages) as? [String: String] ?? [:]
    }

    /// Demande le début du fil d'une session sans titre, une seule fois par lancement.
    public func chargerPremierMessage(_ id: String) async {
        guard let client, premiersMessages[id] == nil, !titresDemandes.contains(id) else { return }
        titresDemandes.insert(id)
        do {
            let debut: [EvenementDate] = try await client.lire(Route.premiersEvenements(id, limite: Self.limiteDebut))
            if let m = TitreSession.premierMessage(debut) { retenirPremierMessage(m, de: id) }
        } catch {
            Trace.erreur("relais", "début du fil \(id) non lu", error)
        }
    }

    func retenirPremierMessage(_ texte: String, de id: String) {
        let ligne = TitreSession.premiereLigne(texte)
        guard !ligne.isEmpty, premiersMessages[id] != ligne else { return }
        premiersMessages[id] = ligne
        UserDefaults.standard.set(premiersMessages, forKey: Self.clePremiersMessages)
    }
}
#endif
