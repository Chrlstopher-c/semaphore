// Le composeur (étalon 001/002, mesuré au pixel). Bande #232323 pleine largeur. Au repos : capsule #20201F de 52 pt
// (marges 16, haut 8), « + » Ø 36 à 8 pt du bord, invite #97958D, micro Ø 36 puis arrêter Ø 36 à droite (écart 8).
// Au focus : carte #20201F rayon 24 à 8 pt des bords, champ en haut (retrait 17), rangée du bas « + », pilule du
// modèle, micro, arrêter / envoyer. Un seul champ, toujours présent : le toucher donne le clavier.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// Le champ de l'étalon, partagé par la session et la nouvelle session.
struct ChampSaisie<Plus: View, Pilule: View>: View {
    @Binding var texte: String
    @Binding var pieces: [PieceSaisie]
    let invite: String
    var travail = false
    var enEnvoi = false
    let envoyer: () -> Void
    var arreter: () -> Void = {}
    let erreur: (String) -> Void
    @ViewBuilder let plus: () -> Plus
    @ViewBuilder let pilule: () -> Pilule
    @FocusState private var focus: Bool
    @State private var dictee = Dictee.partage

    private var etendu: Bool { focus || !texte.isEmpty || !pieces.isEmpty || dictee.active }
    private var pret: Bool { !texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pieces.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !pieces.isEmpty { BandePieces(pieces: $pieces).padding(.top, 12) }
            HStack(spacing: 8) {
                if !etendu { plus() }
                champ
                if !etendu { micro; if travail { boutonArret } }
            }
            if etendu { rangeeBas }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, etendu ? 0 : 8)
        .background(Q.carte, in: .rect(cornerRadius: etendu ? 24 : 26, style: .continuous))
        .padding(.horizontal, etendu ? 8 : 16).padding(.top, 8).padding(.bottom, etendu ? 8 : 0)
        .background(Color(hex: 0x232323).ignoresSafeArea(edges: .bottom))
        .animation(.spring(duration: 0.35, bounce: 0), value: etendu)
        .onDisappear { if dictee.active { dictee.arreter() } }
    }

    private var champ: some View {
        ZStack(alignment: .topLeading) {
            TextField("", text: $texte, prompt: Text(etendu ? "Tape / pour les commandes" : invite)
                .foregroundStyle(Q.tertiaire), axis: .vertical)
                .font(Q.rangee).foregroundStyle(Q.texte).tint(Q.coche)
                .lineLimit(1...8)
                .focused($focus)
                .opacity(dictee.active ? 0 : 1)
            if dictee.active { TexteDicte(cumul: dictee.cumul) { dictee.arreter(); focus = true } }
        }
        .padding(.leading, etendu ? 9 : 7).padding(.top, etendu ? 16 : 0).padding(.bottom, etendu ? 18 : 0)
        .frame(minHeight: 36)
        .contentShape(.rect)
        .simultaneousGesture(TapGesture().onEnded { if !dictee.active { focus = true } }) // marges comprises
        .onChange(of: texte) { _, nouveau in dictee.champModifie(nouveau) }
    }


    private var rangeeBas: some View {
        HStack(spacing: 8) {
            plus()
            pilule()
            Spacer(minLength: 0)
            micro
            if enEnvoi {
                IndicateurTravail().frame(width: 18, height: 18).frame(width: 36, height: 36)
            } else if pret {
                Button(action: envoyer) {
                    Image(systemName: "arrow.up").font(.system(size: 16, weight: .semibold)).foregroundStyle(Q.carte)
                        .frame(width: 36, height: 36).background(Q.texte, in: .circle)
                }
                .buttonStyle(StyleAppui())
                .accessibilityLabel("Envoyer")
            } else if travail {
                boutonArret
            }
        }
        .padding(.bottom, 8)
    }

    /// Micro : dictée en français sur l'appareil, le texte s'écrit dans le champ.
    private var micro: some View {
        Button { basculerDictee() } label: {
            Image(systemName: dictee.active ? "waveform" : "mic").font(.system(size: 16))
                .foregroundStyle(dictee.active ? Q.carte : Q.secondaire)
                .symbolEffect(.variableColor.iterative, isActive: dictee.active)
                .frame(width: 36, height: 36).background(dictee.active ? Q.texte : Q.rond, in: .circle)
        }
        .buttonStyle(StyleAppui())
        .sensoryFeedback(.impact(weight: .light), trigger: dictee.active)
        .accessibilityLabel(dictee.active ? "Arrêter la dictée" : "Dicter")
    }

    private var boutonArret: some View {
        Button(action: arreter) {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Q.texte).frame(width: 12, height: 12)
                .frame(width: 36, height: 36).background(Q.rond, in: .circle)
        }
        .buttonStyle(StyleAppui())
        .accessibilityLabel("Interrompre")
    }

    private func basculerDictee() {
        if dictee.active { dictee.arreter(); return }
        focus = true
        Task {
            if let e = await dictee.demarrer(texteInitial: texte, miseAJour: { texte = $0 }) { erreur(e) }
        }
    }
}

