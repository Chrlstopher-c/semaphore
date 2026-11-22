// Réglages › Connexion (grammaire des réglages de l'étalon) : l'état RÉEL de la liaison — voie (directe ou par le Pi),
// état (relié, en attente d'acceptation, injoignable, refusé), adresse, nœud, empreinte de l'iPhone — et, à tout
// moment, se relier autrement sans réinstaller : la liaison en service reste active tant que la nouvelle n'est pas
// acceptée, la pile ouverte et les réglages ne bougent pas.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ConnexionReglages: View {
    @Environment(Cablage.self) private var cablage
    @Environment(ModeleRelais.self) private var modele
    @State private var formulaire: Voie?

    private static let note = "Changer de liaison ne touche ni aux sessions ouvertes ni aux réglages ; la liaison "
        + "actuelle reste en service jusqu’à ce que la nouvelle soit acceptée."

    private var parPi: Bool { cablage.etatAiguilleur?.identiteNoeud != nil }
    private var enAttente: Bool { cablage.etatAiguilleur != nil && cablage.etatAiguilleur?.identiteNoeud == nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TitreSection(texte: "Liaison actuelle")
                Carte { actuelle }
                if enAttente { attente }
                TitreSection(texte: "Se relier autrement")
                Carte { autrement }
                Text(Self.note).font(Q.detail).foregroundStyle(Q.secondaire).padding(.horizontal, 32).padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
        .barreFeuille("Connexion")
        .navigationDestination(item: $formulaire) { v in
            FormulaireConnexion(entete: false, termine: { formulaire = nil }, voie: v).barreFeuille(titre(v))
        }
    }

    @ViewBuilder private var actuelle: some View {
        RangeeReglage(symbole: parPi ? "point.3.connected.trianglepath.dotted" : "wifi",
                      titre: "Voie", valeur: parPi ? "Par le Pi" : "Directe", chevron: false)
        Filet(retrait: 60)
        RangeeReglage(symbole: symboleEtat, titre: "État", valeur: libelleEtat, couleur: Q.texte, chevron: false)
        Filet(retrait: 60)
        RangeeReglage(symbole: "link", titre: "Adresse", valeur: adresse, chevron: false)
        if parPi, let nom = cablage.etatAiguilleur?.nomNoeud {
            Filet(retrait: 60)
            RangeeReglage(symbole: "desktopcomputer", titre: "Nœud", valeur: nom, chevron: false)
        }
        Filet(retrait: 60)
        NavigationLink { PageEmpreinte() } label: {
            RangeeReglage(symbole: "touchid", titre: "Empreinte de cet iPhone")
        }
        .buttonStyle(.plain)
    }

    /// Demande en cours vers le Pi : empreinte à comparer, état du lien, annulation.
    @ViewBuilder private var attente: some View {
        TitreSection(texte: "Demande en attente (par le Pi)")
        Carte {
            EtatLienVue(lien: cablage.lienAiguilleur)
            Filet()
            EmpreinteVue(texte: cablage.empreinteAppareil).padding(Q.marge)
            Filet()
            Button { cablage.annulerAiguilleur() } label: {
                RangeeReglage(titre: "Annuler la demande", couleur: Q.deconnexion, chevron: false)
            }
            .buttonStyle(.plain)
        }
        Text("Accepte cet iPhone dans Lanterne › Paramètres › Réseau, après avoir vérifié que l’empreinte est la même.")
            .font(Q.detail).foregroundStyle(Q.secondaire).padding(.horizontal, 32).padding(.top, 8)
    }

    @ViewBuilder private var autrement: some View {
        ligne(.aiguilleur, "point.3.connected.trianglepath.dotted", "Passer par le Pi")
        Filet(retrait: 60)
        ligne(.direct, "wifi", "Liaison directe avec un code")
        Filet(retrait: 60)
        ligne(.motDePasse, "key", "Liaison directe avec un mot de passe")
    }

    private func ligne(_ v: Voie, _ symbole: String, _ titre: String) -> some View {
        Button { formulaire = v } label: { RangeeReglage(symbole: symbole, titre: titre) }.buttonStyle(.plain)
    }

    private func titre(_ v: Voie) -> String { v == .aiguilleur ? "Passer par le Pi" : "Liaison directe" }

    private var adresse: String {
        if let a = cablage.etatAiguilleur, let h = URL(string: a.adresse)?.host() { return h }
        return cablage.adresseConnue ? (cablage.adresse.host() ?? cablage.adresse.absoluteString) : "—"
    }

    private var libelleEtat: String {
        if parPi {
            switch cablage.lienAiguilleur {
            case .ouvert: return "Relié"
            case .refuse(let r): return r.contains("révoqu") ? "Révoqué" : "Refusé"
            case .deconnecte: return "Injoignable"
            default: return "Connexion…"
            }
        }
        switch modele.lien {
        case .connecte: return "Relié"
        case .attente: return "Connexion…"
        case .coupe: return "Injoignable"
        case .nonConnecte: return "Clé refusée ou révoquée"
        }
    }

    private var symboleEtat: String {
        switch libelleEtat {
        case "Relié": return "checkmark.circle"
        case "Connexion…": return "arrow.triangle.2.circlepath"
        default: return "exclamationmark.triangle"
        }
    }
}

extension Voie: Identifiable { var id: String { rawValue } }

/// L'empreinte de l'iPhone, à comparer avec celle que montre le nœud.
struct PageEmpreinte: View {
    @Environment(Cablage.self) private var cablage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Carte { EmpreinteVue(texte: cablage.empreinteAppareil).padding(Q.marge) }.padding(.top, 8)
                Text("Même empreinte dans Lanterne › Paramètres › Réseau : c’est bien cet iPhone.").font(Q.detail)
                    .foregroundStyle(Q.secondaire).padding(.horizontal, 32)
            }
        }
        .barreFeuille("Empreinte")
    }
}
#endif
