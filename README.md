# ConveltKit

Public Swift Package for Convelt iOS billing and entitlement integration.

## Requirements

- iOS 17+
- macOS 13+
- Swift tools 5.10+

## Installation

Xcode Swift Package dependency:

- URL: `https://github.com/Aureuma/conveltkit-ios.git`
- Version: exact Git tag pin recommended for release builds

## Quick Start

```swift
import ConveltKit
import Foundation

let config = ConveltConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    publicSDKKey: "public-sdk-key",
    appEnvironmentID: UUID(),
    appCode: "example-app",
    bundleID: "com.example.app",
    appVersion: "1.0.0",
    buildNumber: "1"
)

let client = ConveltClient(configuration: config)
```

LingoSpeak-specific integrations should still pass explicit identity, for example:

```swift
let lingoSpeakConfig = ConveltConfiguration(
    baseURL: URL(string: "https://api.lingospeak.ai")!,
    publicSDKKey: "public-sdk-key",
    appEnvironmentID: UUID(),
    appCode: "lingospeak",
    bundleID: "ai.lingospeak.one",
    appVersion: "1.0.0",
    buildNumber: "1"
)
```

## API Notes

- `ConveltOutcomeResponse.failureReason` is part of the public contract.
- `ConveltClientError.httpStatus(Int, String?)` and `ConveltClientError.decodeFailed` are stable public error surfaces used by app integrations.
- StoreKit helpers are guarded with `#if canImport(StoreKit)`.

## Contract and version source of truth

- Contract semantics are defined in Convelt: `https://github.com/Aureuma/convelt/blob/main/docs/api-contract.md`
- Product version source of truth is `convelt/Cargo.toml` `[workspace.package].version`
- `ConveltKitVersion.swift` is generated from Convelt and should not be edited as source of truth.
- Host apps should pin a released `conveltkit-ios` tag directly in their own
  package configuration. This SDK repo does not maintain app-specific migration
  docs with duplicated exact-version values.

## Security Boundary

- `publicSDKKey` is public client configuration material.
- Server-side credentials must never be embedded in client apps or this package.

## Versioning

Semantic versions are published as Git tags and GitHub releases.
