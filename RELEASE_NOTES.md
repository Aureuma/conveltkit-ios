# ConveltKit 0.1.111

Patch release to fix public API visibility for host integrations.

- Make `ConveltClient.stableStoreKitUploadIdempotencyKey(...)` public so app targets (like LingoSpeak) can compile and call the deterministic StoreKit idempotency helper directly.
