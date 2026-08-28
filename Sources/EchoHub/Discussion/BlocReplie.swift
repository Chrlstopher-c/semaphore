// Un bloc de cheminement : raisonnement, note de travail, appel du modèle, ou
// exécution d'un outil.
//
// `☠` Il ne disparaît jamais — c'est ce qu'on vient lire quand une réponse
// surprend — et il ne se dispute jamais l'œil avec la réponse. C'est tout le
// sujet du registre : ce bloc pose `note`, et rien à l'intérieur ne peut
// remonter en `reponse`.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct BlocReplie: View {
    let segment: SegmentRaisonnement
    let actif: Bool
    /// Ouvert sans que Chris ait touché : posé par `ReponseModele` sur le
    /// dernier bloc d'un tour muet — quand toute la réponse est restée en
    /// raisonnement, ce bloc est la seule chose à lire.
    var ouvertParDefaut = false

    /// `nil` tant que Chris n'a rien décidé : le bloc suit alors la règle
    /// automatique ci-dessous. Dès qu'il touche, son choix l'emporte et ne se
    /// fait plus reprendre par la machine.
    @State private var choix: Bool?

    private var deplie: Bool {
        // Un raisonnement en train de s'écrire est ouvert : c'est précisément ce
        // qu'on veut voir pendant que le modèle réfléchit. Une fois refermé, il
        // se replie tout seul et rend la place à la réponse.
        choix ?? ((actif && !segment.complet) || ouvertParDefaut)
    }

    var body: some View {
        if segment.convention == "outil", let appel = LectureAppel.lire(segment.texte, actif: actif) {
            CarteOutil(appel: appel, deplie: deplie, surBascule: basculer)
        } else {
            bloc
        }
    }

    private var bloc: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Button(action: basculer) { entete }
                .buttonStyle(.appui)
            if deplie {
                Text(segment.texte)
                    .registre(.note)
                    .selonRegistre()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.scene)
            }
        }
        .padding(Trame.element)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Teinte.surface)
        .clipShape(.rect(cornerRadius: Galbe.carte, style: .continuous))
        .animation(Elan.surface, value: deplie)
    }

    private var entete: some View {
        HStack(spacing: Trame.serre) {
            Image(systemName: symbole)
                .imageScale(.small)
                .foregroundStyle(actif && !segment.complet ? Teinte.accent : Teinte.encreEteinte)
            Text(Conventions.libelle(segment.convention)).rubrique()
            Spacer(minLength: 0)
            poids
            Image(systemName: "chevron.down")
                .imageScale(.small)
                .foregroundStyle(Teinte.encreEteinte)
                .rotationEffect(.degrees(deplie ? 0 : -90))
        }
        .contentShape(.rect)
    }

    /// Le poids du bloc, lisible sans le déplier : c'est lui qui répond à « ça
    /// vaut le coup d'ouvrir ? ». Pendant la génération, le compte grimpe avec
    /// les fragments — une mesure réelle, pas une animation.
    @ViewBuilder private var poids: some View {
        let mots = segment.texte.split(whereSeparator: \.isWhitespace).count
        if mots > 0 {
            Text(mots > 1 ? "\(mots) mots" : "1 mot")
                .mesureFine()
                .foregroundStyle(Teinte.encreEteinte)
        }
    }

    private var symbole: String {
        switch segment.convention {
        case "appel": return "curlybraces"
        case "etape": return "text.quote"
        default: return "brain"
        }
    }

    private func basculer() {
        withAnimation(Elan.surface) { choix = !deplie }
    }
}
#endif
