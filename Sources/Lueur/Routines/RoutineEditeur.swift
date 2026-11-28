// Édition d'une routine en feuille (création si `routine` est nul) : quand (nom, heure, jours), puis quoi (la bande des
// instructions et les réglages de l'étape touchée). Rien n'est écrit sur le Pi avant « Enregistrer » ; « Essayer » joue
// la version en cours plafonnée à 30 %.
#if canImport(SwiftUI) && canImport(UIKit)
import LueurNoyau
import SwiftUI
import Systeme

struct RoutineEditeur: View {
    let routine: Routine?
    @Environment(Lampe.self) private var lampe
    @Environment(\.dismiss) private var fermer
    private let programme = Programme.partage
    @State private var nom = ""
    @State private var heure = Date()
    @State private var jours = Horaire.tousLesJours
    @State private var etapes: [Etape] = []
    @State private var choisie = 0
    @State private var modifie = false
    @State private var envoi = false
    @State private var erreur: String?
    @State private var confirmerSuppression = false
    @State private var confirmerAbandon = false
    @State private var pret = false
    @State private var essaye = false

    private var valide: Bool { !nom.trimmingCharacters(in: .whitespaces).isEmpty && !jours.isEmpty && !etapes.isEmpty }
    private var essaiEnCours: Bool { lampe.etat?.lecture?.id == Programme.essai }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Grille.section) {
                    quand
                    quoi
                    actions
                }
                .padding(.horizontal, Grille.ecran)
                .padding(.vertical, Grille.groupe)
            }
            .background(Neutre.fond.ignoresSafeArea())
            .navigationTitle(routine == nil ? "Nouvelle routine" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { if modifie { confirmerAbandon = true } else { quitter() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(envoi ? "…" : "Enregistrer") { Task { await enregistrer() } }
                        .bold().disabled(!valide || envoi)
                }
            }
            .confirmationDialog("Abandonner les modifications ?", isPresented: $confirmerAbandon, titleVisibility: .visible) {
                Button("Abandonner", role: .destructive) { quitter() }
            }
        }
        .tint(Teinte.accent)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(modifie)
        .onAppear(perform: remplir)
        .onChange(of: nom) { if pret { modifie = true } }
        .onChange(of: heure) { if pret { modifie = true } }
        .onChange(of: jours) { if pret { modifie = true } }
        .onChange(of: etapes) { if pret { modifie = true } }
        .sensoryFeedback(Toucher.selection, trigger: choisie)
    }

    // MARK: - Quand

    private var quand: some View {
        VStack(alignment: .leading, spacing: Grille.element) {
            TextField("Nom de la routine", text: $nom)
                .font(Voix.entete)
                .padding(Grille.element)
                .background(Neutre.surface, in: .rect(cornerRadius: Rayon.controle, style: .continuous))
            HStack {
                Text("Heure de début").font(Voix.corps).foregroundStyle(Neutre.encre)
                Spacer()
                DatePicker("", selection: $heure, displayedComponents: .hourAndMinute).labelsHidden()
            }
            .padding(.horizontal, Grille.element).frame(minHeight: Grille.cible)
            .background(Neutre.surface, in: .rect(cornerRadius: Rayon.controle, style: .continuous))
            HStack(spacing: Grille.fin) {
                ForEach(1...7, id: \.self) { j in
                    let on = jours.contains(j)
                    Button { basculer(j) } label: {
                        Text(Horaire.initialesJours[j - 1]).font(Voix.entete)
                            .foregroundStyle(on ? Neutre.fond : Neutre.encreDouce)
                            .frame(maxWidth: .infinity, minHeight: Grille.cible)
                            .background(on ? Teinte.accent : Neutre.surface, in: .circle)
                    }
                    .buttonStyle(Presse())
                }
            }
            .sensoryFeedback(Toucher.selection, trigger: jours)
            HStack(spacing: Grille.serre) {
                prereglage("Tous", Horaire.tousLesJours)
                prereglage("Semaine", Horaire.semaine)
                prereglage("Week-end", Horaire.weekEnd)
                Spacer()
                Text(fourchette).font(Voix.note).foregroundStyle(Neutre.encreEteinte)
            }
        }
    }

    private func prereglage(_ titre: String, _ valeur: [Int]) -> some View {
        let on = jours.sorted() == valeur
        return Button { jours = valeur } label: {
            Text(titre).font(Voix.mention)
                .foregroundStyle(on ? Neutre.encre : Neutre.encreEteinte)
                .padding(.horizontal, Grille.element).frame(minHeight: 32)
                .background(on ? Neutre.surfaceHaute : .clear, in: .capsule)
        }
        .buttonStyle(Presse())
    }

    private var fourchette: String {
        let debut = minutes(heure)
        return "\(Horaire.hhmm(debut)) → \(Horaire.hhmm(debut + Int(Horaire.total(etapes) / 60)))"
    }

    // MARK: - Quoi

    private var quoi: some View {
        VStack(alignment: .leading, spacing: Grille.element) {
            HStack(alignment: .firstTextBaseline) {
                Text("Instructions").rubrique()
                Spacer()
                Text("\(etapes.count) étape\(etapes.count > 1 ? "s" : "") · \(Horaire.duree(Horaire.total(etapes)))")
                    .font(Voix.mesure).foregroundStyle(Neutre.encreDouce)
            }
            BandeEtapes(etapes: etapes, choisie: $choisie) { ajouter() }
            if etapes.indices.contains(choisie) {
                ReglagesEtape(etape: etapeChoisie, rang: choisie, nombre: etapes.count,
                              deplacer: deplacer, retirer: retirer, precedente: choisie > 0 ? etapes[choisie - 1] : nil)
                    .id(choisie)
                    .transition(.opacity)
            }
        }
        .animation(Mouvement.normal, value: choisie)
    }

    /// `$etapes[choisie]` planterait si l'étape disparaît pendant que ses réglages se démontent : liaison bornée.
    private var etapeChoisie: Binding<Etape> {
        let i = choisie
        return Binding(get: { etapes.indices.contains(i) ? etapes[i] : Etape.neuve(.fondu) },
                       set: { if etapes.indices.contains(i) { etapes[i] = $0 } })
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: Grille.element) {
            if let erreur {
                Label(erreur, systemImage: "exclamationmark.triangle.fill")
                    .font(Voix.mention).foregroundStyle(Semantique.panne)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { Task { await essayer() } } label: {
                Label(essaiEnCours ? "Arrêter l'essai" : "Essayer sur le ruban (30 %)",
                      systemImage: essaiEnCours ? "stop.fill" : "play.fill")
                    .font(Voix.entete).frame(maxWidth: .infinity, minHeight: Grille.cible)
                    .foregroundStyle(Neutre.encre)
                    .background(Neutre.surfaceHaute, in: .rect(cornerRadius: Rayon.controle, style: .continuous))
            }
            .buttonStyle(Presse())
            .disabled(etapes.isEmpty)
            .sensoryFeedback(Toucher.engage, trigger: essaiEnCours)
            if routine != nil {
                Button(role: .destructive) { confirmerSuppression = true } label: {
                    Label("Supprimer la routine", systemImage: "trash")
                        .font(Voix.entete).frame(maxWidth: .infinity, minHeight: Grille.cible)
                }
                .confirmationDialog("Supprimer « \(nom) » ? Elle ne se lancera plus.",
                                    isPresented: $confirmerSuppression, titleVisibility: .visible) {
                    Button("Supprimer", role: .destructive) { Task { await supprimer() } }
                }
            }
        }
    }

    // MARK: - Logique

    private func remplir() {
        if let routine {
            nom = routine.nom
            heure = date(Horaire.minutes(routine.heure))
            jours = routine.jours
            etapes = programme.etapes(de: routine).map(\.propre)
            if etapes.isEmpty { etapes = [Etape.neuve(.fondu)] }
        } else {
            nom = "Nouvelle routine"
            heure = date((Calendar.current.component(.hour, from: Date()) + 1) % 24 * 60)
            etapes = [Etape.neuve(.fondu), Etape.neuve(.maintien), Etape.neuve(.extinction)]
        }
        DispatchQueue.main.async { pret = true }
    }

    private func minutes(_ d: Date) -> Int {
        let c = Calendar.current
        return c.component(.hour, from: d) * 60 + c.component(.minute, from: d)
    }

    private func date(_ minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private func basculer(_ j: Int) {
        if jours.contains(j) { jours.removeAll { $0 == j } } else { jours = (jours + [j]).sorted() }
    }

    private func ajouter() {
        let i = min(choisie + 1, etapes.count)
        etapes.insert(Etape.neuve(.fondu, apres: etapes.indices.contains(choisie) ? etapes[choisie] : nil), at: i)
        choisie = i
    }

    private func deplacer(_ sens: Int) {
        let j = choisie + sens
        guard etapes.indices.contains(j) else { return }
        etapes.swapAt(choisie, j)
        choisie = j
    }

    private func retirer() {
        guard etapes.count > 1 else { return }
        etapes.remove(at: choisie)
        choisie = min(choisie, etapes.count - 1)
    }

    private func enregistrer() async {
        envoi = true
        defer { envoi = false }
        let pris = programme.routines.map(\.id)
        let id = routine?.id ?? Horaire.identifiant(nom, pris: pris)
        // chaque routine garde ses propres instructions : un scénario partagé est dédoublé
        let partage = routine.map { r in programme.routines.contains { $0.id != r.id && $0.scenario == r.scenario } } ?? true
        let scenario = routine != nil && !partage ? routine!.scenario
            : Horaire.identifiant(id, pris: Array(programme.scenarios.keys))
        let r = Routine(id: id, nom: nom.trimmingCharacters(in: .whitespaces), heure: Horaire.hhmm(minutes(heure)),
                        scenario: scenario, jours: jours, active: routine?.active ?? true)
        if let message = await programme.enregistrer(r, etapes: etapes) { erreur = message; return }
        quitter()
    }

    private func supprimer() async {
        guard let routine else { return }
        if let message = await programme.supprimer(routine) { erreur = message; return }
        quitter()
    }

    private func essayer() async {
        if essaiEnCours {
            await programme.arreter()
        } else {
            essaye = true
            if let message = await programme.essayer(etapes) { erreur = message }
        }
        lampe.releverMaintenant()
    }

    private func quitter() {
        let enCours = essaiEnCours, aOublier = essaye
        Task {
            if enCours { await programme.arreter() }
            if aOublier { await programme.oublierEssai() }
        }
        fermer()
    }
}
#endif
