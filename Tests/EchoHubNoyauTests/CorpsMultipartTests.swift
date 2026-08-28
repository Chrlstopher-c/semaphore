import XCTest
@testable import EchoHubNoyau

/// Le format `multipart/form-data` est écrit à la main : ce projet s'interdit
/// toute dépendance externe, et `URLSession` n'en fabrique aucun. Dix lignes,
/// et aucune tolérance — une terminaison en `\n` au lieu de `\r\n` fait rendre
/// un 422 par un serveur qui ne dira jamais pourquoi.
final class CorpsMultipartTests: XCTestCase {

    private func texte(_ corps: CorpsMultipart) -> String {
        String(decoding: corps.terminer(), as: UTF8.self)
    }

    func testLeTypeContenuPorteLaFrontiere() {
        let corps = CorpsMultipart(frontiere: "XYZ")
        XCTAssertEqual(corps.typeContenu, "multipart/form-data; boundary=XYZ")
    }

    func testUnChampSimple() {
        var corps = CorpsMultipart(frontiere: "XYZ")
        corps.champ("origine", "utilisateur")
        XCTAssertEqual(
            texte(corps),
            "--XYZ\r\nContent-Disposition: form-data; name=\"origine\"\r\n\r\n"
            + "utilisateur\r\n--XYZ--\r\n"
        )
    }

    func testUnFichierPorteSonNomEtSonType() {
        var corps = CorpsMultipart(frontiere: "XYZ")
        corps.fichier("fichier", nomFichier: "photo.jpg", typeMime: "image/jpeg", octets: Data("ab".utf8))
        XCTAssertEqual(
            texte(corps),
            "--XYZ\r\nContent-Disposition: form-data; name=\"fichier\"; filename=\"photo.jpg\"\r\n"
            + "Content-Type: image/jpeg\r\n\r\nab\r\n--XYZ--\r\n"
        )
    }

    /// Sans les deux tirets finaux, le serveur attend indéfiniment une partie
    /// de plus — et le symptôme est un délai d'attente, pas une erreur.
    func testLaFrontiereDeClotureEstFermeeParDeuxTirets() {
        XCTAssertTrue(texte(CorpsMultipart(frontiere: "XYZ")).hasSuffix("--XYZ--\r\n"))
    }

    /// Un guillemet dans un nom de fichier fermerait l'attribut en plein milieu,
    /// et le serveur lirait un nom tronqué — ou refuserait la partie entière.
    func testUnGuillemetDansLeNomNeCassePasLenTete() {
        var corps = CorpsMultipart(frontiere: "XYZ")
        corps.fichier("f", nomFichier: "mon\"fichier\".png", typeMime: "image/png", octets: Data())
        XCTAssertTrue(texte(corps).contains("filename=\"mon'fichier'.png\""))
    }

    func testUnSautDeLigneDansLeNomEstNeutralise() {
        var corps = CorpsMultipart(frontiere: "XYZ")
        corps.fichier("f", nomFichier: "a\r\nb.png", typeMime: "image/png", octets: Data())
        XCTAssertTrue(texte(corps).contains("filename=\"a  b.png\""))
    }

    /// Les octets ne passent JAMAIS par une `String` : un PNG contient des
    /// séquences qui ne sont pas de l'UTF-8 valide, et les décoder les
    /// remplacerait par des « � » silencieusement.
    func testLesOctetsBrutsTraversentIntacts() {
        var corps = CorpsMultipart(frontiere: "XYZ")
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0xFF, 0xFE, 0x00, 0x01])
        corps.fichier("f", nomFichier: "x.png", typeMime: "image/png", octets: png)
        let produit = corps.terminer()
        XCTAssertNotNil(produit.range(of: png))
    }

    func testChampsEtFichierSEnchainentDansLOrdre() {
        var corps = CorpsMultipart(frontiere: "XYZ")
        corps.champ("origine", "utilisateur")
        corps.fichier("fichier", nomFichier: "n.txt", typeMime: "text/plain", octets: Data("z".utf8))
        let produit = texte(corps)
        let rangOrigine = produit.range(of: "origine")?.lowerBound
        let rangFichier = produit.range(of: "n.txt")?.lowerBound
        XCTAssertNotNil(rangOrigine)
        XCTAssertNotNil(rangFichier)
        XCTAssertTrue(rangOrigine! < rangFichier!)
    }

    /// La frontière par défaut est aléatoire : elle ne doit apparaître dans
    /// aucune partie, et un octet de photo peut contenir n'importe quoi.
    func testLaFrontiereParDefautNEstPasConstante() {
        XCTAssertNotEqual(CorpsMultipart().frontiere, CorpsMultipart().frontiere)
    }
}
