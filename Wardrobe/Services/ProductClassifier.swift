import Foundation

/// Keyword heuristics that turn product text (name, description, material)
/// into closet fields. Deterministic and offline; the user confirms the result.
enum ProductClassifier {
    struct Result {
        var category: ClothingCategory
        var formality: Int
        var warmth: Warmth
        var fit: Fit
        var isPatterned: Bool
    }

    static func classify(name: String, description: String = "", material: String = "") -> Result {
        let nameTokens = tokens(name)
        let allTokens = nameTokens.union(tokens(description)).union(tokens(material))

        // Category comes from the product name first (descriptions mention other garments).
        let category = category(from: nameTokens) ?? category(from: allTokens) ?? .top

        var formality: Int
        switch category {
        case .outerwear, .dress: formality = 3
        default: formality = 2
        }
        let formalHits = formalWords.intersection(allTokens).count
        let casualHits = casualWords.intersection(allTokens).count
        formality += min(formalHits, 2) - min(casualHits, 2)
        formality = min(5, max(1, formality))

        let warmth: Warmth
        if !heavyWords.isDisjoint(with: allTokens) {
            warmth = .heavy
        } else if !lightWords.isDisjoint(with: allTokens) {
            warmth = .light
        } else {
            warmth = .medium
        }

        let fit: Fit
        if !relaxedWords.isDisjoint(with: allTokens) {
            fit = .relaxed
        } else if !fittedWords.isDisjoint(with: allTokens) {
            fit = .fitted
        } else {
            fit = .regular
        }

        return Result(
            category: category,
            formality: formality,
            warmth: warmth,
            fit: fit,
            isPatterned: !patternWords.isDisjoint(with: nameTokens.union(tokens(description)))
        )
    }

    /// Maps color words ("Charcoal", "Off White", "01 BLACK") to the app's palette.
    static func color(from text: String) -> ClothingColor? {
        for word in tokens(text, keepPlurals: true) {
            if let match = colorSynonyms[word] { return match }
        }
        return nil
    }

    // MARK: - Tokenizing

    private static func tokens(_ text: String, keepPlurals: Bool = false) -> Set<String> {
        var lowered = text.lowercased()
        // Phrases whose words would otherwise be misread.
        let phrases = [
            "short sleeve": "shortsleeve", "short-sleeve": "shortsleeve",
            "dress pant": "pant dressy", "dress shirt": "shirt dressy",
            "dress shoe": "shoe dressy", "dress sock": "sock dressy",
            "off white": "white", "off-white": "white",
            "button-down": "buttondown", "button down": "buttondown", "button-up": "buttonup", "button up": "buttonup",
            "tie-dye": "tiedye", "tie dye": "tiedye",
        ]
        for (phrase, replacement) in phrases {
            lowered = lowered.replacingOccurrences(of: phrase, with: replacement)
        }
        let words = lowered.split { !$0.isLetter }.map(String.init)
        var result = Set(words)
        if !keepPlurals {
            for word in words where word.count > 3 && word.hasSuffix("s") {
                result.insert(String(word.dropLast()))
            }
        }
        return result
    }

    private static func category(from tokens: Set<String>) -> ClothingCategory? {
        for (category, words) in categoryWords where !words.isDisjoint(with: tokens) {
            return category
        }
        return nil
    }

    // Order matters: first match wins.
    private static let categoryWords: [(ClothingCategory, Set<String>)] = [
        (.shoes, ["shoe", "sneaker", "loafer", "boot", "sandal", "derby", "trainer", "slipper", "mule"]),
        (.accessory, ["belt", "scarf", "hat", "cap", "bag", "tie", "watch", "sock", "glove", "sunglass", "beanie", "wallet"]),
        (.dress, ["dress", "jumpsuit", "romper", "gown"]),
        (.outerwear, ["jacket", "coat", "blazer", "parka", "cardigan", "vest", "trench", "bomber", "windbreaker", "puffer", "overcoat", "anorak"]),
        (.bottom, ["pant", "trouser", "jean", "short", "skirt", "chino", "jogger", "legging", "slack", "sweatpant", "culotte"]),
        (.top, ["shirt", "tee", "polo", "sweater", "sweatshirt", "hoodie", "blouse", "tank", "knit", "henley", "turtleneck", "top", "pullover", "jersey", "shortsleeve"]),
    ]

    private static let formalWords: Set<String> = [
        "blazer", "suit", "tailored", "dressy", "oxford", "loafer", "derby", "trouser",
        "slack", "pleated", "silk", "buttondown", "buttonup", "tuxedo", "wool", "cashmere", "satin",
    ]
    private static let casualWords: Set<String> = [
        "tee", "graphic", "hoodie", "sweatshirt", "sweatpant", "jogger", "legging", "short",
        "tank", "sneaker", "fleece", "lounge", "athletic", "running", "sport", "jersey", "denim", "jean",
    ]
    private static let heavyWords: Set<String> = [
        "wool", "flannel", "cashmere", "fleece", "down", "puffer", "parka", "corduroy",
        "tweed", "thermal", "sherpa", "insulated", "padded", "overcoat",
    ]
    private static let lightWords: Set<String> = [
        "linen", "seersucker", "mesh", "tank", "short", "sandal", "airism", "lightweight",
        "breathable", "shortsleeve",
    ]
    private static let relaxedWords: Set<String> = [
        "wide", "relaxed", "oversized", "loose", "baggy", "boxy", "barrel", "balloon", "flared",
    ]
    private static let fittedWords: Set<String> = [
        "slim", "skinny", "fitted", "tight", "bodycon", "stretch",
    ]
    private static let patternWords: Set<String> = [
        "stripe", "striped", "plaid", "check", "checked", "checkered", "gingham", "floral",
        "print", "printed", "patterned", "graphic", "polka", "houndstooth", "camo", "camouflage", "paisley", "tartan", "tiedye",
    ]

    private static let colorSynonyms: [String: ClothingColor] = [
        "black": .black, "jet": .black,
        "white": .white, "ivory": .white,
        "grey": .grey, "gray": .grey, "charcoal": .grey, "silver": .grey, "heather": .grey,
        "navy": .navy, "midnight": .navy,
        "beige": .beige, "cream": .beige, "khaki": .beige, "tan": .beige, "stone": .beige,
        "sand": .beige, "camel": .beige, "oatmeal": .beige, "taupe": .beige, "natural": .beige,
        "brown": .brown, "chocolate": .brown, "espresso": .brown, "coffee": .brown, "mocha": .brown,
        "red": .red, "burgundy": .red, "maroon": .red, "wine": .red,
        "orange": .orange, "rust": .orange, "terracotta": .orange,
        "yellow": .yellow, "mustard": .yellow, "gold": .yellow,
        "green": .green, "emerald": .green, "mint": .green, "forest": .green, "sage": .green,
        "olive": .olive, "army": .olive,
        "blue": .blue, "cobalt": .blue, "sky": .blue, "teal": .blue, "indigo": .blue,
        "purple": .purple, "lavender": .purple, "violet": .purple, "plum": .purple,
        "pink": .pink, "rose": .pink, "blush": .pink,
    ]
}
