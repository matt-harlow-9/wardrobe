import Foundation
import SwiftData

enum Occasion: String, CaseIterable, Identifiable {
    case casual
    case businessCasual
    case business
    case dinnerDate
    case nightOut
    case formal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .casual: "Casual"
        case .businessCasual: "Business casual"
        case .business: "Business formal"
        case .dinnerDate: "Dinner date"
        case .nightOut: "Night out"
        case .formal: "Formal event"
        }
    }

    /// Items outside this formality range are never considered for the occasion.
    var formalityRange: ClosedRange<Int> {
        switch self {
        case .casual: 1...3
        case .businessCasual: 3...4
        case .business: 4...5
        case .dinnerDate: 3...5
        case .nightOut: 2...4
        case .formal: 5...5
        }
    }

    /// Items closer to this score higher.
    var targetFormality: Double {
        switch self {
        case .casual: 2
        case .businessCasual: 3.5
        case .business: 4.5
        case .dinnerDate: 4
        case .nightOut: 3
        case .formal: 5
        }
    }
}

@Model
final class Outfit {
    var occasionRaw: String
    var date: Date
    @Relationship var items: [ClothingItem]

    init(occasion: Occasion, items: [ClothingItem]) {
        self.occasionRaw = occasion.rawValue
        self.date = .now
        self.items = items
    }

    var occasion: Occasion {
        Occasion(rawValue: occasionRaw) ?? .casual
    }
}
