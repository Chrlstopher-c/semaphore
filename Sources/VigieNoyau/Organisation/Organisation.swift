import Foundation

// Responsabilité : l'organisation que l'iPhone garde pour lui-même (favoris par machine) et la fusion d'une synchro
// dedans. Une synchro réussie ne change que les sessions qu'elle présente (épinglée ou non) ; une session absente, une
// machine qui ne répond pas ou une lecture échouée ne retirent rien. Pur : le fichier est dans StockageOrganisation.

public struct Organisation: Codable, Equatable, Sendable {
    public static let versionCourante = 1
    public static let vide = Organisation(version: versionCourante, machines: [:])
    /// En deçà de ce délai, la date de synchro n'est pas réécrite : évite un fichier réécrit à chaque tour de liaison.
    static let delaiEcriture: TimeInterval = 60

    /// Ce que l'iPhone sait d'une machine : ses favoris tels que vus à la dernière synchro, et l'état de cette synchro.
    public struct Machine: Codable, Equatable, Sendable {
        /// Instantanés des sessions épinglées : affichables sans réseau (titre, dossier, dernier état connu).
        public var favoris: [Session]
        public var derniereSync: Date?
        public var erreur: String?

        public init(favoris: [Session] = [], derniereSync: Date? = nil, erreur: String? = nil) {
            self.favoris = favoris
            self.derniereSync = derniereSync
            self.erreur = erreur
        }
    }

    public var version: Int
    /// Par identifiant de machine.
    public var machines: [String: Machine]

    public init(version: Int, machines: [String: Machine]) {
        self.version = version
        self.machines = machines
    }

    /// Tous les favoris gardés, toutes machines confondues, les plus récents d'abord.
    public var favoris: [Session] {
        machines.keys.sorted().flatMap { machines[$0]?.favoris ?? [] }.sorted { $0.majLe > $1.majLe }
    }

    /// Fusionne ce que `sessions` (sessions de `machine` présentes dans la synchro) dit de leur épinglage. `maintenant`
    /// nil : une mise à jour isolée d'une session, qui ne compte ni comme synchro ni comme erreur levée.
    public func fusionner(machine: String, sessions: [Session], maintenant: Date?) -> Organisation {
        var suite = self
        var entree = machines[machine] ?? Machine()
        let presentes = Set(sessions.map(\.id))
        entree.favoris = entree.favoris.filter { !presentes.contains($0.id) } + sessions.filter(Self.estFavori)
        if let maintenant {
            entree.erreur = nil
            if entree.derniereSync.map({ maintenant.timeIntervalSince($0) >= Self.delaiEcriture }) ?? true {
                entree.derniereSync = maintenant
            }
        }
        guard machines[machine] != nil || !entree.favoris.isEmpty || maintenant != nil else { return self }
        suite.machines[machine] = entree
        return suite
    }

    /// Une session supprimée par le relais ne reste pas en favori.
    public func oublier(_ session: String) -> Organisation {
        var suite = self
        for (machine, entree) in machines where entree.favoris.contains(where: { $0.id == session }) {
            suite.machines[machine]?.favoris.removeAll { $0.id == session }
        }
        return suite
    }

    /// Une lecture du relais a échoué : les machines données portent la raison, leurs favoris ne bougent pas.
    public func echec(_ raison: String, sur identifiants: [String]) -> Organisation {
        var suite = self
        for identifiant in identifiants {
            var entree = machines[identifiant] ?? Machine()
            entree.erreur = raison
            suite.machines[identifiant] = entree
        }
        return suite
    }

    public static func estFavori(_ session: Session) -> Bool {
        session.epinglee == true && session.archivee != true
    }
}
