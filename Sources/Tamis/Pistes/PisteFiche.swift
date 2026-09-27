// Le libellé, le symbole et l'explication de chaque piste. L'explication dit
// POURQUOI c'est proposé : une piste qu'on ne comprend pas, on ne la suit pas.
#if canImport(SwiftUI) && canImport(Photos)
import TamisNoyau

extension Piste {
    var titre: String {
        switch self {
        case .doublons: return "Doublons exacts"
        case .similaires: return "Photos similaires"
        case .rafales: return "Rafales"
        case .videosLourdes: return "Vidéos lourdes"
        case .captures: return "Captures d'écran"
        case .utilitaires: return "Documents et reçus"
        case .ratees: return "Photos ratées"
        case .videosFurtives: return "Vidéos accidentelles"
        }
    }

    var symbole: String {
        switch self {
        case .doublons: return "plus.square.on.square"
        case .similaires: return "square.on.square"
        case .rafales: return "square.stack.3d.forward.dottedline"
        case .videosLourdes: return "film.stack"
        case .captures: return "rectangle.dashed"
        case .utilitaires: return "doc.text.viewfinder"
        case .ratees: return "camera.metering.unknown"
        case .videosFurtives: return "timer"
        }
    }

    var explication: String {
        switch self {
        case .doublons: return "Même fichier importé plusieurs fois. On en garde un."
        case .similaires: return "Prises à quelques minutes d'écart et presque identiques. On garde la meilleure."
        case .rafales: return "Toutes les images d'une rafale. On garde celle que Photos a choisie."
        case .videosLourdes: return "Plus de 200 Mo chacune : le plus gros gain par geste."
        case .captures: return "Utiles un jour, rarement après."
        case .utilitaires: return "Tickets, papiers, QR : repérés par Vision, sur l'iPhone."
        case .ratees: return "Floues, sombres ou de travers selon Vision. Un avis, pas une vérité."
        case .videosFurtives: return "Moins de trois secondes : souvent déclenchées par erreur."
        }
    }

    /// Vrai si la piste a besoin de l'analyse Vision pour exister.
    var demandeAnalyse: Bool {
        switch self {
        case .similaires, .utilitaires, .ratees: return true
        default: return false
        }
    }
}
#endif
