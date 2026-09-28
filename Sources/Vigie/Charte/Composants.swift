// Les composants signature de la charte : surtitre au carré violet, bouton plein à relief, pastille, point d'état,
// jauge, carte. Rien ici ne connaît une session ou une machine.
#if canImport(SwiftUI)
import SwiftUI

struct Surtitre: View {
    @Environment(\.palette) private var p
    let texte: String

    var body: some View {
        HStack(spacing: Espace.s) {
            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(p.accentVif).frame(width: 8, height: 8)
            Text(texte.uppercased()).font(Voix.etiquette).tracking(1.5).foregroundStyle(p.accentTexte)
        }
    }
}

/// Bouton plein : pilule accent, relief de 3 pt qui s'enfonce au toucher (composant signature Echo Agency).
struct StyleBoutonPlein: ButtonStyle {
    @Environment(\.palette) private var p
    @Environment(\.isEnabled) private var actif

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Voix.entete)
            .foregroundStyle(.white)
            .padding(.horizontal, Espace.xl)
            .frame(minHeight: 48)
            .background(Capsule().fill(p.accent))
            .background(Capsule().fill(p.relief).offset(y: configuration.isPressed ? 0 : 3))
            .offset(y: configuration.isPressed ? 3 : 0)
            .opacity(actif ? 1 : 0.45)
            .animation(Mouvement.micro, value: configuration.isPressed)
    }
}

/// Bouton secondaire : surface, liseré, même hauteur tactile.
struct StyleBoutonDiscret: ButtonStyle {
    @Environment(\.palette) private var p
    var danger = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Voix.petit.weight(.bold))
            .foregroundStyle(danger ? p.danger : p.encre)
            .padding(.horizontal, Espace.l)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous).fill(p.surface))
            .overlay(RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous).strokeBorder(p.filet))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Mouvement.micro, value: configuration.isPressed)
    }
}

struct Pastille: View {
    @Environment(\.palette) private var p
    enum Ton { case accent, neutre, succes, danger, alerte }
    let texte: String
    var ton: Ton = .accent

    var body: some View {
        Text(texte).font(Voix.petit.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, Espace.xs)
            .foregroundStyle(couleur).background(Capsule().fill(fond))
    }

    private var couleur: Color {
        switch ton {
        case .accent: return p.accentTexte
        case .neutre: return p.encreDouce
        case .succes: return p.succes
        case .danger: return p.danger
        case .alerte: return p.alerte
        }
    }

    private var fond: Color { ton == .neutre ? p.surface2 : (ton == .accent ? p.accentFond : couleur.opacity(0.14)) }
}

/// Point d'état : pulse tant que la session travaille.
struct PointEtat: View {
    @Environment(\.palette) private var p
    enum Ton { case actif, calme, eteint, alerte }
    let ton: Ton

    var body: some View {
        Circle().fill(couleur).frame(width: 8, height: 8)
            .phaseAnimator(ton == .actif ? [1.0, 0.35] : [1.0]) { vue, phase in vue.opacity(phase) }
                animation: { _ in .easeInOut(duration: 0.9) }
    }

    private var couleur: Color {
        switch ton {
        case .actif: return p.accentVif
        case .calme: return p.succes
        case .eteint: return p.discret.opacity(0.5)
        case .alerte: return p.danger
        }
    }
}

struct Jauge: View {
    @Environment(\.palette) private var p
    let valeur: Double
    var alerte = 0.8

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(p.surface2)
                Capsule().fill(valeur >= alerte ? p.danger : p.accentVif)
                    .frame(width: max(4, g.size.width * min(1, max(0, valeur))))
            }
        }
        .frame(height: 6)
        .animation(Mouvement.standard, value: valeur)
    }
}

struct Carte: ViewModifier {
    @Environment(\.palette) private var p

    func body(content: Content) -> some View {
        content.padding(Espace.l)
            .background(RoundedRectangle(cornerRadius: Rayon.carte, style: .continuous).fill(p.surface))
            .overlay(RoundedRectangle(cornerRadius: Rayon.carte, style: .continuous).strokeBorder(p.filet))
    }
}

extension View {
    func carte() -> some View { modifier(Carte()) }
}
#endif
