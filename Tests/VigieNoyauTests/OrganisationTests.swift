import Foundation
import Testing
@testable import VigieNoyau

private let maintenant = DateRelative.date("2026-11-22T12:00:00Z")!

private func session(_ id: String, machine: String = "tour", epinglee: Bool = false, archivee: Bool = false,
                     majLe: String = "2026-11-22T10:00:00Z") throws -> Session {
    let json = """
    {"id":"\(id)","machine":"\(machine)","projet":{"machine":"\(machine)","chemin":"/p","nom":"p"},"cwd":"/p",
    "titre":"Titre \(id)","modele":"m","compte":"c","autonomie":false,"statut":"attente",
    "contexte":{"tokens":1,"max":10},"etapes":0,"compactions":0,"tmux":"cc","attachee":false,"pilotee":true,
    "epinglee":\(epinglee),"archivee":\(archivee),"creeLe":"2026-11-01T08:00:00Z","majLe":"\(majLe)"}
    """
    return try JSONDecoder().decode(Session.self, from: Data(json.utf8))
}

private func machine(_ id: String, enLigne: Bool, acces: String? = nil) throws -> Machine {
    let accesJSON = acces.map {
        ",\"acces\":{\"etat\":\"\($0)\",\"detail\":null,\"depuis\":\"2026-11-22T08:00:00Z\"}"
    } ?? ""
    let json = """
    {"id":"\(id)","description":"","racines":[],"projets":[],"comptes":[],"version":"1",
    "derniereVue":"2026-11-22T10:00:00Z","enLigne":\(enLigne)\(accesJSON)}
    """
    return try JSONDecoder().decode(Machine.self, from: Data(json.utf8))
}

private func epinglees(_ ids: String...) throws -> [Session] {
    try ids.map { try session($0, epinglee: true) }
}

@Test func uneSyncGardeLesFavorisQuElleNePresentePas() throws {
    let org = Organisation.vide.fusionner(machine: "tour", sessions: try epinglees("a", "b"), maintenant: maintenant)
    let suite = org.fusionner(machine: "tour", sessions: [try session("b")], maintenant: maintenant + 600)
    #expect(suite.favoris.map(\.id) == ["a"])
}

@Test func uneSessionDesepingleeOuArchiveeSortDesFavoris() throws {
    let org = Organisation.vide.fusionner(machine: "tour", sessions: try epinglees("a", "b"), maintenant: maintenant)
    let suite = org.fusionner(machine: "tour", sessions: [try session("a", epinglee: true, archivee: true)],
                              maintenant: maintenant)
    #expect(suite.favoris.map(\.id) == ["b"])
}

@Test func unEchecNeTouchePasAuxFavoris() throws {
    let org = Organisation.vide.fusionner(machine: "tour", sessions: try epinglees("a"), maintenant: maintenant)
    let suite = org.echec("Liaison coupée", sur: ["tour", "pi"])
    #expect(suite.machines["tour"]?.favoris == org.machines["tour"]?.favoris)
    #expect(suite.machines["tour"]?.derniereSync == maintenant)
    #expect(suite.machines["tour"]?.erreur == "Liaison coupée")
    #expect(suite.machines["pi"]?.erreur == "Liaison coupée")
    #expect(suite.machines["pi"]?.favoris.isEmpty == true)
}

@Test func uneSyncReussieEffaceLErreur() throws {
    let echoue = Organisation.vide.echec("Relais injoignable", sur: ["tour"])
    let suite = echoue.fusionner(machine: "tour", sessions: [], maintenant: maintenant)
    #expect(suite.machines["tour"]?.erreur == nil)
    #expect(suite.machines["tour"]?.derniereSync == maintenant)
}

@Test func laDateDeSyncNeSEcritPasToutesLesSecondes() {
    let premiere = Organisation.vide.fusionner(machine: "tour", sessions: [], maintenant: maintenant)
    let vite = premiere.fusionner(machine: "tour", sessions: [], maintenant: maintenant + 20)
    #expect(vite.machines["tour"]?.derniereSync == maintenant)
    let tard = vite.fusionner(machine: "tour", sessions: [], maintenant: maintenant + 90)
    #expect(tard.machines["tour"]?.derniereSync == maintenant + 90)
}

@Test func uneSessionNonEpingleeNeCreePasDeMachine() throws {
    let suite = Organisation.vide.fusionner(machine: "tour", sessions: [try session("a")], maintenant: nil)
    #expect(suite == .vide)
}

