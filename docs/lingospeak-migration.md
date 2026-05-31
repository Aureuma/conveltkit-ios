# LingoSpeak Migration

Update `apps/ios/LingoSpeak/project.yml` package reference to the platform repo URL and exact semantic version.

## Target Package Reference

```yaml
packages:
  ConveltKit:
    url: https://github.com/Aureuma/conveltkit-ios.git
    exactVersion: 0.1.126
```

Target dependency entry:

```yaml
dependencies:
  - package: ConveltKit
    product: ConveltKit
```

## Validation

- Regenerate iOS project with XcodeGen.
- Resolve package dependencies.
- Verify no remaining old SDK URL in project sources.
