# ActingFor Demo Compatibility

This document records which ActingFor version or exact commit has been verified with this demo application. ActingFor 0.1.1 is released on RubyGems. The `feature/decision-reason-code` branch now resolves the released `acting_for 0.1.1`; the earlier exact-Git candidate remains documented below as pre-release evidence.

| Demo revision | ActingFor source | Automated verification | Human Manual Verification |
| --- | --- | --- | --- |
| `62b06197e85a57858e3468c5dee76162bcb754da` | `5293f25a21093fa514df53466df503984e4981d1` | PASS (17 runs, 94 assertions, 0 failures, 0 errors, 0 skips) | NOT YET COMPLETED |
| `9c1407c4b3643b92d02d611c15aefeb7fb290a5c` | `5293f25a21093fa514df53466df503984e4981d1` | PASS (8 runs, 36 assertions, 0 failures, 0 errors) | NOT YET COMPLETED |
| `e87ef0418d7938443ca3ad9fca109538e8db045b` | RubyGems `acting_for` `0.1.0` | PASS (17 runs, 94 assertions, 0 failures, 0 errors, 0 skips) | NOT YET COMPLETED |
| `fd4846a7f9e6301bfcfd1cef9e889e4442fe05be` | RubyGems `acting_for` `0.1.0` | PASS (18 runs, 108 assertions, 0 failures, 0 errors, 0 skips) | NOT YET COMPLETED |
| `32058147b6527ce46486c523e9a8d036760ca372` | RubyGems `acting_for` `0.1.0` | PASS (18 runs, 108 assertions, 0 failures, 0 errors, 0 skips) | PASS: Scenarios 1–11 human verified; full human completion recorded 2026-09-23 |
| `f1b2d87a635bee8b3b43556079ae6f4decf8774e` | `7578bb541cea5a49e79c1590abcac740e9f65d4b` (`Decision#reason_code` candidate) | PASS (18 runs, 118 assertions, 0 failures, 0 errors, 0 skips; Actions run `36521481895`) | PASS: focused reason_code browser verification completed 2026-09-29 |
| `b784cd268db72e66626dac4d499891b4809f7969` | RubyGems `acting_for` `0.1.1` | PASS (18 runs, 118 assertions, 0 failures, 0 errors, 0 skips; smoke PASS; Actions run `36528758797`) | Published-gem human rerun not repeated; focused reason_code human browser PASS is preserved from the verified candidate |

## Decision reason_code 0.1.1 release verification

Pre-release verification used exact ActingFor commit `7578bb541cea5a49e79c1590abcac740e9f65d4b`. After ActingFor 0.1.1 was published, the Demo dependency was switched to RubyGems `~> 0.1.1`; `Gemfile.lock` resolves `acting_for (0.1.1)` from RubyGems with SHA256 `57ceb266285a0970af79c3ad745171638799b00b6d8617bf9ecfc13382819c29`.

Automated integration verification ran against Demo revision `f1b2d87a635bee8b3b43556079ae6f4decf8774e` in GitHub Actions run `36521481895` and passed:

```text
Decision reason_code: no_matching_delegation
18 runs
118 assertions
0 failures
0 errors
0 skips
```

The Demo tests cover all three public reason codes and verify that the Decision Symbol reason matches the persisted AuditEvent String reason. The purchase-result screen also renders `Decision Reason` directly from `@result.decision.reason_code`.

Focused human browser verification completed on 2026-09-29 and passed for all three outcomes: ALLOW / `delegation_allowed` / executed, REQUIRE APPROVAL / `delegation_requires_approval` / not executed, and DENY / `no_matching_delegation` / not executed. The Audit Events reasons matched each Decision Reason, and Executed Purchases contained only the allowed ¥800 Shopping Agent purchase.

The browser verification was performed from the feature branch after the automated candidate pass; subsequent branch-only changes between the automated behavior revision and the browser pass were documentation / temporary-workflow cleanup and did not change application behavior. The earlier v0.1.0 Scenarios 1–11 human PASS remains separate historical evidence.

Post-release verification then ran against released RubyGems `acting_for 0.1.1` at Demo revision `b784cd268db72e66626dac4d499891b4809f7969` in GitHub Actions run `36528758797`:

