// Routines du ruban : la journée choisie en frise (0 h → 24 h, un bloc par routine, l'heure qu'il est), puis une carte
// par routine (heure, jours, durée, prochain passage, marche/arrêt). Toucher = l'éditer en feuille ; « + » = en créer une.
#if canImport(SwiftUI) && canImport(UIKit)
import LueurNoyau
import SwiftUI
import Systeme

/// Ce que la feuille d'édition ouvre : une routine existante, ou une nouvelle.
struct Edition: Identifiable {
    let routine: Routine?
    var id: String { routine?.id ?? "nouvelle" }
}

struct RoutinesVue: View {
    @Environment(Lampe.self) private var lampe
    private let programme = Programme.partage
    @State private var jour = Horaire.jourIso(Date())
    @State private var edition: Edition?

    var body: some View {
        VStack(alignment: .leading, spacing: Grille.groupe) {
            journee
            VStack(spacing: Grille.element) {
                ForEach(Array(programme.triees.enumerated()), id: \.element.id) { rang, routine in
                    CarteRoutine(routine: routine, enCours: lampe.etat?.lecture?.id == routine.scenario) {
                        edition = Edition(routine: routine)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(Mouvement.cascade(rang), value: programme.charge)
                }
            }
            vide
            Button { edition = Edition(routine: nil) } label: {
                Label("Nouvelle routine", systemImage: "plus")
                    .font(Voix.entete)
                    .frame(maxWidth: .infinity, minHeight: Grille.cible)
                    .foregroundStyle(Neutre.fond)
                    .background(Teinte.accent, in: .rect(cornerRadius: Rayon.controle, style: .continuous))
            }
            .buttonStyle(Presse())
            .sensoryFeedback(Toucher.contact, trigger: edition?.id)
        }
        .task { await programme.charger() }
        .sheet(item: $edition) { e in
            RoutineEditeur(routine: e.routine).environment(lampe)
        }
    }

    // MARK: - La journée

    private var journee: some View {
        VStack(alignment: .leading, spacing: Grille.element) {
            HStack {
                Text(jour == Horaire.jourIso(Date()) ? "Aujourd'hui" : Horaire.nomsJours[jour - 1].capitalized)
                    .font(Voix.titreSection).foregroundStyle(Neutre.encre)
                Spacer()
            }
            HStack(spacing: 0) {
                ForEach(1...7, id: \.self) { j in
                    Button { jour = j } label: {
                        Text(Horaire.initialesJours[j - 1])
                            .font(Voix.mention)
                            .foregroundStyle(j == jour ? Neutre.encre : Neutre.encreEteinte)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(j == jour ? Neutre.surfaceHaute : .clear, in: .capsule)
                            .overlay(alignment: .bottom) {
                                if j == Horaire.jourIso(Date()) {
                                    Circle().fill(Teinte.accent).frame(width: 4, height: 4).offset(y: -3)
                                }
                            }
                    }
                    .buttonStyle(Presse())
                }
            }
            .sensoryFeedback(Toucher.selection, trigger: jour)
            Frise(routines: programme.triees.filter { $0.jours.contains(jour) }, programme: programme,
                  maintenant: jour == Horaire.jourIso(Date())) { edition = Edition(routine: $0) }
        }
        .padding(Grille.bloc)
        .background(Neutre.surface, in: .rect(cornerRadius: Rayon.carte, style: .continuous))
    }

    @ViewBuilder private var vide: some View {
        if programme.routines.isEmpty {
            VStack(spacing: Grille.serre) {
                Image(systemName: programme.charge ? "clock" : programme.panne != nil ? "wifi.slash" : "hourglass")
                    .font(.title2).foregroundStyle(Neutre.encreEteinte)
                Text(programme.charge ? "Aucune routine pour l'instant"
                     : programme.panne ?? "Chargement des routines…")
                    .font(Voix.mention).foregroundStyle(Neutre.encreDouce)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        }
    }
}

/// 0 h → 24 h : un bloc par routine (au moins 6 pt, sinon sa durée) et l'heure qu'il est. Les heures et les noms
/// sont sur les cartes : sur 335 pt, 12 h et 14 h se chevaucheraient.
private struct Frise: View {
    let routines: [Routine]
    let programme: Programme
    let maintenant: Bool
    let ouvrir: (Routine) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous)
                    .fill(Neutre.lumiereBasse).frame(height: 32).offset(y: 22)
                ForEach([6, 12, 18], id: \.self) { h in
                    Rectangle().fill(Neutre.trait).frame(width: 1, height: 32)
                        .offset(x: CGFloat(h) / 24 * w, y: 22)
                }
                ForEach(routines) { r in
                    bloc(r, largeur: w)
                }
                if maintenant {
                    TimelineView(.periodic(from: .now, by: 60)) { ctx in
                        let c = Calendar.current
                        let m = c.component(.hour, from: ctx.date) * 60 + c.component(.minute, from: ctx.date)
                        Capsule().fill(Neutre.encre).frame(width: 2, height: 40)
                            .offset(x: CGFloat(m) / 1440 * w - 1, y: 18)
                    }
                }
                ForEach([0, 6, 12, 18, 24], id: \.self) { h in
                    Text("\(h) h").font(Voix.mesure).foregroundStyle(Neutre.encreEteinte)
                        .fixedSize()
                        .frame(width: 40, alignment: h == 0 ? .leading : h == 24 ? .trailing : .center)
                        .offset(x: min(max(0, CGFloat(h) / 24 * w - 20), w - 40), y: 60)
                }
            }
        }
        .frame(height: 76)
    }

    private func bloc(_ r: Routine, largeur w: CGFloat) -> some View {
        let x = CGFloat(Horaire.minutes(r.heure)) / 1440 * w
        let l = max(6, CGFloat(programme.duree(de: r)) / 86400 * w)
        let pal = Horaire.palette(programme.etapes(de: r)).map(Color.init(hexa:))
        return Button { ouvrir(r) } label: {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: pal.count > 1 ? pal : pal + pal, startPoint: .leading, endPoint: .trailing))
                .frame(width: l, height: 24)
                .opacity(r.active ? 1 : 0.35)
                .padding(.horizontal, Grille.serre).padding(.vertical, Grille.serre)   // cible plus large que le trait
                .contentShape(.rect)
        }
        .buttonStyle(Presse())
        .offset(x: min(x, w - l) - Grille.serre, y: 18)
    }
}

