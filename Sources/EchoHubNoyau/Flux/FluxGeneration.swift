import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Ouvre un flux de génération et rend ses événements au fil de l'eau.
///
/// `☠` C'est LE point du projet où une erreur ne se voit pas dans un test : le
/// streaming ne se prouve qu'en le regardant arriver sur l'appareil. D'où la
/// découpe — tout ce qui peut être pur l'est (`AnalyseurSSE`,
/// `LectureEvenement`, `SegmenteurReponse`, tous testés), et il ne reste ici
/// que le strict nécessaire : ouvrir la requête, pousser les octets dans
/// l'analyseur, rendre les événements.
///
/// Le flux ne LANCE jamais : un échec de transport devient un événement
/// `.erreur`, exactement comme le fait le serveur une fois les en-têtes partis.
/// L'écran n'a donc qu'un seul chemin à peindre, pas deux.
public enum FluxGeneration {
    /// Plafond d'octets pour une seule génération. Il ne décrit aucun modèle :
    /// il borne une boucle qui, sans lui, dépend entièrement de ce que le
    /// serveur veut bien envoyer. 64 Mio, c'est plusieurs fois la plus longue
    /// réponse imaginable en tokens.
    public static let plafondOctets = 64 * 1024 * 1024

    public static func ouvrir(
        client: ClientEchoHub, chemin: String, corps: Data
    ) -> AsyncStream<EvenementFlux> {
        AsyncStream { suite in
            let tache = Task {
                await diffuser(client: client, chemin: chemin, corps: corps, vers: suite)
                suite.finish()
            }
            // L'écran qui referme la conversation annule le flux, donc la
            // requête : sans ça, le PC continuerait de générer dans le vide.
            suite.onTermination = { _ in tache.cancel() }
        }
    }

    private static func diffuser(
        client: ClientEchoHub, chemin: String, corps: Data,
        vers suite: AsyncStream<EvenementFlux>.Continuation
    ) async {
        let requete: URLRequest
        do {
            requete = try await client.requete("POST", chemin, corps: corps)
        } catch let erreur as ErreurRelais {
            suite.yield(erreurFlux(erreur))
            return
        } catch {
            suite.yield(erreurFlux(.injoignable(error.localizedDescription)))
            return
        }
        await lire(requete: requete, chemin: chemin, vers: suite)
    }

    /// Consomme les signaux du collecteur jusqu'à la fin du transfert.
    ///
    /// Boucle bornée par la fin du flux ET par `plafondOctets` : un serveur qui
    /// ne se tairait jamais coupe au plafond, il ne fait pas tourner le
    /// téléphone jusqu'à la batterie vide.
    private static func lire(
        requete: URLRequest, chemin: String, vers suite: AsyncStream<EvenementFlux>.Continuation
    ) async {
        let transfert = SessionSSE.ouvrir(requete)
        let (signaux, tache) = (transfert.signaux, transfert.tache)
        defer { transfert.session.finishTasksAndInvalidate() }
        var etat = EtatLecture()
        await withTaskCancellationHandler {
            for await signal in signaux {
                guard case .arreter(let erreur) = absorber(
                    signal, dans: &etat, chemin: chemin, vers: suite
                ) else { continue }
                if let erreur { suite.yield(erreurFlux(erreur)) }
                return tache.cancel()
            }
        } onCancel: {
            tache.cancel()
        }
    }

    /// Ce qu'une lecture de flux garde entre deux signaux.
    private struct EtatLecture {
        var analyseur = AnalyseurSSE()
        var total = 0
        /// Le statut d'un refus, retenu au lieu d'être agi tout de suite.
        var statutRefus: Int?
        /// Le corps de ce refus, qui porte `message` et `remediation`.
        var corpsRefus = Data()
    }

    private enum SuiteLecture {
        case continuer
        /// Arrêter le transfert, en émettant cette erreur s'il y en a une.
        case arreter(ErreurRelais?)
    }

    /// `☠` Sur un statut non-2xx, la tâche était annulée IMMÉDIATEMENT — donc le
    /// corps de la réponse, qui porte le message et le remède que le backend a
    /// pris la peine d'écrire pour ce cas exact, n'arrivait jamais. Sur le seul
    /// chemin qui compte — l'envoi d'un message — Chris recevait « Le serveur a
    /// répondu 409. » là où une requête ordinaire lui rendait la phrase. On
    /// retient donc le statut, on laisse le corps s'accumuler, et on tranche à
    /// la fin.
    private static func absorber(
        _ signal: SignalFlux, dans etat: inout EtatLecture, chemin: String,
        vers suite: AsyncStream<EvenementFlux>.Continuation
    ) -> SuiteLecture {
        switch signal {
        case .statut(let statut):
            guard !(200..<300).contains(statut) else { return .continuer }
            Journal.echec("flux \(chemin) refusé : statut \(statut)")
            etat.statutRefus = statut
            return .continuer
        case .octets(let donnees):
            guard etat.statutRefus == nil else { return retenirRefus(donnees, dans: &etat) }
            etat.total += donnees.count
            guard etat.total <= plafondOctets else {
                Journal.echec("flux \(chemin) coupé : plafond d'octets atteint")
                return .arreter(nil)
            }
            rendre(etat.analyseur.absorber(donnees), vers: suite)
            return .continuer
        case .fin(let echec):
            return conclure(echec: echec, etat: &etat, vers: suite)
        }
    }

    /// Un corps d'erreur JSON fait quelques centaines d'octets. Borné quand
    /// même : un serveur qui annoncerait un refus puis déverserait un flux
    /// entier ne doit pas remplir la mémoire du téléphone.
    private static let plafondCorpsRefus = 64 * 1024

    private static func retenirRefus(_ donnees: Data, dans etat: inout EtatLecture) -> SuiteLecture {
        guard etat.corpsRefus.count < plafondCorpsRefus else { return .continuer }
        etat.corpsRefus.append(donnees)
        return .continuer
    }

    private static func conclure(
        echec: String?, etat: inout EtatLecture,
        vers suite: AsyncStream<EvenementFlux>.Continuation
    ) -> SuiteLecture {
        if let statut = etat.statutRefus {
            return .arreter(LectureRefus.erreur(statut: statut, donnees: etat.corpsRefus))
        }
        if let echec { suite.yield(erreurFlux(.injoignable(echec))) }
        if let residu = etat.analyseur.terminer() { rendre([residu], vers: suite) }
        return .continuer
    }

    private static func rendre(
        _ trames: [TrameSSE], vers suite: AsyncStream<EvenementFlux>.Continuation
    ) {
        for trame in trames {
            if let evenement = LectureEvenement.lire(trame) { suite.yield(evenement) }
        }
    }

    private static func erreurFlux(_ erreur: ErreurRelais) -> EvenementFlux {
        .erreur(EvenementErreur(code: nil, message: erreur.libelle, remediation: erreur.remede))
    }
}
