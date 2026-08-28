import Foundation

/// Le miroir sur disque. **Vigie ne charge jamais** : elle s'ouvre pleine sur le
/// dernier état connu, daté, puis rafraîchit derrière.
///
/// C'est le gain que Safari ne peut structurellement pas offrir — la SPA
/// recharge trente-quatre fichiers JS non regroupés et trois familles de polices
/// à travers le tunnel à chaque ouverture d'onglet.
public actor DepotMiroir {
    private let fichier: URL
    private var instantane: Instantane
    private var charge = false
    private var salissure = false
    private var tacheEcriture: Task<Void, Never>?

    /// Regroupement des écritures. Un sondage à 400 ms sur un fil en génération
    /// réécrirait le fichier deux fois par seconde pour rien.
    private static let regroupementNs: UInt64 = 3_000_000_000

    public init(fichier: URL? = nil) {
        self.fichier = fichier ?? Self.emplacementParDefaut()
        instantane = Instantane()
    }

    /// Le fichier réellement utilisé. `☠` Lu par le diagnostic pour dire où le
    /// miroir vit — jamais persisté : le conteneur change d'UUID à chaque pose
    /// d'IPA resigné, un chemin absolu retenu d'un lancement à l'autre pointerait
    /// dans le vide.
    public nonisolated var emplacement: URL { fichier }

    /// `Application Support/Vigie/miroir.json`. Hors de `Documents` : ce n'est ni
    /// une production de l'utilisateur ni quelque chose à exposer par iTunes.
    private static func emplacementParDefaut() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dossier = (base.first ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("Vigie", isDirectory: true)
        return dossier.appendingPathComponent("miroir.json")
    }

    // MARK: - Cycle de vie

    /// Lit le disque. Idempotent : les appels suivants ne coûtent rien.
    /// À appeler une fois au démarrage, AVANT le premier écran.
    public func charger() {
        guard !charge else { return }
        charge = true
        do {
            let octets = try Data(contentsOf: fichier)
            let relu = try JSONDecoder().decode(Instantane.self, from: octets)
            guard relu.version == Instantane.versionCourante else {
                Trace.info("miroir", "version \(relu.version) périmée, miroir repartant de zéro")
                return
            }
            instantane = relu
            Trace.info("miroir", "\(relu.rubriquesConnues) rubriques relues (\(octets.count) octets)")
        } catch CocoaError.fileReadNoSuchFile {
            Trace.info("miroir", "aucun miroir sur disque — premier lancement")
        } catch {
            // Un miroir corrompu n'est pas une panne : on repart vide, on le dit,
            // et l'app s'ouvre quand même. Le faire remonter bloquerait l'écran.
            Trace.erreur("miroir", "miroir illisible, repart de zéro", error)
        }
    }

    // MARK: - Lecture

    public func lire<Charge: Decodable & Sendable>(
        _ type: Charge.Type,
        _ cle: CleMiroir
    ) -> DonneeMiroir<Charge>? {
        instantane.lire(type, cle)
    }

    public func releveA(_ cle: CleMiroir) -> Date? {
        instantane.releveA(cle)
    }

    // MARK: - Écriture

    public func deposer(
        _ cle: CleMiroir,
        corps: Data,
        forme: FormeReponse,
        pcEnLigne: Bool,
        releveA: Date = Date()
    ) {
        instantane.deposer(cle, corps: corps, forme: forme, pcEnLigne: pcEnLigne, releveA: releveA)
        salir()
    }

    public func oublier(_ cle: CleMiroir) {
        instantane.oublier(cle)
        salir()
    }

    /// Vide tout. Appelé à la déconnexion : le miroir contient des titres de
    /// projets et des objectifs de mandats, il ne survit pas à une session close.
    public func vider() async {
        tacheEcriture?.cancel()
        tacheEcriture = nil
        instantane.vider()
        salissure = true
        await ecrireMaintenant()
    }

    private func salir() {
        salissure = true
        guard tacheEcriture == nil else { return }
        tacheEcriture = Task { [regroupement = Self.regroupementNs] in
            try? await Task.sleep(nanoseconds: regroupement)
            await self.vidangerRegroupement()
        }
    }

    private func vidangerRegroupement() async {
        tacheEcriture = nil
        await ecrireMaintenant()
    }

    /// Écrit sans attendre le regroupement. À appeler quand la scène passe en
    /// arrière-plan : c'est le dernier instant garanti avant une mise à mort.
    public func ecrireMaintenant() async {
        guard salissure else { return }
        salissure = false
        do {
            try preparerDossier()
            let octets = try JSONEncoder().encode(instantane)
            try octets.write(to: fichier, options: .atomic)
            try protegerAuRepos()
            Trace.detail("miroir", "\(octets.count) octets écrits")
        } catch {
            // On ne remet pas `salissure` : une erreur d'écriture qui se répète
            // relancerait une tâche à chaque dépôt, en boucle.
            Trace.erreur("miroir", "écriture du miroir impossible", error)
        }
    }

    private func preparerDossier() throws {
        let dossier = fichier.deletingLastPathComponent()
        guard !FileManager.default.fileExists(atPath: dossier.path) else { return }
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
    }

    /// Chiffrement au repos. `completeUnlessOpen` et non `complete` : un réveil
    /// de fond peut écrire le miroir alors que l'appareil est verrouillé, et
    /// `complete` ferait échouer cette écriture-là précisément.
    ///
    /// L'écriture atomique remplace l'inode : l'attribut doit être reposé après
    /// chaque écriture, pas une seule fois à la création.
    private func protegerAuRepos() throws {
        #if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUnlessOpen],
            ofItemAtPath: fichier.path
        )
        #endif
    }
}
