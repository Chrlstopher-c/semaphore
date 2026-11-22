import Foundation

#if canImport(CryptoKit)
    import CryptoKit
#else
    import Crypto
#endif

// Responsabilité : signer et vérifier la charte et les ordres du réseau (Ed25519, préfixes de domaine), et dire
// si une charte reçue est digne de confiance. Miroir de `commun/charte.ts` et de l'ordre signé.

/// Qui signe pour le téléphone : son identifiant de membre, son identité publique, et la signature Ed25519.
public protocol Signataire: Sendable {
    func membreSignataire() async -> String
    func identiteSignataire() async -> String?
    func signer(_ octets: Data) async throws -> Data
}

/// Charte signée : le texte JSON exact, et sa signature en base64url.
public struct CharteSignee: Codable, Sendable, Equatable {
    public let texte: String
    public let signature: String

    public init(texte: String, signature: String) {
        self.texte = texte
        self.signature = signature
    }
}

/// Ordre signé à destination d'une machine : le texte JSON exact, et sa signature en base64url.
public struct OrdreSigne: Codable, Sendable, Equatable {
    public let texte: String
    public let signature: String

    public init(texte: String, signature: String) {
        self.texte = texte
        self.signature = signature
    }
}

public enum SignatureReseau {
    public static let prefixeCharte = "lanterne-charte-v1\n"
    public static let prefixeOrdre = "lanterne-ordre-v1\n"

    /// Signe la charte : la signature couvre `prefixeCharte` suivi du texte JSON de `c.brut`.
    public static func signerCharte(_ c: CharteReseau, par s: Signataire) async throws -> CharteSignee {
        let texte = try c.brut.texteJSON()
        let signature = try await s.signer(octetsSignes(prefixeCharte, texte))
        return CharteSignee(texte: texte, signature: Chiffrement.Octets.versBase64url(signature))
    }

    /// Genèse : la charte est lisible, et sa signature tient avec la clé de `par` lue dans ce même texte.
    public static func verifier(_ s: CharteSignee) -> CharteReseau? {
        guard let c = lire(s), let identite = c.membre(c.par)?.identite, verifierSignature(identite, s) else {
            return nil
        }
        return c
    }

    /// Garde du téléphone : la charte reçue est vérifiée ET succède à la gardée. Sans gardée : la genèse.
    /// La succession exige qu'un chef de la gardée ait signé, avec la clé lue DANS la gardée (pas dans la reçue).
    public static func digne(recue: CharteSignee, gardee: CharteSignee?) -> CharteReseau? {
        guard let gardee else { return verifier(recue) }
        guard let neuve = lire(recue), let base = lire(gardee), neuve.reseau == base.reseau,
            neuve.version >= base.version, base.estChef(neuve.par), let identite = base.membre(neuve.par)?.identite,
            verifierSignature(identite, recue)
        else { return nil }
        return neuve
    }

    /// Chef ET avec sa propre identité : seul ce membre peut signer une édition depuis ce téléphone.
    public static func estChefDigne(_ c: CharteReseau, moi: String, identiteMoi: String?) -> Bool {
        guard let identiteMoi, c.estChef(moi), let membre = c.membre(moi) else { return false }
        return membre.identite == identiteMoi
    }

    /// Ordre signé pour une machine : le texte JSON porte réseau, cible, action, signataire, date et nonce.
    public static func signerOrdre(
        reseau: String, cible: String, action: ActionMachine, par s: Signataire, le: String, nonce: String? = nil
    ) async throws -> OrdreSigne {
        let membre = await s.membreSignataire()
        let texte = try ValeurJSON.objet([
            "format": .nombre(1), "reseau": .texte(reseau), "cible": .texte(cible), "action": .texte(action.rawValue),
            "par": .texte(membre), "le": .texte(le), "nonce": .texte(nonce ?? nonceAleatoire()),
        ]).texteJSON()
        let signature = try await s.signer(octetsSignes(prefixeOrdre, texte))
        return OrdreSigne(texte: texte, signature: Chiffrement.Octets.versBase64url(signature))
    }

    // MARK: - Internes

    private static func octetsSignes(_ prefixe: String, _ texte: String) -> Data { Data((prefixe + texte).utf8) }

    /// Lecture d'une charte signée ; un texte illisible est refusé et tracé (jamais accepté par défaut).
    private static func lire(_ s: CharteSignee) -> CharteReseau? {
        do { return try CharteReseau(texte: s.texte) } catch {
            Trace.detail("reseau", "charte non lue : \(error)")
            return nil
        }
    }

    private static func verifierSignature(_ identite: String, _ s: CharteSignee) -> Bool {
        do {
            let publique = try Chiffrement.Identites.importer(identite)
            let cle = try Curve25519.Signing.PublicKey(rawRepresentation: publique.signature)
            let signature = try Chiffrement.Octets.depuisBase64url(s.signature, longueur: Chiffrement.tailleSignature)
            return cle.isValidSignature(signature, for: octetsSignes(prefixeCharte, s.texte))
        } catch {
            Trace.detail("reseau", "signature de charte refusée : \(error)")
            return false
        }
    }

    /// 16 octets aléatoires en hexadécimal minuscule : 32 caractères.
    private static func nonceAleatoire() -> String {
        (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }
}