```text
ActingFor version: 0.1.1
Decision reason_code: no_matching_delegation
18 runs
118 assertions
0 failures
0 errors
0 skips
Smoke HTTP: PASS
```

This verifies that the published gem—not the temporary Git candidate—boots in the Demo, exposes the expected Public API, passes the Demo integration suite, and serves the browser UI. The focused human browser pass was not repeated after publication; its pre-release evidence is preserved separately rather than relabeled as post-release human evidence.

## Released 0.1.0 historical verification

The demo dependency targets RubyGems `acting_for` `~> 0.1.0` and resolves to version `0.1.0` in `Gemfile.lock`.

Automated integration verification against exact Demo revision `e87ef0418d7938443ca3ad9fca109538e8db045b` passed in GitHub Actions run `35677771716`: **17 runs / 94 assertions / 0 failures / 0 errors / 0 skips**. The verification also confirmed the installed `ActingFor::VERSION == "0.1.0"` and the lockfile checksum `a7c3cfc97bf04445c04b8fc9cbe6be8a9aa433cfb8ba20b0da90f853b1336abd`.

Human verification later exposed a Demo-only 500 error when the `allow` Delegation was revoked. The authorization itself failed closed as expected, but the Shop attempted to render a complete two-Delegation settings shape. Demo commit `fd4846a7f9e6301bfcfd1cef9e889e4442fe05be` fixed that host-UI issue. GitHub Actions run `35689734551` then passed with **18 runs / 108 assertions / 0 failures / 0 errors / 0 skips**.

Smoke verification is **PASS**.

The release verification record preserves both the earlier assisted pass and the later human completion pass:

```text
Scenarios 1–6  → human-verified PASS (2026-09-22)
Scenarios 7–8  → human Rails-console PASS (2026-09-23)
Scenarios 9–11 → human browser PASS (2026-09-23)
Regression      → PASS (18 runs / 108 assertions / 0 failures / 0 errors / 0 skips)
Full Human Manual Verification → PASS
```

Scenarios 7–11 were first verified Codex-assisted against exact Demo revision `32058147b6527ce46486c523e9a8d036760ca372`. The user then repeated those checks on 2026-09-23: Scenarios 7–8 through the documented Rails console paths and Scenarios 9–11 through the browser workflow with corresponding service/Audit results checked. The earlier assisted evidence remains in `docs/MANUAL_VERIFICATION.md` for provenance.

The repository commit immediately before the completion record, `073a97f3c350c7c2ac81e2fb2aa6ff1762b1a005`, differs from the behavior baseline `32058147b6527ce46486c523e9a8d036760ca372` only in `docs/COMPATIBILITY.md` and `docs/MANUAL_VERIFICATION.md`; there were no application-behavior changes between them.

The detailed evidence and classification are recorded in `docs/MANUAL_VERIFICATION.md`.

## Current verification environment

- Latest post-release verification date: 2026-09-29
- ActingFor: RubyGems 0.1.1
- Published-gem automated integration: PASS — 18 runs / 118 assertions / 0 failures / 0 errors / 0 skips
- Published-gem smoke verification: PASS
- Focused `reason_code` human browser verification: PASS on the pre-release candidate; not repeated after publication
- Historical full v0.1.0 human completion date: 2026-09-23
- Ruby: 3.4.10
- Rails: 8.0.5.1
- PostgreSQL: 16.15
- Docker Compose
- Demo behavior baseline and automated regression revision: `32058147b6527ce46486c523e9a8d036760ca372`
- Human completion: Scenarios 1–11 PASS; Scenarios 7–8 Rails console, Scenarios 9–11 browser workflow

## Source-of-truth boundary

- Gem behavior, Public API, and Security Contract: `cuichangquan/acting_for`
- Demo usage, host-integration example, and manual-verification workflow: `cuichangquan/acting_for_demo`
- Compatibility history: this document

The demo is an official reference and integration-verification application. It complements, but does not replace, ActingFor core CI. Demo integration tests exercise the gem's public API from a Rails host application and must not depend on `ActingFor::Internal::*` or other internal implementation details.

If demo integration reveals a bug or API problem, treat it as feedback for an ActingFor issue or fix candidate. Do not bypass the gem's contract merely to make the demo pass.

## Release compatibility procedure

For released v0.1.x integration, use the RubyGems version requirement:

```ruby
gem "acting_for", "~> 0.1.1"
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
