# Human Manual Verification

This document distinguishes human-observed browser verification from Codex-assisted verification. Automated or agent-assisted success must not be represented as human verification.

Status: **PARTIALLY COMPLETED — Scenarios 1–6 human-verified; Scenarios 7–11 Codex-assisted. Full human completion is not claimed.**

## Environment Record

```text
Verification Date: 2026-09-22
ActingFor Version / Commit: 0.1.0 (RubyGems)
Demo Commit: 32058147b6527ce46486c523e9a8d036760ca372
Ruby: 3.4.10
Rails: 8.0.5.1
PostgreSQL: 16.15
Browser: Browser UI used for human verification of Scenarios 1–6
OS: macOS host + Docker Compose
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
Scenario 7: PASS — Codex-assisted
Scenario 8: PASS — Codex-assisted
Scenario 9: PASS — Codex-assisted
Scenario 10: PASS — Codex-assisted
Scenario 11: PASS — Codex-assisted
Regression Test: PASS — 18 runs, 108 assertions, 0 failures, 0 errors, 0 skips
Full Human Manual Verification: NOT CLAIMED
```

Scenarios 1–3 were human-confirmed before the partial-revoke Demo fix. That fix only changed how the Shop handles an incomplete Delegation configuration; the normal complete-configuration paths exercised by Scenarios 1–3 were unchanged. Scenarios 4–6 were then human-confirmed after the fix. Scenarios 7–11 were executed by Codex against Demo revision `32058147b6527ce46486c523e9a8d036760ca372`.

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

Codex-assisted evidence:

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

Codex-assisted evidence:

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

Restore with `docker compose run --rm app bin/reset_demo`.

## Scenario 9: direct human purchases

The checklist's browser path is **Buy as Demo User** for each product. For this verification pass, Codex exercised the same host-owned `HumanPurchase` service directly rather than claiming a human browser interaction.

```text
¥800:  Purchase created, source="human", amount=800
¥2,000: Purchase created, source="human", amount=2000
¥5,000: Purchase created, source="human", amount=5000
Purchase delta: 3
ActingFor AuditEvent count change: 0
Sources: ["human", "human", "human"]
PASS / FAIL: PASS — Codex-assisted
```

The browser result template states `ActingFor: NOT INVOLVED`; that browser UI assertion was not reclassified as human-verified by this Codex-assisted pass.

## Scenario 10: change delegated authority

The checklist's browser path changes `1000 / 3000` to `2500 / 6000` through **Delegation Settings**. For this verification pass, Codex exercised `DemoDelegationSettings.replace!` and the host purchase service directly.

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

## Scenario 11: reset delegated authority

Starting from the Scenario 10 settings, Codex exercised `DemoDelegationSettings.reset!`.

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

## Regression Test

After Scenarios 7–11, the full Demo test suite was run against Demo revision `32058147b6527ce46486c523e9a8d036760ca372`.

```text
18 runs
108 assertions
0 failures
0 errors
0 skips
```

This regression result is automated verification and does not change the human-verification classification above.
