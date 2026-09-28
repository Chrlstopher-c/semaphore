// swift-tools-version:6.0

import PackageDescription

// SwiftTerm 1.20.0 (MIT, Miguel de Icaza), copié ici : son manifeste retire les sources Apple dès que l'HÔTE
// est Linux, ce qui les enlève aussi à la compilation croisée iOS de xtool. Ce manifeste-ci ne garde que la
// bibliothèque, sans le rendu Metal (shaders non compilables sous Linux ; le rendu CoreGraphics reste).
let package = Package(
    name: "SwiftTerm",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [.library(name: "SwiftTerm", targets: ["SwiftTerm"])],
    targets: [.target(name: "SwiftTerm", path: "Sources/SwiftTerm")],
    swiftLanguageModes: [.v5]
)
