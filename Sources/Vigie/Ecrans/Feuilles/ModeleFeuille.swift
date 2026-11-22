// La feuille « Choisir le modèle » (étalon 003–006) : quatre modèles avec description et coche, carte « Effort »
// qui pousse la liste des efforts, carte « Autres modèles ». Le choix s'applique tout de suite à la session.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ModeleFeuille: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.dismiss) private var fermer
    let sessionId: String
    @State private var erreur: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Carte {
                        ForEach(Array(CatalogueModeles.principaux.enumerated()), id: \.offset) { i, m in
                            if i > 0 { Filet() }
                            rangeeModele(m)
                        }
                    }
                    Carte {
                        NavigationLink { EffortVue(sessionId: sessionId) } label: { rangeeEffort }.buttonStyle(.plain)
                    }
                    Carte {
                        NavigationLink { AutresModelesVue(sessionId: sessionId) } label: {
                            RangeeReglage(titre: "Autres modèles")
                        }
                        .buttonStyle(.plain)
                    }
                    if let erreur {
                        Text(erreur)
                            .font(Q.detail)
                            .foregroundStyle(Q.retraitTexte)
                            .padding(.horizontal, 32)
                    }
                }
                .padding(.top, 8)
            }
            .barreFeuille("Choisir le modèle")
            .toolbar { ToolbarItem(placement: .topBarLeading) { BoutonEntete(symbole: "xmark") { fermer() } } }
        }
        .feuilleQuart()
    }

    private var session: Session? { modele.session(sessionId) }

    private func rangeeModele(_ m: ModeleCatalogue) -> some View {
        Button { choisir(m.id) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.nom).font(Q.rangee).foregroundStyle(Q.texte)
                    Text(m.description).font(Q.detail).foregroundStyle(Q.secondaire)
                }
                Spacer()
                if CatalogueModeles.estCourant(m, session) {
                    Image(systemName: "checkmark").font(.system(size: 20, weight: .regular)).foregroundStyle(Q.coche)
                }
            }
            .padding(.horizontal, Q.marge).frame(height: 68).contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var rangeeEffort: some View {
        HStack(spacing: 8) {
            Text("Effort").font(Q.rangee).foregroundStyle(Q.texte)
            Spacer()
            if session?.effortSession == nil || session?.effortSession == .medium { Pilule(texte: "Recommandé") }
            Text(CatalogueModeles.libelleEffort(session?.effortSession) ?? "Par défaut").font(Q.rangee)
                .foregroundStyle(Q.secondaire)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .medium)).foregroundStyle(Q.meta)
        }
        .padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur).contentShape(.rect)
    }

    private func choisir(_ id: String) {
        Task {
            erreur = await modele.changerModele(id, de: sessionId)
            if erreur == nil { fermer() }
        }
    }
}

/// Les efforts (étalon 005) : coche, pilule « Recommandé », avertissement sur Max, Ultracode à part.
private struct EffortVue: View {
    @Environment(ModeleRelais.self) private var modele
    let sessionId: String
    @State private var erreur: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Carte {
                    ForEach(Array(EffortSession.allCases.enumerated()), id: \.offset) { i, e in
                        if i > 0 { Filet() }
                        rangee(e)
                    }
                    Filet()
                    rangeeUltracode
                }
                Text(erreur ?? "Un effort plus élevé donne des réponses plus approfondies, mais prend plus de temps et "
                     + "consomme tes limites plus vite.")
                    .font(Q.detail).foregroundStyle(erreur == nil ? Q.secondaire : Q.retraitTexte)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 8)
        }
        .barreFeuille("Effort")
    }

    private var session: Session? { modele.session(sessionId) }

    private func rangee(_ e: EffortSession) -> some View {
        Button { Task { erreur = await modele.changerEffort(e.rawValue, de: sessionId) } } label: {
            HStack(spacing: 8) {
                Text(CatalogueModeles.libelleEffort(e) ?? e.rawValue).font(Q.rangee).foregroundStyle(Q.texte)
                if e == .medium { Pilule(texte: "Recommandé") }
                if e == .max {
                    Pilule(texte: "3,5× ou plus d’usage", symbole: "exclamationmark.triangle",
                        fond: Q.avertissementFond, encre: Q.avertissement)
                }
                Spacer()
                if session?.effortSession == e {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20))
                        .foregroundStyle(Q.coche)
                }
            }
            .padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur).contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var rangeeUltracode: some View {
        let actif = session?.ultracode?.demande == true
        return Button { Task { erreur = await modele.basculerUltracode(!actif, de: sessionId) } } label: {
            HStack {
                Text("Ultracode").font(Q.rangee).foregroundStyle(Q.texte)
                Spacer()
                if actif { Image(systemName: "checkmark").font(.system(size: 20)).foregroundStyle(Q.coche) }
            }
            .padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur).contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(session?.ultracode?.disponible == false)
    }
}

/// Les autres modèles (étalon 006) : liste simple.
private struct AutresModelesVue: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.dismiss) private var retour
    let sessionId: String

    var body: some View {
        ScrollView {
            Carte {
                ForEach(Array(CatalogueModeles.autres.enumerated()), id: \.offset) { i, m in
                    if i > 0 { Filet() }
                    Button { Task { if await modele.changerModele(m.id, de: sessionId) == nil { retour() } } } label: {
                        HStack {
                            Text(m.nom).font(Q.rangee).foregroundStyle(Q.texte)
                            Spacer()
                            if CatalogueModeles.estCourant(m, modele.session(sessionId)) {
                                Image(systemName: "checkmark").foregroundStyle(Q.coche)
                            }
                        }
                        .padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur).contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
        .barreFeuille("Autres modèles")
    }
}
#endif
