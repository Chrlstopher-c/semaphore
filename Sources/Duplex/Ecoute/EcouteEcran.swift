// L'écran unique du monde. Il ne fait qu'arbitrer entre trois vues selon l'état
// réel de la liaison : la liste des PC, la salle d'écoute par-dessus la liste
// quand un PC est relié, la salle seule quand le son coule.
//
// `☠` Pendant l'écoute, la liste disparaît. C'est l'écran qu'on regarde
// longtemps et peu souvent : tout ce qui n'est pas le son qui coule est du bruit.
#if canImport(SwiftUI)
import DuplexNoyau
import SwiftUI
import Systeme

struct EcouteEcran: View {
    @Environment(Duplexeur.self) private var duplexeur
    /// La présentation de la feuille est un état d'INTERFACE, pas de liaison :
    /// avec un `.constant`, un balayage vers le bas ne la fermerait jamais et
    /// Chris resterait coincé dedans. On la miroite, et la fermeture au geste
    /// coupe la liaison — sinon le PC afficherait un code que plus personne ne
    /// vient recopier.
    @State private var jumelageAffiche = false

    var body: some View {
        ZStack {
            Neutre.fond.ignoresSafeArea()
            GeometryReader { geometrie in
                ScrollView {
                    // La hauteur plancher laisse la salle se centrer quand elle
                    // est seule, sans figer la page quand la liste dépasse.
                    contenu.frame(minHeight: geometrie.size.height)
                }
            }
        }
        .onChange(of: duplexeur.attendUnCode) { _, attendu in jumelageAffiche = attendu }
        .sheet(isPresented: $jumelageAffiche, onDismiss: abandonnerJumelage) {
            JumelageFeuille()
                .environment(duplexeur)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Neutre.fond)
        }
        .sensoryFeedback(Toucher.engage, trigger: duplexeur.ecoute)
        .sensoryFeedback(Toucher.reussite, trigger: duplexeur.etablie) { _, reliee in reliee }
        .sensoryFeedback(Toucher.butee, trigger: duplexeur.panne) { _, panne in panne != nil }
    }

    private func abandonnerJumelage() {
        guard duplexeur.attendUnCode else { return }
        Task { await duplexeur.deconnecter() }
    }

    private var contenu: some View {
        VStack(alignment: .leading, spacing: Grille.section) {
            enTete
            if let panne = duplexeur.panne {
                Bandeau(panne.libelle, remede: panne.remede, ton: .panne)
                    .transition(.item)
            }
            if duplexeur.etablie {
                SalleEcoute()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: duplexeur.ecoute ? .infinity : nil)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            if !duplexeur.ecoute {
                PostesListe().transition(.opacity)
            }
        }
        .padding(.horizontal, Grille.ecran)
        .padding(.vertical, Grille.groupe)
        .animation(Mouvement.surface, value: duplexeur.ecoute)
        .animation(Mouvement.normal, value: duplexeur.etablie)
        .animation(Mouvement.normal, value: duplexeur.panne)
    }

    // MARK: - En-tête

    private var enTete: some View {
        HStack(alignment: .firstTextBaseline) {
            Fronton("Duplex")
            Spacer(minLength: 0)
            if let liaison = EtatLiaison(etape: duplexeur.etape, choisi: duplexeur.choisi != nil) {
                Sceau(liaison.libelle, symbole: liaison.symbole, ton: liaison.ton)
                    .id(liaison)
                    .transition(.item)
            }
        }
        .animation(Mouvement.normal, value: duplexeur.etape)
    }
}

extension Duplexeur {
    /// Raccourci de lecture pour les vues : la liaison est-elle établie ?
    var etablie: Bool {
        if case .liee = etape { return true }
        return false
    }
}

/// Le sceau de liaison en tête d'écran : où en est-on avec le PC choisi. Nul
/// tant qu'aucun PC n'est choisi — un sceau « au repos » ne dirait rien.
struct EtatLiaison: Hashable {
    let libelle: String
    let symbole: String
    let ton: Ton

    init?(etape: EtapeLiaison, choisi: Bool) {
        switch etape {
        case .repos:
            guard choisi else { return nil }
            self.init("Connexion…", "antenna.radiowaves.left.and.right", .neutre)
        case .demandeEnvoyee, .codeAttendu, .codeEnVerification, .authentification:
            self.init("Jumelage…", "key", .neutre)
        case .liee:
            self.init("Relié", "link", .ok)
        case .refusee:
            self.init("Refusé", "key.slash", .panne)
        case .fermee:
            self.init("Déconnecté", "bolt.horizontal", .neutre)
        }
    }

    private init(_ libelle: String, _ symbole: String, _ ton: Ton) {
        self.libelle = libelle
        self.symbole = symbole
        self.ton = ton
    }
}
#endif
