// Les allures de bouton — TOUT le retour d'appui de la charte vient d'ici,
// via `configuration.isPressed`.
//
// `☠` Règle absolue : jamais un `onLongPressGesture` ni un geste custom posé
// sur un `Button` ou un `NavigationLink` — le geste gagne la course contre le
// contrôle, le toucher est avalé, et rien ne le signale (trois écrans rendus
// muets d'un coup, mesuré). Le maintien pour l'irréversible passe par
// `BoutonArme`, qui est un contrôle autonome.
#if canImport(SwiftUI)
import SwiftUI

/// Le geste qui engage : fond accent plein, encre sombre. Un seul par carte.
public struct AllureAccent: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .libelle()
            .foregroundStyle(Teinte.encreSurAccent)
            .padding(.horizontal, Trame.bloc)
            .frame(minHeight: Trame.cibleDecision)
            .frame(maxWidth: .infinity)
            .background(
                configuration.isPressed ? Teinte.accentPresse : Teinte.accent,
                in: RoundedRectangle(cornerRadius: Galbe.bouton, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Elan.vif, value: configuration.isPressed)
    }
}

/// Le second geste : surface, filet, encre claire.
public struct AllureDouce: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .libelle()
            .foregroundStyle(Teinte.encre)
            .padding(.horizontal, Trame.bloc)
            .frame(minHeight: Trame.cible)
            .frame(maxWidth: .infinity)
            .background(
                configuration.isPressed ? Teinte.surfaceHaute : Teinte.surface,
                in: RoundedRectangle(cornerRadius: Galbe.bouton, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Galbe.bouton, style: .continuous)
                    .strokeBorder(Teinte.filetAppuye, lineWidth: Trame.trait)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Elan.vif, value: configuration.isPressed)
    }
}

/// Le refus, l'arrêt : voile danger, encre danger. Destructif mais réversible —
/// l'irréversible passe par `BoutonArme`.
public struct AllureDanger: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .libelle()
            .foregroundStyle(Teinte.danger)
            .padding(.horizontal, Trame.bloc)
            .frame(minHeight: Trame.cibleDecision)
            .frame(maxWidth: .infinity)
            .background(
                Teinte.danger.opacity(configuration.isPressed ? 0.24 : 0.14),
                in: RoundedRectangle(cornerRadius: Galbe.bouton, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Elan.vif, value: configuration.isPressed)
    }
}

/// Une carte entière qui s'ouvre : léger tassement, surface qui s'éclaire.
public struct AllureCarte: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Elan.vif, value: configuration.isPressed)
    }
}

/// Bouton d'icône : cible 44 pt, retour discret. Pour les en-têtes.
public struct AllureIcone: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .frame(width: Trame.cible, height: Trame.cible)
            .contentShape(.rect)
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(Elan.vif, value: configuration.isPressed)
    }
}

/// Rangée nue (lignes de liste, choix) : seul un voile d'appui apparaît.
public struct AllureRangee: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.rect)
            .background(
                configuration.isPressed ? Teinte.filet : .clear,
                in: RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
            )
            .animation(Elan.vif, value: configuration.isPressed)
    }
}

/// Petit bouton en rangée : épouse son contenu, 32 pt de haut. Le ton colore
/// l'encre et le voile — `.neutre` rend un bouton de surface.
public struct AllurePuce: ButtonStyle {
    private let ton: Ton

    public init(ton: Ton = .neutre) {
        self.ton = ton
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(ton == .neutre ? Teinte.encre : ton.teinte)
            .padding(.horizontal, Trame.element)
            .frame(minHeight: 32)
            .background(
                ton == .neutre
                    ? (configuration.isPressed ? Teinte.surfaceHaute : Teinte.surface)
                    : ton.teinte.opacity(configuration.isPressed ? 0.24 : 0.14),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    ton == .neutre ? Teinte.filetAppuye : .clear,
                    lineWidth: Trame.trait
                )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Elan.vif, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AllurePuce {
    public static var allurePuce: AllurePuce { AllurePuce() }
    public static func allurePuce(_ ton: Ton) -> AllurePuce { AllurePuce(ton: ton) }
}

extension ButtonStyle where Self == AllureAccent {
    public static var allureAccent: AllureAccent { AllureAccent() }
}
extension ButtonStyle where Self == AllureDouce {
    public static var allureDouce: AllureDouce { AllureDouce() }
}
extension ButtonStyle where Self == AllureDanger {
    public static var allureDanger: AllureDanger { AllureDanger() }
}
extension ButtonStyle where Self == AllureCarte {
    public static var allureCarte: AllureCarte { AllureCarte() }
}
extension ButtonStyle where Self == AllureIcone {
    public static var allureIcone: AllureIcone { AllureIcone() }
}
extension ButtonStyle where Self == AllureRangee {
    public static var allureRangee: AllureRangee { AllureRangee() }
}
#endif
