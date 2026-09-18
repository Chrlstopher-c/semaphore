// La réception du flux audio : un port UDP qu'on ouvre, qu'on annonce, et dont
// chaque datagramme part directement dans le tampon.
#if canImport(SwiftUI)
import DuplexNoyau
import Foundation
import Network

/// Écoute les paquets audio du PC et les verse dans le tampon.
///
/// `☠` Le chemin réseau → tampon ne passe par AUCUN acteur et n'attend personne :
/// 200 paquets par seconde, et le moindre saut de fil ajoute de la gigue. Le
/// rappel de `NWConnection` analyse, comble le trou éventuel et écrit — c'est
/// tout. Les compteurs se lisent ailleurs, à la cadence de l'affichage.
public final class ReceptionAudio: @unchecked Sendable {
    private let tampon: TamponAudio
    private let file = DispatchQueue(label: "duplex.reception", qos: .userInitiated)
    private var ecouteur: NWListener?
    private var connexions: [NWConnection] = []
    private var suivi = SuiviFlux()
    private let verrou = NSLock()

    public init(tampon: TamponAudio) {
        self.tampon = tampon
    }

    /// Le port réellement attribué par le système, à annoncer au PC dans
    /// `flux.demarrer`. Nul tant que l'écouteur n'est pas prêt.
    public private(set) var port: UInt16?

    /// Le relevé des pertes, pour l'affichage. Copie : le suivi lui-même
    /// n'appartient qu'au fil de réception.
    public var releve: SuiviFlux {
        verrou.withLock { suivi }
    }

    /// Ouvre un port UDP et attend qu'il soit prêt. On demande le port 0 : c'est
    /// le système qui en choisit un libre, et on l'annonce ensuite — jamais un
    /// numéro fixe, qui entrerait en conflit avec une autre app.
    public func ouvrir() async throws -> UInt16 {
        fermer()
        let ecouteur = try creerEcouteur()
        self.ecouteur = ecouteur
        let porte = PorteUnique()
        let attribue: UInt16 = try await withCheckedThrowingContinuation { suite in
            ecouteur.stateUpdateHandler = { etat in
                switch etat {
                case .ready:
                    guard let numero = ecouteur.port?.rawValue else {
                        porte.franchir { suite.resume(throwing: ErreurDuplex
                            .portIndisponible("port attribué illisible")) }
                        return
                    }
                    porte.franchir { suite.resume(returning: numero) }
                case let .failed(erreur):
                    porte.franchir { suite.resume(throwing: ErreurDuplex
                        .portIndisponible(erreur.localizedDescription)) }
                case .cancelled:
                    porte.franchir { suite.resume(throwing: ErreurDuplex.annule) }
                default:
                    break
                }
            }
            ecouteur.start(queue: file)
        }
        port = attribue
        Journal.note("port d'écoute UDP \(attribue)")
        return attribue
    }

    public func fermer() {
        ecouteur?.cancel()
        ecouteur = nil
        for connexion in connexions { connexion.cancel() }
        connexions.removeAll()
        port = nil
        verrou.withLock { suivi = SuiviFlux() }
        tampon.vider()
    }

    private func creerEcouteur() throws -> NWListener {
        let parametres = NWParameters.udp
        parametres.includePeerToPeer = false
        do {
            let ecouteur = try NWListener(using: parametres, on: .any)
            ecouteur.newConnectionHandler = { [weak self] connexion in
                self?.accueillir(connexion)
            }
            return ecouteur
        } catch {
            throw ErreurDuplex.portIndisponible(error.localizedDescription)
        }
    }

    private func accueillir(_ connexion: NWConnection) {
        connexions.append(connexion)
        connexion.start(queue: file)
        recevoir(connexion)
    }

    /// Une réception en chaîne : chaque datagramme traité en relance une. Bornée
    /// par l'état de la connexion — un `isComplete` ou une erreur l'arrête.
    private func recevoir(_ connexion: NWConnection) {
        connexion.receiveMessage { [weak self] donnees, _, termine, erreur in
            guard let self else { return }
            if let donnees { self.verser(donnees) }
            if termine || erreur != nil {
                if let erreur {
                    Journal.echec("réception audio interrompue : \(erreur.localizedDescription)")
                }
                connexion.cancel()
                return
            }
            self.recevoir(connexion)
        }
    }

    /// Le cœur du chemin chaud : analyser, combler, écrire.
    private func verser(_ donnees: Data) {
        guard case let .valide(entete) = EnTetePaquet.analyser(donnees) else { return }
        let verdict = verrou.withLock { suivi.accueillir(sequence: entete.sequence) }
        switch verdict {
        case .doublonOuRetard:
            return
        case let .trou(manquantes):
            // Exactement la durée manquante, en silence. On ne redemande jamais
            // un paquet perdu : la latence prime sur la complétude.
            tampon.ecrireSilence(trames: manquantes)
        case .rupture:
            // Trop long pour être comblé : on repart propre plutôt que d'insérer
            // des secondes de silence que la latence garderait pour toujours.
            tampon.vider()
            verrou.withLock { suivi.reprendre() }
        case .premier, .continu:
            break
        }
        tampon.ecrire(EnTetePaquet.echantillons(donnees))
    }
}
#endif
