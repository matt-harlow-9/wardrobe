import SwiftUI
import SwiftData
import PhotosUI

/// Add a new piece (item == nil) or edit an existing one.
struct ItemFormView: View {
    let item: ClothingItem?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var size = ""
    @State private var notes = ""
    @State private var category: ClothingCategory = .top
    @State private var color: ClothingColor = .black
    @State private var formality = 2
    @State private var warmth: Warmth = .medium
    @State private var isPatterned = false
    @State private var fit: Fit = .regular
    @State private var material = ""
    @State private var sourceURL = ""
    @State private var photoData: Data?
    @State private var pickerItem: PhotosPickerItem?

    @State private var linkText = ""
    @State private var isImporting = false
    @State private var importNote: String?

    var body: some View {
        Form {
            Section("Import from product link") {
                TextField("Paste a product page link", text: $linkText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task { await importLink() }
                } label: {
                    if isImporting {
                        HStack { ProgressView(); Text("Reading page…") }
                    } else {
                        Text("Fill in details from link")
                    }
                }
                .disabled(isImporting || linkText.trimmingCharacters(in: .whitespaces).isEmpty)
                if let importNote {
                    Text(importNote).font(.footnote).foregroundStyle(.secondary)
                }
                if let url = URL(string: sourceURL), !sourceURL.isEmpty {
                    Link("View product page", destination: url)
                }
            }

            Section {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    HStack {
                        if let photoData, let image = UIImage(data: photoData) {
                            Image(uiImage: image)
                                .resizable().scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Text(photoData == nil ? "Add photo" : "Change photo")
                    }
                }
            }

            Section("Details") {
                TextField("Name (e.g. Navy oxford shirt)", text: $name)
                TextField("Brand / creator", text: $brand)
                TextField("Size", text: $size)
                Picker("Category", selection: $category) {
                    ForEach(ClothingCategory.allCases) { Text($0.label).tag($0) }
                }
            }

            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(ClothingColor.allCases) { option in
                        Circle()
                            .fill(option.swiftUIColor)
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: 3).opacity(color == option ? 1 : 0).padding(-4))
                            .onTapGesture { color = option }
                    }
                }
                .padding(.vertical, 4)
                Text(color.label).font(.footnote).foregroundStyle(.secondary)
            }

            Section("Style") {
                Picker("Formality", selection: $formality) {
                    ForEach(1...5, id: \.self) { level in
                        Text("\(level) · \(Formality.labels[level] ?? "")").tag(level)
                    }
                }
                Picker("Warmth", selection: $warmth) {
                    ForEach(Warmth.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Fit", selection: $fit) {
                    ForEach(Fit.allCases) { Text($0.label).tag($0) }
                }
                TextField("Material (e.g. 100% wool)", text: $material)
                Toggle("Patterned (stripes, plaid, print)", isOn: $isPatterned)
            }

            Section("Notes") {
                TextField("e.g. runs small", text: $notes, axis: .vertical)
            }

            if let item {
                Section {
                    LabeledContent("Worn", value: "\(item.wearCount) time\(item.wearCount == 1 ? "" : "s")")
                    Button("Delete piece", role: .destructive) {
                        context.delete(item)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(item == nil ? "New piece" : "Edit piece")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if item == nil {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear(perform: load)
        .onChange(of: pickerItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    photoData = Self.downsized(data)
                }
            }
        }
    }

    private func load() {
        guard let item else { return }
        name = item.name
        brand = item.brand
        size = item.size
        notes = item.notes
        category = item.category
        color = item.color
        formality = item.formality
        warmth = item.warmth
        isPatterned = item.isPatterned
        fit = item.fit
        material = item.material
        sourceURL = item.sourceURL
        linkText = item.sourceURL
        photoData = item.photoData
    }

    @MainActor
    private func importLink() async {
        isImporting = true
        importNote = nil
        defer { isImporting = false }
        do {
            let product = try await ProductImporter.importProduct(from: linkText)
            name = product.name
            if !product.brand.isEmpty { brand = product.brand }
            material = product.material
            category = product.category
            formality = product.formality
            warmth = product.warmth
            fit = product.fit
            isPatterned = product.isPatterned
            sourceURL = product.sourceURL.absoluteString
            if let first = product.colors.first { color = first }
            if photoData == nil, let imageURL = product.imageURL,
               let data = await ProductImporter.fetchImage(imageURL) {
                photoData = Self.downsized(data)
            }
            var notes = ["Filled in from the page. Check everything, and set your size."]
            if product.colors.count > 1 {
                notes.append("The page lists \(product.colors.count) colors; confirm yours.")
            } else if product.colors.isEmpty {
                notes.append("Couldn't tell the color; pick it below.")
            }
            importNote = notes.joined(separator: " ")
        } catch {
            importNote = error.localizedDescription
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let item {
            item.name = trimmed
            item.brand = brand
            item.size = size
            item.notes = notes
            item.category = category
            item.color = color
            item.formality = formality
            item.warmth = warmth
            item.isPatterned = isPatterned
            item.fit = fit
            item.material = material
            item.sourceURL = sourceURL
            item.photoData = photoData
        } else {
            context.insert(ClothingItem(
                name: trimmed, brand: brand, size: size, notes: notes,
                category: category, color: color, formality: formality,
                warmth: warmth, isPatterned: isPatterned,
                fit: fit, material: material, sourceURL: sourceURL, photoData: photoData
            ))
        }
        dismiss()
    }

    /// Keep stored photos small: longest side 1200px, JPEG.
    private static func downsized(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1200 / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }
}
