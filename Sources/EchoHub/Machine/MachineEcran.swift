// L'entrée de l'atelier : ce que le PC fait à cet instant, et les portes vers
// ce qu'on peut y régler.
//
// `☠` Amendé le 28/08/2026. Cet écran affichait trois lignes et s'arrêtait là,
// au motif que « le reste se règle devant la machine ». Chris a renversé la
// décision : il veut chercher, télécharger, charger et effacer depuis le
// téléphone. La forme retenue est un LIEU, pas un tableau de bord — on entre
// dans l'atelier, on descend un sujet à la fois. Voir `CHARTE.md`,
// § Amendement du 28/08/2026.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

/// Les deux onglets du web qui parlent de la machine : `Modèles` (ce qui est chargé, sur le disque, à
/// télécharger) et `Système` (santé, journal, réglages du relais).
public enum RayonMachine: Sendable {
    case modeles, systeme

    var titre: String { self == .modeles ? "Modèles" : "Système" }
}

public struct MachineEcran: View {
    @Environment(Salon.self) private var salon
    let rayon: RayonMachine
    @State private var registre: [ModeleEnregistre] = []
    @State private var transfertsActifs = 0
    @State private var echecReleve: String?

    public init(rayon: RayonMachine) { self.rayon = rayon }

    public var body: some View {
        NavigationStack {
            ZStack {
                Teinte.fond.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Trame.section) {
                        Fronton(rayon.titre)
                        corps
                    }
                    .padding(.vertical, Trame.groupe)
                }
                .refreshable { await relever() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .pastilleMoteur()
            .task { await relever() }
        }
    }

    private var corps: some View {
        VStack(alignment: .leading, spacing: Trame.section) {
            if let echec = salon.echecMachine { EchecAction(raison: echec) }
            if rayon == .modeles { CarteStatut(etat: salon.statut) }
            portes
            if let echecReleve { EchecAction(raison: echecReleve) }
        }
        .padding(.horizontal, Trame.ecran)
    }

    /// L'ordre suit ce qu'on fait le plus souvent : charger un modèle qu'on a
    /// déjà, puis en chercher un neuf, puis ranger.
    @ViewBuilder private var portes: some View {
        switch rayon {
        case .modeles:
            SectionAtelier("Les modèles") {
                VStack(spacing: 0) {
                    lien(RegistreEcran(), "square.stack.3d.up", "Sur le disque", detailRegistre)
                    lien(DecouverteEcran(), "magnifyingglass", "Découvrir", "Hugging Face")
                    lien(
                        TransfertsEcran(), "arrow.down.circle", "Transferts", detailTransferts,
                        ton: transfertsActifs > 0 ? .actif : .neutre
                    )
                }
            }
        case .systeme:
            SectionAtelier("La machine") {
                VStack(spacing: 0) {
                    lien(ProfilServicesEcran(), "cpu", "Machine et services", "GPU, mémoire, services de la pile")
                    lien(MoteursEcran(), "engine.combustion", "Moteurs", "llama.cpp, vLLM")
                    lien(JournalEcran(), "list.bullet.rectangle", "Journal et santé", nil)
                    lien(DisqueEcran(), "internaldrive", "Disque du PC", nil)
                    lien(
                        OutilsParDefautEcran(), "wrench.and.screwdriver", "Outils par défaut",
                        "Appliqués aux conversations neuves"
                    )
                    lien(ReglagesRelaisEcran(), "antenna.radiowaves.left.and.right", "Relais", nil)
                }
            }
        }
    }

    private func lien(
        _ destination: some View, _ symbole: String, _ titre: String, _ detail: String?,
        ton: Ton = .neutre
    ) -> some View {
        NavigationLink { destination } label: {
            PorteAtelier(symbole: symbole, titre: titre, detail: detail, ton: ton)
        }
        .buttonStyle(.appui)
    }

    private var detailRegistre: String? {
        registre.isEmpty ? nil : "\(registre.count) sur le disque"
    }

    private var detailTransferts: String? {
        transfertsActifs > 0 ? "\(transfertsActifs) en cours" : nil
    }

