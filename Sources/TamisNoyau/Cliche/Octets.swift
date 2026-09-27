// Écriture des tailles, en unités décimales comme Réglages et iCloud : le
// chiffre affiché doit se comparer à celui que montre l'iPhone, pas s'en écarter
// de 7 % parce qu'on compte en binaire.
import Foundation

public enum Octets {
    private static let unites = ["o", "Ko", "Mo", "Go", "To"]

    /// `12 400 000 000` → « 12,4 Go ». Une décimale sous 100, aucune au-delà.
    public static func lisible(_ octets: Int64) -> String {
        var valeur = Double(max(octets, 0))
        var rang = 0
        while valeur >= 1000, rang < unites.count - 1 {
            valeur /= 1000
            rang += 1
        }
        let decimales = (rang == 0 || valeur >= 100) ? 0 : 1
        let texte = String(format: "%.\(decimales)f", valeur).replacingOccurrences(of: ".", with: ",")
        return "\(texte) \(unites[rang])"
    }
}
