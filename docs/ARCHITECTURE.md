# Architecture

## Runtime containers

```text
Mac Host (Docker + Git + optional Codex CLI)
       ↓ Docker Compose
app: Ruby 3.4.10 / Rails 8.0.5.1 / Bundler / demo source
       ↓ PGHOST=db
db: PostgreSQL 16
       ↓
postgres_data named volume
```

The source tree is bind-mounted for development. Installed gems remain in the image, PostgreSQL data remains in `postgres_data`, and Rails temporary/log data uses named volumes. The host's Ruby and PostgreSQL installations are not used.

Codex CLI, when used for the hands-on Agent flow, runs on the Mac host. It connects to the Rails container through the published loopback MCP endpoint at `http://127.0.0.1:3000/mcp`.

## Human and authenticated Agent paths

```text
Human path                       Authenticated Agent path

Human                            User natural language
  ↓                                ↓
Host Authorization              Codex CLI / MCP Client
  ↓                                ↓ Bearer token
HumanPurchase                   Rails Host Application
  ↓ Product.find                  ↓ AgentCredential digest lookup
Purchase                        ActingFor::Agent
                                   ↓ Host resolves Principal
                                 list_products()
                                   ↓ Product DB data
                                 Agent selects returned product_id
                                   ↓ purchase_product(product_id)
                                 ShoppingAgentPurchase
                                   ↓ Product.find(product_id)
                                 Trusted Context { amount: product.price }
                                   ↓ ActingFor.authorize
                                 Decision + automatic AuditEvent
                                   ↓
                                 Purchase when allowed, otherwise Stop
```

The Agent path deliberately separates four layers:

```text
MCP capability
  → list_products / purchase_product

Authentication
  → Bearer credential resolves ActingFor::Agent

Delegated authorization
  → ActingFor decides what that Agent may do for the Principal

Business execution
  → Rails creates Purchase only after allow
```

## Agent authentication

`AgentCredential` is host-application authentication data. It stores a SHA-256 digest of a high-entropy Bearer token and maps the authenticated caller to `ActingFor::Agent`. The raw token is not stored. This is a small Demo reference mechanism, not an ActingFor authentication feature or protocol.

`DemoMcpIdentityResolver` parses `Authorization: Bearer ...`, authenticates the Agent through `AgentCredential`, and resolves the Demo Principal from host-owned state. Missing or invalid credentials return HTTP 401 before the request reaches delegated authorization. Tool arguments cannot select either Agent or Principal.

Authentication failure and authorization denial are intentionally different:

```text
missing / invalid Bearer
  → HTTP 401
  → no ActingFor authorization

valid Bearer for Agent without matching Delegation
  → authentication succeeds
  → ActingFor DENY / no_matching_delegation
```

## MCP tools

### `list_products()`

`ListProductsTool` is read-only. It accepts no inputs and reads current `Product` records from PostgreSQL, returning:

```text
id
name
price
```

Its purpose is discovery. A real Agent such as Codex can find the actual `product_id` before calling the purchase tool instead of guessing IDs.

`list_products` does not:

- choose the Agent
- choose the Principal
- call ActingFor authorization
- create an AuditEvent
- create a Purchase

### `purchase_product(product_id)`

`PurchaseProductTool` accepts only `product_id` and delegates to `ShoppingAgentPurchase` using the authenticated Agent and host-resolved Principal from `server_context`.

It does not accept or trust:

```text
amount
price
agent_id
principal_id
decision
reason_code
```

## Shared purchase boundary

`ShoppingAgentPurchase` is the shared application boundary. The browser controller and MCP purchase tool both call the same service. It fetches the Product, builds verified Context, authorizes immediately before execution, and creates a Purchase only when `decision.allowed?` is true.

```text
product_id from Agent
  ↓
Product.find(product_id)
  ↓
product.price from DB
  ↓
ActingFor.authorize(
  agent: authenticated_agent,
  principal: host_principal,
  action: :purchase,
  resource: product,
  context: { amount: product.price }
)
  ↓
allow             → Purchase.create!
require_approval  → stop
deny              → stop
```

`HumanPurchase` is the direct-human boundary. It fetches the Product and creates a Purchase with the database price. It does not call ActingFor and does not create an ActingFor AuditEvent. The demo assumes host authorization succeeds for Demo User; production applications must enforce their own human authorization before execution.

`DemoDelegationSettings` is deliberately host-application code, not an ActingFor UI. It reads the two active demo Delegations and replaces them atomically by revoking the old records and calling `ActingFor.delegate` twice. Validation happens before the transaction. There is no explicit deny Delegation: amounts above the approval maximum continue to fail closed.

## Component responsibilities

| Component | Responsibility |
| --- | --- |
| Human / Principal | Delegates authority |
| Codex CLI / MCP Client | Interprets user intent, discovers products, selects and calls tools |
| MCP server | Exposes controlled host capabilities |
| `AgentCredential` | Host-owned Bearer credential → Agent mapping |
| `DemoMcpIdentityResolver` | Authenticates Agent and resolves trusted Demo Principal |
| `ListProductsTool` | Read-only DB-backed product discovery |
| `PurchaseProductTool` | Accepts only `product_id` and enters purchase boundary |
| Rails Host App | Agent authentication, Principal resolution, trusted data, Principal authorization, execution |
| ActingFor | Delegated authorization |
| `ShoppingAgentPurchase` | Actual delegated purchase orchestration |
| `AuditEvent` | Authorization audit |

## Default authorization outcomes

The default allow Delegation matches amounts up to ¥1,000. The default approval Delegation matches amounts above ¥1,000 and at most ¥3,000. The host settings screen can replace these limits. There is intentionally no deny Delegation; values above the current approval maximum demonstrate fail-closed behavior.

```text
¥800
  → allow
  → Purchase created

¥2,000
  → require_approval
  → Purchase not created

¥5,000
  → deny / no_matching_delegation
  → Purchase not created
```

Human Approval is not implemented in this Demo. `require_approval` is a stop result, not permission to execute.

## Codex CLI boundary

Codex is an MCP client, not part of ActingFor Core.

The repository's `AGENTS.md` tells Codex only how to preserve the Demo shopping security boundary:

```text
list_products first
never guess product_id
purchase_product for delegated purchases
never bypass Rails by creating Purchase directly
stop on require_approval
```

`bin/setup_codex` registers the local MCP URL using Codex's Bearer-token environment-variable support. It does not store the Bearer token value in the repository or overwrite an existing same-name MCP configuration.

Replacing Codex with another MCP client does not change the Rails/ActingFor boundary.

## Replaceable authentication layer

ActingFor does not replace host authorization and does not authenticate external Agents. The Demo host supplies a small Bearer-token authentication reference before ActingFor is called.

Production applications can replace that layer with OAuth/OIDC, MCP Authorization, API credentials, or another trusted identity source without changing the ActingFor delegated-authorization boundary:

```text
External Agent authentication
        ↓
trusted ActingFor::Agent
        ↓
host-resolved Principal + Resource + Context
        ↓
ActingFor.authorize
```
