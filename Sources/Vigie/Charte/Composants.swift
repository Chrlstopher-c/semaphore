// Les briques visuelles de Quart, reprises de l'étalon : boutons ronds, capsules, cartes groupées, rangées, pilules.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// Appui : léger recul, comme partout dans l'étalon.
struct StyleAppui: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

/// Bouton rond à glyphe (composeur, loupe de la liste).
struct BoutonRond: View {
    let symbole: String
    var diametre: CGFloat = 36
    var fond: Color = Q.rond
    var encre: Color = Q.texte
    var poids: Font.Weight = .regular
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbole)
                .font(.system(size: diametre * 0.44, weight: poids))
                .foregroundStyle(encre)
                .frame(width: diametre, height: diametre)
                .background(fond, in: .circle)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.circle)
        }
        .buttonStyle(StyleAppui())
    }
}

/// Grande capsule blanche « + Nouvelle session ».
struct CapsuleBlanche: View {
    let titre: String
    var symbole: String = "plus"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbole).font(.system(size: 17, weight: .regular))
                Text(titre).font(Q.rangee)
            }
            .foregroundStyle(Q.carte)
            .padding(.horizontal, 20)
            .frame(height: 42)
            .background(Q.texte, in: .capsule)
        }
        .buttonStyle(StyleAppui())
    }
}

/// Carte groupée : fond #20201F, rayon 12 continu, rangées séparées par un filet décalé.
struct Carte<Contenu: View>: View {
    @ViewBuilder let contenu: () -> Contenu

    var body: some View {
        VStack(spacing: 0) { contenu() }
            .background(Q.carte, in: .rect(cornerRadius: Q.rayonCarte, style: .continuous))
            .padding(.horizontal, Q.marge)
    }
}

/// Filet entre deux rangées d'une carte, aligné sur le texte.
struct Filet: View {
    var retrait: CGFloat = Q.marge

    var body: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1 / 3).padding(.leading, retrait)
    }
}

/// Libellé de section au-dessus d'une carte (« Compte », « Contexte »).
struct TitreSection: View {
    let texte: String

    var body: some View {
        Text(texte).font(Q.section).foregroundStyle(Q.tertiaire)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Q.marge * 2).padding(.top, 24).padding(.bottom, 8)
    }
}

/// Pilule de texte (« Recommandé », « ⚠ 3,5× ou plus »).
struct Pilule: View {
    let texte: String
    var symbole: String? = nil
    var fond: Color = Q.pilule
    var encre: Color = Q.secondaire

    var body: some View {
        HStack(spacing: 4) {
            if let symbole { Image(systemName: symbole) }
            Text(texte)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(encre)
        .padding(.horizontal, 10).frame(height: 26)
        .background(fond, in: .capsule)
    }
}

/// Rangée de réglage : icône trait, libellé, valeur, chevron.
struct RangeeReglage: View {
    var symbole: String? = nil
    let titre: String
    var valeur: String? = nil
    var couleur: Color = Q.texte
    var chevron = true

    var body: some View {
        HStack(spacing: 16) {
            if let symbole {
                Image(systemName: symbole).font(.system(size: 19, weight: .light)).foregroundStyle(Q.secondaire)
                    .frame(width: 28)
            }
            Text(titre).font(Q.rangee).foregroundStyle(couleur)
            Spacer(minLength: 8)
            if let valeur { Text(valeur).font(Q.rangee).foregroundStyle(Q.secondaire).lineLimit(1) }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Q.meta)
            }
        }
        .padding(.horizontal, Q.marge).frame(minHeight: Q.rangeeHauteur)
        .contentShape(.rect)
    }
}

/// Jauge horizontale (usage, contexte) : barre accent sur piste bleu nuit.
struct Jauge: View {
    let part: Double

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Q.piste)
                Capsule().fill(Q.accent).frame(width: max(6, g.size.width * min(max(part, 0), 1)))
            }
        }
        .frame(height: 6)
    }
}

/// Anneau d'usage de l'en-tête de session (étalon : Ø 30, trait 2) : part en accent, nombre au centre.
struct AnneauUsage: View {
    let part: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color(hex: 0x4F4F4F), lineWidth: 2)
            Circle().trim(from: 0, to: min(max(part, 0), 1))
                .stroke(Q.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((part * 100).rounded()))").font(.system(size: 12, weight: .medium)).monospacedDigit()
                .foregroundStyle(Q.texte)
        }
        .frame(width: 30, height: 30)
    }
}

/// Bouton d'en-tête de feuille (✕, ↻, ⓘ) : glyphe fin, zone 44.
struct BoutonEntete: View {
    let symbole: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbole).font(.system(size: 20, weight: .light)).foregroundStyle(Q.texte)
                .frame(width: 44, height: 44).contentShape(.rect)
        }
        .buttonStyle(StyleAppui())
    }
}

/// Glyphe « trois traits décroissants » du tiroir.
struct GlypheTiroir: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Capsule().frame(width: 22, height: 1.6)
            Capsule().frame(width: 17, height: 1.6)
            Capsule().frame(width: 12, height: 1.6)
        }
        .foregroundStyle(Q.texte)
        .frame(width: 44, height: 44, alignment: .leading)
    }
}

/// Bandeau éphémère (erreur d'une commande, confirmation) posé en haut d'un écran.
struct Bandeau: View {
    let texte: String

    var body: some View {
        Text(texte).font(Q.detail).foregroundStyle(Q.texte).multilineTextAlignment(.center)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Q.rond, in: .capsule)
            .padding(.horizontal, 24)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

extension View {
    /// Fond et matière d'une feuille de Quart (détentes, poignée, fond du fil).
    func feuilleQuart(_ detentes: Set<PresentationDetent> = [.medium, .large]) -> some View {
        presentationDetents(detentes)
            .presentationDragIndicator(.visible)
            .presentationBackground(Q.fondFil)
            .presentationCornerRadius(24)
    }

    /// Barre de navigation d'une feuille poussée : fond du fil, titre blanc, retour natif.
    func barreFeuille(_ titre: String) -> some View {
        navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Q.fondFil, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(Q.fondFil.ignoresSafeArea())
    }
}
#endif
