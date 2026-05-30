# Changelog

## 0.1.119 - 2026-05-30

- Move canonical SDK repository references to `Aureuma/conveltkit-ios`.
- Replace runtime workspace-version path walking with generated `ConveltKitVersion` metadata from Convelt.
- Add bootstrap payload contract test coverage for `sdkVersion` and `supportedContractVersions`.

## 0.1.112 - 2026-05-15

- Add `ConveltUserIdentityResolver.adoptCanonicalCustomerID(...)` so host apps can persist server-canonical customer aliases.
- Improve outbox draining to classify client HTTP failures into explicit outcomes and avoid collapsing known conflicts into generic retry-only behavior.

## 0.1.111 - 2026-05-15

- Make `ConveltClient.stableStoreKitUploadIdempotencyKey(...)` public so host apps can deterministically generate upload idempotency keys when integrating StoreKit transaction flows.

## 0.1.110 - 2026-05-14

- Derive deterministic StoreKit transaction upload idempotency keys from app environment ID, original transaction ID, transaction ID, and product ID.
- Apply stable idempotency for purchase success, restore-current-entitlements, and transaction-updates observer flows.
- Add SDK tests that prove deterministic key reuse for the same transaction identity and uniqueness when transaction/product identity differs.

## 0.1.109 - 2026-05-14

- Add `ConveltClient.bindAuthorizationBearerToken(_:)` and forward `Authorization: Bearer ...` on client API requests when present.
- Enables authenticated Lingospeak proxy routes (`/v1/client/entitlements/*`, `/v1/client/apple/transactions`) to avoid 401 unauthorized responses.

## 0.1.108 - 2026-05-14

- Normalize migration/docs references to the canonical public repository name `Aureuma/conveltkit-ios`.
- Update LingoSpeak migration example pin to `0.1.108`.

## 0.1.107 - 2026-05-14

- Fix `fileOutboxDefaultURLCompiles` test expectation to match current default filename (`transaction-outbox.json`).

## 0.1.106 - 2026-05-14

- Fix API-surface compile test to match `FileConveltOutboxStore.defaultURL(appGroupIdentifier:)`.

## 0.1.105 - 2026-05-14

- Raise macOS deployment target to 13 to match StoreKit API availability used by `ConveltClient`.
- Keep iOS target at 17+.

## 0.1.104 - 2026-05-14

- Initial public extraction of ConveltKit Swift Package.
- Source extracted from the internal Convelt monorepo at commit `7e33a098470e322a304014c895b66051c28fbb45`.
- Standardized SwiftPM layout:
  - `Sources/ConveltKit`
  - `Tests/ConveltKitTests`
- Added public docs and CI workflow.
