# ActingFor Demo Compatibility

This document records which ActingFor version or exact commit has been verified with this demo application. ActingFor is not yet released on RubyGems, so the current record uses an exact source commit.

| Demo revision | ActingFor source | Automated verification | Human Manual Verification |
| --- | --- | --- | --- |
| `PENDING_DOCUMENTATION_COMMIT` | `5293f25a21093fa514df53466df503984e4981d1` | PASS (8 runs, 36 assertions, 0 failures, 0 errors) | NOT YET COMPLETED |

The recorded Demo revision is the documentation revision tested immediately before the compatibility-record commit that replaces the temporary value above. The compatibility-record-only commit does not change application behavior or the verified documentation content.

## Current verification environment

- Ruby: 3.4.10
- Rails: 8.0.5.1
- PostgreSQL: 16.15
- Docker Compose

## Source-of-truth boundary

- Gem behavior, Public API, and Security Contract: `cuichangquan/acting_for`
- Demo usage, host-integration example, and manual-verification workflow: `cuichangquan/acting_for_demo`
- Compatibility history: this document

The demo is an official reference and integration-verification application. It complements, but does not replace, ActingFor core CI. Demo integration tests exercise the gem's public API from a Rails host application and must not depend on `ActingFor::Internal::*` or other internal implementation details.

If demo integration reveals a bug or API problem, treat it as feedback for an ActingFor issue or fix candidate. Do not bypass the gem's contract merely to make the demo pass.

## Release compatibility procedure

Before the first RubyGems release, pin ActingFor to an exact commit:

```ruby
gem "acting_for",
  github: "cuichangquan/acting_for",
  ref: "<exact sha>"
```

After ActingFor v0.1.0 is released, switch to:

```ruby
gem "acting_for", "~> 0.1.0"
```

For every dependency update, complete and record this sequence:

```text
Demo automated integration test
  ↓
Smoke verification
  ↓
Human Manual Verification
  ↓
COMPATIBILITY.md update
```

The broader release relationship is:

```text
ActingFor implementation / release candidate
  → core CI
  → RubyGems release
  → Demo dependency update
  → Demo integration tests
  → Demo smoke verification
  → Human manual verification
  → Compatibility record
```
