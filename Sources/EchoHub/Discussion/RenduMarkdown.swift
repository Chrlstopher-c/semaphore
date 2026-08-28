// Le rendu de l'arbre Markdown. L'analyse vit dans le noyau et est testée ;
// cette vue ne fait que peindre selon la charte.
//
// `☠` Avant ce module, une réponse contenant du code arrivait en police
// proportionnelle avec les clôtures ` ``` ` visibles au milieu du texte, et les
// `**gras**` en clair. `AttributedString(markdown:)` n'aurait pas suffi : il ne
// connaît pas les blocs clôturés, donc il abîmerait précisément le cas qui
// compte.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct RenduMarkdown: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            ForEach(AnalyseMarkdown.analyser(source)) { indexe in
                rendre(indexe.bloc)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func rendre(_ bloc: BlocMarkdown) -> some View {
        switch bloc {
        case .titre(let niveau, let contenu):
            Text(assemblee(contenu))
                .font(niveau <= 2 ? Typo.titreSection : Typo.entete)
                .foregroundStyle(Teinte.encre)
        case .paragraphe(let contenu):
            Text(assemblee(contenu))
                .corps()
                .foregroundStyle(Teinte.encre)
                .lineSpacing(Typo.interligneReponse)
                .textSelection(.enabled)
        case .code(let langage, let texte, let complet):
            BlocCode(langage: langage, texte: texte, complet: complet)
        case .liste(let liste):
            RenduListe(liste: liste, profondeur: 0)
        case .citation(let contenu):
            citation(contenu)
        case .tableau(let tableau):
            RenduTableau(tableau: tableau)
        case .separateur:
            Rectangle().fill(Teinte.trait).frame(height: Trame.trait)
        }
    }

    /// Une citation descend d'un registre : c'est un rapport, pas ce que le
    /// modèle adresse à Chris.
    private func citation(_ contenu: [SegmentInline]) -> some View {
        HStack(alignment: .top, spacing: Trame.element) {
            Rectangle().fill(Teinte.trait).frame(width: Trame.trait * 2)
            Text(assemblee(contenu))
                .note()
                .foregroundStyle(Teinte.encreDouce)
                .lineSpacing(Typo.interligneNote)
        }
    }

    /// Les segments assemblés en un seul `Text` : ils doivent couler dans le
    /// même paragraphe, pas se poser côte à côte dans un `HStack` qui casserait
    /// le retour à la ligne au milieu d'une phrase.
    private func assemblee(_ segments: [SegmentInline]) -> AttributedString {
        segments.reduce(into: AttributedString()) { total, segment in
            total.append(RenduMarkdown.compose(segment))
        }
    }

    static func compose(_ segment: SegmentInline) -> AttributedString {
        var morceau = AttributedString(segment.brut)
        switch segment {
        case .texte:
            break
        case .fort:
            morceau.font = Typo.entete
        case .emphase:
            morceau.font = Typo.corps.italic()
        case .code:
            morceau.font = Typo.pensee
            morceau.foregroundColor = Teinte.accent
        case .lien(_, let cible):
            morceau.foregroundColor = Teinte.accent
            morceau.underlineStyle = .single
            if let url = URL(string: cible) { morceau.link = url }
        }
        return morceau
    }
}

/// Une liste, ses items, et ses sous-listes. La récursion est bornée par
/// l'analyseur (`AnalyseListe.profondeurMax`), pas par cette vue.
struct RenduListe: View {
    let liste: ListeMarkdown
    let profondeur: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            ForEach(Array(liste.items.enumerated()), id: \.offset) { rang, item in
                VStack(alignment: .leading, spacing: Trame.serre) {
                    HStack(alignment: .top, spacing: Trame.serre) {
                        Text(marque(rang))
                            .mesureFine()
                            .foregroundStyle(Teinte.encreEteinte)
                        Text(texte(item.contenu))
                            .corps()
                            .foregroundStyle(Teinte.encre)
                            .lineSpacing(Typo.interligneReponse)
                    }
                    if let sous = item.sousListe {
                        RenduListe(liste: sous, profondeur: profondeur + 1)
                            .padding(.leading, Trame.bloc)
                    }
                }
            }
        }
    }

    private func marque(_ rang: Int) -> String {
        liste.ordonnee ? "\(rang + 1)." : "•"
    }

    private func texte(_ segments: [SegmentInline]) -> AttributedString {
        segments.reduce(into: AttributedString()) { total, segment in
            total.append(RenduMarkdown.compose(segment))
        }
    }
}

/// Un bloc de code : chasse fixe, défilement HORIZONTAL, et un bouton copier.
///
/// `☠` Le défilement horizontal est ce qui rend le bloc utilisable sur 375 pt.
/// Sans lui, une ligne de code longue est repliée au milieu d'un identifiant et
/// devient illisible ; avec un repli désactivé et sans défilement, elle est
/// simplement coupée. Le conteneur défile, la page NON.
struct BlocCode: View {
    let langage: String
    let texte: String
    /// La clôture n'est pas arrivée. Pendant une génération c'est le cas normal
    /// du dernier bloc, et le dire évite de croire à une réponse tronquée.
    let complet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            entete
            ScrollView(.horizontal) {
                Text(texte)
                    .brut()
                    .foregroundStyle(Teinte.encre)
                    .lineSpacing(Typo.interligneMachine)
                    .textSelection(.enabled)
                    .padding(Trame.element)
            }
            .scrollIndicators(.hidden)
        }
        .background(Teinte.fond)
        .clipShape(.rect(cornerRadius: Galbe.controle, style: .continuous))
        .lisere(Galbe.controle)
    }

    private var entete: some View {
        HStack(spacing: Trame.serre) {
            Text(langage.isEmpty ? "code" : langage)
                .legende()
                .foregroundStyle(Teinte.encreEteinte)
            if !complet {
                Text("en cours").legende().foregroundStyle(Teinte.encreEteinte)
            }
            Spacer(minLength: 0)
            BoutonAction("Copier", symbole: "doc.on.doc") { Presse.poser(texte) }
        }
        .padding(.horizontal, Trame.element)
        .padding(.vertical, Trame.serre)
        .background(Teinte.surface)
    }
}
#endif
