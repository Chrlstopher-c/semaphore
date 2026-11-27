import Testing
@testable import EchoHubNoyau

@Suite("Artefacts")
struct ArtefactsTests {
    private func creation(_ version: Int, titre: String) -> String {
        "<outil><entree>creer_artefact(titre : \(titre))</entree><sortie>{\"artefact_id\": \"a1\", \"version\": \(version), \"titre\": \"\(titre)\", \"type\": \"html\", \"fichier_id\": \"f\(version)\", \"taille_octets\": 120}</sortie></outil>"
    }

    @Test func regroupeLesVersionsSousLaDerniere() {
        let catalogue = Artefacts.catalogue(["Voici." + creation(1, titre: "Page"), creation(2, titre: "Page v2") + creation(2, titre: "Page v2 bis")])
        #expect(catalogue.count == 1)
        #expect(catalogue.first?.versions.map(\.version) == [1, 2])
        #expect(catalogue.first?.titre == "Page v2 bis")
        #expect(catalogue.first?.versions.last?.fichierId == "f2")
        #expect(catalogue.first?.versions.first?.apercuPossible == true)
    }

    @Test func ignoreUneSortieQuiNEstPasUnArtefact() {
        let echec = "<outil><entree>creer_artefact(titre : x)</entree><sortie>Erreur : titre manquant</sortie></outil>"
        #expect(Artefacts.catalogue([echec]).isEmpty)
    }

    @Test func litUnFichierPresente() throws {
        let texte = "<outil><entree>presenter_fichier(chemin : logo.png)</entree><sortie>{\"fichier_id\": \"z\", \"nom_affiche\": \"logo.png\", \"type_mime\": \"image/png\", \"taille_octets\": 9, \"origine\": \"modele\"}</sortie></outil>"
        let segment = try #require(SegmenteurReponse.segmenter(texte).raisonnements.first)
        let appel = try #require(LectureAppel.lire(segment.texte, actif: false))
        #expect(Artefacts.presente(appel)?.estImage == true)
    }
}
