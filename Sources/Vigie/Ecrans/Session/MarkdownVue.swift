// Le rendu markdown d'une réponse (étalon 001/022) : paragraphes pleine largeur, liens soulignés,
// code en ligne bleu sur gris, listes à retrait suspendu, blocs de code en carte mono.
// Analyse par le moteur maison du noyau.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct MarkdownVue: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(CacheMarkdown.blocs(source)) { b in BlocMarkdownVue(bloc: b.bloc) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Analyse markdown mémorisée par texte : une réponse n'est analysée qu'une fois, pas à chaque rendu.
@MainActor enum CacheMarkdown {
    private final class Boite { let blocs: [BlocRange]; init(_ b: [BlocRange]) { blocs = b } }
    private static let cache: NSCache<NSString, Boite> = {
        let c = NSCache<NSString, Boite>()
        c.countLimit = 400
        return c
    }()

    static func blocs(_ source: String) -> [BlocRange] {
        let cle = source as NSString
        if let b = cache.object(forKey: cle) { return b.blocs }
        let blocs = AnalyseurMarkdown.blocs(source)
        cache.setObject(Boite(blocs), forKey: cle)
        return blocs
    }
}

private struct BlocMarkdownVue: View {
    let bloc: BlocMarkdown

    var body: some View {
        switch bloc {
        case .titre(let niveau, let contenu):
            Text(Inline.texte(contenu))
                .font(.system(size: niveau <= 1 ? 22 : (niveau == 2 ? 20 : 18), weight: .semibold))
                .foregroundStyle(Q.texte).padding(.top, 4)
        case .paragraphe(let contenu): Paragraphe(contenu: contenu)
        case .liste(let entrees): ListeVue(entrees: entrees)
        case .code(let langage, let texte, _): BlocCode(titre: langage, texte: texte)
        case .tableau(let t): TableauVue(tableau: t)
        case .citation(let contenu):
            Paragraphe(contenu: contenu).padding(.leading, 14)
                .overlay(alignment: .leading) { Capsule().fill(Q.rond).frame(width: 3) }
        case .filet: Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
        }
    }
}

struct Paragraphe: View {
    let contenu: [FragmentTexte]

    var body: some View {
        Text(Inline.texte(contenu)).font(Q.corpsFil).foregroundStyle(Q.texte).lineSpacing(Q.interligneFil)
            .tint(Q.texte).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
    }
}

/// Les fragments en `AttributedString` : gras, italique, barré, code en ligne (#6DA7EC sur #262626), liens soulignés.
enum Inline {
    static func texte(_ fragments: [FragmentTexte]) -> AttributedString {
        var sortie = AttributedString()
        for f in fragments {
            var morceau = AttributedString(f.styles.contains(.code) ? "\u{2009}\(f.texte)\u{2009}" : f.texte)
            appliquer(f, &morceau)
            sortie.append(morceau)
        }
        return sortie
    }

    private static func appliquer(_ f: FragmentTexte, _ m: inout AttributedString) {
        if f.styles.contains(.code) {
            m.font = .system(size: 15, design: .monospaced)
            m.foregroundColor = Q.lien
            m.backgroundColor = Q.codeEnLigne
            return
        }
        var police = Font.system(size: 17, weight: f.styles.contains(.gras) ? .semibold : .regular)
        if f.styles.contains(.italique) { police = police.italic() }
        m.font = police
        if f.styles.contains(.barre) { m.strikethroughStyle = .single }
        if let lien = f.lien, let url = URL(string: lien) {
            m.link = url
            m.underlineStyle = .single
        }
    }
}

private struct ListeVue: View {
    let entrees: [EntreeListe]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(entrees.enumerated()), id: \.offset) { _, e in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    puce(e).frame(minWidth: 18, alignment: .trailing)
                    Paragraphe(contenu: e.contenu)
                }
                .padding(.leading, CGFloat(e.niveau) * 20)
            }
        }
    }

    @ViewBuilder private func puce(_ e: EntreeListe) -> some View {
        if let coche = e.cochee {
            Image(systemName: coche ? "checkmark.square.fill" : "square").foregroundStyle(Q.secondaire)
        } else if e.puce.first?.isNumber == true {
            Text(e.puce).font(.system(size: 17, weight: .semibold)).foregroundStyle(Q.texte).monospacedDigit()
        } else {
            Text("•").font(.system(size: 17, weight: .bold)).foregroundStyle(Q.texte)
        }
    }
}

/// Bloc de code (étalon 021) : carte #20201F, liseré, texte mono défilant à l'horizontale, bouton copier.
struct BlocCode: View {
    let titre: String?
    let texte: String
    var couleur: Color = Q.codeTexte

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(texte).font(Q.mono).foregroundStyle(couleur).lineSpacing(4).textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: false)
                .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Q.carte, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Q.pilule))
        .overlay(alignment: .topTrailing) { BoutonCopier(texte: texte).padding(4) }
    }
}

struct BoutonCopier: View {
    let texte: String
    @State private var copie = false

    var body: some View {
        Button {
            UIPasteboard.general.string = texte
            copie = true
            Task { try? await Task.sleep(for: .seconds(1.5)); copie = false }
        } label: {
            Image(systemName: copie ? "checkmark" : "square.on.square").font(.system(size: 15))
                .foregroundStyle(Q.tertiaire).frame(width: 40, height: 40).contentShape(.rect)
        }
        .sensoryFeedback(.success, trigger: copie) { _, nouveau in nouveau }
        .accessibilityLabel("Copier")
    }
}

private struct TableauVue: View {
    let tableau: TableauMarkdown

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow { ForEach(0..<tableau.colonnes, id: \.self) { cellule(tableau.entete, $0, gras: true) } }
                Divider().overlay(Color.white.opacity(0.15))
                ForEach(Array(tableau.lignes.enumerated()), id: \.offset) { _, ligne in
                    GridRow { ForEach(0..<tableau.colonnes, id: \.self) { cellule(ligne, $0, gras: false) } }
                }
            }
            .padding(14)
        }
        .background(Q.carte, in: .rect(cornerRadius: Q.rayonCarte, style: .continuous))
    }

    private func cellule(_ ligne: [[FragmentTexte]], _ i: Int, gras: Bool) -> some View {
        Text(i < ligne.count ? Inline.texte(ligne[i]) : "").font(.system(size: 15, weight: gras ? .semibold : .regular))
            .foregroundStyle(Q.texte)
    }
}
#endif
