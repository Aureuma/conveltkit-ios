# API Contract Notes

This package is the public Swift SDK for Convelt client-side purchase and entitlement integration.

## Contract source of truth

Convelt contract source:

- `https://github.com/Aureuma/convelt/blob/main/docs/api-contract.md`
- `convelt/crates/convelt-core/src/contracts.rs`

## Key Public Surfaces

- `ConveltConfiguration`
- `ConveltClient`
- `ConveltOutcomeResponse`
- `ConveltClientError`
- `ConveltUserIdentityResolver`
- `ConveltOutboxStore`

## Outcome Semantics

`ConveltOutcomeResponse` includes:

- `outcome`
- `displayClass`
- `retryable`
- `readyToFinish`
- `failureReason`
- `requestID`
- `snapshot`

`resolvedOutcome` maps known outcome strings to stable app-facing cases.

## Error Semantics

Public integration relies on:

- `ConveltClientError.httpStatus(Int, String?)`
- `ConveltClientError.decodeFailed`

These are compile-checked in tests and treated as compatibility-sensitive.
