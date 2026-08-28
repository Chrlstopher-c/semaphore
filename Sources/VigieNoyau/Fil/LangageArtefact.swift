import Foundation

/// Le langage d'un artefact, reconnu par l'EXTENSION de son nom de fichier —
/// liste fermée, alignée sur `pieces-jointes/artefacts.ts` côté serveur
/// (« mandat « artefacts » » : script shell, Python, Lua, ou page HTML).
///
/// `☠` La reconnaissance passe par l'extension, PAS par `PieceJointeApi.type`
/// (le MIME servi par le Pi) : c'est l'extension qui fait foi des deux côtés
/// de la liaison — un client qui se fierait au MIME dupliquerait une décision
/// déjà prise ailleurs, avec le risque de diverger si un jour les deux
/// désaccordent.
public enum LangageArtefact: String, Sendable, Hashable, CaseIterable {
    case html, sh, py, lua

    /// Le libellé du badge affiché sur la carte — même vocabulaire que
    /// `HA_TYPES` côté web (`harness-artefacts.js`).
    public var libelle: String {
        switch self {
        case .html: return "HTML"
        case .sh: return "Shell"
        case .py: return "Python"
        case .lua: return "Lua"
        }
    }

    /// `true` pour le seul langage qui bascule code / rendu.
    public var seRend: Bool { self == .html }

    /// Reconnaît le langage depuis le nom de fichier complet (`"demo.html"`).
    /// `nil` hors du périmètre fermé — jamais une extension inventée.
    public static func depuis(nomFichier: String) -> LangageArtefact? {
        guard let point = nomFichier.lastIndex(of: ".") else { return nil }
        let suffixe = nomFichier[nomFichier.index(after: point)...].lowercased()
        return LangageArtefact(rawValue: suffixe)
    }
}
