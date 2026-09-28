// Un appel d'outil et un sous-agent dans le fil : `DisclosureGroup` natifs — une ligne, et tout le détail au toucher.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct LigneOutil: View {
    let appel: AppelOutil
    let dossier: String

    var body: some View {
        DisclosureGroup {
            BlocCode(titre: "Entrée", texte: appel.detail, erreur: false)
            if let r = appel.resultat { BlocCode(titre: r.erreur ? "Erreur" : "Résultat", texte: r.extrait, erreur: r.erreur) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: Charte.symbole(appel.nom)).foregroundStyle(appel.resultat?.erreur == true ? .red : .secondary)
                Text(appel.nom).font(.footnote.weight(.semibold))
                Text(appel.resume.replacingOccurrences(of: dossier + "/", with: ""))
                    .font(.footnote.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                if appel.resultat == nil { ProgressView().controlSize(.mini) }
            }
        }
        .tint(.secondary)
    }
}

struct LigneSousAgent: View {
    let agent: SousAgent
    let dossier: String

    var body: some View {
        DisclosureGroup {
            ForEach(agent.interieur) { element in
                if case .outil(let o) = element { LigneOutil(appel: o, dossier: dossier) }
            }
            if let rapport = agent.rapport { BlocCode(titre: agent.fin == nil ? "Dernier message" : "Rapport", texte: rapport, erreur: false) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Charte.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(agent.description.isEmpty ? "Sous-agent" : agent.description).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text("\(agent.genre) · \(agent.nombreOutils) outil\(agent.nombreOutils > 1 ? "s" : "") · \(agent.fin == nil ? "en cours" : "terminé")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
        .tint(.secondary)
    }
}

private struct BlocCode: View {
    let titre: String
    let texte: String
    let erreur: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titre).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(texte.isEmpty ? "—" : String(texte.prefix(3_000))).font(.caption.monospaced())
                    .foregroundStyle(erreur ? .red : .primary).textSelection(.enabled)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: 220, alignment: .topLeading)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.vertical, 2)
    }
}
#endif
