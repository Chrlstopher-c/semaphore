import Foundation

/// La journalisation du monde Saily. Une seule porte, pour qu'un échec réseau
/// ou disque laisse une trace lisible dans `idevicesyslog` sans dépendance
/// externe — la seule fenêtre de débogage sur un appareil sideloadé.
///
/// `☠` Toute fonction qui touche le réseau, le disque ou un décodage attrape et
/// journalise ici. Une exception avalée sans trace est du code mort en
/// puissance. Type homonyme du `Journal` d'EchoHub, sans collision : les deux
/// vivent dans des modules distincts, jamais importés ensemble.
public enum Journal {
    /// Un échec attendu et absorbé : requête ratée, décodage impossible.
    public static func echec(_ message: String) {
        ecrire("✗", message)
    }

    /// Un fait notable du déroulé normal : socket ouvert, socket clos, reconnexion.
    public static func note(_ message: String) {
        ecrire("·", message)
    }

    private static func ecrire(_ marque: String, _ message: String) {
        print("[Saily] \(marque) \(message)")
    }
}
