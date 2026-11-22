import Foundation
import Testing

@testable import VigieNoyau

// Le client du réseau contre un nœud factice : la charte se relit depuis son texte signé, l'édition n'est
// postée que par une charte digne, les machines, ajouts, demandes et activité se décodent, un refus reste lisible.

/// Un nœud factice : garde les requêtes reçues et les postes de charte, et répond à la charte courante.
actor FauxNoeud {
    private(set) var recues: [String] = []
    private(set) var postes: [CharteSignee] = []
    private var courante: CharteSignee

    init(courante: CharteSignee) { self.courante = courante }

    func repondre(_ methode: String, _ chemin: String, _ corps: String?) throws -> ReponseRequete {
        recues.append("\(methode) \(chemin)")
        if methode == "GET" && chemin.hasSuffix("/charte") {
            return ReponseRequete(statut: 200, corps: try corpsCharte(courante))
        }
        if methode == "POST" && chemin.hasSuffix("/charte"), let corps {
            let lu = try ValeurJSON.lire(corps)
            guard case .texte(let texte)? = lu["texte"], case .texte(let signature)? = lu["signature"] else {
                return ReponseRequete(statut: 400, corps: "{\"erreur\":\"corps invalide\"}")
            }
            let nouvelle = CharteSignee(texte: texte, signature: signature)
            postes.append(nouvelle)
            courante = nouvelle
            return ReponseRequete(statut: 200, corps: try corpsCharte(nouvelle))
        }
        return ReponseRequete(statut: 200, corps: "{}")
    }

    private func corpsCharte(_ signee: CharteSignee) throws -> String {
        try ValeurJSON.objet([
            "signee": .objet(["texte": .texte(signee.texte), "signature": .texte(signee.signature)]),
            "noeud": .texte("noeud-test"), "appareil": .texte("appareil-test"), "chef": .booleen(true),
        ]).texteJSON()
    }
}

private func clientPour(_ faux: FauxNoeud, membre: String, cle: Chiffrement.Identite) -> ClientReseau {
    ClientReseau(
        requete: { methode, chemin, corps in try await faux.repondre(methode, chemin, corps) },
        signataire: SignataireTest(membre: membre, cle: cle), gardee: nil, garder: { _ in })
}

private func identiteNeuve() -> String { Chiffrement.Identites.exporter(Chiffrement.Identite.generer().publique) }

struct ClientReseauTests {
    @Test func editerPosteUneChartePourLaVersionSuivanteSigneeParLeChef() async throws {
        let cle = Chiffrement.Identite.generer()
        let brut = FabriqueCharte.base(
            chef: cle, serveur: Chiffrement.Identite.generer(), pair: Chiffrement.Identite.generer())
        let faux = FauxNoeud(courante: try await FabriqueCharte.signer(brut, par: cle))
        let client = clientPour(faux, membre: FabriqueCharte.chef, cle: cle)
        let nouvelId = "c0ffee000004"
        let identite = identiteNeuve()
        let vue = try await client.editer { c, moi, le in
            try EditionCharte.ajouterMembre(
                c, auteur: moi, id: nouvelId, nom: "Neuf", sorte: .pair, identite: identite, le: le)
        }
        #expect(vue.digne)
        #expect(vue.charte?.version == 2)
        #expect(vue.charte?.par == FabriqueCharte.chef)
        #expect(vue.charte?.membre(nouvelId) != nil)
        let postes = await faux.postes
        let poste = try #require(postes.first)
        #expect(SignatureReseau.verifier(poste)?.version == 2)
    }

