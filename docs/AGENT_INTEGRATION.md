# MCP Reference Integration Design

Status: **Design proposal / implementation not started**

This document defines the next reference-integration step for the ActingFor Shopping Demo: connect a real MCP tool call to the existing Rails host boundary without changing ActingFor Core.

The demo remains the source of truth for host integration. ActingFor remains the source of truth for delegated-authorization behavior, Public API, and the Security Contract.

## Goal

Demonstrate one complete path:

```text
MCP Client / AI Agent
        ↓
purchase_product(product_id)
        ↓
Rails MCP adapter
        ↓
trusted Agent + Principal resolution
        ↓
ShoppingAgentPurchase
        ↓
ActingFor.authorize(...)
        ↓
allow / require_approval / deny
        ↓
Rails executes or stops
        ↓
ActingFor::AuditEvent
```

The first implementation should prove that an external agent can reach the same authorization boundary already exercised by the browser demo.

It should **not** add MCP concepts to ActingFor Core.

## Non-goals

The first MCP reference integration does not provide:

- an MCP implementation inside the `acting_for` gem
- a new ActingFor Public API
- OAuth / OIDC server functionality
- an Agent authentication standard
- a general Agent provisioning system
- an approval workflow
- an approval UI
- cumulative / aggregate delegation budgets
- multiple MCP tools
- a production-ready identity provider

The MCP transport/library choice is intentionally separate from ActingFor Core and may be changed without changing delegated-authorization semantics.

## Existing boundary to reuse

The current demo already has the correct host service boundary:

```ruby
ShoppingAgentPurchase.call(
  product_id:,
  principal:,
  agent:
)
```

That service:

1. loads `Product` from PostgreSQL
2. uses `Product#price` as trusted Context
3. calls `ActingFor.authorize(...)`
4. creates a `Purchase` only when `decision.allowed?`
5. leaves `require_approval` and `deny` unexecuted

The MCP adapter should call this service instead of duplicating authorization or purchase logic.

```text
Browser Controller ───────┐
                          │
MCP Tool Adapter ─────────┼──> ShoppingAgentPurchase
                          │          ↓
Future API Adapter ───────┘      ActingFor
```

This keeps the authorization boundary independent of transport.

## First MCP tool

Implement exactly one tool first:

```text
purchase_product(product_id)
```

### Tool input

The Agent supplies only the product identifier:

```json
{
  "product_id": 1
}
```

Do not accept these values from tool arguments:

- `amount`
- `price`
- `agent_id`
- `principal_id`
- `decision`
- `reason_code`

The Rails host must establish them from trusted state.

## Identity and Principal resolution

MCP transport identity and ActingFor Agent identity are different concepts.

The adapter must follow this direction:

```text
Authenticated / trusted MCP caller context
        ↓
Host identity mapping
        ↓
ActingFor::Agent
        ↓
Host Principal resolution
        ↓
ShoppingAgentPurchase
```

The tool arguments themselves must not decide which Agent or Principal is used.

Conceptually:

```ruby
agent = agent_resolver.resolve!(trusted_auth_context)
principal = principal_resolver.resolve!(
  trusted_auth_context,
  agent:
)

result = ShoppingAgentPurchase.call(
  product_id: input.fetch("product_id"),
  principal:,
  agent:
)
```

For a local development-only reference implementation, the demo may use a deliberately simple resolver for the pre-provisioned `shopping-agent`, but it must be clearly labeled as development-only and must not be presented as Agent authentication.

A later production-oriented example may replace the resolver with OAuth/OIDC or another authenticated identity source without changing ActingFor or `ShoppingAgentPurchase`.

## Trusted Context boundary

The Agent must never provide the authorization amount.

Correct:

```text
Agent sends product_id
        ↓
Rails loads Product
        ↓
Rails reads Product#price
        ↓
context: { amount: product.price }
```

Incorrect:

```text
Agent sends product_id + amount
                         ↑
                 do not trust this
```

This preserves the existing demo's Context Trust Boundary.

## Decision mapping

The MCP adapter should treat all three ActingFor decisions as normal authorization outcomes.

| ActingFor Decision | Host execution | MCP result |
| --- | --- | --- |
| `allow` | Purchase created | success result with `executed: true` |
| `require_approval` | No Purchase | normal result with `executed: false` |
| `deny` | No Purchase | normal result with `executed: false` |

