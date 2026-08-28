// Le panneau : la surface de base de la charte. Fond `surface`, filet, galbe
// continu — et, pour les cartes de décision, un rail coloré sur la tranche
// gauche : c'est lui qu'on lit à 3 h du matin, avant tout texte.
#if canImport(SwiftUI)
import SwiftUI

public struct Panneau<Contenu: View>: View {
    private let rail: Ton?
    private let contenu: Contenu

    /// `rail` pose une tranche colorée de 3 pt à gauche — réservé à ce qui
    /// réclame l'œil (décisions, alertes), jamais décoratif.
    public init(rail: Ton? = nil, @ViewBuilder contenu: () -> Contenu) {
        self.rail = rail
        self.contenu = contenu()
    }

    public var body: some View {
        contenu
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Trame.bloc)
            .background(Teinte.surface, in: forme)
            .overlay(forme.strokeBorder(Teinte.filet, lineWidth: Trame.trait))
            .overlay(alignment: .leading) { tranche }
            .clipShape(forme)
    }

    private var forme: RoundedRectangle {
        RoundedRectangle(cornerRadius: Galbe.panneau, style: .continuous)
    }

    @ViewBuilder private var tranche: some View {
        if let rail {
            Rectangle()
                .fill(rail.teinte)
                .frame(width: 3)
        }
    }
}

/// Le filet : un trait, rien d'autre.
public struct FiletFin: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Teinte.filet)
            .frame(height: Trame.trait)
    }
}

/// Tête de section : rubrique à voix basse, accessoire à droite.
public struct TeteDeSection<Accessoire: View>: View {
    private let titre: String
    private let accessoire: Accessoire

    public init(_ titre: String, @ViewBuilder accessoire: () -> Accessoire) {
        self.titre = titre
        self.accessoire = accessoire()
    }

    public var body: some View {
        HStack(spacing: Trame.serre) {
            Text(titre).rubrique()
            Spacer(minLength: 0)
            accessoire
        }
    }
}

extension TeteDeSection where Accessoire == EmptyView {
    public init(_ titre: String) {
        self.init(titre) { EmptyView() }
    }
}
#endif
