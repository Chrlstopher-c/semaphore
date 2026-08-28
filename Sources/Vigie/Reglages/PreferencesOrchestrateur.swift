// Préférences locales de composition d'un fil : modèle, effort, mode rapide,
// ultracode. Persistées ici, lues par le domaine `Fil` au moment d'ouvrir une
// nouvelle conversation — exactement le rôle de `prefs.model` dans la webapp
// (`localStorage`), jamais une écriture serveur : le catalogue (`GET /modeles`)
// ne connaît qu'un défaut GLOBAL, pas une préférence par opérateur.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

/// `☠` Portée VOLONTAIREMENT locale : côté harness, `model`/`effort`/`fastMode`/
/// `ultracode` sont des réglages DE SESSION, jamais persistés serveur (voir
/// `HarnessState.orchModel` côté pi-web — reconstruit à chaque rechargement).
/// Ce que Réglages fixe ici n'est donc qu'un DÉFAUT de confort pour le prochain
/// fil ouvert, pas une vérité que le serveur pourrait contredire.
public enum PreferencesOrchestrateur {
    private static let cleModele = "vigie.reglages.orchestrateur.modele"
    private static let cleEffort = "vigie.reglages.orchestrateur.effort"
    private static let cleModeRapide = "vigie.reglages.orchestrateur.modeRapide"
    private static let cleUltracode = "vigie.reglages.orchestrateur.ultracode"

    /// `nil` tant que rien n'a été choisi : c'est alors `effortDefaut` du
    /// catalogue qui décide, jamais une valeur inventée ici.
    public static var modele: String? {
        get { UserDefaults.standard.string(forKey: cleModele) }
        set { UserDefaults.standard.set(newValue, forKey: cleModele) }
    }

    public static var effort: String? {
        get { UserDefaults.standard.string(forKey: cleEffort) }
        set { UserDefaults.standard.set(newValue, forKey: cleEffort) }
    }

    public static var modeRapide: Bool {
        get { UserDefaults.standard.bool(forKey: cleModeRapide) }
        set { UserDefaults.standard.set(newValue, forKey: cleModeRapide) }
    }

    public static var ultracode: Bool {
        get { UserDefaults.standard.bool(forKey: cleUltracode) }
        set { UserDefaults.standard.set(newValue, forKey: cleUltracode) }
    }

    /// Le modèle choisi, ou le premier activé du catalogue à défaut.
    public static func modeleCourant(dans catalogue: [ModeleApi]) -> ModeleApi? {
        if let modele, let trouve = catalogue.first(where: { $0.id == modele }) { return trouve }
        return catalogue.first(where: \.enabled)
    }

    /// Reprojette l'effort sur les niveaux RÉELLEMENT acceptés par `modele` —
    /// un changement de modèle ne doit jamais laisser un effort orphelin
    /// (cas de Haiku, dont `effort` est vide).
    public static func effortCoherent(pour modele: ModeleApi) -> String? {
        guard !modele.effort.isEmpty else { return nil }
        if let effort, modele.effort.contains(effort) { return effort }
        return modele.effortDefaut ?? modele.effort.first
    }
}
#endif
