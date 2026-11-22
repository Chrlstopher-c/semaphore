import Foundation
import Testing
@testable import VigieNoyau

@Test func unEchantillonCoupeEntreDeuxMorceauxEstRecolle() {
    var decodeur = DecodeurPCM()
    // 0, 16384 (0x4000) et -32768 (0x8000), en little-endian
    let octets: [UInt8] = [0x00, 0x00, 0x00, 0x40, 0x00, 0x80]
    #expect(decodeur.ajouter(Data(octets[0..<3])) == [0.0])
    #expect(decodeur.enAttente == 1)
    #expect(decodeur.ajouter(Data(octets[3...])) == [0.5, -1.0])
    #expect(decodeur.enAttente == 0)
}

@Test func unDecoupageOctetParOctetDonneLeMemeSignal() {
    let echantillons: [Int16] = [1, -1, 12345, -12345, 32767, -32768, 0]
    var octets = Data()
    for echantillon in echantillons {
        withUnsafeBytes(of: echantillon.littleEndian) { octets.append(contentsOf: $0) }
    }
    var decodeur = DecodeurPCM()
    var sortie: [Float] = []
    for i in octets.indices {
        sortie += decodeur.ajouter(Data([octets[i]]))
    }
    #expect(sortie == echantillons.map { Float($0) / 32768 })
    #expect(decodeur.enAttente == 0)
}
