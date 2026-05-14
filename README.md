# ConveltKit

Public Swift Package for Convelt iOS billing and entitlement integration.

## Requirements

- iOS 17+
- macOS 13+
- Swift tools 5.10+

## Installation

Xcode Swift Package dependency:

- URL: `https://github.com/Aureuma/ConveltKit.git`
- Version: exact pin recommended for release builds

## Quick Start

```swift
import ConveltKit
import Foundation

let config = ConveltConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    publicSDKKey: "public-sdk-key",
    appEnvironmentID: UUID(),
    bundleID: "ai.lingospeak.one",
    appVersion: "1.0.0",
    buildNumber: "1"
)

let client = ConveltClient(configuration: config)
```

## API Notes

- `ConveltOutcomeResponse.failureReason` is part of the public contract.
- `ConveltClientError.httpStatus(Int, String?)` and `ConveltClientError.decodeFailed` are stable public error surfaces used by app integrations.
- StoreKit helpers are guarded with `#if canImport(StoreKit)`.

## Security Boundary

- `publicSDKKey` is public client configuration material.
- Server-side credentials must never be embedded in client apps or this package.

## Versioning

Semantic versions are published as Git tags and GitHub releases.
