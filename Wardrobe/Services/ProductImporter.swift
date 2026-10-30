import Foundation

struct ImportedProduct {
    var name: String
    var brand: String
    var material: String
    /// Every color the page offered that maps to our palette; the first is the best guess.
    var colors: [ClothingColor]
    var category: ClothingCategory
    var formality: Int
    var warmth: Warmth
    var fit: Fit
    var isPatterned: Bool
    var imageURL: URL?
    var sourceURL: URL
}

enum ProductImportError: LocalizedError {
    case badURL
    case http(Int)
    case unreadable
    case noProductInfo

    var errorDescription: String? {
        switch self {
        case .badURL: "That doesn't look like a web link."
        case .http(let code): "The site returned an error (\(code)). It may block automated requests."
        case .unreadable: "Couldn't read that page."
        case .noProductInfo: "No product details found on that page. Enter the piece manually."
        }
    }
}

/// Reads a retail product page and pre-fills closet fields. Most shops embed
/// schema.org JSON-LD and OpenGraph tags for search engines; we read those.
enum ProductImporter {
    static func importProduct(from text: String) async throws -> ImportedProduct {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.contains("://") { trimmed = "https://" + trimmed }
        guard let url = URL(string: trimmed), url.host != nil,
              url.scheme == "https" || url.scheme == "http" else {
            throw ProductImportError.badURL
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ProductImportError.http(http.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ProductImportError.unreadable
        }
        return try parse(html: html, url: response.url ?? url)
    }

    static func fetchImage(_ url: URL) async -> Data? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode ?? 200 < 300 else { return nil }
        return data
    }

    // MARK: - Parsing

    static func parse(html: String, url: URL) throws -> ImportedProduct {
        let meta = metaTags(in: html)
        let product = jsonLDProduct(in: html)

        var name = product?.string("name") ?? pageTitle(in: html) ?? meta["og:title"] ?? meta["twitter:title"] ?? ""
        let siteName = decodeEntities(meta["og:site_name"] ?? "")
        name = cleanTitle(decodeEntities(name), siteName: siteName)
        guard !name.isEmpty else { throw ProductImportError.noProductInfo }

        // Some shops (e.g. Uniqlo) skip JSON-LD and ship product data in an inline JSON state blob.
        let embeddedMaterial = embeddedString("composition", in: html).map { stripTags($0).components(separatedBy: "(").first?.replacingOccurrences(of: "Imported", with: "") ?? "" }
        let embeddedDetails = [embeddedString("designDetail", in: html), embeddedString("longDescription", in: html)]
            .compactMap { $0 }.map(stripTags).joined(separator: " ")

        let baseDescription = decodeEntities(product?.string("description") ?? meta["og:description"] ?? meta["description"] ?? "")
        let description = [baseDescription, embeddedDetails].filter { !$0.isEmpty }.joined(separator: " ")
        let material = decodeEntities(product?.string("material") ?? embeddedMaterial ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = decodeEntities(product?.brand ?? siteName).nonEmpty.map { $0.count <= 3 ? $0 : $0.capitalized }
            ?? brandFromHost(url)

        var colorTexts = product?.colors ?? embeddedColorNames(in: html)
        if colorTexts.isEmpty { colorTexts = [name] }
        var colors: [ClothingColor] = []
        for text in colorTexts {
            if let color = ProductClassifier.color(from: text), !colors.contains(color) { colors.append(color) }
        }

        let result = ProductClassifier.classify(name: name, description: description, material: material)

        var imageURL: URL?
        if let raw = product?.image ?? meta["og:image"] ?? meta["twitter:image"] {
            imageURL = URL(string: decodeEntities(raw), relativeTo: url)?.absoluteURL
        }

        return ImportedProduct(
            name: name, brand: brand, material: material, colors: colors,
            category: result.category, formality: result.formality, warmth: result.warmth,
            fit: result.fit, isPatterned: result.isPatterned,
            imageURL: imageURL, sourceURL: url
        )
    }

    private struct JSONProduct {
        let dict: [String: Any]

        func string(_ key: String) -> String? {
            switch dict[key] {
            case let value as String: return value.nonEmpty
            case let value as [String: Any]: return (value["name"] as? String)?.nonEmpty
            case let value as [Any]: return (value.first as? String)?.nonEmpty
            default: return nil
            }
        }

        var brand: String? { string("brand") }

        var image: String? {
            switch dict["image"] {
            case let value as String: return value
            case let value as [String: Any]: return value["url"] as? String
            case let value as [Any]:
                if let first = value.first as? String { return first }
                return (value.first as? [String: Any])?["url"] as? String
            default: return nil
            }
        }

        /// Product color, plus colors of variants for grouped products.
        var colors: [String] {
            var found: [String] = []
            if let color = string("color") { found.append(color) }
            if let variants = dict["hasVariant"] as? [[String: Any]] {
                for variant in variants {
                    if let color = variant["color"] as? String { found.append(color) }
                }
            }
            return found
        }
    }

    private static func jsonLDProduct(in html: String) -> JSONProduct? {
        let pattern = #"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, range: range) {
            guard let inner = Range(match.range(at: 1), in: html),
                  let data = html[inner].data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let found = findProduct(in: json) { return JSONProduct(dict: found) }
        }
        return nil
    }

