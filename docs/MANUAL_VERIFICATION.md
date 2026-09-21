# Human Manual Verification

This checklist is intentionally uncompleted. Automated test success is not human verification.

Status: **NOT YET COMPLETED**

## Environment Record

```text
Verification Date:
ActingFor Version / Commit: 2c2e1a6638f12b7fb961f04362f807e2cb6ff9a5
Demo Commit:
Ruby:
Rails:
PostgreSQL:
Browser:
OS:
```

Start from a clean Docker state:

```sh
docker compose down -v
docker compose build --ssh default
docker compose run --rm app bin/setup --skip-server
docker compose up
```

Open <http://localhost:3000>. The `-v` command deletes the Docker-managed demo database volume; it does not remove host PostgreSQL data.

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

Run in `docker compose run --rm app bin/rails console`:

```ruby
agent = ActingFor::Agent.find_by!(identifier: "shopping-agent")
ActingFor::Delegation.find_by!(agent:, effect: "allow", revoked_at: nil).revoke!
```

Request ¥800. Expect DENY, no Purchase, and an AuditEvent. Record: decision `[ ]`, purchase `[ ]`, audit `[ ]`, PASS/FAIL `[ ]`. Restore with `docker compose run --rm app bin/reset_demo`.

## Scenario 5: expired

In the Docker console, revoke the current allow Delegation as above, then create a short-lived replacement:

```ruby
user = User.find_by!(name: "Demo User")
agent = ActingFor::Agent.find_by!(identifier: "shopping-agent")
ActingFor.delegate(agent:, principal: user, action: :purchase, resource: Product,
  constraints: [{ field: "amount", operator: "lte", value: 1_000 }],
  effect: :allow, expires_at: 10.seconds.from_now)
```

Wait at least 11 seconds, then request ¥800. Expect DENY, no Purchase, and an AuditEvent. Record: decision `[ ]`, purchase `[ ]`, audit `[ ]`, PASS/FAIL `[ ]`. Restore with `docker compose run --rm app bin/reset_demo`.

## Scenario 6: forged amount

Find the ¥5,000 Product ID, then send a forged amount:

```sh
docker compose run --rm app bin/rails runner 'puts Product.find_by!(price: 5000).id'
curl -i -X POST http://localhost:3000/purchase_requests \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data 'product_id=PRODUCT_ID&amount=100'
```

Rails CSRF protection may reject raw curl. If so, use browser developer tools to add `amount=100` to the existing form submission. Expected: client amount ignored, trusted amount ¥5,000, DENY, no Purchase, AuditEvent context amount 5000. Record PASS/FAIL `[ ]`.

## Scenario 7: different Agent

Run in `docker compose run --rm app bin/rails console`:

```ruby
other = ActingFor::Agent.create!(identifier: "manual-other-agent", name: "Other Agent")
result = ShoppingAgentPurchase.call(product_id: Product.find_by!(price: 800).id,
  principal: User.find_by!(name: "Demo User"), agent: other)
[result.decision.status, result.purchase]
```

Expect `[:deny, nil]` and a new AuditEvent. Record PASS/FAIL `[ ]`. Restore with `docker compose run --rm app bin/reset_demo`.

## Scenario 8: different Principal

Run in `docker compose run --rm app bin/rails console`:

```ruby
other = User.create!(name: "Manual Other User")
result = ShoppingAgentPurchase.call(product_id: Product.find_by!(price: 800).id,
  principal: other, agent: ActingFor::Agent.find_by!(identifier: "shopping-agent"))
[result.decision.status, result.purchase]
```

Expect `[:deny, nil]` and a new AuditEvent. Record PASS/FAIL `[ ]`. Restore with `docker compose run --rm app bin/reset_demo`.

## Scenario 9: direct human purchases

Use **Buy as Demo User** for each product.

```text
¥800:  Expected Purchase: created  Actual: [ ]
¥2,000: Expected Purchase: created  Actual: [ ]
¥5,000: Expected Purchase: created  Actual: [ ]
ActingFor AuditEvent count before: [ ]
ActingFor AuditEvent count after:  [ ]
Expected audit count change: 0
PASS / FAIL: [ ]
```

Confirm the result says `ActingFor: NOT INVOLVED`, and Purchases identifies each row as `HUMAN`.

## Scenario 10: change delegated authority

Open **Delegation Settings** and change `1000 / 3000` to `2500 / 6000`. Confirm Shop displays the new limits, then ask the Shopping Agent to buy:

```text
¥2,000 Expected: ALLOW, Purchase created, Audit created
Actual: [ ]
¥5,000 Expected: REQUIRE APPROVAL, Purchase not created, Audit created
Actual: [ ]
PASS / FAIL: [ ]
```

## Scenario 11: reset delegated authority

Click **Reset to Demo Defaults** and confirm the settings and Shop return to `1000 / 3000`.

```text
¥2,000 Expected: REQUIRE APPROVAL, Purchase not created
Actual: [ ]
¥5,000 Expected: DENY, Purchase not created
Actual: [ ]
PASS / FAIL: [ ]
```
