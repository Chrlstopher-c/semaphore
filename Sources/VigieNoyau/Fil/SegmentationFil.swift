import Foundation

/// Découpe la suite plate d'évènements en segments affichables.
///
/// Logique PURE, et c'est délibéré : c'est le cœur de lisibilité du fil, et
/// c'est la seule partie qu'on peut éprouver sur Arch sans téléphone.
///
/// `☠` Les règles viennent du front éprouvé en production
/// (`harness-orchestrateur.js`), pas d'une reconstruction : chacune corrige un
/// défaut mesuré à l'écran. En particulier — une PAROLE ferme la rafale
/// d'outils, une RÉFLEXION ne la ferme pas. Penser entre deux appels est le
/// cours normal d'une séquence ; reprendre la parole, non.
public enum SegmentationFil {

    public static func segmenter(_ evenements: [EvenementApi]) -> [SegmentFil] {
        var constructeur = Constructeur()
        for evenement in ordonner(evenements) {
            constructeur.absorber(evenement)
        }
        constructeur.clore()
        return constructeur.segments
    }

    /// Tri par curseur et dédoublonnage sur le dernier état connu.
    ///
    /// `☠` Un appel d'outil revient avec le MÊME `seq` une fois son résultat
    /// arrivé. Garder la première occurrence figerait tous les outils du fil sur
    /// « résultat en attente », pour toujours.
    static func ordonner(_ evenements: [EvenementApi]) -> [EvenementApi] {
        var parSeq: [Int: EvenementApi] = [:]
        for evenement in evenements { parSeq[evenement.seq] = evenement }
        return parSeq.values.sorted { $0.seq < $1.seq }
    }
}

/// L'état d'un découpage en cours.
struct Constructeur {
    var segments: [SegmentFil] = []
    private var blocs: [BlocAgent] = []
    private var modele: String?
    private var effort: String?
    /// Position, dans `blocs`, de la rafale d'outils encore ouverte.
    /// `☠` Un INDEX et non une liste à part : la rafale garde la place où elle a
    /// commencé, même si une réflexion s'écrit après elle. C'est ce qui évite
    /// qu'un tour à huit appels se lise en huit lignes séparées.
    private var rafale: Int?

    mutating func absorber(_ evenement: EvenementApi) {
        switch evenement.type {
        case .operateur: poserOperateur(evenement)
        case .resultat: clore()
        case .mandat: poserSeul(.mandat(seq: evenement.seq, proposition: evenement.contenu, at: evenement.at))
        case .compaction: poserSeul(.compaction(seq: evenement.seq, resume: evenement.contenu, at: evenement.at))
        case .outil: poserOutil(evenement)
        case .texte: poserParole(evenement)
        case .reflexion: poserBloc(.reflexion(seq: evenement.seq, texte: evenement.contenu, at: evenement.at), evenement)
        case .erreur: poserBloc(.echec(seq: evenement.seq, texte: evenement.contenu, at: evenement.at), evenement)
        case .notification: poserBloc(.fait(seq: evenement.seq, texte: nettoyerFait(evenement.contenu), at: evenement.at), evenement)
        case .artefact: poserBloc(.artefact(seq: evenement.seq, piece: evenement.pieces.first, at: evenement.at), evenement)
        default: poserBloc(.fait(seq: evenement.seq, texte: evenement.contenu, at: evenement.at), evenement)
        }
    }

    /// Ferme le tour en cours et le pousse. Idempotent : appelé sur chaque
    /// césure du fil, y compris quand il n'y a rien à fermer.
    mutating func clore() {
        rafale = nil
        guard !blocs.isEmpty else {
            modele = nil
            effort = nil
            return
        }
        segments.append(.tour(TourAgent(blocs: blocs, modele: modele, effort: effort)))
        blocs = []
        modele = nil
        effort = nil
    }

    // MARK: - Poses

    private mutating func poserOperateur(_ evenement: EvenementApi) {
        clore()
        segments.append(.operateur(MessageOperateur(
            seq: evenement.seq,
            texte: evenement.contenu,
            pieces: evenement.pieces,
            at: evenement.at
        )))
    }

    private mutating func poserSeul(_ segment: SegmentFil) {
        clore()
        segments.append(segment)
    }

    private mutating func poserParole(_ evenement: EvenementApi) {
        // L'agent reprend la parole ⇒ la rafale d'outils est finie.
        rafale = nil
        poserBloc(.parole(seq: evenement.seq, texte: evenement.contenu, at: evenement.at), evenement)
    }

    private mutating func poserBloc(_ bloc: BlocAgent, _ evenement: EvenementApi) {
        attribuer(evenement)
        blocs.append(bloc)
    }

    private mutating func poserOutil(_ evenement: EvenementApi) {
        attribuer(evenement)
        let appel = AppelOutil(
            seq: evenement.seq,
            nom: evenement.contenu,
            detail: evenement.detail,
            resultat: evenement.resultat,
            at: evenement.at
        )
        guard let position = rafale, case .outils(let groupe) = blocs[position] else {
            blocs.append(.outils(GroupeOutils(appels: [appel])))
            rafale = blocs.count - 1
            return
        }
        blocs[position] = .outils(GroupeOutils(appels: groupe.appels + [appel]))
    }

    /// L'attribution du tour est celle du PREMIER bloc qui en porte une.
    private mutating func attribuer(_ evenement: EvenementApi) {
        guard modele == nil, let porte = evenement.model else { return }
        modele = porte
        effort = evenement.effort
    }

    /// Un fait du harness arrive préfixé. Le préfixe est une adresse technique,
    /// pas du contenu : le garder à l'écran ferait lire « [HARNESS] » à chaque
    /// fin d'équipe.
    private func nettoyerFait(_ contenu: String) -> String {
        guard contenu.hasPrefix("[HARNESS]") else { return contenu }
        return String(contenu.dropFirst("[HARNESS]".count)).trimmingCharacters(in: .whitespaces)
    }
}
