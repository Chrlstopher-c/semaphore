// Réglages › Réseau › Ajouter : serveur (par SSH depuis le nœud relié, ou avec un code), pair, téléphone, invité.
// Un code à usage unique est demandé à l'aiguilleur par le nœud ; la demande de la nouvelle machine revient ici,
// empreinte calculée sur cet iPhone, et l'accord est une charte signée qui la contient déjà. Rien n'entre sans lui.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// Ce qu'on ajoute : décide du texte d'aide et de la façon d'accepter la demande qui arrivera.
enum SorteAjout: String, CaseIterable, Identifiable {
    case serveur, pair, telephone, invite
    var id: String { rawValue }

    var titre: String {
        switch self {
        case .serveur: return "Serveur"
        case .pair: return "Pair"
        case .telephone: return "Téléphone"
        case .invite: return "Invité"
        }
    }

    var symbole: String {
        switch self {
        case .serveur: return "server.rack"
        case .pair: return "laptopcomputer"
        case .telephone: return "iphone"
        case .invite: return "person.crop.circle.badge.plus"
        }
    }

    var detail: String {
        switch self {
        case .serveur: return "fait tourner des sessions, sans appli"
        case .pair: return "une machine avec Lanterne"
        case .telephone: return "pilote seulement"
        case .invite: return "un ami, dans son espace"
        }
    }

    var aide: String {
        switch self {
        case .serveur: return "Sur le serveur, installe le nœud Lanterne et relie-le à l’aiguilleur avec ce code."
        case .pair: return "Sur la machine : Lanterne › Paramètres › Réseau › Relier, avec ce code."
        case .telephone: return "Sur le téléphone : Quart › Passer par le Pi, avec ce code."
        case .invite: return "Sur la machine de ton invité : Lanterne › Paramètres › Réseau › Relier, avec ce code. "
            + "Il entrera comme invité ; modèles et limites se règlent ensuite."
        }
    }

    func accord(machine: String?) -> AccordDemande {
        switch self {
        case .serveur: return .membre(.serveur)
        case .pair: return .membre(.pair)
        case .telephone: return .membre(.telephone)
        case .invite: return .invite(.parDefaut(machine: machine))
        }
    }
}

/// La carte « Ajouter » : une rangée par sorte.
struct MenuAjout: View {
    let modele: ModeleReseau

    var body: some View {
        ForEach(Array(SorteAjout.allCases.enumerated()), id: \.element) { rang, sorte in
            if rang > 0 { Filet(retrait: 60) }
            NavigationLink {
                if sorte == .serveur {
                    ChoixServeurEcran(modele: modele)
                } else {
                    CodeAjoutEcran(modele: modele, sorte: sorte)
                }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: sorte.symbole).font(.system(size: 19, weight: .light))
                        .foregroundStyle(Q.secondaire).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sorte.titre).font(Q.rangee).foregroundStyle(Q.texte)
                        Text(sorte.detail).font(Q.detail).foregroundStyle(Q.secondaire).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .medium)).foregroundStyle(Q.meta)
                }
                .padding(.horizontal, Q.marge).frame(minHeight: 60).contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(modele.enCours != nil)
        }
    }
}

/// Serveur : par SSH depuis le nœud relié (installation guidée), ou avec un code.
private struct ChoixServeurEcran: View {
    let modele: ModeleReseau

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Carte {
                    NavigationLink { AjoutServeurEcran(modele: modele) } label: {
                        RangeeReglage(symbole: "terminal", titre: "Par SSH depuis \(nomRelie)")
                    }
                    .buttonStyle(.plain)
                    Filet(retrait: 60)
                    NavigationLink { CodeAjoutEcran(modele: modele, sorte: .serveur) } label: {
                        RangeeReglage(symbole: "number", titre: "Avec un code")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
                Note(texte: "Par SSH, \(nomRelie) installe le nœud sur le serveur et compare les deux empreintes "
                     + "avant de te demander ton accord.")
            }
        }
        .barreFeuille("Serveur")
    }

    private var nomRelie: String {
        guard let c = modele.charte, let n = modele.noeudRelie else { return "le nœud relié" }
        return c.membre(n)?.nom ?? "le nœud relié"
    }
}

