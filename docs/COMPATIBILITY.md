# ActingFor Demo Compatibility

This document records which ActingFor version or exact commit has been verified with this demo application. ActingFor 0.1.0 is released on RubyGems; the current dependency target is the released gem.

| Demo revision | ActingFor source | Automated verification | Human Manual Verification |
| --- | --- | --- | --- |
| `62b06197e85a57858e3468c5dee76162bcb754da` | `5293f25a21093fa514df53466df503984e4981d1` | PASS (17 runs, 94 assertions, 0 failures, 0 errors, 0 skips) | NOT YET COMPLETED |
| `9c1407c4b3643b92d02d611c15aefeb7fb290a5c` | `5293f25a21093fa514df53466df503984e4981d1` | PASS (8 runs, 36 assertions, 0 failures, 0 errors) | NOT YET COMPLETED |
| `e87ef0418d7938443ca3ad9fca109538e8db045b` | RubyGems `acting_for` `0.1.0` | PASS (17 runs, 94 assertions, 0 failures, 0 errors, 0 skips) | NOT YET COMPLETED |
| `fd4846a7f9e6301bfcfd1cef9e889e4442fe05be` | RubyGems `acting_for` `0.1.0` | PASS (18 runs, 108 assertions, 0 failures, 0 errors, 0 skips) | NOT YET COMPLETED |
| `32058147b6527ce46486c523e9a8d036760ca372` | RubyGems `acting_for` `0.1.0` | PASS (18 runs, 108 assertions, 0 failures, 0 errors, 0 skips) | PARTIAL: Scenarios 1–6 human PASS; Scenarios 7–11 Codex-assisted PASS; full human completion not claimed |

## Released gem verification

The demo dependency targets RubyGems `acting_for` `~> 0.1.0` and resolves to version `0.1.0` in `Gemfile.lock`.

Automated integration verification against exact Demo revision `e87ef0418d7938443ca3ad9fca109538e8db045b` passed in GitHub Actions run `35677771716`: **17 runs / 94 assertions / 0 failures / 0 errors / 0 skips**. The verification also confirmed the installed `ActingFor::VERSION == "0.1.0"` and the lockfile checksum `a7c3cfc97bf04445c04b8fc9cbe6be8a9aa433cfb8ba20b0da90f853b1336abd`.

Human verification later exposed a Demo-only 500 error when the `allow` Delegation was revoked. The authorization itself failed closed as expected, but the Shop attempted to render a complete two-Delegation settings shape. Demo commit `fd4846a7f9e6301bfcfd1cef9e889e4442fe05be` fixed that host-UI issue. GitHub Actions run `35689734551` then passed with **18 runs / 108 assertions / 0 failures / 0 errors / 0 skips**.

Smoke verification is **PASS**.

The release verification record is intentionally split by who performed the check:

```text
Scenarios 1–6  → human-verified PASS
Scenarios 7–11 → Codex-assisted PASS
Regression      → PASS (18 runs / 108 assertions / 0 failures / 0 errors / 0 skips)
Full Human Manual Verification → NOT CLAIMED
```

Scenarios 1–3 were human-confirmed before the partial-revoke Demo fix; that fix did not change the complete-configuration paths exercised by those scenarios. Scenarios 4–6 were human-confirmed after the fix. Scenarios 7–11 and the final regression suite were executed by Codex against exact Demo revision `32058147b6527ce46486c523e9a8d036760ca372`.

The detailed evidence and classification are recorded in `docs/MANUAL_VERIFICATION.md`.

## Current verification environment

- Verification date: 2026-09-22
- ActingFor: RubyGems 0.1.0
- Ruby: 3.4.10
- Rails: 8.0.5.1
- PostgreSQL: 16.15
- Docker Compose
- Demo revision for Codex-assisted Scenarios 7–11 and final regression: `32058147b6527ce46486c523e9a8d036760ca372`

## Source-of-truth boundary

- Gem behavior, Public API, and Security Contract: `cuichangquan/acting_for`
- Demo usage, host-integration example, and manual-verification workflow: `cuichangquan/acting_for_demo`
- Compatibility history: this document

The demo is an official reference and integration-verification application. It complements, but does not replace, ActingFor core CI. Demo integration tests exercise the gem's public API from a Rails host application and must not depend on `ActingFor::Internal::*` or other internal implementation details.

If demo integration reveals a bug or API problem, treat it as feedback for an ActingFor issue or fix candidate. Do not bypass the gem's contract merely to make the demo pass.

## Release compatibility procedure

For released v0.1.x integration, use the RubyGems version requirement:

```ruby
gem "acting_for", "~> 0.1.0"
```

For an unreleased future release-candidate verification pass, an exact Git commit may be used temporarily and must be recorded explicitly in this file.

For every dependency update, complete and record this sequence:

```text
Demo automated integration test
  ↓
Smoke verification
  ↓
Human / assisted verification with provenance recorded
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
  → Human / assisted verification
  → Compatibility record
```
