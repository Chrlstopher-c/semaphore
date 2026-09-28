// L'écran unique d'Iris. Focal : l'aperçu, au format de la webcam des PC — ce
// qu'on voit ici est ce qu'ils reçoivent. Sous lui, le geste (Filmer), puis les
// réglages, puis les ordinateurs.
#if canImport(SwiftUI) && canImport(UIKit)
import IrisNoyau
import SwiftUI
import Systeme

struct IrisEcran: View {
    @Environment(Emetteur.self) private var emetteur

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Grille.section) {
                VStack(alignment: .leading, spacing: Grille.groupe) {
                    enTete
                    apercu
                    bouton
                    if let panne = emetteur.panne {
                        Text(panne).font(Voix.note).foregroundStyle(Semantique.panne).transition(.opacity)
                    }
                }
                ReglagesIris()
                PostesListe()
                Text("L'image part en direct vers chaque ordinateur du réseau local. Le Pi ne fait que les présenter.")
                    .font(Voix.note).foregroundStyle(Neutre.encreEteinte)
            }
            .padding(.horizontal, Grille.ecran)
            .padding(.vertical, Grille.groupe)
        }
        .background(Neutre.fond.ignoresSafeArea())
        .animation(Mouvement.normal, value: emetteur.panne)
        .sensoryFeedback(Toucher.engage, trigger: emetteur.enDirect)
        .sensoryFeedback(Toucher.butee, trigger: emetteur.panne) { _, panne in panne != nil }
    }

    private var enTete: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Iris").font(Voix.titreEcran).foregroundStyle(Neutre.encre)
            Spacer()
            if emetteur.relais == .remplace {
                Button("Reprendre la main") { emetteur.reprendreRelais() }
                    .font(Voix.mention).tint(Teinte.accent)
            } else {
                Text(libelleRelais).font(Voix.legende).foregroundStyle(couleurRelais)
            }
        }
    }

    private var apercu: some View {
        ZStack {
            Apercu(couche: emetteur.capture.apercu, remplir: emetteur.reglages.cadrage == .remplir)
                .opacity(emetteur.enDirect ? 1 : 0)
            if !emetteur.enDirect {
                Image(systemName: "video.slash")
                    .font(Voix.titreSection).foregroundStyle(Neutre.encreEteinte)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(Trame.ratioApercu, contentMode: .fit)
        .background(Color.black)
        .clipShape(.rect(cornerRadius: Rayon.carte, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Rayon.carte, style: .continuous)
                .strokeBorder(Neutre.trait, lineWidth: Grille.trait)
        }
        .animation(Mouvement.normal, value: emetteur.enDirect)
    }

    private var bouton: some View {
        Button {
            Task { await emetteur.basculer() }
        } label: {
            Label(emetteur.enDirect ? "Couper la caméra" : "Filmer",
                  systemImage: emetteur.enDirect ? "stop.fill" : "video.fill")
        }
        .buttonStyle(AllureFilmer(enDirect: emetteur.enDirect))
    }

    private var libelleRelais: String {
        switch emetteur.relais {
        case .repos: return "Relais au repos"
        case .connexion: return "Relais…"
        case .connecte: return "Relais joint"
        case .coupe: return "Relais coupé"
        case .remplace: return "Ouvert ailleurs"
        }
    }

    private var couleurRelais: Color {
        switch emetteur.relais {
        case .connecte: return Semantique.ok
        case .coupe: return Semantique.panne
        default: return Neutre.encreEteinte
        }
    }
}

/// Les trois réglages, en segments système : peu de choix, tous visibles.
private struct ReglagesIris: View {
    @Environment(Emetteur.self) private var emetteur

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.element) {
            Text("Prise de vue").rubrique()
            segments("Objectif", selection: emetteur.reglages.objectif,
                     options: Objectif.allCases, libelle: \.libelle) { [emetteur] o in
                Task { await emetteur.choisir(objectif: o) }
            }
            segments("Définition", selection: emetteur.reglages.qualite,
                     options: Qualite.allCases, libelle: \.libelle) { [emetteur] q in
                Task { await emetteur.choisir(qualite: q) }
            }
            segments("Image", selection: emetteur.reglages.cadrage,
                     options: Cadrage.allCases, libelle: \.libelle) { [emetteur] c in
                Task { await emetteur.choisir(cadrage: c) }
            }
        }
    }

    private func segments<Option: Hashable & Sendable>(
        _ titre: String, selection: Option, options: [Option], libelle: KeyPath<Option, String>,
        choisir: @escaping @Sendable (Option) -> Void
    ) -> some View {
        HStack(spacing: Grille.element) {
            Text(titre).font(Voix.mention).foregroundStyle(Neutre.encreDouce)
                .frame(width: Trame.libelleReglage, alignment: .leading)
            Picker(titre, selection: Binding(get: { selection }, set: choisir)) {
                ForEach(options, id: \.self) { Text($0[keyPath: libelle]).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .frame(minHeight: Grille.cible)
        .sensoryFeedback(Toucher.selection, trigger: selection)
    }
}
#endif
