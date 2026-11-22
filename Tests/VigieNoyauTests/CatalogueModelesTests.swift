import Testing
@testable import VigieNoyau

@Test func nomLisibleDUnIdentifiantDeModele() {
    #expect(CatalogueModeles.nom(id: "claude-opus-5-5") == "Opus 5.5")
    #expect(CatalogueModeles.nom(id: "claude-opus-5-5[1m]") == "Opus 5.5")
    #expect(CatalogueModeles.nom(id: "claude-sonnet-5") == "Sonnet 5")
    #expect(CatalogueModeles.nom(id: "claude-haiku-4-5-20251001") == "Haiku 4.5")
    #expect(CatalogueModeles.nom(id: "opus") == "Opus")
    #expect(CatalogueModeles.nom(id: "") == "")
}

@Test func libellesDEffort() {
    #expect(CatalogueModeles.libelleEffort(.medium) == "Moyen")
    #expect(CatalogueModeles.libelleEffort(.xhigh) == "Très élevé")
    #expect(CatalogueModeles.libelleEffort(nil) == nil)
}
