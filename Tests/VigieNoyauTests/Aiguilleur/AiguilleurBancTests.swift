import Foundation
import Testing
@testable import VigieNoyau

// Banc réel (banc/lancer-banc.sh) : un aiguilleur Quart et un nœud de banc sur 127.0.0.1, parlés avec le vrai
// protocole et le vrai chiffrement. Désactivé hors banc : QUART_AIGUILLEUR_BANC pointe le fichier JSON du banc.

private struct DescriptionBanc: Decodable {
    let adresse: String
    let codeAppareil: String
    let codeIntrus: String
    let codeAppareil2: String
    let codeAppareil3: String
    let noeud: String
    let image: String
}

private let bancActif = ProcessInfo.processInfo.environment["QUART_AIGUILLEUR_BANC"] != nil

/// Le banc, après un temps de repos : sous Linux, la coupure du lien du test précédent (URLSession partagée) peut
/// emporter le lien qui s'ouvre au même instant ; l'appli, elle, n'a qu'un client à la fois.
private func preparerBanc() async throws -> DescriptionBanc {
    try await Task.sleep(for: .milliseconds(400))
    return try chargerBanc()
}

private func chargerBanc() throws -> DescriptionBanc {
    guard let chemin = ProcessInfo.processInfo.environment["QUART_AIGUILLEUR_BANC"] else {
        throw ErreurAiguilleur("QUART_AIGUILLEUR_BANC absent")
    }
    let octets = try Data(contentsOf: URL(fileURLWithPath: chemin))
    return try JSONDecoder().decode(DescriptionBanc.self, from: octets)
}

@Suite(.serialized)
struct AiguilleurBancTests {
    @Test(.enabled(if: bancActif), .timeLimit(.minutes(2)))
    func appareilAppaireServLApiDuNoeudDansLeCanalChiffre() async throws {
        let banc = try await preparerBanc()
        let graines = GrainesIdentite.generer()
        let etat = try await ClientAiguilleur.appairer(
            adresse: try urlBanc(banc), code: banc.codeAppareil, nom: "appareil-banc", graines: graines
        )
        let rec = Enregistreur()
        let client = ClientAiguilleur(
            etat: etat, graines: graines, nomAppareil: "appareil-banc",
            surEtat: { await rec.noterEtat($0) }, surLien: { await rec.noterLien($0) }
        )
        await client.demarrer()
        try await rec.attendreLien(secondes: 30) { $0 == .ouvert }
        #expect(await rec.contient(.attenteAccord(empreinte: graines.empreinte)))
        let reponse = try await client.requete(methode: "GET", chemin: "/api/etat", corps: nil)
        #expect(reponse.statut == 200)
        #expect(reponse.corps == "{\"machine\":\"noeud-banc\"}")
        #expect(await rec.dernierEtat?.noeud == banc.noeud)
        #expect(await rec.dernierEtat?.identiteNoeud != nil)
        await client.arreter()
    }

    @Test(.enabled(if: bancActif), .timeLimit(.minutes(2)))
    func imageFluxEtTerminalPassentParLeCanalChiffre() async throws {
        let banc = try await preparerBanc()
        let graines = GrainesIdentite.generer()
        let etat = try await ClientAiguilleur.appairer(
            adresse: try urlBanc(banc), code: banc.codeAppareil2, nom: "appareil-banc-2", graines: graines
        )
        let rec = Enregistreur()
        let client = ClientAiguilleur(
            etat: etat, graines: graines, nomAppareil: "appareil-banc-2",
            surEtat: { await rec.noterEtat($0) }, surLien: { await rec.noterLien($0) }
        )
        await client.demarrer()
        try await rec.attendreLien(secondes: 30) { $0 == .ouvert }

        // Image : octets identiques à ceux du fichier servi par le nœud (morceaux dans les deux sens).
        let reponse = try await client.requete(methode: "GET", chemin: "/api/banc/image", corps: nil)
        #expect(reponse.codage == "base64")
        #expect(reponse.type == "image/png")
        let attendu = try Data(contentsOf: URL(fileURLWithPath: banc.image))
        #expect(Data(base64Encoded: reponse.corps) == attendu)

        // Flux en direct : le delta publié par le nœud arrive par le canal, sans interrogation.
        let flux = await client.ouvrirDiffusion()
        let recu = Task { () -> String in
            var texte = ""
            for await evenement in flux {
                if case let .message(.flux(_, _, delta, _, _)) = evenement { texte += delta }
                if texte == "Bonjour" { break }
            }
            return texte
        }
        _ = try await client.requete(methode: "POST", chemin: "/api/banc/diffuser", corps: "{}")
        #expect(await recu.value == "Bonjour")

        // Terminal de machine : l'écho du poste de banc revient dans le canal.
        let (terminal, sorties) = try await client.ouvrirTerminal(
            machine: "noeud-banc", cible: .shell(dossier: nil), colonnes: 80, lignes: 24
        )
        let echo = Task { () -> Data in
            var octets = Data()
            for await evenement in sorties {
                if case let .sortie(brut) = evenement { octets.append(brut) }
                if String(decoding: octets, as: UTF8.self).contains("ping") { break }
            }
            return octets
        }
        await client.envoyerTerminal(terminal, octets: Data("ping\n".utf8))
        #expect(String(decoding: await echo.value, as: UTF8.self).contains("ping"))
        await client.fermerTerminal(terminal)
        await client.arreter()
    }

