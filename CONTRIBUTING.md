# Contributing to a2a-swift

Thank you for your interest in contributing! This project aims to be a vendor-neutral, spec-faithful Swift SDK for the [A2A protocol](https://a2a-protocol.org).

## Ground rules

- **The proto is normative.** The data model maps field-for-field to `specification/a2a.proto` in [a2aproject/A2A](https://github.com/a2aproject/A2A). Changes to model types must cite the corresponding proto field or spec section.
- **Zero third-party dependencies** in the core targets. Foundation only; use `#if canImport(FoundationNetworking)` for Linux URLSession.
- **Both platforms must pass.** Every change is CI-verified on macOS and Linux (`swift:6.3` container). Avoid APIs that are unavailable or unreliable in swift-corelibs-foundation (e.g. `URLSession.bytes(for:)`).
- **Vendor extensions live elsewhere.** Anything beyond the core spec should attach via `AgentExtension` URIs, `RequestAuthenticator`, or a custom `A2ATransport` — not patches to core types.

## Development

```sh
swift build
swift test
swift format lint --strict --recursive Sources Tests Package.swift
```

The project uses Swift 6 language mode with strict concurrency; new public types should be `Sendable`.

## Pull requests

1. Fork and create a feature branch.
2. Add tests — coding changes need round-trip coverage; wire-format changes need a golden vector sourced from the spec.
3. Run the format linter before pushing.
4. Open a PR describing what spec section motivates the change.

## Reporting issues

Use GitHub Issues. For protocol-conformance bugs, include the JSON payload and the spec section the SDK violates. For security issues, see [SECURITY.md](SECURITY.md).
