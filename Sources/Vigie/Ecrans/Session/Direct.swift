// Ce qui s'écrit maintenant au bas du fil, comme l'appli Claude iOS : l'étincelle de Claude qui respire tant qu'il
// travaille (avec « Réflexion… » / « Claude travaille… » en reflet tant qu'aucun texte n'est là), puis le texte qui
// s'écrit mot à mot à rythme régulier, sa fin en fondu. L'étincelle reste sous le texte jusqu'à la fin du tour.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

/// Réflexion, texte en direct, étincelle de travail, tâches de fond. `attente` : un message vient de partir et
/// le statut de la session ne l'a pas encore dit (l'étincelle apparaît dès l'envoi, pas une seconde après).
struct DirectVue: View {
    @Environment(ModeleRelais.self) private var modele
    let id: String
    let statut: StatutSession
    let attente: Bool
    let taches: Int
    let ouvrirTaches: () -> Void

    var body: some View {
        let texte = modele.enEcriture[id] ?? ""
        let reflexion = modele.reflexionEnCours[id] ?? ""
        let travaille = statut.enActivite || attente || !texte.isEmpty
        VStack(alignment: .leading, spacing: 14) {
            if !reflexion.isEmpty && texte.isEmpty {
                Text(reflexion.suffix(280)).font(Q.detail).italic().foregroundStyle(Q.tertiaire).lineLimit(4)
                    .transition(.opacity)
            }
            if !texte.isEmpty { TexteDirect(cible: texte).transition(.identity) }
            if travaille {
                HStack(spacing: 10) {
                    Etincelle().frame(width: 22, height: 22)
                    if texte.isEmpty { LibelleScintillant(texte: libelle(reflexion: !reflexion.isEmpty)) }
                }
                .transition(.opacity)
            }
            if taches > 0 {
                Button(action: ouvrirTaches) {
                    Text(taches > 1 ? "\(taches) tâches en cours" : "1 tâche en cours")
                        .font(Q.rangee).foregroundStyle(Q.lien)
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: travaille)
        .animation(.easeOut(duration: 0.25), value: texte.isEmpty)
    }

    private func libelle(reflexion: Bool) -> String {
        if statut == .compaction { return "Compaction du contexte…" }
        return reflexion ? "Réflexion…" : "Claude travaille…"
    }
}

/// Le texte reçu, révélé `RythmeDirect.cadence` fois par seconde : mots entiers, débit régulier même quand le réseau
/// livre par paquets, retard résorbé en douceur. Le texte complet reste dans le modèle ; seule la vue temporise.
private struct TexteDirect: View {
    let cible: String
    @State private var caracteres: [Character] = []
    @State private var affiches = 0

    var body: some View {
        MarkdownDirect(source: String(caracteres.prefix(affiches)))
            .onChange(of: cible, initial: true) { _, nouveau in
                let suite = Array(nouveau)
                affiches = RythmeDirect.conserve(affiches: affiches, ancien: caracteres, nouveau: suite)
                caracteres = suite
            }
            .task {
                let pas = Duration.milliseconds(1000 / RythmeDirect.cadence)
                while !Task.isCancelled {
                    try? await Task.sleep(for: pas)
                    let suivant = RythmeDirect.suivant(affiches: affiches, dans: caracteres)
                    if suivant != affiches { affiches = suivant }
                }
            }
    }
}

/// L'étincelle de Claude (orange #D97757) : douze rayons inégaux qui respirent en décalé et tournent lentement.
/// Dessinée au Canvas à chaque image (rien d'autre n'est recalculé) ; figée si « Réduire les animations ».
struct Etincelle: View {
    @Environment(\.accessibilityReduceMotion) private var reduire
    private static let longueurs: [Double] = [1, 0.78, 0.92, 0.7, 0.97, 0.8, 1, 0.74, 0.9, 0.72, 0.95, 0.82]
    private static let orange = Color(hex: 0xD97757)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduire)) { contexte in
            let t = reduire ? 0 : contexte.date.timeIntervalSinceReferenceDate
            Canvas { ctx, taille in dessiner(&ctx, taille, t) }
        }
        .accessibilityLabel("Claude travaille")
    }

    private func dessiner(_ ctx: inout GraphicsContext, _ taille: CGSize, _ t: Double) {
        let centre = CGPoint(x: taille.width / 2, y: taille.height / 2)
        let rayon = min(taille.width, taille.height) / 2
        let rotation = t * 0.35
        var trace = Path()
        for (i, longueur) in Self.longueurs.enumerated() {
            let angle = rotation + Double(i) * .pi / 6
            let souffle = 0.72 + 0.28 * sin(t * 2.4 + Double(i) * 0.95)
            let fin = rayon * longueur * souffle
            let debut = rayon * 0.16
            trace.move(to: CGPoint(x: centre.x + cos(angle) * debut, y: centre.y + sin(angle) * debut))
            trace.addLine(to: CGPoint(x: centre.x + cos(angle) * fin, y: centre.y + sin(angle) * fin))
        }
        ctx.stroke(trace, with: .color(Self.orange), style: StrokeStyle(lineWidth: rayon * 0.2, lineCap: .round))
    }
}

/// Un libellé gris traversé d'un reflet clair qui balaie de gauche à droite (1,6 s), comme l'appli Claude.
struct LibelleScintillant: View {
    let texte: String
    @Environment(\.accessibilityReduceMotion) private var reduire

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduire)) { contexte in
            let periode = 1.6
            let p = contexte.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: periode) / periode
            let x = p * 1.8 - 0.4
            Text(texte).font(Q.detail).foregroundStyle(Q.tertiaire)
                .overlay {
                    LinearGradient(stops: [.init(color: .clear, location: 0),
                                           .init(color: Q.texte.opacity(reduire ? 0 : 0.85), location: 0.5),
                                           .init(color: .clear, location: 1)],
                                   startPoint: UnitPoint(x: x - 0.25, y: 0.5),
                                   endPoint: UnitPoint(x: x + 0.25, y: 0.5))
                        .mask(Text(texte).font(Q.detail))
                }
        }
    }
}
#endif
