import Foundation
import Testing
@testable import VigieNoyau

// Banc réel du téléphone chef (banc/lancer-banc.sh avec BANC_SCRIPT=banc-chef.ts) : un aiguilleur Quart et deux
// nœuds sur 127.0.0.1 — le portable (chef) et la tour (non chef). Le premier iPhone, nommé chef par le portable, se
// relie à la tour : il signe une charte (acceptée par la tour, relayée au portable) et un ordre de pause pour le
// portable (relayé par la tour, vérifié par le portable). Le second iPhone, membre non chef, est refusé par le nœud
// même quand il contourne la garde du client. Désactivé hors banc (QUART_AIGUILLEUR_BANC).

private struct BancChef: Decodable {
    let adresse: String
    let codeAppareil: String
    let codeAppareil2: String
    let noeud: String
    let tour: String
}

private struct EtatBanc: Decodable {
    let portable: Int
    let tour: Int
    let pausePortable: Bool
}

private let bancChefActif = ProcessInfo.processInfo.environment["QUART_AIGUILLEUR_BANC"] != nil

private func chargerBancChef() throws -> BancChef {
    guard let chemin = ProcessInfo.processInfo.environment["QUART_AIGUILLEUR_BANC"] else {
        throw ErreurAiguilleur("QUART_AIGUILLEUR_BANC absent")
    }
    return try JSONDecoder().decode(BancChef.self, from: Data(contentsOf: URL(fileURLWithPath: chemin)))
}

/// Un iPhone appairé par code, lien ouvert ; rend le client de l'aiguilleur et celui du réseau.
private func iphone(
    _ banc: BancChef, code: String, nom: String, prefere: String? = nil, accepte: (() async throws -> Void)? = nil
) async throws -> (ClientAiguilleur, ClientReseau) {
    guard let url = URL(string: banc.adresse) else { throw ErreurAiguilleur("adresse du banc illisible") }
    let graines = GrainesIdentite.generer()
    var etat = try await ClientAiguilleur.appairer(adresse: url, code: code, nom: nom, graines: graines)
    etat.prefere = prefere
    let rec = Enregistreur()
    let client = ClientAiguilleur(
        etat: etat, graines: graines, nomAppareil: nom,
        surEtat: { await rec.noterEtat($0) }, surLien: { await rec.noterLien($0) }
    )
    await client.demarrer()
    if let accepte {
        try await rec.attendreLien(secondes: 30) { if case .attenteAccord = $0 { return true } else { return false } }
        try await accepte()
    }
    try await rec.attendreLien(secondes: 30) { $0 == .ouvert }
    let reseau = ClientReseau(
        requete: { m, c, b in try await client.requete(methode: m, chemin: c, corps: b) },
        signataire: client, gardee: nil, garder: { _ in })
    return (client, reseau)
}

private func etatBanc(_ client: ClientAiguilleur) async throws -> EtatBanc {
    let r = try await client.requete(methode: "GET", chemin: "/api/banc/etat", corps: nil)
    return try JSONDecoder().decode(EtatBanc.self, from: Data(r.corps.utf8))
}

/// Attend qu'une condition asynchrone soit vraie (pas de 200 ms), ou échoue au bout du délai.
private func jusqua(_ secondes: Double, _ condition: () async throws -> Bool) async throws {
    let fin = Date().addingTimeInterval(secondes)
    while Date() < fin {
        if (try? await condition()) == true { return }
        try await Task.sleep(for: .milliseconds(200))
    }
    throw ErreurAiguilleur("délai dépassé")
}

