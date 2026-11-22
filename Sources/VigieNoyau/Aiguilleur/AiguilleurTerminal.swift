import Foundation

// Responsabilité : le terminal d'une machine du nœud par le canal de l'appareil — miroir de TerminalAppareil
// (Quart, relais/federation/terminal-appareil.ts). Ouverture (`terminal_poste`, la réponse dit si le shell est là),
// sortie et fin en octets, saisie et taille vers le poste. Même suite de messages que le WebSocket direct.

/// Ce qu'un terminal livre à l'appli : sa sortie (octets bruts), sa fin (code de sortie), sa fermeture (raison).
public enum EvenementTerminal: Sendable, Equatable {
    case sortie(Data)
    case fin(code: Int?)
    case ferme(String)
}

/// La cible d'un terminal de machine : le shell (dans un dossier, facultatif) ou une session tmux.
public enum CibleTerminalAiguilleur: Sendable, Equatable {
    case shell(dossier: String?)
    case tmux(String)
}

extension ClientAiguilleur {
    /// Ouvre un terminal sur une machine du nœud ; rend son identifiant et son flux de sortie. Refus : une erreur
    /// qui dit pourquoi (poste hors ligne, terminal refusé).
    public func ouvrirTerminal(
        machine: String, cible: CibleTerminalAiguilleur, colonnes: Int, lignes: Int
    ) async throws -> (terminal: String, evenements: AsyncStream<EvenementTerminal>) {
        let canal = try await canalOuvert()
        let terminal = UUID().uuidString.lowercased()
        let ref = UUID().uuidString.lowercased()
        let (flux, continuation) = AsyncStream.makeStream(of: EvenementTerminal.self)
        terminaux[terminal] = continuation
        await requetes.prevoir(ref)
        armerDelaiReponse(ref, delais.reponse)
        let protocole: ProtocoleAiguilleur.CibleTerminal = switch cible {
        case let .shell(dossier): .shell(dossier: dossier)
        case let .tmux(nom): .tmux(nom)
        }
        let message = ProtocoleAiguilleur.DuLien.terminalPoste(
            ref: ref, terminal: terminal, machine: machine, cible: protocole, colonnes: colonnes, lignes: lignes
        )
        guard await canal.envoyer(message) else {
            await requetes.annuler(ref)
            terminaux[terminal] = nil
            throw ErreurAiguilleur("terminal non ouvert : lien fermé")
        }
        do {
            let reponse = try await requetes.attendre(ref)
            guard reponse.statut == 200 else { throw ErreurAiguilleur(reponse.corps.isEmpty ? "terminal refusé" : reponse.corps) }
            return (terminal, flux)
        } catch {
            terminaux[terminal] = nil
            throw error
        }
    }

    public func envoyerTerminal(_ terminal: String, octets: Data) async {
        guard let canal = await canalPret() else { return }
        _ = await canal.envoyer(.terminalEntree(terminal: terminal, base64: octets.base64EncodedString()))
    }

    public func redimensionnerTerminal(_ terminal: String, colonnes: Int, lignes: Int) async {
        guard let canal = await canalPret() else { return }
        _ = await canal.envoyer(.terminalTaille(terminal: terminal, colonnes: colonnes, lignes: lignes))
    }

    public func fermerTerminal(_ terminal: String) async {
        guard let flux = terminaux.removeValue(forKey: terminal) else { return }
        flux.yield(.ferme("fermé par l'appli"))
        flux.finish()
        guard let canal = await canalPret() else { return }
        _ = await canal.envoyer(.terminalFermer(terminal: terminal))
    }

    func livrerTerminal(_ terminal: String, _ base64: String) {
        guard let octets = Data(base64Encoded: base64) else { return }
        terminaux[terminal]?.yield(.sortie(octets))
    }

    func finirTerminal(_ terminal: String, _ code: Int?) {
        guard let flux = terminaux.removeValue(forKey: terminal) else { return }
        flux.yield(.fin(code: code))
        flux.finish()
    }

    func finirTerminaux(_ raison: String) {
        let ouverts = terminaux
        terminaux = [:]
        for flux in ouverts.values {
            flux.yield(.ferme(raison))
            flux.finish()
        }
    }
}
