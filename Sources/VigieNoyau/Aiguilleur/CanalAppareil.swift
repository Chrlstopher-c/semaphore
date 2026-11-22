import Foundation

// Responsabilité : le canal d'un appareil vers un nœud (rôle ouvrant) — appairage (présentation, décision du
// nœud), poignée sur identités connues, puis trames de l'API clients.
// Miroir côté ouvrant de `relais/federation/canal.ts`.
// Ordre garanti : les envois sortent dans l'ordre de leur chiffrement (flux séquentiel), car le nœud refuse tout
// compteur hors ordre. Les réceptions se traitent une à une : l'appelant doit livrer `surDonnees` dans l'ordre.

extension Chiffrement {
    /// Ce que le canal demande à l'hôte (le client de l'appli) : transport, pairs connus, réception des messages.
    protocol HoteAppareil: Sendable {
        func envoyerAiguilleur(_ message: ProtocoleAiguilleur.VersAiguilleur) async
        func identitePairee(_ membre: String) async -> IdentitePublique?
        func appairageAccepte(membre: String, nom: String, identite: IdentitePublique) async
        func liaisonOuverte(canal: String) async
        func liaisonRefusee(canal: String, raison: String) async
        func recevoir(canal: String, message: ProtocoleAiguilleur.DuLien) async
        func canalFerme(canal: String) async
    }

