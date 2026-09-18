// Six cellules pour six chiffres. Le champ système reste invisible et porte le
// clavier ; les cellules montrent ce qu'il contient, chiffre par chiffre —
// c'est ainsi qu'on compare avec l'écran du PC.
//
// `☠` L'apparition d'un chiffre est le seul mouvement de la feuille : il se
// pose (échelle 0,7 → 1, fondu), il ne surgit pas. Rien d'autre ne bouge.
#if canImport(SwiftUI)
import DuplexNoyau
import SwiftUI
import Systeme

struct ChampCode: View {
    @Binding var code: String
    /// Faux pendant la vérification : les cellules s'éteignent et le clavier ne
    /// change plus rien.
    let actif: Bool
    @FocusState private var enFocus: Bool

    var body: some View {
        ZStack {
            champInvisible
            HStack(spacing: Grille.serre) {
                ForEach(0..<Cadence.longueurCode, id: \.self) { rang in
                    cellule(rang)
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture { enFocus = true }
        .onAppear { enFocus = true }
        .onChange(of: code) { _, nouveau in nettoyer(nouveau) }
        .animation(Mouvement.micro, value: code)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Code de jumelage, \(code.count) chiffres sur \(Cadence.longueurCode)")
    }

    /// Le champ qui tient le clavier. Invisible, mais bien là : c'est lui que le
    /// focus programmatique atteint et que la saisie automatique de code remplit.
    private var champInvisible: some View {
        TextField("", text: $code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($enFocus)
            .disabled(!actif)
            .frame(width: 1, height: 1)
            .opacity(0)
            .accessibilityHidden(true)
    }

    private func cellule(_ rang: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous)
                .fill(Neutre.surfaceHaute)
            RoundedRectangle(cornerRadius: Rayon.controle, style: .continuous)
                .strokeBorder(rang == rangCourant ? Teinte.accent : Neutre.lumiereBasse, lineWidth: Grille.trait)
            if let chiffre = chiffre(rang) {
                Text(chiffre)
                    .font(Voix.code)
                    .foregroundStyle(Neutre.encre)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Trame.cellule)
        .opacity(actif ? 1 : 0.5)
        .animation(Mouvement.normal, value: actif)
    }

    // MARK: - Lecture du code

    private func chiffre(_ rang: Int) -> String? {
        guard rang < code.count else { return nil }
        return String(code[code.index(code.startIndex, offsetBy: rang)])
    }

    /// La cellule qui attend le prochain chiffre ; aucune quand le code est plein.
    private var rangCourant: Int? {
        guard actif, enFocus, code.count < Cadence.longueurCode else { return nil }
        return code.count
    }

    /// Le champ ne garde que des chiffres, et jamais plus de six : la machine
    /// refuserait un code mal formé sans rien dire, et Chris croirait avoir
    /// tapé juste.
    private func nettoyer(_ nouveau: String) {
        let propre = String(nouveau.filter(\.isNumber).prefix(Cadence.longueurCode))
        if propre != nouveau { code = propre }
    }
}
#endif
