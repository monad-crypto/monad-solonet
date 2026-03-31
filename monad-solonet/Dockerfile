FROM ubuntu:noble

ARG MONAD_VERSION=0.13.1
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

# Install OTEL collector
RUN curl -fsSL -o /tmp/otelcol_linux_amd64.deb \
    "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol_${OTEL_VERSION}_linux_amd64.deb" \
    && dpkg -i /tmp/otelcol_linux_amd64.deb

# Install monad client
COPY solonet/config/category-labs.sources /etc/apt/sources.list.d/category-labs.sources
RUN apt-get install -y supervisor
RUN curl -fsSL https://pkg.category.xyz/keys/public-key.asc \
    | gpg --dearmor --yes -o /etc/apt/keyrings/category-labs.gpg \
    && apt-get update && apt-get install -y monad=${MONAD_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Install gotemplate
RUN curl -L -o /usr/local/bin/gomplate \
    https://github.com/hairyhenderson/gomplate/releases/latest/download/gomplate_linux-amd64 \ 
    && chmod +x /usr/local/bin/gomplate

# Setup dashboard
RUN rm -f /etc/nginx/sites-enabled/default
COPY dashboard/ /dashboard/
COPY dashboard/dashboard.conf /etc/nginx/conf.d/.

# Setup solonet
COPY solonet/   /solonet/
COPY bin/       /usr/local/bin/
ENTRYPOINT ["/usr/bin/tini"]
CMD ["/solonet/run.sh"]
