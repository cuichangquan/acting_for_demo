# MCP + Bearer Agent Authentication Reference Integration

Status: **Implemented; verification runs through Demo CI**

This document describes the Agent integration boundary in the ActingFor Shopping Demo. The Demo connects an MCP HTTP client to Rails, authenticates the calling Agent with a Bearer token, maps that identity to a local `ActingFor::Agent`, and then reuses the existing delegated-authorization boundary.

ActingFor Core remains responsible only for delegated authorization. Authentication, MCP transport, Principal resolution, Resource loading, trusted Context, and business execution remain responsibilities of the Rails host application.

## Goal

Demonstrate one complete host-owned path:

```text
MCP Client / AI Agent
        ↓
Authorization: Bearer <token>
        ↓ Streamable HTTP
POST /mcp
        ↓
Rails authenticates token
        ↓
AgentCredential
        ↓
ActingFor::Agent
        ↓
Host resolves Principal
        ↓
purchase_product(product_id)
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

The important separation is:

```text
Bearer authentication
  → Who is this Agent?

ActingFor authorization
  → May this Agent perform this Action on behalf of this Principal?
```

## Responsibility boundary

The integration does **not** move authentication or MCP responsibilities into the `acting_for` gem.

- The MCP client sends requests to the Rails host.
- The Rails host authenticates the Bearer credential.
- The Rails host maps the authenticated credential to `ActingFor::Agent`.
- The Rails host resolves the Principal independently from tool arguments.
- The Rails host loads the Product and establishes trusted Context.
- ActingFor evaluates Delegation, constraints, expiry, and revocation.
- ActingFor returns `allow`, `require_approval`, or `deny` and persists its AuditEvent.
- The Rails host executes the business operation only for `allow`.

ActingFor Core, its database schema, and its Public API are unchanged by this Demo integration.

## Selected MCP implementation

The Demo uses the official MCP Ruby SDK:

```ruby
gem "mcp", "~> 1.6.1"
```

The reference path uses Streamable HTTP through `POST /mcp` and remains stateless.

The official MCP HTTP client supports custom headers, so the verifier sends the Agent credential as:

```ruby
transport = MCP::Client::HTTP.new(
  url: endpoint,
  headers: {
    "Authorization" => "Bearer #{bearer_token}"
  }
)
```

## Agent credential model

Agent authentication is implemented by the Demo host with `AgentCredential`.

```text
AgentCredential
  agent_id
  token_digest
```

The raw Bearer token is **not stored in the database**. The host stores only:

```text
SHA-256(raw bearer token)
```

At request time:

```text
Authorization: Bearer <raw token>
        ↓
SHA-256
        ↓
AgentCredential.token_digest lookup
        ↓
ActingFor::Agent
```

This is a small reference implementation, not a new authentication protocol and not an ActingFor feature.

Production systems should use high-entropy credentials, HTTPS, rotation/revocation policy, and an appropriate authentication provider. OAuth/OIDC or MCP Authorization can replace this Demo credential layer without changing `ActingFor.authorize`.

## Demo credential

Docker Compose exposes a development-only environment variable:

```text
DEMO_MCP_BEARER_TOKEN
```

For local reproducibility, the Demo default is:

```text
acting-for-demo-shopping-agent-token
```

This value is intentionally a public development credential and **must never be reused as a production secret**.

A custom local value can be supplied before setup/start:

```sh
export DEMO_MCP_BEARER_TOKEN="replace-with-a-local-random-token"
docker compose run --rm app bin/setup --skip-server
docker compose up
```

The seed process stores only the digest of that value in `agent_credentials`.

## MCP request authentication

`McpController` authenticates the request before creating the MCP server/transport.

```text
POST /mcp
  ↓
DemoMcpIdentityResolver
  ↓
valid Bearer token?
  ├─ no  → HTTP 401 + WWW-Authenticate: Bearer
  └─ yes → request-specific server_context
