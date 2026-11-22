import Foundation
import Testing
@testable import VigieNoyau

// Le canal de l'appareil contre un nœud simulé qui suit la séquence de Quart : présentation, décision, poignée,
// trames. Les messages passent par une file séquentielle (comme le réseau) : aucune pile d'appels imbriquée.

private enum Acheminement: Sendable {
    case versNoeud(ProtocoleAiguilleur.VersAiguilleur)
}

actor BancLien: Chiffrement.HoteAppareil {
    private let noeud = Chiffrement.Identite.generer()
    let publiqueNoeud: Chiffrement.IdentitePublique
    private let identiteAppareil: Chiffrement.IdentitePublique
    private let accordDuNoeud: Bool
    private var appareil: Chiffrement.CanalAppareil?
    private var pairsAppareil: [String: Chiffrement.IdentitePublique] = [:]
    private var identiteAppareilVue: Chiffrement.IdentitePublique?
    private var canalNoeud: Chiffrement.Canal?
    private var file: AsyncStream<Acheminement>.Continuation?
    private(set) var recus: [ProtocoleAiguilleur.DuLien] = []
    private(set) var refus: [String] = []
    private(set) var ouverts = 0

    init(identiteAppareil: Chiffrement.IdentitePublique, accordDuNoeud: Bool) {
        publiqueNoeud = noeud.publique
        self.identiteAppareil = identiteAppareil
        self.accordDuNoeud = accordDuNoeud
    }

    func raccorder(_ canal: Chiffrement.CanalAppareil, pairAvec identite: Chiffrement.IdentitePublique?) {
        appareil = canal
        if let identite { pairsAppareil["noeud-1"] = identite }
        let (flux, continuation) = AsyncStream.makeStream(of: Acheminement.self)
        file = continuation
        Task { [weak self] in
            for await acheminement in flux { await self?.livrer(acheminement) }
        }
    }

    // MARK: - Hôte côté appareil : les envois sont mis en file, la livraison se fait ailleurs.

    func envoyerAiguilleur(_ message: ProtocoleAiguilleur.VersAiguilleur) {
        file?.yield(.versNoeud(message))
    }

    func identitePairee(_ membre: String) -> Chiffrement.IdentitePublique? { pairsAppareil[membre] }

    func appairageAccepte(membre: String, nom: String, identite: Chiffrement.IdentitePublique) {
        pairsAppareil[membre] = identite
    }

    func liaisonOuverte(canal: String) { ouverts += 1 }

    func liaisonRefusee(canal: String, raison: String) { refus.append(raison) }

    func recevoir(canal: String, message: ProtocoleAiguilleur.DuLien) { recus.append(message) }

    func canalFerme(canal: String) {}

    // MARK: - Le nœud (côté aiguilleur + nœud), sur la file

    private func livrer(_ acheminement: Acheminement) async {
        switch acheminement {
        case let .versNoeud(.ouvrir(canal, _)):
            await appareil?.surAccepter()
            _ = canal
        case let .versNoeud(.donnees(_, charge)):
            await traiterNoeud(charge)
        case .versNoeud:
            break
        }
    }

    private func versAppareil(_ message: ProtocoleAiguilleur.EnClair) async throws {
        let charge = try ProtocoleAiguilleur.encoder(message)
        await appareil?.surDonnees(charge)
    }

    private func traiterNoeud(_ charge: String) async {
        guard let message = try? ProtocoleAiguilleur.decoderEnClair(charge) else { return }
        do {
            switch message {
            case let .presentation(identite, _, _):
                identiteAppareilVue = try Chiffrement.Identites.importer(identite)
                try await versAppareil(.presentation(
                    identite: Chiffrement.Identites.exporter(noeud.publique), nom: "tour", genre: "noeud"
                ))
                if accordDuNoeud { try await versAppareil(.accord) }
            case let .poignee(initiale):
                let cle = Chiffrement.Identites.exporter(identiteAppareil)
                let (reponse, canal) = try Chiffrement.Poignee.repondre(
                    moi: noeud, message: initiale, accepte: { Chiffrement.Identites.exporter($0) == cle }
                )
                canalNoeud = canal
                try await versAppareil(.poigneeReponse(reponse))
            case let .chiffre(trame):
                try await traiterTrame(trame)
            default:
                break
            }
        } catch {
            try? await versAppareil(.refus(raison: "identité non appairée"))
        }
    }

    private func traiterTrame(_ trame: String) async throws {
        guard let canal = canalNoeud else { throw ErreurChiffrement("pas de lien") }
        let clair = try await canal.dechiffrer(try Chiffrement.Octets.depuisBase64url(trame))
        guard case let .api(ref, _, _, _, _, _, _) = try ProtocoleAiguilleur.decoderDuLien(clair) else { return }
        let reponse = try ProtocoleAiguilleur.encoder(ProtocoleAiguilleur.DuLien.apiReponse(
            ref: ref, statut: 200, corps: "{\"machine\":\"tour\"}"
        ))
        let chiffre = try await canal.chiffrer(reponse)
        try await versAppareil(.chiffre(trame: Chiffrement.Octets.versBase64url(chiffre)))
    }
}

private func attendre(_ condition: () async -> Bool) async throws {
    for _ in 0..<400 {
        if await condition() { return }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    throw ErreurChiffrement("délai dépassé")
}

struct CanalAppareilTests {
    @Test func appairageAcceptePuisRequeteDansLeCanalChiffre() async throws {
        let appareil = Chiffrement.Identite.generer()
        let banc = BancLien(identiteAppareil: appareil.publique, accordDuNoeud: true)
        let canal = Chiffrement.CanalAppareil(
            id: "ap-1", membre: "noeud-1", intention: .appairage, moi: appareil, nomLocal: "iphone", hote: banc
        )
        await banc.raccorder(canal, pairAvec: nil)
        await canal.ouvrir()
        try await attendre { await canal.estOuvert }
        #expect(await canal.envoyer(.api(ref: "r1", methode: "GET", chemin: "/api/etat", corps: nil)))
        try await attendre { await banc.recus.count == 1 }
        #expect(await banc.recus == [.apiReponse(ref: "r1", statut: 200, corps: "{\"machine\":\"tour\"}")])
    }

    @Test func identiteNonAccepteeNeRoutePasDeLien() async throws {
        let appareil = Chiffrement.Identite.generer()
        let banc = BancLien(identiteAppareil: Chiffrement.Identite.generer().publique, accordDuNoeud: false)
        let canal = Chiffrement.CanalAppareil(
            id: "lien-1", membre: "noeud-1", intention: .lien, moi: appareil, nomLocal: "iphone", hote: banc
        )
        await banc.raccorder(canal, pairAvec: await banc.publiqueNoeud)
        await canal.ouvrir()
        try await attendre { await banc.refus.count == 1 }
        #expect(await canal.estOuvert == false)
        #expect(await canal.envoyer(.revocation) == false)
    }
}
