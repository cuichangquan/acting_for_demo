# Human Manual Verification

This checklist is intentionally uncompleted. Automated test success is not human verification.

## Environment Record

```text
Verification Date:
ActingFor Version / Commit: 5293f25a21093fa514df53466df503984e4981d1
Demo Commit:
Ruby:
Rails:
PostgreSQL:
Browser:
OS:
```

Start from a clean state with `bin/reset_demo`, then run `bin/rails server` and open <http://localhost:3000>.

## Scenario 1: allow

```text
Product: Everyday Item (¥800)
Expected Decision: ALLOW
Expected Purchase: created
Expected Audit: created
Actual Decision: [ ]
Actual Purchase: [ ]
Actual Audit: [ ]
PASS / FAIL: [ ]
```

## Scenario 2: require_approval

```text
Product: Approval Item (¥2,000)
Expected Decision: REQUIRE APPROVAL
Expected Purchase: not created
Expected Audit: created
Actual Decision: [ ]
Actual Purchase: [ ]
Actual Audit: [ ]
PASS / FAIL: [ ]
```

## Scenario 3: deny

```text
Product: Expensive Item (¥5,000)
Expected Decision: DENY
Expected Purchase: not created
Expected Audit: created
Actual Decision: [ ]
Actual Purchase: [ ]
Actual Audit: [ ]
PASS / FAIL: [ ]
```

## Scenario 4: revoke

Run in `bin/rails console`:

```ruby
agent = ActingFor::Agent.find_by!(identifier: "shopping-agent")
ActingFor::Delegation.find_by!(agent:, effect: "allow", revoked_at: nil).revoke!
```

Request ¥800. Expect DENY, no Purchase, and an AuditEvent. Record: decision `[ ]`, purchase `[ ]`, audit `[ ]`, PASS/FAIL `[ ]`. Restore with `bin/reset_demo`.

## Scenario 5: expired

In the console, revoke the current allow Delegation as above, then create a short-lived replacement:

```ruby
user = User.find_by!(name: "Demo User")
agent = ActingFor::Agent.find_by!(identifier: "shopping-agent")
ActingFor.delegate(agent:, principal: user, action: :purchase, resource: Product,
  constraints: [{ field: "amount", operator: "lte", value: 1_000 }],
  effect: :allow, expires_at: 10.seconds.from_now)
```

Wait at least 11 seconds, then request ¥800. Expect DENY, no Purchase, and an AuditEvent. Record: decision `[ ]`, purchase `[ ]`, audit `[ ]`, PASS/FAIL `[ ]`. Restore with `bin/reset_demo`.

## Scenario 6: forged amount

Find the ¥5,000 Product ID, then send a forged amount:

```sh
bin/rails runner 'puts Product.find_by!(price: 5000).id'
curl -i -X POST http://localhost:3000/purchase_requests \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data 'product_id=PRODUCT_ID&amount=100'
```

In development, Rails CSRF protection may reject raw curl. If so, run `RAILS_ENV=test bin/rails server -p 3001` against prepared test data or use browser developer tools to add `amount=100` to the existing form submission. Expected: client amount ignored, trusted amount ¥5,000, DENY, no Purchase, AuditEvent context amount 5000. Record PASS/FAIL `[ ]`.

## Scenario 7: different Agent

Run in the console:

```ruby
other = ActingFor::Agent.create!(identifier: "manual-other-agent", name: "Other Agent")
result = ShoppingAgentPurchase.call(product_id: Product.find_by!(price: 800).id,
  principal: User.find_by!(name: "Demo User"), agent: other)
[result.decision.status, result.purchase]
```

Expect `[:deny, nil]` and a new AuditEvent. Record PASS/FAIL `[ ]`. Restore with `bin/reset_demo`.

## Scenario 8: different Principal

Run in the console:

```ruby
other = User.create!(name: "Manual Other User")
result = ShoppingAgentPurchase.call(product_id: Product.find_by!(price: 800).id,
  principal: other, agent: ActingFor::Agent.find_by!(identifier: "shopping-agent"))
[result.decision.status, result.purchase]
```

Expect `[:deny, nil]` and a new AuditEvent. Record PASS/FAIL `[ ]`. Restore with `bin/reset_demo`.
