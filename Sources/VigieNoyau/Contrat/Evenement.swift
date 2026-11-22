import Foundation

// Un événement du fil d'une session (miroir de `Evenement` dans `commun/session.ts`). Décodé sur le champ `type`.
// Tolérant : un type inconnu, ou un type connu mal formé, devient `.inconnu` au lieu de faire échouer tout le fil.

public enum Evenement: Sendable, Equatable {
    case message(texte: String, uuid: String?, auteur: String?)
    case texte(texte: String, agent: String?)
    case reflexion(texte: String, agent: String?)
    case outil(id: String, nom: String, resume: String, detail: String, agent: String?)
    case resultatOutil(outilId: String, extrait: String, erreur: Bool, agent: String?)
    case sousAgent(id: String, description: String, modele: String, genre: String)
    case taches([TacheFil])
    case dialogueResolu(dialogue: Dialogue, reponses: [String]?, decision: String?)
    case etape(resume: String, suite: String)
    case objectifAtteint(bilan: String)
    case question(question: String)
    case compaction(avant: Int, apres: Int, declencheur: String)
    case relance(raison: String)
    case tourFini(dureeMs: Int, contexte: Int, entree: Int?, sortie: Int?, coutUsd: Double?)
    case fichiersTour(tour: String, fichiers: [FichierModifie])
    case tourAnnule(tour: String)
    case image(fichier: String, nom: String, mime: String, taille: Int, origine: String, agent: String?)
    case fichier(fichier: String, nom: String, mime: String, taille: Int, legende: String?)
    case relais(sens: String, session: String, titre: String, texte: String)
    case erreur(message: String)
    case inconnu(type: String)
}

/// Une ligne de la liste de tâches (TodoWrite) : `attente`, `en_cours` ou `fait`.
public struct TacheFil: Sendable, Equatable, Decodable {
    public enum Etat: String, Sendable, Equatable {
        case attente, enCours = "en_cours", fait
    }

    public let contenu: String
    public let etat: Etat

    public init(contenu: String, etat: Etat) {
        self.contenu = contenu
        self.etat = etat
    }

    private enum CodingKeys: String, CodingKey { case contenu, etat }

    public init(from decodeur: Decoder) throws {
        let c = try decodeur.container(keyedBy: CodingKeys.self)
        contenu = try c.decode(String.self, forKey: .contenu)
        let brut = c.facultatif(String.self, .etat) ?? ""
        etat = Etat(rawValue: brut) ?? .attente
    }
}

extension Evenement: Decodable {
    fileprivate enum Cle: String, CodingKey {
        case type, texte, agent, id, nom, resume, detail, outilId, extrait, erreur, description, modele, genre
        case suite, bilan, question, avant, apres, declencheur, raison, dureeMs, contexte, message
        case uuid, auteur, taches, dialogue, reponses, decision, entree, sortie, coutUsd
        case tour, fichiers, fichier, mime, taille, origine, legende, sens, session, titre
    }

    private typealias Conteneur = KeyedDecodingContainer<Cle>

    public init(from decodeur: Decoder) throws {
        guard let c = try? decodeur.container(keyedBy: Cle.self) else {
            self = .inconnu(type: "")
            return
        }
        let type = (try? c.decode(String.self, forKey: .type)) ?? ""
        let trouve: Evenement? = (try? Self.contenu(type, c)) ?? (try? Self.dialogues(type, c))
        self = trouve ?? (try? Self.jalon(type, c)) ?? .inconnu(type: type)
    }

