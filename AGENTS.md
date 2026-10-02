# ActingFor Shopping Demo

These instructions apply when using Codex as the hands-on shopping Agent in this repository. They do not change the normal development workflow for editing or testing the codebase.

When the user asks to inspect or purchase demo products:

1. Use the `acting-for-demo` MCP server.
2. Call `list_products` before selecting a product. Never guess `product_id`.
3. Use `purchase_product` for delegated purchases.
4. Treat the MCP result as authoritative and report `allow`, `require_approval`, or `deny`, including whether the purchase was executed.
5. Never bypass the Rails host boundary by directly creating `Purchase` records for an Agent request.
6. Never invent or supply authorization inputs such as `agent_id`, `principal_id`, `amount`, `price`, `decision`, or `reason_code`. Agent identity, Principal, trusted price, and authorization results are host-controlled.
7. `require_approval` means stop. This demo does not implement Human Approval yet.
