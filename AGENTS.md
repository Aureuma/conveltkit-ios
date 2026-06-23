# Repo Rules

- Follow the shared workspace rules in `/home/shawn/Development/AGENTS.md`.

## ConveltKit Shared Version Train

- `convelt/Cargo.toml` `[workspace.package].version` is the canonical hard-coded version for `convelt`, `conveltkit-ios`, and `conveltkit-android`.
- Any tracked-content commit in one of these three repos must advance the next shared patch version across all three repos in the same release train.
- SDK repo version files are generated from Convelt and must not be treated as independent source-of-truth values.
- Public SDK identity remains `ConveltKit`; platform suffixes belong in repo/artifact names, not in user-facing SDK names.

## iOS SDK Contract Rules

- Keep package/product/module names as `ConveltKit`.
- Keep app import usage as `import ConveltKit`.
- Keep bootstrap `supportedContractVersions` aligned with Convelt API contract policy.
