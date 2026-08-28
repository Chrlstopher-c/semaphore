// La ligne clé / valeur d'un panneau. La clé à voix basse, la valeur en face —
// en mono quand c'est une mesure, ce qui est le cas par défaut ici.
#if canImport(SwiftUI)
import SwiftUI

public struct LigneCle: View {
    private let cle: String
    private let valeur: String
    private let teinteValeur: Color?
    private let derniere: Bool

    public init(_ cle: String, valeur: String, teinteValeur: Color? = nil, derniere: Bool = false) {
        self.cle = cle
        self.valeur = valeur
        self.teinteValeur = teinteValeur
        self.derniere = derniere
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Trame.bloc) {
                Text(cle)
                    .note()
                    .foregroundStyle(Teinte.encreDouce)
                    .layoutPriority(1)
                Spacer(minLength: Trame.serre)
                Text(valeur)
                    .donnee()
                    .foregroundStyle(teinteValeur ?? Teinte.encre)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, Trame.serre)
            if !derniere { FiletFin() }
        }
    }
}

/// Variante à valeur longue (périmètre, critère d'arrêt) : la valeur passe
/// sous la clé, en corps texte — un pavé de prose n'est pas une mesure.
public struct LigneCleLongue: View {
    private let cle: String
    private let valeur: String
    private let derniere: Bool

    public init(_ cle: String, valeur: String, derniere: Bool = false) {
        self.cle = cle
        self.valeur = valeur
        self.derniere = derniere
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Trame.fin) {
                Text(cle)
                    .note()
                    .foregroundStyle(Teinte.encreDouce)
                Text(valeur)
                    .note()
                    .foregroundStyle(Teinte.encre)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Trame.serre)
            if !derniere { FiletFin() }
        }
    }
}
#endif
