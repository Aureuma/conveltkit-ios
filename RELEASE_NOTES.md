# ConveltKit 0.1.110

Patch release to stabilize StoreKit transaction upload idempotency.

- Add deterministic idempotency key derivation for verified StoreKit transactions based on app environment, original transaction ID, transaction ID, and product ID.
- Use stable keys across purchase success, restore-current-entitlements, and transaction-updates observer upload paths.
- Add regression tests covering deterministic key reuse and identity-based key differentiation.
