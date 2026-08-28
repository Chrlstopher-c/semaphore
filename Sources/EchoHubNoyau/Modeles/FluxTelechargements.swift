import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Ce qu'un flux de progression peut annoncer.
public enum EvenementTransfert: Sendable, Equatable {
    /// Un état COMPLET, jamais un delta : un client qui se branche en cours de
    /// route n'a rien à reconstituer.
    case etat(Telechargement)
    case echec(String)
    /// La sentinelle `[DONE]` du serveur, ou la fermeture du transport.
    case fin
}

/// La lecture d'une trame de progression. Pure, donc éprouvable sans réseau —
/// c'est tout ce qui, dans ce flux, peut l'être.
public enum LectureTransfert {

    static let sentinelle = "[DONE]"

    public static func lire(_ trame: TrameSSE) -> EvenementTransfert? {
        let charge = trame.donnees.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !charge.isEmpty else { return nil }
        guard charge != sentinelle else { return .fin }
        let octets = Data(charge.utf8)
        if let etat = try? CodageJSON.decodeur().decode(Telechargement.self, from: octets) {
            return .etat(etat)
        }
        // `☠` Le serveur émet aussi ses erreurs métier DANS le flux : le statut
        // HTTP est déjà parti quand le transfert commence, et c'est la seule
        // façon de le dire sans laisser l'écran attendre une fin qui ne viendra
        // pas. La trame porte alors `{code, message, remediation}`.
        guard let erreur = try? CodageJSON.decodeur().decode(EchecTransfert.self, from: octets),
              !erreur.message.isEmpty else {
            Journal.note("trame de transfert non reconnue, ignorée")
            return nil
        }
        return .echec(erreur.remediation.map { "\(erreur.message) \($0)" } ?? erreur.message)
    }
}

struct EchecTransfert: Decodable {
    let message: String
    let remediation: String?
}

/// Le suivi de progression des transferts, au fil de l'eau.
///
/// `☠` Rien n'est ACCUMULÉ. Les octets entrent dans l'analyseur SSE, qui ne
/// retient qu'un fragment de trame, et chaque état complet ressort aussitôt. Un
/// transfert de douze gigaoctets diffuse pendant des heures : accumuler la
/// réponse remplirait la mémoire du téléphone pour n'afficher qu'un pourcentage.
///
/// Le flux ne LANCE jamais : un échec de transport devient un `.echec`, comme
/// le fait le serveur une fois les en-têtes partis. L'écran n'a qu'un chemin.
public enum FluxTelechargements {

    /// Plafond d'octets d'un suivi. Il ne décrit aucun transfert : il borne une
    /// boucle qui, sans lui, dépend entièrement de ce que le serveur envoie.
    /// Un état complet fait quelques centaines d'octets ; 8 Mio couvrent des
    /// dizaines de milliers de relevés.
    public static let plafondOctets = 8 * 1024 * 1024

    /// Tous les transferts. `identifiant` restreint le suivi à un seul —
    /// c'est la diffusion native du domaine, plus économe.
    public static func ouvrir(
        client: ClientEchoHub, identifiant: String? = nil
    ) -> AsyncStream<EvenementTransfert> {
        let chemin = identifiant.map { "models/telechargements/\($0)/flux" }
            ?? "models/telechargements/flux"
        return AsyncStream { suite in
            let tache = Task {
                await diffuser(client: client, chemin: chemin, vers: suite)
                suite.finish()
            }
            // L'écran qui disparaît annule le suivi, donc la requête : sans ça,
            // le PC diffuserait dans le vide.
            suite.onTermination = { _ in tache.cancel() }
        }
    }

    private static func diffuser(
        client: ClientEchoHub, chemin: String,
        vers suite: AsyncStream<EvenementTransfert>.Continuation
    ) async {
        let requete: URLRequest
        do {
            requete = try await client.requete("GET", chemin)
        } catch {
            Journal.echec("suivi des transferts impossible à ouvrir : \(error)")
            let libelle = (error as? ErreurRelais)?.libelle ?? error.localizedDescription
            suite.yield(.echec(libelle))
            return
        }
        await lire(requete: requete, chemin: chemin, vers: suite)
    }

    /// Boucle bornée par la fin du flux ET par `plafondOctets`.
    private static func lire(
        requete: URLRequest, chemin: String,
        vers suite: AsyncStream<EvenementTransfert>.Continuation
    ) async {
        let transfert = SessionSSE.ouvrir(requete)
        defer { transfert.session.finishTasksAndInvalidate() }
        var analyseur = AnalyseurSSE()
        var total = 0
        var refus: Int?
        await withTaskCancellationHandler {
            for await signal in transfert.signaux {
                switch signal {
                case .statut(let statut):
                    guard !(200..<300).contains(statut) else { continue }
                    Journal.echec("suivi \(chemin) refusé : statut \(statut)")
                    refus = statut
                case .octets(let donnees):
                    guard refus == nil else { continue }
                    total += donnees.count
                    guard total <= plafondOctets else {
                        Journal.echec("suivi \(chemin) coupé : plafond d'octets atteint")
                        return transfert.tache.cancel()
                    }
                    rendre(analyseur.absorber(donnees), vers: suite)
                case .fin(let echec):
                    conclure(refus: refus, echec: echec, analyseur: &analyseur, vers: suite)
                    return
                }
            }
        } onCancel: {
            transfert.tache.cancel()
        }
    }

    private static func conclure(
        refus: Int?, echec: String?, analyseur: inout AnalyseurSSE,
        vers suite: AsyncStream<EvenementTransfert>.Continuation
    ) {
        if let refus {
            suite.yield(.echec("Le serveur a refusé le suivi (statut \(refus))."))
            return
        }
        if let echec {
            suite.yield(.echec(echec))
            return
        }
        if let residu = analyseur.terminer() { rendre([residu], vers: suite) }
        suite.yield(.fin)
    }

    private static func rendre(
        _ trames: [TrameSSE], vers suite: AsyncStream<EvenementTransfert>.Continuation
    ) {
        for trame in trames {
            if let evenement = LectureTransfert.lire(trame) { suite.yield(evenement) }
        }
    }
}
