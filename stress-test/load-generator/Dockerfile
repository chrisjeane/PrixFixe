# Load Generator for PrixFixe SMTP Stress Testing
# Alpine-based Python container for minimal footprint

FROM python:3.11-alpine

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    && pip install --no-cache-dir \
    aiosmtplib \
    asyncio \
    click

# Create working directory
WORKDIR /app

# Copy load generator script
COPY load_generator.py /app/
COPY entrypoint.sh /app/

# Make scripts executable
RUN chmod +x /app/entrypoint.sh /app/load_generator.py

# Create results directory
RUN mkdir -p /results

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["--help"]