    /// Le fil de messages et d'outils ; `nil` si le type n'est pas de ce groupe.
    private static func contenu(_ type: String, _ c: Conteneur) throws -> Evenement? {
        switch type {
        case "message":
            return .message(texte: try c.decode(String.self, forKey: .texte), uuid: c.facultatif(String.self, .uuid),
                            auteur: c.facultatif(String.self, .auteur))
        case "texte":
            return .texte(texte: try c.decode(String.self, forKey: .texte), agent: c.facultatif(String.self, .agent))
        case "reflexion":
            return .reflexion(texte: try c.decode(String.self, forKey: .texte),
                              agent: c.facultatif(String.self, .agent))
        case "outil":
            return .outil(id: try c.decode(String.self, forKey: .id), nom: try c.decode(String.self, forKey: .nom),
                          resume: try c.decode(String.self, forKey: .resume),
                          detail: try c.decode(String.self, forKey: .detail), agent: c.facultatif(String.self, .agent))
        case "resultat_outil":
            return .resultatOutil(outilId: try c.decode(String.self, forKey: .outilId),
                                  extrait: try c.decode(String.self, forKey: .extrait),
                                  erreur: try c.decode(Bool.self, forKey: .erreur),
                                  agent: c.facultatif(String.self, .agent))
        case "sous_agent":
            return .sousAgent(id: try c.decode(String.self, forKey: .id),
                              description: try c.decode(String.self, forKey: .description),
                              modele: try c.decode(String.self, forKey: .modele),
                              genre: try c.decode(String.self, forKey: .genre))
        case "taches":
            let taches = try c.decode([Tolere<TacheFil>].self, forKey: .taches).compactMap(\.valeur)
            return .taches(taches)
        default:
            return nil
        }
    }

    /// Dialogues résolus, présentation (fichiers, images) et relais ; `nil` si le type n'est pas de ce groupe.
    private static func dialogues(_ type: String, _ c: Conteneur) throws -> Evenement? {
        switch type {
        case "dialogue_resolu":
            return .dialogueResolu(dialogue: try c.decode(Dialogue.self, forKey: .dialogue),
                                   reponses: c.facultatif([String].self, .reponses),
                                   decision: c.facultatif(String.self, .decision))
        case "fichiers_tour":
            let fichiers = try c.decode([Tolere<FichierModifie>].self, forKey: .fichiers).compactMap(\.valeur)
            return .fichiersTour(tour: try c.decode(String.self, forKey: .tour), fichiers: fichiers)
        case "tour_annule":
            return .tourAnnule(tour: try c.decode(String.self, forKey: .tour))
        case "image":
            return .image(fichier: try c.decode(String.self, forKey: .fichier),
                          nom: try c.decode(String.self, forKey: .nom),
                          mime: try c.decode(String.self, forKey: .mime), taille: try c.entier(.taille),
                          origine: try c.decode(String.self, forKey: .origine),
                          agent: c.facultatif(String.self, .agent))
        case "fichier":
            return .fichier(fichier: try c.decode(String.self, forKey: .fichier),
                            nom: try c.decode(String.self, forKey: .nom),
                            mime: try c.decode(String.self, forKey: .mime), taille: try c.entier(.taille),
                            legende: c.facultatif(String.self, .legende))
        case "relais":
            return .relais(sens: try c.decode(String.self, forKey: .sens),
                           session: try c.decode(String.self, forKey: .session),
                           titre: try c.decode(String.self, forKey: .titre),
                           texte: try c.decode(String.self, forKey: .texte))
        default:
            return nil
        }
    }

    /// Jalons de session (étapes, fin de tour, compaction, erreur) ; `nil` si le type n'est pas de ce groupe.
    private static func jalon(_ type: String, _ c: Conteneur) throws -> Evenement? {
        switch type {
        case "etape":
            return .etape(resume: try c.decode(String.self, forKey: .resume),
                          suite: try c.decode(String.self, forKey: .suite))
        case "objectif_atteint":
            return .objectifAtteint(bilan: try c.decode(String.self, forKey: .bilan))
        case "question":
            return .question(question: try c.decode(String.self, forKey: .question))
        case "compaction":
            return .compaction(avant: try c.entier(.avant), apres: try c.entier(.apres),
                               declencheur: try c.decode(String.self, forKey: .declencheur))
        case "relance":
            return .relance(raison: try c.decode(String.self, forKey: .raison))
        case "tour_fini":
            return .tourFini(dureeMs: try c.entier(.dureeMs), contexte: try c.entier(.contexte),
                             entree: c.entierFacultatif(.entree), sortie: c.entierFacultatif(.sortie),
                             coutUsd: c.facultatif(Double.self, .coutUsd))
        case "erreur":
            return .erreur(message: try c.decode(String.self, forKey: .message))
        default:
            return nil
        }
    }
}

public struct EvenementDate: Decodable, Sendable, Equatable, Identifiable {
    public let seq: Int
    public let sessionId: String
    public let ts: String
    public let evt: Evenement

    public var id: Int { seq }

    public init(seq: Int, sessionId: String, ts: String, evt: Evenement) {
        self.seq = seq
        self.sessionId = sessionId
        self.ts = ts
        self.evt = evt
    }
}
