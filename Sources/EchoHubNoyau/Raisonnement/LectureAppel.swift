import Foundation

/// Clé d'icône monochrome. Le dessin vit dans la charte ; le noyau ne connaît
/// que le mot — c'est ce qui garde `SwiftUI` hors de cette cible.
public enum IconeOutil: String, Sendable, Equatable {
    case loupe, globe, document, crayon, dossier, terminal, code, cadre, outil
}

/// Ce qu'un outil fait, dit en français et en un coup d'œil.
public struct DescripteurOutil: Sendable {
    public let libelle: String
    public let icone: IconeOutil
    /// Clés candidates de l'argument principal, par ordre de priorité. Les alias
    /// y figurent parce que le serveur affiche les arguments TELS QUE REÇUS,
    /// avant normalisation : un modèle qui écrit `pattern` au lieu de `motif`
    /// doit quand même produire une cible lisible.
    public let cles: [String]
}

public enum EtatAppel: Sendable, Equatable {
    case enCours, termine, echec, interrompu
}

/// Un appel d'outil prêt à être affiché en carte.
public struct AppelLisible: Sendable, Equatable {
    /// Nom technique de l'outil, tel qu'émis.
    public let nom: String
    public let libelle: String
    public let icone: IconeOutil
    /// Argument principal ramené à sa première ligne — la cible de l'appel, pas
    /// son détail.
    public let cible: String?
    public let entree: String
    public let sortie: String
    public let etat: EtatAppel
}

/// Lit un segment `outil` pour l'affichage.
///
/// Port de `frontend/src/chat/raisonnement/lecture-appel.ts`. Un outil absent du
/// registre garde son nom brut et sa première ligne d'arguments : il n'emprunte
/// ni libellé ni cible qui mentiraient. C'est voulu — inventer un libellé pour
/// un outil ajouté côté serveur sans mise à jour ici serait pire qu'un nom
/// technique exact.
public enum LectureAppel {
    /// Les outils du harnais (`backend/outils/registre.py`).
    public static let outilsConnus: [String: DescripteurOutil] = [
        "recherche_web": .init(libelle: "Recherche web", icone: .loupe, cles: ["requete", "query", "q"]),
        "recuperer_page": .init(libelle: "Page web", icone: .globe, cles: ["url", "lien", "adresse"]),
        "ecrire_fichier": .init(libelle: "Écriture", icone: .crayon, cles: cheminsPossibles),
        "lire_fichier": .init(libelle: "Lecture", icone: .document, cles: cheminsPossibles),
        "modifier_fichier": .init(libelle: "Modification", icone: .crayon, cles: cheminsPossibles),
        "lister_fichiers": .init(libelle: "Dossier", icone: .dossier, cles: ["motif", "pattern", "glob", "chemin"]),
        "chercher_dans_fichiers": .init(
            libelle: "Recherche fichiers", icone: .loupe, cles: ["motif", "pattern", "texte"]
        ),
        "executer_python": .init(libelle: "Python", icone: .code, cles: ["fichier", "chemin", "code", "source"]),
        "executer_commande": .init(
            libelle: "Commande", icone: .terminal, cles: ["commande", "command", "cmd", "shell"]
        ),
        "presenter_fichier": .init(libelle: "Fichier présenté", icone: .cadre, cles: ["fichier_id", "nom", "chemin"]),
        "creer_artefact": .init(libelle: "Artefact", icone: .cadre, cles: ["titre", "nom"]),
    ]

    private static let cheminsPossibles = ["chemin", "path", "fichier", "nom"]

    /// `actif` distingue « l'outil travaille » de « la génération a été coupée
    /// en plein appel » : le texte seul ne peut pas le savoir, et un « en
    /// cours » qui pulserait pour toujours est un mensonge d'interface.
    public static func lire(_ texte: String, actif: Bool) -> AppelLisible? {
        guard let appel = DecoupeAppel.decouper(texte), !appel.entree.isEmpty else { return nil }
        let (nom, detail) = nomEtDetail(appel.entree)
        let connu = outilsConnus[nom]
        return AppelLisible(
            nom: nom,
            libelle: connu?.libelle ?? nom,
            icone: connu?.icone ?? .outil,
            cible: cible(dans: detail, cles: connu?.cles ?? []),
            entree: appel.entree,
            sortie: appel.sortie,
            etat: etat(appel, actif: actif)
        )
    }

    private static func etat(_ appel: AppelOutil, actif: Bool) -> EtatAppel {
        // Sans génération en cours, une sortie jamais refermée est un appel
        // coupé net (arrêt manuel, plafond de tokens).
        guard appel.termine else { return actif ? .enCours : .interrompu }
        return appel.echec ? .echec : .termine
    }

    private static func nomEtDetail(_ entree: String) -> (nom: String, detail: String) {
        guard let parenthese = entree.firstIndex(of: "(") else {
            return (entree.trimmingCharacters(in: .whitespaces), "")
        }
        let nom = String(entree[..<parenthese]).trimmingCharacters(in: .whitespaces)
        // La parenthèse fermante peut manquer si l'aperçu du serveur a tronqué :
        // on ne retire que celle qui clôt réellement la fin du texte.
        var brut = String(entree[entree.index(after: parenthese)...])
        if brut.hasSuffix(")") { brut.removeLast() }
        return (nom, brut)
    }

    private static func cible(dans detail: String, cles: [String]) -> String? {
        for cle in cles {
            if let valeur = valeur(dans: detail, cle: cle) { return valeur }
        }
        // Aucune clé connue : la première ligne du détail reste plus parlante
        // qu'un vide.
        let ligne = detail.split(separator: "\n", omittingEmptySubsequences: false)
            .first?.trimmingCharacters(in: .whitespaces) ?? ""
        return ligne.isEmpty ? nil : ligne
    }

    /// Coupe la valeur à la clé suivante. La forme `, cle : ` peut apparaître
    /// dans une valeur en prose ; le risque est assumé parce qu'il ne coûte
    /// qu'une cible raccourcie sur la carte — le détail déplié montre toujours
    /// l'entrée entière.
    private static func valeur(dans detail: String, cle: String) -> String? {
        guard let marque = detail.range(of: "\(cle) : ") else { return nil }
        let reste = detail[marque.upperBound...]
        let ligne = reste.split(separator: "\n", omittingEmptySubsequences: false).first ?? reste[...]
        let coupe = couperAvantCleSuivante(String(ligne)).trimmingCharacters(in: .whitespaces)
        return coupe.isEmpty ? nil : coupe
    }

    private static func couperAvantCleSuivante(_ ligne: String) -> String {
        var curseur = ligne.startIndex
        while let virgule = ligne.range(of: ", ", range: curseur..<ligne.endIndex) {
            let apres = ligne[virgule.upperBound...]
            if let separateur = apres.range(of: " : "),
               apres[..<separateur.lowerBound].allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }),
               !apres[..<separateur.lowerBound].isEmpty {
                return String(ligne[..<virgule.lowerBound])
            }
            curseur = virgule.upperBound
        }
        return ligne
    }
}
