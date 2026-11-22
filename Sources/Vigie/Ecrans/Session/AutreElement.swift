// Ce qui n'est ni un message, ni une réponse, ni une suite d'actions : réflexion repliée, liste de tâches, jalons,
// compaction, erreurs, pièces. Discret, en gris, comme les lignes secondaires de l'étalon.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct AutreElement: View {
    let element: ElementFil

    var body: some View {
        if case .simple(_, _, let evt) = element { contenu(evt) }
    }

    @ViewBuilder private func contenu(_ evt: Evenement) -> some View {
        switch evt {
        case .reflexion(let texte, _): Reflexion(texte: texte)
        case .taches(let taches): ListeTachesVue(taches: taches)
        case .etape(let resume, let suite): Jalon(symbole: "flag", titre: "Étape livrée", texte: "\(resume)\n→ \(suite)")
        case .objectifAtteint(let bilan): Jalon(symbole: "checkmark.circle", titre: "Objectif atteint", texte: bilan)
        case .question(let q): Jalon(symbole: "questionmark.circle", titre: "Question", texte: q)
        case .erreur(let m): Jalon(symbole: "exclamationmark.triangle", titre: "Erreur", texte: m, couleur: Q.retraitTexte)
        case .compaction(let avant, let apres, _):
            Signal(texte: "Contexte compacté · \(Format.tokens(avant)) → \(Format.tokens(apres))")
        case .relance(let raison): Signal(texte: raison)
        case .dialogueResolu(let d, let reponses, let decision): Signal(texte: resolu(d, reponses, decision))
        case .fichiersTour(_, let fichiers): Signal(texte: modifies(fichiers))
        case .tourAnnule: Signal(texte: "Modifications du tour annulées")
        case .image(_, let nom, _, _, _, _): Piece(symbole: "photo", nom: nom)
        case .fichier(_, let nom, _, let taille, _): Piece(symbole: "doc", nom: "\(nom) · \(Format.octets(Double(taille)))")
        case .relais(let sens, _, let titre, let texte):
            Jalon(symbole: "arrow.left.arrow.right", titre: sens == "sortant" ? "Envoyé à « \(titre) »" : "Reçu de « \(titre) »",
                  texte: texte)
        default: EmptyView()
        }
    }

    private func resolu(_ d: Dialogue, _ reponses: [String]?, _ decision: String?) -> String {
        if let decision {
            let mot = ["autoriser": "Autorisé", "toujours": "Toujours autorisé", "refuser": "Refusé"][decision] ?? decision
            return "\(mot) · \(d.permission?.outil ?? d.titre)"
        }
        return "\(d.titre) → \((reponses ?? []).joined(separator: ", "))"
    }

    private func modifies(_ fichiers: [FichierModifie]) -> String {
        let plus = fichiers.reduce(0) { $0 + $1.ajouts }, moins = fichiers.reduce(0) { $0 + $1.suppressions }
        return "\(fichiers.count) fichier\(fichiers.count > 1 ? "s" : "") modifié\(fichiers.count > 1 ? "s" : "") · +\(plus) −\(moins)"
    }
}

private struct Reflexion: View {
    let texte: String
    @State private var ouverte = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(.smooth(duration: 0.3)) { ouverte.toggle() } } label: {
                HStack(spacing: 6) {
                    Text("Réflexion").font(Q.detail)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .medium))
                        .rotationEffect(.degrees(ouverte ? 90 : 0))
                }
                .foregroundStyle(Q.tertiaire).frame(minHeight: 32).contentShape(.rect)
            }
            if ouverte {
                Text(texte).font(Q.detail).foregroundStyle(Q.tertiaire).lineSpacing(4).textSelection(.enabled)
            }
        }
    }
}

private struct ListeTachesVue: View {
    let taches: [TacheFil]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(taches.enumerated()), id: \.offset) { _, t in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: symbole(t.etat)).font(.system(size: 14))
                        .foregroundStyle(t.etat == .fait ? Q.ajout : (t.etat == .enCours ? Q.coche : Q.tertiaire))
                    Text(t.contenu).font(Q.detail).foregroundStyle(t.etat == .fait ? Q.tertiaire : Q.texte)
                        .strikethrough(t.etat == .fait, color: Q.tertiaire)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Q.carte, in: .rect(cornerRadius: Q.rayonCarte, style: .continuous))
    }

    private func symbole(_ e: TacheFil.Etat) -> String {
        switch e {
        case .fait: return "checkmark.circle.fill"
        case .enCours: return "circle.dotted"
        case .attente: return "circle"
        }
    }
}

private struct Jalon: View {
    let symbole: String
    let titre: String
    let texte: String
    var couleur: Color = Q.secondaire

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(titre, systemImage: symbole).font(.system(size: 15, weight: .semibold)).foregroundStyle(couleur)
            Text(texte).font(Q.detail).foregroundStyle(Q.texte).lineSpacing(4).textSelection(.enabled)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Q.carte, in: .rect(cornerRadius: Q.rayonCarte, style: .continuous))
    }
}

private struct Signal: View {
    let texte: String

    var body: some View {
        Text(texte).font(Q.petit).foregroundStyle(Q.tertiaire).frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Piece: View {
    let symbole: String
    let nom: String

    var body: some View {
        Label(nom, systemImage: symbole).font(Q.detail).foregroundStyle(Q.secondaire)
            .padding(.horizontal, 14).frame(height: 44)
            .background(Q.carte, in: .rect(cornerRadius: Q.rayonCarte, style: .continuous))
    }
}
#endif
