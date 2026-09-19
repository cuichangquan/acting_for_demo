# Future Agent Integration

No LLM provider is connected in v0.1. A future integration can keep the authorization and execution boundary unchanged:

```text
Claude / ChatGPT / Custom Agent
       ↓ Tool Call
Rails Host Application
       ↓ trusted database lookup
ShoppingAgentPurchase
       ↓
ActingFor
       ↓
Host Business Logic
```

Possible tools are `search_products`, `get_product`, and `purchase_product`. A tool name and an ActingFor Action are related mappings, not necessarily the same concept. For example, the `purchase_product` tool may map to the stable domain Action `purchase` after the host validates and normalizes its input.

For `purchase_product`, accept a product identifier, authenticate the external Agent, resolve it to the pre-provisioned `ActingFor::Agent`, establish the Principal, and call `ShoppingAgentPurchase`. Never trust an Agent-declared price or amount: reload the Product and use its database price. Return only the minimal decision information appropriate for the caller; protect AuditEvent access separately.

External Agent authentication, OAuth, sessions, provider SDKs, and tool transport are host responsibilities and intentionally absent here.