/// Un code à usage unique, puis les demandes qui arrivent, acceptées comme la sorte choisie.
struct CodeAjoutEcran: View {
    let modele: ModeleReseau
    let sorte: SorteAjout
    @State private var code: CodeReseau?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BandeauErreurReseau(modele: modele)
                TitreSection(texte: "Code à usage unique")
                Carte { carteCode }
                Note(texte: sorte.aide)
                TitreSection(texte: "Demandes")
                Carte { demandes }
                Note(texte: "Compare l’empreinte avec celle qu’affiche la nouvelle machine avant d’accepter.")
            }
            .padding(.bottom, 32)
        }
        .barreFeuille(sorte.titre)
        .task { if code == nil { code = await modele.creerCode() } }
    }

    @ViewBuilder private var carteCode: some View {
        if let code {
            VStack(alignment: .leading, spacing: 6) {
                Text(code.code).font(.system(size: 30, weight: .medium, design: .monospaced)).foregroundStyle(Q.texte)
                    .textSelection(.enabled)
                Text(Self.echeance(code.expireLe)).font(Q.detail).foregroundStyle(Q.secondaire)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(Q.marge)
        } else {
            Button { Task { code = await modele.creerCode() } } label: {
                RangeeReglage(symbole: "arrow.clockwise", titre: modele.enCours ?? "Nouveau code", chevron: false)
            }
            .buttonStyle(.plain).disabled(modele.enCours != nil)
        }
    }

    /// « Valable jusqu’à 14:32 » : l'heure locale de l'échéance donnée par l'aiguilleur.
    private static func echeance(_ iso: String) -> String {
        guard let date = DateRelative.date(iso) else { return "Valable quelques minutes, une seule fois" }
        return "Valable jusqu’à \(date.formatted(date: .omitted, time: .shortened)), une seule fois"
    }

    @ViewBuilder private var demandes: some View {
        if modele.demandes.isEmpty {
            HStack(spacing: 12) {
                ProgressView().tint(Q.secondaire)
                Text("En attente de la nouvelle machine…").font(Q.rangee).foregroundStyle(Q.tertiaire)
                Spacer()
            }
            .padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur)
        }
        ForEach(Array(modele.demandes.enumerated()), id: \.element.id) { rang, d in
            if rang > 0 { Filet(retrait: 60) }
            NavigationLink { DemandeReseauEcran(modele: modele, demande: d, proposee: sorte) } label: {
                RangeeDemande(demande: d)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Une demande : empreinte calculée ici, puis accepter (comme la sorte proposée, ou au choix) ou refuser.
struct DemandeReseauEcran: View {
    @Environment(\.dismiss) private var fermer
    let modele: ModeleReseau
    let demande: DemandeReseau
    let proposee: SorteAjout?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BandeauErreurReseau(modele: modele)
                TitreSection(texte: "Empreinte de \(demande.nom)")
                Carte { EmpreinteVue(texte: demande.empreinte ?? "—").padding(Q.marge) }
                if let ajout { concordance(ajout) }
                TitreSection(texte: "Accepter")
                Carte { choix }
                Carte {
                    Button { Task { await modele.refuser(demande); fermer() } } label: {
                        RangeeReglage(symbole: "xmark.circle", titre: "Refuser", couleur: Q.deconnexion, chevron: false)
                    }
                    .buttonStyle(.plain).disabled(modele.enCours != nil)
                }
                .padding(.top, 24)
            }
            .padding(.bottom, 32)
        }
        .barreFeuille("Demande")
    }

    /// Sortes possibles : un appareil est un téléphone ; une machine, la sorte proposée d'abord.
    private var sortes: [SorteAjout] {
        if demande.genre == "appareil" { return [.telephone] }
        if ajout != nil { return [.serveur] }
        let machines: [SorteAjout] = [.pair, .serveur, .invite]
        guard let proposee, machines.contains(proposee) else { return machines }
        return [proposee] + machines.filter { $0 != proposee }
    }

    @ViewBuilder private var choix: some View {
        ForEach(Array(sortes.enumerated()), id: \.element) { rang, sorte in
            if rang > 0 { Filet(retrait: 60) }
            Button { accepter(sorte) } label: {
                RangeeReglage(symbole: sorte.symbole, titre: "Comme \(sorte.titre.lowercased())",
                              couleur: rang == 0 ? Q.lien : Q.texte, chevron: false)
            }
            .buttonStyle(.plain).disabled(modele.enCours != nil || ajout?.concordance == "differente")
        }
    }

    /// Un serveur installé par SSH : les deux empreintes (SSH et aiguilleur) doivent concorder.
    private var ajout: AjoutReseau? { modele.ajouts.first { $0.membre == demande.membre } }

    private func concordance(_ a: AjoutReseau) -> some View {
        let identique = a.concordance == "identique"
        return VStack(spacing: 0) {
            Carte {
                RangeeReglage(symbole: identique ? "checkmark.shield" : "exclamationmark.triangle",
                              titre: identique ? "Même empreinte par SSH" : "Empreintes différentes",
                              couleur: identique ? Q.enLigne : Q.avertissement, chevron: false)
            }
            .padding(.top, 8)
        }
    }

    private func accepter(_ sorte: SorteAjout) {
        let machine = modele.noeudRelie.flatMap { n in
            modele.charte?.membre(n).flatMap { $0.sorte == .telephone ? nil : n }
        }
        Task { if await modele.accepter(demande, comme: sorte.accord(machine: machine)) { fermer() } }
    }
}

