#if canImport(SwiftUI)
import Foundation
import VigieNoyau

/// La **seule** sortie réseau du programme.
///
/// Un acteur, et pas un objet partagé : le jeton de session et l'adresse du Pi
/// sont mutables et lus depuis les écrans, les réveils de fond et le veilleur
/// audio simultanément. Les protéger par convention plutôt que par isolation
/// serait une course garantie sur une chaîne où l'on ne peut rien déboguer.
///
/// Deux `URLSession` distinctes, jamais une seule : le relais du harness monte à
/// 130 s sur une écriture (un tour d'orchestrateur peut mettre une minute à
/// revenir), alors qu'une lecture qui traîne au-delà de 10 s immobilise l'écran
/// pour rien — le miroir a déjà la réponse d'avant.
public actor ClientPi {

    private var adresse: URL
    private var jeton: String?
    private let coffre: CoffreJeton
    private let miroir: DepotMiroir
    private let sessionLecture: URLSession
    private let sessionEcriture: URLSession

    /// Flux des verdicts de liaison. Drainé par la coquille, par personne
    /// d'autre : c'est ce qui rend le bandeau d'état vrai sans qu'aucun domaine
    /// n'ait à y penser.
    public nonisolated let verdicts: AsyncStream<VerdictLien>
    private nonisolated let emetteur: AsyncStream<VerdictLien>.Continuation

    public init(adresse: URL, miroir: DepotMiroir, coffre: CoffreJeton = CoffreJeton()) {
        self.adresse = adresse
        self.miroir = miroir
        self.coffre = coffre
        jeton = coffre.lire()
        let flux = AsyncStream<VerdictLien>.makeStream(bufferingPolicy: .bufferingNewest(4))
        verdicts = flux.stream
        emetteur = flux.continuation
        // Un seul délégué pour les deux sessions : il est sans état, et les deux
        // doivent refuser la redirection de la même façon.
        let refus = RefusRedirection()
        sessionLecture = Self.fabriquerSession(delai: Route.delaiLectureS, delegue: refus)
        sessionEcriture = Self.fabriquerSession(delai: Route.delaiEcritureS, delegue: refus)
    }

    /// `httpShouldSetCookies = false` : Vigie pose l'en-tête `Cookie:`
    /// elle-même depuis le trousseau. Laisser `HTTPCookieStorage` s'en mêler
    /// ferait cohabiter deux sources pour la même valeur, dont une qui s'efface
    /// à chaque lancement.
    private static func fabriquerSession(delai: Double, delegue: RefusRedirection) -> URLSession {
        let reglage = URLSessionConfiguration.ephemeral
        reglage.timeoutIntervalForRequest = delai
        reglage.timeoutIntervalForResource = delai
        reglage.httpShouldSetCookies = false
        reglage.httpCookieAcceptPolicy = .never
        reglage.requestCachePolicy = .reloadIgnoringLocalCacheData
        reglage.waitsForConnectivity = false
        return URLSession(configuration: reglage, delegate: delegue, delegateQueue: nil)
    }

    // MARK: - Session

    public var adresseCourante: URL { adresse }
    public var sessionOuverte: Bool { jeton != nil }

    public func changerAdresse(_ nouvelle: URL) {
        adresse = nouvelle
        Trace.info("lien", "adresse du Pi : \(nouvelle.absoluteString)")
    }

    /// `POST /login` en formulaire. La réponse est un **302 avec `Set-Cookie`**,
    /// pas un JSON : `RefusRedirection` l'empêche d'être suivie, ce qui est
    /// justement ce qui nous laisse lire l'en-tête.
    public func ouvrirSession(motDePasse: String) async -> Result<Void, ErreurApi> {
        let corps = "password=\(Self.echapperFormulaire(motDePasse))".data(using: .utf8)
        guard var demande = requeteVers(Route.connexion, methode: "POST", corps: corps) else {
            return .failure(.contratRompu("adresse du Pi invalide"))
        }
        demande.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // `☠` `tolererRedirection` est indispensable ICI et nulle part ailleurs :
        // une connexion RÉUSSIE répond 302 vers `/`. Sans cette exception, le
        // garde-fou qui traduit les 3xx en « session à rouvrir » ferait échouer
        // la seule requête dont la redirection est le signe du succès.
        switch await executerBrut(demande, session: sessionLecture, tolererRedirection: true) {
        case .failure(let erreur):
            signaler(releveFrais: nil, erreur: erreur)
            return .failure(erreur)
        case .success(let reponse):
            return conclureConnexion(reponse)
        }
    }

    private func conclureConnexion(_ reponse: ReponseBrute) -> Result<Void, ErreurApi> {
        guard let entete = reponse.setCookie,
              let valeur = LectureCookie.valeur(nom: "session", dans: entete) else {
            let erreur = ErreurApi(
                statut: reponse.statut,
                message: reponse.statut == 401 ? "Mot de passe refusé." : "Le Pi n'a pas ouvert de session.",
                genre: .authentification
            )
            signaler(releveFrais: nil, erreur: erreur)
            return .failure(erreur)
        }
        jeton = valeur
        coffre.enregistrer(valeur)
        Trace.info("lien", "session ouverte")
        return .success(())
    }

    /// Ferme la session et efface tout ce qui en dépend — jeton ET miroir. Le
    /// miroir porte des titres de projets et des objectifs de mandats : il ne
    /// survit pas à une déconnexion volontaire.
    public func fermerSession() async {
        jeton = nil
        coffre.effacer()
        await miroir.vider()
        Trace.info("lien", "session fermée")
    }

    // MARK: - Lectures

    /// Lecture enveloppée du harness. `memoriser` range le corps brut dans le
    /// miroir : une ligne, et l'écran s'ouvrira plein au prochain lancement.
    public func lire<Charge: Decodable & Sendable>(
        _ type: Charge.Type,
        _ chemin: String,
        memoriser cle: CleMiroir? = nil
    ) async -> LectureApi<Charge> {
        guard let demande = requeteVers(chemin, methode: "GET", corps: nil) else {
            return .echec(.contratRompu("chemin invalide : \(chemin)"))
        }
        switch await executerBrut(demande, session: sessionLecture) {
        case .failure(let erreur):
            signaler(releveFrais: nil, erreur: erreur)
            return .echec(erreur)
        case .success(let reponse):
            let lecture = DecodeurContrat.lecture(type, statut: reponse.statut, corps: reponse.corps)
            signaler(releveFrais: lecture.erreur == nil ? lecture.releveFrais : nil, erreur: lecture.erreur)
            if let cle, lecture.charge != nil {
                await miroir.deposer(cle, corps: reponse.corps, forme: .enveloppe, pcEnLigne: lecture.releveFrais)
            }
            return lecture
        }
    }

    /// Lecture hors enveloppe : `/health` et les routes natives de `pi-web`.
    public func lireNu<Charge: Decodable & Sendable>(
        _ type: Charge.Type,
        _ chemin: String,
        memoriser cle: CleMiroir? = nil
    ) async -> Result<Charge, ErreurApi> {
        await appelNu(type, chemin, methode: "GET", corps: nil, session: sessionLecture, memoriser: cle)
    }

    /// Route native adossée au poste de travail : `pcAbsent` et `refus` y sont
    /// deux choses différentes, et le 200 y ment sur le succès.
    public func lirePoste<Charge: ReponsePoste>(
        _ type: Charge.Type,
        _ chemin: String,
        memoriser cle: CleMiroir? = nil
    ) async -> LecturePoste<Charge> {
        await appelPoste(type, chemin, methode: "GET", corps: nil, session: sessionLecture, memoriser: cle)
    }

    /// `☠` La seule route du contrat qui rend des octets. Un `AsyncImage` nu
    /// échoue dessus : elle exige le cookie de session.
    public func octets(_ chemin: String) async -> Result<Data, ErreurApi> {
        guard let demande = requeteVers(chemin, methode: "GET", corps: nil) else {
            return .failure(.contratRompu("chemin invalide : \(chemin)"))
        }
        switch await executerBrut(demande, session: sessionLecture) {
        case .failure(let erreur):
            signaler(releveFrais: nil, erreur: erreur)
            return .failure(erreur)
        case .success(let reponse):
            guard (200...299).contains(reponse.statut) else {
                let erreur = ClassementErreur.classer(statut: reponse.statut, corps: reponse.corps)
                signaler(releveFrais: nil, erreur: erreur)
                return .failure(erreur)
            }
            signaler(releveFrais: nil, erreur: nil)
            return .success(reponse.corps)
        }
    }

    // MARK: - Écritures

    /// Écriture du harness. Forme nue `{ ok, effet, … }`, jamais enveloppée.
    public func ecrire(_ chemin: String, _ corps: CorpsJSON? = nil) async -> Result<AccuseEcriture, ErreurApi> {
        guard let demande = requeteEcriture(chemin, corps: corps) else {
            return .failure(.contratRompu("corps ou chemin invalide : \(chemin)"))
        }
        switch await executerBrut(demande, session: sessionEcriture) {
        case .failure(let erreur):
            signaler(releveFrais: nil, erreur: erreur)
            return .failure(erreur)
        case .success(let reponse):
            let accuse = DecodeurContrat.ecriture(statut: reponse.statut, corps: reponse.corps)
            signaler(releveFrais: nil, erreur: accuse.echec)
            return accuse
        }
    }

    /// Ordre envoyé au poste de travail par une route native (`ws_cmd`).
    public func ordonner<Charge: ReponsePoste>(
        _ type: Charge.Type,
        _ chemin: String,
        _ corps: CorpsJSON? = nil
    ) async -> LecturePoste<Charge> {
        await appelPoste(type, chemin, methode: "POST", corps: corps, session: sessionEcriture, memoriser: nil)
    }

    /// Écriture native de `pi-web` qui ne rend ni accusé du harness ni réponse
    /// de poste — `POST /api/wake` et sa forme `{ status }`.
    public func ecrireNu<Charge: Decodable & Sendable>(
        _ type: Charge.Type,
        _ chemin: String,
        _ corps: CorpsJSON? = nil
    ) async -> Result<Charge, ErreurApi> {
        await appelNu(type, chemin, methode: "POST", corps: corps, session: sessionEcriture, memoriser: nil)
    }

    // MARK: - Rouages communs

    private func appelNu<Charge: Decodable & Sendable>(
        _ type: Charge.Type,
        _ chemin: String,
        methode: String,
        corps: CorpsJSON?,
        session: URLSession,
        memoriser cle: CleMiroir?
    ) async -> Result<Charge, ErreurApi> {
        guard let demande = preparer(chemin, methode: methode, corps: corps) else {
            return .failure(.contratRompu("chemin invalide : \(chemin)"))
        }
        switch await executerBrut(demande, session: session) {
        case .failure(let erreur):
            signaler(releveFrais: nil, erreur: erreur)
            return .failure(erreur)
        case .success(let reponse):
            let resultat = DecodeurContrat.nu(type, statut: reponse.statut, corps: reponse.corps)
            signaler(releveFrais: nil, erreur: resultat.echec)
            if let cle, resultat.echec == nil {
                await miroir.deposer(cle, corps: reponse.corps, forme: .nue, pcEnLigne: true)
            }
            return resultat
        }
    }

    private func appelPoste<Charge: ReponsePoste>(
        _ type: Charge.Type,
        _ chemin: String,
        methode: String,
        corps: CorpsJSON?,
        session: URLSession,
        memoriser cle: CleMiroir?
    ) async -> LecturePoste<Charge> {
        guard let demande = preparer(chemin, methode: methode, corps: corps) else {
            return .echec(.contratRompu("chemin invalide : \(chemin)"))
        }
        switch await executerBrut(demande, session: session) {
        case .failure(let erreur):
            signaler(releveFrais: nil, erreur: erreur)
            return .echec(erreur)
        case .success(let reponse):
            let lecture = DecodeurContrat.poste(type, statut: reponse.statut, corps: reponse.corps)
            signaler(releveFrais: lecture.posteEnLigne, erreur: lecture.echec)
            if let cle, case .fraiche = lecture {
                await miroir.deposer(cle, corps: reponse.corps, forme: .nue, pcEnLigne: true)
            }
            return lecture
        }
    }

    private func signaler(releveFrais: Bool?, erreur: ErreurApi?) {
        if erreur?.genre == .authentification, jeton != nil {
            // Le jeton est mort côté serveur : le garder ferait boucler l'app
            // sur des 303 en silence au lieu de demander le mot de passe.
            jeton = nil
            coffre.effacer()
        }
        emetteur.yield(VerdictLien(releveFrais: releveFrais, erreur: erreur))
    }

    // MARK: - Transport

    private struct ReponseBrute: Sendable {
        let statut: Int
        let corps: Data
        let setCookie: String?
    }

    private func preparer(_ chemin: String, methode: String, corps: CorpsJSON?) -> URLRequest? {
        guard methode != "GET" else { return requeteVers(chemin, methode: "GET", corps: nil) }
        return requeteEcriture(chemin, corps: corps)
    }

    private func requeteVers(_ chemin: String, methode: String, corps: Data?) -> URLRequest? {
        guard let url = URL(string: chemin, relativeTo: adresse) else { return nil }
        var demande = URLRequest(url: url)
        demande.httpMethod = methode
        demande.httpBody = corps
        demande.setValue("application/json", forHTTPHeaderField: "Accept")
        if let jeton { demande.setValue("session=\(jeton)", forHTTPHeaderField: "Cookie") }
        return demande
    }

    private func requeteEcriture(_ chemin: String, corps: CorpsJSON?) -> URLRequest? {
        var octets: Data?
        if let corps {
            do {
                octets = try corps.octets()
            } catch {
                Trace.erreur("lien", "corps JSON inencodable pour \(chemin)", error)
                return nil
            }
        }
        guard var demande = requeteVers(chemin, methode: "POST", corps: octets) else { return nil }
        demande.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return demande
    }

    private func executerBrut(
        _ demande: URLRequest,
        session: URLSession,
        tolererRedirection: Bool = false
    ) async -> Result<ReponseBrute, ErreurApi> {
        do {
            let (corps, reponse) = try await session.data(for: demande)
            guard let http = reponse as? HTTPURLResponse else {
                return .failure(.contratRompu("réponse sans statut HTTP"))
            }
            if !tolererRedirection,
               let redirection = Self.redirectionRefusee(http, chemin: demande.url?.path) {
                return .failure(redirection)
            }
            return .success(ReponseBrute(
                statut: http.statusCode,
                corps: corps,
                setCookie: http.value(forHTTPHeaderField: "Set-Cookie")
            ))
        } catch {
            return .failure(.transport(Self.motifTransport(error)))
        }
    }

    /// `☠` Une redirection reçue ici veut dire une seule chose : `check_session`
    /// a renvoyé vers `/login`. Sans cette traduction, l'erreur remonterait en
    /// « HTTP 303 » et personne ne saurait qu'il faut ressaisir le mot de passe.
    private static func redirectionRefusee(_ http: HTTPURLResponse, chemin: String?) -> ErreurApi? {
        guard (300...399).contains(http.statusCode), http.statusCode != 304 else { return nil }
        Trace.info("lien", "session refusée sur \(chemin ?? "?") (\(http.statusCode))")
        return ErreurApi(
            statut: 401,
            message: "Session close ou périmée sur le Pi. Mot de passe à ressaisir.",
            genre: .authentification
        )
    }

    private static func motifTransport(_ erreur: Error) -> String {
        guard let url = erreur as? URLError else { return "Le Pi n'a pas répondu." }
        switch url.code {
        case .timedOut: return "Le Pi n'a pas répondu à temps."
        case .notConnectedToInternet: return "Aucun réseau sur le téléphone."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Adresse du Pi injoignable — tunnel coupé ?"
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return "Liaison chiffrée refusée par le Pi."
        case .networkConnectionLost: return "Liaison interrompue en cours de route."
        case .cancelled: return "Requête annulée."
        default: return "Liaison impossible (\(url.code.rawValue))."
        }
    }

    /// `application/x-www-form-urlencoded` : l'espace devient `+`, tout le reste
    /// est encodé. Un mot de passe à `&` ou `+` casserait un encodage d'URL nu.
    private static func echapperFormulaire(_ valeur: String) -> String {
        let permis = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return valeur.addingPercentEncoding(withAllowedCharacters: permis) ?? valeur
    }
}

// MARK: - Confort d'inspection des résultats

extension Result where Failure == ErreurApi {
    /// Le refus, s'il y en a un. Évite un `if case` à chaque appel.
    public var echec: ErreurApi? {
        if case .failure(let erreur) = self { return erreur }
        return nil
    }

    public var valeur: Success? {
        if case .success(let valeur) = self { return valeur }
        return nil
    }
}

extension LecturePoste {
    public var echec: ErreurApi? {
        if case .echec(let erreur) = self { return erreur }
        return nil
    }

    /// `true` seulement si le poste a répondu. `false` s'il dort, `nil` si on
    /// n'en sait rien (panne de transport ou refus du Pi).
    public var posteEnLigne: Bool? {
        switch self {
        case .fraiche, .refus: return true
        case .pcAbsent: return false
        case .echec: return nil
        }
    }

    public var charge: Charge? {
        if case .fraiche(let charge) = self { return charge }
        return nil
    }
}
#endif
