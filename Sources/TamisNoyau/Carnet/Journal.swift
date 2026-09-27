import Foundation

/// La journalisation du monde Tamis, lisible dans `idevicesyslog`. Toute
/// fonction qui touche la photothèque, Vision ou le disque attrape et note ici.
public enum Journal {
    public static func echec(_ message: String) { print("[Tamis] ✗ \(message)") }
    public static func note(_ message: String) { print("[Tamis] · \(message)") }
}
