import SwiftUI
import SwiftData

enum ClothingCategory: String, CaseIterable, Identifiable {
    case top, bottom, dress, outerwear, shoes, accessory
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum Warmth: Int, CaseIterable, Identifiable {
    case light, medium, heavy
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .light: "Light"
        case .medium: "Medium"
        case .heavy: "Heavy"
        }
    }
}

/// Silhouette volume. Used to balance proportions (wide bottoms with a less voluminous top).
enum Fit: Int, CaseIterable, Identifiable {
    case fitted, regular, relaxed
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .fitted: "Fitted"
        case .regular: "Regular"
        case .relaxed: "Relaxed / wide"
        }
    }
}

enum ClothingColor: String, CaseIterable, Identifiable {
    case black, white, grey, navy, beige, brown
    case red, orange, yellow, green, olive, blue, purple, pink

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// Neutrals go with everything; the outfit scorer limits non-neutral colors.
    var isNeutral: Bool {
        switch self {
        case .black, .white, .grey, .navy, .beige, .brown: true
        default: false
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .black: Color(red: 0.08, green: 0.08, blue: 0.09)
        case .white: Color(red: 0.97, green: 0.97, blue: 0.97)
        case .grey: Color(red: 0.55, green: 0.56, blue: 0.58)
        case .navy: Color(red: 0.10, green: 0.16, blue: 0.33)
        case .beige: Color(red: 0.84, green: 0.77, blue: 0.64)
        case .brown: Color(red: 0.42, green: 0.28, blue: 0.18)
        case .red: Color(red: 0.80, green: 0.14, blue: 0.16)
        case .orange: Color(red: 0.93, green: 0.51, blue: 0.13)
        case .yellow: Color(red: 0.95, green: 0.80, blue: 0.20)
        case .green: Color(red: 0.20, green: 0.60, blue: 0.30)
        case .olive: Color(red: 0.43, green: 0.46, blue: 0.22)
        case .blue: Color(red: 0.20, green: 0.45, blue: 0.85)
        case .purple: Color(red: 0.50, green: 0.30, blue: 0.70)
        case .pink: Color(red: 0.93, green: 0.55, blue: 0.68)
        }
    }
}

enum Formality {
    static let labels: [Int: String] = [
        1: "Loungewear",
        2: "Casual",
        3: "Smart casual",
        4: "Dressy / business",
        5: "Formal",
    ]
}

@Model
final class ClothingItem {
    var name: String
    var brand: String
    var size: String
    var notes: String
    var categoryRaw: String
    var colorRaw: String
    var formality: Int
    var warmthRaw: Int
    var isPatterned: Bool
    @Attribute(.externalStorage) var photoData: Data?
    var dateAdded: Date
    var lastWorn: Date?
    var wearCount: Int
    // Added after v1; defaults let SwiftData migrate existing closets.
    var fitRaw: Int = Fit.regular.rawValue
    var material: String = ""
    var sourceURL: String = ""

    init(
        name: String,
        brand: String = "",
        size: String = "",
        notes: String = "",
        category: ClothingCategory,
        color: ClothingColor,
        formality: Int = 2,
        warmth: Warmth = .medium,
        isPatterned: Bool = false,
        fit: Fit = .regular,
        material: String = "",
        sourceURL: String = "",
        photoData: Data? = nil
    ) {
        self.fitRaw = fit.rawValue
        self.material = material
        self.sourceURL = sourceURL
        self.name = name
        self.brand = brand
        self.size = size
        self.notes = notes
        self.categoryRaw = category.rawValue
        self.colorRaw = color.rawValue
        self.formality = formality
        self.warmthRaw = warmth.rawValue
        self.isPatterned = isPatterned
        self.photoData = photoData
        self.dateAdded = .now
        self.lastWorn = nil
        self.wearCount = 0
    }

    var category: ClothingCategory {
        get { ClothingCategory(rawValue: categoryRaw) ?? .top }
        set { categoryRaw = newValue.rawValue }
    }

    var color: ClothingColor {
        get { ClothingColor(rawValue: colorRaw) ?? .black }
        set { colorRaw = newValue.rawValue }
    }

    var warmth: Warmth {
        get { Warmth(rawValue: warmthRaw) ?? .medium }
        set { warmthRaw = newValue.rawValue }
    }

    var fit: Fit {
        get { Fit(rawValue: fitRaw) ?? .regular }
        set { fitRaw = newValue.rawValue }
    }
}
