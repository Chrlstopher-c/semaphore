// L'écran unique du monde : les PC trouvés, et ce qu'on peut en faire.
//
// Rendu volontairement SOBRE — que des jetons du socle `Systeme`, aucun
// composant maison, aucune animation. La direction artistique de Duplex viendra
// ensuite ; ce qui compte ici est que chaque état soit visible et nommé.
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
            ScrollView { contenu }
        }
        .onChange(of: duplexeur.attendUnCode) { _, attendu in jumelageAffiche = attendu }
        .sheet(isPresented: $jumelageAffiche, onDismiss: abandonnerJumelage) {
            JumelageFeuille()
        }
    }

    private func abandonnerJumelage() {
        guard duplexeur.attendUnCode else { return }
        Task { await duplexeur.deconnecter() }
    }

    private var contenu: some View {
        VStack(alignment: .leading, spacing: Grille.section) {
            Text("Duplex")
                .font(Voix.titreEcran)
                .foregroundStyle(Neutre.encre)
            if let panne = duplexeur.panne { bandeauPanne(panne) }
            listePostes
            if duplexeur.etablie { commandes }
        }
        .padding(.horizontal, Grille.ecran)
        .padding(.vertical, Grille.groupe)
    }

    // MARK: - Les PC trouvés

    private var listePostes: some View {
        VStack(alignment: .leading, spacing: Grille.element) {
            Text("PC sur le réseau")
                .font(Voix.legende)
                .foregroundStyle(Neutre.encreEteinte)
            if duplexeur.postes.isEmpty {
                Text("Aucun PC trouvé. Duplex doit tourner sur le PC, et les deux appareils être sur le même Wi-Fi.")
                    .font(Voix.note)
                    .foregroundStyle(Neutre.encreDouce)
            }
            ForEach(duplexeur.postes) { poste in
                CartePoste(poste: poste, actif: duplexeur.choisi?.id == poste.id) {
                    Task { await duplexeur.choisir(poste) }
                }
            }
        }
    }

    // MARK: - Ce qu'on fait une fois lié

    private var commandes: some View {
        VStack(alignment: .leading, spacing: Grille.element) {
            boutonEcoute
            if duplexeur.ecoute { releve }
            if duplexeur.sources.count > 1 { choixSource }
            if let etat = duplexeur.etatPoste, etat.airplay.actif {
                Text("Le PC joue aussi vers \(etat.airplay.appareil) par AirPlay.")
                    .font(Voix.note)
                    .foregroundStyle(Neutre.encreDouce)
            }
        }
    }

    private var boutonEcoute: some View {
        Button {
            Task { await duplexeur.basculerEcoute() }
        } label: {
            Text(duplexeur.ecoute ? "Arrêter l'écoute" : "Écouter")
                .font(Voix.entete)
                .foregroundStyle(Neutre.fond)
                .frame(maxWidth: .infinity, minHeight: Grille.cible)
                .background(Teinte.accent)
                .clipShape(.rect(cornerRadius: Rayon.controle, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var choixSource: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            Text("Sortie captée")
                .font(Voix.legende)
                .foregroundStyle(Neutre.encreEteinte)
            ForEach(duplexeur.sources) { source in
                Button {
                    Task { await duplexeur.choisirSource(source) }
                } label: {
                    HStack {
                        Text(source.nom).font(Voix.corps).foregroundStyle(Neutre.encre)
                        Spacer(minLength: 0)
                        if duplexeur.etatPoste?.source == source.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Teinte.accent)
                        }
                    }
                    .padding(.vertical, Grille.serre)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Le relevé de qualité. Sans Mac ni débogueur au bout de cette app, c'est
    /// la seule fenêtre sur ce que fait le flux.
    private var releve: some View {
        VStack(alignment: .leading, spacing: Grille.fin) {
            ligne("Tampon", "\(Int(duplexeur.qualite.remplissageMs)) ms")
            ligne("Trous", "\(duplexeur.qualite.trous)")
            ligne("Coupures", "\(duplexeur.qualite.famines + duplexeur.qualite.ruptures)")
            if !duplexeur.qualite.amorce {
                Text("Remplissage du tampon…")
                    .font(Voix.note)
                    .foregroundStyle(Neutre.encreDouce)
            }
        }
        .padding(Grille.bloc)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Neutre.surface)
        .clipShape(.rect(cornerRadius: Rayon.carte, style: .continuous))
    }

    private func ligne(_ libelle: String, _ valeur: String) -> some View {
        HStack {
            Text(libelle).font(Voix.note).foregroundStyle(Neutre.encreDouce)
            Spacer(minLength: 0)
            Text(valeur).font(Voix.mesure).foregroundStyle(Neutre.encre)
        }
    }

    private func bandeauPanne(_ panne: ErreurDuplex) -> some View {
        VStack(alignment: .leading, spacing: Grille.fin) {
            Text(panne.libelle).font(Voix.mention).foregroundStyle(Semantique.panne)
            if let remede = panne.remede {
                Text(remede).font(Voix.note).foregroundStyle(Neutre.encreDouce)
            }
        }
        .padding(Grille.bloc)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Semantique.panne.opacity(0.12))
        .clipShape(.rect(cornerRadius: Rayon.carte, style: .continuous))
    }
}

extension Duplexeur {
    /// Raccourci de lecture pour les vues : la liaison est-elle établie ?
    var etablie: Bool {
        if case .liee = etape { return true }
        return false
    }
}

/// Une rangée de PC : son nom, et où en est la liaison avec lui.
struct CartePoste: View {
    let poste: PosteTrouve
    let actif: Bool
    let surAppui: () -> Void

    var body: some View {
        Button(action: surAppui) {
            HStack(spacing: Grille.element) {
                Image(systemName: "desktopcomputer")
                    .foregroundStyle(actif ? Teinte.accent : Neutre.encreEteinte)
                VStack(alignment: .leading, spacing: Grille.fin) {
                    Text(poste.nom).font(Voix.corps).foregroundStyle(Neutre.encre)
                    Text(poste.service).font(Voix.brut).foregroundStyle(Neutre.encreEteinte)
                }
                Spacer(minLength: 0)
            }
            .padding(Grille.bloc)
            .frame(maxWidth: .infinity, minHeight: Grille.cible, alignment: .leading)
            .background(Neutre.surface)
            .clipShape(.rect(cornerRadius: Rayon.carte, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(poste.nom)
        .accessibilityAddTraits(actif ? .isSelected : [])
    }
}
#endif
