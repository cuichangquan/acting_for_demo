# MCP + Bearer Agent Authentication Reference Integration

Status: **Implemented; automated verification runs through Demo CI. Codex CLI natural-language verification is a local manual step.**

This document describes the Agent integration boundary in the ActingFor Shopping Demo. The Demo connects an MCP HTTP client to Rails, authenticates the calling Agent with a Bearer token, maps that identity to a local `ActingFor::Agent`, exposes trusted product discovery, and then reuses the existing delegated-authorization boundary for purchases.

ActingFor Core remains responsible only for delegated authorization. Authentication, MCP transport, Principal resolution, Resource loading, trusted Context, product discovery, and business execution remain responsibilities of the Rails host application.

## Goal

Demonstrate one complete host-owned path that can be driven by a real local AI Agent such as Codex CLI:

```text
User
  ↓ natural language
Codex CLI / MCP Client
  ↓
list_products()
  ↓ trusted product data
Codex selects returned product_id
  ↓
purchase_product(product_id)
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
ShoppingAgentPurchase
  ↓ Product.find(product_id)
  ↓ Product#price as trusted Context
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
MCP
  → What capabilities/tools can the Agent call?

Bearer authentication
  → Who is this Agent?

ActingFor authorization
  → May this Agent perform this Action on behalf of this Principal?

Rails host
  → Execute the business action only after authorization.
```

## Responsibility boundary

The integration does **not** move authentication or MCP responsibilities into the `acting_for` gem.

- The MCP client sends requests to the Rails host.
- The Rails host authenticates the Bearer credential.
- The Rails host maps the authenticated credential to `ActingFor::Agent`.
- The Rails host resolves the Principal independently from tool arguments.
- `list_products` reads current product data from PostgreSQL.
- `purchase_product` accepts only a returned `product_id`.
- The Rails host reloads the Product and establishes trusted Context from `Product#price`.
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

For Codex CLI, use a separate client-side environment variable whose value must match the Demo credential:

```sh
export ACTING_FOR_DEMO_TOKEN="acting-for-demo-shopping-agent-token"
```

Codex configuration stores the environment-variable **name**, not the token value.

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

The Principal is therefore still host-resolved. Tool requests cannot send `principal_id` to switch principals.

A real multi-user host would replace the Demo Principal lookup with its own trusted account/session/resource/authorization context.

## MCP tools

The Demo exposes two tools:

```text
list_products()
purchase_product(product_id)
```

### `list_products()`

This is a read-only discovery tool. It accepts no caller-controlled authorization inputs and returns current Demo product data from PostgreSQL.

Conceptual result:

```json
[
  { "id": 1, "name": "Everyday Item", "price": 800 },
  { "id": 2, "name": "Approval Item", "price": 2000 },
  { "id": 3, "name": "Expensive Item", "price": 5000 }
]
```

The MCP result also provides structured content under `products` so clients can consume the same data programmatically.

`list_products` does **not** call `ActingFor.authorize`, create an AuditEvent, or create a Purchase. Its purpose is to let the Agent discover a real `product_id` rather than guess one.

### `purchase_product(product_id)`

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

Correct Agent behavior is:

```text
list_products()
  ↓
select a product from returned data
  ↓
purchase_product(returned product_id)
```

The Agent must not guess `product_id`.

## Existing host boundary

Both browser and MCP purchase paths reuse:

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
Agent gets product_id from list_products
        ↓
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

## Codex CLI connection

OpenAI's current Codex CLI supports Streamable HTTP MCP registration with:

```sh
codex mcp add <name> \
  --url <url> \
  --bearer-token-env-var <ENV_VAR>
```

For this Demo:

```sh
export ACTING_FOR_DEMO_TOKEN="acting-for-demo-shopping-agent-token"

codex mcp add acting-for-demo \
  --url http://127.0.0.1:3000/mcp \
  --bearer-token-env-var ACTING_FOR_DEMO_TOKEN

codex mcp get acting-for-demo
codex mcp list
```

The OpenAI Codex MCP quickstart is maintained at <https://developers.openai.com/learn/docs-mcp>.

The repository provides:

```sh
bin/setup_codex
```

The helper:

1. checks that `codex` is available
2. checks whether `acting-for-demo` already exists
3. adds the MCP server only if absent
4. never removes or overwrites an existing entry
5. verifies the local `/mcp` endpoint exposes both tools
6. prints the environment-variable step required before starting Codex

If an existing `acting-for-demo` entry is stale, the helper asks the user to remove it explicitly with `codex mcp remove acting-for-demo`; it does not make that destructive configuration decision automatically.

## `AGENTS.md`

The repository-level `AGENTS.md` is intentionally small and applies only to Demo shopping interactions. It tells Codex to:

