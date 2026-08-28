// Le fil lui-même : les messages établis, la réponse en train de s'écrire, et
// l'échec du dernier tour s'il y en a eu un.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

struct FilConversation: View {
    @Environment(Salon.self) private var salon
    /// La question en cours de réécriture. `nil` = pas d'édition ouverte.
    @State private var aModifier: MessageChat?
    @State private var texteModifie = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Trame.groupe) {
                if let prompt = salon.reglagesConversation?.promptSysteme, !prompt.isEmpty {
                    EnteteSysteme(texte: prompt)
                }
                ForEach(salon.messages) { message in
                    tour(message)
                }
                if let enCours = salon.enCours {
                    ReponseModele(texte: enCours.texte, actif: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let erreur = salon.erreurGeneration {
                    EchecDeTour(raison: erreur)
                }
            }
            .padding(.horizontal, Trame.ecran)
            .padding(.vertical, Trame.groupe)
        }
        // `☠` La règle la plus facile à casser d'une app de chat : un token qui
        // arrive ne doit jamais déplacer une ligne que Chris est en train de
        // lire. Cet ancrage garde le bas collé quand le contenu grandit ET
        // laisse la main dès que Chris a remonté le fil lui-même — contrairement
        // à un `scrollTo` forcé à chaque fragment, qui le ramènerait en bas
        // vingt fois par seconde pendant qu'il relit un raisonnement.
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        // Le seul geste qui relise le fil depuis le PC. Sans lui, le fil restait
        // figé sur ce que l'app avait elle-même observé — voir `Salon.recharger`.
        .refreshable { await salon.recharger() }
        .modifier(FeuilleModification(
            presentee: modificationPresentee, texte: $texteModifie, envoyer: modifier
        ))
    }

    private var modificationPresentee: Binding<Bool> {
        Binding(get: { aModifier != nil }, set: { if !$0 { aModifier = nil } })
    }

    private func ouvrirModification(_ message: MessageChat) {
        texteModifie = message.contenu
        aModifier = message
    }

    private func modifier() {
        guard let cible = aModifier else { return }
        salon.editer(cible, contenu: texteModifie)
        aModifier = nil
    }

    @ViewBuilder private func tour(_ message: MessageChat) -> some View {
        switch message.role {
        case .user:
            VStack(alignment: .trailing, spacing: Trame.fin) {
                BulleChris(texte: message.contenu)
                ActionsQuestion(message: message, surModification: ouvrirModification)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .assistant:
            VStack(alignment: .leading, spacing: Trame.serre) {
                ReponseModele(texte: message.contenu, actif: false)
                PiedDeReponse(message: message, aRelire: salon.aRelire.contains(message.id))
                ActionsReponse(message: message)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .system:
            // Un prompt système n'a rien à faire dans le fil : il se règle, il
            // ne se lit pas. Le serveur peut en renvoyer, l'écran l'ignore.
            EmptyView()
        }
    }
}

/// L'alerte de réécriture d'une question. Extraite du fil parce qu'elle n'a rien
/// à voir avec lui : c'est une saisie, pas un affichage.
struct FeuilleModification: ViewModifier {
    let presentee: Binding<Bool>
    @Binding var texte: String
    let envoyer: () -> Void

    func body(content: Content) -> some View {
        content.alert("Modifier la question", isPresented: presentee) {
            TextField("Question", text: $texte, axis: .vertical)
            Button("Envoyer", action: envoyer)
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("La question d'origine et sa réponse restent dans l'arbre : "
                + "une modification ouvre une branche sœur, elle n'efface rien.")
        }
    }
}

/// Le message de Chris. Une bulle, bornée à `Trame.bulleMax` : prise sur toute
/// la largeur, elle ne se distinguerait plus de la réponse du modèle, qui elle
/// n'a pas de bulle du tout.
struct BulleChris: View {
    let texte: String

    var body: some View {
        Text(texte)
            .corps()
            .foregroundStyle(Teinte.encre)
            .lineSpacing(Typo.interligneReponse)
            .textSelection(.enabled)
            .padding(.horizontal, Trame.bloc)
            .padding(.vertical, Trame.element)
            .frame(maxWidth: Trame.bulleMax, alignment: .leading)
            .background(Teinte.surface)
            .clipShape(.rect(cornerRadius: Galbe.carte, style: .continuous))
            .lisere()
    }
}

/// Les mesures d'un tour terminé. Affichées seulement quand le serveur les a
/// rapportées : aucune estimation n'est fabriquée pour combler le trou — c'est
/// la règle d'EchoHub v2, et elle vaut ici.
struct PiedDeReponse: View {
    let message: MessageChat
    /// L'app a cessé d'écouter sans que le serveur ait dit `fin`.
    let aRelire: Bool

    var body: some View {
        HStack(spacing: Trame.serre) {
            // `☠` Deux causes, deux mots. « Interrompu » n'est vrai que si le
            // SERVEUR l'affirme ; un flux qui se ferme sans `fin` — app
            // suspendue, réseau coupé — est une ignorance, pas un verdict. Le
            // PC, lui, a souvent fini la réponse et l'a persistée entière.
            if aRelire {
                Sceau("Peut-être incomplète — tire pour relire", symbole: "arrow.clockwise")
                    .ton(.alerte)
            } else if message.interrompu {
                Sceau("Interrompu", symbole: "exclamationmark.circle").ton(.alerte)
            }
            if let debit = message.tokensParSeconde {
                Text(String(format: "%.1f tok/s", debit).replacingOccurrences(of: ".", with: ","))
                    .mesureFine()
                    .foregroundStyle(Teinte.encreEteinte)
            }
            if let tokens = message.tokensGeneres {
                Text("\(tokens) tokens").mesureFine().foregroundStyle(Teinte.encreEteinte)
            }
        }
    }
}

/// Le prompt système posé sur cette conversation, replié.
///
/// `☠` Il ne se lit pas dans le fil — un prompt système n'est pas un tour — mais
/// il doit se VOIR. Une conversation dont le prompt a été posé au navigateur se
/// comportait « bizarrement » sur le téléphone, sans qu'aucun signe ne le dise.
/// Registre `note` : c'est un cheminement, pas ce que le modèle adresse à Chris.
struct EnteteSysteme: View {
    let texte: String
    @State private var ouvert = false

    var body: some View {
        VStack(alignment: .leading, spacing: Trame.serre) {
            Button {
                withAnimation(Elan.normal) { ouvert.toggle() }
            } label: {
                HStack(spacing: Trame.fin) {
                    Image(systemName: ouvert ? "chevron.down" : "chevron.right").imageScale(.small)
                    Text("Prompt système posé").legende()
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Teinte.encreDouce)
                .contentShape(.rect)
            }
            .buttonStyle(.appui)
            if ouvert {
                Text(texte)
                    .pensee()
                    .foregroundStyle(Teinte.encreDouce)
                    .lineSpacing(Typo.interligneNote)
                    .textSelection(.enabled)
                    .transition(.scene)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// L'échec du dernier tour, sous le fil. Distinct d'un état d'écran : une
/// génération ratée ne doit pas effacer la conversation déjà lue.
struct EchecDeTour: View {
    let raison: String

    var body: some View {
        Panneau {
            HStack(alignment: .top, spacing: Trame.element) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Teinte.panne)
                Text(raison).note().foregroundStyle(Teinte.encreDouce)
            }
        }
        .transition(.scene)
    }
}
#endif
