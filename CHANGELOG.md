# Changelog

## 0.1.106 - 2026-05-14

- Fix API-surface compile test to match `FileConveltOutboxStore.defaultURL(appGroupIdentifier:)`.

## 0.1.105 - 2026-05-14

- Raise macOS deployment target to 13 to match StoreKit API availability used by `ConveltClient`.
- Keep iOS target at 17+.

## 0.1.104 - 2026-05-14

- Initial public extraction of ConveltKit Swift Package.
- Source extracted from `Aureuma/convelt` at commit `7e33a098470e322a304014c895b66051c28fbb45`.
- Standardized SwiftPM layout:
  - `Sources/ConveltKit`
  - `Tests/ConveltKitTests`
- Added public docs and CI workflow.
