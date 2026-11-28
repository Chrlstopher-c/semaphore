// La bande des instructions (un bloc par étape, large selon sa durée, peint de la lumière qu'il produit) et les
// réglages de l'étape touchée (genre, couleur ou animation, dosage, durée, courbe, ordre).
#if canImport(SwiftUI) && canImport(UIKit)
import LueurNoyau
import SwiftUI
import Systeme

struct BandeEtapes: View {
    let etapes: [Etape]
    @Binding var choisie: Int
    let ajouter: () -> Void

    var body: some View {
        let rendus = Horaire.rendu(etapes)
        let total = max(Horaire.total(etapes), 1)
        ScrollViewReader { defile in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Grille.serre) {
                    ForEach(Array(etapes.enumerated()), id: \.offset) { i, e in
                        Button { choisie = i } label: {
                            Bloc(etape: e, rendu: rendus[i], choisi: i == choisie)
                                .frame(width: min(220, max(96, 420 * (e.duree ?? 0) / total)))
                        }
                        .buttonStyle(Presse())
                        .id(i)
                    }
                    Button(action: ajouter) {
                        Image(systemName: "plus").font(.title3)
                            .foregroundStyle(Neutre.encreDouce)
                            .frame(width: 56, height: 64)
                            .background(Neutre.surface, in: .rect(cornerRadius: Rayon.controle, style: .continuous))
                    }
                    .buttonStyle(Presse())
                    .sensoryFeedback(Toucher.contact, trigger: etapes.count)
                }
            }
            .onChange(of: choisie) { _, i in withAnimation(Mouvement.normal) { defile.scrollTo(i, anchor: .center) } }
        }
    }
}

private struct Bloc: View {
    let etape: Etape
    let rendu: Horaire.Rendu
    let choisi: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.fin) {
            Label(etape.genre.nom, systemImage: etape.genre.symbole).font(Voix.legende.bold())
            Text(etape.genre == .retour ? "lumière d'avant" : Horaire.duree(etape.duree ?? 0))
                .font(Voix.mesure).opacity(0.8)
        }
        .lineLimit(1)
        .foregroundStyle(encre)
        .padding(.horizontal, Grille.element)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(fond, in: .rect(cornerRadius: Rayon.controle, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous)
                .strokeBorder(choisi ? Neutre.encre : Neutre.trait, lineWidth: choisi ? 2 : Grille.trait)
        }
        .animation(Mouvement.micro, value: choisi)
    }

    private var fond: LinearGradient {
        let couleurs: [Color]
        if rendu.animee {
            couleurs = ["#b8323f", "#b89a2c", "#2fa35a", "#2f6fc0", "#8a3cc0"].map(Color.init(hexa:))
        } else {
            switch etape.genre {
            case .pulsation: couleurs = Array(repeating: [rendu.creux, rendu.fin], count: 4).flatMap { $0 }
                .map(Color.init(hexa:)) + [Color(hexa: rendu.creux)]
            case .maintien: couleurs = [Color(hexa: rendu.debut), Color(hexa: rendu.debut)]
            case .retour: couleurs = [Color(hexa: "#2b2740"), Color(hexa: "#2b2740")]
            default: couleurs = [Color(hexa: rendu.debut), Color(hexa: rendu.fin)]
            }
        }
        return LinearGradient(colors: couleurs, startPoint: .leading, endPoint: .trailing)
    }

    /// Encre choisie sur la couleur SOUS le texte (côté gauche du bloc).
    private var encre: Color {
        if rendu.animee { return .white }
        let sous = etape.genre == .pulsation ? rendu.creux : etape.genre == .retour ? "#2b2740" : rendu.debut
        guard let n = Nuance(hexa: sous) else { return .white }
        let l = 0.299 * Double(n.rouge) + 0.587 * Double(n.vert) + 0.114 * Double(n.bleu)
        return l > 150 ? Color(hexa: "#14111d") : .white
    }
}

