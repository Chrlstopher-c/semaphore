// Relier l'iPhone (pas d'équivalent dans l'étalon, dessiné dans sa grammaire : mot-symbole serif, cartes groupées,
// capsule blanche). Deux voies : directe (adresse du nœud + code, ou mot de passe) ou par l'aiguilleur (adresse de
// l'aiguilleur + code de 10 min + nom de l'iPhone), puis acceptation sur le nœud avec comparaison d'empreinte.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ConnexionEcran: View {
    @Environment(Cablage.self) private var cablage

    var body: some View {
        Group {
            if cablage.etatAiguilleur != nil { AcceptationVue() } else { FormulaireConnexion() }
        }
        .background(Q.fondFil.ignoresSafeArea())
        .animation(.spring(duration: 0.4, bounce: 0), value: cablage.etatAiguilleur == nil)
    }
}

enum Voie: String, CaseIterable { case aiguilleur, direct, motDePasse }

/// Le formulaire de liaison : plein écran au premier lancement (`entete`), ou poussé depuis Réglages › Connexion
/// pour se relier autrement à tout moment (`termine` rappelé quand la demande est partie).
struct FormulaireConnexion: View {
    @Environment(Cablage.self) private var cablage
    var entete = true
    var termine: () -> Void = {}
    @State var voie = Voie.aiguilleur
    @State private var adresse = ""
    @State private var code = ""
    @State private var nom = "iPhone de Chris"
    @State private var envoi = false
    @State private var erreur: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if entete {
                    Text("Quart").font(.system(size: 40, weight: .medium, design: .serif)).foregroundStyle(Q.texte)
                        .padding(.horizontal, 32).padding(.top, 72)
                    Text("Pilote les sessions Claude Code du parc depuis l’iPhone.").font(Q.rangee)
                        .foregroundStyle(Q.secondaire).padding(.horizontal, 32).padding(.top, 8)
                }
                TitreSection(texte: "Liaison").padding(.top, entete ? 24 : 0)
                Carte { choixVoie }
                TitreSection(texte: voie == .aiguilleur ? "Aiguilleur" : "Nœud")
                Carte { champs }
                Text(aide).font(Q.detail).foregroundStyle(Q.tertiaire).padding(.horizontal, 32).padding(.top, 8)
                if let erreur {
                    Text(erreur).font(Q.detail).foregroundStyle(Q.retraitTexte)
                        .padding(.horizontal, 32).padding(.top, 12)
                }
                bouton.padding(.top, 32)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.error, trigger: erreur) { _, e in e != nil }
        .onAppear { if adresse.isEmpty && cablage.adresseConnue { adresse = cablage.adresse.absoluteString } }
    }

    private var choixVoie: some View {
        ForEach(Array(Voie.allCases.enumerated()), id: \.offset) { i, v in
            if i > 0 { Filet() }
            Button { voie = v; code = ""; erreur = nil } label: {
                HStack {
                    Text(libelle(v)).font(Q.rangee).foregroundStyle(Q.texte)
                    Spacer()
                    if voie == v { Image(systemName: "checkmark").font(.system(size: 18)).foregroundStyle(Q.coche) }
                }
                .padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur).contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var champs: some View {
        champ("Adresse", texte: $adresse, clavier: .URL)
        Filet()
        champ(voie == .motDePasse ? "Mot de passe" : "Code d’appairage", texte: $code, secret: voie == .motDePasse)
        if voie == .aiguilleur {
            Filet()
            champ("Nom de cet iPhone", texte: $nom, majuscules: true)
        }
    }

    private func libelle(_ v: Voie) -> String {
        switch v {
        case .aiguilleur: return "Par le Pi (aiguilleur)"
        case .direct: return "Directe, avec un code"
        case .motDePasse: return "Directe, avec un mot de passe"
        }
    }

    private var aide: String {
        switch voie {
        case .aiguilleur: return "Le code (XXXX-XXXX, 10 minutes, usage unique) : Lanterne sur le portable, "
            + "Paramètres › Réseau › Ajouter un appareil. Le nœud devra ensuite accepter cet iPhone."
        case .direct: return "Le code s’affiche sur le nœud (10 minutes, usage unique)."
        case .motDePasse: return "Le mot de passe du relais."
        }
    }

    private var bouton: some View {
        Button { Task { await relier() } } label: {
            Group {
                if envoi { IndicateurTravail().frame(width: 18, height: 18) } else { Text("Relier cet iPhone") }
            }
            .font(.system(size: 17, weight: .medium)).foregroundStyle(Q.carte)
            .frame(maxWidth: .infinity, minHeight: 50).background(Q.texte, in: .capsule)
        }
        .buttonStyle(StyleAppui())
        .disabled(envoi || code.isEmpty || URL(string: adresse)?.host() == nil)
        .padding(.horizontal, Q.marge)
    }

    private func champ(_ titre: String, texte: Binding<String>, clavier: UIKeyboardType = .default,
                       secret: Bool = false, majuscules: Bool = false) -> some View {
        Group {
            if secret { SecureField(titre, text: texte) } else { TextField(titre, text: texte).keyboardType(clavier) }
        }
        .font(Q.rangee).foregroundStyle(Q.texte)
        .textInputAutocapitalization(majuscules ? .words : .never).autocorrectionDisabled()
        .padding(.horizontal, Q.marge).frame(height: 52)
    }

    private func relier() async {
        guard let url = URL(string: adresse.trimmingCharacters(in: .whitespaces)) else { return }
        let propre = code.trimmingCharacters(in: .whitespaces)
        envoi = true
        defer { envoi = false }
        do {
            switch voie {
            case .aiguilleur: try await cablage.appairerAiguilleur(adresse: url, code: propre.uppercased(), nom: nom)
            case .direct: try await cablage.appairer(adresse: url, code: propre.uppercased())
            case .motDePasse: try await cablage.connecter(adresse: url, motDePasse: code)
            }
            termine()
        } catch {
            erreur = (error as? ErreurRelais)?.description ?? "Appairage refusé : vérifie l’adresse et le code."
        }
    }
}

/// En attente de l'acceptation sur le nœud : l'empreinte de l'iPhone, à comparer avec celle que montre le nœud
/// (Lanterne › Paramètres › Réseau), et l'état du lien. La liste s'ouvre d'elle-même à l'acceptation.
private struct AcceptationVue: View {
    @Environment(Cablage.self) private var cablage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Accepte cet iPhone").font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundStyle(Q.texte).padding(.horizontal, 32).padding(.top, 72)
                Text("Sur ton nœud : Lanterne › Paramètres › Réseau. Vérifie que l’empreinte affichée est la même "
                     + "que celle-ci avant d’accepter.").font(Q.rangee).foregroundStyle(Q.secondaire)
                    .padding(.horizontal, 32).padding(.top, 8)
                TitreSection(texte: "Empreinte de cet iPhone").padding(.top, 16)
                Carte { EmpreinteVue(texte: cablage.empreinteAppareil).padding(Q.marge) }
                TitreSection(texte: "Lien")
                Carte { EtatLienVue(lien: cablage.lienAiguilleur) }
                Button("Annuler") { cablage.deconnecter() }
                    .font(Q.rangee).foregroundStyle(Q.deconnexion).frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.top, 24)
            }
        }
    }
}

