// Le détail d'un appel (étalon 021 et 024) : description en tête, sections « Commande » / « Sortie » avec copier,
// ou diff pleine largeur (fond vert ou rouge sombre, liseré, « + » / « − » en marge) avec compteurs et chemin.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct DetailOutilVue: View {
    let appel: AppelOutil

    var body: some View {
        let d = DetailOutil.depuis(appel)
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let diff = d.diff, !diff.isEmpty {
                    EnteteDiff(detail: d)
                    DiffVue(lignes: diff)
                } else {
                    Text(d.titre).font(.system(size: 18)).foregroundStyle(Q.texte).lineSpacing(4)
                        .textSelection(.enabled).padding(.horizontal, Q.margeTexte).padding(.bottom, 12)
                    ForEach(Array(d.sections.enumerated()), id: \.offset) { _, s in
                        SectionDetail(section: s, erreur: estErreur(s))
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .barreFeuille(titreBarre(d))
    }

    private func titreBarre(_ d: DetailOutil) -> String {
        if let chemin = d.chemin, d.diff != nil { return (chemin as NSString).lastPathComponent }
        return appel.nom.hasPrefix("mcp__") ? ResumeOutils.nomMcpLisible(service: service, outil: outil) : appel.nom
    }

    private var service: String { ResumeOutils.analyser(appel.nom).service ?? "" }
    private var outil: String { ResumeOutils.analyser(appel.nom).outil }

    private func estErreur(_ s: DetailOutil.Section) -> Bool { s.libelle == "Sortie" && appel.resultat?.erreur == true }
}

private struct SectionDetail: View {
    let section: DetailOutil.Section
    let erreur: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(section.libelle).font(Q.section).foregroundStyle(Q.tertiaire)
                Spacer()
                BoutonCopier(texte: section.contenu)
            }
            .padding(.leading, Q.margeTexte).padding(.trailing, 12)
            if section.code {
                BlocCode(titre: nil, texte: section.contenu.isEmpty ? "(vide)" : section.contenu,
                         couleur: erreur ? Q.retraitTexte : Q.titre, copiable: false)
                    .padding(.horizontal, Q.marge)
            } else {
                Text(section.contenu).font(Q.corps).foregroundStyle(Q.texte).textSelection(.enabled)
                    .padding(.horizontal, Q.margeTexte)
            }
        }
        .padding(.bottom, 16)
    }
}

/// « +43 −0 · /chemin/du/dossier » sous le nom du fichier (étalon 024).
private struct EnteteDiff: View {
    let detail: DetailOutil

    var body: some View {
        HStack(spacing: 6) {
            Text("+\(detail.ajouts ?? 0)").foregroundStyle(Q.ajout)
            Text("−\(detail.suppressions ?? 0)").foregroundStyle(Q.retrait)
            Text("·").foregroundStyle(Q.tertiaire)
            Text(((detail.chemin ?? "") as NSString).deletingLastPathComponent).foregroundStyle(Q.secondaire)
                .lineLimit(1).truncationMode(.head)
        }
        .font(Q.detail).monospacedDigit()
        .padding(.horizontal, Q.margeTexte).padding(.bottom, 8)
    }
}

/// Le diff : une ligne par ligne, fond teinté, liseré de couleur à gauche, défilement horizontal commun.
private struct DiffVue: View {
    let lignes: [DetailOutil.LigneDiff]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lignes.enumerated()), id: \.offset) { _, l in ligne(l) }
            }
            .padding(.vertical, 8)
        }
        .background(Q.carte, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Q.pilule))
        .padding(.horizontal, Q.marge)
    }

    private func ligne(_ l: DetailOutil.LigneDiff) -> some View {
        HStack(spacing: 10) {
            Text(signe(l.genre)).foregroundStyle(couleur(l.genre)).frame(width: 12)
            Text(l.texte.isEmpty ? " " : l.texte).foregroundStyle(l.genre == .retrait ? Q.retraitTexte : Q.titre)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(Q.monoPetit)
        .padding(.leading, 12).padding(.trailing, 16).frame(minHeight: 22, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fond(l.genre))
        .overlay(alignment: .leading) { Rectangle().fill(couleur(l.genre)).frame(width: l.genre == .contexte ? 0 : 2) }
    }

    private func signe(_ g: DetailOutil.LigneDiff.Genre) -> String {
        switch g { case .ajout: "+"; case .retrait: "−"; case .contexte: " " }
    }

    private func couleur(_ g: DetailOutil.LigneDiff.Genre) -> Color {
        switch g { case .ajout: Q.ajout; case .retrait: Q.retrait; case .contexte: Q.tertiaire }
    }

    private func fond(_ g: DetailOutil.LigneDiff.Genre) -> Color {
        switch g { case .ajout: Q.fondAjout; case .retrait: Q.fondRetrait; case .contexte: .clear }
    }
}
#endif
