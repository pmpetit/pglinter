#!/bin/bash
# Script to build and push PostgreSQL Anonymizer container to GitHub Container Registry
# Usage: ./build_and_push_to_ghcr.sh

set -e  # Exit on any error

# Configuration
GITHUB_USER="pmpetit"
IMAGE_NAME="postgresql_pglinter"
TAG="pgrx"
FULL_IMAGE_NAME="ghcr.io/${GITHUB_USER}/${IMAGE_NAME}:${TAG}"

echo "🏗️  Building and pushing PostgreSQL pglinter container to GHCR..."
echo "📦 Image: ${FULL_IMAGE_NAME}"
echo ""

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Error: Docker is not running."
    echo "🐳 Please start Docker and try again."
    exit 1
fi

# Check if logged in to GHCR
echo "🔐 Checking GitHub Container Registry authentication..."
if ! docker pull ghcr.io/hello-world &> /dev/null; then
    echo "❌ Not authenticated with GHCR. Please login first:"
    echo "💡 Run: echo 'YOUR_GITHUB_TOKEN' | docker login ghcr.io -u ${GITHUB_USER} --password-stdin"
    echo "📋 Your token needs 'write:packages' and 'read:packages' scopes"
    exit 1
fi

# Build the container
echo "🏗️  Building Docker image..."
if [ -f "docker/Dockerfile" ]; then
    # Build from docker subdirectory if it exists
    docker build -t "${FULL_IMAGE_NAME}" -f docker/Dockerfile .
elif [ -f "Dockerfile" ]; then
    # Build from root Dockerfile
    docker build -t "${FULL_IMAGE_NAME}" .
else
    echo "❌ Error: No Dockerfile found in current directory or docker/ subdirectory."
    exit 1
fi

# Push to GHCR
echo "📤 Pushing image to GitHub Container Registry..."
docker push "${FULL_IMAGE_NAME}"

echo ""
echo "✅ Successfully built and pushed image to GHCR!"
echo "🐳 Image: ${FULL_IMAGE_NAME}"
echo ""
echo "📋 To use this image in GitHub Actions, update your workflow:"
echo "   container: ${FULL_IMAGE_NAME}"
echo ""
echo "🔧 To update your current workflows:"
echo "   sed -i 's|ghcr.io/pmpetit/postgresql_anonymizer|ghcr.io/pmpetit/postgresql_pglinter|g' .github/workflows/*.yml"
