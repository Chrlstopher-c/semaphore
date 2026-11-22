// La charte de Quart : les jetons relevés au pixel sur l'étalon (partie Code de l'appli Claude iOS, mode sombre).
// Une couleur sans rôle écrit ici n'existe pas. Le monde est toujours sombre, comme l'étalon capturé.
#if canImport(SwiftUI)
import SwiftUI
import UIKit
import VigieNoyau

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Jetons de Quart. Valeurs mesurées sur les captures (voir `QUART-V1-ECRANS.md`).
enum Q {
    // MARK: Fonds
    /// Liste « Code » : quasi noir, barre comprise.
    static let fondListe = Color(hex: 0x0B0B0B)
    /// Fil d'une session, feuilles.
    static let fondFil = Color(hex: 0x151515)
    /// En-tête du fil et bande du composeur.
    static let entete = Color(hex: 0x232324)
    /// Tiroir latéral.
    static let fondTiroir = Color(hex: 0x111111)
    /// Entrée sélectionnée du tiroir.
    static let selection = Color(hex: 0x404040)
    /// Cartes groupées (feuilles, réglages, tâches), champ du composeur, blocs de code.
    static let carte = Color(hex: 0x20201F)
    /// Bulle d'un message de Chris.
    static let bulle = Color(hex: 0x1F1F1E)
    /// Boutons ronds du composeur, pilule du modèle.
    static let rond = Color(hex: 0x313131)
    /// Pilule neutre (« Recommandé »), liseré des blocs de code.
    static let pilule = Color(hex: 0x2B2B2A)
    /// Liseré des capsules sur fond de liste.
    static let lisere = Color(hex: 0x232323)
    /// Code en ligne.
    static let codeEnLigne = Color(hex: 0x262626)

    // MARK: Encres
    static let texte = Color(hex: 0xF9F9F7)
    static let titre = Color(hex: 0xF0EFEC)
    /// Sous-titres de rangée, valeurs.
    static let secondaire = Color(hex: 0xC3C2B7)
    /// Libellés de section, invites, durées.
    static let tertiaire = Color(hex: 0x97958D)
    /// Méta des lignes de session.
    static let meta = Color(hex: 0x898781)
    /// Cercle d'une session au repos.
    static let cercle = Color(hex: 0x9E9D94)
    /// Texte des bulles de Chris.
    static let texteBulle = Color(hex: 0xE8E7E3)

    // MARK: Sémantique
    /// Accent : anneau d'usage, point non lu, barres de jauge.
    static let accent = Color(hex: 0x2A78D6)
    /// Coche de sélection, libellé d'option active.
    static let coche = Color(hex: 0x5598E7)
    /// Liens et actions en ligne (« 2 tâches en cours », « Ajouter »).
    static let lien = Color(hex: 0x6DA7EC)
    /// Lien sur carte (« Voir le détail »).
    static let lienDoux = Color(hex: 0x9EC5F4)
    /// Piste d'une jauge.
    static let piste = Color(hex: 0x032042)
    static let avertissementFond = Color(hex: 0x412400)
    static let avertissement = Color(hex: 0xFAB219)
    /// Machine en ligne (glyphe de l'appareil).
    static let enLigne = Color(hex: 0x0CA30C)
    static let ajout = Color(hex: 0x32D74B)
    static let retrait = Color(hex: 0xFF2C56)
    static let retraitTexte = Color(hex: 0xEB757E)
    static let fondAjout = Color(hex: 0x212E22)
    static let fondRetrait = Color(hex: 0x3A1F22)
    static let codeTexte = Color(hex: 0xABB2BF)
    static let deconnexion = Color(hex: 0xF4ABAB)

    // MARK: Typographie (SF Pro à la place de la police propriétaire de l'étalon)
    static let corps = Font.system(size: 17)
    static let corpsFil = Font.system(size: 17)
    static let titreNav = Font.system(size: 17, weight: .semibold)
    static let sousTitreNav = Font.system(size: 13)
    static let rangee = Font.system(size: 17)
    static let detail = Font.system(size: 15)
    static let section = Font.system(size: 15)
    static let petit = Font.system(size: 13)
    static let mono = Font.system(size: 14, design: .monospaced)
    static let monoPetit = Font.system(size: 13, design: .monospaced)
    /// Mot-symbole du tiroir (serif, comme l'étalon).
    static let motSymbole = Font.system(size: 28, weight: .medium, design: .serif)

    // MARK: Mesures
    static let marge: CGFloat = 16
    static let margeTexte: CGFloat = 24
    static let rayonCarte: CGFloat = 12
    static let rangeeHauteur: CGFloat = 44
    static let interligneFil: CGFloat = 6
}

/// Compatibilité des écrans d'accès à distance gardés de Vigie.
enum Charte {
    static let accent = Q.accent

    static func couleur(_ statut: StatutSession) -> Color {
        switch statut {
        case .demarrage, .travail, .compaction: return Q.accent
        case .attente, .terminee: return Q.ajout
        case .question: return Q.avertissement
        case .erreur: return Q.retrait
        case .fermee: return Q.meta
        }
    }

    static func symbole(_ outil: String) -> String {
        switch outil {
        case "Bash": return "apple.terminal"
        case "Read": return "doc.text"
        case "Edit", "MultiEdit": return "pencil"
        case "Write": return "doc.badge.plus"
        case "Grep", "Glob": return "magnifyingglass"
        case "WebFetch", "WebSearch": return "globe"
        case "Agent", "Task": return "diamond"
        default: return "wrench.and.screwdriver"
        }
    }
}

/// L'accent de Quart vu par le pupitre.
public enum Teinte {
    public static let accent = Color(hex: 0x5598E7)
}
#endif
