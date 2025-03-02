# Elixir Phoenix Application Dockerfile for zzv.io
# Filename: ./Dockerfile
FROM elixir:1.18.2 AS builder

# Set environment for build
ENV MIX_ENV=prod \
    LANG=C.UTF-8 \
    APP_NAME=zzv_app

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y build-essential git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Create app directory
WORKDIR /app

# Copy dependency files for better caching
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application code
COPY . .

# Compile and build release
RUN mix compile
RUN mix phx.digest
RUN mix release

# Create final image
FROM ubuntu:22.04.5

# Install runtime dependencies and SSH server
RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl ca-certificates ncurses-bin curl \
    openssh-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/run/sshd

# Set environment variables
ENV LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PHX_SERVER=true \
    MIX_ENV=prod \
    PORT=443 \
    DOMAIN=zzv.io \
    KAFKA_BROKER="kafka.zzv.io:9092" \
    DATABASE_URL="mongodb://username:password@mongodb.zzv.io:27017"

# Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    echo "AllowGroups admins" >> /etc/ssh/sshd_config

# Create admin group and user directories
RUN groupadd admins && \
    mkdir -p /home/admin/.ssh && \
    chmod 700 /home/admin/.ssh

# Create app user for running the application
RUN groupadd -r app && useradd -r -g app app

# Set up work directory
WORKDIR /app

# Copy the release from the builder stage
COPY --from=builder --chown=app:app /app/_build/prod/rel/zzv_app ./

# Copy SSH authorized_keys for admin access
COPY --chown=root:root ./config/ssh/authorized_keys /home/admin/.ssh/authorized_keys
RUN chmod 600 /home/admin/.ssh/authorized_keys

# Expose HTTPS and SSH ports
EXPOSE 443 22

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f -k https://localhost:443/health || exit 1

# Create entrypoint script to start both SSH and the Phoenix app
RUN echo '#!/bin/bash\n\
/usr/sbin/sshd\n\
exec /app/bin/zzv_app start\n\
' > /app/entrypoint.sh && \
chmod +x /app/entrypoint.sh

# Start SSH server and Phoenix app
CMD ["/app/entrypoint.sh"]
