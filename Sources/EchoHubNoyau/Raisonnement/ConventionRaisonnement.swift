import Foundation

/// Une façon, pour un modèle ou pour le harnais du serveur, de marquer ce qui
/// n'est PAS la réponse.
public struct ConventionRaisonnement: Sendable, Equatable {
    /// Nom court, repris tel quel quand plusieurs conventions coexistent.
    public let nom: String
    public let ouvrante: String
    public let fermante: String

    public init(nom: String, ouvrante: String, fermante: String) {
        self.nom = nom
        self.ouvrante = ouvrante
        self.fermante = fermante
    }
}

/// Les conventions CONSTATÉES sur les modèles servis par EchoHub v2 — la liste
/// est reprise de `frontend/src/chat/raisonnement/conventions.ts`, et elle doit
/// le rester : une entrée présente d'un côté et pas de l'autre fait diverger ce
/// que le téléphone montre et ce que le navigateur montre, sur la même réponse.
///
/// `☠` Aucune n'est ajoutée « au cas où ». Un format non constaté découperait
/// une réponse sur une balise imaginaire et ferait disparaître du texte réel.
public enum Conventions {
    public static let toutes: [ConventionRaisonnement] = [
        ConventionRaisonnement(nom: "think", ouvrante: "<think>", fermante: "</think>"),
        // Constatée sur les dérivés Qwen3.6 abliterated chargés sur le PC.
        ConventionRaisonnement(nom: "process", ouvrante: "<process>", fermante: "</process>"),
        // Posée par le harnais du serveur autour d'un appel d'outil ET de son
        // résultat — pas par un modèle. Repliée comme du raisonnement (c'est du
        // travail intermédiaire), mais nommée à part pour rester distinguable.
        ConventionRaisonnement(nom: "outil", ouvrante: "<outil>", fermante: "</outil>"),
        // L'appel émis par le MODÈLE, dans son propre balisage. Il traverse le
        // flux avant d'être exécuté : sans cette entrée il s'affiche en clair au
        // milieu de la réponse.
        ConventionRaisonnement(nom: "appel", ouvrante: "<tool_call>", fermante: "</tool_call>"),
        // Certains gabarits l'émettent sans englobant. Même nature, même sort.
        ConventionRaisonnement(nom: "appel", ouvrante: "<function=", fermante: "</function>"),
    ]

    /// Marqueur posé par le serveur à la fin d'un tour ayant demandé un outil.
    /// Ce qui le précède est le commentaire de travail du modèle — « je vais
    /// chercher », « je synthétise » — et non sa réponse.
    public static let marqueurFinEtape = "<etape-fin/>"

    /// Libellé affiché en tête d'un bloc replié.
    public static let libelles: [String: String] = [
        "think": "Raisonnement",
        "process": "Raisonnement",
        "outil": "Outil",
        // « Note de travail » plutôt qu'« Étape » : le contenu est ce que le
        // modèle écrit entre deux appels. Un numéro d'étape ne dirait rien de
        // ce qu'on gagne à le déplier.
        "etape": "Note de travail",
        "appel": "Appel du modèle",
    ]

    public static func libelle(_ convention: String) -> String {
        libelles[convention] ?? "Détail"
    }
}
