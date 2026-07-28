import Foundation

/// Génère les mots de passe de partage lisibles à voix haute,
/// au format « mot-mot-nombre-mot » (ex. « corail-lampe-92-nuit »).
enum PassphraseGenerator {
    static let words: [String] = [
        "corail", "lampe", "nuit", "sable", "plume", "orage", "menthe", "fjord",
        "tigre", "lune", "pomme", "brise", "cactus", "delta", "ecume", "figue",
        "givre", "houle", "iris", "jade", "kiwi", "lotus", "mangue", "nacre",
        "ocre", "pavot", "quartz", "roseau", "safran", "tulipe", "vague", "zenith",
        "amande", "bison", "cedre", "dune", "erable", "flamme", "galet", "heron",
    ]

    static func generate(using generator: inout some RandomNumberGenerator) -> String {
        let w1 = words.randomElement(using: &generator)!
        let w2 = words.randomElement(using: &generator)!
        let number = Int.random(in: 10...99, using: &generator)
        let w3 = words.randomElement(using: &generator)!
        return "\(w1)-\(w2)-\(number)-\(w3)"
    }

    static func generate() -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(using: &rng)
    }
}
