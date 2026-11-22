FROM debian:bookworm-slim

ARG ACTIONS_RUNNER_VERSION=2.329.0
ARG DOCKER_COMPOSE_VERSION=2.40.3

ENV RUNNER_SOURCE_DIR=/opt/actions-runner \
    RUNNER_DIR=/tmp/runner

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        bash \
        ca-certificates \
        curl \
        docker.io \
        git \
        jq \
        libicu72 \
        libkrb5-3 \
        liblttng-ust1 \
        libssl3 \
        libstdc++6 \
        libunwind8 \
        zlib1g \
    && mkdir -p "${RUNNER_SOURCE_DIR}" /usr/libexec/docker/cli-plugins \
    && curl -fsSL "https://github.com/actions/runner/releases/download/v${ACTIONS_RUNNER_VERSION}/actions-runner-linux-x64-${ACTIONS_RUNNER_VERSION}.tar.gz" \
        | tar -xz -C "${RUNNER_SOURCE_DIR}" \
    && curl -fsSL "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
        -o /usr/libexec/docker/cli-plugins/docker-compose \
    && chmod +x /usr/libexec/docker/cli-plugins/docker-compose \
    && rm -rf /var/lib/apt/lists/*

COPY runner-entrypoint.sh /usr/local/bin/runner-entrypoint
RUN chmod +x /usr/local/bin/runner-entrypoint

WORKDIR "${RUNNER_DIR}"
ENTRYPOINT ["runner-entrypoint"]
