#!/bin/bash
# Entrypoint script for load generator container

set -e

# Run the load generator with all passed arguments
exec python3 /app/load_generator.py "$@"
