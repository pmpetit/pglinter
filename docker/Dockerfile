
# This instructions must be declared before any FROM
# You can override it and build your own image based another version
# like this: `PG_MAJOR_VERSION=13 make docker_image`
ARG DOCKER_PG_MAJOR_VERSION=17

##
## First Stage: build pg_dump_anon
##
# FROM golang:latest AS gobuilder
# WORKDIR /go/src
# RUN CGO_ENABLED=0 GOOS=linux go build .

##
## Second Stage
##
ARG DOCKER_PG_MAJOR_VERSION=17
FROM postgres:$DOCKER_PG_MAJOR_VERSION

# An ARG declared before a FROM is outside of a build stage, so it can’t be
# used in any instruction after a FROM. We need to declare it again.
ARG DOCKER_PG_MAJOR_VERSION=17

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      wget \
 && rm -rf /var/lib/apt/lists/*

# Install anon extension
ARG PGLINTER_VERSION=latest
RUN wget https://ghcr.io/api/v4/projects/7709206/packages/generic/deb/$PGLINTER_VERSION/postgresql_pglinter_pg$DOCKER_PG_MAJOR_VERSION-$PGLINTER_VERSION.amd64.deb \
 && dpkg -i postgresql_pglinter_pg$DOCKER_PG_MAJOR_VERSION-$PGLINTER_VERSION.amd64.deb

# Install pg_dump_anon from the previous stage
# COPY --from=gobuilder /go/src/pg_dump_anon /usr/bin/

# init script
RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./docker/init_pglinter.sh /docker-entrypoint-initdb.d/init_pglinter.sh

# Entrypoint for Anonymized Dumps (pg_dump_anon / V1)
# This is deprecated but kept for backward compatibility
COPY docker/pglinter.sh /pglinter.sh

# # Entrypoint for Anonymized Dumps (pg_dump / V2)
# COPY docker/dump.sh /dump.sh
