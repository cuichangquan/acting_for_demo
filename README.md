# ActingFor Shopping Demo

A small, hands-on Rails application showing how the [ActingFor](https://github.com/cuichangquan/acting_for) delegated-authorization gem fits into a real host application.

> **Pre-release note:** ActingFor is not yet published to RubyGems and its source repository is currently private. Until the gem is released or the source becomes public, installing this demo requires access to the ActingFor repository. The demo repository is also private during this verification phase.

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
docker compose run --rm app bin/rails db:prepare
docker compose run --rm app bin/rails test
```

The tests exercise the host integration, not ActingFor's internal test suite.

## License

MIT, matching ActingFor. See [LICENSE](LICENSE).
