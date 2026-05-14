# LingoSpeak Migration

Update `apps/ios/LingoSpeak/project.yml` package reference from private monorepo revision pin to public package URL and exact semantic version.

## Target Package Reference

```yaml
packages:
  ConveltKit:
    url: https://github.com/Aureuma/ConveltKit.git
    exactVersion: 0.1.107
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
- Verify no remaining legacy private monorepo package URL in project sources.
