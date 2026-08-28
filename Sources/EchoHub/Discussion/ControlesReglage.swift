// Les deux contrôles de l'écran de réglages : un curseur mesuré, et un champ
// qui a le droit de n'être pas posé.
//
// Ils vivent ici et pas dans `Charte/` : la charte porte ce qui est commun à
// toute l'app, et ces deux-là ne servent qu'à régler une conversation.
#if canImport(SwiftUI)
import SwiftUI

/// Un réglage continu, avec sa valeur lue à chasse fixe — sinon la largeur du
/// nombre danse à chaque cran et l'œil suit le chiffre au lieu du curseur.
struct CurseurReglage: View {
    private let titre: String
    private let valeur: Binding<Double>
    private let plage: ClosedRange<Double>
    private let pas: Double
    private let detail: String

    init(
        _ titre: String, valeur: Binding<Double>,
        plage: ClosedRange<Double>, pas: Double, detail: String
    ) {
        self.titre = titre
        self.valeur = valeur
        self.plage = plage
        self.pas = pas
        self.detail = detail
    }

    var body: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.serre) {
                HStack {
                    Text(titre).mention().foregroundStyle(Teinte.encre)
                    Spacer(minLength: 0)
                    Text(lecture).mesure().foregroundStyle(Teinte.encreDouce)
                }
                Slider(value: valeur, in: plage, step: pas)
                    .tint(Teinte.accent)
                Text(detail).legende().foregroundStyle(Teinte.encreEteinte)
            }
        }
    }

    /// Un pas entier s'affiche entier : « 40 », pas « 40,00 ».
    private var lecture: String {
        let texte = pas >= 1
            ? String(Int(valeur.wrappedValue.rounded()))
            : String(format: "%.2f", valeur.wrappedValue)
        return texte.replacingOccurrences(of: ".", with: ",")
    }
}

/// Un réglage entier qui a le droit d'être ABSENT, et dont l'absence est un
/// réglage à part entière.
///
/// `☠` L'interrupteur ne masque pas le champ, il le désactive : « aucun
/// plafond » et « plafond de 2048 » sont deux décisions, et voir la valeur
/// qu'on retrouvera en rallumant évite de la retaper.
struct ChampFacultatif: View {
    private let titre: String
    private let absent: String
    private let valeur: Binding<Int?>
    private let defaut: Int
    private let detail: String
    /// La saisie est un état LOCAL et pas une projection de `valeur` : sans ça,
    /// effacer le dernier chiffre fait réapparaître l'ancien nombre sous le
    /// doigt, et le champ devient impossible à vider pour le retaper.
    @State private var saisie = ""

    init(
        _ titre: String, absent: String, valeur: Binding<Int?>, defaut: Int, detail: String
    ) {
        self.titre = titre
        self.absent = absent
        self.valeur = valeur
        self.defaut = defaut
        self.detail = detail
    }

    var body: some View {
        Panneau {
            VStack(alignment: .leading, spacing: Trame.serre) {
                entete
                ligneSaisie
                Text(detail).legende().foregroundStyle(Teinte.encreEteinte)
            }
        }
        .onAppear { saisie = valeur.wrappedValue.map(String.init) ?? "" }
        .onChange(of: saisie) { _, neuve in absorber(neuve) }
    }

    private var entete: some View {
        HStack {
            Text(titre).mention().foregroundStyle(Teinte.encre)
            Spacer(minLength: 0)
            Toggle(absent, isOn: liaisonPosee).labelsHidden().tint(Teinte.accent)
        }
    }

    /// `☠` L'interrupteur ne MASQUE pas le champ, il le désactive : « aucun
    /// plafond » et « plafond de 2048 » sont deux décisions, et voir la valeur
    /// qu'on retrouvera en rallumant évite de la retaper.
    private var ligneSaisie: some View {
        HStack(spacing: Trame.serre) {
            Text(valeur.wrappedValue == nil ? absent : "Valeur")
                .legende()
                .foregroundStyle(Teinte.encreDouce)
            Spacer(minLength: 0)
            TextField("—", text: $saisie)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .mesure()
                .foregroundStyle(Teinte.encre)
                .tint(Teinte.accent)
                .textFieldStyle(.plain)
                .disabled(valeur.wrappedValue == nil)
                .frame(maxWidth: Trame.souffle * 2)
        }
    }

    /// L'interrupteur dit « posé », pas « absent » : un interrupteur allumé qui
    /// signifierait une absence se lit à l'envers une fois sur deux.
    private var liaisonPosee: Binding<Bool> {
        Binding(
            get: { valeur.wrappedValue != nil },
            set: { pose in
                valeur.wrappedValue = pose ? (Int(saisie) ?? defaut) : nil
                if pose, saisie.isEmpty { saisie = String(defaut) }
            }
        )
    }

    /// Un champ vidé retombe sur le défaut CÔTÉ VALEUR sans réécrire la saisie :
    /// on peut donc effacer et retaper, et rien n'est jamais envoyé de vide.
    private func absorber(_ neuve: String) {
        let chiffres = String(neuve.filter(\.isNumber))
        if chiffres != neuve { saisie = chiffres }
        guard valeur.wrappedValue != nil else { return }
        valeur.wrappedValue = Int(chiffres) ?? defaut
    }
}
#endif
