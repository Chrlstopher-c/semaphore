import Foundation

/// Ce qu'on AFFICHE d'un en-tête GGUF, lu dans le même document que celui qui
/// nourrit le planificateur.
///
/// `☠` Un seul relevé, deux usages : `CibleChargement` en tire les entrées du
/// plan, cette structure en tire les lignes de la fiche. Deux requêtes pour le
/// même en-tête auraient fini par afficher un fichier et en charger un autre.
///
/// `☠` Rien n'est dérivé ni complété. Un champ absent vaut `nil` et la ligne
/// disparaît de la fiche — elle n'affiche jamais un `0` ou un tiret qui se
/// lirait comme une mesure. C'est la règle du domaine `models` du serveur, et
/// elle vaut aussi pour ce qui s'affiche.
///
/// Pur : prouvable par `swift test`.
public struct FicheMetadonnees: Sendable, Equatable {
    public struct Ligne: Sendable, Equatable, Identifiable {
        public var id: String { libelle }
        public let libelle: String
        public let valeur: String
    }

    public let architecture: String
    public let quantification: String?
    /// Le contexte que le modèle déclare savoir traiter. Ce n'est PAS celui qui
    /// sera servi : le plan décide du contexte appliqué, souvent bien plus bas.
    public let contexteNatif: Int?
    public let nombreCouches: Int?
    public let estMoE: Bool
    public let lignes: [Ligne]

    /// `nil` quand le modèle n'est pas au format GGUF — le serveur répond alors
    /// `null`, et il n'y a rien à lire ni à planifier.
    public static func lire(_ gguf: ValeurJSON) -> FicheMetadonnees? {
        guard !gguf.estNul, let architecture = gguf["architecture"]?.texteOuNil else { return nil }
        let experts = gguf["nb_experts"]?.entierOuNil
        return FicheMetadonnees(
            architecture: architecture,
            quantification: gguf["quantification_mesuree"]?.texteOuNil
                ?? gguf["quantification_declaree"]?.texteOuNil,
            contexteNatif: gguf["contexte_natif"]?.entierOuNil,
            nombreCouches: gguf["block_count"]?.entierOuNil,
            estMoE: (experts ?? 0) > 1,
            lignes: composer(gguf, architecture: architecture)
        )
    }

    /// L'ordre est celui de l'intérêt décroissant sur un écran de téléphone :
    /// ce qui décide d'un chargement d'abord, la curiosité ensuite.
    private static func composer(_ gguf: ValeurJSON, architecture: String) -> [Ligne] {
        var lues: [Ligne] = [Ligne(libelle: "Architecture", valeur: architecture)]
        ajouter(&lues, "Quantification", gguf["quantification_mesuree"]?.texteOuNil
            ?? gguf["quantification_declaree"]?.texteOuNil)
        ajouter(&lues, "Contexte natif", gguf["contexte_natif"]?.entierOuNil.map(Mesures.tokens))
        ajouter(&lues, "Couches", gguf["block_count"]?.entierOuNil.map(String.init))
        ajouter(&lues, "Embedding", gguf["longueur_embedding"]?.entierOuNil.map(String.init))
        ajouter(&lues, "Têtes d'attention", tetes(gguf))
        ajouter(&lues, "Vocabulaire", gguf["taille_vocabulaire"]?.entierOuNil.map(String.init))
        lues.append(contentsOf: lignesExperts(gguf))
        ajouter(&lues, "Tenseurs", gguf["nb_tenseurs"]?.entierOuNil.map(String.init))
        ajouter(
            &lues, "Fichier",
            gguf["taille_fichier_octets"]?.entierOuNil.map(Mesures.octets)
        )
        return lues
    }

    /// « 32 / 8 » quand il y a GQA, « 32 » sinon. L'écart est ce qui explique un
    /// cache KV huit fois plus petit qu'attendu.
    private static func tetes(_ gguf: ValeurJSON) -> String? {
        guard let nombre = gguf.chemin("attention", "nb_tetes")?.entierOuNil else { return nil }
        guard let kv = gguf.chemin("attention", "nb_tetes_kv")?.entierOuNil, kv != nombre else {
            return "\(nombre)"
        }
        return "\(nombre) / \(kv) KV"
    }

    private static func lignesExperts(_ gguf: ValeurJSON) -> [Ligne] {
        guard let total = gguf["nb_experts"]?.entierOuNil, total > 1 else { return [] }
        guard let actifs = gguf["nb_experts_actifs"]?.entierOuNil else {
            return [Ligne(libelle: "Experts", valeur: "\(total)")]
        }
        return [Ligne(libelle: "Experts", valeur: "\(actifs) actifs sur \(total)")]
    }

    private static func ajouter(_ lignes: inout [Ligne], _ libelle: String, _ valeur: String?) {
        guard let valeur, !valeur.isEmpty else { return }
        lignes.append(Ligne(libelle: libelle, valeur: valeur))
    }
}
