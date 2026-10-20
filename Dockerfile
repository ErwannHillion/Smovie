# Image de production : release Elixir, construite en deux etapes.
#
# La seconde etape ne contient ni Elixir, ni Erlang source, ni les sources de
# l'application : seulement la release et ses dependances systeme. L'image
# finale pese quelques dizaines de megaoctets au lieu de plus d'un gigaoctet,
# et sa surface d'attaque se reduit d'autant.

ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.3.1
ARG DEBIAN_VERSION=bookworm-20250630-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends build-essential git ca-certificates \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# Les dependances sont copiees et compilees avant les sources : une
# modification du code applicatif ne reconstruit alors pas tout l'arbre de
# dependances.
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.deploy
RUN mix compile

COPY config/runtime.exs config/
COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# L'application est francophone : sans cette locale, les dates et les
# comparaisons de chaines se font en C et trient les accents n'importe ou.
RUN sed -i '/fr_FR.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=fr_FR.UTF-8 LANGUAGE=fr_FR:fr LC_ALL=fr_FR.UTF-8

WORKDIR /app

# La release tourne sans privileges : une faille applicative ne donne pas
# root sur le conteneur.
RUN chown nobody /app
USER nobody

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/smovie ./

EXPOSE 4000

CMD ["/app/bin/server"]