    @Test func editerRefuseUneChargeNonDigneSansRienEnvoyer() async throws {
        let cle = Chiffrement.Identite.generer()
        let brut = FabriqueCharte.base(
            chef: cle, serveur: Chiffrement.Identite.generer(), pair: Chiffrement.Identite.generer())
        let faux = FauxNoeud(courante: try await FabriqueCharte.signer(brut, par: cle))
        let client = clientPour(faux, membre: FabriqueCharte.pair, cle: Chiffrement.Identite.generer())
        do {
            _ = try await client.editer { c, moi, le in
                try EditionCharte.nommerChef(c, auteur: moi, membre: FabriqueCharte.pair, chef: true, le: le)
            }
            Issue.record("une édition a été acceptée sans charte digne")
        } catch let erreur as ErreurReseau { #expect(erreur.message == "charte non vérifiable : rien n'est signé") }
        let postes = await faux.postes
        #expect(postes.isEmpty)
    }

    @Test func agirEnvoieUnOrdreSigneVersLaMachine() async throws {
        let cle = Chiffrement.Identite.generer()
        let brut = FabriqueCharte.base(
            chef: cle, serveur: Chiffrement.Identite.generer(), pair: Chiffrement.Identite.generer())
        let faux = FauxNoeud(courante: try await FabriqueCharte.signer(brut, par: cle))
        let client = clientPour(faux, membre: FabriqueCharte.chef, cle: cle)
        try await client.agir(.pause, sur: FabriqueCharte.serveur)
        let recues = await faux.recues
        #expect(recues.contains("POST /api/reseau/telephone/machines/\(FabriqueCharte.serveur)/action"))
    }

    @Test func lesMachinesSeDecodentAvecUnEtatTolerant() async throws {
        let corps = """
            {"machines":[{"membre":"0f1e2d3c4b5a","nom":"Noeud test","moi":false,"enLigne":true,"etat":{"cpu":12.5,\
            "memoire":{"utilisee":1,"totale":4},"gpu":null,"fonctions":{"voix":"lancee","dictee":"arretee"},\
            "pause":false,"comptes":["a"],"compte":"a","peutArreter":true,"peutRedemarrer":false,\
            "reveilPossible":false,"le":"2026-11-22T10:00:00.000Z"}},\
            {"membre":"1111aaaa2222","nom":"Autre machine","moi":true,"enLigne":false}]}
            """
        let client = ClientReseau(
            requete: { _, _, _ in ReponseRequete(statut: 200, corps: corps) },
            signataire: SignataireTest(membre: FabriqueCharte.chef, cle: Chiffrement.Identite.generer()), gardee: nil,
            garder: { _ in })
        let machines = try await client.machines()
        #expect(machines.count == 2)
        #expect(machines[0].etat?.memoireUtilisee == 1)
        #expect(machines[0].etat?.gpu == [])
        #expect(machines[0].etat?.voix == "lancee")
        #expect(machines[1].etat == nil)
    }

    @Test func uneErreurDuNoeudPorteSonMessageEtSonStatut() async throws {
        let client = ClientReseau(
            requete: { _, _, _ in ReponseRequete(statut: 409, corps: "{\"erreur\":\"charte périmée\"}") },
            signataire: SignataireTest(membre: FabriqueCharte.chef, cle: Chiffrement.Identite.generer()), gardee: nil,
            garder: { _ in })
        do {
            _ = try await client.machines()
            Issue.record("une erreur 409 n'a pas été remontée")
        } catch let erreur as ErreurReseau {
            #expect(erreur.message == "charte périmée")
            #expect(erreur.statut == 409)
        }
    }

    @Test func lesAjoutsAcceptentLesDeuxFormes() async throws {
        let ajout = #"{"machine":"machine-test-2","nom":"Noeud test","etape":"code","etat":"en_cours"}"#
        for corps in ["[\(ajout)]", "{\"ajouts\":[\(ajout)]}"] {
            let client = ClientReseau(
                requete: { _, _, _ in ReponseRequete(statut: 200, corps: corps) },
                signataire: SignataireTest(membre: FabriqueCharte.chef, cle: Chiffrement.Identite.generer()),
                gardee: nil, garder: { _ in })
            let ajouts = try await client.ajouts()
            #expect(ajouts.map(\.id) == ["machine-test-2"])
        }
    }

    @Test func lEmpreinteDUneDemandeVientDeLIdentiteEtNonDuServeur() async throws {
        let identite = identiteNeuve()
        let corps = try ValeurJSON.objet([
            "demandes": .tableau([
                .objet([
                    "id": .texte("d1"), "membre": .texte("c0ffee000005"), "nom": .texte("Nouveau"),
                    "genre": .texte("meme_proprietaire"), "identite": .texte(identite),
                    "le": .texte(FabriqueCharte.date), "empreinte": .texte("FAUSSE"),
                ])
            ])
        ]).texteJSON()
        let client = ClientReseau(
            requete: { _, _, _ in ReponseRequete(statut: 200, corps: corps) },
            signataire: SignataireTest(membre: FabriqueCharte.chef, cle: Chiffrement.Identite.generer()), gardee: nil,
            garder: { _ in })
        let demandes = try await client.demandes()
        let attendue = Chiffrement.Identites.empreinte(try Chiffrement.Identites.importer(identite))
        #expect(demandes.first?.empreinte == attendue)
    }

    @Test func uneActiviteAbsenteRendNil() async throws {
        let client = ClientReseau(
            requete: { _, _, _ in ReponseRequete(statut: 200, corps: "{\"telemetrie\":false,\"activite\":null}") },
            signataire: SignataireTest(membre: FabriqueCharte.chef, cle: Chiffrement.Identite.generer()), gardee: nil,
            garder: { _ in })
        #expect(try await client.activite(invite: FabriqueCharte.invite) == nil)
    }
}
