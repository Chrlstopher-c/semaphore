// Le tiroir (étalon 015/016) : mot-symbole serif, entrée « Code » sélectionnée, épinglées, récentes, avatar et capsule
// « Nouvelle session » en bas. Les entrées de l'étalon sans objet chez nous
// (projets, artefacts, planifiées) sont absentes.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

enum ChoixTiroir {
    case code, session(String), nouvelle, reglages, machines
}

struct Tiroir: View {
    @Environment(ModeleRelais.self) private var modele
    let choisir: (ChoixTiroir) -> Void
    @State private var toutesEpinglees = false

    var body: some View {
        VStack(spacing: 0) {
            Text("Quart").font(Q.motSymbole).foregroundStyle(Q.texte)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).frame(height: 56)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EntreeTiroir(symbole: "chevron.left.forwardslash.chevron.right", titre: "Code", choisie: true) {
                        choisir(.code)
                    }
                    EntreeTiroir(symbole: "desktopcomputer", titre: "Machines") { choisir(.machines) }
                    epinglees
                    recentes
                }
                .padding(.bottom, 24)
            }
            pied
        }
        .background(Q.fondTiroir.ignoresSafeArea())
    }

    private var sessionsEpinglees: [Session] { modele.sessions.filter { $0.epinglee == true && $0.archivee != true } }

    @ViewBuilder private var epinglees: some View {
        let liste = sessionsEpinglees
        if !liste.isEmpty {
            TitreTiroir(texte: "Épinglées")
            ForEach(toutesEpinglees ? liste : Array(liste.prefix(4))) { s in
                EntreeSession(session: s, symbole: "pin") { choisir(.session(s.id)) }
            }
            if liste.count > 4 {
                Button { withAnimation(.smooth(duration: 0.3)) { toutesEpinglees.toggle() } } label: {
                    HStack(spacing: 6) {
                        Text(toutesEpinglees ? "Afficher moins" : "Tout afficher (\(liste.count))")
                        Image(systemName: toutesEpinglees ? "chevron.up" : "chevron.down").font(.system(size: 12))
                    }
                    .font(Q.detail).foregroundStyle(Q.tertiaire).padding(.horizontal, 24).frame(height: 44)
                }
            }
        }
    }

    @ViewBuilder private var recentes: some View {
        let liste = modele.sessions.filter { $0.archivee != true }.prefix(12)
        if !liste.isEmpty {
            TitreTiroir(texte: "Récentes")
            ForEach(Array(liste)) { s in
                EntreeSession(session: s, symbole: "chevron.left.forwardslash.chevron.right") {
                    choisir(.session(s.id))
                }
            }
        }
    }

    private var pied: some View {
        HStack {
            Button { choisir(.reglages) } label: {
                Text("C").font(.system(size: 17, weight: .medium)).foregroundStyle(Q.texte)
                    .frame(width: 44, height: 44).background(Color.black, in: .circle)
                    .overlay(Circle().strokeBorder(Q.lisere))
            }
            .buttonStyle(StyleAppui())
            .accessibilityLabel("Réglages")
            Spacer()
            CapsuleBlanche(titre: "Nouvelle session") { choisir(.nouvelle) }
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
    }
}

private struct TitreTiroir: View {
    let texte: String

    var body: some View {
        Text(texte).font(Q.detail).foregroundStyle(Q.tertiaire).padding(.horizontal, 24).padding(.top, 16)
            .padding(.bottom, 4)
    }
}

private struct EntreeTiroir: View {
    let symbole: String
    let titre: String
    var choisie = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbole).font(.system(size: 18, weight: .light)).frame(width: 26)
                Text(titre).font(Q.rangee).lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Q.texte).padding(.horizontal, 12).frame(height: 50)
            .background(choisie ? Q.selection : .clear, in: .rect(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 12).contentShape(.rect)
        }
        .buttonStyle(StyleAppui())
    }
}

private struct EntreeSession: View {
    let session: Session
    let symbole: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbole).font(.system(size: 15, weight: .light)).frame(width: 26)
                Text(session.titre).font(Q.rangee).lineLimit(1)
                Spacer(minLength: 8)
                marque
            }
            .foregroundStyle(Q.texte).padding(.horizontal, 24).frame(height: 50).contentShape(.rect)
        }
        .buttonStyle(StyleAppui())
    }

    @ViewBuilder private var marque: some View {
        if session.statut.enActivite {
            IndicateurTravail().frame(width: 18, height: 18)
        } else if session.nonLue == true || session.statut == .question {
            Circle().fill(Q.accent).frame(width: 8, height: 8)
        }
    }
}
#endif
