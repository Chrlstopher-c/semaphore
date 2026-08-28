// Les composants communs de la charte, et le seul retour d'appui autorisé.
//
// `☠` Le retour d'appui vient TOUJOURS de `configuration.isPressed` dans un
// `ButtonStyle`. Jamais d'`onLongPressGesture` ni de geste posé sur un `Button`
// ou un `NavigationLink` : le geste gagne la course contre le contrôle, le
// toucher est avalé, et rien ne le signale.
#if canImport(SwiftUI)
import SwiftUI

/// L'appui universel : 0,97 en 0,2 s. Aucun contrôle de l'app n'est inerte.
public struct AllureAppui: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Elan.micro, value: configuration.isPressed)
    }
}

/// L'action qui engage : envoyer, enregistrer, créer.
public struct AllureEngage: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .entete()
            .foregroundStyle(Teinte.fond)
            .frame(maxWidth: .infinity, minHeight: Trame.cible)
            .background(configuration.isPressed ? Teinte.accentPresse : Teinte.accent)
            .clipShape(.rect(cornerRadius: Galbe.controle, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Elan.micro, value: configuration.isPressed)
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

/// Le titre d'écran, dessiné maison.
///
/// `☠` La barre système en mode `.large` compose à 34 pt gras — au-dessus du
/// plafond de 26 que la charte fixe pour qu'aucun titre ne domine la réponse
/// du modèle. Les écrans qui portent un grand titre masquent donc la barre de
/// navigation et posent ce fronton en tête de leur défilement.
public struct Fronton: View {
    private let titre: String

    public init(_ titre: String) {
        self.titre = titre
    }

    public var body: some View {
        Text(titre)
            .titreEcran()
            .foregroundStyle(Teinte.encre)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Trame.ecran)
    }
}

/// Une carte. Monte l'ambiance d'un palier pour ses enfants : c'est le seul
/// endroit de l'app où la profondeur s'incrémente.
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

/// Une capsule d'état. Enfant type de l'ambiance : elle n'a pas de couleur
/// propre, elle lit le ton hérité et se peint avec — sa surcharge à elle.
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

/// Un état vide conçu — jamais un écran nu, jamais un tourniquet muet. Sert aux
/// trois états d'un écran dépendant du réseau : vide, échec (avec `action` pour
/// réessayer), et — via `ChargementVue` — chargement.
///
/// `☠` Un tourniquet dit « attends ». Un état conçu dit QUOI. Sur une app dont
/// le PC peut être éteint, la différence est tout ce qui sépare « ça rame » de
/// « allume ta machine ».
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
                .font(.system(size: 30, weight: .light))
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
                    .padding(.top, Trame.fin)
            }
        }
        .padding(.horizontal, Trame.souffle)
        .frame(maxWidth: .infinity)
    }
}

/// Le troisième état d'un écran réseau : trois rangées fantômes qui respirent.
/// L'écran raconte la FORME de ce qui arrive, plutôt que de montrer un vide.
///
/// `☠` Seule l'opacité s'anime ici — conforme à `CHARTE.md` : « seuls transform
/// et opacity s'animent ». Aucune mise en page ne bouge.
public struct ChargementVue: View {
    @State private var respire = false

    /// Dimensions du squelette, hors grille `Trame` : un rectangle de texte
    /// fantôme n'a pas de jeton dédié — il ne représente rien de réel.
    private let largeurTitre: CGFloat = 180
    private let largeurSousTitre: CGFloat = 104
    private let epaisseurLigne: CGFloat = 12

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Trame.groupe) {
            ForEach(0..<3, id: \.self) { rang in
                rangee
                    .opacity(respire ? 0.35 : 1)
                    .animation(
                        Elan.normal.repeatForever(autoreverses: true).delay(Double(rang) * 0.08),
                        value: respire
                    )
            }
        }
        .padding(.horizontal, Trame.ecran)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .top)
        .onAppear { respire = true }
    }

    private var rangee: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            barre(largeurTitre)
            barre(largeurSousTitre)
        }
    }

    private func barre(_ largeur: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Trame.fin, style: .continuous)
            .fill(Teinte.surface)
            .frame(width: largeur, height: epaisseurLigne)
    }
}
#endif
