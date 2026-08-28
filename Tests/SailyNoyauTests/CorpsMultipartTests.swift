import XCTest
@testable import SailyNoyau

/// Le corps `multipart/form-data` de `POST /api/blobs` est écrit à la main :
/// aucune dépendance externe, aucune tolérance. Une terminaison en `\n` au lieu
/// de `\r\n` fait rendre un 400 que le serveur n'explique jamais.
final class CorpsMultipartTests: XCTestCase {

    private func texte(_ corps: CorpsMultipart) -> String {
        String(decoding: corps.terminer(), as: UTF8.self)
    }

    func testLeTypeContenuPorteLaFrontiere() {
        XCTAssertEqual(
            CorpsMultipart(frontiere: "XYZ").typeContenu,
            "multipart/form-data; boundary=XYZ"
        )
    }

    func testUnFichierPorteSonNomEtSonType() {
        var corps = CorpsMultipart(frontiere: "XYZ")
        corps.fichier("file", nomFichier: "photo.jpg", typeMime: "image/jpeg", octets: Data("ab".utf8))
        XCTAssertEqual(
            texte(corps),
            "--XYZ\r\nContent-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n"
            + "Content-Type: image/jpeg\r\n\r\nab\r\n--XYZ--\r\n"
        )
    }

    func testLaClotureEstFermeeParDeuxTirets() {
        XCTAssertTrue(texte(CorpsMultipart(frontiere: "XYZ")).hasSuffix("--XYZ--\r\n"))
    }

    /// Les octets bruts d'un PNG contiennent des séquences non-UTF8 : ils ne
    /// doivent JAMAIS transiter par une `String`, qui les remplacerait par « � ».
    func testLesOctetsBrutsTraversentIntacts() {
        var corps = CorpsMultipart(frontiere: "XYZ")
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0xFF, 0xFE, 0x00, 0x01])
        corps.fichier("file", nomFichier: "x.png", typeMime: "image/png", octets: png)
        XCTAssertNotNil(corps.terminer().range(of: png))
    }

    func testUnGuillemetDansLeNomNeCassePasLenTete() {
        var corps = CorpsMultipart(frontiere: "XYZ")
        corps.fichier("file", nomFichier: "mon\"x\".png", typeMime: "image/png", octets: Data())
        XCTAssertTrue(texte(corps).contains("filename=\"mon'x'.png\""))
    }

    func testLaFrontiereParDefautNEstPasConstante() {
        XCTAssertNotEqual(CorpsMultipart().frontiere, CorpsMultipart().frontiere)
    }
}
