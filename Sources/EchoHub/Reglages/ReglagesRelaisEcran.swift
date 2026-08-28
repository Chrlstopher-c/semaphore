// Le seul réglage exposé à Chris : par où l'app joint sa machine.
//
// Deux champs, parce que deux adresses existent dans la vraie vie — locale à la
// maison, tunnel dehors — et parce que le jeton n'est PAS compilé dans l'app.
// Voir `ARCHITECTURE.md` : un mot de passe dans une IPA sideloadée est un mot de
// passe public.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

public struct ReglagesRelaisEcran: View {
    @Environment(Salon.self) private var salon
    @State private var adresse = ""
    @State private var jeton = ""
    @State private var etat = EtatTest.inconnu
    /// Ce que le relais rapporte du PC. C'est la seule machine bien placée pour
    /// le savoir : l'iPhone, lui, ne voit que le relais.
    @State private var detailPC: String?

    /// `Hashable` et pas seulement `Equatable` : `.id(etat)` l'exige pour donner
    /// à chaque état une identité de vue distincte — sans quoi un simple
    /// changement de libellé ne démonte rien et `.transition(.scene)` ne jouerait
    /// jamais.
    private enum EtatTest: Hashable {
        case inconnu, enCours, joignable, sansPC, jetonRefuse, injoignable
    }

    public init() {}

    public var body: some View {
        ZStack {
            Teinte.fond.ignoresSafeArea()
            ScrollView { contenu }
        }
        .navigationTitle("Relais")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            adresse = salon.reglages.adresse
            jeton = salon.reglages.jeton
            await tester()
        }
    }

    private var contenu: some View {
        VStack(alignment: .leading, spacing: Trame.section) {
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
            Text("Le chemin vers ta machine").titreSection().foregroundStyle(Teinte.encre)
            Text("""
                À la maison, l'adresse locale du Pi. Dehors, celle du tunnel. \
                Le relais transmet au PC ; le modèle, lui, ne bouge pas.
                """)
                .note().foregroundStyle(Teinte.encreDouce)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var champAdresse: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.element) {
                Text("Adresse du relais").rubrique()
                TextField(ReglagesRelais.adresseLocaleParDefaut, text: $adresse)
                    .textFieldStyle(.plain)
                    .corps()
                    .foregroundStyle(Teinte.encre)
                    .tint(Teinte.accent)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !adresseValide {
                    Text("Doit ressembler à \(ReglagesRelais.adresseLocaleParDefaut)")
                        .note().foregroundStyle(Teinte.panne)
                }
            }
        }
    }

    private var champJeton: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.element) {
                Text("Jeton").rubrique()
                SecureField("collé depuis le .env du Pi", text: $jeton)
                    .textFieldStyle(.plain)
                    .corps()
                    .foregroundStyle(Teinte.encre)
                    .tint(Teinte.accent)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Sans lui, l'adresse du tunnel suffirait à parler à ton modèle.")
                    .note().foregroundStyle(Teinte.encreDouce)
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
                        .transition(.scene)
                    Spacer(minLength: 0)
                    Button { Task { await tester() } } label: {
                        if etat == .enCours {
                            ProgressView().tint(Teinte.encreDouce).transition(.scene)
                        } else {
                            Text("Tester").mention().foregroundStyle(Teinte.accent)
                                .transition(.scene)
                        }
                    }
                    .buttonStyle(.appui)
                    .disabled(etat == .enCours)
                }
                if let remedeEtat {
                    Text(remedeEtat).note().foregroundStyle(Teinte.encreDouce)
                        .transition(.scene)
                }
            }
        }
        // Un état, un retour : succès et échec d'un test engagent une décision.
        .sensoryFeedback(trigger: etat) { _, nouveau in retourPour(nouveau) }
    }

    private var boutonEnregistrer: some View {
        Button("Enregistrer") { Task { await enregistrer() } }
            .buttonStyle(.engage)
            .disabled(!adresseValide)
            .transition(.scene)
    }

    // MARK: - État dérivé

    private var adresseValide: Bool {
        ReglagesRelais(adresse: adresse, jeton: jeton).adresseValide
    }

    private var modifie: Bool {
        adresse != salon.reglages.adresse || jeton != salon.reglages.jeton
    }

    /// Cinq états et pas trois : « le relais répond mais le PC est éteint » est
    /// le cas le plus fréquent en pratique, et le confondre avec « injoignable »
    /// enverrait Chris vérifier son tunnel alors qu'il doit allumer sa machine.
    private var libelleEtat: String {
        switch etat {
        case .inconnu: return "État inconnu"
        case .enCours: return "Vérification…"
        case .joignable: return "Relais et PC joignables"
        case .sansPC: return "Relais joignable, PC éteint"
        case .jetonRefuse: return "Jeton refusé par le relais"
        case .injoignable: return "Relais injoignable"
        }
    }

    /// `☠` Le remède compte plus que le libellé sur cet écran. Un jeton mal
    /// collé — au tout premier lancement, donc au moment exact où l'on se
    /// trompe — affichait « Relais injoignable » et envoyait vérifier le tunnel
    /// et le PC, alors que le seul problème était le champ juste au-dessus.
    private var remedeEtat: String? {
        switch etat {
        case .jetonRefuse: return "Recolle le jeton du .env du Pi."
        case .injoignable: return "Vérifie l'adresse ci-dessus, et que le Pi est allumé."
        case .sansPC:
            let cause = detailPC.map { " (\($0))" } ?? ""
            return "Allume le PC : le relais répond, EchoHub non." + cause
        case .inconnu, .enCours, .joignable: return nil
        }
    }

    private var symboleEtat: String {
        switch etat {
        case .inconnu: return "questionmark.circle"
        case .enCours: return "hourglass"
        case .joignable: return "checkmark.circle.fill"
        case .sansPC: return "bolt.slash"
        case .jetonRefuse: return "key.slash"
        case .injoignable: return "exclamationmark.triangle.fill"
        }
    }

    private var tonEtat: Ton {
        switch etat {
        case .inconnu, .enCours: return .neutre
        case .joignable: return .ok
        case .sansPC: return .alerte
        case .jetonRefuse, .injoignable: return .panne
        }
    }

    private func retourPour(_ etat: EtatTest) -> SensoryFeedback? {
        switch etat {
        case .joignable: return Retour.engage
        case .sansPC, .jetonRefuse, .injoignable: return Retour.butee
        case .inconnu, .enCours: return nil
        }
    }

    // MARK: - Actions

    private func enregistrer() async {
        guard adresseValide else { return }
        await salon.mettreAJourReglages(ReglagesRelais(adresse: adresse, jeton: jeton))
        await tester()
    }

    private func tester() async {
        withAnimation(Elan.normal) { etat = .enCours }
        let resultat = await salon.sonderRelais()
        withAnimation(Elan.normal) {
            switch resultat {
            case .success(let sante):
                detailPC = sante.detail
                etat = sante.echohub ? .joignable : .sansPC
            case .failure(.refuse):
                detailPC = nil
                etat = .jetonRefuse
            case .failure:
                detailPC = nil
                etat = .injoignable
            }
        }
    }
}
#endif
