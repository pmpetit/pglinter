
# This instructions must be declared before any FROM
# You can override it and build your own image based another version
# like this: `PG_MAJOR_VERSION=13 make docker_image`
# An ARG declared before a FROM is outside of a build stage, so it can’t be
# used in any instruction after a FROM. We need to declare it again.
ARG DOCKER_PG_MAJOR_VERSION=13

FROM postgres:$DOCKER_PG_MAJOR_VERSION


RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      wget \
 && rm -rf /var/lib/apt/lists/*

# Install extension
ARG PGLINTER_VERSION=latest
RUN wget https://ghcr.io/api/v4/projects/7709206/packages/generic/deb/$PGLINTER_VERSION/postgresql_pglinter_pg$DOCKER_PG_MAJOR_VERSION-$PGLINTER_VERSION.amd64.deb \
 && dpkg -i postgresql_pglinter_pg$DOCKER_PG_MAJOR_VERSION-$PGLINTER_VERSION.amd64.deb

# init script
RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./docker/init_pglinter.sh /docker-entrypoint-initdb.d/init_pglinter.sh
