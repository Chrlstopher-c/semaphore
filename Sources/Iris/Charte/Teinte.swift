// Le seul jeton de couleur propre à Iris : son accent. Le reste vient du socle
// `Systeme`. Choix et emplois : `CHARTE.md`.
#if canImport(SwiftUI)
import SwiftUI
import Systeme

public enum Teinte {
    /// Bleu iris — le geste à faire, et la liaison vivante.
    public static let accent = Color(socle: 0x4F9DFF)
    /// L'accent enfoncé, dérivé.
    public static let accentPresse = Color(socle: 0x4F9DFF).mele(vers: .black, part: 0.22)
    /// L'encre posée sur un aplat d'accent : le fond sombre (le blanc n'y tient que 2,6:1).
    public static let encreSurAccent = Neutre.fond
}

extension View {
    /// Tête de rubrique : capitales espacées, éteintes (même geste que Duplex,
    /// dupliqué exprès : les chartes des mondes ne se partagent pas).
    func rubrique() -> some View {
        font(Voix.legende)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Neutre.encreEteinte)
    }
}

/// Les dimensions propres au monde — des tailles de composant, pas des espacements.
enum Trame {
    /// L'aperçu a le format de la webcam des PC : ce qu'on voit est ce qu'ils reçoivent.
    static let ratioApercu: CGFloat = 16 / 9
    /// Le bouton Filmer : au-dessus de la cible tactile, c'est le geste du monde.
    static let bouton: CGFloat = 52
    /// Le point d'état d'un PC.
    static let point: CGFloat = 8
    /// La colonne des libellés de réglage : « Définition », le plus long, y tient en Dynamic Type par défaut.
    static let libelleReglage: CGFloat = 88
}
#endif
