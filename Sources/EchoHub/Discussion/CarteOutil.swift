// Un appel d'outil, lisible en un coup d'œil : quel outil, sur quoi, avec quelle
// issue. La lecture elle-même vit dans le noyau (`LectureAppel`, testé) ; cette
// vue ne fait que la peindre.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct CarteOutil: View {
    let appel: AppelLisible
    let deplie: Bool
    let surBascule: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Button(action: surBascule) { entete }
                .buttonStyle(.appui)
            if deplie { detail }
        }
        .padding(Trame.element)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Teinte.surface)
        .clipShape(.rect(cornerRadius: Galbe.carte, style: .continuous))
        .animation(Elan.surface, value: deplie)
    }

    private var entete: some View {
        HStack(spacing: Trame.element) {
            Image(systemName: glyphe)
                .imageScale(.medium)
                .foregroundStyle(ton.couleur)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: Trame.fin) {
                Text(appel.libelle).mention().foregroundStyle(Teinte.encre)
                if let cible = appel.cible {
                    Text(cible)
                        .brut()
                        .foregroundStyle(Teinte.encreDouce)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
            marque
        }
        .contentShape(.rect)
    }

    /// L'issue, à droite : c'est ce qu'on cherche en balayant une réponse qui a
    /// appelé cinq outils.
    @ViewBuilder private var marque: some View {
        switch appel.etat {
        case .enCours:
            ProgressView().tint(Teinte.accent).controlSize(.small)
        case .termine:
            Image(systemName: "checkmark").imageScale(.small).foregroundStyle(Teinte.ok)
        case .echec:
            Image(systemName: "xmark").imageScale(.small).foregroundStyle(Teinte.panne)
        case .interrompu:
            Image(systemName: "minus").imageScale(.small).foregroundStyle(Teinte.alerte)
        }
    }

    /// Ce que l'outil a reçu et ce qu'il a rendu — registre `machine` : c'est du
    /// texte de machine, il se lit comme tel.
    private var detail: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            partie("Entrée", appel.entree)
            if !appel.sortie.isEmpty { partie("Sortie", appel.sortie) }
        }
        .registre(.machine)
        .transition(.scene)
    }

    private func partie(_ titre: String, _ contenu: String) -> some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            Text(titre).rubrique()
            Text(contenu)
                .selonRegistre()
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ton: Ton {
        switch appel.etat {
        case .enCours: return .actif
        case .termine: return .ok
        case .echec: return .panne
        case .interrompu: return .alerte
        }
    }

    /// Les glyphes SF Symbols correspondant aux icônes nommées par le noyau. La
    /// table est ici et pas là-bas : le noyau ne connaît pas SwiftUI, et c'est
    /// ce qui le rend testable sur Linux.
    private var glyphe: String {
        switch appel.icone {
        case .loupe: return "magnifyingglass"
        case .globe: return "globe"
        case .document: return "doc.text"
        case .crayon: return "square.and.pencil"
        case .dossier: return "folder"
        case .terminal: return "terminal"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .cadre: return "rectangle.on.rectangle"
        case .outil: return "wrench.and.screwdriver"
        }
    }
}
#endif