private struct CarteRoutine: View {
    let routine: Routine
    let enCours: Bool
    let ouvrir: () -> Void
    private let programme = Programme.partage

    var body: some View {
        let pal = Horaire.palette(programme.etapes(de: routine)).map(Color.init(hexa:))
        HStack(spacing: Grille.element) {
            Button(action: ouvrir) {
                HStack(spacing: Grille.element) {
                    RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous)
                        .fill(LinearGradient(colors: pal.count > 1 ? pal : pal + pal, startPoint: .top, endPoint: .bottom))
                        .frame(width: Grille.cible, height: Grille.cible)
                        .overlay { if enCours { Image(systemName: "waveform").foregroundStyle(.white) } }
                        .opacity(routine.active ? 1 : 0.4)
                    VStack(alignment: .leading, spacing: Grille.fin) {
                        Text(routine.nom).font(Voix.entete)
                            .foregroundStyle(routine.active ? Neutre.encre : Neutre.encreDouce)
                        Text("\(routine.heure) · \(Horaire.jours(routine.jours)) · \(Horaire.duree(programme.duree(de: routine)))")
                            .font(Voix.note).foregroundStyle(Neutre.encreDouce)
                        Text(enCours ? "En cours" : routine.active ? Horaire.prochain(routine.prochain) ?? "" : "En pause")
                            .font(Voix.legende)
                            .foregroundStyle(enCours ? Semantique.ok : Neutre.encreEteinte)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(Presse())
            Toggle("", isOn: Binding(get: { routine.active }, set: { programme.basculer(routine, active: $0) }))
                .labelsHidden()
        }
        .padding(Grille.bloc)
        .background(Neutre.surface, in: .rect(cornerRadius: Rayon.carte, style: .continuous))
        .sensoryFeedback(Toucher.selection, trigger: routine.active)
    }
}

extension Color {
    init(hexa: String) {
        self.init(nuance: Nuance(hexa: hexa) ?? Nuance(rouge: 90, vert: 84, bleu: 112))
    }
}
#endif
