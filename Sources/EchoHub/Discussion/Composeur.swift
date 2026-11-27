// Le composeur : le champ de saisie et le seul bouton qui engage.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau
#if canImport(PhotosUI)
import PhotosUI
#endif

struct Composeur: View {
    @Environment(Salon.self) private var salon
    @State private var texte = ""
    @FocusState private var saisieActive: Bool
    /// Compteur de butées — sert de déclencheur haptique. Un `Bool` ne
    /// rejouerait pas le retour deux fois de suite pour le même refus.
    @State private var refus = 0
    @State private var photos: [PhotosPickerItem] = []
    @State private var importateurOuvert = false
    /// L'échec de la dernière soumission (commande refusée, aucun modèle), sous la saisie.
    @State private var erreurSaisie: String?

    var body: some View {
        VStack(spacing: 0) {
            if !propositions.isEmpty {
                PaletteCommandes(propositions: propositions) { definition in
                    texte = AnalyseSaisie.completion(definition)
                }
            }
            Rectangle().fill(Teinte.trait).frame(height: Trame.trait)
            if let erreurSaisie {
                Text(erreurSaisie).legende().foregroundStyle(Teinte.panne)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Trame.ecran).padding(.top, Trame.fin)
            }
            LignesConsignes()
            LigneAttente()
            LigneContexte()
            BandePiecesJointes()
            HStack(alignment: .bottom, spacing: Trame.element) {
                trombone
                champ
                boutonArret
                bouton
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.vertical, Trame.element)
        }
        .background(Teinte.surfaceHaute)
        .animation(Elan.normal, value: salon.piecesJointes)
        .animation(Elan.normal, value: salon.enAttente)
        .sensoryFeedback(Retour.butee, trigger: refus)
        .sensoryFeedback(Retour.engage, trigger: salon.messages.count)
        .onChange(of: photos) { _, choisies in absorber(choisies) }
        .onChange(of: texte) { _, _ in erreurSaisie = nil }
        .fileImporter(
            isPresented: $importateurOuvert, allowedContentTypes: [.item], allowsMultipleSelection: true
        ) { issue in
            absorber(issue)
        }
    }

    /// Le geste le plus naturel d'un téléphone — photographier quelque chose et
    /// demander au modèle ce que c'est — était impossible : `fichierIds` était
    /// dans le contrat, encodé, et valait TOUJOURS `[]`.
    private var trombone: some View {
        Menu {
            #if canImport(PhotosUI)
            PhotosPicker(selection: $photos, matching: .images) {
                Label("Photos", systemImage: "photo")
            }
            #endif
            Button { importateurOuvert = true } label: {
                Label("Fichiers", systemImage: "folder")
            }
        } label: {
            Image(systemName: "paperclip")
                .foregroundStyle(Teinte.encreDouce)
                .frame(width: Trame.cible, height: Trame.composeur)
                .contentShape(.rect)
        }
        .disabled(salon.conversation == nil)
        .accessibilityLabel("Joindre une pièce")
    }

    private func absorber(_ choisies: [PhotosPickerItem]) {
        guard !choisies.isEmpty else { return }
        photos = []
        Task {
            for choisie in choisies {
                do {
                    guard let octets = try await choisie.loadTransferable(type: Data.self) else {
                        Journal.echec("photo choisie illisible : aucune donnée")
                        continue
                    }
                    let type = choisie.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                    await salon.joindre(nom: nomPhoto(type), typeMime: type, octets: octets)
                } catch {
                    Journal.echec("photo choisie illisible : \(error)")
                }
            }
        }
    }

    private func absorber(_ issue: Result<[URL], any Error>) {
        switch issue {
        case .success(let urls): Task { for url in urls { await salon.joindre(fichierA: url) } }
        case .failure(let erreur): Journal.echec("import de fichier annulé : \(erreur)")
        }
    }

    /// Une photo de la pellicule n'a pas de nom de fichier. On en fabrique un
    /// lisible : c'est de l'affichage, le serveur ne s'en sert pour rien.
    private func nomPhoto(_ typeMime: String) -> String {
        "photo." + (typeMime.split(separator: "/").last.map(String.init) ?? "jpg")
    }

    private var champ: some View {
        // `axis: .vertical` : le champ grandit avec le texte au lieu de faire
        // défiler une ligne unique. Plafonné à six lignes — au-delà, c'est le
        // fil qui doit rester visible, pas le brouillon.
        TextField("Écrire à \(nomModele)", text: $texte, axis: .vertical)
            .lineLimit(1...6)
            .corps()
            .foregroundStyle(Teinte.encre)
            .tint(Teinte.accent)
            .focused($saisieActive)
            .padding(.horizontal, Trame.element)
            .padding(.vertical, Trame.serre)
            .frame(minHeight: Trame.composeur)
            .background(Teinte.surface)
            .clipShape(.rect(cornerRadius: Galbe.controle, style: .continuous))
    }

    /// `☠` Le bouton ne change PLUS de rôle quand le champ contient du texte.
    /// Avant, taper la question suivante pendant que le modèle répondait puis
    /// appuyer TUAIT la réponse en cours — le texte restait dans le champ, la
    /// réponse était perdue. Un geste destructeur atteint par le geste le plus
    /// naturel. L'arrêt a désormais son propre bouton, qui n'apparaît que
    /// pendant une génération.
    private var bouton: some View {
        Button(action: agir) {
            Image(systemName: symboleBouton)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Teinte.fond)
                .frame(width: Trame.cible, height: Trame.cible)
                .background(couleurBouton)
                .clipShape(.circle)
        }
        .buttonStyle(.appui)
        .animation(Elan.micro, value: salon.enGeneration)
        .accessibilityLabel(libelleBouton)
    }

    /// Le bouton d'arrêt, séparé et présent seulement pendant une génération :
    /// arrêter est une décision, elle mérite sa propre cible.
    @ViewBuilder private var boutonArret: some View {
        if salon.enGeneration {
            Button { salon.arreter() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Teinte.alerte)
                    .frame(width: Trame.cible, height: Trame.cible)
                    .contentShape(.circle)
            }
            .buttonStyle(.appui)
            .accessibilityLabel("Arrêter la génération")
            .transition(.scene)
        }
    }

    private var symboleBouton: String {
        salon.enGeneration && envoyable ? "arrow.turn.down.right" : "arrow.up"
    }

    private var libelleBouton: String {
        salon.enGeneration && envoyable ? "Glisser à l'agent" : "Envoyer"
    }

    private var couleurBouton: Color {
        envoyable ? Teinte.accent : Teinte.encreEteinte
    }

    private var envoyable: Bool {
        !texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var nomModele: String {
        salon.statutPret?.modele.map { $0.split(separator: "/").last.map(String.init) ?? $0 }
            ?? "EchoHub"
    }

    /// `☠` Un envoi refusé DOIT se sentir. Sans butée, la main croit que l'app
    /// n'a pas senti le doigt, et Chris rappuie — c'est la règle de la charte,
    /// et c'est le seul endroit de l'app où elle s'applique vraiment.
    private func agir() {
        guard envoyable else {
            refus += 1
            return
        }
        let saisie = texte
        // Comme au web : sans modèle prêt, un message ne part pas ; une commande, si.
        if case .commande = AnalyseSaisie(saisie) {} else if salon.statutPret?.estPret != true {
            refus += 1
            erreurSaisie = "Aucun modèle chargé : charges-en un depuis l'onglet Modèles."
            return
        }
        texte = ""
        Task {
            if let echec = await salon.soumettre(saisie) {
                erreurSaisie = echec
                refus += 1
            }
        }
    }

    private var propositions: [DefinitionCommande] {
        guard let prefixe = AnalyseSaisie.nomEnFrappe(texte) else { return [] }
        return AnalyseSaisie.filtrer(salon.catalogueCommandes, prefixe)
    }
}
#endif
