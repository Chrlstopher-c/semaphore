// swift-tools-version: 6.0

import PackageDescription

// Echo : le centre de contrôle. Deux applications entières — Vigie (ccremote)
// et EchoHub Mobile (inférence locale) — assemblées derrière une seule coquille,
// un seul bundle, une seule signature hebdomadaire.
//
// `☠` Chaque application reste UN MODULE SWIFT ENTIER, charte comprise. Ce
// n'est pas de la paresse : leurs chartes portent les mêmes noms de fichiers
// (`Teinte`, `Typo`, `Trame`…) mais pas les mêmes jetons — sept couleurs
// communes sur vingt-cinq, deux styles de texte sur vingt-quatre. Ce sont deux
// directions artistiques, pas deux thèmes. Les fusionner reviendrait à refaire
// les deux apps. La frontière de module est ce qui fait tenir quinze types
// homonymes côte à côte sans qu'un seul fichier n'ait été renommé.
//
// Seul `Echo` importe les deux, et qualifie ce qu'il nomme (`Vigie.Coquille`).
let package = Package(
    name: "Echo",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        // xtool exige exactement un produit `.library` : c'est l'app.
        .library(name: "Echo", targets: ["Echo"]),
    ],
    targets: [
        // Les noyaux purs : aucun import SwiftUI ni UIKit, donc compilables et
        // testables sur Linux par `swift test`. Sans simulateur ni débogueur,
        // c'est la seule preuve automatique dont dispose ce projet.
        .target(name: "VigieNoyau"),
        .target(name: "EchoHubNoyau"),
        .target(name: "SailyNoyau"),
        .target(name: "DuplexNoyau"),
        .target(name: "TamisNoyau"),
        .target(name: "IrisNoyau"),
        // Le socle de design commun : neutres, sémantiques, typo, grille, galbes,
        // motion. UNE vérité pour tout ce qui doit être identique ; chaque monde
        // n'ajoute par-dessus que son accent. Tout est guardé `canImport(SwiftUI)`
        // — sur Linux il compile à vide, sans casser `swift test` des noyaux.
        .target(name: "Systeme"),
        .target(
            name: "Vigie",
            dependencies: ["VigieNoyau", "Systeme"]
        ),
        .target(
            name: "EchoHub",
            dependencies: ["EchoHubNoyau", "Systeme"],
            exclude: ["Charte/CHARTE.md"]
        ),
        .target(
            name: "Saily",
            dependencies: ["SailyNoyau", "Systeme"],
            exclude: ["Charte/CHARTE.md"]
        ),
        .target(
            name: "Duplex",
            dependencies: ["DuplexNoyau", "Systeme"],
            exclude: ["Charte/CHARTE.md"]
        ),
        .target(
            name: "Tamis",
            dependencies: ["TamisNoyau", "Systeme"],
            exclude: ["Charte/CHARTE.md"]
        ),
        .target(
            name: "Iris",
            dependencies: ["IrisNoyau", "Systeme"],
            exclude: ["Charte/CHARTE.md"]
        ),
        .target(
            name: "Echo",
            dependencies: ["Vigie", "EchoHub", "Saily", "Duplex", "Tamis", "Iris", "VigieNoyau", "Systeme"]
        ),
        .testTarget(name: "VigieNoyauTests", dependencies: ["VigieNoyau"], resources: [.copy("Echantillons")]),
        .testTarget(name: "EchoHubNoyauTests", dependencies: ["EchoHubNoyau"]),
        .testTarget(name: "SailyNoyauTests", dependencies: ["SailyNoyau"]),
        .testTarget(name: "DuplexNoyauTests", dependencies: ["DuplexNoyau"]),
        .testTarget(name: "TamisNoyauTests", dependencies: ["TamisNoyau"]),
        .testTarget(name: "IrisNoyauTests", dependencies: ["IrisNoyau"]),
    ]
)
