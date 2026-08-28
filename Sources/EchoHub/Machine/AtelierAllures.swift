// Les pièces communes de l'atelier — le lieu où l'on règle la machine.
//
// `☠` L'atelier a le droit d'être dense (`CHARTE.md`, § Amendement du
// 28/08/2026), mais la densité se peint en `note` et en `machine` : jamais une
// mesure en encre pleine à 17 pt. C'est ce qui garde vrai le corollaire
// fondateur — la seule chose composée ainsi est ce que le modèle répond.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

/// Une porte de l'atelier : un glyphe, un sujet, et ce que le sujet contient
/// en ce moment. Le détail est une MESURE, pas une promesse : il dit ce qu'on
/// trouvera derrière, ce qui évite d'ouvrir pour rien.
struct PorteAtelier: View {
    let symbole: String
    let titre: String
    let detail: String?
    /// Un ton autre que neutre ne décore pas : il annonce qu'il y a quelque
    /// chose à faire derrière cette porte.
    var ton: Ton = .neutre

    var body: some View {
        HStack(spacing: Trame.element) {
            Image(systemName: symbole)
                .foregroundStyle(ton == .neutre ? Teinte.accent : ton.couleur)
                .frame(width: Trame.cible, height: Trame.cible)
                .background(
                    Teinte.surface,
                    in: RoundedRectangle(cornerRadius: Galbe.controle, style: .continuous)
                )
            VStack(alignment: .leading, spacing: Trame.fin) {
                Text(titre).mention().foregroundStyle(Teinte.encre)
                if let detail, !detail.isEmpty {
                    Text(detail).mesureFine().foregroundStyle(Teinte.encreEteinte).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").imageScale(.small)
                .foregroundStyle(Teinte.encreEteinte)
        }
        .frame(minHeight: Trame.rangee)
        .contentShape(.rect)
    }
}

/// Une mesure : son libellé à gauche, sa valeur à droite en chiffres à chasse
/// fixe. C'est la brique de tout l'atelier.
///
/// `☠` La valeur est en `mesure`, jamais en `corps` : sans chiffres à chasse
/// fixe, une colonne de tailles danse d'une ligne à l'autre.
struct LigneMesure: View {
    let libelle: String
    let valeur: String
    /// Ce que le serveur donne comme raison de cette valeur. Affichée sous la
    /// ligne, en `machine` : c'est lui qui parle, on ne le réécrit pas.
    var justification: String?
    var ton: Ton = .neutre

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            HStack(alignment: .firstTextBaseline, spacing: Trame.serre) {
                Text(libelle).note().foregroundStyle(Teinte.encreDouce)
                Spacer(minLength: Trame.serre)
                Text(valeur)
                    .mesure()
                    .foregroundStyle(ton == .neutre ? Teinte.encre : ton.couleur)
                    .multilineTextAlignment(.trailing)
            }
            if let justification, !justification.isEmpty {
                Text(justification)
                    .brut()
                    .foregroundStyle(Teinte.encreEteinte)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Une jauge de remplissage, dessinée par un MASQUE À L'ÉCHELLE.
///
/// `☠` Une barre qui anime sa largeur anime une mise en page, et ça rame
/// visiblement à 60 Hz sur A12 — la charte n'autorise que `transform` et
/// `opacity`. On dessine donc la barre pleine, et on l'écrase horizontalement :
/// c'est un `scaleEffect`, donc une transformation.
///
/// `☠` `part` est un optionnel, et ce n'est pas une commodité : `nil` veut dire
/// « on ne sait pas », et une jauge à zéro se lirait « il ne prend rien ». Sans
/// mesure, la jauge ne se dessine pas.
struct Jauge: View {
    let part: Double?
    var ton: Ton = .actif

    private let epaisseur: CGFloat = 6

    var body: some View {
        if let part {
            Capsule()
                .fill(ton.voile)
                .frame(height: epaisseur)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(ton.couleur)
                        .scaleEffect(x: max(0, min(part, 1)), y: 1, anchor: .leading)
                }
                .animation(Elan.normal, value: part)
        }
    }
}

/// Une rangée d'action dans une liste de l'atelier : un verbe, un ton, et rien
/// d'autre. Un seul verbe par rangée — le GPU est exclusif, et proposer six
/// gestes concurrents laisserait croire qu'on peut les tenir tous.
struct VerbeAtelier: View {
    let libelle: String
    var ton: Ton = .actif
    var occupe = false
    let action: () -> Void

    var body: some View {
        Button(libelle, action: action)
            .buttonStyle(.appui)
            .legende()
            .foregroundStyle(occupe ? Teinte.encreEteinte : ton.couleur)
            .disabled(occupe)
    }
}

/// Une section de l'atelier : sa rubrique, et ce qu'elle contient.
struct SectionAtelier<Contenu: View>: View {
    private let titre: String
    private let contenu: Contenu

    init(_ titre: String, @ViewBuilder contenu: () -> Contenu) {
        self.titre = titre
        self.contenu = contenu()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.element) {
            Text(titre).rubrique()
            contenu
        }
    }
}

/// La coquille d'un écran poussé de l'atelier : fond, fronton, défilement.
///
/// `☠` Le fronton est dessiné maison (26 pt) et la barre système reste en
/// `.inline` : en `.large` elle composerait à 34 pt gras, au-dessus du plafond
/// que la charte pose pour qu'aucun titre ne domine la réponse du modèle.
struct PageAtelier<Contenu: View>: View {
    private let titre: String
    private let rafraichir: (() async -> Void)?
    private let contenu: Contenu

    init(
        _ titre: String, rafraichir: (() async -> Void)? = nil,
        @ViewBuilder contenu: () -> Contenu
    ) {
        self.titre = titre
        self.rafraichir = rafraichir
        self.contenu = contenu()
    }

    var body: some View {
        ZStack {
            Teinte.fond.ignoresSafeArea()
            defilement
        }
        .navigationTitle(titre)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var defilement: some View {
        let vue = ScrollView {
            VStack(alignment: .leading, spacing: Trame.section) {
                contenu
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.vertical, Trame.groupe)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        if let rafraichir {
            vue.refreshable { await rafraichir() }
        } else {
            vue
        }
    }
}
#endif
