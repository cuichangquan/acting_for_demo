# Architecture

```text
Human / Principal
       ↓ creates Delegation
Shopping Agent
       ↓ Purchase Request (product_id only)
Rails Host Application
       ↓ Product.find(product_id)
Trusted Context { amount: product.price }
       ↓
ActingFor.authorize
       ↓ Decision + automatic AuditEvent
Host Business Logic
       ↓
Purchase when allowed, otherwise Stop
```

`ShoppingAgentPurchase` is the shared application boundary. A browser controller calls it today; a future agent tool can call the same service. It fetches the Product, builds verified Context, authorizes immediately before execution, and creates a Purchase only when `decision.allowed?` is true.

| Component | Responsibility |
| --- | --- |
| Human / Principal | Delegates authority |
| Agent | Requests an action |
| Host Rails App | Authentication, trusted data, Principal authorization, execution |
| ActingFor | Delegated authorization |
| Purchase logic | Actual business operation |
| AuditEvent | Authorization audit |

The allow Delegation matches amounts up to ¥1,000. The approval Delegation matches amounts above ¥1,000 and at most ¥3,000. There is intentionally no deny Delegation; values above ¥3,000 demonstrate fail-closed behavior.

ActingFor does not replace host authorization. The demo assumes Demo User may buy every product, but production code must independently confirm the Principal's current host permission. ActingFor also provides no external Agent authentication, transaction-wide atomicity, payment, or approval workflow.
