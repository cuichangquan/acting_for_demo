# Human Manual Verification

This document distinguishes human-observed verification from Codex-assisted verification. Historical Codex-assisted evidence is retained for provenance, but the release status below reflects the later human completion pass.

Status: **COMPLETED — Scenarios 1–11 human-verified. Full Human Manual Verification: PASS.**

## Environment Record

```text
Verification Date: 2026-09-23 (completion pass; Scenarios 1–6 were human-verified on 2026-09-22)
ActingFor Version / Commit: 0.1.0 (RubyGems)
Demo behavior baseline: 32058147b6527ce46486c523e9a8d036760ca372
Repository state before this completion record: 073a97f3c350c7c2ac81e2fb2aa6ff1762b1a005
Ruby: 3.4.10
Rails: 8.0.5.1
PostgreSQL: 16.15
Human verification: browser UI for Scenarios 1–6 and 9–11; Rails console for Scenarios 7–8
OS: macOS host + Docker Compose

Between the behavior baseline and the repository state above, only `docs/COMPATIBILITY.md` and `docs/MANUAL_VERIFICATION.md` changed; no application behavior changed.
```

Start from a clean Docker state:

```sh
docker compose down -v
docker compose build
docker compose run --rm app bin/setup --skip-server
docker compose up
```

Open <http://localhost:3000>. The `-v` command deletes the Docker-managed demo database volume; it does not remove host PostgreSQL data.

## Verification Summary

```text
Smoke Verification: PASS
Scenario 1: PASS — human verified
Scenario 2: PASS — human verified
Scenario 3: PASS — human verified
Scenario 4: PASS — human verified after Demo partial-revoke fix
Scenario 5: PASS — human verified
Scenario 6: PASS — human verified
Scenario 7: PASS — human verified in Rails console
Scenario 8: PASS — human verified in Rails console
Scenario 9: PASS — human browser verified; service-level evidence also confirmed
Scenario 10: PASS — human browser verified; service-level evidence also confirmed
Scenario 11: PASS — human browser verified; service-level evidence also confirmed
Regression Test: PASS — 18 runs, 108 assertions, 0 failures, 0 errors, 0 skips
Full Human Manual Verification: PASS
```

Scenarios 1–3 were human-confirmed before the partial-revoke Demo fix. That fix only changed how the Shop handles an incomplete Delegation configuration; the normal complete-configuration paths exercised by Scenarios 1–3 were unchanged. Scenarios 4–6 were then human-confirmed after the fix. Scenarios 7–11 were first verified Codex-assisted against Demo revision `32058147b6527ce46486c523e9a8d036760ca372`, then re-verified by the user on 2026-09-23. Scenarios 7–8 used the documented Rails console paths; Scenarios 9–11 were completed through the browser workflow with the corresponding service/Audit results checked. The earlier Codex-assisted evidence remains below as historical evidence.

## Scenario 1: allow

```text
Product: Everyday Item (¥800)
Expected Decision: ALLOW
Expected Purchase: created
Expected Audit: created
Actual Decision: ALLOW
Actual Purchase: created
Actual Audit: created
PASS / FAIL: PASS — human verified
```

## Scenario 2: require_approval

```text
Product: Approval Item (¥2,000)
Expected Decision: REQUIRE APPROVAL
Expected Purchase: not created
Expected Audit: created
Actual Decision: REQUIRE APPROVAL
Actual Purchase: not created
Actual Audit: created
PASS / FAIL: PASS — human verified
```

## Scenario 3: deny

```text
Product: Expensive Item (¥5,000)
Expected Decision: DENY
Expected Purchase: not created
Expected Audit: created
Actual Decision: DENY
Actual Purchase: not created
Actual Audit: created
PASS / FAIL: PASS — human verified
```

## Scenario 4: revoke

Run in `docker compose run --rm app bin/rails console`:

```ruby
agent = ActingFor::Agent.find_by!(identifier: "shopping-agent")
ActingFor::Delegation.find_by!(agent:, effect: "allow", revoked_at: nil).revoke!
```

