#if canImport(SwiftUI)
import SwiftUI
import Vigie
import VigieNoyau

/// Point d'entrée du centre de contrôle.
///
/// Il fait trois choses, héritées de Vigie, et il ne doit jamais en faire
/// plus : installer le délégué d'application (les rappels de notification et
/// l'enregistrement des tâches de fond n'arrivent pas par SwiftUI), construire
/// le câblage une seule fois, et poser le pupitre.
///
/// Le délégué est celui de Vigie parce que c'est lui qui porte le système de
/// veille — session audio, relais de localisation, réveils de fond. Ce système
/// tient désormais le processus entier en vie, donc aussi le monde Machine :
/// une génération ou un téléchargement de modèle survivent à l'écran éteint.
@main
struct EchoApp: App {
    @UIApplicationDelegateAdaptor(Vigie.DelegueApplication.self) private var delegue

    /// `@State` et pas une variable calculée : le câblage détient la session
    /// HTTP, le miroir et la minuterie. Le reconstruire à chaque évaluation de
    /// `body` rouvrirait une session par recomposition.
    @State private var cablage = Vigie.Cablage()

    init() {
        Trace.seuil = .info
    }

    var body: some Scene {
        WindowGroup {
            Pupitre()
                .cable(cablage)
        }
    }
}
#endif
