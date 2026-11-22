import Foundation

// Responsabilité : réunir un corps arrivé en morceaux (miroir de `relais/federation/transferts.ts` côté Quart) —
// morceaux numérotés à partir de 0 sous une référence, réunis une fois le nombre annoncé atteint. Un rang hors
// ordre ou une référence en trop abandonne le transfert ; rien n'est rendu à moitié.

struct ReassemblageMorceaux: Sendable {
    /// Au plus ce nombre de transferts en route à la fois (comme le relais) et ce volume total de caractères.
    static let transfertsMax = 16
    static let caracteresMax = 16 * 1024 * 1024

    private var enRoute: [String: [String]] = [:]
    private var volume: [String: Int] = [:]

    /// Un morceau dans l'ordre et sous les bornes ; faux si le transfert est abandonné.
    mutating func recevoir(ref: String, rang: Int, corps: String) -> Bool {
        var morceaux = enRoute[ref] ?? []
        if enRoute[ref] == nil {
            guard rang == 0, enRoute.count < ReassemblageMorceaux.transfertsMax else { return false }
        }
        let total = (volume[ref] ?? 0) + corps.count
        guard rang == morceaux.count, total <= ReassemblageMorceaux.caracteresMax else {
            abandonner(ref)
            return false
        }
        morceaux.append(corps)
        enRoute[ref] = morceaux
        volume[ref] = total
        return true
    }

    /// Le corps réuni, si les `nombre` morceaux sont là ; le transfert est effacé dans tous les cas.
    mutating func assembler(ref: String, nombre: Int) -> String? {
        let morceaux = enRoute[ref]
        abandonner(ref)
        guard let morceaux, morceaux.count == nombre else { return nil }
        return morceaux.joined()
    }

    /// Lien perdu : les transferts en route tombent.
    mutating func vider() {
        enRoute = [:]
        volume = [:]
    }

    private mutating func abandonner(_ ref: String) {
        enRoute[ref] = nil
        volume[ref] = nil
    }
}

/// Découpage d'un corps à émettre : rien s'il tient dans une trame, sinon des morceaux de 4 096 caractères, coupés
/// entre deux caractères. Des trames courtes : une trame de plus de ~16 Ko est tronquée par URLSession hors iOS.
enum DecoupeMorceaux {
    static let tailleCaracteres = 4_096

    static func de(_ texte: String) -> [String] {
        guard texte.utf8.count > tailleCaracteres else { return [] }
        var sortie: [String] = []
        var courant = String.UnicodeScalarView()
        var nombre = 0
        for scalaire in texte.unicodeScalars {
            courant.append(scalaire)
            nombre += 1
            if nombre == tailleCaracteres {
                sortie.append(String(courant))
                courant = String.UnicodeScalarView()
                nombre = 0
            }
        }
        if !courant.isEmpty { sortie.append(String(courant)) }
        return sortie
    }
}
