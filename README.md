# Wardrobe

A personal iOS app that keeps a digital closet and builds outfits for an occasion.

- Add pieces with photo, brand, size, color, formality (1-5), warmth, fit, material and pattern.
- Import details from a product page link (parsed on-device, no server).
- Pick an occasion (casual, business casual, business formal, dinner date, night out, formal) and generate an outfit from the pieces you own.
- Outfit selection is a rules engine; see `Wardrobe/Services/OutfitGenerator.swift`.

## Build

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open Wardrobe.xcodeproj
```

Set your own team in `project.yml` (`DEVELOPMENT_TEAM`) or in Xcode's Signing & Capabilities, then run on a device or simulator. iOS 17+.

## Layout

- `Wardrobe/Models` SwiftData models (`ClothingItem`, `Outfit`) and occasion definitions
- `Wardrobe/Services` outfit generator, product-page importer, keyword classifier
- `Wardrobe/Views` closet grid, add/edit form, outfit screen
