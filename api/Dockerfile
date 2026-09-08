# Development image. Source is bind-mounted by docker-compose, so this layer
# only needs the toolchain and the gems. The production image (multi-stage,
# non-root, bootsnap precompiled) arrives in Phase 11.
FROM ruby:3.3-slim

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4

# build-essential + libpq-dev build the pg native extension; libvips is here
# now so image processing (Phase 9) does not force an image rebuild later.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      curl \
      git \
      libpq-dev \
      libvips \
      postgresql-client && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Gems install in their own layer so editing app code does not re-bundle.
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
