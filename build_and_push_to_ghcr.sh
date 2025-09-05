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

# Try to authenticate using environment variables
if [ -n "$GITHUB_TOKEN" ]; then
    echo "🔑 Using GITHUB_TOKEN environment variable for authentication..."
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u ${GITHUB_USER} --password-stdin
elif [ -n "$CR_PAT" ]; then
    echo "🔑 Using CR_PAT environment variable for authentication..."
    echo "$CR_PAT" | docker login ghcr.io -u ${GITHUB_USER} --password-stdin
elif [ -n "$GITHUB_PAT" ]; then
    echo "🔑 Using GITHUB_PAT environment variable for authentication..."
    echo "$GITHUB_PAT" | docker login ghcr.io -u ${GITHUB_USER} --password-stdin
else
    # Check if already authenticated
    if ! docker pull ghcr.io/hello-world &> /dev/null; then
        echo "❌ Not authenticated with GHCR and no token environment variable found."
        echo "💡 Set one of these environment variables:"
        echo "   export GITHUB_TOKEN='your_token'"
        echo "   export CR_PAT='your_token'"
        echo "   export GITHUB_PAT='your_token'"
        echo ""
        echo "🔗 Or login manually:"
        echo "   echo 'YOUR_GITHUB_TOKEN' | docker login ghcr.io -u ${GITHUB_USER} --password-stdin"
        echo ""
        echo "📋 Your token needs 'write:packages' and 'read:packages' scopes"
        exit 1
    fi
    echo "✅ Already authenticated with GHCR"
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
