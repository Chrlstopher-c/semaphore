// Carte d'un mandat au fil de la conversation.
//
// `☠` Le contenu de l'évènement n'est que l'IDENTIFIANT de la proposition
// (`SegmentFil.mandat`) : la carte se remplit en croisant le miroir des
// propositions, et reste honnête sans correspondance. Trancher n'est PAS le
// rôle de cet écran — la file vit au Quart, et son badge se voit d'ici.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct VueMandatFil: View {
    let identifiant: String
    let at: Int
    let connue: PropositionApi?

    var body: some View {
        Panneau(rail: rail) {
            VStack(alignment: .leading, spacing: Trame.serre) {
                entete
                contenu
            }
        }
    }

    private var entete: some View {
        HStack(spacing: Trame.serre) {
            Sceau("Mandat", ton: .attention)
            statut
            Spacer(minLength: 0)
            Text(heureFil(at))
                .donneeMinuscule()
                .foregroundStyle(Teinte.encreTernie)
        }
    }

    /// L'état de la proposition, tel que le dernier relevé le connaît : un
    /// mandat déjà tranché ne doit pas continuer d'appeler au Quart.
    @ViewBuilder private var statut: some View {
        if let connue {
            switch connue.statut {
            case .approuvee: Sceau("autorisé", ton: .sain)
            case .refusee: Sceau("refusé", ton: .neutre)
            default: Sceau("à trancher au Quart", ton: .attention)
            }
        }
    }

    private var rail: Ton {
        guard let connue else { return .attention }
        return connue.statut == .enAttente ? .attention : .neutre
    }

    @ViewBuilder private var contenu: some View {
        if let connue {
            Text(connue.projet)
                .phraseForte()
                .foregroundStyle(Teinte.encre)
            Text(connue.objectif)
                .note()
                .foregroundStyle(Teinte.encreDouce)
                .lineLimit(3)
            // H-61 : le droit réel, jamais replié — même règle qu'au Quart.
            HStack(spacing: Trame.fin + 1) {
                Image(systemName: connue.acces.ouvreLEcriture ? "pencil.circle.fill" : "eye.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(Lisible.portee(connue.acces))
                    .mention()
            }
            .foregroundStyle(connue.acces.ouvreLEcriture ? Teinte.danger : Teinte.sain)
        } else {
            Text("Proposition « \(identifiant) » — le détail arrive au prochain relevé, "
                + "la file se tranche au Quart.")
                .note()
                .foregroundStyle(Teinte.encreDouce)
        }
    }
}
#endif
