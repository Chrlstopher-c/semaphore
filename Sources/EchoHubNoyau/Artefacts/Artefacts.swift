import Foundation

/// Une version d'artefact (`creer_artefact`), relue dans la sortie persistée de l'appel (`detection.ts` du web).
public struct VersionArtefact: Sendable, Equatable, Hashable {
    public let artefactId: String
    public let version: Int
    public let titre: String
    /// `html`, `markdown`, `code`, `svg`, `mermaid` ; `inconnu` hors liste (affiché en texte brut).
    public let type: String
    public let langage: String?
    public let fichierId: String
    public let tailleOctets: Int

    /// Seuls HTML, SVG et Markdown se rendent ; le reste se lit en code.
    public var apercuPossible: Bool { ["html", "svg", "markdown"].contains(type) }
}

/// Un fichier présenté par l'agent (`presenter_fichier`).
public struct FichierPresente: Sendable, Equatable, Hashable {
    public let fichierId: String
    public let nomAffiche: String
    public let typeMime: String
    public let tailleOctets: Int

    public var estImage: Bool { typeMime.hasPrefix("image/") }
    public var estHtml: Bool { typeMime == "text/html" || nomAffiche.lowercased().hasSuffix(".html") }
}

/// Toutes les versions d'un même artefact, la dernière donnant titre et type.
public struct ArtefactCatalogue: Sendable, Equatable, Identifiable {
    public var id: String { artefactId }
    public let artefactId: String
    public let titre: String
    public let type: String
    public let versions: [VersionArtefact]
}

public enum Artefacts {
    static let creation: Set<String> = ["creer_artefact", "create_artifact"]
    static let presentation: Set<String> = ["presenter_fichier", "show_file"]
    static let types: Set<String> = ["html", "markdown", "code", "svg", "mermaid"]

    public static func version(_ appel: AppelLisible) -> VersionArtefact? {
        guard creation.contains(appel.nom), appel.etat == .termine, let objet = json(appel.sortie),
              let artefactId = objet["artefact_id"] as? String, let fichierId = objet["fichier_id"] as? String,
              let titre = (objet["titre"] ?? objet["title"]) as? String,
              let version = objet["version"] as? Int, version >= 1,
              let taille = objet["taille_octets"] as? Int
        else { return nil }
        let type = objet["type"] as? String ?? ""
        return VersionArtefact(
            artefactId: artefactId, version: version, titre: titre, type: types.contains(type) ? type : "inconnu",
            langage: (objet["langage"] ?? objet["language"]) as? String, fichierId: fichierId, tailleOctets: taille
        )
    }

    public static func presente(_ appel: AppelLisible) -> FichierPresente? {
        guard presentation.contains(appel.nom), appel.etat == .termine, let objet = json(appel.sortie),
              let fichierId = objet["fichier_id"] as? String, let nom = objet["nom_affiche"] as? String,
              let mime = objet["type_mime"] as? String, let taille = objet["taille_octets"] as? Int
        else { return nil }
        return FichierPresente(fichierId: fichierId, nomAffiche: nom, typeMime: mime, tailleOctets: taille)
    }

    /// Le catalogue du fil affiché (réponses de l'assistant + brouillon en cours), par ordre d'apparition.
    /// Un rejeu qui réémet le même numéro remplace l'ancien : c'est le dernier que le serveur a retenu.
    public static func catalogue(_ contenus: [String]) -> [ArtefactCatalogue] {
        var ordre: [String] = []
        var parArtefact: [String: [VersionArtefact]] = [:]
        for contenu in contenus {
            for segment in SegmenteurReponse.segmenter(contenu).raisonnements where segment.convention == "outil" {
                guard let appel = LectureAppel.lire(segment.texte, actif: false), let version = version(appel) else { continue }
                if parArtefact[version.artefactId] == nil { ordre.append(version.artefactId) }
                parArtefact[version.artefactId, default: []].removeAll { $0.version == version.version }
                parArtefact[version.artefactId, default: []].append(version)
            }
        }
        return ordre.compactMap { id in
            let versions = (parArtefact[id] ?? []).sorted { $0.version < $1.version }
            guard let derniere = versions.last else { return nil }
            return ArtefactCatalogue(artefactId: id, titre: derniere.titre, type: derniere.type, versions: versions)
        }
    }

    /// Un SVG seul s'affiche centré sur fond neutre, comme `pageSvg` du web.
    public static func pageSvg(_ svg: String) -> String {
        "<!doctype html><html><head><meta name=\"viewport\" content=\"width=device-width\"><style>html,body{margin:0;height:100%;display:flex;align-items:center;justify-content:center;background:#fff}svg{max-width:100%;max-height:100%}</style></head><body>\(svg)</body></html>"
    }

    private static func json(_ texte: String) -> [String: Any]? {
        guard let donnees = texte.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: donnees)) as? [String: Any]
    }
}

extension ClientEchoHub {
    /// Le contenu brut d'un fichier de conversation (`GET fichiers/{id}`) : artefact ou fichier présenté.
    public func contenuFichier(_ id: String) async throws -> Data {
        try await brut("GET", "fichiers/\(id)")
    }
}
