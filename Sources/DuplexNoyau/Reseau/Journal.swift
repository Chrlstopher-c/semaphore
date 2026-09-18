import Foundation

/// La journalisation du monde Duplex. Une seule porte, pour qu'un échec réseau
/// ou audio laisse une trace lisible dans `idevicesyslog` — la seule fenêtre de
/// débogage sur un appareil sideloadé, sans Mac ni simulateur.
///
/// `☠` Toute fonction qui touche le réseau, le disque ou la carte son attrape et
/// journalise ici. Une exception avalée sans trace est du code mort en
/// puissance. Type homonyme des `Journal` de Saily et d'EchoHub, sans collision :
/// les trois vivent dans des modules distincts, jamais importés ensemble.
///
/// `☠` RIEN ne se journalise depuis le rappel de rendu audio : un `print` y
/// prend un verrou et produit exactement le trou qu'on cherche à éviter. Les
/// famines et les débordements se COMPTENT dans `TamponAudio` et se lisent
/// depuis l'écran, à la cadence de l'affichage.
public enum Journal {
    /// Un échec attendu et absorbé : socket tombé, paquet illisible.
    public static func echec(_ message: String) {
        ecrire("✗", message)
    }

    /// Un fait notable du déroulé normal : PC trouvé, flux démarré, flux arrêté.
    public static func note(_ message: String) {
        ecrire("·", message)
    }

    private static func ecrire(_ marque: String, _ message: String) {
        print("[Duplex] \(marque) \(message)")
    }
}
