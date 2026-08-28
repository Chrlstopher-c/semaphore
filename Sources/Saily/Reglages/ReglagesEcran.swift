// Le seul réglage exposé : par où l'app joint le serveur Saily. Deux champs —
// l'adresse (par défaut la prod) et le jeton, qui n'est PAS compilé dans l'app.
// Un mot de passe dans une IPA sideloadée est un mot de passe public.
#if canImport(SwiftUI)
import SwiftUI
import SailyNoyau

struct ReglagesEcran: View {
    @Environment(Boite.self) private var boite
    @State private var adresse = ""
    @State private var jeton = ""
    @State private var etat = EtatTest.inconnu

    private enum EtatTest: Hashable {
        case inconnu, enCours, joignable, jetonRefuse, injoignable
    }

    var body: some View {
        ZStack {
            Teinte.fond.ignoresSafeArea()
            ScrollView { contenu }
        }
        .task {
            adresse = boite.reglages.adresse
            jeton = boite.reglages.jeton
            await tester()
        }
    }

    private var contenu: some View {
        VStack(alignment: .leading, spacing: Trame.section) {
            Fronton("Réglages").padding(.top, Trame.serre)
            entete
            champAdresse
            champJeton
            etatJoignabilite
            if modifie { boutonEnregistrer }
        }
        .padding(.horizontal, Trame.ecran)
        .padding(.vertical, Trame.groupe)
    }

    private var entete: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Text("Le chemin vers ton serveur").titreSection().foregroundStyle(Teinte.encre)
            Text("""
                Par défaut, la prod. Colle le jeton partagé du serveur ; sans lui, \
                rien ne passe. Tout se synchronise ensuite tout seul.
                """)
                .note().foregroundStyle(Teinte.encreDouce)
        }
    }

    private var champAdresse: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.element) {
                Text("Adresse du serveur").rubrique()
                TextField(ReglagesServeur.adresseProdParDefaut, text: $adresse)
                    .textFieldStyle(.plain)
                    .corps()
                    .foregroundStyle(Teinte.encre)
                    .tint(Teinte.accent)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !adresseValide {
                    Text("Doit ressembler à \(ReglagesServeur.adresseProdParDefaut)")
                        .note().foregroundStyle(Teinte.panne)
                }
            }
        }
    }

    private var champJeton: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.element) {
                Text("Jeton").rubrique()
                SecureField("collé depuis le .env du serveur", text: $jeton)
                    .textFieldStyle(.plain)
                    .corps()
                    .foregroundStyle(Teinte.encre)
                    .tint(Teinte.accent)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
    }

    private var etatJoignabilite: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.serre) {
                HStack {
                    Sceau(libelleEtat, symbole: symboleEtat)
                        .ton(tonEtat)
                        .id(etat)
                        .transition(.item)
                    Spacer(minLength: 0)
                    Button { Task { await tester() } } label: {
                        if etat == .enCours {
                            ProgressView().tint(Teinte.encreDouce)
                        } else {
                            Text("Tester").mention().foregroundStyle(Teinte.accent)
                        }
                    }
                    .buttonStyle(.appui)
                    .disabled(etat == .enCours)
                }
                if let remedeEtat {
                    Text(remedeEtat).note().foregroundStyle(Teinte.encreDouce)
                }
            }
        }
        .sensoryFeedback(trigger: etat) { _, nouveau in retourPour(nouveau) }
    }

    private var boutonEnregistrer: some View {
        Button("Enregistrer") { Task { await enregistrer() } }
            .buttonStyle(.engage)
            .disabled(!adresseValide)
    }

    // MARK: - État dérivé

    private var adresseValide: Bool {
        ReglagesServeur(adresse: adresse, jeton: jeton).adresseValide
    }

    private var modifie: Bool {
        adresse != boite.reglages.adresse || jeton != boite.reglages.jeton
    }

    private var libelleEtat: String {
        switch etat {
        case .inconnu: return "État inconnu"
        case .enCours: return "Vérification…"
        case .joignable: return "Serveur joignable"
        case .jetonRefuse: return "Jeton refusé"
        case .injoignable: return "Serveur injoignable"
        }
    }

    /// `☠` Le remède compte plus que le libellé. Un jeton mal collé — au premier
    /// lancement, donc au moment exact où l'on se trompe — ne doit pas envoyer
    /// vérifier la connexion : il désigne le champ juste au-dessus.
    private var remedeEtat: String? {
        switch etat {
        case .jetonRefuse: return "Recolle le jeton du .env du serveur."
        case .injoignable: return "Vérifie l'adresse ci-dessus, et ta connexion."
        case .inconnu, .enCours, .joignable: return nil
        }
    }

    private var symboleEtat: String {
        switch etat {
        case .inconnu: return "questionmark.circle"
        case .enCours: return "hourglass"
        case .joignable: return "checkmark.circle.fill"
        case .jetonRefuse: return "key.slash"
        case .injoignable: return "exclamationmark.triangle.fill"
        }
    }

    private var tonEtat: Ton {
        switch etat {
        case .inconnu, .enCours: return .neutre
        case .joignable: return .ok
        case .jetonRefuse, .injoignable: return .panne
        }
    }

    private func retourPour(_ etat: EtatTest) -> SensoryFeedback? {
        switch etat {
        case .joignable: return Retour.engage
        case .jetonRefuse, .injoignable: return Retour.butee
        case .inconnu, .enCours: return nil
        }
    }

    // MARK: - Actions

    private func enregistrer() async {
        guard adresseValide else { return }
        await boite.mettreAJourReglages(ReglagesServeur(adresse: adresse, jeton: jeton))
        await tester()
    }

    /// `☠` Le « teste » tape `/health`, la route PUBLIQUE. Un 401 la traverse
    /// quand même (elle ne demande pas de jeton) : c'est donc l'ADRESSE qu'il
    /// valide. Le jeton, lui, se juge à l'usage — d'où l'état `jetonRefuse` tiré
    /// d'un vrai refus de l'API, pas de la sonde de santé.
    private func tester() async {
        withAnimation(Elan.normal) { etat = .enCours }
        let resultat = await boite.sonder()
        withAnimation(Elan.normal) {
            switch resultat {
            case .success: etat = .joignable
            case .failure(.refuse): etat = .jetonRefuse
            case .failure: etat = .injoignable
            }
        }
    }
}
#endif
