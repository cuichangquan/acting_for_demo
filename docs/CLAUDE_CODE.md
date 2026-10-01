# Claude Code Hands-on Agent

This Demo can be used from Claude Code through the same authenticated Streamable HTTP MCP endpoint used by other MCP clients. Claude Code is only the AI Agent/MCP client; ActingFor Core remains unchanged.

## Responsibility boundary

```text
Claude Code
  ↓ natural language
acting-for-demo MCP
  ↓ Authorization: Bearer <token>
Rails Demo
  ↓ Agent authentication + trusted Product data
ActingFor
  ↓ delegated authorization
ALLOW / REQUIRE_APPROVAL / DENY
  ↓
Rails executes only after ALLOW
```

MCP provides capabilities. Bearer authentication establishes which Agent is calling. ActingFor decides what that authenticated Agent may do on behalf of the Principal. Rails owns trusted resource/context resolution and business execution.

## Project MCP configuration

The repository contains `.mcp.json`:

```json
{
  "mcpServers": {
    "acting-for-demo": {
      "type": "http",
      "url": "${ACTING_FOR_DEMO_MCP_URL:-http://127.0.0.1:3000/mcp}",
      "headers": {
        "Authorization": "Bearer ${ACTING_FOR_DEMO_TOKEN}"
      }
    }
  }
}
```

Claude Code supports project-scoped MCP servers in `.mcp.json` and expands environment variables in HTTP URLs and headers. The Bearer token value therefore stays in the user's environment rather than being committed to this repository.

On first use, Claude Code may ask you to trust the workspace and approve the project MCP server. Review and approve it interactively before using the tools.

Official Claude Code MCP reference: <https://code.claude.com/docs/en/mcp>

## Start the Rails Demo

```sh
docker compose build
docker compose run --rm app bin/setup --skip-server
docker compose up
```

The default local development credential is public Demo data, not a production secret:

```text
acting-for-demo-shopping-agent-token
```

If you configured `DEMO_MCP_BEARER_TOKEN` before Demo setup, use the same value for `ACTING_FOR_DEMO_TOKEN` below.

## Configure and verify Claude Code

In another terminal, from this repository:

```sh
export ACTING_FOR_DEMO_TOKEN="acting-for-demo-shopping-agent-token"
bin/setup_claude
```

`bin/setup_claude`:

- checks that the `claude` CLI exists
- verifies the repository's project MCP configuration is present
- does not write to Claude Code user configuration
- does not store the Bearer token value
- verifies that `http://127.0.0.1:3000/mcp` exposes `list_products` and `purchase_product`
- prints the remaining Claude Code startup steps

Then start Claude Code from the repository root:

```sh
claude
```

Inside Claude Code, use:

```text
/mcp
```

to inspect the `acting-for-demo` server status. `claude mcp list` and `claude mcp get acting-for-demo` can also be used from the shell.

## Try the three Demo scenarios

Ask Claude Code:

```text
800円の商品を買って
```

Expected path:

```text
Claude Code
  ↓ list_products()
Everyday Item / ¥800 / returned product_id
  ↓ purchase_product(product_id)
ActingFor
  ↓
ALLOW / delegation_allowed / executed=true
```

Then try:

```text
2000円の商品を買って
```

Expected result:

```text
REQUIRE_APPROVAL / delegation_requires_approval / executed=false
```

Human Approval is not implemented in this Demo, so Claude Code must stop rather than execute the purchase.

Finally:

```text
5000円の商品を買って
```

Expected result:

```text
DENY / no_matching_delegation / executed=false
```

## Claude-specific repository instructions

`CLAUDE.md` keeps the hands-on Agent behavior aligned with the Demo security boundary. For Demo shopping requests, Claude Code is instructed to:

1. use `acting-for-demo`
2. call `list_products` before choosing a product
3. never guess `product_id`
4. use `purchase_product` for delegated purchases
5. never create `Purchase` records directly to bypass the host boundary
6. never invent `agent_id`, `principal_id`, `amount`, `price`, `decision`, or `reason_code`
7. stop on `require_approval`

These instructions are scoped to the Demo shopping flow and do not replace the normal development workflow.

## Security notes

- The checked-in `.mcp.json` contains no Bearer token value.
- The local Demo uses loopback HTTP only; production Bearer credentials require HTTPS.
- A valid Bearer token authenticates the Agent but does not grant delegated authority by itself.
- `list_products` is read-only and discovers DB-backed product IDs.
- `purchase_product` accepts only `product_id`.
- Rails reloads the Product and supplies `Product#price` as trusted authorization Context.
- ActingFor authorization still runs for every delegated purchase.
- `require_approval` is not execution permission.

## Verification status

Automated CI verifies the shared MCP protocol path with the official MCP Ruby HTTP client. Claude Code natural-language interaction runs on the user's local machine and should be recorded separately when manually verified; automated MCP-client evidence must not be relabeled as a Claude Code manual pass.