@Suite(.serialized)
struct ChefBancTests {
    @Test(.enabled(if: bancChefActif), .timeLimit(.minutes(3)))
    func chefSigneParUnNoeudNonChefEtUnMembreNonChefEstRefuse() async throws {
        let banc = try chargerBancChef()
        let (chef, reseauChef) = try await iphone(banc, code: banc.codeAppareil, nom: "iphone-chef")
        try await jusqua(30) { try await reseauChef.charte().digne }

        // Le chef passe par la tour (non chef) : elle l'accepte d'office, il est membre de la charte.
        await chef.prefererNoeud(banc.tour)
        try await jusqua(30) {
            let vue = try await reseauChef.charte()
            return vue.noeud == banc.tour && vue.digne
        }
        #expect(try await reseauChef.charte().charte?.estChef(banc.tour) == false)

        // Charte signée par l'iPhone, adoptée par la tour puis par le portable (vérifiée par chacun).
        var avant = try await reseauChef.charte().charte?.version ?? 0
        let vue = try await reseauChef.editer { c, moi, le in
            try EditionCharte.changerMembre(c, auteur: moi, membre: banc.tour,
                                            droits: DroitsMembre(voir: true, piloter: true, lancer: true,
                                                                 remoteControl: false),
                                            compte: nil, nom: nil, le: le)
        }
        #expect(vue.charte?.version == avant + 1)
        let signataire = await chef.membreSignataire()
        #expect(vue.charte?.par == signataire)
        try await jusqua(15) {
            let e = try await etatBanc(chef)
            return e.portable == avant + 1 && e.tour == avant + 1
        }

        // Ordre signé : pause du portable, relayée par la tour, vérifiée par le portable dans sa charte.
        try await reseauChef.agir(.pause, sur: banc.noeud)
        try await jusqua(15) { try await etatBanc(chef).pausePortable }
        try await reseauChef.agir(.reprendre, sur: banc.noeud)
        try await jusqua(15) { !(try await etatBanc(chef).pausePortable) }

        // Un nouvel iPhone demande à la tour (non chef) : le chef l'accepte en signant la charte qui le contient.
        let (intrus, reseauIntrus) = try await iphone(
            banc, code: banc.codeAppareil2, nom: "iphone-membre", prefere: banc.tour
        ) {
            var demande: DemandeReseau?
            try await jusqua(30) {
                demande = try await reseauChef.demandes().first { $0.nom == "iphone-membre" }
                return demande != nil
            }
            let d = try #require(demande)
            #expect(d.empreinte?.isEmpty == false)
            _ = try await reseauChef.accepter(d, comme: .membre(.telephone))
        }
        avant += 1

        // Ce membre non chef : la garde du client refuse, et le nœud refuse le contournement.
        try await jusqua(30) { try await reseauIntrus.charte().charte?.membre(await intrus.membreSignataire()) != nil }
        let vueIntrus = try await reseauIntrus.charte()
        #expect(vueIntrus.chef == false)
        await #expect(throws: ErreurReseau.self) {
            _ = try await reseauIntrus.editer { c, moi, le in
                try EditionCharte.nommerChef(c, auteur: moi, membre: moi, chef: true, le: le)
            }
        }
        try await contournementRefuse(intrus, vueIntrus, banc: banc)

        let apres = try await etatBanc(chef)
        #expect(apres.portable == avant + 1 && apres.tour == avant + 1)
        #expect(apres.pausePortable == false)
        await intrus.arreter()
        await chef.arreter()
    }

    /// L'intrus signe lui-même (charte où il se nomme chef, ordre de pause) et poste en direct : 403 du nœud.
    private func contournementRefuse(_ intrus: ClientAiguilleur, _ vue: VueCharte, banc: BancChef) async throws {
        let charte = try #require(vue.charte)
        let moi = await intrus.membreSignataire()
        guard case .objet(var brut) = charte.brut else { throw ErreurAiguilleur("charte illisible") }
        brut["version"] = .nombre(Double(charte.version + 1))
        brut["par"] = .texte(moi)
        brut["chefs"] = .tableau((charte.chefs + [moi]).map { .texte($0) })
        let forgee = try CharteReseau(brut: .objet(brut))
        let signee = try await SignatureReseau.signerCharte(forgee, par: intrus)
        let corps = try ValeurJSON.objet(["texte": .texte(signee.texte), "signature": .texte(signee.signature)])
            .texteJSON()
        let r1 = try await intrus.requete(methode: "POST", chemin: "/api/reseau/telephone/charte", corps: corps)
        #expect(r1.statut == 403)

        let ordre = try await SignatureReseau.signerOrdre(
            reseau: charte.reseau, cible: banc.noeud, action: .pause, par: intrus, le: EditionCharte.horodatage())
        let corpsOrdre = try ValeurJSON.objet([
            "ordre": .objet(["texte": .texte(ordre.texte), "signature": .texte(ordre.signature)]),
        ]).texteJSON()
        let r2 = try await intrus.requete(
            methode: "POST", chemin: "/api/reseau/telephone/machines/\(banc.noeud)/action", corps: corpsOrdre)
        #expect(r2.statut == 403)
    }
}
