import Foundation
import Testing
@testable import VigieNoyau

// Le lien chiffré de l'appareil au-delà de l'API : messages binaires et morceaux, flux en direct, terminal de
// machine, révocation. Sans réseau : la forme des messages (miroir de Quart) et les bornes du réassemblage.

private func aller(_ message: ProtocoleAiguilleur.DuLien) throws -> ProtocoleAiguilleur.DuLien {
    try ProtocoleAiguilleur.decoderDuLien(try ProtocoleAiguilleur.encoder(message))
}

struct FormeDuLienTests {
    @Test func requeteBinaireEtReponseBinaireFontLAller() throws {
        let requete = ProtocoleAiguilleur.DuLien.api(
            ref: "r1", methode: "PUT", chemin: "/api/televersement", corps: "", codage: "base64", type: "image/png",
            morceaux: 3
        )
        #expect(try aller(requete) == requete)
        let reponse = ProtocoleAiguilleur.DuLien.apiReponse(
            ref: "r1", statut: 200, corps: "aGk=", codage: "base64", type: "image/png"
        )
        #expect(try aller(reponse) == reponse)
    }

    @Test func morceauxEtDiffusionFontLAller() throws {
        let morceau = ProtocoleAiguilleur.DuLien.morceau(ref: "r2", rang: 1, corps: "tranche")
        #expect(try aller(morceau) == morceau)
        let diffusion = ProtocoleAiguilleur.DuLien.diffusion(ref: "d1", corps: "", morceaux: 2)
        #expect(try aller(diffusion) == diffusion)
        #expect(try aller(.diffusionOuvrir) == .diffusionOuvrir)
        #expect(try aller(.diffusionOuverte) == .diffusionOuverte)
    }

