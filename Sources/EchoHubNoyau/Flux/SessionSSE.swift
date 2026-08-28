import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// L'ouverture d'un transfert SSE : une session, un collecteur, une tâche.
///
/// Extrait de `FluxGeneration` le 28/08/2026, quand le suivi des
/// téléchargements a eu besoin du même montage. C'est du TRANSPORT, pas une
/// règle métier : la mutualiser ne couple aucun domaine, et deux copies de ce
/// montage divergeraient précisément sur les points qui font mal — la file
/// sérielle et l'invalidation de la session.
///
/// `☠` Une session PAR flux. Le délégué est une propriété de session, pas de
/// requête : deux flux concurrents qui partageraient une session
/// entrelaceraient leurs octets. Et la session est invalidée à la sortie, sans
/// quoi elle retiendrait son délégué, donc la continuation, donc l'écran.
enum SessionSSE {

    struct Transfert {
        let signaux: AsyncStream<SignalFlux>
        let session: URLSession
        let tache: URLSessionDataTask
    }

    static func ouvrir(_ requete: URLRequest) -> Transfert {
        var continuation: AsyncStream<SignalFlux>.Continuation!
        let signaux = AsyncStream<SignalFlux> { continuation = $0 }
        let file = OperationQueue()
        // Sérielle : les morceaux du corps doivent arriver dans l'ordre où le
        // réseau les a rendus. Une file concurrente entrelacerait les fragments
        // d'une phrase.
        file.maxConcurrentOperationCount = 1
        let session = URLSession(
            configuration: ClientEchoHub.configurationFlux(),
            delegate: CollecteurSSE(suite: continuation),
            delegateQueue: file
        )
        let tache = session.dataTask(with: requete)
        tache.resume()
        return Transfert(signaux: signaux, session: session, tache: tache)
    }
}