/// L'empreinte en grille de 4 colonnes, monospacée (16 groupes de 4 caractères).
struct EmpreinteVue: View {
    let texte: String

    var body: some View {
        let groupes = texte.split(whereSeparator: { $0 == " " || $0 == ":" || $0 == "-" }).map(String.init)
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            ForEach(Array(stride(from: 0, to: groupes.count, by: 4)), id: \.self) { i in
                GridRow {
                    ForEach(groupes[i..<min(i + 4, groupes.count)], id: \.self) { g in
                        Text(g).font(.system(size: 17, weight: .medium, design: .monospaced)).foregroundStyle(Q.texte)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
}

/// L'état du lien par l'aiguilleur, en une rangée : glyphe, libellé, roue tant qu'il cherche.
struct EtatLienVue: View {
    let lien: ClientAiguilleur.Lien

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbole).font(.system(size: 19, weight: .light)).foregroundStyle(couleur).frame(width: 28)
            Text(libelle).font(Q.rangee).foregroundStyle(Q.texte)
            Spacer()
            if enCours { IndicateurTravail().frame(width: 16, height: 16) }
        }
        .padding(.horizontal, Q.marge).frame(minHeight: Q.rangeeHauteur)
    }

    private var enCours: Bool {
        switch lien {
        case .connexion, .rechercheNoeud, .attenteAccord: return true
        default: return false
        }
    }

    private var libelle: String {
        switch lien {
        case .deconnecte: return "Déconnecté"
        case .connexion: return "Connexion à l’aiguilleur…"
        case .rechercheNoeud: return "Recherche du nœud en ligne…"
        case .attenteAccord: return "En attente de ton acceptation sur le nœud"
        case .ouvert: return "Lien chiffré ouvert"
        case .refuse(let raison): return raison.isEmpty ? "Refusé par le nœud" : "Refusé : \(raison)"
        }
    }

    private var symbole: String {
        switch lien {
        case .ouvert: return "lock"
        case .refuse: return "xmark.shield"
        case .deconnecte: return "wifi.slash"
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    private var couleur: Color {
        switch lien {
        case .ouvert: return Q.enLigne
        case .refuse: return Q.retraitTexte
        default: return Q.secondaire
        }
    }
}
#endif
