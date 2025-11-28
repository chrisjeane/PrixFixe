# PrixFixe SMTP Server - Multi-stage Docker Build
# This Dockerfile builds a minimal production image for the SimpleServer example

# ============================================================================
# Stage 1: Builder
# ============================================================================
FROM swift:6.0-jammy AS builder

# Install system dependencies for building
RUN apt-get update && apt-get install -y \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy package manifest first for dependency caching
COPY Package.swift ./

# Copy source code
COPY Sources ./Sources

# Copy Tests directory structure (swift files excluded via .dockerignore)
# This is needed because Package.swift references test targets
COPY Tests ./Tests

# Copy Examples
COPY Examples ./Examples

# Build the main library in release mode (test targets will be skipped - no source files)
RUN swift build -c release --target PrixFixe

# Build SimpleServer - it references the parent package
WORKDIR /build/Examples/SimpleServer
RUN swift build -c release

# ============================================================================
# Stage 2: Runtime
# ============================================================================
# Use Swift slim runtime which includes necessary Swift runtime libraries
FROM swift:6.0-jammy-slim

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libsqlite3-0 \
    procps \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create non-root user for running the server
RUN groupadd -g 1000 smtp && \
    useradd -u 1000 -g smtp -m -s /bin/bash smtp

# Create directories for runtime
RUN mkdir -p /var/mail /etc/prixfixe /var/log/prixfixe && \
    chown -R smtp:smtp /var/mail /var/log/prixfixe

# Copy the built binary from builder stage
COPY --from=builder /build/Examples/SimpleServer/.build/release/SimpleServer /usr/local/bin/prixfixe-server

# Make binary executable
RUN chmod +x /usr/local/bin/prixfixe-server

# Switch to non-root user
USER smtp

# Set working directory
WORKDIR /var/mail

# Expose SMTP port
EXPOSE 2525

# Health check - verify the process is running
# Note: This is a basic check. In production, you'd want to test actual SMTP connectivity
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD pgrep -f prixfixe-server || exit 1

# Set default environment variables
ENV SMTP_DOMAIN=localhost \
    SMTP_PORT=2525 \
    SMTP_MAX_CONNECTIONS=100 \
    SMTP_MAX_MESSAGE_SIZE=10485760

# Labels for metadata
LABEL org.opencontainers.image.title="PrixFixe SMTP Server" \
      org.opencontainers.image.description="Lightweight embedded SMTP server written in Swift" \
      org.opencontainers.image.version="0.1.0" \
      org.opencontainers.image.authors="PrixFixe Team" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/yourusername/PrixFixe"

# Run the server
CMD ["/usr/local/bin/prixfixe-server"]
