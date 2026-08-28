// Le bandeau de mesures d'un fil ouvert : moteur, contexte, compactions,
// machine, plafond. Défile horizontalement — tout ne tient pas sur 375 pt.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct EnTeteFilMeta: View {
    let detail: DetailFilApi
    /// La machine se lit sur la LISTE, pas sur le détail — le serveur ne la
    /// sert pas dans `DetailFilApi`.
    let machine: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Trame.serre) {
                if let modele = detail.model {
                    PuceDonnee(Lisible.moteur(modele: modele, effort: detail.effort))
                }
                if let contexte = detail.contextPct {
                    Text("ctx \(contexte) %")
                        .donneePetite()
                        .foregroundStyle(contexte >= 80 ? Teinte.vigilance : Teinte.encreDouce)
                        .padding(.horizontal, Trame.serre)
                        .padding(.vertical, 3)
                        .background(Teinte.fondCreux, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                if detail.compactions > 0 {
                    PuceDonnee("\(detail.compactions) compaction\(detail.compactions > 1 ? "s" : "")")
                }
                if let machine { PuceDonnee(machine) }
                PuceDonnee(detail.plafondAutonomie.libelle)
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.bottom, Trame.serre)
        }
    }
}
#endif
