
# This instructions must be declared before any FROM
# You can override it and build your own image based another version
# like this: `PG_MAJOR_VERSION=13 make docker_image`
ARG DOCKER_PG_MAJOR_VERSION=17

##
## First Stage: build pg_dump_anon
##
FROM golang:latest AS gobuilder
WORKDIR /go/src
COPY pg_dump_anon .
RUN CGO_ENABLED=0 GOOS=linux go build .

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
ARG ANON_VERSION=latest
RUN wget https://gitlab.com/api/v4/projects/7709206/packages/generic/deb/$ANON_VERSION/postgresql_anonymizer_pg$DOCKER_PG_MAJOR_VERSION-$ANON_VERSION.amd64.deb \
 && dpkg -i postgresql_anonymizer_pg$DOCKER_PG_MAJOR_VERSION-$ANON_VERSION.amd64.deb

# Install pg_dump_anon from the previous stage
COPY --from=gobuilder /go/src/pg_dump_anon /usr/bin/

# init script
RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./docker/init_anon.sh /docker-entrypoint-initdb.d/init_anon.sh

# Entrypoint for Anonymized Dumps (pg_dump_anon / V1)
# This is deprecated but kept for backward compatibility
COPY docker/anon.sh /anon.sh

# Entrypoint for Anonymized Dumps (pg_dump / V2)
COPY docker/dump.sh /dump.sh