    actor CanalAppareil {
        enum Intention: Sendable {
            case appairage
            case lien
        }

        private enum Phase {
            case ouverture
            case attenteAccord
            case poignee
            case ouvert
            case ferme
        }

        /// Taille maximale d'un message en clair, comme le relais (`TAILLE_MAX_CLAIR_OCTETS`).
        private static let tailleMaxClair = 600_000

        let id: String
        let membre: String
        private let intention: Intention
        private let moi: Identite
        private let nomLocal: String
        private let hote: HoteAppareil
        private var phase: Phase = .ouverture
        private var presentationDistante: (identite: String, nom: String)?
        private var attente: AttentePoignee?
        private var canalChiffre: Canal?
        private var sortie: AsyncStream<Data>.Continuation?

        init(id: String, membre: String, intention: Intention, moi: Identite, nomLocal: String, hote: HoteAppareil) {
            self.id = id
            self.membre = membre
            self.intention = intention
            self.moi = moi
            self.nomLocal = nomLocal
            self.hote = hote
        }

        var estOuvert: Bool { phase == .ouvert }

        /// Demande l'ouverture du canal vers le nœud (message `ouvrir` à l'aiguilleur).
        func ouvrir() async {
            guard phase == .ouverture else { return }
            await hote.envoyerAiguilleur(.ouvrir(canal: id, vers: membre))
        }

        /// L'aiguilleur a relayé l'acceptation du nœud : on joue la suite de l'intention.
        func surAccepter() async {
            guard phase == .ouverture else { return }
            switch intention {
            case .appairage: await presenter()
            case .lien: await lancerPoignee()
            }
        }

        /// Une charge reçue du nœud, dans l'ordre d'arrivée. Une charge hors protocole ferme le canal.
        func surDonnees(_ charge: String) async {
            guard phase != .ferme else { return }
            do {
                try await traiter(try ProtocoleAiguilleur.decoderEnClair(charge))
            } catch {
                await fermer()
            }
        }

        /// Fermeture venue de l'aiguilleur (pair déconnecté, canal retiré) : rien à renvoyer.
        func surFermetureDistante() async {
            await terminer()
        }

        /// Envoie un message de l'API dans le canal chiffré ; faux si le canal n'est pas ouvert.
        func envoyer(_ message: ProtocoleAiguilleur.DuLien) -> Bool {
            guard phase == .ouvert, let sortie else { return false }
            guard let clair = try? ProtocoleAiguilleur.encoder(message),
                  clair.count <= CanalAppareil.tailleMaxClair else { return false }
            sortie.yield(clair)
            return true
        }

        /// Ferme le canal de notre côté : l'aiguilleur en est prévenu.
        func fermer() async {
            guard phase != .ferme else { return }
            await hote.envoyerAiguilleur(.fermer(canal: id))
            await terminer()
        }

        // MARK: - Appairage et poignée

        private func traiter(_ message: ProtocoleAiguilleur.EnClair) async throws {
            switch (phase, message) {
            case let (.attenteAccord, .presentation(identite, nom, _)):
                presentationDistante = (identite, nom)
            case (.attenteAccord, .accord):
                try await accepterAppairage()
            case let (.attenteAccord, .refus(raison)), let (.poignee, .refus(raison)):
                await hote.liaisonRefusee(canal: id, raison: raison)
                await terminer()
            case let (.poignee, .poigneeReponse(reponse)):
                try await finirPoignee(reponse)
            case let (.ouvert, .chiffre(trame)):
                try await recevoirTrame(trame)
            default:
                throw ErreurChiffrement("étape inattendue")
            }
        }

        private func presenter() async {
            phase = .attenteAccord
            let identite = Identites.exporter(moi.publique)
            guard let charge = try? ProtocoleAiguilleur.encoder(
                ProtocoleAiguilleur.EnClair.presentation(identite: identite, nom: nomLocal, genre: "appareil")
            ) else {
                return await fermer()
            }
            await hote.envoyerAiguilleur(.donnees(canal: id, charge: charge))
        }

        private func accepterAppairage() async throws {
            guard let presentation = presentationDistante else { throw ErreurChiffrement("accord avant présentation") }
            let identite = try Identites.importer(presentation.identite)
            await hote.appairageAccepte(membre: membre, nom: presentation.nom, identite: identite)
            await lancerPoignee()
        }

        private func lancerPoignee() async {
            guard let destinataire = await hote.identitePairee(membre) else {
                return await fermer()
            }
            do {
                let (message, nouvelle) = try Poignee.initier(moi: moi, destinataire: destinataire, canal: id)
                attente = nouvelle
                phase = .poignee
                let charge = try ProtocoleAiguilleur.encoder(ProtocoleAiguilleur.EnClair.poignee(message))
                await hote.envoyerAiguilleur(.donnees(canal: id, charge: charge))
            } catch {
                await fermer()
            }
        }

        private func finirPoignee(_ reponse: MessageReponse) async throws {
            guard let attente else { throw ErreurChiffrement("poignée sans attente") }
            let chiffre = try Poignee.terminer(attente: attente, reponse: reponse)
            self.attente = nil
            canalChiffre = chiffre
            demarrerEnvois(chiffre)
            phase = .ouvert
            await hote.liaisonOuverte(canal: id)
        }

        // MARK: - Trames

        private func recevoirTrame(_ trame: String) async throws {
            guard let canalChiffre else { throw ErreurChiffrement("trame hors lien") }
            let clair = try await canalChiffre.dechiffrer(try Octets.depuisBase64url(trame))
            await hote.recevoir(canal: id, message: try ProtocoleAiguilleur.decoderDuLien(clair))
        }

        /// Un seul consommateur chiffre et envoie : l'ordre des compteurs est celui des envois.
        private func demarrerEnvois(_ chiffre: Canal) {
            let (flux, continuation) = AsyncStream.makeStream(of: Data.self)
            sortie = continuation
            let identifiant = id
            let hoteLocal = hote
            Task {
                for await clair in flux {
                    guard let trame = try? await chiffre.chiffrer(clair) else { continue }
                    let charge = try? ProtocoleAiguilleur.encoder(
                        ProtocoleAiguilleur.EnClair.chiffre(trame: Octets.versBase64url(trame))
                    )
                    if let charge { await hoteLocal.envoyerAiguilleur(.donnees(canal: identifiant, charge: charge)) }
                }
            }
        }

        private func terminer() async {
            guard phase != .ferme else { return }
            phase = .ferme
            sortie?.finish()
            sortie = nil
            canalChiffre = nil
            await hote.canalFerme(canal: id)
        }
    }
}