/// Pilule « Opus 5.5 Moyen » (étalon 002) : Ø 36 de haut, #313131, nom blanc + effort gris.
struct PiluleModele: View {
    let nom: String
    let effort: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(nom).foregroundStyle(Q.texte)
                if let effort { Text(effort).foregroundStyle(Q.tertiaire) }
            }
            .font(Q.rangee).lineLimit(1)
            .padding(.horizontal, 14).frame(height: 36)
            .background(Q.rond, in: .capsule)
        }
        .buttonStyle(StyleAppui())
    }
}

/// Le composeur d'une session : envoi (avec pièces), interruption, modèle.
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

    var body: some View {
        ChampSaisie(texte: $texte, pieces: $pieces, invite: invite, travail: session.statut.enActivite,
                    envoyer: envoyer, arreter: interrompre, erreur: erreur) {
            MenuPlus(session: session, pieces: $pieces, ouvrirUsage: ouvrirUsage, ouvrirTaches: ouvrirTaches,
                     erreur: erreur)
        } pilule: {
            PiluleModele(nom: CatalogueModeles.nom(session),
                         effort: CatalogueModeles.libelleEffort(session.effortSession), action: ouvrirModele)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: envoi)
    }

    private var invite: String {
        if session.statut.enActivite { return "Ajoute un message, il attendra la fin du tour" }
        return session.statut == .fermee ? "Réponds pour reprendre la session" : "Réponds à Claude"
    }

    private func interrompre() {
        Task { if let e = await modele.interrompre(session.id) { erreur(e) } }
    }

    /// Optimiste : champ vidé et bulle posée tout de suite (le modèle la garde jusqu'au retour du message).
    private func envoyer() {
        let message = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        let jointes = pieces
        guard !message.isEmpty || !jointes.isEmpty else { return }
        if Dictee.partage.active { Dictee.partage.arreter() }
        texte = ""
        pieces = []
        envoi += 1
        Task {
            let corps = message.isEmpty ? "Pièce jointe" : message
            if let e = await modele.envoyer(corps, pieces: jointes.map(\.piece), a: session.id) {
                texte = message
                pieces = jointes
                erreur(e)
            }
        }
    }
}
/// La dictée en direct DANS le champ : l'acquis en blanc, le segment en cours estompé ; chaque mot entre en fondu
/// doux (interpolation de texte, aucune saccade) ; trois barres sobres respirent à droite. Toucher : arrêter et
/// reprendre la main au clavier (le texte reste modifiable).
private struct TexteDicte: View {
    let cumul: CumulDictee
    let reprendre: () -> Void

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            (Text(cumul.acquis).foregroundStyle(Q.texte)
                + Text(cumul.partiel.isEmpty || cumul.acquis.isEmpty ? cumul.partiel : " " + cumul.partiel)
                .foregroundStyle(Q.secondaire))
                .font(Q.rangee)
                .lineLimit(1...8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.interpolate)
                .animation(.easeOut(duration: 0.22), value: cumul)
                .overlay(alignment: .leading) {
                    if cumul.texte.isEmpty { Text("Je t’écoute…").font(Q.rangee).foregroundStyle(Q.tertiaire) }
                }
            Ecoute()
        }
        .contentShape(.rect)
        .onTapGesture(perform: reprendre)
        .accessibilityLabel("Dictée en cours : \(cumul.texte)")
    }
}

/// Indicateur d'écoute : trois barres qui respirent en décalé (transform seulement, rien de recalculé au rendu).
private struct Ecoute: View {
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(Q.coche).frame(width: 3, height: 14)
                    .phaseAnimator([0.35, 1.0]) { vue, phase in vue.scaleEffect(y: phase, anchor: .center) }
                        animation: { _ in .easeInOut(duration: 0.45).delay(Double(i) * 0.15) }
            }
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }
}
#endif
