# Security Policy

## Supported Versions

Security fixes are applied to the latest minor release line.

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Report vulnerabilities privately via [GitHub Security Advisories](https://github.com/arkavo-ai/a2a-swift/security/advisories/new) or by emailing security@arkavo.com. Include:

- A description of the vulnerability and its impact
- Steps to reproduce (a failing payload or proof-of-concept if applicable)
- Affected versions

You can expect an acknowledgment within 72 hours and a status update within 14 days.

## Scope notes

This SDK handles untrusted input in several places that are deliberately hardened and well-tested:

- JSON decoding of agent cards, messages, and JSON-RPC envelopes from remote agents
- Base64 decoding of `Part` raw content
- Incremental SSE parsing of streamed bytes

Reports involving malformed input causing crashes, hangs, or resource exhaustion in these paths are in scope. Authentication and TLS policy are the embedding application's responsibility (`RequestAuthenticator`, `URLSessionConfiguration`).
