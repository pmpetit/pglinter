
# This instructions must be declared before any FROM
# You can override it and build your own image based another version
# like this: `PG_MAJOR_VERSION=13 make docker_image`
# An ARG declared before a FROM is outside of a build stage, so it can’t be
# used in any instruction after a FROM. We need to declare it again.
ARG DOCKER_PG_MAJOR_VERSION=18

FROM postgres:$DOCKER_PG_MAJOR_VERSION


RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      wget \
 && rm -rf /var/lib/apt/lists/*

# Install extension
ARG PGLINTER_VERSION=1.0.1
ARG DOCKER_PG_MAJOR_VERSION=18

RUN ARCH=$(dpkg --print-architecture) \
&& wget https://github.com/pmpetit/pglinter/releases/download/$PGLINTER_VERSION/postgresql_pglinter_${DOCKER_PG_MAJOR_VERSION}_${PGLINTER_VERSION}_${ARCH}.deb \
&& dpkg -i postgresql_pglinter_${DOCKER_PG_MAJOR_VERSION}_${PGLINTER_VERSION}_${ARCH}.deb

# init script
RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./docker/init_pglinter.sh /docker-entrypoint-initdb.d/init_pglinter.sh
