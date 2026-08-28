// Une carte d'item dans la besace. Un seul type pour les cinq espèces : la
// vignette et la ligne de tête changent, le reste est commun.
#if canImport(SwiftUI)
import SwiftUI
import SailyNoyau

struct CarteItem: View {
    let item: Item
    let surEpingle: () -> Void
    let surSuppression: () -> Void
    /// Éditer l'item. `nil` pour les espèces non éditables (image/vidéo/fichier),
    /// ce qui retire le geste et l'entrée de menu.
    var surEdition: (() -> Void)?

    var body: some View {
        Panneau {
            HStack(alignment: .top, spacing: Trame.element) {
                vignette
                VStack(alignment: .leading, spacing: Trame.serre) {
                    tete
                    corps
                    if !item.tags.isEmpty { tags }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(.rect)
        // `☠` Cohabitation tap / lien : sur iOS 18, un tap qui tombe sur un run
        // `.link` d'un `Text(AttributedString)` déclenche `openURL` et a la
        // priorité sur ce `onTapGesture` d'ancêtre ; un tap ailleurs édite. Le
        // lien reste donc prioritaire dans le rendu, et « Modifier » du menu
        // contextuel est le chemin d'édition GARANTI, quelle que soit la façon
        // dont la plateforme arbitre le geste.
        .onTapGesture { surEdition?() }
        .contextMenu { menu }
    }

    // MARK: - Vignette

    @ViewBuilder
    private var vignette: some View {
        if let blob = item.blob, item.kind == .image {
            ApercuBlob(nom: blob, cote: Trame.vignette)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: Galbe.controle, style: .continuous)
                    .fill(Teinte.surfaceHaute)
                Image(systemName: symboleEspece)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Teinte.encreDouce)
            }
            .frame(width: Trame.vignette, height: Trame.vignette)
        }
    }

    // MARK: - Tête, corps, tags

    private var tete: some View {
        HStack(spacing: Trame.serre) {
            if item.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Teinte.accent)
            }
            Text(titreEspece)
                .rubrique()
            Spacer(minLength: 0)
            Text(dateRelative)
                .mesure()
                .foregroundStyle(Teinte.encreEteinte)
        }
    }

    @ViewBuilder
    private var corps: some View {
        if item.kind == .lien, let url = item.url {
            if !item.text.isEmpty {
                NoteRendue(texte: item.text, lignesMax: 2)
            }
            Text(url).brut().foregroundStyle(Teinte.accent).lineLimit(1)
        } else if item.kind == .note, !item.text.isEmpty {
            // Une note : rendu formaté, retours préservés, aperçu borné à ~8
            // lignes sans écraser le formatage.
            NoteRendue(texte: item.text, lignesMax: 8)
        } else if !texteAffiche.isEmpty {
            // Les autres espèces (fichier avec légende) restent en texte simple :
            // rien à formater, et le nom de blob n'est pas du markdown.
            Text(texteAffiche)
                .corps()
                .foregroundStyle(Teinte.encre)
                .lineSpacing(Typo.interligneNote)
                .lineLimit(2)
        }
    }

    private var tags: some View {
        // Enveloppe simple : les tags d'un item tiennent sur une ou deux lignes.
        FlotTags(tags: item.tags)
    }

    private var menu: some View {
        Group {
            if let surEdition {
                Button {
                    surEdition()
                } label: {
                    Label("Modifier", systemImage: "pencil")
                }
            }
            Button {
                surEpingle()
            } label: {
                Label(item.pinned ? "Désépingler" : "Épingler", systemImage: "pin")
            }
            Button(role: .destructive) {
                surSuppression()
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    // MARK: - Dérivé

    private var texteAffiche: String {
        item.text.isEmpty ? nomFichierLisible : item.text
    }

    private var nomFichierLisible: String {
        item.blob ?? ""
    }

    private var symboleEspece: String {
        switch item.kind {
        case .note: return "note.text"
        case .lien: return "link"
        case .image: return "photo"
        case .video: return "play.rectangle"
        case .fichier: return "doc"
        }
    }

    private var titreEspece: String {
        switch item.kind {
        case .note: return "Note"
        case .lien: return "Lien"
        case .image: return "Image"
        case .video: return "Vidéo"
        case .fichier: return "Fichier"
        }
    }

    /// Un horodatage relatif court, calculé depuis `updatedAt` (ms).
    private var dateRelative: String {
        let date = Date(timeIntervalSince1970: Double(item.updatedAt) / 1000)
        let ecart = Date().timeIntervalSince(date)
        switch ecart {
        case ..<60: return "à l'instant"
        case ..<3600: return "\(Int(ecart / 60)) min"
        case ..<86_400: return "\(Int(ecart / 3600)) h"
        default: return "\(Int(ecart / 86_400)) j"
        }
    }
}

/// Un flot de tags qui passe à la ligne. Écrit maison : `HStack` déborderait,
/// et une grille figerait des colonnes.
struct FlotTags: View {
    let tags: [String]

    var body: some View {
        // Deux rangs au plus dans une carte : au-delà, l'item devient un mur.
        HStack(spacing: Trame.serre) {
            ForEach(tags.prefix(4), id: \.self) { tag in
                Etiquette(tag)
            }
            if tags.count > 4 {
                Text("+\(tags.count - 4)").legende().foregroundStyle(Teinte.encreEteinte)
            }
        }
    }
}
#endif