- use `acting-for-demo`
- call `list_products` before selecting a product
- never guess `product_id`
- use `purchase_product` for delegated purchases
- report the returned ActingFor result
- never bypass the host boundary by creating Purchases directly for an Agent request
- never invent caller-controlled authorization fields
- stop on `require_approval`

It does not attempt to turn Codex into a fixed state machine and does not change ordinary code-development tasks in the repository.

## Hands-on flow

Start the Demo, configure Codex once, then launch Codex from this repository:

```sh
export ACTING_FOR_DEMO_TOKEN="acting-for-demo-shopping-agent-token"
bin/setup_codex
codex
```

Example request:

```text
800円の商品を買って
```

Expected tool behavior:

```text
Codex
  ↓ list_products
Everyday Item / ¥800 / returned id
  ↓ purchase_product(returned id)
ActingFor
  ↓
ALLOW / delegation_allowed
  ↓
executed=true
```

The three default scenarios are:

```text
¥800
  → allow / delegation_allowed / executed=true
  → Purchase created
  → AuditEvent created

¥2,000
  → require_approval / delegation_requires_approval / executed=false
  → no Purchase
  → AuditEvent created

¥5,000
  → deny / no_matching_delegation / executed=false
  → no Purchase
  → AuditEvent created
```

Human Approval remains outside this change. For ¥2,000, the correct result is to stop and explain that human approval is required and the purchase was not executed.

## Security requirements

The implementation preserves these boundaries:

1. **Bearer credentials authenticate Agents; they do not authorize purchases.**
2. **Raw tokens are not persisted.** Only a SHA-256 digest is stored.
3. **Agent is host-resolved from the credential.** Tool arguments cannot choose it.
4. **Principal is host-resolved.** Tool arguments cannot choose it.
5. **Product price is host-resolved.** The Agent cannot choose the authorization amount.
6. **Product ID is discovered, not guessed.** `list_products` returns current DB-backed IDs.
7. **`require_approval != allow`.** No Purchase is created.
8. **Decision is not reusable authority.** Authorization occurs close to the operation.
9. **Audit failure stops execution.** Authorization system failure is not converted to success.
10. **No `ActingFor::Internal::*` dependency.** The Demo uses only ActingFor public APIs.
11. **ActingFor Core remains authentication- and MCP-independent.**

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
- authenticated `tools/list` exposes `list_products` and `purchase_product`
- valid Bearer → `list_products` returns DB-backed `id`, `name`, and `price`
- `list_products` creates neither Purchase nor AuditEvent
- ¥800 → `allow`, Purchase created, AuditEvent recorded
- ¥2,000 → `require_approval`, no Purchase, AuditEvent recorded
- ¥5,000 → `deny`, no Purchase, AuditEvent recorded
- a valid credential for a different Agent resolves that Agent and receives `deny` when it has no Delegation
- forged `amount`, `agent_id`, and `principal_id` are rejected as extra purchase-tool arguments
- the existing browser integration continues to run independently

The Demo also includes model coverage proving that `AgentCredential.issue!` stores a digest rather than the raw token.

## Official MCP client verification

`script/mcp_client_verify.rb` uses the official `MCP::Client::HTTP` transport and sends the Bearer header on every request.

The verifier now follows the same discovery pattern expected from an AI Agent:

```text
official MCP HTTP client
  ↓ Bearer authentication
Rails MCP endpoint
  ↓
list_products
  ↓ discover DB-backed IDs by price/name
purchase_product(returned product_id)
  ↓
ShoppingAgentPurchase
  ↓
ActingFor
```

It expects:

```text
¥800   → allow / delegation_allowed / executed=true
¥2,000 → require_approval / delegation_requires_approval / executed=false
¥5,000 → deny / no_matching_delegation / executed=false
```

This is automated protocol/integration evidence. It does not claim that a local natural-language Codex CLI session was run in CI.

## Manual Codex verification

A release/feature verification can additionally record the real local Agent experience:

```text
$ codex

> 800円の商品を買って

Codex
  → list_products
  → purchase_product
  → allow / executed=true
```

Repeat with ¥2,000 and ¥5,000 and confirm the expected outcomes above. Also confirm that the Agent did not guess IDs, did not bypass the MCP purchase tool, and did not treat `require_approval` as execution permission.

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
- a browser AI Chat UI

## Core-change gate

Before changing the `acting_for` gem for future Agent integration work, ask:

> Can this requirement be implemented correctly in the Rails host while keeping the current ActingFor Public API and Security Contract?

Codex CLI connectivity, Bearer Agent authentication, product discovery, and MCP tool routing can all be implemented entirely in the host. Therefore this change does not require an ActingFor Core change.
