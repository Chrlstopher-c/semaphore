import Foundation

/// Un bloc d'outil découpé en ce qui a été DEMANDÉ et ce qui a été RENDU.
///
/// Le serveur encadre les deux parties et les émet à des instants différents :
/// l'entrée part avant l'exécution, la sortie après. Ce type doit donc rester
/// tolérant à l'inachevé — pendant que l'outil travaille, seule l'entrée
/// existe, et c'est précisément ce qu'il faut afficher pour que l'attente ne
/// soit pas muette.
public struct AppelOutil: Sendable, Equatable {
    /// Ce que le modèle a demandé — nom de l'outil et arguments, déjà mis en
    /// forme par le serveur.
    public let entree: String
    /// Ce que l'outil a rendu. Vide tant que l'exécution n'a rien produit.
    public let sortie: String
    /// Issue transmise par le harnais. `false` aussi tant que la sortie n'est
    /// pas close — un appel en cours n'est pas un appel raté.
    public let echec: Bool
    /// `false` tant que `</sortie>` n'est pas arrivée.
    public let termine: Bool
}

/// Découpe le contenu d'un segment `outil`.
///
/// Port de `frontend/src/chat/raisonnement/appel-outil.ts`. La forme attendue
/// est `<entree>nom(clé : valeur, …)</entree><sortie etat="echec">…</sortie>`.
///
/// `☠` La forme SANS attribut `etat` reste acceptée, et pas par prudence : elle
/// est écrite dans tous les messages enregistrés avant le 26/08/2026, et un
/// historique relu depuis le téléphone ne doit pas changer d'apparence parce
/// que le format a évolué côté serveur.
public enum DecoupeAppel {
    public static func decouper(_ texte: String) -> AppelOutil? {
        let entree = balise(texte, nom: "entree")
        let sortie = balise(texte, nom: "sortie")
        // Aucune des deux balises : un bloc d'une version antérieure, ou un
        // contenu qu'on ne doit pas prétendre comprendre. L'appelant affiche
        // alors le texte tel quel plutôt qu'une structure inventée.
        guard entree != nil || sortie != nil else { return nil }
        return AppelOutil(
            entree: entree?.contenu.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            sortie: sortie?.contenu.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            echec: sortie?.attributs.contains("etat=\"echec\"") ?? false,
            termine: texte.contains("</sortie>")
        )
    }

    private struct Balise {
        let attributs: String
        let contenu: String
    }

    /// Trouve `<nom …>contenu</nom>`, en tolérant l'absence de fermeture — le
    /// flux est lu pendant qu'il s'écrit.
    private static func balise(_ texte: String, nom: String) -> Balise? {
        guard let debutOuvrante = texte.range(of: "<\(nom)") else { return nil }
        guard let finOuvrante = texte.range(
            of: ">", range: debutOuvrante.upperBound..<texte.endIndex
        ) else { return nil }
        let attributs = String(texte[debutOuvrante.upperBound..<finOuvrante.lowerBound])
        let apres = finOuvrante.upperBound
        let fermante = texte.range(of: "</\(nom)>", range: apres..<texte.endIndex)
        let fin = fermante?.lowerBound ?? texte.endIndex
        return Balise(attributs: attributs, contenu: String(texte[apres..<fin]))
    }
}
