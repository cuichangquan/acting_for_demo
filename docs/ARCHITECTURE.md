# Architecture

## Runtime containers

```text
Mac Host (Docker + Git)
       ↓ Docker Compose
app: Ruby 3.4.10 / Rails 8.0.5.1 / Bundler / demo source
       ↓ PGHOST=db
db: PostgreSQL 16
       ↓
postgres_data named volume
```

The source tree is bind-mounted for development. Installed gems remain in the image, PostgreSQL data remains in `postgres_data`, and Rails temporary/log data uses named volumes. The host's Ruby and PostgreSQL installations are not used.

```text
Human path                       Authenticated Agent path

Human                            MCP Client / AI Agent
  ↓                                ↓ Bearer token
Host Authorization              Rails Host Application
  ↓                                ↓ AgentCredential digest lookup
HumanPurchase                   ActingFor::Agent
  ↓ Product.find                  ↓ Host resolves Principal
Purchase                          ↓ purchase_product(product_id)
                                 ShoppingAgentPurchase
                                   ↓ Product.find(product_id)
                                 Trusted Context { amount: product.price }
                                   ↓ ActingFor.authorize
                                 Decision + automatic AuditEvent
                                   ↓
                                 Purchase when allowed, otherwise Stop
```

`AgentCredential` is host-application authentication data. It stores a SHA-256 digest of a high-entropy Bearer token and maps the authenticated caller to `ActingFor::Agent`. The raw token is not stored. This is a small Demo reference mechanism, not an ActingFor authentication feature or protocol.

`DemoMcpIdentityResolver` parses `Authorization: Bearer ...`, authenticates the Agent through `AgentCredential`, and resolves the Demo Principal from host-owned state. Missing or invalid credentials return HTTP 401 before the request reaches delegated authorization. Tool arguments cannot select either Agent or Principal.

`ShoppingAgentPurchase` is the shared application boundary. The browser controller and MCP tool both call the same service. It fetches the Product, builds verified Context, authorizes immediately before execution, and creates a Purchase only when `decision.allowed?` is true.

`HumanPurchase` is the direct-human boundary. It fetches the Product and creates a Purchase with the database price. It does not call ActingFor and does not create an ActingFor AuditEvent. The demo assumes host authorization succeeds for Demo User; production applications must enforce their own human authorization before execution.

`DemoDelegationSettings` is deliberately host-application code, not an ActingFor UI. It reads the two active demo Delegations and replaces them atomically by revoking the old records and calling `ActingFor.delegate` twice. Validation happens before the transaction. There is no explicit deny Delegation: amounts above the approval maximum continue to fail closed.

| Component | Responsibility |
| --- | --- |
| Human / Principal | Delegates authority |
| MCP Client / AI Agent | Presents a credential and requests an action |
| AgentCredential | Host-owned Bearer credential → Agent mapping |
| Host Rails App | Agent authentication, Principal resolution, trusted data, Principal authorization, execution |
| ActingFor | Delegated authorization |
| Purchase logic | Actual business operation |
| AuditEvent | Authorization audit |

The default allow Delegation matches amounts up to ¥1,000. The default approval Delegation matches amounts above ¥1,000 and at most ¥3,000. The host settings screen can replace these limits. There is intentionally no deny Delegation; values above the current approval maximum demonstrate fail-closed behavior.

ActingFor does not replace host authorization and does not authenticate external Agents. The Demo host supplies a small Bearer-token authentication reference before ActingFor is called. Production applications can replace that layer with OAuth/OIDC, MCP Authorization, API credentials, or another trusted identity source without changing the ActingFor delegated-authorization boundary.
