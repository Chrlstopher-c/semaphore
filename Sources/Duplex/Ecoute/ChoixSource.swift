// La sortie du PC qu'on capte. Une seule source : on la nomme. Plusieurs : un
// menu, pour que la salle reste une ligne — une liste de sources sous l'anneau
// serait un réglage qui prend la place du son.
#if canImport(SwiftUI)
import DuplexNoyau
import SwiftUI
import Systeme

struct ChoixSource: View {
    @Environment(Duplexeur.self) private var duplexeur

    var body: some View {
        if duplexeur.sources.count > 1 {
            menu
        } else if let seule = duplexeur.sources.first {
            Text(seule.nom).font(Voix.mention).foregroundStyle(Neutre.encreDouce)
        }
    }

    private var menu: some View {
        Menu {
            ForEach(duplexeur.sources) { source in
                Button {
                    Task { await duplexeur.choisirSource(source) }
                } label: {
                    if source.id == courante?.id {
                        Label(source.nom, systemImage: "checkmark")
                    } else {
                        Text(source.nom)
                    }
                }
            }
        } label: {
            HStack(spacing: Grille.fin) {
                Text(courante?.nom ?? "Sortie captée")
                Image(systemName: "chevron.up.chevron.down").imageScale(.small)
            }
            .font(Voix.mention)
            .foregroundStyle(Neutre.encreDouce)
            .frame(minHeight: Grille.cible)
            .contentShape(.rect)
        }
        .buttonStyle(.appui)
        .accessibilityLabel("Sortie captée : \(courante?.nom ?? "aucune")")
    }

    /// La source que le PC dit capter ; à défaut, celle qu'il propose par défaut.
    private var courante: SourceAudio? {
        if let id = duplexeur.etatPoste?.source, let source = duplexeur.sources.first(where: { $0.id == id }) {
            return source
        }
        return duplexeur.sources.first(where: \.defaut)
    }
}
#endif
