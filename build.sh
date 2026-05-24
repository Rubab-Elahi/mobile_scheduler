#!/bin/bash

# AI Mobile Scheduler — Lambda Dependency Build Script
# This script bundles Python requirements into each service folder
# so they can be packaged by Terraform's archive_file.

set -e

# Get project root (parent of infra/ and services/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="$PROJECT_ROOT/services"

echo "🚀 Starting Lambda dependency bundling..."

for service_dir in "$SERVICES_DIR"/*; do
    if [ -d "$service_dir" ] && [ -f "$service_dir/requirements.txt" ]; then
        service_name=$(basename "$service_dir")
        echo "📦 Processing $service_name..."
        
        cd "$service_dir"
        
        # Install dependencies directly into the service folder
        # --upgrade ensures we get latest versions
        # --no-cache-dir saves space
        pip install -r requirements.txt --target . --upgrade --no-cache-dir
        
        # Clean up __pycache__ and other bloat to keep zips small
        find . -type d -name "__pycache__" -exec rm -rf {} +
        find . -type d -name "*.dist-info" -exec rm -rf {} +
        find . -type d -name "*.egg-info" -exec rm -rf {} +
        
        echo "✅ $service_name dependencies bundled."
    fi
done

echo "🎉 All dependencies bundled successfully. You can now run 'terraform apply'."
cd "$PROJECT_ROOT"
