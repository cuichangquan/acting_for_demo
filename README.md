# ActingFor Shopping Demo

This is the official hands-on reference application for [ActingFor](https://github.com/cuichangquan/acting_for). It shows how ActingFor's public API fits into a real Rails host application and provides automated integration verification plus an environment for human manual verification.

> **Verification note:** ActingFor 0.1.1 is published on RubyGems. The demo verifies the released `Decision#reason_code` Public API and includes an authenticated MCP Streamable HTTP path that can be used directly from Codex CLI or Claude Code.

## Repository responsibilities

- **ActingFor:** authorization library and source of truth for gem behavior, its Public API, and its Security Contract.
- **ActingFor Demo:** host-application example and integration-verification environment. It is the source of truth for demo usage, host integration, Agent authentication reference code, MCP tools, AI coding-agent hands-on usage, and the manual-verification workflow.

The demo does not duplicate the gem specification or replace ActingFor's core CI. `acting_for/test` formally tests gem internals, the Public API, and the Security Contract. `acting_for_demo/test` uses only the public API from a real host application and must not depend on `ActingFor::Internal::*`.

```text
ActingFor implementation / release candidate
  → core CI
  → RubyGems release
  → Demo dependency update
  → Demo integration tests
  → Demo smoke verification
  → Human manual verification
  → Compatibility record
```

Problems found through demo integration are reported back to ActingFor as issues or fix candidates; the demo must not work around the gem's specification merely to pass verification.

## What this demonstrates

- Principal and Agent separation
- Host-owned Bearer Token authentication that resolves a caller to `ActingFor::Agent`
- Delegation constraints and `allow`, `require_approval`, and `deny`
- Fail Closed when no Delegation matches
- A Context Trust Boundary: the host loads `Product#price` from PostgreSQL
- A Host Business Logic Boundary: only `decision.allowed?` creates a `Purchase`
- Automatic ActingFor authorization audit
- Direct human purchases compared with delegated-agent purchases
- A host-built Delegation Settings screen using ActingFor's public API
- An authenticated MCP `list_products()` tool for trusted product discovery
- An authenticated MCP `purchase_product(product_id)` tool routed through the same `ShoppingAgentPurchase` host service
- Codex CLI or Claude Code acting as the real local AI Agent through MCP; no browser AI Chat UI is required

## Delegated purchase flow

With the demo's default Delegation settings, the flow for the ¥800 product looks like this:

```text
Principal (User)
 │
 │ "You may buy products up to ¥1,000."
 ▼
Shopping Agent
 │
 │ Wants to purchase a Product priced at ¥800
 ▼
Rails Host Application
 │
 │ Loads Product#price from PostgreSQL
 ▼
ActingFor
 │
 ├─ Which Agent is acting?
 ├─ On whose behalf is it acting?
 ├─ Is :purchase delegated?
 ├─ Does the Delegation cover this Product?
 ├─ Is the Delegation still valid?
 ├─ Has it been revoked?
 ├─ Does ¥800 satisfy the ¥1,000 constraint?
 │
 ▼
ALLOW
 │
 ├─ AuditEvent is saved automatically
 ▼
Rails Host Application
 │
 ▼
Purchase is created
```

The demo assumes the Principal has host permission to purchase. ActingFor evaluates only the delegated authority, and the Rails host application executes the purchase only when `decision.allowed?` is true.

### 日本語

デモの初期Delegation設定では、¥800の商品購入は次の流れになります。

```text
User
 │
 │ 「1,000円まで買っていいよ」
 ▼
Shopping Agent
 │
 │ Product ¥800を購入したい
 ▼
Rails
 │
 │ PostgreSQLからProduct#priceを取得
 ▼
ActingFor
 │
 ├─ Agentは誰？
 ├─ 誰の代理？
 ├─ purchase権限ある？
 ├─ Product対象？
 ├─ 期限内？
 ├─ revokeされてない？
 ├─ ¥800 <= ¥1,000？
 │
 ▼
ALLOW
 │
 ├─ AuditEventを自動保存
 ▼
Rails
 │
 ▼
Purchase作成
```

このデモでは、User本人には購入権限がある前提です。ActingForはAgentへ委任された権限だけを判定し、`decision.allowed?` がtrueのときだけRails側がPurchaseを作成します。

```text
Human direct path                 Delegated agent path

Human                             Human
  ↓ Host authorization              ↓ delegates
Host Business Logic               Shopping Agent
  ↓ Purchase                         ↓ Host authorization + ActingFor
                                  Host Business Logic
                                    ↓ Purchase or Stop
```

| Product price | Human direct purchase | Shopping Agent purchase |
| ---: | --- | --- |
| ¥800 | Purchase executed | ALLOW → Purchase executed |
| ¥2,000 | Purchase executed | REQUIRE APPROVAL → Not executed |
| ¥5,000 | Purchase executed | DENY (fail closed) → Not executed |

After a Shopping Agent request, the result screen shows both the Decision and its public `reason_code` (for example, `DENY` + `no_matching_delegation`). The Audit Events screen independently shows the persisted String reason for the same authorization decision.

The Human buttons intentionally do not call `ActingFor.authorize` and do not create `ActingFor::AuditEvent` records. The demo assumes Demo User has host permission for every product; a production application must perform its own authorization for direct human actions.

The browser-accessible Delegation Settings screen changes the two demo limits and shows how delegated authority changes agent outcomes. It revokes existing demo Delegations and creates replacements through `ActingFor.delegate` in a database transaction. It is an example UI owned by this host Rails application—not an admin UI supplied by ActingFor v0.1.

## MCP + Bearer Agent authentication reference path

The authenticated MCP path is deliberately small:

```text
Codex CLI / Claude Code / MCP Client
   ↓ Authorization: Bearer <token>
POST /mcp
   ↓
DemoMcpIdentityResolver
   ↓ token digest lookup
AgentCredential
   ↓
ActingFor::Agent
   ↓
list_products()
   ↓ trusted Product data from Rails DB
Agent selects returned product_id
   ↓
purchase_product(product_id)
   ↓
ShoppingAgentPurchase
   ↓ Product.find + Product#price
ActingFor.authorize(...)
   ↓
ALLOW / REQUIRE_APPROVAL / DENY
```

The Bearer token authenticates the Agent; it does **not** authorize a purchase. ActingFor still evaluates whether that authenticated Agent has a matching Delegation for the host-resolved Principal.

The raw Bearer token is not stored in the database. `AgentCredential` stores a SHA-256 digest and maps it to the local `ActingFor::Agent`.

`list_products` takes no authorization inputs and returns current Demo product `id`, `name`, and `price` from PostgreSQL. `purchase_product` accepts only `product_id`. Rails resolves the Agent from the credential, resolves the Demo Principal on the host, reloads the Product, and uses `Product#price` as trusted authorization Context.

The MCP caller cannot supply the authorization amount, Agent ID, Principal ID, Decision, or reason code.

The full design and security boundary are documented in [MCP + Bearer Agent Authentication reference integration](docs/AGENT_INTEGRATION.md).

## Requirements

- Docker Desktop or Docker Engine with Docker Compose
- Git
- Codex CLI or Claude Code only for the optional real-Agent hands-on flows

Ruby, Rails, Bundler gems, and PostgreSQL run inside Docker. They are not required on the Mac host. The images use Ruby 3.4.10, Rails 8.0.5.1, and PostgreSQL 16.

## Quick Start

```sh
git clone git@github.com:cuichangquan/acting_for_demo.git
cd acting_for_demo
docker compose build
docker compose run --rm app bin/setup --skip-server
docker compose up
```

Open <http://localhost:3000>. `app` connects to the Compose `db` service; it does not use a PostgreSQL server on the Mac.

For the local MCP reference only, Docker Compose provides this public development credential by default:

```text
acting-for-demo-shopping-agent-token
```

It is intentionally not a production secret. To use your own local token, set it **before** running setup so the same value is digested into the database:

```sh
export DEMO_MCP_BEARER_TOKEN="replace-with-a-local-random-token"
docker compose run --rm app bin/setup --skip-server
docker compose up
```

For optional database inspection from the Mac (for example, with TablePlus), use host `127.0.0.1`, port `5432`, user `postgres`, password `demo_password_not_for_production`, database `acting_for_demo_development`, and disable SSL. This development-only credential is defined by Compose and must not be reused outside this demo.

The image installs the released ActingFor gem resolved by `Gemfile` / `Gemfile.lock`. No GitHub credentials, SSH agent, or SSH forwarding are required.

Run tests and reset the demo through Docker:

```sh
docker compose run --rm app bin/rails test
docker compose run --rm app bin/reset_demo
```

Stop containers without deleting database data using `docker compose down`. To completely reset Docker-managed database and runtime volumes, use `docker compose down -v`; **`-v` permanently deletes the demo database volume**. Then repeat setup. `bin/reset_demo` also drops and recreates only the non-production demo databases.

## Hands-on with AI coding agents

Both Codex CLI and Claude Code can connect to the same Streamable HTTP MCP endpoint. They are replaceable MCP clients; the Rails authentication, ActingFor authorization, trusted Context, and business-execution boundaries remain identical.

### Codex CLI

OpenAI's current Codex CLI supports `codex mcp add <name> --url <url>` and `--bearer-token-env-var <ENV_VAR>` for HTTP Bearer authentication.

Start the Demo first using the Quick Start above. Then, in the repository directory:

```sh
export ACTING_FOR_DEMO_TOKEN="acting-for-demo-shopping-agent-token"
bin/setup_codex
```

`bin/setup_codex`:

- adds `acting-for-demo` only when that MCP name is not already configured
- never removes or overwrites an existing MCP entry
- stores only the **environment-variable name** in Codex configuration, not the Bearer token value
- verifies that the local MCP endpoint exposes `list_products` and `purchase_product`

The helper changes Codex's normal user MCP configuration only when the entry is absent. If an entry with the same name already exists, it prints that configuration and leaves it unchanged.

You can also configure Codex manually:

```sh
export ACTING_FOR_DEMO_TOKEN="acting-for-demo-shopping-agent-token"

codex mcp add acting-for-demo \
  --url http://127.0.0.1:3000/mcp \
  --bearer-token-env-var ACTING_FOR_DEMO_TOKEN

codex mcp get acting-for-demo
codex mcp list
```

The token environment variable must be present in the shell that starts Codex. The repository includes a small `AGENTS.md` so Codex uses the MCP security boundary for Demo shopping requests without turning those instructions into a general development workflow.

Start Codex from this repository:

```sh
codex
```

OpenAI's current Codex MCP quickstart: <https://developers.openai.com/learn/docs-mcp>

### Claude Code

Claude Code supports project-scoped HTTP MCP configuration in `.mcp.json`, including environment-variable expansion in HTTP headers. This repository includes `.mcp.json` with `acting-for-demo` preconfigured and the Bearer token referenced as `${ACTING_FOR_DEMO_TOKEN}`; the token value is not committed.

Start the Demo first, then in another terminal:

```sh
export ACTING_FOR_DEMO_TOKEN="acting-for-demo-shopping-agent-token"
bin/setup_claude
claude
```

`bin/setup_claude`:

- checks that Claude Code CLI is available
- validates the repository's project MCP configuration
- never writes to Claude Code user configuration
- never stores the Bearer token value
- verifies `list_products` and `purchase_product` when the token is available

On first use, Claude Code may ask you to trust the workspace and approve the project MCP server. Review and approve it interactively. Inside Claude Code, `/mcp` shows the server status. The repository's `CLAUDE.md` gives Claude Code the same Demo-shopping security boundary used for Codex.

Detailed Claude Code instructions: [Claude Code hands-on Agent](docs/CLAUDE_CODE.md).

Official Claude Code MCP reference: <https://code.claude.com/docs/en/mcp>

### Try the Demo

With either Agent, try:

```text
800円の商品を買って
```

Expected Agent path:

```text
AI Agent
  ↓ list_products()
Everyday Item / ¥800 / returned product_id
  ↓ purchase_product(product_id)
Bearer Agent Authentication
  ↓
ActingFor.authorize
  ↓
ALLOW / delegation_allowed
  ↓
Purchase created
```

The three default outcomes are:

```text
800円
  → ALLOW / delegation_allowed / executed=true

2000円
  → REQUIRE_APPROVAL / delegation_requires_approval / executed=false
  → Human Approval is not implemented yet

5000円
  → DENY / no_matching_delegation / executed=false
```

CI verifies the same `list_products → purchase_product` MCP path with the official MCP Ruby HTTP client. Natural-language Codex CLI and Claude Code interactions themselves are local manual verification steps because those Agent CLIs run on the user's machine.

The Demo message is:

```text
MCP gives the AI Agent capabilities.
Authentication establishes who the Agent is.
ActingFor controls what that Agent may do on behalf of the Principal.
Rails executes the business action only after authorization.
```

## Security notes

- Agent-supplied `amount` is not trusted or used for authorization.
- Rails loads `Product` by `product_id` and supplies `product.price` as trusted Context.
- `list_products` exposes current Demo product data read from the Rails database; it does not make an authorization Decision or create a Purchase.
- The Demo host authenticates MCP Agents with a Bearer token and maps its digest to `ActingFor::Agent`.
- A valid Bearer credential identifies the Agent; it does not grant ActingFor authority by itself.
- Missing or invalid MCP Bearer credentials return HTTP `401` before delegated authorization.
- Tool arguments cannot choose the Agent or Principal.
- The Demo's Principal lookup is intentionally small and host-owned; a real multi-user application must resolve the Principal from its own trusted context.
- ActingFor authorizes; it does not authenticate Agents or execute purchases.
- `require_approval` is not `allow`. This demo stops without implementing approval.
- Production applications must independently verify that the Principal itself is authorized to perform the operation. For simplicity, Demo User is assumed to have host permission for every product.
- Direct human purchases bypass delegated authorization and therefore do not appear in ActingFor Audit Events.
- Authorize close to execution; a Decision is not a reusable authorization token.
- Production Bearer tokens require HTTPS, high entropy, and an appropriate rotation/revocation policy. The default Demo token must never be reused as a real secret.

## ActingFor dependency

The demo uses the released RubyGems dependency:

```ruby
gem "acting_for", "~> 0.1.1"
```

`Gemfile.lock` resolves `acting_for 0.1.1` from RubyGems and records the published gem checksum. The earlier exact-Git candidate dependency was used only for pre-release verification and is preserved in `docs/COMPATIBILITY.md` as historical evidence.

## More documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Compatibility](docs/COMPATIBILITY.md)
- [Manual verification checklist](docs/MANUAL_VERIFICATION.md)
- [MCP + Bearer Agent Authentication reference integration](docs/AGENT_INTEGRATION.md)
- [Claude Code hands-on Agent](docs/CLAUDE_CODE.md)

## Tests

```sh
docker compose run --rm app bin/rails db:prepare
docker compose run --rm app bin/rails test
```

The tests exercise the host integration, not ActingFor's internal test suite.

## License

MIT, matching ActingFor. See [LICENSE](LICENSE).
