// Calculs purs des routines : durées lisibles, jours, prochain passage, identifiants, et la lumière que produit
// chaque étape (pour peindre la bande d'instructions). Testés dans LueurNoyauTests.
import Foundation

public enum Horaire {
    public static let initialesJours = ["L", "M", "M", "J", "V", "S", "D"]
    public static let nomsJours = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
    public static let tousLesJours = [1, 2, 3, 4, 5, 6, 7]
    public static let semaine = [1, 2, 3, 4, 5]
    public static let weekEnd = [6, 7]

    public static func total(_ etapes: [Etape]) -> Double {
        etapes.reduce(0) { $0 + ($1.duree ?? 0) }
    }

    /// « 4,8 s », « 45 s », « 6 min 30 s », « 1 h 05 ».
    public static func duree(_ secondes: Double) -> String {
        if secondes < 10, secondes.rounded() != secondes {
            return String(format: "%.1f s", secondes).replacingOccurrences(of: ".", with: ",")
        }
        let s = Int(secondes.rounded())
        if s < 60 { return "\(s) s" }
        let h = s / 3600, m = s % 3600 / 60, r = s % 60
        if h > 0 { return String(format: "%d h %02d", h, m) }
        return r > 0 ? "\(m) min \(r) s" : "\(m) min"
    }

    public static func jours(_ jours: [Int]) -> String {
        let tries = Array(Set(jours)).sorted()
        switch tries {
        case tousLesJours: return "Tous les jours"
        case semaine: return "En semaine"
        case weekEnd: return "Le week-end"
        case []: return "Aucun jour"
        default: return tries.map { String(nomsJours[$0 - 1].prefix(3)) + "." }.joined(separator: " ")
        }
    }

    /// Jour ISO (1 = lundi) d'une date.
    public static func jourIso(_ date: Date, calendrier: Calendar = .current) -> Int {
        (calendrier.component(.weekday, from: date) + 5) % 7 + 1
    }

    /// « Ce soir 21:00 », « Aujourd'hui 12:00 », « Demain 07:00 », « Lundi 14:00 ».
    public static func prochain(_ iso: String?, maintenant: Date = Date(), calendrier: Calendar = .current) -> String? {
        guard let iso, let date = lire(iso, calendrier: calendrier) else { return nil }
        let ecart = calendrier.dateComponents([.day], from: calendrier.startOfDay(for: maintenant),
                                              to: calendrier.startOfDay(for: date)).day ?? 0
        let h = calendrier.component(.hour, from: date), m = calendrier.component(.minute, from: date)
        let heure = String(format: "%02d:%02d", h, m)
        switch ecart {
        case 0: return (h >= 18 ? "Ce soir " : "Aujourd'hui ") + heure
        case 1: return "Demain " + heure
        default:
            let nom = nomsJours[jourIso(date, calendrier: calendrier) - 1]
            return nom.prefix(1).uppercased() + nom.dropFirst() + " " + heure
        }
    }

    private static func lire(_ iso: String, calendrier: Calendar) -> Date? {
        let morceaux = iso.split(whereSeparator: { "-T:".contains($0) }).compactMap { Int($0) }
        guard morceaux.count >= 5 else { return nil }
        return calendrier.date(from: DateComponents(year: morceaux[0], month: morceaux[1], day: morceaux[2],
                                                    hour: morceaux[3], minute: morceaux[4]))
    }

    public static func minutes(_ hhmm: String) -> Int {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        return p.count == 2 ? p[0] * 60 + p[1] : 0
    }

    public static func hhmm(_ minutes: Int) -> String {
        let m = (minutes % 1440 + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    /// Id du serveur (minuscules, chiffres, tirets, 40 max) tiré d'un nom, unique parmi `pris`.
    public static func identifiant(_ nom: String, pris: [String]) -> String {
        let plie = nom.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
        var base = String(plie.lowercased().map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "-" })
        while base.contains("--") { base = base.replacingOccurrences(of: "--", with: "-") }
        base = String(base.trimmingCharacters(in: CharacterSet(charactersIn: "-")).prefix(32))
        if base.isEmpty { base = "routine" }
        var id = base, n = 2
        while pris.contains(id) { id = "\(base)-\(n)"; n += 1 }
        return id
    }

    // MARK: - Lumière de chaque étape

    /// La lumière au début et à la fin d'une étape (hexa éclairci pour l'écran), et si une animation tourne.
    public struct Rendu: Equatable, Sendable {
        public let debut: String
        public let fin: String
        public let creux: String
        public let animee: Bool
    }

    public static let eteint = "#17151f"

    /// Couleur affichée pour une lumière à `niveau` % : jamais noire tant qu'elle brille (lisible à l'écran).
    public static func lumiere(_ hexa: String, niveau: Int) -> String {
        guard let n = Nuance(hexa: hexa), niveau > 0 else { return eteint }
        let f = 0.32 + 0.68 * Double(min(niveau, 100)) / 100
        func c(_ v: UInt8) -> UInt8 { UInt8((Double(v) * f).rounded()) }
        return Nuance(rouge: c(n.rouge), vert: c(n.vert), bleu: c(n.bleu)).hexa
    }

    public static func rendu(_ etapes: [Etape]) -> [Rendu] {
        var avant = eteint, animee = false
        return etapes.map { e in
            var fin = avant
            switch e.genre {
            case .fondu: fin = lumiere(e.couleur ?? "#ffffff", niveau: e.intensite ?? 100)
            case .pulsation: fin = lumiere(e.couleur ?? "#ffffff", niveau: e.pic ?? 100)
            case .extinction: fin = eteint
            case .retour: fin = "#3a3550"
            case .maintien, .animation: break
            }
            if e.genre == .animation { animee = true } else if e.genre != .maintien { animee = false }
            let creux = e.genre == .pulsation ? lumiere(e.couleur ?? "#ffffff", niveau: e.creux ?? 0) : fin
            defer { avant = fin }
            return Rendu(debut: avant, fin: fin, creux: creux, animee: animee)
        }
    }

    /// L'aperçu d'« Essayer » : les mêmes étapes, ramenées à `cible` secondes au plus (durées et ondes à la même
    /// échelle, une onde jamais sous 0,4 s — le minimum du Pi). Une routine de 6 min se juge alors en 15 s.
    public static func acceleree(_ etapes: [Etape], cible: Double = 15) -> [Etape] {
        let t = total(etapes)
        guard t > cible else { return etapes }
        let k = cible / t
        return etapes.map { e in
            var a = e
            if let d = e.duree { a.duree = (d * k * 10).rounded() / 10 }
            if let o = e.onde { a.onde = max(0.4, (o * k * 10).rounded() / 10) }
            return a
        }
    }

    /// Les couleurs qui résument une routine (pastille, bloc de la journée).
    public static func palette(_ etapes: [Etape]) -> [String] {
        var vues: [String] = []
        for c in etapes.compactMap(\.couleur) where !vues.contains(c) { vues.append(c) }
        return vues.isEmpty ? ["#5a5470"] : vues
    }
}
