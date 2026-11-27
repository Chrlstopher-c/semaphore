// Ce que le composeur soumet : un message, une consigne glissée à l'agent qui travaille, ou une
// commande slash (`/compact`, `/clear`), comme la saisie du web.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

extension Salon {
    /// Rend le message d'échec à afficher sous la saisie, `nil` si c'est parti.
    public func soumettre(_ saisie: String) async -> String? {
        switch AnalyseSaisie(saisie) {
        case .texte: return await envoyerOuGlisser(saisie)
        case .litteral(let texte): return await envoyerOuGlisser(texte)
        case .commande(let nom, let arguments): return await executer(nom, arguments)
        }
    }

    /// Pendant un tour, le texte est glissé à l'agent (lu à la fin de son étape) ; si le PC ne
    /// génère plus, il part en file et sera envoyé à la fin du tour.
    private func envoyerOuGlisser(_ texte: String) async -> String? {
        let propre = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !propre.isEmpty else { return nil }
        guard enGeneration, let conversation else {
            envoyerOuFileDAttente(propre)
            return nil
        }
        do {
            if try await conversations.glisserConsigne(conversation.id, texte: propre) {
                consignesGlissees.append(propre)
            } else {
                envoyerOuFileDAttente(propre)
            }
            return nil
        } catch {
            Journal.echec("consigne non glissée : \(error)")
            envoyerOuFileDAttente(propre)
            return nil
        }
    }

    private func executer(_ nom: String, _ arguments: String) async -> String? {
        guard let conversation else { return "Ouvre une conversation pour lancer une commande." }
        guard catalogueCommandes.isEmpty || catalogueCommandes.contains(where: { $0.nom == nom }) else {
            return "Commande inconnue : /\(nom)"
        }
        guard !enGeneration else { return "Une réponse ou une commande est déjà en cours ici : réessaie à sa fin." }
        do {
            let reponse = try await conversations.executerCommande(conversation.id, nom: nom, arguments: arguments)
            if let effacement = reponse.effacement {
                effacements.append(effacement)
                return nil
            }
            await suivreCommande()
            return nil
        } catch {
            Journal.echec("commande /\(nom) refusée : \(error)")
            return Self.libelle(error)
        }
    }

    /// Après le 202, la commande se suit par le flux. La diffusion peut ne pas être encore ouverte
    /// (204) : on se raccroche trois fois au plus, comme le web.
    private func suivreCommande() async {
        for essai in 0..<3 {
            if essai > 0 { try? await Task.sleep(for: .milliseconds(500)) }
            raccrocher()
            await attendreLeTour()
            if let commande, commande.etat != "en_cours" { return }
        }
    }

    public func annuler(effacement: InfoEffacement) async {
        guard let conversation else { return }
        do {
            try await conversations.annulerEffacement(conversation.id, effacement: effacement.id)
            effacements.removeAll { $0.id == effacement.id }
        } catch {
            Journal.echec("effacement non annulé : \(error)")
            poser(erreur: "Annulation du /clear impossible — \(Self.libelle(error))")
        }
    }

    func releverEffacements() async {
        guard let conversation else { return }
        do {
            effacements = try await conversations.effacements(conversation.id)
        } catch {
            Journal.note("effacements non relevés : \(error)")
        }
    }

    func chargerCatalogueCommandes() async {
        do {
            catalogueCommandes = try await conversations.catalogueCommandes()
        } catch {
            Journal.note("catalogue des commandes illisible : \(error)")
        }
    }
}
#endif
