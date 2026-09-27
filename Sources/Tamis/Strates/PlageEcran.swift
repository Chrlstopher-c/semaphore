// Le tamisage par période : deux bornes, quelques raccourcis, les natures à
// retenir. Le résultat se compte en direct — on voit ce qu'on s'apprête à revoir
// avant de le revoir.
#if canImport(SwiftUI) && canImport(Photos)
import SwiftUI
import Systeme
import TamisNoyau

struct PlageEcran: View {
    @Environment(Atelier.self) private var atelier
    @State private var debut = Calendar.current.date(byAdding: .year, value: -10, to: .now) ?? .now
    @State private var fin = Calendar.current.date(byAdding: .year, value: -3, to: .now) ?? .now
    @State private var nature: Nature = .tout
    @State private var epargnerFavoris = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Grille.section) {
                raccourcis
                bornes
                filtres
                resultat
            }
            .padding(.horizontal, Grille.ecran)
            .padding(.vertical, Grille.groupe)
        }
        .pageTamis("Période")
        .sensoryFeedback(Toucher.selection, trigger: nature)
    }

    private var tamisage: Tamisage {
        Tamisage(plage: PlageDates(debut: debut, fin: fin), medias: nature.medias,
                 traits: nature.traits, epargnerFavoris: epargnerFavoris)
    }

    private var raccourcis: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            Text("Raccourcis").rubrique()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Grille.serre) {
                    ForEach([1, 3, 5, 10], id: \.self) { annees in
                        Pastille("Plus de \(annees) an\(annees > 1 ? "s" : "")") { plusDe(annees) }
                    }
                }
            }
        }
    }

    private func plusDe(_ annees: Int) {
        debut = atelier.cliches.first(where: { $0.date != nil })?.date ?? .distantPast
        fin = Calendar.current.date(byAdding: .year, value: -annees, to: .now) ?? .now
    }

    private var bornes: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            Text("Période").rubrique()
            Panneau {
                VStack(spacing: Grille.element) {
                    DatePicker("Du", selection: $debut, in: ...fin, displayedComponents: .date)
                    Divider().overlay(Neutre.trait)
                    DatePicker("Au", selection: $fin, in: debut..., displayedComponents: .date)
                }
                .font(Voix.corps)
                .foregroundStyle(Neutre.encre)
            }
        }
    }

    private var filtres: some View {
        VStack(alignment: .leading, spacing: Grille.serre) {
            Text("Nature").rubrique()
            Picker("Nature", selection: $nature) {
                ForEach(Nature.allCases, id: \.self) { Text($0.libelle).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Épargner les favoris", isOn: $epargnerFavoris)
                .font(Voix.corps).foregroundStyle(Neutre.encre)
                .padding(.top, Grille.serre)
        }
    }

    private var resultat: some View {
        let retenus = tamisage.passer(atelier.cliches)
        return NavigationLink(value: Destination.grille(titre: "Période", ids: retenus.map(\.id))) {
            Text("Voir \(retenus.count.formatted()) éléments · \(Octets.lisible(retenus.poidsTotal))")
                .contentTransition(.numericText())
        }
        .buttonStyle(.engage)
        .disabled(retenus.isEmpty)
    }
}

/// Les natures proposées au tamisage, en une rangée segmentée.
enum Nature: CaseIterable, Hashable {
    case tout, photos, videos, captures

    var libelle: String {
        switch self {
        case .tout: return "Tout"
        case .photos: return "Photos"
        case .videos: return "Vidéos"
        case .captures: return "Captures"
        }
    }

    var medias: Set<Media> {
        switch self {
        case .photos, .captures: return [.photo]
        case .videos: return [.video]
        case .tout: return []
        }
    }

    var traits: Set<Trait> { self == .captures ? [.capture] : [] }
}

/// Un raccourci : capsule éteinte, accent au toucher.
struct Pastille: View {
    private let libelle: String
    private let action: () -> Void

    init(_ libelle: String, action: @escaping () -> Void) {
        self.libelle = libelle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(libelle)
                .font(Voix.mention)
                .foregroundStyle(Neutre.encre)
                .padding(.horizontal, Grille.element)
                .frame(minHeight: Grille.cible)
                .background(Neutre.surface, in: .capsule)
                .lisere(Grille.cible / 2)
        }
        .buttonStyle(.appui)
    }
}
#endif
