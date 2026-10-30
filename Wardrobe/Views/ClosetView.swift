import SwiftUI
import SwiftData

struct ClosetView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ClothingItem.dateAdded, order: .reverse) private var items: [ClothingItem]

    @State private var search = ""
    @State private var filter: ClothingCategory?
    @State private var showingAdd = false

    private var visible: [ClothingItem] {
        items.filter { item in
            (filter == nil || item.category == filter)
                && (search.isEmpty
                    || item.name.localizedCaseInsensitiveContains(search)
                    || item.brand.localizedCaseInsensitiveContains(search))
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                categoryChips
                if visible.isEmpty {
                    ContentUnavailableView(
                        items.isEmpty ? "Your closet is empty" : "No matches",
                        systemImage: "tshirt",
                        description: Text(items.isEmpty ? "Tap + to add your first piece." : "Try a different filter.")
                    )
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(visible) { item in
                            NavigationLink {
                                ItemFormView(item: item)
                            } label: {
                                ItemCard(item: item)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", role: .destructive) { context.delete(item) }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Closet")
            .searchable(text: $search, prompt: "Search name or brand")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack { ItemFormView(item: nil) }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                chip("All", selected: filter == nil) { filter = nil }
                ForEach(ClothingCategory.allCases) { category in
                    chip(category.label, selected: filter == category) { filter = category }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
    }
}

struct ItemThumbnail: View {
    let item: ClothingItem

    var body: some View {
        if let data = item.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                item.color.swiftUIColor
                Text(item.category.label)
                    .font(.caption.bold())
                    .foregroundStyle(item.color == .white || item.color == .beige || item.color == .yellow ? .black : .white)
            }
        }
    }
}

struct ItemCard: View {
    let item: ClothingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ItemThumbnail(item: item)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(item.name).font(.subheadline.bold()).lineLimit(1)
            Text([item.brand, item.size].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
