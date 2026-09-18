// Les composants communs de la charte, et le seul retour d'appui autorisé.
//
// `☠` Le retour d'appui vient TOUJOURS de `configuration.isPressed` dans un
// `ButtonStyle`. Jamais d'`onLongPressGesture` ni de geste posé sur un `Button` :
// le geste gagne la course contre le contrôle, le toucher est avalé, et rien ne
// le signale.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

/// L'appui universel : 0,97 en 0,2 s. Aucun contrôle du monde n'est inerte.
public struct AllureAppui: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Mouvement.micro, value: configuration.isPressed)
    }
}

/// L'action qui engage : valider un code. Le seul aplat d'accent du monde.
public struct AllureEngage: ButtonStyle {
    @Environment(\.isEnabled) private var actif
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Voix.entete)
            .foregroundStyle(actif ? Teinte.encreSurAccent : Neutre.encreEteinte)
            .frame(maxWidth: .infinity, minHeight: Grille.cible)
            .background(fond(configuration.isPressed))
            .clipShape(.rect(cornerRadius: Rayon.controle, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Mouvement.micro, value: configuration.isPressed)
            .animation(Mouvement.normal, value: actif)
    }

    private func fond(_ presse: Bool) -> Color {
        guard actif else { return Neutre.surfaceHaute }
        return presse ? Teinte.accentPresse : Teinte.accent
    }
}

extension ButtonStyle where Self == AllureAppui {
    public static var appui: AllureAppui { AllureAppui() }
}

extension ButtonStyle where Self == AllureEngage {
    public static var engage: AllureEngage { AllureEngage() }
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
                        colors: [Neutre.lumiereHaute, Neutre.lumiereBasse],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: Grille.trait
                )
        }
    }
}

extension View {
    public func lisere(_ galbe: CGFloat = Rayon.carte) -> some View {
        modifier(Lisere(galbe: galbe))
    }
}

/// Le titre d'écran, en serif éditorial.
public struct Fronton: View {
    private let titre: String

    public init(_ titre: String) { self.titre = titre }

    public var body: some View {
        Text(titre)
            .font(Voix.titreEcran)
            .foregroundStyle(Neutre.encre)
    }
}

/// Une carte. Duplex n'en emboîte jamais deux : une seule profondeur, la surface.
public struct Panneau<Contenu: View>: View {
    private let contenu: Contenu

    public init(@ViewBuilder contenu: () -> Contenu) {
        self.contenu = contenu()
    }

    public var body: some View {
        contenu
            .padding(Grille.bloc)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Neutre.surface)
            .clipShape(.rect(cornerRadius: Rayon.carte, style: .continuous))
            .lisere()
    }
}

/// Une capsule d'état, peinte avec son ton.
public struct Sceau: View {
    private let libelle: String
    private let symbole: String?
    private let ton: Ton

    public init(_ libelle: String, symbole: String? = nil, ton: Ton = .neutre) {
        self.libelle = libelle
        self.symbole = symbole
        self.ton = ton
    }

    public var body: some View {
        HStack(spacing: Grille.fin) {
            if let symbole { Image(systemName: symbole).imageScale(.small) }
            Text(libelle)
        }
        .font(Voix.legende)
        .foregroundStyle(ton.couleur)
        .padding(.horizontal, Grille.serre)
        .padding(.vertical, Grille.fin)
        .background(ton.voile, in: .capsule)
    }
}

/// Un bandeau qui dit ce qui a cassé et comment réparer. Le remède compte plus
/// que le libellé : sans lui, Chris relit trois fois le même message.
public struct Bandeau: View {
    private let libelle: String
    private let remede: String?
    private let ton: Ton

    public init(_ libelle: String, remede: String? = nil, ton: Ton) {
        self.libelle = libelle
        self.remede = remede
        self.ton = ton
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Grille.fin) {
            Text(libelle).font(Voix.mention).foregroundStyle(ton.couleur)
            if let remede {
                Text(remede).font(Voix.note).foregroundStyle(Neutre.encreDouce)
            }
        }
        .padding(Grille.bloc)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ton.voile)
        .clipShape(.rect(cornerRadius: Rayon.carte, style: .continuous))
    }
}

/// Un état vide conçu — jamais un écran nu, jamais un tourniquet muet.
///
/// `☠` Un tourniquet dit « attends ». Un état conçu dit QUOI. Ici la différence
/// sépare « ça cherche » de « lance Duplex sur le PC ».
public struct EtatCalme<Pied: View>: View {
    private let symbole: String
    private let titre: String
    private let detail: String
    private let pied: Pied

    public init(symbole: String, titre: String, detail: String, @ViewBuilder pied: () -> Pied) {
        self.symbole = symbole
        self.titre = titre
        self.detail = detail
        self.pied = pied()
    }

    public var body: some View {
        VStack(spacing: Grille.element) {
            Image(systemName: symbole)
                .font(.system(.largeTitle, weight: .light))
                .foregroundStyle(Neutre.encreEteinte)
            VStack(spacing: Grille.fin) {
                Text(titre).font(Voix.entete).foregroundStyle(Neutre.encre)
                Text(detail).font(Voix.note).foregroundStyle(Neutre.encreDouce)
                    .multilineTextAlignment(.center)
            }
            pied.padding(.top, Grille.fin)
        }
        .padding(.horizontal, Grille.souffle)
        .padding(.vertical, Grille.groupe)
        .frame(maxWidth: .infinity)
    }
}

extension EtatCalme where Pied == EmptyView {
    public init(symbole: String, titre: String, detail: String) {
        self.init(symbole: symbole, titre: titre, detail: detail) { EmptyView() }
    }
}
#endif
