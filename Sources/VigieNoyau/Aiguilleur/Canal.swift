import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// Responsabilité : canal chiffré après poignée — AES-256-GCM, un compteur par sens.
// Trame = compteur ‖ chiffré ‖ étiquette.
// Miroir de `commun/chiffrement/messages.ts`. Refus du rejeu, de la réordination, de la troncature, de l'altération
// et de la réflexion. Le transport doit être ordonné : une trame refusée rend le canal inutilisable.

extension Chiffrement {
    /// 1 = initiateur → répondeur, 2 = répondeur → initiateur.
    struct ParametresCanal {
        let nom: String
        let cleEnvoi: SymmetricKey
        let sensEnvoi: UInt8
        let cleReception: SymmetricKey
        let sensReception: UInt8
    }

    actor Canal {
        private static let limiteCompteur: UInt64 = 9_007_199_254_740_991
        private let parametres: ParametresCanal
        private let nomOctets: Data
        private var envoi: UInt64 = 0
        private var attendu: UInt64 = 0

        init(_ parametres: ParametresCanal) {
            self.parametres = parametres
            nomOctets = Data(parametres.nom.utf8)
        }

        func chiffrer(_ clair: Data) throws -> Data {
            guard envoi < Canal.limiteCompteur else {
                throw ErreurChiffrement("canal épuisé : ouvrir une nouvelle poignée")
            }
            let entete = Octets.compteur(envoi)
            envoi += 1
            do {
                let scelle = try AES.GCM.seal(
                    clair,
                    using: parametres.cleEnvoi,
                    nonce: try nonce(entete),
                    authenticating: donneesAssociees(parametres.sensEnvoi, entete)
                )
                return entete + scelle.ciphertext + scelle.tag
            } catch {
                throw ErreurChiffrement("chiffrement refusé : \(error)")
            }
        }

        func dechiffrer(_ trame: Data) throws -> Data {
            guard trame.count >= tailleCompteur + tailleEtiquette else { throw ErreurChiffrement("trame tronquée") }
            let recu = Octets.lireCompteur(trame)
            guard recu >= attendu else { throw ErreurChiffrement("trame rejouée refusée") }
            guard recu == attendu else { throw ErreurChiffrement("trame réordonnée ou manquante : refusée") }
            attendu += 1
            let entete = Data(trame.prefix(tailleCompteur))
            let chiffre = Data(trame.dropFirst(tailleCompteur).dropLast(tailleEtiquette))
            let etiquette = Data(trame.suffix(tailleEtiquette))
            do {
                let boite = try AES.GCM.SealedBox(nonce: try nonce(entete), ciphertext: chiffre, tag: etiquette)
                return try AES.GCM.open(
                    boite,
                    using: parametres.cleReception,
                    authenticating: donneesAssociees(parametres.sensReception, entete)
                )
            } catch {
                throw ErreurChiffrement("trame altérée : authentification échouée")
            }
        }

        /// Nonce de 96 bits : quatre octets nuls puis le compteur.
        private func nonce(_ entete: Data) throws -> AES.GCM.Nonce {
            try AES.GCM.Nonce(data: Data(repeating: 0, count: 12 - tailleCompteur) + entete)
        }

        /// Données associées : nom du canal, sens de la trame, compteur.
        private func donneesAssociees(_ sens: UInt8, _ entete: Data) -> Data {
            nomOctets + Data([sens]) + entete
        }
    }
}