```

The `server_context` contains trusted host objects:

```ruby
{
  agent: authenticated_agent,
  principal: host_resolved_principal
}
```

Authentication failure is not converted into an ActingFor `deny`. It is an HTTP authentication failure and never reaches delegated authorization.

## Agent vs Principal resolution

The Bearer token identifies the Agent. It does not allow the caller to choose a Principal.

For this deliberately small shopping Demo:

- Bearer token → `ActingFor::Agent`
- Host Demo configuration → `Demo User`

The Principal is therefore still host-resolved. The tool request cannot send `principal_id` to switch principals.

A real multi-user host would replace the Demo Principal lookup with its own trusted account/session/resource/authorization context.

## MCP tool

The reference integration exposes exactly one tool:

```text
purchase_product(product_id)
```

The Agent supplies only:

```json
{
  "product_id": 1
}
```

The following are not accepted as caller-controlled authorization inputs:

- `amount`
- `price`
- `agent_id`
- `principal_id`
- `decision`
- `reason_code`

This prevents the caller from overriding authenticated identity or trusted business data.

## Existing host boundary

Both browser and MCP paths reuse:

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
Authenticated MCP Tool ───┼──> ShoppingAgentPurchase
                          │          ↓
Future API Adapter ───────┘      ActingFor
```

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

Representative authorized response:

```json
{
  "status": "allow",
  "reason_code": "delegation_allowed",
  "executed": true,
  "purchase_id": 123
}
```

Authentication and authorization remain distinct:

```text
Missing / invalid Bearer token
  → HTTP 401

Authenticated Agent with no matching Delegation
  → ActingFor deny / no_matching_delegation
```

This distinction is important because a valid Agent identity does not imply delegated authority.

## Security requirements

The implementation preserves these boundaries:

1. **Bearer credentials authenticate Agents; they do not authorize purchases.**
2. **Raw tokens are not persisted.** Only a SHA-256 digest is stored.
3. **Agent is host-resolved from the credential.** Tool arguments cannot choose it.
4. **Principal is host-resolved.** Tool arguments cannot choose it.
5. **Price is host-resolved.** The Agent cannot choose the authorization amount.
6. **`require_approval != allow`.** No Purchase is created.
7. **Decision is not reusable authority.** Authorization occurs close to the operation.
8. **Audit failure stops execution.** Authorization system failure is not converted to success.
9. **No `ActingFor::Internal::*` dependency.** The Demo uses only ActingFor public APIs.
10. **ActingFor Core remains authentication- and MCP-independent.**

Bearer tokens must be transported over HTTPS in production. Plain HTTP is used here only for the local loopback Docker Demo.

## Error boundary

```text
Missing / malformed / invalid Bearer token
        → HTTP 401 before MCP execution

Valid token for an Agent without matching Delegation
        → ActingFor deny

Unknown product_id
        → host input/resource error

ActingFor returns require_approval
        → normal authorization result, no Purchase

Audit persistence / database failure
        → system error, no Purchase
```

## Automated coverage

The Demo test suite covers:

- missing Bearer token → `401 Unauthorized`
- invalid Bearer token → `401 Unauthorized`
- authenticated `tools/list` exposes only `purchase_product`
- ¥800 → `allow`, Purchase created, AuditEvent recorded
- ¥2,000 → `require_approval`, no Purchase, AuditEvent recorded
- ¥5,000 → `deny`, no Purchase, AuditEvent recorded
- a valid credential for a different Agent resolves that Agent and receives `deny` when it has no Delegation
- forged `amount`, `agent_id`, and `principal_id` are rejected as extra tool arguments
- the existing browser integration continues to run independently

The Demo also includes model coverage proving that `AgentCredential.issue!` stores a digest rather than the raw token.

## Official MCP client verification

`script/mcp_client_verify.rb` uses the official `MCP::Client::HTTP` transport and sends the Bearer header on every request.

CI verifies:

```text
official MCP HTTP client
  ↓ Bearer authentication
Rails MCP endpoint
  ↓ Agent resolution
purchase_product
  ↓
ShoppingAgentPurchase
  ↓
ActingFor
```

The verifier calls all three seeded products and expects:

```text
¥800   → allow / delegation_allowed / executed=true
¥2,000 → require_approval / delegation_requires_approval / executed=false
¥5,000 → deny / no_matching_delegation / executed=false
```

The earlier pre-auth MCP reference verification remains historical evidence. The Bearer-authenticated path is the current Demo design.

## Non-goals

This integration intentionally does not provide:

- authentication inside the `acting_for` gem
- OAuth/OIDC server functionality
- MCP Authorization server implementation
- a new Agent identity standard
- a general Agent provisioning/admin system
- token refresh protocol
- approval workflow or Approval UI
- cumulative/aggregate delegation budgets
- multiple MCP tools

## Core-change gate

Before changing the `acting_for` gem for future Agent integration work, ask:

> Can this requirement be implemented correctly in the Rails host while keeping the current ActingFor Public API and Security Contract?

Bearer Agent authentication can be implemented entirely in the host. Therefore this change does not require an ActingFor Core change.
