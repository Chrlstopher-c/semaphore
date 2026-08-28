import Foundation

/// Un champ de patch à TROIS états.
///
/// `☠` C'est le piège du `PATCH /reglages`, et il n'a pas de contournement.
/// Le backend fusionne avec `exclude_unset` et non `exclude_none`
/// (`backend/chat/modeles.py`) : `max_tokens: null` (« aucun plafond ») et
/// `graine: null` (« aléatoire ») sont des VALEURS DEMANDÉES, pas des champs
/// omis. Or un `Optional` Swift dans un `Encodable` synthétise `encodeIfPresent`
/// et ne peut donc pas exprimer la différence entre « je ne touche pas » et
/// « remets à null » — les deux partiraient comme une absence, et ces deux
/// réglages seraient posables mais jamais effaçables.
public enum ChampPatch<Valeur: Sendable & Equatable & Encodable>: Sendable, Equatable {
    /// Ne pas toucher : la clé ne part pas.
    case absent
    /// Effacer : la clé part avec `null`.
    case nul
    /// Écrire cette valeur.
    case valeur(Valeur)

    /// Ce qu'un champ optionnel déjà lu devient quand on veut l'ÉCRIRE tel quel.
    public init(ecrivant valeur: Valeur?) {
        self = valeur.map { .valeur($0) } ?? .nul
    }
}

extension KeyedEncodingContainer {
    /// Encode un champ à trois états. `.absent` n'écrit rien — c'est le seul
    /// moyen de dire « je ne touche pas » sur une route qui lit `null`.
    public mutating func encoder<Valeur>(
        _ champ: ChampPatch<Valeur>, pour cle: Key
    ) throws {
        switch champ {
        case .absent: return
        case .nul: try encodeNil(forKey: cle)
        case .valeur(let valeur): try encode(valeur, forKey: cle)
        }
    }
}

/// Patch partiel des paramètres d'échantillonnage. Seuls les champs FOURNIS
/// sont écrits : patcher la seule température ne ramène pas les six autres à
/// leur défaut.
public struct MajParametres: Sendable, Encodable, Equatable {
    public var temperature: Double?
    public var topP: Double?
    public var topK: Int?
    public var penaliteRepetition: Double?
    public var maxTokens: ChampPatch<Int>
    public var sequencesArret: [String]?
    public var graine: ChampPatch<Int>

    public init(
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        penaliteRepetition: Double? = nil,
        maxTokens: ChampPatch<Int> = .absent,
        sequencesArret: [String]? = nil,
        graine: ChampPatch<Int> = .absent
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.penaliteRepetition = penaliteRepetition
        self.maxTokens = maxTokens
        self.sequencesArret = sequencesArret
        self.graine = graine
    }

    /// Cas nominal de l'écran de réglages : tout est fourni, `null` compris.
    public init(ecrivant parametres: ParametresEchantillonnage) {
        self.init(
            temperature: parametres.temperature,
            topP: parametres.topP,
            topK: parametres.topK,
            penaliteRepetition: parametres.penaliteRepetition,
            maxTokens: ChampPatch(ecrivant: parametres.maxTokens),
            sequencesArret: parametres.sequencesArret,
            graine: ChampPatch(ecrivant: parametres.graine)
        )
    }

    /// Cases en camelCase, sans valeur brute : `CodageJSON` pose
    /// `convertToSnakeCase`, qui les traduit à l'écriture.
    private enum Cle: String, CodingKey {
        case temperature, topP, topK, penaliteRepetition, maxTokens, sequencesArret, graine
    }

    public func encode(to encodeur: any Encoder) throws {
        var conteneur = encodeur.container(keyedBy: Cle.self)
        try conteneur.encodeIfPresent(temperature, forKey: .temperature)
        try conteneur.encodeIfPresent(topP, forKey: .topP)
        try conteneur.encodeIfPresent(topK, forKey: .topK)
        try conteneur.encodeIfPresent(penaliteRepetition, forKey: .penaliteRepetition)
        try conteneur.encoder(maxTokens, pour: .maxTokens)
        try conteneur.encodeIfPresent(sequencesArret, forKey: .sequencesArret)
        try conteneur.encoder(graine, pour: .graine)
    }
}

/// Corps de `PATCH /api/chat/conversations/{id}/reglages`.
///
/// `☠` `promptSysteme` est un `Optional` ordinaire et c'est correct : côté
/// serveur, un `null` de premier niveau est FILTRÉ hors du patch, sauf pour
/// `historique_max_messages`. Vider le prompt se fait avec `""`, pas avec
/// `null` — la chaîne vide EST le prompt vide.
public struct MajReglages: Sendable, Encodable, Equatable {
    public var promptSysteme: String?
    public var parametres: MajParametres?
    /// Le seul champ de premier niveau que le serveur accepte d'effacer
    /// (`_CHAMPS_EFFACABLES`). `nul` = historique complet.
    public var historiqueMaxMessages: ChampPatch<Int>

    public init(
        promptSysteme: String? = nil,
        parametres: MajParametres? = nil,
        historiqueMaxMessages: ChampPatch<Int> = .absent
    ) {
        self.promptSysteme = promptSysteme
        self.parametres = parametres
        self.historiqueMaxMessages = historiqueMaxMessages
    }

    private enum Cle: String, CodingKey {
        case promptSysteme, parametres, historiqueMaxMessages
    }

    public func encode(to encodeur: any Encoder) throws {
        var conteneur = encodeur.container(keyedBy: Cle.self)
        try conteneur.encodeIfPresent(promptSysteme, forKey: .promptSysteme)
        try conteneur.encodeIfPresent(parametres, forKey: .parametres)
        try conteneur.encoder(historiqueMaxMessages, pour: .historiqueMaxMessages)
    }
}
