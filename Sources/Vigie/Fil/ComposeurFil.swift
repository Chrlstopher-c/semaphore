// Le composeur du fil : saisie multiligne, pièces jointes, moteur du prochain
// message, et le bouton d'envoi qui devient bouton d'ARRÊT pendant que
// l'orchestrateur génère.
//
// `☠` L'envoi n'est jamais désactivé pendant la génération : le harness met
// les messages en file, rien n'interdit d'écrire pendant que l'orchestrateur
// répond — et le bouton d'arrêt est le seul moyen d'interrompre un tour.
#if canImport(SwiftUI)
import PhotosUI
import SwiftUI
import UIKit

struct ComposeurFil: View {
    @Binding var texte: String
    @Binding var choixMoteur: ChoixMoteur
    let pieces: [PieceEnAttente]
    let generation: Bool
    let envoiEnCours: Bool
    let ouvrirMoteur: () -> Void
    let ajouterPieces: ([PhotosPickerItem]) async -> Void
    let retirerPiece: (PieceEnAttente.ID) -> Void
    let envoyer: () -> Void
    let interrompre: () -> Void

    @State private var selectionPhotos: [PhotosPickerItem] = []
    @State private var dictee = DicteeSonde()

    private var videDeContenu: Bool {
        texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pieces.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            if let raison = dictee.empechement {
                BandeauNote(raison, ton: .vigilance, symbole: "mic.slash.fill")
            }
            if dictee.actif { LisereDictee() }
            if !pieces.isEmpty { rangeePieces }
            HStack(alignment: .bottom, spacing: Trame.serre) {
                trombone
                BoutonDictee(dictant: dictee.actif) { Task { await basculerDictee() } }
                ChampQuart(texte: $texte, placebo: "Message à l'orchestrateur…", lignes: 1...6)
                    .frame(maxWidth: .infinity)
                boutonEnvoi
            }
            piedMoteur
        }
        .animation(Elan.pose, value: dictee.actif)
        // Un seul sens à la fois : la sonde écrit dans le champ, et une frappe
        // au clavier redevient la base de la dictée. Sans cette seconde branche,
        // le mot suivant écraserait la correction que Chris vient de taper.
        .onChange(of: dictee.texte) { _, nouveau in texte = nouveau }
        .onChange(of: texte) { _, nouveau in
            guard dictee.actif, nouveau != dictee.texte else { return }
            dictee.reprendreSur(nouveau)
        }
        .padding(.horizontal, Trame.ecran)
        .padding(.top, Trame.serre)
        .padding(.bottom, Trame.serre)
        .background(Teinte.fondCreux)
        .overlay(alignment: .top) { FiletFin() }
        .onChange(of: selectionPhotos) { _, nouvelle in
            guard !nouvelle.isEmpty else { return }
            Task {
                await ajouterPieces(nouvelle)
                selectionPhotos = []
            }
        }
    }

    // MARK: - Pièces

    private var rangeePieces: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Trame.serre) {
                ForEach(pieces) { piece in
                    VignettePieceEnAttente(piece: piece) { retirerPiece(piece.id) }
                }
            }
        }
    }

    private var trombone: some View {
        PhotosPicker(
            selection: $selectionPhotos,
            maxSelectionCount: max(1, PieceEnAttente.plafondParMessage - pieces.count),
            matching: .images
        ) {
            Image(systemName: "paperclip")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Teinte.encreDouce)
                .frame(width: 40, height: 40)
                .contentShape(.rect)
        }
        .disabled(pieces.count >= PieceEnAttente.plafondParMessage)
        .accessibilityLabel("Joindre une image")
    }

    // MARK: - Dictée

    private func basculerDictee() async {
        guard !dictee.actif else { return dictee.arreter() }
        dictee.oublierEmpechement()
        await dictee.demarrer(brouillon: texte)
    }

    /// Le micro se coupe AVANT que le champ ne se vide : une transcription qui
    /// survivrait à l'envoi réécrirait le brouillon suivant avec la phrase déjà
    /// partie.
    private func envoyerEtCouper() {
        dictee.arreter()
        envoyer()
    }

    // MARK: - Envoi / arrêt

    @ViewBuilder private var boutonEnvoi: some View {
        if generation {
            Button(action: interrompre) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Teinte.danger)
                    .frame(width: 40, height: 40)
                    .background(Ton.danger.voile, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Interrompre la génération")
        } else {
            Button(action: envoyerEtCouper) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Teinte.encreSurAccent)
                    .frame(width: 40, height: 40)
                    .background(videDeContenu ? Teinte.surfaceHaute : Teinte.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(videDeContenu || envoiEnCours)
            .animation(Elan.vif, value: videDeContenu)
            .accessibilityLabel("Envoyer")
        }
    }

    /// La ligne du moteur : ce qui partira avec le prochain message, et la
    /// respiration quand l'orchestrateur écrit.
    private var piedMoteur: some View {
        HStack(spacing: Trame.serre) {
            Button {
                ouvrirMoteur()
            } label: {
                HStack(spacing: Trame.fin) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10, weight: .semibold))
                    Text(choixMoteur.etiquette ?? "moteur du fil")
                        .donneeMinuscule()
                }
                .foregroundStyle(choixMoteur.estNeutre ? Teinte.encreTernie : Teinte.accent)
                .padding(.vertical, 2)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choisir le moteur du prochain message")
            Spacer(minLength: 0)
            if generation {
                HStack(spacing: Trame.fin) {
                    SouffleActivite()
                    Text("l'orchestrateur écrit")
                        .donneeMinuscule()
                        .foregroundStyle(Teinte.encreTernie)
                }
                .transition(.opacity)
            }
        }
        .animation(Elan.pose, value: generation)
    }
}

/// Vignette d'une pièce PAS ENCORE envoyée — mémoire locale, jamais l'URL du
/// Pi qui n'existe pas encore.
private struct VignettePieceEnAttente: View {
    let piece: PieceEnAttente
    let retirer: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            apercu
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Galbe.encart, style: .continuous)
                        .strokeBorder(Teinte.filetAppuye, lineWidth: Trame.trait)
                )
            Button(action: retirer) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Teinte.encre, Teinte.fondCreux)
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: -5)
            .accessibilityLabel("Retirer la pièce")
        }
        .entreeEnScene()
    }

    @ViewBuilder private var apercu: some View {
        if piece.type.hasPrefix("image/"), let image = UIImage(data: piece.donnees) {
            Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            VStack(spacing: 2) {
                Image(systemName: "doc.fill").font(.system(size: 14))
                Text(piece.tailleLisible).donneeMinuscule()
            }
            .foregroundStyle(Teinte.encreTernie)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Teinte.surface)
        }
    }
}
#endif
