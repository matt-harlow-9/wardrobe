import SwiftUI
import SwiftData

struct OutfitsView: View {
    @Environment(\.modelContext) private var context
    @Query private var closet: [ClothingItem]
    @Query(sort: \Outfit.date, order: .reverse) private var saved: [Outfit]

    @State private var occasion: Occasion = .businessCasual
    @State private var addLayer = false
    @State private var suggestions: [OutfitSuggestion] = []
    @State private var index = 0
    @State private var hasGenerated = false

    private var current: OutfitSuggestion? {
        suggestions.indices.contains(index) ? suggestions[index] : nil
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Occasion") {
                    Picker("Occasion", selection: $occasion) {
                        ForEach(Occasion.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Add a layer (jacket / coat)", isOn: $addLayer)
                    Button {
                        generate()
                    } label: {
                        Label("Generate outfit", systemImage: "sparkles")
                    }
                }

                if let current {
                    Section("Suggestion \(index + 1) of \(suggestions.count)") {
                        ForEach(current.items) { OutfitRow(item: $0) }
                        Button("Save outfit") { save(current) }
                        Button("Wore this today") { wear(current) }
                        Button("Show another") {
                            index = (index + 1) % suggestions.count
                        }
                        .disabled(suggestions.count < 2)
                    }
                } else if hasGenerated {
                    Section {
                        ContentUnavailableView(
                            "Nothing fits yet",
                            systemImage: "hanger",
                            description: Text("Add a top, bottom and shoes (or a dress and shoes) rated for \(occasion.label.lowercased()) formality.")
                        )
                    }
                }

                if !saved.isEmpty {
                    Section("Saved outfits") {
                        ForEach(saved) { outfit in
                            NavigationLink {
                                List(outfit.items) { OutfitRow(item: $0) }
                                    .navigationTitle(outfit.occasion.label)
                            } label: {
                                SavedOutfitLabel(outfit: outfit)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { saved[$0] }.forEach(context.delete)
                        }
                    }
                }
            }
            .navigationTitle("Outfits")
        }
    }

    private func generate() {
        suggestions = OutfitGenerator.suggestions(for: occasion, from: closet, addLayer: addLayer)
        index = 0
        hasGenerated = true
    }

    private func save(_ suggestion: OutfitSuggestion) {
        context.insert(Outfit(occasion: occasion, items: suggestion.items))
    }

    private func wear(_ suggestion: OutfitSuggestion) {
        for item in suggestion.items {
            item.lastWorn = .now
            item.wearCount += 1
        }
        // Regenerate so just-worn pieces drop in the ranking.
        generate()
    }
}

struct OutfitRow: View {
    let item: ClothingItem

    var body: some View {
        HStack(spacing: 12) {
            ItemThumbnail(item: item)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading) {
                Text(item.name)
                Text([item.category.label, item.brand].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SavedOutfitLabel: View {
    let outfit: Outfit

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(outfit.occasion.label)
            Text(outfit.items.map(\.name).joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
