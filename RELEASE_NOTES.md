# ConveltKit 0.1.119

Platform split and version-authority alignment release.

- Canonical iOS SDK source URL is now `https://github.com/Aureuma/conveltkit-ios.git`.
- Bootstrap now reports `sdkVersion` from generated `ConveltKitVersion` metadata.
- Removed filesystem-based workspace version probing from SDK runtime code.
- Added contract test coverage to verify bootstrap sends the generated SDK version and `supportedContractVersions: ["1.0.0"]`.
