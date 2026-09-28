import Foundation

// Mise en forme pour l'écran : tokens, octets, durées. Espaces insécables avant les unités.

public enum Format {
    public static func tokens(_ n: Int) -> String {
        if n >= 1_000_000 { return decimal(Double(n) / 1_000_000) + "\u{00a0}M" }
        if n >= 1_000 { return "\(Int((Double(n) / 1_000).rounded()))\u{00a0}k" }
        return "\(n)"
    }

    public static func octets(_ n: Double) -> String {
        let go = n / 1_073_741_824
        return (go >= 100 ? "\(Int(go.rounded()))" : decimal(go)) + "\u{00a0}Go"
    }

    public static func duree(secondes: Int) -> String {
        let j = secondes / 86_400, h = (secondes % 86_400) / 3600, m = (secondes % 3600) / 60
        if j > 0 { return "\(j)\u{00a0}j \(h)\u{00a0}h" }
        if h > 0 { return "\(h)\u{00a0}h \(m)\u{00a0}min" }
        return "\(m)\u{00a0}min"
    }

    public static func depuis(_ iso: String, maintenant: Date = Date()) -> String {
        guard let date = dateISO(iso) else { return "" }
        let s = max(0, Int(maintenant.timeIntervalSince(date)))
        if s < 45 { return "à l’instant" }
        if s < 3600 { return "il y a \(Int((Double(s) / 60).rounded()))\u{00a0}min" }
        if s < 86_400 { return "il y a \(Int((Double(s) / 3600).rounded()))\u{00a0}h" }
        return "il y a \(Int((Double(s) / 86_400).rounded()))\u{00a0}j"
    }

    /// Les dates du relais sont en ISO 8601 avec millisecondes (`toISOString()` de JavaScript).
    public static func dateISO(_ iso: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }

    private static func decimal(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }
}
