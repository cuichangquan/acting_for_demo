# ActingFor Shopping Demo

This is the official hands-on reference application for [ActingFor](https://github.com/cuichangquan/acting_for). It shows how ActingFor's public API fits into a real Rails host application and provides automated integration verification plus an environment for human manual verification.

> **Pre-release note:** ActingFor is not yet published to RubyGems and its source repository is currently private. Until the gem is released or the source becomes public, installing this demo requires access to the ActingFor repository. The demo repository is also private during this verification phase.

## Repository responsibilities

- **ActingFor:** authorization library and source of truth for gem behavior, its Public API, and its Security Contract.
- **ActingFor Demo:** host-application example and integration-verification environment. It is the source of truth for demo usage, host integration, and the manual-verification workflow.

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
- Delegation constraints and `allow`, `require_approval`, and `deny`
- Fail Closed when no Delegation matches
- A Context Trust Boundary: the host loads `Product#price` from PostgreSQL
- A Host Business Logic Boundary: only `decision.allowed?` creates a `Purchase`
- Automatic ActingFor authorization audit
- Direct human purchases compared with delegated-agent purchases
- A host-built Delegation Settings screen using ActingFor's public API

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

The Human buttons intentionally do not call `ActingFor.authorize` and do not create `ActingFor::AuditEvent` records. The demo assumes Demo User has host permission for every product; a production application must perform its own authorization for direct human actions.

The browser-accessible Delegation Settings screen changes the two demo limits and shows how delegated authority changes agent outcomes. It revokes existing demo Delegations and creates replacements through `ActingFor.delegate` in a database transaction. It is an example UI owned by this host Rails application—not an admin UI supplied by ActingFor v0.1.

## Requirements

- Docker Desktop or Docker Engine with Docker Compose and BuildKit
- Git
- An SSH agent with a GitHub key authorized to read the private ActingFor repository
- Git access to the private ActingFor repository during the pre-release period

Ruby, Rails, Bundler gems, and PostgreSQL run inside Docker. They are not required on the Mac host. The images use Ruby 3.4.10, Rails 8.0.5.1, and PostgreSQL 16.

## Quick Start

```sh
git clone git@github.com:cuichangquan/acting_for_demo.git
cd acting_for_demo
docker compose build --ssh default
docker compose run --rm app bin/setup --skip-server
docker compose up
```

Open <http://localhost:3000>. `app` connects to the Compose `db` service; it does not use a PostgreSQL server on the Mac.

For optional database inspection from the Mac (for example, with TablePlus), use host `127.0.0.1`, port `5432`, user `postgres`, password `demo_password_not_for_production`, database `acting_for_demo_development`, and disable SSL. This development-only credential is defined by Compose and must not be reused outside this demo.

The build uses BuildKit SSH forwarding to fetch the exact private ActingFor commit. Start your SSH agent and add an authorized key before building. The key is forwarded only during `bundle install`; it is not copied into the image. No host-global Git rewrite is required.

```sh
ssh-add -l
docker compose build --ssh default
```

Run tests and reset the demo through Docker:

```sh
docker compose run --rm app bin/rails test
docker compose run --rm app bin/reset_demo
```

Stop containers without deleting database data using `docker compose down`. To completely reset Docker-managed database and runtime volumes, use `docker compose down -v`; **`-v` permanently deletes the demo database volume**. Then repeat setup. `bin/reset_demo` also drops and recreates only the non-production demo databases.

## Security notes

- Agent-supplied `amount` is not trusted or used for authorization.
- Rails loads `Product` by `product_id` and supplies `product.price` as trusted Context.
- ActingFor does not authenticate external agents. This demo uses a pre-provisioned local Agent record; external authentication and identity resolution belong to the host application.
- ActingFor authorizes; it does not execute purchases.
- `require_approval` is not `allow`. This demo stops without implementing approval.
- Production applications must independently verify that the Principal itself is authorized to perform the operation. For simplicity, Demo User is assumed to have host permission for every product.
- Direct human purchases bypass delegated authorization and therefore do not appear in ActingFor Audit Events.
- Authorize close to execution; a Decision is not a reusable authorization token.

## ActingFor dependency

ActingFor is pinned in `Gemfile` and `Gemfile.lock` to exact commit:

```text
2c2e1a6638f12b7fb961f04362f807e2cb6ff9a5
```

Status at verification: release-ready, not released, private repository. Once v0.1.0 is public on RubyGems, the Git dependency can be replaced by `gem "acting_for", "~> 0.1.0"`.

## More documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Compatibility](docs/COMPATIBILITY.md)
- [Manual verification checklist](docs/MANUAL_VERIFICATION.md)
- [Future agent integration](docs/AGENT_INTEGRATION.md)

## Tests

```sh
docker compose run --rm app bin/rails db:prepare
docker compose run --rm app bin/rails test
```

The tests exercise the host integration, not ActingFor's internal test suite.

## License

MIT, matching ActingFor. See [LICENSE](LICENSE).
