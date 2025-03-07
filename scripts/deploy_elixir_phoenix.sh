#!/bin/bash
source scripts/utils.sh

deploy_elixir_phoenix() {
    log_info "Deploying Elixir Phoenix LiveView..."
    mkdir -p ~/git/zzv-mid-layer/phoenix-app
    cd ~/git/zzv-mid-layer/phoenix-app

    tee Dockerfile > /dev/null <<EOF
FROM elixir:latest
WORKDIR /app
COPY . .
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get
CMD ["mix", "phx.server"]
EOF

    docker build -t zzv-mid-layer/elixir-liveview .
    check_status "Deploying Phoenix LiveView"
}

deploy_elixir_phoenix
