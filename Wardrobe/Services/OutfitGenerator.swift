import Foundation

struct OutfitSuggestion: Identifiable {
    let id = UUID()
    let items: [ClothingItem]
    let score: Double
}

/// Rules-based outfit builder. Filters the closet to the occasion, assembles
/// complete outfits (top + bottom + shoes, or dress + shoes), and scores them.
/// An LLM can later pick/explain among the top results; the rules keep every
/// suggestion made only of real, compatible pieces.
enum OutfitGenerator {
    static func suggestions(
        for occasion: Occasion,
        from closet: [ClothingItem],
        addLayer: Bool = false,
        limit: Int = 8
    ) -> [OutfitSuggestion] {
        let pool = closet.filter { occasion.formalityRange.contains($0.formality) }
        func items(_ category: ClothingCategory) -> [ClothingItem] {
            pool.filter { $0.category == category }
        }

        let shoes = items(.shoes)
        var bases: [[ClothingItem]] = []

        for top in items(.top) {
            for bottom in items(.bottom) {
                for pair in shoes { bases.append([top, bottom, pair]) }
            }
        }
        for dress in items(.dress) {
            for pair in shoes { bases.append([dress, pair]) }
        }

        let ranked = bases
            .map { OutfitSuggestion(items: $0, score: score($0, occasion: occasion)) }
            .sorted { $0.score > $1.score }
            .prefix(limit)

        guard addLayer else { return Array(ranked) }

        let layers = items(.outerwear)
        return ranked.map { suggestion in
            let best = layers.max {
                score(suggestion.items + [$0], occasion: occasion) < score(suggestion.items + [$1], occasion: occasion)
            }
            guard let layer = best else { return suggestion }
            let combined = suggestion.items + [layer]
            return OutfitSuggestion(items: combined, score: score(combined, occasion: occasion))
        }
    }

    private static func score(_ outfit: [ClothingItem], occasion: Occasion) -> Double {
        var total = 0.0

        // Formality: how close each piece is to the occasion's target.
        let closeness = outfit.map { 1 - abs(Double($0.formality) - occasion.targetFormality) / 4 }
        total += closeness.reduce(0, +) / Double(outfit.count)

        // Color: neutrals are safe; at most one or two accent colors.
        let accents = Set(outfit.map(\.color).filter { !$0.isNeutral })
        switch accents.count {
        case 0: total += 0.3
        case 1: total += 0.2
        case 2: total -= 0.2
        default: total -= 0.8
        }

        // Pattern: don't stack patterns.
        if outfit.filter(\.isPatterned).count >= 2 { total -= 0.5 }

        // Warmth: don't mix a heavy piece with a light one.
        let warmths = outfit.map(\.warmthRaw)
        if let high = warmths.max(), let low = warmths.min(), high - low > 1 { total -= 0.4 }

        // Silhouette: balance volume between top and bottom.
        if let top = outfit.first(where: { $0.category == .top }),
           let bottom = outfit.first(where: { $0.category == .bottom }) {
            switch (top.fit, bottom.fit) {
            case (.relaxed, .relaxed): total -= 0.3
            case (.fitted, .relaxed), (.regular, .relaxed): total += 0.15
            case (.relaxed, .fitted): total += 0.1
            default: break
            }
        }

        // Freshness: avoid pieces worn in the last few days.
        for item in outfit {
            if let worn = item.lastWorn, worn > Date().addingTimeInterval(-3 * 86_400) {
                total -= 0.15
            }
        }

        // Jitter so "Another" gives variety among near-equal outfits.
        return total + Double.random(in: 0...0.15)
    }
}