    /// Un relevé LÉGER : de quoi remplir les détails des portes, pas de quoi
    /// peindre un tableau de bord. Les deux appels partent ensemble — ils sont
    /// indépendants, et les enchaîner ferait attendre deux traversées du tunnel.
    private func relever() async {
        await salon.rafraichirStatut()
        do {
            async let modeles = salon.modeles.registre()
            async let transferts = salon.modeles.telechargements()
            registre = try await modeles
            transfertsActifs = try await transferts.filter(\.actif).count
            echecReleve = nil
        } catch {
            Journal.echec("relevé de l'atelier échoué : \(error)")
            echecReleve = Salon.libelle(error)
        }
    }
}

/// Ce que le PC fait à cet instant. Un seul état à la fois : le GPU est
/// exclusif, et c'est cette exclusivité que l'écran rend lisible.
struct CarteStatut: View {
    let etat: EtatChargement<StatutInference>

    private var statut: StatutInference? { etat.contenu }

    var body: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.element) {
                HStack {
                    Text("Modèle chargé").rubrique()
                    Spacer(minLength: 0)
                    Sceau(libelle, symbole: symbole).ton(ton)
                }
                Text(statut?.modele ?? "Aucun")
                    .titreSection()
                    .foregroundStyle(statut?.modele == nil ? Teinte.encreDouce : Teinte.encre)
                    .lineLimit(2)
                if let message = statut?.message, !message.isEmpty {
                    Text(message).note().foregroundStyle(Teinte.encreDouce)
                }
                servi
                explication
            }
        }
    }

    /// Ce que le moteur sert RÉELLEMENT — pas ce que le plan demandait. Les
    /// deux diffèrent dès que le planificateur a plafonné, et c'est justement
    /// l'écart qu'on vient vérifier.
    @ViewBuilder private var servi: some View {
        if let moteur = statut?.etatMoteur, statut?.estPret == true {
            VStack(alignment: .leading, spacing: Trame.fin) {
                LigneMesure(libelle: "Contexte servi", valeur: Mesures.tokens(moteur.contexte))
                LigneMesure(libelle: "Couches sur GPU", valeur: "\(moteur.couchesGpu)")
                if let vram = moteur.vramModeleOctets {
                    LigneMesure(libelle: "VRAM du modèle", valeur: Mesures.octets(vram))
                }
            }
        }
    }

    /// `☠` « La machine n'a pas répondu au dernier relevé » était affiché aussi
    /// bien pendant le PREMIER relevé qu'après un échec franc — vrai une fois
    /// sur deux, et jamais du bon côté. La cause est portée par l'état lui-même.
    @ViewBuilder private var explication: some View {
        switch etat {
        case .chargement, .vide:
            Text("Relevé en cours…").note().foregroundStyle(Teinte.encreDouce)
        case .echec(let raison):
            VStack(alignment: .leading, spacing: Trame.fin) {
                Text(raison).note().foregroundStyle(Teinte.encreDouce)
                Text("Tire vers le bas pour resonder.")
                    .note().foregroundStyle(Teinte.encreEteinte)
            }
        case .pret:
            EmptyView()
        }
    }

    private var libelle: String {
        if case .echec = etat { return "Injoignable" }
        switch statut?.etat {
        case .pret: return "Prêt"
        case .enCours: return "Chargement"
        case .echoue: return "Échec"
        case .inactif: return "Inactif"
        case nil: return "Relevé…"
        }
    }

    private var symbole: String {
        if case .echec = etat { return "antenna.radiowaves.left.and.right.slash" }
        switch statut?.etat {
        case .pret: return "checkmark.circle.fill"
        case .enCours: return "hourglass"
        case .echoue: return "exclamationmark.triangle.fill"
        case .inactif, nil: return "questionmark.circle"
        }
    }

    private var ton: Ton {
        if case .echec = etat { return .panne }
        switch statut?.etat {
        case .pret: return .ok
        case .enCours: return .actif
        case .echoue: return .panne
        case .inactif, nil: return .neutre
        }
    }
}
#endif