    @Test func terminalDeMachineFontLAller() throws {
        let ouverture = ProtocoleAiguilleur.DuLien.terminalPoste(
            ref: "r3", terminal: "t1", machine: "tour", cible: .shell(dossier: "/projets/x"), colonnes: 80, lignes: 24
        )
        #expect(try aller(ouverture) == ouverture)
        let tmux = ProtocoleAiguilleur.DuLien.terminalPoste(
            ref: "r4", terminal: "t2", machine: "tour", cible: .tmux("main"), colonnes: 100, lignes: 30
        )
        #expect(try aller(tmux) == tmux)
        #expect(try aller(.terminalSortie(terminal: "t1", base64: "aGk=")) == .terminalSortie(terminal: "t1", base64: "aGk="))
        #expect(try aller(.terminalFin(terminal: "t1", code: nil)) == .terminalFin(terminal: "t1", code: nil))
        #expect(try aller(.terminalFin(terminal: "t1", code: 0)) == .terminalFin(terminal: "t1", code: 0))
        #expect(try aller(.reponse(ref: "r3", ok: false, raison: "poste hors ligne"))
            == .reponse(ref: "r3", ok: false, raison: "poste hors ligne"))
        #expect(try aller(.reponse(ref: "r3", ok: true, raison: nil)) == .reponse(ref: "r3", ok: true, raison: nil))
    }

    @Test func unMessageSansSonChampRequisEstRefuse() {
        #expect(throws: ErreurChiffrement.self) {
            try ProtocoleAiguilleur.decoderDuLien(Data(#"{"t":"morceau","ref":"r1","corps":"x"}"#.utf8))
        }
        #expect(throws: ErreurChiffrement.self) {
            try ProtocoleAiguilleur.decoderDuLien(Data(#"{"t":"reponse","ref":"r1"}"#.utf8))
        }
    }
}

struct MorceauxTests {
    @Test func unCorpsCoupeSeReunitALIdentique() {
        let texte = String(repeating: "é", count: 20_000)
        let morceaux = DecoupeMorceaux.de(texte)
        #expect(morceaux.count > 1)
        #expect(morceaux.allSatisfy { $0.utf8.count <= 8_192 })
        #expect(morceaux.joined() == texte)
        #expect(DecoupeMorceaux.de("court").isEmpty)
    }

    @Test func leReassemblageRefuseLesRangsHorsOrdre() {
        var r = ReassemblageMorceaux()
        let premier = r.recevoir(ref: "a", rang: 0, corps: "un")
        let horsOrdre = r.recevoir(ref: "a", rang: 2, corps: "trois")
        let reuni = r.assembler(ref: "a", nombre: 2)
        #expect(premier)
        #expect(horsOrdre == false)
        #expect(reuni == nil)
    }

    @Test func leReassemblageRendLeCorpsQuandTousLesMorceauxSontLa() {
        var r = ReassemblageMorceaux()
        let premier = r.recevoir(ref: "b", rang: 0, corps: "deux ")
        let second = r.recevoir(ref: "b", rang: 1, corps: "morceaux")
        let reuni = r.assembler(ref: "b", nombre: 2)
        let deuxieme = r.assembler(ref: "b", nombre: 2)
        #expect(premier && second)
        #expect(reuni == "deux morceaux")
        #expect(deuxieme == nil)
    }
}

struct DiffusionTests {
    @Test func unDeltaDeTexteEtUnEvenementSeDecodent() {
        let flux = #"{"type":"flux","sessionId":"s1","bloc":"b","delta":"Bonjour"}"#
        #expect(DecodeurDiffusion.lire(flux) == .flux(sessionId: "s1", bloc: "b", delta: "Bonjour", genre: nil, agent: nil))
        #expect(DecodeurDiffusion.lire(#"{"type":"inconnu"}"#) == .inconnu(type: "inconnu"))
        #expect(DecodeurDiffusion.lire("pas du JSON") == nil)
    }
}

/// Un transport dont le lien est coupé par l'aiguilleur pour révocation (fermeture 4401).
actor TransportRevoque: TransportAiguilleur {
    func envoyer(_ message: ProtocoleAiguilleur.VersAiguilleur) async throws {}

    func recevoir() async throws -> ProtocoleAiguilleur.DeAiguilleur {
        throw ErreurRevocation()
    }

    func fermer() async {}
}

/// Compte les ouvertures de lien, depuis une fabrique synchrone.
final class CompteurOuvertures: @unchecked Sendable {
    private let verrou = NSLock()
    private var nombre = 0

    var valeur: Int {
        verrou.lock()
        defer { verrou.unlock() }
        return nombre
    }

    func ajouter() {
        verrou.lock()
        nombre += 1
        verrou.unlock()
    }
}

struct RevocationTests {
    @Test func laFermeture4401ArreteLeLienSansReprise() async throws {
        let compteur = CompteurOuvertures()
        let rec = Enregistreur()
        let etat = ClientAiguilleur.Etat(adresse: "http://127.0.0.1:9", membre: "aaaaaaaaaaaa", jeton: "jeton-test")
        let client = ClientAiguilleur(
            etat: etat, graines: .generer(), nomAppareil: "iphone-test",
            surEtat: { await rec.noterEtat($0) }, surLien: { await rec.noterLien($0) },
            fabrique: { _, _ in compteur.ajouter(); return TransportRevoque() }, delais: .rapides
        )
        await client.demarrer()
        try await rec.attendreLien { $0 == .revoque }
        try await Task.sleep(for: .milliseconds(300))
        #expect(compteur.valeur == 1)
        #expect(await rec.contient(.deconnecte) == false)
        await client.arreter()
    }
}

struct AppairageInjoignableTests {
    @Test func aiguilleurInjoignableNEstPasUnRefusDuCode() async throws {
        // Port fermé sur la boucle locale : la connexion échoue sans réseau, comme une adresse VPN vue de l'extérieur.
        let adresse = try #require(URL(string: "http://127.0.0.1:9"))
        do {
            _ = try await LienAiguilleur.appairer(adresse: adresse, code: "ABCD-EFGH", nom: "iphone", cle: "cle")
            Issue.record("un appairage vers un port fermé ne devrait pas réussir")
        } catch let erreur as ErreurAiguilleur {
            #expect(erreur.message == LienAiguilleur.messageInjoignable)
        }
    }
}
