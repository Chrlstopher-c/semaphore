import Foundation

/// Composition de l'URL du canal de contrôle à partir de ce que Bonjour rend.
///
/// `☠` Une adresse résolue par Bonjour porte souvent un identifiant de zone :
/// `192.168.1.10%en0`. Tel quel, ce texte ne fait pas une URL valide, et le PC
/// découvert devient injoignable alors qu'il répond parfaitement. Mesuré le
/// 18/09/2026 sur l'iPhone de Chris — le PC apparaissait dans la liste, et le
/// toucher renvoyait « adresse résolue illisible ».
public enum AdresseUrl {

    /// Assemble `ws://hôte:port` en donnant à l'hôte la forme qu'une URL exige.
    public static func canal(hote: String, port: UInt16) -> URL? {
        URL(string: "ws://\(hotePourUrl(hote)):\(port)")
    }

    /// Met l'hôte en forme selon sa famille.
    ///
    /// Une IPv4 n'a que faire d'une zone : elle est routable telle quelle, on
    /// coupe le suffixe. Une IPv6 en a besoin — sans zone, une adresse de lien
    /// local ne mène nulle part — mais l'URL veut des crochets et un pourcent
    /// échappé.
    public static func hotePourUrl(_ hote: String) -> String {
        let nu = hote.hasPrefix("[") && hote.hasSuffix("]")
            ? String(hote.dropFirst().dropLast())
            : hote
        guard nu.contains(":") else {
            return String(nu.split(separator: "%", maxSplits: 1).first ?? "")
        }
        return "[\(nu.replacingOccurrences(of: "%", with: "%25"))]"
    }
}
