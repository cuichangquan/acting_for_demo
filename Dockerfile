# syntax=docker/dockerfile:1.7
FROM ruby:3.4.10-slim

ENV APP_HOME=/rails \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    BUNDLE_WITHOUT=production

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev openssh-client && \
    rm -rf /var/lib/apt/lists/*

WORKDIR $APP_HOME

COPY Gemfile Gemfile.lock ./

# ActingFor is private before release. BuildKit forwards the host SSH agent for
# this step only; no key or token is copied into this image or image layer.
RUN --mount=type=ssh \
    mkdir -p -m 0700 /root/.ssh && \
    ssh-keyscan github.com >> /root/.ssh/known_hosts && \
    git config --global url."git@github.com:".insteadOf "https://github.com/" && \
    bundle install && \
    rm -rf /root/.ssh /root/.gitconfig /usr/local/bundle/cache

COPY . .

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]