@Test func uneSessionSupprimeeNerestePasFavorite() throws {
    let org = Organisation.vide.fusionner(machine: "tour", sessions: try epinglees("a", "b"), maintenant: maintenant)
    #expect(org.oublier("a").favoris.map(\.id) == ["b"])
}

@Test func etatDUneMachineSelonLeRelais() throws {
    let entree = Organisation.Machine(favoris: [], derniereSync: maintenant, erreur: nil)
    let enLigne = try machine("tour", enLigne: true)
    let horsLigne = try machine("tour", enLigne: false)
    let injoignable = try machine("tour", enLigne: true, acces: "injoignable")
    #expect(EtatSynchro.de(machine: horsLigne, entree: entree, relaisJoint: true)
        == .horsLigne(vue: DateRelative.date("2026-11-22T10:00:00Z")))
    #expect(EtatSynchro.de(machine: injoignable, entree: entree, relaisJoint: true) == .neRepondPas)
    #expect(EtatSynchro.de(machine: enLigne, entree: entree, relaisJoint: true) == .aJour(depuis: maintenant))
    #expect(EtatSynchro.de(machine: enLigne, entree: nil, relaisJoint: true) == .jamais)
    #expect(EtatSynchro.de(machine: enLigne, entree: entree, relaisJoint: false) == .ancienne(depuis: maintenant))
    #expect(EtatSynchro.de(machine: nil, entree: nil, relaisJoint: false) == .jamais)
}

@Test func libellesDeSynchro() {
    #expect(EtatSynchro.aJour(depuis: maintenant - 300).libelle(maintenant: maintenant) == "à jour il y a 5 min")
    #expect(EtatSynchro.aJour(depuis: maintenant - 10).libelle(maintenant: maintenant) == "à jour à l’instant")
    #expect(EtatSynchro.horsLigne(vue: maintenant - 7200).libelle(maintenant: maintenant)
        == "hors ligne · vue il y a 2 h")
    #expect(EtatSynchro.horsLigne(vue: nil).libelle(maintenant: maintenant) == "hors ligne")
    #expect(EtatSynchro.neRepondPas.libelle(maintenant: maintenant) == "ne répond pas")
    #expect(EtatSynchro.jamais.libelle(maintenant: maintenant) == "jamais synchronisée")
    #expect(EtatSynchro.ancienne(depuis: maintenant - 300).libelle(maintenant: maintenant)
        == "dernière synchro il y a 5 min")
}

private func dossierTemporaire() throws -> URL {
    let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("organisation-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
    return dossier
}

@Test func lOrganisationSeRelitApresUnRedemarrage() throws {
    let dossier = try dossierTemporaire()
    defer { try? FileManager.default.removeItem(at: dossier) }
    let stockage = StockageOrganisation(fichier: dossier.appendingPathComponent("organisation.json"))
    #expect(stockage.lire() == .vide)
    let org = Organisation.vide.fusionner(machine: "tour", sessions: try epinglees("a"), maintenant: maintenant)
    #expect(stockage.ecrire(org))
    #expect(StockageOrganisation(fichier: stockage.fichier).lire() == org)
}

@Test func unFichierIllisibleEstMisDeCoteSansEtreEcrase() throws {
    let dossier = try dossierTemporaire()
    defer { try? FileManager.default.removeItem(at: dossier) }
    let stockage = StockageOrganisation(fichier: dossier.appendingPathComponent("organisation.json"))
    try Data("pas du json".utf8).write(to: stockage.fichier)
    #expect(stockage.lire() == .vide)
    #expect(FileManager.default.fileExists(atPath: stockage.fichier.path) == false)
    #expect(FileManager.default.fileExists(atPath: stockage.fichier.path + ".illisible"))
}

@Test func uneVersionPlusRecenteEstMiseDeCote() throws {
    let dossier = try dossierTemporaire()
    defer { try? FileManager.default.removeItem(at: dossier) }
    let stockage = StockageOrganisation(fichier: dossier.appendingPathComponent("organisation.json"))
    let futur = Organisation(version: Organisation.versionCourante + 1, machines: [:])
    #expect(stockage.ecrire(futur))
    #expect(stockage.lire() == .vide)
    #expect(FileManager.default.fileExists(atPath: stockage.fichier.path + ".illisible"))
}
