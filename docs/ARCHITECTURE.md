# Architecture

## Runtime containers

```text
Mac Host (Docker + Git + GitHub SSH only)
       ↓ Docker Compose
app: Ruby 3.4.10 / Rails 8.0.5.1 / Bundler / demo source
       ↓ PGHOST=db
db: PostgreSQL 16
       ↓
postgres_data named volume
```

The source tree is bind-mounted for development. Installed gems remain in the image, PostgreSQL data remains in `postgres_data`, and Rails temporary/log data uses named volumes. The host's Ruby and PostgreSQL installations are not used.

```text
Human path                       Agent path

Human                            Human / Principal
  ↓                                ↓ creates Delegation
Host Authorization              Shopping Agent
  ↓                                ↓ Purchase Request (product_id only)
HumanPurchase                   Rails Host Application
  ↓ Product.find                  ↓ Product.find(product_id)
Purchase                        Trusted Context { amount: product.price }
                                   ↓ ActingFor.authorize
                                 Decision + automatic AuditEvent
                                   ↓
                                 Purchase when allowed, otherwise Stop
```

`ShoppingAgentPurchase` is the shared application boundary. A browser controller calls it today; a future agent tool can call the same service. It fetches the Product, builds verified Context, authorizes immediately before execution, and creates a Purchase only when `decision.allowed?` is true.

`HumanPurchase` is the direct-human boundary. It fetches the Product and creates a Purchase with the database price. It does not call ActingFor and does not create an ActingFor AuditEvent. The demo assumes host authorization succeeds for Demo User; production applications must enforce their own human authorization before execution.

`DemoDelegationSettings` is deliberately host-application code, not an ActingFor UI. It reads the two active demo Delegations and replaces them atomically by revoking the old records and calling `ActingFor.delegate` twice. Validation happens before the transaction. There is no explicit deny Delegation: amounts above the approval maximum continue to fail closed.

| Component | Responsibility |
| --- | --- |
| Human / Principal | Delegates authority |
| Agent | Requests an action |
| Host Rails App | Authentication, trusted data, Principal authorization, execution |
| ActingFor | Delegated authorization |
| Purchase logic | Actual business operation |
| AuditEvent | Authorization audit |

The default allow Delegation matches amounts up to ¥1,000. The default approval Delegation matches amounts above ¥1,000 and at most ¥3,000. The host settings screen can replace these limits. There is intentionally no deny Delegation; values above the current approval maximum demonstrate fail-closed behavior.

ActingFor does not replace host authorization. The demo assumes Demo User may buy every product, but production code must independently confirm the Principal's current host permission. ActingFor also provides no external Agent authentication, transaction-wide atomicity, payment, or approval workflow.
