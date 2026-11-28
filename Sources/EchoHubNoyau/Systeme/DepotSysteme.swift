import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Un service de la pile (`GET system/services`), comme la vue Système du web.
public struct ServicePile: Sendable, Decodable, Equatable, Identifiable {
    public var id: String { nom }
    public let nom: String
    public let role: String
    /// `ok`, `degrade`, `panne`… lu tel quel.
    public let etat: String
    public let detail: String?
}

/// La santé d'un moteur (`GET engines/etat`).
public struct SanteBinaireMoteur: Sendable, Decodable, Equatable {
    public let moteur: String
    public let statut: String
    public let version: String?
    public let architecturesGpu: [String]?
    public let diagnostic: String
    public let remediation: String
    public let installe: Bool
    public let fonctionnel: Bool
}

public struct EtatMoteurs: Sendable, Decodable, Equatable {
    public let llamacpp: SanteBinaireMoteur
    public let vllm: SanteBinaireMoteur
}

/// Une version de vLLM dans son environnement propre.
public struct VersionVllm: Sendable, Decodable, Equatable, Identifiable {
    public var id: String { version }
    public let version: String
    public let statut: String
    public let versionTorch: String?
    public let tailleOctets: Int?
    public let installeeLe: String?
    public let diagnostic: String
    public let utilisable: Bool
}

/// Un pas de l'installation, diffusé en direct.
public struct EvenementInstallation: Sendable, Decodable, Equatable {
    public let etape: String
    public let message: String
    public let niveau: String
    public let progression: Double
    public let termine: Bool
    public let succes: Bool?
}

public enum EvenementFluxInstallation: Sendable, Equatable {
    case pas(EvenementInstallation)
    case echec(String)
}

public struct DepotSysteme: Sendable {
    let client: ClientEchoHub

    public init(client: ClientEchoHub) { self.client = client }

    public func services() async throws -> [ServicePile] {
        try await client.lire([ServicePile].self, "GET", "system/services")
    }

    public func moteurs() async throws -> EtatMoteurs {
        try await client.lire(EtatMoteurs.self, "GET", "engines/etat")
    }

    public func versionsVllm(verifier: Bool = false) async throws -> [VersionVllm] {
        try await client.lire([VersionVllm].self, "GET", "engines/vllm/versions?verifier=\(verifier)")
    }

    public func annulerInstallation(_ version: String) async throws {
        try await client.executer("DELETE", "engines/vllm/versions/\(DepotProjets.encoder(version))/installation")
    }

    public func supprimer(_ version: String) async throws {
        try await client.executer("DELETE", "engines/vllm/versions/\(DepotProjets.encoder(version))")
    }

    /// Le flux d'installation. Fermer le flux annule l'installation côté serveur.
    public func installer(_ version: String, remplacer: Bool) -> AsyncStream<EvenementFluxInstallation> {
        let chemin = "engines/vllm/versions/\(DepotProjets.encoder(version))/installation?remplacer=\(remplacer)"
        let client = client
        return AsyncStream { suite in
            let tache = Task {
                await Self.diffuser(client: client, chemin: chemin, vers: suite)
                suite.finish()
            }
            suite.onTermination = { _ in tache.cancel() }
        }
    }

    /// Une trame : un pas d'installation, ou l'erreur métier `{code, message, remediation}` qui clôt le flux.
    public static func lire(_ trame: TrameSSE) -> EvenementFluxInstallation? {
        let octets = Data(trame.donnees.utf8)
        guard !octets.isEmpty else { return nil }
        if let pas = try? CodageJSON.decodeur().decode(EvenementInstallation.self, from: octets) { return .pas(pas) }
        guard let erreur = try? CodageJSON.decodeur().decode(EchecTransfert.self, from: octets) else { return nil }
        return .echec(erreur.remediation.map { "\(erreur.message) \($0)" } ?? erreur.message)
    }

    private static func diffuser(
        client: ClientEchoHub, chemin: String, vers suite: AsyncStream<EvenementFluxInstallation>.Continuation
    ) async {
        let requete: URLRequest
        do {
            requete = try await client.requete("GET", chemin)
        } catch {
            Journal.echec("installation vLLM impossible à ouvrir : \(error)")
            suite.yield(.echec((error as? ErreurRelais)?.libelle ?? error.localizedDescription))
            return
        }
        let transfert = SessionSSE.ouvrir(requete)
        defer { transfert.session.finishTasksAndInvalidate() }
        var analyseur = AnalyseurSSE()
        await withTaskCancellationHandler {
            for await signal in transfert.signaux {
                switch signal {
                case .statut(let statut) where !(200..<300).contains(statut):
                    suite.yield(.echec("Le serveur a refusé l'installation (statut \(statut))."))
                    return transfert.tache.cancel()
                case .statut: continue
                case .octets(let donnees):
                    analyseur.absorber(donnees).compactMap(lire).forEach { suite.yield($0) }
                case .fin(let echec):
                    if let reste = analyseur.terminer(), let dernier = lire(reste) { suite.yield(dernier) }
                    if let echec { suite.yield(.echec(echec)) }
                    return
                }
            }
        } onCancel: {
            transfert.tache.cancel()
        }
    }
}
