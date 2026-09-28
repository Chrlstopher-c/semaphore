// Les sessions du parc, regroupées par machine ; un bouton pour en lancer une nouvelle.
// Cet écran sert à choisir une session ; l'élément dominant est la liste des sessions ouvertes.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ListeSessionsEcran: View {
    @Environment(ModeleRelais.self) private var modele
    @Environment(\.palette) private var p
    @State private var toutes = false
    @State private var nouvelle = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espace.l) {
                EnTeteEcran(surtitre: etatLien, titre: "Sessions") {
                    Button { nouvelle = true } label: { Image(systemName: "plus").font(.system(size: 18, weight: .bold)) }
                        .buttonStyle(StyleBoutonPlein())
                        .accessibilityLabel("Nouvelle session")
                }
                Picker("Filtre", selection: $toutes) {
                    Text("Ouvertes").tag(false)
                    Text("Toutes").tag(true)
                }
                .pickerStyle(.segmented).padding(.horizontal, Espace.marge)
                groupes
            }
            .padding(.bottom, Espace.xxl)
        }
        .background(p.fond.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $nouvelle) { NouvelleSessionFeuille() }
        .refreshable { modele.arreter(); modele.demarrer() }
    }

    private var etatLien: String {
        switch modele.lien {
        case .connecte: return "relais connecté"
        case .attente: return "connexion…"
        case .coupe: return "relais injoignable"
        case .nonConnecte: return "non connecté"
        }
    }

    @ViewBuilder private var groupes: some View {
        let visibles = modele.sessions.filter { toutes || $0.ouverte }
        if visibles.isEmpty {
            EtatVide(symbole: "bubble.left.and.text.bubble.right", titre: "Aucune session ouverte",
                     texte: "Lance-en une sur n’importe quelle machine du parc.")
        }
        ForEach(Dictionary(grouping: visibles, by: \.machine).sorted { $0.key < $1.key }, id: \.key) { machine, liste in
            VStack(alignment: .leading, spacing: Espace.s) {
                Surtitre(texte: machine).padding(.horizontal, Espace.marge)
                VStack(spacing: 0) {
                    ForEach(liste) { s in
                        NavigationLink(value: s.id) { LigneSession(session: s) }.buttonStyle(.plain)
                        if s.id != liste.last?.id { Divider().overlay(p.filet).padding(.leading, Espace.xl + Espace.m) }
                    }
                }
                .background(RoundedRectangle(cornerRadius: Rayon.carte, style: .continuous).fill(p.surface))
                .overlay(RoundedRectangle(cornerRadius: Rayon.carte, style: .continuous).strokeBorder(p.filet))
                .padding(.horizontal, Espace.marge)
            }
        }
    }
}

struct LigneSession: View {
    @Environment(\.palette) private var p
    let session: Session

    var body: some View {
        HStack(spacing: Espace.m) {
            PointEtat(ton: ton(session.statut))
            VStack(alignment: .leading, spacing: Espace.xs) {
                Text(session.titre).font(Voix.courant.weight(.bold)).foregroundStyle(p.encre).lineLimit(1)
                Text("\(session.projet.nom) · \(session.statut.libelle.lowercased())")
                    .font(Voix.etiquette).foregroundStyle(p.discret).lineLimit(1)
            }
            Spacer(minLength: Espace.s)
            if session.statut == .question { Pastille(texte: "?", ton: .alerte) }
            Text(session.contexte.tokens > 0 ? Format.tokens(session.contexte.tokens) : Format.depuis(session.majLe))
                .font(Voix.chiffre).foregroundStyle(p.discret).monospacedDigit()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(p.discret)
        }
        .padding(.horizontal, Espace.l)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}

func ton(_ statut: StatutSession) -> PointEtat.Ton {
    switch statut {
    case .demarrage, .travail, .compaction: return .actif
    case .attente, .terminee: return .calme
    case .question, .erreur: return .alerte
    case .fermee: return .eteint
    }
}
#endif
