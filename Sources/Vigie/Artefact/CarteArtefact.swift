// Carte d'un artefact dans le fil : un contenu que l'orchestrateur produit
// lui-même — script shell/Python/Lua ou page HTML — affiché comme un bloc
// dédié, pas noyé dans une bulle de texte (mandat « artefacts »).
//
// `☠` LE RENDU HTML EST DU CONTENU NON FIABLE, produit par un modèle. Il passe
// par `RenduHTMLIsole`, qui ne partage ni cookies, ni stockage, ni session
// avec Vigie et ne navigue nulle part — voir sa documentation pour le
// mécanisme. Cette carte-ci ne fait qu'afficher le code EN CLAIR (texte, pas
// de script exécuté) et basculer vers ce cadre isolé sur demande.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct CarteArtefact: View {
    /// `nil` : l'évènement est arrivé sans pièce — le fichier a disparu du
    /// disque du Pi. Même trou que le front web (`!piece.url`).
    let piece: PieceJointeApi?
    @Environment(\.clientPi) private var client

    @State private var texte: String?
    @State private var echec = false
    @State private var vueRendu = false
    /// Copie locale du contenu, nommée comme la pièce distante — c'est elle
    /// que la feuille de partage iOS exporte ou envoie.
    @State private var fichierPartage: URL?

    private var langage: LangageArtefact? {
        piece.flatMap { LangageArtefact.depuis(nomFichier: $0.nom) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let piece {
                entete(piece)
                FiletFin()
                corps(piece)
            } else {
                indisponible
            }
        }
        .background(Teinte.surface, in: RoundedRectangle(cornerRadius: Galbe.panneau, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Galbe.panneau, style: .continuous)
                .strokeBorder(Teinte.filet, lineWidth: Trame.trait)
        )
        .clipShape(RoundedRectangle(cornerRadius: Galbe.panneau, style: .continuous))
        .task(id: piece?.url) { await charger() }
    }

    // MARK: - En-tête : badge de langage, nom, taille, actions

    private func entete(_ piece: PieceJointeApi) -> some View {
        HStack(spacing: Trame.serre) {
            Sceau(langage?.libelle ?? "Artefact", ton: .neutre)
            Text(piece.nom)
                .note()
                .foregroundStyle(Teinte.encreDouce)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Trame.serre)
            Text(tailleLisible(piece.taille))
                .donneeMinuscule()
                .foregroundStyle(Teinte.encreTernie)
            if langage?.seRend == true { bascule }
            partage
        }
        .padding(.horizontal, Trame.element)
        .padding(.vertical, Trame.serre)
        .background(Teinte.surfaceHaute)
    }

    @ViewBuilder private var bascule: some View {
        HStack(spacing: 3) {
            ongletBascule("Code", actif: !vueRendu) { vueRendu = false }
            ongletBascule("Rendu", actif: vueRendu) { vueRendu = true }
        }
        .sensoryFeedback(Haptique.selection, trigger: vueRendu)
    }

    private func ongletBascule(_ titre: String, actif: Bool, action: @escaping () -> Void) -> some View {
        Button(titre, action: action)
            .buttonStyle(.allurePuce(actif ? .attention : .neutre))
    }

    @ViewBuilder private var partage: some View {
        if let fichierPartage {
            ShareLink(item: fichierPartage) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.allureIcone)
            .accessibilityLabel("Partager ou exporter")
        } else {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Teinte.encreTernie.opacity(0.4))
                .frame(width: Trame.cible, height: Trame.cible)
        }
    }

    // MARK: - Corps : code lisible, ou rendu isolé pour le HTML

    @ViewBuilder private func corps(_ piece: PieceJointeApi) -> some View {
        if vueRendu, langage?.seRend == true, let texte {
            RenduHTMLIsole(html: texte)
                .frame(height: 340)
        } else if let texte {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(texte)
                    .texteTerminal()
                    .foregroundStyle(Teinte.terminalTexte)
                    .textSelection(.enabled)
                    .padding(Trame.element)
            }
            .frame(maxHeight: 340)
            .background(Teinte.terminalFond)
        } else if echec {
            BandeauNote("Artefact introuvable sur le Pi.", ton: .danger)
                .padding(Trame.element)
        } else {
            HStack {
                SouffleActivite()
                Text("chargement de l'artefact…").mention().foregroundStyle(Teinte.encreTernie)
            }
            .padding(Trame.element)
        }
    }

    private var indisponible: some View {
        HStack(alignment: .firstTextBaseline, spacing: Trame.serre) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Teinte.encreTernie)
            Text("Artefact indisponible — fichier introuvable sur le Pi.")
                .note()
                .foregroundStyle(Teinte.encreTernie)
        }
        .padding(Trame.element)
    }

    // MARK: - Chargement

    private func charger() async {
        guard let piece else { return }
        switch await client.octets(piece.url) {
        case .success(let octets):
            let contenu = String(decoding: octets, as: UTF8.self)
            texte = contenu
            fichierPartage = ecrireCopieLocale(contenu, nom: piece.nom)
        case .failure:
            echec = true
        }
    }

    /// Copie temporaire nommée comme la pièce distante : c'est ce nom-là que
    /// la feuille de partage iOS montre et conserve à l'export.
    private func ecrireCopieLocale(_ contenu: String, nom: String) -> URL? {
        let nomSur = nom.replacingOccurrences(of: "/", with: "_")
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("artefacts", isDirectory: true)
        let chemin = dossier.appendingPathComponent(nomSur)
        do {
            try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
            try contenu.write(to: chemin, atomically: true, encoding: .utf8)
            return chemin
        } catch {
            Trace.erreur("artefact", "copie locale impossible pour \(nom)", error)
            return nil
        }
    }

    private func tailleLisible(_ octets: Int) -> String {
        if octets >= 1024 * 1024 {
            return String(format: "%.1f Mo", Double(octets) / (1024 * 1024))
        }
        return "\(max(1, octets / 1024)) Ko"
    }
}
#endif
