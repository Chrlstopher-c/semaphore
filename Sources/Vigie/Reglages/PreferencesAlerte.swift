// Réglages du canal d'alerte que Réglages possède, et pont de lecture vers ce
// que le domaine `Alerte` mesure.
//
// `☠` INTERFACE PROVISOIRE : au moment d'écrire ce fichier, `Sources/Vigie/Alerte/`
// ne contient que la coquille vide (`AlerteEcran.swift`). Le pont ci-dessous est
// le contrat proposé côté Réglages — à valider avec l'agent du domaine `Alerte` :
// il doit encoder son `EtatCanal` (déjà `Codable`, `VigieNoyau/Veille/EtatCanal.swift`)
// en JSON sous `Self.cleEtatCanal` à CHAQUE changement pour que cette section
// affiche autre chose qu'un état vide. Sans cette écriture, `etatCanalConnu()`
// rend `nil` en permanence — ce n'est pas un bug de ce fichier.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

public enum PreferencesAlerte {
    private static let cleMaintienEnVie = "vigie.reglages.alerte.maintienEnVie"
    private static let cleHeuresCalmesActives = "vigie.reglages.alerte.heuresCalmes.actives"
    private static let cleHeuresCalmesDebut = "vigie.reglages.alerte.heuresCalmes.debut"
    private static let cleHeuresCalmesFin = "vigie.reglages.alerte.heuresCalmes.fin"

    /// Clé du pont : `Alerte` y dépose son `EtatCanal` encodé, Réglages le relit
    /// pour l'afficher. Aucune des deux parties ne construit l'autre.
    public static let cleEtatCanal = "vigie.canal.etat"

    /// L'interrupteur : Alerte doit le lire au lancement et au retour au premier
    /// plan pour décider de démarrer ou couper la session audio.
    public static var maintienEnVie: Bool {
        get { UserDefaults.standard.bool(forKey: cleMaintienEnVie) }
        set { UserDefaults.standard.set(newValue, forKey: cleMaintienEnVie) }
    }

    public static var heuresCalmesActives: Bool {
        // `object(forKey:)` et non `bool(forKey:)` : ce dernier rend `false` par
        // défaut, ce qui désactiverait les heures calmes au tout premier
        // lancement au lieu du régime par défaut demandé (23 h → 8 h actif).
        get { (UserDefaults.standard.object(forKey: cleHeuresCalmesActives) as? Bool) ?? true }
        set { UserDefaults.standard.set(newValue, forKey: cleHeuresCalmesActives) }
    }

    public static var heureDebut: Int {
        get { entier(cleHeuresCalmesDebut, defaut: 23) }
        set { UserDefaults.standard.set(newValue.clampeHeure(), forKey: cleHeuresCalmesDebut) }
    }

    public static var heureFin: Int {
        get { entier(cleHeuresCalmesFin, defaut: 8) }
        set { UserDefaults.standard.set(newValue.clampeHeure(), forKey: cleHeuresCalmesFin) }
    }

    /// Genres qui percent les heures calmes — FIXE, pas un réglage. Une équipe
    /// échouée ou un mandat en attente réclament une décision, quelle que soit
    /// l'heure ; tout le reste patiente jusqu'au matin.
    public static let genresToujoursActifs: [GenreAlerte] = [.mandat, .echec]

    private static func entier(_ cle: String, defaut: Int) -> Int {
        let valeur = UserDefaults.standard.object(forKey: cle) as? Int
        return valeur ?? defaut
    }

    /// L'état du canal tel que `Alerte` l'a laissé, ou `nil` s'il n'a jamais
    /// encore écrit — écran neuf, ou domaine pas encore branché.
    public static func etatCanalConnu() -> EtatCanal? {
        guard let donnees = UserDefaults.standard.data(forKey: cleEtatCanal) else { return nil }
        do {
            return try JSONDecoder().decode(EtatCanal.self, from: donnees)
        } catch {
            Trace.erreur("reglages", "état du canal illisible", error)
            return nil
        }
    }
}

extension Int {
    fileprivate func clampeHeure() -> Int { Swift.min(Swift.max(self, 0), 23) }
}
#endif
