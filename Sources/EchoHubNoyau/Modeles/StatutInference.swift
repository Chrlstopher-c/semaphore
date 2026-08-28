import Foundation

/// Ce que fait le PC à cet instant. Un seul état à la fois : le GPU est
/// exclusif, et c'est cette exclusivité que l'écran doit rendre lisible.
public enum EtatInference: String, Sendable, Decodable {
    case inactif
    case enCours = "en_cours"
    case pret
    case echoue
}

/// Ce que le moteur sert réellement, et ce que le chargement a coûté.
///
/// `☠` Les deux mesures de VRAM ne valent qu'ENSEMBLE : `vramApresOctets` est
/// la VRAM totale utilisée de la carte, bureau compris. Seule leur différence
/// isole le modèle — voir `CibleChargement.modelesCharges`, qui en dépend pour
/// ne pas promettre au planificateur une mémoire qu'aucune éjection ne rendra.
public struct EtatMoteur: Sendable, Decodable, Equatable {
    public let moteur: String
    public let modele: String
    public let pret: Bool
    public let contexte: Int
    public let couchesGpu: Int
    public let dureeChargementS: Double
    public let vramAvantOctets: Int?
    public let vramApresOctets: Int?

    /// Ce que le modèle occupe réellement. `nil` quand une des deux mesures
    /// manque — jamais 0, qui se lirait « il ne prend rien ».
    public var vramModeleOctets: Int? {
        guard let vramAvantOctets, let vramApresOctets else { return nil }
        return max(0, vramApresOctets - vramAvantOctets)
    }
}

/// Le modèle chargé et son plan, vus du téléphone.
///
/// `☠` Amendé le 28/08/2026. La version précédente écrivait ici que l'app
/// n'affichait PAS le plan de chargement, par périmètre. Chris a renversé la
/// décision : le plan se lit désormais dans l'atelier (`CHARTE.md`,
/// § Amendement). Le plan continue de traverser en `ValeurJSON` — c'est
/// `ApercuPlan` qui en extrait ce qui s'affiche, sans porter les trois cents
/// lignes de DTO du planificateur.
///
/// `☠` Le plan appliqué N'EST PAS un champ de cette structure, bien que le
/// serveur le rende sur la même route. `CodageJSON` pose
/// `convertFromSnakeCase`, qui s'applique AUSSI aux clés d'un dictionnaire :
/// un plan décodé ici rendrait `couchesGpu` là où le serveur a écrit
/// `couches_gpu`, et `ApercuPlan` n'y lirait plus rien — sans la moindre erreur
/// de décodage. Le plan courant se relit donc opaque, par
/// `DepotModeles.planCourant()`.
public struct StatutInference: Sendable, Decodable {
    public let etat: EtatInference
    public let moteur: String?
    /// Le nom du modèle chargé, `nil` quand il n'y en a aucun.
    public let modele: String?
    /// La cause QUALIFIÉE d'un échec — `vram_insuffisante`, `moteur_absent`,
    /// `contexte_trop_grand`… `nil` hors échec.
    ///
    /// `☠` Elle existe parce que la v1 remontait « Failed to load model from
    /// file » pour tout : le message accusait le fichier quand la cause était
    /// ailleurs. C'est aussi ce qui permet de DÉGRADER dans la bonne direction
    /// plutôt que de relancer le plan qui vient d'échouer.
    public let cause: String?
    public let message: String
    public let remediation: String
    public let etatMoteur: EtatMoteur?

    public var estPret: Bool { etat == .pret }
}

/// Une ligne du registre local du PC : un modèle présent sur son disque.
public struct ModeleEnregistre: Sendable, Decodable, Identifiable, Hashable {
    public let id: String
    public let depot: String
    /// Le fichier de poids retenu dans le dépôt, quand il en porte plusieurs.
    public let fichier: String?
    public let chemin: String
    /// `gguf` ou `safetensors`. Non porté en `enum` : un format ajouté côté
    /// serveur ferait échouer le décodage de TOUT le registre pour une valeur
    /// qu'on sait afficher telle quelle.
    public let format: String
    public let tailleOctets: Int
    public let quantification: String?
    public let architecture: String?
    public let nbCouches: Int?
    public let contexteMax: Int?
    public let favori: Bool

    /// « 4,7 Go ». Une mesure, donc à composer en chiffres à chasse fixe côté
    /// interface — sans quoi la largeur danse d'une ligne à l'autre.
    public var tailleLisible: String { Mesures.octets(tailleOctets) }

    /// Le nom court, sans l'organisation : c'est ce qui tient sur un écran de
    /// téléphone, et c'est ce qui distingue deux modèles dans une liste.
    public var nomCourt: String {
        depot.split(separator: "/").last.map(String.init) ?? depot
    }
}

/// Les mesures affichées, formatées en UN seul endroit.
///
/// `☠` Le formatage vit ici et pas dans une vue : la même taille en octets
/// apparaît au registre, sur le disque, dans une fiche de dépôt et dans un
/// transfert. Quatre écritures de la même règle divergeraient, et l'écart se
/// lirait comme deux tailles différentes pour un même fichier.
public enum Mesures {
    public static func octets(_ valeur: Int) -> String {
        let giga = Double(valeur) / 1_073_741_824
        guard giga < 0.1 else { return virgule(String(format: "%.1f Go", giga)) }
        let mega = Double(valeur) / 1_048_576
        guard mega < 1 else { return String(format: "%.0f Mo", mega) }
        return "\(valeur) o"
    }

    /// « 32 k », « 1,5 M ». Un contexte de 262 144 ne se lit pas.
    public static func tokens(_ valeur: Int) -> String {
        guard valeur < 1_048_576 else {
            return virgule(String(format: "%.1f M", Double(valeur) / 1_048_576))
        }
        guard valeur >= 1024 else { return "\(valeur)" }
        return "\(valeur / 1024) k"
    }

    private static func virgule(_ texte: String) -> String {
        texte.replacingOccurrences(of: ".", with: ",")
    }
}
