# MCP Reference Integration

Status: **Implemented and verified with the official MCP Ruby HTTP client**

This document describes the MCP reference integration in the ActingFor Shopping Demo. The integration connects a real MCP client to the existing Rails host authorization boundary without adding MCP concepts to ActingFor Core.

ActingFor remains the source of truth for delegated-authorization behavior, Public API, and the Security Contract. The Demo is the source of truth for this host integration.

## Goal

Demonstrate one complete path:

```text
MCP Client / AI Agent
        ↓ Streamable HTTP
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

The integration proves that an MCP client can reach the same host authorization boundary already exercised by the browser demo.

## Responsibility boundary

The MCP reference integration does **not** move MCP responsibilities into the `acting_for` gem.

- MCP handles the client/tool transport into the Rails host.
- The Rails host establishes trusted Agent, Principal, Resource, and Context.
- ActingFor decides whether the resolved Agent may perform the Action on behalf of the Principal.
- The Rails host decides whether to execute the business operation based on the returned Decision.

ActingFor Core, database schema, and Public API remain unchanged by this integration.

## Selected MCP implementation

The Demo uses the official MCP Ruby SDK:

```ruby
gem "mcp", "~> 1.6.1"
```

`Gemfile.lock` resolves MCP Ruby SDK **1.6.1**.

The reference path uses **Streamable HTTP through a Rails controller**. It is stateless and does not expose long-lived subscription listening.

```text
Official MCP HTTP Client
      ↓
POST /mcp
      ↓
McpController
      ├─ establish trusted caller context
      ├─ resolve ActingFor::Agent
      ├─ resolve Principal
      └─ create MCP::Server with request-specific server_context
              ↓
      PurchaseProductTool
              ↓
      ShoppingAgentPurchase
              ↓
          ActingFor
```

### Why this shape

- The official SDK supports MCP server/client functionality and Streamable HTTP.
- Request-specific trusted identity state can be placed in `server_context`.
- The transport stays replaceable; ActingFor Core only receives its normal domain inputs.
- A stateless controller keeps the first reference integration small and makes the trust boundary easy to inspect.

## Implemented files

The reference slice contains:

- `POST /mcp` handled by `McpController`
- `PurchaseProductTool` as the only MCP tool
- `DemoMcpIdentityResolver` as an explicitly development-only host identity boundary
- routing from the MCP tool to the existing `ShoppingAgentPurchase` service
- `script/mcp_client_verify.rb`, a standalone official MCP HTTP client verifier
- host integration tests for tool discovery, `allow`, `require_approval`, `deny`, and forged extra arguments
- CI verification through a running Rails server over HTTP

## MCP tool

The reference integration intentionally exposes exactly one tool:

```text
purchase_product(product_id)
```

The Agent supplies only the product identifier:

```json
{
  "product_id": 1
}
```

These values are not accepted as tool-controlled authorization inputs:

- `amount`
- `price`
- `agent_id`
- `principal_id`
- `decision`
- `reason_code`

The Rails host establishes them from trusted state.

## Existing host boundary

Both the browser path and the MCP path reuse:

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

```text
Browser Controller ───────┐
                          │
MCP Tool Adapter ─────────┼──> ShoppingAgentPurchase
                          │          ↓
