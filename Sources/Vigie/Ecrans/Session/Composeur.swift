// Le composeur (étalon 001/002). UN SEUL champ, toujours présent (le toucher donne le clavier) : au repos, capsule
// 52 pt « Réponds à Claude » entre « + » et arrêter ; au focus, la même forme s'agrandit en carte (champ en haut,
// rangée « + », pilule du modèle, envoyer / arrêter en bas) et monte avec le clavier. Pièces en vignettes au-dessus.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct Composeur: View {
    @Environment(ModeleRelais.self) private var modele
    let session: Session
    let ouvrirModele: () -> Void
    let ouvrirUsage: () -> Void
    let ouvrirTaches: () -> Void
    let erreur: (String) -> Void
    @State private var texte = ""
    @State private var pieces: [PieceSaisie] = []
    @State private var envoi = 0
    @State private var enEnvoi = false
    @FocusState private var focus: Bool

    private var etendu: Bool { focus || !texte.isEmpty || !pieces.isEmpty }
    private var pret: Bool { !texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pieces.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !pieces.isEmpty { BandePieces(pieces: $pieces).padding(.top, 12) }
            HStack(alignment: .center, spacing: 0) {
                if !etendu { plus }
                champ
                if !etendu && session.statut.enActivite { boutonArret }
            }
            if etendu { rangeeBas }
        }
        .padding(.horizontal, 4)
        .background(Q.carte, in: .rect(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(etendu ? Q.pilule : .clear))
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
        .background((etendu ? Q.fondFil : Q.entete).ignoresSafeArea(edges: .bottom))
        .animation(.smooth(duration: 0.25), value: etendu)
        .sensoryFeedback(.impact(weight: .medium), trigger: envoi)
    }

    private var champ: some View {
        TextField(etendu ? "Tape / pour les commandes" : invite, text: $texte, axis: .vertical)
            .font(Q.rangee).foregroundStyle(Q.texte).tint(Q.coche)
            .lineLimit(1...8)
            .focused($focus)
            .padding(.leading, etendu ? 12 : 4).padding(.trailing, 8)
            .padding(.top, etendu ? 14 : 0).padding(.bottom, etendu ? 6 : 0)
            .frame(minHeight: etendu ? 44 : 52)
            .contentShape(.rect)
            .simultaneousGesture(TapGesture().onEnded { focus = true }) // marges du champ comprises
    }

    private var rangeeBas: some View {
        HStack(spacing: 4) {
            plus
            PiluleModele(session: session, action: ouvrirModele)
            Spacer(minLength: 0)
            if enEnvoi {
                IndicateurTravail().frame(width: 18, height: 18).frame(width: 44, height: 44)
            } else if pret {
                BoutonRond(symbole: "arrow.up", fond: Q.texte, encre: Q.carte, poids: .semibold) { envoyer() }
                    .accessibilityLabel("Envoyer")
            } else if session.statut.enActivite {
                boutonArret
            }
        }
        .padding(.bottom, 4)
    }

    private var plus: some View {
        MenuPlus(session: session, pieces: $pieces, ouvrirUsage: ouvrirUsage, ouvrirTaches: ouvrirTaches,
                 erreur: erreur)
    }

    private var boutonArret: some View {
        Button { Task { if let e = await modele.interrompre(session.id) { erreur(e) } } } label: {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Q.texte).frame(width: 12, height: 12)
                .frame(width: 36, height: 36).background(Q.rond, in: .circle).frame(width: 44, height: 44)
        }
        .buttonStyle(StyleAppui())
        .accessibilityLabel("Interrompre")
    }

    private var invite: String {
        if session.statut.enActivite { return "Ajoute un message, il attendra la fin du tour" }
        return session.statut == .fermee ? "Réponds pour reprendre la session" : "Réponds à Claude"
    }

    private func envoyer() {
        let message = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        let jointes = pieces
        guard !message.isEmpty || !jointes.isEmpty else { return }
        texte = ""
        pieces = []
        envoi += 1
        enEnvoi = true
        Task {
            let corps = message.isEmpty ? "Pièce jointe" : message
            if let e = await modele.envoyer(corps, pieces: jointes.map(\.piece), a: session.id) {
                texte = message
                pieces = jointes
                erreur(e)
            }
            enEnvoi = false
        }
    }
}

/// Pilule « Opus 5.5 Moyen » (étalon 002) : ouvre la feuille du modèle.
private struct PiluleModele: View {
    let session: Session
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(CatalogueModeles.nom(session)).foregroundStyle(Q.texte)
                if let effort = CatalogueModeles.libelleEffort(session.effortSession) {
                    Text(effort).foregroundStyle(Q.tertiaire)
                }
            }
            .font(Q.detail).lineLimit(1)
            .padding(.horizontal, 14).frame(height: 36)
            .background(Q.rond, in: .capsule)
        }
        .buttonStyle(StyleAppui())
    }
}
#endif