Human verification found that the original Demo Shop returned HTTP 500 after only the `allow` Delegation was revoked because `DemoDelegationSettings.current` expected the complete Demo Delegation shape. This was a Demo UI issue, not an ActingFor authorization failure.

The Demo was fixed by commit:

```text
fd4846a7f9e6301bfcfd1cef9e889e4442fe05be
fix: keep demo shop usable after partial revoke
```

After the fix, the scenario was rerun manually.

```text
Expected Decision: DENY
Expected Purchase: not created
Expected Audit: created
Actual Decision: DENY
Actual Purchase: not created
Actual Audit: created
Actual Reason: no_matching_delegation
Actual Sanitized Context: {"amount":800}
PASS / FAIL: PASS — human verified
```

Restore with `docker compose run --rm app bin/reset_demo`.

## Scenario 5: expired

In the Docker console, revoke the current allow Delegation as above, then create a short-lived replacement:

```ruby
user = User.find_by!(name: "Demo User")
agent = ActingFor::Agent.find_by!(identifier: "shopping-agent")
ActingFor.delegate(agent:, principal: user, action: :purchase, resource: Product,
  constraints: [{ field: "amount", operator: "lte", value: 1_000 }],
  effect: :allow, expires_at: 10.seconds.from_now)
```

Wait at least 11 seconds, then request ¥800.

```text
Expected Decision: DENY
Expected Purchase: not created
Expected Audit: created
Actual Decision: DENY
Actual Purchase: not created
Actual Audit: created
Actual Reason: no_matching_delegation
Actual Sanitized Context: {"amount":800}
PASS / FAIL: PASS — human verified
```

Restore with `docker compose run --rm app bin/reset_demo`.

## Scenario 6: forged amount

The ¥5,000 Product was submitted with a forged client value of `amount=100`. A raw curl request was first rejected by Rails CSRF protection, so the verification was repeated with a valid CSRF token and session cookie.

```text
Client-supplied amount: 100
Trusted Amount: ¥5,000
Expected Decision: DENY
Expected Purchase: not created
Expected Audit Context: {"amount":5000}
Actual Decision: DENY
Actual Purchase: not created
Actual Audit Context: {"amount":5000}
PASS / FAIL: PASS — human verified
```

This confirms that the host application ignores the forged client amount for authorization and supplies the trusted database value to ActingFor.

## Scenario 7: different Agent

Run in `docker compose run --rm app bin/rails console`:

```ruby
other = ActingFor::Agent.create!(identifier: "manual-other-agent", name: "Other Agent")
result = ShoppingAgentPurchase.call(product_id: Product.find_by!(price: 800).id,
  principal: User.find_by!(name: "Demo User"), agent: other)
[result.decision.status, result.purchase]
```

Historical Codex-assisted evidence:

```text
Decision: deny
Purchase: nil
Purchase delta: 0
Audit delta: 1
Audit agent_identifier: "manual-other-agent"
Audit decision: "deny"
Audit sanitized_context: {"amount"=>800}
PASS / FAIL: PASS — Codex-assisted
```

Human completion evidence (2026-09-23):

```text
Result: [:deny, nil]
Audit agent_identifier: "manual-other-agent"
Audit decision: "deny"
Audit reason: "no_matching_delegation"
Audit sanitized_context: {"amount"=>800}
PASS / FAIL: PASS — human verified in Rails console
```

Note: `ActingFor::AuditEvent` stores the authorization-time Agent identifier as `agent_identifier`; it does not expose an `event.agent` association. An earlier verification helper incorrectly referenced `event.agent.identifier`; that helper was corrected and was not an authorization defect.

Restore with `docker compose run --rm app bin/reset_demo`.

## Scenario 8: different Principal

Run in `docker compose run --rm app bin/rails console`:

```ruby
other = User.create!(name: "Manual Other User")
result = ShoppingAgentPurchase.call(product_id: Product.find_by!(price: 800).id,
  principal: other, agent: ActingFor::Agent.find_by!(identifier: "shopping-agent"))
[result.decision.status, result.purchase]
```

Historical Codex-assisted evidence:

