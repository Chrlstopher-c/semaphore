// La feuille « Usage » (étalon 007–010, 018) : fenêtre de contexte (dépliable par catégorie), puis l'usage du compte
// de la session relevé par sa machine — session de 5 h, limites hebdomadaires — avec l'heure de remise à zéro.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct UsageFeuille: View {
    @Environment(\.dismiss) private var fermer
    let sessionId: String?

    var body: some View {
        NavigationStack {
            UsageContenu(sessionId: sessionId)
                .toolbar { ToolbarItem(placement: .topBarLeading) { BoutonEntete(symbole: "xmark") { fermer() } } }
        }
        .feuilleQuart()
    }
}

/// Le contenu, partagé par la feuille de session et la page « Usage » des réglages (sans session : comptes seuls).
struct UsageContenu: View {
    @Environment(ModeleRelais.self) private var modele
    let sessionId: String?
    @State private var contexte: ContexteSession?
    @State private var erreur: String?
    @State private var deplie = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if sessionId != nil {
                    TitreSection(texte: "Contexte")
                    carteContexte
                }
                ForEach(comptes, id: \.id) { c in SectionsCompte(compte: c, plusieurs: comptes.count > 1) }
                if comptes.isEmpty {
                    Text("Aucun relevé d’usage pour l’instant.").font(Q.detail).foregroundStyle(Q.tertiaire)
                        .padding(.horizontal, 32).padding(.top, 24)
                }
            }
            .padding(.bottom, 24)
        }
        .barreFeuille("Usage")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BoutonEntete(symbole: "arrow.clockwise") {
                    Task { await charger() }
                }
            }
        }
        .task { await charger() }
    }

    private var comptes: [EtatCompte] {
        if let s = sessionId.flatMap(modele.session) {
            let liste = modele.machine(s.machine)?.etatComptes ?? []
            let correspondants = liste.filter { $0.id == s.compte }
            return correspondants.isEmpty ? liste.filter(\.defaut) : correspondants
        }
        var vus = Set<String>()
        return modele.machines.flatMap(\.etatComptes).filter { vus.insert($0.email ?? $0.id).inserted }
    }

    private var carteContexte: some View {
        let s = sessionId.flatMap(modele.session)
        let utilises = contexte?.utilises ?? s?.contexte.tokens ?? 0
        let fenetre = contexte?.fenetre ?? s?.contexte.max ?? 0
        let part = fenetre > 0 ? Double(utilises) / Double(fenetre) : 0
        return Carte {
            Button { withAnimation(.smooth(duration: 0.3)) { deplie.toggle() } } label: {
                JaugeUsage(
                    titre: "Fenêtre de contexte", part: part,
                    note: "\(Format.tokens(utilises)) sur \(Format.tokens(fenetre)) jetons",
                    chevron: contexte == nil ? nil : (deplie ? "chevron.up" : "chevron.down"))
            }
            .buttonStyle(.plain)
            if deplie, let contexte { Filet(); CategoriesContexte(contexte: contexte) }
            if let erreur { Filet(); Text(erreur).font(Q.detail).foregroundStyle(Q.tertiaire).padding(Q.marge) }
        }
    }

    private func charger() async {
        guard let sessionId else { return }
        switch await modele.contexte(de: sessionId) {
        case .success(let c): contexte = c; erreur = nil
        case .failure(let e): erreur = e.description
        }
    }
}

/// Une jauge en carte : titre, « N % utilisé », barre, note (étalon 008).
struct JaugeUsage: View {
    let titre: String
    let part: Double
    let note: String?
    var chevron: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(titre).font(.system(size: 18)).foregroundStyle(Q.texte)
                Spacer()
                Text("\(Int((part * 100).rounded())) % utilisé")
                    .font(Q.rangee)
                    .foregroundStyle(Q.secondaire)
                    .monospacedDigit()
                if let chevron {
                    Image(systemName: chevron)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Q.secondaire)
                }
            }
            Jauge(part: part)
            if let note { Text(note).font(Q.detail).foregroundStyle(Q.tertiaire) }
        }
        .padding(Q.marge).contentShape(.rect)
    }
}

private struct CategoriesContexte: View {
    let contexte: ContexteSession
    private let teintes: [Color] = [Q.accent, Color(hex: 0xE0612D), Color(hex: 0x16A06B), Color(hex: 0xD69A0E)]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array((contexte.categories + contexte.categoriesDifferees).enumerated()), id: \.offset) { i, c in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < teintes.count ? teintes[i] : Q.tertiaire)
                        .frame(width: 9, height: 9)
                    Text(c.libelle).font(Q.rangee).foregroundStyle(Q.texte).lineLimit(1)
                    Spacer()
                    Text(Format.tokens(c.jetons)).font(Q.rangee).foregroundStyle(Q.secondaire).monospacedDigit()
                }
            }
        }
        .padding(Q.marge)
    }
}

/// Les fenêtres d'un compte : session de 5 h, limites hebdomadaires (toutes, puis par modèle).
private struct SectionsCompte: View {
    let compte: EtatCompte
    let plusieurs: Bool

    var body: some View {
        if let s = compte.session {
            TitreSection(texte: plusieurs ? "Session · \(compte.email ?? compte.id)" : "Usage de l’offre")
            Carte { JaugeUsage(titre: "Session en cours", part: s.pourcent / 100, note: remise(s)) }
        }
        let hebdo = [compte.semaine].compactMap { $0 } + compte.autres
        if !hebdo.isEmpty {
            TitreSection(texte: "Limites hebdomadaires")
            Carte {
                ForEach(Array(hebdo.enumerated()), id: \.offset) { i, f in
                    if i > 0 { Filet() }
                    JaugeUsage(
                        titre: i == 0 && compte.semaine != nil ? "Tous les modèles" : f.libelle,
                        part: f.pourcent / 100,
                        note: remise(f))
                }
            }
        }
        if let p = compte.probleme {
            Text(p)
                .font(Q.detail)
                .foregroundStyle(Q.tertiaire)
                .padding(.horizontal, 32)
                .padding(.top, 8)
        }
    }

    private func remise(_ f: FenetreUsage) -> String? {
        guard let iso = f.reinitialiseLe, let date = DateRelative.date(iso) else { return nil }
        let memeJour = Calendar.current.isDateInToday(date)
        return "Remise à zéro " + (memeJour ? "à " + date.formatted(date: .omitted, time: .shortened)
                                            : "le " + date.formatted(.dateTime.weekday(.wide).hour().minute()))
    }
}
#endif
