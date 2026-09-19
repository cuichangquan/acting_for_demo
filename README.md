# ActingFor Shopping Demo

A small, hands-on Rails application showing how the [ActingFor](https://github.com/cuichangquan/acting_for) delegated-authorization gem fits into a real host application.

> **Pre-release note:** ActingFor is not yet published to RubyGems and its source repository is currently private. Until the gem is released or the source becomes public, installing this public demo requires access to the ActingFor repository.

## What this demonstrates

- Principal and Agent separation
- Delegation constraints and `allow`, `require_approval`, and `deny`
- Fail Closed when no Delegation matches
- A Context Trust Boundary: the host loads `Product#price` from PostgreSQL
- A Host Business Logic Boundary: only `decision.allowed?` creates a `Purchase`
- Automatic ActingFor authorization audit

```text
Principal
   ↓ delegates
Shopping Agent
   ↓ requests :purchase
Rails Host Application
   ↓ loads trusted Product data
ActingFor
   ↓ allow / require_approval / deny
Host Business Logic
   ↓ Purchase or Stop
```

| Product price | Decision | Host result |
| ---: | --- | --- |
| ¥800 | ALLOW | Purchase executed |
| ¥2,000 | REQUIRE APPROVAL | Purchase not executed |
| ¥5,000 | DENY (fail closed) | Purchase not executed |

## Requirements

- Ruby 3.4+ (ActingFor supports `>= 3.4, < 4.1`; `.ruby-version` records the locally verified Ruby 4.0.1)
- Rails 8.0.5.1 (installed by Bundler)
- PostgreSQL 16 or a compatible supported PostgreSQL installation
- Git access to the private ActingFor repository during the pre-release period

The ActingFor upstream Quick Start was verified on Ruby 3.4.10, Rails 8.0.5.1, and PostgreSQL 16.15. This demo's automated run used Ruby 4.0.1, Rails 8.0.5.1, and PostgreSQL 16.x, all within ActingFor's current support matrix.

## Quick Start

```sh
git clone https://github.com/cuichangquan/acting_for_demo.git
cd acting_for_demo
bin/setup --skip-server
bin/rails server
```

Open <http://localhost:3000>. Configure PostgreSQL using `PGHOST`, `PGUSER`, and `PGPASSWORD`, or edit `config/database.yml`. The database user must be able to create databases.

While ActingFor is private, authenticate Git first. If your account uses SSH, the upstream pre-release guidance is:

```sh
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

Remove that global rewrite later if it is not appropriate for your environment. `bin/reset_demo` drops and recreates only the non-production demo databases and restores seed state.

## Security notes

- Agent-supplied `amount` is not trusted or used for authorization.
- Rails loads `Product` by `product_id` and supplies `product.price` as trusted Context.
- ActingFor does not authenticate external agents. This demo uses a pre-provisioned local Agent record; external authentication and identity resolution belong to the host application.
- ActingFor authorizes; it does not execute purchases.
- `require_approval` is not `allow`. This demo stops without implementing approval.
- Production applications must independently verify that the Principal itself is authorized to perform the operation. For simplicity, Demo User is assumed to have host permission for every product.
- Authorize close to execution; a Decision is not a reusable authorization token.

## ActingFor dependency

ActingFor is pinned in `Gemfile` and `Gemfile.lock` to exact commit:

```text
5293f25a21093fa514df53466df503984e4981d1
```

Status at verification: release-ready, not released, private repository. Once v0.1.0 is public on RubyGems, the Git dependency can be replaced by `gem "acting_for", "~> 0.1.0"`.

## More documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Manual verification checklist](docs/MANUAL_VERIFICATION.md)
- [Future agent integration](docs/AGENT_INTEGRATION.md)

## Tests

```sh
bin/rails db:prepare
bin/rails test
```

The tests exercise the host integration, not ActingFor's internal test suite.

## License

MIT, matching ActingFor. See [LICENSE](LICENSE).
