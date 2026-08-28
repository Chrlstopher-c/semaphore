// Les composants communs de la charte, et le seul retour d'appui autorisé.
//
// `☠` Le retour d'appui vient TOUJOURS de `configuration.isPressed` dans un
// `ButtonStyle`. Jamais d'`onLongPressGesture` ni de geste posé sur un `Button`
// ou un `NavigationLink` : le geste gagne la course contre le contrôle, le
// toucher est avalé, et rien ne le signale.
#if canImport(SwiftUI)
import SwiftUI

/// L'appui universel : 0,97 en 0,2 s. Aucun contrôle du monde n'est inerte.
public struct AllureAppui: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Elan.micro, value: configuration.isPressed)
    }
}

/// L'action qui engage : capturer, enregistrer, tester.
public struct AllureEngage: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .entete()
            .foregroundStyle(Teinte.fond)
            .frame(maxWidth: .infinity, minHeight: Trame.cible)
            .background(configuration.isPressed ? Teinte.accentPresse : Teinte.accent)
            .clipShape(.rect(cornerRadius: Galbe.controle, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Elan.micro, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AllureAppui {
    public static var appui: AllureAppui { AllureAppui() }
}

extension ButtonStyle where Self == AllureEngage {
    public static var engage: AllureEngage { AllureEngage() }
}

/// Un bouton à icône seule (fermer, effacer) avec une cible tactile GARANTIE de
/// 44×44 pt, quel que soit le corps du glyphe.
///
/// `☠` La règle Apple des 44 pt ne se lit pas sur le glyphe : un `xmark` de 17
/// pt n'offre que 17 pt à toucher si rien n'élargit sa zone. Ce composant pose la
/// cible, le glyphe reste petit — l'un ne dicte pas l'autre.
public struct BoutonIcone: View {
    private let symbole: String
    private let teinte: Color
    private let action: () -> Void

    public init(_ symbole: String, teinte: Color = Teinte.encreEteinte, action: @escaping () -> Void) {
        self.symbole = symbole
        self.teinte = teinte
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: symbole)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(teinte)
                .frame(width: Trame.cible, height: Trame.cible)
                .contentShape(.rect)
        }
        .buttonStyle(.appui)
    }
}

/// La lumière qui fait exister une surface sur fond sombre : un liseré d'un
/// point, clair en haut, éteint en bas. C'est lui qui remplace l'ombre.
public struct Lisere: ViewModifier {
    let galbe: CGFloat

    public func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: galbe, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Teinte.lumiereHaute, Teinte.lumiereBasse],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: Trame.trait
                )
        }
    }
}

extension View {
    public func lisere(_ galbe: CGFloat = Galbe.carte) -> some View {
        modifier(Lisere(galbe: galbe))
    }
}

/// Le titre d'écran, dessiné maison, en rond gras.
public struct Fronton: View {
    private let titre: String

    public init(_ titre: String) { self.titre = titre }

    public var body: some View {
        Text(titre)
            .titreEcran()
            .foregroundStyle(Teinte.encre)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Trame.ecran)
    }
}

/// Une carte. Monte l'ambiance d'un palier pour ses enfants : c'est le seul
/// endroit du monde où la profondeur s'incrémente.
public struct Panneau<Contenu: View>: View {
    @Environment(\.ambiance) private var ambiance
    private let contenu: Contenu

    public init(@ViewBuilder contenu: () -> Contenu) {
        self.contenu = contenu()
    }

    public var body: some View {
        let montee = ambiance.montee()
        contenu
            .padding(Trame.bloc)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(montee.palier.fond)
            .clipShape(.rect(cornerRadius: Galbe.carte, style: .continuous))
            .lisere()
            .ambiance(montee)
    }
}

/// Une capsule d'état. Enfant type de l'ambiance : pas de couleur propre, elle
/// lit le ton hérité et se peint avec.
public struct Sceau: View {
    @Environment(\.ambiance) private var ambiance
    private let libelle: String
    private let symbole: String?

    public init(_ libelle: String, symbole: String? = nil) {
        self.libelle = libelle
        self.symbole = symbole
    }

    public var body: some View {
        HStack(spacing: Trame.fin) {
            if let symbole { Image(systemName: symbole).imageScale(.small) }
            Text(libelle)
        }
        .legende()
        .foregroundStyle(ambiance.ton.couleur)
        .padding(.horizontal, Trame.serre)
        .padding(.vertical, Trame.fin)
        .background(ambiance.ton.voile, in: .capsule)
    }
}

/// Un petit tag cliquable/filtrable, en chasse ronde.
public struct Etiquette: View {
    private let texte: String
    private let actif: Bool

    public init(_ texte: String, actif: Bool = false) {
        self.texte = texte
        self.actif = actif
    }

    public var body: some View {
        Text(texte)
            .legende()
            .foregroundStyle(actif ? Teinte.fond : Teinte.encreDouce)
            .padding(.horizontal, Trame.serre)
            .padding(.vertical, Trame.fin)
            .background(
                actif ? Teinte.accent : Teinte.surfaceHaute,
                in: .rect(cornerRadius: Galbe.controle, style: .continuous)
            )
    }
}

/// Un état vide conçu — jamais un écran nu, jamais un tourniquet muet.
///
/// `☠` Un tourniquet dit « attends ». Un état conçu dit QUOI. Sur une app dont
/// le serveur peut être injoignable, la différence sépare « ça rame » de
/// « vérifie ta connexion ».
public struct EtatCalme: View {
    private let symbole: String
    private let titre: String
    private let detail: String
    private let actionTitre: String?
    private let action: (() -> Void)?

    public init(
        symbole: String, titre: String, detail: String,
        actionTitre: String? = nil, action: (() -> Void)? = nil
    ) {
        self.symbole = symbole
        self.titre = titre
        self.detail = detail
        self.actionTitre = actionTitre
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Trame.element) {
            Image(systemName: symbole)
                .font(.system(.largeTitle, design: .rounded, weight: .light))
                .foregroundStyle(Teinte.encreEteinte)
            VStack(spacing: Trame.fin) {
                Text(titre).entete().foregroundStyle(Teinte.encre)
                Text(detail).note().foregroundStyle(Teinte.encreDouce)
                    .multilineTextAlignment(.center)
            }
            if let actionTitre, let action {
                Button(actionTitre, action: action)
                    .buttonStyle(.appui)
                    .mention()
                    .foregroundStyle(Teinte.accent)
                    .frame(minHeight: Trame.cible)
                    .padding(.top, Trame.fin)
            }
        }
        .padding(.horizontal, Trame.souffle)
        .frame(maxWidth: .infinity)
    }
}
#endif