struct ReglagesEtape: View {
    @Binding var etape: Etape
    let rang: Int
    let nombre: Int
    let deplacer: (Int) -> Void
    let retirer: () -> Void
    let precedente: Etape?
    @Environment(Lampe.self) private var lampe
    private let couleurs = ["#ffffff", "#ffb46b", "#ff6a1a", "#ff0000", "#ff2d6f", "#8000ff",
                            "#0040ff", "#29c8ff", "#00ff40", "#ffd000"]
    private let genres = Array(repeating: GridItem(.flexible(), spacing: Grille.serre), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.bloc) {
            HStack {
                Text("Étape \(rang + 1) sur \(nombre)").font(Voix.entete).foregroundStyle(Neutre.encre)
                Spacer()
                icone("chevron.left", actif: rang > 0) { deplacer(-1) }
                icone("chevron.right", actif: rang < nombre - 1) { deplacer(1) }
                icone("trash", actif: nombre > 1, action: retirer)
            }
            LazyVGrid(columns: genres, spacing: Grille.serre) {
                ForEach(Etape.Genre.allCases, id: \.self) { g in puceGenre(g) }
            }
            Text(etape.genre.explication).font(Voix.note).foregroundStyle(Neutre.encreEteinte)
            dosage
        }
        .padding(Grille.bloc)
        .background(Neutre.surface, in: .rect(cornerRadius: Rayon.carte, style: .continuous))
        .sensoryFeedback(Toucher.selection, trigger: etape.genre)
    }

    @ViewBuilder private var dosage: some View {
        switch etape.genre {
        case .fondu:
            nuancier
            curseur("Intensité", valeur: $etape.intensite, defaut: 80, plancher: 1)
            duree
            VStack(alignment: .leading, spacing: Grille.serre) {
                Text("Courbe").rubrique()
                Picker("Courbe", selection: Binding(get: { etape.courbe ?? .douce }, set: { etape.courbe = $0 })) {
                    ForEach(Etape.Courbe.allCases, id: \.self) { Text($0.nom).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        case .pulsation:
            nuancier
            curseur("Creux", valeur: $etape.creux, defaut: 20, plancher: 0, plafond: (etape.pic ?? 100) - 1)
            curseur("Pic", valeur: $etape.pic, defaut: 100, plancher: (etape.creux ?? 0) + 1)
            duree
            compteur("Une onde", texte: String(format: "%.1f s", etape.onde ?? 2).replacingOccurrences(of: ".", with: ","),
                     moins: { etape.onde = max(0.4, (((etape.onde ?? 2) - 0.2) * 10).rounded() / 10) },
                     plus: { etape.onde = min(60, (((etape.onde ?? 2) + 0.2) * 10).rounded() / 10) })
        case .animation:
            HStack {
                Text("Animation").rubrique()
                Spacer()
                Picker("Animation", selection: Binding(get: { etape.effet ?? 0x93 }, set: { etape.effet = $0 })) {
                    ForEach(lampe.effets) { Text($0.nom).tag($0.code) }
                }
                .pickerStyle(.menu)
            }
            curseur("Vitesse", valeur: $etape.vitesse, defaut: 50, plancher: 0)
            duree
        case .maintien, .extinction:
            duree
        case .retour:
            EmptyView()
        }
    }

    // MARK: - Éléments

    private func puceGenre(_ g: Etape.Genre) -> some View {
        let on = etape.genre == g
        return Button {
            guard !on else { return }
            var neuve = Etape.neuve(g, apres: precedente ?? etape)
            if let d = etape.duree, neuve.duree != nil { neuve.duree = d }
            if let c = etape.couleur, neuve.couleur != nil { neuve.couleur = c }
            etape = neuve
        } label: {
            Label(g.nom, systemImage: g.symbole).font(Voix.mention).lineLimit(1)
                .foregroundStyle(on ? Neutre.encre : Neutre.encreDouce)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(on ? Teinte.accent.opacity(0.18) : Neutre.surfaceHaute,
                            in: .rect(cornerRadius: Rayon.controle, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous)
                        .strokeBorder(on ? Teinte.accent : .clear, lineWidth: Grille.trait)
                }
        }
        .buttonStyle(Presse())
    }

    private var nuancier: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            Text("Couleur").rubrique()
            HStack(spacing: 0) {
                ForEach(couleurs, id: \.self) { hexa in
                    let on = etape.couleur == hexa
                    Button { etape.couleur = hexa } label: {
                        Circle().fill(Color(hexa: hexa)).frame(width: 26, height: 26)
                            .overlay { Circle().strokeBorder(on ? .white : Neutre.trait, lineWidth: on ? 3 : 1) }
                            .frame(maxWidth: .infinity, minHeight: Grille.cible)
                    }
                    .buttonStyle(Presse())
                }
                ColorPicker("", selection: choix, supportsOpacity: false).labelsHidden()
                    .frame(maxWidth: .infinity, minHeight: Grille.cible)
            }
        }
    }

    /// Le sélecteur natif d'iOS, pour toute autre couleur.
    private var choix: Binding<Color> {
        Binding(get: { Color(hexa: etape.couleur ?? "#ffffff") }, set: { c in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
            func o(_ v: CGFloat) -> UInt8 { UInt8((min(max(v, 0), 1) * 255).rounded()) }
            etape.couleur = Nuance(rouge: o(r), vert: o(g), bleu: o(b)).hexa
        })
    }

    private func curseur(_ titre: String, valeur: Binding<Int?>, defaut: Int, plancher: Int,
                         plafond: Int = 100) -> some View {
        let v = Binding<Double>(get: { Double(valeur.wrappedValue ?? defaut) },
                                set: { valeur.wrappedValue = min(plafond, max(plancher, Int($0))) })
        return VStack(alignment: .leading, spacing: Grille.fin) {
            HStack {
                Text(titre).rubrique()
                Spacer()
                Text("\(valeur.wrappedValue ?? defaut) %").font(Voix.mesure).foregroundStyle(Neutre.encreDouce)
            }
            Slider(value: v, in: 0...100, step: 1).frame(minHeight: Grille.cible)
        }
    }

    private var duree: some View {
        let d = etape.duree ?? 0
        func pas(_ v: Double) -> Double { v < 10 ? 1 : v < 60 ? 5 : v < 600 ? 30 : 60 }
        return compteur("Durée", texte: Horaire.duree(d),
                        moins: { etape.duree = max(0, d - pas(d - 0.01)) },
                        plus: { etape.duree = min(10800, d + pas(d)) })
    }

    private func compteur(_ titre: String, texte: String, moins: @escaping () -> Void,
                          plus: @escaping () -> Void) -> some View {
        Stepper(onIncrement: plus, onDecrement: moins) {
            HStack {
                Text(titre).rubrique()
                Spacer()
                Text(texte).font(Voix.mesure).foregroundStyle(Neutre.encre)
            }
        }
        .frame(minHeight: Grille.cible)
    }

    private func icone(_ nom: String, actif: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: nom).font(.body.weight(.semibold))
                .foregroundStyle(actif ? Neutre.encreDouce : Neutre.encreEteinte.opacity(0.4))
                .frame(width: Grille.cible, height: Grille.cible)
        }
        .disabled(!actif)
    }
}

extension Etape.Genre {
    /// SF Symbol du genre.
    var symbole: String {
        switch self {
        case .fondu: return "circle.lefthalf.filled"
        case .pulsation: return "waveform.path"
        case .maintien: return "pause.fill"
        case .animation: return "sparkles"
        case .extinction: return "power"
        case .retour: return "arrow.uturn.backward"
        }
    }
}
#endif
