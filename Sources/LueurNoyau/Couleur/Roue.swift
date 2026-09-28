// Géométrie de la roue chromatique : un point touché ↔ une nuance. Angle 0 à droite, sens horaire
// (repère écran, y vers le bas) — le même que `AngularGradient`, sinon le doigt et la couleur divergent.
import Foundation

public enum Roue {
    /// `dx`, `dy` : écart au centre, en points ; `rayon` : rayon de la roue.
    /// Hors du disque, la saturation plafonne à 1.
    public static func nuance(dx: Double, dy: Double, rayon: Double) -> Nuance {
        guard rayon > 0 else { return Nuance(teinte: 0, saturation: 0) }
        let teinte = atan2(dy, dx) * 180 / .pi
        return Nuance(teinte: teinte, saturation: min(1, hypot(dx, dy) / rayon))
    }

    /// Position du curseur, en écart au centre, pour une nuance donnée.
    public static func position(de nuance: Nuance, rayon: Double) -> (dx: Double, dy: Double) {
        let place = nuance.placeSurRoue
        let angle = place.teinte * .pi / 180
        return (cos(angle) * place.saturation * rayon, sin(angle) * place.saturation * rayon)
    }
}