```text
Decision: deny
Purchase: nil
Purchase delta: 0
Audit delta: 1
Audit Principal: User#2
Audit Agent: "shopping-agent"
Audit Decision: "deny"
Audit Reason: "no_matching_delegation"
Audit Context: {"amount"=>800}
PASS / FAIL: PASS — Codex-assisted
```

Human completion evidence (2026-09-23):

```text
Result: [:deny, nil]
Audit Principal: User#2
Audit Agent: "shopping-agent"
Audit Decision: "deny"
Audit Reason: "no_matching_delegation"
Audit Context: {"amount"=>800}
PASS / FAIL: PASS — human verified in Rails console
```

Restore with `docker compose run --rm app bin/reset_demo`.

## Scenario 9: direct human purchases

The checklist's browser path is **Buy as Demo User** for each product. Codex first exercised the same host-owned `HumanPurchase` service directly. On 2026-09-23, the user completed the browser workflow and checked the Audit Events screen.

```text
¥800:  Purchase created, source="human", amount=800
¥2,000: Purchase created, source="human", amount=2000
¥5,000: Purchase created, source="human", amount=5000
Purchase delta: 3
ActingFor AuditEvent count change: 0
Sources: ["human", "human", "human"]
PASS / FAIL: PASS — Codex-assisted
```

Human completion evidence (2026-09-23):

```text
¥800: human purchase confirmed
¥2,000: human purchase confirmed
¥5,000: human purchase confirmed
ActingFor involvement: NOT INVOLVED
ActingFor AuditEvent count: unchanged for the three direct human purchases
PASS / FAIL: PASS — human browser verified
```

## Scenario 10: change delegated authority

The checklist's browser path changes `1000 / 3000` to `2500 / 6000` through **Delegation Settings**. Codex first exercised `DemoDelegationSettings.replace!` and the host purchase service directly. On 2026-09-23, the user repeated the change through the browser workflow and confirmed the resulting Audit Events.

```text
Actual Settings: allow_max=2500 / approval_max=6000

¥2,000:
Decision: ALLOW
Purchase: created
Purchase delta: 1
Audit delta: 1
Audit decision: "allow"
Audit context: {"amount"=>2000}

¥5,000:
Decision: REQUIRE APPROVAL
Purchase: not created
Purchase delta: 0
Audit delta: 1
Audit decision: "require_approval"
Audit context: {"amount"=>5000}

PASS / FAIL: PASS — Codex-assisted
```

Human completion evidence (2026-09-23):

```text
Actual Settings: allow_max=2500 / approval_max=6000
¥2,000: ALLOW; Purchase created
¥5,000: REQUIRE APPROVAL; Purchase not created
Audit Events: ALLOW for Product#2 and REQUIRE APPROVAL for Product#3
PASS / FAIL: PASS — human browser verified
```

## Scenario 11: reset delegated authority

Starting from the Scenario 10 settings, Codex first exercised `DemoDelegationSettings.reset!`. On 2026-09-23, the user reset the settings through the browser workflow and confirmed the resulting Audit Events.

```text
Actual Reset Settings: allow_max=1000 / approval_max=3000

¥2,000:
Decision: REQUIRE APPROVAL
Purchase: not created
Purchase delta: 0
Audit delta: 1
Audit decision: "require_approval"

¥5,000:
Decision: DENY
Purchase: not created
Purchase delta: 0
Audit delta: 1
Audit decision: "deny"

PASS / FAIL: PASS — Codex-assisted
```

Human completion evidence (2026-09-23):

```text
Actual Reset Settings: allow_max=1000 / approval_max=3000
¥2,000: REQUIRE APPROVAL; Purchase not created
¥5,000: DENY; Purchase not created
Audit Events: REQUIRE APPROVAL for Product#2 and DENY for Product#3
PASS / FAIL: PASS — human browser verified
```

## Regression Test

After Scenarios 7–11, the full Demo test suite was run against Demo revision `32058147b6527ce46486c523e9a8d036760ca372`.

```text
18 runs
108 assertions
0 failures
0 errors
0 skips
```

This regression result is automated verification. The later human completion pass is independently recorded above and closes Full Human Manual Verification as PASS.
