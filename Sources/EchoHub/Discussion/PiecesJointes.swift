// Les pièces jointes du prochain message : ce qui est en train de monter, ce
// qui est posé sur le PC, ce qui a raté.
//
// `☠` Le dépôt est IMMÉDIAT, à la sélection — jamais au moment d'envoyer. Aucun
// octet ne traverse la route de génération, qui ne transporte que des
// identifiants : un envoi ne peut donc pas échouer pour une photo trop lourde
// alors que le texte, lui, était bon.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

/// Une pièce jointe et son sort. `id` est local : il identifie la vignette,
/// pas le fichier du PC — celui-là n'existe qu'une fois le dépôt abouti.
public struct PieceJointe: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public var nom: String
    public var etat: EtatPiece

    /// L'identifiant à envoyer dans `DemandeGeneration.fichierIds`. `nil` tant
    /// que le PC n'a rien accusé : envoyer un identifiant inventé serait pire
    /// qu'attendre.
    public var identifiantServeur: String? {
        if case .posee(let identifiant) = etat { return identifiant }
        return nil
    }
}

public enum EtatPiece: Sendable, Equatable {
    case depot
    case posee(String)
    case echec(String)
}

/// La bande de vignettes, au-dessus du composeur. Absente quand il n'y a rien :
/// une bande vide vole une rangée sur 375 pt.
struct BandePiecesJointes: View {
    @Environment(Salon.self) private var salon

    var body: some View {
        if !salon.piecesJointes.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: Trame.serre) {
                    ForEach(salon.piecesJointes) { piece in
                        VignettePiece(piece: piece) { salon.retirer(piece) }
                    }
                }
                .padding(.horizontal, Trame.ecran)
                .padding(.vertical, Trame.serre)
            }
            .scrollIndicators(.hidden)
            .transition(.scene)
        }
    }
}

/// Une vignette. L'échec RESTE affiché avec sa cause : une pièce qui disparaît
/// laisse croire qu'elle est partie.
struct VignettePiece: View {
    let piece: PieceJointe
    let retirer: () -> Void

    var body: some View {
        HStack(spacing: Trame.fin) {
            marque
            VStack(alignment: .leading, spacing: 0) {
                Text(piece.nom).legende().foregroundStyle(Teinte.encre).lineLimit(1)
                if case .echec(let raison) = piece.etat {
                    Text(raison).legende().foregroundStyle(Teinte.panne).lineLimit(1)
                }
            }
            Button(action: retirer) {
                Image(systemName: "xmark.circle.fill").imageScale(.small)
            }
            .buttonStyle(.appui)
            .foregroundStyle(Teinte.encreEteinte)
            .accessibilityLabel("Retirer \(piece.nom)")
        }
        .padding(.horizontal, Trame.serre)
        .padding(.vertical, Trame.fin)
        .frame(maxWidth: Trame.bulleMax * 0.6, alignment: .leading)
        .background(Teinte.surface)
        .clipShape(.rect(cornerRadius: Galbe.controle, style: .continuous))
        .lisere(Galbe.controle)
    }

    @ViewBuilder private var marque: some View {
        switch piece.etat {
        case .depot: ProgressView().controlSize(.mini).tint(Teinte.encreDouce)
        case .posee: Image(systemName: "paperclip").imageScale(.small)
                .foregroundStyle(Teinte.encreDouce)
        case .echec: Image(systemName: "exclamationmark.triangle.fill").imageScale(.small)
                .foregroundStyle(Teinte.panne)
        }
    }
}
#endif
