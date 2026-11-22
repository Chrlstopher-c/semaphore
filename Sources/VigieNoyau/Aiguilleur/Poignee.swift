import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// Responsabilité : poignée de main d'un canal chiffré de bout en bout (initiateur → répondeur).
// Miroir exact de `commun/chiffrement/poignee.ts` (Noise IK simplifié, deux messages signés) :
// IKM = ee ‖ es ‖ se ‖ ss, sel = SHA-256(transcription), une clé AES-256 par sens.
// L'éphémère fixe n'est fourni que par les vecteurs croisés ; la production le tire au hasard.

extension Chiffrement {
    struct MessageInitial: Codable, Equatable, Sendable {
        let version: Int
        let canal: String
        let identite: String
        let ephemere: String
        let signature: String
    }

    struct MessageReponse: Codable, Equatable, Sendable {
        let ephemere: String
        let signature: String
    }

    /// État gardé par l'initiateur entre son message et la réponse du répondeur.
    struct AttentePoignee {
        let canal: String
        let moi: Identite
        let destinataire: IdentitePublique
        let ephemere: Curve25519.KeyAgreement.PrivateKey
        let ephemerePublique: Data
    }

    enum Poignee {
        static let version = 1
        static let libelleInitial = Data("lanterne-chiffrement/v1/initial".utf8)
        static let libelleReponse = Data("lanterne-chiffrement/v1/reponse".utf8)
        static let libelleCles = Data("lanterne-chiffrement/v1/cles".utf8)
        static let infoIR = Data("lanterne-chiffrement/v1/i>r".utf8)
        static let infoRI = Data("lanterne-chiffrement/v1/r>i".utf8)

        static func initier(
            moi: Identite,
            destinataire: IdentitePublique,
            canal: String,
            ephemere: Curve25519.KeyAgreement.PrivateKey? = nil
        ) throws -> (message: MessageInitial, attente: AttentePoignee) {
            let e = ephemere ?? Curve25519.KeyAgreement.PrivateKey()
            let eI = e.publicKey.rawRepresentation
            let c = ContexteChiffrement(canal: canal, idI: moi.publique, idR: destinataire, eI: eI, eR: nil)
            let signature = try moi.signaturePrivee.signature(for: transcriptionPoignee(libelleInitial, c))
            let message = MessageInitial(
                version: version,
                canal: canal,
                identite: Identites.exporter(moi.publique),
                ephemere: Octets.versBase64url(eI),
                signature: Octets.versBase64url(signature)
            )
            let attente = AttentePoignee(
                canal: canal, moi: moi, destinataire: destinataire, ephemere: e, ephemerePublique: eI
            )
            return (message, attente)
        }

        /// Répondeur : vérifie le premier message (identité acceptée, signature, canal) puis répond.
        static func repondre(
            moi: Identite,
            message: MessageInitial,
            accepte: (IdentitePublique) -> Bool,
            ephemere: Curve25519.KeyAgreement.PrivateKey? = nil
        ) throws -> (reponse: MessageReponse, canal: Canal) {
            guard message.version == version else { throw ErreurChiffrement("poignée : version non reconnue") }
            let idI = try Identites.importer(message.identite)
            guard accepte(idI) else { throw ErreurChiffrement("identité inconnue : poignée refusée") }
            let eI = try Octets.depuisBase64url(message.ephemere, longueur: tailleCleDh)
            let sigI = try Octets.depuisBase64url(message.signature, longueur: tailleSignature)
            let initial = ContexteChiffrement(canal: message.canal, idI: idI, idR: moi.publique, eI: eI, eR: nil)
            try verifierSignatureChiffree(idI.signature, sigI, transcriptionPoignee(libelleInitial, initial))
            let eR = ephemere ?? Curve25519.KeyAgreement.PrivateKey()
            let eRPublique = eR.publicKey.rawRepresentation
            let c = ContexteChiffrement(canal: message.canal, idI: idI, idR: moi.publique, eI: eI, eR: eRPublique)
            let ikm = try secretDhChiffre(eR, eI) + secretDhChiffre(moi.dhPrivee, eI)
                + secretDhChiffre(eR, idI.dh) + secretDhChiffre(moi.dhPrivee, idI.dh)
            let (ir, ri) = try clesSessionChiffrees(ikm, c)
            let signature = try moi.signaturePrivee.signature(for: transcriptionPoignee(libelleReponse, c))
            let reponse = MessageReponse(
                ephemere: Octets.versBase64url(eRPublique),
                signature: Octets.versBase64url(signature)
            )
            let canal = Canal(ParametresCanal(
                nom: message.canal, cleEnvoi: ri, sensEnvoi: 2, cleReception: ir, sensReception: 1
            ))
            return (reponse, canal)
        }