Example response shape:

```json
{
  "status": "allow",
  "reason_code": "delegation_allowed",
  "executed": true,
  "purchase_id": 123
}
```

For non-executed decisions:

```json
{
  "status": "require_approval",
  "reason_code": "delegation_requires_approval",
  "executed": false,
  "purchase_id": null
}
```

A denied authorization is not an MCP transport failure. Authentication failure, identity-resolution failure, invalid tool input, and unexpected host/system failure should remain errors rather than being converted into `deny`.

## Demo scenarios

The existing three products should be reused:

| Product price | Expected Decision | Expected execution |
| ---: | --- | --- |
| ¥800 | `allow` | Purchase created |
| ¥2,000 | `require_approval` | No Purchase |
| ¥5,000 | `deny` | No Purchase |

For each MCP call, verify:

- returned Decision status
- returned `reason_code`
- whether a Purchase was created
- corresponding ActingFor AuditEvent
- AuditEvent reason matches the Decision reason
- only the ¥800 case executes business logic

## Security requirements

The reference integration must preserve these rules:

1. **Agent and Principal are host-resolved.** Tool arguments cannot choose them.
2. **Price is host-resolved.** The Agent cannot choose the authorization amount.
3. **MCP access is not delegated authorization.** Reaching the tool does not imply permission to purchase.
4. **`require_approval != allow`.** No purchase is created.
5. **Decision is not reusable authority.** Authorization occurs close to the protected operation.
6. **Audit failure stops execution.** Do not execute the purchase if `ActingFor.authorize` fails.
7. **No `ActingFor::Internal::*` dependency.** The demo uses only the public API.
8. **ActingFor Core remains MCP-independent.**

## Error boundary

Keep system errors separate from authorization decisions.

```text
Unknown / unauthenticated caller
        → host authentication / resolution error

Unknown product_id
        → host input/resource error

ActingFor returns deny
        → normal authorization result

ActingFor returns require_approval
        → normal authorization result

Audit persistence / database failure
        → system error, no Purchase
```

The adapter should not turn unexpected exceptions into a successful-looking `deny` response.

## Test plan

Add host-level tests without duplicating ActingFor Core tests.

Minimum coverage:

1. MCP `purchase_product` for ¥800 → `allow`, Purchase created, AuditEvent recorded.
2. ¥2,000 → `require_approval`, no Purchase, AuditEvent recorded.
3. ¥5,000 → `deny`, no Purchase, AuditEvent recorded.
4. Tool input cannot override price / amount.
5. Tool input cannot select another Agent or Principal.
6. Identity resolution failure stops before `ShoppingAgentPurchase`.
7. Unknown Product stops without business execution.
8. MCP adapter does not reference `ActingFor::Internal::*`.
9. Existing browser integration tests remain green.

Do not re-test ActingFor internal matching algorithms in the demo repository.

## Implementation sequence

Proceed in small steps:

```text
1. Select a minimal Rails-compatible MCP transport/library
        ↓
2. Add purchase_product only
        ↓
3. Add trusted caller → Agent / Principal resolver boundary
        ↓
4. Route tool execution through ShoppingAgentPurchase
        ↓
5. Add the three Decision integration tests
        ↓
6. Add spoofing / failure-boundary tests
        ↓
7. Verify with a real MCP client
        ↓
8. Document exact manual verification steps
```

The first implementation should not add `search_products` or `get_product` until `purchase_product` is working end-to-end.

## Core-change gate

Before changing the `acting_for` gem, ask:

> Can this requirement be implemented correctly in the Rails host adapter while keeping the current ActingFor Public API and Security Contract?

For the design above, the expected answer is **yes**.

Therefore the initial MCP reference integration should make **no ActingFor Core, schema, or Public API changes**.

If implementation reveals a real missing abstraction, record that separately as a Core design issue instead of working around it inside the demo.

## Completion criteria

The MCP reference integration is complete when:

- a real MCP client can invoke `purchase_product`
- the same `ShoppingAgentPurchase` service is used by MCP and the existing host flow
- ¥800 / ¥2,000 / ¥5,000 produce the expected three decisions
- only the allowed request creates a Purchase
- all authorization attempts produce the expected AuditEvent
- the caller cannot control Agent, Principal, or trusted amount through tool input
- existing demo tests continue to pass
- ActingFor Core remains unchanged
