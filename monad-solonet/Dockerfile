FROM ubuntu:noble AS solonet

ARG OTEL_VERSION=0.139.0
ARG SOLONET_VERSION=dev

ENV ETH_RPC_URL="http://localhost:8080"
ENV SOLONET_VERSION=${SOLONET_VERSION}

WORKDIR /root/

# Install dependencies
RUN apt-get update && apt-get install -y \
    aria2 \
    ca-certificates \
    cpulimit \
    curl \
    git \
    gnupg \
    jq \
    pipx \
    python3 \
    nginx \
    supervisor \
    tini \
    vim \
    yq \
    && rm -rf "/var/lib/apt/lists/*"

# Install staking-cli
RUN git clone "https://github.com/monad-developers/staking-sdk-cli.git" \
    && cd staking-sdk-cli \
    && python3 -m venv cli-venv \
    && . cli-venv/bin/activate \
    && pip install .

# Install monad-status
RUN curl -sSL https://bucket.monadinfra.com/scripts/monad-status.sh \
    -o /usr/local/bin/monad-status \
    && chmod +x /usr/local/bin/monad-status

# Install foundry
RUN curl -L https://foundry.paradigm.xyz | bash \
    && . ~/.bashrc \
    && foundryup
ENV PATH="/root/.foundry/bin:${PATH}"

# Install OTEL collector
RUN curl -fsSL -o /tmp/otelcol_linux_amd64.deb \
    "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol_${OTEL_VERSION}_linux_amd64.deb" \
    && dpkg -i /tmp/otelcol_linux_amd64.deb

# Install Category Labs APT sources
COPY solonet/config/category-labs.sources /etc/apt/sources.list.d/category-labs.sources
RUN curl -fsSL https://pkg.category.xyz/keys/public-key.asc \
    | gpg --dearmor --yes -o /etc/apt/keyrings/category-labs.gpg

# Install gotemplate
RUN curl -L -o /usr/local/bin/gomplate \
    https://github.com/hairyhenderson/gomplate/releases/latest/download/gomplate_linux-amd64 \
    && chmod +x /usr/local/bin/gomplate

# Setup dashboard
RUN rm -f /etc/nginx/sites-enabled/default
COPY dashboard/ /dashboard/
COPY dashboard/dashboard.conf /etc/nginx/conf.d/.
RUN echo "window.SOLONET_VERSION='${SOLONET_VERSION}';" > /dashboard/web/version.js

# Setup solonet
COPY solonet/   /solonet/
COPY bin/       /usr/local/bin/
ENTRYPOINT ["/usr/bin/tini"]
CMD ["/solonet/run.sh"]

###################################################################
FROM monad-builder AS builder-remote

ARG MONAD_BFT_REPO_URL="https://github.com/category-labs/monad-bft.git"
ARG MONAD_BFT_REPO_TARGET="master"
ARG MONAD_EXECUTION_REPO_URL
ARG MONAD_EXECUTION_REPO_TARGET

RUN echo 'deb [trusted=yes] https://repo.goreleaser.com/apt/ /' > /etc/apt/sources.list.d/goreleaser.list \
    && apt-get update \
    && apt-get install -y nfpm binutils \
    && rm -rf /var/lib/apt/lists/*

COPY source/*.sh /usr/local/bin/
COPY source/nfpm.yml /app/nfpm.yml

WORKDIR /app/monad-bft/
RUN --mount=type=cache,id=cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=cargo-git,target=/usr/local/cargo/git \
    clone-monad.sh && build-monad.sh && package-monad.sh

###################################################################
FROM monad-builder AS builder-local

ARG MONAD_LOCAL_SOURCE="./source/monad-bft"

RUN echo 'deb [trusted=yes] https://repo.goreleaser.com/apt/ /' > /etc/apt/sources.list.d/goreleaser.list \
    && apt-get update \
    && apt-get install -y nfpm binutils \
    && rm -rf /var/lib/apt/lists/*

COPY source/*.sh /usr/local/bin/
COPY source/nfpm.yml /app/nfpm.yml
COPY ${MONAD_LOCAL_SOURCE} /app/monad-bft/

WORKDIR /app/monad-bft/
RUN --mount=type=cache,id=cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=cargo-git,target=/usr/local/cargo/git \
    git submodule update --init --recursive --depth 1 && \
    build-monad.sh && package-monad.sh

###################################################################
FROM solonet AS install-remote
COPY --from=builder-remote /app/package/monad_0.0.0_amd64.deb /app/package/monad_0.0.0_amd64.deb
RUN apt-get update \
    && apt-get install -y /app/package/monad_0.0.0_amd64.deb \
    && rm -rf /var/lib/apt/lists/*
###################################################################
FROM solonet AS install-local
COPY --from=builder-local /app/package/monad_0.0.0_amd64.deb /app/package/monad_0.0.0_amd64.deb
RUN apt-get update \
    && apt-get install -y /app/package/monad_0.0.0_amd64.deb \
    && rm -rf /var/lib/apt/lists/*
###################################################################
FROM solonet AS install-apt
ARG MONAD_VERSION=0.14.2
RUN apt-get update \
    && apt-get install -y monad=${MONAD_VERSION} \
    && rm -rf /var/lib/apt/lists/*
###################################################################
FROM install-apt AS default
