# ConveltKit 0.1.112

Patch release to improve customer alias reconciliation and outbox conflict handling.

- Add `ConveltUserIdentityResolver.adoptCanonicalCustomerID(...)` so app targets can persist server-canonical customer IDs per external user.
- Ensure outbox draining returns explicit terminal/retry outcomes for known client HTTP failures instead of silently falling back to generic retry-only behavior.