    /// Le direct au fil de l'eau : 60 deltas horodatés émis toutes les 30 ms par le nœud arrivent un par un (ou par
    /// petits paquets de la fenêtre de regroupement du nœud), jamais en un bloc à la fin. Mesure imprimée.
    @Test(.enabled(if: bancActif), .timeLimit(.minutes(2)))
    func leDirectArriveAuFilDeLEau() async throws {
        let banc = try await preparerBanc()
        let graines = GrainesIdentite.generer()
        let etat = try await ClientAiguilleur.appairer(
            adresse: try urlBanc(banc), code: banc.codeAppareil3, nom: "appareil-banc-3", graines: graines
        )
        let rec = Enregistreur()
        let client = ClientAiguilleur(
            etat: etat, graines: graines, nomAppareil: "appareil-banc-3",
            surEtat: { await rec.noterEtat($0) }, surLien: { await rec.noterLien($0) }
        )
        await client.demarrer()
        try await rec.attendreLien(secondes: 30) { $0 == .ouvert }
        let flux = await client.ouvrirDiffusion()
        let total = 60
        let mesure = Task { () -> [(arrivee: Double, emis: [Double])] in
            var paquets: [(arrivee: Double, emis: [Double])] = []
            var vus = 0
            for await evenement in flux {
                if case let .ferme(raison) = evenement { print("BANC-DIRECT flux fermé : \(raison)") }
                guard case let .message(.flux(_, "r", delta, _, _)) = evenement else { continue }
                let maintenant = Date().timeIntervalSince1970 * 1000
                let emis = HorodatageBanc.lire(delta)
                paquets.append((maintenant, emis))
                vus += emis.count
                if vus >= total { break }
            }
            return paquets
        }
        _ = try await client.requete(methode: "POST", chemin: "/api/banc/rafale", corps: "{\"n\":\(total),\"ms\":30}")
        let paquets = await mesure.value
        let retards = paquets.flatMap { p in p.emis.map { p.arrivee - $0 } }.sorted()
        let duree = (paquets.last?.arrivee ?? 0) - (paquets.first?.arrivee ?? 0)
        print("BANC-DIRECT paquets=\(paquets.count) deltas=\(retards.count) étalement=\(Int(duree)) ms "
              + "retard médian=\(Int(retards[retards.count / 2])) ms max=\(Int(retards.last ?? 0)) ms")
        #expect(retards.count == total)
        // 60 × 30 ms = 1,8 s d'émission : le client doit recevoir au fil de l'eau (≥ 15 paquets, étalés ≥ 1,2 s).
        #expect(paquets.count >= 15)
        #expect(duree >= 1200)
        #expect((retards.last ?? .infinity) < 500)
        await client.arreter()
    }

    @Test(.enabled(if: bancActif), .timeLimit(.minutes(2)))
    func identiteNonApparieeEstRefuseeParLeNoeud() async throws {
        let banc = try await preparerBanc()
        var etat = try await ClientAiguilleur.appairer(
            adresse: try urlBanc(banc), code: banc.codeIntrus, nom: "intrus-banc", graines: .generer()
        )
        etat.noeud = banc.noeud
        etat.identiteNoeud = Chiffrement.Identites.exporter(try GrainesIdentite.generer().identite().publique)
        let rec = Enregistreur()
        let client = ClientAiguilleur(
            etat: etat, graines: .generer(), nomAppareil: "intrus-banc",
            surEtat: { await rec.noterEtat($0) }, surLien: { await rec.noterLien($0) }
        )
        await client.demarrer()
        try await rec.attendreLien(secondes: 30) { $0 == .refuse("identité non appairée") }
        #expect(await rec.contient(.ouvert) == false)
        await client.arreter()
    }
}

/// Les heures d'émission « [epoch_ms] » portées par les deltas de la rafale du nœud de banc.
enum HorodatageBanc {
    static func lire(_ texte: String) -> [Double] {
        texte.split(separator: "]").compactMap { morceau in
            morceau.split(separator: "[").last.flatMap { Double($0) }
        }
    }
}

private func urlBanc(_ banc: DescriptionBanc) throws -> URL {
    guard let url = URL(string: banc.adresse) else { throw ErreurAiguilleur("adresse du banc illisible") }
    return url
}