    private static func findProduct(in node: Any) -> [String: Any]? {
        if let array = node as? [Any] {
            for element in array {
                if let found = findProduct(in: element) { return found }
            }
        } else if let dict = node as? [String: Any] {
            let types: [String]
            if let single = dict["@type"] as? String { types = [single] } else { types = dict["@type"] as? [String] ?? [] }
            if types.contains(where: { $0 == "Product" || $0 == "ProductGroup" }), dict["name"] != nil { return dict }
            if let graph = dict["@graph"], let found = findProduct(in: graph) { return found }
        }
        return nil
    }

    private static func metaTags(in html: String) -> [String: String] {
        guard let tagRegex = try? NSRegularExpression(pattern: #"<meta\b[^>]*>"#, options: .caseInsensitive),
              let attrRegex = try? NSRegularExpression(pattern: #"([a-zA-Z:_-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')"#) else { return [:] }
        var result: [String: String] = [:]
        for tag in tagRegex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let tagRange = Range(tag.range, in: html) else { continue }
            let text = String(html[tagRange])
            var attrs: [String: String] = [:]
            for attr in attrRegex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let keyRange = Range(attr.range(at: 1), in: text) else { continue }
                let valueRange = Range(attr.range(at: 2), in: text) ?? Range(attr.range(at: 3), in: text)
                if let valueRange { attrs[text[keyRange].lowercased()] = String(text[valueRange]) }
            }
            if let key = attrs["property"] ?? attrs["name"], let content = attrs["content"], result[key.lowercased()] == nil {
                result[key.lowercased()] = content
            }
        }
        return result
    }

    private static func pageTitle(in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"<title[^>]*>(.*?)</title>"#, options: [.dotMatchesLineSeparators, .caseInsensitive]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "Pleated Wide Pants | Brushed Twill | UNIQLO US" -> "Pleated Wide Pants - Brushed Twill"
    private static func cleanTitle(_ title: String, siteName: String) -> String {
        let segments = title.components(separatedBy: " | ")
        let site = siteName.lowercased()
        let kept = segments.filter { segment in
            site.isEmpty || !segment.lowercased().contains(site)
        }
        let result = (kept.isEmpty ? segments : kept).joined(separator: " - ")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Inline JSON state fallback

    private static func embeddedString(_ key: String, in html: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        let raw = String(html[range])
        guard let data = "\"\(raw)\"".data(using: .utf8),
              let decoded = try? JSONDecoder().decode(String.self, from: data) else { return raw }
        return decoded
    }

    private static func embeddedColorNames(in html: String) -> [String] {
        guard let blockRegex = try? NSRegularExpression(pattern: #""colors"\s*:\s*\[(.*?)\]"#, options: .dotMatchesLineSeparators),
              let block = blockRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let blockRange = Range(block.range(at: 1), in: html),
              let nameRegex = try? NSRegularExpression(pattern: #""name"\s*:\s*"([^"]*)""#) else { return [] }
        let text = String(html[blockRange])
        return nameRegex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    private static func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func brandFromHost(_ url: URL) -> String {
        let parts = (url.host ?? "").lowercased().split(separator: ".").map(String.init)
        let ignored: Set<String> = ["www", "shop", "us", "com", "co", "uk", "m"]
        guard let core = parts.last(where: { !ignored.contains($0) }) else { return "" }
        return core.capitalized
    }

    private static func decodeEntities(_ text: String) -> String {
        var result = text
        let entities = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
