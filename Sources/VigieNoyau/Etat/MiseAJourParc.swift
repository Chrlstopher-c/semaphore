import Foundation

// Responsabilité : mises à jour pures du parc (sessions, machines, notifications) à partir des messages du relais.
// Chaque fonction rend un nouveau tableau ; l'ordre et les doublons se règlent ici, une fois.

public enum MiseAJourParc {
    /// Borne la liste des notifications gardées en mémoire.
    public static let tailleMaxNotifications = 200

    /// Remplace la session de même `id`, ou l'ajoute ; la liste reste triée par `majLe` décroissant.
    public static func session(_ nouvelle: Session, dans sessions: [Session]) -> [Session] {
        var liste = sessions.filter { $0.id != nouvelle.id }
        liste.append(nouvelle)
        return liste.sorted { $0.majLe > $1.majLe }
    }

    public static func sansSession(_ id: String, dans sessions: [Session]) -> [Session] {
        sessions.filter { $0.id != id }
    }

    /// Remplace la machine de même `id`, ou l'ajoute en queue.
    public static func machine(_ nouvelle: Machine, dans machines: [Machine]) -> [Machine] {
        guard machines.contains(where: { $0.id == nouvelle.id }) else { return machines + [nouvelle] }
        return machines.map { $0.id == nouvelle.id ? nouvelle : $0 }
    }

    /// Ajoute des notifications en tête, sans doublon (même `seq`) ; la plus récente d'abord, bornée.
    public static func notifications(_ nouvelles: [NotificationRelais],
                                     dans existantes: [NotificationRelais]) -> [NotificationRelais] {
        let vues = Set(nouvelles.map(\.seq))
        let reste = existantes.filter { !vues.contains($0.seq) }
        return Array((nouvelles + reste).sorted { $0.seq > $1.seq }.prefix(tailleMaxNotifications))
    }
}
