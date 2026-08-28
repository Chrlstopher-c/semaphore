import Foundation

/// La journalisation du noyau. Une seule porte, pour que l'app n'ait jamais à
/// choisir entre `print` et rien — et pour qu'un échec réseau laisse une trace
/// lisible dans la console Xcode/`idevicesyslog` sans dépendance externe.
///
/// `☠` Toute fonction qui touche le réseau, le disque ou un décodage attrape et
/// journalise. Une exception avalée sans trace est du code mort en puissance.
public enum Journal {
    /// Un échec attendu et absorbé : requête ratée, décodage impossible, fichier
    /// illisible. L'appelant retombe sur un état sûr, mais la cause reste écrite.
    public static func echec(_ message: String) {
        ecrire("✗", message)
    }

    /// Un fait notable du déroulé normal : flux ouvert, flux clos, relais changé.
    public static func note(_ message: String) {
        ecrire("·", message)
    }

    private static func ecrire(_ marque: String, _ message: String) {
        print("[EchoHub] \(marque) \(message)")
    }
}
