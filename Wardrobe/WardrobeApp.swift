import SwiftUI
import SwiftData

@main
struct WardrobeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [ClothingItem.self, Outfit.self])
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            ClosetView()
                .tabItem { Label("Closet", systemImage: "tshirt") }
            OutfitsView()
                .tabItem { Label("Outfits", systemImage: "sparkles") }
        }
    }
}