/// Installer un serveur par SSH depuis le nœud relié : fiche, puis étapes de l'installation jusqu'à l'accord.
private struct AjoutServeurEcran: View {
    let modele: ModeleReseau
    @State private var fiche = FicheAjoutServeur()
    @State private var lance: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BandeauErreurReseau(modele: modele)
                if let suivi = lance.flatMap({ m in modele.ajouts.first { $0.machine == m } }) {
                    EtapesAjout(modele: modele, ajout: suivi)
                } else {
                    formulaire
                }
            }
            .padding(.bottom, 32)
        }
        .barreFeuille("Serveur par SSH")
    }

    @ViewBuilder private var formulaire: some View {
        TitreSection(texte: "Serveur")
        Carte {
            champ("Nom", $fiche.nom, "VPS")
            Filet()
            champ("Hôte", $fiche.hote, "serveur.example.com")
            Filet()
            champ("Port", Binding(get: { String(fiche.port) }, set: { fiche.port = Int($0) ?? fiche.port }), "22")
            Filet()
            champ("Utilisateur", $fiche.utilisateur, "lanterne")
            Filet()
            champ("Clé SSH", $fiche.cle, "/home/…/.ssh/id_ed25519")
        }
        Note(texte: "La clé est un fichier du nœud relié, qui se connecte au serveur ; rien ne passe par cet iPhone.")
        Carte {
            Button { Task { if await modele.lancerAjout(fiche) { lance = fiche.machine } } } label: {
                RangeeReglage(symbole: "arrow.down.circle", titre: modele.enCours ?? "Installer",
                              couleur: fiche.complete ? Q.lien : Q.tertiaire, chevron: false)
            }
            .buttonStyle(.plain).disabled(!fiche.complete || modele.enCours != nil)
        }
        .padding(.top, 24)
    }

    private func champ(_ titre: String, _ valeur: Binding<String>, _ exemple: String) -> some View {
        HStack(spacing: 16) {
            Text(titre).font(Q.rangee).foregroundStyle(Q.texte).frame(width: 104, alignment: .leading)
            TextField(exemple, text: valeur).font(Q.rangee).foregroundStyle(Q.texte)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
        }
        .padding(.horizontal, Q.marge).frame(height: Q.rangeeHauteur)
    }
}

/// Les étapes d'un ajout par SSH, faites, en cours ou à venir ; à l'accord, la demande du nouveau nœud.
private struct EtapesAjout: View {
    let modele: ModeleReseau
    let ajout: AjoutReseau
    private static let etapes: [(String, String)] = [
        ("verification", "Vérification"), ("code", "Code"), ("envoi", "Envoi"), ("installation", "Installation"),
        ("appairage", "Appairage"), ("accord", "Ton accord"), ("lien", "Lien"), ("reprise", "Reprise"),
    ]

    var body: some View {
        TitreSection(texte: ajout.nom)
        Carte {
            ForEach(Array(Self.etapes.enumerated()), id: \.offset) { rang, e in
                if rang > 0 { Filet(retrait: 60) }
                RangeeReglage(symbole: symbole(rang), titre: e.1, couleur: rang <= courante ? Q.texte : Q.tertiaire,
                              chevron: false)
            }
        }
        if let message = ajout.message { Note(texte: message) }
        if ajout.etat == "accord_attendu", let d = modele.demandes.first(where: { $0.membre == ajout.membre }) {
            TitreSection(texte: "Ton accord")
            Carte {
                NavigationLink { DemandeReseauEcran(modele: modele, demande: d, proposee: .serveur) } label: {
                    RangeeDemande(demande: d)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var courante: Int { Self.etapes.firstIndex { $0.0 == ajout.etape } ?? 0 }

    private func symbole(_ rang: Int) -> String {
        if ajout.etat == "echec", rang == courante { return "xmark.circle" }
        if rang < courante || ajout.etat == "fini" { return "checkmark.circle" }
        return rang == courante ? "circle.dotted" : "circle"
    }
}
#endif