Future API Adapter ───────┘      ActingFor
```

This keeps delegated authorization independent of the transport used to reach Rails.

## Identity and Principal resolution

MCP transport identity and ActingFor Agent identity are separate concepts.

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

The tool arguments themselves do not choose the Agent or Principal.

For this local reference Demo, `DemoMcpIdentityResolver` maps to the pre-provisioned `shopping-agent` and `Demo User`. This resolver is **development-only** and must not be presented as Agent authentication.

A production host can replace this resolver with OAuth/OIDC, API credentials, MCP authorization context, or another authenticated identity source without changing ActingFor or `ShoppingAgentPurchase`.

## Trusted Context boundary

The Agent never supplies the authorization amount.

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

## Decision mapping

| ActingFor Decision | Host execution | MCP result |
| --- | --- | --- |
| `allow` | Purchase created | `executed: true` |
| `require_approval` | No Purchase | `executed: false` |
| `deny` | No Purchase | `executed: false` |

Representative response:

```json
{
  "status": "allow",
  "reason_code": "delegation_allowed",
  "executed": true,
  "purchase_id": 123
}
```

A denied authorization is a normal authorization result, not an MCP transport failure. Authentication failure, identity-resolution failure, invalid input, and unexpected host/system failure remain errors instead of being converted into `deny`.

## Security requirements

The implementation preserves these boundaries:

1. **Agent and Principal are host-resolved.** Tool arguments cannot choose them.
2. **Price is host-resolved.** The Agent cannot choose the authorization amount.
3. **MCP access is not delegated authorization.** Reaching the tool does not imply permission to purchase.
4. **`require_approval != allow`.** No Purchase is created.
5. **Decision is not reusable authority.** Authorization occurs close to the protected operation.
6. **Audit failure stops execution.** An authorization system failure is not converted to success.
7. **No `ActingFor::Internal::*` dependency.** The Demo uses only the public API.
8. **ActingFor Core remains MCP-independent.**

## Error boundary

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

## Automated host integration coverage

The Demo test suite covers:

- MCP `tools/list` exposes only `purchase_product`
- ¥800 → `allow`, Purchase created, AuditEvent recorded
- ¥2,000 → `require_approval`, no Purchase, AuditEvent recorded
- ¥5,000 → `deny`, no Purchase, AuditEvent recorded
- forged `amount`, `agent_id`, and `principal_id` are rejected as extra tool arguments
- the existing browser integration continues to pass

The Demo does not duplicate ActingFor Core matching tests.

## Official MCP client verification

The reference path was verified through a running Rails server using the official `MCP::Client::HTTP`, not only through Rails IntegrationTest.

Verification environment:

- ActingFor: **0.1.1**
- MCP Ruby SDK: **1.6.1**
- HTTP client dependency: **Faraday 2.14.4**
- GitHub Actions run: **36706086236**

The standalone verifier performs an MCP lifecycle connection, lists tools, and calls `purchase_product` for all three seeded products.

Observed results:

```text
MCP product=1: allow / delegation_allowed / executed=true
MCP product=2: require_approval / delegation_requires_approval / executed=false
MCP product=3: deny / no_matching_delegation / executed=false
External MCP client verification: PASS
```

The same CI run also completed the normal Demo suite and HTTP smoke verification:

```text
23 runs
152 assertions
0 failures
0 errors
0 skips
Smoke HTTP: PASS
```

This closes the first reference integration verification goal: a protocol-level MCP HTTP client can invoke the Rails tool endpoint and reach ActingFor-backed delegated authorization end-to-end.

## Non-goals

This reference integration intentionally does not provide:

- MCP implementation inside the `acting_for` gem
- a new ActingFor Public API
- OAuth / OIDC server functionality
- a production Agent authentication standard
- a general Agent provisioning system
- approval workflow or Approval UI
- cumulative / aggregate delegation budgets
- multiple MCP tools

## Core-change gate

Before changing the `acting_for` gem for future MCP work, ask:

> Can this requirement be implemented correctly in the Rails host adapter while keeping the current ActingFor Public API and Security Contract?

For this first MCP reference integration, the answer was **yes**. No ActingFor Core, schema, or Public API change was required.

If future integration work reveals a genuinely missing abstraction, record it separately as a Core design issue rather than coupling MCP protocol objects to ActingFor.

## Completion status

The first MCP reference integration is **complete for its defined scope**:

- official MCP Ruby SDK selected and locked
- `purchase_product(product_id)` exposed through Streamable HTTP
- existing `ShoppingAgentPurchase` reused
- trusted Agent, Principal, and amount boundaries preserved
- all three ActingFor decisions verified
- only `allow` executes a Purchase
- authorization attempts remain audited
- official MCP HTTP client end-to-end verification passed
- existing Demo tests and HTTP smoke verification passed
- ActingFor Core remains unchanged