        /// Initiateur : vérifie la réponse signée par l'identité attendue, puis dérive le canal.
        static func terminer(attente: AttentePoignee, reponse: MessageReponse) throws -> Canal {
            let eR = try Octets.depuisBase64url(reponse.ephemere, longueur: tailleCleDh)
            let sigR = try Octets.depuisBase64url(reponse.signature, longueur: tailleSignature)
            let c = ContexteChiffrement(
                canal: attente.canal, idI: attente.moi.publique, idR: attente.destinataire,
                eI: attente.ephemerePublique, eR: eR
            )
            try verifierSignatureChiffree(attente.destinataire.signature, sigR, transcriptionPoignee(libelleReponse, c))
            let ikm = try secretDhChiffre(attente.ephemere, eR)
                + secretDhChiffre(attente.ephemere, attente.destinataire.dh)
                + secretDhChiffre(attente.moi.dhPrivee, eR)
                + secretDhChiffre(attente.moi.dhPrivee, attente.destinataire.dh)
            let (ir, ri) = try clesSessionChiffrees(ikm, c)
            return Canal(ParametresCanal(
                nom: attente.canal, cleEnvoi: ir, sensEnvoi: 1, cleReception: ri, sensReception: 2
            ))
        }
    }
}

private struct ContexteChiffrement {
    let canal: String
    let idI: Chiffrement.IdentitePublique
    let idR: Chiffrement.IdentitePublique
    let eI: Data
    let eR: Data?
}

/// Transcription : chaque élément à longueur préfixée, le libellé distingue les usages.
private func transcriptionPoignee(_ libelle: Data, _ c: ContexteChiffrement) -> Data {
    var morceaux = [libelle, Data(c.canal.utf8), c.idI.octets, c.idR.octets, c.eI]
    if let eR = c.eR { morceaux.append(eR) }
    return Chiffrement.Octets.transcription(morceaux)
}

private func verifierSignatureChiffree(_ cle: Data, _ signature: Data, _ donnees: Data) throws {
    let publique: Curve25519.Signing.PublicKey
    do {
        publique = try Curve25519.Signing.PublicKey(rawRepresentation: cle)
    } catch {
        throw ErreurChiffrement("clé de signature refusée : \(error)")
    }
    guard publique.isValidSignature(signature, for: donnees) else {
        throw ErreurChiffrement("signature de poignée fausse")
    }
}

private func secretDhChiffre(_ privee: Curve25519.KeyAgreement.PrivateKey, _ publique: Data) throws -> Data {
    do {
        let cible = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: publique)
        let secret = try privee.sharedSecretFromKeyAgreement(with: cible)
        return secret.withUnsafeBytes { Data($0) }
    } catch {
        throw ErreurChiffrement("échange X25519 refusé : \(error)")
    }
}

private func clesSessionChiffrees(
    _ ikm: Data, _ c: ContexteChiffrement
) throws -> (ir: SymmetricKey, ri: SymmetricKey) {
    let sel = Data(SHA256.hash(data: transcriptionPoignee(Chiffrement.Poignee.libelleCles, c)))
    let ir = HKDF<SHA256>.deriveKey(
        inputKeyMaterial: SymmetricKey(data: ikm), salt: sel, info: Chiffrement.Poignee.infoIR, outputByteCount: 32
    )
    let ri = HKDF<SHA256>.deriveKey(
        inputKeyMaterial: SymmetricKey(data: ikm), salt: sel, info: Chiffrement.Poignee.infoRI, outputByteCount: 32
    )
    return (ir, ri)
}
