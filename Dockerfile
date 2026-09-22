# syntax=docker/dockerfile:1.7
FROM ruby:3.4.10-slim

ENV APP_HOME=/rails \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    BUNDLE_WITHOUT=production

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR $APP_HOME

COPY Gemfile Gemfile.lock ./

# ActingFor is fetched from its public GitHub repository at the exact commit
# pinned by Gemfile / Gemfile.lock.
RUN bundle install && \
    rm -rf /usr/local/bundle/cache

COPY . .

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]
